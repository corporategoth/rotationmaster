-- Platform adapter for player, encounter, instance, Mythic+, hero talent, spell glow and group state. Readers return
-- `value, nil` or `nil, reason` (or a record carrying per-field reasons), never throw, and pass every game value
-- through platform:CanReadValue first. Must not cache anything except hero tree names, which cannot change in a
-- session. Loaded from RotationMaster.toc after Platform/pet.lua and Platform/instance.lua; consumed by the
-- condition files named below. This file has no generated bindings block.
local _, addon = ...
local platform = addon.Platform

-- ============================================================================
-- Protected-call helpers
-- ============================================================================

-- Player, instance, encounter and group state read through the platform
-- adapter, for PLAYER_STATE (Conditions/player_state.lua), ENCOUNTER and
-- KEYSTONE_LEVEL (Conditions/encounter_state.lua), INSTANCE (Conditions/misc.lua)
-- and GROUP_COUNT (Conditions/group_state.lua). Every read is
-- protected and readability-checked: a missing API is "missing-api", a throw is
-- "api-error", a secret value is "restricted-value" and an answer of the wrong
-- shape is "invalid-api-result". The caller turns a reason into an unavailable
-- condition (also under NOT); a readable false is an ordinary false. None of
-- these runs unless a condition that needs it is evaluated.
--
-- Sources (Blizzard generated API documentation, Gethe/wow-ui-source live and
-- forever; the classic branches carry the same functions undocumented):
--   IsMounted, IsResting (PlayerScript), IsSwimming, IsFalling, IsFlying
--   (Unit; SecretArguments only), C_InstanceEncounter.IsEncounterInProgress,
--   GetInstanceInfo, C_ChallengeMode.GetActiveKeystoneInfo, C_ClassTalents
--   .GetActiveHeroTalentSpec and C_SpellActivationOverlay.IsSpellOverlayed
--   carry no secret annotation on their returns. UnitGroupRolesAssigned is
--   SecretWhenUnitIdentityRestricted, which a group member never meets.

-- Whether a value is a number that is neither NaN nor infinite.
-- @param value any  The value to test.
-- @return boolean  True for a finite number.
local function finite(value)
    return type(value) == 'number' and value == value and value < math.huge and value > -math.huge
end

-- Whether a value is a finite integer.
-- @param value any  The value to test.
-- @return boolean  True for a finite integer.
local function whole(value)
    return finite(value) and value % 1 == 0
end

-- Packs varargs into a table with n set to the count, so trailing nils from a pcall are not lost.
-- @param ... any  The values to pack.
-- @return table  The values in the array part, with the count in field n.
--
-- In a call() result, index 1 is the pcall status and the API's results start at index 2.
local function pack(...)
    return { n = select('#', ...), ... }
end

-- Makes a protected call whose results must all be readable.
-- @param self table  The platform table, used for its CanReadValue method.
-- @param api function|nil  The native function.
-- @param ... any  The arguments passed to api.
-- @return table|nil  The pack() of pcall(api, ...), with the results from index 2 on and n counting nils; nil on
--   failure.
-- @return string|nil  The reason code ("missing-api", "api-error" or "restricted-value") when the first return is nil.
local function call(self, api, ...)
    if type(api) ~= 'function' then
        return nil, 'missing-api'
    end

    local results = pack(pcall(api, ...))

    if not results[1] then
        return nil, 'api-error'
    end

    for index = 2, results.n do
        if not self:CanReadValue(results[index]) then
            return nil, 'restricted-value'
        end
    end

    return results
end

-- ============================================================================
-- Player, encounter, instance and keystone state
-- ============================================================================

-- The player predicates PLAYER_STATE chooses from. The legacy form of the
-- zero-argument functions answers 1 or nil rather than true or false, and they
-- never fail, so nil means "no" here (unlike the player flags in
-- Platform/player_flags.lua). "dead" is UnitIsDead, which is false for a ghost;
-- "ghost" is dead-or-ghost without dead, both reads the generated client
-- manifests (tests/fixtures/client_api_*.lua) already list.
local stateKinds = {
    mounted = true,
    swimming = true,
    falling = true,
    flying = true,
    resting = true,
    dead = true,
    ghost = true,
}

