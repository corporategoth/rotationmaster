-- One rank option, one label ("Use this exact spell rank"), unticked by default,
-- and no rank checkbox anywhere on a client without spell ranks. Stored fields
-- are unchanged: spell families store `ranked` (ticked = true), aura families
-- store `anyrank` and are the inverse (unticked = true).
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local LABEL = 'Use this exact spell rank'

-- name, WOW_PROJECT_ID in the fixtures, has spell ranks
local CLIENTS = {
    { 'Retail', 1, false },
    { 'Classic Era', 2, true },
    { 'TBC Anniversary', 5, true },
    { 'Wrath', 11, true },
    { 'Cataclysm', 14, false },
    { 'Mists', 19, false },
    { 'Forever', 18, true },
}

local function fixture(project)
    local f = F.new(project)
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)

    f.env.C_Spell = {
        GetSpellInfo = function(id)
            if id == 403 then
                return { spellID = id, name = 'Lightning Bolt', iconID = 1, subtext = 'Rank 1' }
            end
        end,
    }

    f.env.GameTooltip = {
        IsVisible = function() return false end,
        IsOwned = function() return false end,
        SetOwner = function() end,
        SetHyperlink = function() end,
        Hide = function() end,
    }

    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    f.env.BOOKTYPE_PET = 'pet'
    f.load('Platform/client.lua')
    f.load('Platform/spells.lua')
    f.load('UI/condition_icon.lua')
    f.load('UI/spell_icon.lua')
    f.load('Conditions/common.lua')
    return f, a
end

test('the client helper follows the spell-rank table and a missing project is rankless', function()
    for _, c in ipairs(CLIENTS) do
        local f, a = fixture(c[2])
        assert(a:ClientHasSpellRanks() == c[3], c[1] .. ' rank support wrong')
    end

    local f, a = fixture(2)
    f.env.WOW_PROJECT_ID = nil
    assert(a:ClientHasSpellRanks() == false)
    f.env.WOW_PROJECT_ID = 2
    f.env.WOW_PROJECT_CLASSIC = nil
    assert(a:ClientHasSpellRanks() == false, 'a missing constant must not match')
end)

