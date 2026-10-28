-- Original public-contract fixtures; no Questie implementation is included.
local test, finish = dofile('tests/fixtures/addon.lua').suite()

local function loadAdapter(addon, env)
    local chunk = loadfile('Integrations/questie.lua')

    if chunk then
        setfenv(chunk, env or _G)
        chunk('RotationMaster', addon)
    end

    assert(
        addon.Integrations and type(addon.Integrations.NewQuestie) == 'function',
        'the optional Questie adapter factory must be published'
    )
end

test('publishes its factory without replacing existing integration entries', function()
    local editor = {}
    local existing = { editor = editor }
    local addon = { Integrations = existing }
    loadAdapter(addon)
    assert(addon.Integrations == existing and addon.Integrations.editor == editor)
end)

-- This model exercises only the documented dot-call callback contract. The
-- provider deliberately retains callbacks, including after logical detach.
local function provider(ready)
    local p = { readyCalls = 0, updateCalls = 0, readyCallbacks = {}, updateCallbacks = {} }

    p.api = {
        isReady = ready,
        Enums = {
            QuestUpdateTriggerReason = {
                QUEST_ACCEPTED = 1,
                QUEST_UPDATED = 2,
                QUEST_TURNED_IN = 3,
                QUEST_ABANDONED = 4,
            },
        },
    }

    p.api.RegisterOnReady = function(...)
        assert(select('#', ...) == 1 and type((...)) == 'function', 'ready must use a dot call')
        local callback = ...
        p.readyCalls = p.readyCalls + 1
        p.readyCallbacks[#p.readyCallbacks + 1] = callback

        if p.onReadyRegister then
            p.onReadyRegister(callback)
        end
        if p.api.isReady == true then
            callback()
        end
    end

    p.api.RegisterForQuestUpdates = function(...)
        assert(select('#', ...) == 1 and type((...)) == 'function', 'updates must use a dot call')
        local callback = ...
        p.updateCalls = p.updateCalls + 1
        p.updateCallbacks[#p.updateCallbacks + 1] = callback

        if p.onUpdateRegister then
            p.onUpdateRegister(callback)
        end
    end

    function p:ready()
        self.api.isReady = true

        for _, cb in ipairs(self.readyCallbacks) do
            cb()
        end
    end

    function p:emit(id, index, reason)
        for _, cb in ipairs(self.updateCallbacks) do
            assert(pcall(cb, id, index, reason))
        end
    end

    return p
end

local function fixture(ready, options)
    local p = provider(ready)

    local state = {
        now = 100,
        loaded = true,
        api = p.api,
        version = '12.1.0',
        family = 'tbc',
        resolves = 0,
        clocks = 0,
    }

    local addon = {}
    loadAdapter(addon)

    local opts = {
        resolve = function()
            state.resolves = state.resolves + 1
            return { loaded = state.loaded, api = state.api, version = state.version, family = state.family }
        end,
        now = function()
            state.clocks = state.clocks + 1
            return state.now
        end,
        readable = function(value) return value ~= state.secret end,
    }

    -- A nil secret must remain readable.
    opts.readable = function(value) return state.secret == nil or value ~= state.secret end

    for k, v in pairs(options or {}) do
        opts[k] = v
    end

    return addon.Integrations.NewQuestie(opts), p, state, opts
end

local function unavailable(service, id, reason)
    local row = service:GetRecentUpdate(id)
    assert(row.status == 'unavailable' and (reason == nil or row.reason == reason), row.reason)
    assert(row.questId == nil and row.observedAt == nil and row.completed == nil)
end

local function available(service, id, reason)
    local row = service:GetRecentUpdate(id)
    assert(row.status == 'available', row.reason)
    assert(row.source == 'Questie' and row.kind == 'quest-update' and row.questId == id and row.reason == reason)
    assert(row.coverage == 'receipt-only' and row.completed == nil and row.progress == nil)
    return row
end

test('disabled construction refresh and queries never discover or read a clock', function()
    local s, p, x = fixture(true)
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().enabled == false)
    assert(s:Refresh().state == 'disabled')
    unavailable(s, 7)
    assert(x.resolves == 0 and x.clocks == 0 and p.readyCalls == 0 and p.updateCalls == 0)
    local ok, why = s:SetEnabled('true')
    assert(ok == false and why == 'invalid-enabled')
end)

test('absence is explicit across every family and cannot register callbacks', function()
    for _, family in ipairs({ 'era', 'tbc', 'progression', 'forever', 'retail', 'unknown' }) do
        local s, p, x = fixture(true)
        x.family = family
        x.loaded = false
        x.api = nil
        assert(s:SetEnabled(true))
        assert(s:GetStatus().state == 'missing')
        unavailable(s, 7)
        assert(p.readyCalls == 0 and p.updateCalls == 0)
    end
end)

test('late provider attaches only on explicit refresh and waiting differs from loaded', function()
    local s, p, x = fixture(false)
    x.loaded = false
    s:SetEnabled(true)
    x.loaded = true
    assert(s:GetStatus().state == 'missing')
    s:Refresh()
    assert(s:GetStatus().state == 'waiting' and p.readyCalls == 1 and p.updateCalls == 0)
    p:ready()
    assert(s:GetStatus().state == 'available' and p.updateCalls == 1)
    p:emit(7, nil, 1)
    local row = available(s, 7, 'accepted')
    assert(row.objectiveIndex == nil)
end)

test('synchronous readiness and repeated toggles register once per actual API', function()
    local s, p = fixture(true)
    s:SetEnabled(true)

    for _ = 1, 100 do
        s:SetEnabled(true)
        s:Refresh()
        s:SetEnabled(false)
        s:SetEnabled(true)
    end

    assert(p.readyCalls == 1 and p.updateCalls == 1 and s:GetStatus().state == 'available')
    p:emit(7, 2, 2)
    local a = available(s, 7, 'updated')
    p:emit(7, 2, 2)
    assert(available(s, 7, 'updated').sequence == a.sequence + 1)
end)

test('status distinguishes source version and declared family from native acceptance', function()
    for _, family in ipairs({ 'era', 'tbc', 'progression', 'forever' }) do
        local s, _, x = fixture(true)
        x.family = family
        s:SetEnabled(true)
        local st = s:GetStatus()
        assert(st.state == 'available' and st.family == family and st.familyContract == 'declared-unverified')
        assert(st.versionStatus == 'source-tested' and st.nativeAcceptance == 'unverified')
        assert(st.provider == 'Questie' and st.coverage == 'recent-update-receipts-only')
        x.version = '99.1'
        s:Refresh()
        assert(s:GetStatus().versionStatus == 'unverified')
        x.version = nil
        s:Refresh()
        assert(s:GetStatus().versionStatus == 'unverified')
        x.version = string.rep('x', 400)
        s:Refresh()
        assert(#s:GetStatus().version <= 64)
    end
end)

test('unsupported families do not subscribe or claim available', function()
    for _, family in ipairs({ 'retail', 'unknown', 'imagined' }) do
        local s, p, x = fixture(true)
        x.family = family
        s:SetEnabled(true)
        assert(s:GetStatus().state ~= 'available' and s:GetStatus().familyContract == 'unsupported')
        assert(p.readyCalls == 0 and p.updateCalls == 0)
    end
end)

test('malformed public shapes and enums fail closed without invoking registration', function()
    for _, mutate in ipairs({
        function(a)
            a.RegisterOnReady = nil
        end,
        function(a)
            a.RegisterForQuestUpdates = true
        end,
        function(a)
            a.Enums = nil
        end,
        function(a)
            a.Enums.QuestUpdateTriggerReason.QUEST_UPDATED = 9
        end,
        function(a)
            a.isReady = 1
        end,
        function(a)
            a.Enums.QuestUpdateTriggerReason.QUEST_ACCEPTED = '1'
        end,
    }) do
        local s, p = fixture(true)
        mutate(p.api)
        s:SetEnabled(true)
        assert(s:GetStatus().state == 'incompatible' and p.readyCalls == 0 and p.updateCalls == 0)
    end
end)

test('four reasons remain receipt facts with detached values and same-clock sequence', function()
    local s, p = fixture(true)
    s:SetEnabled(true)

    for i, reason in ipairs({ 'accepted', 'updated', 'turned-in', 'abandoned' }) do
        p:emit(7, i, i)
        local row = available(s, 7, reason)
        assert(row.objectiveIndex == i and row.observedAt == 100 and row.expiresAt == 130 and row.sequence == i)
        row.questId = 99
        row.reason = 'invented'
        assert(available(s, 7, reason).questId == 7)
    end
end)

test('receipt retention expires exactly at thirty seconds and never guesses missing facts', function()
    local s, p, x = fixture(true)
    s:SetEnabled(true)
    unavailable(s, 7)
    p:emit(7, nil, 2)
    x.now = 129.999
    available(s, 7, 'updated')
    x.now = 130
    unavailable(s, 7)
    x.now = 131
    p:emit(8, nil, 1)
    available(s, 8, 'accepted')
    unavailable(s, 7)
end)

test('sixty fifth distinct quest evicts oldest receipt while overwrite refreshes order', function()
    local s, p = fixture(true)
    s:SetEnabled(true)

    for id = 1, 64 do
        p:emit(id, nil, 2)
    end

    p:emit(1, nil, 3)
    p:emit(65, nil, 4)
    unavailable(s, 2)
    available(s, 1, 'turned-in')
    available(s, 65, 'abandoned')

    for id = 3, 64 do
        available(s, id, 'updated')
    end
end)

test('disabled and disposed callbacks stay inert and disposal is terminal', function()
    local s, p, x = fixture(true)
    s:SetEnabled(true)
    p:emit(7, nil, 2)
    s:SetEnabled(false)
    local before = x.resolves
    p:ready()
    p:emit(8, nil, 2)
    assert(x.resolves == before)
    unavailable(s, 7)
    s:SetEnabled(true)
    unavailable(s, 7)
    s:Dispose()
    before = x.resolves
    p:ready()
    p:emit(8, nil, 2)
    assert(x.resolves == before and s:Refresh() == nil)
    local ok, why = s:SetEnabled(true)
    assert(ok == false and why == 'disposed')
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().reason == 'disposed')
end)

test('queries detect replacement clear receipts and never subscribe before explicit refresh', function()
    local s, p, x = fixture(true)
    s:SetEnabled(true)
    p:emit(7, nil, 2)
    local q = provider(true)
    x.api = q.api
    unavailable(s, 7)
    assert(q.readyCalls == 0 and q.updateCalls == 0)
    p:emit(7, nil, 1)
    s:Refresh()
    p:emit(8, nil, 2)
    unavailable(s, 8)
    q:emit(8, nil, 3)
    available(s, 8, 'turned-in')
end)

test('actual API identity ignores equality metamethods for receipts and retained callbacks', function()
    local s, p, x = fixture(true)
    local comparisons = 0

    local meta = {
        __eq = function()
            comparisons = comparisons + 1
            return true
        end,
    }

    setmetatable(p.api, meta)

    local replacement = setmetatable({
        isReady = true,
        Enums = p.api.Enums,
        RegisterOnReady = p.api.RegisterOnReady,
        RegisterForQuestUpdates = p.api.RegisterForQuestUpdates,
    }, meta)

    s:SetEnabled(true)
    p:emit(7, nil, 2)
    available(s, 7, 'updated')
    local oldReady, oldUpdate = p.readyCallbacks[1], p.updateCallbacks[1]
    x.api = replacement
    unavailable(s, 7)
    assert(p.updateCalls == 1, 'query subscribed during replacement')
    s:Refresh()
    assert(s:GetStatus().state == 'available' and p.updateCalls == 2)
    local resolves = x.resolves
    oldReady()
    oldUpdate(8, nil, 2)
    assert(x.resolves == resolves, 'retired callback impersonated replacement API')
    unavailable(s, 8)
    p.updateCallbacks[2](9, nil, 3)
    available(s, 9, 'turned-in')
    assert(comparisons == 0, 'provider equality metamethod was invoked for ownership')
end)

test('old queued readiness cannot attach replacement provider', function()
    local s, p, x = fixture(false)
    s:SetEnabled(true)
    local q = provider(false)
    x.api = q.api
    s:Refresh()
    p:ready()
    assert(p.updateCalls == 0 and q.updateCalls == 0)
    q:ready()
    assert(q.updateCalls == 1)
    q:emit(7, nil, 2)
    available(s, 7, 'updated')
end)

test('changed registration functions and lost readiness retire current observations', function()
    local s, p = fixture(true)
    s:SetEnabled(true)
    p:emit(7, nil, 2)
    available(s, 7, 'updated')

    p.api.RegisterForQuestUpdates = function()
        error('must not auto-register')
    end

    p:emit(8, nil, 2)
    unavailable(s, 7)
    unavailable(s, 8)
    local t, q = fixture(true)
    t:SetEnabled(true)
    q:emit(7, nil, 2)
    q.api.isReady = false
    unavailable(t, 7)
    q:emit(8, nil, 2)
    unavailable(t, 8)
end)

test('invalid identifiers and malformed payloads cannot create receipts', function()
    local s, p, x = fixture(true)
    s:SetEnabled(true)
    p:emit(8, nil, 2)
    available(s, 8, 'updated')

    for _, id in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, '7', {}, false }) do
        p:emit(id, nil, 2)
        unavailable(s, id)
    end

    for _, index in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, '2', {}, false }) do
        p:emit(7, index, 2)
        unavailable(s, 7)
    end

    for _, reason in ipairs({ 0, 5, '2', {}, false, 0 / 0, math.huge }) do
        p:emit(7, nil, reason)
        unavailable(s, 7)
    end

    x.secret = {}
    p:emit(x.secret, nil, 2)
    unavailable(s, 7)
