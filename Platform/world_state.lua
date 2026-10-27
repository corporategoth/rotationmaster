local _, addon = ...
local platform = addon.Platform

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

local function finite(value)
    return type(value) == 'number' and value == value and value < math.huge and value > -math.huge
end

local function whole(value)
    return finite(value) and value % 1 == 0
end

-- A protected call whose results must all be readable: the results from index
-- 2 on (index 1 is the pcall status), with n their count including nils.
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

local function flag(self, api, ...)
    local results, reason = call(self, api, ...)
    if not results then return nil, reason end
    local result = results[2]
    if result == nil or result == 0 then return false end
    if result == 1 then return true end
    if type(result) ~= 'boolean' then return nil, 'invalid-api-result' end
    return result
end

function platform:GetPlayerStateObservation(kind)
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    if not self:CanReadValue(kind) then return nil, 'restricted-value' end
    if type(kind) ~= 'string' or not stateKinds[kind] then return nil, 'invalid-player-state-query' end
    if kind == 'dead' then return flag(self, UnitIsDead, 'player') end

    if kind == 'ghost' then
        local either, reason = flag(self, UnitIsDeadOrGhost, 'player')
        if either == nil then return nil, reason end
        if not either then return false end
        local dead, why = flag(self, UnitIsDead, 'player')
        if dead == nil then return nil, why end
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

-- Whether a boss encounter is in progress, from the game rather than a boss mod.
function platform:GetEncounterObservation()
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    local api = type(C_InstanceEncounter) == 'table' and C_InstanceEncounter.IsEncounterInProgress or nil
    if type(api) ~= 'function' then api = IsEncounterInProgress end
    local results, reason = call(self, api)
    if not results then return nil, reason end
    local result = results[2]
    if result == nil then return nil, 'encounter-data-unavailable' end
    if result == 0 then return false end
    if result == 1 then return true end
    if type(result) ~= 'boolean' then return nil, 'invalid-api-result' end
    return result
end

-- GetInstanceInfo() of the area you are in, one read for every condition that
-- needs it: {difficultyID, instanceID, name, instanceType, maxPlayers}, with a
-- field left nil when its value could not be read (reasons[field] says why).
-- In the open world the difficulty is 0 and the instance ID is the map ID of
-- the continent.
function platform:GetInstanceDetails()
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    if type(GetInstanceInfo) ~= 'function' then return nil, 'missing-api' end
    local results = pack(pcall(GetInstanceInfo))
    if not results[1] then return nil, 'api-error' end

    local name, instanceType, difficultyID, _, maxPlayers, _, _, instanceID =
        results[2], results[3], results[4], results[5], results[6], results[7], results[8], results[9]

    local record, reasons = {}, {}

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

