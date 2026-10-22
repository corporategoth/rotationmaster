local _, addon = ...
local platform = addon.Platform
local cacheKey = {}

local function query(cache, unit, index, filter)
    if not cache then return platform:GetAuraByIndex(unit, index, filter) end
    -- Only normalized observations enter this per-evaluation cache. Avoid the
    -- legacy CRC cache's tostring/tuple path for restricted native records.
    cache[cacheKey] = cache[cacheKey] or {}
    local units = cache[cacheKey]
    units[unit] = units[unit] or {}
    local filters = units[unit]
    filters[filter] = filters[filter] or {}
    local records = filters[filter]
    if not records[index] then
        local aura, reason = platform:GetAuraByIndex(unit, index, filter)
        records[index] = {aura=aura, reason=reason}
    end
    return records[index].aura, records[index].reason
end

local function matchesAura(aura, value, mode, identity)
    local matches
    if mode == "stealable" then
        local stealable, why = platform:ReadAuraField(aura, "isStealable")
        if why then return nil, why end
        if stealable == nil then return nil, "aura-stealability-unavailable" end
        matches = stealable
    elseif mode == "dispel" then
        local dispel, why = platform:ReadAuraField(aura, "dispelName")
        if why then return nil, why end
        matches = dispel == value.debufftype or (value.debufftype == "Enrage" and dispel == "")
    else
        local field = type(value.spell) == "number" and "spellID" or "name"
        local spell, why = platform:ReadAuraField(aura, field)
        if why then return nil, why end
        if spell == nil then return nil, "aura-identity-unavailable" end
        matches = spell == value.spell
        if not matches and field=='spellID' and value.anyrank==true then
            if not identity.resolved then
                identity.resolved=true
                if type(platform.GetSpellInfo)~='function' then identity.reason='missing-api'
                else
                    local info,reason=platform:GetSpellInfo(value.spell)
                    identity.name=info and info.name;identity.reason=reason
                end
            end
            if not identity.name then return nil,identity.reason or 'spell-data-unavailable' end
            local name,reason=platform:ReadAuraField(aura,'name')
            if reason then return nil,reason end
            if name==nil then return nil,'aura-identity-unavailable' end
            matches=name==identity.name
        end
    end
    if matches and (value.ownbuff or value.owndebuff) then
        local source, why = platform:ReadAuraField(aura, "sourceUnit")
        if why then return nil, why end
        matches = source == "player"
    end
    return matches
end

function addon:EvaluateAuraCondition(value, cache, start, filter, mode)
    if type(UnitExists) ~= "function" then return nil, "missing-api" end
    local ok, exists = pcall(UnitExists, value.unit)
    if not ok then return nil, "api-error" end
    if not platform:CanReadValue(exists) then return nil, "restricted-value" end
    if exists == nil or exists == false then return false end
    if exists ~= true and exists ~= 1 then return nil, "invalid-api-result" end

    if mode == "dispel" and value.dispellable then filter = "HARMFUL|RAID" end
    local existential = mode == "present" or mode == "dispel" or mode == "stealable"
    local pendingReason;local identity={}
    for index = 1, 256 do
        local aura, reason = query(cache, value.unit, index, filter)
        if reason then return nil, reason end
        if not aura then
            if pendingReason then return nil, pendingReason end
            return false
        end
        local matches, why = matchesAura(aura, value, mode, identity)
        if why then
            if not existential then return nil, why end
            pendingReason = pendingReason or why
        end
        if matches then
            if mode == "remaining" then
                local remaining, why = platform:AuraRemaining(aura, start or GetTime())
                if remaining == nil then return nil, why end
                return addon.Functions.values.compare(value.operator, remaining, value.value)
            elseif mode == "stacks" then
                local stacks, why = platform:ReadAuraField(aura, "applications")
                if why then return nil, why end
                if stacks == nil then return nil, "aura-stacks-unavailable" end
                return addon.Functions.values.compare(value.operator, stacks, value.value)
            end
            return true
        end
    end
    return nil, pendingReason or "aura-scan-limit"
end

if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('EvaluateAuraCondition',addon.EvaluateAuraCondition)
end
