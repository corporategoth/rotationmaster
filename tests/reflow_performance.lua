-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Live reflow cost. Simulates a 60-frame window-grip drag, a 60-frame divider
-- drag and 60 idle frames on the heaviest pages under client-faithful sizing
-- (tests/fixtures/deferred_layout.lua), counting per rendered frame: page
-- draws (builder runs), pooled control acquisitions, frames created,
-- OnSizeChanged handler invocations and, for the rotation editor, renders
-- and card binds. A drag may relayout a page at most once per frame; an
-- idle frame does no relayout work at all.
-- Run with REFLOW_REPORT=1 to print the per-page numbers.
local F = dofile('tests/fixtures/addon.lua')
local make = dofile('tests/fixtures/rotation_data.lua')
local test, finish = F.suite()

local function read(path)
    local h = assert(io.open(path))
    local text = h:read('*a')
    h:close()
    return text
end

local prefix = assert(read('tests/workbench_reflow.lua'):match('^(.-)\ntest%('))

local browserFixture, pointer = assert(loadstring(
    prefix .. '\nreturn browserFixture,pointer',
    '@reflow-performance-fixture'
))()

local report = os.getenv and os.getenv('REFLOW_REPORT')

local FILES = {
    'Platform/spells.lua', 'Data/catalog.lua', 'Data/rotation_store.lua', 'Core/rotation_library.lua',
    'Core/rotation_scope.lua', 'Core/rotation_migration.lua', 'Core/function_data.lua', 'Help/general.lua',
    'Help/conditions.lua', 'Help/effects.lua', 'Help/itemsets.lua', 'Help/announce.lua', 'UI/window.lua', 'UI/help.lua',
    'UI/icon_picker.lua', 'UI/color_picker.lua', 'UI/settings_roster_order.lua', 'UI/settings_layout.lua',
    'UI/settings_ordered.lua', 'UI/settings_draft.lua', 'UI/settings_history.lua', 'UI/settings_unsaved.lua',
    'UI/settings_form.lua', 'UI/settings_transfer.lua', 'UI/cpu_profile.lua', 'UI/settings_general.lua',
    'UI/settings_profiles.lua', 'UI/collection_compare.lua', 'UI/settings_collections.lua', 'UI/settings_announces.lua',
    'UI/settings_effects.lua', 'UI/settings_items.lua', 'UI/settings_conditions.lua', 'UI/lua_input_probe.lua',
    'UI/lua_input_diagnostics.lua', 'UI/lua_editor.lua', 'UI/settings_functions.lua', 'UI/function_bindings.lua',
    'UI/function_source_pane.lua', 'UI/function_bundle_transfer.lua'
}

-- Counters shared by every instrumented form, the frame factory and the mock.
local function counters(layout, regions)
    local c = { draws = 0, nested = 0, depth = 0, builds = 0, acquires = 0 }

    function c.snapshot()
        return {
            draws = c.draws,
            nested = c.nested,
            builds = c.builds,
            acquires = c.acquires,
            frames = #regions,
            size = layout.sizeHandlers,
            renders = c.renders or 0,
            binds = c.binds or 0,
        }
    end

    return c
end

local function instrumentForms(a, c)
    local create = a.CreateSettingsForm

    a.CreateSettingsForm = function(self, ...)
        local p = create(self, ...)
        local draw, acquire, open = p.Draw, p.Acquire, p.Open

        -- A form drawn inside another form's drawing (an inline editor) is
        -- part of that page relayout, counted apart.
        function p:Draw(...)
            if not self.active then
                return draw(self, ...)
            end

            if c.depth > 0 then
                c.nested = c.nested + 1
            else
                c.draws = c.draws + 1

                if c.drawCost then
                    c.clock = c.clock + c.drawCost
                end
            end

            c.depth = c.depth + 1
            local ok, why = pcall(draw, self, ...)
            c.depth = c.depth - 1

            if not ok then
                error(why, 0)
            end
        end

        function p:Acquire(...)
            c.acquires = c.acquires + 1
            return acquire(self, ...)
        end

        function p:Open(builder, ...)
            return open(
                self,
                function(...)
                    c.builds = c.builds + 1
                    return builder(...)
                end,
                ...
            )
        end

        return p
    end
end

