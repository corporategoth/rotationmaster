-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Independent actual full-main/series observations; no source substitutions.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local h = assert(io.open('tests/announcement_series_runtime.lua'))
local source = h:read('*a')
h:close()
local prefix = assert(source:match('^(.-)\ntest%('))
local automatic = assert(source:match('(local function automatic%(cards%).-)\ntest%('))
local make = assert(loadstring(prefix .. '\n' .. automatic .. '\nreturn automatic'))()

local function card(n)
    return { id = string.format('%08d-1111-1111-1111-111111111111', n), announce = 'local', value = tostring(n) }
end

local function getter(a, fn)
    local prior = getmetatable(a)
    local old = prior and prior.__index
    local mt = {}

    if prior then
        for k, v in pairs(prior) do
            mt[k] = v
        end
    end

    mt.__index = function(object, key)
        if key == 'IsEnabled' then
            return fn()
        end

        if type(old) == 'function' then
            return old(object, key)
        elseif type(old) == 'table' then
            return old[key]
        end
    end

    a.IsEnabled = nil
    setmetatable(a, mt)
end

test('legacy actual event delivery performs zero new lifecycle method lookups', function()
    local _, a, out = make({})

    a.db.profile.announces[1] = {
        id = '11111111-1111-1111-1111-111111111111',
        type = 'spell',
        spell = 686,
        event = 'START',
        announce = 'local',
        value = 'Legacy',
    }

    local reads = 0

    getter(a, function()
        reads = reads + 1
    end)

    a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START', 'player', 'legacy', 686)
    assert(#out == 1)
    assert(reads == 0, 'legacy lifecycle lookups ' .. reads)
end)

test('series final lifecycle getter cannot disable after raw state witness and still output', function()
    local _, a, out = make({ card(1), card(2) })
    a.enabledState = true
    local armed = false
    local retiredOutputs = 0

    local lifecycle = function(self)
        self.enabledState = true
        armed = true
        return true
    end

    getter(a, function()
        if armed then
            armed = false
            a.enabledState = false
        end

        return lifecycle
    end)

    local original = a.announce

    a.announce = function(self, text)
        if self.enabledState == false then
            retiredOutputs = retiredOutputs + 1
        end

        return original(self, text)
    end

    a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START', 'player', 'getter-retire', 686)
    assert(retiredOutputs == 0, 'disabled series emitted ' .. retiredOutputs .. ' outputs')
end)

finish()
