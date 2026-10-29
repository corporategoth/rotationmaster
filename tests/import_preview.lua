-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- The import window's first button follows its destination: replacing an entry COMPARES the import with it, a new
-- copy PREVIEWS the import in full, in the rotation editor's own read-only view. The second button checks the
-- import for problems. Nothing here may save anything or touch the candidate.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function fixture(product)
    local f = F.new(product)
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.nativeFrames = frames
    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    local data, envelope, options = make()
    a.RotationData = data
    a.conditionDefinitions = options.conditions
    a.db.keys = { char = 'A - Realm' }
    local n = 0

    a.uuid = function()
        n = n + 1
        return 'preview-' .. n
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

    for _, path in ipairs({
        'Platform/spells.lua', 'Data/catalog.lua', 'Data/diff.lua', 'Data/visual_comparison.lua',
        'Data/import_session.lua', 'Data/rotation_store.lua', 'Data/rotation_draft.lua', 'Core/rotation_library.lua',
        'Core/rotation_scope.lua', 'Core/imports.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua',
        'Core/rotation_tags.lua', 'Core/rotation_canvas.lua', 'UI/window.lua', 'UI/settings_layout.lua',
        'UI/settings_roster_order.lua', 'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_ordered.lua',
        'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/rotation_reference.lua', 'UI/rotation_comparison.lua',
        'UI/transfer.lua'
    }) do
        f.load(path)
    end

    for _, file in ipairs({
        'UI/rotation_cards.lua', 'UI/rotation_canvas.lua', 'UI/color_picker.lua', 'UI/rotation_effect_fields.lua',
        'UI/rotation_fields.lua', 'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua',
        'UI/rotation_editor.lua', 'UI/unsaved.lua', 'UI/draft_change_controls.lua', 'UI/help.lua'
    }) do
        local h = io.open(file)

        if h then
            h:close()
            f.load(file)
        end
    end

    local body = envelope().body

    body.rotation = {
        {
            id = 'branch',
            type = 'branch',
            conditions = {},
            onTrue = {
                { id = 'yes', type = 'spell', action = 403, conditions = { type = 'SPELL_KNOWN', spell = 403 } },
            },
            onFalse = { { id = 'no', type = 'stop', conditions = {} } },
        },
    }

    body.cooldowns = { { id = 'optional', type = 'spell', action = 324, conditions = {} } }

    a.db.profile = {
        rotationFallbackID = 'Default',
        rotationStore = {
            version = 1,
            classes = { SHAMAN = { [0] = { mine = { body = body } } } },
            characters = {},
            legacy = {},
        },
    }

    a.GetRotationContext = function(_, spec)
        return { class = 'SHAMAN', family = 'tbc', spec = spec, actionContext = 'player', combatDataPolicy = 'probe' }
    end

    assert(a:BindRotationProfile())

    a.GetEditableRotation = function()
        error('ordinary transfer used mutable getter')
    end

    local incoming = data.CopyData(body)
    incoming.name = 'Incoming'
    incoming.priority = 7
    incoming.description = 'What it does'
    incoming.rotation[1].onTrue[1].action = 974
    incoming.rotation[1].onTrue[1].conditions = { type = 'SPELL_KNOWN', spell = 974 }
    local wire = { incoming = incoming }

    a.NewRotationCodec = function()
        return {
            Encode = function() return 'export-text' end,
            Decode = function(_, text)
                if text == 'bad' then
                    return nil, 'invalid-base64'
                end

                if text == 'future' then
                    local value = envelope()
                    value.futureMetadata = { coefficient = 42 }
                    return { kind = 'envelope', original = text, value = value }
                end

                if text == 'envelope' then
                    local value = envelope()
                    value.body.name = 'Packaged'
                    return { kind = 'envelope', original = text, value = value }
                end

                if text == 'scalar' then
                    return { kind = 'legacy', original = text, value = 7 }
                end

                return { kind = 'legacy', original = text, value = data.CopyData(wire[text]) }
            end,
        }
    end

    a.ShowComparisonReport = function(_, text) return text end
    a.printCondition = function() return 'Readable conditions' end
    a.ShowConfig = function() end
    return f, a, data, body, wire
end

local function reference(a)
    return 'mine'
end

