-- Shared native model for the Mists of Pandaria Classic premade scenario suites
-- (defaults_mop_<class>.lua: Death Knight, Druid, Hunter, Mage, Monk, Paladin). Real catalog,
-- predicates, composition, sequence executor, readiness and auto-select order on a modeled 5.5.4
-- client (WOW_PROJECT_MISTS_CLASSIC, LE_EXPANSION_LEVEL_CURRENT 4): family 'progression', probe
-- policy, rotations stored per talent group (dual spec 1/2), grid talents, POINT per class
-- (Holy Power, Chi, Combo Points), Runes for Death Knights. Every spell is its own family
-- ('Spell <id>'), so learned state is per ID.
-- SPECIALIZATION: s.spec indexes the class's specialization IDs (M.SPECS; nil below 10); s.specID(id).
-- FORM by spell: s.bar lists stance-bar spells in slot order, s.form the active slot (0 none); s.shift(id).
-- WEAPON_TYPE: s.gear[16]/s.gear[17]={itemID,classID,subClassID,equipLoc} (M.DAGGER, M.SHIELD, ...).
-- Cast/channel identity and progress: s.castSpell / s.channelSpell, the channel running from s.channelStart
-- to s.channelEnd (seconds; GetTime is 100, default 99..102).
local F = dofile('tests/fixtures/addon.lua')
local M = {}

-- PowerTypeConstantsDocumentation.lua at 5.5.4.70531 (as tests/progression_points.lua).
local POWER = {
    Mana = 0,
    Rage = 1,
    Focus = 2,
    Energy = 3,
    ComboPoints = 4,
    Runes = 5,
    RunicPower = 6,
    SoulShards = 7,
    LunarPower = 8,
    HolyPower = 9,
    Alternate = 10,
    Maelstrom = 11,
    Chi = 12,
    Insanity = 13,
    BurningEmbers = 14,
    DemonicFury = 15,
    ArcaneCharges = 16,
    Fury = 17,
    Pain = 18,
    Essence = 19,
    Balance = 26,
    ShadowOrbs = 28,
}

M.POWER = POWER

-- Specialization IDs by index (C_SpecializationInfo.GetSpecializationInfo), Blizzard's order.
local SPECS = {
    WARRIOR = { 71, 72, 73 },
    PALADIN = { 65, 66, 70 },
    HUNTER = { 253, 254, 255 },
    ROGUE = { 259, 260, 261 },
    PRIEST = { 256, 257, 258 },
    DEATHKNIGHT = { 250, 251, 252 },
    SHAMAN = { 262, 263, 264 },
    MAGE = { 62, 63, 64 },
    WARLOCK = { 265, 266, 267 },
    MONK = { 268, 270, 269 },
    DRUID = { 102, 103, 104, 105 },
}

M.SPECS = SPECS
-- Equipment records {itemID, item class, subclass, equip location}: weapons are class 2, shields class 4/6.
M.DAGGER = { 7001, 2, 15, 'INVTYPE_WEAPON' }
M.SWORD = { 7002, 2, 7, 'INVTYPE_WEAPON' }
M.AXE2H = { 7003, 2, 1, 'INVTYPE_2HWEAPON' }
M.SHIELD = { 7004, 4, 6, 'INVTYPE_SHIELD' }
M.STAFF = { 7005, 2, 10, 'INVTYPE_2HWEAPON' }
M.OFFHAND = { 7006, 4, 0, 'INVTYPE_HOLDABLE' }
-- RM's rune types (constants.lua addon.runes; 5.5.4 RuneFrame_Shared.lua): B Blood, F Frost, U Unholy, D Death.
local RUNES = { B = 1, F = 2, U = 3, D = 4 }

local function packPaths(class)
    return dofile('tools/builtin_modules.lua').paths({ family = 'progression', class = (class:gsub('%-', '')):upper() })
end

M.packPaths = packPaths

