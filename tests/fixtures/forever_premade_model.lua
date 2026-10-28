-- Shared native model for the WoW Forever premade scenario suites (defaults_forever_<class>.lua).
-- Real catalog, predicates, composition, sequence executor, readiness and auto-select order on a
-- modeled Forever (WOW_PROJECT_CAMELOT) client. RM classes Forever as combatDataPolicy=restricted
-- and never auto-selects a Built In there; scenarios therefore run on a synthetic Forever context
-- whose policy is 'probe' (as tests/default_corpus.lua does for its synthetic families), so the
-- packs are exercised as they would run if that policy is relaxed. M.new(class,{policy='restricted'})
-- keeps the real policy. Every spell is its own family ('Spell <id>'), so learned state is per ID.
local F = dofile('tests/fixtures/addon.lua')
local M = {}

-- The class's Built In module files (tools/builtin_modules.lua reads its TOC).
local function packPaths(class)
    return dofile('tools/builtin_modules.lua').paths({ family = 'forever', class = (class:gsub('%-', '')):upper() })
end

M.packPaths = packPaths

function M.new(class, options)
    options = options or {}
    local f = F.new(18, 0, class:upper())
    local a, e = f.addon, f.env
    a.db.profile.rotations = {}
    a.db.profile.itemsets = {}
    a.db.global.effects = {}

    local s = {
        level = 60,
        combat = true,
        targetCombat = true,
        hostile = true,
        friendly = false,
        dead = false,
        exists = true,
        moving = false,
        group = false,
        raid = false,
        vehicle = false,
        known = {},
        usable = {},
        range = {},
        cooldown = {},
        mapped = {},
        power = {},
        pet = false,
        petDead = false,
        cast = false,
        channel = false,
        repeatActive = false,
        current = {},
        stealthed = false,
        classification = 'normal',
        creature = 'HUMANOID',
        enemies = {},
        party = {},
        health = { player = 100, target = 100, pet = 100 },
        mana = { player = 100 },
        energy = 100,
        powerType = 0,
        points = 0,
        targetTarget = 'player',
        focus = nil,
        targetRange = { 0, 5 },
        targetLevel = 60,
        swing = 2.6,
        instance = nil,
        trees = { 0, 0, 0 },
        nodes = {},
        auras = { player = { HELPFUL = {}, HARMFUL = {} }, target = { HELPFUL = {}, HARMFUL = {} } },
    }

    local function enemy(unit)
        for _, entry in ipairs(s.enemies) do
            if entry.unit == unit then
                return entry
            end
        end
    end

    local function member(unit)
        return s.party[unit]
    end

    local function exists(unit)
        if unit == 'player' then
            return true
        elseif unit == 'target' then
            return s.exists
        elseif unit == 'pet' then
            return s.pet
        elseif unit == 'targettarget' then
            return s.exists and s.targetTarget ~= nil
        elseif unit == 'focus' then
            return s.focus ~= nil
        end

        return enemy(unit) ~= nil or member(unit) ~= nil
    end

    e.UnitExists = exists

    e.UnitLevel = function(unit)
        if unit == 'target' then
            return s.targetLevel
        end

        return s.level
    end

    e.UnitAffectingCombat = function(unit)
        if unit == 'player' then
            return s.combat
        end

        return s.targetCombat
    end

    e.UnitCanAttack = function(_, unit) return unit == 'target' and s.hostile end
    e.UnitIsFriend = function(_, unit) return unit == 'player' or unit == 'pet' or unit == 'target' and s.friendly end

    e.UnitIsEnemy = function(_, unit)
        if unit == 'target' then
            return s.hostile
        end

        return enemy(unit) ~= nil
    end

    e.UnitIsDead = function(unit)
        if unit == 'pet' then
            return s.petDead
        end

        return unit == 'target' and s.dead
    end

    e.UnitIsDeadOrGhost = e.UnitIsDead

    e.UnitIsUnit = function(x, y)
        if x == y then
            return true
        end
        if x == 'targettarget' then
            return s.targetTarget == y
        end
        if x == 'target' and y == 'focus' or x == 'focus' and y == 'target' then
            return s.focus == 'target'
        end
        if x == 'target' and y == 'player' or x == 'player' and y == 'target' then
            return s.targetIsMe == true
        end

        return false
    end

    e.UnitClassification = function() return s.classification end
    local creatures = { BEAST = 1, DRAGONKIN = 2, DEMON = 3, ELEMENTAL = 4, GIANT = 5, UNDEAD = 6, HUMANOID = 7 }
    e.UnitCreatureType = function() return s.creature, creatures[s.creature] end
    e.UnitHasVehicleUI = function() return s.vehicle end
    e.C_PetBattles = { IsInBattle = function() return false end }
    e.GetUnitSpeed = function() return s.moving and 7 or 0 end
    e.IsStealthed = function() return s.stealthed end
    e.IsInInstance = function() return s.instance ~= nil, s.instance or 'none' end
    e.UnitAttackSpeed = function() return s.swing, nil end
    e.IsInGroup = function() return s.group or s.raid end
    e.IsInRaid = function() return s.raid end

    e.UnitPlayerOrPetInParty = function(unit)
        return s.group and (unit == 'player' or member(unit) ~= nil or unit == 'target' and s.friendly)
    end

    e.UnitPlayerOrPetInRaid = function() return false end

    e.UnitPosition = function(unit)
        if unit == 'player' or member(unit) then
            return 0, 0, 0, 1
        end
    end

    e.UnitHealth = function(unit)
        if member(unit) then
            return member(unit).health
        end

        return s.health[unit] or 100
    end

    e.UnitHealthMax = function() return 100 end

    -- Power: mana (0), combo points (4, on the player as on Mainline-engine clients), else rage/energy.
    -- Your threat status on the target follows whom it attacks (3: you hold it; s.targetThreat overrides).
    e.UnitThreatSituation = function(_, unit)
        if unit == 'target' then
            if s.targetThreat ~= nil then
                return s.targetThreat
            end
            if not s.exists then
                return nil
            end

            return s.targetTarget == 'player' and 3 or 0
        end

        local entry = enemy(unit)
        return entry and entry.threat
    end

    e.UnitPowerType = function() return s.powerType end

    e.UnitPower = function(unit, kind)
        if kind == nil then
            kind = s.powerType
        end

        if kind == 0 then
            return s.mana[unit] or 100
        elseif kind == 4 then
            return s.points
        end

        return s.energy
    end

    e.UnitPowerMax = function(_, kind)
        if kind == 4 then
            return 5
        end

        return 100
    end

    e.UnitGUID = function(unit)
        if unit == 'player' then
            return 'Player-test'
        end

        local entry = enemy(unit)

        if entry then
            return entry.guid
        end

        return 'Creature-' .. unit
    end

    e.UnitCastingInfo = function(unit)
        if unit == 'player' and s.cast then
            return 'Manual cast', 'Manual cast', 1, 99000, 102000, false, 'cast-guid', false, 1
        end
    end

    e.UnitChannelInfo = function(unit)
        if unit == 'player' and s.channel then
            return 'Manual channel', 'Manual channel', 1, 99000, 102000, false, false, 1
        end
    end

    e.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }

    e.C_SpellBook = {
        IsSpellKnown = function(id, bank)
            if s.knownError then
                error('learning unavailable')
            end

            return bank ~= 1 and s.known[id] == true
        end,
    }

    e.C_CVar = {
        GetCVar = function(name)
            assert(name == 'nameplateMaxDistance')
            return '40'
        end,
    }

    -- Forever talents (C_ClassTalents/C_Traits, as the Camelot talent frame reads them): the three classic
    -- trees are node groups of one trait tree, in display order. s.trees = points per tree, s.nodes[node] =
    -- a node's rank (absent: not in the tree), s.config=false = no active config yet (below level 10).
    e.C_ClassTalents = {
        GetActiveConfigID = function()
            if s.config == false then
                return nil
            end

            return 7
        end,
    }

    e.C_Traits = {
        GetConfigInfo = function() return { ID = 7, type = 1, name = 'Loadout', treeIDs = { 900 } } end,
        GetGroupDisplayInfoByTreeID = function()
            local list = {}

            for i = 1, 3 do
                list[i] = { groupID = 10 + i, treeID = 900, orderIndex = i - 1, displayName = 'Tree ' .. i, icon = i }
            end

            return list
        end,
        GetGroupCurrencyInfo = function(_, ids)
            local list = {}

            for i, id in ipairs(ids) do
                list[i] = { traitNodeGroupID = id, currencyInfos = { { spent = s.trees[id - 10] or 0 } } }
            end

            return list
        end,
        GetNodeInfo = function(_, node)
            local rank = s.nodes[node]

            if rank == nil then
                return { ID = 0, activeRank = 0, maxRanks = 0, entryIDs = {} }
            end

            return {
                ID = node,
                activeRank = rank,
                ranksPurchased = rank,
                maxRanks = 5,
                entryIDs = { node * 10 },
                isVisible = true,
            }
        end,
    }

    -- LibRangeCheck intervals: enemies carry their own, the target uses s.targetRange.
    f.libraries['LibRangeCheck-3.0'].GetRange = function(_, unit)
        if unit == 'target' then
            return s.targetRange[1], s.targetRange[2]
        end

        local entry = enemy(unit)

        if entry then
            return entry.range[1], entry.range[2]
        end
        if member(unit) then
            return 0, 5
        end
    end

    e.C_Spell = {
        GetSpellInfo = function(id)
            if type(id) == 'string' then
                local n = tonumber(id:match('^Spell (%d+)$'))

                if n then
                    return { name = id, spellID = n }
                end

                return
            end

            return { name = 'Spell ' .. id, spellID = id }
        end,
        SpellHasRange = function(id) return s.range[id] ~= nil end,
        IsSpellInRange = function(id, unit)
            if id == 6603 then
                return s.targetRange[2] <= 5
            end

            return s.range[id]
        end,
        IsSpellUsable = function(id) return s.usable[id] ~= false and not s.power[id], s.power[id] == true end,
        GetSpellCooldown = function(id)
            return s.cooldown[id] or { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
        end,
        IsAutoRepeatSpell = function() return s.repeatActive end,
        IsCurrentSpell = function(id) return s.current[id] == true end,
    }

    e.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
            if s.auraError then
                error('auras unavailable')
            end

            local list = s.auras[unit] and s.auras[unit][(filter or 'HELPFUL'):match('^(%u+)')]
            return list and list[index]
        end,
    }

    for _, path in ipairs({
        'Platform/inventory.lua', 'Platform/unit_states.lua', 'Platform/spells.lua', 'Platform/auras.lua',
        'Platform/range.lua', 'Platform/actions.lua', 'Platform/talents.lua', 'Core/action_policy.lua',
        'Core/conditions.lua', 'Core/aura_conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua',
        'Data/validation.lua', 'Data/catalog.lua', 'Data/diff.lua', 'Core/build_context.lua',
        'Core/rotation_library.lua', 'Conditions/common.lua', 'Conditions/spell.lua', 'Conditions/known_spell.lua',
        'Conditions/character.lua', 'Conditions/buffs.lua', 'Conditions/debuffs.lua', 'Conditions/combat.lua',
        'Conditions/casting.lua', 'Conditions/channeling.lua', 'Conditions/stats.lua', 'Conditions/talent.lua',
        'Conditions/item.lua', 'Conditions/spatial.lua', 'Conditions/spatial_stats.lua', 'Conditions/unit_states.lua',
        'Conditions/range.lua', 'Conditions/misc.lua', 'Conditions/weapon.lua'
    }) do
        f.load(path)
    end

    for _, path in ipairs(packPaths(class)) do
        f.load(path)
    end

    -- The client has no BOOKTYPE_* globals (removed in 11.0) and reads addon metadata through C_AddOns.
    e.C_AddOns = {
        GetAddOnMetadata = function() return 'Rotation Master test' end,
        IsAddOnLoaded = function() return false end,
    }

    f.libraries['AceAddon-3.0'] = { NewAddon = function(_, object) return object end }
    f.libraries['AceEvent-3.0'] = {}
    f.libraries['LibDBIcon-1.0'] = {}
    f.libraries['LibSharedMedia-3.0'] = {}
    f.libraries['LibDataBroker-1.1'] = { NewDataObject = function(_, _, object) return object end }
    f.libraries['ThreatClassic-1.0'] = { Disable = function() end }
    f.libraries['LibClassicDurations'].Register = function() end
    f.load('Core/rotation_sequence.lua')
    f.load('Core/rotation_selection.lua')
    f.load('main.lua')
    a.ScheduleTimer = function(_, callback) return callback end

    if (options.policy or 'probe') ~= 'restricted' then
        local real = a.Platform.GetClientInfo

        a.Platform.GetClientInfo = function(self)
            local info = real(self)
            assert(info.family == 'forever')
            info.combatDataPolicy = options.policy or 'probe'
            return info
        end
    end

    -- The client's Diagnostics call boundary keeps two results per leaf; without it a provider's
    -- extra provenance result (BEYOND_MELEE's 'native-attack-range') would read as a skip.
    for _, definition in pairs(a.conditionDefinitions) do
        local evaluate = definition.evaluate

        if type(evaluate) == 'function' then
            definition.evaluate = function(...)
                local matched, reason = evaluate(...)
                return matched, reason
            end
        end
    end

    assert(a:InitializeRotationLibrary())
    a.spellHistory = {}

    -- Learning a spell also teaches the catalog its identity; ranged spells default in range.
    s.learn = function(...)
        for _, id in ipairs({ ... }) do
            s.known[id] = true
            a.SpellCatalog:UpdateSpell(id)
        end
    end

    s.ranged = function(...)
        for _, id in ipairs({ ... }) do
            s.range[id] = true
        end
    end

    s.setLevel = function(level)
        s.level = level
        a.longtermCache = {}
        a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')
    end

    -- Talent points per tree ({1,2,3} in display order) and single node ranks.
    s.setTrees = function(points)
        s.trees = points
        a:InvalidateBuildContext('talents')
    end

    s.setNode = function(node, rank)
        s.nodes[node] = rank
        a:InvalidateBuildContext('talents')
    end

    -- Nameplate enemies engaged with you, for THREAT_COUNT (threat 0 = on your table, 3 = attacking
    -- you) and DISTANCE_COUNT (each at the given LibRangeCheck interval, default 0-5).
    s.near = function(count, range, threat)
        s.enemies = {}
        a.unitsInRange = {}

        for i = 1, count do
            local unit, guid = 'nameplate' .. i, 'Creature-np' .. i
            s.enemies[i] = { unit = unit, guid = guid, range = range or { 0, 5 }, threat = threat or 0 }
            a.unitsInRange[guid] = { unit = unit }
        end
    end

    -- Party members party1..n at the given health percentages (group implied).
    s.members = function(...)
        s.party = {}
        s.group = true

        for i, hp in ipairs({ ... }) do
            s.party['party' .. i] = { health = hp }
        end
    end

    s.cooling = function(id, remain)
        s.cooldown[id] = { startTime = 100 - (60 - remain), duration = 60, isEnabled = true, modRate = 1 }
    end

    s.cast = false

    s.history = function(id, ago)
        table.insert(a.spellHistory, 1, { spell = id, time = 100 - ago })
    end

    s.buff = function(unit, id, extra)
        local list = s.auras[unit].HELPFUL
        local aura = { spellId = id, name = 'Spell ' .. id, sourceUnit = 'player' }

        for k, v in pairs(extra or {}) do
            aura[k] = v
        end

        list[#list + 1] = aura
    end

    s.debuff = function(unit, id, extra)
        local list = s.auras[unit].HARMFUL
        local aura = { spellId = id, name = 'Spell ' .. id, sourceUnit = 'player' }

        for k, v in pairs(extra or {}) do
            aura[k] = v
        end

        list[#list + 1] = aura
    end

    s.clearAuras = function()
        s.auras = { player = { HELPFUL = {}, HARMFUL = {} }, target = { HELPFUL = {}, HARMFUL = {} } }
    end

    return f, s
end

-- Helpers over one fixture.
function M.rows(a)
    local byId = {}

    for _, row in ipairs(a:ListDefaultRotations(0)) do
        byId[row.id] = row
    end

    return byId
end

function M.row(a, id)
    local row = M.rows(a)[id]
    assert(row, 'missing premade ' .. id)
    return row
end

function M.switch(a, id)
    return a:evaluateConditionResult(M.row(a, id).envelope.body.switch).status
end

-- Auto-select exactly as main does: built-in order by priority, first matching switch wins.
function M.selected(a)
    local rows = a:GetRuntimeRotations(0)
    local byKey = {}

    for _, row in ipairs(a:ListDefaultRotations(0)) do
        byKey[row.runtimeKey] = row.id
    end

    for _, key in ipairs(a:GetOrderedAutoSwitchRotations(0, rows)) do
        if a:evaluateConditionResult(rows[key].switch).status == 'match' then
            return byKey[key]
        end
    end
end

-- First recommended action of a premade's rotation; returns the action ID and the result.
function M.first(a, s, id)
    local ready = a:NewActionReadiness(100)
    local chosen

    local result = a:EvaluateRotationSequence(
        M.row(a, id).envelope.body,
        function(c) return a:evaluateConditionResult(c) end,
        function(step)
            if a:evaluateCondition(step.conditions) then
                for _, spell in ipairs(a:GetSpellIds(step) or {}) do
                    if s.mapped[spell] ~= false and ready(step.type, spell) then
                        chosen = spell
                        return false
                    end
                end
            end
        end
    )

    return chosen, result
end

-- Independent reminders that would light: a set of action IDs.
function M.upkeep(a, s, id)
    local lit = {}
    local ready = a:NewActionReadiness(100)

    for _, step in ipairs(M.row(a, id).envelope.body.cooldowns) do
        if not step.disabled and a:evaluateConditionResult(step.conditions).status == 'match' then
            for _, spell in ipairs(a:GetSpellIds(step) or {}) do
                if s.mapped[spell] ~= false and ready(step.type, spell) then
                    lit[spell] = true
                    break
                end
            end
        end
    end

    return lit
end

-- Asserts the first action (nil for none) and, optionally, the sequence status.
function M.expect(a, s, id, want, status, label)
    local got, result = M.first(a, s, id)

    assert(
        got == want,
        (label or id)
            .. ': expected '
            .. tostring(want)
            .. ', got '
            .. tostring(got)
            .. ' ('
            .. tostring(result.status)
            .. ')'
    )

    if status then
        assert(
            result.status == status,
            (label or id) .. ': expected status ' .. status .. ', got ' .. tostring(result.status)
        )
    end

    return result
end

-- On the real restricted Forever client: every premade listed and complete (every condition it uses
-- is readable there), the player-chosen variants disabled, and want auto-selected for the character
-- setup(s,a) describes.
function M.checkRestricted(class, ids, setup, want)
    local f, s = M.new(class, { policy = 'restricted' })
    local a = f.addon
    local support = dofile('tests/fixtures/client_support.lua')
    support.install(f, { stubNatives = true })

    if setup then
        setup(s, a)
    end

    assert(a.Platform:GetClientInfo().combatDataPolicy == 'restricted', 'not the restricted policy')
    local rows = M.rows(a)

    for _, id in ipairs(ids) do
        assert(rows[id] and rows[id].readOnly, id .. ' not listed')
        support.complete(rows[id], id)
    end

    assert(
        M.selected(a) == want,
        'restricted Forever auto-selected ' .. tostring((M.selected(a))) .. ', expected ' .. tostring(want)
    )
end

return M
