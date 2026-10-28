-- Counting of tracked enemies by threat status, for the Built In threat count condition (Conditions/combat.lua).
-- Owns the count over the unit snapshot (probe clients) and over live nameplate tokens (restricted clients, where an
-- enemy GUID is secret); it must not cache, modify the snapshot or invent members. Every value read goes through
-- platform:CanReadValue. Loaded from RotationMaster.toc after Core/health_forecast_conditions.lua; the nameplate
-- tokens are maintained by main.lua. The helpers here are Built In helpers that saved custom conditions bind to by
-- text: do not edit a function body. The block at the end is generated; never hand-edit it.

local _, addon = ...

-- Checks that a threat value is readable and a finite number. Returns true, or false and a reason; NaN and infinities
-- are rejected so a comparison against the minimum can never silently misbehave.
local function finite(platform, value)
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    if type(value)~='number' or value~=value or value>=math.huge or value<=-math.huge then return false,'invalid-threat-count-number' end
    return true
end

-- Reads object[key] defensively: returns the value, or nil and a reason when the object or value is restricted, the
-- object is not a table, or the index raises. Used for fields of the unit snapshot the addon itself keeps.
local function readField(platform, object, key)
    if not platform:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-unit-snapshot' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'unit-snapshot-read-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- Returns how many tracked enemies have threat status at or above the minimum, or nil and a reason when any required
-- fact is unavailable. Count only observed membership, using current facts for the same identity.
-- Neither the snapshot nor the complete count is cached or changed here.
function addon:GetConditionThreatCount(minimum, cache)
    local platform=self.Platform
    local policy=platform:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    local valid,issue=finite(platform,minimum)
    if not valid then return nil,issue end
    if not platform:CanReadValue(cache) then return nil,'restricted-value' end
    if cache~=nil and type(cache)~='table' then return nil,'invalid-threat-count-cache' end
    if policy=='restricted' then return self:GetConditionNameplateThreatCount(minimum,cache) end
    local snapshot,why=readField(platform,self,'unitsInRange')
    if why then return nil,why end
    if type(snapshot)~='table' then return nil,'unit-snapshot-unavailable' end
    local count=0
    for guid,entity in pairs(snapshot) do
        if not platform:CanReadValue(guid) or not platform:CanReadValue(entity) then return nil,'restricted-value' end
        if type(guid)~='string' or guid=='' or type(entity)~='table' then return nil,'invalid-unit-snapshot' end
        local unit,reason=readField(platform,entity,'unit')
        if reason then return nil,reason end
        if type(unit)~='string' or unit=='' then return nil,'invalid-unit-snapshot' end
        -- The existing forecast identity observer is exactly existence + GUID;
        -- it consumes no health, history, provider or clock facts.
        local observeIdentity=platform.GetHealthForecastIdentityObservation
        if type(observeIdentity)~='function' then return nil,'missing-api' end
        local current,identityReason=addon.Functions.cache.getCached(cache,observeIdentity,platform,unit)
        if not platform:CanReadValue(current) then return nil,'restricted-value' end
        if current==nil then return nil,identityReason or 'unit-guid-unavailable' end
        if current~=false then
            if type(current)~='string' or current=='' then return nil,'invalid-unit-identity' end
            -- A recycled token is excluded; its replacement is not new membership.
            if current==guid then
                local observeThreat=platform.GetUnitThreatObservation
                if type(observeThreat)~='function' then return nil,'missing-api' end
                local status,threatReason=addon.Functions.cache.getCached(cache,observeThreat,platform,unit)
                if not platform:CanReadValue(status) then return nil,'restricted-value' end
                if status==nil then return nil,threatReason or 'threat-data-unavailable' end
                if status~=false then
                    local readable,problem=finite(platform,status)
                    if not readable then return nil,problem end
                    if status>=minimum then count=count+1 end
                end
            end
        end
    end
    return count
end

-- Restricted-client branch of GetConditionThreatCount: counts nameplate units instead of GUID-keyed membership.
-- Returns the count, or nil and a reason. Restricted clients make an enemy NPC's GUID secret
-- (UnitGUID: SecretWhenUnitIdentityRestricted, "when the unit isn't
-- player-controlled or in the party/raid"), so the GUID-keyed snapshot above
-- cannot exist there. The nameplate unit tokens NAME_PLATE_UNIT_ADDED/REMOVED
-- report are kept instead (main.lua), and each is read live: a vanished token
-- reads absent, a reused one is the unit now on that plate. Threat between the
-- player and a nameplate is "generally not secret"
-- (SecretWhenUnitThreatStateRestricted); a secret reading is unavailable.
function addon:GetConditionNameplateThreatCount(minimum, cache)
    local platform = self.Platform
    local units, why = readField(platform, self, 'nameplateUnits')

    if why then
        return nil, why
    end
    if type(units) ~= 'table' then
        return nil, 'unit-snapshot-unavailable'
    end

    local observeThreat = platform.GetUnitThreatObservation

    if type(observeThreat) ~= 'function' then
        return nil, 'missing-api'
    end

    local count = 0

    for unit in pairs(units) do
        if not platform:CanReadValue(unit) then
            return nil, 'restricted-value'
        end
        if type(unit) ~= 'string' or unit == '' then
            return nil, 'invalid-unit-snapshot'
        end

        local status, threatReason = addon.Functions.cache.getCached(cache, observeThreat, platform, unit)

        if not platform:CanReadValue(status) then
            return nil, 'restricted-value'
        end
        if status == nil then
            return nil, threatReason or 'threat-data-unavailable'
        end

        if status ~= false then
            local readable, problem = finite(platform, status)

            if not readable then
                return nil, problem
            end

            if status >= minimum then
                count = count + 1
            end
        end
    end

    return count
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetConditionThreatCount" then return addon.GetConditionThreatCount end
        if name=="finite" then return finite end
        if name=="readField" then return readField end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/threat_count_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/threat_count_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