end)

test('unreadable public values are restricted before comparison', function()
    local s, p, x = fixture(true)
    x.secret = {}
    p.api.isReady = x.secret
    s:SetEnabled(true)
    assert(s:GetStatus().state == 'client-restricted' and p.readyCalls == 0)
end)

test('clock failures nonfinite values and backward jumps invalidate retained receipts', function()
    for _, bad in ipairs({ false, math.huge, 0 / 0, 99 }) do
        local s, p, x = fixture(true)
        s:SetEnabled(true)
        p:emit(7, nil, 2)
        x.now = bad
        unavailable(s, 7)
        x.now = 101
        unavailable(s, 7)
        assert(s:GetStatus().state == 'error')
    end

    local fail = false

    local t, q = fixture(true, {
        now = function()
            if fail then
                error('private-clock')
            end

            return 100
        end,
    })

    t:SetEnabled(true)
    q:emit(7, nil, 2)
    fail = true
    unavailable(t, 7)
    assert(t:GetStatus().state == 'error')
end)

test('provider and resolver exceptions are contained and use fixed reasons', function()
    local s = fixture(true, {
        resolve = function()
            error('private-resolver')
        end,
    })

    assert(s:SetEnabled(true))
    assert(s:GetStatus().state == 'error' and not s:GetStatus().reason:find('private'))

    for _, name in ipairs({ 'RegisterOnReady', 'RegisterForQuestUpdates' }) do
        local t, p = fixture(true)

        p.api[name] = function()
            error('private-register')
        end

        assert(t:SetEnabled(true))
        assert(t:GetStatus().state == 'error')
        assert(not t:GetStatus().reason:find('private'))
        p:emit(7, nil, 2)
        unavailable(t, 7)
    end
end)

