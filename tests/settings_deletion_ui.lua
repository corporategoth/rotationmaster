-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local codecData, codecDeps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = codecData
    a.NewRotationCodec = function() return codecData.NewCodec(codecDeps) end
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1

    for _, path in ipairs({
        'Platform/spells.lua', 'Help/general.lua', 'Help/conditions.lua', 'Help/effects.lua', 'Help/itemsets.lua',
        'Help/announce.lua', 'UI/window.lua', 'UI/help.lua', 'UI/icon_picker.lua', 'UI/color_picker.lua',
        'UI/settings_roster_order.lua', 'UI/settings_layout.lua', 'UI/settings_ordered.lua', 'UI/settings_draft.lua',
        'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_form.lua', 'UI/settings_transfer.lua',
        'UI/settings_general.lua', 'UI/settings_profiles.lua', 'UI/collection_compare.lua',
        'UI/settings_collections.lua', 'UI/settings_announces.lua', 'UI/settings_effects.lua', 'UI/settings_items.lua',
        'UI/settings_conditions.lua'
    }) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    local parent = create('Frame')
    parent:SetSize(1000, 600)
    return f, parent
end

local function setup(kind)
    local f, parent = fixture()
    local a = f.addon
    local p

    if kind == 'Effects' then
        a.db.global.effects = { A = { name = 'A', type = 'pixel' }, B = { name = 'B', type = 'pixel' } }
        p = a:OpenNativeSettings(parent, kind)
    elseif kind == 'ItemSets' then
        a.db.profile.itemsets = { A = { name = 'A', items = { 1 } }, B = { name = 'B', items = { 2 } } }
        p = a:OpenNativeSettings(parent, kind)
    elseif kind == 'Announces' then
        a.db.profile.announces = {
            { id = 'A', name = 'A', type = 'spell', spell = 403, event = 'SUCCEEDED', announce = 'local', value = 'A' },
            { id = 'B', name = 'B', type = 'spell', spell = 403, event = 'SUCCEEDED', announce = 'local', value = 'B' },
        }

        p = a:OpenNativeSettings(parent, kind)
    else
        a.conditionDefinitions = {}
        a.conditionSpecials = {}
        a.listConditions = function() return {} end

        a.db.profile.condition_groups = {
            { id = 'A', name = 'A', conditions = {} },
            { id = 'B', name = 'B', conditions = {} },
        }

        p = a:OpenNativeSettings(parent, 'Conditions')
        p.mode = 'categories'
        p:Draw()
    end

    return f, a, p
end

