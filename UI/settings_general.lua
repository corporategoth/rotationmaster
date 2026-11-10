-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Settings > General page: recommendation, polling, history, preview window, effect, tooltip and debugging options,
-- and the diagnostic capture buttons, laid out in two columns on a pooled settings form `p`.
-- Every field edits the page's settings draft (p:SettingsData()) and applies its side effect through
-- p:RunSettingsEffect, so Discard undoes it; the exceptions are the preview lock, the preview position reset, the
-- Masque skin and the capture buttons, which act immediately on live state and say why where they are built.
-- Loaded from RotationMaster.toc after UI/settings_transfer.lua and custom_condition_transfer.lua; the settings window
-- picks it from the section table in UI/settings_collections.lua. Many calls are guarded with `self.X and` because the
-- optional feature files load later or are missing on some clients.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Turns a { key = text } table into a list of choice entries sorted by text, for choice controls.
-- @param values table|nil  The map of key to display text.
-- @return table[]  The entries, each { value = key, text = text }.
local function entries(values)
    local result = {}

    for key, text in pairs(values or {}) do
        result[#result + 1] = { value = key, text = text }
    end

    table.sort(result, function(a, b) return tostring(a.text) < tostring(b.text) end)
    return result
end

-- ============================================================================
-- The General page
-- ============================================================================

-- Draws the General page into the settings pane. Runs on every redraw of the page, so each call rebuilds all controls
-- from the draft in `p:SettingsData()` and registers its cleanups on p.cleanups; nothing it creates may outlive the
-- drawing (every callback checks the drawing's generation through p:Guard or p:Valid).
-- @param p table  The settings pane.
function addon:BuildGeneralSettings(p)
    local store = p:SettingsData()
    local profile = store.profile
    p:Column(1)
    p:Heading(L['Recommendations'])
    local enableY = p.y

    p:Check('enable', L['Enable'], profile.enable, function(v)
        profile.enable = v

        p:RunSettingsEffect('enable', function()
            if v then
                self:enable()
            else
                self:disable()
            end
        end)
    end)

    p:Check('disable_buttons', L['Disable Bar Highlighting'], profile.disable_buttons, function(v)
        profile.disable_buttons = v

        p:RunSettingsEffect('buttons', function()
            if v then
                self:GlowClear()
            end
        end)
    end)

    p:Check('minimap', L['Minimap Icon'], not (profile.minimap or {}).hide, function(v)
        profile.minimap = profile.minimap or {}
        profile.minimap.hide = not v

        p:RunSettingsEffect('minimap', function()
            local lib = LibStub('LibDBIcon-1.0')

            if v then
                lib:Show(self.name)
            else
                lib:Hide(self.name)
            end
        end)
    end)

    -- Enable, Disable Bar Highlighting and Minimap Icon share one row in thirds.
    self:LayoutWorkbenchRow({ p.fields.enable, p.fields.disable_buttons, p.fields.minimap }, 0, enableY, p.width, {
        text = 22,
    })

    p.y = enableY + 30

    p:Slider('poll', L['Polling Interval (seconds)'], profile.poll, .05, 1, .05, function(v)
        profile.poll = v

        p:RunSettingsEffect('poll', function()
            if self.rotationTimer then
                self:DisableRotationTimer()
                self:EnableRotationTimer()
            end
        end)
    end)

    p:Slider('idle_poll', L['Idle Re-check Interval (seconds)'], profile.idle_poll or 1, 0, 5, .25, function(v)
        profile.idle_poll = v
    end)

    p:Slider(
        'autoswitch_poll',
        L['Auto-Switch Re-check Interval (seconds)'],
        profile.autoswitch_poll or 1,
        0,
        10,
        .25,
        function(v)
            profile.autoswitch_poll = v
            profile.disable_autoswitch = nil

            p:RunSettingsEffect('autoswitch_poll', function()
                self:StartAutoSwitchTimer()
            end)
        end
    )

    -- Live Status Update Frequency slider: stores the value and, when it changed, queues restarting the condition timer
    -- and the open editor's live bars.
    p:Slider(
        'live_config_update',
        L['Live Status Update Frequency (seconds)'],
        profile.live_config_update,
        0,
        60,
        1,
        function(v)
            if profile.live_config_update == v then
                return
            end

            profile.live_config_update = v

            p:RunSettingsEffect('conditionTimer', function()
                if self.conditionEvalTimer then
                    self:CancelTimer(self.conditionEvalTimer)
                    self.conditionEvalTimer = nil
                end

                if self.RestartLiveStatus then
                    self:RestartLiveStatus()
                end
            end)
        end
    )

    p:Choice(
        'rotation_view',
        L['Default rotation view'],
        profile.rotation_view or 'diagram',
        { { value = 'diagram', text = L['Diagram view'] }, { value = 'list', text = L['List view'] } },
        function(v)
            profile.rotation_view = v
        end
    )

    -- These options only change what counts as ready for advice (Core/action_policy.lua reads them each poll).
    local readinessY = p.y

    p:Check('ignore_mana', L['Ignore Mana'], profile.ignore_mana == true, function(v)
        profile.ignore_mana = v
        p:Draw()
    end)

    p:Check('ignore_range', L['Ignore Range'], profile.ignore_range == true, function(v)
        profile.ignore_range = v
    end)

    p:Check('ignore_moving', L['Ignore Moving'], profile.ignore_moving == true, function(v)
        profile.ignore_moving = v
    end)

    self:LayoutWorkbenchRow(
        { p.fields.ignore_mana, p.fields.ignore_range, p.fields.ignore_moving },
        0,
        readinessY,
        p.width,
        { text = 22 }
    )

    p.y = readinessY + 30

    -- Off by default: remembered values can be stale (Platform/auras.lua, Platform/spells.lua).
    p:Check('remember_hidden', L['Remember hidden buffs and cooldowns'], profile.remember_hidden == true, function(v)
        profile.remember_hidden = v
    end)

    p:Heading(L['History'])

    for _, entry in ipairs({
        { 'spell_history', 'Spell History Memory (seconds)' },
        { 'combat_history', 'Combat History Memory (seconds)' },
        { 'damage_history', 'Damage History Memory (seconds)' },
    }) do
        local key = entry[1]

        p:Slider(key, L[entry[2]], profile[key], 0, 300, 1, function(v)
            profile[key] = v
        end)
    end

    -- Talent groups need your own names (Primary, Secondary, ...) on every client that keys rotations by talent group:
    -- Era, TBC, Wrath, Cataclysm and Forever. Retail and Mists name real specializations, so the option is gone.
    if self.Platform:GetRotationSpecKind() == 'slot' and store.char and store.char.specs then
        p:Heading(L['Specialization Names'])

        for i, caption in ipairs({ PRIMARY, SECONDARY }) do
            p:Edit('spec' .. i, caption, store.char.specs[i], nil, function(v)
                store.char.specs[i] = v
            end)
        end
    end

    p:Column(2)
    p:Heading(L['Effect Options'])
    -- The preview icon has no caption: it sits left of Effect and
    -- Magnification and spans both rows, their captions beside it.
    local y = p.y

    local preview = p:Acquire('preview', function()
        local frame = CreateFrame('Frame', nil, p.child)
        frame.icon = frame:CreateTexture(nil, 'ARTWORK')
        frame.icon:SetAllPoints(frame)
        return frame
    end)

    preview:ClearAllPoints()
    preview:SetPoint('TOPLEFT', 4, -y - 4)
    preview:SetSize(48, 48)
    preview.icon:SetTexture('Interface\\Icons\\Spell_Nature_Lightning')
    p.fields.preview = preview

    -- Builds a control through `build` and moves the caption it just acquired to the right of the preview icon, which
    -- spans the Effect and Magnification rows. Relies on the label pool order: the caption is the next pooled label.
    -- @param build function  Creates the control (and its caption row) and returns it.
    -- @return table  The control.
    local function besidePreview(build)
        local count = p.counts.labels or 0
        local rowY = p.y
        local control = build()
        local caption = p.pool.labels[count + 1]

        if caption then
            caption:ClearAllPoints()
            caption:SetPoint('TOPLEFT', 64, -rowY)
            caption:SetWidth(148)
        end

        return control
    end

    -- Redraws the sample glow on the preview icon from the draft's effect, color, magnification and position.
    local function refresh()
        if self.RemoveAllCurrentGlows then
            self:RemoveAllCurrentGlows()
        end
        if self.HideGlow then
            self:HideGlow(preview, 'settings-preview')
        end

        local effect = (store.global.effects or {})[profile.effect]

        if effect and self.Glow then
            self:Glow(
                preview,
                'settings-preview',
                effect,
                profile.color or { r = 1, g = 1, b = 1, a = 1 },
                profile.magnification or 1,
                profile.setpoint or 'CENTER',
                profile.xoffs or 0,
                profile.yoffs or 0
            )
        end
    end

    local effectEntries = {}

    for id, effect in pairs(store.global.effects or {}) do
        if type(effect) == 'table' and effect.name then
            effectEntries[#effectEntries + 1] = { value = id, text = effect.name }
        end
    end

    table.sort(effectEntries, function(a, b) return a.text < b.text end)

    besidePreview(function()
        return p:Choice('effect', L['Effect'], profile.effect, effectEntries, function(v)
            profile.effect = v
            refresh()
        end)
    end)

    besidePreview(function()
        return p:Slider('magnification', L['Magnification'], profile.magnification or 1, .1, 2, .1, function(v)
            profile.magnification = v
            refresh()
        end)
    end)

    p.y = math.max(p.y, y + 60)

    p:Color('color', L['Highlight Color'], profile.color, function(v)
        profile.color = v
        refresh()
    end)

    local positionY = p.y

    local anchor = p:Choice('setpoint', nil, profile.setpoint or 'CENTER', entries(self.setpoints), function(v)
        profile.setpoint = v
        profile.xoffs = 0
        profile.yoffs = 0
        refresh()
        p:Draw()
    end)

    anchor:ClearAllPoints()
    anchor:SetPoint('TOPLEFT', 0, -positionY - 22)
    anchor:SetWidth(204)
    p.y = positionY

    p:Position(
        profile.xoffs,
        profile.yoffs,
        function(x, y, center)
            profile.xoffs = x
            profile.yoffs = y

            if center then
                profile.setpoint = 'CENTER'
            end

            refresh()
        end,
        true
    )

    -- Who highlights a "Blizzard's suggestion" step. Hidden where the client
    -- has no Blizzard highlight (Core/assisted_highlight.lua).
    if self.GetAssistedHighlightSupport and self:GetAssistedHighlightSupport() then
        local modes = {
            { value = 'rm', text = L["Rotation Master's glow"] },
            { value = 'blizzard', text = L["Blizzard's Assisted Highlight"] },
            { value = 'both', text = L['Both'] },
        }

        p:Choice(
            'assisted_highlight',
            L["Blizzard's suggestion highlight"],
            self:GetAssistedHighlightMode(profile),
            modes,
            function(v)
                profile.assisted_highlight = v

                p:RunSettingsEffect('assisted_highlight', function()
                    self:RefreshAssistedHighlight(true)
                end)
            end
        )

        if self.Platform:GetAssistedCombatAvailability() == false then
            p:Text(
                L["Assisted Combat is not available for your current specialization, so Blizzard's highlight stays off."]
            )
        end
    end

    -- Lines Rotation Master adds to spell and item tooltips (Core/tooltips.lua).
    p:Heading(L['Tooltips'])

    -- Re-applies the tooltip integration after any tooltip option changes.
    local function tooltipsChanged()
        p:RunSettingsEffect('tooltips', function()
            if self.RefreshTooltipIntegration then
                self:RefreshTooltipIntegration()
            end
        end)
    end

    local tooltipsOn = profile.tooltips ~= false

    -- A grid, two to a row: the master switch with disabled rotations, the condition options, then the two lines.
    local boxes = p:CheckGrid({
        {
            key = 'tooltips',
            caption = L['Show Rotation Master in tooltips'],
            value = tooltipsOn,
            changed = function(v)
                profile.tooltips = v
                tooltipsChanged()
                p:Draw()
            end,
        },
        {
            key = 'tooltip_disabled_rotations',
            caption = L['Include disabled rotations'],
            value = profile.tooltip_disabled_rotations ~= false,
            changed = function(v)
                profile.tooltip_disabled_rotations = v
                tooltipsChanged()
            end,
        },
        {
            key = 'tooltip_conditions',
            caption = L['Include rotation conditions'],
            value = profile.tooltip_conditions == true,
            changed = function(v)
                profile.tooltip_conditions = v
                tooltipsChanged()
            end,
        },
        {
            key = 'tooltip_exclude_disabled_conditions',
            caption = L['Exclude disabled conditions'],
            value = profile.tooltip_exclude_disabled_conditions == true,
            changed = function(v)
                profile.tooltip_exclude_disabled_conditions = v
                tooltipsChanged()
            end,
        },
        {
            key = 'tooltip_itemsets',
            caption = L['List item sets in item tooltips'],
            value = profile.tooltip_itemsets ~= false,
            changed = function(v)
                profile.tooltip_itemsets = v
                tooltipsChanged()
            end,
        },
        {
            key = 'tooltip_rotations',
            caption = L['List rotations in spell and item tooltips'],
            value = profile.tooltip_rotations ~= false,
            changed = function(v)
                profile.tooltip_rotations = v
                tooltipsChanged()
            end,
        },
    })

    -- The master switch (the first box) turns the other five off.
    if not tooltipsOn then
        for index = 2, #boxes do
            boxes[index]:Disable()
        end
    end

    p:Slider('tooltip_limit', L['Names listed per tooltip line'], profile.tooltip_limit or 3, 1, 20, 1, function(v)
        profile.tooltip_limit = v
        tooltipsChanged()
    end)

    p:Heading(L['Debugging Options'])

    local logEntries = {
        { value = 4, text = self.loglevels[4] },
        { value = 3, text = self.loglevels[3] },
        { value = 2, text = self.loglevels[2] },
        { value = 1, text = L['Silent'] },
    }

    local logY = p.y

    local logLevel = p:Choice('loglevel', L['Log Level'], profile.loglevel or 2, logEntries, function(v)
        profile.loglevel = v

        p:RunSettingsEffect('loglevel', function()
            if self.RefreshEvaluationProfilerPolicy then
                self:RefreshEvaluationProfilerPolicy()
            end
        end)

        p:Draw()
    end)

    local detail = p:Check('detailed_profiling', L['Detailed Profiling'], profile.detailed_profiling, function(v)
        profile.detailed_profiling = v
    end)

    if (profile.loglevel or 2) < 3 then
        detail:Disable()
    end

    -- Detailed Profiling follows Log Level on its row, only as wide as its
    -- box and caption.
    local detailText = detail:GetFontString()
    detailText:SetWidth(300)
    local detailWidth = 22 + math.min(180, math.max(40, math.ceil(detailText:GetStringWidth() or 0) + 2))
    detailText:SetWidth(detailWidth - 22)
    detail:SetWidth(detailWidth)
    detail:ClearAllPoints()
    detail:SetPoint('TOPLEFT', math.max(0, p.width - detailWidth), -logY - 3)
    logLevel:SetWidth(math.max(60, p.width - 220 - detailWidth - 8))
    p.y = logY + 30

    if self.GetCacheDiagnosticMode and self.SetCacheDiagnosticMode then
        local _, requested = self:GetCacheDiagnosticMode()
        local control = p:Check('cpu_cache_bypass', '', requested == 'cached', function() end)
        control.tooltip = L['Observation caching can reduce repeated lookups but increases table allocations. Off by default; reload to change the running mode.']

        -- Labels the observation cache box "required" when the loaded mode matches the requested one, "pending" while a
        -- reload would change it, and checks it when the requested mode is the cached one.
        local function updateModeCaption()
            local loaded, nextMode = self:GetCacheDiagnosticMode()

            control:SetText(
                loaded == nextMode and L['Enable observation cache (reload required)']
                    or L['Enable observation cache (pending)']
            )

            control:SetChecked(nextMode == 'cached')
        end

        updateModeCaption()

        -- Diagnostic requests persist independently of pending settings edits.
        self:SetUIScript(control, 'OnClick', p:Guard(function()
            local _, current = self:GetCacheDiagnosticMode()
            local wanted = current == 'direct' and 'cached' or 'direct'
            local ok = self:SetCacheDiagnosticMode(wanted)
            updateModeCaption()
            p:Message(ok and '' or L['Cache diagnostic is unavailable.'], ok)
        end))
    end

    -- Diagnostics: one column per capture kind, its capture button above its
    -- report button. While a capture runs its button stops it (the report is
    -- kept); a report button stays disabled until that kind has a report.
    -- Labels follow live state, whoever started or ended the capture, but only
    -- while this page is shown. Each action uses live settings, never a draft.
    local captures = {}

    -- Calls an addon method under pcall.
    -- @param method string  The name of the addon method.
    -- @param ... any  The arguments passed after the addon.
    -- @return any  The method's first result; false when the method is missing or errors.
    local function call(method, ...)
        local fn = self[method]

        if type(fn) ~= 'function' then
            return false
        end

        local ok, value = pcall(fn, self, ...)
        return ok and value
    end

    -- Returns the action that stops a capture: through the shared performance command when it exists, otherwise by
    -- calling the stop method directly.
    -- @param kind string  The capture kind used in the performance command ('cpu', 'runtime' or 'memory').
    -- @param method string  The name of the addon method that stops the capture.
    -- @return function  The action; it returns whether it worked and a message.
    local function stopper(kind, method)
        return function()
            if type(self.HandlePerformanceCommand) == 'function' then
                return self:HandlePerformanceCommand(kind .. ' stop')
            end

            local ok = call(method)
            return ok, ''
        end
    end

    -- Returns a check that is true when an addon method yields a stored report string.
    -- @param method string  The name of the addon method that returns the report.
    -- @return function  The check; it returns true when a report exists.
    local function stored(method)
        return function()
            local fn = self[method]

            if type(fn) ~= 'function' then
                return false
            end

            local ok, value = pcall(fn, self)
            return ok and type(value) == 'string'
        end
    end

    if self.RunCPUProfileAction then
        captures[#captures + 1] = {
            key = 'cpu_capture',
            reportKey = 'cpu_report',
            start = L['Capture CPU (10s)'],
            stop = L['Stop CPU capture'],
            report = L['CPU report'],
            running = function() return call('IsCPUProfileRunning') == true end,
            hasReport = stored('GetCPUProfileReport'),
            begin = function() return self:RunCPUProfileAction('start') end,
            finish = stopper('cpu', 'StopCPUProfile'),
            open = function() return self:RunCPUProfileAction('report') end,
        }

        if type(self.StartCPURuntimeCapture) == 'function' then
            captures[#captures + 1] = {
                key = 'cpu_runtime_capture',
                reportKey = 'cpu_runtime_report',
                start = L['Capture runtime (10s)'],
                stop = L['Stop runtime capture'],
                report = L['Runtime report'],
                running = function() return call('IsCPURuntimeCaptureRunning') == true end,
                hasReport = stored('GetCPURuntimeCaptureReport'),
                begin = function() return self:RunCPUProfileAction('runtime') end,
                finish = stopper('runtime', 'StopCPURuntimeCapture'),
                open = function() return self:RunCPUProfileAction('runtimereport') end,
            }
        end
        if type(self.StartMemoryCapture) == 'function' then
            captures[#captures + 1] = {
                key = 'memory_capture',
                reportKey = 'memory_report',
                start = L['Capture memory (10m)'],
                stop = L['Stop memory capture'],
                report = L['Memory report'],
                running = function() return call('IsMemoryCaptureRunning') == true end,
                hasReport = stored('GetMemoryCaptureReport'),
                begin = function() return self:RunCPUProfileAction('memory') end,
                finish = stopper('memory', 'CompleteMemoryCapture'),
                open = function() return self:RunCPUProfileAction('memoryreport') end,
            }
        end
    end

    if self.RunCastCaptureAction then
        -- The cast report copies its snapshot, so it is checked only when the
        -- running state changes (and now and then as a safety net).
        captures[#captures + 1] = {
            key = 'cast_capture',
            reportKey = 'cast_report',
            start = L['Capture casts (30s)'],
            stop = L['Stop cast capture'],
            report = L['Cast report'],
            costly = true,
            running = function()
                return type(self.GetCastCaptureState) == 'function' and self:GetCastCaptureState() == true
            end,
            hasReport = function()
                if type(self.GetCastCaptureState) ~= 'function' then
                    return true
                end

                local _, available = self:GetCastCaptureState(true)
                return available == true
            end,
            begin = function() return self:RunCastCaptureAction('start') end,
            finish = function() return self:RunCastCaptureAction('stop') end,
            open = function() return self:RunCastCaptureAction('report') end,
        }
    end

    if #captures > 0 then
        local token = p.generation
        local minimumWidth = 120
        local diagnosticY = p.y

        -- Sets one capture's button label from its running state and enables its report button when a report exists. A
        -- costly check (the cast report copies its snapshot) is repeated only when the running state changed, when
        -- forced, or about every two seconds.
        -- @param entry table  The capture entry.
        -- @param force boolean|nil  True re-checks for a report even for a costly entry.
        local function paint(entry, force)
            local running = entry.running()
            local has = entry.has

            if not running and (force or not entry.costly or running ~= entry.wasRunning or (entry.age or 0) >= 2) then
                has = entry.hasReport() == true
                entry.age = 0
            end

            if running then
                has = false
            end

            entry.wasRunning = running
            entry.has = has
            entry.button:SetText(running and entry.stop or entry.start)

            if has then
                entry.reportButton:Enable()
            else
                entry.reportButton:Disable()
            end
        end

        -- Repaints every capture's buttons, but only while this drawing of the page is current.
        -- @param force boolean|nil  True forces the report check.
        local function repaint(force)
            if p:Valid(token) then
                for _, entry in ipairs(captures) do
                    paint(entry, force)
                end
            end
        end

        for _, entry in ipairs(captures) do
            local button = p:Button(entry.key, entry.start, function() end)
            local reportButton = p:Button(entry.reportKey, entry.report, function() end)
            entry.button, entry.reportButton = button, reportButton

            for _, text in ipairs({ entry.start, entry.stop }) do
                button:SetText(text)
                minimumWidth = math.max(minimumWidth, button:GetFontString():GetStringWidth() + 20)
            end

            self:SetUIScript(button, 'OnClick', p:Guard(function()
                local action = entry.running() and entry.finish or entry.begin
                local ok, message, current = action()

                if current == false or not p:Valid(token) then
                    return
                end

                if message and message ~= '' then
                    p:Message(message, ok)
                end

                repaint(true)
            end))

            self:SetUIScript(reportButton, 'OnClick', p:Guard(function()
                local ok, message, current = entry.open()

                if current == false or not p:Valid(token) then
                    return
                end

                p:Message(message or '', ok)
                repaint(true)
            end))
        end

        local gap = 4
        local columns = math.max(1, math.min(#captures, math.floor((p.width + gap) / (minimumWidth + gap))))
        local each = (p.width - (columns - 1) * gap) / columns

        for i, entry in ipairs(captures) do
            local x = ((i - 1) % columns) * (each + gap)
            local top = diagnosticY + math.floor((i - 1) / columns) * 58
            entry.button:ClearAllPoints()
            entry.button:SetPoint('TOPLEFT', x, -top)
            entry.button:SetWidth(each)
            entry.reportButton:ClearAllPoints()
            entry.reportButton:SetPoint('TOPLEFT', x, -top - 28)
            entry.reportButton:SetWidth(each)
        end

        p.y = diagnosticY + math.ceil(#captures / columns) * 58
        repaint(true)
        local watcher = p:Acquire('captureWatcher', function() return CreateFrame('Frame', nil, p.child) end)
        local elapsed = 0

        -- Every quarter of a second while the page is shown: ages the capture entries and repaints their buttons, so
        -- the labels follow the live state whoever started or ended the capture. Stops itself when the page was
        -- redrawn.
        -- @param frame table  The watcher frame.
        -- @param delta number|nil  The time since the last update, in seconds.
        self:SetUIScript(watcher, 'OnUpdate', function(frame, delta)
            if not p:Valid(token) then
                self:SetUIScript(frame, 'OnUpdate', nil)
                return
            end

            elapsed = elapsed + (delta or 0)

            if elapsed < .25 then
                return
            end

            for _, entry in ipairs(captures) do
                entry.age = (entry.age or 0) + elapsed
            end

            elapsed = 0
            repaint(false)
        end)
    end

    if self.Glow and store.global.effects and store.global.effects[profile.effect] then
        self:Glow(
            preview,
            'settings-preview',
            store.global.effects[profile.effect],
            profile.color or { r = 1, g = 1, b = 1, a = 1 },
            profile.magnification or 1,
            profile.setpoint or 'CENTER',
            profile.xoffs or 0,
            profile.yoffs or 0
        )
    end

    p:EndColumns()

    p.cleanups[#p.cleanups + 1] = function()
        if self.HideGlow then
            self:HideGlow(preview, 'settings-preview')
        end
    end
end
