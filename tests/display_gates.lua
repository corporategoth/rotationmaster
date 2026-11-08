-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Display gates: a readable gate is an ordinary test; a hidden one puts the step in the preview only, drawn over the
-- next recommendation with the game's alpha pair, while the bar glow keeps the next step. Both engines. Also the gate
-- field's validation and the platform curve evaluation.
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
local GATE = { unit = 'target', kind = 'health', operator = 'LESSTHAN', value = 20 }

local function make(engine, observation)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    local c = build({ buttons = true, target = true, poll = .15, preview = 3 })
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine))
    c.a.print = function() end
    c.setSpellReady(true)
    c.tick()
    local key = c.a.currentRotation
    local record, token = c.a:GetRotationRecordSnapshot(0, key)

    record.body.rotation = {
        { id = 'gated', type = 'spell', action = 8042, gate = GATE, conditions = {} },
        { id = 'bolt', type = 'spell', action = 403, conditions = {} },
    }

    local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, key))
    assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
    c.a.Platform.GetGateObservation = function() return observation.open, observation.why end
    c.a.Platform.GetGateAlphas = function() return 'open-alpha', 'closed-alpha' end
    return c
end

local function poll(c)
    for _ = 1, 6 do
        c.tick()
    end
end

for _, engine in ipairs({ 'standard', 'lean' }) do
    test(engine .. ': a readable gate is an ordinary test', function()
        local observation = { open = true }
        local c = make(engine, observation)
        poll(c)
        assert(c.a.currentSpell == 8042, 'open gate: ' .. tostring(c.a.currentSpell))
        observation.open = false
        poll(c)
        assert(c.a.currentSpell == 403, 'closed gate: ' .. tostring(c.a.currentSpell))
        assert(not c.a.nextWindow.icons[1].gateFrame:IsShown(), 'no overlay for a readable gate')
    end)

    test(engine .. ': a hidden gate shows only in the preview, over the next recommendation', function()
        local c = make(engine, { open = nil, why = 'restricted-value' })
        poll(c)
        local icon = c.a.nextWindow.icons[1]
        assert(c.a.currentSpell == 403, 'the bar glow keeps the next step: ' .. tostring(c.a.currentSpell))
        assert(icon.spellId == 403 and icon.gateFrame:IsShown(), 'gated icon not drawn over the next one')
        assert(icon.gateTexture.alpha == 'open-alpha' and icon.texture.alpha == 'closed-alpha', 'game alphas')
    end)

    test(engine .. ': a hidden gate also lights a gated glow on its own buttons', function()
        local observation = { open = nil, why = 'restricted-value' }
        local c = make(engine, observation)
        local last
        local glow = c.a.SetGatedGlows

        c.a.SetGatedGlows = function(self, entries)
            last = {}

            for i, entry in ipairs(entries) do
                last[i] = entry.spellId
            end

            return glow(self, entries)
        end

        poll(c)
        assert(last and last[1] == 8042 and #last == 1, 'gated glow not requested')
        observation.open, observation.why = false, nil
        poll(c)
        assert(last and #last == 0, 'gated glow kept after the gate became readable')
    end)

    test(
        engine .. ': consecutive hidden gates stack in one slot, first open gate on top, the next step at the bottom',
        function()
            local c = make(engine, { open = nil, why = 'restricted-value' })
            local record, token = c.a:GetRotationRecordSnapshot(0, c.a.currentRotation)

            table.insert(record.body.rotation, 2, {
                id = 'gated2',
                type = 'spell',
                action = 324,
                gate = GATE,
                conditions = {},
            })

            local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, c.a.currentRotation))
            assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
            local calls = 0

            c.a.Platform.GetGateAlphas = function()
                calls = calls + 1
                return 'open' .. calls, 'closed' .. calls
            end

            poll(c)
            local icon = c.a.nextWindow.icons[1]
            assert(c.a.currentSpell == 403, 'the bar glow keeps the next step: ' .. tostring(c.a.currentSpell))
            assert(icon.spellId == 403 and icon.gateFrame:IsShown() and icon.gateDepth == 2, 'two gates not stacked')
            local first, second = icon.gateLayers[1], icon.gateLayers[2]
            assert(first.texture.alpha:match('^open') and first.rest.alpha:match('^closed'), 'first layer alphas')
            assert(second.frame == first.rest, 'the second gate is nested under the first gate\'s inverse')
            assert(second.texture.alpha:match('^open') and second.rest.alpha:match('^closed'), 'second layer alphas')

            assert(
                icon.gateFallback:IsShown() and icon.texture.alpha == 0,
                'the next step moves to the bottom of the stack'
            )

            local next = c.a.nextWindow.icons[2]
            assert(not next or not next:IsShown() or next.spellId ~= 324, 'a stacked gate takes no slot of its own')
        end
    )

    test(engine .. ': a cooldown whose only condition is a hidden threshold is handed to the game', function()
        local c = make(engine, { open = true })
        c.a.Platform.GetCombatDataPolicy = function() return 'restricted' end
        c.a.Platform.GetUnitHealthObservation = function() return nil, 'restricted-value' end
        local record, token = c.a:GetRotationRecordSnapshot(0, c.a.currentRotation)

        record.body.cooldowns = {
            {
                id = 'execute-window',
                type = 'spell',
                action = 324,
                magnification = 2.5,
                conditions = {
                    type = 'AND',
                    value = { { type = 'HEALTHPCT', unit = 'target', operator = 'LESSTHAN', value = .2 } },
                },
            },
        }

        local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, c.a.currentRotation))
        assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
        local last
        local glow = c.a.SetGatedGlows

        c.a.SetGatedGlows = function(self, entries)
            last = {}

            for i, entry in ipairs(entries) do
                last[i] = entry
            end

            return glow(self, entries)
        end

        poll(c)

        if engine == 'lean' then
            local handed

            for _, entry in ipairs(last or {}) do
                if entry.spellId == 324 then
                    handed = entry
                end
            end

            assert(handed, 'the cooldown is not a gated glow')
            assert(handed.gate.kind == 'health' and handed.gate.operator == 'LESSTHAN' and handed.gate.value == 20)
            assert(handed.style and handed.style.magnification == 2.5, 'the cooldown keeps its glow style')
            assert(not c.a.avail_announced['execute-window'], 'never announced: RM does not know the answer')
        else
            for _, entry in ipairs(last or {}) do
                assert(entry.spellId ~= 324, 'the standard engine evaluates the cooldown itself')
            end
        end
    end)

    test(engine .. ': in combat, a cooldown the game cannot answer is left out; out of combat it glows', function()
        local c = make(engine, { open = true })
        c.a.Platform.GetCombatDataPolicy = function() return 'restricted' end
        c.setAura(false)
        local lit = {}
        local glowCooldown = c.a.GlowCooldown

        c.a.GlowCooldown = function(self, spellId, on, ...)
            lit[spellId] = on and true or nil
            return glowCooldown(self, spellId, on, ...)
        end

        -- Commits the rotation with the cooldown, which also makes both engines build their plan again.
        local function commit()
            local record, token = c.a:GetRotationRecordSnapshot(0, c.a.currentRotation)

            record.body.cooldowns = {
                {
                    id = 'shield-missing',
                    type = 'spell',
                    action = 324,
                    conditions = { type = 'NOT', value = { type = 'BUFF', unit = 'player', spell = 324 } },
                },
            }

            local ref = assert(c.a:GetScopedRotationCoordinator():Resolve(0, c.a.currentRotation))
            assert(c.a:CommitRotationDraft(ref, token, record, 'class'))
        end

        commit()
        poll(c)
        assert(lit[324], 'out of combat the cooldown is evaluated and glows')
        c.setCombat(true)
        commit()
        poll(c)
        assert(not lit[324], 'in combat it is left out, as if it were not defined')
        c.setCombat(false)
        commit()
        poll(c)
        assert(lit[324], 'it comes back when combat ends')
    end)

    test(engine .. ': a gate with a missing unit skips the step', function()
        local c = make(engine, { open = nil, why = 'unit-data-unavailable' })
        poll(c)
        assert(c.a.currentSpell == 403 and not c.a.nextWindow.icons[1].gateFrame:IsShown())
    end)
