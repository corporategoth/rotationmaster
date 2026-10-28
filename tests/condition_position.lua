-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    dofile('tests/fixtures/native_ui.lua')(f.env)
    local create = f.env.CreateFrame

    f.env.CreateFrame = function(...)
        local frame = create(...)
        local makeFont = frame.CreateFontString

        function frame:CreateFontString(...)
            local label = makeFont(self, ...)

            function label:SetFont(path, size, flags)
                self.font = { path, size, flags }
                return true
            end

            return label
        end

        return frame
    end

    if not f.addon.CreateConditionPositionPad then
        local h = io.open('UI/condition_position.lua')

        if h then
            h:close()
            f.load('UI/condition_position.lua')
        end
    end

    return f, f.addon
end

local function find(root, kind)
    if root.type == kind then
        return root
    end

    for _, child in ipairs(root.children or {}) do
        local found = find(child, kind)

        if found then
            return found
        end
    end
end

test('cooldown Help uses only native widgets and retains the explanatory offset row', function()
    local f, a = fixture()
    f.load('Help/rotations.lua')
    assert(f.libraries['AceGUI-3.0'] == nil)
    local root = a:CreateConditionGroup()
    root:SetWidth(680)
    a.layout_cooldown_help(root)
    local pad = assert(find(root, 'RM-ConditionPositionPad'), 'offset illustration missing')

    assert(
        pad.parent.layout == 'Table' and pad.parent:GetUserData('table').columns[1] == 50,
        'offset text column changed'
    )

    local text = F.text(root)

    assert(
        text:find('Left and Right arrows', 1, true) and text:find('The center button will reset', 1, true),
        'offset explanation changed'
    )

    assert(pad.disabled, 'Help illustration can change values')

    for _, button in pairs(pad.pad.buttons) do
        assert(not button:IsEnabled())
    end

    a:ReleaseConditionWidget(root)
    assert(not pad.rmActive)
end)

test('position adapter delegates arrows center and shift steps to the shared component', function()
    local f, a = fixture()
    local created = 0
    local factory = a.CreateWorkbenchPositionPad

    a.CreateWorkbenchPositionPad = function(self, parent)
        created = created + 1
        return factory(self, parent)
    end

    local w = assert(a.CreateConditionPositionPad, 'native position factory missing')(a)
    local moves = {}

    w:SetCallback('OnOffsetChanged', function(_, _, dx, dy, center, amount)
        moves[#moves + 1] = { dx, dy, center, amount }
    end)

    w.pad.buttons.Up:Click()
    f.env.IsShiftKeyDown = function() return true end
    w.pad.buttons.Left:Click()
    w.pad.buttons.Center:Click()

    assert(
        created == 1 and w.frame:GetWidth() == 48 and w.frame:GetHeight() == 48,
        'adapter duplicated or resized the shared pad'
    )

    assert(moves[1][1] == 0 and moves[1][2] == 1 and moves[1][3] == false and moves[1][4] == 1)
    assert(moves[2][1] == -1 and moves[2][2] == 0 and moves[2][4] == 10)
    assert(moves[3][1] == 0 and moves[3][2] == 0 and moves[3][3] == true)
    a:ReleaseConditionWidget(w)
end)

test('position leases disable queued owners and reject retired native callbacks after reuse', function()
    local f, a = fixture()
    assert(a.CreateConditionPositionPad, 'native position factory missing')
    local w = a:CreateConditionPositionPad()
    local calls = 0

    w:SetCallback('OnOffsetChanged', function()
        calls = calls + 1
    end)

    local old = w.pad.buttons.Up:GetScript('OnClick')
    w:SetDisabled(true)
    old(w.pad.buttons.Up)
    assert(calls == 0)
    w:SetDisabled(false)
    w.parent = { isQueuedForRelease = true }
    old(w.pad.buttons.Up)
    assert(calls == 0)
    w.parent = nil
    a:ReleaseConditionWidget(w)
    local nextPad = a:CreateConditionPositionPad()
    assert(nextPad == w and not w.disabled)

    nextPad:SetCallback('OnOffsetChanged', function()
        calls = calls + 10
    end)

    old(w.pad.buttons.Up)
    assert(calls == 0, 'retired button changed new lease')
    nextPad.pad.buttons.Down:Click()
    assert(calls == 10)
    a:ReleaseConditionWidget(nextPad)
end)

test('rotation Help remains native and its content survives a release and reopen', function()
    local f, a = fixture()
    f.load('Help/rotations.lua')
    assert(f.libraries['AceGUI-3.0'] == nil)

    for _ = 1, 2 do
        local root = a:CreateConditionGroup()
        root:SetWidth(600)
        a.layout_rotation_help(root)
        local text = F.text(root)

        assert(
            text:find('order of priority', 1, true) and text:find(
                'auto-attack (Attack or Shoot) is the implicit final fallback',
                1,
                true
            )
        )

        a:ReleaseConditionWidget(root)
    end
end)

test('native position roots recycle pads without stale clicks or stranded leases', function()
    local f, a = fixture()
    local seen = {}
    local calls = 0

    for _ = 1, 25 do
        local parent = a:CreateConditionGroup()
        local w = a:CreateConditionPositionPad()
        seen[w] = true

        w:SetCallback('OnOffsetChanged', function()
            calls = calls + 1
        end)

        local old = w.pad.buttons.Up:GetScript('OnClick')
        parent:AddChild(w)
        w.pad.buttons.Up:Click()
        parent:Release()
        assert(not w.rmActive)
        old(w.pad.buttons.Up)
    end

    local count = 0

    for _ in pairs(seen) do
        count = count + 1
    end

    assert(count == 1 and calls == 25, 'native discard stranded pads or fired retired callbacks')
end)

finish()
