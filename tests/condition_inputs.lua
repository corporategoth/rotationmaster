-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    return f
end

local function enter(w, text, event)
    w.editbox:SetText(text)
    w.editbox.scripts.OnTextChanged(w.editbox, true)

    if event then
        return w.editbox.scripts[event](w.editbox)
    end
end

test('flat condition text inputs commit Enter or blur once and Escape restores confirmed text', function()
    local f = fixture()
    assert(f.addon.CreateConditionEditBox, 'native condition edit factory missing')
    local w = f.addon:CreateConditionEditBox()
    local calls = 0
    local last
    w:SetLabel('Name')
    w:SetText('Original')

    w:SetCallback('OnEnterPressed', function(_, _, value)
        calls = calls + 1
        last = value
    end)

    assert(w.type == 'RM-ConditionEditBox' and w:GetText() == 'Original' and calls == 0)
    enter(w, 'Renamed', 'OnEnterPressed')
    assert(calls == 1 and last == 'Renamed' and not w:IsPending())
    w.editbox.scripts.OnEditFocusLost(w.editbox)
    assert(calls == 1, 'blur repeated the confirmed edit')
    enter(w, 'By focus', 'OnEditFocusLost')
    assert(calls == 2 and last == 'By focus')
    enter(w, 'Cancelled', 'OnEscapePressed')
    assert(w:GetText() == 'By focus' and not w:IsPending() and calls == 2)
end)

test('flat slider raw percent values preserve fractions and reject malformed or unbounded edits', function()
    local f = fixture()
    assert(f.addon.CreateConditionSlider, 'native condition slider factory missing')
    local w = f.addon:CreateConditionSlider()
    local calls = 0
    local last
    w:SetValue(.333333333)
    w:SetSliderValues(0, 1, .01)
    w:SetIsPercent(true)

    w:SetCallback('OnValueChanged', function(_, _, value)
        calls = calls + 1
        last = value
    end)

    assert(
        w.type == 'RM-ConditionSlider' and w:GetValue() == .333333333 and calls == 0,
        'viewing rounded the saved fraction'
    )

    enter(w, '37.5%', 'OnEnterPressed')
    assert(last == .375 and calls == 1 and w:GetValue() == .375)

    for _, text in ipairs({ '', 'oops', 'nan', '1e999', '-1', '101', '25%%' }) do
        enter(w, text)
        assert(not w:CommitPending() and w:GetValue() == .375 and calls == 1, 'invalid percent committed: ' .. text)
        assert(w.editbox.textColor[2] < 1, 'invalid input was not marked')
        w.editbox.scripts.OnEscapePressed(w.editbox)
    end

    enter(w, '37.125', 'OnEditFocusLost')
    assert(w:GetValue() == .37125 and calls == 2, 'typed precision was snapped to drag step')
    w.slider:SetValue(.606)
    assert(w:GetValue() == .61 and math.abs(last - .61) < .000001, 'slider gesture ignored step')
    w:SetIsPercent(false)
    enter(w, '0.825', 'OnEnterPressed')
    assert(last == .825)
    w:SetSliderValues(0, 1, .1)
    w:SetValue(.8)
    w.slider.scripts.OnMouseWheel(w.slider, 1)
    assert(math.abs(w:GetValue() - .9) < .000001)
    w:SetDisabled(true)
    w.slider.scripts.OnMouseWheel(w.slider, -1)
    assert(math.abs(w:GetValue() - .9) < .000001, 'readonly slider accepted wheel input')
end)

test('missing and out-of-range saved slider references remain unchanged until an explicit edit', function()
    local f = fixture()
    local w = f.addon:CreateConditionSlider()
    w:SetValue(nil)
    w:SetSliderValues(0, 1, .01)
    assert(w:GetValue() == nil and w.editbox:GetText() == '' and not w:IsPending())
    w:SetValue(1.5)
    w:SetSliderValues(0, 1, .01)
    assert(w:GetValue() == 1.5, 'viewing silently clamped an authored value')
    enter(w, '0.5', 'OnEnterPressed')
    assert(w:GetValue() == .5)
end)

