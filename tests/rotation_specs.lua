-- A rotation's specializations are its own property, body.specs (the user,
-- 2026-10-24): the minimap list, /rm set and the Rotations list read it, the
-- switch condition never decides whether a rotation is listed or can be chosen
-- by hand (it could be anything, "in PvP" included), and automatic switching
-- tries the specialization first, then the switch, then priority.
--
-- What a value means is a static fact of the client (Platform/specializations.lua
-- GetRotationSpecKind): specialization IDs where they are the same on every
-- account (Retail with its "No specialization" IDs, Mists of Pandaria Classic),
-- talent groups everywhere dual specialization exists or will (Era, TBC,
-- Wrath, Cataclysm, Forever), whatever the character's level. Talent groups
-- never leave the character: exports drop them, imports fill them in.
local T = dofile('tests/fixtures/toc_addon.lua')
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for k, v in pairs(a) do
        if not same(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local function show(v)
    if type(v) ~= 'table' then
        return tostring(v)
    end

    local keys = {}

    for k in pairs(v) do
        keys[#keys + 1] = k
    end

    table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
    local out = {}

    for _, k in ipairs(keys) do
        out[#out + 1] = tostring(k) .. '=' .. show(v[k])
    end

    return '{' .. table.concat(out, ',') .. '}'
end

local function platform(project, expansion)
    local f = F.new(project, expansion)
    f.load('Platform/specializations.lua')
    return f
end

local function key(a, id)
    return a:GetScopedRotationCoordinator():Key({ kind = 'builtin', id = id })
end

local function custom(f, spec, name, body)
    local a = f.addon
    local ref = assert(a:NewRotationDraftTarget(spec, 'class'))
    body = body or {}
    body.name = name
    body.rotation = body.rotation or { { id = 'a1', type = 'assisted', conditions = {} } }
    body.cooldowns = body.cooldowns or {}
    assert(a:CommitRotationDraft(ref, nil, { body = body }, 'class'))
    return a:GetScopedRotationCoordinator():Key(ref), ref
end

local function spec(n)
    return { type = 'SPECIALIZATION', spec = n }
end

local function level(n)
    return { type = 'LEVEL', unit = 'player', operator = 'GREATERTHANOREQUALS', value = n }
end

local COMBAT = { type = 'COMBAT', unit = 'player' }

-- Platform/specializations.lua's table, client by client.
test(
    'classification: specialization IDs on Retail and Mists Classic, talent groups on every dual-specialization client',
    function()
        local rows = {
            { 1, 12, 'portable', true, 'Retail' },
            { 19, 4, 'portable', false, 'Mists of Pandaria Classic' },
            { 2, 0, 'slot', false, 'Classic Era and Season of Discovery' },
            { 5, 1, 'slot', false, 'TBC Anniversary' },
            { 11, 2, 'slot', true, 'Wrath Classic' },
            { 14, 3, 'slot', true, 'Cataclysm Classic' },
            { 18, 12, 'slot', false, 'Forever' },
        }

        for _, row in ipairs(rows) do
            local p = platform(row[1], row[2]).addon.Platform
            assert(p:GetRotationSpecKind() == row[3], row[5] .. ': ' .. tostring(p:GetRotationSpecKind()))
            assert(p:RotationKeyIsSpecValue() == row[4], row[5] .. ' namespace')

            if row[3] == 'slot' then
                local choices = assert(p:GetRotationSpecChoices(10))

                assert(
                    #choices == 2 and choices[1].id == 1 and choices[2].id == 2 and choices[1].slot,
                    row[5] .. ': both talent groups'
                )
            end
        end

        local unknown = platform(999, 12).addon.Platform

        assert(
            unknown:GetRotationSpecKind() == nil and unknown:GetRotationSpecValue() == nil,
            'an unknown client has no specializations'
        )
    end
)

test(
    'the current value: the active talent group on slot clients (a low-level Forever character is in group 1), the specialization ID elsewhere',
    function()
        -- Forever before dual specialization: the client still answers group 1.
        local forever = platform(18, 12)
        forever.env.C_SpecializationInfo = { GetActiveSpecGroup = function() return 1 end }
        assert(forever.addon.Platform:GetRotationSpecValue() == 1)
        forever.env.C_SpecializationInfo = { GetActiveSpecGroup = function() return 2 end }
        assert(forever.addon.Platform:GetRotationSpecValue() == 2)
        -- No talent-group API at all: the only group there is.
        local era = platform(2, 0)
        era.env.C_SpecializationInfo = nil
        era.env.GetActiveTalentGroup = nil
        assert(era.addon.Platform:GetRotationSpecValue() == 1)
        local tbc = platform(5, 1)
        tbc.env.C_SpecializationInfo = nil
        tbc.env.GetActiveTalentGroup = function() return 2 end
        assert(tbc.addon.Platform:GetRotationSpecValue() == 2)
        local mists = platform(19, 4)

        mists.env.C_SpecializationInfo = {
            GetSpecialization = function() return 1 end,
            GetSpecializationInfo = function() return 268, 'Brewmaster' end,
            GetActiveSpecGroup = function() return 2 end,
        }

        assert(
            mists.addon.Platform:GetRotationSpecValue() == 268,
            'Mists names the specialization, not its talent group'
        )

        mists.env.C_SpecializationInfo.GetSpecialization = function() return nil end
        assert(mists.addon.Platform:GetRotationSpecValue() == nil, 'no specialization chosen yet is unknown')
        local retail = platform(1, 12)

        retail.env.C_SpecializationInfo = {
            GetSpecialization = function() return 5 end,
            GetSpecializationInfo = function() return 1450, 'Initial' end,
        }

        assert(retail.addon.Platform:GetRotationSpecValue() == 1450, '"No specialization" is a value of its own')
    end
)

-- The minimap list and /rm set: the specialization, never the switch.
test(
    'a switch condition never hides a rotation from the minimap list or manual selection; another specialization does',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        local pvp = custom(f, 268, 'Only in PvP', { priority = 5, switch = { type = 'PVP', unit = 'player' } })
        local ww = custom(f, 268, 'Windwalker only', { priority = 5, specs = { 269 }, switch = COMBAT })
        local pass = a:AcquireRotationRuntimePass(268)
        local listed = pass:Candidates(false)
        assert(listed[pvp], 'a rotation whose switch does not match left the minimap list')
        assert(listed[ww] == nil, 'another specialization reached the minimap list')
        assert(a:ExplainRotationRefusal(268, pvp) == nil, 'manual selection refused over a switch')
        local why, code = a:ExplainRotationRefusal(268, ww)
        assert(code == 'specialization-mismatch' and why == 'it is for another specialization', tostring(why))
        -- A Built In of another specialization says the same, from its body.specs.
        local _, builtinCode = a:ExplainRotationRefusal(268, key(a, 'rm.retail.monk.windwalker'))
        assert(builtinCode == 'specialization-mismatch', tostring(builtinCode))
        -- /rm set by identifier selects the PvP one by hand.
        a:HandleCommand('set only-in-pvp')
        assert(a.currentRotation == pvp and a.manualRotation, 'manual selection failed')
        -- Respec to Windwalker: now the Windwalker rotation is listed (it lives where it was saved).
        f.state.specIndex = 3
        f.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
        assert(a.currentSpec == 269)
        listed = a:AcquireRotationRuntimePass(269):Candidates(false)
        assert(listed[ww] and listed[pvp], 'respec did not bring the Windwalker rotation')
        local report = table.concat(a:GetRotationIdentifierReport(), '\n')
        assert(report:find('Rotations for Windwalker', 1, true), report)
    end
)

test(
    'automatic switching: the specialization first, then the switch, then priority; no switch condition matches',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon

        for _, id in ipairs({ 'rm.retail.monk.brewmaster', 'rm.retail.monk.windwalker' }) do
            assert(a:SetDefaultRotationEnabled(id, false))
        end

        local mine = custom(f, 268, 'Brewmaster mine', { priority = 50, specs = { 268 }, switch = level(1) })
        local theirs = custom(f, 268, 'Windwalker mine', { priority = 60, specs = { 269 }, switch = level(1) })
        local plain = custom(f, 268, 'No switch', { priority = 40, specs = { 268 } })

        local function inOrder(key)
            for _, k in ipairs(a.autoswitchRotation) do
                if k == key then
                    return true
                end
            end
        end

        local function pick()
            a.db.profile.disable_autoswitch = false
            a:DisableRotation()
            a.manualRotation = false
            a:UpdateAutoSwitch()
            a:SwitchRotation()
            return a.currentRotation
        end

        assert(
            pick() == mine,
            'expected the Brewmaster rotation, got ' .. tostring(a:GetRotationName(a.currentRotation))
        )

        local order = a.autoswitchRotation
        local listed = {}

        for _, k in ipairs(order) do
            listed[k] = true
        end

        assert(listed[plain] and listed[mine], 'a rotation with no switch condition is tried by automatic switching')

        assert(
            a:HasSwitchCondition(level(1))
                and not a:HasSwitchCondition(nil)
                and not a:HasSwitchCondition({})
                and not a:HasSwitchCondition({ type = 'AND', value = {} })
        )

        local report = table.concat(a:GetRotationEligibilityReport(), '\n')
        assert(report:find('No switch [no-switch]: ready', 1, true) and not report:find('manual only', 1, true), report)

        assert(
            report:find('Windwalker mine [windwalker-mine]: cannot be selected, it is for Windwalker.', 1, true),
            report
        )

        assert(a:AcquireRotationRuntimePass(268):Get(theirs) == nil)
        -- With no switch it is chosen when it ranks first, exactly like any other rotation that matches.
        local top = custom(f, 268, 'Top, no switch', { priority = 70, specs = { 268 } })

        assert(
            pick() == top,
            'the highest priority among those that match was not chosen: ' .. tostring(a:GetRotationName(
                a.currentRotation
            ))
        )

        assert(a:PreviewAutoSwitch() == top)
        -- It can always be switched off, and then it is not tried.
        local off = custom(f, 268, 'Off, no switch', { priority = 90, specs = { 268 }, disabled = true })
        assert(pick() == top and not inOrder(off), 'a disabled rotation without a switch was tried')

        -- A rotation whose switch is a broken (unknown) condition is not "no switch": it cannot be selected.
        local broken = custom(f, 268, 'Broken', {
            priority = 95,
            specs = { 268 },
            switch = { type = 'NO_SUCH_CONDITION' },
        })

        assert(pick() == top and not inOrder(broken), 'a broken switch was treated as none')
        -- Its overlap with another Brewmaster rotation is judged with its specializations: none with Windwalker's.
        local overlaps = a:GetSwitchOverlaps(268)

        for _, entry in ipairs(overlaps[mine] or {}) do
            assert(entry.key ~= theirs, 'overlaps another specialization')
        end

        local found

        for _, entry in ipairs(overlaps[top] or {}) do
            if entry.key == mine then
                found = entry
            end
        end

        assert(
            found and found.kind == 'subsumes' and not found.tie,
            'a rotation with no switch overlaps one that has: ' .. tostring(found and found.kind)
        )

        f.state.specIndex = 3
        f.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
        a.manualRotation = false
        a:SwitchRotation()

        assert(
            a.currentRotation == theirs,
            'Windwalker did not switch: ' .. tostring(a:GetRotationName(a.currentRotation))
        )
    end
)

test('on a talent-group client body.specs holds the group, and switching groups changes what is listed', function()
    local f = T.new({ project = 5, expansion = 1, class = 'MAGE', level = 60 })
    local a = f.addon
    local group = 1
    f.env.C_SpecializationInfo.GetActiveSpecGroup = function() return group end
    a:InvalidateBuildContext('talents')
    assert(a:GetRotationSpecKind() == 'slot' and a:GetCurrentRotationSpecValue() == 1)
    local second = custom(f, 0, 'Second talents', { priority = 5, specs = { 2 }, switch = COMBAT })
    local either = custom(f, 0, 'Either', { priority = 5, switch = COMBAT })
    local listed = a:AcquireRotationRuntimePass(0):Candidates(false)
    assert(listed[either] and listed[second] == nil, 'the secondary talents rotation is listed in the primary group')
    group = 2
    f.fire('ACTIVE_TALENT_GROUP_CHANGED')
    a:InvalidateBuildContext('talents')
    listed = a:AcquireRotationRuntimePass(0):Candidates(false)
    assert(listed[either] and listed[second], 'switching to the secondary group did not list it')
    local entries = a:GetRotationSpecEntries()

    assert(
        #entries == 2 and entries[1].name:find('Primary', 1, true) and entries[2].name:find('Secondary', 1, true),
        show(entries)
    )

    assert(
        not a:DescribeRotationSpecs({ 2 }):find('2', 1, true) or a:DescribeRotationSpecs({ 2 }):find(
            'Secondary',
            1,
            true
        ),
        'a group is named, never "spec 2"'
    )
end)

-- The one-time profile migration.
local function store(records, key, class)
    class = class or 'MONK'
    local rows = {}

    for id, switch in pairs(records) do
        rows[id] = { body = { name = id, switch = switch, rotation = {}, cooldowns = {} } }
    end

    return {
        rotationFallbackID = 'Default-id',
        rotationStore = { version = 1, classes = { [class] = { [key] = rows } }, characters = {}, legacy = {} },
    }
end

local function body(profile, id, key, class)
    return profile.rotationStore.classes[class or 'MONK'][key][id].body
end

test(
    'migration on Retail: the namespace becomes body.specs, and exactly the shapes that filed a Built In move out of the switch',
    function()
        local a = T.new({ level = 10, specIndex = 1 }).addon

        local profile = store({
            only = spec(268),
            withLevel = { type = 'AND', value = { level(10), spec(268) } },
            withTwo = { type = 'AND', value = { level(10), spec(268), COMBAT } },
            either = { type = 'OR', value = { spec(268), spec(269) } },
            other = spec(269),
            negated = { type = 'NOT', value = spec(268) },
            mixed = { type = 'OR', value = { spec(268), COMBAT } },
            conflict = { type = 'AND', value = { spec(268), spec(269) } },
            disabled = { type = 'SPECIALIZATION', spec = 268, disabled = true },
            plain = COMBAT,
            ['Default-id'] = spec(268),
        }, 268)

        profile.rotationStore.classes.MONK[268].preset = {
            body = { name = 'preset', specs = {}, switch = spec(268), rotation = {}, cooldowns = {} },
        }

        assert(a:MoveRotationSpecsToProperty(profile) and profile.rotationSpecsMigrated)

        local function check(id, specs, switch)
            local b = body(profile, id, 268)

            assert(
                same(b.specs, specs) and same(b.switch, switch),
                id .. ': ' .. show(b.specs) .. ' ' .. show(b.switch)
            )
        end

        check('only', { 268 }, {})  -- it chose itself automatically, and still does: no switch matches
        check('withLevel', { 268 }, level(10))
        check('withTwo', { 268 }, { type = 'AND', value = { level(10), COMBAT } })
        check('either', { 268 }, {})
        check('other', { 268 }, spec(269))  -- never matched where it was saved; left as it was
        check('negated', { 268 }, { type = 'NOT', value = spec(268) })
        check('mixed', { 268 }, { type = 'OR', value = { spec(268), COMBAT } })
        check('conflict', { 268 }, { type = 'AND', value = { spec(268), spec(269) } })
        check('disabled', { 268 }, { type = 'SPECIALIZATION', spec = 268, disabled = true })
        check('plain', { 268 }, COMBAT)
        check('Default-id', nil, spec(268))  -- the fallback belongs to its namespace
        check('preset', {}, spec(268))  -- already has the property: untouched
        -- Once only: a rotation later set to Any stays Any.
        body(profile, 'only', 268).specs = nil
        assert(not a:MoveRotationSpecsToProperty(profile) and body(profile, 'only', 268).specs == nil)

        assert(
            a:ValidateProfileTransfer({ rotationSpecsMigrated = true })
                and not a:ValidateProfileTransfer({ rotationSpecsMigrated = 'yes' })
        )
    end
)

test(
    'migration elsewhere: Mists moves the switch only; Wrath files talent groups; Era, TBC and Forever move nothing',
    function()
        -- Mists: rotations are saved per talent group, but SPECIALIZATION reads the specialization ID.
        local mists = platform(19, 4)
        mists.load('Data/plain.lua')
        mists.load('Data/validation.lua')
        mists.load('Core/rotation_migration.lua')
        local profile = store({ brew = { type = 'AND', value = { level(10), spec(268) } }, plain = COMBAT }, 2)
        assert(mists.addon:MoveRotationSpecsToProperty(profile))

        assert(same(body(profile, 'brew', 2).specs, { 268 }) and same(body(profile, 'brew', 2).switch, level(10)), show(
            body(profile, 'brew', 2)
        ))

        assert(body(profile, 'plain', 2).specs == nil, 'a talent-group namespace became a specialization')
        -- Wrath: the namespace is the talent group; SPECIALIZATION there tests talent trees.
        local wrath = platform(11, 2)
        wrath.load('Data/plain.lua')
        wrath.load('Data/validation.lua')
        wrath.load('Core/rotation_migration.lua')
        profile = store({ tree = spec(62), plain = COMBAT }, 2, 'MAGE')
        assert(wrath.addon:MoveRotationSpecsToProperty(profile))

        assert(
            same(body(profile, 'tree', 2, 'MAGE').specs, { 2 }) and same(body(profile, 'tree', 2, 'MAGE').switch, spec(
                62
            )),
            show(body(profile, 'tree', 2, 'MAGE'))
        )

        assert(same(body(profile, 'plain', 2, 'MAGE').specs, { 2 }))

        for _, client in ipairs({ { 2, 0 }, { 5, 1 }, { 18, 12 } }) do
            local f = platform(client[1], client[2])
            f.load('Data/plain.lua')
            f.load('Data/validation.lua')
            f.load('Core/rotation_migration.lua')
            profile = store({ tree = spec(62), both = { type = 'AND', value = { spec(62), COMBAT } } }, 0, 'MAGE')
            assert(f.addon:MoveRotationSpecsToProperty(profile))

            for _, id in ipairs({ 'tree', 'both' }) do
                local b = body(profile, id, 0, 'MAGE')
                assert(b.specs == nil and b.switch.type ~= nil, id .. ' moved on ' .. client[1])
            end
        end
    end
)

-- The premades were converted once, by tokenizer (tests/fixtures/premade_spec_switches.lua holds
-- every pre-conversion switch that named a specialization).
test(
    'every converted premade: the old switch-derived specializations are its body.specs, and its switch is the old one minus them',
    function()
        local corpus = dofile('tests/fixtures/default_corpus.lua')
        local f, packs = corpus.load(5, 1, 'ROGUE')
        f.load('Data/plain.lua')
        f.load('Data/validation.lua')
        f.load('Core/rotation_migration.lua')
        local old = dofile('tests/fixtures/premade_spec_switches.lua')
        local byId = {}

        for _, p in ipairs(packs) do
            byId[p.id] = p
        end

        local count = 0

        for id, switch in pairs(old) do
            local p = assert(byId[id], id .. ' is gone')
            local specs, rest = f.addon:SplitSwitchSpecializations(switch)
            assert(specs, id .. ': the old switch was not a recognized shape')
            assert(same(p.body.specs, specs), id .. ': specs ' .. show(p.body.specs) .. ' expected ' .. show(specs))

            -- What was left of the switch; nothing left is no switch at all (it matches whenever the premade applies).
            if next(rest or {}) == nil then
                assert(p.body.switch == nil, id .. ': switch ' .. show(p.body.switch) .. ' expected none')
            else
                assert(
                    same(p.body.switch, rest),
                    id .. ': switch ' .. show(p.body.switch) .. ' expected ' .. show(rest)
                )
            end

            count = count + 1
        end

        assert(count == 155, count .. ' converted premades')

        -- Nothing else gained specializations, and slot editions never do.
        for _, p in ipairs(packs) do
            if p.body.specs then
                assert(old[p.id], p.id .. ' gained specs it never had')
            end

            local family = p.applicability.families[1]

            if family ~= 'retail' and family ~= 'progression' then
                assert(p.body.specs == nil, p.id .. ' has talent-group specs')
            end
        end
    end
)

-- Talent groups stay on the character.
local function exporter(project, expansion, body)
    local f = platform(project, expansion)
    f.load('Data/plain.lua')
    f.load('Data/validation.lua')
    f.load('Core/rotation_selection.lua')
    f.load('Core/rotation_library.lua')
    f.load('Core/imports.lua')
    local a = f.addon

    a.GetScopedRotationCoordinator = function()
        return { Snapshot = function() return { body = a.RotationData.CopyData(body) } end }
    end

    return a
end

test(
    'exports drop talent groups on every dual-specialization client (a low-level Forever character too) and keep specialization IDs',
    function()
        local body = { name = 'Mine', specs = { 2 }, rotation = {}, cooldowns = {} }

        for _, client in ipairs({ { 2, 0 }, { 5, 1 }, { 11, 2 }, { 14, 3 }, { 18, 12 } }) do
            local a = exporter(client[1], client[2], body)

            if client[1] == 18 then
                a.Platform.GetRotationSpecValue = function() return 1 end
            end

            local exported = assert(a:GetRotationExportData(0, 'x'))
            assert(exported.specs == nil, 'project ' .. client[1] .. ' exported a talent group')
        end

        for _, client in ipairs({ { 1, 12 }, { 19, 4 } }) do
            local a = exporter(client[1], client[2], { name = 'Mine', specs = { 268 }, rotation = {}, cooldowns = {} })

            assert(
                same(a:GetRotationExportData(268, 'x').specs, { 268 }),
                'project ' .. client[1] .. ' dropped specialization IDs'
            )
        end
    end
)

test(
    'imports fill in a talent group (the list\'s, else yours), keep specialization IDs, and refuse another class\'s',
    function()
        for _, client in ipairs({ { 2, 0 }, { 5, 1 }, { 11, 2 }, { 14, 3 }, { 18, 12 } }) do
            local a = exporter(client[1], client[2], {})
            a.GetRotationSpecValue = function() return 2 end

            assert(
                same(a:PrepareImportedRotationSpecs(nil), { 2 }),
                'project ' .. client[1] .. ': not the current group'
            )

            assert(same(a:PrepareImportedRotationSpecs({ 1 }), { 2 }), 'an imported group number was trusted')
            assert(same(a:PrepareImportedRotationSpecs(nil, 1), { 1 }), 'not the list\'s group')

            assert(
                a:PrepareImportedRotationSpecs(nil, nil, { reference = {} }) == nil,
                'a replacement does not keep its own'
            )
        end

        -- On a whole Retail client, through the real import.
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon

        local id = assert(a:CreateImportedRotation({
            body = {
                name = 'x',
                specs = { 269, 268 },
                rotation = { { id = 's', type = 'assisted', conditions = {} } },
                cooldowns = {},
            },
        }, 268, 'Imported'))

        local found

        for _, row in ipairs(a:ListRotationHeaders(268)) do
            if row.canonicalId == id then
                found = row
            end
        end

        assert(found and same(found.specs, { 268, 269 }), show(found and found.specs))

        local _, why = a:CreateImportedRotation({
            body = {
                name = 'y',
                specs = { 71 },
                rotation = { { id = 's', type = 'assisted', conditions = {} } },
                cooldowns = {},
            },
        }, 268, 'Warrior')

        assert(why == 'class-mismatch', tostring(why))
        -- A whole TBC client: the export carries none, the import is for the group you are in.
        local g = T.new({ project = 5, expansion = 1, class = 'MAGE', level = 60 })
        local b = g.addon
        g.env.C_SpecializationInfo.GetActiveSpecGroup = function() return 2 end
        b:InvalidateBuildContext('talents')

        local imported = assert(b:CreateImportedRotation({
            body = {
                name = 'z',
                specs = { 1 },
                rotation = { { id = 's', type = 'spell', action = 133, conditions = {} } },
                cooldowns = {},
            },
        }, 0, 'From a friend'))

        local key2

        for _, row in ipairs(b:ListRotationHeaders(0)) do
            if row.canonicalId == imported then
                key2 = row.key
                assert(same(row.specs, { 2 }), show(row.specs))
            end
        end

        assert(b:GetRotationExportData(0, key2).specs == nil)
    end
)

-- The list: a dropdown above the search box, filtering like the class does.
test(
    'the Rotations list: a specialization dropdown above the search box, the current one by default, a warning for another, All',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        local brew = custom(f, 268, 'Brew rot', { priority = 3, specs = { 268 } })
        local wind = custom(f, 268, 'Wind rot', { priority = 3, specs = { 269 } })
        local any = custom(f, 268, 'Any rot', { priority = 3 })
        local host = f.env.CreateFrame('Frame')
        host:SetSize(1000, 3000)
        local browser = a:CreateRotationBrowser(host, { spec = 268 })

        local function shown()
            local set = {}

            for _, row in ipairs(browser.rows) do
                set[row.key] = true
            end

            return set
        end

        assert(
            browser.specFilter:IsShown() and browser.specFilter:GetParent() == browser.left,
            'the dropdown is not inside the list column'
        )

        local _, _, _, _, searchY = browser.search:GetPoint(1)
        assert(searchY < 0, 'the search box is not below the dropdown')
        assert(browser.specValue == 268 and a.rotationListSpec == 268 and not browser.specWarning:IsShown())
        local rows = shown()

        assert(
            rows[brew] and rows[any] and not rows[wind] and not rows[key(a, 'rm.retail.monk.windwalker')],
            'the list is not filtered by specialization'
        )

        browser:SetSpecValue(269)
        rows = shown()
        assert(rows[wind] and rows[any] and not rows[brew] and rows[key(a, 'rm.retail.monk.windwalker')])

        assert(
            browser.specWarning:IsShown()
                and browser.specWarning:GetText() == 'This is not your current specialization.',
            'no warning for another specialization'
        )

        assert(browser.spec == 269, 'the namespace (its fallback) did not follow')
        -- A new rotation is for the specialization the list shows.
        browser.newButton:Click()

        assert(
            same(browser.pane.workspace:Snapshot().specs, { 269 }),
            'new rotation: ' .. show(browser.pane.workspace:Snapshot().specs)
        )

        browser:SetSpecValue('all')
        rows = shown()
        assert(rows[wind] and rows[any] and rows[brew] and not browser.specWarning:IsShown())
        browser:Release()
        assert(a.rotationListSpec == nil)
        -- Session only: reopening starts at the current specialization again.
        browser = a:CreateRotationBrowser(host, { spec = 268 })
        assert(browser.specValue == 268)
        browser:Release()
    end
)

test(
    'the editor header: a specialization picker first on the name line, several or Any, read-only on a Built In',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        local parent = f.env.CreateFrame('Frame')
        parent:SetSize(900, 700)
        local pane = assert(a:CreateRotationEditor(parent, 268, key(a, 'rm.retail.monk.brewmaster')))
        pane:Layout()

        assert(
            pane.specButton:IsShown() and not pane.specButton:IsEnabled() and pane.specButton:GetText() == 'Brewmaster',
            'Built In picker'
        )

        local _, _, _, x, y = pane.specButton:GetPoint(1)
        local _, _, _, nameX, nameY = pane.name:GetPoint(1)

        assert(
            x == 8 and y > nameY - 8 and nameX > x + pane.specButton:GetWidth(),
            'the picker is not first on the name line'
        )

        local mineKey = custom(f, 268, 'Mine', { specs = { 268 }, switch = COMBAT })
        pane = assert(a:CreateRotationEditor(parent, 268, mineKey))
        pane:Layout()
        assert(pane.specButton:IsEnabled() and pane.specButton:GetText() == 'Brewmaster')
        pane.specButton:Click()
        pane.specMenu.changed(269)

        assert(
            same(pane.workspace:Snapshot().specs, { 268, 269 })
                and pane.specButton:GetText() == 'Brewmaster, Windwalker',
            show(pane.workspace:Snapshot().specs)
        )

        pane.specMenu.changed('any')
        assert(pane.workspace:Snapshot().specs == nil and pane.specButton:GetText() == 'Any specialization')
        pane.apply:Click()
        local saved

        for _, row in ipairs(a:ListRotationHeaders(268)) do
            if row.key == mineKey then
                saved = row
            end
        end

        assert(saved and saved.specs == nil, 'Any was not saved')
        -- The fallback shows the specialization it belongs to, read-only (see below).
        local fallback = assert(a:CreateRotationEditor(parent, 268, DEFAULT or f.env.DEFAULT))
        fallback:Layout()

        assert(
            fallback.specButton:IsShown()
                and not fallback.specButton:IsEnabled()
                and fallback.specButton:GetText() == 'Brewmaster',
            'Default picker'
        )
    end
)

-- The fallback's own editor page shows the specialization it belongs to, in
-- the same control as every rotation but read-only, worded like the list's
-- specialization dropdown.
test(
    'the Default\'s editor shows its specialization read-only: a specialization, "No specialization", a talent group, or All',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        local parent = f.env.CreateFrame('Frame')
        parent:SetSize(900, 700)
        local entries = a:GetRotationSpecEntries()
        local names = {}

        for _, entry in ipairs(entries) do
            names[entry.id] = entry.name
        end

        for _, entry in ipairs(entries) do
            local pane = assert(a:CreateRotationEditor(parent, entry.id, f.env.DEFAULT))
            assert(pane.workspace.fallback)
            pane:Layout()

            assert(
                pane.specButton:IsShown() and not pane.specButton:IsEnabled(),
                'the Default of ' .. entry.name .. ' has no read-only picker'
            )

            assert(
                pane.specButton:GetText() == entry.name,
                'the Default of ' .. entry.name .. ' says ' .. tostring(pane.specButton:GetText())
            )

            pane.specButton:Click()
            assert(not pane.specMenu.frame or not pane.specMenu.frame:IsShown(), 'a read-only picker opened a menu')
            assert(pane.workspace:Snapshot().specs == nil and not pane.workspace:IsDirty(), 'the Default changed')
            local _, _, _, x = pane.specButton:GetPoint(1)
            assert(x == 8, 'the Default picker is not first on the name line')
            pane:Release()
        end

        local initial

        for _, entry in ipairs(entries) do
            if entry.initial then
                initial = entry
            end
        end

        assert(
            initial and initial.name == 'No specialization',
            "Retail's initial specialization is labeled No specialization"
        )

        -- Where one Default serves every specialization, it says so.
        local era = T.new({ project = 2, expansion = 0, level = 10 })
        local ea = era.addon
        local eparent = era.env.CreateFrame('Frame')
        eparent:SetSize(900, 700)
        local pane = assert(ea:CreateRotationEditor(eparent, 0, era.env.DEFAULT))
        pane:Layout()

        assert(
            ea:GetRotationSpecKind() == 'slot'
                and pane.specButton:IsShown()
                and not pane.specButton:IsEnabled()
                and pane.specButton:GetText() == 'All specializations',
            tostring(pane.specButton:GetText())
        )
    end
)

-- The header's geometry (both rows, every locale, two widths) is proved in
-- tests/rotation_header_layout.lua.
-- A list row's line is only the kind, the specialization and the priority; the
-- rest (read-only, switched off, not available) is color and tooltip.
test(
    'a list row says kind, specialization and priority on one line at the narrowest window (in every language), and nothing else',
    function()
        -- The width of a line of text in a font of `size` (the mock's default, 12, is the full measure).
        local function width(text, size)
            local w = 0

            for char in (text or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
                w = w + (#char == 1 and 6 or 7)
            end

            return w * (size or 12) / 12
        end

        for _, language in ipairs({
            'enUS', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'
        }) do
            -- The fixture boots the addon in the game language, the way the client does.
            local f = T.new({ level = 10, specIndex = 1, locale = language })
            local a = f.addon

            for _, id in ipairs({ 'rm.retail.monk.windwalker', 'rm.retail.monk.mistweaver' }) do
                assert(a:SetDefaultRotationEnabled(id, false))
            end

            custom(f, 268, 'Mine', { specs = { 268, 269, 270 }, switch = COMBAT, priority = 7 })
            local host = f.env.CreateFrame('Frame')
            host:SetSize(800 - 24, 500)
            local browser = a:CreateRotationBrowser(host, { spec = 268 })
            browser:SetSpecValue('all')
            local seen = {}
            local shrunk = false

            -- Text is measured per character (a Cyrillic or accented letter is wider), as the client measures it.
            for _, c in ipairs(browser.rowButtons) do
                function c.statusLabel:GetStringWidth()
                    local _, size = self:GetFont()
                    return width(self.text, size)
                end
            end

            browser:RefreshRows()

            for _, c in ipairs(browser.rowButtons) do
                if c:IsShown() and c.browserEntry then
                    local entry = c.browserEntry
                    local text = c.statusLabel:GetText()
                    local label = language .. ' ' .. tostring(entry.name)
                    local parts = {}

                    for part in (text .. ' · '):gmatch('(.-) · ') do
                        parts[#parts + 1] = part
                    end

                    assert(
                        #parts == (entry.fallback and 2 or 3),
                        label
                            .. ': the line is not kind, specialization'
                            .. (entry.fallback and '' or ', priority')
                            .. ': '
                            .. text
                    )

                    assert(
                        not text:find('only', 1, true)
                            and not text:find('Disabled', 1, true)
                            and not text:find('Not available', 1, true)
                            and not text:find('Ships', 1, true),
                        label .. ': extra words: ' .. text
                    )

                    if not entry.fallback then
                        assert(parts[3]:find('%d+$'), label .. ': the priority was cut: ' .. text)
                    end

                    assert(c.statusLabel:GetWidth() < 220, 'not the narrow column: ' .. c.statusLabel:GetWidth())

                    local _, size = c.statusLabel:GetFont()

                    assert(
                        width(text, size) <= c.statusLabel:GetWidth(),
                        label .. ': the line is wider than the column (' .. width(text, size) .. '): ' .. text
                    )

                    -- The caption only shrinks as far as it still reads, and never for a line that fits.
                    assert(size >= 8, label .. ': the line shrank below a readable size: ' .. size)
                    shrunk = shrunk or size < 12

                    seen[entry.fallback and 'fallback' or entry.readOnly and 'builtin' or 'custom'] = text
                end
            end

            assert(seen.fallback and seen.builtin and seen.custom, language .. ': a kind of row was not listed')

            -- English fits without shrinking; German's long kind word is what needs it.
            assert(language ~= 'enUS' or not shrunk, 'the English line shrank')
            assert(language ~= 'deDE' or shrunk, 'the German line fits without shrinking, so the test proves nothing')

            if language == 'enUS' then
                assert(
                    seen.custom:find('^Custom · ') and seen.custom:find('…') and seen.custom:find('Priority 7$'),
                    'long specializations give way, kind and priority stay: ' .. seen.custom
                )

                assert(seen.fallback:find('^Fallback · ') and not seen.fallback:find('Priority'), seen.fallback)
                assert(seen.builtin:find('^Built In · ') and seen.builtin:find('Priority %-?%d+$'), seen.builtin)
            end
        end
    end
)

-- Each specialization has its own fallback (Default), kept under its key. The
-- list shows the Default of the specialization it is set to, and "All
-- specializations" shows every one's, each named by its specialization.
test('the Rotations list shows each specialization\'s Default, and All lists every one of them, selectable', function()
    local f = T.new({ level = 10, specIndex = 1 })
    local a = f.addon
    local host = f.env.CreateFrame('Frame')
    host:SetSize(1000, 3000)
    local browser = a:CreateRotationBrowser(host, { spec = 268 })

    local function defaults()
        local list = {}

        for _, row in ipairs(browser.rows) do
            if row.fallback then
                list[#list + 1] = row
            end
        end

        return list
    end

    local function control(row)
        for _, c in ipairs(browser.rowButtons) do
            if c.browserEntry == row and c:IsShown() then
                return c
            end
        end
    end

    -- One specialization: its own Default only.
    local own = defaults()
    assert(#own == 1 and own[1].spec == 268, 'the current specialization shows more or less than its Default: ' .. #own)
    browser:SetSpecValue(269)
    own = defaults()

    assert(
        #own == 1
            and own[1].spec == 269
            and browser.spec == 269
            and browser.pane.workspace.fallback
            and browser.pane.workspace.spec == 269,
        'another specialization does not show its own Default'
    )

    assert(browser.specWarning:IsShown(), 'no not-your-specialization warning')
    -- All: every specialization has one, in the namespace it belongs to.
    browser:SetSpecValue('all')
    local all = defaults()
    local entries = browser.specEntries

    assert(
        #entries >= 3 and #all == #entries,
        'All lists ' .. #all .. ' Defaults for ' .. #entries .. ' specializations'
    )

    local seen = {}

    for _, row in ipairs(all) do
        assert(not seen[row.spec], 'two Defaults for one specialization')
        seen[row.spec] = row
    end

    for _, entry in ipairs(entries) do
        assert(seen[entry.id], 'no Default for ' .. tostring(entry.name))
    end

    assert(a.currentSpec == 268 and all[1].spec == 268, 'your own Default does not come first')

    -- Each says which specialization it is for; the Retail "No specialization" has its own.
    for _, entry in ipairs(entries) do
        local row = seen[entry.id]
        local c = assert(control(row), 'row not drawn for ' .. entry.name)

        assert(
            c.statusLabel:GetText():find(entry.name, 1, true),
            'the row does not name ' .. entry.name .. ': ' .. c.statusLabel:GetText()
        )
    end

    local initial

    for _, entry in ipairs(entries) do
        if entry.initial then
            initial = entry
        end
    end

    assert(initial and seen[initial.id], '"No specialization" has no Default of its own')
    -- Selecting another specialization\'s Default edits that one, in its namespace, without changing what you are playing.
    local target = seen[269]
    local c = control(target)
    c.scripts.OnClick(c)

    assert(
        browser.spec == 269
            and browser.selected == target.key
            and browser.pane.workspace.fallback
            and browser.pane.workspace.spec == 269,
        'the Default of another specialization did not open'
    )

    assert(
        browser.specValue == 'all' and #defaults() == #entries and a.currentSpec == 268,
        'selecting a Default changed the list or the active specialization'
    )

    local name = browser.pane.workspace.reference.address.spec
    assert(name == 269)
    -- Another of them, then back: the search survives moving between Defaults.
    browser.search:SetText('def')
    browser.search.scripts.OnTextChanged(browser.search, true)
    c = control(seen[270] or seen[268])

    if c then
        c.scripts.OnClick(c)
    end

    assert(browser.query == 'def', 'the search was cleared by moving to another Default')
    browser:Release()
end)

-- A new rotation fills its own identifier in from its name; that is not an
-- edit, so moving on from an untouched one neither asks nor leaves it listed.
test('an untouched new rotation neither prompts nor lingers when you choose another one', function()
    local f = T.new({ level = 10, specIndex = 1 })
    local a = f.addon
    local host = f.env.CreateFrame('Frame')
    host:SetSize(1000, 3000)
    local browser = a:CreateRotationBrowser(host, { spec = 268 })
    local target = key(a, 'rm.retail.monk.brewmaster')
    browser.newButton:Click()
    local pane = browser.pane
    local made = browser.selected
    assert(pane.workspace.pending and pane.identifierDirty, 'the identifier was not filled in on its own')
    browser:SelectRotation(268, target)
    assert(not (pane.leavePrompt and pane.leavePrompt.frame:IsShown()), 'an untouched new rotation asked what to do')

    assert(
        browser.selected == target and not browser.rowsByKey[made] and #a:ListPendingRotationDrafts(268) == 0,
        'it stayed in the list'
    )

    -- Typing a name makes it a draft worth asking about.
    browser.newButton:Click()
    pane = browser.pane
    pane.name:SetText('Mine')
    pane.name.scripts.OnTextChanged(pane.name, true)
    browser:SelectRotation(268, target)
    assert(pane.leavePrompt and pane.leavePrompt.frame:IsShown(), 'an edited draft did not ask')
    pane.leavePrompt.discard:Click()
    assert(#a:ListPendingRotationDrafts(268) == 0 and browser.selected == target)
    browser:Release()
end)

finish()
