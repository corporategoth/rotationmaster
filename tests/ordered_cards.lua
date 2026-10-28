-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- One ordered card list for every settings list. Its header row carries an
-- optional section title (the shared header style) and the Add action
-- right-aligned to the cards' right edge. A click appends through the page's
-- insert; dragging Add drops into a gap through that same insert; dragging a
-- card or its arrows reorders. Each converted page keeps its saved format.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function settingsFixture()
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1
    a.RotationData = make()

    for _, path in ipairs({
        'Platform/spells.lua', 'Data/catalog.lua', 'Data/rotation_store.lua', 'Core/rotation_library.lua',
        'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Help/general.lua', 'Help/conditions.lua',
        'Help/effects.lua', 'Help/itemsets.lua', 'Help/announce.lua', 'UI/window.lua', 'UI/help.lua',
        'UI/icon_picker.lua', 'UI/color_picker.lua', 'UI/settings_roster_order.lua', 'UI/settings_layout.lua',
        'UI/settings_ordered.lua', 'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua',
        'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/cpu_profile.lua', 'UI/settings_general.lua',
        'UI/settings_profiles.lua', 'UI/collection_compare.lua', 'UI/settings_collections.lua',
        'UI/settings_announces.lua', 'UI/settings_effects.lua', 'UI/settings_items.lua', 'UI/settings_conditions.lua'
    }) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    return f, frames, create
end

local function copy(list)
    local out = {}

    for i, v in ipairs(list) do
        out[i] = type(v) == 'table' and { id = v.id, value = v.value } or v
    end

    return out
end

local function same(a, b)
    if #a ~= #b then
        return false
    end

    for i = 1, #a do
        local x, y = a[i], b[i]

        if type(x) == 'table' then
            if x.id ~= y.id or x.value ~= y.value then
                return false
            end
        elseif x ~= y then
            return false
        end
    end

    return true
end

local function list(f, options)
    local a = f.addon
    local frames, create = f.frames, f.create
    local parent = create('Frame')
    parent:SetSize(900, 600)
    local p = a:CreateSettingsForm(parent)
    local state = { items = options.items or { 'a', 'b', 'c' }, inserted = 0 }

    local function build(form)
        form:Text('Before the list')

        state.view = form:OrderedCollection(
            'things',
            state.items,
            function(i) return 'Item ' .. i end,
            function(row, i, item)
                local t = row:Text(tostring(item))
            end,
            function()
                state.changed = (state.changed or 0) + 1
            end,
            {
                heading = options.heading,
                header = options.header,
                readOnly = options.readOnly,
                add = options.add ~= false and {
                    key = 'add_thing',
                    text = 'Add thing',
                    insert = function(gap)
                        state.inserted = state.inserted + 1
                        table.insert(state.items, gap, 'new' .. state.inserted)
                        form:Draw()
                    end,
                } or nil,
            }
        )
    end

    p:Open(build)
    return p, state
end

local FUNCTION_PATHS = {
    'Core/function_data.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_layout.lua',
    'UI/settings_ordered.lua', 'UI/settings_roster_order.lua', 'UI/settings_form.lua', 'UI/settings_collections.lua',
    'UI/settings_transfer.lua', 'UI/lua_input_probe.lua', 'UI/lua_input_diagnostics.lua', 'UI/lua_editor.lua',
    'UI/settings_functions.lua', 'UI/function_bindings.lua', 'UI/function_source_pane.lua',
    'UI/function_bundle_transfer.lua'
}

local function fixture()
    local f, frames, create = settingsFixture()
    f.frames, f.create = frames, create
    return f
end

local function rect(c)
    return c.point[2], c.point[2] + c:GetWidth(), -c.point[3]
end

