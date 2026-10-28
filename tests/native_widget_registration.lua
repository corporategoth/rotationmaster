local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local entries = {
    { 'RM-ConditionIcon', 'CreateConditionIcon', 'UI/condition_icon.lua' },
    { 'RM-ConditionPositionPad', 'CreateConditionPositionPad', 'UI/condition_position.lua' },
    { 'RM-ConditionLink', 'CreateConditionLink', 'UI/condition_display.lua' },
    { 'RM-ConditionLabel', 'CreateConditionLabel', 'UI/condition_display.lua' },
    { 'RM-ConditionButton', 'CreateConditionButton', 'UI/condition_display.lua' },
}

local function fixture()
    local f = F.new()
    local frames = dofile('tests/fixtures/native_ui.lua')(f.env)
    local lookup = f.env.LibStub

    f.env.LibStub = function(name, ...)
        assert(name ~= 'AceGUI-3.0', 'native widget requested a GUI library')
        return lookup(name, ...)
    end

    return f, f.addon, frames
end

local function sources(f)
    for _, path in ipairs({
        'Data/builtin_sources.lua',
        'Core/builtin_sources.lua',
        'Core/custom_authoring.lua',
        'Core/function_data.lua',
    }) do
        f.load(path)
    end
end

test('native visual modules load lazily and all factories recycle without registrations', function()
    local f, a, frames = fixture()
    assert(f.libraries['AceGUI-3.0'] == nil)
    local before = #frames

    for _, path in ipairs({ 'UI/condition_icon.lua', 'UI/condition_position.lua', 'UI/condition_display.lua' }) do
        f.load(path)
    end

    assert(#frames == before, 'native module load constructed controls')

    for _, entry in ipairs(entries) do
        local w = a[entry[2]](a)
        assert(w.type == entry[1] and a:IsConditionWidget(w) and w.rmActive)
        local calls = 0

        w:SetCallback('Probe', function()
            calls = calls + 1
        end)

        local stale = w.events.Probe
        a:ReleaseConditionWidget(w)
        local reused = a[entry[2]](a)
        assert(reused == w)
        stale(w, 'Probe')
        assert(calls == 0)
        reused:Release()
    end
end)

test('native links retain clickable images while ordinary labels remain inert text', function()
    local _, a = fixture()
    local link = a:CreateConditionLink()
    local label = a:CreateConditionLabel()
    assert(link.frame.kind == 'Button' and link.image and label.frame.kind == 'Frame' and not label.image)
    local clicked

    link:SetCallback('OnClick', function(_, _, button)
        clicked = button
    end)

    link:SetImage('fixture')
    link.frame.scripts.OnClick(link.frame, 'LeftButton')
    assert(clicked == 'LeftButton')
    link:SetDisabled(true)
    clicked = nil
    link.frame.scripts.OnClick(link.frame, 'RightButton')
    assert(clicked == nil)
    a:ReleaseConditionWidget(link)
    a:ReleaseConditionWidget(label)
end)

test('current visual factory source IDs compile into owned native leases with interactive links intact', function()
    local f, a = fixture()
    sources(f)

    for index, entry in ipairs(entries) do
        local id = 'builtin:' .. entry[3] .. ':' .. entry[2]
        local record = assert(a.builtinFunctions[id])
        assert(a:ResolveFunctionBinding(id) == a[entry[2]])
        assert(a:InstallCustomFunction('NATIVE_VISUAL_' .. index, a:CopySettingsData(record.source)))
        local w = assert(a:ResolveFunctionBinding('NATIVE_VISUAL_' .. index))(a)
        assert(w.type == entry[1] and a:IsConditionWidget(w) and w.rmActive)
        w:Release()
    end

    local font = 'builtin:UI/condition_display.lua:defaultFont'
    assert(a:FunctionSourceHash(assert(a.builtinFunctions[font]).source) == 'da8d3722')
end)

test('native visual root ownership remains bounded and releases nested descendants', function()
    local _, a = fixture()

    for _, entry in ipairs(entries) do
        local seen = {}

        for _ = 1, 100 do
            local root = a:CreateConditionGroup()
            local w = a[entry[2]](a)
            seen[w] = true
            root:AddChild(w)
            root:Release()
            assert(not w.rmActive)
        end

        local n = 0

        for _ in pairs(seen) do
            n = n + 1
        end

        assert(n == 1, 'native visual lease pool grew')
    end
end)

finish()