test('disabled released and reused native inputs cannot commit stale edits or retain percent settings', function()
    local f = fixture()

    for _, method in ipairs({ 'CreateConditionEditBox', 'CreateConditionSlider' }) do
        local w = f.addon[method](f.addon)
        local calls = 0

        w:SetCallback(w.type == 'RM-ConditionSlider' and 'OnValueChanged' or 'OnEnterPressed', function()
            calls = calls + 1
        end)

        if w.SetValue then
            w:SetValue(.5)
            w:SetIsPercent(true)
        else
            w:SetText('Saved')
        end

        w:SetDisabled(true)
        enter(w, '20', 'OnEnterPressed')
        assert(calls == 0)
        w:SetDisabled(false)
        enter(w, '30')
        local stale = w.editbox.scripts.OnEnterPressed
        w:OnRelease()
        stale(w.editbox)
        assert(calls == 0)
        w.userdata = {}
        w:OnAcquire()
        assert(not w:IsPending())

        if w.GetValue then
            assert(not w.isPercent and w:GetValue() == nil)
        end
    end
end)

test('built-in conditions route text and sliders through native shared factories', function()
    for _, name in ipairs({ 'common', 'combat', 'spatial', 'stats' }) do
        local h = assert(io.open('Conditions/' .. name .. '.lua'))
        local source = h:read('*a')
        h:close()

        assert(
            not source:find('AceGUI:Create("EditBox")', 1, true)
                and not source:find('AceGUI:Create("Slider")', 1, true),
            name .. ' retains old input visuals'
        )
    end
end)

test('temporary popup hides retain pending text and invalid numeric blockers while release discards them', function()
    local f = fixture()
    local w = f.addon:CreateConditionSlider()
    local calls = 0
    w:SetValue(.5)
    w:SetSliderValues(0, 1, .01)

    w:SetCallback('OnValueChanged', function()
        calls = calls + 1
    end)

    enter(w, 'bad')
    w.frame:Hide()
    w.frame:Show()
    assert(w:IsPending() and not w:CommitPending(), 'temporary hide lost an invalid-input blocker')
    enter(w, '0.75')
    w.frame:Hide()
    w.frame:Show()
    assert(w:CommitPending() and w:GetValue() == .75 and calls == 1, 'temporary hide lost a valid input')
    enter(w, '0.8')
    w.isQueuedForRelease = true
    w.frame:Hide()
    w.editbox.scripts.OnEditFocusLost(w.editbox)
    w:OnRelease()
    assert(calls == 1 and not w:IsPending(), 'Ace hide-before-release committed abandoned input')
end)

test('opening the real Distance Count declaration never fills a missing numeric field', function()
    local f = fixture()
    local a = f.addon
    f.env.C_CVar = { GetCVar = function() return '40' end }
    f.load('Platform/range.lua')
    f.load('Conditions/common.lua')
    f.load('Conditions/spatial.lua')
    local value = { operator = 'GREATERTHAN', value = 0 }
    local parent, top = f.widget('Group'), f.widget('Frame')
    parent:SetUserData('top', top)
    top:SetUserData('root', value)
    top:SetUserData('funcs', { print = function() return 'Updated' end })
    a.definitions.DISTANCE_COUNT.widget(parent, 0, value)
    local slider = parent.children[4]

    assert(
        value.enemy == nil and value.distance == nil and slider:GetValue() == nil and slider.editbox:GetText() == '',
        'opening the field manufactured a saved distance'
    )

    enter(slider, '25', 'OnEnterPressed')
    assert(value.distance == 25)
    f.env.C_CVar = nil
    local unavailable = { operator = 'GREATERTHAN', value = 0, distance = 25 }
    local other = f.widget('Group')
    other:SetUserData('top', top)
    a.definitions.DISTANCE_COUNT.widget(other, 0, unavailable)

    assert(
        unavailable.enemy == nil and unavailable.distance == 25 and other.children[4].disabled,
        'unavailable setting mutated the draft or left an invented range enabled'
    )
end)

test('real Distance field commits notify its owning detached editor', function()
    local f = fixture()
    local a = f.addon
    f.load('Conditions/common.lua')
    f.load('Conditions/spatial.lua')
    local value = { unit = 'target', value = 20 }
    local parent, top = f.widget('Group'), f.widget('Frame')
    local updates = 0
    parent:SetUserData('top', top)
    top:SetUserData('root', value)

    top:SetUserData('funcs', {
        print = function(_, root)
            updates = updates + 1
            assert(root == value)
            return 'Updated'
        end,
    })

    a.definitions.DISTANCE.widget(parent, 0, value)
    local input = parent.children[2]
    enter(input, '30', 'OnEnterPressed')
    assert(value.value == 30 and updates == 1, 'Distance commit bypassed editor synchronization')
end)

finish()
