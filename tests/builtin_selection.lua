-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built Ins are selectable whenever /rm why calls them ready: in the minimap menu, by
-- automatic switching (before the fallback, which is the last resort), and their on/off
-- switch is the player's choice alone.
--
-- The user's report (Retail 12.1.5, a Monk levelling 7 to 11, Brewmaster at 10): eligible
-- Built Ins were never auto-selected and the menu offered only Automatic Switching and
-- Default. Two causes, both reproduced here on the real addon (tests/fixtures/toc_addon.lua):
-- the saved fallback (Default) beat every Built In in automatic switching, and the
-- Brewmaster pack carried a saved enabled=false the player never chose. The Built In
-- toggle showed a pack that did not validate as "Disabled" (validity and the switch were
-- one flag) and the editor flipped a cached copy of it, so trying to turn a pack "on" could
-- save it off. Validity and the switch are now apart, the toggle reads the live switch, a
-- choice equal to the shipped default is not stored, and a one-time repair clears the
-- enabled=false entries of packs that ship enabled.
local T = dofile('tests/fixtures/toc_addon.lua')
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local out = {}

    for k, x in pairs(v) do
        out[copy(k)] = copy(x)
    end

    return out
end

local function menu(f)
    local rows = {}

    f.env.UIDropDownMenu_AddButton = function(r)
        rows[#rows + 1] = copy(r)
    end

    f.env.minimapInitialize()
    return rows
end

local function menuText(rows)
    local list = {}

    for _, r in ipairs(rows) do
        list[#list + 1] = tostring(r.text)
    end

    return table.concat(list, '\n')
end

local function why(f)
    return table.concat(f.addon:GetRotationEligibilityReport(), '\n')
end

local function noLoadErrors(f)
    for _, e in ipairs(f.loadErrors) do
        assert(e:match('^Libs/'), 'addon file failed to load: ' .. e)
    end

    assert(not f.addon.initializationErrorReport, 'initialization failed')
end

local function fallback(f, spec, steps)
    local a = f.addon
    local ref = assert(a:NewRotationDraftTarget(spec, 'class', true))

    assert(a:CommitRotationDraft(
        ref,
        nil,
        { body = { rotation = steps or { { id = 'a1', type = 'assisted', conditions = {} } }, cooldowns = {} } },
        'class'
    ))
end

local function select(f)
    f.addon:UpdateAutoSwitch()
    f.addon:SwitchRotation()
end

local function current(f)
    local a = f.addon

    return a.currentRotation
        and (a.currentRotation == f.env.DEFAULT and 'Default'
            or a:GetDefaultIdForRuntime(a.currentSpec, a.currentRotation)
            or a.currentRotation)
end

local function preferences(f)
    return f.addon.db.profile.rotationLibrary.preferences
end

local function count(t)
    local n = 0

    for _ in pairs(t or {}) do
        n = n + 1
    end

    return n
end

local function logout(f)
    f.fire('PLAYER_LOGOUT')
    return copy(f.env.RotationMasterDB)
end

test(
    'Retail initial spec: the eligible Built In beats the saved fallback, is in the menu, and /rm why agrees',
    function()
        local f = T.new({ level = 7, specIndex = 5 })
        noLoadErrors(f)
        local a = f.addon
        assert(a.currentSpec == 1450, 'spec ' .. tostring(a.currentSpec))

        fallback(f, 1450, {
            { id = 't1', type = 'spell', action = 100780, ranked = false, conditions = {} },
            { id = 'a1', type = 'assisted', conditions = {} },
        })

        fallback(f, 268, {
            { id = 'r1', type = 'spell', action = 109132, ranked = false, conditions = {} },
            { id = 'a1', type = 'assisted', conditions = {} },
        })

        select(f)
        assert(current(f) == 'rm.retail.monk.initial', 'auto-switch chose ' .. tostring(current(f)))
        local rows = menu(f)
        local text = menuText(rows)
        assert(text:find('Automatic Switching', 1, true) and text:find('\nDefault\n', 1, true), text)
        assert(text:find('|cff5bc0ebBlizzard Assisted [initial]|r', 1, true), text)
        assert(not text:find('read%-only'), 'the menu still carries the read-only suffix: ' .. text)
        local report = why(f)
        assert(report:find('Blizzard Assisted (Built In) [initial]: ready', 1, true), report)
        assert(report:find('Automatic switching would choose: Blizzard Assisted', 1, true), report)
        assert(report:find('Higher numbers are tried first', 1, true), report)

        -- Choosing it by hand works from the menu entry itself.
        for _, r in ipairs(rows) do
            if r.text and r.text:find('[initial]', 1, true) then
                r.func(nil, r.arg1)
            end
        end

        assert(a.manualRotation and current(f) == 'rm.retail.monk.initial')
    end
)

test('Retail level-up and respec: Brewmaster Built In is chosen over the Brewmaster fallback', function()
    local f = T.new({ level = 9, specIndex = 5 })
    local a = f.addon

    fallback(f, 268, {
        { id = 'r1', type = 'spell', action = 109132, ranked = false, conditions = {} },
        { id = 'a1', type = 'assisted', conditions = {} },
    })

    f.state.level = 10
    f.fire('PLAYER_LEVEL_UP', 10)
    f.runPending()
    f.state.specIndex = 1
    f.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
    f.fire('ACTIVE_TALENT_GROUP_CHANGED')
    f.runPending()
    assert(a.currentSpec == 268, 'spec ' .. tostring(a.currentSpec))
    select(f)
    assert(current(f) == 'rm.retail.monk.brewmaster', 'auto-switch chose ' .. tostring(current(f)))
    assert(menuText(menu(f)):find('Blizzard Assisted with brews', 1, true))
    -- Switched off, the fallback is the last resort again.
    assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster', false))
    select(f)
    assert(current(f) == 'Default')
end)

test(
    'a fresh profile has every shipped-enabled Built In on, stores no choice, and a toggle stores exactly one',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        assert(count(preferences(f)) == 0, 'fresh profile already has preferences')

        for _, row in ipairs(a:GetBuiltinStates(268)) do
            local on, state, shipped = a:GetBuiltinSwitch(row.id)

            assert(
                on == not shipped and state == (shipped and 'shipped-disabled' or 'enabled'),
                row.id .. ' ' .. tostring(state)
            )
        end

        -- The Built In editor opens, renders and closes without writing anything.
        local key = a:GetScopedRotationCoordinator():Key({ kind = 'builtin', id = 'rm.retail.monk.brewmaster' })
        local parent = f.env.CreateFrame('Frame')
        local pane = assert(a:CreateRotationEditor(parent, 268, key))

        if pane.Render then
            pane:Render()
        end

        assert(
            pane.enable.selected == true and pane.enable.text == 'Enabled',
            'the toggle does not show the shipped default'
        )

        assert(count(preferences(f)) == 0, 'opening the editor wrote a preference')
        -- One click: exactly one choice saved; clicking back removes it (it equals the default).
        pane.enable.action()
        local saved = preferences(f)['rm.retail.monk.brewmaster']

        assert(
            count(preferences(f)) == 1 and saved and saved.enabled == false,
            'one click did not save exactly one choice'
        )

        assert(pane.enable.text == 'Disabled')
        pane.enable.action()
        assert(count(preferences(f)) == 0, 'returning to the default kept a stored choice')

        -- A pack that ships off: turning it on is a stored choice, turning it off again removes it.
        assert(
            a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide', true)
                and preferences(f)['rm.retail.monk.brewmaster.guide'].enabled == true
        )

        assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide', false) and count(preferences(f)) == 0)
    end
)

test(
    'a pack that cannot be validated is "not available", never "disabled", and its toggle still shows the switch',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        -- A condition the pack uses changes shape (its unit field becomes a number), so the
        -- pack's saved condition no longer validates, as with a definition from another version.
        local combat = a.conditionDefinitions.COMBAT
        local changed = {}

        for k, v in pairs(combat) do
            changed[k] = v
        end

        changed.fields = { unit = 'number' }
        a.conditionDefinitions.COMBAT = changed
        a.conditionRegistryVersion = (a.conditionRegistryVersion or 0) + 1
        local on, state = a:GetBuiltinSwitch('rm.retail.monk.brewmaster')
        assert(state == 'invalid' and on == true, 'invalid pack reads as ' .. tostring(state) .. '/' .. tostring(on))

        for _, row in ipairs(a:ListRotationHeaders(268)) do
            if row.canonicalId == 'rm.retail.monk.brewmaster' then
                assert(row.builtinState == 'invalid' and row.switchedOn == true)
            end
        end

        local report = why(f)
        assert(report:find('Blizzard Assisted with brews (Built In) [brewmaster]: cannot be selected', 1, true), report)

        assert(
            not report:find(
                'Brewmaster (Retail, Blizzard Assisted with brews) (Built In) [brewmaster]: disabled',
                1,
                true
            ),
            report
        )
    end
)

test(
    '/rm why and the menu name a Built In the player switched off; a one-time repair turns shipped-enabled ones back on',
    function()
        local f = T.new({ level = 10, specIndex = 1 })
        local a = f.addon
        assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster', false))
        local report = why(f)
        assert(report:find('Blizzard Assisted with brews (Built In) [brewmaster]: disabled by you', 1, true), report)
        local text = menuText(menu(f))
        -- No Brewmaster pack is on, so the alternative that ships off is named too.
        assert(text:find('2 Built In disabled: Blizzard Assisted with brews, Reference (Icy Veins)', 1, true), text)
        assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide', true))
        text = menuText(menu(f))
        assert(text:find('1 Built In disabled: Blizzard Assisted with brews|r', 1, true), text)
        assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide', false))
        -- A profile saved before the repair: a shipped-enabled pack off, a shipped-off pack off
        -- and on, and another class's pack off (unknown here, left alone).
        local saved = logout(f)
        local profile = saved.profiles[next(saved.profiles)]
        profile.builtinPreferenceRepairs = nil

        profile.rotationLibrary.preferences = {
            ['rm.retail.monk.brewmaster'] = { enabled = false },
            ['rm.retail.monk.windwalker'] = { enabled = false },
            ['rm.retail.monk.mistweaver'] = { enabled = false },
            ['rm.retail.monk.brewmaster.guide'] = { enabled = true },
            ['rm.retail.mage.frost'] = { enabled = false },
        }

        local g = T.new({ level = 10, specIndex = 1, saved = copy(saved) })
        local b = g.addon
        noLoadErrors(g)
        local prefs = b.db.profile.rotationLibrary.preferences

        assert(
            prefs['rm.retail.monk.brewmaster'] == nil and prefs['rm.retail.monk.windwalker'] == nil,
            'shipped-enabled packs were not turned back on'
        )

        assert(
            prefs['rm.retail.monk.mistweaver'].enabled == false
                and prefs['rm.retail.monk.brewmaster.guide'].enabled == true,
            'choices for shipped-off packs changed'
        )

        assert(prefs['rm.retail.mage.frost'].enabled == false, "another class's choice changed")
        assert(b.db.profile.builtinPreferenceRepairs.MONK == true)
        local chat = table.concat(g.state.chat, '\n')

        assert(
            chat:find('Built In rotations turned back on', 1, true) and chat:find(
                'Blizzard Assisted with brews',
                1,
                true
            ),
            chat
        )

        select(g)
        assert(current(g) == 'rm.retail.monk.brewmaster')
        -- It runs once: a choice made afterwards survives the next login, and nothing is said.
        assert(b:SetDefaultRotationEnabled('rm.retail.monk.brewmaster', false))
        local h = T.new({ level = 10, specIndex = 1, saved = logout(g) })

        assert(
            h.addon.db.profile.rotationLibrary.preferences['rm.retail.monk.brewmaster'].enabled == false,
            'the repair ran twice'
        )

        assert(not table.concat(h.state.chat, '\n'):find('turned back on', 1, true))
        local p = h.addon.db.profile

        assert(
            h.addon:ValidateProfileTransfer({
                rotationLibrary = h.addon:CopySettingsData(p.rotationLibrary),
                builtinPreferenceRepairs = h.addon:CopySettingsData(p.builtinPreferenceRepairs),
            }),
            'the repaired profile data does not validate'
        )

        assert(
            not h.addon:ValidateProfileTransfer({ builtinPreferenceRepairs = { MONK = 'yes' } })
                and not h.addon:ValidateProfileTransfer({ builtinPreferenceRepairs = { ['monk'] = true } })
        )

        assert(
            h.addon:ValidateProfileTransfer({ rotationLibrary = { preferences = { x = { priority = 5 } } } })
                and not h.addon:ValidateProfileTransfer({
                    rotationLibrary = { preferences = { x = { priority = 0.5 } } },
                })
        )
    end
)

test('Classic (TBC): an enabled Built In whose switch matches is chosen before the saved fallback', function()
    local f = T.new({ project = 5, expansion = 1, class = 'SHAMAN', level = 5 })
    noLoadErrors(f)
    local a = f.addon
    fallback(f, 0)
    select(f)
    assert(current(f) == 'rm.tbc.shaman.enhancement.icyveins', 'auto-switch chose ' .. tostring(current(f)))
    assert(menuText(menu(f)):find('|cff5bc0ebEnhancement (Icy Veins) [enhancement-icyveins]|r', 1, true))
    assert(why(f):find('Automatic switching would choose: Enhancement (Icy Veins)', 1, true))
    -- The same-switch alternative ships disabled: with the recommended one off, the fallback runs
    -- until the player enables the alternative.
    assert(a:SetDefaultRotationEnabled('rm.tbc.shaman.enhancement.icyveins', false))
    select(f)
    assert(not tostring(current(f)):find('^rm%.'), 'a disabled Built In was chosen: ' .. tostring(current(f)))
    assert(a:SetDefaultRotationEnabled('rm.tbc.shaman.enhancement.wowsims', true))
    select(f)

    assert(
        current(f) == 'rm.tbc.shaman.enhancement.wowsims',
        'the enabled alternative was not chosen: ' .. tostring(current(f))
    )
end)

finish()
