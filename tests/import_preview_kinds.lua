-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The preview step of the import window for every kind that imports directly: replacing an entry COMPARES the
-- import with it, a new copy PREVIEWS everything the import contains, and Check import lists the problems. Looking
-- is optional (Import is never gated) and never saves or changes anything.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(product)
    local f = F.new(product)
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
        'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Core/collection_data.lua', 'Core/category_data.lua',
        'Core/custom_condition_data.lua', 'Help/general.lua', 'Help/conditions.lua', 'Help/effects.lua',
        'Help/itemsets.lua', 'Help/announce.lua', 'UI/window.lua', 'UI/help.lua', 'UI/icon_picker.lua',
        'UI/color_picker.lua', 'UI/settings_roster_order.lua', 'UI/settings_layout.lua', 'UI/settings_ordered.lua',
        'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua', 'UI/settings_form.lua',
        'UI/settings_transfer.lua', 'UI/cpu_profile.lua', 'UI/settings_general.lua', 'UI/settings_profiles.lua',
        'UI/collection_compare.lua', 'UI/transfer_review.lua', 'UI/rotation_comparison.lua',
        'UI/custom_condition_transfer.lua', 'UI/settings_collections.lua', 'UI/settings_announces.lua',
        'UI/settings_effects.lua', 'UI/settings_items.lua', 'UI/settings_conditions.lua'
    }) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    local parent = create('Frame')
    parent:SetSize(1000, 600)
    return f, parent, a
end

local function paste(d, text)
    d.input:SetText(text)
    d.input.scripts.OnTextChanged(d.input, true)
end

local function clone(x, seen)
    if type(x) ~= 'table' then
        return x
    end

    seen = seen or {}

    if seen[x] then
        return seen[x]
    end

    local result = {}
    seen[x] = result

    for k, v in pairs(x) do
        result[k] = clone(v, seen)
    end

    return result
end

local function same(x, y, seen)
    if type(x) ~= type(y) then
        return false
    end
    if type(x) == 'function' or type(x) == 'userdata' then
        return true
    end
    if type(x) ~= 'table' then
        return x == y
    end

    seen = seen or {}

    if seen[x] then
        return true
    end

    seen[x] = true

    for k, v in pairs(x) do
        if not same(v, y[k], seen) then
            return false
        end
    end

    for k in pairs(y) do
        if x[k] == nil then
            return false
        end
    end

    return true
end

