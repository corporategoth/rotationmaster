-- Live condition bars on rotation, cooldown, Branch/Stop and switch condition
-- fields (UI/rotation_cards.lua, UI/rotation_editor.lua): a thin stripe on
-- the field's left edge, from the real evaluator, at the General "Live Status
-- Update Frequency" (profile.live_config_update), only while the editor is
-- open and visible; 0 turns them off.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function cond(tag)
    return { type = tag }
end

local function body()
    return {
        name = 'Mine',
        switch = cond('SW'),
        rotation = {
            { id = 'yes', type = 'spell', action = 100, conditions = cond('YES') },
            { id = 'no', type = 'spell', action = 100, conditions = cond('NO') },
            { id = 'odd', type = 'spell', action = 100, conditions = cond('ODD') },
            { id = 'plain', type = 'spell', action = 100, conditions = {} },
            { id = 'stop', type = 'stop', conditions = cond('YES') },
            {
                id = 'branch',
                type = 'branch',
                conditions = cond('NO'),
                onTrue = {},
                onFalse = { { id = 'inner', type = 'spell', action = 100, conditions = cond('YES') } },
            },
            { id = 'forced', type = 'branch', mode = 'true', conditions = cond('NO'), onTrue = {}, onFalse = {} },
        },
        cooldowns = { { id = 'cd', type = 'spell', action = 100, conditions = cond('YES') } },
    }
end

local function fixture(interval)
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    f.nativeFrames = frames
    dofile('tests/fixtures/spell_editbox.lua')(f, create)
    a.db.profile.rotations = { [0] = { mine = body() } }
    a.configPaneGeneration = 1
    a.db.profile.live_config_update = interval

    function a:GetEditableRotation(spec, id)
        return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id]
    end

    function a:GetDefaultIdForRuntime(_, id)
        if id == 'builtin' then
            return 'pack'
        end
    end

    function a:ListDefaultRotations()
        return {
            {
                id = 'pack',
                runtimeKey = 'builtin',
                name = 'Mine',
                description = 'Preview',
                enabled = true,
                envelope = { body = body() },
            },
        }
    end

    function a:GetImportValidationOptions()
        return {}
    end

    function a:validateCondition()
        return true
    end

    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    a.EvaluateNextAction = function() end
    -- The live state, the evaluator over it, and the timers.
    local live = { YES = 'match', NO = 'no-match', ODD = 'unavailable', SW = 'match' }
    local evaluated = 0

    function a:evaluateConditionResult(value, context)
        evaluated = evaluated + 1
        assert(type(context) == 'table' and context.stepId ~= nil, 'no step context')
        local status = live[value.type] or 'match'

        if status == 'unavailable' then
            return { status = 'unavailable', reason = 'target-unreadable' }
        end

        return { status = status }
    end

    function a:SwitchConditionMatchesNow(value)
        evaluated = evaluated + 1
        local s = live[value.type]

        if s == 'unavailable' then
            return nil
        end

        return s == 'match'
    end

    local timers = {}

    function a:ScheduleRepeatingTimer(fn, delay)
        local t = { fn = fn, delay = delay }
        timers[#timers + 1] = t
        return t
    end

    function a:CancelTimer(t)
        t.cancelled = true
    end

    local clock = 100
    f.env.GetTime = function() return clock end

    for _, file in ipairs({
        'Platform/spells.lua', 'Data/plain.lua', 'Data/tags.lua', 'Data/rotation_tree.lua', 'Data/rotation_draft.lua',
        'Data/validation.lua', 'Core/rotation_editor.lua', 'Core/rotation_workspace.lua', 'Core/rotation_tags.lua',
        'Core/rotation_canvas.lua', 'UI/window.lua'
    }) do
        f.load(file)
    end

    for _, file in ipairs({
        'UI/rotation_cards.lua', 'UI/rotation_canvas.lua', 'UI/color_picker.lua', 'UI/rotation_effect_fields.lua',
        'UI/rotation_fields.lua', 'UI/rotation_navigation.lua', 'UI/rotation_metadata.lua', 'UI/rotation_view.lua',
        'UI/rotation_editor.lua'
    }) do
        local h = io.open(file)

        if h then
            h:close()
            f.load(file)
        end
    end

    dofile('tests/fixtures/rotation_header_backend.lua')(a, f.env.DEFAULT, f.env.NEW)
    local parent = create('Frame')
    parent:SetSize(740, 600)

    local env = {
        live = live,
        timers = timers,
        evaluated = function() return evaluated end,
        advance = function(s)
            clock = clock + s
        end,
    }

    function env.running()
        local n = 0

        for _, t in ipairs(timers) do
            if not t.cancelled then
                n = n + 1
            end
        end

        return n
    end

    function env.tick()
        for _, t in ipairs(timers) do
            if not t.cancelled then
                t.fn()
            end
        end
    end

    return f, parent, env
end

local function visibleCard(pane, id)
    for _, c in ipairs(pane.canvas.cards) do
        if c.model and c.model.id == id and c.frame:IsShown() then
            return c
        end
    end
end

local function card(pane, id)
    local snapshot = pane.workspace:Snapshot()
    local section = 'rotation'

    for _, step in ipairs(snapshot.cooldowns or {}) do
        if step.id == id then
            section = 'cooldowns'
            break
        end
    end

    if pane.view.section ~= section then
        pane:SelectContent(section)
    end

    return visibleCard(pane, id)
end

local function bar(c)
    return c.liveBar:IsShown() and c.liveBar.state
end

local GREEN, RED, GREY = { .3, .85, .4, 1 }, { .9, .27, .22, 1 }, { .55, .55, .55, .55 }

local function painted(c, want)
    local got = c.liveBar.color
    return got and got[1] == want[1] and got[2] == want[2] and got[3] == want[3] and got[4] == want[4]
end

local function tooltip(f)
    local lines = {}

    f.env.GameTooltip = {
        SetOwner = function() end,
        SetText = function(_, text, r, g, b)
            for i = #lines, 1, -1 do
                lines[i] = nil
            end

            lines[1] = { text, r, g, b }
        end,
        AddLine = function(_, text, r, g, b)
            lines[#lines + 1] = { text, r, g, b }
        end,
        Show = function() end,
        Hide = function() end,
        IsOwned = function() return true end,
    }

    return lines
end

local CLICK = 'Click condition text on any card to view or edit its conditions.'

test('bars show matching, not matching and unavailable; no condition shows nothing; no dot remains', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    assert(env.running() == 1 and env.timers[1].delay == 2, 'timer not started at the live update frequency')
    local yes, no, odd = card(pane, 'yes'), card(pane, 'no'), card(pane, 'odd')
    assert(bar(yes).status == 'satisfied' and painted(yes, GREEN), 'yes')
    assert(bar(no).status == 'unsatisfied' and painted(no, RED), 'no')
    assert(bar(odd).status == 'unavailable' and painted(odd, GREY) and bar(odd).reason == 'target-unreadable', 'odd')
    assert(not card(pane, 'plain').liveBar:IsShown(), 'a card with no condition has a bar')
    assert(bar(card(pane, 'stop')).status == 'satisfied', 'Stop')

    assert(
        bar(card(pane, 'branch')).status == 'unsatisfied' and bar(card(pane, 'inner')).status == 'satisfied',
        'Branch and its child'
    )

    assert(not card(pane, 'forced').liveBar:IsShown(), 'a forced branch (condition skipped) has a bar')
    assert(yes.live == nil and pane.switchLive == nil, 'the old dot is still there')
end)

test('the bar is a thin stripe inside the condition field, on its left edge', function()
    local f, parent = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))

    for _, id in ipairs({ 'yes', 'branch', 'inner', 'stop', 'cd' }) do
        local c = card(pane, id)
        local stripe = c.liveBar
        assert(stripe:GetParent() == c.condition, id .. ': bar is not inside the condition field')
        local point, relative, relativePoint, x, y = stripe:GetPoint(1)

        assert(
            point == 'TOPLEFT' and relative == c.condition and relativePoint == 'TOPLEFT' and x == 0 and y == 0,
            id .. ': bar not on the field\'s left edge'
        )

        local point2, relative2 = stripe:GetPoint(2)
        assert(point2 == 'BOTTOMLEFT' and relative2 == c.condition, id .. ': bar does not span the field')
        assert(stripe.width == 3, id .. ': bar width ' .. tostring(stripe.width))
    end

    assert(bar(card(pane, 'cd')).status == 'satisfied', 'cooldown bar')
end)

