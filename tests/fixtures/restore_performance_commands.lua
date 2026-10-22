-- Exact cold CLI diagnostics successor -> Git7552 predecessor.
-- Construct the complete successor once; unknown bytes never normalize.
local rows={
["Diagnostics/cpu.lua"]={before=([==[~local addon_name,addon=...
-- Opt-in cumulative snapshots. No functions are wrapped and shared counters are
-- never reset. Only this module's one completion timer exists during capture.
local active,lastReport
-- Fixed, source-free proof snapshots. The installer is retired by main;
-- this reader is private and is never invoked outside capture boundaries.
local proofType,proofRawget,proofPcall=type,rawget,pcall
-- BEGIN PRIVATE CACHE ANCHORS
local cacheSourceEqual=rawequal
local cacheSourceModules=proofRawget(addon,'builtinSourceModules')
local cacheSourceGetter=proofType(cacheSourceModules)=='table' and proofRawget(cacheSourceModules,'Functions/cache.lua') or nil
-- END PRIVATE CACHE ANCHORS
local executionIndexDiagnostic
function addon:BindCPUExecutionIndexDiagnostic(provider)
 if self~=addon or executionIndexDiagnostic or proofType(provider)~="function" then return end
 executionIndexDiagnostic=provider;addon.BindCPUExecutionIndexDiagnostic=nil
end
local proofReasons={}
for _,reason in ipairs({"ready","unbound","namespace","capability","env","method","public-env","finite-env","diagnostic-env","raw-type","raw-pairs","raw-ipairs","raw-getmetatable","raw-getfenv","raw-math","raw-table","math-huge","math-max","table-sort","portable-proof","child-env","location-env","failure-env","identifier-env","dense-env","parser-match-unavailable","parser-sub-unavailable","owner","db","profile","index-reader"}) do proofReasons[reason]=true end
local proofOwners={"main","sequence","portable","index"}
local proofRawKeys={"type","pairs","ipairs","getmetatable","getfenv","math","table"}
local function executionIndexProof()
 if not executionIndexDiagnostic then return "probe-unavailable" end
 local ok,text=proofPcall(function()
  local status=executionIndexDiagnostic()
  if proofType(status)~="table" then return "probe-unavailable" end
  local parts={}
  for i=1,4 do
   local name=proofOwners[i];local row=proofRawget(status,name)
   local reason=proofType(row)=="table" and proofRawget(row,"reason") or nil
   reason=proofType(reason)=="string" and proofRawget(proofReasons,reason) and reason or "unavailable"
   local part=name.."="..reason
   if reason~="ready" and name~="main" then
    local flags=proofType(row)=="table" and proofRawget(row,"raw") or nil
    part=part.."["
    for keyIndex=1,7 do
     local key=proofRawKeys[keyIndex]
     if name~="sequence" or key=="type" or key=="ipairs" or key=="getfenv" then
      local flag=proofType(flags)=="table" and proofRawget(flags,key)
      part=part..key.."="..(flag==true and "1" or flag==false and "0" or "?").."," end
    end
    part=part.."]"
   end
   parts[i]=part
  end
  local function parserFlag(owner,key)
   local row=proofRawget(status,owner)
   local value=proofType(row)=="table" and proofRawget(row,key)
   return value==true and "1" or value==false and "0" or "?"
  end
  return parts[1].."; "..parts[2].."; "..parts[3].."; "..parts[4].."; parser-match="..parserFlag("index","parserMatch").."; parser-sub="..parserFlag("portable","parserSub")
 end)
 return ok and text or "probe-unavailable"
end
local function appendExecutionIndexProof(report,started,ended)
 local bytes=#report-1
 for i=1,#report do bytes=bytes+#report[i] end
 local first="Execution index proof start: "..(started or "probe-unavailable")
 local last="Execution index proof end: "..ended
 if bytes+1+#first+1+#last<16000 then
  report[#report+1]=first;report[#report+1]=last
 else
  local omitted="Execution index proof omitted to keep report bounded."
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
local MAX_FUNCTIONS,MAX_SCAN,TOP=384,512,20
local runtimeNames={
 'EvaluateNextAction','EvaluateNextActionInternal','UpdateCurrentCondition','Fetch','UpdateBagContents',
 'GetRotationOwnerContext','GetRotationContext','GetRotationValidationStamp','GetRotationValidationOptions',
 'AcquireRotationRuntimePass','GetRuntimeRotations','GetRuntimeRotation','GetRotationCandidates',
 'EvaluateRotationSequence','rotationValidConditions','evaluateConditionResult','validateCondition',
 'NewActionReadiness','GetConditionUnitLevel','GetConditionPointResource','GetClassGroupCount','EvaluateItemCondition',
 'RefreshPreviewWindow','RemoveAllCurrentGlows','DestroyAllGlows','RefreshMacroButtons','UpdateButtonGlow','GlowNextSpell','GlowSpell','GlowCooldown','IsGlowing','FindSpell','GetSpellIds','RefreshSpellCatalog',
}
local platformNames={}
for name in ([[AuraRemaining CanReadValue GetAPISurface GetAnnouncementGroup GetAssistedAvailability GetAuraByIndex GetBagItemCounts GetBagSnapshot GetClientInfo GetGlobalCooldown GetGlyphItemInfo GetGlyphSocketSnapshot GetGridTalentInfo GetGroupMembership GetInstanceObservation GetItemCooldown GetItemCount GetItemDisplayInfo GetItemID GetItemInfoInstant GetItemMetadata GetItemRangeState GetItemUseSpell GetLossOfControlCount GetLossOfControlEvent GetMobInfo2Observation GetMacroAction GetNameplateMaxDistance GetPetObservation GetPlayerFlagObservation GetPlayerFormObservation GetPlayerMovementObservation GetPlayerOwnerClassObservation GetPrimaryTalentTree GetRangeCheckBounds GetRosterClassObservation GetRotationSpecialization GetRotationSpecializations GetRuneCooldownObservation GetRuneEvaluationTime GetRuneTypeObservation GetSpellBookSnapshot GetSpellCharges GetSpellCooldown GetSpellInfo GetSpellLink GetSpellRangeState GetTalentLayout GetTalentTreeCount GetTalentTreeInfo GetTotemInfo GetTotemSlotCount GetTreeTalentCount GetTreeTalentInfo GetUnitAttackabilityObservation GetUnitCastObservation GetUnitFlagObservation GetUnitHealthObservation GetUnitIdentityObservation GetUnitLevelObservation GetUnitMetadataObservation GetUnitPointIdentityObservation GetUnitPointPowerObservation GetUnitPowerObservation GetUnitThreatObservation GetZonePVPObservation IsAutoRepeatActive IsBeyondMeleeRange IsCurrentSpell IsItemEquipped IsItemLevelAllowed IsItemReady IsMeleeAttackNeeded IsSpellKnown IsSpellReady IsSpellUsable NewSpellRangeReader ReadAuraField SendAnnouncementChat]]):gmatch('%S+') do platformNames[#platformNames+1]=name end
local function readable(value)
 if type(issecretvalue)=='function' then local ok,secret=pcall(issecretvalue,value);if not ok or secret then return false end end
 if type(canaccessvalue)=='function' then local ok,allowed=pcall(canaccessvalue,value);if not ok or not allowed then return false end end
 return true
end
-- BEGIN COLD STORE STRING SHAPE
-- Current observations only: cached constructor identities/admission stay private.
local function storeStringShape()
 local ok,text=proofPcall(function()
  local meta=getmetatable('');if not readable(meta) then return 'unavailable' end
  local index;if proofType(meta)=='table' then index=proofRawget(meta,'__index') end
  if not readable(index) then return 'unavailable' end
  local find;if proofType(index)=='table' then find=proofRawget(index,'find') end
  if not readable(find) then return 'unavailable' end
  local repeated=getmetatable('');if not readable(repeated) then return 'unavailable' end
  local repeatedIndex;if proofType(repeated)=='table' then repeatedIndex=proofRawget(repeated,'__index') end
  if not readable(repeatedIndex) then return 'unavailable' end
  return 'meta='..proofType(meta)..'; index='..proofType(index)..'; raw-find='..proofType(find)
   ..'; repeat-meta='..(cacheSourceEqual(meta,repeated) and '1' or '0')
   ..'; repeat-index='..(cacheSourceEqual(index,repeatedIndex) and '1' or '0')
 end)
 return ok and text or 'unavailable'
end
local function appendStoreStringShape(report,started,ended)
 local lines={'Store string shape start: '..(started or 'unavailable'),'Store string shape end: '..ended,
  'Necessary shape only: table/table/function and stable reads; does not prove private-store use or cached factory identities/admission.'}
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Store string shape omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END COLD STORE STRING SHAPE
local function finite(value) return readable(value) and type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
local function counter(value,integer) return finite(value) and value>=0 and (not integer or value%1==0) end
local function field(owner,key) if type(owner)=='table' then return rawget(owner,key) end end
local function addonCPUAPI(name,legacy)
 local candidate=field(C_AddOns,name)
 if type(candidate)=='function' then return candidate end
 if type(legacy)=='function' then return legacy end
end
local function totalAPI() return addonCPUAPI('GetAddOnCPUUsage',GetAddOnCPUUsage) end
local function updateAPI() return addonCPUAPI('UpdateAddOnCPUUsage',UpdateAddOnCPUUsage) end
local function cvarAPI() return type(GetCVar)=='function' and GetCVar or type(C_CVar)=='table' and type(C_CVar.GetCVar)=='function' and C_CVar.GetCVar or nil end
local function enabled(fn)
 if type(fn)~='function' then return false,'missing-script-profile-api' end
 local ok,value=pcall(fn,'scriptProfile');if not ok then return false,'script-profile-query-error' end
 if not readable(value) then return false,'restricted-script-profile' end
 if value=='0' then return false,'script-profile-disabled' end
 if value~='1' then return false,'invalid-script-profile-result' end
 return true
end
local function clockAPI() return type(GetTimePreciseSec)=='function' and GetTimePreciseSec or type(GetTime)=='function' and GetTime or nil end
local function clock(fn)
 if type(fn)~='function' then return nil,'missing-clock-api' end
 local ok,value=pcall(fn);if not ok then return nil,'clock-error' end
 if not counter(value) then return nil,'invalid-clock' end
 return value
end
local function total(run)
 local ok=pcall(run.update);if not ok then return nil,'addon-cpu-update-error' end
 local good,value=pcall(run.total,addon_name);if not good then return nil,'addon-cpu-query-error' end
 if not counter(value) then return nil,'invalid-addon-cpu-counter' end
 return value
end
local function snapshot(run,fn)
 local ok,exclusive,calls=pcall(run.query,fn,false)
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 local good,inclusive,inclusiveCalls=pcall(run.query,fn,true)
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function visibility(owner)
 local frame=field(owner,'frame') or owner
 local method=type(frame)=='table' and frame.IsShown
 if type(method)~='function' then return nil end
 local ok,shown=pcall(method,frame);if ok and readable(shown) and type(shown)=='boolean' then return shown end
end
local function context(owner)
 local config=visibility(field(owner,'configWindow'));local dialog=visibility(field(owner,'nativeCustomConditionDialog'))
 if dialog==true then config=true end
 local combat='unavailable';if type(InCombatLockdown)=='function' then local ok,value=pcall(InCombatLockdown);if ok and readable(value) and type(value)=='boolean' then combat=tostring(value) end end
 local profile=field(field(owner,'db'),'profile')
 local function interval(key) local value=field(profile,key);if finite(value) or readable(value) and type(value)=='boolean' then return tostring(value) end;return 'unavailable' end
 local result='config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
 -- BEGIN CACHE MODE CONTEXT
 local mode=field(owner,'GetCacheDiagnosticMode')
 if type(mode)=='function' then
  local ok,loaded,requested,pending=pcall(mode,owner)
  local function known(value) return readable(value) and type(value)=='string' and (value=='cached' or value=='direct') end
  if ok and known(loaded) and known(requested) and readable(pending) and type(pending)=='boolean' then
   result=result..' observation-cache='..loaded..' requested='..requested..' reload='..tostring(pending)
  else result=result..' observation-cache=unavailable' end
 end
 return result
 -- END CACHE MODE CONTEXT
end
-- BEGIN STANDALONE PREVIEW CONTEXT
-- Canonical-slot observation only; this does not authenticate foreign frames.
local previewNumbers={[0]='0','1','2','3','4','5'}
local function standalonePreviewContext(owner)
 local ok,text=pcall(function()
  local selected,canonical=field(owner,'nextWindow'),field(owner,'nativePreviewWindow')
  if not readable(selected) then return 'selected=unavailable' end
  if selected==nil then return 'selected=none' end
  local marker=field(selected,'nativePreview')
  if not readable(canonical) or not readable(marker) then return 'selected=unavailable' end
  if type(selected)~='table' or not rawequal(selected,canonical) or marker~=true then return 'selected=custom' end
  local db=field(owner,'db');local profile=field(db,'profile');local frame=field(selected,'frame')
  local activeValue,count,slots,windowProfile=field(selected,'active'),field(selected,'count'),field(selected,'slots'),field(selected,'profile')
  local setting,generation=field(profile,'preview_spells'),field(selected,'generation')
  local capture=active
  local function current()
   return active==capture and rawequal(field(owner,'nextWindow'),selected) and rawequal(field(owner,'nativePreviewWindow'),canonical)
    and rawequal(field(owner,'db'),db) and rawequal(field(db,'profile'),profile) and rawequal(field(selected,'frame'),frame)
    and rawequal(field(selected,'nativePreview'),marker) and rawequal(field(selected,'active'),activeValue)
    and rawequal(field(selected,'count'),count) and rawequal(field(selected,'slots'),slots)
    and rawequal(field(selected,'profile'),windowProfile) and rawequal(field(profile,'preview_spells'),setting)
    and rawequal(field(selected,'generation'),generation)
  end
  local function number(value)
   if readable(value) and type(value)=='number' and value==value and value>=0 and value<=5 and value%1==0 then return previewNumbers[value] end
   return '?'
  end
  local function boolean(value)
   if readable(value) and type(value)=='boolean' then return value and '1' or '0' end
   return '?'
  end
  local shown='?'
  if readable(frame) and type(frame)=='table' then
   local valid,value=pcall(function()
    local method=frame.IsShown
    if readable(method) and type(method)=='function' and current() then return method(frame) end
   end)
   if valid then shown=boolean(value) end
  end
  local sameProfile='?'
  if readable(profile) and readable(windowProfile) and type(profile)=='table' and type(windowProfile)=='table' then
   sameProfile=rawequal(profile,windowProfile) and 'current' or 'different'
  end
  local result='selected=canonical shown='..shown..' active='..boolean(activeValue)..' setting='..number(setting)
   ..' slots='..number(slots)..' recommendations='..number(count)..' profile='..sameProfile
  -- A getter or visibility method may retire/rebind this surface mid-snapshot.
  if not current() then return 'selected=unavailable' end
  return result
 end)
 return ok and text or 'selected=unavailable'
end
local function appendStandalonePreviewContext(report,started,ended)
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local first='Standalone preview start: '..(started or 'selected=unavailable')
 local last='Standalone preview end: '..ended
 if bytes+1+#first+1+#last<16000 then report[#report+1]=first;report[#report+1]=last
 else
  local omitted='Standalone preview context omitted to keep report bounded.'
  if bytes+1+#omitted<16000 then report[#report+1]=omitted end
 end
end
-- END STANDALONE PREVIEW CONTEXT
local function reference(owner,...)
 local keys={...}
 return function() local value=owner;for _,key in ipairs(keys) do value=field(value,key) end;return value end
end
local function definitionsOf(owner) return field(owner,'conditionDefinitions') or field(owner,'definitions') end
local function conditionReference(owner,key,callback)
 return function() return field(field(definitionsOf(owner),key),callback) end
end
local function selectFunctions(owner)
 local rows,seen,validationRows={},{},{};local truncated=false
 local function add(container,key,label,resolve)
  local fn=field(container,key);if type(fn)~='function' then return end
  resolve=resolve or reference(container,key)
  local previous=seen[fn]
  if previous then previous.refs[#previous.refs+1]=resolve;return previous end
  if #rows>=MAX_FUNCTIONS then truncated=true;return end
  local row={fn=fn,label=label,refs={resolve}};seen[fn]=row;rows[#rows+1]=row;return row
 end
 for _,name in ipairs(runtimeNames) do add(owner,name,'Runtime.'..name) end
 for _,name in ipairs(platformNames) do add(field(owner,'Platform'),name,'Platform.'..name,reference(owner,'Platform',name)) end
 for _,entry in ipairs({{'RotationData','IndexRotationSteps'},{'RotationData','CheckPortable'},{'SpellCatalog','GetAllSpellIds'},{'SpellCatalog','GetSpellId'}}) do
  local row=add(field(owner,entry[1]),entry[2],entry[1]..'.'..entry[2],reference(owner,entry[1],entry[2]))
  if entry[2]=='IndexRotationSteps' then validationRows.IndexRotationSteps=row end
 end
 for _,name in ipairs({'ValidateEnvelope','ValidateBody'}) do validationRows[name]=add(field(owner,'RotationData'),name,'RotationData.'..name,reference(owner,'RotationData',name)) end
 local functions=field(owner,'Functions');local cache=field(functions,'cache');add(cache,'getCached','Functions.cache.getCached',reference(owner,'Functions','cache','getCached'));add(cache,'getRetryCached','Functions.cache.getRetryCached',reference(owner,'Functions','cache','getRetryCached'))
 local definitions=definitionsOf(owner);local catalog=field(field(owner,'BuiltinSourceCatalog'),'conditions');local keys={};local scanned=0
 if type(definitions)=='table' then for key in pairs(definitions) do
  scanned=scanned+1;if scanned>MAX_SCAN then truncated=true;break end
  if readable(key) and type(key)=='string' then keys[#keys+1]=key end
 end end
 table.sort(keys,function(a,b)
  local aBuiltin=type(field(catalog,a))=='table';local bBuiltin=type(field(catalog,b))=='table'
  if aBuiltin~=bBuiltin then return aBuiltin end;return a<b
 end)
 local custom=0
 for _,key in ipairs(keys) do
  local definition=field(definitions,key);local label
  if type(field(catalog,key))=='table' and #key<=64 and key:match('^[A-Z][A-Z_0-9]*$') then label='Condition.'..key
  else custom=custom+1;label='Condition.custom'..custom end
  add(definition,'evaluate',label..'.evaluate',conditionReference(owner,key,'evaluate'));add(definition,'valid',label..'.valid',conditionReference(owner,key,'valid'))
 end
 return rows,truncated,validationRows
end
-- BEGIN PRIVATE CACHE SAMPLES
local function cacheFunction(owner,alias)
 if proofType(cacheSourceModules)~='table' or proofType(cacheSourceGetter)~='function' then return nil,'source-reader-unavailable' end
 if not cacheSourceEqual(owner,addon) or not cacheSourceEqual(proofRawget(owner,'builtinSourceModules'),cacheSourceModules)
  or not cacheSourceEqual(proofRawget(cacheSourceModules,'Functions/cache.lua'),cacheSourceGetter) then return nil,'source-reader-changed' end
 local ok,fn=proofPcall(cacheSourceGetter,alias)
 if not ok then return nil,'source-reader-error' end
 if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 return fn
end
local function privateCacheSelection(owner,rows)
 local result={views={},samples={}};local seen={}
 for _,row in ipairs(rows) do seen[row.fn]=row end
 for _,alias in ipairs({'getCachedInternal','packResults'}) do
  local fn,reason=cacheFunction(owner,alias)
  local view={alias=alias,label='Functions.cache.'..alias,reason=reason};result.views[#result.views+1]=view
  if fn then
   local sample=seen[fn]
   if not sample then
    if #rows+#result.samples>=MAX_FUNCTIONS then view.reason='selection-limit'
    else sample={fn=fn};seen[fn]=sample;result.samples[#result.samples+1]=sample end
   end
   view.sample=sample
  end
 end
 return result
end
-- BEGIN PRIVATE VALIDATION SCOPES
local validationEqual,validationSelect=rawequal,select
local validationSpecs={
 {name='references',anchor='GetRotationValidationStamp',slots={'observe','sameEntries','sameItemsets','proofGlobals'}},
 {name='library',anchor='InitializeRotationLibrary',slots={'ensure','eligible'}},
 {name='scope',anchor='BindRotationProfile',slots={'same'}},
}
local validationGroups,validationClosed,validationCount,validationCapture={},false,0,nil
local validationInstaller
local function validationRetire()
 validationClosed=true
 if validationEqual(proofRawget(addon,'BindCPUValidationScopeDiagnostic'),validationInstaller) then addon.BindCPUValidationScopeDiagnostic=nil end
end
validationInstaller=function(self,name,anchor,reader)
 if validationClosed or not validationEqual(self,addon) or proofType(name)~='string'
  or proofType(anchor)~='function' or proofType(reader)~='function' or validationGroups[name] then return false end
 local found
 for _,spec in ipairs(validationSpecs) do if name==spec.name then found=true;break end end
 if not found then return false end
 validationGroups[name]={anchor=anchor,reader=reader};validationCount=validationCount+1
 if validationCount==3 then validationRetire() end
 return true
end
addon.BindCPUValidationScopeDiagnostic=validationInstaller
local function validationClear(run)
 local state=run.validationScopes
 if state then state.phase='retired' end
 run.validationScopes=nil
 if validationCapture==run then validationCapture=nil end
end
local function validationEnding(run,status)
 if status~='complete' then validationClear(run)
 elseif run.validationScopes then run.validationScopes.phase='end' end
end
local function validationTuple(...) return {n=validationSelect('#',...),...} end
local function validationSnapshot(run,fn,current)
 if not current() then return nil,'capture-retired' end
 local ok,exclusive,calls=proofPcall(run.query,fn,false)
 if not current() then return nil,'capture-retired' end
 if not ok then return nil,'function-cpu-query-error' end
 if not counter(exclusive) or not counter(calls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 local good,inclusive,inclusiveCalls=proofPcall(run.query,fn,true)
 if not current() then return nil,'capture-retired' end
 if not good then return nil,'function-cpu-query-error' end
 if not counter(inclusive) or not counter(inclusiveCalls,true) then return nil,'invalid-function-cpu-counter' end
 if not current() then return nil,'capture-retired' end
 return {exclusive=exclusive,inclusive=inclusive,calls=calls,inclusiveCalls=inclusiveCalls}
end
local function validationFunctions(run,spec,group,current)
 if not current() then return nil,'capture-retired' end
 if not validationEqual(run.owner,addon) then return nil,'owner-changed' end
 if not group then return nil,'unbound' end
 local anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 local values=validationTuple(proofPcall(group.reader))
 if not current() then return nil,'capture-retired' end
 if not values[1] then return nil,'provider-unavailable' end
 if values.n~=#spec.slots+1 then return nil,'invalid-source-function' end
 for i=1,#spec.slots do
  local fn=values[i+1]
  if not readable(fn) or proofType(fn)~='function' then return nil,'invalid-source-function' end
 end
 anchor=proofRawget(addon,spec.anchor)
 if not readable(anchor) or not validationEqual(anchor,group.anchor) then return nil,'owner-changed' end
 if not current() then return nil,'capture-retired' end
 return values
end
local function validationStart(run)
 if active~=run then return end
 local state={phase='start',views={},samples={},groups={}}
 run.validationScopes=state;validationCapture=run
 state.current=function()
  return validationCapture==run and run.validationScopes==state
   and (state.phase=='start' and active==run or state.phase=='end' and active==nil)
 end
 local seen,total={},0
 local function remember(row) if not seen[row.fn] then seen[row.fn]=row;total=total+1 end end
 for _,row in ipairs(run.rows) do remember(row) end
 for _,row in ipairs(run.privateCache.samples) do remember(row) end
 for _,row in ipairs(run.activity and run.activity.samples or {}) do remember(row) end
 for _,spec in ipairs(validationSpecs) do
  local group=validationGroups[spec.name];local funcs,reason=validationFunctions(run,spec,group,state.current)
  local source={spec=spec,group=group};state.groups[#state.groups+1]=source
  for i,name in ipairs(spec.slots) do
   local view={label='Validation.'..spec.name..'.'..name,group=source,slot=i,reason=reason};state.views[#state.views+1]=view
   if funcs then
    local fn=funcs[i+1];view.fn=fn
    local sample=seen[fn]
    if not sample then
     if total>=MAX_FUNCTIONS then view.reason='selection-limit'
     else
      sample={fn=fn};seen[fn]=sample;total=total+1;state.samples[#state.samples+1]=sample
      sample.before,sample.reason=validationSnapshot(run,fn,state.current)
     end
    end
    view.sample=sample
   end
  end
 end
end
local function appendValidationScopes(report,run,sampleEnd)
 local state=run.validationScopes
 local lines={'Private validation scopes (native counters; shared functions overlap):'};local available=0
 if state then
  for _,source in ipairs(state.groups) do source.functions,source.reason=validationFunctions(run,source.spec,source.group,state.current) end
 end
 local index=0
 for _,spec in ipairs(validationSpecs) do for _,name in ipairs(spec.slots) do
  index=index+1;local view=state and state.views[index];local problem
  if view then problem=view.reason else problem='baseline-unavailable' end
  local sample,current
  if view and not problem then
   local source=view.group;problem=source.reason
   if not problem and not validationEqual(source.functions[view.slot+1],view.fn) then problem='function-replaced' end
   sample=view.sample;problem=problem or sample.reason
   if not problem then current,problem=sampleEnd(run,sample,state.current) end
   if not problem then
    for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<sample.before[key] then problem='function-cpu-counter-reset';break end end
   end
  end
  local exclusive,inclusive,calls
  if not problem then
   exclusive,inclusive,calls=current.exclusive-sample.before.exclusive,current.inclusive-sample.before.inclusive,current.calls-sample.before.calls
   if not finite(exclusive) or not finite(inclusive) or not counter(calls,true) then problem='invalid-function-cpu-delta' end
  end
  local label='Validation.'..spec.name..'.'..name
  lines[#lines+1]=problem and label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end end
 lines[#lines+1]=string.format('Fixed validation views: aliases=7; available=%d; unavailable=%d (excluded from rankings above).',available,7-available)
 lines[#lines+1]='Shared helper counters include all callers; inclusive scopes overlap, not additive.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private validation scopes omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE VALIDATION SCOPES
-- BEGIN RUNTIME WORK VIEWS
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
local function finishSample(run,row,guard)
 if not row.sampled then
  row.sampled=true
  if guard then row.current,row.currentReason=validationSnapshot(run,row.fn,guard)
  else row.current,row.currentReason=snapshot(run,row.fn) end
 end
 return row.current,row.currentReason
end
local function appendPrivateCache(report,run)
 local lines={'Private cache helpers (native counters; shared functions overlap):'}
 local available=0
 for _,view in ipairs(run.privateCache.views) do
  local sample,problem=view.sample,view.reason
  if not problem then
   local fn;fn,problem=cacheFunction(run.owner,view.alias)
   if not problem and not cacheSourceEqual(fn,sample.fn) then problem='function-replaced' end
   problem=problem or sample.reason
  end
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
  lines[#lines+1]=problem and view.label..' | unavailable: '..problem
   or string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s',view.label,exclusive,inclusive,tostring(calls))
  if not problem then available=available+1 end
 end
 lines[#lines+1]=string.format('Private helper views: aliases=2; available=%d; unavailable=%d (excluded from rankings above).',available,2-available)
 lines[#lines+1]='Shared helper counters include all callers, including archived copies; inclusive costs overlap.'
 local bytes=#report-1;for _,line in ipairs(report) do bytes=bytes+#line end
 local extra=#lines;for _,line in ipairs(lines) do extra=extra+#line end
 if bytes+extra<16000 then for _,line in ipairs(lines) do report[#report+1]=line end
 else local omitted='Private cache helpers omitted to keep report bounded.';if bytes+1+#omitted<16000 then report[#report+1]=omitted end end
end
-- END PRIVATE CACHE SAMPLES
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
local function activityEnsureAPI()
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
end
local function activityStart(run)
 addon.BindCPUActivityDiagnostic=nil
 run.activity={events={spell=0,item=0,unknown=0,available=false},views={},samples={}}
 local state=run.activity
 activityEnsureAPI()
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
local memoryActivityPrepared=false
-- Bounded detached cardinality for explicit lifetime diagnostics. Never return
-- private maps, native frames, callbacks or the activity reader functions.
function addon:GetRetainedMemoryDiagnostic()
 if self~=addon then return end
 if not memoryActivityPrepared then memoryActivityPrepared=true;activityEnsureAPI()end
 local observed=activityRead();local result={}
 for _,spec in ipairs({{'spell','spellIDs'},{'spell','spellNames'},{'item','itemRecords'},{'item','itemIndex'},{'item','itemBlocked'}}) do
  local value=field(field(observed,spec[1]),spec[2]);local n=field(value,'n');local capped=field(value,'capped')
  if counter(n,true)and n<=4096 and readable(capped)and proofType(capped)=='boolean'then result[spec[2]]=n;result[spec[2]..'Capped']=capped end
 end
 local visual=field(observed,'visual')
 if field(visual,'unsupported')~=true then
  for _,name in ipairs({'buttons','slots','logical','overlays','sequence','pixel','autocast','blizzard','proc'}) do
   local n=field(visual,name)
   if counter(n,true)and n<=4096 then result[name]=n;result[name..'Capped']=field(visual,'capped')==true end
  end
 end
 return result
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
local function finish(run,status,reason)
 if active~=run then return end
 -- BEGIN PRIVATE VALIDATION END TOKEN
 validationEnding(run,status)
 -- END PRIVATE VALIDATION END TOKEN
 -- BEGIN RUNTIME WORK END TOKEN
 workEnding(run,status)
 -- END RUNTIME WORK END TOKEN
 active=nil;run.timer=nil
 -- BEGIN CPU ACTIVITY STOP
 activityStop(run)
 -- END CPU ACTIVITY STOP
 local text
 if status=='complete' then
  local now,why=clock(run.clock);local elapsed=now and now-run.started
  if not elapsed or not finite(elapsed) or elapsed<=0 then status,reason='invalid',why or 'clock-reset' end
  if status=='complete' then
   local allowed,problem=enabled(run.cvar)
   if clockAPI()~=run.clock or cvarAPI()~=run.cvar or GetFunctionCPUUsage~=run.query or totalAPI()~=run.total or updateAPI()~=run.update then status,reason='invalid','profiling-api-changed'
   elseif not allowed then status,reason='invalid',problem end
  end
  local used,rate
  if status=='complete' then local value,problem=total(run);if value==nil or value<run.initialTotal then status,reason='invalid',problem or 'addon-cpu-counter-reset' else used=value-run.initialTotal;if not finite(used) then status,reason='invalid','invalid-addon-cpu-delta' end end end
  if status=='complete' then rate=used/elapsed;if not finite(rate) then status,reason='invalid','invalid-cpu-rate' end end
  if status=='complete' then
   -- BEGIN CPU ACTIVITY END
   if run.activity then run.activity.ended=activityRead() end
   -- END CPU ACTIVITY END
   local ranked,unavailable={},{}
   for _,row in ipairs(run.rows) do
    local problem=row.reason
    for _,ref in ipairs(row.refs) do if ref()~=row.fn then problem='function-replaced';break end end
    local current;if not problem then current,problem=finishSample(run,row) end
    if not problem then
     for _,key in ipairs({'exclusive','inclusive','calls','inclusiveCalls'}) do if current[key]<row.before[key] then problem='function-cpu-counter-reset';break end end
    end
    if not problem then
     local result={label=row.label,exclusive=current.exclusive-row.before.exclusive,inclusive=current.inclusive-row.before.inclusive,calls=current.calls-row.before.calls}
     if not finite(result.exclusive) or not finite(result.inclusive) or not counter(result.calls,true) then problem='invalid-function-cpu-delta' else ranked[#ranked+1]=result;row.deltaCalls=result.calls end
    end
    if problem then unavailable[#unavailable+1]={label=row.label,reason=problem} end
   end
   table.sort(ranked,function(a,b) if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;return a.label<b.label end)
   local report={'Rotation Master CPU profile: complete',string.format('duration=%.3f s; addon CPU=%.3f ms; addon rate=%.3f ms/s',elapsed,used,rate),
    'start '..run.context,'end '..context(run.owner),'States describe capture boundaries only; activity may change within the interval.',
    'Native cumulative counters include collection and profiling overhead. Inclusive rows overlap and are not additive.',
    'Rows are selected coverage, not complete CPU accounting; addon and function snapshot boundaries differ slightly.',
    string.format('selected=%d; available=%d; unavailable=%d; top=%d%s',#run.rows,#ranked,#unavailable,math.min(TOP,#ranked),run.truncated and '; selection truncated' or '')}
   local function validationCount(name)
    local row=run.validationRows[name]
    return row and row.deltaCalls~=nil and tostring(row.deltaCalls) or 'unavailable'
   end
   report[#report+1]='Structural validation calls: ValidateEnvelope='..validationCount('ValidateEnvelope')..'; ValidateBody='..validationCount('ValidateBody')..' (native counters; shared functions overlap).'
   report[#report+1]='Execution indexing calls: IndexRotationSteps='..validationCount('IndexRotationSteps')..' (native counter).'
   for index=1,math.min(TOP,#ranked) do local row=ranked[index];local mean=row.calls>0 and row.exclusive/row.calls or nil
    report[#report+1]=string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s | mean=%s ms',row.label,row.exclusive,row.inclusive,tostring(row.calls),mean and string.format('%.3f',mean) or 'unavailable')
   end
   for index=1,math.min(10,#unavailable) do local row=unavailable[index];report[#report+1]=row.label..' | unavailable: '..row.reason end
   if #unavailable>10 then report[#report+1]='Additional unavailable rows omitted.' end
   -- BEGIN INCLUSIVE CPU SCOPES
   -- Existing lines are complete before this second view of the same rows.
   local reportBytes=#report-1
   for _,line in ipairs(report) do reportBytes=reportBytes+#line end
   local title='Inclusive scopes (top 10; includes descendants; overlapping, not additive):'
   local omitted='Additional inclusive scopes omitted to keep report bounded.'
   if reportBytes+1+#title+1+#omitted<16000 then
    report[#report+1]=title;reportBytes=reportBytes+1+#title
    table.sort(ranked,function(a,b) if a.inclusive~=b.inclusive then return a.inclusive>b.inclusive end;if a.exclusive~=b.exclusive then return a.exclusive>b.exclusive end;return a.label<b.label end)
    for index=1,math.min(10,#ranked) do local row=ranked[index]
     local line=string.format('%s | inclusive=%.3f ms | exclusive=%.3f ms | calls=%s',row.label,row.inclusive,row.exclusive,tostring(row.calls))
     if reportBytes+1+#line+1+#omitted>=16000 then report[#report+1]=omitted;break end
     report[#report+1]=line;reportBytes=reportBytes+1+#line
    end
   end
   -- END INCLUSIVE CPU SCOPES
   -- BEGIN EXECUTION INDEX DIAGNOSTICS
   appendExecutionIndexProof(report,run.executionIndexProof,executionIndexProof())
   -- END EXECUTION INDEX DIAGNOSTICS
   -- BEGIN PRIVATE CACHE APPENDIX
   appendPrivateCache(report,run)
   -- END PRIVATE CACHE APPENDIX
   -- BEGIN CPU ACTIVITY APPENDIX
   appendActivity(report,run)
   -- END CPU ACTIVITY APPENDIX
   -- BEGIN STANDALONE PREVIEW APPENDIX
   appendStandalonePreviewContext(report,run.previewContext,standalonePreviewContext(run.owner))
   -- END STANDALONE PREVIEW APPENDIX
   -- BEGIN PRIVATE VALIDATION APPENDIX
   local validationState=run.validationScopes
   local validationEntered=validationState and validationState.current()
   appendValidationScopes(report,run,finishSample)
   if validationEntered and not validationState.current() then validationClear(run);return end
   -- END PRIVATE VALIDATION APPENDIX
   -- BEGIN RUNTIME WORK APPENDIX
   local workState=run.runtimeWork
   local workEntered=workState and workState.current()
   appendWorkViews(report,run,finishSample)
   if workEntered and not workState.current() then workClear(run);return end
   -- END RUNTIME WORK APPENDIX
   -- BEGIN COLD STORE STRING END
   local shapeEntered=workState and workState.current()
   appendStoreStringShape(report,run.storeStringShape,storeStringShape())
   if shapeEntered and not workState.current() then workClear(run);return end
   -- END COLD STORE STRING END
   text=table.concat(report,'\n')
  end
 end
 text=text or 'Rotation Master CPU profile: '..status..(reason and ' ('..reason..')' or '')
 -- BEGIN PRIVATE VALIDATION CLEANUP
 validationClear(run)
 -- END PRIVATE VALIDATION CLEANUP
 -- BEGIN RUNTIME WORK CLEANUP
 workClear(run)
 -- END RUNTIME WORK CLEANUP
 lastReport=text
 local callback=field(run.owner,'OnCPUProfileFinished');if type(callback)=='function' then pcall(callback,run.owner,text,status) end
end
function addon:StartCPUProfile(duration)
 -- BEGIN NATIVE RUNTIME EXCLUSION
 if type(self.IsCPURuntimeCaptureRunning)=='function' and self:IsCPURuntimeCaptureRunning() then return false,'native-runtime-capture-running' end
 -- END NATIVE RUNTIME EXCLUSION
 -- BEGIN PRIVATE VALIDATION RETIRE
 validationRetire()
 -- END PRIVATE VALIDATION RETIRE
 -- BEGIN RUNTIME WORK RETIRE
 workRetire()
 -- END RUNTIME WORK RETIRE
 if active then return false,'already-running' end
 if duration==nil then duration=10 end
 if not finite(duration) or duration<1 or duration>60 then return false,'invalid-duration' end
 local cvar=cvarAPI();local allowed,reason=enabled(cvar);if not allowed then return false,reason end
 if type(GetFunctionCPUUsage)~='function' then return false,'missing-function-cpu-api' end
 if not totalAPI() or not updateAPI() then return false,'missing-addon-cpu-api' end
 if type(self.ScheduleTimer)~='function' or type(self.CancelTimer)~='function' then return false,'missing-timer-api' end
 local run={owner=self,query=GetFunctionCPUUsage,total=totalAPI(),update=updateAPI(),clock=clockAPI(),cvar=cvar,duration=duration,cancel=self.CancelTimer}
 run.started,reason=clock(run.clock);if run.started==nil then return false,reason end
 run.initialTotal,reason=total(run);if run.initialTotal==nil then return false,reason end
 run.rows,run.truncated,run.validationRows=selectFunctions(self);run.context=context(self)
 local available=0
 for _,row in ipairs(run.rows) do row.before,row.reason=snapshot(run,row.fn);if row.before then available=available+1 end end
 if available==0 then return false,'function-cpu-unavailable' end
 -- BEGIN PRIVATE CACHE START
 run.privateCache=privateCacheSelection(self,run.rows)
 for _,sample in ipairs(run.privateCache.samples) do sample.before,sample.reason=snapshot(run,sample.fn) end
 -- END PRIVATE CACHE START
 active=run
 -- BEGIN CPU ACTIVITY START
 local activityOK=proofPcall(activityStart,run)
 if not activityOK then activityStop(run);run.activity=nil end
 -- END CPU ACTIVITY START
 -- BEGIN PRIVATE VALIDATION START
 local validationEntered=active==run
 validationStart(run)
 if validationEntered and active~=run then validationClear(run);return true end
 -- END PRIVATE VALIDATION START
 -- BEGIN RUNTIME WORK START
 local workEntered=active==run
 workStart(run)
 if workEntered and active~=run then workClear(run);return true end
 -- END RUNTIME WORK START
 local ok,timer=pcall(self.ScheduleTimer,self,function() finish(run,'complete') end,duration)
 -- BEGIN PRIVATE VALIDATION TIMER FAILURE
 if not ok or not timer then validationClear(run) end
 -- END PRIVATE VALIDATION TIMER FAILURE
 -- BEGIN RUNTIME WORK TIMER FAILURE
 if not ok or not timer then workClear(run) end
 -- END RUNTIME WORK TIMER FAILURE
 if not ok or not timer then if active==run then active=nil end;activityStop(run);return false,'timer-error' end
 run.timer=timer;if active==run then run.executionIndexProof=executionIndexProof() end;lastReport=nil
 -- BEGIN STANDALONE PREVIEW START
 if active==run then run.previewContext=standalonePreviewContext(self) end
 -- END STANDALONE PREVIEW START
 -- BEGIN COLD STORE STRING START
 if active==run then
  run.storeStringShape=storeStringShape()
  if active~=run then return true end
 end
 -- END COLD STORE STRING START
 return true
end
function addon:CancelCPUProfile()
 local run=active;if not run then return false,'not-running' end
 if run.timer then pcall(run.cancel,run.owner,run.timer) end
 finish(run,'cancelled');return true
end
function addon:IsCPUProfileRunning() return active~=nil end
function addon:GetCPUProfileReport()
 if active then return string.format('Rotation Master CPU profile: running (requested %.3f s)',active.duration) end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
-- AceAddon invokes this before AceTimer retires the addon's embedded timers.
-- The ordinary rotation enable/disable toggle remains independent of capture.
function addon:OnDisable()
 -- BEGIN NATIVE RUNTIME DISABLE
 if type(self.CancelCPURuntimeCapture)=='function' then self:CancelCPURuntimeCapture() end
 -- END NATIVE RUNTIME DISABLE
 self:CancelCPUProfile()
 if type(self.IsMemoryCaptureRunning)=='function' and self:IsMemoryCaptureRunning()
  and type(self.StopMemoryCapture)=='function' then self:StopMemoryCapture() end
 if type(self.ClearCastCaptureForDisable)=='function' then self:ClearCastCaptureForDisable() end
end
]==]):sub(2),edits={{50085,50084,([==[~'..(run.stopRequested and 'stopped' or ']==]):sub(2)},{50094,50093,([==[~)]==]):sub(2)},{54669,54668,([==[~if status=='complete'and run.stopRequested then status='stopped'end
 ]==]):sub(2)},{58131,58130,([==[~StopCPUProfile()
 local run=active;if not run then return false,'not-running'end
 local timer=run.timer;run.stopRequested=true
 finish(run,'complete')
 if timer then pcall(run.cancel,run.owner,timer)end
 return true
end
function addon:]==]):sub(2)}}},
["Diagnostics/cpu_runtime.lua"]={before=([==[~local addon_name,addon=...
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
  'Requested=10 s; actual='..(run.duration and string.format('%.3f s',run.duration)or 'unavailable')..'; max dispatches=512; measured='..run.measured..'; unmeasured nested='..run.nested,
  'poll start='..run.poll,
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
 run.selectionEnd=selectedKey()
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
 if at>=run.started+10 then finish(run,'complete');return run.original(self,...)end
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
 if duration~=nil and duration~=10 then return false,'invalid-duration'end
 local original=rawget(addon,'EvaluateNextAction');local cumulative=rawget(addon,'IsCPUProfileRunning')
 local schedule,cancel=rawget(addon,'ScheduleTimer'),rawget(addon,'CancelTimer')
 local clock=rawget(_G,'GetTimePreciseSec')or rawget(_G,'GetTime')
 if type(original)~='function'or type(cumulative)~='function'or type(schedule)~='function'or type(cancel)~='function'or type(clock)~='function'then return false,'missing-runtime-api'end
 local run={phase='starting',poll='unavailable',original=original,cancel=cancel,clock=clock,measured=0,nested=0,elapsed=0,maximum=0,allocated=0,deallocated=0}
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
 run.started=now(run);run.poll=poll();run.selectionStart=selectedKey()
 diagnosticStart(run)
 if active~=run then return false,'capture-retired'end
 phasePrepare(run)
 if active~=run then return false,'capture-retired'end
 if not run.started or not providerCurrent(run)or not rawequal(rawget(addon,'EvaluateNextAction'),original)or not rawequal(rawget(addon,'IsCPUProfileRunning'),cumulative)then return reject('capture-changed')end
 run.wrapper=function(...)return dispatch(run,...)end
 local accepted,timer=pcall(schedule,addon,function()finish(run,'complete')end,10)
 if active~=run then if accepted and timer then pcall(cancel,addon,timer)end;return false,'capture-retired'end
 if not accepted or not timer then return reject('timer-error')end
 run.timer=timer
 if not providerCurrent(run)or not rawequal(rawget(addon,'EvaluateNextAction'),original)or not rawequal(rawget(addon,'IsCPUProfileRunning'),cumulative)then finish(run,'invalid','capture-changed');return false,'capture-changed'end
 addon.EvaluateNextAction=run.wrapper;run.phase='running';phaseInstall(run);decisionInstall(run);lastReport=nil
 return true
end
function addon:CancelCPURuntimeCapture()
 if not rawequal(self,addon)then return false,'invalid-owner'end
 if not active then return false,'not-running'end
 finish(active,'cancelled');return true
end
function addon:IsCPURuntimeCaptureRunning()return active~=nil end
function addon:GetCPURuntimeCaptureReport()
 if active then return 'Rotation Master native runtime capture: running (requested 10 s; all normal evaluator dispatches)'end
 if lastReport then return lastReport end
 return nil,'not-captured'
end
]==]):sub(2),edits={{12446,12447,([==[~'..string.format('%g',run.requested)..']==]):sub(2)},{15838,15839,([==[~run.requested]==]):sub(2)},{18317,18317,([==[~=]==]):sub(2)},{18323,18323,([==[~the]==]):sub(2)},{18325,18325,([==[~]==]):sub(2)},{18335,18335,([==[~]==]):sub(2)},{18338,18337,([==[~0 end
 if not finite(duration)or duration<1 or duration>6]==]):sub(2)},{18846,18845,([==[~,requested=duration]==]):sub(2)},{20344,20345,([==[~duration]==]):sub(2)},{20917,20916,([==[~StopCPURuntimeCapture()
 if not rawequal(self,addon)then return false,'invalid-owner'end
 if not active then return false,'not-running'end
 finish(active,'stopped');return true
end
function addon:]==]):sub(2)},{21235,21234,([==[~string.format(]==]):sub(2)},{21295,21296,([==[~%g]==]):sub(2)},{21334,21333,([==[~,active.requested)]==]):sub(2)}}},
["Diagnostics/memory.lua"]={before=([==[~local addon_name,addon=...
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
  'addonKiB boundary start='..amount(run.startAddonKB)..'; end='..amount(run.endAddonKB)..' (explicit refresh results; unavailable if missing, failed or not requested)',
  format('Sampler overhead total=%s ms; max=%s ms; failed samples=%d. Timings include instrumentation, unadjusted.',amount(run.overhead),amount(run.overheadMax),run.failedSamples)..' Timed sampler bodies='..run.timedSamples..'.',
  'Counts are keys/rows, not bytes; >= marks a bounded lower limit. Missing or restricted observations are unavailable.',
  'Heap precedes each attribution refresh. CPU/runtime flags describe detailed boundaries only; overlapping instrumentation can affect memory.',
  'Attribution refreshes occur only at capture start/end. Intermediate addonKiB is cached with unknown age; other addons may refresh it.',
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
  local text=format('t=%s s heapKiB=%s addonKiB=%s fresh=%s scanMs=%s',amount(row.t),amount(row.heap),amount(row.addonKB),row.fresh and'yes'or'no',amount(row.scanMs))..' attribution='..row.attribution..' age='..(row.fresh and'0'or'unknown')..' cpu='..row.cpu..' runtime='..row.runtime..' WTM/RMspikes='..(storedNumber(row.wtmSpikes)and format('%.0f',row.wtmSpikes)or'unavailable')..' WTMlastSpikeT='..amount(row.wtmLast)
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
local function detail(run,at,heap,refresh)
 local row={t=at-run.started,heap=heap,fresh=false,attribution='unavailable',wtmSpikes=run.wtmCount}
 if run.wtmLast and run.wtmLast>=run.started then row.wtmLast=run.wtmLast-run.started end
 if kind(run.update)=='function'and kind(run.memory)=='function'then
  if refresh then
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
  if row.fresh then row.attribution='refreshed';run.scanOK=run.scanOK+1 else run.scanFailed=run.scanFailed+1 end
  else
   row.addonKB=callNumber(run,run.memory,addon_name)
   if row.addonKB~=nil then row.attribution='cached' end
   if not current(run)then return end
  end
 end
 if refresh then
  if run.finalDetail then run.endAddonKB=row.addonKB else run.startAddonKB=row.addonKB end
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
  local freshTick=run.lastAt==nil or at>run.lastAt
  if freshTick or ending then
   local before=callNumber(run,run.ms)
   local heap=run.heapEnd
   if freshTick then
   heap=callNumber(run,run.heap,'count')
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
   end
   local final=ending or run.elapsed>=DURATION or run.heapSamples>=HEAP_LIMIT
   if final then
    -- Reserve the final row even when periodic detail sampling drifted. Set
    -- before native callouts so a stale/late timer cannot repeat this scan.
    if not run.finalDetail then run.finalDetail=true;detail(run,at,heap,true)end
   elseif at>=run.nextDetail and #run.rows<DETAIL_LIMIT-1 then
    detail(run,at,heap,#run.rows==0)
   end
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
]==]):sub(2),edits={{143,142,([==[~EFAULT_D]==]):sub(2)},{151,152,([==[~M]==]):sub(2)},{154,154,([==[~X]==]):sub(2)},{156,156,([==[~DURAT]==]):sub(2)},{158,173,([==[~ON]==]):sub(2)},{202,202,([==[~18]==]):sub(2)},{204,207,([==[~0]==]):sub(2)},{5373,5375,([==[~%g]==]):sub(2)},{5430,5429,([==[~,run.requested]==]):sub(2)},{8690,8689,([==[~
 if status=='complete'and run.stopRequested then status='stopped'end]==]):sub(2)},{11968,11972,([==[~run.heap]==]):sub(2)},{11974,11977,([==[~imit]==]):sub(2)},{12622,12629,([==[~run.requested]==]):sub(2)},{12651,12655,([==[~run.heap]==]):sub(2)},{12657,12660,([==[~imit]==]):sub(2)},{12957,12961,([==[~run.detail]==]):sub(2)},{12963,12968,([==[~imit]==]):sub(2)},{13331,13338,([==[~run.requested]==]):sub(2)},{13360,13364,([==[~run.heap]==]):sub(2)},{13366,13369,([==[~imit]==]):sub(2)},{13594,13593,([==[~duration]==]):sub(2)},{13895,13894,([==[~if duration==nil then duration=DEFAULT_DURATION end
 if not number(duration)or duration<1 or duration>MAX_DURATION then return false,'invalid-duration'end
 ]==]):sub(2)},{13921,13920,([==[~,requested=duration,heapLimit=math.ceil(duration)+1,detailLimit=math.ceil(duration/30)+1]==]):sub(2)},{15365,15372,([==[~duration]==]):sub(2)},{15601,15600,([==[~
 return true
end
-- Explicit completed boundary; legacy StopMemoryCapture remains cancellation.
function addon:CompleteMemoryCapture()
 if self~=addon or not active then return false,'not-running'end
 local run=active;run.stopRequested=true
 if run.sampling then finish(run,'stopped')else sample(run,true)end]==]):sub(2)}}},
}
for _,row in pairs(rows)do
 local parts,at={},1
 for _,edit in ipairs(row.edits)do
  parts[#parts+1]=row.before:sub(at,edit[1]-1);parts[#parts+1]=edit[3];at=edit[2]+1
 end
 parts[#parts+1]=row.before:sub(at);row.after=table.concat(parts);row.edits=nil
end
return function(text,path)
 local row=rows[path];if not row then return text end
 if text==row.after then return row.before end
 assert(text==row.before,'unrelated performance command source: '..path)
 return text
end
