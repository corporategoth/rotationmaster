-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local module = 'Conditions/character.lua'

local function collect(options)
    options = options or {}
    local observedGetter, duplicateIndex

    local wrapped = {
        new = function(...)
            local f = F.new(...)
            local load = f.load

            f.load = function(path)
                local result

                if path == module and options.oldCapture then
                    local file = assert(io.open(path))
                    local text = file:read('*a')
                    file:close()

                    if text:find('addon:GetClassGroupCount', 1, true) then
                        text = dofile('tests/fixtures/restore_class_group_repairs.lua')(text)
                    end

                    local chunk = assert(loadstring(text, '@' .. path))
                    setfenv(chunk, f.env)
                    result = chunk('rotationmaster', f.addon)
                else
                    result = load(path)
                end

                if path == module then
                    if options.removeCapture then
                        f.addon.definitions.CLASS_GROUP.evaluate = f.addon.definitions.CLASS.evaluate
                    end

                    if options.nilValue then
                        local getter = f.addon.builtinSourceModules[module]

                        for i = 1, 200 do
                            local name = debug.getupvalue(getter, i)

                            if not name then
                                break
                            end

                            if name == 'character_class' then
                                debug.setupvalue(getter, i, nil)
                            end
                        end
                    end

                    if options.change then
                        options.change(f)
                    end

                    observedGetter = f.addon.builtinSourceModules[module]

                    if type(observedGetter) == 'function' then
                        duplicateIndex = 1

                        while debug.getupvalue(observedGetter, duplicateIndex) do
                            duplicateIndex = duplicateIndex + 1
                        end
                    end
                end

                return result
            end

            return f
        end,
    }

    local output

    local env = setmetatable({
        dofile = function(path)
            if path == 'tests/fixtures/addon.lua' then
                return wrapped
            end

            local result = dofile(path)

            if path == 'tools/retained_builtin_values.lua' and options.manifest then
                options.manifest(result)
            end

            return result
        end,
        print = function(value)
            output = value
        end,
    }, { __index = _G })

    if options.upvalues then
        env.debug = setmetatable({
            getupvalue = function(fn, index)
                if fn == observedGetter then
                    if options.upvalues == 'duplicate' and index == duplicateIndex then
                        return 'character_class', fn('character_class')
                    end

                    local name, value = debug.getupvalue(fn, index)

                    if name == 'character_class' and options.upvalues == 'missing' then
                        return 'other', value
                    end

                    return name, value
                end

                return debug.getupvalue(fn, index)
            end,
        }, { __index = debug })
    end

    local chunk = assert(loadfile('tools/collect_builtin_sources.lua'))
    setfenv(chunk, env)
    local ok, why = pcall(chunk)
    return ok, why, output
end

local function accepts(options)
    local ok, why, text = collect(options)
    assert(ok, why)
    assert(text and text:find('"retained":', 1, true), 'actual collector omitted retained declaration')
    assert(text:find('"character_class":{"kind":', 1, true), 'retained alias missing')
    assert(not text:find('AceGUI', 1, true), 'retention revived GUI ownership')
    return text
end

local function rejects(options)
    local ok, why = collect(options)

    assert(
        not ok and tostring(why):find('retained', 1, true),
        'collector accepted or failed outside retained contract: ' .. tostring(why)
    )
end

test(
    'retained singleton survives actual old capture final capture removal and nil value without a fake consumer',
    function()
        accepts({ oldCapture = true })
        accepts({ removeCapture = true })
        local text = accepts({ nilValue = true })
        assert(text:find('"character_class":{"kind":"nil"', 1, true), 'nil erased retained declaration')
    end
)

test('retained manifest is closed over its exact identity provenance source metadata and hash', function()
    local fields = { 'module', 'alias', 'bindingID', 'declaration', 'namespace', 'description', 'sourceHash' }

    for _, field in ipairs(fields) do
        rejects({
            manifest = function(m)
                m.character_class[field] = 'changed'
            end,
        })

        rejects({
            manifest = function(m)
                m.character_class[field] = nil
            end,
        })
    end

    rejects({
        manifest = function(m)
            setmetatable(m, {})
        end,
    })

    rejects({
        manifest = function(m)
            local row = m.character_class
            row.module = nil
            setmetatable(row, { __index = { module = 'Conditions/character.lua' } })
        end,
    })

    rejects({
        manifest = function(m)
            m.other = {}
        end,
    })

    rejects({
        manifest = function(m)
            m.character_class.extra = true
        end,
    })

    rejects({
        manifest = function(m)
            m.character_class = nil
        end,
    })
end)

test('actual retained getter must be the module Lua getter with exactly one class upvalue', function()
    for _, mode in ipairs({ 'missing', 'proxy', 'foreign', 'wrong-value' }) do
        rejects({
            change = function(f)
                local getter = f.addon.builtinSourceModules[module]

                if mode == 'missing' then
                    f.addon.builtinSourceModules[module] = nil
                elseif mode == 'foreign' then
                    f.addon.builtinSourceModules[module] = f.addon.Functions.values.compare
                elseif mode == 'proxy' then
                    f.addon.builtinSourceModules[module] = function(...) return getter(...) end
                else
                    f.addon.builtinSourceModules[module] = function(name)
                        if name == 'character_class' then
                            return 'CHANGED'
                        end

                        return getter(name)
                    end
                end
            end,
        })
    end

    rejects({ upvalues = 'missing' })
    rejects({ upvalues = 'duplicate' })
end)

test('normal capture discovery cannot silently accept a mismatching already-retained value', function()
    rejects({
        change = function(f)
            local make = assert(loadstring(
                'local character_class=...;return function() return character_class end',
                '@Conditions/character.lua'
            ))

            f.addon.definitions.CLASS_GROUP.evaluate = make('CHANGED')
        end,
    })
end)

finish()
