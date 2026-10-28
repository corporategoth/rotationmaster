-- Platform adapter for UnitCastingInfo and UnitChannelInfo: what a unit is casting or channeling right now.
-- Owns platform:GetUnitCastObservation (the `value or nil, reason` reader) and its field validators; it must not
-- decide whether a cast is worth interrupting. Every field is an independent observation, so a secret or missing field
-- degrades that field only (see docs/restricted-clients.md). The reader and the helpers in the generated block at the
-- end of the file are Built In helpers and must keep their exact text.
-- Loaded from RotationMaster.toc after Platform/mobinfo2.lua; needs Platform/client.lua.
local _, addon = ...
local platform = addon.Platform

-- Whether a value is a real finite number (not NaN, not infinite).
-- @param value any  The value to test.
-- @return boolean  True for a finite number.
local function finite(value)
    return type(value)=='number' and value==value and value<math.huge and value>-math.huge
end

-- Computes the seconds until the cast ends.
-- @param ending number|nil  The cast end time in milliseconds, compared with GetTime().
-- @return number|nil  The seconds remaining, never negative; nil when either value is secret, missing or invalid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
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

-- Computes the full length of the cast from its own start and end.
-- @param starting number|nil  The cast start time in milliseconds.
-- @param ending number|nil  The cast end time in milliseconds.
-- @return number|nil  The duration in seconds; nil when either value is secret, missing or invalid.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- With the remaining seconds it gives the share done without a second clock read.
local function durationSeconds(starting, ending)
    if not platform:CanReadValue(starting) or not platform:CanReadValue(ending) then return nil,'restricted-value' end
    if starting==nil or ending==nil then return nil,'cast-time-unavailable' end
    if not finite(starting) or not finite(ending) or starting<0 or ending<=starting then return nil,'invalid-api-result' end
    return (ending-starting)/1000
end

-- Validates a cast's spell id.
-- @param id number|nil  The spell id from the native tuple.
-- @return number|nil  The id when it is a positive integer; nil otherwise.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function spellIdentity(id)
    if not platform:CanReadValue(id) then return nil,'restricted-value' end
    if id==nil then return nil,'cast-spell-unavailable' end
    if type(id)~='number' or id~=id or id<=0 or id==math.huge or id%1~=0 then return nil,'invalid-api-result' end
    return id
end

-- Converts the native "not interruptible" flag into interruptible (its inverse).
-- @param flag boolean|nil  The native not-interruptible flag.
-- @return boolean|nil  Whether the cast can be interrupted; nil when the flag is secret, missing or not a boolean.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function interruptibility(flag)
    if not platform:CanReadValue(flag) then return nil,'restricted-value' end
    if flag==nil then return nil,'interruptibility-unavailable' end
    if type(flag)~='boolean' then return nil,'invalid-api-result' end
    return not flag
end

-- Reads what a unit is casting or channeling right now (UnitCastingInfo or UnitChannelInfo).
-- @param unit string  The unit token to read; must be a non-empty string.
-- @param kind string  "cast" (UnitCastingInfo) or "channel" (UnitChannelInfo).
-- @return table|nil  { active = false } when the unit does not exist or is not casting; otherwise { active = true }
--   with name, remainingSeconds, durationSeconds, interruptible and spellID, each beside a *Reason code when that
--   field alone could not be read. nil when the query itself fails.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The timestamp, duration, flag and spell id fields are independent observations. A readable name can still
-- establish presence when the timer, duration, interruptibility or spell id is unavailable; so can a secret name,
-- though the record then has no name (nameReason says why).
function platform:GetUnitCastObservation(unit, kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
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
    local record
    if not self:CanReadValue(name) then
        -- Retail and Forever make cast fields secret for a unit other than the
        -- player or pet unless the spell is flagged never secret
        -- (SecretWhenUnitSpellCastRestricted). A secret is a value, never nil:
        -- the unit is casting, and only the name is hidden.
        record={active=true,nameReason='restricted-value'}
    else
        if name==nil then return {active=false} end
        if type(name)~='string' or name=='' then return nil,'invalid-api-result' end
        record={active=true,name=name}
    end
    record.remainingSeconds,record.remainingReason=remainingSeconds(tuple[5])
    record.durationSeconds,record.durationReason=durationSeconds(tuple[4],tuple[5])
    record.interruptible,record.interruptibleReason=interruptibility(tuple[kind=='cast' and 8 or 7])
    record.spellID,record.spellReason=spellIdentity(tuple[kind=='cast' and 9 or 8])
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetUnitCastObservation" then return addon.Platform.GetUnitCastObservation end
        if name=="durationSeconds" then return durationSeconds end
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