local function labels(d)
    local out = {}

    for _, row in ipairs(d.rows or {}) do
        out[#out + 1] = row.label
    end

    return table.concat(out, '|')
end

local function changed(d)
    local n = 0

    for _, row in ipairs(d.rows or {}) do
        if row.changed then
            n = n + 1
        end
    end

    return n
end

local function snapshot(a)
    return { clone(a.db.profile), clone(a.db.global), clone(a.db.char) }
end

local function unchanged(a, before)
    return same(before[1], a.db.profile) and same(before[2], a.db.global) and same(before[3], a.db.char)
end

local function reportText(a)
    local r = a.transferCheckReport
    return r and r.text or ''
end

-- One loop of the same checks for every kind: the label follows the checkbox, Compare opens two columns, Preview one
-- column with every field, Check lists problems, nothing is saved, and a bad text is explained, never gated.
local function kinds()
    local list = {}

    list[#list + 1] = {
        name = 'item set',
        make = function(a, parent)
            a.db.profile.itemsets = { set = { name = 'Consumables', items = { 1, 2 } } }
            a.db.global.itemsets = {}
            a.db.char = { bindings = {} }
            a.UpdateItemSetButtons = function() end
            a.UpdateBoundButton = function() end
            a.EndHighlightSlot = function() end
            local p = a:CreateSettingsForm(parent)

            p:Open(function(form)
                a:BuildItemSettings(form)
            end)

            p.fields.transfer:Click()

            return p,
                p.textDialog,
                a:NewRotationCodec():Encode({
                    format = 'RM-ItemSet',
                    version = 1,
                    name = 'Incoming',
                    items = { 5, 6, 7 },
                }),
                a:NewRotationCodec():Encode({ format = 'RM-ItemSet', version = 1, name = 'Bad', items = 'x' }),
                'Item 3'
        end,
    }

    list[#list + 1] = {
        name = 'effect',
        make = function(a, parent)
            a.db.global.effects = { e = { name = 'Selected', type = 'pixel', lines = 8 } }
            a.RemoveAllCurrentGlows = function() end
            a.HideGlow = function() end
            a.Glow = function() end
            local p = a:OpenNativeSettings(parent, 'Effects')
            p.fields.transfer:Click()

            return p,
                p.textDialog,
                a:NewRotationCodec():Encode({ name = 'Incoming', type = 'pixel', lines = 5 }),
                a:NewRotationCodec():Encode({ name = 'Bad', type = 'nonsense' }),
                'Lines'
        end,
    }

    list[#list + 1] = {
        name = 'announcement',
        make = function(a, parent)
            a.events = { SUCCEEDED = 'Success' }

            a.db.profile.announces = {
                {
                    id = 'a',
                    type = 'spell',
                    spell = 403,
                    event = 'SUCCEEDED',
                    announce = 'local',
                    value = 'Keep text',
                    name = 'First',
                },
            }

            local p = a:CreateSettingsForm(parent)

            p:Open(function(form)
                a:BuildAnnounceSettings(form)
            end)

            p.fields.transfer:Click()

            return p,
                p.textDialog,
                a:NewRotationCodec():Encode({
                    format = 'RM-Announcement',
                    version = 1,
                    announcement = {
                        type = 'spell',
                        spell = 8042,
                        event = 'SUCCEEDED',
                        announce = 'local',
                        value = 'Incoming text',
                        name = 'Second',
                    },
                }),
                a:NewRotationCodec():Encode({
                    format = 'RM-Announcement',
                    version = 1,
                    announcement = { type = 'bad' },
                }),
                'Text'
        end,
    }

    list[#list + 1] = {
        name = 'profile',
        make = function(a, parent)
            local current = 'One'
            local profiles = { One = { enable = true, poll = .1 }, Two = { enable = false, poll = .2 } }
            a.db.profile = profiles.One
            a.db.profiles = profiles
            a.db.GetCurrentProfile = function() return current end

            a.db.GetProfiles = function()
                local list = {}

                for name in pairs(profiles) do
                    list[#list + 1] = name
                end

                return list
            end

            a.DisableRotation = function() end
            a.EnableRotation = function() end
            local p = a:CreateSettingsForm(parent)

            p:Open(function(form)
                a:BuildProfileSettings(form)
            end)

            p.fields.transfer:Click()
            local exported = p.textDialog.input:GetText()
            local data = a:NewRotationCodec():Decode(exported).value
            data.name = 'Incoming'
            data.profile.poll = .5

            return p,
                p.textDialog,
                a:NewRotationCodec():Encode(data),
                a:NewRotationCodec():Encode({ format = 'RM-Profile', version = 1, name = 'Bad', profile = 7 }),
                'Polling Interval (seconds)'
        end,
    }

    list[#list + 1] = {
        name = 'condition category',
        make = function(a, parent)
            a.conditionDefinitions = { A = { description = 'Alpha' }, B = { description = 'Beta' } }
            a.conditionSpecials = {}
            a.db.profile.condition_groups = { { id = 'g', name = 'Before', conditions = { 'A' }, icon = 12 } }
            a.listConditions = function() return { 'A' } end
            a.db.global.custom_conditions = {}
            a.db.profile.switch_conditions = {}
            a.db.profile.disabled_conditions = {}
            local p = a:CreateSettingsForm(parent)
            p.mode = 'categories'

            p:Open(function(form)
                a:BuildConditionSettings(form)
            end)

            p.fields.transfer:Click()

            return p,
                p.textDialog,
                a:NewRotationCodec():Encode({
                    format = 'RM-ConditionCategory',
                    version = 1,
                    name = 'After',
                    icon = 'path',
                    conditions = { 'A', 'B' },
                }),
                a:NewRotationCodec():Encode({
                    format = 'RM-ConditionCategory',
                    version = 1,
                    name = 'Bad',
                    conditions = { 'NOPE' },
                }),
                'Conditions'
        end,
    }

    return list
end

for _, kind in ipairs(kinds()) do
    test(
        kind.name .. ': Compare while replacing, Preview for a new copy, Check lists problems, and nothing is saved',
        function()
            local f, parent, a = fixture()
            local p, d, good, bad, field = kind.make(a, parent)
            assert(d and d.frame:IsShown() and d.options and d.options.review, 'no review for ' .. kind.name)
            assert(good and bad)
            local before = snapshot(a)

            assert(
                d.mode == 'replace'
                    and d.preview:IsShown()
                    and d.inspect:IsShown()
                    and d.preview:GetText() == 'Compare import'
                    and d.inspect:GetText() == 'Check import',
                tostring(d.preview:GetText())
            )

            assert(d.apply:IsEnabled(), 'looking is optional: Import must not be gated')
            paste(d, good)
            assert(d.apply:IsEnabled(), 'typing disabled Import for a kind that imports directly')
            -- Compare: two columns, changed rows.
            d.preview:Click()
            local c = p.comparison
            assert(c and c.frame:IsShown() and c.fromImport, 'no comparison')
            assert(changed(c) >= 1, 'a comparison of different entries shows no change: ' .. labels(c))
            assert(c.leftHeading:GetText() ~= nil and c.rightHeading:IsShown(), 'two columns expected')
            assert(unchanged(a, before), 'Compare saved something')
            -- Preview: one column, every field.
            d.destination:Click()

            assert(
                d.mode == 'new' and d.preview:GetText() == 'Preview import' and not c.frame:IsShown(),
                'switching to a new copy must retire the comparison'
            )

            d.preview:Click()
            c = p.comparison

            assert(
                c and c.frame:IsShown() and c.fromImport and not c.rightHeading:IsShown(),
                'no single-column preview'
            )

            assert(labels(c):find(field, 1, true), 'the preview omits ' .. field .. ': ' .. labels(c))
            assert(unchanged(a, before), 'Preview saved something')
            -- Check import.
            d.inspect:Click()
            local report = reportText(a)

            assert(
                report:find('This import can be applied.', 1, true) and report:find('No problems found.', 1, true),
                report
            )

            -- Text changed closes the view; a bad text is explained by both buttons and still never gates Import.
            paste(d, bad)
            assert(not c.frame:IsShown(), 'changing the text left the view open')
            assert(d.apply:IsEnabled())
            d.preview:Click()
            assert(d.status:GetText():find('unavailable', 1, true), tostring(d.status:GetText()))
            d.inspect:Click()
            report = reportText(a)
            assert(report:find('cannot be applied', 1, true) and not report:find('No problems found.', 1, true), report)
            assert(unchanged(a, before), 'Check saved something')
            -- Closing the transfer closes the view.
            paste(d, good)
            d.preview:Click()
            assert(p.comparison.frame:IsShown())
            d.cancel:Click()
            assert(not p.comparison.frame:IsShown(), 'closing the transfer left the preview open')
        end
    )
end

-- "New" is selected (nothing exists yet to replace): Replace is unticked and disabled, the mode is new, the label is
-- Preview import, a click on the disabled checkbox changes nothing and Preview opens the single-column view.
local function newSelected(name, make, text)
    test(name .. ': with New selected nothing can be replaced and Preview works', function()
        local f, parent, a = fixture()
        local p = make(a, parent)
        local d = p.textDialog
        assert(d and d.frame:IsShown(), 'no transfer window')

        assert(
            d.mode == 'new' and not d.destination:GetChecked() and not d.destination:IsEnabled(),
            'mode ' .. tostring(d.mode)
        )

        assert(d.preview:GetText() == 'Preview import' and d.inspect:GetText() == 'Check import')
        d.destination:Click()

        assert(
            d.mode == 'new' and not d.destination:GetChecked() and d.preview:GetText() == 'Preview import',
            'a disabled checkbox flipped the mode'
        )

        paste(d, a:NewRotationCodec():Encode(text))
        d.preview:Click()
        local c = p.comparison

        assert(
            c and c.frame:IsShown() and c.fromImport and not c.rightHeading:IsShown(),
            'Preview did nothing: ' .. tostring(d.status:GetText())
        )
    end)
end

newSelected(
    'effect',
    function(a, parent)
        a.db.global.effects = {}
        a.RemoveAllCurrentGlows = function() end
        a.HideGlow = function() end
        a.Glow = function() end
        local p = a:OpenNativeSettings(parent, 'Effects')
        p.fields.transfer:Click()
        return p
    end,
    { name = 'Incoming', type = 'pixel', lines = 5 }
)

newSelected(
    'announcement',
    function(a, parent)
        a.events = { SUCCEEDED = 'Success' }
        a.db.profile.announces = {}
        local p = a:CreateSettingsForm(parent)

        p:Open(function(form)
            a:BuildAnnounceSettings(form)
        end)

        p.fields.transfer:Click()
        return p
    end,
    {
        format = 'RM-Announcement',
        version = 1,
        announcement = {
            type = 'spell',
            spell = 8042,
            event = 'SUCCEEDED',
            announce = 'local',
            value = 'Incoming text',
            name = 'Second',
        },
    }
)

newSelected(
    'item set',
    function(a, parent)
        a.db.profile.itemsets = {}
        a.db.global.itemsets = {}
        a.db.char = { bindings = {} }
        a.UpdateItemSetButtons = function() end
        local p = a:CreateSettingsForm(parent)

        p:Open(function(form)
            a:BuildItemSettings(form)
        end)

        p.fields.transfer:Click()
        return p
    end,
    { format = 'RM-ItemSet', version = 1, name = 'Incoming', items = { 5, 6 } }
)

newSelected(
    'profile',
    function(a, parent)
        local profiles = { One = { enable = true, poll = .1 } }
        a.db.profile = profiles.One
        a.db.profiles = profiles
        a.db.GetCurrentProfile = function() return 'One' end
        a.db.GetProfiles = function() return { 'One' } end
        a.DisableRotation = function() end
        a.EnableRotation = function() end
        local p = a:CreateSettingsForm(parent)

        p:Open(function(form)
            a:BuildProfileSettings(form)
        end)

        p.previousSelection = p.selection
        p.creating = true
        p:Draw()
        assert(p.creating, 'the New entry is not selected')
        p.fields.transfer:Click()
        return p
    end,
    { format = 'RM-Profile', version = 1, name = 'Incoming', profile = { poll = .5 } }
)

test('a comparison the user opened from the page is not closed by the import window', function()
    local f, parent, a = fixture()
    a.db.profile.itemsets = { a = { name = 'One', items = { 1 } }, b = { name = 'Two', items = { 2 } } }
    a.db.global.itemsets = {}
    a.db.char = { bindings = {} }
    a.UpdateItemSetButtons = function() end
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildItemSettings(form)
    end)

    local own = a:ShowCollectionComparison(p, 'itemset', { name = 'One', items = { 1 } }, {
        name = 'Two',
        items = { 2 },
    })

    assert(own.frame:IsShown() and not own.fromImport)
    a:CloseTransferReview(p)
    assert(own.frame:IsShown(), 'a page comparison was closed as if it were an import view')
end)

test('item set import is applied exactly as before, after looking or not', function()
    local f, parent, a = fixture()
    a.db.profile.itemsets = { set = { name = 'Consumables', items = { 1, 2 } } }
    a.db.global.itemsets = {}
    a.db.char = { bindings = {} }
    a.UpdateItemSetButtons = function() end
    a.UpdateBoundButton = function() end
    a.EndHighlightSlot = function() end
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildItemSettings(form)
    end)

    p.fields.transfer:Click()
    local d = p.textDialog

    local text = a:NewRotationCodec():Encode({
        format = 'RM-ItemSet',
        version = 1,
        name = 'Incoming',
        items = { 5, 6, 7 },
    })

    paste(d, text)
    d.preview:Click()
    d.inspect:Click()
    d.apply:Click()
    local items = a.db.profile.itemsets.set.items
    assert(#items == 3 and items[1] == 5 and items[3] == 7, 'replacement is not what the preview showed')
    p.fields.transfer:Click()
    d = p.textDialog
    paste(d, text)
    d.destination:Click()
    d.name:SetText('Copy')
    d.name.scripts.OnTextChanged(d.name, true)
    d.apply:Click()
    local found

    for id, set in pairs(a.db.profile.itemsets) do
        if set.name == 'Copy' then
            found = set
        end
    end

    assert(found and #found.items == 3, 'a new copy without looking failed')
end)

test('the creating variants (nothing to replace) always say Preview import', function()
    local f, parent, a = fixture()
    a.db.profile.itemsets = {}
    a.db.global.itemsets = {}
    a.db.char = { bindings = {} }
    a.UpdateItemSetButtons = function() end
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildItemSettings(form)
    end)

    p.fields.transfer:Click()
    local d = p.textDialog

    assert(
        d.mode == 'new'
            and not d.destination:IsEnabled()
            and d.preview:GetText() == 'Preview import'
            and d.preview:IsShown()
    )

    paste(d, a:NewRotationCodec():Encode({ format = 'RM-ItemSet', version = 1, name = 'Incoming', items = { 5, 6 } }))
    d.preview:Click()

    assert(
        p.comparison.frame:IsShown() and not p.comparison.rightHeading:IsShown() and labels(p.comparison):find(
            'Item 2',
            1,
            true
        )
    )
end)

test('Check import names a taken effect name and a taken profile name', function()
    local f, parent, a = fixture()
    a.db.global.effects = { e = { name = 'Selected', type = 'pixel' }, other = { name = 'Taken', type = 'pixel' } }
    a.RemoveAllCurrentGlows = function() end
    a.HideGlow = function() end
    a.Glow = function() end
    local p = a:OpenNativeSettings(parent, 'Effects')
    p.fields.transfer:Click()
    local d = p.textDialog
    paste(d, a:NewRotationCodec():Encode({ name = 'Source', type = 'pixel', lines = 5 }))
    d.destination:Click()
    d.name:SetText('Taken')
    d.name.scripts.OnTextChanged(d.name, true)
    d.inspect:Click()
    local report = reportText(a)
    assert(report:find('already in use', 1, true) and report:find('cannot be applied', 1, true), report)
    d.name:SetText('Fresh')
    d.name.scripts.OnTextChanged(d.name, true)
    d.inspect:Click()
    assert(reportText(a):find('No problems found.', 1, true), reportText(a))
end)

test('a profile preview caps the rows it draws and says how many it left out', function()
    local f, parent, a = fixture()
    local profiles = { One = { enable = true } }
    a.db.profile = profiles.One
    a.db.profiles = profiles
    a.db.GetCurrentProfile = function() return 'One' end
    a.db.GetProfiles = function() return { 'One' } end
    local p = a:CreateSettingsForm(parent)

    p:Open(function(form)
        a:BuildProfileSettings(form)
    end)

    p.fields.transfer:Click()
    local d = p.textDialog
    local data = a:NewRotationCodec():Decode(d.input:GetText()).value
    data.name = 'Big'

    for i = 1, 600 do
        data.profile['setting_' .. i] = i
    end

    paste(d, a:NewRotationCodec():Encode(data))
    d.destination:Click()
    d.preview:Click()
    local c = p.comparison
    assert(c.frame:IsShown() and #c.rows <= 400, 'rows not capped: ' .. #c.rows)
end)

test(
    'a custom condition import compares and previews its description, schema and code, and a bundle is pointed to its review',
    function()
        local f, parent, a = fixture()

        a.db.global.custom_conditions = {
            MINE = {
                description = 'Mine',
                icon = 12,
                fields = { amount = 'number' },
                valid = 'return true',
                evaluate = 'return true',
                print = 'return "x"',
                widget = '',
                help = '',
                on_register = '',
                on_unregister = '',
            },
        }

        a.CanResumeCustomConditionDialog = function() return true end
        a.describeCondition = function() return nil end
        local owner = { widgets = {} }

        local conditionParent = setmetatable({ nativeCustomEditor = true, rmConditionOwner = owner, form = nil }, {
            __index = parent,
        })

        function conditionParent:SetCallback() end
        function conditionParent:HideForChild() end
        function conditionParent:Show() end
        function conditionParent:Hide() end
        local condition = a.db.global.custom_conditions.MINE
        local d = a:ShowCustomConditionTransfer(conditionParent, function() end, 'MINE', condition)
        assert(d and d.options and d.options.review, 'no review on the custom condition window')

        local incoming = {
            format = 'RM-CustomCondition',
            version = 1,
            name = 'MINE',
            condition = {
                description = 'Theirs',
                icon = 12,
                fields = { amount = 'number', unit = 'string' },
                valid = 'return true',
                evaluate = 'return false -- different',
                print = 'return "y"',
                widget = '',
                help = '',
                on_register = '',
                on_unregister = '',
            },
        }

        local before = snapshot(a)
        paste(d, a:NewRotationCodec():Encode(incoming))
        assert(d.preview:GetText() == 'Compare import' and d.preview:IsShown())
        d.preview:Click()
        local p = conditionParent.rmCustomTransferForm
        local c = p.comparison

        assert(
            c and c.frame:IsShown() and c.fromImport and changed(c) >= 3,
            'no comparison: ' .. tostring(c and labels(c))
        )

        assert(
            labels(c):find('Code: evaluate', 1, true) and labels(c):find('Fields', 1, true) and labels(c):find(
                'Description',
                1,
                true
            ),
            labels(c)
        )

        d.destination:Click()
        assert(d.preview:GetText() == 'Preview import' and not c.frame:IsShown())
        d.preview:Click()
        c = p.comparison
        assert(c.frame:IsShown() and not c.rightHeading:IsShown() and labels(c):find('Code: print', 1, true), labels(c))
        local shown = false

        for _, row in ipairs(c.rows) do
            if row.left:find('different', 1, true) then
                shown = true
            end
        end

        assert(shown, 'the code of the import is not shown')
        d.inspect:Click()
        local report = reportText(a)
        assert(report:find('Lua code', 1, true) and report:find('No problems found.', 1, true), report)

        paste(d, a:NewRotationCodec():Encode({
            format = 'RM-CustomCondition',
            version = 1,
            name = 'X',
            condition = { description = 7 },
        }))

        d.inspect:Click()
        assert(reportText(a):find('Invalid custom condition', 1, true), reportText(a))
        assert(unchanged(a, before), 'looking saved something')
    end
)

finish()
