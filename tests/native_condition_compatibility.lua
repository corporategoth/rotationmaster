-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local modules = { 'Conditions/common.lua', 'Conditions/combat.lua', 'Conditions/talent.lua' }

local function fixture()
    local f = F.new()
    local lookup = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'native condition import requested GUI library')
        return lookup(name, ...)
    end

    f.load('Core/conditions.lua')
    f.load('Platform/spells.lua')
    f.env.C_Spell = { GetSpellInfo = function(id) return { spellID = id, name = 'Fixture spell' } end }
    return f, f.addon
end

local function loadModules(f)
    for _, path in ipairs(modules) do
        f.load(path)
    end
end

test('native condition definitions and responsive spell factories load without GUI registration', function()
    local f, a = fixture()
    assert(f.libraries['AceGUI-3.0'] == nil)
    loadModules(f)
    local value = { spell = 123, ranked = false }

    local group = a:Widget_SpellWidget(
        0,
        'Spell_EditBox',
        value,
        function(v) return tonumber(v) end,
        function() return true end,
        function() end
    )

    assert(group.layout == 'RM-SpellField' and #group.children == 3 and a:IsConditionWidget(group))
    group:Release()
    assert(a.conditionDefinitions.COMBAT and a.conditionDefinitions.TALENT)
end)

test('obsolete condition library dependencies become unavailable without rewriting stored custom code', function()
    local f, a = fixture()
    loadModules(f)

    for _, p in ipairs({
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(p)
    end

    for index, path in ipairs(modules) do
        local id = 'builtin:' .. path .. ':AceGUI'
        assert(a.builtinFunctions[id] == nil, 'retired condition library binding remains')

        local source = {
            description = 'Old library capture',
            args = {},
            returns = {},
            bindings = { AceGUI = id },
            code = 'return AceGUI',
        }

        a.db.global.custom_functions = a.db.global.custom_functions or {}
        a.db.global.custom_functions['OLD_LIBRARY_' .. index] = a:CopySettingsData(source)
        a:InitializeFunctionRegistry()
        local value, why = a:ResolveFunctionBinding('OLD_LIBRARY_' .. index)

        assert(
            value == nil and why == 'missing-function' and a:SettingsDataEqual(
                source,
                a.db.global.custom_functions['OLD_LIBRARY_' .. index]
            )
        )
    end
end)

test('native spell layout directly forwards to the shared geometry without registration', function()
    local _, a = fixture()
    local group = a:CreateConditionGroup()
    group:SetLayout('RM-SpellField')
    local before = a.LayoutWorkbenchSpellGroup
    local calls = 0

    a.LayoutWorkbenchSpellGroup = function(self, content, children)
        assert(self == a and content == group.frame and children == group.children)
        calls = calls + 1
        return 74
    end

    group:DoLayout()
    assert(calls == 1 and group.frame:GetHeight() == 74)
    a.LayoutWorkbenchSpellGroup = before
    group:Release()
end)

test('current condition catalogs omit all seven removed library binding records', function()
    local f, a = fixture()
    loadModules(f)
    f.load('Data/builtin_sources.lua')

    for _, path in ipairs({
        'UI/selector.lua',
        'UI/checkbox.lua',
        'UI/condition_inputs.lua',
        'UI/condition_layout.lua',
        'Conditions/common.lua',
        'Conditions/combat.lua',
        'Conditions/talent.lua',
    }) do
        local module = a.BuiltinSourceCatalog.modules[path]
        assert(module and module.bindings.AceGUI == nil, 'removed library identity returned to the catalog: ' .. path)
    end
end)

finish()
