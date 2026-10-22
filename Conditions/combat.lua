local addon_name, addon = ...
local runtimeCondition=addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness('Conditions/combat.lua') or function(_,definition)return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color, tostring, tonumber, pairs = color, tostring, tonumber, pairs
local helpers = addon.help_funcs

-- Private canonical leaves preserve explicit saved-source dependency identities.
local PetSummary={phrase=addon.Functions.presentation.phrase}
local Functions={
    collections={deepcopy=addon.Functions.collections.deepcopy,keys=addon.Functions.collections.keys},
    values={compare=addon.Functions.values.compare,isin=addon.Functions.values.isin},
    presentation={nullable=addon.Functions.presentation.nullable,playerize=addon.Functions.presentation.playerize,compareString=addon.Functions.presentation.compareString},
    cache={getCached=addon.Functions.cache.getCached},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/combat.lua"]={
    ["PetSummary.phrase"]="builtin:Functions/presentation.lua:phrase",
    ["Functions.collections.deepcopy"]="builtin:Functions/collections.lua:deepcopy",
    ["Functions.collections.keys"]="builtin:Functions/collections.lua:keys",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"]="builtin:utils.lua:playerize",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
}

addon:RegisterCondition("COMBAT", runtimeCondition('COMBAT',{
    requiredFields = {"unit"},
    description = L["In Combat"],
    icon = addon.Artwork.condition["COMBAT"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "combat")
    end,
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} in combat"], L["%s {{!is|is not}} in combat"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
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
}))

