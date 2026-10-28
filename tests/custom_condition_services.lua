-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture(modern)
    local f = F.new()
    local a = f.addon

    if modern then
        f.load('Core/custom_authoring.lua')
    end

    local lib = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'authoring services loaded AceGUI')
        return lib(name, ...)
    end

    a.name = 'rotationmaster'
    f.env.rotationmaster = a
    a.funcDeserialize = {}

    f.env.loadstring = function(text, name)
        local fn, why = loadstring(text, name)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, why
    end

    f.load('Core/custom_condition_services.lua')
    return f, a
end

test('standalone services initialize templates and compiler contracts without GUI libraries', function()
    local _, a = fixture(true)
    local bridge = assert(a.CustomConditionServices)

    local expected = {
        on_register = 'function(tag)',
        on_unregister = 'function(tag)',
        valid = 'function(spec, value)',
        evaluate = 'function(value, cache, evalStart)',
        print = 'function(spec, value)',
        widget = 'function(parent, spec, value)',
        help = 'function(frame)',
    }

    for name, signature in pairs(expected) do
        assert(bridge.signatures[name] == signature)
        assert(type(a.empty_condition[name]) == 'string' and not a.empty_condition[name]:match('^%s*%-%-'))
    end

    assert(
        type(bridge.compile) == 'function'
            and a.empty_condition.valid == 'return true\n'
            and a.empty_condition.evaluate == 'return true\n'
    )

    assert(
        a.empty_condition.widget
            == 'local top = parent:GetUserData("top")\nlocal root = top:GetUserData("root")\nlocal funcs = top:GetUserData("funcs")\n\n'
    )

    assert(a.empty_condition.help == 'local helpers = addon.help_funcs\n\n' and next(a.empty_condition.fields) == nil)
end)

test('only exact generated headers are removed and read-only preparation preserves original bytes', function()
    local _, a = fixture(true)
    local header = '-- Create the widgets required to configure this condition.\n-- Params:\n--    parent - A bounding box that will contain this condition\'s widgets.\n--    spec - The talent specialization in use (as a number).\n--    value - The storage for this condition (ie. where it\'s parameters are stored).\n'
    local source = a:CopySettingsData(a.empty_condition)
    source.widget = header .. 'local AceGUI = LibStub("AceGUI-3.0")\nreturn AceGUI'
    source.fields.nested = { 'number', 'string' }
    local readonly = a:PrepareCustomConditionEditorSource(source, true)
    assert(readonly.widget == source.widget and readonly ~= source and readonly.fields.nested ~= source.fields.nested)
    local prepared = a:PrepareCustomConditionEditorSource(source)

    assert(
        prepared.widget == 'local AceGUI = LibStub("AceGUI-3.0")\nreturn AceGUI'
            and source.widget == header .. prepared.widget
    )

    source.widget = '-- Authored introduction\n' .. source.widget
    assert(a:PrepareCustomConditionEditorSource(source).widget == source.widget, 'authored comments were removed')
end)

test('modern registration delegates to the current compiler without publishing failed results', function()
    local _, a = fixture(true)
    local source = a:CopySettingsData(a.empty_condition)
    source.description = 'Modern'
    local compiled = { description = 'Compiled', fields = {} }
    local calls = 0

    a.CompileCustomCondition = function(self, key, value, compatibility)
        assert(self == a and key == 'MODERN' and value == source and compatibility == true)
        calls = calls + 1
        return compiled
    end

    assert(a:register_custom_condition('MODERN', source) and a.definitions.MODERN == compiled and calls == 1)
    a.CompileCustomCondition = function() return nil, { reason = 'rejected' } end

    assert(
        not a:register_custom_condition('MODERN', source)
            and a.definitions.MODERN == compiled
            and next(a.funcDeserialize) == nil
    )
end)

