-- Explicit, volatile TBC player-event receipts. No advice or ordinary-cast proof.
local _,addon=...
local type,next,rawget,rawequal,getmetatable,pcall,error=type,next,rawget,rawequal,getmetatable,pcall,error
local huge=math.huge
local analytics=addon.Analytics or{}
addon.Analytics=analytics
local newCapture=analytics.NewCapture
local platform=addon.Platform
local service={}
analytics.NativeCasts=service
local active,last,frame,methods,unusable,cleaning
local generation,retiring,resourceCalls=0,0,0
local phase,reason='idle',nil
-- BEGIN ANALYTICS PREVIEW HANDOFF
-- Two fixed source producers, consumed during normal TOC startup. No listeners.
local installAdvice,installPreview,armed
function addon:BindAnalyticsAdviceCapture(install)
 if not rawequal(self,addon)or installAdvice or type(install)~='function'then return false end
 installAdvice=install;addon.BindAnalyticsAdviceCapture=nil;return true
end
function addon:BindAnalyticsPreviewCapture(install)
 if not rawequal(self,addon)or installPreview or type(install)~='function'then return false end
 installPreview=install;addon.BindAnalyticsPreviewCapture=nil;return true
end
local function disarm(s)
 if armed~=s then return end
 armed=nil
 if installAdvice then installAdvice(nil)end
 if installPreview then installPreview(nil)end
 s.advice=nil
end
-- END ANALYTICS PREVIEW HANDOFF
local castEvents={
 UNIT_SPELLCAST_SENT=true,UNIT_SPELLCAST_START=true,UNIT_SPELLCAST_STOP=true,
 UNIT_SPELLCAST_SUCCEEDED=true,UNIT_SPELLCAST_FAILED=true,UNIT_SPELLCAST_INTERRUPTED=true,
 UNIT_SPELLCAST_CHANNEL_START=true,UNIT_SPELLCAST_CHANNEL_STOP=true,
}
local events={'UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP','PLAYER_ENTERING_WORLD','PLAYER_CONTROL_LOST'}
local reasons={stop=true,context=true,disabled=true,error=true,['end']=true,unknown=true}
local fault={}
local function fail(why)error({owner=fault,reason=why},0)end
local function issue(value)
 if type(value)=='table'and rawequal(rawget(value,'owner'),fault)then return rawget(value,'reason')end
 return'native-error'
end
local function finite(v)return type(v)=='number'and v==v and v~=huge and v~=-huge end
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in next,v do out[k]=copy(x)end;return out end
local function current(s)return generation==s.generation end
local function fence(s)if not current(s)then fail('retired-operation')end end
local function call(s,fn,...)
 local before=s.phase
 local ok,value=pcall(fn,...);fence(s);if before~=s.phase then fail('retired-operation')end;if not ok then fail('native-error')end;return value
end
-- A Clear inside an in-flight setter/registration cannot hand its frame to a
-- new Start before that call returns and its retired startup tail releases it.
local function resourceCall(s,fn,...)
 resourceCalls=resourceCalls+1
 local ok,value=pcall(call,s,fn,...)
 resourceCalls=resourceCalls-1
 if not ok then error(value,0)end
 return value
end
local function read(s,value)
 local ok=call(s,s.read,platform,value);if ok~=true then fail('unreadable-value')end;return value
end
local function clock(s)
 local now=read(s,call(s,s.clock));if not finite(now)then fail('invalid-time')end
 if s.started~=nil then local elapsed=now-s.started;if elapsed<0 or elapsed>600 or elapsed<s.elapsed then fail('invalid-time')end;s.elapsed=elapsed end
 return now
end
local function wrapper(s,status,why,capture)
 return{format=1,producer='UNIT_SPELLCAST-adapter',status=status,reason=why,
  client=copy(s.client or{}),tupleContract='wow-ui-source:2cfec7c00f0f24762d5ca35a4beb1e93c0cde328:UnitDocumentation',
  nativeAcceptance='unverified',runtimeVerified=false,advice=s.adviceProducer and'primary-publisher-receipts'or'not-wired',presentation=s.previewProducer and'owned-native-preview-boundaries'or'not-wired',ordinary='unavailable',autorepeat='unassociated',damage='unavailable',capture=capture}
