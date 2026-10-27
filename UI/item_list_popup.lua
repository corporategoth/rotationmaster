-- Popup editor for one item list (an item set or an item condition's list): a settings form of ordered item cards with
-- its own draft, undo history and Apply. The popup edits a copy and writes into the caller's table only on Apply, after
-- re-validating every item; the caller learns of the change through its update callback. Loaded from RotationMaster.toc
-- after UI/settings_form.lua, which supplies the form it embeds; the popup is a pooled condition widget.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Pool constructor for the RM-ItemListPopup widget: builds the frame and embedded settings form once, overrides the
-- form's dirty, history and review hooks to work on the popup's draft (w.draft) instead of saved settings, and returns
-- the registered widget. Per-use state is set later in OnAcquire and addon:OpenItemListPopup.
local function constructor()
    local w = { type = 'RM-ItemListPopup' }
    local frame = CreateFrame('Frame', nil, UIParent)
    w.frame = frame
    frame:Hide()
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    w.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    w.chrome = addon:CreateWorkbenchDialogChrome(frame, w.title)
    local content = CreateFrame('Frame', nil, frame)
    content:SetPoint('TOPLEFT', 10, -38)
    content:SetPoint('BOTTOMRIGHT', -10, 28)
    w.form = addon:CreateSettingsForm(content)
    local p = w.form
    w.closeButton = addon:CreateWorkbenchIconButton(frame, 'close', L['Close'])
    w.closeButton:SetPoint('TOPRIGHT', -5, -5)
    w.helpButton = addon:CreateWorkbenchHelpButton(frame, L['Help'])
    w.helpButton:SetPoint('TOPRIGHT', -31, -5)
    w.helpButton:SetSize(20, 20)
    w.helpButton.icon:SetSize(16, 16)

    -- True while the popup is active and the profile, global and character tables it was opened against are still the
    -- live ones (a profile switch invalidates it), and the caller's options.valid, if any, still passes.
    function w:Valid()
        if
            not self.rmActive
            or self:IsReleasing()
            or self.closed
            or self.profile ~= addon.db.profile
            or self.global ~= addon.db.global
            or self.char ~= addon.db.char
        then
            return false
        end

        if self.options.valid then
            local ok, value = pcall(self.options.valid)
            return ok and value and true or false
        end

        return true
    end

    local formValid = p.Valid

    -- Form validity token check, narrowed by the popup's own validity.
    function p:Valid(token)
        return formValid(self, token) and w:Valid()
    end

    -- Returns whether item resolves through the reference provider and passes the caller's isvalid test.
    function w:Accept(item)
        if not self:Valid() then return false end
        local provider = addon:GetReferenceProvider(self.editbox)
        local resolved = provider.resolve(tostring(item), { inventory = provider.inventory })
        if resolved == nil then return false end
        local ok, value = pcall(self.isvalid, resolved)
        return ok and value and true or false
    end

    -- True when a field has an uncommitted edit or the draft differs from the list as it was opened.
    function p:IsSettingsDraftDirty()
        for _, record in ipairs(self.edits) do
            if record.dirty then return true end
        end

        return not addon:SettingsDataEqual(w.baseline, w.draft)
    end

    -- The popup has no creation state; only the draft can be dirty.
    function p:IsCreationDirty()
        return false
    end

    p.historyEnabled = true

    -- Snapshot recorded in the undo history: a copy of the whole draft list.
    function p:HistorySnapshot()
        return addon:CopySettingsData(w.draft)
    end

    -- Undo (or redo) one step: swaps the draft with the previous (next) snapshot and redraws. No-op when a pending
    -- field edit cannot be flushed or the stack is empty.
    function p:TravelSettingsHistory(redo)
        if not self:FlushEdits() then return end
        local from = redo and self.historyRedo or self.historyUndo
        local to = redo and self.historyUndo or self.historyRedo
        if not from or #from == 0 then return end
        to[#to + 1] = self:HistorySnapshot()
        w.draft = table.remove(from)
        self.historyEpoch = (self.historyEpoch or 0) + 1
        self:Draw()
    end

    -- Opens the View changes comparison of the opened list against the draft, plus any item field still being edited.
    function p:ReviewSettingsChanges()
        local pending = {}

        for _, record in ipairs(self.edits) do
            if record.dirty then
                pending[#pending + 1] = {
                    label = L['Item'],
                    before = record.baseline,
                    after = record.control:GetText(),
                }
            end
        end

        local token = self.generation

        return addon:ShowWorkbenchDraftChanges(
            self,
            'profile',
            { items = w.baseline },
            { items = w.draft },
            function() return self:Valid(token) end,
            nil,
            pending
        )
    end

    -- Marks the item fields and cards that differ from the opened list and enables Apply and View changes only while
    -- the draft is dirty.
    function p:RefreshUnsaved()
        if not self:Valid(self.generation) then return end

        for key, control in pairs(self.fields) do
            local index = key:match('^item(%d+)$')

            if index then
                addon:SetWorkbenchUnsaved(
                    control,
                    not addon:SettingsDataEqual(w.baseline[tonumber(index)], w.draft[tonumber(index)])
                )
            end
        end

        for _, record in ipairs(self.edits) do
            if record.dirty then
                addon:SetWorkbenchUnsaved(record.control, record.control:GetText() ~= record.baseline)
            end
        end

        for _, view in pairs(self.ordered or {}) do
            for i, row in ipairs(view.rows) do
                addon:SetWorkbenchUnsaved(row, not addon:SettingsDataEqual(w.baseline[i], w.draft[i]))
            end
        end

        local dirty = self:IsSettingsDraftDirty()

        for _, key in ipairs({ 'apply', 'viewChanges' }) do
            if self.fields[key] then
                if dirty then
                    self.fields[key]:Enable()
                else
                    self.fields[key]:Disable()
                end
            end
        end

        addon:SetWorkbenchUnsaved(self.fields.apply, dirty)
    end

    -- Closes the popup once and releases the widget; later calls are ignored.
    function w:Close()
        if not self.rmActive or self.closed then return end
        self.closed = true
        addon:ReleaseConditionWidget(self)
    end

    -- Writes the draft into the caller's list in place and closes. Refuses (returning false with a message) when the
    -- list was changed elsewhere since opening or any item no longer validates. A failing update callback is rethrown
    -- after the popup closes.
    function w:Apply()
        if not self:Valid() or self.applying or not p:FlushEdits() then return false end

        if type(self.target) ~= 'table' or not addon:SettingsDataEqual(self.target, self.baseline) then
            p:Message(L['The item list changed elsewhere. Close and reopen it before applying.'])
            return false
        end

        for _, item in ipairs(self.draft) do
            if not self:Accept(item) then
                p:Message(L['Complete the highlighted input fields before applying.'])
                return false
            end
        end

        if not self:Valid() then return false end
        self.applying = true

        for key in pairs(self.target) do
            self.target[key] = nil
        end

        for key, item in pairs(self.draft) do
            self.target[key] = addon:CopySettingsData(item)
        end

        local callback = self.update
        local ok, why = true, nil
        if callback then ok, why = pcall(callback) end
        self:Close()
        if not ok then error(why, 0) end
        return true
    end

    -- Close with the unsaved-changes prompt: applies or discards when the draft is dirty, closes at once otherwise.
    function w:RequestClose()
        if not self:Valid() then
            self:Close()
            return
        end

        if p:IsSettingsDraftDirty() then
            p:ConfirmPending(function() self:Apply() end, function() self:Close() end)
        else
            self:Close()
        end
    end

    -- Window-registry hook: hiding the popup means asking to close it, so the unsaved prompt is not bypassed.
    function w:Hide()
        self:RequestClose()
    end

    -- Pool hook: resets per-use state, centers and sizes the frame and binds the close and help buttons to this lease
    -- so a stale click on a recycled popup does nothing.
    function w:OnAcquire()
        self.closed = false
        self.applying = false
        self.options = {}
        frame:ClearAllPoints()
        frame:SetPoint('CENTER')
        self:SetWidth(720)
        self:SetHeight(540)
        local lease = self.rmLease

        addon:SetUIScript(w.closeButton, 'OnClick', function()
            if w.rmLease == lease and w.rmActive then w:RequestClose() end
        end)

        addon:SetUIScript(w.helpButton, 'OnClick', function()
            if w.rmLease == lease and w:Valid() then
                addon:ShowWorkbenchHelp(L['Item Set'], addon:GetNativeItemListHelp(), w.chrome.author:GetText())
            end
        end)
    end

    -- Pool hook: tears down the form and any open comparison window, clears every reference to the caller's data and
    -- then runs the caller's onclose callback.
    function w:OnRelease()
        local callback = self.onclose
        self.onclose = nil
        self.closed = true
        p:Release()

        if p.draftComparisonOwner then
            p.draftComparisonOwner.generation = p.draftComparisonOwner.generation + 1
            if p.draftComparisonOwner.comparison then p.draftComparisonOwner.comparison.frame:Hide() end
        end

        self.target = nil
        self.update = nil
        self.isvalid = nil
        self.options = {}
        self.draft = {}
        self.baseline = {}
        if callback then callback(self) end
    end

    addon:SetUIScript(frame, 'OnHide', function()
        if w.rmActive and not w.isQueuedForRelease then
            if w:Valid() then
                frame:Show()
                w:RequestClose()
            else
                w:Close()
            end
        end
    end)

    return addon:RegisterConditionWidget(w)
end

-- Opens the popup for items (the caller's list, edited only on Apply) titled name. editbox names the reference provider
-- that resolves and displays items (default the item editbox), isvalid(resolved) vets each entry, update() runs after a
-- successful Apply and onclose(widget) after release. options.valid() may revoke the popup. Returns the widget.
function addon:OpenItemListPopup(name, editbox, items, isvalid, update, onclose, options)
    local w = self:AcquireConditionWidget('RM-ItemListPopup', constructor)
    w.target = items
    w.baseline = self:CopySettingsData(items or {})
    w.draft = self:CopySettingsData(items or {})
    w.editbox = editbox or 'Item_EditBox'
    w.isvalid = isvalid or function() return true end
    w.update = update
    w.onclose = onclose
    w.options = options or {}
    w.profile, w.global, w.char = self.db.profile, self.db.global, self.db.char
    w.chrome:SetContext(L['Item Set'], L['Items in priority order'], name)
    w.form:ClearSettingsHistory()
    w.form.newItem = ''

    w.form:Open(function(p)
        p:Heading(name)
        p:Text(L['Apply changes to this selected item list. Other settings keep their own Apply action.'])

        if type(w.target) ~= 'table' then
            p:Text(L['Choose an item list before editing.'])
            p:CreationActions(function() end, function() w:Close() end, true)
            return
        end

        p:HistoryActions()
        local items = w.draft

        -- The new-item field and Add share the row above the item cards. Inserts the typed item at gap (clamped to the
        -- list) after validating it; the field is cleared and the form redrawn.
        local function insertItem(gap)
            if p.newItem == '' or not w:Accept(p.newItem) then
                p:Message(L['Choose an item first.'])
                return
            end

            table.insert(w.draft, math.max(1, math.min(gap, #w.draft + 1)), p.newItem)
            p.newItem = ''
            p:Draw()
        end

        p:OrderedCollection(
            'items_popup',
            items,
            function(i)
                local provider = self:GetReferenceProvider(w.editbox)
                return provider.name(tonumber(items[i]) or provider.resolve(items[i])) or L['Item data loading']
            end,
            function(form, i, item)
                local field = form:Reference(
                    'item' .. i,
                    nil,
                    item,
                    w.editbox,
                    { accept = function(value) return w:Accept(value) end },
                    function(value) items[i] = value end
                )

                field:ClearAllPoints()
                field:SetPoint('TOPLEFT', 18, -2)
                field:SetSize(form.width - 20, 24)
                form.y = 22
            end,
            function() end,
            {
                prefix = 'item',
                compact = true,
                readOnly = type(w.target) ~= 'table',
                add = {
                    key = 'add_item',
                    text = L['Add item'],
                    insert = insertItem,
                    leading = function(form, y, width)
                        return self:LayoutNewItemField(
                            form,
                            form:Reference(
                                'new_item',
                                nil,
                                p.newItem,
                                w.editbox,
                                { accept = function(value) return w:Accept(value) end },
                                function(value) p.newItem = value end,
                                true
                            ),
                            y,
                            width
                        )
                    end,
                },
            }
        )

        p:CreationActions(function() w:Apply() end, function() w:Close() end, true)
    end)

    w.frame:Show()
    self:OpenPopup(w)
    return w
end
