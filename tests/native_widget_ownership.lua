local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local factories = {
    'CreateConditionGroup', 'CreateConditionEditBox', 'CreateConditionSlider', 'CreateConditionCheckBox',
    'CreateConditionDropdown', 'CreateConditionIcon', 'CreateConditionPositionPad', 'CreateConditionLabel',
    'CreateConditionLink', 'CreateConditionButton'
}

local function fixture()
    local f = F.new()
    local lookup = f.env.LibStub
    local attempts = 0

    f.env.LibStub = function(name, ...)
        if name == 'AceGUI-3.0' then
            attempts = attempts + 1
            error('native core requested foreign GUI library')
        end

        return lookup(name, ...)
    end

    return f, f.addon, function() return attempts end
end

local function foreign(f, spoof)
    local calls = 0
    local frame = f.env.CreateFrame('Frame')
    local child = { frame = frame, type = 'ForeignWidget', userdata = {}, events = {} }

    function child:GetUserData(key)
        return self.userdata[key]
    end

    function child:SetWidth()
        calls = calls + 1
        error('foreign widget geometry called')
    end

    function child:OnRelease()
        calls = calls + 1
    end

    if spoof then
        child.rmWidget = true
        child.rmActive = true
        child.rmLease = {}
    end

    return child, function() return calls end
end

test('native fixture and native module loading require no GUI library or registration bridges', function()
    local f, a = fixture()
    assert(f.libraries['AceGUI-3.0'] == nil, 'native fixture still provides GUI library')

    for _, path in ipairs({
        'UI/condition_widgets.lua', 'UI/condition_observation.lua', 'UI/condition_inputs.lua', 'UI/checkbox.lua',
        'UI/selector.lua', 'UI/condition_layout.lua', 'UI/condition_table.lua', 'UI/condition_icon.lua',
        'UI/condition_position.lua', 'UI/condition_display.lua'
    }) do
        f.load(path)
    end

    assert(a.GetConditionWidgetCompatibilityLibrary == nil and a.BindConditionGroupCompatibilityLibrary == nil)
end)

test('every native factory recycles one lease and retires old callbacks without library lookup', function()
    local _, a = fixture()

    for _, name in ipairs(factories) do
        local w = a[name](a)
        local calls = 0

        w:SetCallback('Probe', function()
            calls = calls + 1
        end)

        local stale = w.events.Probe
        w:SetUserData('discard', 'old')
        local lease = w.rmLease
        assert(a:IsConditionWidget(w) and w.rmActive and w.frame.obj == w)
        assert(a:ReleaseConditionWidget(w) and not a:ReleaseConditionWidget(w))
        local nextWidget = a[name](a)
        assert(nextWidget == w and nextWidget.rmLease ~= lease and nextWidget:GetUserData('discard') == nil)
        stale(w, 'Probe')
        assert(calls == 0)
        assert(nextWidget.AceGUIWidgetVersion == nil and nextWidget.rmLegacyOwned == nil)
        nextWidget:Release()
    end
end)

test('foreign and spoofed native-looking widgets cannot enter native trees or release pools', function()
    for _, spoof in ipairs({ false, true }) do
        local f, a = fixture()
        local group = a:CreateConditionGroup()
        local child, calls = foreign(f, spoof)
        local oldParent = child.frame:GetParent()
        local shown = child.frame:IsShown()
        local lease = child.rmLease
        local ok = pcall(group.AddChild, group, child)

        assert(
            not ok
                and #group.children == 0
                and child.parent == nil
                and child.frame:GetParent() == oldParent
                and calls() == 0,
            'foreign AddChild mutated ownership or geometry'
        )

        ok = pcall(a.ReleaseConditionWidget, a, child)

        assert(
            not ok
                and child.isQueuedForRelease == nil
                and child.rmLease == lease
                and child.frame:GetParent() == oldParent
                and child.frame:IsShown() == shown
                and calls() == 0,
            'foreign release mutated state'
        )

        a:ReleaseConditionWidget(group)
    end
end)

