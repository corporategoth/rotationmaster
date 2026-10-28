-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Rotation metadata window opened from the rotation editor: description, tags, scope (class or this character) and the
-- author, realm, email, website and version fields, plus a read-only list of source citations. It edits the pane's
-- draft through pane fields (metadataDraft, tagsDirty, scopeDraft, ...) and never saves; Apply writes into the draft
-- and the rotation Apply saves it. Cancel or Escape restores the values the window opened with. Loaded from
-- RotationMaster.toc after UI/rotation_navigation.lua; UI/rotation_editor.lua calls
-- addon:InstallRotationMetadata(pane).
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data = addon.RotationData

-- Order, key and caption of the plain text attribution fields; the key is the field name in the saved metadata table.
local definitions = {
    { 'author', 'Author' },
    { 'realm', 'Realm' },
    { 'email', 'Email' },
    { 'website', 'Website' },
    { 'version', 'Version' },
}

-- Creates a wrapped, left-aligned caption at the given y inside parent.
local function label(parent, value, y)
    local text = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    text:SetPoint('TOPLEFT', 8, -y)
    text:SetWidth(460)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(true)
    text:SetText(value)
    return text
end

-- Builds the window once for pane and stores it as pane.metadataWindow. The pane's description edit box and tags field
-- are re-parented into this window, so the pane keeps one set of controls and the window only decides where they show.
-- The dialog table follows the window interface (Valid, Open, Close, Hide) that addon:OpenPopup and HideOnEscape use.
function addon:InstallRotationMetadata(pane)
    local dialog = { fields = {}, labels = {} }
    local frame = CreateFrame('Frame', nil, UIParent)
    dialog.frame = frame
    frame:SetSize(530, 540)
    frame:SetPoint('CENTER')
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    addon:MakeWindowOpaque(frame)
    dialog.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    dialog.chrome = addon:CreateWorkbenchDialogChrome(frame, dialog.title)
    local drag = CreateFrame('Frame', nil, frame)
    drag:SetPoint('TOPLEFT', 8, -1)
    drag:SetPoint('TOPRIGHT', -150, -1)
    drag:SetHeight(28)
    drag:EnableMouse(true)
    drag:RegisterForDrag('LeftButton')

    addon:SetUIScript(drag, 'OnDragStart', function()
        frame:StartMoving()
    end)

    addon:SetUIScript(drag, 'OnDragStop', function()
        frame:StopMovingOrSizing()
    end)

    frame:SetMovable(true)
    local scroll = addon:CreateWorkbenchScrollFrame(frame)
    scroll:SetPoint('TOPLEFT', 12, -40)
    scroll:SetSize(484, 296)
    dialog.scroll = scroll
    local child = CreateFrame('Frame', nil, scroll)
    child:SetSize(476, 296)
    scroll:SetScrollChild(child)
    pane.descriptionLabel:SetParent(child)
    pane.descriptionLabel:ClearAllPoints()
    pane.descriptionLabel:SetPoint('TOPLEFT', 8, 0)
    local area = CreateFrame('Frame', nil, child)
    area:SetPoint('TOPLEFT', 8, -20)
    area:SetSize(460, 108)
    dialog.descriptionArea = area
    local background = area:CreateTexture(nil, 'BACKGROUND')
    background:SetAllPoints(area)
    background:SetColorTexture(.08, .09, .10, .95)
    local line = area:CreateTexture(nil, 'BORDER')
    line:SetPoint('BOTTOMLEFT')
    line:SetPoint('BOTTOMRIGHT')
    line:SetHeight(1)
    line:SetColorTexture(.38, .43, .48, .8)
    local descriptionScroll = addon:CreateWorkbenchScrollFrame(area)
    descriptionScroll:SetPoint('TOPLEFT', 4, -4)
    descriptionScroll:SetSize(436, 100)
    dialog.descriptionScroll = descriptionScroll
    pane.description:SetParent(descriptionScroll)
    pane.description:ClearAllPoints()
    pane.description:SetPoint('TOPLEFT', 0, 0)
    pane.description:SetWidth(436)
    pane.description:SetHeight(100)
    pane.description:SetTextInsets(4, 4, 4, 4)
    descriptionScroll:SetScrollChild(pane.description)
    dialog.fields.description = pane.description

    addon:SetUIScript(pane.description, 'OnSizeChanged', function()
        descriptionScroll:UpdateWorkbenchScroll()
    end)

    addon:SetUIScript(pane.description, 'OnCursorChanged', function(_, _, y, _, height)
        if not dialog:Valid() then
            return
        end

        descriptionScroll:UpdateWorkbenchScroll()
        local bar = descriptionScroll.workbenchBar
        local offset = bar:GetValue()
        local top = -y

        if top < offset then
            bar:SetValue(top)
        elseif top + height > offset + descriptionScroll:GetHeight() then
            bar:SetValue(top + height - descriptionScroll:GetHeight())
        end
    end)

    pane.description:EnableMouseWheel(true)

    addon:SetUIScript(pane.description, 'OnMouseWheel', function(_, delta)
        local bar = descriptionScroll.workbenchBar
        bar:SetValue(bar:GetValue() - delta * 40)
    end)

    -- Right-click anywhere in the window cancels it; a left click on the description area focuses the editable box.
    local function bodyMouseUp(_, button)
        if not dialog:Valid() then
            return
        end

        if button == 'RightButton' then
            dialog:Close(false)
        elseif button == 'LeftButton' and not pane.workspace.readOnly then
            pane.description:SetFocus()
        end
    end

    descriptionScroll:EnableMouse(true)
    addon:SetUIScript(descriptionScroll, 'OnMouseUp', bodyMouseUp)

    addon:SetUIScript(pane.description, 'OnMouseUp', function(control, button)
        if button == 'RightButton' then
            bodyMouseUp(control, button)
        end
    end)

    dialog.labels.tags = label(child, L['Tags'], 140)
    dialog.labels.tags:SetWidth(96)
    dialog.labels.tags:SetHeight(24)
    dialog.labels.tags:SetJustifyV('MIDDLE')
    pane.tags = addon:CreateWorkbenchEditBox(child)
    dialog.fields.tags = pane.tags
    pane.tags:SetSize(352, 24)
    pane.tags:SetPoint('TOPLEFT', 116, -140)
    pane.tags:SetMaxLetters(32768)
    pane.tags:Hide()

    dialog.tagPicker = addon:CreateRotationTagPicker(child, {
        allowCustom = true,
        available = function() return addon:GetAllRotationTags(pane.workspace.spec) end,
        valid = function() return dialog:Valid() end,
        changed = function(tags)
            if not pane.workspace.readOnly then
                pane.tags:SetText(data.FormatRotationTags(tags))
                pane.tagsDirty = true
                pane:UpdateHistory()
            end
        end,
        color = function(tag) return addon:GetRotationTagColor(tag) end,
        setColor = function(tag, color)
            addon:SetRotationTagColor(tag, color)
        end,
        layout = function()
            if dialog.source then
                dialog:Layout(dialog.sourceText or '')
            end
        end,
    })

    dialog.tagPicker.frame:SetPoint('TOPLEFT', 116, -140)
    dialog.tagPicker:SetWidth(352)
    dialog.labels.scope = label(child, L['Applies to'], 140)
    dialog.labels.scope:SetWidth(96)
    dialog.labels.scope:SetHeight(24)
    dialog.labels.scope:SetJustifyV('MIDDLE')
    dialog.scope = addon:CreateWorkbenchLabeledIconButton(child, 'chevron-down', '', 352)
    dialog.scope:SetPoint('TOPLEFT', 116, -140)
    dialog.scopeMenu = addon:CreateWorkbenchSelector()

    -- True when the rotation can be re-scoped: it is editable and its workspace can name its stored target.
    function dialog:HasOwnership()
        return not pane.workspace.readOnly and type(pane.workspace.TargetReference) == 'function'
    end

    -- Shows the pane's effective scope on the scope button.
    function dialog:PaintScope()
        self.scope:SetText(pane:EffectiveScope() == 'character' and L['This character'] or L['Class'])
    end

    -- Switch priority is not metadata: it sits beside the Enabled pill in the
    -- rotation editor's header (UI/rotation_editor.lua), with the switch.
    for index, entry in ipairs(definitions) do
        local key = entry[1]
        local y = 200 + (index - 1) * 30
        dialog.labels[key] = label(child, L[entry[2]], y)
        dialog.labels[key]:SetWidth(96)
        dialog.labels[key]:SetHeight(24)
        dialog.labels[key]:SetJustifyV('MIDDLE')
        local input = addon:CreateWorkbenchEditBox(child)
        dialog.fields[key] = input
        input:SetSize(352, 24)
        input:SetPoint('TOPLEFT', 116, -y)
        input:SetMaxLetters(512)

        addon:SetUIScript(input, 'OnMouseUp', function(control, button)
            if button == 'RightButton' then
                bodyMouseUp(control, button)
            end
        end)
    end

    dialog.sourceHeading = label(child, L['Sources'], 356)
    dialog.source = label(child, '', 376)
    dialog.source:Hide()
    dialog.sourceHeading:Hide()
    dialog.note = label(frame, L['Apply updates the draft. Apply the rotation to save it.'], 348)
    dialog.note:SetWidth(506)
    dialog.apply = addon:CreateWorkbenchButton(frame, L['Apply'], 112)
    dialog.apply:SetPoint('BOTTOMRIGHT', -136, 28)
    dialog.cancel = addon:CreateWorkbenchButton(frame, L['Cancel'], 112)
    dialog.cancel:SetPoint('BOTTOMRIGHT', -16, 28)
    dialog.close = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
    dialog.close:SetPoint('TOPRIGHT', -5, -5)
    dialog.help = addon:CreateWorkbenchHelpButton(frame, L['Help'])
    dialog.help:SetPoint('TOPRIGHT', -31, -5)
    dialog.help:SetSize(20, 20)
    dialog.help.icon:SetSize(16, 16)

    addon:SetUIScript(dialog.help, 'OnClick', function()
        if dialog:Valid() and addon.ShowWorkbenchHelp then
            addon:ShowWorkbenchHelp(
                L['Rotation metadata'],
                {
                    {
                        title = L['Description and attribution'],
                        text = L['Edit the description, tags, author, realm, email, website and version. Source citations remain separate from your attribution. Apply updates the rotation draft; Apply the rotation to save it. Cancel or Escape restores this dialog’s opening values.'],
                    },
                    {
                        title = L['Applies to'],
                        text = L['Class rotations are shared by characters of the same class in this settings profile. This character limits the rotation to your current character. Applying a scope change moves the complete saved rotation; an existing destination is never overwritten.'],
                    },
                },
                pane:RotationDisplayName()
            )
        end
    end)

    pane.tags.tooltip = L['Separate tags with commas. Use quotes for tags containing commas. Any personal label is allowed.']

    addon:SetUIScript(frame, 'OnMouseUp', function(control, button)
        if button == 'RightButton' then
            bodyMouseUp(control, button)
        end
    end)

    addon:SetUIScript(scroll, 'OnMouseUp', function(control, button)
        if button == 'RightButton' then
            bodyMouseUp(control, button)
        end
    end)

    scroll:EnableMouse(true)

    -- Positions every row for the current state (the scope row exists only with ownership; the tag chips change
    -- height), shows or hides the source list for sourceText and resizes the scroll area and window to fit.
    function dialog:Layout(sourceText)
        self.sourceText = sourceText
        local tagsY = self:HasOwnership() and 170 or 140
        local metadataY = tagsY + (self.tagPicker.height or 24) + 6
        local sourceY = metadataY + #definitions * 30 + 6

        -- Anchors control at (x, y) below the top-left of the scroll content.
        local function place(control, x, y)
            control:ClearAllPoints()
            control:SetPoint('TOPLEFT', x, -y)
        end

        if self:HasOwnership() then
            self.labels.scope:Show()
            self.scope:Show()
            self.fields.scope = self.scope
        else
            self.labels.scope:Hide()
            self.scope:Hide()
            self.fields.scope = nil
        end

        place(self.labels.tags, 8, tagsY)
        place(pane.tags, 116, tagsY)
        place(self.tagPicker.frame, 116, tagsY)

        for i, entry in ipairs(definitions) do
            place(self.labels[entry[1]], 8, metadataY + (i - 1) * 30)
            place(self.fields[entry[1]], 116, metadataY + (i - 1) * 30)
        end

        place(self.sourceHeading, 8, sourceY)
        place(self.source, 8, sourceY + 20)
        local contentHeight = sourceY

        if sourceText ~= '' then
            self.source:SetText(sourceText)
            self.source:SetHeight(0)
            self.source:SetHeight(self.source:GetStringHeight())
            self.source:Show()
            self.sourceHeading:Show()
            contentHeight = sourceY + 20 + self.source:GetHeight() + 12
        else
            self.source:SetText('')
            self.source:Hide()
            self.sourceHeading:Hide()
        end

        child:SetHeight(contentHeight)
        local visible = math.min(contentHeight, 380)
        scroll:SetHeight(visible)
        self.note:SetHeight(0)
        local noteHeight = math.max(14, self.note:GetStringHeight())
        self.note:SetHeight(noteHeight)
        self.note:ClearAllPoints()
        self.note:SetPoint('TOPLEFT', 12, -40 - visible - 8)
        frame:SetHeight(40 + visible + 8 + noteHeight + 8 + 24 + 8 + 20)
        self.chrome:LayoutTitle()
        scroll:UpdateWorkbenchScroll()
        descriptionScroll:UpdateWorkbenchScroll()
    end

    -- True only while the window is open for the pane's current workspace and generation; every callback checks it.
    function dialog:Valid()
        return pane.active
            and self.workspace == pane.workspace
            and self.generation == pane.generation
            and frame:IsShown()
    end

    -- Loads the workspace's current metadata, description, tags and scope into the controls, leaving fields the player
    -- has already edited alone. While open and clean it also refreshes the values Cancel restores.
    function dialog:Sync()
        local snapshot = pane.workspace:Snapshot()
        local metadata = type(snapshot.metadata) == 'table' and snapshot.metadata or {}
        pane.metadataDraft = data.CopyData(metadata)

        if not pane.descriptionDirty then
            pane.description:SetText(
                snapshot.description or (pane.workspace.readOnly and pane.workspace.description or '')
            )
        end

        if not pane.tagsDirty then
            pane.tags:SetText(data.FormatRotationTags(pane:EffectiveTags(snapshot)) or '')
            pane.tags:SetTextColor(1, 1, 1)
        end

        self.tagPicker:SetTags(data.ParseRotationTags(pane.tags:GetText()) or {})

        if not pane.scopeDirty then
            pane.scopeDraft = pane.workspace.scope
        end

        self:PaintScope()

        if
            self.opened
            and not pane.descriptionDirty
            and not pane.metadataDirty
            and not pane.tagsDirty
            and not pane.scopeDirty
        then
            self.startMetadata = data.CopyData(metadata)
            self.startMetadataDirty = false
            self.startDescription = pane.description:GetText()
            self.startDescriptionDirty = false
            self.startTags = pane.tags:GetText()
            self.startTagsDirty = false
            self.startScope = pane.scopeDraft
            self.startScopeDirty = false
        end

        for _, entry in ipairs(definitions) do
            self.fields[entry[1]]:SetText(type(metadata[entry[1]]) == 'string' and metadata[entry[1]] or '')
        end
    end

    -- Puts the draft back to the values captured when the window opened (Cancel, Escape, or hiding without Apply).
    function dialog:Restore()
        if not pane.active or self.workspace ~= pane.workspace or self.generation ~= pane.generation then
            return
        end

        pane.metadataDraft = data.CopyData(self.startMetadata)
        pane.metadataDirty = self.startMetadataDirty
        pane.description:SetText(self.startDescription)
        pane.descriptionDirty = self.startDescriptionDirty
        pane.tags:SetText(self.startTags or '')
        pane.tagsDirty = self.startTagsDirty
        pane:UpdateHistory()
        self.tagPicker:SetTags(data.ParseRotationTags(pane.tags:GetText()) or {})
        pane:Message('')
        pane:UpdateHistory()
        pane.scopeDraft = self.startScope
        pane.scopeDirty = self.startScopeDirty
        self:PaintScope()
        pane:UpdateHistory()
    end

    -- Hides the window. keep true keeps the edits (Apply); otherwise the opening values are restored first.
    function dialog:Close(keep)
        if not keep then
            self:Restore()
        end

        self.scopeMenu:Hide()
        self.closing = true
        frame:Hide()
        self.closing = false
        self.opened = false
    end

    -- Opens the window for the pane's current rotation: captures the restore point, builds the source citation list,
    -- sets the note and read-only state, and rebinds every control script to this open's token so stale callbacks do
    -- nothing.
    function dialog:Open()
        if self:Valid() then
            addon:OpenPopup(self, pane)
            return
        end

        self.openToken = (self.openToken or 0) + 1
        self.workspace = pane.workspace
        self.generation = pane.generation

        if not pane.metadataDirty and not pane.tagsDirty and not pane.scopeDirty then
            self:Sync()
        end

        self.startMetadata = data.CopyData(pane.metadataDraft)
        self.startMetadataDirty = pane.metadataDirty
        self.startDescription = pane.description:GetText()
        self.startDescriptionDirty = pane.descriptionDirty
        self.startTags = pane.tags:GetText()
        self.startTagsDirty = pane.tagsDirty
        self.startScope = pane.scopeDraft
        self.startScopeDirty = pane.scopeDirty
        self:PaintScope()
        local readOnly = pane.workspace.readOnly
        local lines = {}
        local source = pane.workspace.source
        local seen = {}

        -- Collects unique citation entries (title and URL) from a manifest into lines. Spell and item database links
        -- are left out; they are references to game data, not sources of the rotation.
        local function sources(manifest)
            if type(manifest) ~= 'table' then
                return
            end

            if type(manifest.sources) == 'table' then
                for _, entry in ipairs(manifest.sources) do
                    if
                        type(entry) == 'table'
                        and type(entry.url) == 'string'
                        and not seen[entry.url]
                        and not entry.url:lower():find('/spell/', 1, true)
                        and not entry.url:lower():find('spell=', 1, true)
                        and not entry.url:lower():find('spell%3d', 1, true)
                        and not entry.url:lower():find('/item/', 1, true)
                        and not entry.url:lower():find('item=', 1, true)
                    then
                        seen[entry.url] = true

                        lines[#lines + 1] = (type(entry.title) == 'string' and entry.title or L['Source'])
                            .. '\n'
                            .. entry.url
                    end
                end
            end
        end

        if source then
            sources(source.envelope)
        end

        local reserved = pane.workspace.reserved or {}

        for _, kind in ipairs({ 'origins', 'imports', 'comparisons' }) do
            local entry = reserved[kind]

            if type(entry) == 'table' then
                sources(entry.manifest)
            end
        end

        self.note:SetText(
            readOnly
                and (pane.workspace.preview
                    and L['Import preview: the metadata is shown as imported and cannot be edited here.']
                    or L['Built In rotation: duplicate it to edit its metadata.'])
                or L['Apply updates the draft. Apply the rotation to save it.']
        )

        if type(pane.workspace:Snapshot().metadata) ~= 'table' and pane.workspace:Snapshot().metadata ~= nil then
            self.note:SetText(string.format(
                L['Saved metadata is invalid (%s). Editing these fields replaces it.'],
                tostring(pane.workspace:Snapshot().metadata)
            ))
        end

        self.chrome:SetContext(pane:RotationDisplayName(), L['Metadata'], pane:RotationDisplayName())
        self:Layout(table.concat(lines, '\n\n'))
        scroll.workbenchBar:SetValue(0)
        descriptionScroll.workbenchBar:SetValue(0)

        for _, input in pairs(self.fields) do
            input:EnableMouse(not readOnly)
        end

        self.tagPicker.options.readOnly = readOnly
        self.tagPicker.input:EnableMouse(not readOnly)
        self.tagPicker:SetTags(data.ParseRotationTags(pane.tags:GetText()) or {})

        if readOnly then
            self.apply:Disable()
        else
            self.apply:Enable()
        end

        local token = self.openToken
        local owner = self.workspace

        -- True only for this open of the window and this workspace; a reopen or workspace switch retires older
        -- callbacks.
        local function valid()
            return self:Valid() and token == self.openToken and owner == self.workspace
        end

        addon:SetUIScript(self.scope, 'OnClick', function()
            if not valid() or not self:HasOwnership() then
                return
            end

            local entries = {
                { value = 'class', text = L['Class'] },
                { value = 'character', text = L['This character'] },
            }

            self.scopeMenu:Open(
                self.scope,
                entries,
                pane:EffectiveScope(),
                function(value)
                    if valid() and (value == 'class' or value == 'character') then
                        pane.scopeDraft = value
                        pane.scopeDirty = value ~= pane.workspace.scope
                        self:PaintScope()
                        pane:UpdateHistory()
                    end
                end,
                valid
            )
        end)

        for _, entry in ipairs(definitions) do
            local key = entry[1]
            local input = self.fields[key]

            addon:SetUIScript(input, 'OnTextChanged', function(_, userInput)
                if not valid() or readOnly or not userInput then
                    return
                end

                pane.metadataDraft = pane.metadataDraft or {}
                pane.metadataDraft[key] = input:GetText() ~= '' and input:GetText() or nil
                pane.metadataDirty = true
                pane:UpdateHistory()
            end)

            addon:SetUIScript(
                input,
                'OnEditFocusGained',
                readOnly and function(control)
                    control:ClearFocus()
                end or nil
            )
        end

        addon:SetUIScript(pane.tags, 'OnTextChanged', function(_, user)
            if valid() and not readOnly and user then
                pane.tagsDirty = true
                local ok = data.ParseRotationTags(pane.tags:GetText())
                pane.tags:SetTextColor(1, ok and 1 or .35, ok and 1 or .35)
                pane:UpdateHistory()
            end
        end)

        addon:SetUIScript(pane.tags, 'OnEnter', function()
            if valid() and GameTooltip then
                GameTooltip:SetOwner(pane.tags, 'ANCHOR_RIGHT')
                GameTooltip:SetText(pane.tags.tooltip, 1, 1, 1, 1, true)
            end
        end)

        addon:SetUIScript(pane.tags, 'OnLeave', function()
            if GameTooltip and GameTooltip:IsOwned(pane.tags) then
                GameTooltip:Hide()
            end
        end)

        addon:SetUIScript(
            pane.tags,
            'OnEditFocusGained',
            readOnly and function(control)
                control:ClearFocus()
            end or nil
        )

        addon:SetUIScript(pane.tags, 'OnMouseUp', function(_, button)
            if button == 'RightButton' then
                bodyMouseUp(nil, button)
            end
        end)

        addon:SetUIScript(self.apply, 'OnClick', function()
            if not valid() or readOnly then
                return
            end

            if pane:FlushName() then
                self:Close(true)
                pane:Render()
            end
        end)

        -- Cancel and Close both discard the edits made since the window opened.
        local function cancel()
            if not valid() then
                return
            end

            self:Close(false)
        end

        addon:SetUIScript(self.cancel, 'OnClick', cancel)
        addon:SetUIScript(self.close, 'OnClick', cancel)
        self.opened = true
        frame:Show()
        addon:OpenPopup(self, pane)
        scroll:UpdateWorkbenchScroll()
        pane:UpdateHistory()
    end

    addon:SetUIScript(frame, 'OnHide', function()
        if dialog.opened and not dialog.closing then
            dialog:Restore()
        end

        dialog.opened = false
        dialog.tagPicker.menu:Hide()
        dialog.scopeMenu:Hide()

        for _, input in pairs(dialog.fields) do
            if input.ClearFocus then
                input:ClearFocus()
            end
        end
    end)

    -- Window-registry hook: hiding the window by Escape or the registry counts as Cancel.
    function dialog:Hide()
        self:Close(false)
    end

    frame:Hide()
    addon.HideOnEscape(dialog)
    pane.metadataWindow = dialog
end
