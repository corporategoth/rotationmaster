-- Actual main/AceDB/native authoring transition contracts.
local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local function prefix(path, returns)
    local s = assert(read(path):match('^(.-)\ntest%('))
    return assert(loadstring(s .. '\nreturn ' .. returns, '@active-transition/' .. path))()
end

local startup, initialize = prefix('tests/startup.lua', 'fixture,initialize')
local runtime = prefix('tests/rotation_scope_runtime.lua', 'fixture')
local browserFixture = prefix('tests/rotation_scope_browser_ui.lua', 'fixture')
local passed, failed, gaps = 0, 0, {}
local requireNewerWins = true

local function check(name, fn)
    local ok, why = pcall(fn)

    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(why))
    end
end

local function gap(name, condition)
    gaps[#gaps + 1] = name

    if requireNewerWins then
        assert(not condition, name)
    else
        assert(condition, 'baseline changed; recheck recorded gap')
        print('BASELINE GAP ' .. name)
    end
end

local function main()
    local env, a, load = startup(true, true)
    load('main.lua')
    initialize(a)
    a.currentSpec = 0
    a.db.profile.disable_autoswitch = false
    local trace = {}

    local function event(kind, ...)
        trace[#trace + 1] = { kind, ... }
    end

    a.info = function() end
    a.warn = function() end
    a.debug = function() end
    a.verbose = function() end

    a.RemoveAllCurrentGlows = function(self)
        event('cleanup', self.currentRotation, self.currentSpec)
    end

    a.DestroyAllGlows = function(self)
        event('destroy', self.currentRotation)
    end

    a.EnableRotationTimer = function(self)
        event('timer', self.currentRotation)
    end

    a.DisableRotationTimer = function(self)
        event('cancel', self.currentRotation)
    end

    env.LibStub('AceEvent-3.0').SendMessage = function(_, kind, ...)
        event(kind, ...)
    end

    env.LibStub('AceConsole-3.0').GetArgs = function(_, str)
        return str:match('^(%S+)'), (str:find(' ', 1, true) or #str) + 1
    end

    a.rotationValidConditions = function() return true end
    a.evaluateCondition = function() return true end
    a.db.profile.rotations[0] = { named = { name = 'Named', switch = {}, rotation = {}, cooldowns = {} } }
    a.autoswitchRotation = { 'named' }
    return env, a, trace, load
end

local function ref(scope)
    return {
        kind = 'custom',
        address = {
            scope = scope,
            class = 'SHAMAN',
            owner = scope == 'class' and 'SHAMAN' or 'A - Realm',
            spec = 0,
            id = 'shared',
        },
    }
end

check('startup publishes no active selection or timer', function()
    local _, a = main()
    assert(a.currentRotation == nil and not a.manualRotation and a.rotationTimer == nil)
end)

check('manual named chat actual boundary publishes before timer/message', function()
    local _, a, t = main()
    a:HandleCommand('set Named')
    assert(a.currentRotation == 'named' and a.manualRotation)

    assert(
        t[1][1] == 'cleanup'
            and t[2][1] == 'timer'
            and t[2][2] == 'named'
            and t[3][1] == 'ROTATIONMASTER_ROTATION'
            and t[3][2] == 'named'
    )
end)

check('manual default chat actual boundary remains valid without autoswitch', function()
    local e, a, t = main()
    a.db.profile.rotations[0][e.DEFAULT] = { name = e.DEFAULT, switch = {}, rotation = {}, cooldowns = {} }
    a:HandleCommand('set ' .. e.DEFAULT)
    assert(a.currentRotation == e.DEFAULT and a.manualRotation and t[2][2] == e.DEFAULT)
end)

check('manual same-ID chat keeps current selection and does not restart effects', function()
    local _, a, t = main()
    a.currentRotation = 'named'
    a:HandleCommand('set named')
    assert(a.currentRotation == 'named' and a.manualRotation and #t == 0)
end)

check('ambiguous manual names retain current selection', function()
    local _, a, t = main()
    a.currentRotation = 'older'
    a.db.profile.rotations[0].peer = { name = 'Named' }
    a:HandleCommand('set Named')
    assert(a.currentRotation == 'older' and #t == 0)
end)

check('actual minimap callback chooses named and automatic mode', function()
    local e, a, t = main()
    local menu = {}
    e.UIDropDownMenu_CreateInfo = function() return {} end

    e.UIDropDownMenu_AddButton = function(info)
        local c = {}

        for k, v in pairs(info) do
            c[k] = v
        end

        menu[#menu + 1] = c
    end

    e.minimapInitialize()
    local named, auto

    for _, row in ipairs(menu) do
        if row.arg1 == 'named' then
            named = row
        elseif row.text == 'Automatic Switching' then
            auto = row
        end
    end

    assert(named and auto)
    named.func(nil, named.arg1)
    assert(a.currentRotation == 'named' and a.manualRotation)
    auto.func(nil, auto.arg1)
    assert(not a.manualRotation and a.currentRotation == 'named')
end)

check('actual automatic scoped selector uses one current pass', function()
    local _, a = runtime()
    local key = a.currentRotation
    a.currentRotation = nil
    a.autoswitchRotation = { key }
    a.RemoveAllCurrentGlows = function() end
    a.EnableRotationTimer = function() end
    local get = a.AcquireRotationRuntimePass
    local n = 0

    a.AcquireRotationRuntimePass = function(self, ...)
        n = n + 1
        return get(self, ...)
    end

    a:SwitchRotation()
    assert(a.currentRotation == key and n == 1)
end)

check('manual mode prevents automatic selection work', function()
    local _, a, t = main()
    a.currentRotation = 'older'
    a.manualRotation = true
    a:GetRuntimeRotations(0).named.switch = {}
    a:SwitchRotation()
    assert(a.currentRotation == 'older' and #t == 0)
end)

check('manual cleanup preserves the newer selection', function()
    local _, a = main()

    a.RemoveAllCurrentGlows = function(self)
        self.currentRotation = 'newer'
    end

    a:HandleCommand('set Named')
    gap('manual cleanup must not overwrite newer selection', a.currentRotation == 'named')
end)

check('auto cleanup reentry already rejects older selection', function()
    local _, a = main()
    a.currentRotation = 'older'

    a.RemoveAllCurrentGlows = function(self)
        self.currentRotation = 'newer'
    end

    a:SwitchRotation()
    assert(a.currentRotation == 'newer')
end)

check('normal disable clears ID before public messages', function()
    local _, a, t = main()
    a.currentRotation = 'named'
    a.currentSpell = 403
    a:DisableRotation()
    assert(a.currentRotation == nil and a.currentSpell == nil)

    for _, row in ipairs(t) do
        if row[1] == 'ROTATIONMASTER_ROTATION' then
            assert(row[2] == nil)
        end
    end

    local _, b = runtime()
    local key = b.currentRotation
    local get = b.GetRotationForCleanup
    local called, glows

    b.GetRotationForCleanup = function(self, spec, id)
        assert(spec == 0 and id == key)
        called = true
        return get(self, spec, id)
    end

    b.GetSpellIds = function(_, step) return { step.action } end

    b.GlowCooldown = function(_, id, on)
        assert(id == 324 and on == false)
        glows = true
    end

    b.DestroyAllGlows = function() end
    b:DisableRotation()
    assert(not b.currentRotation and called and glows)
end)

check('disable cleanup preserves the newer selection', function()
    local _, a = main()
    a.currentRotation = 'older'

    a.RemoveAllCurrentGlows = function(self)
        self.currentRotation = 'newer'
    end

    a:DisableRotation()
    gap('disable cleanup must not retire newer selection', a.currentRotation == nil)
end)

check('error-stop cleanup stops old clear messages after reentry', function()
    local _, a, t = main()
    a.currentRotation = 'older'
    a.Diagnostics = { Call = function(_, _, fn, ...) return pcall(fn, ...) end }

    a.RemoveAllCurrentGlows = function(self)
        self.currentRotation = 'newer'
    end

    a:StopAdviceForError(9)
    assert(a.currentRotation == 'newer')
    local clear = false

    for _, row in ipairs(t) do
        if row[1] == 'ROTATIONMASTER_ROTATION' and row[2] == nil then
            clear = true
        end
    end

    gap('error cleanup must stop old clear publication after newer activation', clear)
end)

check('specialization cleanup runs before new namespace publication', function()
    local _, a, t = main()
    a.currentRotation = 'named'
    a.manualRotation = true
    a.Platform.GetRotationSpecialization = function() return { key = 2 } end
    a.UpdateSpecSpells = function() end
    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    a.ButtonFetch = function() end
    a:UpdateSkill()

    assert(
        t[2][1] == 'cleanup' and t[2][3] == 0 and a.currentSpec == 2 and not a.currentRotation and not a.manualRotation
    )
end)

check('unknown specialization retires selection and refuses EnableRotation', function()
    local _, a = main()
    a.currentRotation = 'named'
    a.Platform.GetRotationSpecialization = function() return nil end
    a:UpdateSkill()
    assert(a.currentSpec == nil and not a.currentRotation and next(a.autoswitchRotation) == nil)

    a.Fetch = function()
        error('unknown namespace fetch')
    end

    a:EnableRotation()
    assert(not a.currentRotation)
end)

check('actual AceDB profile switch/copy/reset retires and rebinds before enabled callback', function()
    local _, a, _, _, _, _, load = runtime()
    local enabled = 0
    a.DestroyAllGlows = function() end
    a.RefreshConfiguration = function() end

    a.EnableRotation = function(self)
        assert(not self.currentRotation and self:ListRotationHeaders(0))
        enabled = enabled + 1
    end

    a:InstallRotationProfileLifecycle()
    a.db:SetProfile('Other')
    a.db:CopyProfile('Default')
    a.db:ResetProfile()
    assert(enabled == 3 and not a.currentRotation)
end)

check('actual scoped same-ID pane Apply commits new body revision before advice', function()
    local _, a, parent = browserFixture()
    local p = assert(a:CreateRotationEditor(parent, 0, ref('class')))
    a.currentSpec = 0
    a.currentRotation = p.workspace.id
    a.manualRotation = true
    local key = a.currentRotation
    local observed

    a.EvaluateNextAction = function(self)
        observed = self:GetRotationRecordSnapshot(0, p.workspace.reference).body.revision
    end

    assert(p:Command('SetBodyField', 'description', 'Saved'))
    assert(p:Apply())
    assert(a.currentRotation == key and a.manualRotation and observed == 2)
end)

check('actual scoped pane ownership move retargets exact active address', function()
    local _, a, parent = browserFixture()
    local _, token = a:GetRotationRecordSnapshot(0, ref('character'))
    assert(a:DeleteRotationRecord(ref('character'), token))
    local b = a:CreateRotationBrowser(parent, { spec = 0, id = ref('class') })
    a.currentSpec = 0
    a.currentRotation = b.selected
    a.manualRotation = true
    assert(b.pane:Command('SetOwnership', 'character'))
    assert(b.pane:Apply())
    assert(a:ResolveRotationReference(0, a.currentRotation).address.scope == 'character' and a.manualRotation)
end)

check('same-ID import replacement changes revision while retaining active visible key', function()
    local _, a, _, old, r, _, load = runtime()
    load('Core/imports.lua')
    local key = a.currentRotation
    local _, token = a:GetRotationRecordSnapshot(0, r)
    local input = { body = { name = 'Imported', rotation = {}, cooldowns = {} } }
    local session = { GetReady = function() return input end }
    a.UpdateAutoSwitch = function() end
    a.SwitchRotation = function() end
    local seen

    a.EvaluateNextAction = function(self)
        seen = self:GetRotationRecordSnapshot(0, r).body.revision
    end

    assert(a:ApplyRotationImport(session, {}, 0, 'Imported', r, {
        profile = a.db.profile,
        reference = r,
        recordToken = token,
    }))

    assert(a.currentRotation == key and seen == 2)
end)

check('exact-owner deletion leaves equal-ID peer and retires selected key', function()
    local _, a, parent = browserFixture()
    local b = a:CreateRotationBrowser(parent, { spec = 0, id = ref('class') })
    a.currentSpec = 0
    a.currentRotation = b.selected
    a.manualRotation = true
    a.RemoveAllCurrentGlows = function() end
    b.pane:ConfirmDelete()
    b.pane.deletePrompt.confirm:Click()
    assert(not a.currentRotation and not a.manualRotation and a:GetRotationRecordSnapshot(0, ref('character')))
end)

check('selected builtin preference disable retires before another runtime read', function()
    local _, a = runtime()
    a.DestroyAllGlows = function() end
    local header

    for _, h in ipairs(a:ListRotationHeaders(0)) do
        if h.kind == 'builtin' then
            header = h
            break
        end
    end

    assert(header)
    a.currentRotation = header.key
    assert(a:SetDefaultRotationEnabled(header.id or header.builtin or header.canonicalId, false))
    gap('selected builtin disable must retire exact activation at commit boundary', a.currentRotation == header.key)
end)

check('manual runtime lookup reentry also needs an entry operation lease', function()
    local _, a = main()
    a.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }
    local get = a.GetRuntimeRotations
    local entered = false

    a.GetRuntimeRotations = function(self, ...)
        if not entered then
            entered = true
            self:HandleCommand('set Other')
        end

        return get(self, ...)
    end

    a:HandleCommand('set Named')
    gap('manual resolution must not overwrite a nested selection', a.currentRotation == 'named')
end)

check('manual timer reentry must stop old broker and message tail', function()
    local e, a = main()
    a.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }

    a.EnableRotationTimer = function(self)
        self.currentRotation = 'other'
    end

    a:HandleCommand('set Named')
    assert(a.currentRotation == 'other')
    gap('manual timer callback must stop stale broker tail', e.broker.text == 'Named')
end)

check('failed activation preparation retains existing selection', function()
    local _, a = main()
    a:HandleCommand('set Named')
    local op = a:BeginActiveRotationTransition()
    assert(not a:CommitActiveRotationTransition(op, 0, 'missing'))
    assert(a.currentRotation == 'named')
end)

check('unchanged reselect keeps activation while operation supersedes', function()
    local _, a = main()
    local op = a:BeginActiveRotationTransition()
    local first = assert(a:CommitActiveRotationTransition(op, 0, 'named'))
    local nextOp = a:BeginActiveRotationTransition()
    assert(first == a:CommitActiveRotationTransition(nextOp, 0, 'named'))
    assert(not a:IsActiveRotationTransitionCurrent(op) and a:IsActiveRotationTransitionCurrent(nextOp))
end)

check('stale retire cannot clear newer activation', function()
    local _, a = main()
    local old = a:BeginActiveRotationTransition()
    local fresh = a:BeginActiveRotationTransition()
    assert(a:CommitActiveRotationTransition(fresh, 0, 'named'))
    assert(not a:RetireActiveRotationTransition(old))
    assert(a.currentRotation == 'named')
end)

check('foreign receivers cannot change active authority', function()
    local _, a = main()
    local foreign = { db = a.db, currentSpec = 0 }
    assert(not a.BeginActiveRotationTransition(foreign))
    assert(not a.CommitActiveRotationTransition(foreign, {}, 0, 'named'))
    assert(not a.RetireActiveRotationTransition(foreign, {}))
end)

check('resolution reentry prevents old prepared publication', function()
    local _, a = main()
    local op = a:BeginActiveRotationTransition()
    local get = a.GetRuntimeRotation
    local entered = false

    a.GetRuntimeRotation = function(self, ...)
        if not entered then
            entered = true
            self:HandleCommand('set Named')
        end

        return get(self, ...)
    end

    assert(not a:CommitActiveRotationTransition(op, 0, 'named'))
    assert(a.currentRotation == 'named')
end)

check('profile and spec drift invalidate pending activation', function()
    for _, kind in ipairs({ 'profile', 'spec' }) do
        local _, a = main()
        local op = a:BeginActiveRotationTransition()

        if kind == 'profile' then
            a.db.profile = {}
        else
            a.currentSpec = 2
        end

        assert(not a:CommitActiveRotationTransition(op, 0, 'named'))
    end
end)

check('opaque activation handles do not expose mutable authority', function()
    local _, a = main()
    local op = a:BeginActiveRotationTransition()
    local token = assert(a:CommitActiveRotationTransition(op, 0, 'named'))
    assert(type(token) == 'table' and next(token) == nil)
    token.profile = 'forged'
    token.dependencies = {}
    assert(a:IsActiveRotationTransitionCurrent(op) and a.currentRotation == 'named')
    local copy = a.RotationData.CopyData
    local retained = {}

    a.RotationData.CopyData = function(...)
        local value, why = copy(...)
        retained[#retained + 1] = value
        return value, why
    end

    local stable = assert(a:RefreshActiveRotation(0))

    for _, value in ipairs(retained) do
        if type(value) == 'table' and value.name == 'Named' then
            value.description = 'poison'
        end
    end

    assert(a:RefreshActiveRotation(0) == stable, 'public copy result exposed private active snapshot')
end)

check('runtime authority never enters saved bodies or profile', function()
    local _, a = main()
    a:HandleCommand('set Named')
    local b = a.db.profile.rotations[0].named

    assert(
        not b.activationToken and not b.dependencies and not b.dependency_revision and not a.db.profile.activeRotation
    )
end)

check('headless flat Apply refreshes once and noop preserves activation', function()
    local _, a, _, load = main()
    load('Data/rotation_draft.lua')
    load('Core/rotation_editor.lua')
    a.GetImportValidationOptions = function() return {} end
    a.validateCondition = function() return true end
    local op = a:BeginActiveRotationTransition()
    local first = assert(a:CommitActiveRotationTransition(op, 0, 'named'))
    local b = a.db.profile.rotations[0].named
    local s = assert(a:NewRotationEditSession(0, b))
    assert(s:Command('SetBodyField', 'description', 'Edit'))
    assert(s:Apply())
    assert(not a:IsActiveRotationTransitionCurrent(op), 'flat publication did not refresh active lease')
    local second = assert(a:RefreshActiveRotation(0))
    assert(second ~= first and b.revision == 2 and a:RefreshActiveRotation(0) == second)
end)

check('headless scoped commits distinguish active and unrelated address', function()
    local _, a, _, b, r, save = runtime()
    local op = a:BeginActiveRotationTransition()
    local first = assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation))
    b.description = 'Edit'
    save(b)
    assert(not a:IsActiveRotationTransitionCurrent(op), 'scoped publication did not refresh active lease')
    local second = assert(a:RefreshActiveRotation(0))
    assert(first ~= second)

    assert(a:CommitRotationDraft(
        { kind = 'custom', address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'other' } },
        nil,
        { body = { name = 'Other', rotation = {}, cooldowns = {} } }
    ))

    assert(a:RefreshActiveRotation(0) == second)
end)

check('malformed runtime body cannot become active', function()
    local _, a = main()
    a.GetRuntimeRotation = function() return { name = 'Malformed', revision = false } end
    local op = a:BeginActiveRotationTransition()
    assert(not a:CommitActiveRotationTransition(op, 0, 'named'))
    assert(a.currentRotation == nil)
end)

check('same DEFAULT alias resolving another owner replaces activation', function()
    local _, a = runtime()

    local r = {
        kind = 'custom',
        address = {
            scope = 'class',
            class = 'SHAMAN',
            owner = 'SHAMAN',
            spec = 0,
            id = a.db.profile.rotationFallbackID,
        },
    }

    assert(a:CommitRotationDraft(r, nil, { body = { name = 'Class fallback', rotation = {}, cooldowns = {} } }))
    a.currentRotation = 'Default'
    local first = assert(a:RefreshActiveRotation(0))
    r.address.scope = 'character'
    r.address.owner = assert(a:GetRotationOwnerContext()).character
    assert(a:CommitRotationDraft(r, nil, { body = { name = 'Character fallback', rotation = {}, cooldowns = {} } }))
    local second = assert(a:RefreshActiveRotation(0))
    assert(first ~= second and a.currentRotation == 'Default')
end)

check('publication finalization cannot invoke a public refresh callback after saved data', function()
    local _, a, parent = browserFixture()
    local p = assert(a:CreateRotationEditor(parent, 0, ref('class')))
    a.currentSpec = 0
    a.currentRotation = p.workspace.id

    a.RefreshActiveRotation = function()
        error('public post-publication callback')
    end

    assert(p:Command('SetBodyField', 'description', 'Committed'))
    assert(p:Apply())
    assert(a:GetRotationRecordSnapshot(0, p.workspace.reference).body.revision == 2)
end)

check('nested disable prevents an older enable from resuming selection', function()
    local _, a = main()
    a.RegisterEvent = function() end
    a.UnregisterAllEvents = function() end
    a.Fetch = function() end
    a.UpdateAutoSwitch = function() end

    a.UpdateSkill = function(self)
        self:disable()
    end

    a:enable()
    assert(a.currentRotation == nil)
end)

check('getter and cleanup-row reentry cannot invoke stale work', function()
    local _, a = main()
    a.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }
    local calls, entered = 0, false

    local remove = function()
        calls = calls + 1
    end

    a.RemoveAllCurrentGlows = nil

    setmetatable(a, {
        __index = function(self, key)
            if key == 'RemoveAllCurrentGlows' then
                if not entered then
                    entered = true
                    self:HandleCommand('set Other')
                end

                return remove
            end
        end,
    })

    a:HandleCommand('set Named')
    assert(a.currentRotation == 'other' and calls == 1, 'stale returned cleanup ran after getter reentry')
    local _, b = runtime()
    local count, clears = 0, 0
    b.GetSpellIds = function() return { 324, 325 } end
    b.DestroyAllGlows = function() end

    b.GlowCooldown = function(self)
        count = count + 1
        self:BeginActiveRotationTransition()
        self.currentRotation = 'newer'
    end

    b.GlowClear = function()
        clears = clears + 1
    end

    b:DisableRotation()

    assert(
        b.currentRotation == 'newer' and count == 1 and clears == 0,
        'old cleanup continued after first row callback'
    )

    local _, c = runtime()
    local custom = c.currentRotation
    local header

    for _, h in ipairs(c:ListRotationHeaders(0)) do
        if h.kind == 'builtin' then
            header = h
            break
        end
    end

    assert(header)
    c.currentRotation = header.key
    c.DestroyAllGlows = function() end
    local disable = c.DisableRotation
    c.DisableRotation = nil
    local inside = false

    setmetatable(c, {
        __index = function(self, key)
            if key == 'DisableRotation' then
                if not inside then
                    inside = true
                    local op = self:BeginActiveRotationTransition()
                    assert(self:CommitActiveRotationTransition(op, 0, custom))
                end

                return disable
            end
        end,
    })

    assert(c:SetDefaultRotationEnabled(header.id or header.builtin or header.canonicalId, false))
    assert(c.currentRotation == custom, 'stale disable getter destroyed newer selection')
end)

check('retirement field getter cannot clear a newer operation', function()
    local _, a = main()
    a.currentRotation = 'older'
    local token = assert(a:BeginActiveRotationTransition())
    local prior = getmetatable(a)
    local mt = {}

    for k, v in pairs(prior or {}) do
        mt[k] = v
    end

    local reads, nested = 0, nil

    mt.__index = function(self, key)
        if key == 'currentRotation' then
            reads = reads + 1

            if reads == 2 then
                rawset(self, 'currentRotation', 'newer')
                nested = assert(self:BeginActiveRotationTransition())
            end

            return 'older'
        end

        if prior and type(prior.__index) == 'function' then
            return prior.__index(self, key)
        end
        if prior and type(prior.__index) == 'table' then
            return prior.__index[key]
        end
    end

    rawset(a, 'currentRotation', nil)
    setmetatable(a, mt)
    local ok, why = a:RetireActiveRotationTransition(token)

    assert(
        not ok
            and why == 'rotation-transition-superseded'
            and rawget(a, 'currentRotation') == 'newer'
            and a:IsActiveRotationTransitionCurrent(nested)
    )
end)

check('owned publication has no newindex callback after final authority check', function()
    local _, a = main()
    local calls = 0
    local mt = getmetatable(a) or {}

    mt.__newindex = function(self, key, value)
        if key == 'currentRotation' then
            calls = calls + 1
            rawset(self, key, 'newer')
            self:BeginActiveRotationTransition()
        else
            rawset(self, key, value)
        end
    end

    setmetatable(a, mt)
    local op = assert(a:BeginActiveRotationTransition())
    assert(a:CommitActiveRotationTransition(op, 0, 'named'))
    assert(calls == 0 and rawget(a, 'currentRotation') == 'named' and a:IsActiveRotationTransitionCurrent(op))
    local _, b = main()
    local prepare, finish

    b:BindActiveRotationPublication(function(p, f)
        prepare, finish = p, f
    end)

    b.currentRotation = 'named'
    local body = b.db.profile.rotations[0].named
    local ticket = assert(prepare(0, 'named', nil, nil, body))
    local mtB = getmetatable(b) or {}
    local writes = 0

    mtB.__newindex = function(self, key, value)
        if key == 'currentRotation' then
            writes = writes + 1
        end

        rawset(self, key, value)
    end

    setmetatable(b, mtB)
    rawset(b, 'currentRotation', nil)
    assert(not finish(ticket), 'changed raw authority must reject completion')
    assert(writes == 0)
end)

check('retired cleanup expires only after a successful activation', function()
    local _, a = runtime()
    local old = a.currentRotation

    local reference = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'second' },
    }

    assert(a:CommitRotationDraft(reference, nil, {
        body = {
            name = 'Second',
            rotation = {},
            cooldowns = { { id = 'second-cd', type = 'spell', action = 777, conditions = {} } },
        },
    }))

    local new = a:GetScopedRotationCoordinator():Key(reference)
    local get = a.GetRotationForCleanup
    local ids = {}

    a.GetRotationForCleanup = function(self, spec, id)
        ids[#ids + 1] = id
        return get(self, spec, id)
    end

    a.GetSpellIds = function(_, step) return { step.action } end
    a.GlowCooldown = function() end
    a.GlowClear = function() end
    local token = assert(a:BeginActiveRotationTransition())
    assert(a:RetireActiveRotationTransition(token))
    a:RemoveAllCurrentGlows()
    assert(ids[1] == old)
    assert(not a:CommitActiveRotationTransition(token, 0, 'missing'))
    a:RemoveAllCurrentGlows()
    assert(ids[2] == old, 'failed activation lost retired cleanup')
    assert(a:CommitActiveRotationTransition(token, 0, new))
    a:RemoveAllCurrentGlows()
    assert(ids[3] == new, 'successful activation retained old cleanup')
    local spec, id = a:GetActiveRotationCleanupSelection()
    assert(spec == nil and id == nil)
end)

check('event method getter cannot publish a stale transition tail', function()
    local e, a, trace = main()
    a.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }
    local ace = e.LibStub('AceEvent-3.0')
    local send = ace.SendMessage
    ace.SendMessage = nil

    setmetatable(ace, {
        __index = function(_, key)
            if key == 'SendMessage' then
                rawset(ace, key, send)
                a:HandleCommand('set Other')
                return send
            end
        end,
    })

    a:HandleCommand('set Named')
    assert(a.currentRotation == 'other')

    for _, row in ipairs(trace) do
        assert(row[1] ~= 'ROTATIONMASTER_ROTATION' or row[3] ~= 'Named', 'stale event after method getter')
    end
end)

