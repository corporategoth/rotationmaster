local addon_name,addon=...
-- Opt-in cumulative snapshots. No functions are wrapped and shared counters are
-- never reset. Only this module's one completion timer exists during capture.
local active,lastReport
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
 return 'config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
end
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
 for _,entry in ipairs({{'RotationData','IndexRotationSteps'},{'RotationData','CheckPortable'},{'SpellCatalog','GetAllSpellIds'},{'SpellCatalog','GetSpellId'}}) do add(field(owner,entry[1]),entry[2],entry[1]..'.'..entry[2],reference(owner,entry[1],entry[2])) end
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
local function finish(run,status,reason)
 if active~=run then return end
 active=nil;run.timer=nil
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
   local ranked,unavailable={},{}
   for _,row in ipairs(run.rows) do
    local problem=row.reason
    for _,ref in ipairs(row.refs) do if ref()~=row.fn then problem='function-replaced';break end end
    local current;if not problem then current,problem=snapshot(run,row.fn) end
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
   for index=1,math.min(TOP,#ranked) do local row=ranked[index];local mean=row.calls>0 and row.exclusive/row.calls or nil
    report[#report+1]=string.format('%s | exclusive=%.3f ms | inclusive=%.3f ms | calls=%s | mean=%s ms',row.label,row.exclusive,row.inclusive,tostring(row.calls),mean and string.format('%.3f',mean) or 'unavailable')
   end
   for index=1,math.min(10,#unavailable) do local row=unavailable[index];report[#report+1]=row.label..' | unavailable: '..row.reason end
   if #unavailable>10 then report[#report+1]='Additional unavailable rows omitted.' end
   text=table.concat(report,'\n')
  end
 end
 text=text or 'Rotation Master CPU profile: '..status..(reason and ' ('..reason..')' or '')
 lastReport=text
 local callback=field(run.owner,'OnCPUProfileFinished');if type(callback)=='function' then pcall(callback,run.owner,text,status) end
end
function addon:StartCPUProfile(duration)
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
 active=run
 local ok,timer=pcall(self.ScheduleTimer,self,function() finish(run,'complete') end,duration)
 if not ok or not timer then if active==run then active=nil end;return false,'timer-error' end
 run.timer=timer;lastReport=nil
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
 self:CancelCPUProfile()
end
