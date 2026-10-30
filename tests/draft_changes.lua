-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)

    for _, p in ipairs({
        'UI/settings_draft.lua',
        'Data/plain.lua',
        'Data/tags.lua',
        'Data/rotation_tree.lua',
        'Data/condition_draft.lua',
        'UI/collection_compare.lua',
        'UI/draft_changes.lua',
    }) do
        local h = io.open(p)

        if h then
            h:close()
            f.load(p)
        end
    end

    f.addon.Platform.GetSpellInfo = function(_, id) return { iconID = id } end
    f.addon.SpellLabel = function(_, id) return 'Spell ' .. tostring(id) end
    f.addon.DescribeCondition = function(_, v) return v.type or 'Always' end
    return f, f.addon
end

test('saved versus draft rotation rows show semantic cards metadata and changed order without writes', function()
    local _, a = fixture()
    assert(a.BuildDraftChangeRows)

    local before = {
        name = 'One',
        switch = {},
        rotation = { { id = 'a', type = 'spell', action = 403, conditions = {} } },
        cooldowns = {},
    }

    local after = a.RotationData.CopyData(before)
    after.rotation[1].action = 8042
    after.metadata = { author = 'PreZ' }
    local rows, count = a:BuildDraftChangeRows('rotation', before, after, false, 0)
    assert(count >= 2 and #rows >= 2)
    assert(rows[#rows].left:find('403', 1, true) and rows[#rows].right:find('8042', 1, true))
    assert(before.rotation[1].action == 403 and not before.metadata)
end)

test('owned changes window uses saved and unsaved columns and becomes inert when its owner closes', function()
    local f, a = fixture()
    assert(a.ShowWorkbenchDraftChanges)
    local active = true
    local owner = { frame = f.env.CreateFrame('Frame') }

    local d = a:ShowWorkbenchDraftChanges(owner, 'profile', { name = 'Before' }, { name = 'After' }, function()
        return active
    end)

    assert(
        d.leftHeading:GetText() == 'Saved'
            and d.rightHeading:GetText() == 'Unsaved'
            and d.frame:IsShown()
            and d.rows[1].changed
    )

    active = false
    d.frame.scripts.OnUpdate()
    assert(not d.frame:IsShown())
end)

test('condition values remain reviewable when a custom summary omits a changed field', function()
    local _, a = fixture()
    a.conditionDefinitions = { CUSTOM = { description = 'Custom', fields = { value = 'number' } } }

    local rows, count = a:BuildDraftChangeRows(
        'condition',
        { type = 'CUSTOM', value = 1 },
        { type = 'CUSTOM', value = 2 },
        false
    )

    assert(count > 0)
    local found

    for _, row in ipairs(rows) do
        if row.left == '1' and row.right == '2' then
            found = true
        end
    end

    assert(found)
end)

test('item lists and action types remain distinct in rotation change cards', function()
    local _, a = fixture()
    a.GetReferenceProvider = function() return { name = function(id) return 'Item ' .. id end, resolve = tonumber } end
    local old = { rotation = { { id = 'a', type = 'item', action = { 1, 2 }, conditions = {} } }, cooldowns = {} }
    local new = a.RotationData.CopyData(old)
    new.rotation[1].action = { 2, 3 }
    local rows = a:BuildDraftChangeRows('rotation', old, new, false)
    assert(rows[#rows].left:find('Item 1', 1, true) and rows[#rows].right:find('Item 3', 1, true))
end)

test('rotation review exposes names changed inside switch and action condition groups', function()
    local f, a = fixture()
    f.load('Core/conditions.lua')
    f.load('Core/condition_description.lua')
    a:RegisterCondition('TEST', { description = 'Test', fields = {}, print = function() return 'same predicate' end })
    local group = { type = 'AND', name = 'Original group', value = { { type = 'TEST' } } }

    local before = {
        switch = a.RotationData.CopyData(group),
        rotation = { { id = 'a', type = 'spell', action = 403, conditions = a.RotationData.CopyData(group) } },
        cooldowns = {},
    }

    local after = a.RotationData.CopyData(before)
    after.switch.name = 'New switch name'
    after.rotation[1].conditions.name = 'New action name'
    assert(a:DescribeCondition(before.switch) == a:DescribeCondition(after.switch))
    local rows = a:BuildDraftChangeRows('rotation', before, after, false)
    local switch, action

    for _, row in ipairs(rows) do
        if row.left:find('Original group', 1, true) then
            if row.right:find('New switch name', 1, true) then
                switch = true
            end
            if row.right:find('New action name', 1, true) then
                action = true
            end
        end
    end

    assert(switch and action, 'group rename was invisible in saved/draft comparison')
end)

finish()
