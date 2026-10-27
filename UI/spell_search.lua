-- Spell and item search box: the edit box used for every spell, item and totem field, with a suggestion list, exact
-- selection by ID or link, drag and drop from the cursor, and a right-click menu of what the game offers right now.
-- It decorates a pooled native text input lease (addon:CreateConditionEditBox) and restores its scripts and methods
-- when the lease is released; it never owns saved data, it only reports the chosen reference through OnEnterPressed.
-- Loaded from RotationMaster.toc after UI/window.lua and UI/help.lua and before UI/spell_icon.lua. Names and searches
-- come from the reference provider (addon:GetReferenceProvider); live game values (the target's cast, trinkets, the
-- cursor) are read through pcall and gated by platform:CanReadValue because restricted clients hide them.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- ============================================================================
-- Suggestion popup
-- ============================================================================

-- Removes color escapes from a name so it can sit in the edit box as plain text.
local function clean(text)
    return type(text) == "string" and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or text
end

-- Hides the game tooltip when one of the popup's rows owns it, so closing the list never leaves a stale tooltip.
local function hideTooltip(popup)
    if GameTooltip then
        for _, row in ipairs(popup.rows) do
            if GameTooltip:IsOwned(row) then
                GameTooltip:Hide()
                break
            end
        end
    end
end

-- Builds the suggestion list frame (twelve rows and a footer) and stores it on `widget` so the next lease of the same
-- widget reuses it. It sits in the TOOLTIP strata on purpose: it is a list, not a window, so the window registry does
-- not order it (docs/architecture/window-layering.md).
local function newPopup(widget)
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup.rows = {}
    popup.footer = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.footer:SetPoint("BOTTOMLEFT", 10, 10)
    popup.footer:SetJustifyH("LEFT")

    for index = 1, 12 do
        local row = CreateFrame("Button", nil, popup)
        popup.rows[index] = row
        row:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 26)
        row:SetPoint("TOPRIGHT", -8, -8 - (index - 1) * 26)
        row:SetHeight(26)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 30, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 3, 0)
        row.selection = row:CreateTexture(nil, "BACKGROUND")
        row.selection:SetAllPoints(row)
        row.selection:SetColorTexture(.357, .753, .922, .2)
    end

    addon:MakeWindowOpaque(popup)
    popup:Hide()
    widget.rmSpellPopup = popup
    return popup
end

-- What the game can offer a spell or item field right now, for its
-- right-click menu: the target's and focus's current cast, the player's
-- recent casts (newest first) and equipped trinkets. Each entry is
-- {id=number, context=format string taking the name}. Values the client
-- marks unreadable, and repeats, are left out.

-- ============================================================================
-- What the game offers right now
-- ============================================================================

