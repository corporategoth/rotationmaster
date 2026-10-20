local _,addon=...
-- Desired profile data only. Inventory snapshots are explicit caller inputs.
local type,pairs,getmetatable=type,pairs,getmetatable
local huge,format,sort=math.huge,string.format,table.sort
local stock={};addon.StockTargets=stock
local fields={itemID=true,minimum=true,target=true,enabled=true}
local function plain(value)return type(value)=='table'and getmetatable(value)==nil end
local function integer(value)return type(value)=='number'and value==value and value~=huge and value~=-huge and value%1==0 end
local function quantity(value)return integer(value)and value>=0 and value<=1000000 end
local function itemID(value)return integer(value)and value>0 end
local function rowID(value)return type(value)=='string'and #value>0 and #value<=128 and not value:find('[%z\1-\31\127]')end
local function configuration(row)
 return plain(row)and itemID(row.itemID)and quantity(row.minimum)and quantity(row.target)and row.minimum<=row.target and type(row.enabled)=='boolean'
end
function stock.Validate(plan)
 if plan==nil then return true end
 if not plain(plan)then return nil,'invalid-stock-plan' end
 local count,items=0,{}
 for id,row in pairs(plan)do
  count=count+1;if count>128 then return nil,'stock-target-limit' end
  if not rowID(id)then return nil,'invalid-stock-row-id' end
  if not plain(row)then return nil,'invalid-stock-row',id end
  for key in pairs(row)do if not fields[key]then return nil,'invalid-stock-fields',id end end
  if not itemID(row.itemID)then return nil,'invalid-stock-item-id',id end
  if not quantity(row.minimum)or not quantity(row.target)then return nil,'invalid-stock-quantity',id end
  if row.minimum>row.target then return nil,'invalid-stock-range',id end
  if type(row.enabled)~='boolean'then return nil,'invalid-stock-enabled',id end
  if items[row.itemID]then return nil,'duplicate-stock-item',id end
  items[row.itemID]=true
 end
 return true
end
function stock.BuildReport(plan,counts,reason)
 local ok,why,id=stock.Validate(plan);if not ok then return nil,why,id end
 local report={rows={},complete=true}
 local complete=plain(counts)and reason==nil
 for key,config in pairs(plan or {})do
  local carried;if complete then carried=rawget(counts,config.itemID)end
  if complete and carried==nil then carried=0 end
  local known=complete and integer(carried)and carried>=0 or false
  local row={rowID=key,itemID=config.itemID,minimum=config.minimum,target=config.target,enabled=config.enabled,countKnown=known}
  if known then row.carried=carried else row.reason=complete and 'invalid-stock-count'or 'inventory-unavailable' end
  if not row.enabled then row.shortage=0
  elseif known then row.shortage=carried<row.minimum and row.target-carried or 0
  else report.complete=false;report.reason='inventory-unavailable' end
  report.rows[#report.rows+1]=row
 end
 sort(report.rows,function(a,b)return a.itemID<b.itemID end)
 return report
end
function stock.FormatShortages(report)
 if not plain(report)or type(report.complete)~='boolean'or not plain(report.rows)then return nil,'invalid-stock-report' end
 if not report.complete then return nil,'inventory-unavailable' end
 local rows,seen,count,maximum={},{},0,0
 for index,row in pairs(report.rows)do
  count=count+1
  if count>128 or not integer(index)or index<1 or index>128 or not configuration(row)or seen[row.itemID]then return nil,'invalid-stock-report' end
  seen[row.itemID]=true;if index>maximum then maximum=index end
  if row.enabled then
   if row.countKnown~=true or not integer(row.carried)or row.carried<0 then return nil,'invalid-stock-report' end
   local expected=row.carried<row.minimum and row.target-row.carried or 0
   if row.shortage~=expected then return nil,'invalid-stock-report' end
   if expected>0 then rows[#rows+1]={itemID=row.itemID,shortage=expected}end
  elseif row.shortage~=0 then return nil,'invalid-stock-report' end
 end
 if count~=maximum then return nil,'invalid-stock-report' end
 sort(rows,function(a,b)return a.itemID<b.itemID end)
 local lines={'Carried bags:'}
 for _,row in ipairs(rows)do lines[#lines+1]=format('%.0f x %.0f',row.itemID,row.shortage)end
 if #rows==0 then lines[#lines+1]='No shortages.'end
 return table.concat(lines,'\n')
end