test('arbitrary thrown tables cannot choose public status or trigger error getters', function()
    for _, payload in ipairs({
        { state = 'PRIVATE_STATE', reason = 'PRIVATE_REASON', owner = {} },
        setmetatable({}, {
            __index = function()
                error('private-error-getter')
            end,
        }),
    }) do
        local addon = {
            Platform = setmetatable({ GetClientInfo = function() return { family = 'tbc' } end }, {
                __index = function(_, key)
                    if key == 'CanReadValue' then
                        error(payload, 0)
                    end
                end,
            }),
        }

        loadAdapter(addon)
        local s = addon.Integrations.NewQuestie()
        assert(pcall(s.SetEnabled, s, true), 'exception escaped the adapter')
        local st = s:GetStatus()
        assert(st.state == 'error' and st.reason == 'adapter-error', 'arbitrary thrown table chose public status')
    end
end)

test('explicit refresh returns detached error status and retains observed metadata', function()
    local s, p = fixture(true)
    p.api.Enums = nil
    s:SetEnabled(true)
    local st = s:Refresh()
    assert(st and st.state == 'incompatible' and st.family == 'tbc' and st.version == '12.1.0')
    st.state = 'mutated'
    assert(s:GetStatus().state == 'incompatible')
end)

test('status queries are cached and detached while notifications cannot recurse on failure', function()
    local count = 0

    local s, p, x = fixture(true, {
        onChange = function(st)
            count = count + 1
            st.state = 'corrupt'
            error('private-notification')
        end,
    })

    s:SetEnabled(true)
    assert(count == 1 and s:GetStatus().state == 'error')
    local before = x.resolves
    local st = s:GetStatus()
    st.reason = 'corrupt'
    s:GetStatus()
    assert(x.resolves == before and s:GetStatus().reason ~= 'corrupt')
    p:emit(7, nil, 2)
    unavailable(s, 7)
end)