-- Returns up to ten context entries for `kind` ('spell' or 'item'); see the description above for the shape.
function addon:GetReferenceContextEntries(kind)
    local entries, seen = {}, {}
    local platform = self.Platform

    -- True for a value the client lets addons read; a restricted-client secret value must never be compared or used
    -- as a table key, so unreadable ids are dropped before anything else touches them.
    local function readable(value)
        return value ~= nil and (not platform or not platform.CanReadValue or platform:CanReadValue(value))
    end

    -- Adds one entry unless the id is unreadable, not a positive number, already listed, or the list is full.
    local function add(id, context)
        if not readable(id) or type(id) ~= 'number' or id <= 0 or seen[id] or #entries >= 10 then return end
        seen[id] = true
        entries[#entries + 1] = { id = id, context = context }
    end

    -- Drops the pcall status and returns the results only on success.
    local function returned(ok, ...)
        if ok then return ... end
    end

    -- Calls a game function under pcall; returns its results, or nothing when it is missing or errors (an API that is
    -- absent on one client must not break the menu).
    local function call(fn, ...)
        if type(fn) == 'function' then return returned(pcall(fn, ...)) end
    end

    if kind == 'spell' then
        for _, unit in ipairs({ 'target', 'focus' }) do
            local exists = call(UnitExists, unit)

            if readable(exists) and exists then
                local casting = select(9, call(UnitCastingInfo, unit))
                local channel = select(8, call(UnitChannelInfo, unit))
                add(casting, unit == 'target' and L['Target casting: %s'] or L['Focus casting: %s'])
                add(channel, unit == 'target' and L['Target channeling: %s'] or L['Focus channeling: %s'])
            end
        end

        for _, entry in ipairs(type(self.spellHistory) == 'table' and self.spellHistory or {}) do
            if type(entry) == 'table' then add(entry.spell, L['Recently cast: %s']) end
        end
    elseif kind == 'item' then
        for slot, context in pairs({ [13] = L['Trinket 1: %s'], [14] = L['Trinket 2: %s'] }) do
            add(call(GetInventoryItemID, 'player', slot), context)
        end

        table.sort(entries, function(a, b) return a.context < b.context end)
    end

    return entries
end

-- ============================================================================
-- The search field
-- ============================================================================

-- The ordinary field remains compatible with existing data callbacks. Search,
-- suggestions and exact selection belong to RM, not the shared ID scanner.
-- `kind` is the field type ('Spell_EditBox', 'Item_EditBox', 'Spec_EditBox', 'Totem_EditBox', ...) and `initialSpell`
-- an id or name to prime the provider's index. Returns the decorated widget; every script and method changed here is
-- restored by its OnRelease, and every callback checks `alive` first.
function addon:CreateReferenceEditBox(kind, initialSpell)
    local provider = self:GetReferenceProvider(kind)

    if type(initialSpell) == "number" then
        provider.index(initialSpell)
    elseif type(initialSpell) == "string" then
        provider.resolve(initialSpell)
    end

    local widget = self:CreateConditionEditBox()
    -- Suggestions temporarily decorate a native text lease. Restore its exact
    -- scripts and methods before it returns to the ordinary input pool.
    local field = widget.editbox
    local popup = widget.rmSpellPopup or newPopup(widget)
    local dropHint = field.rmDropHint or field:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
    field.rmDropHint = dropHint
    dropHint:ClearAllPoints()
    dropHint:SetPoint('LEFT', 5, 0)
    dropHint:SetPoint('RIGHT', -5, 0)
    dropHint:SetJustifyH('LEFT')
    dropHint:SetText(provider.kind == 'item' and L['Search or drag an item here'] or L['Search or drag a spell here'])
    local alive, setting = true, false
    local acceptedText = ""
    local acceptedID
    local selected, navigated = 1, false
    local matches = {}
    widget.rmSpellSearchActive = true

    -- A right click opens the insert menu; it must not also close the window (UI/window.lua, UI/config.lua).
    field.rmOwnsRightClick = true
    widget:SetMaxLetters(256)

    local originalText, originalRelease, originalReferenceID, originalCommit =
        widget.SetText, widget.OnRelease, widget.GetReferenceID, widget.CommitPending

    local scripts = {}

    -- Replaces a frame script with `handler`, remembering the original so OnRelease can put it back, but only if the
    -- handler is still the one installed (another owner may have replaced it since).
    local function install(frame, event, handler)
        local binding = { frame = frame, event = event, original = frame:GetScript(event) }
        binding.handler = addon:SetUIScript(frame, event, handler)
        scripts[#scripts + 1] = binding
    end

    -- Search options for this field: the spec for spellbook fields, the totem name filter, the no-rank flag, the
    -- inventory source and the row limit.
    local function settings()
        return {
            spec = (kind == "Spec_EditBox" or kind == "Totem_EditBox") and widget:GetUserData("spec") or nil,
            nameContains = kind == "Totem_EditBox" and L["Totem"] or nil,
            norank = widget:GetUserData("norank") == true,
            inventory = provider.inventory,
            limit = 12,
        }
    end

    local blurDeferred = false

    -- Closes the suggestion list and any tooltip it owns, and clears a deferred blur.
    local function hide()
        blurDeferred = false
        hideTooltip(popup)
        popup:Hide()
    end

    -- Is the pointer on this field's suggestion list? Mouse focus, not
    -- geometry, so a window over the list does not count.
    local function overPopup()
        if not popup:IsShown() then return false end
        local focus

        if type(GetMouseFoci) == "function" then
            local ok, foci = pcall(GetMouseFoci)
            focus = ok and type(foci) == "table" and foci[1] or nil
        elseif type(GetMouseFocus) == "function" then
            local ok, value = pcall(GetMouseFocus)
            focus = ok and value or nil
        else
            return type(popup.IsMouseOver) == "function" and popup:IsMouseOver() or false
        end

        for _ = 1, 20 do
            if focus == popup then return true end
            if type(focus) ~= "table" or type(focus.GetParent) ~= "function" then return false end
            focus = focus:GetParent()
        end

        return false
    end

    -- Retail clears keyboard focus on every left GLOBAL_MOUSE_DOWN that is
    -- not on the focused EditBox (Blizzard_Game/Mainline/EventImplementation.lua
    -- ClearCurrentKeyboardFocus), before the suggestion row sees its press:
    -- the list closed and the pick was lost. That handler keeps focus when
    -- the EditBox reports HasStickyFocus(), so the field does while the
    -- pointer is on its own list.
    local originalSticky = rawget(field, "HasStickyFocus")
    field.HasStickyFocus = function() return alive and overPopup() or false end

    -- Setting the text accepts it: a number or a link becomes the item or spell name, the accepted id and text are
    -- remembered, and the list closes. `setting` keeps the resulting OnTextChanged from starting a new search.
    widget.SetText = function(self, text)
        local id = type(text) == 'number' and text
            or type(text) == 'string' and (tonumber(text) or tonumber(text:match('|H' .. provider.kind .. ':(%d+)')))

        acceptedID = id
        if id then text = provider.name(id, self:GetUserData('norank')) or provider.missing end
        setting = true
        originalText(self, clean(text))
        setting = false
        acceptedText = field:GetText()

        if acceptedText == '' then
            dropHint:Show()
        else
            dropHint:Hide()
        end

        hide()
    end

    -- The accepted id while the text is still exactly what was accepted; nil once the user has edited it.
    widget.GetReferenceID = function()
        if alive and field:GetText() == acceptedText then return acceptedID end
    end

    -- Marks the selected row (the one Enter would pick).
    local function highlight()
        for index, row in ipairs(popup.rows) do
            if index == selected and matches[index] then
                row.selection:Show()
            else
                row.selection:Hide()
            end
        end
    end

    -- Accepts reference `id`: resolves it through the provider, sets the text and fires OnEnterPressed with the
    -- resolved id. Returns true when it was accepted.
    local function commit(id)
        if not alive or widget.disabled then return end
        local resolved = provider.resolve(tostring(id), settings())
        if not resolved then return end
        local name = provider.name(resolved, widget:GetUserData("norank"))
        widget:SetText(resolved)
        widget:Fire("OnEnterPressed", tostring(resolved))
        -- A callback may rebuild/release this field; never touch its next owner.
        if alive then widget:ClearFocus() end
        return true
    end

    -- Runs the search for the text in the box and fills the suggestion rows and footer. A search with no hits that
    -- the provider can resolve exactly (an id, link or exact name) is retried by that name. Only runs while focused.
    local function query()
        if not alive or setting or widget.disabled or not field:HasFocus() then return end

        if acceptedID and field:GetText() == acceptedText then
            local name = provider.name(acceptedID, widget:GetUserData('norank'))
            if name and name ~= acceptedText then widget:SetText(acceptedID) end
        end

        local text = field:GetText()

        if text == '' then
            dropHint:Show()
        else
            dropHint:Hide()
        end

        if text == provider.missing then text = '' end
        local opts = settings()
        local rows, status = provider.search(text, opts)

        if rows and #rows == 0 and text ~= "" then
            local id = provider.resolve(text, opts)
            local name = id and provider.name(id, true)
            if name then rows, status = provider.search(name, opts) end
        end

        matches = rows or {}
        selected = 1
        navigated = false

        for index, row in ipairs(popup.rows) do
            local entry = matches[index]
            row.referenceID = entry and entry.id
            row.spellID = provider.kind == 'spell' and row.referenceID or nil
            row.itemID = provider.kind == 'item' and row.referenceID or nil

            if entry then
                row.text:SetText(entry.display)

                if entry.icon then
                    row.icon:SetTexture(entry.icon)
                    row.icon:Show()
                else
                    row.icon:Hide()
                end

                row:Show()
            else
                row:Hide()
            end
        end

        local footer

        if provider.kind == "item" then
            footer = #matches == 0 and L["No matching items."] or L["Click a result or enter an item name, ID or link."]
        elseif status and status.reason then
            footer = L["Spell search data is unavailable."]
        elseif #matches == 0 then
            footer = L["No matching spells."]
        elseif status and status.more then
            footer = L["More matches available. Keep typing to narrow the search."]
        elseif opts.spec ~= nil then
            footer = L["Spells from this spellbook. Click a result or press Enter."]
        else
            footer = L["Known and referenced spells. Enter a spell ID or link to find another spell."]
        end

        popup.footer:SetText(
            footer
                .. '\n'
                .. (provider.kind == 'item' and L['Search or drag an item here'] or L['Search or drag a spell here'])
                .. '\n'
                .. (provider.kind == 'item' and L['Right-click to insert an equipped trinket.']
                    or L["Right-click to insert your target's cast or a recent cast."])
        )

        local width = math.max(360, field:GetWidth() + 16)
        popup:SetSize(width, math.max(1, #matches) * 26 + 74)
        popup.footer:SetWidth(width - 20)
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", field, "BOTTOMLEFT", -6, -4)
        highlight()
        popup.rmContextMenu = nil
        popup:Show()
    end

    -- Enter pressed: an empty box clears the field; otherwise an exact reference wins, then the selected suggestion,
    -- and with neither the list is refreshed. Tab navigation (`navigated`) makes the selected row win.
    local function enter()
        if not alive or widget.disabled then return end
        local text = field:GetText()

        if text == "" then
            widget:SetText("")
            widget:Fire("OnEnterPressed", "")
            if alive then widget:ClearFocus() end
            return
        end

        local id = not navigated and (text == acceptedText and acceptedID or provider.resolve(text, settings())) or nil

        if id then
            commit(id)
        elseif matches[selected] then
            commit(matches[selected].id)
        else
            query()
        end
    end

    -- Commits typed-but-unaccepted text (as Enter would). Returns true when nothing was pending, true when the text
    -- was accepted, and nil when it could not be resolved so the caller keeps the page dirty.
    widget.CommitPending = function(self)
        if not alive or self.disabled or not self:IsPending() then return true end
        enter()
        return field:GetText() == acceptedText or nil
    end

    local onText = field:GetScript("OnTextChanged")

    install(field, "OnTextChanged", function(self, ...)
        if not alive then return end
        if onText then onText(self, ...) end
        if alive then query() end
    end)

    local onFocus = field:GetScript("OnEditFocusGained")

    install(field, "OnEditFocusGained", function(self, ...)
        if not alive then return end
        if onFocus then onFocus(self, ...) end
        blurDeferred = false
        if alive then query() end
    end)

    local onLost = field:GetScript("OnEditFocusLost")

    install(field, "OnEditFocusLost", function(self, ...)
        if not alive then return end

        -- A press on a suggestion owns the outcome: the row commits it. Only
        -- a blur elsewhere restores the accepted text and closes the list.
        if overPopup() then
            blurDeferred = true
            return
        end

        if alive then
            widget:SetText(acceptedID or acceptedText)
            hide()
        end

        if onLost then onLost(self, ...) end
    end)

    install(field, "OnEnterPressed", enter)

    install(field, "OnEscapePressed", function()
        if alive then
            hide()
            widget:ClearFocus()
        end
    end)

    install(field, "OnTabPressed", function(_, reverse)
        if not alive or widget.disabled then return end

        if #matches > 0 then
            selected = ((selected - 1 + (reverse and -1 or 1)) % #matches) + 1
            navigated = true
            highlight()
        end
    end)

    -- Accepts the spell or item being dragged on the cursor, when its id resolves for this field. The cursor values
    -- are read under pcall and CanReadValue because a restricted client may hide them.
    local function drag()
        if not alive or type(GetCursorInfo) ~= "function" then return end
        local observed = { pcall(GetCursorInfo) }
        local ok, cursor, first, third = observed[1], observed[2], observed[3], observed[5]
        if not ok or not addon.Platform:CanReadValue(cursor) then return end
        local id

        if provider.kind == "item" and cursor == "item" then
            id = first
        elseif provider.kind == "spell" and cursor == "spell" then
            id = third
        elseif provider.kind == "spell" and cursor == "petaction" then
            id = first
        end

        if not addon.Platform:CanReadValue(id) or type(id) ~= "number" then return end

        if provider.resolve(tostring(id), settings()) then
            if commit(id) and type(ClearCursor) == "function" then ClearCursor() end
        end
    end

    -- Right-click lists what the game offers right now (see
    -- GetReferenceContextEntries) in the suggestion rows; a click commits it
    -- exactly like a suggestion.
    local function insertMenu()
        if not alive or widget.disabled then return end

        if popup:IsShown() and popup.rmContextMenu then
            hide()
            return
        end

        local opts = settings()
        matches = {}

        for _, entry in ipairs(addon:GetReferenceContextEntries(provider.kind)) do
            local id = provider.resolve(tostring(entry.id), opts)

            if id then
                local info = provider.info and provider.info(id)

                matches[#matches + 1] = {
                    id = id,
                    display = string.format(
                        entry.context,
                        provider.name(id, widget:GetUserData('norank')) or tostring(id)
                    ),
                    icon = info and info.icon,
                }
            end
        end

        selected = 1
        navigated = false

        for index, row in ipairs(popup.rows) do
            local entry = matches[index]
            row.referenceID = entry and entry.id
            row.spellID = provider.kind == 'spell' and row.referenceID or nil
            row.itemID = provider.kind == 'item' and row.referenceID or nil

            if entry then
                row.text:SetText(entry.display)

                if entry.icon then
                    row.icon:SetTexture(entry.icon)
                    row.icon:Show()
                else
                    row.icon:Hide()
                end

                row:Show()
            else
                row:Hide()
            end
        end

        popup.footer:SetText(
            #matches == 0
                and (provider.kind == 'item' and L['No equipped trinket to insert.']
                    or L['Nothing to insert: no target or focus cast and no recent casts.'])
                or L['Click to insert. Right-click the field again to close.']
        )

        local width = math.max(360, field:GetWidth() + 16)
        popup:SetSize(width, math.max(1, #matches) * 26 + 46)
        popup.footer:SetWidth(width - 20)
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", field, "BOTTOMLEFT", -6, -4)
        highlight()
        popup.rmContextMenu = true
        popup:Show()
    end

    install(field, "OnReceiveDrag", drag)

    install(field, "OnMouseDown", function(_, button)
        if button == "RightButton" then
            insertMenu()
        else
            drag()
        end
    end)

    local onHide = widget.frame:GetScript("OnHide")

    install(widget.frame, "OnHide", function(self, ...)
        if not alive then return end
        hide()
        if onHide then onHide(self, ...) end
    end)

    -- A deferred blur ends with the press: a row commits, anything else on
    -- the list restores the accepted text as an ordinary blur would.
    -- Completes a blur that was deferred because the press landed on the list.
    local function finishBlur()
        if alive and blurDeferred and not field:HasFocus() then
            widget:SetText(acceptedID or acceptedText)
            hide()
        end
    end

    install(popup, "OnMouseUp", finishBlur)

    for _, row in ipairs(popup.rows) do
        addon:SetUIScript(row, "OnMouseDown", function(self, button)
            if button == "LeftButton" and self.referenceID then commit(self.referenceID) end
        end)

        addon:SetUIScript(row, "OnMouseUp", finishBlur)

        addon:SetUIScript(row, "OnEnter", function(self)
            if self.referenceID and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(provider.kind .. ":" .. self.referenceID)
            end
        end)

        addon:SetUIScript(row, "OnLeave", function(self)
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end

    -- Lease release: marks the field dead so late callbacks do nothing, closes the list, puts back every script and
    -- method this function replaced, and then runs the original release.
    widget.OnRelease = function(self, ...)
        alive = false
        hide()
        dropHint:Hide()
        self.rmSpellSearchActive = nil
        field.rmOwnsRightClick = nil
        field.HasStickyFocus = originalSticky

        for _, binding in ipairs(scripts) do
            if binding.frame:GetScript(binding.event) == binding.handler then
                binding.frame:SetScript(binding.event, binding.original)
            end
        end

        for _, row in ipairs(popup.rows) do
            row.spellID = nil
            row.itemID = nil
            row.referenceID = nil
            addon:SetUIScript(row, "OnMouseDown", nil)
            addon:SetUIScript(row, "OnMouseUp", nil)
            addon:SetUIScript(row, "OnEnter", nil)
            addon:SetUIScript(row, "OnLeave", nil)
        end

        self.SetText, self.OnRelease, self.GetReferenceID, self.CommitPending =
            originalText, originalRelease, originalReferenceID, originalCommit

        if originalRelease then return originalRelease(self, ...) end
    end

    return widget
end

-- Spell field entry point; the same widget as CreateReferenceEditBox.
function addon:CreateSpellEditBox(kind, initialSpell)
    return self:CreateReferenceEditBox(kind, initialSpell)
end

-- Item field entry point; `kind` defaults to 'Item_EditBox'.
function addon:CreateItemEditBox(kind, initialItem)
    return self:CreateReferenceEditBox(kind or 'Item_EditBox', initialItem)
end