for _, kind in ipairs({ 'Effects', 'ItemSets', 'Announces', 'Categories' }) do
    test(kind .. ' removal commits only after permanent confirmation and leaves a clean successor', function()
        local _, a, p = setup(kind)
        local field = kind == 'Categories' and 'delete_category' or 'delete'
        local before = a:CopySettingsData(a.db)
        p.fields[field]:Click()

        assert(
            p.prompt and p.prompt.frame:IsShown() and p.prompt.text:GetText():find('cannot be undone', 1, true),
            'permanent deletion warning is missing'
        )

        assert(a:SettingsDataEqual(a.db, before))
        p.prompt.cancel:Click()
        assert(a:SettingsDataEqual(a.db, before) and not p:IsSettingsDraftDirty(), 'cancel changed saved data')
        p.fields[field]:Click()
        p.prompt.accept:Click()

        assert(
            not p:IsSettingsDraftDirty() and not p.fields.apply:IsEnabled(),
            'confirmed removal did not leave a clean successor'
        )

        if kind == 'Categories' then
            assert(a.db.profile.condition_groups[1].id == 'B' and p.categorySelection == 'B')
        elseif kind == 'Announces' then
            assert(#a.db.profile.announces == 1 and a.db.profile.announces[1].id == 'B')
        elseif kind == 'ItemSets' then
            assert(not a.db.profile.itemsets.A and a.db.profile.itemsets.B and p.selection == 'B')
        else
            assert(not a.db.global.effects.A and a.db.global.effects.B and p.selection == 'B')
        end
    end)
end

test('last confirmed deletion leaves an empty clean page without creating another draft', function()
    local _, a, p = setup('Effects')
    a.db.global.effects.B = nil
    p:DiscardSettingsDraft()
    p:Draw()
    p.fields.delete:Click()
    p.prompt.accept:Click()

    assert(
        not next(a.db.global.effects)
            and not p.creating
            and not p.fields.new_name
            and not p:IsSettingsDraftDirty()
            and not p.fields.apply:IsEnabled()
    )
end)

test('pending edits must be resolved before delete without saving unrelated changes silently', function()
    local _, a, p = setup('Effects')
    p.fields.name:SetText('Unsaved A')
    p.fields.name.scripts.OnTextChanged(p.fields.name, true)
    p.fields.delete:Click()

    assert(
        p.prompt.discard and p.prompt.discard:IsShown() and a.db.global.effects.A.name == 'A',
        'delete skipped pending-change decision'
    )

    p.prompt.cancel:Click()
    assert(p.fields.name:GetText() == 'Unsaved A' and a.db.global.effects.A)
    p.fields.delete:Click()
    p.prompt.discard:Click()

    assert(
        p.prompt.frame:IsShown()
            and p.prompt.text:GetText():find('cannot be undone', 1, true)
            and a.db.global.effects.A.name == 'A'
    )

    p.prompt.accept:Click()
    assert(not a.db.global.effects.A and a.db.global.effects.B and not p:IsSettingsDraftDirty())
end)

test('pending Apply refreshes current records before confirmed deletion', function()
    local _, a, p = setup('Effects')
    p.fields.name:SetText('Saved A')
    p.fields.name.scripts.OnTextChanged(p.fields.name, true)
    p.fields.delete:Click()
    p.prompt.accept:Click()

    assert(
        a.db.global.effects.A.name == 'Saved A' and p.prompt.frame:IsShown(),
        'pending Apply did not save before permanent confirmation'
    )

    p.prompt.accept:Click()

    assert(
        not a.db.global.effects.A and a.db.global.effects.B and not p:IsSettingsDraftDirty(),
        'delete mutated a discarded draft reference'
    )
end)

test('stale confirmation or combat cannot remove current saved entries', function()
    local f, a, p = setup('Effects')
    p.fields.delete:Click()
    a.db.global.effects.A = { name = 'Externally changed', type = 'pixel' }
    p.prompt.accept:Click()
    assert(a.db.global.effects.A.name == 'Externally changed', 'stale warning removed a replaced record')
    p:DiscardSettingsDraft()
    p:Draw()
    p.fields.delete:Click()
    f.env.InCombatLockdown = function() return true end
    p.prompt.accept:Click()
    assert(a.db.global.effects.A, 'combat deleted protected configuration')
    f.env.InCombatLockdown = function() return false end
    p:DiscardSettingsDraft()
    p:Draw()
    p.fields.delete:Click()
    local accept = p.prompt.accept.scripts.OnClick
    p:Release()
    accept()
    assert(a.db.global.effects.A, 'stale owner callback deleted an entry')
end)

test('invalid pending text can be discarded before deletion', function()
    local _, a, p = setup('Effects')
    p.fields.name:SetText('')
    p.fields.name.scripts.OnTextChanged(p.fields.name, true)
    p.fields.delete:Click()
    assert(p.prompt and p.prompt.discard:IsShown(), 'invalid input blocked the pending-change dialog')
    p.prompt.discard:Click()
    assert(p.prompt.text:GetText():find('cannot be undone', 1, true))
    p.prompt.accept:Click()
    assert(not a.db.global.effects.A)
end)

test('failed unbind keeps the saved item set and binding', function()
    local _, a, p = setup('ItemSets')
    a.db.char = { bindings = { A = { 4 } } }
    p:Release()
    local host = p.frame:GetParent()
    p = a:OpenNativeSettings(host, 'ItemSets')
    a.UnbindItemSet = function() return false end
    p.fields.delete:Click()
    p.prompt.accept:Click()
    assert(a.db.profile.itemsets.A and a.db.char.bindings.A and p.selection == 'A')
end)

finish()