end
-- Only this frame's original methods and this operation's exact script may be
-- removed. Failed release makes the singleton unusable rather than leaking frames.
local function cleanup(s)
 if cleaning then return false end
 cleaning=true
 local good=not s.timerAmbiguous
 local function invoke(fn,...)
  if type(fn)~='function'then good=false;return nil end
  local ok,v=pcall(fn,...);if not ok then good=false;return nil end;return v
 end
 if s.timer~=nil then
  if invoke(s.cancel,addon,s.timer)~=true then good=false end;s.timer=nil
 end
 local ownedFrame,ownedMethods=s.frame,s.methods
 if ownedFrame and ownedMethods then
  local frame,methods=ownedFrame,ownedMethods
  local safe=true
  for name,fn in next,methods do
   local ok,v=pcall(function()return frame[name]end)
   if not ok or not rawequal(v,fn)then good=false;safe=false end
  end
  if safe then
   local script=invoke(methods.GetScript,frame,'OnEvent')
   if rawequal(script,s.handler)then invoke(methods.SetScript,frame,'OnEvent',nil)
   elseif script~=nil then good=false end
   for _,event in ipairs(events)do
    local registered=invoke(methods.IsEventRegistered,frame,event)
    if registered then invoke(methods.UnregisterEvent,frame,event)end
   end
   local remaining=invoke(methods.GetScript,frame,'OnEvent')
   if remaining~=nil then good=false end
   for _,event in ipairs(events)do if invoke(methods.IsEventRegistered,frame,event)then good=false end end
  end
 end
 if not good then unusable=true end
 cleaning=false
 return good
end
local function settle()
 if not active and not cleaning and retiring==0 then phase=unusable and'unusable'or'idle'end
end
local function retire(s)
 -- BEGIN ANALYTICS PREVIEW RETIRE
 disarm(s)
 -- END ANALYTICS PREVIEW RETIRE
 s.phase='stopping'
 if rawequal(active,s)then active=nil end
 phase='stopping'
end
local function abort(s,why)
 retiring=retiring+1;retire(s)
 local ok=cleanup(s)
 if s.builder then s.builder:Clear()end
 if current(s)then
  last=wrapper(s,'unavailable',ok and why or'cleanup-failed');phase=unusable and'unusable'or'idle';reason=last.reason
 end
 retiring=retiring-1;settle()
end
local function field(s,object,key)
 read(s,object)
 local value=call(s,function()return object[key]end)
 return read(s,value)
end
local function clientInfo(s)
 local info=read(s,call(s,s.clientReader,platform))
 if type(info)~='table'then fail('unsupported-client')end
 local family=field(s,info,'family');local policy=field(s,info,'combatDataPolicy')
 if family~='tbc'or policy~='probe'then fail('unsupported-client')end
 local out={family='tbc'}
 for _,name in ipairs({'build','interface','version','locale'})do
  local v=field(s,info,name)
  if v~=nil then
   if type(v)=='string'and#v<=64 then out[name]=v
   elseif finite(v)and v>=0 and v<=2147483647 then out[name]=v
   else fail('invalid-client-info')end
  end
 end
 s.client=out
end
local function loadDependencies(s)
 if type(platform)~='table'or type(newCapture)~='function'then fail('missing-dependency')end
 local ok=pcall(function()
  s.read=platform.CanReadValue;s.clientReader=platform.GetClientInfo
  s.clock=GetTime;s.create=CreateFrame;s.schedule=addon.ScheduleTimer;s.cancel=addon.CancelTimer
 end)
 fence(s);if not ok then fail('missing-dependency')end
 for _,fn in ipairs({s.read,s.clientReader,s.clock,s.create,s.schedule,s.cancel})do if type(fn)~='function'then fail('missing-dependency')end end
 -- ipairs cannot detect a nil dependency in the middle.
 if type(s.read)~='function'or type(s.clientReader)~='function'or type(s.clock)~='function'or type(s.create)~='function'or type(s.schedule)~='function'or type(s.cancel)~='function'then fail('missing-dependency')end