check('WeakAuras getter cannot invoke a stale transition tail', function()
    local ew, w = main()
    w.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }
    w:HandleCommand('set Named')
    local weakCalls = 0
    local weak = {}

    setmetatable(weak, {
        __index = function(self, key)
            if key == 'ScanEvents' then
                local fn = function()
                    weakCalls = weakCalls + 1
                end

                rawset(self, key, fn)
                w:HandleCommand('set Other')
                return fn
            end
        end,
    })

    ew.WeakAuras = weak
    w:DisableRotation()
    assert(w.currentRotation == 'other' and weakCalls == 0, 'stale WeakAuras invocation after getter')
end)

check('pane cleanup method getter cannot invoke stale work', function()
    local _, a, parent = browserFixture()
    local pane = assert(a:CreateRotationEditor(parent, 0, ref('class')))
    a.currentSpec = 0
    a.currentRotation = pane.workspace.id
    local calls, reads = 0, 0
    a.GetSpellIds = nil
    a.GlowCooldown = function() end
    local mt = getmetatable(a) or {}
    local prior = mt.__index

    mt.__index = function(self, key)
        if key == 'GetSpellIds' then
            reads = reads + 1

            if reads == 2 then
                self.currentRotation = 'newer'
                self:BeginActiveRotationTransition()
            end

            return function()
                calls = calls + 1
                return { 324 }
            end
        end

        if type(prior) == 'function' then
            return prior(self, key)
        elseif type(prior) == 'table' then
            return prior[key]
        end
    end

    setmetatable(a, mt)
    assert(not pane:RefreshAdvice({ cooldowns = { { id = 'old', type = 'spell', action = 324 } } }))
    assert(a.currentRotation == 'newer' and calls == 0)
end)

