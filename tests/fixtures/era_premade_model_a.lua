-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared native model for the Classic Era and Season of Discovery premade scenario suites
-- (defaults_era_{druid,hunter,mage,paladin,priest}.lua). Real catalog, predicates, composition,
-- build context (season rulesets), sequence executor, readiness and auto-select order on a modeled
-- 1.15 client (WOW_PROJECT_CLASSIC, family era, combatDataPolicy probe). Every spell is its own
-- family ('Spell <id>') unless M.new is given rank families, so learned state is per ID.
-- The Era client exposes the legacy talent tree API (GetTalentTabInfo/GetTalentInfo) and the
-- legacy IsSpellKnown; combo points are read with UnitPower(player, ComboPoints).
-- s.setSeason(2) makes the realm Season of Discovery ('season:2'); nil is a standard realm.
-- FORM by spell: s.bar lists the stance-bar spells in slot order, s.form the active slot (0 none);
-- s.shift(id) activates a form by spell (adding it to the bar), s.shift(0) leaves it.
-- WEAPON_TYPE: s.wield(slot, M.GEAR.X) equips a modeled item record in slot 16/17/18 (nil empties it).
local F = dofile('tests/fixtures/addon.lua')
local M = {}

local function packPaths(class)
    return dofile('tools/builtin_modules.lua').paths({ family = 'era', class = (class:gsub('%-', '')):upper() })
end

M.packPaths = packPaths

-- Equipment records {itemID, item class, subclass, equip location} for WEAPON_TYPE.
M.GEAR = {
    DAGGER = { 7001, 2, 15, 'INVTYPE_WEAPON' },
    SWORD = { 7002, 2, 7, 'INVTYPE_WEAPON' },
    MACE2H = { 7003, 2, 5, 'INVTYPE_2HWEAPON' },
    SHIELD = { 7004, 4, 6, 'INVTYPE_SHIELD' },
    STAFF = { 7005, 2, 10, 'INVTYPE_2HWEAPON' },
    OFFHAND = { 7006, 4, 0, 'INVTYPE_HOLDABLE' },
}