test('batch child insertion preflights all ownership before touching valid native siblings', function()
    local f, a = fixture()
    local group = a:CreateConditionGroup()
    local child = a:CreateConditionCheckBox()
    local bad = foreign(f, true)
    local oldParent = child.frame:GetParent()
    assert(not pcall(group.AddChildren, group, child, bad))

    assert(
        #group.children == 0 and child.parent == nil and child.frame:GetParent() == oldParent,
        'failed batch partially reparented native child'
    )

    group:AddChild(child)
    assert(not pcall(group.AddChild, group, child) and #group.children == 1, 'duplicate child acquired twice')
    a:ReleaseConditionWidget(group)
end)

test('native self parenting and ancestor insertion reject without creating parent cycles', function()
    local _, a = fixture()
    local root = a:CreateConditionGroup()
    local nested = a:CreateConditionGroup()
    root:AddChild(nested)
    assert(not pcall(nested.AddChild, nested, root) and root.parent == nil and #nested.children == 0)
    assert(not pcall(root.SetParent, root, root) and root.parent == nil, 'native SetParent created a self cycle')
    assert(not pcall(root.SetParent, root, nested) and root.parent == nil, 'native SetParent created an ancestor cycle')
    root:Release()
end)

test('unknown layout names and function aliases reject before geometry or layout state changes', function()
    local _, a = fixture()
    local group = a:CreateConditionGroup()
    group:SetWidth(320)
    local child = a:CreateConditionCheckBox()
    group:AddChild(child)
    local height = group.frame:GetHeight()
    local point = child.frame.point

    for _, layout in ipairs({
        'Flow',
        'Fill',
        'list',
        'table',
        'External',
        function()
            error('external layout executed')
        end,
    }) do
        assert(not pcall(group.SetLayout, group, layout), 'unsupported layout accepted')

        assert(
            group.layout == 'List'
                and group.frame:GetHeight() == height
                and child.frame.point == point
                and not group.layingOut
        )
    end

    a:ReleaseConditionWidget(group)
end)

test('native release discards pending and invalid child input before focus loss can commit it', function()
    local _, a = fixture()

    for _, numeric in ipairs({ false, true }) do
        local group = a:CreateConditionGroup()
        local child = numeric and a:CreateConditionSlider() or a:CreateConditionEditBox()
        group:AddChild(child)
        local commits = 0

        child:SetCallback(numeric and 'OnValueChanged' or 'OnEnterPressed', function()
            commits = commits + 1
        end)

        if numeric then
            child:SetValue(10)
        else
            child:SetText('saved')
        end

        child.editbox:SetText(numeric and 'invalid' or 'pending')
        child.editbox.scripts.OnTextChanged(child.editbox, true)

        group.frame:SetScript('OnHide', function()
            child.editbox.scripts.OnEditFocusLost(child.editbox)
        end)

        a:ReleaseConditionWidget(group)
        assert(commits == 0 and not child:IsPending() and not child.rmActive)
    end
end)

test('native observation and focus helpers never ask another GUI library to allocate or clear focus', function()
    local f, a, lookups = fixture()
    local allocations = {}
    local cleared = 0

    f.env.GetCurrentKeyBoardFocus = function()
        return {
            ClearFocus = function()
                cleared = cleared + 1
            end,
        }
    end

    local result = {
        a:WithConditionWidgetObservation(
            function(w)
                allocations[#allocations + 1] = w
            end,
            pcall,
            function()
                local w = a:CreateConditionCheckBox()
                return 'ok', nil, w
            end
        ),
    }

    assert(result[1] and result[2] == 'ok' and result[3] == nil and result[4] == allocations[1])
    a:ClearConditionWidgetFocus()
    assert(cleared == 1 and lookups() == 0, 'native observation or focus queried a GUI library')
    a:ReleaseConditionWidget(result[4])
end)

test('warm native roots recycle bounded child pools through repeated discard', function()
    local _, a = fixture()
    local seen = {}
    local commits = 0

    for _ = 1, 100 do
        local root = a:CreateConditionGroup()
        local child = a:CreateConditionEditBox()
        seen[child] = true
        child:SetText('saved')

        child:SetCallback('OnEnterPressed', function()
            commits = commits + 1
        end)

        root:AddChild(child)
        child.editbox:SetText('pending')
        child.editbox.scripts.OnTextChanged(child.editbox, true)
        a:ReleaseConditionWidget(root)
    end

    local count = 0

    for _ in pairs(seen) do
        count = count + 1
    end

    assert(count == 1 and commits == 0, 'native pool grew or committed discarded data')
end)

finish()
