-- Actual main publication protocol; no gameplay observations are cached.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local prefix = assert(read('tests/active_runtime_main.lua'):match('^(.-)\ntest%('))
local fixture = assert(loadstring(prefix .. '\nreturn fixture', '@noop-publication-fixture'))()

local function setup(count)
    local c, s = fixture()
    s.mode = 'plan'
    s.body.rotation = {}
    s.body.cooldowns = {}
    s.views = {}

    for i = 1, count do
        local v = { id = 'inactive-' .. i, type = 'spell', disabled = true }
        s.body.cooldowns[i] = v
        s.views[v] = { id = v.id }
    end

    return c, s
end

test('inactive cooldown rows do not each repeat the complete publication proof', function()
    local c, s = setup(0)
    c.tick()
    local base = s.fullChecks
    c, s = setup(64)
    c.tick()
    assert(s.fullChecks == base, 'no-op rows added ' .. (s.fullChecks - base) .. ' full publication proofs')
    assert(#c.a.Diagnostics:GetReports() == 0)
end)

test('a previously announced disabled cooldown still retires and clears its glow', function()
    local c, s = setup(1)
    c.a.avail_announced['inactive-1'] = 403
    local glows = 0

    c.a.GlowCooldown = function(_, id, enabled, view)
        assert(id == 403 and enabled == false and view == s.views[s.body.cooldowns[1]])
        glows = glows + 1
    end

    c.tick()
    assert(c.a.avail_announced['inactive-1'] == nil and glows == 1, 'active cooldown retirement was skipped')
    assert(#c.a.Diagnostics:GetReports() == 0)
end)

test('an opaque advice publisher can add retirement work after observations were collected', function()
    local c, s = setup(1)
    local announced = false

    c.e.WeakAuras = {
        ScanEvents = function()
            if not announced then
                announced = true
                c.a.avail_announced['inactive-1'] = 403
            end
        end,
    }

    local glows = 0

    c.a.GlowCooldown = function(_, id, enabled)
        assert(id == 403 and not enabled)
        glows = glows + 1
    end

    c.tick()

    assert(
        announced and glows == 1 and c.a.avail_announced['inactive-1'] == nil,
        'publication used an earlier no-op decision'
    )

    assert(#c.a.Diagnostics:GetReports() == 0)
end)

test('public announcement table accessors keep their ordinary getter dispatch', function()
    local c = setup(3)
    local reads = 0

    c.a.avail_announced = setmetatable({}, {
        __index = function()
            reads = reads + 1
            return nil
        end,
    })

    c.tick()
    assert(reads == 6, 'accessor dispatch changed: ' .. reads)
    assert(#c.a.Diagnostics:GetReports() == 0)
end)

test('an expired full guard still suppresses staged publication', function()
    local c, s = setup(64)

    s.onPrepare = function()
        return {
            AfterOpaque = function() return true end,
            EvaluateBool = function()
                s.current = false
                return false
            end,
            EvaluateResult = function()
                s.current = false
                return { status = 'no-match' }
            end,
        }
    end

    -- Preserve a reached predicate so the owned setup can retire this invocation.
    s.body.cooldowns[1].disabled = false
    s.body.cooldowns[1].action = 403
    c.reset(true)
    c.tick()
    local counts = c.snapshot()
    assert((counts.SendMessage or 0) == 0 and (counts.GlowClear or 0) == 0, 'retired invocation published')
end)

finish()
