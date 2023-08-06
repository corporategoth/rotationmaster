local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs
local helpers = addon.help_funcs

addon:RegisterCondition("COMBAT", {
    description = L["In Combat"],
    icon = "Interface\\Icons\\ability_dualwield",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        return addon.getCached(cache, UnitAffectingCombat, value.unit)
    end,
    print = function(_, value)
        return string.format(addon.playerize(value.unit, L["%s are in combat"], L["%s is in combat"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("PET", {
    description = L["Have Pet"],
    icon = "Interface\\Icons\\Inv_box_petcarrier_01",
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return addon.getCached(cache, UnitExists, "pet")
    end,
    print = function()
        return L["you have a pet"]
    end,
})

addon:RegisterCondition("PET_NAME", {
    description = L["Have Named Pet"],
    icon = "Interface\\Icons\\inv_box_birdcage_01",
    fields = { value = "string" },
    valid = function(_, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache)
        return addon.getCached(cache, GetUnitName, "pet") == value.value
    end,
    print = function(_, value)
        return string.format(L["you have a pet named %s"], addon.nullable(value.value, L["<name>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local petname = AceGUI:Create("EditBox")
        petname:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        petname:SetLabel(NAME)
        if (value.value ~= nil) then
            petname:SetText(value.value)
        end
        parent:AddChild(petname)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. NAME .. color.RESET .. " - " ..
            "The name of the pet you have summoned."))
    end
})

addon:RegisterCondition("STEALTHED", {
    description = L["Stealth"],
    icon = "Interface\\Icons\\ability_stealth",
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return addon.getCached(cache, IsStealthed)
    end,
    print = function()
        return L["you are stealthed"]
    end,
})

addon:RegisterCondition("INCONTROL", {
    description = L["In Control"],
    icon = "Interface\\Icons\\spell_nature_polymorph",
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return addon.getCached(cache, HasFullControl)
    end,
    print = function()
        return L["you are in control of your character"]
    end,
})

addon:RegisterCondition("LOC_TYPE", {
    description = L["Loss Of Control Type"],
    icon = "Interface\\Icons\\spell_nature_polymorph_cow",
    fields = { operator = "string", value = "number", loc_type = "string" },
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.loc_type ~= nil and addon.isin(addon.loc_types, value.loc_type))
    end,
    evaluate = function(value, cache)
        for i=1,addon.getCached(cache, C_LossOfControl.GetNumEvents) do
            local loc_type, _, _, _, _, remain = addon.getCached(cache, C_LossOfControl.GetEventInfo, i)
            if addon.loc_equivalent[loc_type] then
                loc_type = addon.loc_equivalent[loc_type]
            end
            if loc_type == value.loc_type then
                return addon.compare(value.operator, remain, value.value)
            end
        end
        return false
    end,
    print = function(_, value)
        return addon.compareString(value.operator, string.format(L["time remaining on %s"],
                addon.nullable(addon.loc_types[value.loc_type], L["<school>"])), string.format(L["%s seconds"], addon.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local loc_type = AceGUI:Create("Dropdown")
        loc_type:SetLabel(L["Control Type"])
        loc_type:SetCallback("OnValueChanged", function(_, _, v)
            value.loc_type = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        loc_type.configure = function()
            loc_type:SetList(addon.loc_types)
            loc_type:SetValue(value.loc_type)
        end
        parent:AddChild(loc_type)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Control Type"] .. color.RESET .. " - " ..
                "The type of loss of control you are subject to."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Loss Of Control Type"], L["Seconds"],
            "How long until the loss of control expires.")
    end
})

addon:RegisterCondition("LOC_BLOCKED", {
    description = L["Loss Of Control Blocked"],
    icon = "Interface\\Icons\\inv_misc_fish_turtle_03",
    fields = { operator = "string", value = "number", school = "string" },
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.school ~= nil and addon.isin(SCHOOL_STRINGS, value.school))
    end,
    evaluate = function(value, cache)
        for i=1,addon.getCached(cache, C_LossOfControl.GetNumEvents) do
            local _, _, _, _, _, remain, _, school = addon.getCached(cache, C_LossOfControl.GetEventInfo, i)
            if bit.band(school, bit.lshift(1, value.school-1)) then
                return addon.compare(value.operator, remain, value.value)
            end
        end
        return false
    end,
    print = function(_, value)
        return addon.compareString(value.operator, string.format(L["time remaining on block of your %s abilities"],
            addon.nullable(SCHOOL_STRINGS[value.school], L["<school>"])), string.format(L["%s seconds"], addon.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local school = AceGUI:Create("Dropdown")
        school:SetLabel(L["School Blocked"])
        school:SetCallback("OnValueChanged", function(_, _, v)
            value.school = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        school.configure = function()
            school:SetList(SCHOOL_STRINGS)
            school:SetValue(value.school)
        end
        parent:AddChild(school)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["School Blocked"] .. color.RESET .. " - " ..
            "The type of ability you are prevented from using."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Loss Of Control Blocked"], L["Seconds"],
            "How long until the loss of control expires.")
    end
})

addon:RegisterCondition("MOVING", {
    description = L["Moving"],
    icon = "Interface\\Icons\\Ability_druid_dash",
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return (addon.getCached(cache, GetUnitSpeed, "player") ~= 0)
    end,
    print = function()
        return L["you are moving"]
    end,
})

addon:RegisterCondition("THREAT", {
    description = L["Threat"],
    icon = "Interface\\Icons\\ability_physical_taunt",
    fields = { unit = "string", threat = "number" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit) and
               value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local enemy = addon.getCached(cache, UnitIsEnemy, "player", value.unit)
        if enemy then
            local rv = addon.getCached(cache, UnitThreatSituation, "player", value.unit)
            if rv ~= nil and rv >= value.threat - 1 then
                return true
            else
                return false
            end
        else
            return false
        end
    end,
    print = function(_, value)
        return string.format(L["you are at least %s on %s"], addon.nullable(addon.threat[value.threat], L["<addon.threat>"]),
        addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local val = AceGUI:Create("Dropdown")
        val:SetLabel(L["Threat"])
        val:SetCallback("OnValueChanged", function(_, _, v)
            value.threat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        val.configure = function()
            val:SetList(addon.threat)
            val:SetValue(value.threat)
        end
        parent:AddChild(val)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " - " ..
            "The amount of addon.threat you have with " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
            "condition will not be successful if you have no addon.threat whatsoever (ie. are not considered in combat " ..
            "with that unit.)"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no addon.threat risk"] .. color.RESET .. " - " ..
            "You are not in danger of taking addon.threat away from whoever has addon.threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher addon.threat than tank"] .. color.RESET .. " - " ..
            "You are in danger of pulling addon.threat away from the current tank, and should reduce the amount of " ..
            "addon.threat generated (by using addon.threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ", however " ..
            "you are not at the top of the addon.threat table, and thus are at risk of them switching targets " ..
            "to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " and are " ..
            "not at risk of them switching targets at the moment.")))
    end
})

addon:RegisterCondition("THREAT_COUNT", {
    description = L["Threat Count"],
    icon = "Interface\\Icons\\Ability_racial_bloodrage",
    fields = { threat = "number", operator = "string", value = "number" },
    valid = function(_, value)
        return value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    evaluate = function(value)
        local count = 0
        for _, entity in pairs(addon.unitsInRange) do
            if entity.enemy and entity.addon.threat and entity.addon.threat >= value.threat - 1 then
                count = count + 1
            end
        end
        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return addon.compareString(value.operator,
                        string.format(L["number of enemies you are at least %s"],
                        addon.nullable(addon.threat[value.threat], L["<addon.threat>"])),
                        addon.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local val = AceGUI:Create("Dropdown")
        val:SetLabel(L["Threat"])
        val:SetCallback("OnValueChanged", function(_, _, v)
            value.threat = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        val.configure = function()
            val:SetList(addon.threat)
            val:SetValue(value.threat)
        end
        parent:AddChild(val)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " - " ..
                "The minimum amount of addon.threat you have with other addon.units."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no addon.threat risk"] .. color.RESET .. " - " ..
                "You are not in danger of taking addon.threat away from whoever has addon.threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher addon.threat than tank"] .. color.RESET .. " - " ..
                "You are in danger of pulling addon.threat away from the current tank, and should reduce the amount of " ..
                "addon.threat generated (by using addon.threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
                "You are currently tanking, however you are not at the top of the addon.threat table, and thus are at " ..
                "risk of them switching targets to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
                "You are currently tanking  and are not at risk of them switching targets at the moment.")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Threat Count"], L["Count"],
                "The number of addon.units you have at least " .. color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " on.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText("Threat is measured only on addon.units within a maximum measurable range. The maximum " ..
                " range is set using Game Options -> Interface -> Game tab -> Names -> Nameplate Distance."))
    end
})

local character_class = select(2, UnitClass("player"))
addon:RegisterCondition("FORM", {
    description = L["Shapeshift Form"],
    icon = "Interface\\Icons\\ability_hunter_pet_bear",
    fields = { value = "number" },
    valid = function(_, value)
        return value.value ~= nil and value.value >= 0 and value.value <= (character_class == "SHAMAN" and 1 or GetNumShapeshiftForms())
    end,
    evaluate = function(value, cache)
        return addon.getCached(cache, GetShapeshiftForm) == value.value
    end,
    print = function(_, value)
        local form
        if value.value ~= nil then
            if value.value == 0 then
                form = L["humanoid"]
            elseif character_class == "SHAMAN" then
                form = select(1, GetSpellInfo("Ghost Wolf"))
            else
                form = GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
            end
        end
        return string.format(L["you are in %s form"], addon.nullable(form, L["<form>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local forms = {}
        local formsOrder = {}

        forms["0"] = L["humanoid"]
        table.insert(formsOrder, "0")
        if character_class == "SHAMAN" then
            forms["1"] = select(1, GetSpellInfo("Ghost Wolf"))
            table.insert(formsOrder, tostring("1"))
        else
            for i=1,GetNumShapeshiftForms() do
                local spellid = select(4, GetShapeshiftFormInfo(i))
                if spellid == nil then
                    break
                end
                forms[tostring(i)] = GetSpellInfo(spellid)
                table.insert(formsOrder, tostring(i))
            end
        end

        local formIcon = AceGUI:Create("Icon")
        local function set_form_icon()
            if value.value ~= nil then
                if value.value == 0 then
                    formIcon:SetImage("Interface\\Icons\\inv_misc_head_human_02")
                else
                    if character_class == "SHAMAN" then
                        if value.value == 1 then
                            formIcon:SetImage(GetSpellTexture("Ghost Wolf"))
                        end
                    else
                        formIcon:SetImage(GetShapeshiftFormInfo(value.value))
                    end
                end
            else
                formIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end

        formIcon:SetWidth(44)
        formIcon:SetHeight(44)
        formIcon:SetImageSize(36, 36)
        set_form_icon()
        parent:AddChild(formIcon)

        local form = AceGUI:Create("Dropdown")
        form:SetLabel(L["Form"])
        form:SetCallback("OnValueChanged", function(_, _, v)
            value.value = tonumber(v)
            form:SetValue(v)
            set_form_icon()
            top:SetStatusText(funcs:print(root, spec))
        end)
        form.configure = function()
            form:SetList(forms, formsOrder)
            if (value.value) then
                form:SetValue(tostring(value.value))
            end
        end
        parent:AddChild(form)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Form"] .. color.RESET .. " - " ..
            "You are shapeshifted into a different form.  This includes stances for warriors and stealth.  " ..
            color.GREEN .. L["humanoid"] .. color.RESET .. " can be used to indicate you are NOT shapeshifted."))
    end
})

addon:RegisterCondition("ATTACKABLE", {
    description = L["Attackable"],
    icon = "Interface\\Icons\\inv_misc_head_dragon_bronze",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        return addon.getCached(cache, UnitCanAttack, "player", value.unit) and
               not addon.getCached(cache, UnitIsDead, value.unit)
    end,
    print = function(_, value)
        return string.format(L["%s is attackable"], addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("ENEMY", {
    description = L["Hostile"],
    icon = "Interface\\Icons\\inv_misc_head_dragon_01",
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and addon.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        return addon.getCached(cache, UnitIsEnemy, "player", value.unit)
    end,
    print = function(_, value)
        return string.format(L["%s is an enemy"], addon.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("COMBAT_HISTORY", {
    description = L["Combat Action History"],
    icon = "Interface\\Icons\\Spell_shadow_shadowward",
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.action ~= nil and addon.isin(addon.actions, value.action) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value)
        if addon.combatHistory[value.unit] ~= nil then
            for idx, entry in pairs(addon.combatHistory[value.unit]) do
                if (addon.compare(value.operator, idx, value.value)) and (value.action == entry.action or
                    (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return addon.compareString(value.operator, string.format(addon.playerize(value.unit, L["%s were %s"], L["%s was %s"]),
                             addon.nullable(addon.units[value.unit], L["<unit>"]), addon.nullable(addon.actions[value.action], L["<action>"])),
                             string.format(L["%s addon.actions ago"], addon.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = AceGUI:Create("Dropdown")
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, addon.keys(addon.actions))
            action:SetValue(value.action)
        end
        parent:AddChild(action)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Action"] .. color.RESET .. " - " ..
                "The kind of combat action to look for (Hit, Miss, Parried, etc)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Combat Action History"], L["Count"],
            "How far back in your combat history to look for " .. color.BLIZ_YELLOW .. L["Action"] .. color.RESET ..
            " (by count).  A value of 1 means the last combat action, 2 means two combat addon.actions ago, etc.  " ..
            "Each combat action treated separately.  Any combat action more than the setting of " .. color.BLUE ..
            L["Combat History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

addon:RegisterCondition("COMBAT_HISTORY_TIME", {
    description = L["Combat Action History Time"],
    icon = "Interface\\Icons\\Spell_shadow_shadetruesight",
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and addon.isin(addon.units, value.unit) and
                value.action ~= nil and addon.isin(addon.actions, value.action) and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, _, evalStart)
        if addon.combatHistory[value.unit] ~= nil then
            for _, entry in pairs(addon.combatHistory[value.unit]) do
                if addon.compare(value.operator, (evalStart - entry.time), value.value) and (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return addon.compareString(value.operator, string.format(addon.playerize(value.unit, L["%s were %s"], L["%s was %s"]),
            addon.nullable(addon.units[value.unit], L["<unit>"]), addon.nullable(addon.actions[value.action], L["<action>"])),
            string.format(L["%s seconds ago"], addon.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = AceGUI:Create("Dropdown")
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, addon.keys(addon.actions))
            action:SetValue(value.action)
        end
        parent:AddChild(action)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Action"] .. color.RESET .. " - " ..
                "The kind of combat action to look for (Hit, Miss, Parried, etc)."))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Combat Action History Time"], L["Seconds"],
            "How far back in your combat history to look for " .. color.BLIZ_YELLOW .. L["Action"] .. color.RESET ..
            " (by time).  A value of 1 means the last combat action, 2 means two combat addon.actions ago, etc.  " ..
            "Each combat action treated separately.  Any combat action more than the setting of " .. color.BLUE ..
            L["Combat History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

addon:RegisterCondition("TIME_IN_COMBAT", {
    description = "Time Since Combat Start",
    icon = "Interface\\Icons\\Spell_holy_borrowedtime",
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return ( value.operator ~= nil and addon.isin(addon.operators, value.operator) and value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, _, evalStart)
        if addon.combatStart ~= nil then
            return addon.compare(value.operator, (evalStart - addon.combatStart), value.value)
        end
        return false
    end,
    print = function(_, value)
        return string.format("Time in combat is %s %s seconds",
        addon.nullable(addon.operators[value.operator], L["<operator>"]),
        addon.nullable(value.value))    
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Time Since Combat Start"], L["Seconds"],
        "This condition checks how long you've been in combat. For example, if the operator is set to 'is less than' and the " ..
        "value is set to 5, this condition will only be true if you have been in combat for less than 5 seconds, or if the " ..
        "operator is set to 'is greater than' and the value is set to 10, the condition will only be true if you have been in " ..
        "combat for more than 10 seconds. This is very useful for adjusting rotation priorities for openers vs. normal rotation")
    end
})