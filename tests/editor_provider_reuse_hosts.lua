-- Actual source hosts and provider lifecycles; codec fixture requires LuaJIT bit.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function prefix(path, change)
    local file = assert(io.open(path))
    local text = file:read('*a')
    file:close()
    text = assert(text:match('^(.-)\ntest%('))

    if change then
        text = change(text)
    end

    return assert(loadstring(text .. '\nreturn fixture', '@actual-host-prefix'))()
end

local function available(f)
    f.env.C_AddOns = { IsAddOnLoaded = function(name) return name == '!!!LuaWorkbench' end }
    f.env.IsAddOnLoaded = f.env.C_AddOns.IsAddOnLoaded
end

local function counter(f)
    local n = 0
    local create = f.env.CreateFrame

    f.env.CreateFrame = function(...)
        n = n + 1
        return create(...)
    end

    return function() return n end
end

local function tick(code)
    local c = code.inner or code
    local update = c.frame:GetScript('OnUpdate')

    if update then
        update(c.frame, .1)
    end

    for _, hook in ipairs(c.frame.hooks.OnUpdate or {}) do
        hook(c.frame, .1)
    end
end

local providers = { 'plain', 'native', 'LuaWorkbench' }

local function assertVisibleInput(code)
    local inner = code.inner or code
    local input = (inner.engine or inner.completionEngine).Query.Console.input
    local frame = input.editBox

    while frame do
        assert(frame:IsShown(), 'active source input has a hidden ancestor')
        frame = frame:GetParent()
    end
end

test('actual condition host cycles providers with bounded controls and source reset', function()
    local f, a = prefix('tests/custom_authoring_ui.lua')(false, true)
    available(f)
    local frames = counter(f)
    local controls = {}
    local warm

    for cycle = 1, 5 do
        a.db.profile.lua_line_numbers = cycle % 2 == 1

        for _, provider in ipairs(providers) do
            a.db.profile.lua_editor = provider
            local d = a:condition_edit_box(function() end)
            local code = d.code

            if controls[provider] then
                assert(code == controls[provider], 'host control recreated')
            else
                controls[provider] = code
            end

            d:SetCode('local x=1\nreturn x')
            tick(code)
            tick(code)
            assertVisibleInput(code)
            d:SelectFunction('valid')
            tick(code)
            tick(code)
            assertVisibleInput(code)
            d:SelectFunction('evaluate')
            tick(code)
            tick(code)
            assertVisibleInput(code)
            local inner = code.inner or code
            local engine = inner.engine or inner.completionEngine

            if a.db.profile.lua_line_numbers then
                assert(
                    engine.Query.Console.input.queryLineNumbers
                        and #engine.Query.Console.input.queryLineNumbers.positions == 2
                )
            else
                assert(not inner.lineNumbersVisible)
            end

            d:Close()
            assert(code.released and inner.released)
        end

        if warm then
            assert(frames() == warm, 'actual condition host grew ' .. frames() .. '/' .. warm)
        else
            warm = frames()
        end
    end

    print('CONTROL actualconditionhost', 'frames=' .. frames(), 'cycles=5', 'providercontrols=3')
end)

test('actual Functions host cycles providers and entities with bounded controls and fresh metadata', function()
    local build = prefix('tests/functions_ui.lua', function(text)
        text = text:gsub('local f=F.new%(%)', 'local f=dofile("tests/fixtures/lua_workbench.lua")()', 1)
        text = text:gsub("dofile%('tests/fixtures/native_ui.lua'%)%(f.env%);", '', 1)
        return text
    end)

    local f, a, host = build()
    available(f)
    local frames = counter(f)

    local function source(name)
        return {
            name = name,
            description = 'Doc ' .. name,
            args = {},
            returns = {},
            code = 'return "' .. name .. '"',
            bindings = {},
        }
    end

    a.db.global.custom_functions.A = source('A')
    a.db.global.custom_functions.B = source('B')
    local p = a:OpenNativeSettings(host, 'Functions')
    local controls = {}
    local warm

    for cycle = 1, 5 do
        a.db.profile.lua_line_numbers = cycle % 2 == 1

        for _, provider in ipairs(providers) do
            a.db.profile.lua_editor = provider
            p.functionID = cycle % 2 == 0 and 'A' or 'B'
            p:Draw()
            local d = p.inlineFunction
            local code = d.code

            if controls[provider] then
                assert(code == controls[provider], 'function host recreated')
            else
                controls[provider] = code
            end

            tick(code)
            tick(code)
            assertVisibleInput(code)
            local inner = code.inner or code
            assert(inner.context.id == p.functionID, 'stale source context')

            if inner.engine then
                local snippets = inner.engine.Workspace.db.snippets
                local n = 0

                for _ in pairs(snippets) do
                    n = n + 1
                end

                assert(n == 1 and snippets[p.functionID], 'workspace retained old entity')
            end

            d:Close()
        end

        if warm then
            assert(frames() == warm, 'actual functions host grew ' .. frames() .. '/' .. warm)
        else
            warm = frames()
        end
    end

    print('CONTROL actualfunctionshost', 'frames=' .. frames(), 'cycles=5', 'providercontrols=3')
end)

test('actual condition active redraw retains its queue and trace without extra native Enable', function()
    for _, provider in ipairs({ 'plain', 'LuaWorkbench' }) do
        local f, a = prefix('tests/custom_authoring_ui.lua')(false, true)
        available(f)
        a.db.profile.lua_editor = provider
        local d = a:condition_edit_box(function() end)
        local code = d.code
        local c = code.inner or code
        d:SetCode('local x=1\nreturn x')
        tick(code)
        tick(code)
        local C = (c.engine or c.completionEngine).Query.Console
        C:UpdateLineNumbers()
        local queue, trace = c.lineNumberQueue, c.inputTrace
        assert(queue.pending)
        local enables = 0
        local enable = c.edit.Enable

        c.edit.Enable = function(self, ...)
            enables = enables + 1
            return enable(self, ...)
        end

        for i = 1, 5 do
            d.form:Draw()

            assert(
                d.code == code and c.lineNumberQueue == queue and c.inputTrace == trace,
                'active Draw reset lifecycle'
            )

            assert(queue.pending)
        end

        assert(enables == 5, 'active Draw added provider Enable beyond existing SetReadOnly')
        tick(code)
        assert(not queue.pending)
        d:Close()
    end
end)

finish()