-- Calls a Boolean predicate and normalizes its answer.
-- @param self table  The platform table, used for its CanReadValue method.
-- @param api function|nil  The native predicate.
-- @param ... any  The arguments passed to api.
-- @return boolean|nil  True or false, treating nil and 0 as false and 1 as true (legacy answers); nil for anything
--   else.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
local function flag(self, api, ...)
    local results, reason = call(self, api, ...)

    if not results then
        return nil, reason
    end

    local result = results[2]

    if result == nil or result == 0 then
        return false
    end
    if result == 1 then
        return true
    end
    if type(result) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    return result
end

-- Reads one of the player's state predicates.
-- @param kind string  One of the stateKinds names: "mounted", "swimming", "falling", "flying", "resting", "dead" or
--   "ghost".
-- @return boolean|nil  The state; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Probe and restricted policies only.
function platform:GetPlayerStateObservation(kind)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(kind) then
        return nil, 'restricted-value'
    end
    if type(kind) ~= 'string' or not stateKinds[kind] then
        return nil, 'invalid-player-state-query'
    end
    if kind == 'dead' then
        return flag(self, UnitIsDead, 'player')
    end

    if kind == 'ghost' then
        local either, reason = flag(self, UnitIsDeadOrGhost, 'player')

        if either == nil then
            return nil, reason
        end
        if not either then
            return false
        end

        local dead, why = flag(self, UnitIsDead, 'player')

        if dead == nil then
            return nil, why
        end

        return not dead
    end

    local api

    if kind == 'mounted' then
        api = IsMounted
    elseif kind == 'swimming' then
        api = IsSwimming
    elseif kind == 'falling' then
        api = IsFalling
    elseif kind == 'flying' then
        api = IsFlying
    else
        api = IsResting
    end

    return flag(self, api)
end

-- Reads whether a boss encounter is in progress, from the game rather than a boss mod.
-- @return boolean|nil  True or false; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Prefers C_InstanceEncounter and falls back to the legacy global.
function platform:GetEncounterObservation()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end

    local api = type(C_InstanceEncounter) == 'table' and C_InstanceEncounter.IsEncounterInProgress or nil

    if type(api) ~= 'function' then
        api = IsEncounterInProgress
    end

    local results, reason = call(self, api)

    if not results then
        return nil, reason
    end

    local result = results[2]

    if result == nil then
        return nil, 'encounter-data-unavailable'
    end
    if result == 0 then
        return false
    end
    if result == 1 then
        return true
    end
    if type(result) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    return result
end

-- Reads GetInstanceInfo() of the area the player is in, one read for every condition that needs it.
-- @return table|nil  { difficultyID, instanceID, name, instanceType, maxPlayers, reasons }: a field is left nil when
--   its value could not be read, and reasons[field] says why. The record is always returned once the API ran; nil when
--   the API cannot be called.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- In the open world the difficulty is 0 and the instance id is the map id of the continent.
function platform:GetInstanceDetails()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if type(GetInstanceInfo) ~= 'function' then
        return nil, 'missing-api'
    end

    local results = pack(pcall(GetInstanceInfo))

    if not results[1] then
        return nil, 'api-error'
    end

    local name, instanceType, difficultyID, _, maxPlayers, _, _, instanceID =
        results[2], results[3], results[4], results[5], results[6], results[7], results[8], results[9]

    local record, reasons = {}, {}

    -- Stores a value in the record when it is readable, present and valid.
    -- @param field string  The record field to set.
    -- @param value any  The value read from the API.
    -- @param valid function  Predicate taking the value and returning true when it has the right shape.
    --
    -- Otherwise the reason is recorded in reasons[field].
    local function take(field, value, valid)
        if not self:CanReadValue(value) then
            reasons[field] = 'restricted-value'
            return
        end

        if value == nil then
            reasons[field] = 'instance-data-unavailable'
            return
        end

        if not valid(value) then
            reasons[field] = 'invalid-api-result'
            return
        end

        record[field] = value
    end

    take('difficultyID', difficultyID, whole)
    take('instanceID', instanceID, whole)
    take('maxPlayers', maxPlayers, whole)
    take('name', name, function(value) return type(value) == 'string' end)
    take('instanceType', instanceType, function(value) return type(value) == 'string' end)
    record.reasons = reasons
    return record
end

