-- Volatile cast-receipt diagnostics, independently of editable settings drafts.
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local type,rawget,rawequal,pcall=type,rawget,rawequal,pcall
local service=addon.Analytics and addon.Analytics.NativeCasts
local methods={}
for _,name in ipairs({'Start','Stop','Clear','GetStatus','GetSnapshot'})do methods[name]=service and service[name]end
local generation,lease,busy=0,nil,false
local function owned()
 if not service or not addon.Analytics or not rawequal(addon.Analytics.NativeCasts,service)then return false end
 for name,fn in pairs(methods)do if type(fn)~='function'or not rawequal(service[name],fn)then return false end end
 return true
end
local function available()return L['Cast capture is unavailable.']end
local function invoke(name,...)
 local ok,value=pcall(methods[name],service,...)
 if not ok then return nil end
 return value
end
local function phase()
 if not owned()then return nil end
 local status=invoke('GetStatus')
 return type(status)=='table'and rawget(status,'phase')or nil
end
function addon:GetCastCaptureStatusText()
 if not rawequal(self,addon)then return available()end
 local p=phase()
 if p=='running'or p=='starting'then return L['Cast capture status: running']end
 if p=='idle'then return L['Cast capture status: idle']end
 return available()
end
local function retire()
 generation=generation+1;lease=nil;busy=nil
 -- Clear is the strict inverse for a pending Start too. Never invoke a
 -- replacement service or replacement method during addon shutdown.
 if service and type(methods.Clear)=='function'and rawequal(service.Clear,methods.Clear)then return invoke('Clear')==true end
 return false
end
function addon:ClearCastCaptureForDisable()
 if not rawequal(self,addon)then return false end
 return retire()
end
local function number(v)
 if type(v)=='number'and v==v and v~=math.huge and v~=-math.huge then return tostring(v)end
 return '?'
end
local function metadata(v)
 if type(v)=='number'then return number(v)end
 if type(v)~='string'then return L['unavailable']end
 return(v:sub(1,64):gsub('[%c]',' '):gsub('|','||'))
end
local function token(value,allowed)
 return type(value)=='string'and allowed[value]and value or'unknown'
end
local kinds={ordinary=true,channel=true,autorepeat=true,unmodeled=true}
local actors={player=true,pet=true,other=true,unknown=true}
local signals={sent=true,start=true,success=true,failed=true,interrupted=true,stop=true}
local function report(snapshot)
 local client=type(snapshot.client)=='table'and snapshot.client or{}
 local lines={L['Rotation Master cast receipt diagnostics'],
  L['Producer: UNIT_SPELLCAST adapter'],
  L['Native acceptance: unverified'],
  L['Advice: not available; presentation: not available; ordinary-cast proof: not available.'],
  L['Scoring: unavailable'],
  string.format(L['Client: family=%s version=%s build=%s interface=%s locale=%s'],metadata(client.family),metadata(client.version),metadata(client.build),metadata(client.interface),metadata(client.locale))}
 if snapshot.status~='complete'then lines[#lines+1]=L['Capture: unavailable'];return table.concat(lines,'\n')end
 local trace=snapshot.capture and snapshot.capture.trace
 if type(trace)~='table'or type(trace.records)~='table'then lines[#lines+1]=L['Capture: unavailable'];return table.concat(lines,'\n')end
 local rows=trace.records
 lines[#lines+1]=string.format(L['Duration: %s seconds'],number(trace.duration))
 lines[#lines+1]=string.format(L['Records: %d'],#rows)
 local attempts,results=0,0
 for _,row in ipairs(rows)do if row.type=='attempt'then attempts=attempts+1 elseif row.type=='result'then results=results+1 end end
 lines[#lines+1]=string.format(L['Attempts: %d; results: %d'],attempts,results)
 for i=1,math.min(#rows,200)do
  local row=rows[i]
  local kind=token(row.type,{attempt=true,result=true})
  lines[#lines+1]=string.format('seq=%s time=%s %s actor=%s cast=%s spell=%s kind=%s signal=%s',number(row.seq),number(row.time),kind,token(row.actor,actors),number(row.cast),number(row.spell),token(row.castKind,kinds),token(row.phase or row.status,signals))
 end
 if #rows>200 then lines[#lines+1]=string.format(L['Rows omitted: %d'],#rows-200)end
 return table.concat(lines,'\n')
end
function addon:RunCastCaptureAction(action)
 if not rawequal(self,addon)then return false,available()end
 if action=='clear'then
  if not owned()then return false,available()end
  return retire(),L['Cast capture cleared.']
 end
 if action~='start'and action~='stop'and action~='report'then return false,available()end
 if busy or not owned()then return false,available()end
 local operation={}
 busy=operation
 local ticket=generation
 local ok,message=false,available()
 if action=='start'then
  local value=invoke('Start',{duration=30})
  if ticket==generation and owned()and value then lease=value;ok=true;message=L['Cast capture started for 30 seconds. Configuration can be closed during capture.']end
 elseif action=='stop'then
  if lease then
   local value=invoke('Stop',lease,'stop')
   if ticket==generation and owned()and value then lease=nil;ok=true;message=L['Cast capture stopped. Open Cast report to inspect receipts.']end
  else message=L['No cast capture is running.']end
 else
  local status=phase()
  if status=='running'or status=='starting'then message=L['Cast capture is running. Stop it or wait before opening Cast report.']
  else
   local value=invoke('GetSnapshot')
   if ticket==generation and owned()and type(value)=='table'and type(self.ShowConditionText)=='function'then
    local text=report(value)
    if ticket==generation and owned()then local shown=pcall(self.ShowConditionText,self,text,L['Cast receipt report']);ok=shown;message=shown and ''or available()end
   else message=L['No cast capture report is available. Start a capture first.']end
  end
 end
 if rawequal(busy,operation)then busy=nil end
 if ticket~=generation then return false,'',false end
 return ok,message,true
end
