-- Exact diagnostic additions only; restored predecessors are whole-module pinned.
local records={
 ['Diagnostics/cpu.lua']={length=55109,hash='785d8fa6',oldLength=46911,oldHash='92d4503a',blocks={
[====[-- BEGIN RUNTIME WORK VIEWS
-- Fixed pointers only. Readers are source-local literal returns, not helpers.
local workGroups,workClosed,workCount,workCapture={},false,0,nil
local workEqual=rawequal
local workSpecs={
 {name='store',namespace='RotationData',anchor='NewRotationStore',slots={'Store.plain','Store.fields','Store.validAddress'}},
 {name='main',anchor='EvaluateNextActionInternal',slots={'Main.UpdateUnitInfo'}},
 {name='diagnostics',namespace='Diagnostics',member='Call',slots={'Diagnostics.Call'}},
 {name='profile',namespace='evaluationProfile',member='child',slots={'EvaluationProfile.child'}},
}
local workInstaller
local function workRetire()
 workClosed=true
 if workEqual(proofRawget(addon,'BindCPURuntimeWorkDiagnostic'),workInstaller) then addon.BindCPURuntimeWorkDiagnostic=nil end
end
workInstaller=function(self,name,anchor,reader)
 if workClosed or not workEqual(self,addon) or (name~='store' and name~='main')
  or proofType(anchor)~='function' or proofType(reader)~='function' or workGroups[name] then return false end
 local namespace=addon;if name=='store' then namespace=proofRawget(addon,'RotationData') end
 workGroups[name]={anchor=anchor,reader=reader,namespace=namespace}
 workCount=workCount+1;if workCount==2 then workRetire() end
 return true
end
addon.BindCPURuntimeWorkDiagnostic=workInstaller
local function workClear(run)
 local state=run.runtimeWork;if state then state.phase='retired' end
 run.runtimeWork=nil;if workCapture==run then workCapture=nil end
end
local function workEnding(run,status)
 if status~='complete' then workClear(run) elseif run.runtimeWork then run.runtimeWork.phase='end' end
end
local function workNamespace(spec)
 if spec.namespace then return proofRawget(addon,spec.namespace) end
 return addon
end
local function workFunctions(run,source,current)
 if not current() then return nil,'capture-retired' end
 if not workEqual(run.owner,addon) then return nil,'owner-changed' end
 local spec,group=source.spec,source.group
 if spec.anchor and not group then return nil,'unbound' end
 local namespace=workNamespace(spec)
 if not readable(namespace) or not workEqual(namespace,source.namespace) or proofType(namespace)~='table' then return nil,'owner-changed' end
 local values
 if spec.anchor then
  local anchor=proofRawget(namespace,spec.anchor)
  if not readable(anchor) or not workEqual(anchor,group.anchor) then return nil,'owner-changed' end
  if not current() then return nil,'capture-retired' end
  values=validationTuple(proofPcall(group.reader))
  if not current() then return nil,'capture-retired' end
  if not values[1] then return nil,'provider-unavailable' end
  if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
  if not workEqual(proofRawget(addon,spec.namespace or spec.anchor),spec.namespace and namespace or group.anchor)
   or not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 else values={true,proofRawget(namespace,spec.member)} end
 for i=1,#spec.slots do if not readable(values[i+1]) or proofType(values[i+1])~='function' then return nil,'invalid-source-function' end end
 if not current() then return nil,'capture-retired' end
 if not workEqual(workNamespace(spec),namespace) then return nil,'owner-changed' end
 if spec.anchor then
  if not workEqual(proofRawget(namespace,spec.anchor),group.anchor) then return nil,'owner-changed' end
 elseif not workEqual(proofRawget(namespace,spec.member),values[2]) then return nil,'function-replaced' end
 return values
end
local function workStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},sources={}};run.runtimeWork=state;workCapture=run
 state.current=function() return workCapture==run and run.runtimeWork==state
  and (state.phase=='start' and active==run or state.phase=='end' and active==nil) end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,group in ipairs({run.privateCache,run.activity or {},run.validationScopes or {}}) do for _,row in ipairs(group.samples or {}) do remember(row) end end
 for _,spec in ipairs(workSpecs) do
  local group=workGroups[spec.name]
  local namespace=workNamespace(spec);if group then namespace=group.namespace end
  local source={spec=spec,group=group,namespace=namespace}
  state.sources[#state.sources+1]=source
  local funcs,reason=workFunctions(run,source,state.current)
  for i,name in ipairs(spec.slots) do
   local view={label='Work.'..name,source=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn;local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current) end
    end
    view.sample=sample
   end
  end
 end
end
local function appendWorkViews(report,run,sampleEnd)
 local state=run.runtimeWork
 local lines={'Runtime work views (native counters; shared functions overlap):'};local available=0;local index=0
 if state then for _,source in ipairs(state.sources) do source.functions,source.reason=workFunctions(run,source,state.current) end end
 for _,spec in ipairs(workSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem=view and view.reason or 'baseline-unavailable'
  local sample,current
  if view then
   problem=view.reason
   if not problem then
    local source=view.source;problem=source.reason
    if not problem and not workEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
    sample=view.sample;problem=problem or sample.reason
    if not problem then current,problem=sampleEnd(run,sample,state.current) end
    if not problem then for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Work.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed runtime work views: aliases=6; available=%d; unavailable=%d (excluded from rankings above).',available,6-available)
 lines[#lines+1]='Shared function counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Runtime work views omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END RUNTIME WORK VIEWS
]====],
[====[ -- BEGIN RUNTIME WORK END TOKEN
 workEnding(run,status)
 -- END RUNTIME WORK END TOKEN
]====],
[====[   -- BEGIN RUNTIME WORK APPENDIX
   local workState=run.runtimeWork
   local workEntered=workState and workState.current()
   appendWorkViews(report,run,finishSample)
   if workEntered and not workState.current() then workClear(run);return end
   -- END RUNTIME WORK APPENDIX
]====],
[====[ -- BEGIN RUNTIME WORK CLEANUP
 workClear(run)
 -- END RUNTIME WORK CLEANUP
]====],
[====[ -- BEGIN RUNTIME WORK RETIRE
 workRetire()
 -- END RUNTIME WORK RETIRE
]====],
[====[ -- BEGIN RUNTIME WORK START
 local workEntered=active==run
 workStart(run)
 if workEntered and active~=run then workClear(run);return true end
 -- END RUNTIME WORK START
]====],
[====[ -- BEGIN RUNTIME WORK TIMER FAILURE
 if not ok or not timer then workClear(run) end
 -- END RUNTIME WORK TIMER FAILURE
]====],
 }},
 ['Data/rotation_store.lua']={length=36964,hash='64c496e7',oldLength=36718,oldHash='09dd5761',blocks={
[====[-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'store',data.NewRotationStore,function() return plain,fields,validAddress end) end
end
-- END CPU RUNTIME WORK HANDOFF
]====],
 }},
 ['main.lua']={length=77591,hash='7780dabb',oldLength=77346,oldHash='a564d651',blocks={
[====[-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'main',addon.EvaluateNextActionInternal,function() return UpdateUnitInfo end) end
end
-- END CPU RUNTIME WORK HANDOFF
]====],
 }},
}
local function hash(s)local h=0;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.format('%08x',h)end
return function(text,path)
 if path=='main.lua'and text:find('-- BEGIN ANALYTICS ADVICE HANDOFF',1,true)then text=dofile('tests/fixtures/restore_analytics_preview_delivery.lua')(text,path)end
 if path=='Data/rotation_store.lua' and text:find("-- Preserve public-reader admission",1,true) then text=dofile('tests/fixtures/restore_runtime_store_native_gate.lua')(text,path) end
 -- Callers may already have removed the accepted publication/event changes.
 -- Admit only these exact current or normalized whole modules, never an arbitrary skip.
 local accepted={['Data/rotation_store.lua']={41494,'8a0fe0d0',36975,'1801f0e3'},['main.lua']={86781,'5c9d4420',84322,'7185fab1'}}
 local input=accepted[path]
 if input then
  if #text==input[1] and hash(text)==input[2] then text=dofile('tests/fixtures/restore_runtime_event_context.lua')(text,path)
  else assert(#text==input[3] and hash(text)==input[4],'unexpected current or normalized runtime work source: '..path) end
 end
 if path=='Data/rotation_store.lua' then text=dofile('tests/fixtures/restore_rotation_store_schema_maps.lua')(text) end
 if path=='Diagnostics/cpu.lua' then text=dofile('tests/fixtures/restore_analytics_disable.lua')(text,path) end
 if path=='main.lua' then text=dofile('tests/fixtures/restore_questie_wiring.lua')(text,path) end
 if path=='main.lua' then text=dofile('tests/fixtures/restore_nameplate_lifecycle.lua')(text,path) end
 local r=assert(records[path],'unknown runtime work inverse path')
 assert(#text==r.length and hash(text)==r.hash,'unrelated runtime work module change: '..path)
 for _,block in ipairs(r.blocks)do
  local first,last=assert(text:find(block,1,true));assert(not text:find(block,last+1,true),'duplicate runtime work addition')
  text=text:sub(1,first-1)..text:sub(last+1)
 end
 assert(#text==r.oldLength and hash(text)==r.oldHash,'runtime work predecessor mismatch: '..path)
 return text
end
