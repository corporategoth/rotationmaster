-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local entries = {
    { 'RM-Selector', 'CreateConditionDropdown', 'UI/selector.lua' },
    { 'RM-CheckBox', 'CreateConditionCheckBox', 'UI/checkbox.lua' },
    { 'RM-ConditionEditBox', 'CreateConditionEditBox', 'UI/condition_inputs.lua' },
    { 'RM-ConditionSlider', 'CreateConditionSlider', 'UI/condition_inputs.lua' },
}

local modules = { 'UI/selector.lua', 'UI/checkbox.lua', 'UI/condition_inputs.lua' }

local function fixture()
    local f = F.new()
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    local lookup = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'native field requested a GUI library')
        return lookup(name, ...)
    end

    return f, f.addon, frames
end

local function sources(f)
    for _, path in ipairs({
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(path)
    end
end

test('native field implementation modules allocate lazily and recycle current callback leases', function()
    local f, a, frames = fixture()
    assert(f.libraries['AceGUI-3.0'] == nil)
    local before = #frames

    for _, path in ipairs(modules) do
        f.load(path)
    end

    assert(#frames == before)

    for _, entry in ipairs(entries) do
        local w = a[entry[2]](a)
        assert(w.type == entry[1] and a:IsConditionWidget(w))
        local calls = 0

        w:SetCallback('Probe', function()
            calls = calls + 1
        end)

        local old = w.events.Probe
        w:Release()
        local nextWidget = a[entry[2]](a)
        assert(nextWidget == w)
        old(w, 'Probe')
        assert(calls == 0)
        nextWidget:Release()
    end
end)

test('native factories retain public source IDs and actual compiled fields without library captures', function()
    local f, a = fixture()
    sources(f)

    for index, entry in ipairs(entries) do
        local id = 'builtin:' .. entry[3] .. ':' .. entry[2]
        local record = assert(a.builtinFunctions[id])
        assert(a:ResolveFunctionBinding(id) == a[entry[2]])
        assert(a:InstallCustomFunction('NATIVE_FIELD_' .. index, a:CopySettingsData(record.source)))
        local w = a:ResolveFunctionBinding('NATIVE_FIELD_' .. index)(a)
        assert(w.type == entry[1] and a:IsConditionWidget(w) and w.rmActive)
        w:Release()
    end

    local id = 'builtin:UI/condition_inputs.lua:finite'
    assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source) == 'd020adf8')
end)

test('retired GUI binding IDs fail explicitly while saved custom source remains untouched', function()
    local f, a = fixture()
    sources(f)

    for index, path in ipairs(modules) do
        local id = 'builtin:' .. path .. ':AceGUI'
        assert(a.builtinFunctions[id] == nil, 'retired library binding still cataloged')

        local source = {
            description = 'Old saved GUI source',
            args = {},
            returns = { { type = 'table' } },
            bindings = { AceGUI = id },
            code = 'return AceGUI:Create("RM-CheckBox")',
        }

        a.db.global.custom_functions = a.db.global.custom_functions or {}
        a.db.global.custom_functions['OLD_GUI_' .. index] = a:CopySettingsData(source)
        a:InitializeFunctionRegistry()
        local available, reason = a:FunctionAvailable('OLD_GUI_' .. index)
        assert(not available and reason == 'missing-function')

        assert(
            a:SettingsDataEqual(a.db.global.custom_functions['OLD_GUI_' .. index], source),
            'retired dependency rewrote saved source'
        )
    end
end)

test('field release discards pending native text and hides selector popups before reuse', function()
    local _, a = fixture()
    local root = a:CreateConditionGroup()
    local input = a:CreateConditionEditBox()
    local selector = a:CreateConditionDropdown()
    root:AddChildren(input, selector)
    local calls = 0
    input:SetText('saved')

    input:SetCallback('OnEnterPressed', function()
        calls = calls + 1
    end)

    input.editbox:SetText('pending')
    input.editbox.scripts.OnTextChanged(input.editbox, true)
    selector:SetList({ one = 'One' })
    selector.button:Click()
    assert(selector.selector.frame:IsShown())
    root:Release()
    assert(calls == 0 and not selector.selector.frame:IsShown() and not input:IsPending())
end)

finish()
