local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- SPECIALIZATION: the player's talent specialization, saved as the game's
-- specialization ID so one condition reads the same on every client.
--   Retail, Mists of Pandaria Classic: the active specialization ID.
--   Era, TBC, Wrath (talent trees): the primary talent tree, the unique tree
--     with the most points. Feral and Guardian both mean Feral Combat there.
--   Forever: its specialization API names one specialization per class (the
--     trees are trait groups), so a spec of your own class is unavailable.
-- A specialization of another class is false everywhere. No specialization
-- yet, tied or unspent trees and unreadable values are unavailable, including
-- under NOT. The observation is cached by Core/build_context.lua until a
-- talent or specialization notification, so evaluation reads no native API.
local Functions={
    presentation={nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/specialization.lua"]={
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

-- Game specialization IDs: class token, talent tree on tree clients (nil
-- where the class or spec has no tree), and the English name used where the
-- client cannot name the specialization itself.
local SPECS={
    [71]={"WARRIOR",1,"Arms"},[72]={"WARRIOR",2,"Fury"},[73]={"WARRIOR",3,"Protection"},
    [65]={"PALADIN",1,"Holy"},[66]={"PALADIN",2,"Protection"},[70]={"PALADIN",3,"Retribution"},
    [253]={"HUNTER",1,"Beast Mastery"},[254]={"HUNTER",2,"Marksmanship"},[255]={"HUNTER",3,"Survival"},
    [259]={"ROGUE",1,"Assassination"},[260]={"ROGUE",2,"Combat"},[261]={"ROGUE",3,"Subtlety"},
    [256]={"PRIEST",1,"Discipline"},[257]={"PRIEST",2,"Holy"},[258]={"PRIEST",3,"Shadow"},
    [250]={"DEATHKNIGHT",1,"Blood"},[251]={"DEATHKNIGHT",2,"Frost"},[252]={"DEATHKNIGHT",3,"Unholy"},
    [262]={"SHAMAN",1,"Elemental"},[263]={"SHAMAN",2,"Enhancement"},[264]={"SHAMAN",3,"Restoration"},
    [62]={"MAGE",1,"Arcane"},[63]={"MAGE",2,"Fire"},[64]={"MAGE",3,"Frost"},
    [265]={"WARLOCK",1,"Affliction"},[266]={"WARLOCK",2,"Demonology"},[267]={"WARLOCK",3,"Destruction"},
    [268]={"MONK",nil,"Brewmaster"},[269]={"MONK",nil,"Windwalker"},[270]={"MONK",nil,"Mistweaver"},
    [102]={"DRUID",1,"Balance"},[103]={"DRUID",2,"Feral"},[104]={"DRUID",2,"Guardian"},[105]={"DRUID",3,"Restoration"},
    [577]={"DEMONHUNTER",nil,"Havoc"},[581]={"DEMONHUNTER",nil,"Vengeance"},[1480]={"DEMONHUNTER",nil,"Devourer"},
    [1467]={"EVOKER",nil,"Devastation"},[1468]={"EVOKER",nil,"Preservation"},[1473]={"EVOKER",nil,"Augmentation"},
    -- Retail's initial specializations (levels 1-9, Platform/specializations.lua INITIAL_SPECS),
    -- so the Built In premades for that stage can switch on them without a client lookup.
    [1446]={"WARRIOR",nil,"Initial"},[1451]={"PALADIN",nil,"Initial"},[1448]={"HUNTER",nil,"Initial"},
    [1453]={"ROGUE",nil,"Initial"},[1452]={"PRIEST",nil,"Initial"},[1455]={"DEATHKNIGHT",nil,"Initial"},
    [1444]={"SHAMAN",nil,"Initial"},[1449]={"MAGE",nil,"Initial"},[1454]={"WARLOCK",nil,"Initial"},
    [1450]={"MONK",nil,"Initial"},[1447]={"DRUID",nil,"Initial"},[1456]={"DEMONHUNTER",nil,"Initial"},
    [1465]={"EVOKER",nil,"Initial"},
}
local SPEC_ORDER={71,72,73,65,66,70,253,254,255,259,260,261,256,257,258,250,251,252,262,263,264,
    62,63,64,265,266,267,268,269,270,102,103,104,105,577,581,1480,1467,1468,1473}
local CLASS_IDS={WARRIOR=1,PALADIN=2,HUNTER=3,ROGUE=4,PRIEST=5,DEATHKNIGHT=6,SHAMAN=7,MAGE=8,
    WARLOCK=9,MONK=10,DRUID=11,DEMONHUNTER=12,EVOKER=13}

local function specID(value)
    return type(value)=="number" and value>0 and value<math.huge and value%1==0
end
-- The class a specialization belongs to: the table, else the client.
local function specClass(id)
    local known=SPECS[id]
    if known then return known[1] end
    local display=addon.Platform.GetSpecializationDisplay and addon.Platform:GetSpecializationDisplay(id)
    return display and display.class
end
local function specName(id)
    if not specID(id) then return nil end
    local display=addon.Platform.GetSpecializationDisplay and addon.Platform:GetSpecializationDisplay(id)
    if display then return display.name,display.icon end
    local known=SPECS[id]
    if known then return L[known[3]] end
    return string.format(L["specialization %d"],id)
end
local function playerClass()
    local ok,_,class=pcall(UnitClass,"player")
    if ok and addon.Platform:CanReadValue(class) and type(class)=="string" then return class end
end
-- The specializations of one class for the editor: the client's own names
-- and icons where it has them, else the table.
local function classChoices(class)
    local choices,order={},{}
    local listed=CLASS_IDS[class] and addon.Platform.GetClassSpecializationChoices
        and addon.Platform:GetClassSpecializationChoices(CLASS_IDS[class])
    if listed and #listed>0 then
        for _,spec in ipairs(listed) do
            choices[spec.id]=spec.icon and {text=spec.name,icon=spec.icon} or spec.name
            order[#order+1]=spec.id
        end
        return choices,order
    end
    for _,id in ipairs(SPEC_ORDER) do
        if SPECS[id][1]==class then choices[id]=specName(id);order[#order+1]=id end
    end
    return choices,order
end

if addon.Artwork and addon.Artwork.condition and addon.Artwork.condition["SPECIALIZATION"]==nil then
    -- No original artwork yet: reuses the Primary Talent Tree icon
    -- (tests/condition_icons.lua lists it as pending).
    addon.Artwork.condition["SPECIALIZATION"]=addon.Artwork.condition["PRIMARY_TALENT_TREE"]
end

addon:RegisterCondition("SPECIALIZATION", {
    description = L["Specialization"],
    icon = addon.Artwork.condition["SPECIALIZATION"],
    requiredFields = { "spec" },
    fields = { spec = "number" },
    valid = function(_, value)
        return specID(value.spec)
    end,
    -- Client support (Core/condition_support.lua): Forever has no
    -- specializations, so one of your own class can never be read there;
    -- another class's specialization is an ordinary false.
    supported = function(value)
        if type(value) ~= "table" or not specID(value.spec) then return nil end
        if addon.Platform:GetClientFamily() ~= "forever" then return nil end
        local class = playerClass()
        if class == nil or (canaccessvalue and not canaccessvalue(class)) then return nil end
        if specClass(value.spec) == class then return "specialization-unsupported" end
    end,
    evaluate = function(value)
        if not addon.GetPlayerSpecializationObservation then return nil, "build-context-unavailable" end
        local mode, current, reason, class = addon:GetPlayerSpecializationObservation()
        local wanted = specClass(value.spec)
        if wanted == nil then return nil, "unknown-specialization" end
        if class == nil then return nil, "class-unavailable" end
        if wanted ~= class then return false end
        if current == nil then return nil, reason or "specialization-unavailable" end
        if mode == "tree" then
            local known = SPECS[value.spec]
            if not known or known[2] == nil then return nil, "unknown-specialization" end
            return known[2] == current
        end
        return current == value.spec
    end,
    print = function(_, value)
        return string.format(L["your specialization {{!is|is not}} %s"],
            Functions.presentation.nullable((specName(value.spec)), L["<specialization>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local selectedClass = specID(value.spec) and specClass(value.spec) or playerClass()

        local specPicker
        local class = addon:CreateConditionDropdown()
        class:SetLabel(L["Class"])
        class:SetCallback("OnValueChanged", function(_, _, v)
            if v == selectedClass then return end
            selectedClass, value.spec = v, nil
            local choices, order = classChoices(v)
            specPicker:SetList(choices, order)
            specPicker:SetValue(nil)
            top:SetStatusText(funcs:print(root, spec))
        end)
        class.configure = function()
            class:SetList(LOCALIZED_CLASS_NAMES_MALE, CLASS_SORT_ORDER)
            class:SetValue(selectedClass)
        end
        parent:AddChild(class)

        specPicker = addon:CreateConditionDropdown()
        specPicker:SetLabel(L["Specialization"])
        specPicker:SetCallback("OnValueChanged", function(_, _, v)
            value.spec = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        specPicker.configure = function()
            local choices, order = classChoices(selectedClass)
            specPicker:SetList(choices, order)
            specPicker:SetValue(value.spec)
        end
        parent:AddChild(specPicker)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.SPECIALIZATION"]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Help.Conditions.SPECIALIZATION.editions"]))
    end
})

-- Cold, one-time seed for profiles created before these predicates existed:
-- SPECIALIZATION joins Character, WEAPON_TYPE (Conditions/equipment.lua)
-- joins Items, and both join the Switch picker, once per profile under their
-- own flag. Removing them later stays saved; new and reset profiles get them
-- from the packaged defaults.
local loadoutSeeds={
    {category="b8136123-2bda-4230-a77a-89ea2aed3a1a",tag="SPECIALIZATION"},
    {category="fca4ff75-4085-458a-b5bf-27a6b52f2092",tag="WEAPON_TYPE"},
}
function addon:InitializeLoadoutConditions(_, db)
    local profile = db and db.profile
    if type(profile) ~= "table" or profile.loadoutConditionsSeeded then return end
    local function append(list, tag)
        if type(list) ~= "table" then return end
        for _, existing in ipairs(list) do if existing == tag then return end end
        list[#list + 1] = tag
    end
    for _, seed in ipairs(loadoutSeeds) do
        append(profile.switch_conditions, seed.tag)
        for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
            if type(category) == "table" and category.id == seed.category then append(category.conditions, seed.tag) end
        end
    end
    profile.loadoutConditionsSeeded = true
end
local seedOwner = {}
function addon:InstallLoadoutConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then return end
    for _, event in ipairs({"OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied"}) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB) addon:InitializeLoadoutConditions(nil, currentDB) end)
    end
    self:InitializeLoadoutConditions(nil, db)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CLASS_IDS" then return CLASS_IDS end
        if name=="SPECS" then return SPECS end
        if name=="SPEC_ORDER" then return SPEC_ORDER end
        if name=="classChoices" then return classChoices end
        if name=="helpers" then return helpers end
        if name=="playerClass" then return playerClass end
        if name=="specClass" then return specClass end
        if name=="specID" then return specID end
        if name=="specName" then return specName end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/specialization.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/specialization.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