check('cleanup rotation method getter cannot invoke stale work', function()
    local _, a = runtime()
    local token = assert(a:BeginActiveRotationTransition())
    assert(a:RetireActiveRotationTransition(token))
    local calls = 0
    local get = a.GetRotationForCleanup
    a.GetRotationForCleanup = nil
    local mt = getmetatable(a) or {}
    local prior = mt.__index

    mt.__index = function(self, key)
        if key == 'GetRotationForCleanup' then
            self.currentRotation = 'newer'
            self:BeginActiveRotationTransition()

            return function(...)
                calls = calls + 1
                return get(...)
            end
        end

        if type(prior) == 'function' then
            return prior(self, key)
        elseif type(prior) == 'table' then
            return prior[key]
        end
    end

    setmetatable(a, mt)
    a:RemoveAllCurrentGlows()
    assert(a.currentRotation == 'newer' and calls == 0)
end)

check('internal transition authority ignores replacement control API getters', function()
    for _, name in ipairs({
        'BeginActiveRotationTransition',
        'RetireActiveRotationTransition',
        'CommitActiveRotationTransition',
        'GetActiveRotationCleanupSelection',
    }) do
        local _, a = main()
        a.db.profile.rotations[0].other = { name = 'Other', switch = {}, rotation = {}, cooldowns = {} }
        local original = a[name]
        local calls = 0
        rawset(a, name, nil)
        local mt = getmetatable(a) or {}
        local prior = mt.__index

        mt.__index = function(self, key)
            if key == name then
                calls = calls + 1
                rawset(self, key, original)
                self:HandleCommand('set Other')
                return original
            end

            if type(prior) == 'function' then
                return prior(self, key)
            elseif type(prior) == 'table' then
                return prior[key]
            end
        end

        setmetatable(a, mt)
        a:HandleCommand('set Named')
        assert(a.currentRotation == 'named' and calls == 0, name .. ' getter controlled internal authority')
    end
end)

