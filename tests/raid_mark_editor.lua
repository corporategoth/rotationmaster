-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- The Set Mark step in the rotation editor (UI/rotation_mark_fields.lua, UI/rotation_fields.lua): it is offered only
-- where the client can place marks, choosing it fills in a valid unit and mark, the unit and mark are choices from fixed
-- lists, Bind makes and picks up the macro and reports why it cannot, and the step shows readable names. The card
-- harness is the one tests/rotation_editor_ui.lua builds.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local handle = assert(io.open(path))
    local text = handle:read('*a')
    handle:close()
    return text
end

local prefix = assert(read('tests/rotation_editor_ui.lua'):match('^(.-)\ntest%('))
local baseFixture, card = assert(loadstring(prefix .. '\nreturn fixture,card', '@raid-mark-card-fixture'))()

-- The editor on a rotation that holds one Set Mark step and one spell step; capable = false models a client with no
-- way to place marks.
local function fixture(capable)
    local f, parent = baseFixture()
    local a, e = f.addon, f.env
    local macros, picked = {}, {}

    if capable then
        e.SetRaidTarget = function() end

        e.GetMacroIndexByName = function(name)
            for index, macro in ipairs(macros) do
                if macro.name == name then
                    return index
                end
            end

            return 0
        end

        e.CreateMacro = function(name, icon, body, perCharacter)
            macros[#macros + 1] = { name = name, icon = icon, body = body, perCharacter = perCharacter }
            return #macros
        end

        e.PickupMacro = function(index)
            picked[#picked + 1] = index
        end
    end

    e.InCombatLockdown = function() return false end
    e.GetCursorInfo = function() return nil end
    local create = e.CreateFrame

    e.CreateFrame = function(kind, name, ...)
        local frame = create(kind, name, ...)
        frame.attributes = {}

        function frame:SetAttribute(key, value)
            self.attributes[key] = value
        end

        if name then
            e[name] = frame
        end

        return frame
    end

    for _, path in ipairs({
        'Platform/focus_unit.lua',
        'Platform/unit_presence.lua',
        'Platform/raid_marks.lua',
        'Platform/raid_mark_actions.lua',
        'Core/raid_mark_buttons.lua',
        'UI/rotation_mark_fields.lua',
        'UI/rotation_fields.lua',
    }) do
        f.load(path)
    end

    a.units = a.units or {
        player = 'you',
        target = 'your target',
        focus = 'your focus target',
        mouseover = 'your mouseover target',
    }

    local mine = a.db.profile.rotations[0].mine
    table.insert(mine.rotation, { id = 'mark', type = 'mark', unit = 'target', action = 'skull', conditions = {} })
    table.insert(mine.rotation, { id = 'bolt', type = 'spell', action = 403, conditions = {} })

    -- The Built In view of the same rotation, which is read only.
    function a:ListDefaultRotations()
        return {
            {
                id = 'pack',
                runtimeKey = 'builtin',
                name = 'Mine',
                description = 'Preview',
                enabled = true,
                envelope = { body = a:CopySettingsData(mine) },
            },
        }
    end

    return f, parent, macros, picked
end

-- Opens a card's choice and picks the entry with the given value; returns the texts it offered.
local function choose(pane, id, key, value)
    local control = card(pane, id).fieldControls[key]
    control:Click()
    local offered = {}
    local chosen

    for _, row in ipairs(control.menu.rows) do
        if row.menuEntry then
            offered[#offered + 1] = row.menuEntry.text

            if row.menuEntry.value == value then
                chosen = row
            end
        end
    end

    if chosen then
        chosen:Click()
    end

    return offered, chosen ~= nil
end

local function offers(pane, id, key)
    local control = card(pane, id).fieldControls[key]
    control:Click()
    local texts = {}

    for _, row in ipairs(control.menu.rows) do
        if row.menuEntry then
            texts[#texts + 1] = row.menuEntry.text
        end
    end

    control.menu:Hide()
    return texts
end

local function contains(list, wanted)
    for _, text in ipairs(list) do
        if text == wanted then
            return true
        end
    end

    return false
end

test(
    'the step type menu offers Set Mark where the client can place marks and keeps it on a step that is one',
    function()
        local f, parent = fixture(true)
        local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
        card(pane, 'bolt').action:Click()
        assert(contains(offers(pane, 'bolt', 'type'), 'Set Mark'), 'Set Mark is offered')
        local g, other = fixture(false)
        local second = assert(g.addon:CreateRotationEditor(other, 0, 'mine'))
        card(second, 'bolt').action:Click()

        assert(
            not contains(offers(second, 'bolt', 'type'), 'Set Mark'),
            'Set Mark is offered where marks cannot be placed'
        )

        card(second, 'mark').action:Click()
        assert(contains(offers(second, 'mark', 'type'), 'Set Mark'), 'an imported Set Mark step is still shown as one')
    end
)

test('choosing the Set Mark type fills in a valid unit and mark, and leaving it removes them', function()
    local f, parent = fixture(true)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    card(pane, 'bolt').action:Click()
    local _, found = choose(pane, 'bolt', 'type', 'mark')
    assert(found)
    local step = pane.workspace:Snapshot().rotation[3]
    assert(step.type == 'mark' and step.unit == 'target' and step.action == 'skull', 'defaults')
    assert(f.addon.Platform:GetMarkStepActionId(step) ~= nil, 'the defaults are a valid step')
    _, found = choose(pane, 'bolt', 'type', 'spell')
    assert(found)
    step = pane.workspace:Snapshot().rotation[3]
    assert(step.type == 'spell' and step.unit == nil and step.action == nil, 'the Set Mark fields went away')
end)

test('the unit and mark are chosen from fixed lists and written as the choice', function()
    local f, parent = fixture(true)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    card(pane, 'mark').action:Click()
    local units = offers(pane, 'mark', 'markunit')
    assert(#units == 7 and contains(units, 'your target'), table.concat(units, ','))
    local marks = offers(pane, 'mark', 'mark')

    assert(#marks == 9 and marks[1] == 'Skull' and marks[8] == 'Star' and marks[9] == 'Clear the mark', table.concat(
        marks,
        ','
    ))

    choose(pane, 'mark', 'mark', 'moon')
    choose(pane, 'mark', 'markunit', 'focus')
    local step = pane.workspace:Snapshot().rotation[2]
    assert(step.unit == 'focus' and step.action == 'moon')
    choose(pane, 'mark', 'mark', 'none')
    assert(pane.workspace:Snapshot().rotation[2].action == 'none')
    -- A value that is not in the list cannot be chosen, and a saved hostile value is only text on the button.
    local _, found = choose(pane, 'mark', 'markunit', 'target]\n/run x')
    assert(found == false and pane.workspace:Snapshot().rotation[2].unit == 'focus')
end)

test('the card shows the step in words and with the mark icon', function()
    local f, parent = fixture(true)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    local shown = card(pane, 'mark')
    assert(shown, 'the Set Mark card is drawn')
    assert(f.addon:DescribeMarkStep(shown.model.step) == 'Set Skull on your target')
    assert(f.addon:GetStepIcon(shown.model.step, 'fallback') == 'Interface\\TargetingFrame\\UI-RaidTargetingIcon_8')
end)

test('Bind makes the macro, puts it on the cursor and tells the player what to do next', function()
    local f, parent, macros, picked = fixture(true)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    card(pane, 'mark').action:Click()
    local bind = card(pane, 'mark').fieldControls.bind
    assert(bind and bind.text == 'Put on an action bar' and bind.tooltip, 'the Bind button')
    bind.scripts.OnClick(bind)
    assert(#macros == 1 and macros[1].body == '/click RM_Mark_target_skull' and picked[1] == 1)
    assert(pane.status.text == 'Drag the macro RM skull/tgt to an action bar slot.', tostring(pane.status.text))
    f.env.GetCursorInfo = function() return 'item' end
    bind.scripts.OnClick(bind)
    assert(#macros == 1 and pane.status.text == 'Empty your cursor before binding.', tostring(pane.status.text))
    f.env.GetCursorInfo = function() return nil end
    f.env.InCombatLockdown = function() return true end
    bind.scripts.OnClick(bind)
    assert(pane.status.text == 'Leave combat before changing action bar bindings.', tostring(pane.status.text))
    f.env.InCombatLockdown = function() return false end
    f.env.CreateMacro = function() return nil end
    f.env.GetMacroIndexByName = function() return 0 end
    bind.scripts.OnClick(bind)

    assert(pane.status.text == 'Your character macros are full, so the macro could not be made.', tostring(
        pane.status.text
    ))
end)

test('a read-only Set Mark card cannot Bind or change', function()
    local f, parent = fixture(true)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'builtin'))
    local shown = assert(card(pane, 'mark'), 'the Set Mark card is drawn')
    shown.action:Click()
    local bind = card(pane, 'mark').fieldControls.bind
    assert(bind and bind.enabled == false, 'Bind is disabled')
    local control = card(pane, 'mark').fieldControls.mark
    assert(control.enabled == false, 'the mark choice is disabled')
end)

finish()
