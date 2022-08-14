local _, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")

local error, pairs = error, pairs
local ceil, min = math.ceil, math.min

-- From utils
local cleanArray, deepcopy, wrap, HideOnEscape = addon.cleanArray, addon.deepcopy, addon.wrap, addon.HideOnEscape

--------------------------------
-- Common code
-------------------------------

local evaluateArray, evaluateSingle, printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle

local conditions = {}

local special = {}
special["DELETE"] = { desc = DELETE, icon = "Interface\\Icons\\Trade_Engineering" }
special["AND"] = { desc = L["AND"], icon = "Interface\\Icons\\Spell_ChargePositive" }
special["OR"] = { desc = L["OR"], icon = "Interface\\Icons\\Spell_ChargeNegative" }
special["NOT"] = { desc = L["NOT"], icon = "Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent" }

evaluateArray = function(operation, array, cache, start)
    if array ~= nil then
        for _, entry in pairs(array) do
            if entry ~= nil and entry.type ~= nil then
                local rv
                if entry.type == "AND" or entry.type == "OR" then
                    rv = evaluateArray(entry.type, entry.value, cache, start);
                else
                    rv = evaluateSingle(entry, cache, start)
                end

                if operation == "AND" and not rv then
                    return false
                elseif operation == "OR" and rv then
                    return true
                end
            end
        end
    end

    if operation == "AND" then
        return true
    elseif operation == "OR" then
        return false
    else
        error("Array evaluation with an operation other than AND or OR")
        return false
    end
end

evaluateSingle = function(value, cache, start)
    if value == nil or value.type == nil then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return evaluateArray(value.type, value.value, cache, start)
    elseif value.type == "NOT" then
        return not evaluateSingle(value.value, cache, start)
    elseif conditions[value.type] ~= nil then
        local rv = false
        -- condition is FALSE if the condition is INVALID.
        if conditions[value.type].valid(addon.currentSpec, value) then
            rv = conditions[value.type].evaluate(value, cache, start)
        end
        -- Extra protection so we don't evaluate the print realtime
        if addon.db.profile.verbose then
            addon:verbose("COND: %s = %s", conditions[value.type].print(addon.currentSpec, value), (rv and "true" or "false"))
        end
        return rv
    else
        error("Unrecognized condition for evaluation")
        return false
    end
end

printArray = function(operation, array, spec)
    if array == nil then
        return ""
    end

    local rv = "("
    local first = true

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            if first then
                first = false
            else
                rv = rv .. " " .. operation .. " "
            end

            if entry.type == "AND" or entry.type == "OR" then
                rv = rv .. printArray(entry.type, entry.value, spec)
            else
                rv = rv .. printSingle(entry, spec)
            end
        end
    end

    rv = rv .. ")"

    return rv
end

printSingle = function(value, spec)
    if value == nil or value.type == nil then
        return ""
    end

    if value.type == "AND" or value.type == "OR" then
        return  printArray(value.type, value.value, spec)
    elseif value.type == "NOT" then
        return "NOT " .. printSingle(value.value, spec)
    elseif conditions[value.type] ~= nil then
        return conditions[value.type].print(spec, value)
    else
        return L["<INVALID CONDITION>"]
    end
end

validateArray = function(_, array, spec)
    if array == nil then
        return true
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = validateArray(entry.type, entry.value, spec)
            else
                rv = validateSingle(entry, spec)
            end
            if not rv then
                return false
            end
        end
    end

    return true
end

validateSingle = function(value, spec)
    if value == nil or value.type == nil then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return validateArray(value.type, value.value, spec)
    elseif value.type == "NOT" then
        return validateSingle(value.value, spec)
    elseif conditions[value.type] ~= nil then
        return conditions[value.type].valid(spec, value)
    else
        return false
    end
end

usefulArray = function(_, array)
    if array == nil then
        return false
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = usefulArray(entry.type, entry.value)
            else
                rv = usefulSingle(entry)
            end
            if rv then
                return true
            end
        end
    end

    return false
end

usefulSingle = function(value)
    if value == nil or value.type == nil then
        return false
    end

    if value.type == "AND" or value.type == "OR" then
        return usefulArray(value.type, value.value)
    elseif value.type == "NOT" then
        return usefulSingle(value.value)
    elseif conditions[value.type] ~= nil then
        return true
    else
        return false
    end