check('specialization setter cannot make an older continuation adopt a newer operation', function()
    local _, a = main()
    a.currentRotation = 'named'
    a.currentSpec = nil
    local tail, tabs = 0, {}
    a.Platform.GetRotationSpecialization = function() return { key = 2 } end

    a.UpdateSpecSpells = function()
        tail = tail + 1
    end

    a.UpdateAutoSwitch = function()
        tail = tail + 1
    end

    a.SwitchRotation = function()
        tail = tail + 1
    end

    a.ButtonFetch = function()
        tail = tail + 1
    end

    a.specTab = {
        SelectTab = function(_, n)
            tabs[#tabs + 1] = n
        end,
    }

    local mt = getmetatable(a) or {}
    local prior = mt.__newindex

    mt.__newindex = function(self, key, value)
        if key == 'currentSpec' then
            rawset(self, key, 3)
            rawset(self, 'currentRotation', 'newer')
            self:BeginActiveRotationTransition()
            return
        end

        if prior then
            return prior(self, key, value)
        end

        rawset(self, key, value)
    end

    setmetatable(a, mt)
    a:UpdateSkill()
    assert(a.currentSpec == 3 and a.currentRotation == 'newer' and tail == 0 and #tabs == 0)
end)

check('profile archive adoption refreshes only the effective active fallback owner', function()
    for _, destination in ipairs({ 'character', 'class' }) do
        local _, a = browserFixture()
        a.currentSpec = 0
        local p = a.db.profile
        local id = p.rotationFallbackID

        if destination == 'character' then
            p.rotationStore.characters['A - Realm'].specs[0][id] = nil
        else
            p.rotationStore.classes.SHAMAN[0][id] = nil
        end

        p.rotationStore.legacy.rotations[0][id] = {
            name = 'Adopted fallback',
            switch = {},
            rotation = {},
            cooldowns = {},
        }

        assert(a:BindRotationProfile())
        a.currentRotation = 'Default'
        local op = assert(a:BeginActiveRotationTransition())
        local before = assert(a:CommitActiveRotationTransition(op, 0, 'Default'))
        local plan = assert(a:PlanRotationAdoption({ kind = 'profile', spec = 0, id = id }, destination))
        assert(a:ApplyRotationAdoption(plan))
        assert(not a:IsActiveRotationTransitionCurrent(op))
        local after = assert(a:RefreshActiveRotation(0))

        if destination == 'character' then
            assert(before ~= after and a:ResolveRotationReference(0, 'Default').address.scope == 'character')
        else
            assert(before == after, 'shadowed Class adoption changed active Character identity')
        end
    end
end)

check('character archive adoption refreshes active fallback before rebinding the root', function()
    local _, a = browserFixture()
    a.currentSpec = 0
    local p = a.db.profile
    local id = p.rotationFallbackID
    p.rotationStore.characters['A - Realm'].specs[0][id] = nil

    a.db.sv = {
        char = {
            ['A - Realm'] = {
                rotations = {
                    [0] = { [id] = { name = 'Adopted fallback', switch = {}, rotation = {}, cooldowns = {} } },
                },
            },
        },
    }

    assert(a:BindRotationProfile())
    a.currentRotation = 'Default'
    local op = assert(a:BeginActiveRotationTransition())
    local before = assert(a:CommitActiveRotationTransition(op, 0, 'Default'))
    local bind = a.BindRotationProfile
    local observed = false

    a.BindRotationProfile = function(self)
        observed = not self:IsActiveRotationTransitionCurrent(op)
        return bind(self)
    end

    local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = id }, 'character'))
    assert(a:ApplyRotationAdoption(plan))
    assert(observed and not a:IsActiveRotationTransitionCurrent(op))

    assert(
        a:ResolveRotationReference(0, 'Default').address.scope == 'character' and a:RefreshActiveRotation(0) ~= before
    )