function M.new(class, options)
    options = options or {}
    local token = (class:gsub('%-', '')):upper()
    local f = F.new(options.project or 19, options.expansion or 4, token)
    local a, e = f.addon, f.env
    local types = {}

    for name, id in pairs(POWER) do
        types[name] = id
    end

    e.Enum.PowerType = types
    a.db.profile.rotations = {}
    a.db.profile.itemsets = {}
    a.db.global.effects = {}

    local s = {
        level = 90,
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
        talentGroup = 1,
        spec = nil,
        talents = {},
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
        energyMax = 100,
        powerType = 0,
        resource = {},
        targetTarget = 'player',
        focus = nil,
        targetRange = { 0, 5 },
        targetLevel = 90,
        swing = 2.6,
        offhand = nil,
        instance = nil,
        runes = { { 1, true }, { 1, true }, { 3, true }, { 3, true }, { 2, true }, { 2, true } },
        auras = {
            player = { HELPFUL = {}, HARMFUL = {} },
            target = { HELPFUL = {}, HARMFUL = {} },
            pet = { HELPFUL = {}, HARMFUL = {} },
        },
        form = 0,
        bar = {},
        gear = {},
        castSpell = nil,
        channelSpell = nil,
        channelStart = 99,
        channelEnd = 102,
    }

    s.specID = function(id)
        s.spec = nil

        for index, known in ipairs(SPECS[token] or {}) do
            if known == id then
                s.spec = index
            end
        end

        assert(s.spec, 'not a ' .. token .. ' specialization: ' .. tostring(id))
    end

    s.shift = function(id)
        if id == 0 then
            s.form = 0
            return
        end

        for index, known in ipairs(s.bar) do
            if known == id then
                s.form = index
                return
            end
        end

        s.bar[#s.bar + 1] = id
        s.form = #s.bar
    end

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
    -- Off-hand speed is nil with a two-hander (s.offhand=nil), as UnitAttackSpeed reports it.
    e.UnitAttackSpeed = function() return s.swing, s.offhand end
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

    e.UnitThreatSituation = function(_, unit)
        local entry = enemy(unit)
        return entry and entry.threat
    end

    -- Power: mana (0); the primary bar (rage, energy, focus, runic power) is s.energy of s.powerType;
    -- class resources (Holy Power 9, Chi 12, Combo Points 4 on the player) are s.resource[type].
    e.UnitPowerType = function() return s.powerType end
    local maxima = { [POWER.ComboPoints] = 5, [POWER.HolyPower] = 5, [POWER.Chi] = 4 }

    e.UnitPower = function(unit, kind)
        if kind == nil then
            kind = s.powerType
        end

        if kind == 0 then
            return s.mana[unit] or 100
        end
        if kind == s.powerType then
            return s.energy
        end

        return s.resource[kind] or 0
    end

    e.UnitPowerMax = function(_, kind)
        if kind == nil then
            kind = s.powerType
        end

        if kind ~= 0 and kind == s.powerType then
            return s.energyMax
        end

        return s.maximum and s.maximum[kind] or maxima[kind] or 100
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
            local name = s.castSpell and ('Spell ' .. s.castSpell) or 'Manual cast'
            return name, name, 1, 99000, 102000, false, 'cast-guid', false, s.castSpell or 1
        end
    end

    e.UnitChannelInfo = function(unit)
        if unit == 'player' and s.channel then
            local name = s.channelSpell and ('Spell ' .. s.channelSpell) or 'Manual channel'
            return name, name, 1, s.channelStart * 1000, s.channelEnd * 1000, false, false, s.channelSpell or 1
        end
    end

    e.GetShapeshiftForm = function() return s.form end
    e.GetNumShapeshiftForms = function() return #s.bar end

    e.GetShapeshiftFormInfo = function(index)
        local id = s.bar[index]

        if id then
            return 136000, index == s.form, true, id
        end
    end

    e.GetInventoryItemID = function(_, slot)
        local item = s.gear[slot]
        return item and item[1]
    end

    e.GetInventoryItemLink = function(_, slot)
        local item = s.gear[slot]
        return item and ('|Hitem:' .. item[1] .. ':0:0:0:0:0:0|h')
    end

    e.GetItemInfoInstant = function(id)
        for _, item in pairs(s.gear) do
            if item[1] == id then
                return id, 'Type', 'Subtype', item[4], 1, item[2], item[3]
            end
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

    -- Talent groups (storage) and grid talents: index = (tier-1)*3+column, s.talents[index]=true.
    e.GetNumTalentGroups = function() return 2 end

    e.C_SpecializationInfo = {
        GetActiveSpecGroup = function() return s.talentGroup end,
        GetSpecialization = function() return s.spec end,
        GetSpecializationInfo = function(index) return SPECS[token] and SPECS[token][index] end,
        GetTalentInfo = function(query)
            local index = (query.tier - 1) * 3 + query.column

            return {
                name = 'Talent ' .. index,
                icon = 1,
                talentID = index,
                spellID = 900000 + index,
                selected = s.talents[index] == true,
            }
        end,
    }

    -- Runes: six slots {type, ready}; GetRuneCooldown reports a 10 s recharge started 5 s ago when not ready.
    e.GetRuneType = function(index) return s.runes[index][1] end

    e.GetRuneCooldown = function(index)
        local rune = s.runes[index]

        if rune[2] then
            return 0, 10, true
        end

        return 95, 10, false
    end

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
        'Data/validation.lua', 'Data/catalog.lua', 'Data/diff.lua', 'Core/rotation_library.lua',
        'Conditions/common.lua', 'Conditions/spell.lua', 'Conditions/known_spell.lua', 'Conditions/character.lua',
        'Conditions/buffs.lua', 'Conditions/debuffs.lua', 'Conditions/combat.lua', 'Conditions/casting.lua',
        'Conditions/channeling.lua', 'Conditions/stats.lua', 'Conditions/talent.lua', 'Conditions/item.lua',
        'Conditions/spatial.lua', 'Conditions/spatial_stats.lua', 'Conditions/unit_states.lua', 'Conditions/range.lua',
        'Conditions/misc.lua', 'Conditions/weapon.lua', 'Core/build_context.lua', 'Conditions/specialization.lua',
        'Conditions/equipment.lua'
    }) do
        f.load(path)
    end

    for _, path in ipairs(packPaths(class)) do
        f.load(path)
    end

    e.BOOKTYPE_SPELL, e.BOOKTYPE_PET = 'spell', 'pet'  -- No client has a GetAddOnMetadata global any more; metadata comes from C_AddOns.

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

    s.forget = function(...)
        for _, id in ipairs({ ... }) do
            s.known[id] = nil
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

    -- Runes by letter, slot order: B Blood, F Frost, U Unholy, D Death; lower case is recharging.
    -- s.setRunes('BBUUFF') is all six ready; s.setRunes('bbuuff') none.
    s.setRunes = function(text)
        assert(#text == 6, 'six runes')

        for i = 1, 6 do
            local c = text:sub(i, i)
            s.runes[i] = { assert(RUNES[c:upper()], c), c == c:upper() }
        end
    end

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
        s.auras = {
            player = { HELPFUL = {}, HARMFUL = {} },
            target = { HELPFUL = {}, HARMFUL = {} },
            pet = { HELPFUL = {}, HARMFUL = {} },
        }
    end

    -- The character plays talent group 1 (the namespace the helpers read; body.specs reads the
    -- specialization through it).
    a.currentSpec = 1
    return f, s
end

-- Helpers over one fixture. Progression stores rotations per talent group; the suites use group 1.
local GROUP = 1
M.GROUP = GROUP

function M.rows(a)
    local byId = {}

    for _, row in ipairs(a:ListDefaultRotations(GROUP)) do
        byId[row.id] = row
    end

    return byId
end

function M.row(a, id)
    local row = M.rows(a)[id]
    assert(row, 'missing premade ' .. id)
    return row
end

-- Specialization and equipment are cached until their notifications; the model changes them directly.
local function fresh(a)
    a:InvalidateBuildContext()
end

-- Whether automatic switching would find it matching: its specializations (body.specs), then its switch.
function M.switch(a, id)
    fresh(a)
    local body = M.row(a, id).envelope.body

    if body.specs and not a:RotationSpecsApply(body.specs, GROUP) then
        return 'no-match'
    end

    return a:evaluateConditionResult(body.switch).status
end

-- Auto-select exactly as main does: built-in order by priority, first matching switch wins.
function M.selected(a)
    fresh(a)
    local rows = a:GetRuntimeRotations(GROUP)
    local byKey = {}

    for _, row in ipairs(a:ListDefaultRotations(GROUP)) do
        byKey[row.runtimeKey] = row.id
    end

    for _, key in ipairs(a:GetOrderedAutoSwitchRotations(GROUP, rows)) do
        if a:evaluateConditionResult(rows[key].switch).status == 'match' then
            return byKey[key]
        end
    end
end

-- First recommended action of a premade's rotation; returns the action ID and the result.
function M.first(a, s, id)
    fresh(a)
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
    fresh(a)
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

-- Every premade of a class: listed read-only, Mists only (progression, expansion 4), applicability
-- holding only load-time facts (level lives in the switch, specialization in body.specs), eligible on
-- the modeled Mists client in its own specialization, and never registered on a Wrath client.
-- minLevel is kept for the callers' record.
function M.scope(class, ids, minLevel)
    local f, s = M.new(class)
    local a = f.addon
    local rows = M.rows(a)
    local token = (class:gsub('%-', '')):upper()
    local initial = s.spec

    for _, id in ipairs(ids) do
        local row = assert(rows[id], id)
        local scope = row.applicability
        -- A specialization's premade is eligible while you play that specialization.
        local specs = row.envelope.body.specs

        if specs then
            s.specID(specs[1])
            fresh(a)
            row = assert(M.rows(a)[id], id)
            scope = row.applicability
        end

        assert(
            row.readOnly
                and row.builtin
                and scope.families[1] == 'progression'
                and #scope.families == 1
                and scope.class == token,
            id
        )

        assert(
            scope.minExpansion == 4
                and scope.maxExpansion == 4
                and scope.maxLevel == nil
                and scope.minLevel == nil
                and scope.specs == nil,
            id .. ' scope'
        )

        -- A player-chosen variant ships disabled: listed, ineligible only because it is off.
        if row.envelope.body.disabled then
            assert(
                not row.eligible and row.eligibilityReason == 'disabled',
                id .. ': ' .. tostring(row.eligibilityReason)
            )
        else
            assert(row.eligible, id .. ' not eligible on the Mists client: ' .. tostring(row.eligibilityReason))
        end
    end

    s.spec = initial
    fresh(a)
    local wrath = M.new(class, { project = 11, expansion = 2 }).addon
    local wrows = M.rows(wrath)

    for _, id in ipairs(ids) do
        assert(not wrows[id] or not wrows[id].eligible, id .. ' eligible on a Wrath client')
    end

    return a, s, f
end

return M