test('synchronous readiness publishes one notification for the final owned status', function()
    local changes = {}

    local s = fixture(true, {
        onChange = function(st)
            changes[#changes + 1] = st
        end,
    })

    s:SetEnabled(true)
    assert(#changes == 1 and changes[1].state == 'available', 'duplicate readiness notification')
end)

test('readiness loss during ready registration cannot start an updates subscription', function()
    local s, p = fixture(true)

    p.onReadyRegister = function()
        p.api.isReady = false
    end

    s:SetEnabled(true)
    assert(p.updateCalls == 0 and s:GetStatus().state == 'waiting')
end)

test('notification disposal during error recovery cannot escape or replace terminal status', function()
    local s, armed

    s = fixture(true, {
        resolve = function()
            error('private-resolver')
        end,
        onChange = function()
            if armed then
                s:Dispose()
                error('private-notification')
            end
        end,
    })

    armed = true
    assert(pcall(s.SetEnabled, s, true), 'error-recovery notification escaped the adapter')
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().reason == 'disposed')
end)

test('disposal notification failure keeps disposal permanent', function()
    local s = fixture(true, {
        onChange = function()
            error('private-notification')
        end,
    })

    s:Dispose()
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().reason == 'disposed')
end)

test('registration function replacement cannot acquire a second trampoline on the same API', function()
    local s, p = fixture(true)
    s:SetEnabled(true)
    p:emit(7, nil, 2)
    available(s, 7, 'updated')
    s:SetEnabled(false)
    local calls = 0

    p.api.RegisterOnReady = function()
        calls = calls + 1
    end

    s:SetEnabled(true)
    assert(calls == 0 and s:GetStatus().state == 'incompatible')
    p:emit(7, nil, 2)
    unavailable(s, 7)
end)