end)

check('adoption preparation cannot overwrite newer profile or character archive state', function()
    for _, mode in ipairs({ 'profile-owner', 'character-owner', 'character-archive' }) do
        local _, a = browserFixture()
        a.currentSpec = 0
        local p = a.db.profile
        local id = p.rotationFallbackID
        p.rotationStore.characters['A - Realm'].specs[0][id] = nil
        local kind = mode == 'profile-owner' and 'profile' or 'character'

        if kind == 'profile' then
            p.rotationStore.legacy.rotations[0][id] = { name = 'Adopted', rotation = {}, cooldowns = {} }
        else
            a.db.sv = {
                char = {
                    ['A - Realm'] = {
                        rotations = { [0] = { [id] = { name = 'Adopted', rotation = {}, cooldowns = {} } } },
                    },
                },
            }
        end

        assert(a:BindRotationProfile())
        a.currentRotation = 'Default'
        local plan = assert(a:PlanRotationAdoption({ kind = kind, spec = 0, id = id }, 'character'))
        local get = a.GetScopedRotationCoordinator
        local reads = 0
        local newer = { marker = 'new-profile' }

        a.GetScopedRotationCoordinator = function(self, ...)
            local value = get(self, ...)
            reads = reads + 1

            if reads == 2 then
                if mode == 'character-archive' then
                    self.db.sv.char['A - Realm'].rotations[0][id].name = 'Newer archive'
                else
                    self.db.profile = newer
                end
            end

            return value
        end

        local ok = a:ApplyRotationAdoption(plan)
        assert(not ok, mode .. ' old adoption committed')

        if mode == 'character-archive' then
            assert(a.db.sv.char['A - Realm'].rotations[0][id].name == 'Newer archive')
        else
            assert(a.db.profile == newer and newer.marker == 'new-profile' and newer.rotationStore == nil)
        end
    end
end)

