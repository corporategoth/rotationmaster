-- The Rotations page of the settings window: a searchable, filterable roster of rotations on the left (specialization,
-- Built In or custom, tags, a recovery button for unassigned records) and the rotation editor pane on the right, with a
-- splitter between. It owns the list state and row recycling and never edits a rotation itself; selection, new,
-- duplicate and leave prompts are delegated to the editor pane (UI/rotation_editor.lua) and the rotation library in
-- Core/. Rows are virtualized (only the visible range is bound) and every row, menu and callback carries serial,
-- revision and lease checks so a stale handler does nothing. Built by UI/config.lua through
-- addon:CreateRotationBrowser; loaded in the UI/ block of RotationMaster.toc after UI/config.lua.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Helpers
-- ============================================================================

-- Shorthand for a workbench button.
local function button(parent, text, width)
    return addon:CreateWorkbenchButton(parent, text, width)
end

-- Creates a left-aligned, non-wrapping font string (small highlight font unless `font` is given).
local function label(parent, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

-- True when two rotation references name the same rotation: the same Built In id, or the same stored address
-- (scope, class, owner, specialization, id).
local function sameReference(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' or a.kind ~= b.kind then return false end
    if a.kind == 'builtin' then return a.id == b.id end
    if type(a.address) ~= 'table' or type(b.address) ~= 'table' then return false end

    for _, key in ipairs({ 'scope', 'class', 'owner', 'spec', 'id' }) do
        if a.address[key] ~= b.address[key] then return false end
    end

    return true
end

-- ============================================================================
-- Browser construction
-- ============================================================================

-- Builds the browser inside `parent`: the frames, controls and click scripts, then the browser methods below. Returns
-- the browser record; call browser:Open(selection) to show it and browser:Release() to retire it. Created once per
-- parent and reused (see addon:CreateRotationBrowser).
local function create(parent)
    local frame = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, parent))
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local browser = {
        frame = frame,
        rowButtons = {},
        filters = {},
        rows = {},
        active = false,
        filter = "all",
        query = "",
    }

    local left = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, frame))
    browser.left = left
    local detail = addon:TrackWorkbenchSize(CreateFrame("Frame", nil, frame))
    browser.detail = detail
    -- The editor touches the page "?" corner; it inherits the reserve.
    detail.rmHelpReserve = addon:GetWorkbenchHelpReserve(frame)
    -- The specialization filter heads the list (no row above the panes): your
    -- current specialization by default, any of the class's, or all of them.
    -- Rotations restricted to other specializations (body.specs) are hidden
    -- like another class's; "any specialization" rotations always show.
    local specFilter = addon:CreateWorkbenchLabeledIconButton(left, 'chevron-down', '', 240)
    browser.specFilter = specFilter
    specFilter:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    specFilter:SetHeight(24)
    specFilter.tooltip = L['Show the rotations for this specialization (and those for any specialization).']
    local specMenu = addon:CreateWorkbenchSelector()
    browser.specMenu = specMenu
    local specWarning = label(left)
    browser.specWarning = specWarning
    specWarning:SetHeight(16)
    specWarning:SetTextColor(1, .72, .25)
    specWarning:SetText(L['This is not your current specialization.'])
    specWarning:Hide()
    local search = addon:CreateWorkbenchEditBox(left)
    browser.search = search
    search:SetAutoFocus(false)
    search:SetMaxLetters(128)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetSize(240, 24)
    search:SetTextInsets(5, 5, 0, 0)
    addon:AttachWorkbenchSearchHint(search)
    search:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)

    addon:SetUIScript(search, "OnTextChanged", function(control)
        if not browser.active then return end
        browser.query = string.lower(string.sub(control:GetText() or "", 1, 128))
        browser:RefreshRows()
        if browser.list then browser.list.workbenchBar:SetValue(0) end
    end)

    addon:SetUIScript(search, "OnEscapePressed", function(control) control:ClearFocus() end)
    local filterEntries = { { "all", L["All"] }, { "builtin", L["Built In"] }, { "custom", L["Custom"] } }

    for index, entry in ipairs(filterEntries) do
        local control = button(left, entry[2], 76)
        browser.filters[entry[1]] = control
        control:SetPoint("TOPLEFT", left, "TOPLEFT", (index - 1) * 80, -28)
        control.filterIndex = index
        local key = entry[1]
        addon:SetUIScript(control, "OnClick", function() browser:SetFilter(key) end)
    end

    browser.selectedTags = {}
    browser.tagMode = 'any'
    browser.tagLabel = label(left)
    browser.tagLabel:SetText(L['Tags'])
    browser.tagLabel:SetHeight(18)
    browser.tagLabel:SetWidth(36)
    browser.tagLabel:SetJustifyV('MIDDLE')
    browser.tagLabel:SetPoint('TOPLEFT', 0, -56)
    browser.tagModeButton = addon:CreateWorkbenchPill(left, L['Any'], 44)
    browser.tagModeButton:SetPoint('TOPLEFT', 40, -56)
    browser.tagModeButton:SetAccent(.75, .6, .18)

    browser.tagPicker = addon:CreateRotationTagPicker(left, {
        allowCustom = false,
        inputInset = 92,
        available = function() return browser.availableTags or {} end,
        valid = function() return browser.active and browser.profile == addon.db.profile end,
        changed = function(tags) browser:SetTags(tags) end,
        color = function(tag) return addon:GetRotationTagColor(tag) end,
        setColor = function(tag, color)
            addon:SetRotationTagColor(tag, color)
            browser:RefreshRows()
        end,
        layout = function()
            if browser.active then browser:Layout() end
        end,
    })

    browser.tagPicker.frame:SetPoint('TOPLEFT', 0, -56)
    browser.tagButton = browser.tagPicker.input
    browser.tagMenu = browser.tagPicker.menu

    addon:SetUIScript(browser.tagModeButton, 'OnClick', function()
        if browser.active then
            browser.tagMode = browser.tagMode == 'any' and 'all' or 'any'
            browser.tagModeButton:SetText(browser.tagMode == 'any' and L['Any'] or L['All'])
            browser:RefreshRows()
        end
    end)

    local list = addon:CreateWorkbenchScrollFrame(left)
    browser.list = list
    local child = CreateFrame("Frame", nil, list)
    child:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    list:SetScrollChild(child)
    browser.listChild = child
    local empty = label(child)
    empty:SetPoint("TOPLEFT", 4, -6)
    empty:SetText(L["No rotations match this search."])
    browser.empty = empty

    -- Rows follow the list column; the scroll bar reserves space only when shown.
    -- Called by the scroll frame when its column width changes; resizes the empty-state text and rebinds visible rows.
    function list:OnWorkbenchColumnResized(width)
        empty:SetWidth(math.max(40, width - 8))
        browser:RefreshViewport()
    end

    browser.splitter = addon:CreateWorkbenchSplitter(frame, function()
        if browser.active then browser:Layout() end
    end)

    local count = label(left)
    browser.count = count
    local new = addon:CreateWorkbenchLabeledIconButton(left, "plus", L["New"], 112)
    browser.newButton = new

    addon:SetUIScript(new, "OnClick", function()
        if not browser.active then return end

        browser:RequestLeave(function()
            if not browser.active then return end
            local reference, key = addon:NewRotationDraftTarget(browser.spec)

            if not reference then
                if browser.pane then browser.pane:Message(key) end
                return
            end

            browser.pendingId = key
            browser.filter = "all"
            browser.tag = nil
            browser.selectedTags = {}
            browser.query = ""
            search:SetText("")
            browser:SelectRotation(browser.spec, key, true)
        end)
    end)

    local duplicate = addon:CreateWorkbenchLabeledIconButton(left, "copy", L["Duplicate"], 112)
    browser.duplicateButton = duplicate

    addon:SetUIScript(duplicate, "OnClick", function()
        if not browser.active then return end
        local owner = browser.editorOwner

        browser:RequestLeave(function()
            if not browser.active or browser.editorOwner ~= owner then return end

            if browser.nativeDetails and browser.pane then
                if not browser.pane.workspace.pending then browser.pane.clone.action() end
            else
                local builtin = addon:GetDefaultIdForRuntime(browser.spec, browser.selected)
                local source = browser.allByKey and browser.allByKey[browser.selected]
                local title = source and source.name
                local name = string.format(L["Copy of %s"], title or browser.selected)
                local id, why, reference

                if builtin then
                    id, why, reference = addon:CloneDefaultRotation(browser.spec, builtin, name)
                else
                    id, why, reference = addon:DuplicateCustomRotation(browser.spec, browser.selected, name)
                end

                if id then browser:SelectRotation(browser.spec, reference or id, true) end
            end
        end)
    end)

    local import = addon:CreateWorkbenchLabeledIconButton(left, "transfer", L["Import/Export"], 112)
    browser.importButton = import

    addon:SetUIScript(import, "OnClick", function()
        if browser.active then
            browser:RequestLeave(function()
                if browser.active then addon:ShowRotationTransfer(browser.spec, browser.selected) end
            end)
        end
    end)

    local compare = addon:CreateWorkbenchLabeledIconButton(left, "compare", L["Compare"], 140)
    browser.compareButton = compare

    addon:SetUIScript(compare, "OnClick", function()
        if not browser.active then return end
        local owner = browser.editorOwner

        browser:RequestLeave(function()
            if browser.active and browser.editorOwner == owner and addon.ShowRotationComparison then
                addon:ShowRotationComparison(browser.spec, browser.selected)
            end
        end)
    end)

    local recovery = button(left, L['Recover unassigned rotations'], 240)
    browser.recoveryButton = recovery
    recovery:Hide()

    -- ============================================================================
    -- Recovery of unassigned rotations
    -- ============================================================================

    -- Shows the "Recover unassigned rotations" button when the archive has records, or when listing it failed (so the
    -- player can still reach the diagnostic details).
    function browser:RefreshRecovery()
        local rows, why

        if addon.ListUnassignedRotations and addon.ShowRotationAdoption then
            rows, why = addon:ListUnassignedRotations()
        end

        self.hasRecovery = rows and #rows > 0 or why ~= nil

        if self.hasRecovery then
            recovery:Show()
        else
            recovery:Hide()
        end
    end

    -- Also the settings-window banner's way in (UI/legacy_archive_banner.lua).
    -- Opens the recovery window after the editor's leave prompt; when a record is adopted the list refreshes, selects
    -- it and refreshes automatic switching and the banner. Does nothing if the browser or profile changed meanwhile.
    function browser:OpenRecovery()
        if not browser.active or browser.profile ~= addon.db.profile then return end
        local serial, profile = browser.serial, browser.profile

        browser:RequestLeave(function()
            if not browser.active or browser.serial ~= serial or addon.db.profile ~= profile then return end

            addon:ShowRotationAdoption(browser, function(reference)
                if not browser.active or browser.serial ~= serial or addon.db.profile ~= profile then return end
                browser:RefreshRecovery()
                browser:Layout()
                browser:SelectRotation(reference.address.spec, reference, true)
                if addon.UpdateAutoSwitch then addon:UpdateAutoSwitch() end
                if addon.SwitchRotation then addon:SwitchRotation() end
                if addon.RefreshLegacyArchiveBanner then addon:RefreshLegacyArchiveBanner() end
            end)
        end)
    end

    addon:SetUIScript(recovery, 'OnClick', function() browser:OpenRecovery() end)

    -- ============================================================================
    -- Rows
    -- ============================================================================

    -- Releases the editor pane on the right. Bumps the pane generation and clears the condition evaluation context so
    -- callbacks from the old pane cannot act on the next one.
    function browser:ReleaseDetails()
        addon.configPaneGeneration = (addon.configPaneGeneration or 0) + 1
        addon.currentConditionEval = nil
        self.editorOwner = nil
        -- Retire native editor focus before releasing its owned pane.
        addon:ClearConditionWidgetFocus()

        if self.pane then
            local pane = self.pane
            self.pane = nil
            if self.nativeDetails then pane:Release() end
            self.nativeDetails = nil
        end
    end

    -- Unbinds a pooled row: drops its lease and entry, clears its click script and hides it.
    function browser:RetireRow(control)
        control.browserLease = nil
        control.browserEntry = nil
        control.browserIndex = nil
        addon:SetUIScript(control, 'OnClick', nil)
        control:Hide()
    end

    -- Fills a pooled row control from roster `entry` at list position `index`: name, one status line (kind,
    -- specialization, priority), color and alpha for the state, the tooltip, the "Turn on" button for a Built In the
    -- player disabled, and the click handler. The handler is bound to a fresh lease and to the serial, revision, spec
    -- and profile current now, so a click on a row from an earlier list does nothing.
    function browser:BindRow(control, entry, index)
        local lease = {}
        local serial, revision, spec, profile = self.serial, self.resultRevision, self.spec, self.profile
        local navigation = self.navigationRevision
        local key = entry.key
        -- A row selects in its own namespace: every specialization's Default is
        -- listed under "All specializations", each in the one it belongs to.
        local target = entry.spec ~= nil and entry.spec or spec
        control.browserLease = lease
        control.browserEntry = entry
        control.browserIndex = index
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', child, 'TOPLEFT', 0, -(index - 1) * 48)
        control:SetSize(child:GetWidth(), 46)
        control.nameLabel:SetWidth(math.max(32, child:GetWidth() - 12))
        control.statusLabel:SetWidth(math.max(32, child:GetWidth() - 12))
        control.nameLabel:SetText(entry.name)

        if entry.readOnly then
            control.nameLabel:SetTextColor(.357, .753, .922)
        else
            control.nameLabel:SetTextColor(.9, .92, .94)
        end

        -- The line is only what the list is sorted and chosen by: the kind, the
        -- specialization and the priority. Everything else (read-only, scope,
        -- switched off, not available here) is the row's color, order and
        -- tooltip, never more words in the line.
        local kind = entry.readOnly and L['Built In'] or entry.fallback and L['Fallback'] or L['Custom']
        local specText

        if self.hasSpecFilter then
            if entry.fallback then
                specText = addon:GetFallbackSpecName(entry.spec) or L['Any specialization']
            else
                specText = addon:DescribeRotationSpecs(entry.specs)
            end
        end

        local priorityText = not entry.fallback
            and (entry.priority and string.format(L['Priority %d'], entry.priority) or L['Invalid priority'])
            or nil

        -- Joins kind, the given specialization text and the priority into the row's status line.
        local function line(specPart)
            local parts = { kind }
            if specPart then parts[#parts + 1] = specPart end
            if priorityText then parts[#parts + 1] = priorityText end
            return table.concat(parts, ' · ')
        end

        local status = line(specText)
        -- One line, never cut in the middle of the kind or the priority: when
        -- the specializations are too long for the column, they give way (the
        -- full text is in the tooltip).
        local room = control.statusLabel:GetWidth()

        if specText and room > 0 then
            control.statusLabel:SetText(status)

            if control.statusLabel:GetStringWidth() > room then
                local characters = {}

                for character in specText:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
                    characters[#characters + 1] = character
                end

                for count = #characters - 1, 0, -1 do
                    status = line(table.concat(characters, '', 1, count) .. '…')
                    control.statusLabel:SetText(status)
                    if control.statusLabel:GetStringWidth() <= room then break end
                end
            end
        end

        control.statusLabel:SetText(status)
        control.statusLabel:SetTextColor(.67, .72, .77)
        addon:SetWorkbenchListSelection(control, key == self.selected)

        -- Red when anything in it (a card, a branch child, a cooldown, the
        -- switch) stops it being selected; the tooltip names the first issue.
        local blocked = entry.problem ~= nil
            or entry.validationState ~= nil and entry.validationState ~= 'valid' and entry.validationState ~= 'pending'

        local blockedText = blocked and string.format(
            L['This rotation cannot be selected. %s.'],
            entry.problem and addon.DescribeRotationIssue and addon:DescribeRotationIssue(entry.problem)
                or L['It has incomplete or unsupported data']
        )
            or nil

        addon:SetWorkbenchProblem(control, blockedText)
        -- Grey when it is switched off (by you, or as it ships); amber when
        -- its switch can match together with another rotation, so only
        -- priority decides (stronger on a tie). The tooltip says which apply.
        local disabledText

        if entry.readOnly and entry.builtinState == 'user-disabled' then
            disabledText = L['Disabled by you: automatic switching skips it. Select it and click Disabled to turn it back on.']
        elseif entry.readOnly and entry.builtinState == 'shipped-disabled' then
            disabledText = L['Ships disabled (an alternative to the recommended Built In): automatic switching skips it until you turn it on.']
        elseif not entry.readOnly and entry.enabled == false then
            disabledText = L['Disabled: automatic switching skips it.']
        end

        local alpha = disabledText and .5 or 1
        control.nameLabel:SetAlpha(alpha)
        control.statusLabel:SetAlpha(alpha)
        if disabledText then control.nameLabel:SetTextColor(.6, .6, .6) end
        local overlapText, tie = nil, false

        if not entry.fallback and self.overlaps and addon.DescribeSwitchOverlap then
            overlapText, tie = addon:DescribeSwitchOverlap(self.overlaps[key])
        end

        if addon.SetWorkbenchNotice then addon:SetWorkbenchNotice(control, overlapText and true or false, tie) end
        local lines = {}
        if blockedText then lines[#lines + 1] = blockedText end

        if entry.readOnly then
            lines[#lines
                + 1] = L['Built In: it cannot be edited. Duplicate makes your own copy; Enabled and Priority are your settings for this profile.']
        end

        if entry.readOnly and not entry.eligible and not blockedText then
            local reasons = addon.BuiltinEligibilityReasons or {}

            lines[#lines + 1] = string.format(
                L['Not available for this character: %s'],
                reasons[entry.eligibilityReason] or L['Unavailable']
            )
        end

        if specText and status ~= line(specText) then lines[#lines + 1] = line(specText) end
        if entry.scope then lines[#lines + 1] = entry.scope == 'character' and L['This character'] or L['Class'] end
        if disabledText then lines[#lines + 1] = disabledText end
        if overlapText then lines[#lines + 1] = overlapText end
        local identifier = self.identifiers and self.identifiers[key]
        if entry.fallback and entry.spec ~= nil and entry.spec ~= addon.currentSpec then identifier = nil end

        if identifier then
            lines[#lines + 1] = string.format(L['Identifier: %s (/rm set %s)'], identifier, identifier)
        end

        if not entry.fallback then
            lines[#lines
                + 1] = L['Higher numbers are tried first; equal priorities go by name. Your rotations and Built Ins compete on priority alone.']
        end

        control.tooltip = #lines > 0 and table.concat(lines, '\n\n') or nil

        -- True while this row's list is still the live one: same serial, profile, specialization and navigation
        -- state, and the row's key is still listed.
        local function requestValid()
            return browser.active
                and browser.serial == serial
                and browser.profile == profile
                and profile == addon.db.profile
                and browser.spec == spec
                and browser.navigationRevision == navigation
                and browser.rowsByKey[key] ~= nil
        end

        -- A Built In you switched off turns back on from the list in one click.
        if entry.readOnly and entry.builtinState == 'user-disabled' then
            if not control.enableButton then
                control.enableButton = addon:CreateWorkbenchButton(control, L['Turn on'], 64)
                control.enableButton:SetHeight(18)
                control.enableButton:SetPoint('RIGHT', control, 'RIGHT', -6, 0)
            end

            local button = control.enableButton
            button.tooltip = L['Turn this Built In back on for this profile.']

            addon:SetUIScript(button, 'OnClick', function()
                if not requestValid() or control.browserLease ~= lease then return end
                local ok = addon:SetDefaultRotationEnabled(entry.canonicalId, true)

                if ok then
                    if addon.currentSpec ~= nil and addon.db.profile.enable then
                        addon:UpdateAutoSwitch()
                        addon:SwitchRotation()
                    end

                    browser:RefreshRows()
                end
            end)

            button:Show()
        elseif control.enableButton then
            addon:SetUIScript(control.enableButton, 'OnClick', nil)
            control.enableButton:Hide()
        end

        addon:SetUIScript(control, 'OnClick', function()
            if requestValid() and browser.resultRevision == revision and control.browserLease == lease then
                browser:SelectRotation(target, key, false, requestValid)
            end
        end)

        control:Show()
    end

    -- Binds row controls to the visible slice of the list (plus a margin) and retires the rest, so only a screenful
    -- of controls exists however many rotations there are. Re-entry and rebuilds in progress are ignored; a failing
    -- bind retires the half-bound row before the error is re-raised.
    function browser:RefreshViewport()
        if
            not self.active or self.profile ~= addon.db.profile or self.rebuilding or self.refreshing or not self.rows
        then
            return
        end

        self.refreshing = true
        local binding

        local ok, why = pcall(function()
            local first, last = addon:GetWorkbenchVisibleRowRange(
                #self.rows,
                48,
                list.workbenchBar:GetValue(),
                list:GetHeight(),
                96
            )

            local bound = {}

            for _, control in ipairs(self.rowButtons) do
                if control.browserLease then
                    local index = control.browserIndex

                    if index >= first and index <= last then
                        bound[index] = control
                        control:SetWidth(child:GetWidth())
                        control.nameLabel:SetWidth(math.max(32, child:GetWidth() - 12))
                        control.statusLabel:SetWidth(math.max(32, child:GetWidth() - 12))
                    else
                        self:RetireRow(control)
                    end
                end
            end

            local free = 1

            for index = first, last do
                if not bound[index] then
                    while self.rowButtons[free] and self.rowButtons[free].browserLease do
                        free = free + 1
                    end

                    local control = self.rowButtons[free]

                    if not control then
                        control = addon:CreateWorkbenchListRow(child, child:GetWidth(), 46)
                        self.rowButtons[free] = control
                        control.nameLabel = label(control, 'GameFontHighlight')
                        control.nameLabel:SetPoint('TOPLEFT', 6, -5)
                        control.statusLabel = label(control)
                        control.statusLabel:SetPoint('TOPLEFT', 6, -24)
                    end

                    binding = control
                    self:BindRow(control, self.rows[index], index)
                    binding = nil
                end
            end
        end)

        self.refreshing = nil

        if not ok then
            if binding then pcall(self.RetireRow, self, binding) end
            error(why, 0)
        end
    end

    -- ============================================================================
    -- Roster and filters
    -- ============================================================================

    -- Rebuilds the roster from the rotation library: reads headers (plus other specializations' Defaults under "All"
    -- and pending new rotations), sorts them in automatic-switching order, applies the kind, specialization, tag and
    -- search filters, then restores the scroll position by anchor row. Bumps resultRevision (and navigationRevision
    -- when the filter signature changes) so row handlers from the previous list go stale. Updates the counts and
    -- the Duplicate and Compare buttons.
    function browser:RefreshRows()
        if not self.active or self.profile ~= addon.db.profile then return end
        local offset = list.workbenchBar:GetValue()
        local anchor = self.rows and self.rows[math.floor(offset / 48) + 1]
        local anchorOffset = offset % 48
        self.rebuilding = true
        self.resultRevision = (self.resultRevision or 0) + 1

        for _, control in ipairs(self.rowButtons) do
            self:RetireRow(control)
        end

        local all, state = addon:ListRotationHeaders(self.spec)
        local reason = not all and state or nil
        self.rosterStamp = all and state or nil
        all = all or {}
        self.loadError = reason
        -- Each specialization has its own fallback (Default), stored under its
        -- key; every other rotation is shared. "All specializations" lists
        -- every one's Default beside the shared rotations.
        local all_specs = self.specValue == 'all' and #(self.specKeys or {}) > 1
        self.specOrder = {}

        for index, key in ipairs(self.specKeys or {}) do
            self.specOrder[key] = index
        end

        for _, entry in ipairs(all) do
            entry.spec = self.spec
        end

        if all_specs and not reason then
            for _, key in ipairs(self.specKeys) do
                if key ~= self.spec then
                    for _, entry in ipairs(addon:ListRotationHeaders(key) or {}) do
                        if entry.fallback then
                            entry.spec = key
                            all[#all + 1] = entry
                        end
                    end
                end
            end
        end

        local byKey = {}

        for _, entry in ipairs(all) do
            byKey[entry.key] = entry
        end

        local draftSpecs = all_specs and self.specKeys or { self.spec }
        local drafts = {}

        for _, key in ipairs(draftSpecs) do
            for _, entry in ipairs(addon.ListPendingRotationDrafts and addon:ListPendingRotationDrafts(key) or {}) do
                entry.spec = key
                drafts[#drafts + 1] = entry
            end
        end

        for _, entry in ipairs(drafts) do
            if not byKey[entry.key] then
                local view = entry.presentation or {}

                local row = {
                    key = entry.key,
                    spec = entry.spec,
                    reference = entry.reference,
                    canonicalId = entry.canonicalId,
                    name = entry.name,
                    scope = entry.scope,
                    kind = 'custom',
                    pending = true,
                    fallback = entry.fallback,
                    effectiveFallback = false,
                    validationState = 'pending',
                    tags = addon.RotationData.GetRotationTags(view) or {},
                    search = addon.RotationData.RotationSearchText(view, entry.name, view.description),
                    priority = addon.RotationData.GetRotationPriority(view.priority),
                }

                all[#all + 1] = row
                byKey[row.key] = row
            end
        end

        if self.pendingId and byKey[self.pendingId] and not byKey[self.pendingId].pending then self.pendingId = nil end
        self.allByKey = byKey

        -- The order automatic switching tries them in: by priority (higher
        -- first), then name, your rotations and Built Ins alike; the fallback,
        -- the last resort, comes last.
        table.sort(all, function(a, b)
            if a.fallback ~= b.fallback then return b.fallback == true end
            local ap, bp = a.priority or -math.huge, b.priority or -math.huge
            if ap ~= bp then return ap > bp end
            if a.name ~= b.name then return a.name < b.name end

            -- Defaults of different specializations: the one you play first.
            if a.fallback and a.spec ~= b.spec then
                return (self.specOrder[a.spec] or math.huge) < (self.specOrder[b.spec] or math.huge)
            end

            return tostring(a.key) < tostring(b.key)
        end)

        self.overlaps = self.spec == addon.currentSpec and addon.GetSwitchOverlaps and addon:GetSwitchOverlaps(
            self.spec
        )
            or {}

        self.identifiers = {}

        if addon.ListRotationIdentifiers then
            for _, entry in ipairs(addon:ListRotationIdentifiers(self.spec, all)) do
                self.identifiers[entry.key] = entry.identifier
            end
        end

        local tags, seen = {}, {}
        self.tagRevision = (self.tagRevision or 0) + 1

        for _, entry in ipairs(all) do
            for _, tag in ipairs(entry.tags or {}) do
                local canonical = tag:lower()

                if not seen[canonical] then
                    tags[#tags + 1] = tag
                    seen[canonical] = true
                end
            end
        end

        table.sort(tags, function(a, b) return a:lower() < b:lower() end)
        self.availableTags = tags
        local selected = {}

        for _, tag in ipairs(self.selectedTags) do
            if seen[tag:lower()] then selected[#selected + 1] = tag end
        end

        self.selectedTags = selected
        self.tag = selected[1]
        self.tagPicker:SetTags(selected)
        local rows = {}

        for _, entry in ipairs(all) do
            if
                (self.filter == 'all' or self.filter == entry.kind)
                and self:SpecMatches(entry)
                and addon.RotationData.RotationTagMatches(entry.tags, self.selectedTags, self.tagMode)
                and entry.search:find(self.query, 1, true)
            then
                rows[#rows + 1] = entry
            end
        end

        self.rows = rows
        self.rowsByKey = {}
        local positions = {}

        for index, entry in ipairs(rows) do
            self.rowsByKey[entry.key] = entry
            positions[entry.key] = index
        end

        local parts = {
            tostring(self.specValue == 'all' and 'all' or self.spec),
            tostring(self.specValue),
            self.filter,
            self.query,
            self.tagMode,
        }

        for _, tag in ipairs(self.selectedTags) do
            parts[#parts + 1] = tag
        end

        for index, value in ipairs(parts) do
            parts[index] = #value .. ':' .. value
        end

        local signature = table.concat(parts, ';')

        if signature ~= self.navigationSignature then
            self.navigationSignature = signature
            self.navigationRevision = (self.navigationRevision or 0) + 1
        end

        empty:SetText(reason or L['No rotations match this search.'])

        if #rows == 0 then
            empty:Show()
        else
            empty:Hide()
        end

        child:SetHeight(math.max(30, #rows * 48))
        list:UpdateScrollChildRect()
        list:UpdateWorkbenchScroll()

        if anchor and positions[anchor.key] then
            list.workbenchBar:SetValue((positions[anchor.key] - 1) * 48 + anchorOffset)
        end

        self.rebuilding = nil
        self:RefreshViewport()
        count:SetText(string.format(L["%d of %d rotations"], #rows, #all))

        if
            not self.selected
            or self.pendingId == self.selected
            or self.nativeDetails and self.pane and self.pane.workspace.pending
        then
            duplicate:Disable()
            compare:Disable()
        else
            duplicate:Enable()
            compare:Enable()
        end

        for key, control in pairs(self.filters) do
            if key == self.filter then
                control:Disable()
            else
                control:Enable()
            end
        end
    end

    -- Whether a row shows under the specialization filter. The fallback is
    -- the namespace's own; a pending new rotation always shows.
    function browser:SpecMatches(entry)
        if self.specValue == 'all' or self.specValue == nil or entry.fallback or entry.pending then return true end
        return addon.RotationData.RotationSpecsMatch(entry.specs, self.specValue)
    end

    -- The namespace a filter value reads (fallback, new rotations): the value
    -- itself where namespaces are specializations, else the current one.
    function browser:KeyForSpecValue(value)
        if
            type(value) == 'number'
            and addon.Platform.RotationKeyIsSpecValue
            and addon.Platform:RotationKeyIsSpecValue()
        then
            for _, entry in ipairs(self.specEntries or {}) do
                if entry.id == value then return value end
            end
        end

        return addon.currentSpec ~= nil and addon.currentSpec or self.specKeys and self.specKeys[1]
    end

    -- Shows the selected specialization (or "All specializations") on the filter button and the warning when it is
    -- not the player's current one.
    function browser:PaintSpecFilter()
        local current = addon:GetCurrentRotationSpecValue()
        local text = L['All specializations']
        local icon

        for _, entry in ipairs(self.specEntries or {}) do
            if entry.id == self.specValue then
                text = entry.name
                icon = entry.icon
            end
        end

        addon:PaintSelectorSelection(specFilter, icon and { icon = icon } or nil, text)

        if type(self.specValue) == 'number' and current ~= nil and self.specValue ~= current then
            specWarning:Show()
        else
            specWarning:Hide()
        end
    end

    -- Applies a specialization filter value (a specialization id or 'all'): selects that namespace's rotation when the
    -- namespace changes, otherwise just refreshes the list.
    function browser:SetSpecValue(value)
        if not self.active then return end
        self.specValue = value
        addon.rotationListSpec = value
        self:PaintSpecFilter()
        local key = self:KeyForSpecValue(value)

        if key ~= self.spec then
            self:SelectRotation(key, key == addon.currentSpec and addon.currentRotation or DEFAULT, true)
        else
            self:RefreshRows()
        end

        self:Layout()
        list.workbenchBar:SetValue(0)
    end

    addon:SetUIScript(specFilter, 'OnClick', function()
        if not browser.active then return end
        local entries = {}

        for _, entry in ipairs(browser.specEntries or {}) do
            entries[#entries + 1] = { value = entry.id, text = entry.name, icon = entry.icon }
        end

        entries[#entries + 1] = { value = 'all', text = L['All specializations'] }
        local serial = browser.serial

        specMenu:Open(
            specFilter,
            entries,
            browser.specValue,
            function(value)
                if browser.active and browser.serial == serial and value ~= browser.specValue then
                    browser:RequestLeave(function()
                        if browser.active and browser.serial == serial then browser:SetSpecValue(value) end
                    end)
                end
            end,
            function() return browser.active and browser.serial == serial end,
            true
        )
    end)

    -- Sets the tag filter from a list of tags (normalized; ignored if invalid) and refreshes the list.
    function browser:SetTags(tags)
        if not self.active then return end
        local normalized = addon.RotationData.NormalizeRotationTags(tags or {})
        if not normalized then return end
        self.selectedTags = normalized
        self.tag = normalized[1]
        self:RefreshRows()
        list.workbenchBar:SetValue(0)
    end

    -- Single-tag convenience over SetTags: a string selects it, nil clears the filter.
    function browser:SetTag(value)
        if value == nil or type(value) == 'string' then self:SetTags(value and { value } or {}) end
    end

    -- Sets the kind filter ('all', 'builtin' or 'custom'); other values are ignored.
    function browser:SetFilter(value)
        if value ~= "all" and value ~= "builtin" and value ~= "custom" then return end
        self.filter = value
        self:RefreshRows()
        list.workbenchBar:SetValue(0)
    end

    -- ============================================================================
    -- Selection
    -- ============================================================================

    -- Runs `callback` once the editor pane agrees to be left (it may prompt about unsaved changes); with no editor it
    -- runs at once. Returns what the pane returns, or true.
    function browser:RequestLeave(callback)
        if self.nativeDetails and self.pane and self.pane.RequestLeave then return self.pane:RequestLeave(callback) end
        callback()
        return true
    end

    -- An untouched new rotation has nothing to keep: leaving it (for another
    -- rotation, or closing the window) removes it instead of leaving a
    -- placeholder in the list. One with edits was handled by the leave prompt.
    function browser:DropUntouchedNew(nextKey)
        local pane = self.pane
        local old = pane and self.nativeDetails and pane.workspace

        if not old or not old.pending or old.id == nextKey or not pane.IsUntouchedNew or not pane:IsUntouchedNew() then
            return
        end

        addon:DiscardPendingRotation(old)
    end

    -- Selects rotation `id` in specialization namespace `spec` and opens it in the editor pane. Unless `approved`, the
    -- editor's leave prompt runs first and the selection repeats once it agrees. `requestValid`, when given, is the
    -- caller's staleness check. Falls back to the namespace's fallback rotation, then the first row, when `id` is
    -- missing; an editor failure is shown in place of the pane. Always ends with a roster refresh.
    function browser:SelectRotation(spec, id, approved, requestValid)
        if not self.active or self.profile ~= addon.db.profile or requestValid and not requestValid() then return end

        if not approved and self.pane and self.nativeDetails then
            local owner = self.editorOwner

            return self:RequestLeave(function()
                if self.active and self.editorOwner == owner and (not requestValid or requestValid()) then
                    self:SelectRotation(spec, id, true, requestValid)
                end
            end)
        end

        local found = false

        for _, key in ipairs(self.specKeys) do
            if key == spec then
                found = true
                break
            end
        end

        if not found then spec = self:KeyForSpecValue(self.specValue) end

        -- Moving between specializations' Defaults under "All" keeps the search.
        if spec ~= self.spec and self.specValue ~= 'all' then
            self.pendingId = nil
            self.query = ""
            search:SetText("")
        end

        self.spec = spec
        local headers, headerState = addon:ListRotationHeaders(spec)
        local headerError = not headers and headerState or nil
        local reference, selectionError = addon:ResolveRotationReference(spec, id)
        local key, fallback

        for _, entry in ipairs(headers or {}) do
            if reference and sameReference(reference, entry.reference) then key = entry.key end
            if entry.effectiveFallback or not fallback and entry.fallback then fallback = entry.key end
        end

        if not key and reference and type(id) == 'string' then key = id end
        self.selected = key or fallback or headers and headers[1] and headers[1].key
        addon.configRotationSelection = { spec = spec, id = self.selected }
        self:DropUntouchedNew(self.selected)
        self:ReleaseDetails()
        local owner = {}
        self.editorOwner = owner

        -- Callback handed to the editor so it can ask the browser to select another rotation; ignored once this
        -- editor has been replaced.
        local function selected(nextSpec, nextId)
            if self.active and self.editorOwner == owner then self:SelectRotation(nextSpec, nextId) end
        end

        local pane, problem

        if not self.selected then
            problem = headerError or selectionError or L['No rotations match this search.']
        elseif type(addon.CreateRotationEditor) == 'function' then
            pane, problem = addon:CreateRotationEditor(detail, spec, self.selected, selected)
        else
            problem = L['The native rotation editor is unavailable.']
        end

        if not pane then
            self.editorOwner = nil
            local label = detail.rmEditorError or detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            detail.rmEditorError = label
            label:SetPoint("TOPLEFT", 8, -8)
            label:SetText(tostring(problem or L['The native rotation editor is unavailable.']))
            label:Show()
        else
            if detail.rmEditorError then detail.rmEditorError:Hide() end
            self.nativeDetails = true
            self.pane = pane

            pane.onSaved = function()
                if self.active and self.editorOwner == owner then
                    self.selected = pane.workspace.id or self.selected
                    addon.configRotationSelection = { spec = self.spec, id = self.selected }
                    self:RefreshRows()
                end
            end
        end

        self:RefreshRows()
    end

    -- ============================================================================
    -- Layout and lifecycle
    -- ============================================================================

    -- Positions the list column (specialization filter, search, kind buttons, tags, list, count, action buttons,
    -- recovery button), the splitter and the editor pane for the current frame size, then rebinds the visible rows.
    function browser:Layout()
        local width, height = frame:GetWidth(), frame:GetHeight()
        local geometry = addon:GetWorkbenchRosterGeometry(width, height, 0)
        local leftWidth = geometry.sidebarWidth
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        left:SetSize(leftWidth, geometry.sidebarHeight)
        detail:SetPoint("TOPLEFT", frame, "TOPLEFT", geometry.detailX, 0)
        detail:SetSize(geometry.detailWidth, geometry.sidebarHeight)
        self.splitter:Place(geometry)
        -- The specialization filter (and its warning) sit inside the list
        -- column, above the search box, only where specializations exist.
        local offset = 0

        if self.hasSpecFilter then
            specFilter:Show()
            specFilter:SetWidth(leftWidth)
            offset = 28

            if specWarning:IsShown() then
                specWarning:ClearAllPoints()
                specWarning:SetPoint('TOPLEFT', left, 'TOPLEFT', 2, -offset)
                specWarning:SetWidth(leftWidth - 4)
                offset = offset + 18
            end
        else
            specFilter:Hide()
            specWarning:Hide()
        end

        search:ClearAllPoints()
        search:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -offset)

        for _, control in pairs(self.filters) do
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", left, "TOPLEFT", (control.filterIndex - 1) * 80, -offset - 28)
        end

        addon:LayoutWorkbenchRow({
            self.filters.all,
            self.filters.builtin,
            self.filters.custom,
        }, 0, offset + 28, leftWidth)

        self.tagLabel:ClearAllPoints()
        self.tagLabel:SetPoint('TOPLEFT', 0, -offset - 56)
        self.tagModeButton:ClearAllPoints()
        self.tagModeButton:SetPoint('TOPLEFT', 40, -offset - 56)
        self.tagPicker.frame:ClearAllPoints()
        self.tagPicker.frame:SetPoint('TOPLEFT', 0, -offset - 56)
        search:SetWidth(leftWidth)
        local footerExtra = self.hasRecovery and 26 or 0
        local footerHeight = 50 + footerExtra
        self.tagPicker:SetWidth(leftWidth)
        local listTop = offset + 56 + self.tagPicker.height + 8
        list:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -listTop)
        list:SetHeight(math.max(64, left:GetHeight() - listTop - 36 - footerHeight))
        list:SetWorkbenchColumnWidth(leftWidth)
        child:SetWidth(list:GetWidth())
        count:ClearAllPoints()
        count:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, footerHeight + 8)
        count:SetWidth(leftWidth)
        local buttonWidth = (leftWidth - 4) / 2

        for _, control in ipairs({ new, duplicate, import, compare }) do
            control:ClearAllPoints()
            control:SetWidth(buttonWidth)
            addon:AlignWorkbenchTextLeft(control, 24)
        end

        new:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 24 + footerExtra)
        duplicate:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", buttonWidth + 4, 24 + footerExtra)
        import:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, footerExtra)
        compare:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", buttonWidth + 4, footerExtra)
        recovery:ClearAllPoints()
        recovery:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
        recovery:SetWidth(leftWidth)
        empty:SetWidth(math.max(40, child:GetWidth() - 8))

        if self.pane then
            self.pane:SetWidth(detail:GetWidth())
            self.pane:SetHeight(detail:GetHeight())
        end

        self:RefreshViewport()
    end

    -- Size setters used by the owning window's layout; the frame's OnSizeChanged runs Layout.
    function browser:SetWidth(value)
        frame:SetWidth(value)
    end

    function browser:SetHeight(value)
        frame:SetHeight(value)
    end

    -- Retires the browser when the page is left: marks it inactive (so every pending handler is ignored), discards an
    -- untouched new rotation, releases the editor and menus, and hides the frame. The browser can be Opened again.
    function browser:Release()
        self.active = false
        self.serial = (self.serial or 0) + 1
        self.tagPicker:Hide()
        self:DropUntouchedNew(nil)
        self:ReleaseDetails()
        self.pendingId = nil
        search:ClearFocus()
        if self.tagMenu then self.tagMenu:Release() end
        specMenu:Hide()
        addon.rotationListSpec = nil

        for _, control in ipairs(self.rowButtons) do
            self:RetireRow(control)
        end

        frame:Hide()
    end

    -- (Re)opens the page: resets the filters and search, works out which specialization namespaces the list can
    -- read, then selects `selection` ({ spec, id }) or the current rotation. The browser is inactive until the
    -- namespaces are known so no handler runs on half-built state. Returns the browser.
    function browser:Open(selection)
        self.active = false
        self.serial = (self.serial or 0) + 1
        self.tagPicker:Hide()

        for _, control in ipairs(self.rowButtons) do
            self:RetireRow(control)
        end

        self.filter = "all"
        self.tag = nil
        self.query = ""
        search:SetText("")
        -- Session only: every opening starts at your current specialization.
        self.specEntries = addon.GetRotationSpecEntries and addon:GetRotationSpecEntries() or {}
        self.hasSpecFilter = #self.specEntries > 0
        local current = addon.GetCurrentRotationSpecValue and addon:GetCurrentRotationSpecValue()
        self.specValue = self.hasSpecFilter and (current ~= nil and current or 'all') or nil
        addon.rotationListSpec = self.specValue
        -- The namespaces this list can read: yours, and every specialization
        -- where namespaces are specializations (each keeps its own fallback).
        self.specKeys = {}
        if addon.currentSpec ~= nil then self.specKeys[1] = addon.currentSpec end

        if addon.Platform.RotationKeyIsSpecValue and addon.Platform:RotationKeyIsSpecValue() then
            for _, entry in ipairs(self.specEntries) do
                if entry.id ~= addon.currentSpec then self.specKeys[#self.specKeys + 1] = entry.id end
            end
        end

        if #self.specKeys == 0 then
            for _, entry in ipairs(addon:GetRotationEditorSpecs()) do
                self.specKeys[#self.specKeys + 1] = entry.id
            end
        end

        if self.hasSpecFilter then self:PaintSpecFilter() end
        self:RefreshRecovery()
        self:Layout()
        frame:Show()
        local spec = selection and selection.spec or addon.currentSpec
        local found = false

        for _, key in ipairs(self.specKeys) do
            if key == spec then
                found = true
                break
            end
        end

        if not found then spec = self:KeyForSpecValue(self.specValue) end

        -- Opening a namespace that is another specialization shows that one.
        if
            self.hasSpecFilter
            and spec ~= addon.currentSpec
            and addon.Platform.RotationKeyIsSpecValue
            and addon.Platform:RotationKeyIsSpecValue()
        then
            self.specValue = spec
            addon.rotationListSpec = spec
            self:PaintSpecFilter()
        end

        self.active = true
        self.profile = addon.db.profile
        self.selectedTags = {}
        self.tagPicker.frame:Show()
        self.tagPicker.input:Show()

        self:SelectRotation(
            spec,
            selection and selection.id or spec == addon.currentSpec and addon.currentRotation or DEFAULT
        )

        return self
    end

    list.workbenchBar:HookScript('OnValueChanged', function() browser:RefreshViewport() end)
    addon:SetUIScript(frame, "OnSizeChanged", function() browser:Layout() end)
    return browser
end

-- ============================================================================
-- Entry point
-- ============================================================================

-- Returns the (cached) rotation browser for `parent`, sized to it and opened on `selection` ({ spec, id } or nil).
function addon:CreateRotationBrowser(parent, selection)
    local browser = parent.rmRotationBrowser

    if not browser then
        browser = create(parent)
        parent.rmRotationBrowser = browser
    end

    browser:SetWidth(parent:GetWidth())
    browser:SetHeight(parent:GetHeight())
    return browser:Open(selection)
end