test('failed ready registration after disable preserves its outcome without publishing stale error', function()
    local s, p = fixture(true)
    local calls = 0

    p.api.RegisterOnReady = function()
        calls = calls + 1
        s:SetEnabled(false)
        error('private-ready-register', 0)
    end

    s:SetEnabled(true)
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().reason == 'disabled')
    s:SetEnabled(true)

    assert(
        s:GetStatus().state == 'error' and s:GetStatus().reason == 'registration-failed',
        'failed retired ready registration was treated as confirmed'
    )

    assert(calls == 1 and p.updateCalls == 0)
end)

test('failed updates registration after disable preserves its outcome without publishing stale error', function()
    local s, p = fixture(true)
    local calls = 0

    p.api.RegisterForQuestUpdates = function()
        calls = calls + 1
        s:SetEnabled(false)
        error('private-update-register', 0)
    end

    s:SetEnabled(true)
    assert(s:GetStatus().state == 'disabled' and s:GetStatus().reason == 'disabled')
    s:SetEnabled(true)

    assert(
        s:GetStatus().state == 'error' and s:GetStatus().reason == 'registration-failed',
        'failed retired updates registration was treated as confirmed'
    )

    assert(calls == 1)
    unavailable(s, 7)
end)

test('every readability boundary stops immediately when its lease is retired', function()
    local total = 0

    local baseline = fixture(true, {
        readable = function()
            total = total + 1
            return true
        end,
    })

    baseline:SetEnabled(true)

    for target = 1, total do
        local s, reads, armed = nil, 0, false

        s = fixture(true, {
            readable = function()
                reads = reads + 1

                if armed and reads == target then
                    s:Dispose()
                end

                return true
            end,
        })

        armed = true
        s:SetEnabled(true)
        assert(reads == target, 'continued reading after retirement at field ' .. target)
        assert(s:GetStatus().reason == 'disposed')
    end
end)