-- The active Mythic+ keystone: {active, level, affixes}. level is 0 when no
-- keystone is running. Retail only; where the API is absent the reason is
-- missing-api.
function platform:GetKeystoneObservation()
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    local namespace = C_ChallengeMode
    if type(namespace) ~= 'table' then return nil, 'missing-api' end
    local active, reason = call(self, namespace.IsChallengeModeActive)
    if not active then return nil, reason end
    if type(active[2]) ~= 'boolean' then return nil, 'invalid-api-result' end
    if not active[2] then return { active = false, level = 0, affixes = {} } end
    local keystone, why = call(self, namespace.GetActiveKeystoneInfo)
    if not keystone then return nil, why end
    local level, affixes = keystone[2], keystone[3]
    if level == nil then return nil, 'keystone-data-unavailable' end
    if not whole(level) or level < 0 then return nil, 'invalid-api-result' end
    local list = {}

    if type(affixes) == 'table' then
        if getmetatable(affixes) ~= nil then return nil, 'invalid-api-result' end

        for index = 1, #affixes do
            local id = affixes[index]
            if not self:CanReadValue(id) then return nil, 'restricted-value' end
            if whole(id) then list[#list + 1] = id end
        end
    end

    return { active = true, level = level, affixes = list }
end

-- The hero talent tree (subtree ID) the player has chosen: a number, false
-- when none is chosen (below the level that offers one, or not chosen yet), or
-- nil with a reason. Retail only.
function platform:GetActiveHeroTree()
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    local namespace = C_ClassTalents
    if type(namespace) ~= 'table' then return nil, 'missing-api' end
    local results, reason = call(self, namespace.GetActiveHeroTalentSpec)
    if not results then return nil, reason end
    local id = results[2]
    if id == nil then return false end
    if not whole(id) or id <= 0 then return nil, 'invalid-api-result' end
    return id
end

-- The name the game gives a hero tree, remembered once read (a name does not
-- change within a session). Needs the active talent config, so it is nil while
-- the config is unavailable.
local heroNames = {}

function platform:GetHeroTreeName(subTreeID)
    if not whole(subTreeID) or subTreeID <= 0 then return nil, 'invalid-talent-query' end
    local known = heroNames[subTreeID]
    if known then return known end
    local classTalents, traits = C_ClassTalents, C_Traits
    if type(classTalents) ~= 'table' or type(traits) ~= 'table' then return nil, 'missing-api' end
    local config, reason = call(self, classTalents.GetActiveConfigID)
    if not config then return nil, reason end
    if not whole(config[2]) then return nil, 'talent-config-unavailable' end
    local info, why = call(self, traits.GetSubTreeInfo, config[2], subTreeID)
    if not info then return nil, why end
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

-- The hero trees a specialization (default: the one being played) can choose,
-- for the editor: a list of {id, name}. Listed from the talent tree reader, so
-- another specialization's trees need the view loadout and not being in combat.
function platform:GetHeroTreeChoices(specID)
    if type(self.GetTraitTalents) ~= 'function' then return nil, 'missing-api' end
    local groups, reason = self:GetTraitTalents(specID)
    if not groups then return nil, reason end
    local list = {}

    for _, group in ipairs(groups) do
        if group.kind == 'hero' and whole(group.hero) then
            if type(group.name) == 'string' and group.name ~= '' then heroNames[group.hero] = group.name end
            list[#list + 1] = { id = group.hero, name = group.name }
        end
    end

    if #list == 0 then return nil, 'hero-trees-unavailable' end
    return list
end

-- Whether a spell currently shows its activation (proc) glow. The game answers
-- for the spell ID the action shows, so the spell and its base and override
-- relatives are each asked by the caller.
function platform:IsSpellGlowing(spellID)
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    if not self:CanReadValue(spellID) then return nil, 'restricted-value' end
    if not whole(spellID) or spellID <= 0 then return nil, 'invalid-spell-query' end
    local namespace = C_SpellActivationOverlay
    local api = type(namespace) == 'table' and namespace.IsSpellOverlayed or nil
    local results, reason = call(self, api, spellID)
    if not results then return nil, reason end
    local result = results[2]
    if result == nil then return nil, 'spell-glow-unavailable' end
    if type(result) ~= 'boolean' then return nil, 'invalid-api-result' end
    return result
end

-- Group size, assigned roles or dead members over the party or raid tokens:
-- {size, roles={TANK,HEALER,DAMAGER,NONE}, dead}. Everything counts you: size
-- is 1 when solo, a role counts you when it is yours, and dead counts you when
-- you are dead or a ghost. `want` is 'size' (the default), 'roles' or 'dead':
-- only the members' values that measure needs are read, so a group size never
-- calls the role or death APIs. roles or dead is nil, with rolesReason or
-- deadReason, when a member's value could not be read.
function platform:GetGroupSnapshot(want)
    local policy = self:GetCombatDataPolicy()
    if policy ~= 'probe' and policy ~= 'restricted' then return nil, 'unsupported-policy' end
    if not self:CanReadValue(want) then return nil, 'restricted-value' end
    if want ~= nil and want ~= 'size' and want ~= 'roles' and want ~= 'dead' then return nil, 'invalid-group-query' end
    local count, reason = call(self, GetNumGroupMembers)
    if not count then return nil, reason end
    local members = count[2]
    if not whole(members) or members < 0 or members > 40 then return nil, 'invalid-api-result' end
    local inRaid, why = call(self, IsInRaid)
    if not inRaid then return nil, why end
    if type(inRaid[2]) ~= 'boolean' then return nil, 'invalid-api-result' end
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

            if roles[role] == nil then role = 'NONE' end
            roles[role] = roles[role] + 1
        end

        if ok then record.roles = roles end
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

            if result[2] then dead = dead + 1 end
        end

        if ok then record.dead = dead end
    end

    return record
end
