-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local fixture = dofile('tests/fixtures/lua_workbench.lua')

local function tick(frame)
    local update = frame:GetScript('OnUpdate')

    if update then
        update(frame, .1)
    end

    for _, hook in ipairs(frame.hooks and frame.hooks.OnUpdate or {}) do
        hook(frame, .1)
    end
end

for _, provider in ipairs({ 'plain', 'WowLua' }) do
    local f, a = fixture()
    a.CreateLuaWorkbenchEngine = function() return nil end
    local create = f.env.CreateFrame

    f.env.CreateFrame = function(...)
        local frame = create(...)

        function frame:IsMultiLine()
            return true
        end

        function frame:GetMaxBytes()
            return 0
        end

        function frame:SetMaxBytes() end

        function frame:GetMaxLetters()
            return 0
        end

        return frame
    end

    f.env.C_AddOns = { IsAddOnLoaded = function(id) return id == 'WowLua' end }
    f.env.WowLua = {}
    f.load('LibsAugment/FAIAP.lua')
    f.env.WowLua.indent = a.LuaSyntax
    f.load('LibsAugment/WowLua.lua')
    local c = a:CreateWorkbenchLuaEditor(f.env.UIParent, function() end, function() return true end, provider)
    local inner = c.inner or c
    inner.frame:SetSize(620, 300)
    c:SetText('first\nsecond\nthird')
    inner:Layout()
    tick(inner.frame)
    local state = assert(inner.standaloneLineNumbers, provider .. ' has no independent gutter')
    assert(inner.lineNumbersVisible and state.frame:IsShown(), 'gutter not visible')
    assert(not state.frame:DoesClipChildren(), 'native gutter must not clip; clipping hides caret on WoW clients')

    if provider == 'WowLua' then
        c:SetText('local value = 1')
        local edit = inner.edit

        for _, hook in ipairs(edit.hooks and edit.hooks.OnTextChanged or {}) do
            hook(edit, true)
        end

        tick(edit)
        assert(inner.nativeGetText(edit):find('|cff', 1, true), 'syntax color was not applied on next frame')
        assert(c:GetText() == 'local value = 1', 'coloring changed source')
        c:SetText('first\nsecond\nthird')
        inner:Layout()
        tick(inner.frame)
    end

    for i = 1, 3 do
        assert(
            state.rows[i] and state.rows[i]:IsShown() and state.rows[i]:GetText() == tostring(i),
            'missing line ' .. i
        )
    end

    inner.scroll:SetHeight(15)
    inner.scroll:SetVerticalScroll(30)
    tick(inner.frame)
    assert(tonumber(state.rows[1]:GetText()) > 1, 'gutter did not scroll')
    inner.scroll:SetVerticalScroll(0)
    inner.scroll:SetHeight(200)
    tick(inner.frame)
    local text = c:GetText()
    a.db.profile.lua_line_numbers = false
    inner:Layout('line-number-setting')
    tick(inner.frame)
    assert(not state.frame:IsShown(), 'gutter did not hide')
    a.db.profile.lua_line_numbers = true
    inner:Layout('line-number-setting')
    tick(inner.frame)
    assert(state.frame:IsShown() and c:GetText() == text, 'gutter did not reappear safely')
    c:Release()
    assert(not state.frame:IsShown(), 'released gutter remained visible')
    c:Acquire(function() end, function() return true end)
    inner = c.inner or c
    state = assert(inner.standaloneLineNumbers)
    inner.frame:SetSize(620, 300)
    c:SetText('one\ntwo')
    inner:Layout()
    tick(inner.frame)
    assert(state.frame:IsShown() and state.rows[2]:GetText() == '2', 'gutter did not survive reuse')
    c:Release()
end

print('PASS standalone gutters for plain and WowLua without LuaWorkbench')
