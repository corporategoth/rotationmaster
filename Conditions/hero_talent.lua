-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In condition HERO_TALENT: which hero talent tree (subtree) you have chosen. Retail only: Forever has the API
-- but no hero talents, and the Classic clients have neither, so Core/condition_support.lua marks it unsupported there.
-- The tree comes from addon.Platform.GetActiveHeroTree and the editor lists trees through Platform:GetHeroTreeChoices
-- and GetHeroTreeName; all game reads and CanReadValue checks live in the Platform adapter, not here. Stores `subtree`
-- (the game's subtree ID, or nil for "any chosen tree"). Loaded from RotationMaster.toc after
-- Conditions/group_state.lua and before Conditions/proc_glow.lua. The condition callbacks and the helpers recorded in
-- the generated block at the end are frozen Built In source: never edit inside their bodies.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Pure helper leaves selected privately; the bindings table below tells the source collector which public helper each
-- one stands for.
local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    presentation = { nullable = addon.Functions.presentation.nullable },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/hero_talent.lua"] = {
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
}

-- True for a positive whole-number hero subtree ID below 2^31 (the range the game uses for IDs).
-- @param value any  The value to test.
-- @return boolean  True when value is a number in that range with no fractional part.
local function validTree(value)
    return type(value) == "number" and value == value and value > 0 and value < 2^31 and value % 1 == 0
end

-- Builds the display name of a hero talent tree.
-- @param id any  The hero subtree ID; anything but a valid ID gives nil.
-- @return string|nil  The name the game gives the tree, or a generic "hero talent tree N" label when the name is not
--     known yet; nil for an invalid ID.
--
-- The game names a tree only while the talent config is readable.
local function treeName(id)
    if not validTree(id) then return nil end
    local platform = addon.Platform
    local name = type(platform.GetHeroTreeName) == "function" and platform:GetHeroTreeName(id)
    if name then return name end
    return string.format(L["hero talent tree %d"], id)
end

-- Picks the specialization whose hero trees the editor lists.
-- @param spec any  The rotation's specialization ID.
-- @return number|nil  spec when it is one of your class's specializations; otherwise nil, which the Platform reads as
--     "the specialization being played".
local function listedSpec(spec)
    local platform = addon.Platform
    if type(spec) ~= "number" or type(platform.GetClassSpecializationChoices) ~= "function" then return nil end
    local ok, _, _, classID = pcall(UnitClass, "player")
    if not ok or not platform:CanReadValue(classID) then return nil end
    for _, choice in ipairs(platform:GetClassSpecializationChoices(classID) or {}) do
        if choice.id == spec then return spec end
    end
end

-- HERO_TALENT: with no `subtree` saved, true when you have chosen any hero tree; with one saved, true when it is the
-- tree you chose. No tree chosen (below the level that offers one, or not picked yet) is false, not unavailable.
-- Returns `nil, reason` when the Platform cannot read the active tree (restricted value, missing API, other client).
-- The tree is saved as the game's subtree ID; the editor lists the trees the rotation's specialization can choose and
-- still accepts a typed ID for a tree that cannot be listed (another class, in combat). Stores `subtree`.
addon:RegisterCondition("HERO_TALENT", {
    description = L["Hero Talent Tree"],
    icon = addon.Artwork.condition["HERO_TALENT"],
    fields = { subtree = "number" },
    -- Checks that the saved fields of the HERO_TALENT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- A missing subtree is valid ("any hero tree"); otherwise it must be a plausible ID.
    valid = function(_, value)
        return value.subtree == nil or validTree(value.subtree)
    end,
    -- Decides whether you chose any hero tree (with no subtree saved) or the saved hero tree; no tree chosen is false.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads the active tree once per poll through the shared cache. Unavailable (`nil, reason`) when the Platform
    -- cannot answer; false when no tree is chosen and a specific one is required.
    evaluate = function(value, cache)
        local tree, reason = Functions.cache.getCached(cache, addon.Platform.GetActiveHeroTree, addon.Platform)
        if tree == nil then return nil, reason end
        if value.subtree == nil then return tree ~= false end
        return tree == value.subtree
    end,
    -- Builds the readable rule summary for the HERO_TALENT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary: "chosen a hero talent tree" or the named tree.
    print = function(_, value)
        if value.subtree == nil then
            return L["you {{!have|have not}} chosen a hero talent tree"]
        end
        return string.format(L["your hero talent tree {{!is|is not}} %s"], Functions.presentation.nullable(treeName(value.subtree), L["<hero talent tree>"]))
    end,
    -- Builds the editor controls for the HERO_TALENT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: a dropdown of the listed trees ("any" plus each tree) and an ID box that stay in step with each other.
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
    -- Builds the help page for the HERO_TALENT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page text (the Help.Conditions.HERO_TALENT locale entry).
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
