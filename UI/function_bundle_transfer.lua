-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Import and export window for custom function and custom condition bundles: the bundle text, per-item conflict choices
-- (reuse, replace, rename, create), the required-function list and a read-only source review window. Nothing is saved
-- until the whole bundle has been reviewed and Apply import is pressed, and the plan comes from the bundle services in
-- Core (BuildFunctionBundle, ParseFunctionBundleImport, PlanFunctionBundleImport, ApplyFunctionBundleImport). Imported
-- Lua runs once registered, so the warning text stays on screen. Loaded from RotationMaster.toc after
-- UI/function_bindings.lua and UI/function_source_pane.lua; callers are the function and custom condition editors.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Conflict actions offered for each bundle entry whose identifier already exists.
local actions = {
    { value = 'reuse', text = L['Reuse existing'] },
    { value = 'replace', text = L['Replace existing'] },
    { value = 'rename', text = L['Import with new identifier'] },
    { value = 'create', text = L['Create'] },
}

-- Formats an import failure (a record with callback or field, and detail or reason, or a plain value) as one status
-- line.
local function problemText(why)
    if type(why) == 'table' then
        return (why.callback or why.field or L['Definition']) .. ': ' .. tostring(
            why.detail or why.reason or L['Invalid import.']
        )
    end

    return tostring(why)
end

-- ============================================================================
-- Source review window
-- ============================================================================

