-- Real observed-unit producers and native observation modules; detached facts.
local F = dofile('tests/fixtures/addon.lua')

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local producers = assert(read('main.lua'):match('(local function CreateUnitInfo.-)\nfunction addon:StopAdviceForError'))

return function(engine, project)
    local f = F.new(project or 11, 2, 'SHAMAN')
    local a, e = f.addon, f.env
    local opaque = {}

    local s = {
        facts = {
            nameplate1 = {
                exists = true,
                guid = 'Creature-old',
                enemy = true,
                threat = 3,
                name = 'Audit mob',
                attack = true,
            },
        },
        calls = {},
    }

    e.canaccessvalue = function(v) return not rawequal(v, opaque) end
    e.getCached = a.getCached

    local function query(key, ...)
        local n = select('#', ...)
        local actor, unit = ...

        if key == 'enemy' or key == 'threat' or key == 'attack' then
            assert(n == 2 and actor == 'player')
            unit = unit
        else
            assert(n == 1)
            unit = actor
        end

        assert(type(unit) == 'string')
        s.calls[#s.calls + 1] = { key, unit, n }
        local row = assert(s.facts[unit], 'unexpected unit ' .. unit)

        if row.throw == key then
            error('controlled native failure')
        end

        return row[key]
    end

    e.UnitName = function(...) return query('name', ...) end
    e.UnitCanAttack = function(...) return query('attack', ...) end
    e.UnitExists = function(...) return query('exists', ...) end
    e.UnitGUID = function(...) return query('guid', ...) end
    e.UnitIsEnemy = function(...) return query('enemy', ...) end
    e.UnitThreatSituation = function(...) return query('threat', ...) end
    local fn = assert(loadstring(producers .. '\nreturn CreateUnitInfo,UpdateUnitInfo', '@actual-main-unit-producers'))
    setfenv(fn, e)
    local create, update = fn()
    a.unitsInRange = { ['Creature-old'] = { unit = 'nameplate1', enemy = true, threat = 3, name = 'Audit mob' } }

    if type(a.GetConditionThreatCount) ~= 'function' then
        local file = io.open('Core/threat_count_conditions.lua')

        if file then
            file:close()
            f.load('Core/threat_count_conditions.lua')
        end
    end

    if engine then
        for _, path in ipairs({
            'Diagnostics/errors.lua', 'Core/conditions.lua', 'Data/plain.lua', 'Data/tags.lua',
            'Data/rotation_tree.lua', 'Core/rotation_sequence.lua', 'Conditions/combat.lua',
            'Core/custom_authoring.lua', 'Core/function_data.lua', 'Data/builtin_sources.lua',
            'Core/builtin_sources.lua'
        }) do
            f.load(path)
        end

        e.loadstring = function(code, name)
            local chunk, why = loadstring(code, name)

            if chunk then
                setfenv(chunk, e)
            end

            return chunk, why
        end
    end

    s.calls = {}
    return f, a, s, opaque, create, update
end
