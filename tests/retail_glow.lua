-- Retail action bars: the spell -> button -> glow path on a Retail 12.x model,
-- and the /rm debug glow diagnostic (Diagnostics/glow.lua) that reports
-- where that path stops.
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

-- The whole addon (tests/fixtures/wholepoll_shaman.lua), polling, with four
-- action buttons; the diagnostic is loaded as the TOC loads it.
local function whole(engine)
    local build = assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace', root, true, root, true)
    local c = build({ buttons = true, target = true, poll = .15 })
    c.a.db.profile.idle_poll = 0
    assert(c.a:SetEvaluationEngine(engine or 'standard'))
    -- The fixture's AceEvent only counts SendMessage; give it message
    -- delivery, as the client's AceEvent has, before the diagnostic registers.
    local events = c.e.LibStub('AceEvent-3.0')
    local send, handlers = events.SendMessage, {}

    events.RegisterMessage = function(_, message, fn)
        handlers[message] = handlers[message] or {}
        table.insert(handlers[message], fn)
    end

    events.SendMessage = function(self, message, ...)
        send(self, message, ...)

        for _, fn in ipairs(handlers[message] or {}) do
            fn(message, ...)
        end
    end

    c.load('Diagnostics/glow.lua')
    c.e.RotationMasterDB = c.e.RotationMasterDB or {}
    c.printed = {}

    c.a.print = function(_, message, ...)
        c.printed[#c.printed + 1] = string.format(message, ...)
    end

    c.a.ShowConditionText = function(_, text, heading)
        c.shown, c.heading = text, heading
    end

    for _ = 1, 4 do
        c.tick()
    end

    return c
end

local function find(lines, pattern)
    for _, line in ipairs(lines) do
        if line:find(pattern) then
            return line
        end
    end
end

-- Diagnostic ------------------------------------------------------------------
test('diagnostic: walks the chain, names the step, the button and the glow, and saves the report', function()
    local c = whole()
    local lines, stop = c.a:RunGlowDiagnostic()
    assert(c.a.currentSpell == 403, 'fixture did not recommend 403: ' .. tostring(c.a.currentSpell))
    assert(find(lines, '^index: 4 buttons, 4 spells'), 'index summary missing')

    assert(
        find(lines, '^ActionButton1%-12: 4 frames, type=action 4, holding an action 4, indexed 4, read errors 0'),
        'bar summary missing'
    )

    assert(find(lines, '^  #1 spell action=403 conditions=match'), 'first step missing')
    assert(find(lines, 'spell 403 .* mapped=true'), 'mapping missing')

    assert(
        find(lines, 'ready=true known=true usable=true noPower=false cooldownReady=true range=true'),
        'readiness breakdown missing'
    )

    assert(find(lines, 'currentSpell=403 lastRequest spell=403 .* result=lit buttonsLit=1'), 'glow request missing')
    assert(find(lines, '^expected=403'), 'expected spell missing')
    assert(stop and stop:find('^none'), 'unexpected stop: ' .. tostring(stop))
    assert(c.heading == 'Glow diagnostic' and c.shown == table.concat(lines, '\n'), 'report window not opened')
    local saved = c.e.RotationMasterDB.diagnostics.glow
    assert(#saved == 1 and saved[1].lines == lines, 'report not saved to RotationMasterDB.diagnostics.glow')
end)

test('diagnostic: keeps at most five reports, and shows the newest on request', function()
    local c = whole()

    for _ = 1, 7 do
        c.a:RunGlowDiagnostic()
    end

    local saved = c.e.RotationMasterDB.diagnostics.glow
    assert(#saved == 5, 'reports not capped: ' .. #saved)
    c.shown = nil
    c.a:HandleDebugCommand('glow show')
    assert(c.shown == table.concat(saved[5].lines, '\n'), 'show did not open the newest report')
    c.a:HandleDebugCommand('nonsense')
    assert(c.printed[#c.printed]:find('Usage: /rm debug glow'), 'usage not printed')
    local reports = 0

    c.a.ShowLuaEditorInputReport = function()
        reports = reports + 1
    end

    c.a:HandleDebugCommand(' editor')
    assert(reports == 1, '/rm debug editor did not open the Lua input report')
    assert(c.printed[#c.printed]:find('/rm debug editor', 1, true), 'usage does not name /rm debug editor')
end)

test('diagnostic: names the first read error when the scan indexes nothing', function()
    local c = whole()

    c.e.GetActionInfo = function()
        error('modelled failure')
    end

    c.a:Fetch()

    for _ = 1, 3 do
        c.tick()
    end

    local lines, stop = c.a:RunGlowDiagnostic()
    assert(stop:find('^the button scan indexed no buttons; first read error: .*modelled failure'), stop)
    assert(find(lines, 'read errors 4'), 'per-bar error count missing')
end)

test('diagnostic: an unready spell is reported with the piece that failed', function()
    local c = whole()
    c.setSpellReady(false)

    for _ = 1, 3 do
        c.tick()
    end

    local lines = c.a:RunGlowDiagnostic()
    assert(find(lines, 'cooldownReady=false'), 'cooldown piece missing')
end)

test('diagnostic: a watch appends one line per second to the saved report', function()
    local c = whole()
    local timers = {}

    c.a.ScheduleRepeatingTimer = function(_, fn, delay)
        local t = { fn = fn, delay = delay }
        timers[#timers + 1] = t
        return t
    end

    c.a.CancelTimer = function(_, t)
        t.cancelled = true
    end

    local lines = c.a:RunGlowDiagnostic('3')
    assert(#timers == 1 and timers[1].delay == 1, 'watch timer not scheduled')

    for _ = 1, 3 do
        timers[1].fn()
    end

    assert(timers[1].cancelled, 'watch did not stop')
    local watch = 0

    for _, line in ipairs(lines) do
        if line:find('^t=') then
            watch = watch + 1
        end
    end

    assert(watch == 3, 'watch lines: ' .. watch)
    assert(find(lines, '#1:selected=403'), 'watch line lacks the step verdict')
    assert(c.e.RotationMasterDB.diagnostics.glow[1].lines == lines, 'watch lines are not in the saved report')
end)

test('diagnostic: costs nothing until run (no frames, timers or saved data at load)', function()
    local c = whole()
    assert(c.e.RotationMasterDB.diagnostics == nil, 'diagnostic wrote saved data before it was run')
end)

-- Retail 12.x action bars --------------------------------------------------------
-- Modelled from Blizzard's UI source (Gethe/wow-ui-source live b9be9379, 12.0.5):
--   * Blizzard_ActionBar/Shared/ActionBar.lua names the buttons ActionButton1-12
--     and <bar>Button1-12 (MultiBarBottomLeft ... MultiBar5-7), CheckButtons
--     parented to a per-button container;
--   * ActionBarActionButtonMixin:OnLoad sets the "type" attribute to "action"
--     and no "action" attribute; the slot is self.action (CalculateAction from
--     the bar's actionpage), returned by GetPagedID;
--   * HasAction, IsUsableAction, GetActionCooldown, IsActionInRange... live in
--     C_ActionBar; the globals come only from Blizzard_DeprecatedActionBar when
--     the loadDeprecationFallbacks CVar is set (not set here). GetActionInfo
--     stays a global;
--   * BOOKTYPE_SPELL and BOOKTYPE_PET do not exist at all since 11.0
--     (Blizzard_Deprecated/11_0_0_SpellBookAPITransitionGuide.lua), even with
--     the fallbacks loaded.
local BLACKOUT_KICK, TIGER_PALM, ROLL = 100784, 100780, 109132

local function retailBars(c, layout)
    local e, a = c.e, c.a
    e.HasAction, e.IsUsableAction, e.GetActionCooldown, e.IsActionInRange = nil, nil, nil, nil
    e.BOOKTYPE_SPELL, e.BOOKTYPE_PET = nil, nil

    e.C_ActionBar = {
        HasAction = function(slot)
            assert(type(slot) == 'number' and slot > 0, 'invalid slot')
            return layout[slot] ~= nil
        end,
        FindSpellActionButtons = function(spell)
            local slots = {}

            for slot, id in pairs(layout) do
                if id == spell then
                    slots[#slots + 1] = slot
                end
            end

            table.sort(slots)
            return slots
        end,
    }

    e.GetActionInfo = function(slot)
        local id = layout[slot]

        if id then
            return 'spell', id
        end
    end

    local frames = {}

    local function bar(prefix, page)
        for i = 1, 12 do
            local name = prefix .. 'Button' .. i
            local container = e.CreateFrame('Frame', prefix .. 'ButtonContainer' .. i, e.UIParent)
            local button = e.CreateFrame('CheckButton', name, container)
            button:SetSize(45, 45)
            local attributes = { type = 'action', ['useparent-actionpage'] = true }
            button.GetAttribute = function(_, key) return attributes[key] end
            button.GetName = function() return name end
            button.action = i + (page - 1) * 12
            button.GetPagedID = function(self) return self.action end
            e[name] = button
            frames[name] = button
        end
    end

    bar('Action', 1)
    bar('MultiBarBottomLeft', 6)
    bar('MultiBar5', 13)
    a:Fetch()
    return frames
end

local function lit(button)
    local overlay = type(button.rmOverlays) == 'table' and button.rmOverlays.next
    return overlay and overlay:IsShown() == true or false
end

local function custom(a, id, body)
    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = id },
    }

    assert(a:CommitRotationDraft(reference, nil, { body = body }, 'class'))
end

local function select(c, name)
    c.a:HandleCommand('set ' .. name)

    if c.a.AssistedHighlight then
        c.a.AssistedHighlight:OnEvent('ROTATIONMASTER_ROTATION')
    end

    for _ = 1, 4 do
        c.tick()
    end
end

-- The whole engine on the Retail bars, with Blizzard's suggestion modelled.
local function retail(engine, layout, state)
    local c = whole(engine)
    state = state or {}
    state.cvars = state.cvars or { assistedCombatHighlight = '0' }
    local e, a = c.e, c.a

    e.C_AssistedCombat = {
        IsAvailable = function() return true, '' end,
        GetNextCastSpell = function() return state.next end,
        GetRotationSpells = function() return { BLACKOUT_KICK, TIGER_PALM } end,
        GetActionSpell = function() return nil end,
    }

    e.AssistedCombatManager = {}

    e.C_CVar = {
        GetCVar = function(name) return state.cvars[name] end,
        SetCVar = function(name, value)
            state.cvars[name] = tostring(value)

            if a.AssistedHighlight then
                a.AssistedHighlight:OnEvent('CVAR_UPDATE', name, tostring(value))
            end
        end,
    }

    e.InCombatLockdown = function() return false end
    c.load('Platform/assisted_combat.lua')
    c.load('Conditions/assisted.lua')
    c.load('Core/assisted_highlight.lua')
    a.db.char = a.db.char or {}
    a.AssistedHighlight:OnEvent('PLAYER_ENTERING_WORLD')
    c.frames = retailBars(c, layout or { [1] = BLACKOUT_KICK, [2] = TIGER_PALM })
    return c, state
end

local function litNames(c)
    local names = {}

    for name, button in pairs(c.frames) do
        if lit(button) then
            names[#names + 1] = name
        end
    end

    table.sort(names)
    return table.concat(names, ',')
end

for _, engine in ipairs({ 'standard', 'lean' }) do
    test(
        'retail 12 bars (' .. engine .. '): the top spell step lights ActionButton1 with no deprecated globals',
        function()
            local c = retail(engine)

            custom(c.a, 'top', {
                name = 'Top',
                priority = 0,
                cooldowns = {},
                rotation = {
                    { id = 'bok', type = 'any', action = BLACKOUT_KICK, conditions = {} },
                    { id = 'blizzard', type = 'assisted', conditions = {} },
                },
            })

            select(c, 'Top')
            assert(c.a:FindSpell({ BLACKOUT_KICK }) == BLACKOUT_KICK, 'Blackout Kick on ActionButton1 was not indexed')
            assert(c.a.currentSpell == BLACKOUT_KICK, 'recommended ' .. tostring(c.a.currentSpell))
            assert(litNames(c) == 'ActionButton1', 'lit: ' .. litNames(c))
            assert(c.a:GetEvaluationEngine() == engine)
        end
    )

    test(
        'retail 12 bars ('
            .. engine
            .. '): Blizzard\'s suggestion lights its button in rm and both, never in blizzard mode',
        function()
            for _, mode in ipairs({ 'rm', 'both', 'blizzard' }) do
                local c, state = retail(engine, nil, { next = TIGER_PALM })
                c.a.db.profile.assisted_highlight = mode

                custom(c.a, 'assisted', {
                    name = 'Assisted',
                    priority = 0,
                    cooldowns = {},
                    rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } },
                })

                select(c, 'Assisted')
                assert(c.a.currentSpell == TIGER_PALM, mode .. ': recommended ' .. tostring(c.a.currentSpell))
                local want = mode == 'blizzard' and '' or 'ActionButton2'
                assert(litNames(c) == want, mode .. ': lit ' .. litNames(c) .. ' (want ' .. want .. ')')

                assert(
                    (state.cvars.assistedCombatHighlight == '1') == (mode ~= 'rm'),
                    mode .. ': CVar ' .. state.cvars.assistedCombatHighlight
                )
            end
        end
    )
end

test('retail 12 bars: a suggested override lights the button holding its base spell', function()
    local OVERRIDE = 1249999
    local c = retail('standard', nil, { next = OVERRIDE })
    c.e.C_Spell.GetBaseSpell = function(id) return id == OVERRIDE and TIGER_PALM or id end
    c.e.C_Spell.GetOverrideSpell = function(id) return id == TIGER_PALM and OVERRIDE or id end

    custom(c.a, 'assisted', {
        name = 'Assisted',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } },
    })

    select(c, 'Assisted')
    assert(litNames(c) == 'ActionButton2', 'lit: ' .. litNames(c))
end)

test('retail 12 bars: action bars 6-8 (MultiBar5-7) are scanned', function()
    local c = retail('standard', { [145] = ROLL })

    custom(c.a, 'roll', {
        name = 'Roll',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'roll', type = 'spell', action = ROLL, conditions = {} } },
    })

    select(c, 'Roll')
    assert(litNames(c) == 'MultiBar5Button1', 'lit: ' .. litNames(c))
end)

test('retail 12 bars: the diagnostic finds the button, the step and a lit frame', function()
    local c = retail('standard')

    custom(c.a, 'top', {
        name = 'Top',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'bok', type = 'any', action = BLACKOUT_KICK, conditions = {} } },
    })

    select(c, 'Top')
    local lines, stop = c.a:RunGlowDiagnostic()
    assert(find(lines, 'HasAction=missing C_ActionBar.HasAction=present'), 'API presence not reported')

    assert(
        find(lines, '^ActionButton1%-12: 12 frames, type=action 12, holding an action 2, indexed 2, read errors 0'),
        'scan summary'
    )

    assert(find(lines, '^  ActionButton1 type=action slot=1 .*spell=100784 indexed=100784'), 'ActionButton1 row')
    assert(find(lines, 'blizzardSlots=%[1%]'), 'Blizzard slot cross-check missing')
    assert(stop:find('^none'), stop)
end)

-- The restricted Retail client ----------------------------------------------------
-- tests/fixtures/retail_premade_model_a.lua with the real restricted policy
-- (Midnight secrets, C_Spell/C_SpellBook readiness), plus buttons.lua.
local function restricted()
    local M = dofile('tests/fixtures/retail_premade_model_a.lua')
    local f, s = M.new('monk', 'MONK', 268, { policy = 'restricted' })
    local a, e = f.addon, f.env
    assert(a.Platform:GetClientInfo().combatDataPolicy == 'restricted')
    dofile('tests/fixtures/native_ui.lua')(e)
    local create = e.CreateFrame

    e.CreateFrame = function(...)
        local frame = create(...)
        local texture = frame.CreateTexture

        frame.CreateTexture = function(...)
            local t = texture(...)
            t.SetBlendMode = t.SetBlendMode or function() end
            t.SetRotation = t.SetRotation or function() end
            return t
        end

        return frame
    end

    e.tinsert, e.tremove = table.insert, table.remove

    f.libraries['LibCustomGlow-1.0'] = {
        PixelGlow_Stop = function() end,
        AutoCastGlow_Stop = function() end,
        ButtonGlow_Stop = function() end,
    }

    e.C_AddOns.IsAddOnLoaded = function() return false end
    -- LibStub is a callable table in the client (LibStub:GetLibrary).
    local call = e.LibStub

    e.LibStub = setmetatable({
        GetLibrary = function(_, name, silent)
            if silent then
                local ok, lib = pcall(call, name)
                return ok and lib or nil
            end

            return call(name)
        end,
    }, { __call = function(_, name, silent) return call(name, silent) end })

    f.load('Platform/macros.lua')
    f.load('Core/presentation.lua')
    f.load('Functions/collections.lua')
    f.load('buttons.lua')
    a.uuid = a.uuid or function() return 'overlay' end
    a.ScheduleRepeatingTimer = function() return {} end
    a.CancelTimer = function() end
    a.db.global.effects = { ping = { type = 'texture', texture = 'Interface\\Cooldown\\ping4' } }
    a.db.profile.effect = 'ping'
    a.db.profile.magnification = 1.4
    a.db.profile.setpoint = 'CENTER'
    a.db.profile.color = { r = 1, g = 1, b = 1, a = 1 }
    local c = { a = a, e = e, s = s, f = f, load = f.load, tick = function() end }
    return c
end

test('restricted retail: Blizzard bars are indexed through C_ActionBar alone', function()
    local c = restricted()
    local frames = retailBars(c, { [1] = BLACKOUT_KICK, [2] = TIGER_PALM })

    assert(
        c.a:FindSpell({ BLACKOUT_KICK }) == BLACKOUT_KICK and c.a:FindSpell({ TIGER_PALM }) == TIGER_PALM,
        'not indexed'
    )

    c.a:GlowNextSpell(TIGER_PALM)
    assert(lit(frames.ActionButton2) and not lit(frames.ActionButton1), 'wrong frame lit')
    local overlay = frames.ActionButton2.rmOverlays.next

    assert(
        overlay:GetParent() == frames.ActionButton2
            and overlay:GetFrameLevel() == frames.ActionButton2:GetFrameLevel() + 1,
        'overlay not above its button'
    )

    c.a:GlowNextSpell(TIGER_PALM, nil, true)
    assert(not lit(frames.ActionButton2) and c.a:IsGlowing(TIGER_PALM, nil, true), 'a hidden glow still lit the button')
end)

test('restricted retail: a talent override on the button maps from its base spell, and the reverse', function()
    local c = restricted()
    local OVERRIDE = 1249999
    c.s.base = { [OVERRIDE] = TIGER_PALM }
    c.s.override = { [TIGER_PALM] = OVERRIDE }
    -- The slot reports the override; a step names the base spell.
    local frames = retailBars(c, { [2] = OVERRIDE })
    assert(c.a:FindSpell({ TIGER_PALM }) == TIGER_PALM, 'base spell did not map to the overridden button')
    c.a:GlowNextSpell(TIGER_PALM)
    assert(lit(frames.ActionButton2), 'base spell glow missed the button')
    c.a:GlowClear()
    -- The slot reports the base; the override (e.g. Blizzard's suggestion) maps too.
    frames = retailBars(c, { [2] = TIGER_PALM })
    assert(c.a:FindSpell({ OVERRIDE }) == OVERRIDE, 'override did not map to the base button')
    c.a:GlowNextSpell(OVERRIDE)
    assert(lit(frames.ActionButton2), 'override glow missed the button')
    -- Slot highlighting lights the aliased button once.
    local count = 0
    local glow = c.a.Glow

    c.a.Glow = function(self, button, id, ...)
        if id == 'highlight' then
            count = count + 1
        end

        return glow(self, button, id, ...)
    end

    c.a:HighlightSlots({ 2 })
    assert(count == 1, 'slot highlighted ' .. count .. ' times')
end)

test(
    'restricted retail: readiness from never-secret flags in combat; cooldown, power and range still decide',
    function()
        local c = restricted()
        local s, a = c.s, c.a
        s.learn(BLACKOUT_KICK, TIGER_PALM)
        s.ranged(BLACKOUT_KICK, TIGER_PALM)

        local function ready(kind, id)
            return a:NewActionReadiness(100)(kind, id)
        end

        assert(
            ready('spell', BLACKOUT_KICK) and ready('any', BLACKOUT_KICK) and ready('assisted', TIGER_PALM),
            'ready out of combat'
        )

        s.secrets(true)

        assert(
            ready('spell', BLACKOUT_KICK) and ready('any', BLACKOUT_KICK),
            'secret cooldown times made a ready spell unready'
        )

        s.cooling(BLACKOUT_KICK, 5)
        assert(not ready('spell', BLACKOUT_KICK), 'a spell on its own cooldown read ready')
        s.cooling(BLACKOUT_KICK, nil)
        s.power[BLACKOUT_KICK] = true
        assert(not ready('spell', BLACKOUT_KICK), 'a spell without power read ready')
        s.power[BLACKOUT_KICK] = nil
        s.range[BLACKOUT_KICK] = false
        assert(not ready('spell', BLACKOUT_KICK), 'out of range read ready')
    end
)

test('restricted retail: vehicle and override buttons are judged through C_ActionBar', function()
    local c = restricted()
    local a, e = c.a, c.e
    local frames = retailBars(c, { [133] = 77777 })
    local VEHICLE = e.CreateFrame('CheckButton', 'OverrideActionBarButton1', e.UIParent)

    VEHICLE.GetAttribute = function(_, key)
        if key == 'type' then
            return 'action'
        end
    end

    VEHICLE.action = 133
    VEHICLE.GetPagedID = function(self) return self.action end
    e.OverrideActionBarButton1 = VEHICLE
    a:Fetch()
    local info = { startTime = c.s.SECRET or 0, duration = 0, isEnabled = true, isActive = false }

    e.C_ActionBar.IsUsableAction = function(slot)
        assert(slot == 133)
        return true, false
    end

    e.C_ActionBar.GetActionCooldown = function(slot)
        assert(slot == 133)
        return info
    end

    e.C_ActionBar.IsActionInRange = function() return nil end
    local SECRET = dofile('tests/fixtures/retail_premade_model_a.lua').SECRET
    e.issecretvalue = function(v) return rawequal(v, SECRET) end
    info.startTime, info.duration = SECRET, SECRET
    assert(a:IsBoundActionReady(77777, 100) == true, 'an inactive cooldown with secret times read unready')
    info.isActive = true
    info.isOnGCD = false
    assert(a:IsBoundActionReady(77777, 100) == false, 'an active own cooldown read ready')
    info.isActive = false
    e.C_ActionBar.IsUsableAction = function() return false, false end
    assert(a:IsBoundActionReady(77777, 100) == false, 'an unusable action read ready')
    assert(frames)
end)

test('Bartender4 and ElvUI (LibActionButton) buttons are indexed on Retail 12', function()
    local c = restricted()
    local a, e = c.a, c.e
    local labButtons = {}

    for i = 1, 2 do
        local button = e.CreateFrame('CheckButton', 'BT4Button' .. i, e.UIParent)
        local slot, name = i, 'BT4Button' .. i
        button.GetName = function() return name end

        button.GetAttribute = function(_, key)
            if key == 'type' then
                return 'action'
            elseif key == 'action' then
                return slot
            end
        end

        labButtons[button] = true
    end

    local lab = { GetAllButtons = function() return labButtons end }
    local stub = e.LibStub
    local libs = { ['LibActionButton-1.0'] = lab }

    e.LibStub = setmetatable(
        { GetLibrary = function(_, name, silent) return libs[name] or (not silent and stub(name) or nil) end },
        {
            __call = function(_, name, silent)
                if libs[name] then
                    return libs[name]
                end

                return stub(name, silent)
            end,
        }
    )

    retailBars(c, { [1] = BLACKOUT_KICK, [2] = TIGER_PALM })
    local names = a:GetSpellButtonNames(TIGER_PALM)
    local found = false

    for _, name in ipairs(names) do
        if name == 'BT4Button2' then
            found = true
        end
    end

    assert(found, 'LibActionButton button not indexed: ' .. table.concat(names, ','))
    libs['LibActionButton-1.0'] = nil
    libs['LibActionButton-1.0-ElvUI'] = lab
    a:Fetch()
    found = false

    for _, name in ipairs(a:GetSpellButtonNames(BLACKOUT_KICK)) do
        if name == 'BT4Button1' then
            found = true
        end
    end

    assert(found, 'ElvUI LibActionButton button not indexed')
end)

test('restricted retail: vehicle, override and possession bars are detected through C_ActionBar', function()
    local c = restricted()
    local a, e = c.a, c.e
    e.HasVehicleActionBar, e.HasOverrideActionBar, e.IsPossessBarVisible = nil, nil, nil
    e.UnitHasVehicleUI = function() return false end
    local bars = {}

    e.C_ActionBar = {
        HasVehicleActionBar = function() return bars.vehicle == true end,
        HasOverrideActionBar = function() return bars.override == true end,
        IsPossessBarVisible = function() return bars.possess == true end,
    }

    assert(a:ReadActionContext() == 'player')
    bars.possess = true
    assert(a:ReadActionContext() == 'possession', 'possession missed')
    bars.override = true
    assert(a:ReadActionContext() == 'override', 'override missed')
    bars.vehicle = true
    assert(a:ReadActionContext() == 'vehicle', 'vehicle missed')
    -- Every current client has C_ActionBar (tests/fixtures/client_api_*.lua); the global
    -- is read only on builds older than that, modelled here past the fixture's guard.
    e.C_ActionBar = nil
    rawset(e, 'HasOverrideActionBar', function() return true end)
    assert(a:ReadActionContext() == 'override', 'legacy global no longer read')
end)

for _, engine in ipairs({ 'standard', 'lean' }) do
    test(
        'retail 12 ('
            .. engine
            .. '): the user\'s rotation, a plain spell step above the suggestion, lights the spell (no BOOKTYPE_SPELL)',
        function()
            -- Live report: Brewmaster, Tiger Palm on ActionButton1, rotation
            -- {spell 100780, assisted}; the suggestion (Keg Smash) is on no bar.
            local c = retail(engine, { [1] = TIGER_PALM, [2] = BLACKOUT_KICK }, { next = 121253 })
            assert(c.e.BOOKTYPE_SPELL == nil)

            custom(c.a, 'user', {
                name = 'User',
                priority = 0,
                cooldowns = {},
                rotation = {
                    { id = 'tp', type = 'spell', action = TIGER_PALM, conditions = {} },
                    { id = 'blizzard', type = 'assisted', conditions = {} },
                },
            })

            select(c, 'User')
            local ids = c.a:GetSpellIds({ type = 'spell', action = TIGER_PALM })
            assert(ids[1] == TIGER_PALM, 'a spell step resolved no spell IDs')
            assert(c.a.currentSpell == TIGER_PALM, 'recommended ' .. tostring(c.a.currentSpell))
            assert(litNames(c) == 'ActionButton1', 'lit: ' .. litNames(c))
            local _, stop = c.a:RunGlowDiagnostic()
            assert(stop:find('^none'), stop)
        end
    )
end

test('diagnostic: each glow is attributed to the step that asked for it, and a clear is recorded', function()
    -- The live report: step #1 could not be selected, so Blizzard's
    -- suggestion drove the glow (Spinning Crane Kick, then nothing for Keg
    -- Smash, which is on no bar).
    local SCK, KEG = 322729, 121253
    local c, state = retail('standard', { [1] = TIGER_PALM, [6] = SCK }, { next = SCK })

    custom(c.a, 'assisted', {
        name = 'Assisted',
        priority = 0,
        cooldowns = {},
        rotation = { { id = 'blizzard', type = 'assisted', conditions = {} } },
    })

    select(c, 'Assisted')
    assert(litNames(c) == 'ActionButton6', 'lit: ' .. litNames(c))
    state.next = KEG

    for _ = 1, 3 do
        c.tick()
    end

    assert(litNames(c) == '' and c.a.currentSpell == nil)
    local lines = c.a:RunGlowDiagnostic()
    assert(find(lines, 'recent t=.*step #1 %(assisted%) recommended 322729'), 'glow not attributed to its step')
    assert(find(lines, 'recent t=.*recommendation cleared'), 'clear not recorded')
    assert(find(lines, 'lastRequest spell=322729 .* clearedAt=[%d.]+'), 'clear time missing')
    assert(find(lines, 'spell 121253 .* mapped=false'), 'unmapped suggestion not shown')
end)

test('diagnostic: says why a step has no spell IDs', function()
    local c = retail('standard', nil, { next = nil })

    custom(c.a, 'two', {
        name = 'Two',
        priority = 0,
        cooldowns = {},
        rotation = {
            { id = 'tp', type = 'spell', action = TIGER_PALM, conditions = {} },
            { id = 'blizzard', type = 'assisted', conditions = {} },
        },
    })

    select(c, 'Two')
    c.e.BOOKTYPE_SPELL = 'book'  -- a client whose spell book type is not the step's
    local lines, stop = c.a:RunGlowDiagnostic()

    assert(
        find(
            lines,
            'no spell IDs: spell step, action 100780: BOOKTYPE_SPELL=book BOOKTYPE_PET=nil; the step type matches no spell book type'
        ),
        'spell explanation missing'
    )

    assert(find(lines, 'no spell IDs: assisted: Blizzard suggests nothing right now'), 'assisted explanation missing')
    assert(stop:find('no spell IDs %(spell step'), stop)
end)

print(pass .. ' passed, ' .. fail .. ' failed')

if fail > 0 then
    os.exit(1)
end
