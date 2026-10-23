local addon_name,addon=...
-- Explicit native measurements of normal outer evaluator dispatches. This
-- module never starts evaluation, resets counters, or installs a lasting hook.
local active,lastReport
local LIMIT,SAFE=512,9007199254740991
local function tuple(...)return {n=select('#',...),...}end
local function readable(value)
 local secret=rawget(_G,'issecretvalue');if type(secret)=='function'then local ok,v=pcall(secret,value);if not ok or v~=false then return false end end
 local access=rawget(_G,'canaccessvalue');if type(access)=='function'then local ok,v=pcall(access,value);if not ok or v~=true then return false end end
 return true
end
local function finite(v)return readable(v)and type(v)=='number'and v==v and v~=math.huge and v~=-math.huge end
local function field(t,k)if readable(t)and type(t)=='table'then return rawget(t,k)end end
local function bytes(v)
 if not readable(v)then return end
 if type(v)=='string'then
  if #v==0 or #v>16 or not v:match('^%d+$')then return end
  v=tonumber(v)
 end
 if finite(v)and v>=0 and v<=SAFE and v%1==0 then return v end
end
local function now(run)local ok,v=pcall(run.clock);if ok and finite(v)then return v end end
local function providerCurrent(run)
 return rawequal(rawget(_G,'C_AddOnProfiler'),run.provider)
  and rawequal(rawget(run.provider,'IsEnabled'),run.enabled)
  and rawequal(rawget(run.provider,'MeasureCall'),run.measure)
end
local function current(run)return active==run and run.phase=='running' and rawequal(rawget(addon,'EvaluateNextAction'),run.wrapper)end
-- Consumed once by Main; the sink receives fixed scalar enums only.
local decisionSetter,decisionBound,decisionOwner
function addon:BindCPURuntimeDecisionCounts(setter)
 if self~=addon or decisionBound or type(setter)~='function'then return end
 decisionBound=true;decisionSetter=setter;return true
end
local function decisionPrepare(run)
 run.decisionComplete=0;run.decisionAvailable=type(decisionSetter)=='function'
 run.decisionFields={'attempted','matched','notMatchedOrUnavailable','skippedDisabled','skippedNoAction','mapped','unmapped','ready','notReady'}
 run.decisionIndex={attempt=1,matched=2,notmatched=3,disabled=4,noaction=5,mapped=6,unmapped=7,ready=8,notready=9}
 run.decisionTotals={{0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0}}
 run.decisionScratch={{0,0,0,0,0,0,0,0,0},{0,0,0,0,0,0,0,0,0}}
 run.decisionSink=function(scope,event)
  if not current(run)or not run.callbackInside or not run.decisionSampleOK then return end
  local row=scope=='rotation'and 1 or scope=='cooldowns'and 2
  local index=run.decisionIndex[event];local scratch=run.decisionScratch
  if row and index and scratch then scratch[row][index]=scratch[row][index]+1 end
 end
end
local function decisionInstall(run)
 if run.decisionAvailable then decisionOwner=run;decisionSetter(run.decisionSink)end
end
local function decisionRestore(run)
 if decisionOwner==run then decisionOwner=nil;decisionSetter(nil)end
end
local function decisionAccumulate(run)
 if not run.decisionSampleOK or not run.decisionScratch or decisionOwner~=run then return end
 run.decisionComplete=run.decisionComplete+1
 for row=1,2 do for index=1,9 do run.decisionTotals[row][index]=run.decisionTotals[row][index]+run.decisionScratch[row][index]end end
