-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation transfer: the Import/Export window for one rotation and the two read-only previews an import can open (a
-- comparison against the rotation it would replace, or the full incoming content in a read-only editor). It stages
-- pasted text through an import session, previews the result and applies it only through ApplyRotationImport; it never
-- writes a rotation itself, and every callback re-checks that the profile, owner and saved record are unchanged.
-- Loaded from RotationMaster.toc directly after UI/rotation_comparison.lua; UI/rotation_browser.lua opens it. The text
-- layer lives in Data and Core, not here.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Builds the serializer/compressor codec used for every rotation export and import (AceSerializer plus LibCompress).
-- @return table  The codec (Encode and Decode).
function addon:NewRotationCodec()
    local serializer, compressor = LibStub("AceSerializer-3.0"), LibStub("LibCompress")

    return self.RotationData.NewCodec({
        serialize = function(value) return serializer:Serialize(value) end,
        deserialize = function(text) return serializer:Deserialize(text) end,
        compress = function(text) return compressor:Compress(text, 1) end,
        decompress = function(text) return compressor:Decompress(text) end,
    })
end

-- ============================================================================
-- Read-only import previews
-- ============================================================================

-- Shows the comparison between an incoming rotation and the one it would replace, as read-only cards in a popup owned
-- by the transfer form. It closes itself when the form, the staged candidate or its own drawing changes, and its
-- widgets are released on hide.
-- @param p table  The transfer form that owns the popup.
-- @param view table  The comparison view of the staged candidate.
-- @param spec number|string  The specialization namespace the conditions are described in.
-- @return table  The popup.
function addon:ShowNativeImportPreview(p, view, spec)
    local d = p.importPreview

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent) }
        p.importPreview = d
        d.frame:SetSize(940, 620)
        d.frame:SetPoint('CENTER')
        d.frame:SetClampedToScreen(true)
        d.frame:EnableMouse(true)
        self:MakeWindowOpaque(d.frame)
        d.title = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = self:CreateWorkbenchDialogChrome(d.frame, d.title)
        d.close = self:CreateWorkbenchIconButton(d.frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)

        self:SetUIScript(d.close, 'OnClick', function()
            d.frame:Hide()
        end)

        d.scroll = self:CreateWorkbenchGroupViewport(d.frame)
        d.scroll:SetPoint('TOPLEFT', 12, -34)
        d.scroll:SetSize(898, 560)

        -- Releases the comparison widgets so a hidden preview holds no pooled condition widgets.
        function d:Clear()
            self.scroll:ReleaseConditionContent()
            self.graph = nil
        end

        self:SetUIScript(d.frame, 'OnHide', function()
            d:Clear()
        end)

        d.frame:Hide()
    end

    d:Clear()
    d.serial = (d.serial or 0) + 1
    local serial = d.serial
    local graph = self:CreateConditionGroup()
    d.graph = graph
    graph:SetLayout('List')
    d.scroll:SetConditionContent(graph)
    d.chrome:SetContext(L['Import comparison'], L['Read-only'], self.pretty_name)
    local ok, why = pcall(self.RenderRotationComparison, self, graph, view, spec)

    if not ok then
        d:Clear()
        error(why, 0)
    end

    p.cleanups[#p.cleanups + 1] = function()
        if d.serial == serial then
            d.frame:Hide()
        end
    end

    d.frame:Show()
    self:OpenPopup(d, p)

    if self.BindTransferHelp then
        local generation = p.generation
        local graphLease = graph.rmLease
        local evidence = self:CopySettingsData(view)

        self:BindTransferHelp(
            d,
            {
                heading = L['Import comparison'],
                brief = L["Explain this read-only incoming rotation comparison."],
                sections = {
                    {
                        title = L['Read-only'],
                        text = L["This view compares the saved or exported rotation with the current incoming preview. It does not apply changes. Close it to choose the destination and import from the transfer dialog. A changed preview, closed owner, or changed profile retires this comparison Help."],
                    },
                },
                briefs = { close = L["Close this dialog without importing its text."] },
            },
            function()
                return p.importPreview == d
                    and d.serial == serial
                    and p.generation == generation
                    and (not p.Valid or p:Valid(generation))
                    and d.graph == graph
                    and graph.rmActive
                    and graph.rmLease == graphLease
                    and addon:SettingsDataEqual(view, evidence)
            end
        )
    end

    return d
end

-- Shows the full content of an incoming rotation, read-only, in the rotation editor itself: header, specializations,
-- switch condition, steps and cooldowns, as they are shown for a Built In. The editor works on a detached copy of the
-- staged candidate (NewRotationPreviewWorkspace): nothing here can reach the candidate, the live profile or the
-- rotation in the transfer window.
-- @param p table  The transfer form that owns the popup.
-- @param preview table  The incoming rotation body to show.
-- @param spec number|string  The specialization namespace of the rotation.
-- @return table|nil  The popup; nil when the preview workspace or editor cannot be created.
-- @return string|nil  The reason when the first value is nil.
function addon:ShowNativeImportContent(p, preview, spec)
    local d = p.importContent

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent) }
        p.importContent = d
        d.frame:SetSize(940, 620)
        d.frame:SetPoint('CENTER')
        d.frame:SetClampedToScreen(true)
        d.frame:EnableMouse(true)
        self:MakeWindowOpaque(d.frame)
        d.title = d.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = self:CreateWorkbenchDialogChrome(d.frame, d.title)
        d.close = self:CreateWorkbenchIconButton(d.frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)

        self:SetUIScript(d.close, 'OnClick', function()
            d.frame:Hide()
        end)

        d.host = CreateFrame('Frame', nil, d.frame)
        d.host:SetPoint('TOPLEFT', 12, -34)
        d.host:SetSize(916, 562)

        -- Releases the read-only editor pane and closes its detached workspace; both must go together or the workspace
        -- would outlive its pane.
        function d:Clear()
            local pane, workspace = self.pane, self.workspace
            self.pane = nil
            self.workspace = nil

            if pane and pane.active then
                pane:Release()
            end
            if workspace then
                workspace:Close()
            end
        end

        self:SetUIScript(d.frame, 'OnHide', function()
            d:Clear()
        end)

        d.frame:Hide()
    end

    d:Clear()
    d.serial = (d.serial or 0) + 1
    local serial = d.serial
    local workspace, why = self:NewRotationPreviewWorkspace(spec, preview)

    if not workspace then
        return nil, why
    end

    workspace.importDisabled = preview.importDisabled == true

    local pane, problem = self:CreateRotationEditor(d.host, spec, workspace.id, nil, workspace)

    if not pane then
        workspace:Close()
        return nil, problem
    end

    d.workspace = workspace
    d.pane = pane
    d.chrome:SetContext(L['Import preview'], L['Read-only'], self.pretty_name)

    p.cleanups[#p.cleanups + 1] = function()
        if d.serial == serial then
            d.frame:Hide()
        end
    end

    d.frame:Show()
    self:OpenPopup(d, p)

    if self.BindTransferHelp then
        local generation = p.generation

        self:BindTransferHelp(
            d,
            {
                heading = L['Import preview'],
                brief = L["Explain this read-only preview of the incoming rotation."],
                sections = {
                    {
                        title = L['Read-only'],
                        text = L["This view shows the rotation as it would be imported: name, specializations, switch condition, steps and cooldowns. It is read-only and works on a copy; it saves and changes nothing. Close it to choose the destination and import from the transfer dialog. A changed text, closed transfer or changed profile retires this Help."],
                    },
                },
                briefs = { close = L["Close this dialog without importing its text."] },
            },
            function()
                return p.importContent == d
                    and d.serial == serial
                    and p.generation == generation
                    and (not p.Valid or p:Valid(generation))
                    and d.workspace == workspace
                    and not workspace.closed
                    and d.pane == pane
                    and pane.active
            end
        )
    end

    return d
end

-- ============================================================================
-- The Import/Export Rotation window
-- ============================================================================

-- Opens the Import/Export window for a rotation. The export text is the current rotation as a Rotation Master export;
-- an import is staged, previewed (a comparison when replacing, the full content for a copy) and applied through
-- ApplyRotationImport with the owner, profile and record token captured here, so a profile switch, a character change
-- or an edit of the saved rotation elsewhere invalidates the window (`valid`).
-- @param spec number|string  The specialization namespace of the rotation.
-- @param id string|table  The rotation id or reference to export.
-- @return table  The dialog.
--
-- The Import button's callback (the function passed to ShowSettingsTextTransfer) applies the staged candidate as a
-- replacement or a named copy in the chosen scope (Class or This character), then opens the Rotations page on the
-- result.
function addon:ShowRotationTransfer(spec, id)
    local codec = self:NewRotationCodec()
    local source, exportError = self:GetRotationExportData(spec, id)
    local exported

    if source then
        exported, exportError = codec:Encode(source)
    end

    local session = self.RotationData.NewImportSession(codec, self:GetImportValidationOptions())
    local p = self.rotationTransferForm

    if p then
        p:Release()
    else
        local host = CreateFrame('Frame', nil, UIParent)
        host:SetSize(1, 1)
        host:Hide()
        p = self:CreateSettingsForm(host)
        self.rotationTransferForm = p
    end

    p:Open(function() end)
    local reference = self:ResolveRotationReference(spec, id)
    local record, recordToken

    if reference then
        record, recordToken = self:GetRotationRecordSnapshot(spec, reference)
    end

    -- A snapshot that failed answers (nil, reason): the reason is a string, not a token. A selection with no saved
    -- record (a new rotation not applied yet, a Default never saved) has nothing to replace.
    if type(record) ~= 'table' or type(recordToken) ~= 'table' then
        recordToken = nil
    end

    local original = record and record.body
    local profile = self.db.profile
    local coordinator = self:GetScopedRotationCoordinator()
    local context = self:GetRotationOwnerContext()
    local expected = { profile = profile, reference = reference, recordToken = recordToken }
    local candidate, dialog
    local active = true
    local generation = p.generation

    -- Tells whether the window still belongs to the state it opened for: same form drawing, profile and scoped
    -- coordinator, same owner (class and character), and the replaced record's token is still current.
    -- @return boolean  True while the window's callbacks may act.
    local function valid()
        if
            not active
            or not p:Valid(generation)
            or addon.db.profile ~= profile
            or addon:GetScopedRotationCoordinator() ~= coordinator
            or not coordinator
            or not coordinator:CheckReady()
        then
            return false
        end

        local now = addon:GetRotationOwnerContext()

        if not now or not context or now.class ~= context.class or now.character ~= context.character then
            return false
        end

        return not recordToken or coordinator:TokenCurrent(recordToken)
    end

    -- Which selections an import can replace: a saved custom rotation, the saved Default included (it is a custom
    -- record and Apply replaces it in place). Never a Built In, a new rotation not yet applied, or a Default that was
    -- never saved. canReplace is the one answer; the dialog's mode starts from it and everything below reads the mode.
    local canReplace = reference ~= nil and reference.kind == 'custom' and record ~= nil and recordToken ~= nil

    local options = {
        valid = valid,
        canReplace = canReplace,
        selectedName = original and original.name or source and self:RotationDisplayName(source),
        fallbackName = L['Imported rotation'],
        requirePreview = true,
        help = {
            heading = L['Import/Export Rotation'],
            brief = L["Explain rotation preview, destination, and import scope."],
            briefs = self:TransferHelpBriefs(),
            sections = {
                {
                    title = L['Import/Export'],
                    text = L["Copy the text to export the current rotation, or paste a rotation to import. Choose replacement of the selected editable rotation or a new named copy. Class and This character set the owner of a new copy; replacement keeps the original owner. The imported rotation is opened for editing after a successful import."],
                },
                {
                    title = L['Preview import'],
                    text = L["With Replace selected entry ticked, the button reads Compare import and shows what would change in that rotation. For a new named copy it reads Preview import and shows everything the import contains, read-only, as the rotation editor shows it. Neither saves anything. Import is enabled for a staged preview or comparison; changing the text requires another one. Pressing Import lists anything that stops it. A rotation that uses conditions this client cannot use can still be imported: you are asked first, it is saved disabled, and you replace the conditions in the editor."],
                },
                {
                    title = L['Applies to'],
                    text = L['Copies belong to your Class unless This character is selected. Replacement keeps its original owner.'],
                },
            },
        },
    }

    -- Returns the name of the rotation inside pasted text, used to suggest a name for the copy.
    -- @param text string  The pasted text.
    -- @return string|nil  The name; nil when the text does not decode.
    options.originalName = function(text)
        local decoded = codec:Decode(text)
        local value = decoded and decoded.value

        if type(value) == 'table' then
            return self:RotationDisplayName(value)
        end
    end

    -- Handles the pasted text changing: drops the staged candidate, disables Apply and Inspect and closes both
    -- previews, so what is applied is always what was previewed.
    -- @param d table  The transfer dialog.
    options.invalidate = function(d)
        if not valid() or dialog and (d ~= dialog or d.options ~= options) then
            return
        end

        candidate = nil
        session:Clear()
        d.apply:Disable()
        d.inspect:Disable()

        d.status:SetText(
            d.mode == 'replace' and L['Text changed. Compare again before importing.']
                or L['Text changed. Preview again before importing.']
        )

        if p.importPreview then
            p.importPreview.frame:Hide()
        end
        if p.importContent then
            p.importContent.frame:Hide()
        end
    end

    -- Names one validation diagnostic in words: where it is in the rotation and what is wrong.
    -- @param issue table  The diagnostic.
    -- @param body table  The staged rotation body, used to name the step.
    -- @return string  The text.
    local function describe(issue, body)
        local text = self.DescribeRotationIssue and self:DescribeRotationIssue(issue, body)

        return text or string.format(L['has a problem (%s)'], tostring(issue.code))
    end

    -- Splits the staged candidate's diagnostics into what stops the import and the conditions that are kept but cannot
    -- work on this client.
    -- @return string[]  The problems, in words.
    -- @return string[]  The unusable conditions, in words.
    local function issueLists()
        local body = candidate.kind == 'envelope' and candidate.value.body or candidate.value
        local conditions = self.RotationData.UnresolvedConditionIssues(candidate.validation)
        local kept, problems, warnings = {}, {}, {}

        for _, issue in ipairs(conditions) do
            kept[issue.code .. '|' .. tostring(issue.path)] = true
            warnings[#warnings + 1] = describe(issue, body)
        end

        for _, issue in ipairs(candidate.validation.diagnostics) do
            if not kept[issue.code .. '|' .. tostring(issue.path)] then
                problems[#problems + 1] = describe(issue, body)
            end
        end

        return problems, warnings
    end

    -- Shows the Import prompt: a heading and the issues found, with Import anyway when the import can still go ahead,
    -- and Cancel (Close when nothing can be imported).
    -- @param d table  The transfer dialog.
    -- @param heading string  The text above the list.
    -- @param items string[]  The issues, in words.
    -- @param confirm function|nil  Called on Import anyway; nil when the import cannot go ahead.
    local function showImportNotice(d, heading, items, confirm)
        local prompt = p.importNotice

        if not prompt then
            prompt = { frame = CreateFrame('Frame', nil, d.frame) }
            p.importNotice = prompt
            prompt.frame:SetSize(560, 200)
            prompt.frame:SetPoint('CENTER')
            prompt.frame:SetClampedToScreen(true)
            prompt.frame:EnableMouse(true)
            self:MakeWindowOpaque(prompt.frame)
            prompt.title = prompt.frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
            prompt.chrome = self:CreateWorkbenchDialogChrome(prompt.frame, prompt.title)
            prompt.close = self:CreateWorkbenchIconButton(prompt.frame, 'close', L['Close'])
            prompt.close:SetPoint('TOPRIGHT', -5, -5)
            prompt.text = prompt.frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
            prompt.text:SetPoint('TOPLEFT', 16, -44)
            prompt.text:SetJustifyH('LEFT')
            prompt.text:SetJustifyV('TOP')
            prompt.text:SetWordWrap(true)
            prompt.accept = self:CreateWorkbenchButton(prompt.frame, L['Import anyway'], 130)
            prompt.cancel = self:CreateWorkbenchButton(prompt.frame, L['Cancel'], 100)
            prompt.cancel:SetPoint('BOTTOMRIGHT', -16, 30)
            prompt.accept:SetPoint('RIGHT', prompt.cancel, 'LEFT', -8, 0)

            self:SetUIScript(prompt.cancel, 'OnClick', function()
                prompt.frame:Hide()
            end)

            self:SetUIScript(prompt.close, 'OnClick', function()
                prompt.frame:Hide()
            end)

            prompt.frame:Hide()
        end

        local body = candidate.kind == 'envelope' and candidate.value.body or candidate.value

        prompt.chrome:SetContext(
            L['Import'],
            confirm and L['Warning'] or L['Problems'],
            type(body) == 'table' and body.name or nil
        )

        local lines = { heading, '' }

        for index, text in ipairs(items) do
            if index > 12 then
                lines[#lines + 1] = string.format(L['... and %d more'], #items - 12)
                break
            end

            lines[#lines + 1] = '- ' .. text
        end

        prompt.text:SetWidth(528)
        prompt.text:SetText(table.concat(lines, '\n'))
        local height = prompt.text.GetStringHeight and prompt.text:GetStringHeight() or 16 * #lines
        prompt.text:SetHeight(height)
        prompt.frame:SetHeight(math.max(150, math.ceil(height) + 112))
        prompt.cancel:SetText(confirm and L['Cancel'] or L['Close'])

        if confirm then
            prompt.accept:Show()

            self:SetUIScript(prompt.accept, 'OnClick', function()
                prompt.frame:Hide()

                if valid() then
                    confirm()
                end
            end)
        else
            prompt.accept:Hide()
        end

        prompt.frame:Show()
        self:OpenPopup(prompt, p)
    end

    -- Stages the pasted text and opens the matching preview: a comparison when replacing, the full content for a copy.
    -- Apply is enabled only when the session reports the candidate ready.
    -- @param d table  The transfer dialog.
    options.preview = function(d)
        if not valid() then
            return
        end

        local why
        candidate, why = session:Stage(d.input:GetText())
        d.apply:Disable()
        d.inspect:Disable()

        if not candidate then
            d.status:SetText(string.format(L['Import preview unavailable: %s'], tostring(why)))
            return
        end

        local ready, reason = session:GetReady(candidate.token)
        local unresolved = ready and #ready.unresolved or 0
        local problems = ready and {} or issueLists()

        d.status:SetText(
            ready
                and (unresolved > 0 and string.format(
                    L['Ready to import, with a warning: %d condition(s) cannot work on this client. They are kept as imported and the rotation is saved disabled. Replace them in the editor to use it.'],
                    unresolved
                )
                    or L['Ready to import. Choose replacement or a named copy.'])
                or string.format(L['This import cannot be applied: %s'], problems[1] or tostring(reason))
        )

        -- Import is always pressable once something is staged: pressing it says what is wrong when it cannot go ahead.
        d.apply:Enable()

        if p.importPreview then
            p.importPreview.frame:Hide()
        end
        if p.importContent then
            p.importContent.frame:Hide()
        end

        if d.mode == 'replace' and canReplace then
            -- Replacing: what would change in the selected rotation.
            local own = original or source and (source.body or source) or { rotation = {}, cooldowns = {} }
            local view = session:Compare(candidate.token, own, self.RotationData.GetRotationTags(source))

            if view then
                self:ShowNativeImportPreview(p, view, spec)
            end
        else
            -- A new copy: nothing to compare with, so everything that would be created.
            local incoming, missing = session:Preview(candidate.token)
            local shown, problem

            if incoming then
                incoming.importDisabled = unresolved > 0
                local ok, result, reason = pcall(self.ShowNativeImportContent, self, p, incoming, spec)

                if ok then
                    shown, problem = result, reason
                else
                    problem = result
                end
            else
                problem = missing
            end

            if not shown and valid() then
                d.status:SetText(
                    (d.status:GetText() or '') .. '\n' .. string.format(
                        L['This import cannot be shown in full (%s).'],
                        tostring(problem)
                    )
                )
            end
        end
    end

    -- Handles the window closing: marks it inactive and releases the import session and the form.
    options.onClose = function()
        active = false
        session:Clear()

        if p.active and p.generation == generation then
            p:Release()
        end
    end

    dialog = self:ShowSettingsTextTransfer(
        p,
        L['Import/Export Rotation'],
        exported or '',
        function(_, settings)
            if not candidate then
                return false, L['Preview a pasted rotation before importing it.']
            end

            local target = settings.mode == 'replace' and reference or nil

            local generated, why, saved = self:ApplyRotationImport(
                session,
                candidate.token,
                spec,
                settings.name,
                target,
                expected,
                {
                    scope = dialog.scope:GetChecked() and 'character' or 'class',
                    specs = type(self.rotationListSpec) == 'number' and self.rotationListSpec or nil,
                }
            )

            if not generated then
                return false, string.format(L['Could not import this rotation: %s'], why)
            end

            local workspace, problem = self:GetRotationEditWorkspace(spec, saved)

            if not workspace then
                return false, problem
            end

            self:ShowConfig('Rotations', { spec = spec, id = workspace.id })
            return true
        end,
        options
    )

    if not dialog.scope then
        dialog.classScope = self:CreateWorkbenchCheckBox(dialog.frame, L['Class'], 210)
        dialog.classScope:SetPoint('TOPLEFT', 12, -98)
        dialog.scope = self:CreateWorkbenchCheckBox(dialog.frame, L['This character'], 268)
        dialog.scope:SetPoint('TOPLEFT', 290, -98)
    end

    dialog.scope:SetChecked(false)
    dialog.scope:Show()
    dialog.classScope:Show()

    -- Syncs the Class and This character boxes with the mode: a replacement keeps its owner's scope (both boxes
    -- locked), a copy chooses one, and This character is unavailable when there is no current character.
    local function scopeState()
        if dialog.mode == 'replace' then
            dialog.scope:SetChecked(reference and reference.address and reference.address.scope == 'character')
            dialog.scope:Disable()
        elseif context and context.character then
            dialog.scope:Enable()
        else
            dialog.scope:SetChecked(false)
            dialog.scope:Disable()
        end

        dialog.classScope:SetChecked(not dialog.scope:GetChecked())

        if dialog.mode == 'new' then
            dialog.classScope:Enable()
        else
            dialog.classScope:Disable()
        end
    end

    local destination = dialog.destination:GetScript('OnClick')

    -- Runs the dialog's own destination toggle (replace or new copy), then resets the scope boxes to match, closes any
    -- open preview and syncs the Class and This character boxes.
    -- @param ... any  The click arguments, passed on to the original handler.
    self:SetUIScript(dialog.destination, 'OnClick', function(...)
        if dialog.options == options then
            destination(...)

            if not valid() then
                return
            end

            if dialog.mode == 'new' then
                dialog.scope:SetChecked(false)
            end

            scopeState()

            if p.importPreview then
                p.importPreview.frame:Hide()
            end
            if p.importContent then
                p.importContent.frame:Hide()
            end
        end
    end)

    self:SetUIScript(dialog.scope, 'OnClick', function()
        if valid() and dialog.options == options and dialog.mode == 'new' and context.character then
            dialog.scope:SetChecked(true)
            scopeState()
        end
    end)

    self:SetUIScript(dialog.classScope, 'OnClick', function()
        if valid() and dialog.options == options and dialog.mode == 'new' then
            dialog.scope:SetChecked(false)
            scopeState()
        end
    end)

    local importClick = dialog.apply:GetScript('OnClick')

    -- Pressing Import first says what is wrong. An import that cannot go ahead lists why; one with conditions this
    -- client cannot use asks whether to import it anyway (it is saved disabled); a clean one imports at once.
    -- @param ... any  The click arguments, passed on to the original handler.
    self:SetUIScript(dialog.apply, 'OnClick', function(...)
        if dialog.options ~= options or not valid() or not candidate then
            return importClick(...)
        end

        local ready, reason = session:GetReady(candidate.token)
        local problems, warnings = issueLists()
        local args = { ... }

        if not ready then
            showImportNotice(
                dialog,
                L['This rotation cannot be imported:'],
                #problems > 0 and problems or { tostring(reason) }
            )
        elseif #warnings > 0 then
            showImportNotice(
                dialog,
                L['These conditions cannot work on this client. They are kept as imported and the rotation is imported disabled. Replace them in the editor before enabling it:'],
                warnings,
                function()
                    importClick(unpack(args))
                end
            )
        else
            return importClick(...)
        end
    end)

    dialog.scope.tooltip = L['Copies belong to your Class unless This character is selected. Replacement keeps its original owner.']
    dialog.scroll:ClearAllPoints()
    dialog.scroll:SetPoint('TOPLEFT', 12, -130)
    dialog.scroll:SetHeight(200)
    dialog.input:SetHeight(200)
    scopeState()

    if exportError then
        dialog.status:SetText(string.format(L['Export unavailable: %s'], exportError))
    end

    return dialog
end