addon:RegisterCondition("PET", {
    description = L["Have Pet"],
    icon = addon.Artwork.condition["PET"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, false)
        if not record then return nil,reason end
        return record.exists
    end,
    print = function()
        return L["you {{!have|do not have}} a pet"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when your pet unit exists. This does not check whether the pet is alive, in range or able to use an ability."] ))
    end,
})

addon:RegisterCondition("PET_NAME", {
    description = L["Have Named Pet"],
    icon = addon.Artwork.condition["PET_NAME"],
    fields = { value = "string" },
    valid = function(_, value)
        return value.value ~= nil
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetPetObservation, addon.Platform, true)
        if not record then return nil,reason end
        if not record.exists then return false end
        return record.name == value.value
    end,
    print = function(_, value)
        return PetSummary.phrase(L["you {{!have|do not have}} a pet named {name}"], {name = Functions.presentation.nullable(value.value, L["<name>"])})
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local petname = addon:CreateConditionEditBox()
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
    icon = addon.Artwork.condition["STEALTHED"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "stealthed")
    end,
    print = function()
        return L["you {{!are|are not}} stealthed"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches while the game reports your character as stealthed. It does not test whether an enemy can detect you."] ))
    end,
})

addon:RegisterCondition("INCONTROL", {
    description = L["In Control"],
    icon = addon.Artwork.condition["INCONTROL"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetPlayerFlagObservation, addon.Platform, "control")
    end,
    print = function()
        return L["you {{!are|are not}} in control of your character"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches when the game reports that you have full control of your character. This does not guarantee that a particular spell is usable."] ))
    end,
})

addon:RegisterCondition("LOC_TYPE", {
    description = L["Loss Of Control Type"],
    icon = addon.Artwork.condition["LOC_TYPE"],
    fields = { operator = "string", value = "number", loc_type = "string" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.loc_type ~= nil and Functions.values.isin(addon.loc_types, value.loc_type))
    end,
    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "type")
            if not record then return nil,why end
            local loc_type = record.locType
            if addon.loc_equivalent[loc_type] then
                loc_type = addon.loc_equivalent[loc_type]
            end
            if loc_type == value.loc_type then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["time remaining on %s"],
                Functions.presentation.nullable(addon.loc_types[value.loc_type], L["<school>"])), string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local loc_type = addon:CreateConditionDropdown()
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
    icon = addon.Artwork.condition["LOC_BLOCKED"],
    fields = { operator = "string", value = "number", school = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0.0 and
                value.school ~= nil and Functions.values.isin(SCHOOL_STRINGS, value.school))
    end,
    evaluate = function(value, cache)
        local count,reason=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlCount, addon.Platform)
        if count==nil then return nil,reason end
        for i=1,count do
            local record,why=Functions.cache.getCached(cache, addon.Platform.GetLossOfControlEvent, addon.Platform, i, "school")
            if not record then return nil,why end
            if not addon.Platform:CanReadValue(bit) then return nil,"restricted-value" end
            if type(bit)~="table" then return nil,"missing-api" end
            local shiftOk,selectedBit=pcall(function() return bit.lshift(1, value.school-1) end)
            if not shiftOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(selectedBit) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(selectedBit) then return nil,"restricted-value" end
            if type(selectedBit)~="number" or selectedBit~=selectedBit or selectedBit==math.huge or selectedBit==-math.huge or selectedBit%1~=0 then return nil,"invalid-api-result" end
            local bandOk,blocked=pcall(function() return bit.band(record.lockoutSchool, selectedBit) end)
            if not bandOk then return nil,"api-error" end
            if not addon.Platform:CanReadValue(blocked) then return nil,"restricted-value" end
            if canaccessvalue and not canaccessvalue(blocked) then return nil,"restricted-value" end
            if type(blocked)~="number" or blocked~=blocked or blocked==math.huge or blocked==-math.huge or blocked%1~=0 then return nil,"invalid-api-result" end
            if blocked~=0 then
                if record.timeRemaining==nil then return nil,record.timeRemainingReason end
                return Functions.values.compare(value.operator, record.timeRemaining, value.value)
            end
        end
        return false
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(L["time remaining on block of your %s abilities"],
            Functions.presentation.nullable(SCHOOL_STRINGS[value.school], L["<school>"])), string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local school = addon:CreateConditionDropdown()
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

addon:RegisterCondition("MOVING", runtimeCondition('MOVING',{
    description = L["Moving"],
    icon = addon.Artwork.condition["MOVING"],
    fields = { },
    valid = function()
        return true
    end,
    evaluate = function(_, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetPlayerMovementObservation,addon.Platform)
        if not record then return nil,reason end
        return record.speed~=0
    end,
    print = function()
        return L["you {{!are|are not}} moving"]
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Matches while your character is moving, based on current movement speed. It does not test the movement of your target."] ))
    end,
}))

addon:RegisterCondition("THREAT", {
    description = L["Threat"],
    icon = addon.Artwork.condition["THREAT"],
    fields = { unit = "string", threat = "number" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
               value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    evaluate = function(value, cache)
        local observed,reason=Functions.cache.getCached(cache, addon.Platform.GetUnitThreatObservation, addon.Platform, value.unit)
        if observed==nil then return nil,reason end
        if observed==false then return false end
        return observed >= value.threat - 1
    end,
    print = function(_, value)
        return string.format(L["you {{!are|are not}} at least %s on %s"], Functions.presentation.nullable(addon.threat[value.threat], L["<threat>"]),
        Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local val = addon:CreateConditionDropdown()
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
            "The amount of threat you have with " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".  This " ..
            "condition will not be successful if you have no threat whatsoever (ie. are not considered in combat " ..
            "with that unit.)"))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no threat risk"] .. color.RESET .. " - " ..
            "You are not in danger of taking threat away from whoever has threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher threat than tank"] .. color.RESET .. " - " ..
            "You are in danger of pulling threat away from the current tank, and should reduce the amount of " ..
            "threat generated (by using threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ", however " ..
            "you are not at the top of the threat table, and thus are at risk of them switching targets " ..
            "to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
            "You are currently tanking " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " and are " ..
            "not at risk of them switching targets at the moment.")))
    end
})

addon:RegisterCondition("THREAT_COUNT", {
    description = L["Threat Count"],
    icon = addon.Artwork.condition["THREAT_COUNT"],
    fields = { threat = "number", operator = "string", value = "number" },
    valid = function(_, value)
        return value.value ~= nil and value.value >= 0 and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.threat ~= nil and value.threat >= 1 and value.threat <= 4
    end,
    evaluate = function(value, cache)
        local count,reason=addon:GetConditionThreatCount(value.threat-1,cache)
        if count==nil then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
                        string.format(L["number of enemies you are at least %s"],
                        Functions.presentation.nullable(addon.threat[value.threat], L["<threat>"])),
                        Functions.presentation.nullable(value.value))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local val = addon:CreateConditionDropdown()
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
                "The minimum amount of threat you have with other units."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["no threat risk"] .. color.RESET .. " - " ..
                "You are not in danger of taking threat away from whoever has threat.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["higher threat than tank"] .. color.RESET .. " - " ..
                "You are in danger of pulling threat away from the current tank, and should reduce the amount of " ..
                "threat generated (by using threat-reducing abilities or ceasing DPS or Healing) immediately.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, at risk"] .. color.RESET .. " - " ..
                "You are currently tanking, however you are not at the top of the threat table, and thus are at " ..
                "risk of them switching targets to somebody else.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["tanking, secure"] .. color.RESET .. " - " ..
                "You are currently tanking  and are not at risk of them switching targets at the moment.")))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Threat Count"], L["Count"],
                "The number of units you have at least " .. color.BLIZ_YELLOW .. L["Threat"] .. color.RESET .. " on.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText("Threat is measured only on units within a maximum measurable range. The maximum " ..
                " range is set using Game Options -> Interface -> Game tab -> Names -> Nameplate Distance."))
    end
})

