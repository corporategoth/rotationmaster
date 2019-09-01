local addon_name, addon = ...

local _G = _G
local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")

local assert, error, tostring, tonumber, pairs
    = assert, error, tostring, tonumber, pairs

local floor = math.floor

-- From constants
local operators, units, unitsPossessive, classes, roles, debufftypes, zonepvp, instances, totems =
        addon.operators, addon.units, addon.unitsPossessive, addon.classes, addon.roles, addon.debufftypes,
        addon.zonepvp, addon.instances, addon.totems

-- From utils
local compare, compareString, nullable, keys, tomap, has, is, isin, cleanArray, deepcopy, getCached, HideOnEscape =
        addon.compare, addon.compareString, addon.nullable, addon.keys, addon.tomap, addon.has,
        addon.is, addon.isin, addon.cleanArray, addon.deepcopy, addon.getCached, addon.HideOnEscape

--------------------------------
-- Common code
-------------------------------

local evaluateArray, evaluateSingle, printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle
local LayoutFrame

evaluateArray = function(operation, array, conditions, cache, start)
    if array ~= nil then
        for idx, entry in pairs(array) do
            if entry ~= nil and entry.type ~= nil then
                local rv
                if entry.type == "AND" or entry.type == "OR" then
                    rv = evaluateArray(entry.type, entry.value, conditions, cache, start);
                else
                    rv = evaluateSingle(entry, conditions, cache, start)
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

evaluateSingle = function(value, conditions, cache, start)
    if value == nil or value.type == nil then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return evaluateArray(value.type, value.value, conditions, cache, start)
    elseif value.type == "NOT" then
        return not evaluateSingle(value.value, conditions, cache, start)
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

printArray = function(operation, array, conditions, spec)
    if array == nil then
        return ""
    end

    local rv = "("
    local first = true

    for idx, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            if first then
                first = false
            else
                rv = rv .. " " .. operation .. " "
            end

            if entry.type == "AND" or entry.type == "OR" then
                rv = rv .. printArray(entry.type, entry.value, conditions, spec)
            else
                rv = rv .. printSingle(entry, conditions, spec)
            end
        end
    end

    rv = rv .. ")"

    return rv
end

printSingle = function(value, conditions, spec)
    if value == nil or value.type == nil then
        return ""
    end

    if value.type == "AND" or value.type == "OR" then
        return  printArray(value.type, value.value, conditions, spec)
    elseif value.type == "NOT" then
        return "NOT " .. printSingle(value.value, conditions, spec)
    elseif conditions[value.type] ~= nil then
        return conditions[value.type].print(spec, value)
    else
        return L["<INVALID CONDITION>"]
    end
end

validateArray = function(operation, array, conditions, spec)
    if array == nil then
        return true
    end

    for idx, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = validateArray(entry.type, entry.value, conditions, spec)
            else
                rv = validateSingle(entry, conditions, spec)
            end
            if not rv then
                return false
            end
        end
    end

    return true
end

validateSingle = function(value, conditions, spec)
    if value == nil or value.type == nil then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return validateArray(value.type, value.value, conditions, spec)
    elseif value.type == "NOT" then
        return validateSingle(value.value, conditions, spec)
    elseif conditions[value.type] ~= nil then
        return conditions[value.type].valid(spec, value)
    else
        return false
    end
end

usefulArray = function(operation, array, conditions)
    if array == nil then
        return false
    end

    for idx, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = usefulArray(entry.type, entry.value, conditions)
            else
                rv = usefulSingle(entry, conditions)
            end
            if rv then
                return true
            end
        end
    end

    return false
end

usefulSingle = function(value, conditions)
    if value == nil or value.type == nil then
        return false
    end

    if value.type == "AND" or value.type == "OR" then
        return usefulArray(value.type, value.value, conditions)
    elseif value.type == "NOT" then
        return usefulSingle(value.value, conditions)
    elseif conditions[value.type] ~= nil then
        return true
    else
        return false
    end
end