end

local function LayoutConditionTab(top, frame, funcs, value, selected, index, group, filter)
    local profile = addon.db.profile

    frame:ReleaseChildren()
    frame:PauseLayout()

    local selectedIcon

    local function layoutIcon(cond, icon, desc, selected, onclick)
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
        description:SetCallback("OnClick", function (widget)
            onclick(widget, cond)
            top:Hide()
        end)

        if selected then
            selectedIcon = description
            addon:ApplyCustomGlow({ type = "pixel" }, selectedIcon.frame, nil, { r = 0, g = 1, b = 0, a = 1 }, 0, 3)
            description:SetCallback("OnRelease", function()
                if selectedIcon then
                    addon:HideGlow(selectedIcon.frame)
                end
            end)
        end

        return description
    end

    local special_act = {}
    special_act["DELETE"] = layoutIcon("DELETE", special["DELETE"].icon, special["DELETE"].desc, false, function()
        if selected == "NOT" and value.value ~= nil then
            local subvalue = value.value
            cleanArray(value, { "type" })
            for k,v in pairs(subvalue) do
                value[k] = v
            end
        else
            cleanArray(value, { "type" })
            value.type = nil
        end
    end)

    special_act["AND"] = layoutIcon("AND", special["AND"].icon, special["AND"].desc, selected == "AND", function()
        local subvalue
        if selected ~= "AND" and selected ~= "OR" then
            if value ~= nil and value.type ~= nil then
                subvalue = { deepcopy(value) }
            end
            cleanArray(value, { "type" })
        end
        value.type = "AND"
        if subvalue ~= nil then
            value.value = subvalue
        end
    end)

    special_act["OR"] = layoutIcon("OR", special["OR"].icon, special["OR"].desc, selected == "OR", function()
        local subvalue
        if selected ~= "AND" and selected ~= "OR" then
            if value ~= nil and value.type ~= nil then
                subvalue = { deepcopy(value) }
            end
            cleanArray(value, { "type" })
        end
        value.type = "OR"
        if subvalue ~= nil then
            value.value = subvalue
        end
    end)

    special_act["NOT"] = layoutIcon("NOT", special["NOT"].icon, special["NOT"].desc, selected == "NOT", function()
        local subvalue
        if selected ~= "NOT" then
            if value ~= nil and value.type ~= nil then
                subvalue = deepcopy(value)
            end
            cleanArray(value, { "type" })
        end
        value.type = "NOT"
        if subvalue ~= nil then
            value.value = subvalue
        elseif selected ~= "NOT" then
            value.value = { type = nil }
        end
    end)

    local cond_selected = function(_, cond)
        if selected ~= cond then
            cleanArray(value, { "type" })
        end
        value.type = cond
    end

    for _, cond in pairs(funcs:list(index and index > 0 and group or "SWITCH")) do
        if special_act[cond] then
            local desc = special[cond].desc
            if not filter or string.find(string.lower(desc), string.lower(filter)) then
                frame:AddChild(special_act[cond])
            end
        elseif conditions[cond] then
            local icon, desc = funcs:describe(cond)
            if not filter or string.find(string.lower(desc), string.lower(filter)) then
                local action = layoutIcon(cond, icon, desc, selected == cond, cond_selected)
                frame:AddChild(action)
            end
        end
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function ChangeConditionType(parent, _, ...)
    local profile = addon.db.profile
    local top = parent:GetUserData("top")
    local value = parent:GetUserData("value")
    local spec = top:GetUserData("spec")
    local root = top:GetUserData("root")
    local funcs = top:GetUserData("funcs")
    local index = top:GetUserData("index")

    -- Don't let the notifications happen, or the top screen destroy itself on hide.
    top:SetCallback("OnClose", function() end)
    top:Hide()

    local selected
    if (value ~= nil and value.type ~= nil) then
        selected = value.type
    end

    local frame = AceGUI:Create("Window")
    --local frame = AceGUI:Create("Frame")
    frame:PauseLayout()
    frame:SetLayout("Flow")
    frame:SetTitle(L["Condition Type"])
    local DEFAULT_COLUMNS = 5
    local DEFAULT_ROWS = 5

    local group_count
    if not index or index == 0 then
        group_count = addon.tablelength(funcs:list("SWITCH"))
    else
        for _,v in pairs(profile.condition_groups) do
            if v.conditions then
                local count = addon.tablelength(v.conditions)
                if not group_count or group_count < count then
                    group_count = count
                end
            end
        end
        local count = addon.tablelength(funcs:list("DEFAULT"))
        if not group_count or group_count < count then
            group_count = count
        end
    end

    frame:SetWidth((index and index > 0 and 70 or 50) + (DEFAULT_COLUMNS * 100))
    local rows = ceil(group_count / DEFAULT_COLUMNS)
    frame:SetHeight((index and index > 0 and 90 or 46) + min(rows * 70, DEFAULT_ROWS * 70))
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        addon.LayoutConditionFrame(top)
        top:SetStatusText(funcs:print(root, spec))
        top:Show()
    end)
    HideOnEscape(frame)

    local header = AceGUI:Create("SimpleGroup")
    header:SetFullWidth(true)
    header:SetLayout("Table")
    header:SetUserData("table", { columns = { 1, 250 } })
    frame:AddChild(header)

    local scrollwin = AceGUI:Create("ScrollFrame")
    scrollwin:SetFullHeight(true)
    scrollwin:SetFullWidth(true)
    scrollwin:SetLayout("Flow")
    frame:AddChild(scrollwin)

    local cond_group
    if index and index > 0 then
        local group_sel = {}
        local group_sel_order = {}
        for _, v in pairs(profile.condition_groups) do
            group_sel[v.id] = v.name
            table.insert(group_sel_order, v.id)
        end
        group_sel["DEFAULT"] = L["Other"]
        table.insert(group_sel_order, "DEFAULT")

        cond_group = addon:findConditionGroup(selected)
        local group = AceGUI:Create("Dropdown")
        --group:SetLabel("Move To")
        group.configure = function()
            group:SetList(group_sel, group_sel_order)
            group:SetValue(cond_group or "DEFAULT")
        end
        group:SetCallback("OnValueChanged", function(_, _, val)
            cond_group = val
            LayoutConditionTab(frame, scrollwin, funcs, value, selected, index, val, nil)
        end)
        header:AddChild(group)

    else
        local function spacer()
            local rv = AceGUI:Create("Label")
            rv:SetFullWidth(true)
            return rv
        end

        header:AddChild(spacer())
    end

    local search = AceGUI:Create("EditBox")
    -- search:SetLabel("Search")
    search:SetFullWidth(true)
    search:DisableButton(true)
    search:SetCallback("OnTextChanged", function(_, _, v)
        LayoutConditionTab(frame, scrollwin, funcs, value, selected, index, cond_group, v)
    end)
    header:AddChild(search)

    LayoutConditionTab(frame, scrollwin, funcs, value, selected, index, cond_group, nil)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function ActionGroup(parent, value, idx, array)
    local top = parent:GetUserData("top")
    local spec = top:GetUserData("spec")
    local funcs = top:GetUserData("funcs")

    local group = AceGUI:Create("InlineGroup")
    group:SetLayout("Table")
    group:SetFullWidth(true)
    group:SetUserData("top", top)

    if array then
        group:SetUserData("table", { columns = { 24, 44, 1 } })

        local movegroup = AceGUI:Create("SimpleGroup")
        movegroup:SetLayout("Table")
        movegroup:SetUserData("table", { columns = { 24 } })
        movegroup:SetHeight(68)
        movegroup:SetUserData("cell", { alignV = "middle" })
        group:AddChild(movegroup)

        local moveup = AceGUI:Create("InteractiveLabel")
        --moveup:SetUserData("cell", { alignV = "bottom" })
        if idx ~= nil and idx > 1 and value.type ~= nil then
            moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
            moveup:SetDisabled(false)
        else
            moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
            moveup:SetDisabled(true)
        end
        moveup:SetImageSize(24, 24)
        moveup:SetCallback("OnClick", function()
            local tmp = array[idx-1]
            array[idx-1] = array[idx]
            array[idx] = tmp
            addon.LayoutConditionFrame(top)
        end)
        addon.AddTooltip(moveup, L["Move Up"])
        movegroup:AddChild(moveup)

        local movedown = AceGUI:Create("InteractiveLabel")
        --movedown:SetUserData("cell", { alignV = "top" })
        if idx ~= nil and idx < #array - 1 and value.type ~= nil then
            movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            movedown:SetDisabled(false)
        else
            movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
            movedown:SetDisabled(true)
        end
        movedown:SetImageSize(24, 24)
        movedown:SetCallback("OnClick", function()
            local tmp = array[idx+1]
            array[idx+1] = array[idx]
            array[idx] = tmp
            addon.LayoutConditionFrame(top)
        end)
        addon.AddTooltip(movedown, L["Move Down"])
        movegroup:AddChild(movedown)
    else
        group:SetUserData("table", { columns = { 44, 1 } })
    end

    local actionicon = AceGUI:Create("Icon")
    actionicon:SetWidth(44)
    actionicon:SetImageSize(36, 36)
    actionicon:SetUserData("top", top)
    actionicon:SetUserData("value", value)
    actionicon:SetCallback("OnClick", ChangeConditionType)

    local description, helpfunc
    if (value == nil or value.type == nil) then
        actionicon:SetImage("Interface\\Icons\\Trade_Engineering")
        addon.AddTooltip(actionicon, L["Please Choose ..."])
    elseif (value.type == "AND") then
        actionicon:SetImage("Interface\\Icons\\Spell_ChargePositive")
        description = L["AND"]
        helpfunc = addon.layout_condition_and_help
    elseif (value.type == "OR") then
        actionicon:SetImage("Interface\\Icons\\Spell_ChargeNegative")
        description = L["OR"]
        helpfunc = addon.layout_condition_or_help
    elseif (value.type == "NOT") then
        actionicon:SetImage("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
        description = L["NOT"]
        helpfunc = addon.layout_condition_not_help
    else
        local icon
        icon, description, helpfunc = funcs:describe(value.type)
        if (icon == nil) then
            actionicon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        else
            actionicon:SetImage(icon)
        end
    end

    group:AddChild(actionicon)

    if description then
        group:SetTitle(description)
        addon.AddTooltip(actionicon, description)
    end

    if (value ~= nil and value.type ~= nil) then
        local arraygroup = AceGUI:Create("SimpleGroup")
        arraygroup:SetFullWidth(true)
        arraygroup:SetLayout("Flow")
        arraygroup:SetUserData("top", top)

        if helpfunc and description then
            local addgroup = arraygroup
            local help = AceGUI:Create("Help")
            help:SetLayout(helpfunc)
            help:SetTitle(description)
            help:SetTooltip(description .. " " .. L["Help"])
            help:SetFrameSize(400, 300)
            addgroup:AddChild(help)
            local func = addgroup.LayoutFunc
            addgroup.LayoutFunc = function (content, children)
                func(content, children)
                help:SetPoint("TOPRIGHT", 8, 8)
            end
        end

        if (value.type == "AND" or value.type == "OR") then
            if (value.value == nil) then
                value.value = { { type = nil } }
            end

            local arraysz = #value.value
            if value.value[arraysz].type ~= nil then
                table.insert(value.value, { type = nil })
                arraysz = arraysz + 1
            end

            local i = 1
            while i <= arraysz do
                -- Clean out deleted items in the middle of the list.
                while i < arraysz and (value.value[i] == nil or value.value[i].type == nil) do
                    table.remove(value.value, i)
                    arraysz = arraysz - 1
                end

                ActionGroup(arraygroup, value.value[i], i, value.value)
                i = i + 1
            end

        elseif (value.type == "NOT") then
            ActionGroup(arraygroup, value.value)
        else
            funcs:widget(arraygroup, spec, value)
        end

        group:AddChild(arraygroup)
    end

    parent:AddChild(group)
end

addon.LayoutConditionFrame = function(frame)
    local root = frame:GetUserData("root")
    local funcs = frame:GetUserData("funcs")

    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        if funcs.close ~= nil then
            funcs.close()
        end
        addon:UpdateAutoSwitch()
        addon:SwitchRotation()
    end)

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("ScrollFrame")

    group:SetLayout("Flow")
    group:SetUserData("top", frame)
    ActionGroup(group, root)
    frame:AddChild(group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

--------------------------------
--  Dealing with Conditionals
-------------------------------

function addon:RegisterCondition(tag, array)
    conditions[tag] = array
end

function addon:EditCondition(index, spec, value, callback)
    local funcs = {
        print = addon.printCondition,
        validate = addon.validateCondition,
        list = addon.listConditions,
        describe = addon.describeCondition,
        widget = addon.widgetCondition,
        close = callback,
    }

    local frame = AceGUI:Create("Frame")

    if index and index > 0 then
        frame:SetTitle(string.format(L["Edit Condition #%d"], index))
    else
        frame:SetTitle(L["Edit Condition"])
    end
    frame:SetStatusText(funcs:print(value, spec))
    frame:SetUserData("index", index)
    frame:SetUserData("spec", spec)
    frame:SetUserData("root", value)
    frame:SetUserData("funcs", funcs)
    frame:SetLayout("Fill")

    addon.LayoutConditionFrame(frame)
    HideOnEscape(frame)
end

function addon:evaluateCondition(value)
    local cache = {}
    local start = GetTime()
    return evaluateSingle(value, cache, start)
end

function addon:printCondition(value, spec)
    return printSingle(value, spec)
end

function addon:validateCondition(value, spec)
    return validateSingle(value, spec)
end

function addon:usefulCondition(value)
    return usefulSingle(value)
end

function addon:findConditionGroup(value)
    if not value then
        return nil
    end

    local profile = addon.db.profile
    for _, v in pairs(profile.condition_groups) do
        if v.conditions then
            for _, cond in pairs(v.conditions) do
                if value == cond then
                    return v.id
                end
            end
        end
    end

    return "DEFAULT"
end

function addon:listConditions(group, nohide)
    local profile = addon.db.profile

    local special = {}
    special["DELETE"] = true
    special["AND"] = true
    special["OR"] = true
    special["NOT"] = true

    local rv = {}
    if group == "SWITCH" then
        for _, cond in pairs(profile.switch_conditions) do
            if special[cond] then
                table.insert(rv, cond)
            elseif conditions[cond] then
                table.insert(rv, cond)
            end
        end
        for cond,_ in pairs(special) do
            if not addon.index(rv, cond) then
                table.insert(rv, cond)
            end
        end
    else
        local skipped = {}
        for _, v in pairs(profile.condition_groups) do
            if v.conditions then
                if group == "DEFAULT" then
                    for _, cond in pairs(v.conditions) do
                        skipped[cond] = true
                    end
                elseif group == v.id or group == "ALL" then
                    for _, cond in pairs(v.conditions) do
                        if special[cond] then
                            table.insert(rv, cond)
                        elseif conditions[cond] then
                            table.insert(rv, cond)
                        end
                        skipped[cond] = true
                    end
                end
            end
        end
        if group == "DEFAULT" or group == "ALL" then
            for _, cond in pairs(profile.other_conditions_order) do
                if not (group == "ALL" and skipped[cond]) then
                    if special[cond] then
                        table.insert(rv, cond)
                    elseif conditions[cond] then
                        table.insert(rv, cond)
                    end
                    skipped[cond] = true
                end
            end
            for cond,_ in pairs(special) do
                if not skipped[cond] then
                    table.insert(rv, cond)
                end
            end
            for cond,_ in pairs(conditions) do
                if not skipped[cond] and (nohide or not addon.index(profile.disabled_conditions, cond)) then
                    table.insert(rv, cond)
                end
            end
        end
    end

    return rv
end

function addon:describeCondition(type)
    if (conditions[type] == nil) then
        return nil, nil
    end
    return conditions[type].icon, conditions[type].description, conditions[type].help
end

function addon:widgetCondition(parent, spec, value)
    if value ~= nil and value.type ~= nil and conditions[value.type] ~= nil and conditions[value.type].widget ~= nil then
        conditions[value.type].widget(parent, spec, value)
    end
end