test('legacy fallback compiles every fixed signature and copies nested cyclic field schemas', function()
    local f, a = fixture(false)
    local bridge = a.CustomConditionServices
    local source = a.deepcopy(a.empty_condition)
    source.description = 'Fallback'
    source.fields = { nested = { 'string', 'number' } }
    source.fields.self = source.fields
    source.evaluate = 'return value,cache,evalStart,addon,L'
    source.print = 'return spec,value'
    source.widget = 'return parent,spec,value'
    source.help = 'return frame'
    source.on_register = 'return tag'
    source.on_unregister = 'return tag'
    assert(a:register_custom_condition('LEGACY', source))
    local d = a.definitions.LEGACY

    assert(
        d.customCode
            and d.fields ~= source.fields
            and d.fields.self == d.fields
            and d.fields.nested ~= source.fields.nested
    )

    local value, cache = {}, {}
    local x, y, z, instance, locale = d.evaluate(value, cache, 123)

    assert(
        x == value and y == cache and z == 123 and instance == a and locale == f.libraries['AceLocale-3.0']:GetLocale(
            'rotationmaster'
        )
    )

    assert(
        d.print(8, value) == 8
            and d.widget(value, 8, cache) == value
            and d.help(value) == value
            and d.on_register('TAG') == 'TAG'
            and d.on_unregister('TAG') == 'TAG'
    )

    assert(
        next(a.funcDeserialize) == nil
            and type(bridge.compile('valid', 'return true')) == 'function'
            and next(a.funcDeserialize) == nil
    )

    source.evaluate = 'return )'

    assert(
        not a:register_custom_condition('LEGACY', source)
            and a.definitions.LEGACY == d
            and next(a.funcDeserialize) == nil
    )
end)

test('modern installation still rolls back saved source and registry after a registration hook fails', function()
    local _, a = fixture(true)
    local before = { description = 'Previous', fields = {} }
    local saved = { description = 'Saved previous' }
    a.conditionDefinitions = { CUSTOM = before }
    a.db.global.custom_conditions = { CUSTOM = saved }

    a.RegisterCondition = function(self, key, definition)
        self.conditionDefinitions[key] = definition
        definition.on_register(key)
    end

    local source = a:CopySettingsData(a.empty_condition)
    source.description = 'Replacement'
    source.on_register = 'error("hook failed")'

    assert(
        not a:InstallCustomCondition('CUSTOM', source, before)
            and a.conditionDefinitions.CUSTOM == before
            and a.db.global.custom_conditions.CUSTOM == saved
    )
end)

test('native editor loading reuses templates registration and compiler services without reinitializing them', function()
    local f, a = fixture(true)
    local template = a.empty_condition
    local registration = a.register_custom_condition
    local prepare = a.PrepareCustomConditionEditorSource
    local bridge = a.CustomConditionServices
    local compile = bridge.compile
    local signatures = bridge.signatures
    template.testMarker = 'Preserved'
    f.load('UI/custom_condition_editor.lua')

    assert(
        a.empty_condition == template
            and template.testMarker == 'Preserved'
            and a.register_custom_condition == registration
            and a.PrepareCustomConditionEditorSource == prepare,
        'native editor reinitialized authoring services'
    )

    assert(
        type(a.LayoutCustomConditionEditor) == 'function'
            and bridge.compile == compile
            and bridge.signatures == signatures
    )

    local source = a:CopySettingsData(template)
    source.testMarker = nil
    source.description = 'Native service reuse'

    assert(
        a:register_custom_condition('NATIVE_REUSE', source)
            and a.definitions.NATIVE_REUSE.description == source.description
    )

    assert(bridge.compile == compile and bridge.signatures == signatures and next(a.funcDeserialize) == nil)
end)

test('legacy compiler preserves its captured UUID alias and clears temporary functions after success', function()
    local _, a = fixture(false)

    a.uuid = function()
        error('compiler reread the UUID alias')
    end

    local fn = a.CustomConditionServices.compile('evaluate', 'return value,cache,evalStart')
    assert(fn and select(3, fn({}, nil, 321)) == 321 and next(a.funcDeserialize) == nil)
end)

finish()