end

test('the gate field is validated', function()
    local c = make('standard', { open = true })
    local validate = c.a.RotationData.ValidateBody

    local function check(gate, stepType)
        local body = {
            cooldowns = {},
            rotation = { { id = 'x', type = stepType or 'spell', action = 403, gate = gate, conditions = {} } },
        }

        local result = validate(body, c.a:GetRotationValidationOptions())
        return result.valid, result.diagnostics
    end

    assert(check(GATE), 'a good gate')
    assert(not check({ unit = 'focus', kind = 'health', operator = 'LESSTHAN', value = 20 }), 'bad unit')
    assert(not check({ unit = 'target', kind = 'mana', operator = 'LESSTHAN', value = 20 }), 'bad kind')
    assert(not check({ unit = 'target', kind = 'health', operator = 'EQUALS', value = 20 }), 'bad operator')
    assert(not check({ unit = 'target', kind = 'health', operator = 'LESSTHAN', value = 0 }), 'bad percent')
    assert(not check('x'), 'not a table')
end)

test('the platform builds step curves and hands the game alpha pair through', function()
    local c = make('standard', { open = true })
    local env = c.e
    local curves = {}

    env.C_CurveUtil = {
        CreateCurve = function()
            local curve = { points = {} }

            function curve:SetType(kind)
                self.kind = kind
            end

            function curve:AddPoint(x, y)
                self.points[#self.points + 1] = { x, y }
            end

            curves[#curves + 1] = curve
            return curve
        end,
    }

    env.Enum.LuaCurveType = { Step = 1 }
    env.UnitHealthPercent = function(unit, predicted, curve) return curve end
    c.load('Platform/gates.lua')
    local open, closed = c.a.Platform:GetGateAlphas(GATE)
    assert(open and closed and open ~= closed, 'two curves')
    assert(open.kind == 1 and open.points[1][2] == 1 and open.points[2][1] == .2 and open.points[2][2] == 0, 'below')
    assert(closed.points[1][2] == 0 and closed.points[2][2] == 1, 'inverse')
    env.UnitHealthPercent = nil
    assert(c.a.Platform:GetGateAlphas(GATE) == nil, 'no API')
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