test('synchronous registration reentry retires the outer operation before later phases', function()
    for _, action in ipairs({ 'disable', 'dispose', 'replace' }) do
        local s, p, x = fixture(true)
        local q = provider(true)

        p.onReadyRegister = function()
            if action == 'disable' then
                s:SetEnabled(false)
            elseif action == 'dispose' then
                s:Dispose()
            else
                x.api = q.api
                s:Refresh()
            end
        end

        s:SetEnabled(true)
        assert(p.updateCalls == 0)

        if action == 'replace' then
            assert(q.updateCalls == 1)
            q:emit(7, nil, 2)
            available(s, 7, 'updated')
        else
            assert(s:GetStatus().state == 'disabled')
        end
    end
end)

test('resolver readability clock and notification reentry stop stale publication', function()
    for _, phase in ipairs({ 'resolve', 'readable', 'now', 'notify' }) do
        local service, armed
        local notifications = 0
        local p = provider(true)

        local opts = {
            resolve = function()
                if armed and phase == 'resolve' then
                    service:Dispose()
                end

                return { loaded = true, api = p.api, version = '12.1.0', family = 'tbc' }
            end,
            readable = function()
                if armed and phase == 'readable' then
                    service:Dispose()
                end

                return true
            end,
            now = function()
                if armed and phase == 'now' then
                    service:Dispose()
                end

                return 100
            end,
            onChange = function()
                notifications = notifications + 1

                if armed and phase == 'notify' then
                    service:Dispose()
                end
            end,
        }

        local addon = {}
        loadAdapter(addon)
        service = addon.Integrations.NewQuestie(opts)

        if phase == 'now' then
            service:SetEnabled(true)
            armed = true
            p:emit(7, nil, 2)
        else
            armed = true
            service:SetEnabled(true)
        end

        assert(service:GetStatus().reason == 'disposed')
        unavailable(service, 7)

        if phase == 'resolve' or phase == 'readable' then
            assert(p.readyCalls == 0 and p.updateCalls == 0)
        end

        assert(notifications <= 2)
    end
end)

test('default dependencies use protected native reads and platform family/readability', function()
    local p = provider(true)

    local addon = {
        Platform = {
            GetClientInfo = function() return { family = 'era' } end,
            CanReadValue = function() return true end,
        },
    }

    local env = setmetatable({
        _G = false,
        Questie = { API = p.api },
        GetTime = function() return 10 end,
        C_AddOns = {
            IsAddOnLoaded = function(name)
                assert(name == 'Questie')
                return true
            end,
            GetAddOnMetadata = function(name, key)
                assert(name == 'Questie' and key == 'Version')
                return '12.1.0'
            end,
        },
    }, { __index = _G })

    env._G = env
    loadAdapter(addon, env)
    local s = addon.Integrations.NewQuestie()
    s:SetEnabled(true)
    p:emit(7, nil, 2)
    assert(available(s, 7, 'updated').observedAt == 10 and s:GetStatus().family == 'era')

    env.C_AddOns.IsAddOnLoaded = function()
        error('private-native')
    end

    s:Refresh()
    assert(s:GetStatus().state == 'error')
end)

finish()