-- Reads the active Mythic+ keystone.
-- @return table|nil  { active, level, affixes }: level is 0 when no keystone is running; affixes is a list of affix
--   ids. nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil ("missing-api" where the API is absent); nil
--   otherwise.
--
-- Retail only. Affix ids the client reports that are not whole numbers are dropped rather than failing the read.
function platform:GetKeystoneObservation()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end

    local namespace = C_ChallengeMode

    if type(namespace) ~= 'table' then
        return nil, 'missing-api'
    end

    local active, reason = call(self, namespace.IsChallengeModeActive)

    if not active then
        return nil, reason
    end
    if type(active[2]) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end
    if not active[2] then
        return { active = false, level = 0, affixes = {} }
    end

    local keystone, why = call(self, namespace.GetActiveKeystoneInfo)

    if not keystone then
        return nil, why
    end

    local level, affixes = keystone[2], keystone[3]

    if level == nil then
        return nil, 'keystone-data-unavailable'
    end
    if not whole(level) or level < 0 then
        return nil, 'invalid-api-result'
    end

    local list = {}

    if type(affixes) == 'table' then
        if getmetatable(affixes) ~= nil then
            return nil, 'invalid-api-result'
        end

        for index = 1, #affixes do
            local id = affixes[index]

            if not self:CanReadValue(id) then
                return nil, 'restricted-value'
            end

            if whole(id) then
                list[#list + 1] = id
            end
        end
    end

    return { active = true, level = level, affixes = list }
end

-- ============================================================================
-- Hero talents and spell glow
-- ============================================================================

-- Reads the hero talent tree the player has chosen.
-- @return number|false|nil  The subtree id; false when none is chosen (below the level that offers one, or not chosen
--   yet); nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Retail only.
function platform:GetActiveHeroTree()
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end

    local namespace = C_ClassTalents

    if type(namespace) ~= 'table' then
        return nil, 'missing-api'
    end

    local results, reason = call(self, namespace.GetActiveHeroTalentSpec)

    if not results then
        return nil, reason
    end

    local id = results[2]

    if id == nil then
        return false
    end
    if not whole(id) or id <= 0 then
        return nil, 'invalid-api-result'
    end

    return id
end

-- Hero tree names already read, by subtree ID; also filled by GetHeroTreeChoices.
local heroNames = {}

-- Reads the name the game gives a hero tree, remembered once read.
-- @param subTreeID number  The hero subtree id; a positive integer.
-- @return string|nil  The name; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- A name does not change within a session. Needs the active talent config, so it is nil while the config is
-- unavailable.
function platform:GetHeroTreeName(subTreeID)
    if not whole(subTreeID) or subTreeID <= 0 then
        return nil, 'invalid-talent-query'
    end

    local known = heroNames[subTreeID]

    if known then
        return known
    end

    local classTalents, traits = C_ClassTalents, C_Traits

    if type(classTalents) ~= 'table' or type(traits) ~= 'table' then
        return nil, 'missing-api'
    end

    local config, reason = call(self, classTalents.GetActiveConfigID)

    if not config then
        return nil, reason
    end
    if not whole(config[2]) then
        return nil, 'talent-config-unavailable'
    end

    local info, why = call(self, traits.GetSubTreeInfo, config[2], subTreeID)

    if not info then
        return nil, why
    end

    local record = info[2]

    if
        type(record) ~= 'table'
        or not self:CanReadValue(record.name)
        or type(record.name) ~= 'string'
        or record.name == ''
    then
        return nil, 'talent-name-unavailable'
    end

    heroNames[subTreeID] = record.name
    return record.name
end

-- Lists the hero trees a specialization can choose, for the editor.
-- @param specID number|nil  The specialization id; nil means the one being played.
-- @return table[]|nil  A list of { id, name }; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil ("hero-trees-unavailable" when the specialization
--   has none); nil otherwise.
--
-- Listed from the talent tree reader, so another specialization's trees need the view loadout and not being in
-- combat. Depends on platform:GetTraitTalents from Platform/talents.lua, which loads later, so it is looked up at
-- call time.
function platform:GetHeroTreeChoices(specID)
    if type(self.GetTraitTalents) ~= 'function' then
        return nil, 'missing-api'
    end

    local groups, reason = self:GetTraitTalents(specID)

    if not groups then
        return nil, reason
    end

    local list = {}

    for _, group in ipairs(groups) do
        if group.kind == 'hero' and whole(group.hero) then
            if type(group.name) == 'string' and group.name ~= '' then
                heroNames[group.hero] = group.name
            end

            list[#list + 1] = { id = group.hero, name = group.name }
        end
    end

    if #list == 0 then
        return nil, 'hero-trees-unavailable'
    end

    return list
end

-- Reads whether a spell currently shows its activation (proc) glow.
-- @param spellID number  The spell id; a positive integer.
-- @return boolean|nil  True or false; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The game answers for the spell id the action shows, so the spell and its base and override relatives are each asked
-- by the caller.
function platform:IsSpellGlowing(spellID)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(spellID) then
        return nil, 'restricted-value'
    end
    if not whole(spellID) or spellID <= 0 then
        return nil, 'invalid-spell-query'
    end

    local namespace = C_SpellActivationOverlay
    local api = type(namespace) == 'table' and namespace.IsSpellOverlayed or nil
    local results, reason = call(self, api, spellID)

    if not results then
        return nil, reason
    end

    local result = results[2]

    if result == nil then
        return nil, 'spell-glow-unavailable'
    end
    if type(result) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    return result
end

-- ============================================================================
-- Group
-- ============================================================================

-- Reads the group size, assigned roles or dead members over the party or raid tokens.
-- @param want string|nil  Which measure to read: "size" (the default), "roles" or "dead".
-- @return table|nil  { size, roles = { TANK, HEALER, DAMAGER, NONE }, dead, rolesReason, deadReason }; nil when it
--   cannot be read. roles or dead is nil, with rolesReason or deadReason, when a member's value could not be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Everything counts you: size is 1 when solo, a role counts you when it is yours, and dead counts you when you are
-- dead or a ghost. Only the members' values that the measure needs are read, so a group size never calls the role or
-- death APIs.
function platform:GetGroupSnapshot(want)
    local policy = self:GetCombatDataPolicy()

    if policy ~= 'probe' and policy ~= 'restricted' then
        return nil, 'unsupported-policy'
    end
    if not self:CanReadValue(want) then
        return nil, 'restricted-value'
    end
    if want ~= nil and want ~= 'size' and want ~= 'roles' and want ~= 'dead' then
        return nil, 'invalid-group-query'
    end

    local count, reason = call(self, GetNumGroupMembers)

    if not count then
        return nil, reason
    end

    local members = count[2]

    if not whole(members) or members < 0 or members > 40 then
        return nil, 'invalid-api-result'
    end

    local inRaid, why = call(self, IsInRaid)

    if not inRaid then
        return nil, why
    end
    if type(inRaid[2]) ~= 'boolean' then
        return nil, 'invalid-api-result'
    end

    local raid = inRaid[2]
    local size = members > 1 and members or 1
    local record = { size = size }
    -- A raid lists you among raid1-40; a party is you plus party1-4.
    local tokens

    if raid then
        tokens = {}

        for index = 1, members do
            tokens[index] = 'raid' .. index
        end
    else
        tokens = { 'player' }

        for index = 1, members - 1 do
            tokens[#tokens + 1] = 'party' .. index
        end
    end

    if want == 'roles' then
        local roles = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }
        local ok = true

        for _, token in ipairs(tokens) do
            local result, problem = call(self, UnitGroupRolesAssigned, token)

            if not result then
                record.rolesReason = problem
                ok = false
                break
            end

            local role = result[2]

            if type(role) ~= 'string' then
                record.rolesReason = 'invalid-api-result'
                ok = false
                break
            end

            if roles[role] == nil then
                role = 'NONE'
            end

            roles[role] = roles[role] + 1
        end

        if ok then
            record.roles = roles
        end
    elseif want == 'dead' then
        local dead = 0
        local ok = true

        for _, token in ipairs(tokens) do
            local result, problem = call(self, UnitIsDeadOrGhost, token)

            if not result then
                record.deadReason = problem
                ok = false
                break
            end

            if type(result[2]) ~= 'boolean' then
                record.deadReason = 'invalid-api-result'
                ok = false
                break
            end

            if result[2] then
                dead = dead + 1
            end
        end

        if ok then
            record.dead = dead
        end
    end

    return record
end
