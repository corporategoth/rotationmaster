-- The Format choice of the rotation import/export window (UI/transfer.lua, UI/transfer_format.lua,
-- Core/transfer_formats.lua): shown only for rotations; Rotation Master is the default; the export box shows
-- WowSims JSON with its warning and a report; pasted WowSims JSON is converted first and then goes through the
-- ordinary Preview / Compare / Check import flow, which stays gated exactly as before; the choice is remembered; the
-- converter is not loaded until it is wanted; every client that has a simulator works, Retail says why it cannot.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local W = dofile('tests/fixtures/wowsims.lua')
local test, finish = F.suite()

local nsForData = W.loadModule()
local PERMISSIVE = W.permissiveConditions(nsForData)
local EXPORT_TEXT = 'export-text'

local function fixture(product, expansion)
    local f = F.new(product, expansion)
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.nativeFrames = frames
    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    local data, envelope = make()
    a.RotationData = data
    a.conditionDefinitions = PERMISSIVE
    a.db.keys = {char = 'A - Realm'}
    local n = 0
    a.uuid = function() n = n + 1; return 'preview-' .. n end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch = function() end; a.SwitchRotation = function() end; a.EvaluateNextAction = function() end
    for _, path in ipairs({'Platform/spells.lua', 'Platform/items.lua', 'Data/catalog.lua', 'Data/diff.lua', 'Data/visual_comparison.lua', 'Data/import_session.lua',
        'Data/rotation_store.lua', 'Data/rotation_draft.lua', 'Core/rotation_library.lua', 'Core/rotation_scope.lua', 'Core/imports.lua',
        'Core/condition_support.lua', 'Core/transfer_formats.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua', 'Core/rotation_tags.lua',
        'Core/rotation_canvas.lua', 'UI/window.lua', 'UI/settings_layout.lua', 'UI/settings_roster_order.lua', 'UI/settings_draft.lua',
        'UI/settings_history.lua', 'UI/settings_ordered.lua', 'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/rotation_reference.lua',
        'UI/rotation_comparison.lua', 'UI/transfer.lua', 'UI/transfer_format.lua'}) do f.load(path) end
    for _, file in ipairs({'UI/rotation_cards.lua', 'UI/rotation_canvas.lua', 'UI/color_picker.lua', 'UI/rotation_effect_fields.lua', 'UI/rotation_fields.lua',
        'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua', 'UI/rotation_editor.lua', 'UI/unsaved.lua',
        'UI/draft_change_controls.lua', 'UI/help.lua'}) do local h = io.open(file); if h then h:close(); f.load(file) end end
    -- The game's own condition-support answers, on this simulated client.
    local api = dofile('tests/fixtures/client_api.lua')
    local client = api.byProject[product or 5] or 'mists'
    local requirements = a.conditionRequirements
    W.stubApis(f.env, requirements, api.absent(client, client ~= 'retail' and client ~= 'forever'))
    local body = envelope().body
    body.rotation = {
        {id = 'a', type = 'spell', action = 403, conditions = {type = 'SPELL_KNOWN', spell = 403}},
        {id = 'b', type = 'spell', action = 324, conditions = {type = 'BUFF', unit = 'player', spell = 324}},
    }
    body.cooldowns = {{id = 'c', type = 'spell', action = 8042, conditions = {}}}
    a.db.profile = {rotationFallbackID = 'Default', rotationStore = {version = 1, classes = {SHAMAN = {[0] = {mine = {body = body}}}}, characters = {}, legacy = {}}}
    a.GetRotationContext = function(_, spec) return {class = 'SHAMAN', family = a.Platform:GetClientFamily(), spec = spec, actionContext = 'player', combatDataPolicy = 'probe'} end
    assert(a:BindRotationProfile())
    a.GetEditableRotation = function() error('ordinary transfer used mutable getter') end
    -- The Rotation Master codec is a stand-in: only the text it would export and the one text it accepts matter here.
    local incoming = data.CopyData(body)
    incoming.name = 'Incoming'
    a.NewRotationCodec = function()
        return {Encode = function() return EXPORT_TEXT end, Decode = function(_, text)
            if text == 'incoming' then return {kind = 'legacy', original = text, value = data.CopyData(incoming)} end
            return nil, 'invalid-base64'
        end}
    end
    function a:GetImportValidationOptions()
        return {conditions = a.conditionDefinitions, support = function(tag, definition, value) return a:GetConditionSupport(tag, definition, value) end}
    end
    a.ShowComparisonReport = function(_, text) return text end
    a.printCondition = function() return 'Readable conditions' end
    a.ShowConfig = function() end
    local loads = 0
    a.transferFormatLoader = function(name)
        assert(name == 'RotationMaster_WowSims', name)
        loads = loads + 1
        local ns = {}
        for _, file in ipairs({'json', 'mapping', 'ids', 'import', 'export', 'render', 'api'}) do
            local chunk = assert(loadfile('Modules/RotationMaster_WowSims/' .. file .. '.lua'))
            setfenv(chunk, f.env)
            chunk(name, ns)
        end
        return true
    end
    return f, a, function() return loads end, data, body
