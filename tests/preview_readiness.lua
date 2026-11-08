-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Separate readiness for the bar glow and the preview: with "Preview uses its own readiness options" the preview shows
-- the first steps ready under its own Ignore Mana / Range / Moving, while the bar glow keeps the General options; off,
-- both follow the same options. Both evaluation engines.
local pass, fail = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        pass = pass + 1
        print('PASS ' .. name)
    else
        fail = fail + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local root = assert(io.popen('pwd'):read('*l'))

local function make(engine)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    local c = build({ buttons = true, target = true, poll = .15, preview = 3 })
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine))
    c.a.print = function() end
    -- Every spell off cooldown, so another step is ready when Lightning Bolt (403) is not.
    c.setSpellReady(true)
    return c
end

local function poll(c)
    for _ = 1, 6 do
        c.tick()
    end
end

local function first(c)
    local icon = c.a.nextWindow and c.a.nextWindow.icons[1]
    return icon and icon:IsShown() and icon.spellId or nil
end

for _, engine in ipairs({ 'standard', 'lean' }) do
    -- In this fixture the starter rotation's only matching step is Lightning Bolt (403).
    test(engine .. ': shared options keep the glow and the preview on the same answer', function()
        local c = make(engine)
        poll(c)
        assert(c.a.currentSpell == 403 and first(c) == 403, 'baseline ' .. tostring(c.a.currentSpell))
        c.e.C_Spell.IsSpellInRange = function(id) return id ~= 403 end
        poll(c)
        assert(c.a.currentSpell ~= 403 and first(c) ~= 403, 'out-of-range spell kept')
    end)

    test(engine .. ': the preview can ignore range while the bar glow does not', function()
        local c = make(engine)
        c.e.C_Spell.IsSpellInRange = function(id) return id ~= 403 end
        c.a.db.profile.preview_readiness = true
        c.a.db.profile.preview_ignore_range = true
        poll(c)
        assert(c.a.currentSpell ~= 403, 'bar glowed an out-of-range spell')
        assert(first(c) == 403, 'preview did not ignore range: ' .. tostring(first(c)))
        c.a.db.profile.preview_readiness = false
        poll(c)
        assert(first(c) ~= 403, 'turning the option off did not return to shared options')
        c.a.db.profile.ignore_range = true
        poll(c)
        assert(c.a.currentSpell == 403 and first(c) == 403, 'Ignore Range on both')
    end)

    test(engine .. ': without Ignore Moving a cast is skipped while moving; the preview can keep it', function()
        local c = make(engine)
        c.e.GetUnitSpeed = function() return 7 end

        c.e.C_Spell.GetSpellInfo = function(id)
            return { spellID = id, name = 'Spell ' .. id, iconID = 1, castTime = id == 403 and 2000 or 0 }
        end

        poll(c)
        assert(c.a.currentSpell ~= 403 and first(c) ~= 403, 'cast advised while moving')
        c.a.db.profile.preview_readiness = true
        c.a.db.profile.preview_ignore_moving = true
        poll(c)
        assert(c.a.currentSpell ~= 403 and first(c) == 403, 'preview did not ignore moving')
        c.a.db.profile.ignore_moving = true
        poll(c)
        assert(c.a.currentSpell == 403, 'Ignore Moving on the bar')
    end)
end

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