check('direct and unrelated adoption rebinds preserve the exact active nondefault reference', function()
    for _, adopt in ipairs({ false, true }) do
        local _, a, parent = browserFixture()
        local pane = assert(a:CreateRotationEditor(parent, 0, ref('class')))
        a.currentSpec = 0
        a.currentRotation = pane.workspace.id
        local op = assert(a:BeginActiveRotationTransition())
        assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation))

        if adopt then
            a.db.sv = {
                char = {
                    ['A - Realm'] = {
                        rotations = { [0] = { other = { name = 'Adopted unrelated', rotation = {}, cooldowns = {} } } },
                    },
                },
            }

            local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = 'other' }, 'character'))
            assert(a:ApplyRotationAdoption(plan))
        else
            assert(a:BindRotationProfile())
        end

        assert(not a:IsActiveRotationTransitionCurrent(op))
        local selected = assert(a:ResolveRotationReference(0, a.currentRotation))

        assert(
            selected.address.scope == 'class' and selected.address.id == 'shared' and a:GetRuntimeRotation(
                0,
                a.currentRotation
            )
        )
    end
end)

check('newer exact selection during fresh rebind resolution wins', function()
    local _, a, parent = browserFixture()
    local pane = assert(a:CreateRotationEditor(parent, 0, ref('class')))
    a.currentSpec = 0
    a.currentRotation = pane.workspace.id

    local other = {
        kind = 'custom',
        address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = 0, id = 'other' },
    }

    assert(a:CommitRotationDraft(other, nil, { body = { name = 'Other', rotation = {}, cooldowns = {} } }))
    local op = assert(a:BeginActiveRotationTransition())
    assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation))
    local old = a:GetScopedRotationCoordinator()
    local get = a.GetRotationOwnerContext
    local entered = false
    local newer

    a.GetRotationOwnerContext = function(self)
        if not entered and self:GetScopedRotationCoordinator() ~= old then
            entered = true
            local key = self:GetScopedRotationCoordinator():Key(other)
            local fresh = self:BeginActiveRotationTransition()
            assert(self:CommitActiveRotationTransition(fresh, 0, key))
            newer = key
        end

        return get(self)
    end

    assert(a:BindRotationProfile())
    assert(entered and a.currentRotation == newer and a:ResolveRotationReference(0, newer).address.id == 'other')
