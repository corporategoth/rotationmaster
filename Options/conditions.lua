local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")

local color, table, pairs, ipairs = color, table, pairs, ipairs
local wrap, HideOnEscape, deepcopy= addon.wrap, addon.HideOnEscape, addon.deepcopy

local special = {}
special["DELETE"] = { desc = DELETE, icon = "Interface\\Icons\\Trade_Engineering" }
special["AND"] = { desc = L["AND"], icon = "Interface\\Icons\\Spell_ChargePositive" }
special["OR"] = { desc = L["OR"], icon = "Interface\\Icons\\Spell_ChargeNegative" }
special["NOT"] = { desc = L["NOT"], icon = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent" }

local ENTRIES_PER_ROW = 5

local function ImportExport(conditions, update)
    local function spacer(width)
        local rv = AceGUI:Create("Label")
        rv:SetRelativeWidth(width)
        return rv
    end

    local frame = AceGUI:Create("Window")
    frame:SetTitle(L["Import/Export Condition Group"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetWidth(485)
    frame:SetHeight(485)
    frame:EnableResize(false)
    HideOnEscape(frame)

    frame:PauseLayout()

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")

    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    -- editbox:SetLabel("")
    editbox:SetNumLines(28)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if conditions and #conditions > 0 then
        local body = conditions[1]
        for i=2,#conditions do
            body = body .. "\n" .. conditions[i]
        end
        editbox:SetText(body)
    end
    -- editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 13)
    editbox:SetCallback("OnTextChanged", function()
        import:SetDisabled(false)
    end)

    editbox:HighlightText(0, string.len(editbox:GetText()))
    frame:AddChild(editbox)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 1, 0.25, 0.25 } })

    group:AddChild(spacer(1))

    import:SetText(L["Import"])
    import:SetDisabled(true)
    import:SetCallback("OnClick", function()
        local body = addon.split(editbox:GetText():gsub(",", "\n"), "\n")
        for _, v in ipairs(body) do
            v = addon.trim(v)
        end

        frame:Hide()
        update(body)
    end)
    group:AddChild(import)

    local close = AceGUI:Create("Button")
    close:SetText(CANCEL)
    close:SetCallback("OnClick", function()
        frame:Hide()
    end)
    group:AddChild(close)

    frame:AddChild(group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function layout_conditions(frame, group, selected, filter, update)
    local function spacer()
        local rv = AceGUI:Create("Label")
        rv:SetUserData("cell", { colspan = ENTRIES_PER_ROW })
        rv:SetFullWidth(true)
        return rv
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    local selectedIcon

    local cols = {}
    for _=1,ENTRIES_PER_ROW do
        table.insert(cols, 1 / ENTRIES_PER_ROW)
    end
    local grid = AceGUI:Create("SimpleGroup")
    grid:SetFullWidth(true)
    grid:SetFullHeight(true)
    grid:SetLayout("Table")
    grid:SetUserData("table", { columns = cols, spaceV = 5 })
    frame:AddChild(grid)

    grid:AddChild(spacer())

    for _,cond in pairs(addon:listConditions(group, group == "ALL")) do
        local desc, icon
        if special[cond] then
            icon, desc = special[cond].icon, special[cond].desc
        else
            icon, desc = addon:describeCondition(cond)
        end

        if not filter or string.find(string.lower(desc), string.lower(filter)) then
            local description = AceGUI:Create("InteractiveLabel")
            local text = wrap(desc, 18)
            if not string.match(text, "\n") then
                text = text .. "\n"
            end
            description:SetImage(icon)
            description:SetImageSize(36, 36)
            description:SetText(text)
            description:SetJustifyH("center")
            description:SetWidth(100)
            description:SetUserData("cell", { alignV = "top", alignH = "left" })
            description:SetCallback("OnClick", function ()
                if selectedIcon then
                    addon:HideGlow(selectedIcon.frame)
                end
                selectedIcon = description
                addon:ApplyCustomGlow({ type = "pixel" }, selectedIcon.frame, nil, { r = 0, g = 1, b = 0, a = 1 }, 0, 3)
                update(cond)
            end)
            grid:AddChild(description)

            if selected == cond then
                selectedIcon = description
                addon:ApplyCustomGlow({ type = "pixel" }, selectedIcon.frame, nil, { r = 0, g = 1, b = 0, a = 1 }, 0, 3)
            end
        end
    end

    grid:AddChild(spacer())
    grid:AddChild(spacer())

    grid:SetCallback("OnRelease", function()
        if selectedIcon then
            addon:HideGlow(selectedIcon.frame)
        end
    end)

    if selected and not selectedIcon then
        update()
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function layout_top_window(frame, group, update, filter)
    local profile = addon.db.profile

    frame:ReleaseChildren()
    frame:PauseLayout()

    local cond_group_idx
    for idx,v in pairs(profile.condition_groups) do
        if group == v.id then
            cond_group_idx = idx
        end
    end

    local cond_header = AceGUI:Create("SimpleGroup")
    cond_header:SetFullWidth(true)
    cond_header:SetLayout("Table")
    cond_header:SetUserData("table", { columns = { 200, 24, 24, 24, 24, 24, 24, 1 } })
    frame:AddChild(cond_header)

    local movetop = AceGUI:Create("Icon")
    local moveup = AceGUI:Create("Icon")
    local movedown = AceGUI:Create("Icon")
    local movebottom = AceGUI:Create("Icon")
    local importexport = AceGUI:Create("Icon")
    local delete = AceGUI:Create("Icon")

    local function UpdateMoveButtons()
        if not cond_group_idx or cond_group_idx == 1 then
            movetop:SetImage("Interface\\AddOns\\RotationMaster\\textures\\UI-ChatIcon-ScrollHome-Disabled")
            movetop:SetDisabled(true)
        else
            movetop:SetImage("Interface\\AddOns\\RotationMaster\\textures\\UI-ChatIcon-ScrollHome-Up")
            movetop:SetDisabled(false)
        end
        if not cond_group_idx or cond_group_idx == 1 then
            moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
            moveup:SetDisabled(true)
        else
            moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
            moveup:SetDisabled(false)
        end
        if not cond_group_idx or cond_group_idx == #profile.condition_groups then
            movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
            movedown:SetDisabled(true)
        else
            movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            movedown:SetDisabled(false)
        end
        if not cond_group_idx or cond_group_idx == #profile.condition_groups then
            movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
            movebottom:SetDisabled(true)
        else
            movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
            movebottom:SetDisabled(false)
        end
    end
    UpdateMoveButtons()

    local name = AceGUI:Create("EditBox")
    name:SetLabel(NAME)
    name:SetFullWidth(true)
    if group == "ALL" then
        name:SetText(ALL)
        name:SetDisabled(true)
    elseif group == "DEFAULT" then
        name:SetText(L["Other"])
        name:SetDisabled(true)
    elseif group == "SWITCH" then
        name:SetText(L["Switch"])
        name:SetDisabled(true)
    elseif cond_group_idx then
        name:SetText(profile.condition_groups[cond_group_idx].name)
    end
    name:SetCallback("OnEnterPressed", function(_, _, v)
        if not cond_group_idx then
            local cond_group = { id = group, name = v }
            table.insert(profile.condition_groups, cond_group)
            cond_group_idx = #profile.condition_groups
            UpdateMoveButtons()
            delete:SetDisabled(false)
            importexport:SetDisabled(false)
        else
            profile.condition_groups[cond_group_idx].name = v
        end
        update()
    end)
    cond_header:AddChild(name)

    movetop:SetImageSize(24, 24)
    movetop:SetUserData("cell", { alignV = "bottom" })
    movetop:SetCallback("OnClick", function()
        local tmp = table.remove(profile.condition_groups, cond_group_idx)
        table.insert(profile.condition_groups, 1, tmp)
        cond_group_idx = 1
        UpdateMoveButtons()
        update()
    end)
    addon.AddTooltip(movetop, L["Move to Top"])
    cond_header:AddChild(movetop)

    moveup:SetImageSize(24, 24)
    moveup:SetUserData("cell", { alignV = "bottom" })
    moveup:SetCallback("OnClick", function()
        local tmp = profile.condition_groups[cond_group_idx-1]
        profile.condition_groups[cond_group_idx-1] = profile.condition_groups[cond_group_idx]
        profile.condition_groups[cond_group_idx] = tmp
        cond_group_idx = cond_group_idx - 1
        UpdateMoveButtons()
        update()
    end)
    addon.AddTooltip(moveup, L["Move Up"])
    cond_header:AddChild(moveup)

    movedown:SetImageSize(24, 24)
    movedown:SetUserData("cell", { alignV = "bottom" })
    movedown:SetCallback("OnClick", function()
        local tmp = profile.condition_groups[cond_group_idx+1]
        profile.condition_groups[cond_group_idx+1] = profile.condition_groups[cond_group_idx]
        profile.condition_groups[cond_group_idx] = tmp
        cond_group_idx = cond_group_idx + 1
        UpdateMoveButtons()
        update()
    end)
    addon.AddTooltip(movedown, L["Move Down"])
    cond_header:AddChild(movedown)

    movebottom:SetImageSize(24, 24)
    movebottom:SetUserData("cell", { alignV = "bottom" })
    movebottom:SetCallback("OnClick", function()
        local tmp = table.remove(profile.condition_groups, cond_group_idx)
        table.insert(profile.condition_groups, tmp)
        cond_group_idx = #profile.condition_groups
        UpdateMoveButtons()
        update()
    end)
    addon.AddTooltip(movebottom, L["Move to Bottom"])
    cond_header:AddChild(movebottom)

    importexport:SetImageSize(24, 24)
    if group == "ALL" then
        importexport:SetDisabled(true)
        importexport:SetImage("Interface\\AddOns\\RotationMaster\\textures\\UI-FriendsList-Small-Disabled")
    else
        importexport:SetDisabled(false)
        importexport:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
    end
    importexport:SetUserData("cell", { alignV = "bottom" })
    importexport:SetCallback("OnClick", function()
        ImportExport(addon:listConditions(group), function(conds)
            if group == "SWITCH" then
                profile.switch_conditions = conds
            elseif group == "DEFAULT" then
                profile.other_conditions_order = conds
            elseif cond_group_idx then
                profile.condition_groups[cond_group_idx].conditions = conds
            end
            filter(nil)
        end)
    end)
    addon.AddTooltip(importexport, L["Import/Export"])
    cond_header:AddChild(importexport)

    delete:SetImageSize(24, 24)
    delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    delete:SetUserData("cell", { alignV = "bottom" })
    delete:SetDisabled(not cond_group_idx)
    delete:SetCallback("OnClick", function()
        table.remove(profile.condition_groups, cond_group_idx)
        update("ALL")
    end)
    addon.AddTooltip(delete, DELETE)
    cond_header:AddChild(delete)

    local search = AceGUI:Create("EditBox")
    search:SetLabel(L["Search"])
    search:SetFullWidth(true)
    search:DisableButton(true)
    search:SetCallback("OnTextChanged", function(_, _, v)
        filter(v)
    end)
    cond_header:AddChild(search)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function layout_bottom_window(frame, group, selected, update)
    local profile = addon.db.profile

    local function spacer(rs)
        local rv = AceGUI:Create("Label")
        rv:SetUserData("cell", { rowspan = rs })
        rv:SetFullWidth(true)
        return rv
    end

    frame:ReleaseChildren()
    frame:PauseLayout()

    local bottomheader = AceGUI:Create("Heading")
    bottomheader:SetText(L["Condition Options"])
    bottomheader:SetFullWidth(true)
    frame:AddChild(bottomheader)

    local grid = AceGUI:Create("SimpleGroup")
    grid:SetFullWidth(true)
    grid:SetLayout("Table")
    grid:SetUserData("table", { columns = { 180, 50, 40, 30, 30, 20, 230 } })
    frame:AddChild(grid)

    local switch = AceGUI:Create("CheckBox")
    switch:SetLabel(L["Switch Condition"])
    if selected then
        switch:SetValue(addon.index(profile.switch_conditions, selected) ~= nil)
        switch:SetDisabled(group == "SWITCH")
    else
        switch:SetValue(false)
        switch:SetDisabled(true)
    end
    switch:SetCallback("OnValueChanged", function(_, _, val)
        if val then
            table.insert(profile.switch_conditions, selected)
        else
            table.remove(profile.switch_conditions, addon.index(profile.switch_conditions, selected))
        end
    end)
    grid:AddChild(switch)

    local directional = AceGUI:Create("Directional")
    directional:SetDisabled(group == "ALL" or not selected)
    directional:DisableCenter(true)
    directional:SetUserData("cell", { rowspan = 2 })
    directional:SetCallback("OnClick", function(_, _, _, direction)
        local current_conds = addon:listConditions(group)
        local current_conds_idx = addon.index(current_conds, selected)

        local conds
        if group == "SWITCH" then
            conds = profile.switch_conditions
        elseif group == "DEFAULT" then
            conds = profile.other_conditions_order
        else
            for _,v in pairs(profile.condition_groups) do
                if group == v.id then
                    conds = v.conditions
                    break
                end
            end
        end
        local cond_idx = addon.index(conds, selected)

        local function repair_conds()
            if group == "SWITCH" then
                profile.switch_conditions = addon:listConditions("SWITCH")
                conds = profile.switch_conditions
            elseif group == "DEFAULT" then
                profile.other_conditions_order = addon:listConditions("DEFAULT")
                conds = profile.other_conditions_order
            else
                for _,v in pairs(profile.condition_groups) do
                    if group == v.id then
                        v.conditions = addon:listConditions(group)
                        conds = v.conditions
                        break
                    end
                end
            end

        end

        -- Repair condition index if necessary
        if not cond_idx then
            repair_conds()
            cond_idx = addon.index(conds, selected)
        end

        if cond_idx then
            local current_swap
            if direction == "UP" then
                if current_conds_idx > ENTRIES_PER_ROW then
                    current_swap = current_conds[current_conds_idx - ENTRIES_PER_ROW]
                end
            elseif direction == "LEFT" then
                if current_conds_idx % ENTRIES_PER_ROW ~= 1 and current_conds_idx > 1 then
                    current_swap = current_conds[current_conds_idx - 1]
                end
            elseif direction == "RIGHT" then
                if current_conds_idx % ENTRIES_PER_ROW ~= 0 and current_conds_idx < #current_conds then
                    current_swap = current_conds[current_conds_idx + 1]
                end
            elseif direction == "DOWN" then
                if current_conds_idx <= #current_conds - ENTRIES_PER_ROW then
                    current_swap = current_conds[current_conds_idx + ENTRIES_PER_ROW]
                end
            end
            if current_swap then
                local swap_idx = addon.index(conds, current_swap)
                if not swap_idx then
                    repair_conds()
                    swap_idx = addon.index(conds, current_swap)
                end
                if swap_idx then
                    conds[cond_idx] = conds[swap_idx]
                    conds[swap_idx] = selected
                end
            end
            update()
        end
    end)
    grid:AddChild(directional)

    grid:AddChild(spacer(2))

    local add = AceGUI:Create("Icon")
    add:SetImageSize(28, 28)
    add:SetUserData("cell", { alignV = "bottom" })
    add:SetImage("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
    add:SetCallback("OnClick", function()
        addon:condition_edit_box(function()
            update()
        end)
    end)
    addon.AddTooltip(add, ADD)
    grid:AddChild(add)

    local edit = AceGUI:Create("Icon")
    edit:SetImageSize(28, 28)
    edit:SetUserData("cell", { alignV = "bottom" })
    if not selected or addon.db.global.custom_conditions[selected] == nil then
        edit:SetImage("Interface\\AddOns\\RotationMaster\\textures\\UI-FriendsList-Large-Disabled")
        edit:SetDisabled(true)
    else
        edit:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Large-Up")
        edit:SetDisabled(false)
    end
    edit:SetCallback("OnClick", function()
        addon:condition_edit_box(function()
            update()
        end, selected, addon.db.global.custom_conditions[selected])
    end)
    addon.AddTooltip(edit, EDIT)
    grid:AddChild(edit)

    grid:AddChild(spacer(2))

    local group_sel = {}
    local group_sel_order = {}
    for _, v in pairs(profile.condition_groups) do
        group_sel[v.id] = v.name
        table.insert(group_sel_order, v.id)
    end
    group_sel["DEFAULT"] = L["Other"]
    table.insert(group_sel_order, "DEFAULT")

    local moveto = AceGUI:Create("Dropdown")
    moveto:SetLabel(L["Move To"])
    moveto:SetDisabled(not selected or group == "SWITCH")
    moveto:SetUserData("cell", { alignH = "right" })
    moveto.configure = function()
        moveto:SetList(group_sel, group_sel_order)
        if selected then
            if group == "ALL" or group == "SWITCH" then
                local cond_group = addon:findConditionGroup(selected)
                moveto:SetValue(cond_group)
                moveto:SetItemDisabled(cond_group, true)
            else
                moveto:SetValue(group)
                moveto:SetItemDisabled(group, true)
            end
        end
    end
    moveto:SetCallback("OnValueChanged", function(_, _, val)
        local selected_group
        if group == "ALL" or group == "SWITCH" then
            selected_group = addon:findConditionGroup(selected)
        else
            selected_group = group
        end
        if val ~= selected_group then
            moveto:SetItemDisabled(val, true)
            moveto:SetItemDisabled(selected_group, false)
            if selected_group == "DEFAULT" then
                local idx = addon.index(profile.other_conditions_order, selected)
                if idx then
                    table.remove(profile.other_conditions_order, idx)
                end
            end
            if val == "DEFAULT" then
                table.insert(profile.other_conditions_order, selected)
            end
            for _,v in pairs(profile.condition_groups) do
                if v.id == val then
                    table.insert(v.conditions, selected)
                elseif v.id == selected_group then
                    local idx = addon.index(v.conditions, selected)
                    if idx then
                        table.remove(v.conditions, idx)
                    end
                end
            end
            update()
        end
    end)
    grid:AddChild(moveto)

    local hidden = AceGUI:Create("CheckBox")
    hidden:SetLabel(L["Hidden"])
    if (group == "ALL" or group == "SWITCH") and selected and not special[selected] then
        hidden:SetValue(addon.index(profile.disabled_conditions, selected) ~= nil)
        hidden:SetDisabled(false)
    else
        hidden:SetValue(false)
        hidden:SetDisabled(true)
    end
    hidden:SetCallback("OnValueChanged", function(_, _, val)
        if val then
            table.insert(profile.disabled_conditions, selected)
        else
            table.remove(profile.disabled_conditions, addon.index(profile.hidden_conditions, selected))
        end
    end)
    grid:AddChild(hidden)

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(28, 28)
    delete:SetUserData("cell", { alignV = "top" })
    if not selected or addon.db.global.custom_conditions[selected] == nil then
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
        delete:SetDisabled(true)
    else
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        delete:SetDisabled(false)
    end
    delete:SetCallback("OnClick", function()
        addon:UnregisterCondition(selected)
        addon.db.global.custom_conditions[selected] = nil
        update()
    end)
    addon.AddTooltip(delete, DELETE)
    grid:AddChild(delete)

    local duplicate = AceGUI:Create("Icon")
    duplicate:SetImageSize(28, 28)
    duplicate:SetUserData("cell", { alignV = "bottom" })
    if not selected or addon.db.global.custom_conditions[selected] == nil then
        duplicate:SetImage("Interface\\AddOns\\RotationMaster\\textures\\UI-ChatIcon-Maximize-Disabled")
        duplicate:SetDisabled(true)
    else
        duplicate:SetImage("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up")
        duplicate:SetDisabled(false)
    end
    duplicate:SetCallback("OnClick", function()
        local newkey = selected .. "_" .. date("%Y%m%d%H%M%S")
        addon.db.global.custom_conditions[newkey] = deepcopy(addon.db.global.custom_conditions[selected])
        addon:register_custom_condition(newkey, addon.db.global.custom_conditions[newkey])
        update()
    end)
    addon.AddTooltip(duplicate, L["Duplicate"])
    grid:AddChild(duplicate)

    local tag = AceGUI:Create("Label")
    tag:SetFullWidth(true)
    tag:SetText(selected)
    tag:SetUserData("cell", { alignH = "right" })
    grid:AddChild(tag)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function display_condition_group(frame, group, update)
    frame:ReleaseChildren()
    frame:PauseLayout()

    local topwin = AceGUI:Create("SimpleGroup")
    topwin:SetLayout("List")
    topwin:SetFullWidth(true)
    frame:AddChild(topwin)

    local scrollwin = AceGUI:Create("ScrollFrame")
    scrollwin:SetLayout("List")
    scrollwin:SetFullWidth(true)
    scrollwin:SetHeight(365)
    frame:AddChild(scrollwin)

    local bottomwin = AceGUI:Create("SimpleGroup")
    bottomwin:SetLayout("List")
    bottomwin:SetFullWidth(true)
    frame:AddChild(bottomwin)

    local cond_selected
    local layout_conditions_func
    layout_bottom_window(bottomwin, group, cond_selected, layout_conditions_func)

    layout_conditions_func = function(filter)
        layout_conditions(scrollwin, group, cond_selected, filter, function(selected)
            cond_selected = selected
            layout_bottom_window(bottomwin, group, cond_selected, function()
                layout_conditions_func(filter)
            end)
        end)
    end
    layout_conditions_func(nil)

    layout_top_window(topwin, group, update, function(filter)
        layout_conditions_func(filter)
    end)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_conditions_options_help)
    help:SetTitle(L["Conditions"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 8)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:get_condition_group_list(empty)
    local profile = addon.db.profile

    local selects = {}
    local sorted = {}

    selects["ALL"] = ALL
    table.insert(sorted, "ALL")
    selects["SWITCH"] = color.CYAN .. L["Switch"] .. color.RESET
    table.insert(sorted, "SWITCH")
    for _,v in pairs(profile.condition_groups) do
        selects[v.id] = v.name
        table.insert(sorted, v.id)
    end
    selects["DEFAULT"] = L["Other"]
    table.insert(sorted, "DEFAULT")

    selects[""] = empty
    table.insert(sorted, "")

    return selects, sorted
end

function addon:create_condition_list(frame)
    frame:ReleaseChildren()
    frame:PauseLayout()

    local select = AceGUI:Create("DropdownGroup")
    select:SetTitle(addon.pretty_name .. " - " .. L["Conditions"])
    select:SetFullWidth(true)
    select:SetFullHeight(true)
    select:SetLayout("Fill")
    frame:AddChild(select)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("List")
    select:AddChild(group)

    local selected
    select:SetCallback("OnGroupSelected", function(_, _, val)
        if val == nil then
            selected = nil
            group:ReleaseChildren()
            group:DoLayout()
        elseif val ~= selected then
            if val == "" then
                selected = addon:uuid()
            else
                selected = val
            end

            display_condition_group(group, selected, function(newsel)
                local selects, sorted = self:get_condition_group_list(NEW)
                select:SetGroupList(selects, sorted)
                if selects[newsel or selected] then
                    select:SetGroup(newsel or selected)
                else
                    select:SetGroup("ALL")
                end
            end)
        end
    end)

    select.configure = function()
        local selects, sorted = self:get_condition_group_list(NEW)
        select:SetGroupList(selects, sorted)
        select:SetGroup("ALL")
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end