end

local function paste(d, text) d.input:SetText(text); d.input.scripts.OnTextChanged(d.input, true) end
local function same(x, y, seen)
    if type(x) ~= type(y) then return false end
    if type(x) == 'function' or type(x) == 'userdata' then return true end
    if type(x) ~= 'table' then return x == y end
    seen = seen or {}
    if seen[x] then return true end
    seen[x] = true
    for k, v in pairs(x) do if not same(v, y[k], seen) then return false end end
    for k in pairs(y) do if x[k] == nil then return false end end
    return true
end
local function clone(x)
    if type(x) ~= 'table' then return x end
    local out = {}
    for k, v in pairs(x) do out[k] = clone(v) end
    return out
end
local function fixtureText(name) return W.read(W.dir .. name) end
local function countRotations(a)
    local count = 0
    for _ in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do count = count + 1 end
    return count
end
local function reports(a)
    local shown = {}
    a.ShowTransferReport = function(_, title, text) shown[#shown + 1] = {title = title, text = text}; return {} end
    return shown
end
local NO_APL = 'This export contains no rotation to import. In WowSims, open the Rotation tab, choose an APL (or a preset), then export again.'
local JSONREADER = nsForData.json
local function decodeJson(text) local r = JSONREADER.parse(text, W.BIG); assert(r.ok, tostring(r.error and r.error.code)); return r.value end

-- ---- the choice ------------------------------------------------------------------------------------------------
test('the rotation window has a Format choice that starts at Rotation Master, and no other kind of transfer has one', function()
    local f, a, loads = fixture(2)
    local d = a:ShowRotationTransfer(0, 'mine')
    local c = d.formatControls
    assert(c and c.button:GetText() == 'Rotation Master' and c.label:GetText() == 'Format' and c.button:IsEnabled())
    assert(d.input:GetText() == EXPORT_TEXT and not c.note:IsShown() and not c.check:IsShown(), 'nothing of WowSims shows by default')
    assert(loads() == 0, 'the converter is not loaded by merely opening the window')
    local entries
    c.button.scripts.OnClick(c.button)
    assert(c.menu.frame:IsShown(), 'the menu opens')
    entries = c.menu.entries
    assert(#entries == 2 and entries[1].text == 'Rotation Master' and entries[1].value == 'rm' and entries[2].text == 'WowSims' and entries[2].value == 'wowsims' and not entries[2].disabled)
    c.menu:Hide()
    -- Other kinds of transfer (here an item set / settings window) show no such control.
    local parent = f.env.CreateFrame('Frame')
    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)
    local other = a:ShowSettingsTextTransfer(p, 'Items', 'text', function() return true end)
    assert(other.formatControls == nil, 'a transfer that is not a rotation has no Format choice')
    local withOptions = a:ShowSettingsTextTransfer(p, 'Items', 'text', function() return true end, {canReplace = false, fallbackName = 'Copy', originalName = function() return 'x' end})
    assert(withOptions.formatControls == nil)
end)
test('choosing WowSims writes the rotation as WowSims JSON with a warning and a report; Rotation Master brings the export back', function()
    local _, a, loads = fixture(2)
    local shown = reports(a)
    local d = a:ShowRotationTransfer(0, 'mine')
    local c = d.formatControls
    c.Choose('wowsims')
    assert(loads() == 1 and c.button:GetText() == 'WowSims' and a.db.profile.transfer_format == 'wowsims')
    local text = d.input:GetText()
    local value = decodeJson(text)
    assert(value.player.class == 'ClassShaman' and value.player.rotation.type == 'TypeAPL' and #value.player.rotation.priorityList == 3, text:sub(1, 200))
    assert(text:sub(-1) == '\n' and text:find('\n  "player": {', 1, true), 'two-space JSON')
    for line in text:gmatch('[^\n]+') do assert(not line:find('^RM1:'), line) end
    assert(c.note:IsShown() and c.note:GetText() == 'Some detail may be lost converting to WowSims.', tostring(c.note:GetText()))
    assert(c.check:IsShown() and c.check:IsEnabled())
    c.check.scripts.OnClick(c.check)
    assert(#shown == 1 and shown[1].title == 'WowSims export report' and shown[1].text:find('Converted for SHAMAN on Classic Era', 1, true) and shown[1].text:find('Steps:', 1, true), tostring(shown[1] and shown[1].text))
    assert(d.status:GetText():find('paste WowSims JSON here to import it', 1, true))
    -- The Cooldowns list comes first: Earth Shock (cooldown), then the two steps.
    local list = value.player.rotation.priorityList
    assert(list[1].action.castSpell.spellId.spellId == 10414 and list[1].action.castSpell.spellId.rank == 7 and list[1].notes:find('cooldown', 1, true), 'cooldowns first, at the highest rank')
    -- Back to Rotation Master.
    c.Choose('rm')
    assert(d.input:GetText() == EXPORT_TEXT and a.db.profile.transfer_format == 'rm' and not c.note:IsShown() and not c.check:IsShown())
    assert(loads() == 1, 'loaded once')
end)
test('the choice is remembered in the profile: the window opens in it, and it reaches the converter only when wanted', function()
    local _, a, loads = fixture(5)
    a.db.profile.transfer_format = 'wowsims'
    local d = a:ShowRotationTransfer(0, 'mine')
    assert(d.formatControls.button:GetText() == 'WowSims' and loads() == 1, 'a remembered WowSims is loaded when the window opens')
    assert(decodeJson(d.input:GetText()).player.rotation.type == 'TypeAPL')
    assert(d.formatControls.note:GetText() == 'Some detail may be lost converting to WowSims.')
    d.cancel:Click()
    d = a:ShowRotationTransfer(0, 'mine')
    assert(d.formatControls.button:GetText() == 'WowSims' and loads() == 1, 'the converter is loaded once per session')
    d.formatControls.Choose('rm')
    assert(a.db.profile.transfer_format == 'rm')
    d = a:ShowRotationTransfer(0, 'mine')
    assert(d.formatControls.button:GetText() == 'Rotation Master' and d.input:GetText() == EXPORT_TEXT)
    a.db.profile.transfer_format = 'nonsense'
    assert(a:GetTransferFormat() == 'rm', 'a value that is not a format is read as the default')
end)

test('the remembered format is a profile setting that travels with the profile and is checked', function()
    if not pcall(require, 'bit') then return end    -- the codec fixture needs LuaJIT's bit library
    local f = F.new(5)
    local a = f.addon
    local data = dofile('tests/fixtures/codec.lua')()
    a.RotationData = data
    f.load('Core/profile_data.lua')
    for _, ok in ipairs({'rm', 'wowsims'}) do assert(a:ValidateProfileTransfer({transfer_format = ok}), ok) end
    for _, bad in ipairs({'sims', '', 5, true, {}}) do assert(not a:ValidateProfileTransfer({transfer_format = bad}), tostring(bad)) end
    assert(a:ProfileFromPortable(a:ProfileToPortable({transfer_format = 'wowsims'})).transfer_format == 'wowsims')
    local main = W.read('main.lua')
    assert(main:find('transfer_format = "rm"', 1, true), 'the default is Rotation Master')
end)

test('an export that does not fit the box is shown compact, or said not to fit; it is never cut', function()
    local _, a = fixture(2)
    local source = a:GetRotationExportData(0, 'mine')
    local converted = assert(a:ConvertRotationToFormat('wowsims', source, 0))
    local pretty, compact = #converted.text, #converted.compactText
    assert(compact < pretty and not converted.compactText:sub(1, -2):find('\n'), 'a compact form exists')
    local d = a:ShowRotationTransfer(0, 'mine')
    d.input:SetMaxLetters(pretty - 1)
    d.formatControls.Choose('wowsims')
    assert(d.input:GetText() == converted.compactText and decodeJson(d.input:GetText()).player.rotation.type == 'TypeAPL', 'the compact JSON is shown whole')
    d.formatControls.Choose('rm')
    d.input:SetMaxLetters(compact - 1)
    d.formatControls.Choose('wowsims')
    assert(d.input:GetText() == EXPORT_TEXT and d.formatControls.button:GetText() == 'Rotation Master', 'nothing cut is shown')
    assert(d.status:GetText():find('is too long for this box (' .. pretty .. ' characters)', 1, true), tostring(d.status:GetText()))
    d.input:SetMaxLetters(pretty + 10)
    d.formatControls.Choose('wowsims')
    assert(d.input:GetText() == converted.text, 'the pretty JSON when it fits')
end)
test('if the Format row cannot be built, the window is the Rotation Master window and says so', function()
    local _, a = fixture(5)
    a.AttachTransferFormatControls = function() error('no widgets today') end
    local d = a:ShowRotationTransfer(0, 'mine')
    assert(d.status:GetText():find('The Format choice could not be shown: ', 1, true) and d.status:GetText():find('no widgets today', 1, true), tostring(d.status:GetText()))
    assert(d.input:GetText() == EXPORT_TEXT)
    paste(d, 'incoming'); d.preview:Click()
    assert(d.apply:IsEnabled(), 'Rotation Master imports keep working')
end)

-- ---- importing ---------------------------------------------------------------------------------------------------
test('pasted WowSims JSON is converted, then previewed, compared and imported like any other import', function()
    local _, a = fixture(2)
    local shown = reports(a)
    local compared = 0
    local native = a.ShowNativeImportPreview
    a.ShowNativeImportPreview = function(...) compared = compared + 1; return native(...) end
    local d = a:ShowRotationTransfer(0, 'mine')
    d.formatControls.Choose('wowsims')
    local before = clone(a.db.profile)
    paste(d, fixtureText('era_ele.apl.json'))
    assert(d.formatControls.note:GetText() == 'Some detail may be lost converting from WowSims.', tostring(d.formatControls.note:GetText()))
    assert(d.original:GetText():find('WowSims import: SHAMAN', 1, true), tostring(d.original:GetText()))
    assert(not d.apply:IsEnabled(), 'nothing is importable before a preview')
    d.preview:Click()
    assert(d.preview:GetText() == 'Compare import' and compared == 1 and a.rotationTransferForm.importPreview.frame:IsShown(), 'replace mode compares')
    assert(d.apply:IsEnabled() and d.inspect:IsEnabled())
    assert(d.status:GetText():find('Ready to import', 1, true) and d.status:GetText():find('Converted from WowSims: 8 steps, 3 disabled', 1, true), tostring(d.status:GetText()))
    d.inspect:Click()
    assert(#shown == 1 and shown[1].title == 'WowSims import report' and shown[1].text:find('Items in the rotation: 9 (6 exact, 3 approximate, 0 lossy, 0 not representable).', 1, true), tostring(shown[1] and shown[1].text))
    assert(same(before, a.db.profile) and countRotations(a) == 1, 'previewing and checking saved nothing: ' .. tostring(countRotations(a)))
    -- A new copy shows the converted rotation in the read-only editor view.
    d.destination:Click()
    assert(d.mode == 'new' and d.preview:GetText() == 'Preview import')
    d.preview:Click()
    local view = a.rotationTransferForm.importContent
    assert(view and view.frame:IsShown() and view.workspace.preview and #view.workspace:Snapshot().rotation == 8, 'the preview holds the 8 converted steps')
    assert(view.workspace:Snapshot().name:find('WowSims import', 1, true))
    view.close:Click()
    assert(same(before, a.db.profile))
    d.name:SetText('From the simulator')
    d.name.scripts.OnTextChanged(d.name, true)
    d.apply:Click()
    assert(countRotations(a) == 2 and not d.frame:IsShown(), 'Import adds exactly one rotation')
    local saved
    for _, record in pairs(a.db.profile.rotationStore.classes.SHAMAN[0]) do if record.body.name == 'From the simulator' then saved = record.body end end
    assert(saved and #saved.rotation == 8 and saved.tags[1] == 'wowsims')
    local disabled = 0
    for _, step in ipairs(saved.rotation) do if step.disabled then disabled = disabled + 1 end end
    assert(disabled == 3, 'the steps that were not an exact copy are imported disabled: ' .. disabled)
    assert(same(a.db.profile.rotationStore.classes.SHAMAN[0].mine.body.rotation, before.rotationStore.classes.SHAMAN[0].mine.body.rotation), 'the selected rotation is untouched')
end)
test('text with no rotation, blank text and hostile text give a message and leave Import off', function()
    local _, a = fixture(5)
    local d = a:ShowRotationTransfer(0, 'mine')
    d.formatControls.Choose('wowsims')
    for _, text in ipairs({'{"player":{"class":"ClassShaman","rotation":{"type":"TypeAuto"}}}', '{"type":"TypeAuto"}'}) do
        paste(d, text); d.preview:Click()
        assert(not d.apply:IsEnabled() and d.status:GetText():find(NO_APL, 1, true), tostring(d.status:GetText()))
    end
    paste(d, '{"player":{"class":"ClassMage","rotation":{"type":"TypeSimple"}}}'); d.preview:Click()
    assert(d.status:GetText():find('Simple rotation', 1, true) and not d.apply:IsEnabled())
    paste(d, '   '); d.preview:Click()
    assert(d.status:GetText():find('Paste a WowSims rotation first.', 1, true), tostring(d.status:GetText()))
    for _, hostile in ipairs({string.rep('[', 5000), '{"__proto__":{"x":1}}', '{"a":' .. string.rep('9', 400) .. '}', string.rep('{"a":', 100) .. '1' .. string.rep('}', 100),
        '[' .. string.rep('"x",', 30000) .. '1]', 'https://www.wowsims.com/classic/ele/#abc', 'not json at all', '\255\254\0\1', '{"player":{"rotation":[1,2,3]}}'}) do
        local ok, err = pcall(function() paste(d, hostile); d.preview:Click() end)
        assert(ok, 'raised on hostile text: ' .. tostring(err))
        assert(not d.apply:IsEnabled(), 'hostile text enabled Import')
        assert(d.status:GetText() and d.status:GetText() ~= '', 'no message for hostile text')
    end
end)
test('a rotation for another class or for another game version is refused with the reason', function()
    local _, a = fixture(2)
    local d = a:ShowRotationTransfer(0, 'mine')
    d.formatControls.Choose('wowsims')
    paste(d, fixtureText('era_mage_p1.apl.json')); d.preview:Click()
    assert(not d.apply:IsEnabled() and d.status:GetText():find('spells look like MAGE', 1, true), tostring(d.status:GetText()))
    paste(d, '{"player":{"class":"ClassMage","rotation":{"type":"TypeAPL","priorityList":[{"action":{"castSpell":{"spellId":{"spellId":10150}}}}]}}}'); d.preview:Click()
    assert(d.status:GetText():find('The file is for MAGE, but this character is SHAMAN.', 1, true), tostring(d.status:GetText()))
    -- A Wrath client given a Classic Era file (it carries spell ranks, which Wrath does not have).
    local _, wrath = fixture(11, 2)
    local w = wrath:ShowRotationTransfer(0, 'mine')
    w.formatControls.Choose('wowsims')
    paste(w, fixtureText('era_ele.apl.json')); w.preview:Click()
    assert(not w.apply:IsEnabled() and w.status:GetText():find('The file cannot be for Classic Progression', 1, true) and w.status:GetText():find('Classic Era', 1, true), tostring(w.status:GetText()))
end)
test('switching the Format with text pasted keeps the text, drops the staged import and reads it again in the new format', function()
    local _, a = fixture(2)
    local d = a:ShowRotationTransfer(0, 'mine')
    local c = d.formatControls
    c.Choose('wowsims')
    local json = fixtureText('era_ele.apl.json')
    paste(d, json); d.preview:Click()
    assert(d.apply:IsEnabled())
    c.Choose('rm')
    assert(d.input:GetText() == json, 'the pasted text stays')
    assert(not d.apply:IsEnabled() and d.status:GetText() == 'Format changed. Preview the pasted text again before importing.', tostring(d.status:GetText()))
    d.preview:Click()
    assert(not d.apply:IsEnabled() and d.status:GetText():find('This looks like WowSims JSON. Set Format to WowSims to import it.', 1, true), tostring(d.status:GetText()))
    c.Choose('wowsims')
    paste(d, 'incoming'); d.preview:Click()
    assert(not d.apply:IsEnabled())
    paste(d, 'RM1:abcdef'); d.preview:Click()
    assert(d.status:GetText():find('This looks like a Rotation Master export. Set Format to Rotation Master to import it.', 1, true), tostring(d.status:GetText()))
    c.Choose('rm')
    paste(d, 'incoming'); d.preview:Click()
    assert(d.apply:IsEnabled(), 'Rotation Master text imports in the Rotation Master format as before')
    -- Clearing the box and choosing again gives the export of the chosen format.
    d.clear:Click()
    c.Choose('wowsims')
    assert(decodeJson(d.input:GetText()).player.rotation.type == 'TypeAPL')
end)
test('the converted rotation goes through the existing validators: a condition the game\'s schema refuses keeps Import off', function()
    local _, a = fixture(2)
    a.conditionDefinitions = clone(PERMISSIVE)
    a.conditionDefinitions.BUFF.fields.unit = 'number'   -- the game's schema says a unit is a number: the converter's 'player' is refused
    local d = a:ShowRotationTransfer(0, 'mine')
    d.formatControls.Choose('wowsims')
    paste(d, fixtureText('era_ele.apl.json')); d.preview:Click()
    assert(not d.apply:IsEnabled(), 'an import the validators call invalid was enabled')
    assert(d.status:GetText():find('cannot be applied', 1, true), tostring(d.status:GetText()))
    local _, b = fixture(2)
    b.conditionDefinitions = clone(PERMISSIVE)
    b.conditionDefinitions.BUFF = nil     -- a condition the game does not have: the step is imported disabled and says so, the import is not blocked
    local shown = reports(b)
    local e = b:ShowRotationTransfer(0, 'mine')
    e.formatControls.Choose('wowsims')
    paste(e, fixtureText('era_ele.apl.json')); e.preview:Click()
    assert(e.apply:IsEnabled(), tostring(e.status:GetText()))
    e.inspect:Click()
    assert(shown[1].text:find('BUFF is not available on this client (Rotation Master has no such condition)', 1, true), shown[1].text)
end)

-- ---- clients --------------------------------------------------------------------------------------------------------
local CLIENTS = {
    {name = 'Classic Era', product = 2, expansion = 0, file = 'era_ele.apl.json', edition = 'era'},
    {name = 'TBC', product = 5, expansion = 1, file = 'tbcnew_ele.apl.json', edition = 'tbc'},
    {name = 'Wrath', product = 11, expansion = 2, file = 'wotlk_ele_default.apl.json', edition = 'progression'},
    {name = 'Cataclysm', product = 14, expansion = 3, file = 'cata_shaman_elemental_default.apl.json', edition = 'progression'},
    {name = 'Mists', product = 19, expansion = 4, file = 'mop_ele.apl.json', edition = 'progression'},
    {name = 'Forever', product = 18, expansion = 0, file = 'forever_shaman_enhancement_default.apl.json', edition = 'forever'},
}
test('the Format choice works on every client that has a simulator: export, then a pasted WowSims rotation previews and imports', function()
    for _, client in ipairs(CLIENTS) do
        local _, a = fixture(client.product, client.expansion)
        local d = a:ShowRotationTransfer(0, 'mine')
        local c = d.formatControls
        assert(c.button:IsEnabled() and a:IsTransferFormatAvailable('wowsims'), client.name)
        c.Choose('wowsims')
        assert(a:GetTransferFormat() == 'wowsims', client.name)
        assert(decodeJson(d.input:GetText()).player.rotation.type == 'TypeAPL', client.name .. ' export')
        paste(d, fixtureText(client.file)); d.preview:Click()
        assert(d.apply:IsEnabled(), client.name .. ': ' .. tostring(d.status:GetText()))
        assert(d.status:GetText():find('Converted from WowSims:', 1, true), client.name)
        d.destination:Click(); d.preview:Click()
        assert(a.rotationTransferForm.importContent.workspace:Snapshot().rotation[1], client.name)
        a.rotationTransferForm.importContent.close:Click()
        local before = countRotations(a)
        d.name:SetText('Imported ' .. client.name); d.name.scripts.OnTextChanged(d.name, true); d.apply:Click()
        assert(countRotations(a) == before + 1, client.name)
    end
end)
test('Retail has no WowSims simulator: the choice stays Rotation Master and the tooltip says why', function()
    local _, a, loads = fixture(1, 11)
    assert(not a:IsTransferFormatAvailable('wowsims') and a:GetTransferFormatUnavailableReason():find('no simulator', 1, true))
    a.db.profile.transfer_format = 'wowsims'
    assert(a:GetTransferFormat() == 'rm', 'a remembered WowSims is ignored where it cannot be used')
    local d = a:ShowRotationTransfer(0, 'mine')
    local c = d.formatControls
    assert(c.button:GetText() == 'Rotation Master' and not c.button:IsEnabled())
    assert(c.button.tooltip == 'WowSims has no simulator for this game version, so only the Rotation Master format is available here.', tostring(c.button.tooltip))
    assert(d.input:GetText() == EXPORT_TEXT and not c.note:IsShown() and loads() == 0, 'nothing of WowSims was loaded')
    c.Choose('wowsims')
    assert(c.button:GetText() == 'Rotation Master' and d.input:GetText() == EXPORT_TEXT and loads() == 0)
    assert(a:SetTransferFormat('wowsims') == false)
    c.button.scripts.OnClick(c.button)
    assert(not c.menu.frame:IsShown(), 'the menu does not open where there is nothing to choose')
    local choices = a:GetTransferFormatChoices()
    assert(choices[2].disabled == true)
    local text, why = a:ConvertRotationToFormat('wowsims', {name = 'x', rotation = {}, cooldowns = {}}, 0)
    assert(text == nil and why:find('no simulator', 1, true))
end)
test('Forever hides mana, health and the combat log from addons: those conditions are left out, their steps are imported disabled, and the report says why', function()
    local _, a = fixture(18, 0)
    local shown = reports(a)
    local d = a:ShowRotationTransfer(0, 'mine')
    d.formatControls.Choose('wowsims')
    paste(d, fixtureText('forever_shaman_enhancement_default.apl.json')); d.preview:Click()
    assert(d.apply:IsEnabled(), tostring(d.status:GetText()))
    d.inspect:Click()
    local text = shown[1].text
    assert(text:find('cannot be used on Forever', 1, true) and text:find('the game hides', 1, true), text)
    d.destination:Click(); d.preview:Click()
    local steps = a.rotationTransferForm.importContent.workspace:Snapshot().rotation
    local disabled = 0
    for _, step in ipairs(steps) do if step.disabled then disabled = disabled + 1 end end
    assert(disabled > 0 and disabled < #steps + 1)
end)

-- ---- the converter is not part of the add-on until it is wanted -------------------------------------------------------------
test('a converter that cannot load leaves Rotation Master working, and says so', function()
    local _, a = fixture(5)
    a.transferFormatLoader = function() return false, 'MISSING' end
    a.db.profile.transfer_format = 'wowsims'
    local d = a:ShowRotationTransfer(0, 'mine')
    assert(d.formatControls.button:GetText() == 'Rotation Master' and d.input:GetText() == EXPORT_TEXT, 'fell back to Rotation Master')
    assert(d.status:GetText():find('could not be loaded (MISSING)', 1, true), tostring(d.status:GetText()))
    d.formatControls.Choose('wowsims')
    assert(d.formatControls.button:GetText() == 'Rotation Master' and d.status:GetText():find('could not be loaded', 1, true))
    paste(d, 'incoming'); d.preview:Click()
    assert(d.apply:IsEnabled(), 'Rotation Master imports still work')
end)
test('nothing of the converter exists in the add-on at login: the module is a separate load-on-demand add-on', function()
    local toc = W.read('RotationMaster.toc')
    for line in toc:gmatch('[^\r\n]+') do assert(not line:find('WowSims', 1, true) and not line:find('wowsims', 1, true), 'the main TOC loads ' .. line) end
    local module = W.read('Modules/RotationMaster_WowSims/RotationMaster_WowSims.toc')
    assert(module:find('## LoadOnDemand: 1', 1, true) and module:find('## Dependencies: RotationMaster', 1, true))
    local pkg = W.read('.pkgmeta')
    assert(pkg:find('RotationMaster/Modules/RotationMaster_WowSims: RotationMaster_WowSims', 1, true))
    -- The login-time code is the small host plus the window, not the converter.
    local host = W.read('Core/transfer_formats.lua')
    assert(#host < 16000 and not host:find('priorityList', 1, true), 'the host stays small and knows no APL')
    local _, a, loads = fixture(2)
    assert(a.RotationMasterWowSims == nil and loads() == 0 and not a:IsTransferFormatLoaded('wowsims'))
    a:ShowRotationTransfer(0, 'mine')
    assert(loads() == 0 and not a:IsTransferFormatLoaded('wowsims'), 'opening the window loads nothing')
end)

finish()
