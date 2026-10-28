-- TBC Shaman premades (successor of the original Shaman starter test): the shipped packs on
-- the real catalog, predicates, readiness and sequence executor; native APIs modeled.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local H = dofile('tests/fixtures/tbc_hybrid_premades.lua')
local ENH, SIM = 'rm.tbc.shaman.enhancement.icyveins', 'rm.tbc.shaman.enhancement.wowsims'

local ELE, EWH, ENA, RESTO =
    'rm.tbc.shaman.elemental.icyveins',
    'rm.tbc.shaman.elemental.wowhead',
    'rm.tbc.shaman.elemental.nextaction',
    'rm.tbc.shaman.restoration'

local ALL = { ENH, SIM, ELE, EWH, ENA, RESTO }

local function fixture(level, talents)
    local f, s = H.new('SHAMAN')
    s.level = level or 70
    s.talents = talents or { 0, 0, 0 }
    H.learn(f, s, 6603, 403, 8042, 8017)
    return f, s, f.addon
end

local function fight(s)
    s.combat = true
    s.target.combat = true
end

local function lit(f, s, id)
    local out = {}

    for k in pairs(H.upkeep(f, s, id)) do
        out[#out + 1] = k
    end

    table.sort(out)
    return table.concat(out, ',')
end

local ENH70 = {
    8050, 17364, 324, 24398, 8232, 674, 8075, 8512, 8835, 3599, 5675, 5394, 1535, 8190, 30823, 2825, 5730, 2062, 2894
}

test('six sourced, localized, valid premades replace the bounded Shaman starters', function()
    local f, s, a = fixture()

    for _, id in ipairs(ALL) do
        local r = H.row(a, id)
        local e = r.envelope
        assert(r.validation.valid and r.validation.supported and r.validation.resolved, id)
        assert(f.translations[r.nameKey] and f.translations[r.descriptionKey], id .. ' localization')
        assert(#e.sources > 0 and e.sources[1].reviewedAt == '2026-10-23', id .. ' sources')

        assert(
            e.revision == ({ [ENH] = 6, [SIM] = 7, [ELE] = 4, [EWH] = 5, [ENA] = 5, [RESTO] = 4 })[id]
                and r.enabled == (id ~= SIM and id ~= EWH and id ~= ENA)
                and e.applicability.class == 'SHAMAN'
                and e.applicability.maxLevel == nil
                and e.applicability.actionContext == 'player',
            id
        )

        assert(e.applicability.families[1] == 'tbc' and #e.applicability.families == 1)
        assert(a:GetDefaultRotationComposition(id), id .. ' uses the shared Shaman blocks')
    end

    assert(
        H.row(a, ENH).envelope.applicability.minLevel == nil and H.row(a, SIM).envelope.applicability.minLevel == nil
    )

    for _, old in ipairs({
        'rm.tbc.shaman.starter',
        'rm.tbc.shaman.enhancement.30-39',
        'rm.tbc.shaman.enhancement.40-49',
        'rm.tbc.shaman.enhancement.50-59',
    }) do
        assert(not a:GetDefaultRotation(old), old)
    end

    local other = H.new('MAGE', { packs = H.packs.SHAMAN })
    assert(#other.addon:ListDefaultRotations(0) == 0, 'Shaman premades leaked to another class')
end)

test(
    'auto-select: Enhancement below 10 and without talents, then the primary tree, recommended variant first',
    function()
        local f, s, a = fixture(5)
        assert(H.selected(f, s) == ENH)

        for _, case in ipairs({
            { 12, { 0, 0, 0 }, ENH },
            { 30, { 21, 0, 0 }, ELE },
            { 30, { 0, 21, 0 }, ENH },
            { 30, { 0, 0, 21 }, RESTO },
            { 40, { 10, 10, 1 }, ENH },
            { 70, { 41, 20, 0 }, ELE },
            { 70, { 0, 41, 20 }, ENH },
            { 70, { 0, 20, 41 }, RESTO },
            { 70, { 20, 20, 21 }, RESTO },
        }) do
            s.level, s.talents = case[1], case[2]

            assert(
                H.selected(f, s) == case[3],
                table.concat(case[2], '/') .. ' at ' .. case[1] .. ' chose ' .. tostring(H.selected(f, s))
            )
        end

        -- Variants share their sibling's switch exactly.
        for _, talents in ipairs({ { 0, 0, 0 }, { 21, 0, 0 }, { 0, 21, 0 }, { 0, 0, 21 }, { 10, 10, 0 } }) do
            s.talents = talents
            assert(H.switch(a, SIM) == H.switch(a, ENH) and H.switch(a, SIM) == 'match')
            assert(H.switch(a, EWH) == H.switch(a, ELE) and H.switch(a, ENA) == H.switch(a, ELE))
        end

        s.talents = { 0, 0, 0 }

        assert(
            H.switch(a, ELE) == 'unavailable' and H.switch(a, RESTO) == 'unavailable',
            'no points: the tree is unknown, never a match'
        )

        -- Variants ship disabled: players pick one by enabling it and turning the recommended one off.
        s.level, s.talents = 70, { 0, 41, 20 }
        assert(a:SetDefaultRotationEnabled(ENH, false))
        assert(H.selected(f, s) ~= SIM)
        assert(a:SetDefaultRotationEnabled(SIM, true))
        assert(H.selected(f, s) == SIM)
        s.talents = { 41, 20, 0 }
        assert(a:SetDefaultRotationEnabled(ELE, false))
        assert(H.selected(f, s) == SIM, 'Elemental off: the Enhancement catch-all')
        assert(a:SetDefaultRotationEnabled(EWH, true))
        assert(H.selected(f, s) == EWH)
        assert(a:SetDefaultRotationEnabled(EWH, false) and a:SetDefaultRotationEnabled(ENA, true))
        assert(H.selected(f, s) == ENA)
    end
)

test('Enhancement leveling stage: Bolt pull from range, then Earth Shock and a ranged Bolt in combat', function()
    local f, s = fixture(6)
    s.near = false
    assert(H.first(f, s, ENH) == 403, 'stationary ranged pull')
    s.moving = true
    assert(H.first(f, s, ENH) == nil)
    s.moving = false
    s.target.combat = true
    assert(H.first(f, s, ENH) == nil, 'no pull on an engaged target')
    s.target.combat = false
    s.near = true
    assert(H.first(f, s, ENH) == nil, 'no pull in melee: walk in')
    fight(s)
    assert(H.first(f, s, ENH) == 8042)
    s.cooldown[8042] = 4
    assert(H.first(f, s, ENH) == nil, 'melee waits for the shock: implicit Attack')
    s.near = false
    assert(H.first(f, s, ENH) == 403, 'ranged Bolt while out of reach')
    s.moving = true
    assert(H.first(f, s, ENH) == nil)
end)

test(
    'Enhancement full kit: Stormstrike, Earth Shock on its debuff, Flame Shock on a living target, Earth Shock',
    function()
        local f, s = fixture(70)
        H.learn(f, s, unpack(ENH70))
        fight(s)
        assert(H.first(f, s, ENH) == 17364)
        s.cooldown[17364] = 8
        s.debuffs = { { id = 17364, mine = true } }
        assert(H.first(f, s, ENH) == 8042, 'Earth Shock spends the Stormstrike debuff')
        s.debuffs = {}
        assert(H.first(f, s, ENH) == 8050, 'Flame Shock when missing')
        s.ttd = 6
        assert(H.first(f, s, ENH) == 8042, 'no Flame Shock on a target about to die')
        s.ttd = nil
        s.debuffs = { { id = 8050, mine = true } }
        assert(H.first(f, s, ENH) == 8042)
        s.debuffs = { { id = 8050, mine = false } }
        assert(H.first(f, s, ENH) == 8050, 'another shaman\'s Flame Shock is not yours')
    end
)

test('Stop boundaries: casts, channels, Ghost Wolf and no attackable target end advice', function()
    local f, s = fixture(70)
    fight(s)

    for _, key in ipairs({ 'cast', 'channel' }) do
        s[key] = true
        local spell, result = H.first(f, s, ENH)
        assert(not spell and result.status == 'stopped' and result.suppressAttack, key)
        s[key] = nil
    end

    s.buffs = { { id = 2645 } }
    local spell, result = H.first(f, s, ENH)
    assert(not spell and result.status == 'stopped' and result.suppressAttack, 'Ghost Wolf')
    s.buffs = {}
    s.target = { hostile = false, health = 1 }
    spell, result = H.first(f, s, ENH)
    assert(not spell and result.status == 'stopped', 'friendly target')
    s.target = nil
    spell, result = H.first(f, s, ENH)
    assert(not spell and result.status == 'stopped', 'no target')
    s.target = { hostile = true, dead = true, health = 0 }
    assert(H.first(f, s, ENH) == nil, 'dead target')
end)

test('interrupt, then Fire Nova and Magma for three nearby enemies; an uncertain count never halts', function()
    local f, s = fixture(70)
    H.learn(f, s, unpack(ENH70))
    fight(s)
    s.target.cast = true
    assert(H.first(f, s, ENH) == 8042, 'Earth Shock interrupts first')
    s.target.cast = 'locked'
    assert(H.first(f, s, ENH) == 17364, 'an uninterruptible cast is not kicked')
    s.target.cast = nil
    s.enemies = 3
    assert(H.first(f, s, ENH) == 1535)
    s.totems[1] = 1535
    assert(H.first(f, s, ENH) == 17364, 'Magma never replaces an active Fire Nova')
    s.totems[1] = nil
    s.cooldown[1535] = 10
    assert(H.first(f, s, ENH) == 8190, 'Magma while Fire Nova recharges')
    s.totems[1] = 8190
    assert(H.first(f, s, ENH) == 17364)
    s.enemies = 2
    s.totems = {}
    s.cooldown = {}
    assert(H.first(f, s, ENH) == 17364, 'two enemies is single target')
    s.enemies = 3
    s.rangeUncertain = true
    local spell, result = H.first(f, s, ENH)
    assert(spell == 17364 and result.status == 'selected', 'range-uncertain count must not stop the priority')
end)

test('Enhancement upkeep reminders stay independent of the damage priority', function()
    local f, s = fixture(20)
    assert(lit(f, s, ENH) == '8017', 'Rockbiter before Windfury; Lightning Shield not yet learned')
    H.learn(f, s, 324)
    assert(lit(f, s, ENH) == '324,8017')
    s.enchant.main = true
    s.buffs = { { id = 324 } }
    assert(lit(f, s, ENH) == '')
    f, s = fixture(70)
    H.learn(f, s, unpack(ENH70))
    assert(lit(f, s, ENH) == '8232,24398', 'Windfury and Water Shield out of combat; Rockbiter is superseded')
    s.enchant.main = true
    assert(lit(f, s, ENH) == '24398', 'Dual Wield known, a shield or nothing in the off hand')
    s.gear = { [16] = H.GEAR.SWORD, [17] = H.GEAR.SHIELD }
    assert(lit(f, s, ENH) == '24398', 'a shield takes no Windfury')
    s.gear[17] = H.GEAR.SWORD
    assert(lit(f, s, ENH) == '8232,24398', 'an off-hand weapon without its enchant')
    s.enchant.off = true
    s.buffs = { { id = 324 } }
    assert(lit(f, s, ENH) == '', 'a Lightning Shield you chose is respected')
    fight(s)
    assert(lit(f, s, ENH) == '8075,8835,30823', 'solo: Strength of Earth, Grace of Air, Shamanistic Rage')
    s.ttd = 40
    assert(lit(f, s, ENH) == '3599,5394,8075,8835,30823', 'a long fight adds Searing and Healing Stream')
    s.totems = { 3599, 8075, 5394, 8835 }
    assert(lit(f, s, ENH) == '30823', 'filled totem slots are respected')
    s.group = true
    s.totems = {}
    s.ttd = nil
    assert(lit(f, s, ENH) == '5675,8075,8512,30823', 'group: Windfury and Mana Spring')
    s.target.classification = 'worldboss'
    assert(lit(f, s, ENH) == '2825,5675,8075,8512,30823', 'Bloodlust on a boss in a group; Fire Elemental stays off')
    s.group = false
    s.enemies = 2
    s.health = 0.3
    s.target.classification = 'normal'

    assert(
        lit(f, s, ENH) == '2062,5730,8075,8835,30823',
        'solo emergencies: Stoneclaw for two enemies, Earth Elemental'
    )

    local disabled = H.step(H.body(f.addon, ENH), 'enh-icy-fire-elemental')
    assert(disabled.disabled == true and disabled.action == 2894)
end)

test('Wowhead & wowsims variant: Fire Nova weave, unconditional Flame Shock, totem twist, Rage when low', function()
    local f, s = fixture(70)
    H.learn(f, s, unpack(ENH70))
    fight(s)
    assert(H.first(f, s, SIM) == 17364)
    s.cooldown[17364] = 8
    assert(H.first(f, s, SIM) == 1535, 'Fire Nova weave after Stormstrike')
    s.totems[1] = 1535
    s.ttd = 6
    assert(H.first(f, s, SIM) == 8050, 'Flame Shock whenever it is down, even on a dying target')
    assert(H.first(f, s, ENH) == 8042, 'the Icy Veins variant skips it')
    s.debuffs = { { id = 17364 }, { id = 8050 } }
    assert(H.first(f, s, SIM) == 8042)
    s.buffs = { { id = 24398 } }
    s.enchant = { main = true, off = true }
    s.totems = { nil, 8075, 5675 }
    assert(lit(f, s, SIM) == '3599,8512', 'fire slot refilled with Searing; air slot gets Windfury first')
    s.totems[4] = 8512
    s.history[1] = { spell = 8512, time = s.now - 2 }
    assert(lit(f, s, SIM) == '3599,8835', 'Grace of Air one second after Windfury')
    s.totems[4] = 8835
    assert(lit(f, s, SIM) == '3599', 'Windfury is not recast within 8.5 s')
    s.history[1].time = s.now - 9
    assert(lit(f, s, SIM) == '3599,8512', 'twist back to Windfury')
    s.totems[1] = 3599
    s.totems[4] = 8512
    s.history[1].time = s.now - 0.5
    assert(lit(f, s, SIM) == '')
    s.mana = 0.3
    assert(lit(f, s, SIM) == '30823', 'Shamanistic Rage only when mana runs low')
end)

test('Elemental (Icy Veins & wowsims): Bolt filler, adaptive Chain Lightning, Flame Shock only while moving', function()
    local f, s = fixture(20, { 11, 0, 0 })
    s.near = true
    fight(s)
    assert(H.first(f, s, ELE) == nil, 'before Chain Lightning a target in melee is left to auto-attack')
    s.near = false
    assert(H.first(f, s, ELE) == 403)
    H.learn(f, s, 421, 8050, 16166, 1535, 8190)
    s.level = 70
    s.near = true
    s.mana = 0.5
    assert(H.first(f, s, ELE) == 403, 'Bolt filler at 70 without a reason to Chain')
    s.buffs = { { id = 16166 } }
    assert(H.first(f, s, ELE) == 421, 'Chain Lightning with Elemental Mastery')
    s.buffs = { { id = 16246 } }
    s.mana = 0.5
    assert(H.first(f, s, ELE) == 421, 'Clearcasting with mana to spare')
    s.mana = 0.3
    assert(H.first(f, s, ELE) == 403)
    s.buffs = {}
    s.mana = 0.9
    assert(H.first(f, s, ELE) == 421, 'mana surplus')
    s.mana = 0.5
    s.moving = true
    assert(H.first(f, s, ELE) == 8050, 'Flame Shock while moving')
    s.debuffs = { { id = 8050 } }
    local spell, result = H.first(f, s, ELE)
    assert(not spell and result.status == 'stopped', 'nothing else while moving')
    s.moving = false
    s.debuffs = {}
    assert(H.first(f, s, ELE) == 403, 'no Flame Shock when standing')
    s.enemies = 3
    assert(H.first(f, s, ELE) == 1535)
    s.totems[1] = 1535
    assert(H.first(f, s, ELE) == 421, 'Chain Lightning for packs')
    s.target.cast = true
    assert(H.first(f, s, ELE) == 8042, 'interrupt')
end)

test('Elemental upkeep: caster totems, Totemic Call, Mastery paired with Chain Lightning', function()
    local f, s = fixture(70, { 41, 20, 0 })
    H.learn(f, s, 421, 16166, 30706, 3599, 3738, 5675, 36936, 24398, 8232)
    s.buffs = { { id = 24398 } }
    s.enchant.main = true
    assert(lit(f, s, ELE) == '')
    fight(s)
    assert(lit(f, s, ELE) == '3738,16166,30706', 'Wrath of Air, Totem of Wrath, Elemental Mastery')
    s.ttd = 40
    assert(lit(f, s, ELE) == '3738,5675,16166,30706', 'Mana Spring on a long fight; Searing yields to Totem of Wrath')
    s.cooldown[421] = 3
    assert(lit(f, s, ELE) == '3738,5675,30706', 'Mastery waits for Chain Lightning')
    s.known[30706] = nil
    assert(lit(f, s, ELE) == '3599,3738,5675', 'Searing without Totem of Wrath')
    s.combat = false
    s.target = nil
    s.totems = { 3599 }
    assert(lit(f, s, ELE) == '36936', 'Totemic Call refunds mana after the fight')
end)

test(
    'Elemental (Wowhead): Chain Lightning on cooldown at 70, buffs only while leveling, Earth Shock to finish',
    function()
        local f, s = fixture(70, { 41, 20, 0 })
        H.learn(f, s, 421, 8050, 16166)
        fight(s)
        s.near = false
        s.mana = 0.5
        assert(H.first(f, s, EWH) == 421 and H.first(f, s, ELE) == 403, 'Wowhead chains on cooldown; Icy Veins bolts')
        s.level = 50
        assert(H.first(f, s, EWH) == 403)
        s.buffs = { { id = 16246 } }
        assert(H.first(f, s, EWH) == 421)
        s.buffs = {}
        s.ttd = 1.5
        assert(H.first(f, s, EWH) == 8042 and H.first(f, s, ELE) == 403, 'Earth Shock only before a cast would land')
    end
)

test('Elemental (NextActionTBC): Flame Shock upkeep, Chain Lightning only on two enemies, Lightning Shield', function()
    local f, s = fixture(70, { 41, 20, 0 })
    H.learn(f, s, 421, 8050, 16166, 324, 24398, 30706, 3738)
    fight(s)
    assert(H.first(f, s, ENA) == 8050, 'keeps Flame Shock up')
    s.debuffs = { { id = 8050, remain = 1 } }
    assert(H.first(f, s, ENA) == 8050, 'refreshes under 2 s')
    s.debuffs = { { id = 8050, remain = 10 } }
    assert(H.first(f, s, ENA) == 403)
    s.enemies = 2
    assert(H.first(f, s, ENA) == 421)
    s.mana = 0.2
    assert(H.first(f, s, ENA) == 403, 'Chain Lightning needs 30% mana')
    s.moving = true
    assert(H.first(f, s, ENA) == nil)
    s.moving = false
    s.enchant.main = true
    assert(lit(f, s, ENA) == '324,16166', 'Lightning Shield, not Water Shield; no totem reminders')
end)

test('Restoration: emergencies, cures, Earth Shield, Chain Heal for a hurt group, Healing Wave', function()
    local f, s = fixture(70, { 0, 20, 41 })
    H.learn(f, s, 331, 8004, 1064, 974, 16188, 526, 2870, 8050, 24398, 16190, 5675, 8075, 2825)
    s.target = { hostile = false, health = 0.95 }
    fight(s)
    local spell, result = H.first(f, s, RESTO)
    assert(not spell and result.status == 'stopped' and result.suppressAttack, 'healthy target: nothing to heal')
    s.target.health = 0.8
    assert(H.first(f, s, RESTO) == 331)
    s.party = { 0.5, 0.6, 0.7 }
    assert(H.first(f, s, RESTO) == 1064, 'Chain Heal for three hurt allies')
    s.target.isFocus = true
    assert(H.first(f, s, RESTO) == 974, 'Earth Shield on the focused tank')
    s.targetBuffs = { { id = 974 } }
    s.debuffs = { { id = 1, dispel = 'Poison' } }
    assert(H.first(f, s, RESTO) == 526)
    s.debuffs = { { id = 1, dispel = 'Disease' } }
    assert(H.first(f, s, RESTO) == 2870)
    s.debuffs = {}
    s.target.health = 0.35
    assert(H.first(f, s, RESTO) == 8004, 'Lesser Healing Wave in an emergency')
    s.target.health = 0.2
    assert(H.first(f, s, RESTO) == 16188, 'Nature\'s Swiftness when nearly dead')
    s.buffs = { { id = 16188 } }
    assert(H.first(f, s, RESTO) == 331, 'instant Healing Wave')
    s.target = nil
    s.buffs = { { id = 24398 } }
    s.party = {}
    spell = H.first(f, s, RESTO)
    assert(spell == nil, 'no target: only proximity heals')
    s.target = { hostile = true, health = 1, combat = true }
    assert(H.first(f, s, RESTO) == 8050, 'hostile target: solo damage')
    s.target = { hostile = false, enemy = true, dead = true, health = 0 }
    spell, result = H.first(f, s, RESTO)
    assert(not spell and result.suppressAttack, 'a dead enemy is not healed')
    s.target = { hostile = false, health = 1 }
    s.focus = { buffs = {} }
    s.group = true
    s.mana = 0.5
    assert(lit(f, s, RESTO) == '974,5675,8075,16190', 'Earth Shield on the focus, Mana Tide, group totems')
    s.focus.buffs = { { id = 974 } }
    s.totems = { nil, 8075, 5675 }
    assert(lit(f, s, RESTO) == '16190')
end)

test('profiles holding clones and preferences of the retired Shaman packs still load', function()
    local old, os = H.new('SHAMAN', { packs = { 'tests/fixtures/shaman_starter_pack.lua' } })
    os.level = 12
    local id = assert(old.addon:CloneDefaultRotation(0, 'rm.tbc.shaman.starter', 'My old starter'))
    assert(old.addon:SetDefaultRotationEnabled('rm.tbc.shaman.starter', false))
    local saved = H.copy({ library = old.addon.db.profile.rotationLibrary, rotations = old.addon.db.profile.rotations })
    local f, s, a = fixture(12)
    a.db.profile.rotationLibrary = saved.library
    a.db.profile.rotations = saved.rotations
    assert(a:InitializeRotationLibrary(), 'retired pack ids in saved preferences or origins must not break loading')
    local clone = assert(a:GetEditableRotation(0, id), 'the clone is an independent saved rotation')
    assert(clone.rotation[1].action == 403)
    assert(not a:GetDefaultRotation('rm.tbc.shaman.starter'))
    assert(H.selected(f, s) == ENH)
end)

finish()