test(
    'the condition tooltip leads with the match state on its own line, coloured, then the click hint, then when it was checked',
    function()
        local f, parent, env = fixture(2)
        local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
        env.advance(3)
        local lines = tooltip(f)
        local yes = card(pane, 'yes')
        yes.condition.scripts.OnEnter(yes.condition)

        assert(
            lines[1][1] == 'Currently Matches' and lines[1][2] == GREEN[1] and lines[1][3] == GREEN[2],
            'first line ' .. tostring(lines[1] and lines[1][1])
        )

        assert(lines[2][1] == CLICK, 'second line ' .. tostring(lines[2] and lines[2][1]))
        assert(lines[3][1] == 'Checked 3 seconds ago.', 'third line ' .. tostring(lines[3] and lines[3][1]))
        lines = tooltip(f)
        local no = card(pane, 'no')
        no.condition.scripts.OnEnter(no.condition)
        assert(lines[1][1] == 'Does Not Currently Match' and lines[1][2] == RED[1] and lines[2][1] == CLICK)
        lines = tooltip(f)
        local odd = card(pane, 'odd')
        odd.condition.scripts.OnEnter(odd.condition)

        assert(
            lines[1][1] == 'Unavailable: target-unreadable' and lines[1][2] == GREY[1] and lines[2][1] == CLICK,
            tostring(lines[1][1])
        )

        lines = tooltip(f)
        local plain = card(pane, 'plain')
        plain.condition.scripts.OnEnter(plain.condition)
        assert(#lines == 1 and lines[1][1] == CLICK, 'a field without a condition gained a state line')
    end
)

test('each tick re-evaluates; a changed state repaints the bar', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    env.live.NO = 'match'
    env.tick()
    assert(bar(card(pane, 'no')).status == 'satisfied' and painted(card(pane, 'no'), GREEN), 'tick did not repaint')
    env.live.YES = 'unavailable'
    env.tick()
    assert(bar(card(pane, 'yes')).status == 'unavailable' and painted(card(pane, 'yes'), GREY))
end)

test('the switch condition field has the same bar and tooltip', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    local stripe = pane.switchLiveBar
    assert(stripe:IsShown() and stripe.state.status == 'satisfied' and stripe:GetParent() == pane.switch)
    local lines = tooltip(f)
    pane.switch.scripts.OnEnter(pane.switch)

    assert(
        lines[1][1] == 'Currently Matches' and lines[2][1]:sub(1, #CLICK) == CLICK,
        'switch tooltip ' .. tostring(lines[1][1])
    )

    env.live.SW = 'no-match'
    env.tick()
    assert(stripe.state.status == 'unsatisfied')
    env.live.SW = 'unavailable'
    env.tick()
    assert(stripe.state.status == 'unavailable')
end)

test('closing the editor cancels the timer; nothing is evaluated while closed', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    local stale = env.timers[1].fn
    pane:Release()
    assert(env.running() == 0, 'timer survived the closed editor')
    local before = env.evaluated()
    stale()
    env.tick()
    assert(env.evaluated() == before, 'a closed editor evaluated conditions')
    assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    assert(env.running() == 1)
end)

test('a hidden editor stops its timer at the next tick', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    pane.frame:Hide()
    local before = env.evaluated()
    env.tick()
    assert(env.running() == 0 and env.evaluated() == before, 'hidden editor kept evaluating')
end)

test('0 turns the bars off: no timer, no evaluation, no bars', function()
    local f, parent, env = fixture(0)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    assert(env.running() == 0 and env.evaluated() == 0)
    assert(not card(pane, 'yes').liveBar:IsShown() and not pane.switchLiveBar:IsShown())
end)

test('changing the frequency restarts the open editor\'s timer; 0 clears the bars', function()
    local f, parent, env = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'mine'))
    f.addon.db.profile.live_config_update = 5
    f.addon:RestartLiveStatus()
    assert(env.running() == 1 and env.timers[#env.timers].delay == 5)
    f.addon.db.profile.live_config_update = 0
    f.addon:RestartLiveStatus()
    assert(env.running() == 0 and not card(pane, 'yes').liveBar:IsShown())
    pane:Release()
    f.addon.db.profile.live_config_update = 3
    f.addon:RestartLiveStatus()
    assert(env.running() == 0, 'a closed editor got a timer')
end)

test('Built In read-only views get the bars', function()
    local f, parent = fixture(2)
    local pane = assert(f.addon:CreateRotationEditor(parent, 0, 'builtin'))
    assert(pane.workspace.readOnly and bar(card(pane, 'yes')).status == 'satisfied')
end)

test('the tooltip names the advised step; the not-on-your-bars warning stays on its own row', function()
    local f, parent = fixture(2)
    local a = f.addon
    a.currentSpec = 0
    a.currentRotation = 'mine'
    a.GetRecentRecommendations = function() return { { rotation = 'mine', id = 'yes', spell = 100 } } end

    a.GetStepBinding = function(_, step)
        if step.id == 'no' then
            return false
        end

        return true
    end

    a.WatchButtonIndex = function() end
    local pane = assert(a:CreateRotationEditor(parent, 0, 'mine'))
    local lines = tooltip(f)
    local yes = card(pane, 'yes')
    yes.condition.scripts.OnEnter(yes.condition)

    assert(
        lines[1][1] == 'Currently Matches'
            and lines[2][1] == CLICK
            and lines[3][1] == 'Rotation Master is advising this step now.',
        'advising line order'
    )

    local no = card(pane, 'no')
    assert(no.unbound:IsShown() and no.unbound.tooltip:find('this step is skipped'), 'warning row moved')
    assert(bar(no).status == 'unsatisfied')
end)

test('the addon schedules no live-status timer of its own (zero cost with the editor closed)', function()
    local root = assert(io.popen('pwd'):read('*l'))

    local c = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)({
        buttons = true,
        target = true,
        poll = .15,
    })

    local scheduled = {}
    local schedule = c.a.ScheduleRepeatingTimer

    c.a.ScheduleRepeatingTimer = function(self, method, delay, ...)
        scheduled[#scheduled + 1] = method
        return schedule(self, method, delay, ...)
    end

    c.a.db.profile.live_config_update = 2
    c.a.db.profile.enable = false
    c.e.GetAddOnMetadata = c.e.GetAddOnMetadata or function() return 'test' end
    c.a:OnEnable()

    for _, method in ipairs(scheduled) do
        assert(method ~= 'UpdateCurrentCondition', 'OnEnable scheduled the live-status timer')
    end

    assert(c.a.conditionEvalTimer == nil, 'a live-status timer is running with no editor open')
end)

finish()