test('every condition rank widget exists only on clients with spell ranks', function()
    for _, c in ipairs(CLIENTS) do
        local f, a = fixture(c[2])
        local aura = a:Widget_AuraRankWidget({}, function() end)
        local cast = a:Widget_SpellRankWidget({}, function() end)
        assert((aura ~= nil) == c[3], c[1] .. ' aura rank checkbox')
        assert((cast ~= nil) == c[3], c[1] .. ' cast rank checkbox')

        local group = a:Widget_SpellWidget(
            0,
            'Spell_EditBox',
            { spell = 403 },
            function() return 403 end,
            function() return true end,
            function() end
        )

        assert(#group.children == (c[3] and 3 or 2), c[1] .. ' spell widget rank checkbox')

        local pet = a:Widget_SpellWidget(
            'pet',
            'Spell_EditBox',
            { spell = 403 },
            function() return 403 end,
            function() return true end,
            function() end
        )

        assert(#pet.children == 2, c[1] .. ' pet spell widgets never had one')

        if c[3] then
            assert(aura.button.text == LABEL or aura.button:GetText() == LABEL, c[1] .. ' aura label')
            assert(cast.button.text == LABEL or cast.button:GetText() == LABEL, c[1] .. ' cast label')

            assert(
                aura.button.tooltip
                    and aura.button.tooltip == cast.button.tooltip
                    and group.children[3].button.tooltip == aura.button.tooltip,
                c[1] .. ' tooltip'
            )
        end
    end
end)

test('the aura checkbox is the inverse of anyrank and starts unticked for a new condition', function()
    local f, a = fixture(2)
    local value = {}
    local updates = 0

    local box = a:Widget_AuraRankWidget(value, function()
        updates = updates + 1
    end)

    assert(box:GetValue() == true, 'a saved condition without anyrank keeps the exact ID, so it shows ticked')
    box:Fire('OnValueChanged', false)
    assert(value.anyrank == true and updates == 1, 'unticking must store anyrank=true')
    box:Fire('OnValueChanged', true)
    assert(value.anyrank == nil and updates == 2, 'ticking must clear anyrank')
    local saved = { spell = 10, anyrank = true }
    local other = a:Widget_AuraRankWidget(saved, function() end)
    assert(other:GetValue() == false, 'anyrank=true shows unticked')
    assert(saved.anyrank == true, 'building the widget must not write')
    local exact = { spell = 10, anyrank = false }
    assert(a:Widget_AuraRankWidget(exact, function() end):GetValue() == true and exact.anyrank == false)
end)

test('the cast and spell checkboxes keep ranked as it was stored', function()
    local f, a = fixture(2)
    local value = {}
    local updates = 0

    local box = a:Widget_SpellRankWidget(value, function()
        updates = updates + 1
    end)

    assert(box:GetValue() == false, 'new cast conditions start unticked: any rank')
    box:Fire('OnValueChanged', true)
    assert(value.ranked == true and updates == 1)
    box:Fire('OnValueChanged', false)
    assert(value.ranked == nil and updates == 2)
    assert(a:Widget_SpellRankWidget({ ranked = true }, function() end):GetValue() == true)
    local spellValue = { spell = 403 }

    local group = a:Widget_SpellWidget(
        0,
        'Spell_EditBox',
        spellValue,
        function() return 403 end,
        function() return true end,
        function() end
    )

    local rank = group.children[3]
    assert(rank:GetValue() == false)
    rank:Fire('OnValueChanged', true)
    assert(spellValue.ranked == true)
    rank:Fire('OnValueChanged', false)
    assert(spellValue.ranked == false)
end)

test(
    'a condition group takes the hidden checkbox (nil) as a no-op, so saved copies of the built-in widgets still build',
    function()
        local f, a = fixture(1)
        local group = a:CreateConditionGroup()
        local hidden = a:Widget_AuraRankWidget({}, function() end)
        assert(hidden == nil)
        group:AddChild(hidden)
        assert(#group.children == 0)
        local real = a:CreateConditionCheckBox()
        group:AddChild(real)
        assert(#group.children == 1)
    end
)

test('rank checkbox tooltips never leak to the next user of a pooled checkbox', function()
    local f, a = fixture(2)
    local box = a:Widget_AuraRankWidget({}, function() end)
    assert(box.button.tooltip)
    a:ReleaseConditionWidget(box)
    local again = a:CreateConditionCheckBox()
    assert(again == box and again.button.tooltip == nil)
end)

test('only aura condition types start with every rank matching, and only where ranks exist', function()
    for _, c in ipairs(CLIENTS) do
        local f, a = fixture(c[2])

        a.conditionDefinitions = {
            BUFF = {
                fields = { unit = 'string', spell = { 'string', 'number' }, anyrank = 'boolean', ownbuff = 'boolean' },
            },
            DEBUFF_STACKS = { fields = { anyrank = 'boolean', value = 'number' } },
            STEALABLE = { fields = { unit = 'string' } },
            CASTING_SPELL = { fields = { unit = 'string', spell = { 'string', 'number' }, ranked = 'boolean' } },
        }

        f.load('Core/condition_editor.lua')

        for _, tag in ipairs({ 'BUFF', 'DEBUFF_STACKS' }) do
            local value = a:NewConditionValue(tag)
            assert(value.type == tag)
            assert((value.anyrank == true) == c[3] and (c[3] or value.anyrank == nil), c[1] .. ' ' .. tag .. ' default')
        end

        for _, tag in ipairs({ 'STEALABLE', 'CASTING_SPELL', 'NOT_REGISTERED' }) do
            local value = a:NewConditionValue(tag)

            assert(
                value.type == tag and next(value, next(value)) == nil and value.anyrank == nil and value.ranked == nil,
                c[1] .. ' ' .. tag
            )
        end
    end
end)

test('the description of a new aura condition says any rank, a saved one stays exact', function()
    local f, a = fixture(2)
    f.load('Core/presentation.lua')
    local label = a.AuraSpellLabel

    if label then
        local fresh = label(a, { spell = 10, anyrank = true })
        local saved = label(a, { spell = 10 })
        assert(fresh:find('any rank', 1, true) and not saved:find('any rank', 1, true))
    end
end)

-- The announcement editor.
local function announcementFixture(project)
    local f = F.new(project)
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local codecData, codecDeps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = codecData
    a.NewRotationCodec = function() return codecData.NewCodec(codecDeps) end
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1

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

    local parent = create('Frame')
    parent:SetSize(1000, 600)
    return f, parent
end

test('the announcement rank checkbox is per client, unticked by default, and keeps ranked as stored', function()
    for _, c in ipairs(CLIENTS) do
        for _, stored in ipairs({ false, true }) do
            local f, parent = announcementFixture(c[2])
            local a = f.addon

            a.db.profile.announces = {
                {
                    type = 'spell',
                    spell = 403,
                    ranked = stored or nil,
                    event = 'SUCCEEDED',
                    announce = 'local',
                    value = 'Cast',
                },
            }

            local p = a:OpenNativeSettings(parent, 'Announces')
            local box = p.fields.entry1ranked
            assert((box ~= nil) == c[3], c[1] .. ' announcement rank checkbox')

            if c[3] then
                assert(box.checked == stored, c[1] .. ' announcement default')
                assert(box.tooltip and box.tooltip:find('any rank', 1, true))
                box:Click()
                assert(p:SettingsData().profile.announces[1].ranked == not stored, c[1] .. ' toggling stores ranked')
            else
                assert(a.db.profile.announces[1].ranked == (stored or nil), c[1] .. ' a stored value is left alone')
            end
        end
    end
end)

-- The rotation editor card.
local function editorFixture(project)
    local f = F.new(project)
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.nativeFrames = frames
    dofile('tests/fixtures/spell_editbox.lua')(f, create)

    local function body()
        return {
            name = 'Mine',
            switch = {},
            rotation = { { id = 'stop', type = 'stop', conditions = {} } },
            cooldowns = { { id = 'optional', type = 'spell', action = 324, conditions = {} } },
        }
    end

    a.db.profile.rotations = { [0] = { mine = body() } }
    a.configPaneGeneration = 1

    function a:GetEditableRotation(spec, id)
        return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id]
    end

    function a:GetDefaultIdForRuntime() end

    function a:ListDefaultRotations()
        return {}
    end

    function a:GetImportValidationOptions()
        return {}
    end

    function a:validateCondition()
        return true
    end

    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    a.EvaluateNextAction = function() end

    for _, file in ipairs({
        'Platform/spells.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/rotation_draft.lua',
        'Data/validation.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua', 'Core/rotation_tags.lua',
        'Core/rotation_canvas.lua', 'UI/window.lua'
    }) do
        f.load(file)
    end

    for _, file in ipairs({
        'UI/rotation_cards.lua', 'UI/rotation_canvas.lua', 'UI/color_picker.lua', 'UI/rotation_effect_fields.lua',
        'UI/rotation_fields.lua', 'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua',
        'UI/rotation_editor.lua'
    }) do
        local h = io.open(file)

        if h then
            h:close()
            f.load(file)
        end
    end

    dofile('tests/fixtures/rotation_header_backend.lua')(a, f.env.DEFAULT, f.env.NEW)
    local parent = create('Frame')
    parent:SetSize(740, 600)
    return f, parent
end

test('the rotation step rank checkbox is per client and writes ranked as before', function()
    for _, c in ipairs(CLIENTS) do
        local f, parent = editorFixture(c[2])
        local a = f.addon
        local pane = assert(a:CreateRotationEditor(parent, 0, 'mine'))
        pane:SelectContent('cooldowns')
        local card

        for _, candidate in ipairs(pane.canvas.cards) do
            if candidate.model and candidate.model.id == 'optional' and candidate.frame:IsShown() then
                card = candidate
            end
        end

        card.action:Click()
        local controls = card.fieldControls
        assert(controls.spell, c[1] .. ' spell field')
        assert((controls.ranked ~= nil) == c[3], c[1] .. ' step rank checkbox')

        if c[3] then
            assert(controls.ranked.checked == false and controls.ranked.tooltip)
            controls.ranked:Click()
            assert(pane.workspace:Snapshot().cooldowns[1].ranked == true, c[1] .. ' ticking stores ranked')
        end
    end
end)

test('no current English or locale text still offers Match all ranks', function()
    local files = { 'Locales/enUS.lua' }

    for _, loc in ipairs({'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}) do
        files[#files + 1] = 'Locales/' .. loc .. '.lua'
    end

    for _, path in ipairs(files) do
        local h = assert(io.open(path, 'rb'))
        local text = h:read('*a')
        h:close()
        assert(not text:find('Match all ranks', 1, true), path .. ' still says Match all ranks')
    end

    -- The label every rank checkbox uses, in every locale.
    for _, path in ipairs(files) do
        local h = assert(io.open(path, 'rb'))
        local text = h:read('*a')
        h:close()
        -- English: [id] = "label"; a translation records the English it answers in the comment above it.
        local marker = path:match('enUS%.lua$') and ('= "' .. LABEL .. '",') or (' English: ' .. LABEL .. '\n')
        assert(text:find(marker, 1, true), path .. ' lacks the shared rank label')
    end

    for _, path in ipairs({
        'Conditions/common.lua',
        'Help/conditional.lua',
        'Help/rotations.lua',
        'Help/announce.lua',
        'UI/rotation_fields.lua',
        'UI/settings_announces.lua',
        'UI/rotation_reference.lua',
        'UI/collection_compare.lua',
    }) do
        local h = assert(io.open(path, 'rb'))
        local text = h:read('*a')
        h:close()
        assert(not text:find('Match all ranks', 1, true), path .. ' still says Match all ranks')
    end
end)

finish()