local function ChangeConditionType(parent, event, ...)
    local top = parent:GetUserData("top")
    local value = parent:GetUserData("value")
    local index = top:GetUserData("index")
    local spec = top:GetUserData("spec")
    local root = top:GetUserData("root")
    local funcs = top:GetUserData("funcs")

    -- Don't let the notifications happen, or the top screen destroy itself on hide.
    top:SetCallback("OnClose", function(widget) end)
    top:Hide()

    local conditions = funcs:list()

    local selected, selectedIcon
    local selectedDesc = L["Please Choose ..."]
    if (value ~= nil and value.type ~= nil) then
        selected = value.type
    end

    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    local framegroup = AceGUI:Create("SimpleGroup")
    frame:AddChild(framegroup)
    local deleteicon = AceGUI:Create("Icon")
    framegroup:AddChild(deleteicon)
    local andicon = AceGUI:Create("Icon")
    framegroup:AddChild(andicon)
    local oricon = AceGUI:Create("Icon")
    framegroup:AddChild(oricon)
    local noticon = AceGUI:Create("Icon")
    framegroup:AddChild(noticon)

    frame:SetTitle(L["Condition Type"])
    frame:SetCallback("OnClose", function(widget)
        if selectedIcon then
            ActionButton_HideOverlayGlow(selectedIcon.frame)
        end
        AceGUI:Release(widget)
        LayoutFrame(top)
        top:Show()
    end)

    frame:SetWidth(8 * 44 + 40)
    local rows = math.floor((#conditions + 4) / 8) + (((#conditions + 4) % 8 ~= 0) and 1 or 0)
    frame:SetHeight(rows * 49 + 72)
    frame:SetLayout("Flow")
    HideOnEscape(frame)

    framegroup:SetFullWidth(true)
    framegroup:SetFullHeight(true)
    framegroup:SetLayout("Flow")

    deleteicon:SetImage("Interface\\Icons\\Trade_Engineering")
    deleteicon:SetImageSize(36, 36)
    deleteicon:SetWidth(44)
    deleteicon:SetCallback("OnClick", function (widget)
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
        frame:Hide()
    end)
    deleteicon:SetCallback("OnEnter", function () frame:SetStatusText(DELETE) end)
    deleteicon:SetCallback("OnLeave", function () frame:SetStatusText(selectedDesc) end)

    andicon:SetImage("Interface\\Icons\\Spell_ChargePositive")
    andicon:SetImageSize(36, 36)
    andicon:SetWidth(44)
    andicon:SetCallback("OnClick", function (widget)
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
        frame:Hide()
    end)
    andicon:SetCallback("OnEnter", function () frame:SetStatusText(L["AND"]) end)
    andicon:SetCallback("OnLeave", function () frame:SetStatusText(selectedDesc) end)
    if selected == "AND" then
        selectedDesc = L["AND"]
        selectedIcon = andicon
    end

    oricon:SetImage("Interface\\Icons\\Spell_ChargeNegative")
    oricon:SetImageSize(36, 36)
    oricon:SetWidth(44)
    oricon:SetCallback("OnClick", function (widget)
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
        frame:Hide()
    end)
    oricon:SetCallback("OnEnter", function () frame:SetStatusText(L["OR"]) end)
    oricon:SetCallback("OnLeave", function () frame:SetStatusText(selectedDesc) end)
    if selected == "OR" then
        selectedDesc = "OR"
        selectedIcon = oricon
    end

    noticon:SetImage("Interface\\Icons\\inv_misc_map_01")
    noticon:SetImageSize(36, 36)
    noticon:SetWidth(44)
    noticon:SetCallback("OnClick", function (widget)
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
        frame:Hide()
    end)
    noticon:SetCallback("OnEnter", function () frame:SetStatusText(L["NOT"]) end)
    noticon:SetCallback("OnLeave", function () frame:SetStatusText(selectedDesc) end)
    if selected == "NOT" then
        selectedDesc = L["NOT"]
        selectedIcon = noticon
    end

    for k, v in pairs(conditions) do
        local icon, desc = funcs:describe(v)

        local acticon = AceGUI:Create("Icon")
        framegroup:AddChild(acticon)

        acticon:SetImage(icon)
        acticon:SetImageSize(36, 36)
        acticon:SetWidth(44)
        acticon:SetCallback("OnClick", function (widget)
            if selected ~= v then
                cleanArray(value, { "type" })
            end
            value.type = v
            frame:Hide()
        end)
        acticon:SetCallback("OnEnter", function () frame:SetStatusText(desc) end)
        acticon:SetCallback("OnLeave", function () frame:SetStatusText(selectedDesc) end)
        if selected == v then
            selectedDesc = desc
            selectedIcon = acticon
        end
    end

    if selectedIcon then
        ActionButton_ShowOverlayGlow(selectedIcon.frame)
    end

    frame:ResumeLayout()
    frame:DoLayout()
end

local function ActionGroup(parent, value, idx, array)
    local top = parent:GetUserData("top")
    local spec = top:GetUserData("spec")
    local funcs = top:GetUserData("funcs")

    -- local group = parent;
    local group = AceGUI:Create("InlineGroup")
    parent:AddChild(group)
    local icongroup = AceGUI:Create("SimpleGroup")
    group:AddChild(icongroup)
    local moveup
    if idx ~= nil and idx > 1 and value.type ~= nil then
        moveup = AceGUI:Create("InteractiveLabel")
        icongroup:AddChild(moveup)
    end
    local actionicon = AceGUI:Create("Icon")
    icongroup:AddChild(actionicon)
    local movedown
    if idx ~= nil and idx < #array - 1 and value.type ~= nil then
        movedown = AceGUI:Create("InteractiveLabel")
        icongroup:AddChild(movedown)
    end
    local arraygroup
    if (value ~= nil and value.type ~= nil and value.type ~= "NOT") then
        arraygroup = AceGUI:Create("SimpleGroup")
        group:AddChild(arraygroup)
    end

    group:SetLayout("Table")
    group:SetFullWidth(true)
    group:SetUserData("top", top)
    group:SetUserData("table", { columns = { 0, 1 } })

    icongroup:SetFullWidth(true)
    icongroup:SetLayout("List")
    icongroup:SetUserData("top", top)
    icongroup:SetWidth(50)

    if idx ~= nil and idx > 1 and value.type ~= nil then
        moveup:SetText(L["Up"])
        moveup:SetWidth(50)
        moveup:SetFontObject(GameFontNormalTiny)
        moveup:SetJustifyH("center")
        moveup:SetCallback("OnClick", function (widget)
            local tmp = array[idx-1]
            array[idx-1] = array[idx]
            array[idx] = tmp
            LayoutFrame(top)
        end)
    end

    if (value == nil or value.type == nil) then
        actionicon:SetImage("Interface\\Icons\\Trade_Engineering")
    elseif (value.type == "AND") then
        actionicon:SetImage("Interface\\Icons\\Spell_ChargePositive")
        group:SetTitle("AND")
    elseif (value.type == "OR") then
        actionicon:SetImage("Interface\\Icons\\Spell_ChargeNegative")
        group:SetTitle("OR")
    elseif (value.type == "NOT") then
        actionicon:SetImage("Interface\\Icons\\inv_misc_map_01")
        group:SetTitle("NOT")
    else
        local icon, description = funcs:describe(value.type)
        if (icon == nil) then
            actionicon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
        else
            actionicon:SetImage(icon)
            group:SetTitle(description)
        end
    end
    actionicon:SetImageSize(36, 36)
    actionicon:SetWidth(50)
    actionicon:SetUserData("top", top)
    actionicon:SetUserData("value", value)
    actionicon:SetCallback("OnClick", ChangeConditionType)

    if idx ~= nil and idx < #array - 1 and value.type ~= nil then
        movedown:SetText(L["Down"])
        movedown:SetWidth(50)
        movedown:SetFontObject(GameFontNormalTiny)
        movedown:SetJustifyH("center")
        movedown:SetCallback("OnClick", function (widget)
            local tmp = array[idx+1]
            array[idx+1] = array[idx]
            array[idx] = tmp
            LayoutFrame(top)
        end)
    end

    if (value ~= nil and value.type ~= nil) then
        if (value.type == "AND" or value.type == "OR") then
            arraygroup:SetFullWidth(true)
            arraygroup:SetLayout("Flow")
            arraygroup:SetUserData("top", top)

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
            ActionGroup(group, value.value)
        else
            arraygroup:SetFullWidth(true)
            arraygroup:SetLayout("Flow")
            arraygroup:SetUserData("top", top)

            funcs:widget(arraygroup, spec, value)
        end
    end
end

LayoutFrame = function(frame)
    local root = frame:GetUserData("root")
    local funcs = frame:GetUserData("funcs")

    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        if funcs.close ~= nil then
            funcs.close()
        end
        addon:UpdateAutoSwitch()
    end)

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("ScrollFrame")
    frame:AddChild(group)

    group:SetLayout("Flow")
    group:SetUserData("top", frame)
    ActionGroup(group, root)

    frame:ResumeLayout()
    frame:DoLayout()
end

local function EditConditionCommon(index, spec, value, funcs)
    local frame = AceGUI:Create("Frame")

    if index > 0 then
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
    HideOnEscape(frame)

    LayoutFrame(frame)
end

--------------------------------
--  Dealing with Conditionals
-------------------------------

local conditions = {}
local conditions_idx = 1

function addon:RegisterCondition(tag, array)
    local index = #conditions

    array["order"] = conditions_idx
    conditions[tag] = array
    conditions_idx = conditions_idx + 1
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

    EditConditionCommon(index, spec, value, funcs)
end

function addon:evaluateCondition(value)
    local cache = {}
    local start = GetTime()
    return evaluateSingle(value, conditions, cache, start)
end

function addon:printCondition(value, spec)
    return printSingle(value, conditions, spec)
end

function addon:validateCondition(value, spec)
    return validateSingle(value, conditions, spec)
end

function addon:usefulCondition(value)
    return usefulSingle(value, conditions)
end

function addon:listConditions()
    local rv = {}
    for k, v in pairs(conditions) do
        table.insert(rv, k)
    end
    table.sort(rv, function (lhs, rhs)
        if (conditions[rhs] == nil or conditions[rhs].order == nil) then
            return lhs
        end
        if (conditions[lhs] == nil or conditions[lhs].order == nil) then
            return rhs
        end
        return conditions[lhs].order < conditions[rhs].order
    end)
    return rv
end

function addon:describeCondition(type)
    if (conditions[type] == nil) then
        return nil, nil
    end
    return conditions[type].icon, conditions[type].description
end

function addon:widgetCondition(parent, spec, value)
    if value ~= nil and value.type ~= nil and conditions[value.type] ~= nil and conditions[value.type].widget ~= nil then
        conditions[value.type].widget(parent, spec, value)
    end
end

--------------------------------
--  Dealing with Switch Conditionals
-------------------------------

local switchConditions = {}
local switchConditions_idx = 1

function addon:RegisterSwitchCondition(tag, array)
    local index = #switchConditions

    array["order"] = switchConditions_idx
    switchConditions[tag] = array
    switchConditions_idx = switchConditions_idx + 1
end

function addon:EditSwitchCondition(spec, value, callback)
    local funcs = {
        print = addon.printSwitchCondition,
        validate = addon.validateSwitchCondition,
        list = addon.listSwitchConditions,
        describe = addon.describeSwitchCondition,
        widget = addon.widgetSwitchCondition,
        close = callback,
    }

    EditConditionCommon(0, spec, value, funcs)
end

function addon:evaluateSwitchCondition(value)
    local cache = {}
    local start = GetTime()
    return evaluateSingle(value, switchConditions, cache, start)
end

function addon:printSwitchCondition(value, spec)
    return printSingle(value, switchConditions, spec)
end

function addon:validateSwitchCondition(value, spec)
    return validateSingle(value, switchConditions, spec)
end

function addon:usefulSwitchCondition(value)
    return usefulSingle(value, switchConditions)
end

function addon:listSwitchConditions()
    local rv = {}
    for k, v in pairs(switchConditions) do
        table.insert(rv, k)
    end
    table.sort(rv, function (lhs, rhs)
        if (switchConditions[rhs] == nil or switchConditions[rhs].order == nil) then
            return lhs
        end
        if (switchConditions[lhs] == nil or switchConditions[lhs].order == nil) then
            return rhs
        end
        return switchConditions[lhs].order < switchConditions[rhs].order
    end)
    return rv
end

function addon:describeSwitchCondition(type)
    if (switchConditions[type] == nil) then
        return nil, nil
    end
    return switchConditions[type].icon, switchConditions[type].description
end

function addon:widgetSwitchCondition(parent, spec, value)
    if value ~= nil and value.type ~= nil and switchConditions[value.type] ~= nil and switchConditions[value.type].widget ~= nil then
        switchConditions[value.type].widget(parent, spec, value)
    end
end
