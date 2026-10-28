-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local module = 'UI/condition_layout.lua'

local function fixture()
    local f = F.new()
    local lookup = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'native group requested a GUI library')
        return lookup(name, ...)
    end

    return f, f.addon
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

test('native groups own List Table and spell-field layouts without a compatibility library', function()
    local f, a = fixture()
    f.load(module)
    assert(f.libraries['AceGUI-3.0'] == nil and not a.BindConditionGroupCompatibilityLibrary)
    local group = a:CreateConditionGroup()
    group:SetWidth(320)
    local child = a:CreateConditionCheckBox()
    child:SetFullWidth(true)
    group:AddChild(child)
    assert(child.frame:GetWidth() == 320)

    for _, layout in ipairs({ 'List', 'Table', 'RM-SpellField' }) do
        local empty = a:CreateConditionGroup()
        empty:SetLayout(layout)
        empty:Release()
    end

    group:Release()
end)

test('group factory and unrelated alignment helper retain IDs and current native source clones', function()
    local f, a = fixture()
    sources(f)

    for name, hash in pairs({ verticalAlignment = '4de23615' }) do
        local id = 'builtin:' .. module .. ':' .. name
        assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source) == hash)
        assert(a:ResolveFunctionBinding(id) == a.builtinSourceModules[module](name))
    end

    local source = assert(a.builtinFunctions['builtin:' .. module .. ':CreateConditionGroup']).source

    assert(
        a:ResolveFunctionBinding('builtin:' .. module .. ':CreateConditionGroup') == a.CreateConditionGroup
            and source.returns[1].type == 'RMConditionGroup'
    )

    assert(a:InstallCustomFunction('NATIVE_GROUP_FACTORY', a:CopySettingsData(source)))
    local group = a:ResolveFunctionBinding('NATIVE_GROUP_FACTORY')(a)
    assert(group.type == 'RM-ConditionGroup' and group.rmActive and a:IsConditionWidget(group))
    group:Release()
end)

test('retired group library dependency cannot acquire foreign leases or mutate saved custom source', function()
    local f, a = fixture()
    sources(f)
    local id = 'builtin:' .. module .. ':AceGUI'
    assert(a.builtinFunctions[id] == nil)

    local source = {
        description = 'Old group source',
        args = {},
        returns = { { type = 'table' } },
        bindings = { AceGUI = id },
        code = 'return AceGUI:Create("RM-ConditionGroup")',
    }

    a.db.global.custom_functions = a.db.global.custom_functions or {}
    a.db.global.custom_functions.OLD_GROUP = a:CopySettingsData(source)
    a:InitializeFunctionRegistry()
    local value, why = a:ResolveFunctionBinding('OLD_GROUP')
    assert(value == nil and why == 'missing-function')
    assert(a:SettingsDataEqual(source, a.db.global.custom_functions.OLD_GROUP))
end)

test('pooled native groups discard pending descendants and retire captured callbacks', function()
    local _, a = fixture()
    local seen = {}
    local calls = 0

    for _ = 1, 100 do
        local root = a:CreateConditionGroup()
        local child = a:CreateConditionEditBox()
        seen[root] = true
        child:SetText('saved')

        child:SetCallback('OnEnterPressed', function()
            calls = calls + 1
        end)

        local stale = child.events.OnEnterPressed
        root:AddChild(child)
        child.editbox:SetText('pending')
        child.editbox.scripts.OnTextChanged(child.editbox, true)
        root:Release()
        stale(child, 'OnEnterPressed', 'wrong')
        assert(not child.rmActive)
    end

    local n = 0

    for _ in pairs(seen) do
        n = n + 1
    end

    assert(n == 1 and calls == 0)
end)

finish()
