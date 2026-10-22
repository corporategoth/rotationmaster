local addon_name,addon=...
-- Explicit, bounded lifetime observations. No evaluator hook or GC control.
local active,lastReport,latest
local DURATION,HEAP_LIMIT,DETAIL_LIMIT,COUNT_LIMIT,NODE_LIMIT=600,601,21,4096,8192
local kind,raw,nextKey,protect,each,same=type,rawget,next,pcall,ipairs,rawequal
local format,concat=string.format,table.concat
local function readable(value)
 local secret=raw(_G,'issecretvalue');if secret~=nil then if kind(secret)~='function'then return false end;local ok,v=protect(secret,value);if not ok or v~=false then return false end end
 local access=raw(_G,'canaccessvalue');if access~=nil then if kind(access)~='function'then return false end;local ok,v=protect(access,value);if not ok or v~=true then return false end end
 return true
end
local function number(value)return readable(value)and kind(value)=='number'and value==value and value>=0 and value<=9007199254740991 end
local function field(value,key)if readable(value)and kind(value)=='table'then return raw(value,key)end end
local function current(run)return active==run and run.phase=='running'end
---@return number|nil
local function callNumber(run,fn,...)
 if not current(run)or kind(fn)~='function'then return end
 local ok,value=protect(fn,...)
 if not current(run)or not ok or not number(value)or not current(run)then return end
 ---@cast value number
 return value
end
local function api(name)
 local method=field(raw(_G,'C_AddOns'),name)
 if kind(method)=='function'then return method end
 method=raw(_G,name);if kind(method)=='function'then return method end
