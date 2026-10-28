-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage premades: Frost (default), Fire (Icy Veins, recommended), Fire (Wowhead), Arcane.
-- Real catalog, composition, predicates, sequence executor, readiness and auto-select order;
-- native observations are modeled (tests/fixtures/tbc_premades.lua).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local M = dofile('tests/fixtures/tbc_premades.lua')

local FROST, FIRE, FIREWH, ARCANE =
    'rm.tbc.mage.frost', 'rm.tbc.mage.fire.icyveins', 'rm.tbc.mage.fire.wowhead', 'rm.tbc.mage.arcane'

local ALL = { FROST, FIRE, FIREWH, ARCANE }

local function fixture(level, talents, ...)
    local f, s = M.new('mage')
    s.learn(133, ...)
    s.talents = talents or { 0, 0, 0 }
    s.setLevel(level or 70)
    return f.addon, s, f
end

local function full(talents, ...)
    return fixture(70, talents, 116, 2136, 122, 120, 10, 1449, 30455, 1459, 168, 7302, 6117, 12051, 5019, ...)
end

local function stopped(r)
    return r.status == 'stopped' and r.suppressAttack
end

test('all four premades register valid, localized, sourced and composed', function()
    local a, _, f = fixture(70)

    for _, id in ipairs(ALL) do
        local row = M.row(a, id)
        assert(row.readOnly and row.validation.valid and row.validation.resolved, id)
        assert(f.translations[row.nameKey] and f.translations[row.descriptionKey], id .. ' untranslated')
        assert(#row.envelope.sources >= 1 and row.envelope.revision == (id == FIREWH and 6 or 5), id)
        assert(row.enabled == (id ~= FIREWH), id .. ' shipped enablement')
        assert(a:GetDefaultRotationComposition(id), id .. ' is not composed from the shared Mage blocks')

        assert(
            row.applicability.class == 'MAGE'
                and row.applicability.maxLevel == nil
                and row.applicability.minLevel == nil
                and row.applicability.families[1] == 'tbc'
        )
    end

    do
        local sw = M.row(a, FIRE).envelope.body.switch

        assert(
            sw.type == 'AND' and sw.value[1].type == 'LEVEL' and sw.value[1].value == 10,
            'Fire switch holds level 10'
        )
    end

    -- Each variant cites only its own sources.
    for _, source in ipairs(M.row(a, FIREWH).envelope.sources) do
        assert(not source.url:find('icy%-veins'), 'Wowhead variant cites Icy Veins')
    end

    for _, source in ipairs(M.row(a, FIRE).envelope.sources) do
        assert(not source.url:find('wowhead'), 'Icy Veins variant cites Wowhead')
    end
end)

test('auto-select: Frost owns low levels and no talents; Fire, Arcane and Frost by primary tree', function()
    local a, s = fixture(5)
    assert(M.selected(a) == FROST and M.row(a, FROST).eligible and M.switch(a, FIRE) == 'no-match')
    s.setLevel(9)
    assert(M.selected(a) == FROST)
    s.setLevel(30)
    assert(M.selected(a) == FROST, 'no points spent must still select Frost')
    assert(M.switch(a, FIRE) == 'unavailable' and M.switch(a, ARCANE) == 'unavailable')
    s.talents = { 0, 21, 0 }
    assert(M.selected(a) == FIRE)
    assert(M.switch(a, FIREWH) == 'match', 'Wowhead Fire must match like its Icy Veins sibling')
    s.talents = { 21, 0, 0 }
    assert(M.selected(a) == ARCANE)
    s.talents = { 10, 10, 0 }
    assert(M.selected(a) == FROST, 'a tied build falls back to Frost')
    s.setLevel(70)
    s.talents = { 0, 10, 51 }
    assert(M.selected(a) == FROST)
    s.talents = { 2, 44, 15 }
    assert(M.selected(a) == FIRE)
    -- The Wowhead variant ships disabled: with the recommended Fire off, the Frost catch-all runs until it is enabled.
    assert(a:SetDefaultRotationEnabled(FIRE, false))
    assert(M.selected(a) == FROST, 'disabling the recommended Fire selects ' .. tostring(M.selected(a)))
    assert(a:SetDefaultRotationEnabled(FIREWH, true))
    assert(M.selected(a) == FIREWH, 'enabling the Wowhead variant does not select it')
    assert(a:SetDefaultRotationEnabled(FIRE, true))
    assert(M.selected(a) == FIRE)
end)

test('cast, channel and target boundaries stop every Mage premade without melee', function()
    local a, s = full({ 0, 44, 17 }, 11366, 2948)

    for _, id in ipairs(ALL) do
        s.cast = true
        assert(stopped(select(2, M.first(a, s, id))), id)
        s.cast = false
        s.channel = true
        assert(stopped(select(2, M.first(a, s, id))), id)
        s.channel = false
        s.hostile = false
        assert(stopped(select(2, M.first(a, s, id))), id)
        s.hostile = true
        s.combat = false
        assert(stopped(select(2, M.first(a, s, id))), id .. ' pulled a mob someone else is fighting')
        s.combat = true
        assert(M.first(a, s, id), id .. ' gave no advice in plain combat')
    end
end)

test('pull: one opener out of combat, then stop', function()
    local a, s = fixture(3)
    s.combat = false
    s.targetCombat = false
    local id, r = M.first(a, s, FROST)
    assert(id == 133)
    s.usable[133] = false
    id, r = M.first(a, s, FROST)
    assert(id == nil and stopped(r), 'pull fell through to combat priorities')
    a, s = full({ 0, 44, 17 }, 11366)
    s.combat = false
    s.targetCombat = false
    assert(M.first(a, s, FROST) == 116)
    assert(M.first(a, s, FIRE) == 11366, 'Icy Veins Fire opens with Pyroblast')
    assert(M.first(a, s, FIREWH) == 133, 'Wowhead Fire opens with Fireball')
    a, s = full({ 44, 0, 17 }, 30451)
    s.combat = false
    s.targetCombat = false
    assert(M.first(a, s, ARCANE) == 30451)
end)

test('Frost training stages: Fireball, Frostbolt, then Ice Lance on frozen targets', function()
    local a, s = fixture(3)
    assert(M.first(a, s, FROST) == 133)
    s.learn(116)
    s.setLevel(4)
    assert(M.first(a, s, FROST) == 116)
    s.usable[116] = false
    assert(M.first(a, s, FROST) ~= 133, 'a learned but unusable Frostbolt must not fall back to Fireball')
    a, s = full({ 0, 10, 51 })
    assert(M.first(a, s, FROST) == 116)
    s.debuff('target', 122, { sourceUnit = 'party1' })
    assert(M.first(a, s, FROST) == 30455, 'any frozen target takes Ice Lance')
    s.known[30455] = nil
    assert(M.first(a, s, FROST) == 116)
end)

test('Frost Nova when something is hitting you, never on a raid boss', function()
    local a, s = full({ 0, 10, 51 })
    s.engage(1, 3)
    assert(M.first(a, s, FROST) == 122)
    s.classification = 'worldboss'
    assert(M.first(a, s, FROST) == 116)
    s.classification = 'normal'
    s.cooldown[122] = { startTime = 95, duration = 25, isEnabled = true, modRate = 1 }
    assert(M.first(a, s, FROST) == 116)
end)

test('Frost single target versus three engaged enemies', function()
    local a, s = full({ 0, 10, 51 })
    s.engage(2, 0)
    assert(M.first(a, s, FROST) == 116)
    s.engage(3, 0)
    assert(M.first(a, s, FROST) == 120, 'Cone of Cold first in the AoE arm')
    s.cooldown[120] = { startTime = 95, duration = 10, isEnabled = true, modRate = 1 }
    assert(M.first(a, s, FROST) == 1449)
    s.debuff('target', 122)
    assert(M.first(a, s, FROST) == 10, 'frozen pack gets Blizzard')
    s.known[10] = nil
    assert(M.first(a, s, FROST) == 30455, 'without Blizzard the single-target priority continues')
end)

test('moving: instants only, then stop', function()
    local a, s = full({ 0, 10, 51 })
    s.moving = true
    assert(M.first(a, s, FROST) == 30455)
    s.known[30455] = nil
    assert(M.first(a, s, FROST) == 2136)
    s.cooldown[2136] = { startTime = 95, duration = 8, isEnabled = true, modRate = 1 }
    local id, r = M.first(a, s, FROST)
    assert(id == nil and stopped(r))
    a, s = full({ 0, 44, 17 }, 2948)
    s.moving = true
    assert(M.first(a, s, FIRE) == 2136 and M.first(a, s, ARCANE) == 2136, 'Fire and Arcane move with Fire Blast first')
end)

test('Fire: Improved Scorch keeps five stacks only with the talent', function()
    local a, s = full({ 0, 44, 17 }, 2948, 11366)

    for _, id in ipairs({ FIRE, FIREWH }) do
        assert(M.first(a, s, id) ~= 2948, id .. ' Scorch without Improved Scorch')
    end

    s.talent['2:10'] = 3
    assert(M.first(a, s, FIRE) == 2948)
    s.debuff('target', 22959, { sourceUnit = 'party1', applications = 5, expirationTime = 125, duration = 30 })
    assert(M.first(a, s, FIRE) == 133)
    s.auras.target.HARMFUL[1].applications = 3
    assert(M.first(a, s, FIRE) == 2948)
    s.auras.target.HARMFUL[1].applications = 5
    s.auras.target.HARMFUL[1].expirationTime = 104
    assert(M.first(a, s, FIRE) == 2948, 'refresh before 5.5 s')
end)

test('Fire variants differ on Fire Blast: Icy Veins moves with it, Wowhead weaves it', function()
    local a, s = full({ 0, 44, 17 }, 2948, 11366)
    assert(M.first(a, s, FIRE) == 133, 'Icy Veins keeps Fire Blast for movement')
    assert(M.first(a, s, FIREWH) == 2136, 'Wowhead weaves Fire Blast when ready')
    s.cooldown[2136] = { startTime = 95, duration = 8, isEnabled = true, modRate = 1 }
    assert(M.first(a, s, FIREWH) == 133)
end)

test('Fire AoE: Blast Wave, Dragon\'s Breath, Flamestrike when its burn is missing', function()
    local a, s = full({ 0, 44, 17 }, 2948, 2120, 11113, 31661)
    s.engage(3, 0)
    assert(M.first(a, s, FIRE) == 11113)
    s.cooldown[11113] = { startTime = 95, duration = 30, isEnabled = true, modRate = 1 }
    assert(M.first(a, s, FIRE) == 31661)
    s.cooldown[31661] = s.cooldown[11113]
    assert(M.first(a, s, FIRE) == 2120)
    s.debuff('target', 2120)
    assert(M.first(a, s, FIRE) == 133)
end)

test('Arcane: Missiles before 64, burn and conserve with Arcane Blast after', function()
    local a, s = fixture(40, { 31, 0, 0 }, 116, 5143, 2136)
    assert(M.first(a, s, ARCANE) == 5143)
    s.mana.player = 15
    assert(M.first(a, s, ARCANE) == 116, 'low mana switches to Frostbolt')
    a, s = full({ 44, 0, 17 }, 30451, 5143)
    assert(M.first(a, s, ARCANE) == 30451, 'burn above 35% mana')
    s.mana.player = 30
    assert(M.first(a, s, ARCANE) == 30451, 'conserve: build to three stacks')
    s.debuff('player', 36032, { applications = 3, expirationTime = 106, duration = 8, sourceUnit = 'player' })
    assert(s.auras.player.HARMFUL[1].spellId == 36032)
    assert(M.first(a, s, ARCANE) == 116, 'three stacks: Frostbolt')
    s.auras.player.HARMFUL[1].expirationTime = 101
    assert(M.first(a, s, ARCANE) == 30451, 'stacks about to drop: Arcane Blast')
    s.auras.player.HARMFUL[1].expirationTime = 106
    s.buff('player', 12042)
    assert(M.first(a, s, ARCANE) == 30451, 'Arcane Power burns')
end)

test('out of mana: wand, never toggling an active wand off', function()
    local a, s = full({ 0, 10, 51 })

    for _, id in ipairs({ 116, 133, 30455, 2136, 122, 120, 10, 1449 }) do
        s.power[id] = true
    end

    assert(M.first(a, s, FROST) == 5019)
    s.repeatActive = true
    local id, r = M.first(a, s, FROST)
    assert(id == nil and stopped(r))
end)

test('upkeep: Intellect, armor preference, mana tools and talent cooldowns', function()
    local a, s = full({ 0, 10, 51 }, 30482, 12472, 11958, 31687, 11426)
    s.combat = false
    local lit = M.upkeep(a, s, FROST)
    assert(lit[1459] and lit[6117] and not lit[7302] and not lit[168] and not lit[30482], 'Frost prefers Mage Armor')
    lit = M.upkeep(a, s, FIRE)
    assert(lit[30482] and not lit[6117], 'Fire prefers Molten Armor')
    s.buff('player', 7302)
    lit = M.upkeep(a, s, FIRE)
    assert(not lit[30482] and not lit[6117], 'an armor you chose is kept')
    s.clearAuras()
    s.mapped[30482] = false
    s.usable[30482] = false
    lit = M.upkeep(a, s, FIRE)
    assert(not lit[30482] and not lit[6117], 'unready Molten never licenses Mage Armor')
    s.usable[30482] = nil
    s.combat = true
    lit = M.upkeep(a, s, FROST)
    assert(not lit[1459], 'Intellect waits for the end of combat')
    assert(lit[12472] and lit[31687] and not lit[11958])
    s.buff('player', 12472)
    s.cooldown[12472] = { startTime = 95, duration = 180, isEnabled = true, modRate = 1 }
    s.pet = true
    lit = M.upkeep(a, s, FROST)
    assert(not lit[12472] and not lit[11958] and not lit[31687], 'Cold Snap only after Icy Veins has run out')
    s.clearAuras()
    lit = M.upkeep(a, s, FROST)
    assert(lit[11958])
    s.mana.player = 15
    lit = M.upkeep(a, s, FROST)
    assert(lit[12051] and lit['mage-frost-mana-gem'])
    s.buff('player', 2825)
    lit = M.upkeep(a, s, FROST)
    assert(not lit[12051], 'no Evocation during Bloodlust')
    s.health.player = 30
    s.clearAuras()
    lit = M.upkeep(a, s, FROST)
    assert(lit[11426], 'Ice Barrier when hurt')
end)

test('upkeep: Fire Combustion under 20% target health; Arcane Power with mana', function()
    local a, s = full({ 0, 44, 17 }, 11129, 12042, 12043)
    assert(not M.upkeep(a, s, FIRE)[11129])
    s.health.target = 15
    assert(M.upkeep(a, s, FIRE)[11129])
    assert(M.upkeep(a, s, ARCANE)[12042])
    s.mana.player = 30
    assert(not M.upkeep(a, s, ARCANE)[12042])
    assert(not M.upkeep(a, s, ARCANE)[12043])
    s.moving = true
    assert(M.upkeep(a, s, ARCANE)[12043], 'Presence of Mind while moving')
end)

test('unknown learning keeps armor advice unavailable instead of guessing', function()
    local a, s = full({ 0, 10, 51 })
    s.combat = false
    s.knownError = true

    assert(
        M.status(a, FROST, 'mage-frost-mage-armor') == 'unavailable'
            and M.status(a, FROST, 'mage-frost-frost-armor') == 'unavailable'
    )
end)

test('a saved clone of a removed Mage premade keeps loading and running', function()
    local a, s = full({ 0, 10, 51 })
    local clone = assert(a:CloneDefaultRotation(0, FROST, 'My Frost'))
    local lineage = a.db.profile.rotationLibrary.origins[0][clone].lineage

    lineage.sourceId, lineage.clonedFrom, lineage.baseline.id =
        'rm.tbc.mage.starter.50-59', 'rm.tbc.mage.starter.50-59', 'rm.tbc.mage.starter.50-59'

    a.db.profile.rotationLibrary.preferences = a.db.profile.rotationLibrary.preferences or {}
    local f2, s2 = M.new('mage')
    local b = f2.addon
    b.db.profile = a.db.profile
    assert(b:InitializeRotationLibrary())
    s2.learn(133, 116)
    s2.setLevel(70)
    local body = assert(b:GetEditableRotation(0, clone), 'clone lost after its source pack was removed')
    assert(b:GetRuntimeRotations(0)[clone], 'clone no longer runnable')
    local ready = b:NewActionReadiness(100)
    local chosen

    b:EvaluateRotationSequence(body, function(c) return b:evaluateConditionResult(c) end, function(step)
        if b:evaluateCondition(step.conditions) then
            for _, id in ipairs(b:GetSpellIds(step) or {}) do
                if ready(step.type, id) then
                    chosen = id
                    return false
                end
            end
        end
    end)

    assert(chosen == 116, 'clone stopped recommending')
end)

finish()