-- options.families: {[base]={base,rank2,...}} rank families named 'Spell <base>'.
function M.new(class, options)
    options = options or {}
    local families = options.families or {}
    local f = F.new(2, 0, class:upper())
    local a, e = f.addon, f.env
    a.db.profile.rotations = {}
    a.db.profile.itemsets = {}
    a.db.global.effects = {}
    a.delayed_condition = {}

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
        talents = { 0, 0, 0 },
        talent = {},
        runes = {},
        cast = false,
        channel = false,
        castSpell = nil,
        channelSpell = nil,
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
        targetRange = { 0, 5 },
        targetLevel = 60,
        swing = 2.6,
        offSwing = nil,
        instance = nil,
        items = {},
        equipped = {},
        season = nil,
        hardcore = false,
        enchant = { main = false, mainId = nil, off = false, offId = nil },
        targetCast = nil,
        targetInterruptible = true,
        auras = {
            player = { HELPFUL = {}, HARMFUL = {} },
            target = { HELPFUL = {}, HARMFUL = {} },
            pet = { HELPFUL = {}, HARMFUL = {} },
        },
        form = 0,
        bar = {},
        gear = {},
        channelStart = 99,
        channelEnd = 102,
    }

    local names = {}

    for base, ids in pairs(families) do
        for _, id in ipairs(ids) do
            names[id] = 'Spell ' .. base
        end
    end

    local function name(id)
        return names[id] or ('Spell ' .. id)
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

    e.UnitCanAttack = function(_, unit) return unit == 'target' and s.hostile or enemy(unit) ~= nil end

    e.UnitIsFriend = function(_, unit)
        return unit == 'player' or unit == 'pet' or member(unit) ~= nil or unit == 'target' and s.friendly
    end

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
    e.UnitAttackSpeed = function() return s.swing, s.offSwing end
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

        if entry then
            return entry.threat
        end
        if unit == 'target' then
            return s.targetThreat
        end
    end

    -- Power: mana (0), combo points (4, UnitPower on 1.15), else rage/energy.
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

    e.GetComboPoints = function() return s.points end

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
            local n = s.castSpell and name(s.castSpell) or 'Manual cast'
            return n, n, 1, 99000, 102000, false, 'cast-guid', false, s.castSpell or 1
        end

        if unit == 'target' and s.targetCast then
            return s.targetCast, s.targetCast, 1, 99000, 102000, false, 'cast-guid', not s.targetInterruptible, 1
        end
    end

    e.UnitChannelInfo = function(unit)
        if unit == 'player' and s.channel then
            local n = s.channelSpell and name(s.channelSpell) or 'Manual channel'
            return n, n, 1, s.channelStart * 1000, s.channelEnd * 1000, false, false, s.channelSpell or 1
        end
    end

    e.IsSpellKnown = function(id, pet)
        if s.knownError then
            error('learning unavailable')
        end

        return not pet and s.known[id] == true
    end

    e.IsPlayerSpell = function(id) return s.known[id] == true end
    -- Legacy talent tree API (1.15): GetTalentTabInfo returns name, icon, points spent.
    e.GetNumTalentTabs = function() return 3 end
    e.GetTalentTabInfo = function(tree) return 'Tree ' .. tree, 136048, s.talents[tree] or 0, 'Background' end
    e.GetNumTalents = function() return 30 end

    e.GetTalentInfo = function(tree, index)
        local rank = s.talent[tree .. ':' .. index] or 0
        return 'Talent ' .. tree .. ':' .. index, 136048, 1, 1, rank, 5, nil, nil, nil, nil, nil, tree * 100 + index
    end

    -- Seasons and game rules (C_Seasons exists on every 1.15 realm).
    e.Enum.SeasonID = {
        NoSeason = 0,
        SeasonOfMastery = 1,
        SeasonOfDiscovery = 2,
        Hardcore = 3,
        Fresh = 11,
        FreshHardcore = 12,
    }

    e.C_Seasons = { GetActiveSeason = function() return s.season or 0 end }

    e.C_GameRules = {
        IsHardcoreActive = function() return s.hardcore == true end,
        IsSelfFoundAllowed = function() return false end,
    }

    -- Season of Discovery engraving (C_Engraving, enabled on SoD realms only): s.runes holds the spells whose
    -- runes are engraved, one equipment slot each in spell ID order; each rune teaches its one spell.
    -- s.runesPending models the rune list not loaded yet after login (engraving unavailable).
    local function engraved()
        local list = {}

        for id in pairs(s.runes) do
            list[#list + 1] = id
        end

        table.sort(list)
        return list
    end

    e.C_Engraving = {
        IsEngravingEnabled = function() return s.season == 2 end,
        GetNumRunesKnown = function()
            if s.runesPending then
                return 0, 0
            end

            return #engraved(), 20
        end,
        IsEquipmentSlotEngravable = function() return true end,
        GetRuneForEquipmentSlot = function(slot)
            local id = engraved()[slot]

            if id then
                return {
                    skillLineAbilityID = id,
                    itemEnchantmentID = id,
                    name = 'Rune ' .. id,
                    iconTexture = 1,
                    equipmentSlot = slot,
                    level = 1,
                    learnedAbilitySpellIDs = { id },
                }
            end
        end,
    }

    -- Backpack only: one slot per carried item ID (s.items[id]=count). Equipped item IDs by slot.
    e.NUM_BAG_SLOTS = 0

    local function slots()
        local list = {}

        for id, count in pairs(s.items) do
            if count > 0 then
                list[#list + 1] = { itemID = id, stackCount = count }
            end
        end

        table.sort(list, function(x, y) return x.itemID < y.itemID end)
        return list
    end

    e.C_Container = {
        GetContainerNumSlots = function(bag)
            assert(bag == 0)
            return #slots()
        end,
        GetContainerItemInfo = function(_, slot) return slots()[slot] end,
        GetItemCooldown = function() return 0, 0, 1 end,
    }

    e.GetItemCooldown = function() return 0, 0, 1 end

    e.GetInventoryItemID = function(_, slot)
        local item = s.gear[slot]

        if item then
            return item[1]
        end

        return s.equipped[slot]
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

    e.GetInventorySlotInfo = function(slot)
        assert(slot == 'RANGEDSLOT')
        return 18
    end

    e.GetWeaponEnchantInfo = function()
        return s.enchant.main, 1000, 1, s.enchant.mainId, s.enchant.off, 1000, 1, s.enchant.offId
    end

    e.C_CVar = {
        GetCVar = function(cvar)
            assert(cvar == 'nameplateMaxDistance')
            return '20'
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
                for base, ids in pairs(families) do
                    if 'Spell ' .. base == id then
                        for i = #ids, 1, -1 do
                            if s.known[ids[i]] then
                                return { name = id, spellID = ids[i] }
                            end
                        end

                        return { name = id, spellID = base }
                    end
                end

                local n = tonumber(id:match('^Spell (%d+)$'))

                if n then
                    return { name = id, spellID = n }
                end

                return
            end

            return { name = name(id), spellID = id }
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
        IsAutoRepeatSpell = function(id) return s.repeatActive == true or s.repeatActive == id end,
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

    e.GetShapeshiftForm = function() return s.form end
    e.GetNumShapeshiftForms = function() return #s.bar end

    e.GetShapeshiftFormInfo = function(index)
        local id = s.bar[index]

        if id then
            return 136000, index == s.form, true, id
        end
    end

    e.GetPetActionInfo = function() end

    for _, path in ipairs({
        'Diagnostics/errors.lua', 'Platform/inventory.lua', 'Platform/unit_states.lua', 'Platform/spells.lua',
        'Platform/auras.lua', 'Platform/range.lua', 'Platform/actions.lua', 'Platform/talents.lua',
        'Platform/totems.lua', 'Platform/engraving.lua', 'Core/action_policy.lua', 'Core/conditions.lua',
        'Core/aura_conditions.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/validation.lua',
        'Data/catalog.lua', 'Data/diff.lua', 'Core/build_context.lua', 'Core/rotation_library.lua'
    }) do
        f.load(path)
    end

    for line in io.lines('RotationMaster.toc') do
        local path = line:gsub('\r', ''):match('^(Conditions/.-%.lua)$')

        if path then
            f.load(path)
        end
    end

    for _, path in ipairs(options.packs or packPaths(class)) do
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

    for _, ids in pairs(families) do
        for _, id in ipairs(ids) do
            a.SpellCatalog:UpdateSpell(id)
        end
    end

    -- Learning a spell also teaches the catalog its identity; ranged spells default in range.
    s.learn = function(...)
        for _, id in ipairs({ ... }) do
            s.known[id] = true
            a.SpellCatalog:UpdateSpell(id)
        end
    end

    s.unlearn = function(...)
        for _, id in ipairs({ ... }) do
            s.known[id] = nil
        end
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

    s.wield = function(slot, item)
        s.gear[slot] = item
        a:InvalidateBuildContext('equipment')
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

    -- Talents: points per tree ({arcane,fire,frost}...) and single talent ranks (tree, index, rank).
    s.setTalents = function(points)
        s.talents = points
        a:InvalidateBuildContext('talents')
    end

    s.setTalent = function(tree, index, rank)
        s.talent[tree .. ':' .. index] = rank
        a:InvalidateBuildContext('talents')
    end

    -- Realm season: 2 = Season of Discovery, 3 = Hardcore, nil = standard Era.
    s.setSeason = function(id, hardcore)
        s.season = id
        s.hardcore = hardcore == true
        a:InvalidateBuildContext('client')
        a:InvalidateBuildContext('runes')
        a.longtermCache = {}
    end

    -- Engraving a rune teaches its spell (s.learn); unengraving removes both.
    s.engrave = function(...)
        for _, id in ipairs({ ... }) do
            s.runes[id] = true
        end

        s.learn(...)
        a:InvalidateBuildContext('runes')
    end

    s.unengrave = function(...)
        for _, id in ipairs({ ... }) do
            s.runes[id] = nil
        end

        s.unlearn(...)
        a:InvalidateBuildContext('runes')
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

    s.history = function(id, ago)
        table.insert(a.spellHistory, 1, { spell = id, time = 100 - ago })
    end

    local function add(unit, kind, id, extra)
        local list = s.auras[unit][kind]
        local aura = { spellId = id, name = name(id), sourceUnit = 'player' }

        for k, v in pairs(extra or {}) do
            aura[k] = v
        end

        list[#list + 1] = aura
    end

    s.buff = function(unit, id, extra)
        add(unit, 'HELPFUL', id, extra)
    end

    s.debuff = function(unit, id, extra)
        add(unit, 'HARMFUL', id, extra)
    end

    s.clearAuras = function()
        s.auras = {
            player = { HELPFUL = {}, HARMFUL = {} },
            target = { HELPFUL = {}, HARMFUL = {} },
            pet = { HELPFUL = {}, HARMFUL = {} },
        }
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

-- Independent reminders that would light: a set of action IDs (items by their step ID too).
function M.upkeep(a, s, id)
    local lit = {}
    local ready = a:NewActionReadiness(100)

    for _, step in ipairs(M.row(a, id).envelope.body.cooldowns) do
        if not step.disabled and a:evaluateConditionResult(step.conditions).status == 'match' then
            if step.type == 'item' then
                lit[step.id] = true
            end

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

-- A step anywhere in a premade (rotation, cooldowns, branch arms) by expanded ID.
function M.step(a, id, stepId)
    local found

    local function walk(list)
        for _, st in ipairs(list or {}) do
            if st.id == stepId then
                found = st
            end

            walk(st.onTrue)
            walk(st.onFalse)
        end
    end

    local body = M.row(a, id).envelope.body
    walk(body.rotation)
    walk(body.cooldowns)
    return assert(found, 'missing step ' .. stepId)
end

function M.status(a, id, stepId)
    return a:evaluateConditionResult(M.step(a, id, stepId).conditions).status
end

-- Every premade of the class registers valid, localized, sourced, composed and scoped to era.
function M.registered(a, f, ids, class)
    for _, id in ipairs(ids) do
        local row = M.row(a, id)
        local scope = row.applicability
        assert(row.readOnly and row.builtin and row.validation.valid and row.validation.resolved, id .. ' invalid')
        assert(f.translations[row.nameKey] and f.translations[row.descriptionKey], id .. ' untranslated')
        assert(#row.envelope.sources >= 1, id .. ' unsourced')

        assert(
            #scope.families == 1
                and scope.families[1] == 'era'
                and scope.class == class
                and scope.maxLevel == nil
                and scope.minLevel == nil
                and scope.specs == nil
                and scope.actionContext == 'player',
            id .. ' scope'
        )

        local sod = id:match('^rm%.sod%.') ~= nil
        assert((scope.rulesets ~= nil) == sod, id .. ' rulesets')

        if sod then
            assert(#scope.rulesets == 1 and scope.rulesets[1] == 'season:2', id .. ' must be Season of Discovery only')
        end
    end
end

return M
