-- Group unit resolution: turns the group unit kinds (main tank, assigned healer, leader, ...) in a condition value into
-- real unit tokens for one evaluation. It reads who holds an assignment through platform:ResolveGroupUnit and must not
-- cache across evaluations. Loaded from the TOC before rotation_lifecycle.lua; called by Core/conditions.lua for every
-- condition evaluation. The group member lookup is a restricted-client concern that lives in the Platform adapter.

local _, addon = ...

-- Resolves the group unit kinds in a condition value to real unit tokens for one evaluation.
-- @param value table  The condition value; its unit and otherunit fields may name a group unit kind.
-- @param cache table|nil  The per-evaluation cache, so each kind is resolved once per evaluation.
-- @return table|nil  The value itself when neither field is a group kind, otherwise a shallow copy whose unit and
--   otherunit hold the real tokens; nil when a kind cannot be resolved.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Conditions name a unit by a token the game understands, or by one of the group unit types in addon.groupUnitKinds
-- (the
-- group's main tank, assigned healer, leader, ...). Those have no token of their own: the engine hands a condition a
-- copy of its value whose unit (and otherunit) is the real token of whoever holds the assignment right now, so every
-- unit-aware condition works on them unchanged. Nobody holding it, or a member the game will not read, is unavailable
-- with the reason; it is never guessed.
function addon:ResolveConditionUnits(value, cache)
    local kinds = self.groupUnitKinds
    local unit, other = value.unit, value.otherunit
    local unitKind, otherKind = kinds[unit], kinds[other]

    if not unitKind and not otherKind then
        return value
    end

    local platform = self.Platform
    local resolved = {}

    for key, field in pairs(value) do
        resolved[key] = field
    end

    if unitKind then
        local token, reason = self.Functions.cache.getCached(cache, platform.ResolveGroupUnit, platform, unit)

        if not token then
            return nil, reason
        end

        resolved.unit = token
    end

    if otherKind then
        local token, reason = self.Functions.cache.getCached(cache, platform.ResolveGroupUnit, platform, other)

        if not token then
            return nil, reason
        end

        resolved.otherunit = token
    end

    return resolved
end