local function shellPage(key, setup)
    local f = F.new()
    local a = f.addon
    local frames, create = dofile('tests/fixtures/native_ui.lua')(f.env)
    local layout = dofile('tests/fixtures/deferred_layout.lua')(f.env, create)
    a.pretty_name = 'Rotation Master'
    a.name = 'rotationmaster'
    a.configPaneGeneration = 1
    a.RotationData = make()

    for _, path in ipairs(FILES) do
        local h = io.open(path)

        if h then
            h:close()
            f.load(path)
        end
    end

    f.load('UI/config.lua')
    a.SetupOptions = function() end
    a.RemoveAllCurrentGlows = function() end
    a.HideGlow = function() end
    a.Glow = function() end
    a.listConditions = function() return {} end
    a.db.char = a.db.char or {}
    a.db.global.custom_functions = a.db.global.custom_functions or {}
    a.db.GetCurrentProfile = function() return 'One' end
    a.db.GetProfiles = function() return { 'One', 'Two' } end
    local c = counters(layout, frames)
    instrumentForms(a, c)
    -- A realistic profile behind every page: forty saved rotations of thirty
    -- steps each, so work that scales with the profile shows.
    local rotations = {}

    for r = 1, 40 do
        local steps = {}

        for i = 1, 30 do
            steps[i] = {
                id = 'r' .. r .. 's' .. i,
                type = 'spell',
                action = 403,
                ranked = true,
                conditions = { type = 'AND', value = { { type = 'BUFF', unit = 'player', spell = 403 } } },
            }
        end

        rotations['rot' .. r] = { name = 'Rotation ' .. r, rotation = steps }
    end

    a.db.profile.rotations = { [0] = rotations }

    if setup then
        setup(a)
    end

    local shell = a:ShowConfig(key)
    layout.settle()
    local p = shell.pane

    if p.roster and p.roster.rows[1] and p.roster.rows[1]:IsShown() then
        p.roster.rows[1]:Click()
        layout.settle()
    end

    return {
        f = f,
        a = a,
        layout = layout,
        c = c,
        shell = shell,
        grip = function(i)
            layout.userResize(shell.frame, 1000 + i * 4, 700)
        end,
        splitter = function() return shell.pane.roster and shell.pane.roster.splitter end,
        check = function()
            assert(shell.pane.active, 'page released')
        end,
    }
end

local function rotationPage()
    local f, _, _, _, regions = browserFixture(nil, nil, true)
    local a = f.addon
    local layout = f.layout
    a.db.profile.rotations[0].one.rotation = {}

    for i = 1, 24 do
        a.db.profile.rotations[0].one.rotation[i] = {
            id = 's' .. i,
            type = 'spell',
            action = 403,
            ranked = true,
            conditions = {},
        }
    end

    a.db.profile.rotation_view = 'list'
    local c = counters(layout, regions)
    local host = a:TrackWorkbenchSize(layout.create('Frame'))
    host:SetSize(1000, 700)
    layout.settle()
    local browser = a:CreateRotationBrowser(host, { spec = 0, id = 'one' })
    layout.settle()

    local function hook(object, name, field)
        local fn = object[name]

        object[name] = function(...)
            c[field] = (c[field] or 0) + 1
            return fn(...)
        end
    end

    hook(browser.pane, 'Render', 'renders')
    hook(browser.pane.canvas, 'BindCard', 'binds')
    assert(browser.pane.view.layout == 'list', 'rotation editor is not in list view')

    return {
        f = f,
        a = a,
        layout = layout,
        c = c,
        grip = function(i)
            host:SetSize(1000 + i * 4, 700)
            browser:SetWidth(1000 + i * 4)
        end,
        splitter = function() return browser.splitter end,
        check = function()
            assert(browser.pane.active, 'editor released')
        end,
    }
end

local PAGES = {
    { 'General', function() return shellPage('General') end },
    { 'Rotations (list view)', rotationPage },
    {
        'Announces (6 outputs)',
        function()
            return shellPage('Announces', function(a)
                local outputs = {}

                for i = 1, 6 do
                    outputs[i] = { id = 'o' .. i, announce = 'local', value = 'Output ' .. i }
                end

                a.db.profile.announces = {
                    { id = 'e1', type = 'spell', spell = 403, event = 'SUCCEEDED', outputs = outputs },
                }
            end)
        end,
    },
    {
        'Effects (24 steps)',
        function()
            return shellPage('Effects', function(a)
                local sequence = {}

                for i = 1, 24 do
                    sequence[i] = {
                        texture = 136048,
                        angle = i * 10,
                        color = { r = 1, g = 1, b = 1, a = 1 },
                        magnification = 1,
                    }
                end

                a.db.global.effects = { long = { name = 'Long', type = 'custom', sequence = sequence } }
            end)
        end,
    },
    {
        'Functions editor',
        function()
            return shellPage('Functions', function(a)
                a.db.global.custom_functions = {
                    A = {
                        name = 'LongFunctionName',
                        description = 'Documentation',
                        args = {
                            { name = 'value', type = 'number', description = 'Input value' },
                            { name = 'other', type = 'string', description = 'Second' },
                        },
                        returns = { { type = 'number', description = 'Result' } },
                        code = 'return value',
                    },
                }
            end)
        end,
    },
}