end
local function decisionReport(lines,run)
 lines[#lines+1]='Decisions: complete='..(run.decisionComplete or 0)..'; unavailable='..(run.measured-(run.decisionComplete or 0))
 lines[#lines+1]='Counts are reached action decisions, not unique configured rows or all rotation clauses; unreached/short-circuited conditions are not counted false. Cooldowns count reached configured rows.'
 lines[#lines+1]='Condition false combines not matched or unavailable. Mapping is the FindSpell cached button index, not visibility, glow or animation; one row can perform multiple mapping/readiness attempts.'
 if (run.decisionComplete or 0)>0 then for row=1,2 do
  local parts={};for index,name in ipairs(run.decisionFields)do parts[#parts+1]=name..'='..run.decisionTotals[row][index]end
  lines[#lines+1]=(row==1 and 'rotation' or 'cooldowns')..' decisions | '..table.concat(parts,'; ')
 end end
end
-- Capture-only markers at the existing six profiler child lookups. The real
-- child objects/methods are always returned and invoked by the original code.
local childNames={'environment','environment','rotation','rotation','cooldowns','cooldowns'}
local eventNames={'RM:environment:start','RM:environment:stop','RM:rotation:start','RM:rotation:stop','RM:cooldowns:start','RM:cooldowns:stop'}
local phaseNames={'selection+macro','environment','history+setup','rotation','transition','cooldowns','publication+tail'}
local function phaseCurrent(run)
 return run.phaseRoot and rawequal(rawget(addon,'evaluationProfile'),run.phaseRoot)
  and rawequal(rawget(run.phaseRoot,'child'),run.childWrapper)
  and rawequal(rawget(run.provider,'AddMeasuredCallEvent'),run.marker)
end
local function phasePrepare(run)
 decisionPrepare(run)
 run.phaseComplete=0;run.phaseRows={}
 for i=1,7 do run.phaseRows[i]={time=0,allocated=0,deallocated=0}end
 local root=field(addon,'evaluationProfile');local child=field(root,'child');local marker=field(run.provider,'AddMeasuredCallEvent')
 if type(root)~='table'or type(child)~='function'or type(marker)~='function'then return end
 run.phaseRoot,run.childOriginal,run.marker=root,child,marker
 run.childWrapper=function(self,...)
  local name=(...)
  if rawequal(self,root)and run.callbackInside and current(run)then
   run.phasePosition=run.phasePosition+1
   if not run.samplePhaseOK or not phaseCurrent(run)or childNames[run.phasePosition]~=name then run.samplePhaseOK=false
   else
    local ok=pcall(marker,eventNames[run.phasePosition])
    if not ok or not current(run)or not phaseCurrent(run)then run.samplePhaseOK=false end
   end
  end
  return child(self,...)
 end
end
local function phaseInstall(run)
 if run.phaseRoot and rawequal(rawget(addon,'evaluationProfile'),run.phaseRoot)
  and rawequal(rawget(run.phaseRoot,'child'),run.childOriginal)
  and rawequal(rawget(run.provider,'AddMeasuredCallEvent'),run.marker)then
  rawset(run.phaseRoot,'child',run.childWrapper)
 end
end
local function phaseRestore(run)
 if run.phaseRoot and rawequal(rawget(run.phaseRoot,'child'),run.childWrapper)then rawset(run.phaseRoot,'child',run.childOriginal)end
end
local function invalidSnapshotCounter(value)
 return readable(value)and type(value)=='number'and(not finite(value)or value<0 or value%1~=0)
end
local function phaseAccumulate(run,metrics,elapsed,allocated,deallocated)
 if not run.samplePhaseOK or run.phasePosition~=6 or not phaseCurrent(run)then return end
 local events=field(metrics,'events');if not readable(events)or type(events)~='table'or #events~=6 then return end
 local times,allocations,deallocations={0},{0},{0};local allocOK,freeOK=allocated~=nil,deallocated~=nil
 for i=1,6 do
  local event=field(events,i);local name=field(event,'name');if not readable(name)or name~=eventNames[i]then return end
  local t=field(event,'elapsedMilliseconds');if not finite(t)or t<times[i]or t>elapsed then return end;times[i+1]=t
  local rawA,rawD=field(event,'allocatedBytes'),field(event,'deallocatedBytes')
  if invalidSnapshotCounter(rawA)or invalidSnapshotCounter(rawD)then return end
  local a,d=bytes(rawA),bytes(rawD)
  if a==nil then allocOK=false elseif allocOK and(a<allocations[i]or a>allocated)then return end
  if d==nil then freeOK=false elseif freeOK and(d<deallocations[i]or d>deallocated)then return end
  allocations[i+1],deallocations[i+1]=a,d
 end
 times[8],allocations[8],deallocations[8]=elapsed,allocated,deallocated
 if not current(run)or not phaseCurrent(run)then return end
 run.phaseComplete=run.phaseComplete+1
 for i,row in ipairs(run.phaseRows)do
  row.time=row.time+(times[i+1]-times[i])
  if row.allocated~=nil then row.allocated=allocOK and row.allocated+(allocations[i+1]-allocations[i])or nil;if row.allocated and row.allocated>SAFE then row.allocated=nil end end
  if row.deallocated~=nil then row.deallocated=freeOK and row.deallocated+(deallocations[i+1]-deallocations[i])or nil;if row.deallocated and row.deallocated>SAFE then row.deallocated=nil end end
 end
end
local function poll()
 local value=field(field(rawget(addon,'db'),'profile'),'poll')
 return finite(value)and tostring(value)or 'unavailable'
end
-- Timer ticks the idle gate let through or skipped; skipped ticks never reach
-- EvaluateNextAction, so they are not dispatches in this capture.
local function idleGate()
 local gate=rawget(addon,'idleGate');local value=field(field(rawget(addon,'db'),'profile'),'idle_poll')
 return {interval=finite(value)and tostring(value)or 'unavailable',evaluated=type(gate)=='table'and gate.evaluated or nil,skipped=type(gate)=='table'and gate.skipped or nil}
end
-- Boundary-only routing label. No IDs, names, providers or private bodies leave
-- here, and report reads/normal evaluator dispatches never re-observe selection.
local selectionSub=string.sub
local function selectedKey()
 local value=rawget(addon,'currentRotation')
 if not readable(value)or not rawequal(rawget(addon,'currentRotation'),value)then return 'unavailable'end
 if value==nil then return 'none'end
 if type(value)~='string'then return 'unavailable'end
 local ok,prefix=pcall(selectionSub,value,1,13)
 if not ok then return 'unavailable'end
 return prefix=='\1rm:rotation:'and 'scoped'or 'raw'
end
-- Snapshot only at explicit capture boundaries, outside measured dispatches.
-- Copy scalar fields immediately: providers cannot mutate a retained snapshot.
local diagnosticSpecs={
 {method='GetActiveRuntimePlanDiagnostic',label='Active runtime plan',state='currentRoute',fields={'plansBuilt','reused','declined'}},
 {method='GetConditionRuntimeDiagnostic',label='Condition runtime',state='active',fields={'compiles','legacyFallback','leafEvaluations','validatorCalls','stableHits','eventInvalidations'}},
}
local diagnosticRoutes={idle=true,managed=true,unavailable=true,fallback=true,retired=true}
local function observationMode(provider)
 if type(provider)~='function' or not rawequal(rawget(addon,'GetCacheDiagnosticMode'),provider)then return 'unavailable'end
 local ok,value=pcall(provider,addon)
 if not ok or not readable(value)or not rawequal(rawget(addon,'GetCacheDiagnosticMode'),provider)then return 'unavailable'end
 if value=='cached'or value=='direct'then return value end
 return 'unavailable'
end
local function diagnosticSnapshot(spec,provider)
 local snapshot={state='unavailable'}
 if type(provider)~='function' or not rawequal(rawget(addon,spec.method),provider)then return snapshot end
 local ok,result=pcall(provider,addon)
 if not ok or not rawequal(rawget(addon,spec.method),provider)then return snapshot end
 local state=field(result,spec.state)
 if readable(state)then
  if spec.state=='active'and type(state)=='boolean'then snapshot.state=tostring(state)
  elseif spec.state=='currentRoute'and type(state)=='string'and diagnosticRoutes[state]then snapshot.state=state end
 end
 for _,name in ipairs(spec.fields)do snapshot[name]=bytes(field(result,name))end
 if not rawequal(rawget(addon,spec.method),provider)then return {state='unavailable'}end
 return snapshot
end
local function diagnosticStart(run)
 run.cacheModeProvider=rawget(addon,'GetCacheDiagnosticMode')
 run.cacheModeStart=observationMode(run.cacheModeProvider)
 run.diagnostics={}
 for i,spec in ipairs(diagnosticSpecs)do
  local provider=rawget(addon,spec.method)
  run.diagnostics[i]={provider=provider,first=diagnosticSnapshot(spec,provider)}
 end
end
local function diagnosticEnd(run)
 run.cacheModeEnd=observationMode(run.cacheModeProvider)
 for i,spec in ipairs(diagnosticSpecs)do
  local record=run.diagnostics and run.diagnostics[i]
  if record then record.last=diagnosticSnapshot(spec,record.provider)end
 end
end
local function diagnosticReport(lines,run)
 lines[#lines+1]='Observation cache: start='..(run.cacheModeStart or 'unavailable')..'; end='..(run.cacheModeEnd or 'unavailable')
 for i,spec in ipairs(diagnosticSpecs)do
  local record=run.diagnostics and run.diagnostics[i]
  local first,last=record and record.first or {},record and record.last or {}
  local parts={spec.label..': start='..(first.state or 'unavailable')..'; end='..(last.state or 'unavailable')}
  for _,name in ipairs(spec.fields)do
   local a,b=first[name],last[name]
   parts[#parts+1]=name..'='..(a and b and b>=a and string.format('%.0f',b-a)or 'unavailable')
  end
  lines[#lines+1]=table.concat(parts,'; ')
 end
 lines[#lines+1]='Runtime counters are capture deltas; route/active states describe boundaries only. Diagnostics are read outside measured dispatches.'
end
local function report(run,status,reason)
 local lines={'Rotation Master native runtime capture: '..status..(reason and ' ('..reason..')'or ''),
  'Scope: all normal EvaluateNextAction dispatches, including timer and event calls; descendants overlap.',
  'Requested='..string.format('%g',run.requested)..' s; actual='..(run.duration and string.format('%.3f s',run.duration)or 'unavailable')..'; max dispatches=512; measured='..run.measured..'; unmeasured nested='..run.nested,
  'poll start='..run.poll,
  (function()local a,b=run.idleStart or {},run.idleEnd or {}
   local function delta(k)return a[k]and b[k]and b[k]>=a[k]and tostring(b[k]-a[k])or 'unavailable'end
   return 'Idle gate: idle_poll='..(a.interval or 'unavailable')..'; timer ticks evaluated='..delta('evaluated')..'; skipped='..delta('skipped')end)(),
  'Selected key: start='..(run.selectionStart or 'unavailable')..'; end='..(run.selectionEnd or 'unavailable'),
  string.format('elapsedMilliseconds: total=%.3f; average=%.3f; max=%.3f',run.elapsed,run.measured>0 and run.elapsed/run.measured or 0,run.maximum),
  'allocatedBytes='..(run.allocated~=nil and string.format('%.0f',run.allocated)or 'unavailable')..'; deallocatedBytes='..(run.deallocated~=nil and string.format('%.0f',run.deallocated)or 'unavailable'),
  'Gross allocated/deallocated bytes are not retained heap, garbage collection totals, or evidence of a memory leak.',
  'Measurements include the capture trampoline and instrumentation; real native evaluator acceptance requires a client capture.'}
 decisionReport(lines,run)
 lines[#lines+1]='Phases: complete='..(run.phaseComplete or 0)..'; unavailable='..(run.measured-(run.phaseComplete or 0))..' (missing, changed or invalid marker sequence/snapshots).'
 lines[#lines+1]='Phase rows include complete samples only, at existing child lookup boundaries. Intervals are disjoint; native marker overhead is included, unadjusted.'
 lines[#lines+1]='Byte snapshots are differenced; unavailable arithmetic is withheld. Native totals exclude outer aggregation and report work.'
 if run.phaseComplete and run.phaseComplete>0 then for i,row in ipairs(run.phaseRows)do
  lines[#lines+1]=string.format('%s | time=%.3f ms | allocatedBytes=%s | deallocatedBytes=%s',phaseNames[i],row.time,
   row.allocated~=nil and string.format('%.0f',row.allocated)or 'unavailable',row.deallocated~=nil and string.format('%.0f',row.deallocated)or 'unavailable')
 end end
 diagnosticReport(lines,run)
 return table.concat(lines,'\n')
end
local function finish(run,status,reason)
 if active~=run or run.phase=='finishing' then return end
 run.phase='finishing'
 local ended=now(run)
 if ended and run.started and ended>=run.started and finite(ended-run.started)then run.duration=ended-run.started end
 run.selectionEnd=selectedKey();run.idleEnd=idleGate()
 diagnosticEnd(run)
 active=nil;run.phase='retired'
 decisionRestore(run)
 if rawequal(rawget(addon,'EvaluateNextAction'),run.wrapper)then addon.EvaluateNextAction=run.original end
 phaseRestore(run)
 local timer=run.timer;run.timer=nil;if timer then pcall(run.cancel,addon,timer)end
 lastReport=report(run,status,reason)
 local callback=rawget(addon,'OnCPURuntimeCaptureFinished')
 if type(callback)=='function'then pcall(callback,addon,lastReport,status)end
end
local function originalResult(result)
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
local function dispatch(run,self,...)
 if not rawequal(self,addon)or not current(run)then return run.original(self,...)end
 if run.inside then run.nested=run.nested+1;run.samplePhaseOK=false;run.decisionSampleOK=false;return run.original(self,...)end
 if not providerCurrent(run)then finish(run,'invalid','profiling-api-changed');return run.original(self,...)end
 local at=now(run)
 if not current(run)or not providerCurrent(run)then finish(run,'invalid','capture-changed');return run.original(self,...)end
 if not at or at<run.started then finish(run,'invalid','clock-unavailable');return run.original(self,...)end
 if at>=run.started+run.requested then finish(run,'complete');return run.original(self,...)end
 local entries,open,result=0,true,nil
 local arguments=tuple(self,...);local exact=true
 local function once(...)
  if not open then return end
  entries=entries+1
  if entries~=1 or not current(run)then return end
  local given=tuple(...)
  if given.n~=arguments.n then exact=false else for i=1,arguments.n do if not rawequal(given[i],arguments[i])then exact=false;break end end end
  run.callbackInside=true
  result=tuple(pcall(run.original,unpack(arguments,1,arguments.n)))
  run.callbackInside=false
  return 'RM:runtime'
 end
 run.inside=true
 run.decisionSampleOK=run.decisionAvailable
 if run.decisionSampleOK then for row=1,2 do for index=1,9 do run.decisionScratch[row][index]=0 end end end
 run.phasePosition=0;run.samplePhaseOK=phaseCurrent(run)and true or false
 local native=tuple(pcall(run.measure,once,self,...))
 open=false;run.inside=false
 if not result then
  finish(run,'invalid','callback-not-run')
  return run.original(self,...)
 end
 if not result[1]then finish(run,'invalid','original-error');return originalResult(result)end
 if not current(run)then return originalResult(result)end
 local valid=native[1]and entries==1 and exact and providerCurrent(run)and native.n==3 and native[3]=='RM:runtime'
 local elapsed=valid and field(native[2],'elapsedMilliseconds')
 if not finite(elapsed)or elapsed<0 or not finite(run.elapsed+elapsed)then valid=false end
 if not valid then finish(run,'invalid','native-result-unavailable');return originalResult(result)end
 decisionAccumulate(run)
 run.measured=run.measured+1;run.elapsed=run.elapsed+elapsed;run.maximum=math.max(run.maximum,elapsed)
 local allocated,deallocated=bytes(field(native[2],'allocatedBytes')),bytes(field(native[2],'deallocatedBytes'))
 phaseAccumulate(run,native[2],elapsed,allocated,deallocated)
 if run.allocated~=nil then run.allocated=allocated and run.allocated+allocated or nil;if run.allocated and run.allocated>SAFE then run.allocated=nil end end
 if run.deallocated~=nil then run.deallocated=deallocated and run.deallocated+deallocated or nil;if run.deallocated and run.deallocated>SAFE then run.deallocated=nil end end
 if current(run)and run.measured>=LIMIT then finish(run,'complete','dispatch-limit')end
 return originalResult(result)
end
function addon:StartCPURuntimeCapture(duration)
 if not rawequal(self,addon)then return false,'invalid-owner'end
 if active then return false,'already-running'end
 if duration==nil then duration=10 end
 if not finite(duration)or duration<1 or duration>60 then return false,'invalid-duration'end
 local original=rawget(addon,'EvaluateNextAction');local cumulative=rawget(addon,'IsCPUProfileRunning')
 local schedule,cancel=rawget(addon,'ScheduleTimer'),rawget(addon,'CancelTimer')
 local clock=rawget(_G,'GetTimePreciseSec')or rawget(_G,'GetTime')
 if type(original)~='function'or type(cumulative)~='function'or type(schedule)~='function'or type(cancel)~='function'or type(clock)~='function'then return false,'missing-runtime-api'end
 local run={phase='starting',requested=duration,poll='unavailable',original=original,cancel=cancel,clock=clock,measured=0,nested=0,elapsed=0,maximum=0,allocated=0,deallocated=0}
 active=run
 local function reject(reason)if active==run then active=nil;run.phase='retired'end;return false,reason end
 local ok,running=pcall(cumulative,addon)
 if active~=run then return false,'capture-retired'end
 if not ok or not readable(running)or running~=false then return reject('cumulative-capture-running')end
 run.provider=rawget(_G,'C_AddOnProfiler');run.enabled=field(run.provider,'IsEnabled');run.measure=field(run.provider,'MeasureCall')
 if type(run.enabled)~='function'or type(run.measure)~='function'then return reject('missing-native-profiler-api')end
 local good,enabled=pcall(run.enabled)
 if active~=run then return false,'capture-retired'end
 if not good or not readable(enabled)or enabled~=true or not providerCurrent(run)then return reject('native-profiler-unavailable')end
 run.started=now(run);run.poll=poll();run.idleStart=idleGate();run.selectionStart=selectedKey()
 diagnosticStart(run)
 if active~=run then return false,'capture-retired'end
 phasePrepare(run)
 if active~=run then return false,'capture-retired'end
 if not run.started or not providerCurrent(run)or not rawequal(rawget(addon,'EvaluateNextAction'),original)or not rawequal(rawget(addon,'IsCPUProfileRunning'),cumulative)then return reject('capture-changed')end
 run.wrapper=function(...)return dispatch(run,...)end
 local accepted,timer=pcall(schedule,addon,function()finish(run,'complete')end,duration)
 if active~=run then if accepted and timer then pcall(cancel,addon,timer)end;return false,'capture-retired'end
 if not accepted or not timer then return reject('timer-error')end
 run.timer=timer
 if not providerCurrent(run)or not rawequal(rawget(addon,'EvaluateNextAction'),original)or not rawequal(rawget(addon,'IsCPUProfileRunning'),cumulative)then finish(run,'invalid','capture-changed');return false,'capture-changed'end
 addon.EvaluateNextAction=run.wrapper;run.phase='running';phaseInstall(run);decisionInstall(run);lastReport=nil
 return true
end
function addon:StopCPURuntimeCapture()
 if not rawequal(self,addon)then return false,'invalid-owner'end
 if not active then return false,'not-running'end
 finish(active,'stopped');return true
end
function addon:CancelCPURuntimeCapture()
 if not rawequal(self,addon)then return false,'invalid-owner'end
 if not active then return false,'not-running'end
 finish(active,'cancelled');return true
end
function addon:IsCPURuntimeCaptureRunning()return active~=nil end
function addon:GetCPURuntimeCaptureReport()
 if active then return string.format('Rotation Master native runtime capture: running (requested %g s; all normal evaluator dispatches)',active.requested)end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
