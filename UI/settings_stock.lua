-- Profile desired-stock editing and a private visible-only inventory observation session.
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function integer(n)return type(n)=='number'and n==n and n~=math.huge and n~=-math.huge and n%1==0 end
local function quantity(text)local n=tonumber(text);if integer(n)and n>=0 and n<=1000000 then return n end end
-- Observations belong to one visible pane/owner lease and never enter desired data.
local sessions={}
local paint,request
local function stockClearReport(d,expected)
 if d.stockLease and d.stockLease~=expected then return end
 d.stockLease=nil
 if d.chrome and d.chrome.drag then d.chrome.drag.moving=nil;d.frame:StopMovingOrSizing()end
 if d.stockLease then return end
 d.text='';d.input:ClearFocus()
 if d.stockLease then return end
 d.setting=true;d.input:SetText('')
 if d.stockLease then return end
 d.setting=false;d.measure:SetText('')
 if d.stockOriginalHide then d.stockOriginalHide(d)else d:Hide()end
 if not d.stockLease and d.stockOriginalFrameHide then d.stockOriginalFrameHide(d.frame)end
end
local function stockStop(p,expected)
 local s=sessions[p];if not s or expected and s~=expected then return end
 sessions[p]=nil;s.retired=true;s.refs=nil;s.counts=nil;s.reason=nil;s.profile=nil;s.global=nil;s.char=nil
 local pending=s.pending;s.pending=nil
 s.events:UnregisterAllEvents();s.events:SetScript('OnEvent',nil)
 if s.report then stockClearReport(s.report,s);s.report=nil end
 if pending and pending.handle then pcall(addon.CancelTimer,addon,pending.handle)end
end
local function stockLive(s)
 local p=s.p
 return not s.retired and sessions[p]==s and p.active and p.settingsKey=='ItemSets'and p.itemSettingsSource=='stock'and p.frame:IsVisible()
 and rawequal(p.profile,addon.db.profile)and rawequal(p.global,addon.db.global)and rawequal(p.char,addon.db.char)
 and rawequal(s.profile,addon.db.profile)and rawequal(s.global,addon.db.global)and rawequal(s.char,addon.db.char)
end
local function stockSaved(s)
 if not stockLive(s)then return end
 local raw=rawget(s.profile,'stockTargets');if not addon.StockTargets.Validate(raw)then return end
 return true,raw
end
local function stockReport(s,plan)
 if s.pending then return end
 local platform=addon.Platform;local counts=s.counts
 local ok,report=pcall(function()
  if not platform:CanReadValue(counts)or type(counts)~='table'or getmetatable(counts)~=nil then return addon.StockTargets.BuildReport(plan,nil,'inventory-unavailable')end
  local selected={}
  for _,row in pairs(plan or{})do
   local count=rawget(counts,row.itemID)
   if not platform:CanReadValue(count)then return addon.StockTargets.BuildReport(plan,nil,'inventory-unavailable')end
   if count~=nil then selected[row.itemID]=count end
  end
  return addon.StockTargets.BuildReport(plan,selected,s.reason)
 end)
 if ok then return report end
end
-- Assessment uses the already-built committed report, never a second observation.
local function stockReadinessText(report,reason,pending)
 if pending then return L['Saved stock counts pending.'] end
 if reason=='page-changes' then return L['Apply or discard page changes to assess saved targets.'] end
 if not report then return L['Saved stock readiness unavailable.'] end
 local enabled,below,unknown=0,0,0
 for _,row in ipairs(report.rows)do
  if row.enabled then
   enabled=enabled+1
   if not row.countKnown then unknown=unknown+1 elseif row.carried<row.minimum then below=below+1 end
  end
 end
 if enabled==0 then return L['No enabled saved targets.'] end
 if unknown>0 then return string.format(L['%d below minimum; %d unknown.'],below,unknown) end
 if below>0 then return string.format(L['%d saved targets below minimum.'],below) end
 return L['All saved minimums met.']
end
local function stockReadinessLabel(p)
 local control=p:Text('');local previous=control:GetHeight();local height=previous
 -- Reserve every localized state at Draw; later count updates only change text.
 control:SetText('0');local lineHeight=control:GetStringHeight();control:SetHeight(0)
 for _,text in ipairs({L['All saved minimums met.'],L['No enabled saved targets.'],string.format(L['%d saved targets below minimum.'],128),
  string.format(L['%d below minimum; %d unknown.'],128,128),L['Saved stock counts pending.'],
  L['Apply or discard page changes to assess saved targets.'],L['Saved stock readiness unavailable.']})do
  control:SetText(text);height=math.max(height,control:GetStringHeight())
 end
 -- One extra native line allows digit-width variation in the bounded counts.
 control:SetHeight(height+lineHeight);control:SetText('');p.y=p.y+control:GetHeight()-previous
 return control
