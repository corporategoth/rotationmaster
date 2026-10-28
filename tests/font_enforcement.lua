-- The client raises "Font not set" from FontString:SetText() (and from an
-- EditBox's) until the region has a font. The native_ui fixture enforces that
-- now, so every suite that draws a page also proves its text regions are
-- fonted. This suite pins the rule itself and drives the Functions tab, with
-- the real embedded LuaWorkbench gutter, through the paths that raised in game:
-- the page redraws from the shared reflow driver while its first Lua editor is
-- still unpainted, and releasing that editor empties every text region it owns.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function functions()
    local f = dofile('tests/fixtures/lua_workbench.lua')()
    local a = f.addon
    local errors = {}

    f.env.geterrorhandler = function()
        return function(err)
            errors[#errors + 1] = err
        end
    end

    a.db.char = {}
    a.db.global.custom_functions = {}

    for _, path in ipairs({
        'UI/controls.lua', 'Core/function_data.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua',
        'UI/settings_layout.lua', 'UI/settings_ordered.lua', 'UI/settings_roster_order.lua', 'UI/settings_form.lua',
        'UI/settings_collections.lua', 'UI/settings_transfer.lua', 'UI/lua_input_probe.lua',
        'UI/lua_input_diagnostics.lua', 'UI/lua_editor.lua', 'UI/settings_functions.lua', 'UI/function_bindings.lua',
        'UI/function_source_pane.lua', 'UI/function_bundle_transfer.lua'
    }) do
        local file = io.open(path)

        if file then
            file:close()
            f.load(path)
        end
    end

    local data, deps = dofile('tests/fixtures/codec.lua')()
    a.RotationData = data
    a.NewRotationCodec = function() return data.NewCodec(deps) end
    local host = f.env.CreateFrame('Frame')
    host:SetSize(1100, 700)
    return f, a, host, errors
end

local function source(name, bindings)
    return {
        name = name,
        description = name .. ' documentation',
        args = { { name = 'value', type = 'number', description = 'Input value' } },
        returns = { { type = 'number', description = 'Result' } },
        code = 'return value\nreturn value',
        bindings = bindings or {},
    }
end

local function none(errors)
    assert(#errors == 0, 'a relayout reached the error handler: ' .. tostring(errors[1]))
end

test('a FontString or EditBox without a font fails like the client, and a font fixes it', function()
    local f = dofile('tests/fixtures/lua_workbench.lua')()
    local create = f.env.CreateFrame
    local parent = create('Frame')
    local bare = parent:CreateFontString(nil, 'OVERLAY')
    assert(not pcall(bare.SetText, bare, 'x'), 'a bare FontString accepted text')
    local ok, why = pcall(bare.SetText, bare, '')

    assert(
        not ok and why:find('FontString:SetText(): Font not set', 1, true),
        'even empty text needs a font: ' .. tostring(why)
    )

    assert(
        not pcall(bare.GetStringHeight, bare) and not pcall(bare.GetStringWidth, bare),
        'a bare FontString measured text'
    )

    assert(bare:GetFont() == nil, 'a bare FontString reports a font')

    assert(
        bare:SetFont('', 12, '') == false
            and bare:SetFont('Fonts\\FRIZQT__.TTF', 0, '') == false
            and bare:GetFont() == nil,
        'an unusable font was accepted'
    )

    bare:SetFont('Fonts\\FRIZQT__.TTF', 12, '')
    bare:SetText('x')
    assert(bare:GetText() == 'x' and bare:GetFont() == 'Fonts\\FRIZQT__.TTF')
    local object = parent:CreateFontString(nil, 'OVERLAY')
    object:SetFontObject('GameFontHighlightSmall')
    object:SetText('x')
    local templated = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    templated:SetText('x')
    templated:SetFormattedText('%d', 3)
    local edit = create('EditBox', nil, parent)
    assert(not pcall(edit.SetText, edit, ''), 'a bare EditBox accepted text')
    edit:SetFontObject('GameFontHighlightSmall')
    edit:SetText('x')
    local button = create('Button', nil, parent)
    button:GetFontString():SetText('x')
end)

test('a failing reflow reaches the error handler with the stack it failed in', function()
    local f, a = functions()
    local owner = {}
    local frame = f.env.CreateFrame('Frame')
    local seen

    f.env.geterrorhandler = function()
        return function(err)
            seen = err
        end
    end

    -- The client's debugstack; the fixture's stand-in is the Lua traceback.
    f.env.debugstack = function() return debug.traceback('', 2) end

    a:RequestWorkbenchReflow(owner, frame, function()
        local bare = frame:CreateFontString(nil, 'OVERLAY')
        bare:SetText('boom')
    end)

    a:FlushWorkbenchReflow()

    assert(
        type(seen) == 'string' and seen:find('Font not set', 1, true),
        'the reflow failure was lost: ' .. tostring(seen)
    )

    assert(
        seen:find('stack traceback', 1, true) and seen:find('font_enforcement.lua', 1, true),
        'the failure carries no stack: ' .. tostring(seen)
    )

    seen = nil

    a:RequestWorkbenchSettle(
        owner,
        frame,
        function()
            error({ code = 1 })
        end,
        1
    )

    a:FlushWorkbenchReflow()
    assert(type(seen) == 'table' and seen.code == 1, 'a non-string error was rewritten')
    a:RequestWorkbenchReflow(owner, frame, function() end)
    a:FlushWorkbenchReflow()
    assert(seen.code == 1)
end)

test('Functions draws, redraws from a reflow and releases its unpainted Lua editor with every region fonted', function()
    local f, a, host, errors = functions()
    a.db.global.custom_functions.A = source('Alpha')
    a.db.global.custom_functions.B = source('Beta')
    a:InitializeFunctionRegistry()
    a:RegisterBuiltinFunction('builtin:test', source('Packaged helper'), function() return function(v) return v end end)
    local p = a:OpenNativeSettings(host, 'Functions')
    assert(p and p.inlineFunction and p.inlineFunction.code, 'Functions did not open')

    -- The page is drawn once at its opening width; a different width asks the
    -- shared driver for a second drawing that releases the first editor
    -- before any frame has painted it.
    for _, width in ipairs({ 900, 700, 1100, 320, 1100 }) do
        host:SetWidth(width)
        p:SetWidth(width)
        a:FlushWorkbenchReflow()
        none(errors)
    end

    p:SetHeight(500)
    a:FlushWorkbenchReflow()
    none(errors)
    p.roster.choose('B')
    assert(p.functionID == 'B')
    a:FlushWorkbenchReflow()
    none(errors)
    p.roster.choose('A')
    a:FlushWorkbenchReflow()
    none(errors)
    p:Draw()
    p:Draw()
    none(errors)
    p.fields.new_function:Click()
    a:FlushWorkbenchReflow()
    none(errors)
    p.roster.choose('A')
    a:FlushWorkbenchReflow()
    none(errors)
    p.fields.duplicate_function:Click()
    a:FlushWorkbenchReflow()
    none(errors)
    p:Release()
    a:FlushWorkbenchReflow()
    none(errors)
end)

test('Functions source pane, bindings, compare, bundle transfer and relayout keep every text region fonted', function()
    local f, a, host, errors = functions()
    local helper = source('Helper')
    local root = source('Root', { helper = 'HELPER' })
    root.code = 'return helper(value)'
    a.db.global.custom_functions.ROOT = root
    a.db.global.custom_functions.HELPER = helper
    a:InitializeFunctionRegistry()
    local p = a:OpenNativeSettings(host, 'Functions')
    a:FlushWorkbenchReflow()
    local d = p.inlineFunction
    assert(d and d.form and d.code)
    -- Source pane: metadata rows, signature, Lua editor, syntax and history.
    d.code.edit:SetText('return value + 1')
    d.code.edit.scripts.OnTextChanged(d.code.edit, true)
    d:UpdateActions()
    d.syntax:Click()
    a:FlushWorkbenchReflow()
    none(errors)
    d.codeUndo:Click()
    d.codeRedo:Click()
    d.codeReset:Click()
    none(errors)
    -- Bindings rows and the width-driven redraw of the form that holds them.
    d.form.fields.function_bindings:Click()
    a:FlushWorkbenchReflow()
    none(errors)

    for _, width in ipairs({ 1100, 640, 1100 }) do
        p:SetWidth(width)
        d.form:SetWidth(width)
        a:FlushWorkbenchReflow()
    end

    none(errors)
    -- Roster actions: Compare and Import/Export, then the bundle window.
    p.fields.compare:Click()
    p:Draw()
    a:FlushWorkbenchReflow()
    none(errors)
    p.fields.transfer:Click()
    local t = p.functionBundleTransfer
    assert(t and t.frame:IsShown(), 'bundle transfer did not open')
    t:Review()
    t.includeDependencies:Click()
    t:Review()
    a:FlushWorkbenchReflow()
    none(errors)
    t.frame:Hide()
    a:FlushWorkbenchReflow()
    p:Release()
    a:FlushWorkbenchReflow()
    none(errors)
end)

test('every Functions text region has a font after drawing, including pooled and hidden ones', function()
    local f, a, host, errors = functions()
    a.db.global.custom_functions.ROOT = source('Root', { helper = 'HELPER' })
    a.db.global.custom_functions.HELPER = source('Helper')
    a:InitializeFunctionRegistry()
    local made = {}
    local create = f.env.CreateFrame

    f.env.CreateFrame = function(...)
        local frame = create(...)
        made[#made + 1] = frame
        local font = frame.CreateFontString

        function frame:CreateFontString(...)
            local region = font(self, ...)
            made[#made + 1] = region
            return region
        end

        return frame
    end

    local p = a:OpenNativeSettings(host, 'Functions')
    p.inlineFunction.form.fields.function_bindings:Click()
    host:SetWidth(700)
    p:SetWidth(700)
    a:FlushWorkbenchReflow()
    none(errors)
    p.fields.transfer:Click()
    a:FlushWorkbenchReflow()
    local bare = {}

    for _, region in ipairs(made) do
        if (region.kind == 'FontString' or region.kind == 'EditBox') and not region:GetFont() then
            bare[#bare + 1] = region.kind .. (region.name and ' ' .. region.name or '')
        end
    end

    assert(#bare == 0, #bare .. ' text regions have no font: ' .. table.concat(bare, ', '))
    p:Release()
    none(errors)
end)

test('releasing a LuaWorkbench editor that never painted empties every region without a font error', function()
    for _, provider in ipairs({ 'plain', 'LuaWorkbench' }) do
        local f, a = dofile('tests/fixtures/lua_workbench.lua')()
        local errors = {}

        f.env.geterrorhandler = function()
            return function(err)
                errors[#errors + 1] = err
            end
        end

        local code = a:CreateWorkbenchLuaEditor(f.env.UIParent, function() end, function() return true end, provider)
        code:SetText('return 1\nreturn 2')
        -- No OnUpdate has run: the gutter's measuring string and the syntax
        -- overlay are exactly as constructed.
        code:Release()
        assert(#errors == 0, provider .. ' release failed: ' .. tostring(errors[1]))
        code:Acquire(function() end, function() return true end)
        code:Release()
        assert(#errors == 0, provider .. ' reuse failed: ' .. tostring(errors[1]))
    end
end)

finish()