test('the header row holds the shared-style title and the Add right-aligned to the cards', function()
    local f = fixture()
    local p, state = list(f, { heading = 'Things' })
    local view = state.view
    local title, add = view.heading, p.fields.add_thing
    local _, addRight, addY = rect(add)
    local _, _, titleY = rect(title)
    assert(addY == titleY, 'Add is not on the title row')
    assert(math.abs(addRight - view.rows[1]:GetWidth()) < .01, 'Add is not right-aligned to the cards')

    assert(
        title.rmHeaderFont == f.addon.WorkbenchHeaderFont and f.addon.WorkbenchHeaderFont == 'GameFontNormal',
        'title does not use the shared header style'
    )

    assert(-view.rows[1].point[3] >= addY + 22, 'cards start on the header row')
    local q = list(f, {})
    assert(not q.ordered.things.heading and q.fields.add_thing, 'no-title list lost its Add')
    local r, rs = list(f, { add = false })

    assert(
        not rs.view.heading and not r.fields.add_thing and -rs.view.rows[1].point[3] <= addY + 1,
        'a list with neither title nor Add spent a header row'
    )
end)

test('a click appends and dragging Add inserts into any gap through the same insert', function()
    local f = fixture()
    local p, state = list(f, { heading = 'Things' })
    p.fields.add_thing:Click()
    assert(same(state.items, { 'a', 'b', 'c', 'new1' }), 'click did not append')

    for _, gap in ipairs({ 1, 3, 'end' }) do
        if gap == 'end' then
            gap = #state.items + 1
        end

        local view = p.ordered.things

        view:BeginInsert(nil, 'Add thing', function(g)
            state.inserted = state.inserted + 1
            table.insert(state.items, g, 'new' .. state.inserted)
            p:Draw()
        end)

        assert(view:Drop(gap), 'drop into gap ' .. gap .. ' refused')
    end

    assert(
        same(state.items, { 'new2', 'a', 'new3', 'b', 'c', 'new1', 'new4' }),
        'drag inserts landed in the wrong gaps'
    )

    -- The drag source is the Add button itself.
    local add = p.fields.add_thing
    add.scripts.OnDragStart(add)
    local view = p.ordered.things

    assert(
        view.insertAction and view:Drop(#state.items + 1) and state.items[#state.items] == 'new5',
        'dragging Add did not insert through the page insert'
    )
end)

test('dropping Add at the end leaves exactly what a click leaves', function()
    local f = fixture()
    local p1, s1 = list(f, {})
    p1.fields.add_thing:Click()
    local p2, s2 = list(f, {})
    local add = p2.fields.add_thing
    add.scripts.OnDragStart(add)
    assert(p2.ordered.things:Drop(4))
    assert(same(s1.items, s2.items), 'append and end drop differ')
end)

test('dragging a card reorders like its arrows, including first, last and no-op drops', function()
    local f = fixture()

    local function dragged(from, gap)
        local p, s = list(f, {})
        local v = p.ordered.things
        v:BeginDrag(from)
        local ok = v:Drop(gap)
        return s.items, ok
    end

    local function arrowed(from, up)
        local p, s = list(f, {})
        local key = 'things' .. from .. (up and 'up' or 'down')
        p.fields[key]:Click()
        return s.items
    end

    assert(same((dragged(1, 4)), { 'b', 'c', 'a' }), 'first to last')
    assert(same((dragged(3, 1)), { 'c', 'a', 'b' }), 'last to first')
    assert(same((dragged(2, 1)), arrowed(2, true)), 'drag up differs from the up arrow')
    assert(same((dragged(2, 4)), arrowed(2, false)), 'drag down differs from the down arrow')
    local items, ok = dragged(2, 2)
    assert(not ok and same(items, { 'a', 'b', 'c' }), 'a drop onto its own gap changed the list')
    items, ok = dragged(2, 3)
    assert(not ok and same(items, { 'a', 'b', 'c' }))
end)

test('read-only lists keep their header but cannot add', function()
    local f = fixture()
    local p, state = list(f, { heading = 'Things', readOnly = true })
    assert(not p.fields.add_thing:IsEnabled())
    p.fields.add_thing:Click()
    assert(#state.items == 3)
    local add = p.fields.add_thing
    add.scripts.OnDragStart(add)
    assert(not p.ordered.things.insertAction, 'read-only Add started a drag')
end)

test('Item Sets: no title, the new-item field and Add sit above the cards, and Undo reverts a drag', function()
    local f = fixture()
    local a = f.addon
    local create = f.create
    a.db.global.itemsets = { set1 = { name = 'Potions', items = { 11, 12, 13 } } }
    a.db.profile.itemsets = {}
    local parent = create('Frame')
    parent:SetSize(1000, 600)
    local p = a:OpenNativeSettings(parent, 'ItemSets')
    local view = p.ordered.items_set1
    local add, field = p.fields.add_item, p.fields.new_item
    assert(not view.heading, 'Item Sets list still has a title')
    assert(add.point[3] == field.point[3], 'new-item field and Add are not on one row')

    assert(
        math.abs(add.point[2] + add:GetWidth() - view.rows[1]:GetWidth()) < .01
            and field.point[2] + field:GetWidth() <= add.point[2],
        'Add is not at the cards right edge'
    )

    assert(-view.rows[1].point[3] >= -add.point[3] + 22, 'cards start on the add row')
    local items = function() return p:SettingsData().global.itemsets.set1.items end
    view:BeginDrag(1)
    assert(view:Drop(4))
    assert(same(items(), { 12, 13, 11 }), 'item drag did not reorder')
    p:TravelSettingsHistory(false)
    assert(same(items(), { 11, 12, 13 }), 'Undo did not revert the drag')
    field:SetText('99')
    field.scripts.OnTextChanged(field, true)
    local addControl = p.fields.add_item
    addControl.scripts.OnDragStart(addControl)
    assert(p.ordered.items_set1:Drop(1), 'item drop refused')
    assert(items()[1] == 99 and #items() == 4, 'dragged new item did not land first')
end)

test('Announces: Outputs header with Add, untitled cards with Announce on the first row, close labels', function()
    local f = fixture()
    local a = f.addon
    local create = f.create

    a.db.profile.announces = {
        {
            id = 'e1',
            type = 'spell',
            spell = 403,
            event = 'SUCCEEDED',
            outputs = {
                { id = 'o1', announce = 'local', value = 'One' },
                { id = 'o2', announce = 'local', value = 'Two' },
            },
        },
    }

    local parent = create('Frame')
    parent:SetSize(1000, 700)
    local p = a:OpenNativeSettings(parent, 'Announces')
    local view

    for key, v in pairs(p.ordered) do
        if key:find('announce_outputs_', 1, true) then
            view = v
        end
    end

    local add = p.fields.entry1add_output
    assert(view and view.heading and add, 'Outputs list has no header row')

    assert(
        view.heading:GetText() == 'Outputs' and add.point[3] == view.heading.point[3],
        'Add output is not on the Outputs row'
    )

    assert(
        math.abs(add.point[2] + add:GetWidth() - view.rows[1]:GetWidth()) < .01,
        'Add output is not at the cards right edge'
    )

    for i, row in ipairs(view.rows) do
        assert(row.header:GetText() == '', 'card ' .. i .. ' still has a title')
        local choice = p.fields[i == 1 and 'entry1channel' or 'entry1output' .. i .. 'channel']
        local pill = p.fields['entry1output' .. i .. 'enabled'] or p.fields['entry1enabled_output' .. i]

        assert(
            choice and choice:GetParent() == row.body and -choice.point[3] <= 6,
            'Announce is not on the card first row'
        )

        local help = p.fields['entry1output' .. i .. 'help']
        assert(help and -help.point[3] <= 6, 'card Help left the first row')

        assert(
            26 + choice.point[2] + choice:GetWidth() <= row:GetWidth() - 98,
            'Announce runs under the card corner controls'
        )
    end

    -- Labels sit next to their values: the caption column fits the captions.
    local choice = p.fields.entry1channel
    local caption

    for _, t in ipairs(p.pool.labels) do
        if t:IsShown() and t:GetText() == 'Announce' and t:GetParent() == choice:GetParent() then
            caption = t
        end
    end

    assert(caption and choice.point[2] - caption:GetStringWidth() <= 20, 'Announce value sits far from its label')
    local widest = 0

    for _, t in ipairs(p.pool.labels) do
        if t:IsShown() and t:GetParent() == choice:GetParent() and t.point and t.point[2] == 0 then
            widest = math.max(widest, t:GetStringWidth())
        end
    end

    assert(choice.point[2] >= widest + 8, 'value overlaps the longest caption in its card')
    local before = #a.db.profile.announces[1].outputs
    add:Click()
    local outputs = p:SettingsData().profile.announces[1].outputs

    assert(
        #outputs == before + 1 and outputs[#outputs].announce == 'partyraid' and type(outputs[#outputs].id) == 'string',
        'Add output did not append a new output'
    )

    local addControl = p.fields.entry1add_output
    addControl.scripts.OnDragStart(addControl)

    for key, v in pairs(p.ordered) do
        if key:find('announce_outputs_', 1, true) then
            view = v
        end
    end

    assert(view:Drop(1))
    outputs = p:SettingsData().profile.announces[1].outputs
    assert(outputs[1].announce == 'partyraid' and outputs[2].id == 'o1', 'dragged output did not land first')
    p.fields.cancel:Click()
    assert(#a.db.profile.announces[1].outputs == 2, 'Discard kept added outputs')
end)

test('the macro trigger reads Via Script/Macro', function()
    local f = fixture()
    local a = f.addon
    local create = f.create

    a.db.profile.announces = {
        { id = 'm', type = 'macro', identifier = 'FOO', outputs = { { id = 'o', announce = 'local', value = 'x' } } },
    }

    local parent = create('Frame')
    parent:SetSize(1000, 700)
    local p = a:OpenNativeSettings(parent, 'Announces')
    p.fields.entry1type:Click()
    local found = false

    for _, row in ipairs(p.menu.rows) do
        if row:IsShown() and row:GetText() == 'Via Script/Macro' then
            found = true
        end
    end

    assert(found, 'type choice does not offer Via Script/Macro')
    assert(a.db.profile.announces[1].type == 'macro')
end)

test('Effects: the Sequence header carries Add step, which appends or drops into a gap', function()
    local f = fixture()
    local a = f.addon
    local create = f.create
    a.RemoveAllCurrentGlows = function() end
    a.HideGlow = function() end
    a.Glow = function() end
    a.db.global.effects = { p = { name = 'Pulse', type = 'pulse', frequency = .25, sequence = { 1, .5 } } }
    local parent = create('Frame')
    parent:SetSize(1000, 700)
    local p = a:OpenNativeSettings(parent, 'Effects')
    local view = p.ordered.sequence_p
    local add = p.fields.sequence_add

    assert(
        view.heading:GetText() == 'Sequence'
            and add.point[3] == view.heading.point[3]
            and math.abs(add.point[2] + add:GetWidth() - view.rows[1]:GetWidth()) < .01,
        'Add step is not on the Sequence header row'
    )

    add:Click()
    local seq = function() return p:SettingsData().global.effects.p.sequence end
    assert(#seq() == 3 and seq()[3] == 1)
    add.scripts.OnDragStart(add)
    assert(p.ordered.sequence_p:Drop(1))
    assert(#seq() == 4 and seq()[2] == 1 and seq()[3] == .5, 'dropped step landed in the wrong gap')
end)

test('section headers everywhere use the shared header style', function()
    local f = fixture()
    local a = f.addon
    local create = f.create
    local parent = create('Frame')
    parent:SetSize(1000, 700)
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        form:Heading('Heading')
        form:Section('s', 'Section', function() end)
    end)

    local heading

    for _, t in ipairs(p.pool.text) do
        if t:IsShown() and t:GetText() == 'Heading' then
            heading = t
        end
    end

    assert(heading and heading.rmHeaderFont == 'GameFontNormal', 'Heading does not use the shared style')
    assert(p.fields.section_s:GetFontString().rmHeaderFont == 'GameFontNormal', 'Section does not use the shared style')
end)

test('Functions: Arguments and Returns headers carry their Add on the same row', function()
    local f = F.new()
    local a = f.addon
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.db.char = {}
    a.db.global.custom_functions = {}
    a.RotationData = make()

    for _, path in ipairs(FUNCTION_PATHS) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    a.db.global.custom_functions.A = {
        name = 'Fn',
        description = 'Documentation',
        args = { { name = 'value', type = 'number', description = 'Input' } },
        returns = { { type = 'number', description = 'Result' } },
        code = 'return value',
    }

    local host = f.env.CreateFrame('Frame')
    host:SetSize(1100, 700)
    local p = a:OpenNativeSettings(host, 'Functions')
    local form = p.inlineFunction.form

    for _, field in ipairs({ 'args', 'returns' }) do
        local heading, add = form.fields['section_' .. field], form.fields['add_' .. field]
        local view = form.ordered['function_' .. field]
        assert(heading and add and heading.point[3] == add.point[3], field .. ' Add is not on its header row')

        assert(
            math.abs(add.point[2] + add:GetWidth() - view.rows[1]:GetWidth()) < .01,
            field .. ' Add is not at the cards right edge'
        )

        assert(
            heading:GetFontString().rmHeaderFont == 'GameFontNormal',
            field .. ' header does not use the shared style'
        )
    end

    local before = #p.inlineFunction.value.args
    form.fields.add_args:Click()
    assert(#p.inlineFunction.value.args == before + 1, 'Argument did not append')
end)

-- Every list draws the same card: no title and no grip, arrows on the left,
-- a right rail of optional Help and Duplicate above the trash, and the whole
-- card picks up for a drag, leaving its outline behind and offering only the
-- gaps that would move it.
local function sameCards(view, name, rail)
    assert(view and #view.rows >= 2, name .. ': needs two cards')

    for i, row in ipairs(view.rows) do
        assert(not row.header:IsShown() and not row.header.grip, name .. ' card ' .. i .. ' shows a title or grip')

        assert(
            row.up.point[1] == 'TOPLEFT' and row.up.point[2] == 3 and row.down.point[2] == 3,
            name .. ' arrows are not at the card left'
        )

        local expected = {}

        for _, control in ipairs(rail) do
            expected[#expected + 1] = row[control]
        end

        expected[#expected + 1] = row.remove

        for slot, control in ipairs(expected) do
            assert(
                control and control:IsShown() and control:GetParent() == row,
                name .. ' rail control ' .. slot .. ' missing'
            )

            assert(
                control.point[1] == 'TOPRIGHT' and control.point[2] == -4 and control.point[3] == -3 - (slot - 1) * 22,
                name .. ' rail control ' .. slot .. ' is out of order'
            )
        end

        for _, control in ipairs({ 'help', 'duplicate' }) do
            local present = false

            for _, c in ipairs(rail) do
                present = present or c == control
            end

            assert(
                present or not (row[control] and row[control]:IsShown()),
                name .. ' shows an unrequested ' .. control
            )
        end

        assert(row.body.point[2] + row.body:GetWidth() <= row:GetWidth() - 24, name .. ' card body runs under the rail')
    end

    local row = view.rows[1]
    row.scripts.OnMouseDown(row, 'LeftButton')
    assert(view.drag == 1 and view.ghost:IsShown(), name .. ': clicking the card did not pick it up')

    assert(
        view.ghost.placeholders[1] and view.ghost.placeholders[1]:IsShown(),
        name .. ': the carried card left no space behind'
    )

    assert(not view.zones[1]:IsShown() and not view.zones[2]:IsShown(), name .. ': a no-op gap is offered')

    for gap = 3, #view.zones do
        assert(view.zones[gap]:IsShown(), name .. ': gap ' .. gap .. ' is not offered')
    end

    view:CancelDrag()
end

test('every list draws the same card and drags it the same way', function()
    local f = fixture()
    local a = f.addon
    local create = f.create
    a.RemoveAllCurrentGlows = function() end
    a.HideGlow = function() end
    a.Glow = function() end
    local p = list(f, { heading = 'Things' })
    sameCards(p.ordered.things, 'plain', {})

    a.db.profile.announces = {
        {
            id = 'e1',
            type = 'spell',
            spell = 403,
            event = 'SUCCEEDED',
            outputs = {
                { id = 'o1', announce = 'local', value = 'One' },
                { id = 'o2', announce = 'local', value = 'Two' },
            },
        },
    }

    local parent = create('Frame')
    parent:SetSize(1000, 700)
    p = a:OpenNativeSettings(parent, 'Announces')
    local view

    for key, v in pairs(p.ordered) do
        if key:find('announce_outputs_', 1, true) then
            view = v
        end
    end

    sameCards(view, 'Announces', { 'help', 'duplicate' })

    for i, row in ipairs(view.rows) do
        assert(
            row.enabled:IsShown()
                and row.enabled.point[1] == 'TOPRIGHT'
                and row.enabled.point[2] == -28
                and row.enabled.point[3] == -4,
            'Announces card ' .. i .. ' pill is not beside the rail'
        )
    end

    a.db.global.effects = { p = { name = 'Pulse', type = 'pulse', frequency = .25, sequence = { 1, .5, .75 } } }
    parent = create('Frame')
    parent:SetSize(1000, 700)
    p = a:OpenNativeSettings(parent, 'Effects')
    sameCards(p.ordered.sequence_p, 'Effects', {})
    a.db.global.itemsets = { set1 = { name = 'Potions', items = { 11, 12, 13 } } }
    a.db.profile.itemsets = {}
    parent = create('Frame')
    parent:SetSize(1000, 600)
    p = a:OpenNativeSettings(parent, 'ItemSets')
    sameCards(p.ordered.items_set1, 'Item Sets', {})
end)

test('function argument cards use the shared rail with Nullable against the help icon', function()
    local f = F.new()
    local a = f.addon
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    a.db.char = {}
    a.db.global.custom_functions = {}
    a.RotationData = make()

    for _, path in ipairs(FUNCTION_PATHS) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    a.db.global.custom_functions.A = {
        name = 'Fn',
        description = 'Documentation',
        args = {
            { name = 'value', type = 'number', description = 'Input' },
            { name = 'other', type = 'string', description = 'More' },
        },
        returns = { { type = 'number', description = 'Result' }, { type = 'string', description = 'Second' } },
        code = 'return value',
    }

    local host = f.env.CreateFrame('Frame')
    host:SetSize(1100, 700)
    local p = a:OpenNativeSettings(host, 'Functions')
    local form = p.inlineFunction.form

    for _, field in ipairs({ 'args', 'returns' }) do
        local view = form.ordered['function_' .. field]
        sameCards(view, field, { 'help', 'duplicate' })
        local check = form.fields[(field == 'args' and 'arg_' or 'return_') .. '1_nullable']
        local row = view.rows[1]
        local right = row.body.point[2] + check.point[2] + check:GetWidth()
        assert(check:GetWidth() <= 22 + 120 and check:GetWidth() < 102, field .. ' Nullable is not narrow')

        assert(
            math.abs(right - (row.body.point[2] + row.body:GetWidth())) < .01 and row:GetWidth() - 4 - 20 - right <= 14,
            field .. ' Nullable is not against the help icon'
        )

        assert(
            check.point[3] == row.help.point[3] + 1 or math.abs(check.point[3] - row.help.point[3]) <= 6,
            field .. ' Nullable left the help row'
        )
    end
end)

finish()