end)

check('adoption committed success survives a newer selection in the bind override', function()
    local _, a = browserFixture()
    a.currentSpec = 0
    local p = a.db.profile
    local id = p.rotationFallbackID
    p.rotationStore.characters['A - Realm'].specs[0][id] = nil

    a.db.sv = {
        char = {
            ['A - Realm'] = { rotations = { [0] = { [id] = { name = 'Adopted', rotation = {}, cooldowns = {} } } } },
        },
    }

    assert(a:BindRotationProfile())
    a.currentRotation = 'Default'
    local op = assert(a:BeginActiveRotationTransition())
    assert(a:CommitActiveRotationTransition(op, 0, 'Default'))
    local plan = assert(a:PlanRotationAdoption({ kind = 'character', spec = 0, id = id }, 'character'))
    local bind = a.BindRotationProfile

    a.BindRotationProfile = function(self)
        self.currentRotation = 'newer'
        self:BeginActiveRotationTransition()
        return bind(self)
    end

    assert(a:ApplyRotationAdoption(plan))
    assert(a.currentRotation == 'newer' and p.rotationStore.characters['A - Realm'].specs[0][id])
end)

check('unavailable exact reference after a rebind retires selection safely', function()
    local _, a, parent = browserFixture()
    local pane = assert(a:CreateRotationEditor(parent, 0, ref('class')))
    a.currentSpec = 0
    a.currentRotation = pane.workspace.id
    a.manualRotation = true
    local op = assert(a:BeginActiveRotationTransition())
    assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation))
    a.db.profile.rotationStore.classes.SHAMAN[0].shared = nil
    assert(a:BindRotationProfile())
    assert(a.currentRotation == nil and not a.manualRotation and not a:IsActiveRotationTransitionCurrent(op))
