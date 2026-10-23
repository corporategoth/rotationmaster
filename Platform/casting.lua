local _,addon=...
local platform=addon.Platform

local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end
local function remainingSeconds(ending)
    if not platform:CanReadValue(ending) then return nil,'restricted-value' end
    if ending==nil then return nil,'cast-time-unavailable' end
    if not finite(ending) or ending<0 then return nil,'invalid-api-result' end
    if type(GetTime)~='function' then return nil,'missing-api' end
    local ok,now=pcall(GetTime)
    if not ok then return nil,'api-error' end
    if not platform:CanReadValue(now) then return nil,'restricted-value' end
    if not finite(now) or now<0 then return nil,'invalid-api-result' end
    return math.max(0,ending/1000-now)
end
local function spellIdentity(id)
    if not platform:CanReadValue(id) then return nil,'restricted-value' end
    if id==nil then return nil,'cast-spell-unavailable' end
    if type(id)~='number' or id~=id or id<=0 or id==math.huge or id%1~=0 then return nil,'invalid-api-result' end
    return id
end
local function interruptibility(flag)
    if not platform:CanReadValue(flag) then return nil,'restricted-value' end
    if flag==nil then return nil,'interruptibility-unavailable' end
    if type(flag)~='boolean' then return nil,'invalid-api-result' end
    return not flag
end

-- The timestamp/flag/spell ID fields are independent observations. A readable
-- name can still establish presence when the timer, interruptibility or spell
-- ID is unavailable.
function platform:GetUnitCastObservation(unit,kind)
    if self:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='cast' and kind~='channel' then return nil,'invalid-cast-query' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local existsOk,exists=pcall(UnitExists,unit)
    if not existsOk then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return {active=false} end
    local fn
    if kind=='cast' then fn=UnitCastingInfo else fn=UnitChannelInfo end
    if type(fn)~='function' then return nil,'missing-api' end
    -- Capture into an owned tuple table without comparing native values. The
    -- channel flag is slot7; casting includes castID and uses slot8 instead,
    -- so the spell ID is slot9 for a cast and slot8 for a channel.
    local ok,tuple=pcall(function() return {fn(unit)} end)
    if not ok then return nil,'api-error' end
    local name=tuple[1]
    if not self:CanReadValue(name) then return nil,'restricted-value' end
    if name==nil then return {active=false} end
    if type(name)~='string' or name=='' then return nil,'invalid-api-result' end
    local record={active=true,name=name}
    record.remainingSeconds,record.remainingReason=remainingSeconds(tuple[5])
    record.interruptible,record.interruptibleReason=interruptibility(tuple[kind=='cast' and 8 or 7])
    record.spellID,record.spellReason=spellIdentity(tuple[kind=='cast' and 9 or 8])
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitCastObservation" then return addon.Platform.GetUnitCastObservation end
        if name=="finite" then return finite end
        if name=="interruptibility" then return interruptibility end
        if name=="platform" then return platform end
        if name=="remainingSeconds" then return remainingSeconds end
        if name=="spellIdentity" then return spellIdentity end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/casting.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/casting.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
