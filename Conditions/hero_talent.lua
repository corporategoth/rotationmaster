local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- HERO_TALENT: the hero talent tree (subtree) you have chosen, from
-- C_ClassTalents.GetActiveHeroTalentSpec. Retail only: Forever has the API but
-- no hero talents, and the Classic clients have neither. No subtree chosen
-- (below the level that offers one, or not picked yet) matches "no hero tree".
-- The tree is saved as the game's subtree ID; the editor lists the trees the
-- rotation's specialization can choose, named by the game, and still accepts
-- an ID typed in for a tree that cannot be listed (another class, in combat).
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    presentation={nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/hero_talent.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}

local function validTree(value)
    return type(value) == "number" and value == value and value > 0 and value < 2^31 and value % 1 == 0
end
local function treeName(id)
    if not validTree(id) then return nil end
    local platform = addon.Platform
    local name = type(platform.GetHeroTreeName) == "function" and platform:GetHeroTreeName(id)
    if name then return name end
    return string.format(L["hero talent tree %d"], id)
end
-- The specialization whose trees the editor lists: the rotation's, when it is
-- one of your class's, else the one being played.
local function listedSpec(spec)
    local platform = addon.Platform
    if type(spec) ~= "number" or type(platform.GetClassSpecializationChoices) ~= "function" then return nil end
    local ok, _, _, classID = pcall(UnitClass, "player")
    if not ok or not platform:CanReadValue(classID) then return nil end
    for _, choice in ipairs(platform:GetClassSpecializationChoices(classID) or {}) do
        if choice.id == spec then return spec end
    end
end

addon:RegisterCondition("HERO_TALENT", {
    description = L["Hero Talent Tree"],
    icon = addon.Artwork.condition["HERO_TALENT"],
    fields = { subtree = "number" },
    valid = function(_, value)
        return value.subtree == nil or validTree(value.subtree)
    end,
    evaluate = function(value, cache)
        local tree, reason = Functions.cache.getCached(cache, addon.Platform.GetActiveHeroTree, addon.Platform)
        if tree == nil then return nil, reason end
        if value.subtree == nil then return tree ~= false end
        return tree == value.subtree
    end,
    print = function(_, value)
        if value.subtree == nil then
            return L["you {{!have|have not}} chosen a hero talent tree"]
        end
        return string.format(L["your hero talent tree {{!is|is not}} %s"], Functions.presentation.nullable(treeName(value.subtree), L["<hero talent tree>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local function update() top:SetStatusText(funcs:print(root, spec)) end

        local idEdit
        local ANY = 0
        local choices, order = { [ANY] = L["Any hero talent tree"] }, { ANY }
        local platform = addon.Platform
        local listed = type(platform.GetHeroTreeChoices) == "function" and platform:GetHeroTreeChoices(listedSpec(spec))
        for _, tree in ipairs(listed or {}) do
            choices[tree.id] = tree.name or string.format(L["hero talent tree %d"], tree.id)
            order[#order + 1] = tree.id
        end
        if validTree(value.subtree) and choices[value.subtree] == nil then
            choices[value.subtree] = treeName(value.subtree)
            order[#order + 1] = value.subtree
        end

        local picker = addon:CreateConditionDropdown()
        picker:SetLabel(L["Hero Talent Tree"])
        picker:SetCallback("OnValueChanged", function(_, _, v)
            value.subtree = v ~= ANY and v or nil
            if idEdit then idEdit:SetText(value.subtree and tostring(value.subtree) or "") end
            update()
        end)
        picker.configure = function()
            picker:SetList(choices, order)
            picker:SetValue(value.subtree or ANY)
        end
        parent:AddChild(picker)

        idEdit = addon:CreateConditionEditBox()
        idEdit:SetFullWidth(true)
        idEdit:SetLabel(L["Hero talent tree ID (blank for any)"])
        idEdit:SetText(value.subtree and tostring(value.subtree) or "")
        idEdit:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber(text)
            value.subtree = validTree(id) and id or nil
            idEdit:SetText(value.subtree and tostring(value.subtree) or "")
            picker:SetValue(value.subtree or ANY)
            update()
        end)
        parent:AddChild(idEdit)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.HERO_TALENT"]))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="helpers" then return helpers end
        if name=="listedSpec" then return listedSpec end
        if name=="treeName" then return treeName end
        if name=="validTree" then return validTree end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/hero_talent.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/hero_talent.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