end)

check('nested retire and constructor rebinds keep the newer coordinator', function()
    for _, mode in ipairs({ 'retire', 'constructor' }) do
        for _, selected in ipairs({ false, true }) do
            local _, a, parent = browserFixture()
            local pane = assert(a:CreateRotationEditor(parent, 0, ref('class')))
            a.currentSpec = 0

            if selected then
                a.currentRotation = pane.workspace.id
                local op = assert(a:BeginActiveRotationTransition())
                assert(a:CommitActiveRotationTransition(op, 0, a.currentRotation))
            else
                a.currentRotation = nil
            end

            local innerCoordinator, innerKey

            if mode == 'retire' then
                local old = a:GetScopedRotationCoordinator()
                local retire = old.Retire

                old.Retire = function(self, ...)
                    old.Retire = retire
                    assert(a:BindRotationProfile())
                    innerCoordinator = a:GetScopedRotationCoordinator()
                    innerKey = a.currentRotation
                    return retire(self, ...)
                end
            else
                local construct = a.RotationData.NewRotationStore

                a.RotationData.NewRotationStore = function(...)
                    a.RotationData.NewRotationStore = construct
                    assert(a:BindRotationProfile())
                    innerCoordinator = a:GetScopedRotationCoordinator()
                    innerKey = a.currentRotation
                    return construct(...)
                end
            end

            local ok, why = a:BindRotationProfile()

            assert(
                not ok
                    and why == 'rotation-transition-superseded'
                    and a:GetScopedRotationCoordinator() == innerCoordinator
                    and a.currentRotation == innerKey
            )

            if selected then
                assert(a:ResolveRotationReference(0, a.currentRotation).address.id == 'shared')
            else
                assert(a.currentRotation == nil)
            end
        end
    end
end)

local assignments = 0

for _, path in ipairs({
    'main.lua',
    'Core/rotation_library.lua',
    'Core/rotation_lifecycle.lua',
    'Core/imports.lua',
    'Core/rotation_scope.lua',
    'Core/rotation_editor.lua',
    'Core/rotation_migration.lua',
    'UI/rotation_editor.lua',
}) do
    for line in read(path):gmatch('[^\n]+') do
        if line:match('%.currentRotation%s*=[^=]') then
            assert(
                path == 'main.lua' and line:match('self%.currentRotation%s*=%s*nil'),
                'direct selection write outside central service: ' .. path
            )

            assignments = assignments + 1
        end
    end
end

assert(assignments == 1, 'missing initialization inventory')
print(string.format('%d passed, %d failed; central assignment inventory verified', passed, failed))

if failed > 0 then
    os.exit(1)
end
