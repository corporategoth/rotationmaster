local _,addon=...

local function finite(platform,value)
    if not platform:CanReadValue(value) then return false,'restricted-value' end
    if type(value)~='number' or value~=value or value>=math.huge or value<=-math.huge then return false,'invalid-threat-count-number' end
    return true
end

local function readField(platform,object,key)
    if not platform:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-unit-snapshot' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'unit-snapshot-read-error' end
    if not platform:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- Count only observed membership, using current facts for the same identity.
-- Neither the snapshot nor the complete count is cached or changed here.
function addon:GetConditionThreatCount(minimum,cache)
    local platform=self.Platform
    if platform:GetClientInfo().combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    local valid,issue=finite(platform,minimum)
    if not valid then return nil,issue end
    if not platform:CanReadValue(cache) then return nil,'restricted-value' end
    if cache~=nil and type(cache)~='table' then return nil,'invalid-threat-count-cache' end
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