end
local retainedKeys={'spellIDs','spellNames','itemRecords','itemIndex','itemBlocked','buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}
local publicKeys={'units','spellRows','combatUnits','combatRows','damageUnits','damageRows','healRows','combatKeys','longtermKeys'}
-- Optional installed WTM public scalars only; no WTM method, event or frame hook.
local wtmAddonKey=string.lower(addon_name)
local function sampleSpikes(run,at,dropped)
 local owner=field(field(field(raw(_G,'WoWTaskManager'),'Processes'),'byName'),wtmAddonKey)
 local n,last=field(owner,'spikes'),field(owner,'lastSpikeAt')
 if not current(run)then return end
 if not number(n)or n%1~=0 then run.wtmOwner=nil;run.wtmCount=nil;run.wtmLast=nil;return end
 if not current(run)then return end
 run.wtmSnapshots=run.wtmSnapshots+1
 if same(run.wtmOwner,owner)and run.wtmCount and n>=run.wtmCount then
  local increase=n-run.wtmCount
  run.wtmIncreases=run.wtmIncreases+increase
  run.wtmIntervals=run.wtmIntervals+1
  run.wtmMaxInterval=math.max(run.wtmMaxInterval or 0,at-run.wtmAt)
  if dropped and increase>0 then run.wtmOverlaps=run.wtmOverlaps+increase;run.wtmOverlapIntervals=run.wtmOverlapIntervals+1 end
 end
 run.wtmOwner,run.wtmCount,run.wtmAt=owner,n,at
 run.wtmLast=number(last)and last or nil
end
local function count(run,map,budget)
 if not readable(map)or kind(map)~='table'or getmetatable(map)~=nil then return end
 local n,key=0,nil
 repeat
  if budget.n>=NODE_LIMIT then return n,true end
  local value;key,value=nextKey(map,key)
  if key==nil then return n,false end
  if not readable(key)or not current(run)then return end
  budget.n=budget.n+1;n=n+1
 until n>COUNT_LIMIT
 return COUNT_LIMIT,true
end
local function roots(run,row)
 local budget={n=0}
 local function save(key,map)local n,capped=count(run,map,budget);row[key],row[key..'Capped']=n,capped end
 save('units',raw(addon,'unitsInRange'));save('spellRows',raw(addon,'spellHistory'))
 save('combatKeys',raw(addon,'combatCache'));save('longtermKeys',raw(addon,'longtermCache'))
 local function nested(root,unitKey,rowKey,child,second)
  local map=raw(addon,root);save(unitKey,map)
  if not readable(map)or kind(map)~='table'or getmetatable(map)~=nil then return end
  local total,capped,key=0,false,nil;local other,otherCapped=0,false
  while true do
   if budget.n>=NODE_LIMIT then capped=true;otherCapped=true;break end
   local value;key,value=nextKey(map,key);if key==nil then break end
   if not readable(key)or not current(run)then return end
   budget.n=budget.n+1
   local n,cap=count(run,child and field(value,child)or value,budget)
   if n==nil then return end
   total=total+n;capped=capped or cap
   if second then local x,c=count(run,field(value,second),budget);if x==nil then return end;other=other+x;otherCapped=otherCapped or c end
   if total>COUNT_LIMIT or other>COUNT_LIMIT then capped=true;otherCapped=true;break end
  end
  row[rowKey],row[rowKey..'Capped']=math.min(total,COUNT_LIMIT),capped
  if second then row.healRows,row.healRowsCapped=math.min(other,COUNT_LIMIT),otherCapped end
 end
 nested('combatHistory','combatUnits','combatRows')
 nested('damageHistory','damageUnits','damageRows','damage','heals')
end
local function storedNumber(value)return kind(value)=='number'and value==value and value>=0 and value<=9007199254740991 end
local function amount(value)
 return storedNumber(value)and format('%.3f',value)or 'unavailable'
end
local function render(run,status)
 local lines={'Rotation Master memory capture: '..status,'Native acceptance: unverified',
  'Whole heap is shared Lua memory; addonKiB is sampled attribution. Neither identifies retained object bytes.',
  'Heap decreases are observations, not confirmed GC events. No collection or evaluator profiling was requested.',
  format('requested=600 s; actual=%s s; heap samples=%d; detailed samples=%d',amount(run.elapsed),run.heapSamples,#run.rows),
  format('heapKiB start=%s; end=%s; min=%s; max=%s; decreases=%d (>=256 KiB); max drop=%s at=%s s',amount(run.heapStart),amount(run.heapEnd),amount(run.heapMin),amount(run.heapMax),run.drops,amount(run.maxDrop),amount(run.maxDropAt)),
  format('Explicit attribution refreshes=%d; successful=%d; failed=%d; scan total=%s ms; max=%s ms',run.scanAttempts,run.scanOK,run.scanFailed,amount(run.scanTime),amount(run.scanMax))..' (timed scans='..run.timedScans..')',
  format('Sampler overhead total=%s ms; max=%s ms; failed samples=%d. Timings include instrumentation, unadjusted.',amount(run.overhead),amount(run.overheadMax),run.failedSamples)..' Timed sampler bodies='..run.timedSamples..'.',
  'Counts are keys/rows, not bytes; >= marks a bounded lower limit. Missing or restricted observations are unavailable.',
  'Heap precedes each attribution refresh. CPU/runtime flags describe detailed boundaries only; overlapping instrumentation can affect memory.',
  'Explicit memory attribution refreshes may themselves contribute to observed frame spikes; compare scan costs before attributing overlaps to ordinary RM work.'}
 local function counts(row,keys)
  local parts={}
  for _,key in each(keys)do local v=row[key];parts[#parts+1]=key..'='..(storedNumber(v)and((row[key..'Capped']and'>='or'')..format('%.0f',v))or'unavailable')end
  return concat(parts,' ')
 end
 if run.wtmSnapshots>0 then
  lines[#lines+1]=format('WTM/RM spike increases=%d; overlapping observed heap-drop intervals=%d; overlapping spike increases=%d; valid comparisons=%d; max interval=%s s. Co-occurrence only, not confirmed GC or causality.',run.wtmIncreases,run.wtmOverlapIntervals,run.wtmOverlaps,run.wtmIntervals,amount(run.wtmMaxInterval))
 else lines[#lines+1]='WTM spike correlation: unavailable (optional public counters not observed).'end
 local reportBytes=#concat(lines,'\n')
 for _,row in each(run.rows)do
  local text=format('t=%s s heapKiB=%s addonKiB=%s fresh=%s scanMs=%s',amount(row.t),amount(row.heap),amount(row.addonKB),row.fresh and'yes'or'no',amount(row.scanMs))..' cpu='..row.cpu..' runtime='..row.runtime..' WTM/RMspikes='..(storedNumber(row.wtmSpikes)and format('%.0f',row.wtmSpikes)or'unavailable')..' WTMlastSpikeT='..amount(row.wtmLast)
  local a,b=counts(row,retainedKeys),counts(row,publicKeys)
  if a~=''then text=text..' '..a end;if b~=''then text=text..' '..b end
  if reportBytes+#text+1>15500 then lines[#lines+1]='Remaining detailed rows omitted to keep report bounded.';break end
  lines[#lines+1]=text;reportBytes=reportBytes+#text+1
 end
 lines[#lines+1]='WTM spikes, when displayed elsewhere, correlate sampled CPU windows with slow frames; they do not prove RM caused a frame hitch.'
 return concat(lines,'\n')
end
local function finish(run,status)
 if not current(run)then return end
 active=nil;run.phase='retired'
 local report=render(run,status);lastReport=report
 local repeating,timeout=run.timer,run.timeout;run.timer,run.timeout=nil,nil
 if repeating then protect(run.cancel,addon,repeating)end
 if timeout then protect(run.cancel,addon,timeout)end
 if active==nil and latest==run then local notify=raw(addon,'OnMemoryCaptureFinished');if kind(notify)=='function'then protect(notify,addon,report,status)end end
end
local function detail(run,at,heap)
 local row={t=at-run.started,heap=heap,fresh=false,wtmSpikes=run.wtmCount}
 if run.wtmLast and run.wtmLast>=run.started then row.wtmLast=run.wtmLast-run.started end
 if kind(run.update)=='function'and kind(run.memory)=='function'then
  run.scanAttempts=run.scanAttempts+1
  local before=callNumber(run,run.ms)
  if not current(run)then return end
  local ok=protect(run.update)
  if not current(run)then return end
  local ending=callNumber(run,run.ms)
  if not current(run)then return end
  if before and ending and ending>=before then
   row.scanMs=ending-before;run.scanTime=(run.scanTime or 0)+row.scanMs;run.scanMax=math.max(run.scanMax or 0,row.scanMs);run.timedScans=run.timedScans+1
  end
  if ok then row.addonKB=callNumber(run,run.memory,addon_name)end
  if not current(run)then return end
  row.fresh=row.addonKB~=nil
  if row.fresh then run.scanOK=run.scanOK+1 else run.scanFailed=run.scanFailed+1 end
 end
 local function captureState(name)
  local fn=raw(addon,name)
  if kind(fn)~='function'then return 'unknown'end
  local ok,value=protect(fn,addon)
  if not current(run)then return 'unknown'end
  if ok and readable(value)and kind(value)=='boolean'then return value and'active'or'inactive'end
  return 'unknown'
 end
 row.cpu,row.runtime=captureState('IsCPUProfileRunning'),captureState('IsCPURuntimeCaptureRunning')
 if not current(run)then return end
 local provider=raw(addon,'GetRetainedMemoryDiagnostic')
 if kind(provider)=='function'then
  local ok,value=protect(provider,addon)
  if not current(run)then return end
  if ok then for _,key in each(retainedKeys)do
   local n=field(value,key)
   if number(n)and n%1==0 and n<=COUNT_LIMIT then row[key]=n;row[key..'Capped']=field(value,key..'Capped')==true end
   if not current(run)then return end
  end end
 end
 protect(roots,run,row)
 if not current(run)then return end
 run.rows[#run.rows+1]=row;run.nextDetail=at+30
end
local function sample(run,ending)
 if not current(run)or run.sampling then return end
 run.sampling=true
 local ok=protect(function()
  local at=callNumber(run,run.clock);if not at or not current(run)then return end
  if at<run.started then finish(run,'invalid');return end
  run.elapsed=at-run.started
  if run.lastAt==nil or at>run.lastAt then
   local before=callNumber(run,run.ms)
   local heap=callNumber(run,run.heap,'count')
   if not current(run)then return end
   if heap~=nil and run.heapSamples<HEAP_LIMIT then
    run.heapSamples=run.heapSamples+1;run.heapStart=run.heapStart or heap;run.heapEnd=heap
    run.heapMin=math.min(run.heapMin or heap,heap);run.heapMax=math.max(run.heapMax or heap,heap)
    local dropped=run.previousHeap and run.previousHeap-heap>=256
    if dropped then local drop=run.previousHeap-heap;run.drops=run.drops+1;if not run.maxDrop or drop>run.maxDrop then run.maxDrop=drop;run.maxDropAt=at-run.started end end
    sampleSpikes(run,at,dropped)
    if not current(run)then return end
    run.previousHeap=heap
   else run.failedSamples=run.failedSamples+1 end
   run.lastAt=at
   if at>=run.nextDetail and #run.rows<DETAIL_LIMIT then detail(run,at,heap)end
   if not current(run)then return end
   local after=callNumber(run,run.ms)
   if before and after and after>=before then local cost=after-before;run.overhead=(run.overhead or 0)+cost;run.overheadMax=math.max(run.overheadMax or 0,cost);run.timedSamples=run.timedSamples+1 end
  end
  if ending or run.elapsed>=DURATION or run.heapSamples>=HEAP_LIMIT then finish(run,'complete')end
 end)
 if current(run)then
  run.sampling=false
  if not ok then run.failedSamples=run.failedSamples+1 end
  if ending then finish(run,'invalid')end
 end
end
function addon:StartMemoryCapture()
 if self~=addon then return false,'foreign-owner'end
 local enabled=self.IsEnabled
 if kind(enabled)=='function'then
  local ok,value=protect(enabled,self)
  if not ok or not readable(value)or value~=true then return false,'addon-disabled'end
 end
 if active then return false,'already-running'end
 local run={phase='running',rows={},heapSamples=0,drops=0,scanAttempts=0,scanOK=0,scanFailed=0,failedSamples=0,timedScans=0,timedSamples=0,wtmSnapshots=0,wtmIncreases=0,wtmIntervals=0,wtmOverlaps=0,wtmOverlapIntervals=0,
  clock=raw(_G,'GetTimePreciseSec')or raw(_G,'GetTime'),heap=raw(_G,'collectgarbage'),ms=raw(_G,'debugprofilestop'),
  update=api('UpdateAddOnMemoryUsage'),memory=api('GetAddOnMemoryUsage'),cancel=raw(addon,'CancelTimer')}
 local repeating,timeout=raw(addon,'ScheduleRepeatingTimer'),raw(addon,'ScheduleTimer')
 if kind(run.clock)~='function'or kind(run.heap)~='function'or kind(repeating)~='function'or kind(timeout)~='function'or kind(run.cancel)~='function'then return false,'missing-memory-api'end
 active=run;latest=run
 run.started=callNumber(run,run.clock)
 if not current(run)then return false,'capture-retired'end
 if not run.started then finish(run,'unavailable');return false,'invalid-clock'end
 run.nextDetail=run.started;sample(run)
 if not current(run)then return false,'capture-retired'end
 if run.heapSamples==0 then finish(run,'unavailable');return false,'unavailable-heap'end
 local ok,timer=protect(repeating,addon,function()sample(run)end,1)
 if not current(run)then if ok and timer then protect(run.cancel,addon,timer)end;return false,'capture-retired'end
 if not ok or not timer then finish(run,'unavailable');return false,'timer-error'end
 run.timer=timer
 local good,handle=protect(timeout,addon,function()sample(run,true)end,DURATION)
 if not current(run)then if good and handle then protect(run.cancel,addon,handle)end;return false,'capture-retired'end
 if not good or not handle then finish(run,'unavailable');return false,'timer-error'end
 run.timeout=handle
 return true
end
function addon:StopMemoryCapture()
 if self~=addon or not active then return false,'not-running'end
 finish(active,'cancelled');return true
end
function addon:IsMemoryCaptureRunning()return self==addon and active~=nil end
function addon:GetMemoryCaptureReport()
 if self~=addon then return nil,'foreign-owner'end
 if active then return nil,'running'end
 return lastReport,lastReport and nil or'not-captured'
end
