-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Export text format (docs/quality/export-text-format.md): the codec, every export
-- kind and the native windows. LuaJIT only, like the codec fixture it uses.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()
local H = dofile('tests/fixtures/export_text_cases.lua')
local lines, equal, variants = H.lines, H.equal, H.variants

local function codecFixture()
    local data, deps, calls = dofile('tests/fixtures/codec.lua')()
    return data, assert(data.NewCodec(deps)), calls
end

local function formatter()
    return F.new().addon
end

local function envelopeWire(codec, name)
    local _, envelope = make()
    local value = envelope()
    value.body.name = name or value.body.name

    for index = 1, 40 do
        value.body.rotation[#value.body.rotation + 1] = {
            id = 'step-' .. (index + 1),
            type = 'spell',
            action = 403 + index,
            conditions = { type = 'SPELL_KNOWN', spell = 403 + index },
        }
    end

    return assert(codec:Encode(value)), value
end

test('the importer accepts the wrapped and the unwrapped form of every encoding and decodes the same value', function()
    local data, codec = codecFixture()
    local a = formatter()
    local first, envelope = envelopeWire(codec)
    local wires = { first }
    wires[#wires + 1] = assert(codec:Encode(envelope.body))

    for _, golden in ipairs(dofile('tests/fixtures/legacy_rotation_exports.lua')) do
        wires[#wires + 1] = golden.text
    end

    assert(#wires == 5 and wires[1]:sub(1, 4) == 'RM1:' and wires[2]:sub(1, 4) ~= 'RM1:')

    for index, wire in ipairs(wires) do
        assert(#wire > 76 * 3 or index == 2, 'the fixtures must wrap')
        local plain = assert(codec:Decode(wire))

        for _, variant in ipairs(variants(a, wire)) do
            local decoded, why = codec:Decode(variant[2])
            assert(decoded, 'wire ' .. index .. ' ' .. variant[1] .. ': ' .. tostring(why))

            assert(
                decoded.kind == plain.kind and decoded.transportVersion == plain.transportVersion and equal(
                    decoded.value,
                    plain.value
                ),
                'wire ' .. index .. ' ' .. variant[1] .. ' decoded differently'
            )
        end
    end

    local session = data.NewImportSession(codec, {})

    for _, golden in ipairs(dofile('tests/fixtures/legacy_rotation_exports.lua')) do
        local shown = a:FormatExportText(golden.text)
        local candidate = assert(session:Stage(shown))

        assert(
            candidate.kind == 'legacy'
                and candidate.value.name == 'Legacy Shaman 雪'
                and #candidate.value.rotation == 12
                and candidate.original == shown
        )
    end
end)

test('a corrupted string fails with the same error whether it is wrapped or not', function()
    local data, codec, calls = codecFixture()
    local a = formatter()
    local wire = envelopeWire(codec)
    local oldStrip = function(text) return (text:gsub('[ \t\r\n]', '')) end
    local middle = math.floor(#wire / 2)

    local broken = {
        truncated = wire:sub(1, -2),
        junk = wire:sub(1, middle) .. '!' .. wire:sub(middle + 1),
        stray = wire:sub(1, middle) .. '*' .. wire:sub(middle + 1),
        padding = wire:sub(1, 9) .. '=' .. wire:sub(11),
        future = 'RM9:' .. wire:sub(5),
        marker = 'RM1:',
        empty = '',
        blank = ' \r\n\t ',
        flipped = wire:sub(1, 30) .. (wire:sub(31, 31) == 'A' and 'B' or 'A') .. wire:sub(32),
        tail = wire:sub(1, -3) .. '==',
        legacyTruncated = assert(codec:Encode({ name = 'x', rotation = {}, cooldowns = {} })):sub(1, -5),
    }

    local expected = {
        truncated = 'invalid-base64',
        junk = 'invalid-base64',
        stray = 'invalid-base64',
        padding = 'invalid-base64-padding',
        future = 'unsupported-transport-version',
        empty = 'invalid-base64',
        blank = 'invalid-base64',
    }

    for name, text in pairs(broken) do
        local before, beforeWhy = codec:Decode(oldStrip(text))

        for _, variant in ipairs(variants(a, text)) do
            local decoded, why = codec:Decode(variant[2])

            if
                variant[1] ~= 'no-break spaces'
                and variant[1] ~= 'zero-width spaces'
                and variant[1] ~= 'byte order mark and separators'
                and variant[1] ~= 'mixed'
            then
                assert(
                    before == nil or decoded,
                    name .. ' ' .. variant[1] .. ' failed where the unwrapped form decodes'
                )

                assert(
                    (decoded == nil) == (before == nil) and why == beforeWhy,
                    name .. ' ' .. variant[1] .. ': got ' .. tostring(why) .. ', before ' .. tostring(beforeWhy)
                )
            end
        end

        if expected[name] then
            assert(beforeWhy == expected[name], name .. ' now ' .. tostring(beforeWhy))
        end

        assert(
            not before or name == 'flipped' or name == 'tail' or name == 'legacyTruncated',
            'the corruption ' .. name .. ' must not decode'
        )
    end

    local before = calls.decompress
    assert(not codec:Decode(a:FormatExportText(broken.junk)))
    assert(calls.decompress == before, 'a bad transport reached the decompressor')
    assert(select(2, codec:Decode((a:FormatExportText(wire):gsub('A', '!', 1)))) == 'invalid-base64')
    assert(select(2, codec:Decode(12)) == 'expected-import-string')
end)

test('every export kind survives the formatted string with its encoded bytes unchanged', function()
    local data, codec = codecFixture()
    local f = F.new()
    local a = f.addon
    a.RotationData = data
    f.load('Core/custom_authoring.lua')
    f.load('Core/function_data.lua')
    f.load('Core/conditions.lua')

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    a.conditionDefinitions = { ALPHA = {}, BETA = {} }

    local function check(kind, value, parse)
        local wire = assert(codec:Encode(value), kind)
        local shown = a:FormatExportText(wire)
        assert(not wire:find('%s'), kind .. ': the in-memory export stays unwrapped')
        assert(shown:gsub('\n', '') == wire, kind .. ': formatting changed the encoded bytes')
        assert(a:NormalizeImportText(shown) == wire, kind .. ': normalizing did not restore the encoded bytes')

        assert(
            equal(assert(codec:Decode(shown)).value, assert(codec:Decode(wire)).value),
            kind .. ': decoded differently'
        )

        if parse then
            local plain, plainWhy = parse(wire)
            local wrapped, wrappedWhy = parse(shown)
            assert(plain ~= nil, kind .. ' unwrapped did not import: ' .. tostring(plainWhy))

            assert(
                wrapped ~= nil and equal(plain, wrapped),
                kind .. ' wrapped did not import the same: ' .. tostring(wrappedWhy)
            )

            for _, variant in ipairs(variants(a, wire)) do
                local parsed, why = parse(variant[2])
                assert(parsed and equal(parsed, plain), kind .. ' ' .. variant[1] .. ': ' .. tostring(why))
            end
        end

        return wire, shown
    end

    -- rotation: an RM1 envelope and a bare legacy body, staged exactly as the preview does
    local session = data.NewImportSession(codec, {})

    local stage = function(text)
        local candidate, why = session:Stage(text)
        return candidate and { kind = candidate.kind, value = candidate.value }, why
    end

    local _, envelope = envelopeWire(codec)
    check('rotation envelope', envelope, stage)
    check('rotation body', envelope.body, stage)

    -- item set
    check(
        'item set',
        { format = 'RM-ItemSet', version = 1, name = 'Potions', items = { 5512, 'Healthstone', 22829 } },
        function(text) return a:ParseItemSetImport(text, codec) end
    )

    -- announcement
    local entry = {
        id = '11111111-1111-1111-1111-111111111111',
        type = 'say',
        announce = 'say',
        value = 'Casting {{spell}}',
    }

    check(
        'announcement',
        {
            format = 'RM-Announcement',
            version = 2,
            announcement = {
                id = entry.id,
                type = 'say',
                name = 'Say',
                outputs = { { announce = 'say', value = 'Hello 雪' } },
            },
        },
        nil
    )

    -- effect
    check('effect', { name = 'Pulse 雪', type = 'pulse', sequence = { 1, 1.25, 1.5 } }, nil)

    -- condition category
    check(
        'condition category',
        { format = 'RM-ConditionCategory', version = 1, name = 'Mine', conditions = { 'ALPHA', 'BETA' } },
        function(text) return a:ParseConditionCategoryImport(text, codec) end
    )

    -- profile
    local portable = assert(a:ProfileToPortable({
        announces = { { id = entry.id, type = 'say', announce = 'say', value = 'Hi' } },
    }))

    check('profile', { format = 'RM-Profile', version = 1, name = 'Default', profile = portable }, nil)
    -- custom condition
    local source = { description = 'Test condition', icon = 'Interface\\Icons\\INV_Misc_QuestionMark', fields = {} }

    for callback in pairs(a.CustomConditionCallbacks) do
        source[callback] = ''
    end

    check(
        'custom condition',
        { format = 'RM-CustomCondition', version = 1, name = 'MINE', condition = source },
        function(text) return a:ParseCustomConditionImport(text, codec) end
    )

    -- function and condition bundles
    local function sourceOf(code, bindings)
        return {
            name = 'Utility',
            description = 'Test utility',
            args = { { name = 'value', type = 'number' } },
            returns = { { type = 'number' } },
            code = code,
            bindings = bindings or {},
        }
    end

    assert(a:InstallCustomFunction('BASE', sourceOf('return value * 2')))
    assert(a:InstallCustomFunction('ROOT', sourceOf('return base(value)', { base = 'BASE' })))
    local functionBundle = assert(a:BuildFunctionBundle('function', 'ROOT'))
    assert(#functionBundle.dependencies == 1)
    check('function bundle', functionBundle, function(text) return a:ParseFunctionBundleImport(text, codec) end)
    local conditionSource = a:CopySettingsData(source)
    conditionSource.bindings = { base = 'ROOT' }
    local conditionBundle = assert(a:BuildFunctionBundle('condition', 'MINE', conditionSource))
    assert(conditionBundle.root.kind == 'condition')
    check('condition bundle', conditionBundle, function(text) return a:ParseFunctionBundleImport(text, codec) end)
end)

test('plain pasted lists that rely on whitespace still import, because only the codec normalizes', function()
    local _, codec = codecFixture()
    local f = F.new()
    local a = f.addon
    a.conditionDefinitions = { ALPHA = {}, BETA = {} }
    local items = assert(a:ParseItemSetImport('5512\n22829\r\n  Healthstone  ', codec))
    assert(#items.items == 3 and items.items[1] == 5512 and items.items[2] == 22829 and items.items[3] == 'Healthstone')
    local category = assert(a:ParseConditionCategoryImport('ALPHA BETA\nALPHA', codec))
    assert(#category.conditions == 2 and category.conditions[1] == 'ALPHA' and category.conditions[2] == 'BETA')
end)

-- The native windows -------------------------------------------------------
local function dialogFixture()
    local f = F.new()
    local a = f.addon
    local _, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local data, deps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = data
    a.NewRotationCodec = function() return data.NewCodec(deps) end
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1

    for _, path in ipairs({
        'Platform/spells.lua', 'Data/catalog.lua', 'Data/rotation_store.lua', 'Core/rotation_library.lua',
        'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Help/general.lua', 'Help/conditions.lua',
        'Help/effects.lua', 'Help/itemsets.lua', 'Help/announce.lua', 'UI/window.lua', 'UI/help.lua',
        'UI/icon_picker.lua', 'UI/color_picker.lua', 'UI/settings_roster_order.lua', 'UI/settings_layout.lua',
        'UI/settings_ordered.lua', 'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua',
        'UI/settings_form.lua', 'UI/settings_transfer.lua'
    }) do
        f.load(path)
    end

    local parent = create('Frame')
    parent:SetSize(1000, 600)
    return f, a, parent, data, deps
end

local FONT = 'Interface\\AddOns\\rotationmaster\\Fonts\\Inconsolata-Regular.ttf'

test('the transfer window shows the wrapped export in Inconsolata and the fixed-pitch face fits its box', function()
    local f, a, parent, data, deps = dialogFixture()
    local codec = data.NewCodec(deps)
    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)
    local wire = envelopeWire(codec)
    a:ShowSettingsTextTransfer(p, 'Rotation', wire, function() return true end)
    local d = p.textDialog
    local shown = d.input:GetText()
    assert(shown == a:FormatExportText(wire) and shown ~= wire)

    for index, row in ipairs(lines(shown)) do
        assert(#row <= 76 and (#row == 76 or index == #lines(shown)), 'line ' .. index)
    end

    assert(not shown:find('\r') and not shown:find('\n$') and shown:gsub('\n', '') == wire)
    local path, size = d.input:GetFont()
    assert(path == FONT and size == 12 or path == FONT and size >= 9, 'edit box face ' .. tostring(path))
    assert(d.exportFont and d.exportFont.size == size and d.input.maxLetters >= #shown and d.input.maxLetters > 131072)
    -- an empty import window is fixed-pitch too, and an empty export stays empty
    a:ShowSettingsTextTransfer(p, 'Rotation', '', function() return true end)
    assert(d.input:GetText() == '' and (d.input:GetFont()) == FONT)
    -- a text report keeps the proportional face
    local report = a:CreateWorkbenchTextReport(820, 500)
    assert((report.input:GetFont()) ~= FONT and report.input.fontObject == 'GameFontHighlightSmall')
end)

test('the function bundle window wraps its export and uses the same fixed-pitch box', function()
    local f, a, parent, data, deps = dialogFixture()
    local codec = data.NewCodec(deps)

    for _, path in ipairs({
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
        'UI/function_source_pane.lua',
        'UI/lua_input_diagnostics.lua',
        'UI/lua_editor.lua',
        'UI/function_bundle_transfer.lua',
    }) do
        f.load(path)
    end

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    local function sourceOf(code, bindings)
        return {
            name = 'Utility',
            description = 'Test utility',
            args = { { name = 'value', type = 'number' } },
            returns = { { type = 'number' } },
            code = code,
            bindings = bindings or {},
        }
    end

    assert(a:InstallCustomFunction('BASE', sourceOf('return value * 2')))

    assert(a:InstallCustomFunction('ROOT', sourceOf(
        string.rep('-- padding so the bundle spans several lines\n', 20) .. 'return base(value)',
        { base = 'BASE' }
    )))

    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)
    local d = a:ShowFunctionBundleTransfer(p, 'ROOT', a.db.global.custom_functions.ROOT, {})
    local shown = d.input:GetText()
    local wire = assert(codec:Encode(assert(a:BuildFunctionBundle('function', 'ROOT'))))
    assert(#wire > 76 * 2 and shown == a:FormatExportText(wire), 'the bundle export is wrapped')
    assert(shown:gsub('\n', '') == wire and not shown:find('\r'))
    local path, size = d.input:GetFont()

    assert(
        path == FONT and d.exportFont and d.exportFont.size == 12 and size == 12,
        'the bundle box is Inconsolata at its full size: ' .. tostring(path)
    )

    assert(d.input.maxLetters > 1048576)
    -- pasting the CRLF form back reviews the same bundle
    d.input:SetText((shown:gsub('\n', '\r\n')))
    assert(d:Review() and d.plan and d.plan.valid, 'the CRLF form did not review')
    d.input:SetText(H.NBSP .. shown)
    assert(d:Review() and d.plan and d.plan.valid, 'leading no-break space did not review')
end)

test('the font size is the largest whose 76-character line fits the box, and a missing font falls back', function()
    local f, a, parent = dialogFixture()
    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)
    a:ShowSettingsTextTransfer(p, 'Rotation', 'x', function() return true end)
    local d = p.textDialog

    d.exportProbe.GetStringWidth = function(self)
        local font = self.fontState
        return #(self.text or '') * font.size * 0.5
    end

    for width, expected in pairs({ [510] = 12, [420] = 10, [400] = 10, [300] = 9 }) do
        d.input:SetWidth(width)
        assert(a:UseExportFont(d))
        assert(d.exportFont.size == expected, width .. ' chose ' .. d.exportFont.size)
        local path, size = d.input:GetFont()
        assert(path == FONT and size == expected)
    end

    d.input:SetWidth(429)
    a:UseExportFont(d)
    assert(d.exportFont.size == 10 and d.exportFont.width <= 429 - 12, 'the chosen line fits without wrapping')
    -- the client refuses the file
    local refuse = d.input.SetFont
    d.input.SetFont = function() return false end

    assert(
        a:UseExportFont(d) == false
            and d.exportFont == nil
            and d.input.fontObject == 'GameFontHighlightSmall'
            and (d.input:GetFont()) ~= FONT
    )

    d.input:SetText(a:FormatExportText(string.rep('A', 200)))
    assert(#lines(d.input:GetText()) == 3, 'text still shows and wraps by lines without the font')
    -- the client reports success but keeps another face
    d.input.SetFont = function() end
    assert(a:UseExportFont(d) == false and d.exportFont == nil and (d.input:GetFont()) ~= FONT)
    -- no SetFont at all
    d.input.SetFont = nil
    assert(a:UseExportFont(d) == false and d.input.fontObject == 'GameFontHighlightSmall')
    d.input.SetFont = refuse
    assert(a:UseExportFont(d) and d.exportFont)
end)

test('pasting any form of the export into the window imports the same entry', function()
    local f, a, parent, data, deps = dialogFixture()
    local codec = data.NewCodec(deps)
    f.load('Core/collection_data.lua')
    local p = a:CreateSettingsForm(parent)
    p:Open(function() end)

    local wire = assert(codec:Encode({
        format = 'RM-ItemSet',
        version = 1,
        name = 'Potions',
        items = { 5512, 'Healthstone', 22829 },
    }))

    local imported, failures

    local function apply(text)
        local parsed, why = a:ParseItemSetImport(text, codec)

        if not parsed or not parsed.name then
            failures = (failures or 0) + 1
            return false, why
        end

        imported = parsed
        return true
    end

    a:ShowSettingsTextTransfer(p, 'Items', '', apply)
    local d = p.textDialog

    for _, variant in ipairs(variants(a, wire)) do
        imported = nil
        d.input:SetText(variant[2])
        d.apply:Click()

        assert(
            imported and imported.name == 'Potions' and #imported.items == 3 and imported.items[2] == 'Healthstone',
            'paste ' .. variant[1] .. ' did not import: ' .. tostring(d.status:GetText())
        )

        a:ShowSettingsTextTransfer(p, 'Items', '', apply)
        d = p.textDialog
    end

    assert(not failures)

    -- A corrupted wrapped string reports the codec's own error, exactly as the unwrapped one does.
    local function decodeOnly(text)
        local decoded, why = codec:Decode(text)

        if not decoded then
            return false, why
        end

        return true
    end

    a:ShowSettingsTextTransfer(p, 'Effect', '', decodeOnly)
    d = p.textDialog

    for _, text in ipairs({
        wire:sub(1, -2),
        (a:FormatExportText(wire):sub(1, -2)),
        (a:FormatExportText(wire):gsub('A', '!', 1)),
    }) do
        d.status:SetText('')
        d.input:SetText(text)
        d.apply:Click()
        assert(d.status:GetText() == 'invalid-base64', 'got ' .. tostring(d.status:GetText()))
    end
end)

finish()