end
local function copyReady(s)
 local ok,raw=stockSaved(s);if not ok then return end
 if s.p.creating then return nil,nil,nil,'page-changes' end
 local p=s.p
 if not p.draft or not p.draftBaseline or not addon.StockTargets.Validate(p.draft.profile.stockTargets)or not addon.StockTargets.Validate(p.draftBaseline.profile.stockTargets)then return end
 if p:IsSettingsDraftDirty()or not addon:SettingsDataEqual(raw,p.draftBaseline.profile.stockTargets)then return nil,nil,nil,'page-changes' end
 local report=stockReport(s,raw)
 if report and report.complete then return report,raw,report end
 return nil,nil,report
end
paint=function(s)
 if not stockLive(s)then stockStop(s.p,s);return end
 local refs=s.refs;if not refs or not s.p:Valid(refs.generation)then return end
 local saved=stockSaved(s)
 if not saved then s.ready=false;s.counts=nil end
 local plan=s.p.draft and s.p.draft.profile.stockTargets
 local report=saved and addon.StockTargets.Validate(plan)and stockReport(s,plan)
 local selected=refs.row and addon.StockTargets.Validate({selected=refs.row})and stockReport(s,{selected=refs.row})
 local row=selected and selected.rows[1]
 local canCopy,_,assessmentReport,assessmentReason=copyReady(s)
 if not stockLive(s)or s.refs~=refs or not s.p:Valid(refs.generation)then return end
 refs.status:SetText(s.pending and L['Stock counts pending.']or report and report.complete and L['Stock counts ready.']or L['Stock counts unavailable.'])
 refs.readiness:SetText(stockReadinessText(assessmentReport,assessmentReason,s.pending))
 if refs.row then
  refs.carried:SetText(string.format(L['Carried: %s'],row and row.countKnown and string.format('%.0f',row.carried)or L['Unknown']))
  refs.shortage:SetText(string.format(L['Shortage: %s'],row and row.shortage~=nil and string.format('%.0f',row.shortage)or L['Unknown']))
 end
 if canCopy then refs.copy:Enable()else refs.copy:Disable()end
end
request=function(s)
 if not stockLive(s)then stockStop(s.p,s);return end
 if not stockSaved(s)then s.ready=false;s.counts=nil;paint(s);return end
 if s.pending then return end
 s.serial=s.serial+1;local pending={serial=s.serial};s.pending=pending;paint(s)
 local ok,handle=pcall(addon.ScheduleTimer,addon,function()
  if not stockLive(s)then stockStop(s.p,s);return end
  if s.pending~=pending then return end
  s.pending=nil
  if not stockSaved(s)then s.ready=false;s.counts=nil;paint(s);return end
  s.ready=false;s.counts=nil;s.reason='inventory-unavailable'
  local selected,platform,method=pcall(function()
   local owner=addon.Platform
   if type(owner)~='table'then return end
   local fn=owner.GetBagItemCounts
   if not owner:CanReadValue(fn)or type(fn)~='function'then return end
   return owner,fn
  end)
  if not stockLive(s)then stockStop(s.p,s);return end
  local success,counts,reason
  if selected and method then success,counts,reason=pcall(method,platform)end
  if not stockLive(s)then stockStop(s.p,s);return end
  if s.serial~=pending.serial then paint(s);return end
  s.ready=success==true
  if success then s.counts=counts;s.reason=reason else s.counts=nil;s.reason='inventory-unavailable'end
  paint(s)
 end,0)
 if s.pending==pending then
  if ok and handle then pending.handle=handle
  else s.pending=nil;s.ready=false;s.counts=nil;s.reason='inventory-unavailable';paint(s)end
 elseif ok and handle and not stockLive(s)then addon:CancelTimer(handle)
 end
end
local function stockObserve(p)
 local s=sessions[p]
 if s and not stockLive(s)then stockStop(p);s=nil end
 if not s then
  p.stockObservationEvents=p.stockObservationEvents or CreateFrame('Frame',nil,p.frame)
  s={p=p,profile=addon.db.profile,global=addon.db.global,char=addon.db.char,serial=0,events=p.stockObservationEvents};sessions[p]=s
  p.stopStockObservation=function()stockStop(p)end
  p.checkStockObservationOwner=function()local current=sessions[p];if current and not stockLive(current)then stockStop(p)end end
  p.updateStockObservationActions=function()local current=sessions[p];if current then paint(current)end end
  s.events:RegisterEvent('BAG_UPDATE');s.events:RegisterEvent('PLAYER_ENTERING_WORLD');s.events:SetScript('OnEvent',function()request(s)end)
  request(s)
 end
 return s