-- Opens (creating once per owner) the read-only source review window for one import row: description, identifiers,
-- signature or callback chooser, binding aliases and the code in a read-only Lua editor. It closes itself as soon as
-- ownerValid() fails or the owner's plan or row changes, so it can never show source for a different import.
function addon:ShowFunctionBundleSource(owner, row, ownerValid)
    local view = owner.sourceReview

    if not view then
        view = { frame = CreateFrame('Frame', nil, UIParent) }
        owner.sourceReview = view
        view.frame:SetSize(880, 680)
        view.frame:SetPoint('CENTER')
        view.frame:EnableMouse(true)
        self:MakeWindowOpaque(view.frame)
        view.title = view.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        view.chrome = self:CreateWorkbenchDialogChrome(view.frame, view.title)
        view.chromeUpdate = view.frame:GetScript('OnUpdate')
        view.body = CreateFrame('Frame', nil, view.frame)
        view.body:SetPoint('TOPLEFT', 8, -36)
        view.body:SetSize(864, 606)
        view.form = self:CreateSettingsForm(view.body)
        view.close = self:CreateWorkbenchButton(view.frame, L['Close'], 104)
        view.close:SetPoint('BOTTOMRIGHT', -12, 28)

        self:SetUIScript(view.close, 'OnClick', function()
            view.frame:Hide()
        end)

        view.xClose = self:CreateWorkbenchIconButton(view.frame, 'close', L['Close'])
        view.xClose:SetPoint('TOPRIGHT', -5, -5)

        self:SetUIScript(view.xClose, 'OnClick', function()
            view.frame:Hide()
        end)

        -- Window-registry hook: hides the review window.
        function view:Hide()
            self.frame:Hide()
        end
    end

    view.serial = (view.serial or 0) + 1
    local serial = view.serial

    -- True while this review window is the current one, still shown and its owner (the transfer window) is still valid.
    local function valid()
        return view.serial == serial and view.frame:IsShown() and ownerValid()
    end

    view.chrome:SetContext(row.originalName, L['Review source'], row.originalID)
    local source = row.originalSource or row.source
    view.selected = row.kind == 'function' and 'code' or 'evaluate'

    view.form:Open(function(form)
        form.width = 830
        form.child:SetWidth(form.width)
        form:Text(source.description or '')

        form:Text(
            L['Original identifier']
                .. ': '
                .. row.originalID
                .. '   '
                .. L['Destination identifier']
                .. ': '
                .. row.destinationID
        )

        if row.kind == 'function' then
            form:Text(addon:FunctionSignature(row.originalID, source))

            for _, argument in ipairs(source.args or {}) do
                if argument.description and argument.description ~= '' then
                    form:Text((argument.name or '') .. ': ' .. argument.description)
                end
            end

            for _, result in ipairs(source.returns or {}) do
                if result.description and result.description ~= '' then
                    form:Text((result.type or '') .. ': ' .. result.description)
                end
            end
        else
            local callbacks = {
                { value = 'evaluate', text = L['Evaluate'] },
                { value = 'valid', text = L['Validate'] },
                { value = 'print', text = L['Summary'] },
                { value = 'widget', text = L['Fields UI'] },
                { value = 'help', text = L['Help'] },
                { value = 'on_register', text = L['On register'] },
                { value = 'on_unregister', text = L['On unregister'] },
            }

            form:Choice('callback', L['Callback'], view.selected, callbacks, function(value)
                view.selected = value
                view.code:SetText(source[value] or '')
            end)
        end

        local aliases = {}

        for alias, id in pairs(source.bindings or {}) do
            aliases[#aliases + 1] = alias .. ' → ' .. id
        end

        table.sort(aliases)

        if #aliases > 0 then
            form:Text(table.concat(aliases, ', '))
        end

        if view.code and view.code.Acquire then
            view.code:Acquire(function() end, valid)
        else
            view.code = addon:CreateWorkbenchLuaEditor(form.child, function() end, valid, 'native')
        end

        view.code:SetReadOnly(true)
        view.code:SetText(source[view.selected] or '')
        view.code.frame:ClearAllPoints()
        view.code.frame:SetPoint('TOPLEFT', 0, -form.y)
        view.code.frame:SetSize(form.width, math.max(300, view.body:GetHeight() - form.y - 24))
        form.y = form.y + view.code.frame:GetHeight() + 8
    end)

    local plan = owner.plan
    local sourceEvidence = self:CopySettingsData(source)
    local originalID, destinationID, kind = row.originalID, row.destinationID, row.kind

    -- Help is bound only while the very same row, plan and source evidence are still on screen.
    local function helpValid()
        if
            not valid()
            or owner.sourceReview ~= view
            or owner.plan ~= plan
            or row.originalID ~= originalID
            or row.destinationID ~= destinationID
            or row.kind ~= kind
        then
            return false
        end

        local found = false

        for _, candidate in ipairs(owner.lastRows or {}) do
            if candidate == row then
                found = true
                break
            end
        end

        return found and (row.originalSource or row.source) == source and addon:SettingsDataEqual(
            source,
            sourceEvidence
        )
    end

    self:SetUIScript(view.frame, 'OnHide', function()
        if view.code then
            view.code:Release()
        end

        view.form:Release()
    end)

    self:SetUIScript(view.frame, 'OnUpdate', function(...)
        if view.chromeUpdate then
            view.chromeUpdate(...)
        end
        if not valid() then
            view.frame:Hide()
        end
    end)

    view.frame:Show()
    self:OpenPopup(view, owner)

    self:BindTransferHelp(
        view,
        {
            heading = L['Review source'],
            owner = row.originalName,
            brief = L['Help.Transfers.source_brief'],
            sections = { { title = L['Read-only'], text = L['Help.Transfers.source_review'] } },
            briefs = { close = L['Help.Transfers.source_close'], xClose = L['Help.Transfers.source_close'] },
        },
        helpValid
    )

    return view
end

-- ============================================================================
-- Bundle transfer window
-- ============================================================================

-- Shows the bundle window for the settings pane p: exports (source, id) as bundle text and lets the player paste
-- another bundle to import. options.kind is 'function' (default) or 'condition'; options.text pre-fills and reviews an
-- incoming bundle; options.valid() ties the window to its caller; options.onApplied(rootId) replaces the default
-- refresh of the function editor and options.onClose runs when the window hides. Returns the dialog. Any change of the
-- pasted text or of a choice invalidates the plan, so Apply import only ever applies exactly what was reviewed.
function addon:ShowFunctionBundleTransfer(p, id, source, options)
    options = options or {}
    local kind = options.kind or 'function'
    local codec = self:NewRotationCodec()
    local d = p.functionBundleTransfer

    if d and d.frame:IsShown() then
        d.frame:Hide()
    end

    if not d then
        d = self:CreateWorkbenchTransferShell(880, 720)
        p.functionBundleTransfer = d
        d.includeDependencies = self:CreateWorkbenchCheckBox(d.frame, L['Include custom function dependencies'], 420)
        d.includeDependencies:SetPoint('TOPLEFT', 12, -34)
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint('TOPLEFT', 12, -66)
        d.scroll:SetSize(852, 152)
        d.input:SetMaxLetters(self:ExportTextLimit(1048576))
        d.input:SetSize(828, 152)
        self:UseExportFont(d)
        d.review = self:CreateWorkbenchButton(d.frame, L['Review import'], 116)
        d.review:SetPoint('TOPLEFT', 12, -226)
        d.copy:ClearAllPoints()
        d.copy:SetPoint('LEFT', d.review, 'RIGHT', 8, 0)
        d.clear:ClearAllPoints()
        d.clear:SetPoint('LEFT', d.copy, 'RIGHT', 6, 0)
        d.status = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.status:SetPoint('TOPLEFT', 12, -258)
        d.status:SetSize(852, 44)
        d.status:SetJustifyH('LEFT')
        d.status:SetWordWrap(true)
        d.body = CreateFrame('Frame', nil, d.frame)
        d.body:SetPoint('TOPLEFT', 4, -306)
        d.body:SetSize(872, 344)
        d.form = self:CreateSettingsForm(d.body)
        d.apply:SetText(L['Apply import'])
        d.apply:SetWidth(116)
        d.apply:ClearAllPoints()
        d.apply:SetPoint('BOTTOMRIGHT', -124, 28)
        d.cancel:SetWidth(104)
        d.cancel:ClearAllPoints()
        d.cancel:SetPoint('BOTTOMRIGHT', -12, 28)
    end

    d.serial = (d.serial or 0) + 1
    local serial = d.serial
    local token = p.generation
    d.choices = {}
    d.plan = nil
    d.bundle = nil
    d.lastRows = {}
    d.lastRequirements = {}
    d.exportSource = source
    d.include = true
    d.includeDependencies:SetChecked(true)

    if source and id then
        d.includeDependencies:Enable()
    else
        d.includeDependencies:Disable()
    end

    local profile, global = self.db.profile, self.db.global

    -- True while this window is the current one for the pane and the profile and global tables it opened against, and
    -- the caller's own validity test (or the pane's generation token) still holds. Gates every button and refresh.
    local function valid()
        return d.serial == serial
            and d.frame:IsShown()
            and p.active
            and self.db.profile == profile
            and self.db.global == global
            and (options.valid and options.valid() or not options.valid and p:Valid(token))
    end

    d.OwnerValid = valid

    d.chrome:SetContext(
        L['Function dependency bundle'],
        L['Import/Export'],
        source and source.name or id or L['Functions']
    )

    -- Writes a warning-colored message to the dialog's status line.
    local function status(message)
        d.status:SetText(message or '')
        d.status:SetTextColor(1, .75, .35)
    end

    -- Drops the reviewed plan and disables Apply import until the bundle is reviewed again; shows the trust warning.
    function d:Invalidate()
        self.plan = nil
        self.apply:Disable()

        status(
            L['Review the complete bundle before applying an import. Imported Lua can execute when registered; only apply code you trust.']
        )
    end

    -- Rebuilds the export text for the current source (with or without dependencies) and clears any import review.
    function d:Export()
        self.plan = nil
        self.bundle = nil
        self.choices = {}
        self.lastRows = {}
        self.lastRequirements = {}
        local bundle, why = addon:BuildFunctionBundle(kind, id, source, self.include)
        local text, errorText

        if bundle then
            text, errorText = codec:Encode(bundle)
        end

        self.input:SetText(addon:FormatExportText(text))
        self:Invalidate()

        if not text and source then
            status(problemText(why or errorText))
        end

        self.form:Draw()
        self.scroll:UpdateWorkbenchScroll()
    end

    -- Parses the pasted bundle and plans the import with the current conflict choices; enables Apply import only for a
    -- valid plan of the expected kind. Choices reset when the pasted text changes. Returns whether the plan is valid.
    function d:Review()
        if not valid() or not self.form:FlushEdits() then
            return false
        end

        local bundle, why = addon:ParseFunctionBundleImport(self.input:GetText(), codec)

        if not bundle or bundle.root.kind ~= kind then
            self.plan = nil
            self.bundle = nil
            self.lastRows = {}
            self.lastRequirements = {}
            self.apply:Disable()
            status(bundle and L['The imported definition type does not match this editor.'] or problemText(why))
            self.form:Draw()
            return false
        end

        if self.reviewedText ~= self.input:GetText() then
            self.choices = {}
            self.reviewedText = self.input:GetText()
        end

        self.bundle = bundle
        local plan, errorText = addon:PlanFunctionBundleImport(bundle, self.choices)
        self.plan = plan

        if not plan then
            self.apply:Disable()
            status(problemText(errorText))
            return false
        end

        self.lastRows = plan.rows
        self.lastRequirements = plan.requirements

        if plan.valid then
            self.apply:Enable()

            status(
                L['Review each original name, destination and dependency below. Apply import saves the complete reviewed bundle.']
            )
        else
            self.apply:Disable()
            local problems = {}

            for _, problem in ipairs(plan.problems or {}) do
                problems[#problems + 1] = problem.id .. ': ' .. problem.reason
            end

            status(table.concat(problems, '; '))
        end

        self.form:Draw()
        return plan.valid
    end

    d.form:Open(function(form)
        form.width = math.max(240, d.body:GetWidth() - 34)
        form.child:SetWidth(form.width)

        for index, row in ipairs(d.lastRows) do
            form:Heading((row.kind == 'condition' and L['Condition'] or L['Function']) .. ': ' .. row.originalName)
            form:Text(L['Original identifier'] .. ': ' .. row.originalID)
            local choiceKey = row.choiceKey or row.kind .. ':' .. row.originalID
            local choice = d.choices[choiceKey] or {}
            d.choices[choiceKey] = choice

            -- Any edit to a destination or name invalidates the reviewed plan.
            local function changed()
                d:Invalidate()
            end

            form:Choice('action_' .. index, L['Conflict action'], choice.action or row.action, actions, function(value)
                choice.action = value
                changed()
                d:Review()
            end)

            form:Edit(
                'destination_' .. index,
                L['Destination identifier'],
                choice.id or row.destinationID,
                nil,
                function(value)
                    choice.id = value
                    changed()
                end
            )

            if row.kind == 'function' then
                form:Edit(
                    'name_' .. index,
                    L['Imported name'],
                    choice.name or row.source.name or row.originalName,
                    nil,
                    function(value)
                        choice.name = value
                        changed()
                    end
                )
            end

            form:Button('review_source_' .. index, L['Review source'], function()
                addon:ShowFunctionBundleSource(d, row, valid)
            end)

            if row.existing then
                form:Button('compare_' .. index, L['View Changes'], function()
                    addon:ShowWorkbenchDraftChanges(d, 'profile', row.existing, row.source, valid)
                end)
            end
            if #row.effects > 0 then
                form:Text(L['Existing dependents'] .. ': ' .. table.concat(row.effects, ', '))
            end
            if row.source.disabled then
                form:Text(L['This imported definition is disabled. Its dependents remain unavailable.'])
            end
        end

        if #d.lastRequirements > 0 then
            form:Heading(L['Required functions'])
        end

        for _, requirement in ipairs(d.lastRequirements) do
            local text = form:Text(
                (requirement.name or requirement.id) .. ' [' .. requirement.id .. '] — ' .. requirement.status
            )

            if requirement.status ~= 'available' and requirement.status ~= 'included' then
                text:SetTextColor(1, .35, .35)
            end
        end

        if #d.lastRows == 0 then
            form:Text(L['Paste a bundle above, then review its original names, destinations and required functions.'])
        end
    end)

    addon:SetUIScript(d.includeDependencies, 'OnClick', function()
        if valid() then
            d.include = not d.include
            d.includeDependencies:SetChecked(d.include)
            d:Export()
        end
    end)

    addon:SetUIScript(d.input, 'OnTextChanged', function(_, user)
        if user and valid() then
            d:Invalidate()
        end

        d.scroll:UpdateWorkbenchScroll()
    end)

    addon:SetUIScript(d.input, 'OnSizeChanged', function()
        d.scroll:UpdateWorkbenchScroll()
    end)

    addon:SetUIScript(d.input, 'OnCursorChanged', function(_, _, y, _, height)
        local top = -y
        local bar = d.scroll.workbenchBar
        d.scroll:UpdateWorkbenchScroll()

        if top < bar:GetValue() then
            bar:SetValue(top)
        elseif top + height > bar:GetValue() + d.scroll:GetHeight() then
            bar:SetValue(top + height - d.scroll:GetHeight())
        end
    end)

    d.input:EnableMouseWheel(true)

    addon:SetUIScript(d.input, 'OnMouseWheel', function(_, delta)
        local bar = d.scroll.workbenchBar
        bar:SetValue(bar:GetValue() - delta * 40)
    end)

    addon:SetUIScript(d.review, 'OnClick', function()
        d:Review()
    end)

    addon:SetUIScript(d.copy, 'OnClick', function()
        if valid() then
            d.input:SetFocus()
            d.input:HighlightText(0, -1)
        end
    end)

    addon:SetUIScript(d.clear, 'OnClick', function()
        if valid() then
            d.input:SetText('')
            d.input:SetFocus()
            d.input:SetCursorPosition(0)
            d.scroll.workbenchBar:SetValue(0)
            d.choices = {}
            d.plan = nil
            d.bundle = nil
            d.lastRows = {}
            d.lastRequirements = {}
            d:Invalidate()
            d.form:Draw()
        end
    end)

    -- Window-registry hook: hides the dialog.
    function d:Hide()
        self.frame:Hide()
    end

    addon:SetUIScript(d.cancel, 'OnClick', function()
        d:Hide()
    end)

    addon:SetUIScript(d.close, 'OnClick', function()
        d:Hide()
    end)

    addon:SetUIScript(d.frame, 'OnHide', function()
        d.input:ClearFocus()

        if d.sourceReview then
            d.sourceReview:Hide()
        end

        d.form:Release()

        if options.onClose then
            options.onClose()
        end
    end)

    addon:SetUIScript(d.apply, 'OnClick', function()
        if not valid() then
            return
        end

        local pending = false

        for _, record in ipairs(d.form.edits) do
            if record.dirty then
                pending = true
            end
        end

        if pending or d.reviewedText ~= d.input:GetText() then
            d:Review()
            return
        end

        if not d.plan or not d.plan.valid then
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            status(L['Leave combat before applying these settings.'])
            return
        end

        local plan = d.plan
        local ok, why = addon:ApplyFunctionBundleImport(plan)

        if not ok then
            d:Invalidate()
            status(problemText(why))
            return
        end

        local root

        for _, row in ipairs(plan.rows) do
            if row.originalID == plan.bundle.root.id and row.kind == plan.bundle.root.kind then
                root = row.destinationID
            end
        end

        d.frame:Hide()

        if options.onApplied then
            options.onApplied(root)
        else
            if p.inlineFunction then
                p.inlineFunction:Close()
            end

            p:DiscardSettingsDraft()
            p.newFunctionID = nil
            p.newFunctionSource = nil
            p.functionID = root
            p.functionSource = 'custom'
            p:Draw()
        end
    end)

    p.cleanups[#p.cleanups + 1] = function()
        if d.serial == serial then
            d.frame:Hide()
        end
    end

    addon:SetUIScript(d.frame, 'OnUpdate', function(...)
        if d.chromeUpdate then
            d.chromeUpdate(...)
        end
        if d.frame:IsShown() and not valid() then
            d.frame:Hide()
        end
    end)

    d.frame:Show()
    d:Export()

    if options.text then
        d.input:SetText(addon:FormatExportText(options.text))
        d:Review()
    end

    addon:OpenPopup(d, p)
    local briefs = self:TransferHelpBriefs()
    briefs.review = L['Help.Transfers.bundle_review']
    briefs.includeDependencies = L['Help.Transfers.bundle_dependencies']
    local sourceEvidence = self:CopySettingsData(source)

    self:BindTransferHelp(
        d,
        {
            heading = L['Function dependency bundle'],
            owner = source and source.name or id,
            brief = L['Help.Transfers.bundle_brief'],
            sections = {
                { title = L['Import/Export'], text = L['Help.Transfers.bundle'] },
                { title = L['Review source'], text = L['Help.Transfers.source_review'] },
            },
            briefs = briefs,
            valid = function() return d.exportSource == source and addon:SettingsDataEqual(source, sourceEvidence) end,
        },
        valid
    )

    return d
end

-- ============================================================================
-- Custom condition entry point
-- ============================================================================

-- Shows the bundle window for a custom condition dialog (parent), hiding the dialog while it is open and tracking the
-- window as one of its child widgets. update(identifier) runs after a successful import of the condition. Returns the
-- bundle dialog, or nil when the parent has no form or no owner to return to.
function addon:ShowConditionFunctionBundleTransfer(parent, update, key, source, incomingText)
    local owner = parent.rmConditionOwner

    if not owner or not parent.form then
        return
    end

    -- True while the condition dialog can still be resumed, so a closed or replaced dialog is never reopened.
    local function valid()
        return addon:CanResumeCustomConditionDialog(parent, owner)
    end

    local dialog

    dialog = self:ShowFunctionBundleTransfer(parent.form, key and key ~= '' and key or 'IMPORTED_CONDITION', source, {
        kind = 'condition',
        text = incomingText,
        valid = valid,
        onClose = function()
            if dialog then
                owner.widgets[dialog] = nil
                dialog.rmConditionOwner = nil
            end

            if valid() then
                parent:Show()
            end
        end,
        onApplied = function(identifier)
            if valid() then
                parent:Close()
                update(identifier)
            end
        end,
    })

    if not dialog then
        return
    end

    dialog.rmConditionOwner = owner
    owner.widgets[dialog] = true
    parent:HideForChild()
    return dialog
end
