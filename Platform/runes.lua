local _,addon=...
local platform=addon.Platform

local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end
local function validIndex(self,index)
    if not self:CanReadValue(index) then return nil,'restricted-value' end
    if not finite(index) or index%1~=0 or index<1 or index>6 then return nil,'invalid-rune-index' end
    return true
end
local function numberField(self,value,missing)
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(value) then return nil,'restricted-value' end
    if value==nil then return nil,missing end
    if not finite(value) then return nil,'invalid-api-result' end
    return value
end

function platform:GetRuneTypeObservation(index)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    local valid,reason=validIndex(self,index)
    if not valid then return nil,reason end
    local api=GetRuneType
    if type(api)~='function' then return nil,'missing-api' end
    local ok,value=pcall(api,index)
    if not ok then return nil,'api-error' end
    local runeType,why=numberField(self,value,'rune-type-unavailable')
    if runeType==nil then return nil,why end
    if runeType<=0 or runeType%1~=0 then return nil,'invalid-api-result' end
    return runeType
end

-- A single native tuple supports independent ready and timing predicates.
-- Missing optional fields do not invalidate another readable field.
function platform:GetRuneCooldownObservation(index)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    local valid,reason=validIndex(self,index)
    if not valid then return nil,reason end
    local api=GetRuneCooldown
    if type(api)~='function' then return nil,'missing-api' end
    local ok,tuple=pcall(function() return {api(index)} end)
    if not ok then return nil,'api-error' end
    local record={}
    record.start,record.startReason=numberField(self,tuple[1],'rune-start-unavailable')
    record.duration,record.durationReason=numberField(self,tuple[2],'rune-duration-unavailable')
    local ready=tuple[3]
    if not self:CanReadValue(ready) then record.readyReason='restricted-value'
    elseif ready==nil then record.readyReason='rune-ready-unavailable'
    elseif type(ready)~='boolean' then record.readyReason='invalid-api-result'
    else record.ready=ready end
    return record
end

-- This clock is deliberately not a per-pass cached observation.
function platform:GetRuneEvaluationTime()
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    local api=GetTime
    if type(api)~='function' then return nil,'missing-api' end
    local ok,value=pcall(api)
    if not ok then return nil,'api-error' end
    return numberField(self,value,'rune-time-unavailable')
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetRuneCooldownObservation" then return addon.Platform.GetRuneCooldownObservation end
        if name=="Platform_GetRuneEvaluationTime" then return addon.Platform.GetRuneEvaluationTime end
        if name=="Platform_GetRuneTypeObservation" then return addon.Platform.GetRuneTypeObservation end
        if name=="finite" then return finite end
        if name=="numberField" then return numberField end
        if name=="validIndex" then return validIndex end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/runes.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/runes.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