local function paste(d, text)
    d.input:SetText(text)
    d.input.scripts.OnTextChanged(d.input, true)
end

local function counts(a)
    local compared = 0
    local native = a.ShowNativeImportPreview

    a.ShowNativeImportPreview = function(...)
        compared = compared + 1
        return native(...)
    end

    return function() return compared end
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

local function diff(x, y, path, out, seen)
    path = path or ''
    out = out or {}
    seen = seen or {}

    if type(x) ~= type(y) then
        out[#out + 1] = path .. ': ' .. type(x) .. ' vs ' .. type(y)
        return out
    end

    if type(x) == 'function' or type(x) == 'userdata' then
        return out
    end

    if type(x) ~= 'table' then
        if x ~= y then
            out[#out + 1] = path .. ': ' .. tostring(x) .. ' vs ' .. tostring(y)
        end

        return out
    end

    if seen[x] then
        return out
    end

    seen[x] = true

    for k, v in pairs(x) do
        diff(v, y[k], path .. '.' .. tostring(k), out, seen)
    end

    for k in pairs(y) do
        if x[k] == nil then
            out[#out + 1] = path .. '.' .. tostring(k) .. ' added'
        end
    end

    return out
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

local function cardIds(pane)
    local ids = {}

    for _, card in ipairs(pane.canvas.scene.cards) do
        ids[card.id] = card
    end

    return ids
end

test(
    'the first button reads Compare import while replacing and Preview import for a new copy, following the checkbox at once',
    function()
        local _, a = fixture()
        local d = a:ShowRotationTransfer(0, reference(a))

        assert(d.mode == 'replace' and d.destination:GetChecked() and d.preview:GetText() == 'Compare import', tostring(
            d.preview:GetText()
        ))

        assert(
            d.inspect:GetText() == 'Check import',
            'the diagnostics button is named for what it does: ' .. tostring(d.inspect:GetText())
        )

        d.destination:Click()
        assert(d.mode == 'new' and d.preview:GetText() == 'Preview import')
        d.destination:Click()
        assert(d.mode == 'replace' and d.preview:GetText() == 'Compare import')
        d.destination:Click()
        assert(d.preview:GetText() == 'Preview import' and d.inspect:GetText() == 'Check import')
        assert(d.preview:IsShown() and d.inspect:IsShown(), 'both buttons stay')
    end
)

test('a transfer opened from an entry that cannot be replaced still previews the import in full', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, 'missing')
    paste(d, 'incoming')
    d.preview:Click()
    local view = a.rotationTransferForm.importContent
    assert(view and view.frame:IsShown() and view.pane.workspace:Snapshot().name == 'Incoming')
end)

test('with no destination to replace the button is always Preview import', function()
    local _, a = fixture()
    a.GetRotationContext = a.GetRotationContext
    local d = a:ShowRotationTransfer(0, 'missing')
    assert(d.mode == 'new' and not d.destination:IsEnabled() and d.preview:GetText() == 'Preview import')
    d.destination:Click()
    assert(d.mode == 'new' and d.preview:GetText() == 'Preview import', 'a disabled destination cannot make it Compare')
end)

test('tooltips and help tell the two actions apart: what you would get, and what is wrong with it', function()
    local f, a = fixture()
    local L = f.libraries['AceLocale-3.0'].GetLocale()
    local d = a:ShowRotationTransfer(0, reference(a))

    local compare, preview, inspect =
        L["Compare import shows what would change in the entry you are replacing, side by side with its current content. Nothing is saved."],
        L["Preview import shows everything this import contains, read-only, the way the editor shows it. Nothing is saved."],
        L["Check import lists problems with the text instead of its content: why it cannot be imported and any unsupported data. It does not import or change anything."]

    local entries = dofile('tests/fixtures/locale_entries.lua').entries('enUS', true)

    assert(
        entries[compare] == compare and entries[preview] == preview and entries[inspect] == inspect,
        'help texts are registered with their exact English source'
    )

    assert(
        compare:find('would change', 1, true)
            and preview:find('everything this import contains', 1, true)
            and inspect:find('problems', 1, true)
            and inspect:find('unsupported', 1, true)
    )

    assert(d.preview.tooltip == compare and d.inspect.tooltip == inspect)
    local briefs = a:TransferHelpBriefs()
    assert(briefs.preview(d) == compare and briefs.inspect == inspect)
    d.destination:Click()
    assert(d.preview.tooltip == preview and briefs.preview(d) == preview)
    local general = L["With Replace selected entry ticked, the button reads Compare import and shows what would change in that rotation. For a new named copy it reads Preview import and shows everything the import contains, read-only, as the rotation editor shows it. Neither saves anything. Import is enabled only for a ready preview or comparison; changing the text requires another one. Check import shows read-only diagnostics, including unsupported data that prevents import."]

    assert(
        general:find('Compare import', 1, true)
            and general:find('Preview import', 1, true)
            and general:find('Check import', 1, true)
            and not general:find('Inspect', 1, true)
    )

    assert(
        L["This view shows the rotation as it would be imported: name, specializations, switch condition, steps and cooldowns. It is read-only and works on a copy; it saves and changes nothing. Close it to choose the destination and import from the transfer dialog. A changed text, closed transfer or changed profile retires this Help."]:find(
            'read%-only'
        )
            and entries["Explain this read-only preview of the incoming rotation."]
                == "Explain this read-only preview of the incoming rotation."
    )
end)

test('the help tooltip of the first button is read when it opens, so it follows the mode', function()
    local f, a = fixture()
    local L = f.libraries['AceLocale-3.0'].GetLocale()
    local d = a:ShowRotationTransfer(0, reference(a))
    assert(d.help, 'no help button')
    local lines = {}

    f.env.GameTooltip = {
        IsOwned = function() return false end,
        SetOwner = function() end,
        SetText = function(_, text)
            lines[#lines + 1] = text
        end,
        Show = function() end,
        Hide = function() end,
        AddLine = function(_, text)
            lines[#lines + 1] = text
        end,
    }

    d.preview.scripts.OnEnter(d.preview)

    assert(
        lines[#lines]
            == L["Compare import shows what would change in the entry you are replacing, side by side with its current content. Nothing is saved."],
        tostring(lines[#lines])
    )

    d.destination:Click()
    d.preview.scripts.OnEnter(d.preview)

    assert(
        lines[#lines]
            == L["Preview import shows everything this import contains, read-only, the way the editor shows it. Nothing is saved."],
        tostring(lines[#lines])
    )
end)

test('Compare import (replacing) still shows the comparison and never the full view', function()
    local _, a = fixture()
    local compared = counts(a)
    local d = a:ShowRotationTransfer(0, reference(a))
    paste(d, 'incoming')
    d.preview:Click()

    assert(
        compared() == 1
            and a.rotationTransferForm.importPreview
            and a.rotationTransferForm.importPreview.frame:IsShown(),
        'comparison not shown'
    )

    assert(not a.rotationTransferForm.importContent, 'replace mode opened the full view')
    assert(d.apply:IsEnabled() and d.inspect:IsEnabled())
end)

test('Preview import (new copy) opens the full content in the read-only editor view and no comparison', function()
    local _, a = fixture()
    local compared = counts(a)
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'incoming')
    d.preview:Click()
    local p = a.rotationTransferForm
    local view = p.importContent

    assert(
        compared() == 0 and not (p.importPreview and p.importPreview.frame:IsShown()),
        'a new copy compared with the selected rotation'
    )

    assert(
        view
            and view.frame:IsShown()
            and view.pane
            and view.pane.active
            and view.workspace.preview
            and view.workspace.readOnly,
        'full view missing'
    )

    assert(view.frame:GetFrameStrata() == 'FULLSCREEN_DIALOG')
    local pane = view.pane
    local snapshot = pane.workspace:Snapshot()
    assert(pane.workspace == view.workspace, 'the editor works on another workspace than the preview copy')
    assert(snapshot.name == 'Incoming' and snapshot.priority == 7 and snapshot.description == 'What it does')

    assert(
        pane.name:GetText() == 'Incoming'
            and pane.priority:GetText() == '7'
            and pane.description:GetText() == 'What it does',
        'header shows the incoming rotation'
    )

    assert(pane.readOnlyPill:IsShown(), 'read-only marker missing')
    assert(d.apply:IsEnabled(), 'a ready preview enables Import')
end)

test('the full view lists every step, nested branch arm and cooldown of the import, with its conditions', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'incoming')
    d.preview:Click()
    local pane = a.rotationTransferForm.importContent.pane
    local ids = cardIds(pane)
    assert(ids.branch and ids.yes and ids.no, 'nested rotation steps are missing')

    assert(
        pane.workspace:Snapshot().rotation[1].onTrue[1].action == 974
            and pane.workspace:Snapshot().rotation[1].onFalse[1].type == 'stop'
    )

    assert(pane.workspace:Snapshot().rotation[1].onTrue[1].conditions.spell == 974, 'nested condition missing')
    pane:SelectContent('cooldowns')
    assert(cardIds(pane).optional, 'cooldowns missing')
    pane:SelectContent('rotation')

    for _, control in ipairs({ pane.apply, pane.discard, pane.delete }) do
        assert(not control:IsEnabled(), 'a write control is live in the preview')
    end

    for _, card in ipairs(pane.canvas.cards) do
        if card.model and card.frame:IsShown() and card.controls.remove then
            assert(not card.controls.remove:IsEnabled(), 'a card can be removed in the preview')
        end
    end

    assert(pane.canvas:CanSelect() == false, 'preview cards can be selected')
end)

test(
    'opening, browsing and closing the full view leaves the saved variables, the candidate and the transfer rotation unchanged',
    function()
        local _, a, _, body = fixture()
        local d = a:ShowRotationTransfer(0, reference(a))
        d.destination:Click()
        paste(d, 'incoming')
        local before = { profile = a.db.profile, global = a.db.global, char = a.db.char }
        local copy = clone(a.db.profile)
        local copyGlobal = clone(a.db.global or {})
        local copyChar = clone(a.db.char or {})
        local saved = a.RotationData.CopyData(body)
        d.preview:Click()
        local view = a.rotationTransferForm.importContent
        local pane = view.pane
        -- Poke every header control a reader might touch.
        pane.name:SetText('Renamed')

        if pane.name.scripts.OnTextChanged then
            pane.name.scripts.OnTextChanged(pane.name, true)
        end

        pane.priority:SetText('99')

        if pane.priority.scripts.OnTextChanged then
            pane.priority.scripts.OnTextChanged(pane.priority, true)
        end

        pane.priorityUp:Click()
        pane.priorityDown:Click()
        pane.enable:Click()
        pane.overrideReset:Click()
        pane.priority.scripts.OnEnterPressed(pane.priority)
        pane.priority.scripts.OnEditFocusLost(pane.priority)
        pane.apply:Click()
        pane.discard:Click()
        pane.delete:Click()
        pane.info:Click()
        pane:SelectContent('cooldowns')
        pane:SelectContent('rotation')
        pane.viewMode:Click()
        pane.viewMode:Click()
        local snapshot = pane.workspace:Snapshot()
        assert(snapshot.name == 'Incoming' and snapshot.priority == 7, 'the preview was edited')
        view.close:Click()
        assert(not view.frame:IsShown() and not view.pane and not view.workspace, 'close did not release the view')

        assert(
            before.profile == a.db.profile
                and same(copy, a.db.profile)
                and same(copyGlobal, a.db.global or {})
                and same(copyChar, a.db.char or {}),
            'saved variables changed: ' .. table.concat(diff(copy, a.db.profile), '; ')
        )

        assert(
            same(saved, body) and same(
                saved,
                a:GetRotationRecordSnapshot(0, a:ResolveRotationReference(0, 'mine')).body
            ),
            'the selected rotation changed'
        )

        -- Reopen: a fresh private copy, not the closed one.
        d.preview:Click()
        assert(a.rotationTransferForm.importContent.pane.workspace:Snapshot().name == 'Incoming')
        -- What the preview showed is exactly what Import saves: nothing the reader poked reached the candidate.
        a.rotationTransferForm.importContent.close:Click()
        d.name:SetText('Saved copy')
        d.name.scripts.OnTextChanged(d.name, true)
        d.apply:Click()
        local saved

        for id, record in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do
            if record.body.name == 'Saved copy' then
                saved = record.body
            end
        end

        assert(
            saved
                and saved.priority == 7
                and saved.description == 'What it does'
                and saved.rotation[1].onTrue[1].action == 974,
            'the imported copy is not what was previewed'
        )
    end
)

test('the full view does not run the incoming conditions against the game and is not the active editor', function()
    local _, a = fixture()
    local live = 0

    a.evaluateConditionResult = function()
        live = live + 1
        return { status = 'match' }
    end

    a.SwitchConditionMatchesNow = function()
        live = live + 1
        return true
    end

    a.ScheduleRepeatingTimer = function()
        live = live + 1
        return {}
    end

    a.db.profile.live_config_update = 1
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'incoming')
    d.preview:Click()
    local pane = a.rotationTransferForm.importContent.pane

    assert(
        live == 0 and not pane.liveTimer and a.activeRotationEditor ~= pane and a.liveStatusLastPane ~= pane,
        'preview evaluated or registered as the live editor'
    )

    pane:RefreshLiveStatus()
    assert(live == 0)
end)

test('the metadata and condition views of a preview are read-only and say it is an import', function()
    local _, a = fixture()
    local captured

    function a:ShowConditionEditor(_, _, condition, callback, valid, options)
        captured = { condition = condition, callback = callback, valid = valid, options = options }
    end

    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'incoming')
    d.preview:Click()
    local pane = a.rotationTransferForm.importContent.pane
    pane.switch:Click()
    assert(captured and captured.options.readOnly == true, 'switch condition not read-only')
    captured.callback(true)
    assert(pane.workspace:Snapshot().switch.type == nil, 'a read-only callback edited the preview')
    local ids = cardIds(pane)
    assert(ids.yes)
    local card

    for _, c in ipairs(pane.canvas.cards) do
        if c.model and c.model.id == 'yes' and c.frame:IsShown() then
            card = c
        end
    end

    captured = nil

    if card and card.condition then
        card.condition:Click()
        assert(captured and captured.options.readOnly == true and captured.valid(), 'step condition not read-only')
    end

    pane.info:Click()
    assert(pane.metadataWindow.frame:IsShown() and not pane.metadataWindow.apply:IsEnabled())

    assert(pane.metadataWindow.note:GetText():find('Import preview', 1, true), tostring(
        pane.metadataWindow.note:GetText()
    ))

    assert(pane.readOnlyPill.tooltip:find('incoming rotation', 1, true))
end)

test('an envelope import shows its own tags and applicability like a pack would', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'envelope')
    d.preview:Click()
    local pane = a.rotationTransferForm.importContent.pane

    assert(
        pane.workspace:Snapshot().name == 'Packaged' and table.concat(pane:EffectiveTags(), ',') == 'leveling',
        'manifest tags missing: ' .. table.concat(pane:EffectiveTags(), ',')
    )

    assert(d.apply:IsEnabled())
end)

test('changing the text, toggling the destination or closing the transfer retires every open view', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    local p = a.rotationTransferForm
    paste(d, 'incoming')
    d.preview:Click()
    assert(p.importPreview.frame:IsShown())
    d.destination:Click()
    assert(not p.importPreview.frame:IsShown(), 'a comparison stayed open after switching to a new copy')
    d.preview:Click()
    assert(p.importContent.frame:IsShown())
    d.destination:Click()

    assert(
        not p.importContent.frame:IsShown() and not p.importContent.pane,
        'the preview stayed open after switching to replace'
    )

    d.destination:Click()
    d.preview:Click()
    assert(p.importContent.frame:IsShown() and d.apply:IsEnabled())
    paste(d, 'incoming')

    assert(
        not p.importContent.frame:IsShown() and not d.apply:IsEnabled() and d.status:GetText():find(
            'Preview again',
            1,
            true
        ),
        tostring(d.status:GetText())
    )

    d.destination:Click()
    paste(d, 'incoming')
    assert(d.status:GetText():find('Compare again', 1, true), tostring(d.status:GetText()))
    d.destination:Click()
    d.preview:Click()
    assert(p.importContent.frame:IsShown())
    d.cancel:Click()

    assert(
        not d.frame:IsShown() and not p.importContent.frame:IsShown() and not p.importContent.pane,
        'closing the transfer left the preview open'
    )
end)

test('invalid text gives no view, no Import and says why', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'bad')
    d.preview:Click()
    local p = a.rotationTransferForm

    assert(
        not p.importContent and not d.apply:IsEnabled() and not d.inspect:IsEnabled(),
        'invalid text produced a view or an enabled button'
    )

    assert(d.status:GetText():find('unavailable', 1, true), tostring(d.status:GetText()))
    paste(d, 'scalar')
    d.preview:Click()
    assert(not d.apply:IsEnabled())
    assert(not p.importContent or not p.importContent.frame:IsShown(), 'scalar text produced a view')
end)

test('unsupported data blocks Import, still shows what it can, and Check import explains it', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    paste(d, 'future')
    d.preview:Click()
    assert(not d.apply:IsEnabled(), 'unsupported data can be imported')
    assert(d.status:GetText():find('cannot be applied', 1, true), tostring(d.status:GetText()))
    assert(d.inspect:IsEnabled())
    local details = d.inspect.scripts.OnClick()
    assert(details:find('futureMetadata', 1, true), 'diagnostics do not name the unsupported data')
end)

test('a body that cannot be shown in full points to Check import and keeps Import off', function()
    local f, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    local create = a.CreateRotationEditor

    a.CreateRotationEditor = function()
        error('injected editor failure')
    end

    paste(d, 'incoming')
    d.preview:Click()

    assert(
        d.status:GetText():find('Check import', 1, true) and d.status:GetText():find('Ready to import', 1, true),
        tostring(d.status:GetText())
    )

    assert(d.apply:IsEnabled(), 'a view failure must not change whether the import is ready')
    a.CreateRotationEditor = create
end)

test('Import after a new-copy preview saves a copy and the preview never saved anything', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    d.destination:Click()
    local rows = 0

    for _ in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do
        rows = rows + 1
    end

    paste(d, 'incoming')
    d.preview:Click()
    local after = 0

    for _ in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do
        after = after + 1
    end

    assert(rows == after, 'the preview saved a rotation')
    d.name:SetText('Imported copy')
    d.name.scripts.OnTextChanged(d.name, true)
    d.apply:Click()
    local count = 0

    for _ in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do
        count = count + 1
    end

    assert(count == rows + 1 and not d.frame:IsShown(), 'Import did not add exactly one rotation')
end)

test('the new-copy preview and the replace comparison work on every supported client', function()
    for _, product in ipairs({ 1, 2, 5, 11, 14, 19 }) do
        local _, a = fixture(product)
        local compared = counts(a)
        local d = a:ShowRotationTransfer(0, reference(a))
        assert(d.preview:GetText() == 'Compare import', product)
        paste(d, 'incoming')
        d.preview:Click()
        assert(compared() == 1 and not a.rotationTransferForm.importContent, product)
        d.destination:Click()
        assert(d.preview:GetText() == 'Preview import', product)
        d.preview:Click()
        local view = a.rotationTransferForm.importContent

        assert(
            view
                and view.frame:IsShown()
                and cardIds(view.pane).yes
                and view.pane.workspace:Snapshot().name == 'Incoming',
            'client ' .. product
        )
    end
end)

test('the detached workspace refuses every write and is not listed anywhere', function()
    local _, a, data = fixture()

    local workspace = assert(a:NewRotationPreviewWorkspace(0, {
        kind = 'legacy',
        body = { name = 'X', switch = {}, rotation = { { type = 'stop', conditions = {} } }, cooldowns = {} },
    }))

    assert(workspace.readOnly and workspace.preview and not workspace:IsDirty())

    assert(
        workspace:Command('SetBodyField', 'name', 'Y') == nil
            and workspace:Apply() == nil
            and workspace:Discard() == nil
    )

    assert(workspace:Snapshot().name == 'X' and workspace:Snapshot().rotation[1].id, 'ids are generated in the copy')
    assert(a:GetRotationWorkspace(0, 'import-preview') == nil, 'the preview workspace is reachable by reference')
    local target = workspace:ConditionEditorTarget({ kind = 'switch' })
    assert(target.readOnly and target.commit() == nil)
    workspace:Close()
    assert(not workspace:ValidTarget() and not target.valid())
    assert(a:NewRotationPreviewWorkspace(0, {}) == nil and a:NewRotationPreviewWorkspace('x', { body = {} }) == nil)

    local session = data.NewImportSession(
        { Decode = function() return { kind = 'legacy', original = 't', value = { name = 'A' } } end },
        {}
    )

    local candidate = session:Stage('t')
    assert(session:Preview(candidate.token).body.name == 'A')
    session:Clear()
    local gone, why = session:Preview(candidate.token)
    assert(gone == nil and why == 'stale-import')
end)

-- The bottom row of the import window (Copy, Clear, Compare/Preview, Check, Import, Cancel) in every locale. The
-- review buttons grow with their label, and the window grows with them, so Import is never covered. Two width models:
-- the fixture's own (7 per byte, which over-measures accents and CJK) and a per-character one close to the 10 px game
-- font (5 for Latin, 6 for Cyrillic, 10 for CJK and Hangul).
local audit = dofile('tests/fixtures/layout_audit.lua')
local LOCALES = {'enUS', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}

local function perCharacter(text)
    local width = 0

    for char in (text or ''):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        local byte = char:byte()

        if byte < 0xD0 then
            width = width + 5
        elseif byte < 0xE0 then
            width = width + 6
        else
            width = width + 10
        end
    end

    return width
end

local function openWithLocale(name, model)
    local f, a = fixture()
    f.language(name)

    if model then
        local make = a.CreateWorkbenchButton

        a.CreateWorkbenchButton = function(...)
            local button = make(...)
            local get = button.GetFontString

            button.GetFontString = function(self)
                local fs = get(self)
                fs.GetStringWidth = function(this) return model(this.text) end
                return fs
            end

            return button
        end
    end

    return a, a:ShowRotationTransfer(0, reference(a))
end

local function assertRow(name, label, d, model)
    local resolve = audit.resolver(d.frame)

    local function rect(button)
        return assert(resolve(button), name .. ' ' .. label .. ': a bottom-row button has no resolved rectangle')
    end

    local order = { d.copy, d.clear, d.preview, d.inspect, d.apply, d.cancel }
    local frameWidth = d.frame:GetWidth()

    for index, button in ipairs(order) do
        local r = rect(button)

        assert(r.left >= 0 and r.right <= frameWidth, string.format(
            '%s %s: button %d leaves the window (%g..%g of %g)',
            name,
            label,
            index,
            r.left,
            r.right,
            frameWidth
        ))

        if index > 1 then
            local previous = rect(order[index - 1])

            assert(previous.right + 4 <= r.left, string.format(
                '%s %s: button %d (%g..%g) overlaps or touches button %d (%g..%g)',
                name,
                label,
                index,
                r.left,
                r.right,
                index - 1,
                previous.left,
                previous.right
            ))
        end
    end

    for _, button in ipairs({ d.preview, d.inspect }) do
        local need = model and model(button:GetText()) or #button:GetText() * 7

        assert(
            rect(button).right - rect(button).left >= need,
            name .. ' ' .. label .. ': a review button is narrower than its label'
        )
    end

    assert(
        d.scroll:GetWidth() <= frameWidth - 12 and d.status:GetWidth() <= frameWidth,
        name .. ' ' .. label .. ': the text box or status line was not resized with the window'
    )
end

test(
    'the import window keeps its bottom row apart in all 11 locales, in Compare and Preview modes, under both width models',
    function()
        for _, name in ipairs(LOCALES) do
            for _, modelName in ipairs({ 'fixture', 'character' }) do
                local model = modelName == 'character' and perCharacter or nil
                local _, d = openWithLocale(name, model)
                assert(d.mode == 'replace')
                assertRow(name, modelName .. '/compare', d, model)
                d.destination:Click()
                assert(d.mode == 'new')
                assertRow(name, modelName .. '/preview', d, model)

                if name == 'enUS' and model then
                    assert(d.frame:GetWidth() == 570, 'the common English window grew beyond its default width')
                end
            end
        end
    end
)

test('the window returns to its default width for a transfer without review buttons', function()
    local _, a = fixture()
    local d = a:ShowRotationTransfer(0, reference(a))
    local wide = d.frame:GetWidth()
    local p = a.rotationTransferForm
    assert(p and p.textDialog == d)
    a:ShowSettingsTextTransfer(p, 'Plain', 'text', function() return true end)

    assert(
        d.frame:GetWidth() == 570 and d.input:GetWidth() == 510 and d.scroll:GetWidth() == 520,
        'a plain box kept the widened size of the review window: ' .. d.frame:GetWidth() .. ' after ' .. wide
    )
end)

finish()