end
local function stockCopy(s,generation)
 if not stockLive(s)or not s.p:Valid(generation)then return end
 local report,raw=copyReady(s)
 if not report then s.p:Message(L['Apply or discard page changes and refresh stock counts before copying.']);return end
 local saved=addon:CopySettingsData(raw)
 local ok,text=pcall(addon.StockTargets.FormatShortages,report)
 if not ok or type(text)~='string'or not stockLive(s)or not copyReady(s)or not addon:SettingsDataEqual(rawget(s.profile,'stockTargets'),saved)then return end
 local p=s.p
 if p.stockReportConstructing then return end
 local d=p.stockObservationReport
 if not d then
  p.stockReportConstructing=true
  local made,result=pcall(addon.CreateWorkbenchTextReport,addon)
  p.stockReportConstructing=nil
  if not made or not result then return end
  d=result;p.stockObservationReport=d
 end
 if not stockLive(s)or not p:Valid(generation)or not copyReady(s)or not addon:SettingsDataEqual(rawget(s.profile,'stockTargets'),saved)then stockClearReport(d,s);return end
 if not d.stockOriginalHide then
  addon:RegisterWindowForEscape(d)
  d.stockOriginalHide=d.Hide;d.stockOriginalFrameHide=d.frame:GetScript('OnHide')
  d.stockScripts={}
  for _,record in ipairs({{d.copy,'OnClick'},{d.close,'OnClick'},{d.input,'OnEscapePressed'},{d.input,'OnMouseWheel'},{d.input,'OnTextChanged'},{d.input,'OnCursorChanged'},{d.frame,'OnHide'},{d.frame,'OnShow'},{d.chrome.drag,'OnDragStart'},{d.chrome.drag,'OnDragStop'},{d.chrome.drag,'OnMouseUp'},{d.chrome.drag,'OnHide'},{d.frame.rmRightClickWatcher,'OnUpdate'}})do
   record.callback=record[1]:GetScript(record[2]);d.stockScripts[#d.stockScripts+1]=record
  end
 end
 local function live()return stockLive(s)and p.stockObservationReport==d and d.stockLease==s end
 d.stockLease=s
 d.Hide=function(control,...)if live()then return d.stockOriginalHide(control,...)end end
 for _,record in ipairs(d.stockScripts)do
  local callback=record.callback
  addon:SetUIScript(record[1],record[2],function(...)if live()and callback then return callback(...)end end)
 end
 s.report=d;d:SetReport(L['Stock shortage list'],text)
 if not stockLive(s)then stockStop(s.p,s);stockClearReport(d,s)end
end
local function stockBind(p,row)
 local s=stockObserve(p);local generation=p.generation
 local status=p:Text('');p.fields.stock_status=status
 local readiness=stockReadinessLabel(p);p.fields.stock_readiness=readiness
 local refs={generation=generation,status=status,readiness=readiness,row=row,copy=p.fields.stock_copy}
 if row then refs.carried=p:Text('');refs.shortage=p:Text('');p.fields.stock_carried=refs.carried;p.fields.stock_shortage=refs.shortage end
 s.refs=refs
 addon:SetUIScript(p.fields.stock_refresh,'OnClick',function()if p:Valid(generation)and stockLive(s)then request(s)end end)
 addon:SetUIScript(p.fields.stock_copy,'OnClick',function()stockCopy(s,generation)end)
 p.cleanups[#p.cleanups+1]=function()if s.refs==refs then s.refs=nil end end
 paint(s)
end

function addon:ItemSettingsSourceOptions(p,options)
 if p.stockProfile~=self.db.profile or p.stockGlobal~=self.db.global or p.stockChar~=self.db.char then
  stockStop(p)
  p.stockProfile,p.stockGlobal,p.stockChar=self.db.profile,self.db.global,self.db.char
  p.itemSettingsSource='itemsets';p.stockSelection=nil;p.newStockTarget=nil
 end
 if p.settingsKey=='ItemSets'and p.stockEditable==true and p.draft and p.draftBaseline and p.draftBaseline.profile
 and addon.StockTargets.Validate(p.draft.profile.stockTargets)and addon.StockTargets.Validate(p.draftBaseline.profile.stockTargets)then
  local keys=p.transactionKeys and p.transactionKeys.profile
  if keys then local found=false;for _,key in ipairs(keys)do if key=='stockTargets'then found=true;break end end;if not found then keys[#keys+1]='stockTargets'end end
 end
 options.sources={{value='itemsets',text=L['Item Sets']},{value='stock',text=L['Stock']}};options.source=p.itemSettingsSource
 local function choose(value)if value~='stock'then stockStop(p)end;p.itemSettingsSource=value;p.creating=false;p.newStockTarget=nil;p.newItemSetName=nil;p:Draw()end
 options.chooseSource=choose
 options.requestSource=function(value)
  if value==p.itemSettingsSource then return end
  if p.creationUsedForNew then p:RequestLeave(function()choose(value)end)
  elseif p:FlushEdits()then choose(value)end
 end
 return options
end
function addon:BuildStockSettings(p)
 local store=p:SettingsData();local raw=rawget(self.db.profile,'stockTargets');local valid,reason=self.StockTargets.Validate(raw)
 local options=self:ItemSettingsSourceOptions(p,{})
 if not valid then
  stockStop(p)
  p:UseRoster({},nil,function()end,options);p:Heading(L['Stock targets']);p:Text(L['Invalid stock targets; data preserved.']);p:Text(reason)
  p:Button('stock_reset',L['Reset targets'],function()
   local profile,global,char=self.db.profile,self.db.global,self.db.char;local expected=rawget(profile,'stockTargets')
   p:RequestLeave(function()
    if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
    p:Confirm(L['Reset invalid stock targets? This cannot be undone.'],function()
     if InCombatLockdown and InCombatLockdown()then p:Message(L['Leave combat before applying these settings.']);return end
     if self.db.profile~=profile or self.db.global~=global or self.db.char~=char or not rawequal(rawget(profile,'stockTargets'),expected) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
     profile.stockTargets=nil;p:DiscardSettingsDraft();p:Draw()
    end)
   end)
  end)
  return
 end
 local plan=store.profile.stockTargets or {};local entries={}
 for id,row in pairs(plan)do entries[#entries+1]={value=id,text=string.format('%.0f',row.itemID),icon='Interface\\Icons\\INV_Misc_QuestionMark'}end
 table.sort(entries,function(a,b)return plan[a.value].itemID<plan[b.value].itemID end)
 if not plan[p.stockSelection]and not p.creating then p.stockSelection=entries[1]and entries[1].value end
 local function create()p.previousStockSelection=p.stockSelection;p.stockSelection=nil;p.creating=true;p.newStockTarget={minimum=0,target=0,enabled=true};p:Draw()end
 options.new=create;options.newText=L['Add stock target']
 p:UseRoster(entries,p.stockSelection,function(id)p.stockSelection=id;p.creating=false;p.newStockTarget=nil;p:Draw()end,options)
 p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',enabled=#entries<128,action=create},{key='stock_refresh',text=L['Refresh'],icon='refresh',action=function()end},{key='stock_copy',text=L['Copy shortage list'],icon='copy',action=function()end}})
 p:Heading(L['Stock targets']);p:HistoryActions()
 local row=p.creating and p.newStockTarget or plan[p.stockSelection]
 stockBind(p,row)
 if not row then p:Text(L['No stock targets.']);return end
 local id=p.stockSelection
 local function accepted(value)
  if not integer(value)or value<=0 then return false end
  for key,other in pairs(plan)do if key~=id and other.itemID==value then return false end end
  return true
 end
 local itemLabel
 local function itemText()return row.itemID and string.format(L['Item ID: %s'],string.format('%.0f',row.itemID))or L['Choose an item first.']end
 p:Reference('itemID',L['Item'],row.itemID,'Item_EditBox',{accept=accepted},function(value)row.itemID=value;if itemLabel then itemLabel:SetText(itemText())end;if id then p:UpdateRosterEntry(id,{text=string.format('%.0f',value)})end end)
 itemLabel=p:Text(itemText());p.fields.stock_item_id=itemLabel
 p:Check('enabled',L['Enabled'],row.enabled,function(value)row.enabled=value end)
 local function parseMinimum(text)local n=quantity(text);local other=p.fields.target and quantity(p.fields.target:GetText())or row.target;if n and other and n<=other then return n end end
 local function parseTarget(text)local n=quantity(text);local other=p.fields.minimum and quantity(p.fields.minimum:GetText())or row.minimum;if n and other and other<=n then return n end end
 p:Edit('minimum',L['Minimum'],row.minimum,parseMinimum,function(value)row.minimum=value end)
 p:Edit('target',L['Target'],row.target,parseTarget,function(value)row.target=value end)
 if p.creating then
  p:CreationActions(function()
   if #entries>=128 or not accepted(row.itemID)or not self.StockTargets.Validate({candidate=row})then p:Message(L['Complete the highlighted input fields before applying.']);return end
   local new=self:uuid();if plan[new]then p:Message(L['This name is already in use.']);return end
   store.profile.stockTargets=plan;plan[new]=row;p.stockSelection=new;p.creating=false;p.newStockTarget=nil;p:Draw()
  end,function()p.creating=false;p.newStockTarget=nil;p.stockSelection=p.previousStockSelection;p:Draw()end)
 else
  self:SettingsTopDelete(p,function()if p:FlushEdits()then plan[id]=nil;p.stockSelection=nil;p:Draw()end end)
 end
end