local function run(scene, frames, input)
    local layout, c = scene.layout, scene.c
    local before = c.snapshot()
    local worst = {}
    local clock = os.clock()

    for i = 1, frames do
        local start = c.snapshot()
        input(i)

        if c.clock then
            c.clock = c.clock + 16.7
        end

        layout.step()
        local after = c.snapshot()

        for key, value in pairs(after) do
            worst[key] = math.max(worst[key] or 0, value - start[key])
        end
    end

    local after = c.snapshot()
    local total = {}

    for key, value in pairs(after) do
        total[key] = value - before[key]
    end

    total.cpu = (os.clock() - clock) * 1000 / frames
    return total, worst
end

-- A drag ends with the frames after release: anything settling then counts
-- toward the drag, so the idle frames after it must do nothing at all.
local function settle(scene, total)
    local rest = run(scene, 10, function() end)

    for key, value in pairs(rest) do
        if key ~= 'cpu' then
            total[key] = total[key] + value
        end
    end
end

local function grip(scene)
    local total, worst = run(scene, 60, scene.grip)
    settle(scene, total)
    return total, worst
end

local function divider(scene)
    local splitter = scene.splitter()

    if not splitter then
        return nil
    end

    local state = pointer(scene.f)
    state.down = true
    state.x = 0
    splitter.scripts.OnMouseDown(splitter, 'LeftButton')

    local total, worst = run(scene, 60, function(i)
        state.x = i * 2
    end)

    state.down = false
    settle(scene, total)
    return total, worst
end

local function idle(scene)
    return run(scene, 60, function() end)
end

local function line(name, kind, total, worst)
    if not report or not total then
        return
    end

    print(string.format(
        '%-22s %-7s relayouts %3d (max %d/frame, +%d nested)  acquires %6d (max %4d)  new regions %5d  OnSizeChanged %5d (max %4d)  renders %3d  card binds %4d  mock CPU %.2f ms/frame',
        name,
        kind,
        total.draws,
        worst.draws,
        total.nested,
        total.acquires,
        worst.acquires,
        total.frames,
        total.size,
        worst.size,
        total.renders,
        total.binds,
        total.cpu
    ))
end

for _, page in ipairs(PAGES) do
    local name, open = page[1], page[2]

    test(name .. ': a grip drag relayouts at most once per frame and idle frames do nothing', function()
        local scene = open()
        local total, worst = grip(scene)
        line(name, 'grip', total, worst)
        scene.layout.settle()
        scene.check()
        assert(worst.draws <= 1 and worst.renders <= 1, name .. ': a grip frame relayouted more than once')

        assert(
            total.draws > 0 or total.renders > 0 or total.binds > 0 or name:find('Rotations'),
            name .. ': the grip drag never reflowed'
        )

        local rest, restWorst = idle(scene)
        line(name, 'idle', rest, restWorst)

        assert(
            rest.draws == 0
                and rest.acquires == 0
                and rest.renders == 0
                and rest.binds == 0
                and rest.size == 0
                and rest.frames == 0,
            name .. ': idle frames did relayout work'
        )
    end)

    test(name .. ': a divider drag relayouts at most once per frame', function()
        local scene = open()
        local total, worst = divider(scene)

        if not total then
            return
        end

        line(name, 'divider', total, worst)
        scene.check()
        assert(worst.draws <= 1 and worst.renders <= 1, name .. ': a divider frame relayouted more than once')
    end)
end

-- A slow client: every page drawing costs 30 ms against 16.7 ms frames. The
-- driver times each drawing and waits twice as long before the next, so a
-- drag keeps most of its frames for the client, and the last width is still
-- drawn once the drag ends.
test('a slow page draws a fraction of the frames of a drag and the final width once it ends', function()
    for _, key in ipairs({ 'Effects', 'Announces' }) do
        local scene = shellPage(key)
        local c = scene.c
        c.clock = 0
        c.drawCost = 30
        scene.f.env.debugprofilestop = function() return c.clock end
        local total = grip(scene)
        local p = scene.shell.pane

        if report then
            print(string.format(
                '%-22s slow    relayouts %3d over 60 drag frames + 10 after (30 ms per drawing)',
                key,
                total.draws
            ))
        end

        assert(
            total.draws >= 4 and total.draws <= 24,
            key .. ': a slow page drew ' .. total.draws .. ' times in a 60-frame drag'
        )

        assert(p.drawnReflowKey == p:ReflowKey(), key .. ': the final width was never drawn')
    end
end)

finish()