end
local function stop(s,why)
 retiring=retiring+1;retire(s)
 local ok,value=pcall(function()clock(s);return s.builder:Stop(s.builderLease,s.elapsed,why)end)
 local release=cleanup(s)
 if not current(s)then retiring=retiring-1;settle();return nil,'retired-operation'end
 if not ok then last=wrapper(s,'unavailable',issue(value));s.builder:Clear()
 elseif not release then last=wrapper(s,'unavailable','cleanup-failed');s.builder:Clear()
 elseif type(value)~='table'or value.status~='complete'then last=wrapper(s,'unavailable',type(value)=='table'and value.reason or'builder-error')
 else last=wrapper(s,'complete',why,value)end
 phase=unusable and'unusable'or'idle';reason=last.reason
 retiring=retiring-1;settle();return copy(last)
end
-- BEGIN ANALYTICS PREVIEW RECEIPTS
local function pushEvidence(s,row)
 local seq,why=s.builder:Push(s.builderLease,s.elapsed,row);fence(s)
 if active~=s or s.phase~='running'then fail('retired-operation')end
 if not seq then fail(why or'builder-error')end
 return seq
end
local function retireEvidence(s)
 local a=s.advice
 clock(s)
 if not rawequal(s.advice,a)then return end
 s.advice=nil;s.epoch=(s.epoch or 1)+1
 pushEvidence(s,{type='retire',reason='context'})
end
local function checkAdvice(s)
 local a=s.advice
 if not a then return end
 local valid=call(s,a.current)
 if not rawequal(s.advice,a)then return end
 if valid~=true then retireEvidence(s);return end
 if a.visible then
  local visible=call(s,a.visible)
  if not rawequal(s.advice,a)then return end
  if visible~='visible'then retireEvidence(s)end
 end
end
local function producer(s,event,window,witness,kind,spell)
 if active~=s or s.phase~='running'then return end
 local ok,why=pcall(function()
  if event=='retire'then
   if s.advice and(window==nil or rawequal(window,s.advice.window))then retireEvidence(s)end
  elseif event=='advice'then
   if type(witness)~='function'or call(s,witness)~=true then return end
   clock(s);if call(s,witness)~=true then return end
   local action=kind=='spell'and'spell'or'unmodeled'
   if action=='spell'and(not finite(spell)or spell<=0 or spell%1~=0)then fail('invalid-receipt')end
   local row={type='advice',epoch=s.epoch or 1,action=action};if action=='spell'then row.spell=spell end
   local seq=pushEvidence(s,row)
   s.advice={seq=seq,spell=spell,window=window,current=witness,action=action}
  elseif event=='delivery'then
   local a=s.advice
   if not a or a.action~='spell'or not rawequal(a.window,window)or a.spell~=spell or a.ack then return end
   local valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   local state=call(s,witness)
   if not rawequal(s.advice,a)then return end
   if state=='retired'then retireEvidence(s);return end
   if state~='visible'and state~='hidden'then state='unknown'end
   clock(s)
   if not rawequal(s.advice,a)then return end
   valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   -- Visibility callbacks may themselves retire a window or start a new poll.
   local repeated=call(s,witness)
   if not rawequal(s.advice,a)then return end
   if repeated=='retired'then retireEvidence(s);return end
   if repeated~=state then state='unknown'end
   valid=call(s,a.current)
   if not rawequal(s.advice,a)then return end
   if valid~=true then retireEvidence(s);return end
   pushEvidence(s,{type='presentation',adviceSeq=a.seq,state=state})
   a.ack=true;if state=='visible'then a.visible=witness end
  end
 end)
 if not ok and current(s)and active==s then abort(s,issue(why))end
end
local function arm(s)
 if not installAdvice then return end
 armed=s;s.previewProducer=installPreview~=nil;s.adviceProducer=true
 local sink=function(...)producer(s,...)end
 installAdvice(sink);if installPreview then installPreview(sink)end
