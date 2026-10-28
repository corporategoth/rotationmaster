-- Strict whole-file inverse of the capture-only retained/activity diagnostics.
local blocks = {
    ["Diagnostics/cpu.lua"] = {
        [====[
-- BEGIN CPU ACTIVITY DIAGNOSTICS
local activityProviders,activityFrame,activityAPI={},nil,nil
local activityEqual,activityCreate=rawequal,CreateFrame
function addon:BindCPUActivityDiagnostic(name,reader)
 if self~=addon or (name~='spell' and name~='item' and name~='visual') or proofType(reader)~='function' or activityProviders[name] then return false end
 activityProviders[name]=reader
 if activityProviders.spell and activityProviders.item and activityProviders.visual then addon.BindCPUActivityDiagnostic=nil end
 return true
end
local function activityRead()
 local result={}
 for _,name in ipairs({'spell','item','visual'}) do
  local reader=activityProviders[name]
  if reader then local ok,value=proofPcall(reader,activityAPI);if ok and proofType(value)=='table' then result[name]=value end end
 end
 return result
end
local function activityEvent(run,event,_,success)
 if not readable(success) or proofType(success)~='boolean' then run.activity.events.unknown=run.activity.events.unknown+1;return end
 if success then
  if event=='SPELL_DATA_LOAD_RESULT' then run.activity.events.spell=run.activity.events.spell+1
  elseif event=='ITEM_DATA_LOAD_RESULT' then run.activity.events.item=run.activity.events.item+1 end
 end
end
local function activityStop(run)
 local state=run.activity;if not state then return end
 if state.lease then state.lease.run=nil;state.lease=nil end
 local frame,api=state.frame,state.api;state.frame=nil;state.api=nil
 if frame and api then
  local ok,current=proofPcall(api.GetScript,frame,'OnEvent')
  local released=false
  if ok and activityEqual(current,state.handler) then
   local events=proofPcall(api.UnregisterAllEvents,frame);local handler=proofPcall(api.SetScript,frame,'OnEvent',nil);released=events and handler
  end
  if not released then
   state.events.available=false
   if activityEqual(activityFrame,frame) then activityFrame=nil;activityAPI=nil end
  end
 end
 state.handler=nil
end
local function activityStart(run)
 addon.BindCPUActivityDiagnostic=nil
 run.activity={events={spell=0,item=0,unknown=0,available=false},views={},samples={}}
 local state=run.activity
 if not activityFrame and proofType(activityCreate)=='function' then
  local ok,frame=proofPcall(activityCreate,'Frame')
  if ok and frame then
   local api={};local valid=true
   for _,name in ipairs({'GetScript','SetScript','RegisterEvent','UnregisterAllEvents','Hide','GetParent','IsVisible'}) do
    local method=frame[name];if proofType(method)~='function' then valid=false end;api[name]=method
   end
   if valid then activityFrame,activityAPI=frame,api;proofPcall(api.Hide,frame) end
  end
 end
 if activityFrame then
  state.frame=activityFrame;state.api=activityAPI
  local lease={run=run};state.lease=lease
  state.handler=function(_,event,...)
   local current=lease.run;if not current or active~=current then return end
   if not proofPcall(activityEvent,current,event,...) then current.activity.events.unknown=current.activity.events.unknown+1 end
  end
  local ok=proofPcall(function()
   activityAPI.SetScript(activityFrame,'OnEvent',state.handler)
   activityAPI.RegisterEvent(activityFrame,'SPELL_DATA_LOAD_RESULT');activityAPI.RegisterEvent(activityFrame,'ITEM_DATA_LOAD_RESULT')
  end)
  if ok then state.events.available=true else activityStop(run) end
 end
 state.started=activityRead()
 local seen,totalSamples={},#run.rows+#run.privateCache.samples
 for _,row in ipairs(run.rows) do seen[row.fn]=row end
 for _,row in ipairs(run.privateCache.samples) do seen[row.fn]=row end
 local visual=state.started.visual
 for _,name in ipairs({'overlay','pixel','autocast','blizzard'}) do
  local view={name=name};state.views[#state.views+1]=view
  local callbacks=field(visual,'callbacks');local ambiguous=field(visual,'ambiguous')
  local fn=field(callbacks,name)
  if field(ambiguous,name)==true then view.reason='ambiguous-callback'
  elseif proofType(fn)~='function' or not readable(fn) then view.reason='no-start-callback'
  else
   local sample=seen[fn]
   if not sample then
    if totalSamples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;totalSamples=totalSamples+1;state.samples[#state.samples+1]=sample;sample.before,sample.reason=snapshot(run,fn) end
   end
   view.sample=sample
  end
 end
end
local function appendActivity(report,run)
 local state=run.activity;if not state then return end
 local lines={'Retained catalogs and animation activity (capture only):'}
 local function retained(root,key)
  local object=field(root,key);local n=field(object,'n');local capped=field(object,'capped')
  if not counter(n,true) or n>4096 or proofType(capped)~='boolean' then return 'unavailable' end
  return (capped and '>=' or '')..tostring(n),not capped and n or nil
 end
 for _,entry in ipairs({{'spell','spellIDs','spell IDs'},{'spell','spellNames','spell name groups'},{'item','itemRecords','item records'},{'item','itemIndex','item index'},{'item','itemBlocked','blocked items'}}) do
  local start,before=retained(field(state.started,entry[1]),entry[2]);local ending,after=retained(field(state.ended,entry[1]),entry[2])
  lines[#lines+1]=entry[3]..': start='..start..'; end='..ending..'; change='..(before~=nil and after~=nil and tostring(after-before) or 'unavailable')
 end
 local events=state.events
 lines[#lines+1]=events.available and string.format('metadata successes: spell=%s; item=%s; unknown=%s',tostring(events.spell),tostring(events.item),tostring(events.unknown)) or 'metadata successes: unavailable'
 local function visual(label,value)
  if proofType(value)~='table' then return label..' visuals: unavailable' end
  local parts={label..' visuals:'}
  for _,key in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(value,key);parts[#parts+1]=key..'='..(counter(n,true) and n<=4096 and tostring(n) or 'unavailable')
  end
  parts[#parts+1]='capped='..(field(value,'capped')==true and 'true' or 'false')
  if field(value,'unsupported')==true then parts[#parts+1]='native-observation=unavailable' end
  return table.concat(parts,' ')
 end
 lines[#lines+1]=visual('start',field(state.started,'visual'));lines[#lines+1]=visual('end',field(state.ended,'visual'))
 local labels={overlay='RM.UpdateOverlay',pixel='SharedGlow.Pixel.OnUpdate',autocast='SharedGlow.AutoCast.OnUpdate',blizzard='SharedGlow.Blizzard.OnUpdate'}
 local available=0
 for _,view in ipairs(state.views) do
  local sample,problem=view.sample,view.reason
  if not field(state.ended,'visual') then problem=problem or 'source-reader-changed' end
  problem=problem or sample and sample.reason
  local current
  if not problem then current,problem=finishSample(run,sample) end
  if not problem then
   for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  lines[#lines+1]=problem and labels[view.name]..' | unavailable: '..problem or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',labels[view.name],exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Animation views: aliases=4; available=%d; unavailable=%d (excluded from rankings above).',available,4-available)
 lines[#lines+1]='Catalog counts are keys, not bytes; global metadata arrivals may originate outside RM. Capped counts are lower bounds; sequence counts timer handles regardless of visibility, not measured executions.'
 lines[#lines+1]='Shared glow frames are associated with RM-active slots; shared callback counters include all callers. Start callbacks only; end-only callbacks lack a baseline. Proc uses native animations.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Retained activity omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END CPU ACTIVITY DIAGNOSTICS
]====],
        [====[
 -- BEGIN CPU ACTIVITY STOP
 activityStop(run)
 -- END CPU ACTIVITY STOP
]====],
        [====[
   -- BEGIN CPU ACTIVITY END
   if run.activity then run.activity.ended=activityRead() end
   -- END CPU ACTIVITY END
]====],
        [====[
   -- BEGIN CPU ACTIVITY APPENDIX
   appendActivity(report,run)
   -- END CPU ACTIVITY APPENDIX
]====],
        [====[
 -- BEGIN CPU ACTIVITY START
 local activityOK=proofPcall(activityStart,run)
 if not activityOK then activityStop(run);run.activity=nil end
 -- END CPU ACTIVITY START
]====],
    },
    ["Core/spell_catalog.lua"] = {
        [====[

-- BEGIN CPU ACTIVITY HANDOFF
-- Private capture-only cardinality; no metadata query or per-event bookkeeping.
do
    local raw,nextKey,kind,equal=rawget,next,type,rawequal
    local ownedUpdate=catalog.UpdateSpell
    local function count(map)
        local n,key=0,nil
        repeat key=nextKey(map,key);if key~=nil then n=n+1 end until key==nil or n>4096
        return {n=n>4096 and 4096 or n,capped=n>4096}
    end
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'spell',function()
        if not equal(raw(addon,'SpellCatalog'),catalog) or not equal(raw(catalog,'UpdateSpell'),ownedUpdate) then return end
        return {spellIDs=count(entries),spellNames=count(byName)}
    end) end
end
-- END CPU ACTIVITY HANDOFF
]====],
    },
    ["Core/reference_catalog.lua"] = {
        [====[

-- BEGIN CPU ACTIVITY HANDOFF
-- Count retained keys directly only when an explicit CPU capture asks.
do
    local raw,nextKey,kind,equal=rawget,next,type,rawequal
    local ownedUpdate,ownedProvider=addon.UpdateReferenceItem,addon.GetReferenceProvider
    local function count(map)
        local n,key=0,nil
        repeat key=nextKey(map,key);if key~=nil then n=n+1 end until key==nil or n>4096
        return {n=n>4096 and 4096 or n,capped=n>4096}
    end
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'item',function()
        if not equal(raw(addon,'UpdateReferenceItem'),ownedUpdate) or not equal(raw(addon,'GetReferenceProvider'),ownedProvider) then return end
        return {itemRecords=count(items),itemIndex=count(indexed),itemBlocked=count(blocked)}
    end) end
end
-- END CPU ACTIVITY HANDOFF
]====],
    },
    ["buttons.lua"] = {
        [====[

-- BEGIN CPU ACTIVITY HANDOFF
-- Only the private RM button maps and their current logical slots are inspected.
-- Shared glow fields establish association, never exclusive caller ownership.
do
    local raw,nextKey,kind,equal,protect,text=rawget,next,type,rawequal,pcall,tostring
    local ownedGlow,ownedFetch=addon.Glow,addon.Fetch
    local starts={pixel=CustomGlow.PixelGlow_Start,autocast=CustomGlow.AutoCastGlow_Start,blizzard=CustomGlow.ButtonGlow_Start}
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'visual',function(api)
        if not equal(raw(addon,'Glow'),ownedGlow) or not equal(raw(addon,'Fetch'),ownedFetch) then return end
        for name,method in nextKey,starts do
            local key=name=='pixel' and 'PixelGlow_Start' or name=='autocast' and 'AutoCastGlow_Start' or 'ButtonGlow_Start'
            if not equal(raw(CustomGlow,key),method) then return end
        end
        local result={buttons=0,slots=0,logical=0,overlays=0,sequence=0,pixel=0,autocast=0,blizzard=0,proc=0,capped=false,callbacks={overlay=UpdateOverlay},ambiguous={}}
        if kind(api)~='table' or kind(raw(api,'GetParent'))~='function' or kind(raw(api,'IsVisible'))~='function' or kind(raw(api,'GetScript'))~='function' then result.unsupported=true;return result end
        local highlighted,seen={},{};local n=0
        for _,button in nextKey,Highlight do n=n+1;if n>128 then result.capped=true;break end;highlighted[button]=true end
        local function inspect(frame,button,name)
            result.slots=result.slots+1;if result.slots>512 then result.slots=512;result.capped=true;return end
            if kind(frame)~='table' or seen[frame] then return end
            local ok,parent=protect(api.GetParent,frame);if not ok or not equal(parent,button) then return end
            seen[frame]=true
            if name=='overlays' and raw(frame,'sequenceTimer')~=nil then result.sequence=result.sequence+1 end
            local visible,shown=protect(api.IsVisible,frame)
            if not visible then result.unsupported=true;return end
            if shown~=true then return end
            result[name]=result[name]+1
            if name=='overlays' or name=='proc' then return end
            local success,fn=protect(api.GetScript,frame,'OnUpdate')
            if not success or kind(fn)~='function' then return end
            if result.callbacks[name] and not equal(result.callbacks[name],fn) then result.callbacks[name]=nil;result.ambiguous[name]=true
            elseif not result.ambiguous[name] then result.callbacks[name]=fn end
        end
        for button,spell in nextKey,ButtonSpells do
            result.buttons=result.buttons+1;if result.buttons>128 then result.buttons=128;result.capped=true;break end
            if result.capped and result.slots>=512 then break end
            if kind(button)=='table' then
                local ids={}
                local glowing,flag=SpellsGlowing[spell],Flags[spell]
                if glowing and (glowing.itemId==nil or equal(glowing.itemId,ButtonItems[button])) then ids[#ids+1]='next' end
                if flag and (flag.itemId==nil or equal(flag.itemId,ButtonItems[button])) then ids[#ids+1]=spell end
                if highlighted[button] then ids[#ids+1]='highlight' end
                for _,id in nextKey,ids do
                    result.logical=result.logical+1
                    local overlays=raw(button,'rmOverlays');inspect(kind(overlays)=='table' and raw(overlays,id),button,'overlays')
                    local key=text(id)
                    inspect(raw(button,'_PixelGlow'..key),button,'pixel')
                    inspect(raw(button,'_AutoCastGlow'..key),button,'autocast')
                    inspect(raw(button,'_ProcGlow'..key),button,'proc')
                    if result.slots>=512 then result.capped=true;break end
                end
                if #ids>0 then inspect(raw(button,'_ButtonGlow'),button,'blizzard') end
            end
        end
        return result
    end) end
end
-- END CPU ACTIVITY HANDOFF
]====],
    },
}

local pins = {
    ["Diagnostics/cpu.lua"] = { 25671, "a6968fb2" },
    ["Core/spell_catalog.lua"] = { 5777, "eb332f95" },
    ["Core/reference_catalog.lua"] = { 7335, "7b3c6366" },
    ["buttons.lua"] = { 28024, "0d983d17" },
}

return function(text, path)
    if path == 'buttons.lua' then
        text = dofile('tests/fixtures/restore_overlay_animation_dirty.lua')(text, path)

        if text:find('local publishActivePresentation=', 1, true) then
            text = dofile('tests/fixtures/restore_active_runtime_plan.lua')(text, path)
        end
    end

    local pin = assert(pins[path], 'unknown retained-activity inverse path')

    for _, block in ipairs(blocks[path]) do
        local a, b = text:find(block, 1, true)
        assert(a, 'retained activity block changed: ' .. path)
        assert(not text:find(block, b + 1, true), 'duplicate retained activity block')
        text = text:sub(1, a - 1) .. text:sub(b + 1)
    end

    if path == 'Diagnostics/cpu.lua' then
        local from = " if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end"
        local to = " if not ok or not timer then if active==run then active=nil end;return false,'timer-error' end"
        local a, b = assert(text:find(from, 1, true))
        assert(not text:find(from, b + 1, true))
        text = text:sub(1, a - 1) .. to .. text:sub(b + 1)
    end

    local h = 0

    for i = 1, #text do
        h = (h * 33 + text:byte(i)) % 4294967296
    end

    assert(#text == pin[1] and string.format('%08x', h) == pin[2], 'unrelated retained-activity source delta: ' .. path)
    return text
end
