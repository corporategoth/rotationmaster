-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local getLibrary = f.env.LibStub

    f.env.LibStub = setmetatable({ GetLibrary = function(_, name) return getLibrary(name) end }, {
        __call = function(_, name)
            if name == 'AceSerializer-3.0' then
                return {}
            end

            return getLibrary(name)
        end,
    })

    f.env.loadstring = function(text)
        local fn, err = loadstring(text)

        if fn then
            setfenv(fn, f.env)
        end

        return fn, err
    end

    f.addon.name = 'rotationmaster'
    f.env.rotationmaster = f.addon
    f.addon.funcDeserialize = {}
    f.load('Core/custom_condition_services.lua')
    return f
end

test('custom condition registration retains an independent field schema', function()
    local f = fixture()
    local source = f.addon.deepcopy(f.addon.empty_condition)
    source.description = 'Custom fixture'
    source.fields = { spell = { 'string', 'number' }, count = 'number' }
    assert(f.addon:register_custom_condition('CUSTOM_SCHEMA', source))
    local registered = f.addon.definitions.CUSTOM_SCHEMA
    assert(registered.fields and registered.fields.count == 'number', 'registered condition lost its declared fields')
    assert(registered.fields.spell[1] == 'string' and registered.fields.spell[2] == 'number')
    registered.fields.spell[1] = 'changed'
    assert(source.fields.spell[1] == 'string', 'registration mutated SavedVariables')
end)

test('custom code is marked for diagnostic source redaction', function()
    local f = fixture()
    local source = f.addon.deepcopy(f.addon.empty_condition)
    assert(f.addon:register_custom_condition('CUSTOM_SOURCE', source))
    assert(f.addon.definitions.CUSTOM_SOURCE.customCode == true)
end)

test('a custom callback failure reaches diagnostics with the custom-code marker', function()
    local f = fixture()
    f.env.geterrorhandler = function() return function() end end
    f.env.debugstack = function() return 'Interface/AddOns/rotationmaster/fixture.lua:1' end
    f.load('Diagnostics/errors.lua')
    f.load('Core/conditions.lua')
    local source = f.addon.deepcopy(f.addon.empty_condition)
    source.evaluate = 'error("CUSTOM_PRIVATE_FRAGMENT",0)'
    assert(f.addon:register_custom_condition('CUSTOM_FAILURE', source))
    assert(f.addon:evaluateConditionResult({ type = 'CUSTOM_FAILURE' }).status == 'unavailable')
    assert(not f.addon.Diagnostics:FormatReport():find('CUSTOM_PRIVATE_FRAGMENT', 1, true))
    assert(f.addon.Diagnostics:FormatReport(nil, true):find('CUSTOM_PRIVATE_FRAGMENT', 1, true))
end)

finish()
