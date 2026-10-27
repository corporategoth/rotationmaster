local _, addon = ...

-- Conditions name a unit by a token the game understands, or by one of the
-- group unit types in addon.groupUnitKinds (the group's main tank, assigned
-- healer, leader, ...). Those have no token of their own: the engine hands a
-- condition a copy of its value whose unit (and otherunit) is the real token
-- of whoever holds the assignment right now, so every unit-aware condition
-- works on them unchanged. Nobody holding it, or a member the game will not
-- read, is unavailable with the reason; it is never guessed.
-- One resolution per kind per evaluation (the evaluation's cache).
function addon:ResolveConditionUnits(value, cache)
    local kinds = self.groupUnitKinds
    local unit, other = value.unit, value.otherunit
    local unitKind, otherKind = kinds[unit], kinds[other]
    if not unitKind and not otherKind then return value end
    local platform = self.Platform
    local resolved = {}

    for key, field in pairs(value) do
        resolved[key] = field
    end

    if unitKind then
        local token, reason = self.Functions.cache.getCached(cache, platform.ResolveGroupUnit, platform, unit)
        if not token then return nil, reason end
        resolved.unit = token
    end

    if otherKind then
        local token, reason = self.Functions.cache.getCached(cache, platform.ResolveGroupUnit, platform, other)
        if not token then return nil, reason end
        resolved.otherunit = token
    end

    return resolved
end