end
-- END ANALYTICS PREVIEW RECEIPTS
local function receipt(s,event,unit,key,spell)
 -- The lease check is before native readability or any payload operation.
 if not rawequal(active,s)or s.phase~='running'then return end
 local ok,why=pcall(function()
  read(s,unit);if unit~='player'then return end
  read(s,key);read(s,spell)
  if key~=nil and(type(key)~='string'or#key<1 or#key>128)then fail('invalid-payload')end
  if spell==nil then spell=0 end
  if not finite(spell)or spell<0 or spell>2147483647 or spell%1~=0 then fail('invalid-payload')end
  clock(s)
  -- BEGIN ANALYTICS PREVIEW ATTEMPT
  checkAdvice(s)
  -- END ANALYTICS PREVIEW ATTEMPT
  local r={key=key,actor='player',spell=spell,castKind='unmodeled'}
  if event=='UNIT_SPELLCAST_SENT'or event=='UNIT_SPELLCAST_START'or event=='UNIT_SPELLCAST_CHANNEL_START'then
   r.type='attempt';r.epoch=s.epoch or 1;r.phase=event=='UNIT_SPELLCAST_SENT'and'sent'or'start'
  else
   r.type='result'
   if event=='UNIT_SPELLCAST_SUCCEEDED'then r.status='success'
   elseif event=='UNIT_SPELLCAST_FAILED'then r.status='failed'
   elseif event=='UNIT_SPELLCAST_INTERRUPTED'then r.status='interrupted'
   else r.status='stop'end
  end
  if event=='UNIT_SPELLCAST_CHANNEL_START'or event=='UNIT_SPELLCAST_CHANNEL_STOP'then r.castKind='channel'end
  local n,problem=s.builder:Push(s.builderLease,s.elapsed,r);fence(s);if not n then fail(problem or'builder-error')end
 end)
 if not ok and current(s)and rawequal(active,s)then abort(s,issue(why))end
end
function service:Start(options)
 if not rawequal(self,service)then return nil,'foreign-receiver'end
 if active or cleaning or retiring>0 or resourceCalls>0 or phase=='stopping'then return nil,'busy'end
 if unusable then return nil,'unusable'end
 if options~=nil then
  if type(options)~='table'or getmetatable(options)~=nil then return nil,'invalid-options'end
  for k in next,options do if k~='duration'then return nil,'invalid-options'end end
 end
 local duration=options and rawget(options,'duration');if duration==nil then duration=30 end
 if not finite(duration)or duration<=0 or duration>600 then return nil,'invalid-options'end
 generation=generation+1
 local s={generation=generation,lease={},phase='starting',elapsed=0};active=s;phase='starting'
 local ok,why=pcall(function()
  loadDependencies(s);clientInfo(s);s.started=clock(s)
  s.builder=assert(newCapture());s.builderLease=assert(s.builder:Start({family='tbc',actor='player',ordinaryEvidence='unavailable',presentationEvidence=installAdvice and installPreview and'trusted-receipt'or'unavailable'}));fence(s)
  s.handler=function(_,event,unit,a,b,c)
   if not rawequal(active,s)or s.phase~='running'then return end
   local readable,problem=pcall(function()read(s,event);if type(event)~='string'then fail('invalid-payload')end end)
   if not readable then if current(s)and rawequal(active,s)then abort(s,issue(problem))end;return end
   if event=='PLAYER_ENTERING_WORLD'or event=='PLAYER_CONTROL_LOST'then stop(s,'context');return end
   if not rawget(castEvents,event)then return end
   if event=='UNIT_SPELLCAST_SENT'then receipt(s,event,unit,b,c)else receipt(s,event,unit,a,b)end
  end
  s.frame,s.methods=frame,methods
  if not frame then
   local created
   resourceCalls=resourceCalls+1
   local success,value=pcall(s.create,'Frame');created=value
   resourceCalls=resourceCalls-1
   if not success then unusable=true end
   if success and(type(created)=='table'or type(created)=='userdata')then frame=created;s.frame=created end
   if not current(s)and frame then unusable=true end
   fence(s);if not success or not frame then fail('native-error')end
   methods={};s.methods=methods
   for _,name in ipairs({'GetScript','SetScript','IsEventRegistered','RegisterEvent','UnregisterEvent','RegisterUnitEvent'})do
    local method=resourceCall(s,function()return frame[name]end)
    if name~='RegisterUnitEvent'or method~=nil then
     if type(method)~='function'then fail('missing-frame-method')end;methods[name]=method
    end
   end
  end
  for name,fn in next,methods do if not rawequal(resourceCall(s,function()return frame[name]end),fn)then fail('foreign-frame-method')end end
  if resourceCall(s,methods.GetScript,frame,'OnEvent')~=nil then fail('foreign-frame-handler')end
  for _,event in ipairs(events)do if resourceCall(s,methods.IsEventRegistered,frame,event)then fail('foreign-registration')end end
  resourceCall(s,methods.SetScript,frame,'OnEvent',s.handler)
  for _,event in ipairs(events)do
   if rawget(castEvents,event)and methods.RegisterUnitEvent then resourceCall(s,methods.RegisterUnitEvent,frame,event,'player')else resourceCall(s,methods.RegisterEvent,frame,event)end
   if not resourceCall(s,methods.IsEventRegistered,frame,event)then fail('registration-failed')end
  end
  if not rawequal(resourceCall(s,methods.GetScript,frame,'OnEvent'),s.handler)then fail('foreign-frame-handler')end
  resourceCalls=resourceCalls+1
  local success,handle=pcall(s.schedule,addon,function()
   if not rawequal(active,s)then return end
   s.timer=nil
   if s.phase~='running'then abort(s,'timer-before-commit')else stop(s,'end')end
  end,duration)
  resourceCalls=resourceCalls-1
  if success and handle~=nil then s.timer=handle else s.timerAmbiguous=true end
  fence(s);if not success or handle==nil then fail('timer-failed')end
  if not rawequal(active,s)or s.phase~='starting'then fail('timer-before-commit')end
  s.phase='running';phase='running';reason=nil;last=nil
  -- BEGIN ANALYTICS PREVIEW ARM
  arm(s)
  -- END ANALYTICS PREVIEW ARM
 end)
 if not ok then
  if current(s)then abort(s,issue(why))else cleanup(s);if s.builder then s.builder:Clear()end end
  settle()
  return nil,current(s)and(reason or issue(why))or'retired-operation'
 end
 return s.lease
end
function service:Stop(lease,why)
 if not rawequal(self,service)then return nil,'foreign-receiver'end
 if not active or not rawequal(lease,active.lease)then return nil,'retired-lease'end
 if active.phase~='running'then return nil,'busy'end
 if why==nil then why='stop'end
 if type(why)~='string'or not rawget(reasons,why)then return nil,'invalid-reason'end
 return stop(active,why)
end
function service:Clear()
 if not rawequal(self,service)then return nil,'foreign-receiver'end
 generation=generation+1
 local s=active;active=nil;last=nil;reason=nil
 -- BEGIN ANALYTICS PREVIEW CLEAR
 if s then disarm(s)end
 -- END ANALYTICS PREVIEW CLEAR
 if s then
  retiring=retiring+1;phase='stopping';cleanup(s);if s.builder then s.builder:Clear()end;retiring=retiring-1
 end
 settle()
 return true
end
function service:GetStatus()
 if not rawequal(self,service)then return nil,'foreign-receiver'end
 return{phase=phase,reason=reason,nativeAcceptance='unverified',runtimeVerified=false,advice='not-wired',presentation='not-wired',ordinary='unavailable',autorepeat='unassociated',damage='unavailable'}
end
function service:GetSnapshot()
 if not rawequal(self,service)then return nil,'foreign-receiver'end
 if active then return nil,'running'end
 if not last then return nil,'no-session'end
 return copy(last)
end
