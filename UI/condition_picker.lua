-- Condition type picker: the combobox the condition editor shows on a card to choose or replace a condition type, with
-- a search box, a category list from the profile's condition groups and a capped list of matching types.
-- It owns its popup frames and rows (reused through the `reuse` table) and reports a choice only through the callback;
-- it never edits the rotation. Conditions are listed per scope from the registry (addon:listConditions).
-- Loaded from RotationMaster.toc just before UI/condition_cards.lua; UI/condition_editor.lua is the only caller and
-- registers the picker's escape frame with the window registry (UI/window.lua).

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- One native combobox: typing immediately opens its filtered results; clicking
-- opens the same results and category browser without needing a search term.
-- `choose(tag)` is called once for the chosen type, `alive()` must return false once the owning editor drawing is gone
-- (every callback checks it), and `reuse` is a previous picker table whose frames are kept. Returns the picker, hidden.
function addon:CreateConditionTypePicker(parent, scope, current, choose, alive, reuse)
    local picker = reuse or { rows = {}, categories = {} }
    local width = math.max(300, math.min(540, parent:GetWidth() - 48))
    local host = picker.host or CreateFrame("Frame", nil, parent)
    picker.host = host
    host:SetSize(width + 8, 300)
    host:SetClampedToScreen(true)
    host:EnableMouse(true)
    addon:MakeWindowOpaque(host)
    local input = picker.frame or addon:CreateWorkbenchEditBox(host)
    picker.frame = input
    input:SetAutoFocus(false)
    input:SetMaxLetters(128)
    input:SetHeight(26)
    input:ClearAllPoints()
    input:SetPoint("TOPLEFT", 8, -4)
    input:SetPoint("TOPRIGHT", -8, -4)
    local popup = picker.popup or CreateFrame("Frame", nil, host)
    picker.popup = popup
    local popupWidth = width
    popup:SetSize(popupWidth, 260)
    popup:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -4, -4)
    popup:SetFrameLevel(host:GetFrameLevel() + 1)
    popup:EnableMouse(true)
    addon:MakeWindowOpaque(popup)
    local scroll = picker.scroll or addon:CreateWorkbenchScrollFrame(popup)
    picker.scroll = scroll
    scroll:SetPoint("TOPLEFT", 160, -8)
    scroll:SetSize(popupWidth - 190, 244)
    local child = picker.child or CreateFrame("Frame", nil, scroll)
    picker.child = child
    child:SetWidth(popupWidth - 198)
    scroll:SetScrollChild(child)
    local allowed = {}

    for _, tag in ipairs(addon:listConditions(scope)) do
        if addon.conditionDefinitions[tag] then
            allowed[tag] = true
        end
    end

    local groups = { { name = L["All categories"] } }

    for _, group in ipairs(addon.db.profile.condition_groups or {}) do
        local tags = {}

        for _, tag in ipairs(group.conditions or {}) do
            tags[tag] = true
        end

        groups[#groups + 1] = { name = group.name or group.id, tags = tags }
    end

    local selected = 1
    local selectedType = current

    -- Shows the current type's description in the box, or the prompt when there is none.
    local function display()
        input:SetText(
            selectedType
                and addon.conditionDefinitions[selectedType]
                and addon.conditionDefinitions[selectedType].description
                or L["Choose or search condition type"]
        )
    end

    -- Records the choice, closes the popup, then reports it; ignored when the owning drawing is gone.
    local function selectType(tag)
        if not alive() then
            return
        end

        selectedType = tag
        picker:Dismiss()
        choose(tag)
    end

    -- Fills the result list with the allowed types in the selected category whose description or tag contains `query`
    -- (case-insensitive, plain text), sorted by description. Only the first 200 matches get rows, which bounds the
    -- number of buttons created; self.matches keeps the full list for Enter.
    function picker:Filter(query)
        if not alive() then
            return
        end

        query = string.lower(query or "")
        local tags = {}
        local category = groups[selected]

        for index, button in ipairs(self.categories) do
            button:SetSelected(index == selected)
        end

        for tag in pairs(allowed) do
            local definition = addon.conditionDefinitions[tag]
            local description = definition.description or tag

            if
                (not category.tags or category.tags[tag])
                and (query == "" or string.find(string.lower(description), query, 1, true) or string.find(
                    string.lower(tag),
                    query,
                    1,
                    true
                ))
            then
                tags[#tags + 1] = tag
            end
        end

        table.sort(tags, function(a, b)
            return (addon.conditionDefinitions[a].description or a) < (addon.conditionDefinitions[b].description or b)
        end)

        self.matches = tags

        for index = 1, math.min(200, #tags) do
            local tag = tags[index]
            local row = self.rows[index]

            if not row then
                row = addon:CreateWorkbenchButton(child, "", popupWidth - 200)
                self.rows[index] = row
            end

            row:SetSize(popupWidth - 200, 24)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 26)
            row:SetText(addon.conditionDefinitions[tag].description or tag)

            addon:SetUIScript(row, "OnClick", function()
                selectType(tag)
            end)

            row:Show()
        end

        for index = math.min(200, #tags) + 1, #self.rows do
            self.rows[index]:Hide()
        end

        child:SetHeight(math.max(1, math.min(200, #tags) * 26))
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(0)
    end

    local categoryScroll = picker.categoryScroll or addon:CreateWorkbenchScrollFrame(popup)
    picker.categoryScroll = categoryScroll
    categoryScroll:SetPoint("TOPLEFT", 8, -8)
    categoryScroll:SetSize(128, 244)
    local categoryChild = picker.categoryChild or CreateFrame("Frame", nil, categoryScroll)
    picker.categoryChild = categoryChild
    categoryChild:SetSize(120, #groups * 28)
    categoryScroll:SetScrollChild(categoryChild)

    for index, group in ipairs(groups) do
        local button = picker.categories[index] or addon:CreateWorkbenchButton(categoryChild, "", 118)
        button:SetSize(118, 26)
        button:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        button:SetText(group.name)
        button:Show()

        addon:SetUIScript(button, "OnClick", function()
            if alive() then
                selected = index
                picker:Filter(input:GetText())
            end
        end)

        picker.categories[index] = button
    end

    for index = #groups + 1, #picker.categories do
        picker.categories[index]:Hide()
    end

    display()

    -- OnUpdate poll while the picker is open: closes it when a left click lands outside the host frame, or when the
    -- owner is gone. mouseDown remembers the previous state so the click that opened the picker does not close it.
    local function watchOutside()
        if not alive() then
            picker:Dismiss()
            return
        end

        local down = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        local over = InputUtil and InputUtil.IsMouseOver or MouseIsOver

        if down and not picker.mouseDown and over and not over(host) then
            picker:Dismiss()
        end

        picker.mouseDown = down
    end

    -- Shows the host and the unfiltered results and starts the outside-click poll.
    local function open()
        if alive() then
            host:Show()
            input:Show()
            input:SetText("")
            picker:Filter("")
            popup:Show()
            addon:SetUIScript(host, "OnUpdate", watchOutside)
        end
    end

    -- Closes the popup without choosing, restores the box text and stops the outside-click poll.
    function picker:Dismiss()
        popup:Hide()
        host:Hide()
        input:ClearFocus()
        display()
        addon:SetUIScript(host, "OnUpdate", nil)
    end

    -- Opens below `anchor` (when given) with the results showing and the box focused.
    function picker:Open(anchor)
        if anchor then
            host:ClearAllPoints()
            host:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -112, -4)
        end

        self.mouseDown = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        open()
        input:SetFocus()
    end

    addon:SetUIScript(input, "OnEditFocusGained", open)

    addon:SetUIScript(input, "OnMouseDown", function()
        if not popup:IsShown() then
            open()
        end
    end)

    addon:SetUIScript(input, "OnTextChanged", function(_, userInput)
        if userInput and alive() then
            picker:Filter(input:GetText())
            popup:Show()
        end
    end)

    addon:SetUIScript(input, "OnEnterPressed", function()
        if alive() and popup:IsShown() and picker.matches and picker.matches[1] then
            selectType(picker.matches[1])
        end
    end)

    addon:SetUIScript(input, "OnEscapePressed", function()
        picker:Dismiss()
    end)

    addon:SetUIScript(input, "OnEditFocusLost", function()
        if not popup:IsShown() then
            display()
        end
    end)

    if not picker.escape then
        picker.escape = { frame = host }

        addon:SetUIScript(host, "OnHide", function()
            popup:Hide()
            input:ClearFocus()
            addon:SetUIScript(host, "OnUpdate", nil)
        end)

        addon:OpenPopup(picker.escape, parent)
    end

    -- Dismisses and hides the picker so its frames can be reused by the next CreateConditionTypePicker call.
    function picker:Release()
        self:Dismiss()
        input:Hide()
    end

    picker:Release()
    return picker
end