local character_class = select(2, UnitClass("player"))
addon:RegisterCondition("FORM", {
    description = L["Shapeshift Form"],
    icon = addon.Artwork.condition["FORM"],
    fields = { value = "number" },
    valid = function(_, value)
        return value.value ~= nil and value.value >= 0 and value.value <= (character_class == "SHAMAN" and 1 or GetNumShapeshiftForms())
    end,
    evaluate = function(value, cache)
        local form,reason=Functions.cache.getCached(cache, addon.Platform.GetPlayerFormObservation, addon.Platform)
        if form==nil then return nil,reason end
        return form == value.value
    end,
    print = function(_, value)
        local form
        if value.value ~= nil then
            if value.value == 0 then
                form = L["humanoid"]
            elseif character_class == "SHAMAN" then
                local info = addon.Platform:GetSpellInfo(2645)
                form = info and info.name
            else
                local info = addon.Platform:GetSpellInfo(select(4, GetShapeshiftFormInfo(value.value)))
                form = info and info.name
            end
        end
        return string.format(L["you {{!are|are not}} in %s form"], Functions.presentation.nullable(form, L["<form>"]))
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
            local info = addon.Platform:GetSpellInfo(2645)
            forms["1"] = info and info.name or L["<form>"]
            table.insert(formsOrder, tostring("1"))
        else
            for i=1,GetNumShapeshiftForms() do
                local spellid = select(4, GetShapeshiftFormInfo(i))
                if spellid == nil then
                    break
                end
                local info = addon.Platform:GetSpellInfo(spellid)
                forms[tostring(i)] = info and info.name or L["<form>"]
                table.insert(formsOrder, tostring(i))
            end
        end

        local formIcon = addon:CreateConditionIcon()
        local function set_form_icon()
            if value.value ~= nil then
                if value.value == 0 then
                    formIcon:SetImage("Interface\\Icons\\inv_misc_head_human_02")
                else
                    if character_class == "SHAMAN" then
                        if value.value == 1 then
                            local info = addon.Platform:GetSpellInfo(2645)
                            formIcon:SetImage(info and info.iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
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

        local form = addon:CreateConditionDropdown()
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

addon:RegisterCondition("ATTACKABLE", runtimeCondition('ATTACKABLE',{
    requiredFields = {"unit"},
    description = L["Attackable"],
    icon = addon.Artwork.condition["ATTACKABLE"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitAttackabilityObservation, addon.Platform, value.unit)
    end,
    print = function(_, value)
        return string.format(L["%s {{!is|is not}} attackable"], Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
}))

addon:RegisterCondition("ENEMY", {
    description = L["Hostile"],
    icon = addon.Artwork.condition["ENEMY"],
    fields = { unit = "string" },
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit);
    end,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "enemy")
    end,
    print = function(_, value)
        return string.format(L["%s {{!is|is not}} an enemy"], Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end
})

addon:RegisterCondition("COMBAT_HISTORY", {
    description = L["Combat Action History"],
    icon = addon.Artwork.condition["COMBAT_HISTORY"],
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.action ~= nil and Functions.values.isin(addon.actions, value.action) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value)
        if addon.combatHistory[value.unit] ~= nil then
            for idx, entry in pairs(addon.combatHistory[value.unit]) do
                if (Functions.values.compare(value.operator, idx, value.value)) and (value.action == entry.action or
                    (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(Functions.presentation.playerize(value.unit, L["%s were %s"], L["%s was %s"]),
                             Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.actions[value.action], L["<action>"])),
                             string.format(L["%s actions ago"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = addon:CreateConditionDropdown()
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, Functions.collections.keys(addon.actions))
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
            " (by count).  A value of 1 means the last combat action, 2 means two combat actions ago, etc.  " ..
            "Each combat action treated separately.  Any combat action more than the setting of " .. color.BLUE ..
            L["Combat History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

addon:RegisterCondition("COMBAT_HISTORY_TIME", {
    description = L["Combat Action History Time"],
    icon = addon.Artwork.condition["COMBAT_HISTORY_TIME"],
    fields = { unit = "string", action = "string", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.action ~= nil and Functions.values.isin(addon.actions, value.action) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, _, evalStart)
        if addon.combatHistory[value.unit] ~= nil then
            for _, entry in pairs(addon.combatHistory[value.unit]) do
                local compare,operator=Functions.values.compare,value.operator
                if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
                if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-history-time' end
                if not addon.Platform:CanReadValue(entry) then return nil,'restricted-value' end
                if type(entry)~='table' then return nil,'invalid-combat-history-entry' end
                local timestamp=entry.time
                if not addon.Platform:CanReadValue(timestamp) then return nil,'restricted-value' end
                if type(timestamp)~='number' or timestamp~=timestamp or timestamp>=math.huge or timestamp<=-math.huge then return nil,'invalid-combat-history-time' end
                local elapsed=evalStart-timestamp
                if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
                if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-history-elapsed' end
                if compare(operator, elapsed, value.value) and (value.action == entry.action or
                        (entry.severity ~= nil and value.action == (entry.action .. '_' .. entry.severity))) then
                    return true
                end
            end
        end
        return false
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, string.format(Functions.presentation.playerize(value.unit, L["%s were %s"], L["%s was %s"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]), Functions.presentation.nullable(addon.actions[value.action], L["<action>"])),
            string.format(L["%s seconds ago"], Functions.presentation.nullable(value.value)))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet", "target" }, true),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local action = addon:CreateConditionDropdown()
        action:SetLabel(L["Action Type"])
        action:SetCallback("OnValueChanged", function(_, _, v)
            value.action = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        action.configure = function()
            action:SetList(addon.actions, Functions.collections.keys(addon.actions))
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
            " (by time).  A value of 1 means the last combat action, 2 means two combat actions ago, etc.  " ..
            "Each combat action treated separately.  Any combat action more than the setting of " .. color.BLUE ..
            L["Combat History Memory (seconds)"] .. color.RESET .. " in the primary Rotation Master configuration " ..
            "screen ago will not be available.")
    end
})

addon:RegisterCondition("TIME_IN_COMBAT", {
    description = L["Time Since Combat Start"],
    icon = addon.Artwork.condition["TIME_IN_COMBAT"],
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return ( value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, _, evalStart)
        local start=addon.combatStart
        if not addon.Platform:CanReadValue(start) then return nil,'restricted-value' end
        if start==nil then return false end
        if type(start)~='number' or start~=start or start>=math.huge or start<=-math.huge then return nil,'invalid-combat-start' end
        if not addon.Platform:CanReadValue(evalStart) then return nil,'restricted-value' end
        if type(evalStart)~='number' or evalStart~=evalStart or evalStart>=math.huge or evalStart<=-math.huge then return nil,'invalid-combat-time' end
        local elapsed=evalStart-start
        if not addon.Platform:CanReadValue(elapsed) then return nil,'restricted-value' end
        if elapsed~=elapsed or elapsed>=math.huge or elapsed<=-math.huge then return nil,'invalid-combat-elapsed' end
        return Functions.values.compare(value.operator,elapsed,value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,L["Time in combat"],string.format(L["%s seconds"],Functions.presentation.nullable(value.value)))
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
        addon.layout_condition_operatorwidget_help(frame, L["Time Since Combat Start"], L["Seconds"],
        "This condition checks how long you've been in combat. For example, if the operator is set to 'is less than' and the " ..
        "value is set to 5, this condition will only be true if you have been in combat for less than 5 seconds, or if the " ..
        "operator is set to 'is greater than' and the value is set to 10, the condition will only be true if you have been in " ..
        "combat for more than 10 seconds. This is very useful for adjusting rotation priorities for openers vs. normal rotation")
    end
})

-- Source-owned configuration validators and optional notification facts.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/combat.lua',{ COMBAT={pure=true},ATTACKABLE={pure=true},MOVING={pure=true} })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="character_class" then return character_class end
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/combat.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/combat.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
