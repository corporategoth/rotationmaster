local _, addon = ...
local platform = addon.Platform

-- Unit TYPES that stand for a member of your group, resolved to a real unit
-- token when a condition is evaluated (Core/group_unit_resolution.lua):
--   maintank, mainassist   the raid's Main Tank / Main Assist (raid leader or
--                          assistant sets them; a party has none)
--   assignedtank,          the first member whose assigned role is Tank / Healer
--   assignedhealer
--   groupleader            the party or raid leader
-- The answer is a token ('raid7', 'party2', 'player'), never a guess: nobody
-- holds the assignment is "no-assigned-unit", an unreadable member is
-- "restricted-value", a missing API is "missing-api". Group members are
-- readable on Retail and Forever (SecretWhenUnitIdentityRestricted is for
-- units outside your group). Sources: GetRaidRosterInfo's role field (the
-- Main Tank and Main Assist marks; GetPartyAssignment gives the same answer
-- but is not in the generated client manifests), UnitGroupRolesAssigned,
-- UnitIsGroupLeader.
local KINDS = {
    maintank = 'roster',
    mainassist = 'roster',
    assignedtank = 'role',
    assignedhealer = 'role',
    groupleader = 'leader',
}

local ROSTER_ROLE = { maintank = 'maintank', mainassist = 'mainassist' }
local ASSIGNED_ROLE = { assignedtank = 'TANK', assignedhealer = 'HEALER' }

local function pack(...)
    return { n = select('#', ...), ... }
end

local function call(self, api, ...)
    if type(api) ~= 'function' then return nil, 'missing-api' end
    local results = pack(pcall(api, ...))
    if not results[1] then return nil, 'api-error' end

    for index = 2, results.n do
        if not self:CanReadValue(results[index]) then return nil, 'restricted-value' end
    end

    return results
end

-- nil when this client can resolve the kind, else the reason. Roles exist only
-- where players can assign them (see 'no-group-roles' in Core/condition_support.lua).
function platform:GetGroupUnitSupport(kind)
    if not KINDS[kind] then return 'invalid-group-unit' end
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return 'unsupported-policy' end
    local group = KINDS[kind]
    if group == 'roster' and type(GetRaidRosterInfo) ~= 'function' then return 'missing-api' end
    if group == 'leader' and type(UnitIsGroupLeader) ~= 'function' then return 'missing-api' end

    if group == 'role' then
        local info = self:GetClientInfo()
        local family = type(info) == 'table' and info.family
        if family == 'era' or family == 'tbc' then return 'no-group-roles' end
        if type(UnitGroupRolesAssigned) ~= 'function' then return 'missing-api' end
    end
end

local function groupTokens(self)
    local count, reason = call(self, GetNumGroupMembers)
    if not count then return nil, reason end
    local members = count[2]

    if type(members) ~= 'number' or members ~= members or members < 0 or members > 40 or members % 1 ~= 0 then
        return nil, 'invalid-api-result'
    end

    local inRaid, why = call(self, IsInRaid)
    if not inRaid then return nil, why end
    if type(inRaid[2]) ~= 'boolean' then return nil, 'invalid-api-result' end
    local tokens = {}

    if inRaid[2] then
        for index = 1, members do
            tokens[index] = 'raid' .. index
        end
    else
        tokens[1] = 'player'

        for index = 1, members - 1 do
            tokens[#tokens + 1] = 'party' .. index
        end
    end

    return tokens, inRaid[2]
end

-- The token of the first member holding the assignment, else nil and a reason.
function platform:ResolveGroupUnit(kind)
    local unsupported = self:GetGroupUnitSupport(kind)
    if unsupported then return nil, unsupported end
    local tokens, raid = groupTokens(self)
    if not tokens then return nil, raid end
    local group = KINDS[kind]

    if group == 'roster' then
        if not raid then return nil, 'no-assigned-unit' end

        for index = 1, #tokens do
            local result, reason = call(self, GetRaidRosterInfo, index)
            if not result then return nil, reason end
            local role = result[11]
            if role ~= nil and type(role) ~= 'string' then return nil, 'invalid-api-result' end
            if role == ROSTER_ROLE[kind] then return tokens[index] end
        end

        return nil, 'no-assigned-unit'
    end

    for _, token in ipairs(tokens) do
        local result, reason

        if group == 'role' then
            result, reason = call(self, UnitGroupRolesAssigned, token)
        else
            result, reason = call(self, UnitIsGroupLeader, token)
        end

        if not result then return nil, reason end
        local answer = result[2]

        if group == 'role' then
            if type(answer) ~= 'string' then return nil, 'invalid-api-result' end
            if answer == ASSIGNED_ROLE[kind] then return token end
        else
            if answer == 1 then
                answer = true
            elseif answer == nil or answer == 0 then
                answer = false
            end

            if type(answer) ~= 'boolean' then return nil, 'invalid-api-result' end
            if answer then return token end
        end
    end

    return nil, 'no-assigned-unit'
end

function platform:GetGroupUnitKinds()
    return KINDS
end
