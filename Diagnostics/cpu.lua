local addon_name,addon=...
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
 if type(self.ClearCastCaptureForDisable)=='function' then self:ClearCastCaptureForDisable() end
end
