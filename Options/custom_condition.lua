local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")

local HideOnEscape, deepcopy, uuid = addon.HideOnEscape, addon.deepcopy, addon.uuid

local function_signatures = {
    valid = "function(spec, value)",
    evaluate = "function(value, cache, evalStart)",
    print = "function(spec, value)",
    widget = "function(parent, spec, value)",
    help = "function(frame)",
}

local empty_condition = {
    description = "",
    icon = "Interface\\Icons\\Inv_misc_questionmark",
    valid = [[
-- Validate that the condition has all required values set and they are in
-- acceptable bounds.  This does not indicate if the condition is true or not.
-- Params:
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
-- Return: true if the condition is valid

return true
]],
    evaluate = [[
-- Evaluate the condition at runtime, and let us know if the current situation
-- makes this condition pass.
-- Params:
--    value - The storage for this condition (ie. where it's parameters are stored).
--    cache - A cache for this evaluation run (it is reset every evaluation cycle).
--            You can also use addon.combatCache (only reset when going out of combat)
--            or addon.longtermCache (only reset when your skills are updated).
--    evalStart - The timestamp (GetTime()) of when this evaluation cycle started.
-- Return: true if the condition passes

return true
]],
    print = [[
-- Create a printable string that describes this condition in words.
-- Params:
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
-- Return: A string that describes this condition

return ''
]],
    widget = [[
-- Create the widgets required to configure this condition.
-- Params:
--    parent - A bounding box that will contain this condition's widgets.
--    spec - The talent specialization in use (as a number).
--    value - The storage for this condition (ie. where it's parameters are stored).
local AceGUI = LibStub("AceGUI-3.0")
local top = parent:GetUserData("top")
local root = top:GetUserData("root")
local funcs = top:GetUserData("funcs")

]],
    help = [[
-- Create the required help information for this condition
-- Params:
--    frame - The frame the help widgets will be layed out in.

]],
}

local function open_icon_window(parent, update)
    parent:SetCallback("OnClose", function() end)
    parent:Hide()

    local frame = AceGUI:Create("Window")
    frame:SetTitle(L["Select Icon"])
    frame:SetLayout("table")
    frame:SetUserData("table", { columns = { 44, 1, 44 } })
    frame:SetWidth(470)
    frame:SetHeight(440)
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        parent:Show()
    end)
    frame:PauseLayout()
    HideOnEscape(frame)

    local prev = AceGUI:Create("Icon")
    prev:SetImageSize(44, 44)
    prev:SetImage("Interface\\BUTTONS\\UI-SpellbookIcon-PrevPage-Up")
    prev:SetUserData("cell", { alignV = "center" })
    frame:AddChild(prev)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullHeight(true)
    group:SetFullWidth(true)
    group:SetLayout("Flow")
    frame:AddChild(group)

    local next = AceGUI:Create("Icon")
    next:SetImageSize(44, 44)
    next:SetImage("Interface\\BUTTONS\\UI-SpellbookIcon-NextPage-Up")
    next:SetUserData("cell", { alignV = "center" })
    frame:AddChild(next)

    local icons = GetMacroIcons()
    local itemicons = GetMacroItemIcons()
    for i=1,#itemicons do
        table.insert(icons, itemicons[i])
    end

    local function displayIcons(offs, count)
        group:ReleaseChildren()
        group:PauseLayout()

        for i=offs,offs + count - 1 do
            if i <= #icons then
                local icon = AceGUI:Create("Icon")
                icon:SetImage(icons[i])
                icon:SetImageSize(36, 36)
                icon:SetWidth(44)
                icon:SetCallback("OnClick", function()
                    update(icons[i])
                    frame:Release()
                end)
                group:AddChild(icon)
            end
        end

        addon:configure_frame(group)
        group:ResumeLayout()
        group:DoLayout()
    end

    local offs = 1
    local ipp = 64
    prev:SetDisabled(offs == 1)
    prev:SetCallback("OnClick", function()
        offs = math.max(offs - ipp, 1)
        prev:SetDisabled(offs == 1)
        next:SetDisabled(offs + ipp > #icons)
        displayIcons(offs, ipp)
    end)

    next:SetDisabled(offs + ipp > #icons)
    next:SetCallback("OnClick", function()
        if offs + ipp <= #icons then
            offs = offs + ipp
            prev:SetDisabled(offs == 1)
            next:SetDisabled(offs + ipp > #icons)
            displayIcons(offs, ipp)
        end
    end)
    displayIcons(offs, ipp)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end


local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetWidth(width)
    return rv
end

local function compile_function(sel, val)
    local funcid = uuid()
    local str = string.format([[
_G.%s.funcDeserialize["%s"] = %s
local addon = _G.%s
%s
end
]], addon.name, funcid, function_signatures[sel], addon.name, val)
    local comp = loadstring(str)
    if not comp then
        return nil
    end

    comp()
    local rv = addon.funcDeserialize[funcid]
    addon.funcDeserialize[funcid] = nil
    return rv
end

function addon:register_custom_condition(key, condition)
    local newcond = { description = condition.description, icon = condition.icon }

    for field, _ in pairs(function_signatures) do
        local func = compile_function(field, condition[field])
        if not func then
            return false
        end
        newcond[field] = func
    end

    addon:RegisterCondition(key, newcond)
    return true
end

function addon:condition_edit_box(update, key, condition)
    local frame = AceGUI:Create("Window")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetTitle(L["Edit Condition"])
    frame:EnableResize(false)
    HideOnEscape(frame)

    frame:PauseLayout()

    if not condition then
        condition = deepcopy(empty_condition)
    end

    local update_save_state

    local top_group = AceGUI:Create("SimpleGroup")
    top_group:SetFullWidth(true)
    top_group:SetLayout("Table")
    top_group:SetUserData("table", { columns = { 150, 1, 42 } })

    local key_widget = AceGUI:Create("EditBox")
    key_widget:SetLabel(L["Key"])
    key_widget:SetFullWidth(true)
    key_widget:SetDisabled(key ~= nil and key ~= '')
    key_widget:SetText(key)
    key_widget:SetCallback("OnTextChanged", function(_, _, val)
        key_widget:DisableButton(val == nil or val == '' or addon:describeCondition(val) ~= nil)
        update_save_state()
    end)
    key_widget:SetCallback("OnEnterPressed", function(_, _, val)
        key = val
        update_save_state()
    end)
    top_group:AddChild(key_widget)

    local description = AceGUI:Create("EditBox")
    description:SetLabel(L["Description"])
    description:SetText(condition.description)
    description:SetFullWidth(true)
    description:SetCallback("OnTextChanged", function(_, _, val)
        description:DisableButton(val == nil or val == '')
        update_save_state()
    end)
    description:SetCallback("OnEnterPressed", function(_, _, val)
        condition.description = val
        update_save_state()
    end)
    top_group:AddChild(description)

    local icon = AceGUI:Create("Icon")
    icon:SetImage(condition.icon)
    icon:SetImageSize(36, 36)
    icon:SetCallback("OnClick", function()
        open_icon_window(frame, function(v)
            condition.icon = v
            icon:SetImage(v)
        end)
    end)
    top_group:AddChild(icon)

    frame:AddChild(top_group)

    local code_tabs = {
        { value = "valid", text = L["Validity Function"] },
        { value = "evaluate", text = L["Evaluation Function"] },
        { value = "print", text = L["Print Function"] },
        { value = "widget", text = L["Widget Function"] },
        { value = "help", text = L["Help Function"] },
    }

    local last_selected
    local live_content = {}
    local live_cursor = {}
    for _,ent in pairs(code_tabs) do
        live_content[ent.value] = condition[ent.value]
    end

    local editbox = AceGUI:Create("LuaEditBox")
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    editbox:SetLabel("")
    editbox:SetNumLines(20)

    local code_group = AceGUI:Create("TabGroup")
    code_group:SetFullWidth(true)
    code_group:SetFullHeight(true)
    code_group:SetLayout("List")
    code_group:SetTabs(code_tabs)
    code_group:SetCallback("OnGroupSelected", function(_, _, sel)
        if last_selected then
            live_content[last_selected] = editbox:GetText()
            live_cursor[last_selected] = editbox:GetCursorPosition()
        end
        editbox:SetLabel(function_signatures[sel])
        editbox:SetText(live_content[sel])
        if live_cursor[sel] then
            editbox:SetCursorPosition(live_cursor[sel])
        end
        editbox:DisableButton(live_content[sel] == condition[sel])

        editbox:SetCallback("OnTextChanged", function(_, _, val)
            local func = compile_function(sel, val)
            editbox:DisableButton(func == nil)
            update_save_state()
        end)
        editbox:SetCallback("OnEnterPressed", function(_, _, val)
            condition[sel] = val
            update_save_state()
        end)
        last_selected = sel
    end)

    code_group:SelectTab("valid")
    code_group:AddChild(editbox)
    frame:AddChild(code_group)

    local bottom_group = AceGUI:Create("SimpleGroup")
    bottom_group:SetFullWidth(true)
    bottom_group:SetLayout("Table")
    bottom_group:SetUserData("table", { columns = { 1, 150 } })

    bottom_group:AddChild(spacer(1))

    local save = AceGUI:Create("Button")
    save:SetDisabled(key == nil or key == '' or condition.description == nil or condition.description == '')
    save:SetText((key ~= nil and key ~= '') and SAVE or ADD)
    save:SetCallback("OnClick", function()
        if addon:register_custom_condition(key, condition) then
            addon.db.global.custom_conditions[key] = condition
        end
        update(key)
        frame:Release()
    end)

    update_save_state = function()
        local disabled = false
        if key == nil or key == '' then disabled = true end
        if condition.description == nil or condition.description == '' then disabled = true end
        if key_widget:GetText() ~= key or description:GetText() ~= condition.description then disabled = true end
        for field, _ in pairs(function_signatures) do
            if last_selected == field then
                if editbox:GetText() ~= condition[field] then disabled = true end
            else
                if live_content[field] ~= condition[field] then disabled = true end
            end
        end

        save:SetDisabled(disabled)
    end

    bottom_group:AddChild(save)
    frame:AddChild(bottom_group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end