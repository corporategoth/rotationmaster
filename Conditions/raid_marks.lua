-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions about raid target markers: MARKED (whether a unit carries a mark, none, or one of several marks)
-- and MARK_COUNT (how many marked units the mark table knows). MARKED reads one unit's mark directly through
-- Platform:GetUnitRaidMark; MARK_COUNT reads the event-driven table in Platform/raid_marks.lua, which exists only while
-- something asks about marks. Both go through platform:CanReadValue: a mark the client hides is unavailable
-- (nil, reason), also under NOT, never false. The mark unit types (skull ... star, anymark) are in
-- Core/raid_mark_units.lua and work with every unit-based condition. Loaded from RotationMaster.toc after
-- Conditions/world_seed.lua. Callback and helper bodies are hashed by saved copies and bundles: never add or change
-- text inside a function body, and leave the generated block at the end alone.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Two conditions share one icon with a condition of a related meaning until artwork of their own is generated:
-- MARKED uses the Unit Classification skull and MARK_COUNT the Distance Count studs. tests/condition_icons.lua lists them.
addon.Artwork.condition["MARKED"] = addon.Artwork.condition["MARKED"] or addon.Artwork.condition["CLASSIFICATION"]

addon.Artwork.condition["MARK_COUNT"] = addon.Artwork.condition["MARK_COUNT"]
    or addon.Artwork.condition["DISTANCE_COUNT"]

local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        playerize = addon.Functions.presentation.playerize,
        compareString = addon.Functions.presentation.compareString,
    },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/raid_marks.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
}

-- The mark names, skull first (the order the editor lists them and a saved list keeps), and the number of each.
local MARK_ORDER = { "skull", "cross", "square", "moon", "triangle", "diamond", "circle", "star" }
local MARK_NUMBER = { star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, skull = 8 }
local MARK_KEY = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }

-- The three ways a MARKED condition can name its marks, in the order the editor lists them. A saved `mark` is "any",
-- "none", or a comma-separated list of mark names such as "skull,moon".
local MODE_ORDER = { "any", "none", "some" }

-- Returns the editor labels of the three modes, keyed by mode.
local function modeNames()
    return { any = L["Any mark"], none = L["No mark"], some = L["One of these marks"] }
end

-- Returns the game's own name for a mark, by mark name; the English name when the client has none.
local function markName(key)
    local label = _G["RAID_TARGET_" .. (MARK_NUMBER[key] or 0)]
    if type(label) == "string" and label ~= "" then return label end
    return key:sub(1, 1):upper() .. key:sub(2)
end

-- Returns whether a saved `mark` is valid: "any", "none", or a list of one to eight different mark names separated by
-- single commas.
-- @param mark any  The saved mark field.
-- @return boolean  True for "any", "none" or a valid list; false for anything else, including an empty or over-long
--   string, an unknown or repeated name.
local function validMark(mark)
    if mark == "any" or mark == "none" then return true end
    if type(mark) ~= "string" or mark == "" or #mark > 64 then return false end
    local seen, count = {}, 0

    for name in (mark .. ","):gmatch("([^,]*),") do
        if MARK_NUMBER[name] == nil or seen[name] then return false end
        seen[name] = true
        count = count + 1
    end

    return count >= 1
end

-- Returns the localized names of the marks in a saved list, joined with commas, skull first.
-- @param mark string  A saved mark list that passed validMark.
-- @return string  The names of the listed marks, such as "Skull, Moon".
local function markListText(mark)
    local names = {}

    for _, key in ipairs(MARK_ORDER) do
        if mark:find(key, 1, true) then names[#names + 1] = markName(key) end
    end

    return table.concat(names, ", ")
end

-- MARKED: true when the unit carries the chosen mark: any mark, none, or one of the listed marks. False when the unit
-- does not exist (it has no mark to compare, also for "none"). Returns `nil, reason` when the mark cannot be read
-- ('restricted-value' on Retail and Forever when the client hides it, or the presence or API reason). Stores `unit`
-- and `mark`.
addon:RegisterCondition("MARKED", {
    description = L["Raid Mark"],
    icon = addon.Artwork.condition["MARKED"],
    requiredFields = { "unit", "mark" },
    fields = { unit = "string", mark = "string" },
    -- A selectable unit and a valid mark choice.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and validMark(value.mark)
    end,
    -- Reads whether the unit exists and the mark it carries, once per poll each through the evaluation cache. The
    -- list is searched by name: no mark name is part of another, so a plain find answers without allocating.
    evaluate = function(value, cache)
        local exists, why = Functions.cache.getCached(cache, addon.Platform.GetUnitPresenceObservation, addon.Platform, value.unit)
        if exists == nil then return nil, why end
        if exists == false then return false end
        local mark, reason = Functions.cache.getCached(cache, addon.Platform.GetUnitRaidMark, addon.Platform, value.unit)
        if mark == nil then return nil, reason end
        if value.mark == "any" then return mark > 0 end
        if value.mark == "none" then return mark == 0 end
        return mark > 0 and value.mark:find(MARK_KEY[mark], 1, true) ~= nil
    end,
    -- Readable summary: any mark, no mark, one mark, or a list; "you" takes the first-person verb.
    print = function(_, value)
        local unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"])
        local mark = value.mark
        if mark == "any" then
            return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a raid mark"], L["%s {{!has|does not have}} a raid mark"]), unit)
        elseif mark == "none" then
            return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have no|have a}} raid mark"], L["%s {{!has no|has a}} raid mark"]), unit)
        elseif validMark(mark) then
            local text = markListText(mark)
            if mark:find(",", 1, true) then
                return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} one of these marks: %s"], L["%s {{!has|does not have}} one of these marks: %s"]), unit, text)
            end
            return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} the %s mark"], L["%s {{!has|does not have}} the %s mark"]), unit, text)
        end
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} a raid mark"], L["%s {{!has|does not have}} a raid mark"]), unit)
    end,
    -- Builds the editor controls for the MARKED condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the unit selector, the any / none / one-of dropdown and the eight mark checkboxes (used only by the
    -- one-of choice); help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local function refresh()
            top:SetStatusText(funcs:print(root, spec))
        end

        parent:AddChild(addon:Widget_UnitWidget(value, addon.units, refresh))
        local boxes = {}
        local mode = addon:CreateConditionDropdown()

        -- Returns the choice the saved mark stands for: any, none, some, or nil while it is unset or invalid.
        local function currentMode()
            if value.mark == "any" or value.mark == "none" then return value.mark end
            if validMark(value.mark) then return "some" end
        end

        -- Ticks the checkboxes that match the saved list and enables them only for the one-of choice.
        local function sync()
            local some = currentMode() == "some"

            for key, box in pairs(boxes) do
                box:SetValue(some and value.mark:find(key, 1, true) ~= nil or false)
                box:SetDisabled(value.disabled or not some)
            end
        end

        mode:SetLabel(L["Mark"])
        mode:SetCallback("OnValueChanged", function(_, _, v)
            if v == "some" then
                if currentMode() ~= "some" then value.mark = "skull" end
            else
                value.mark = v
            end
            sync()
            refresh()
        end)
        mode.configure = function()
            mode:SetList(modeNames(), MODE_ORDER)
            if currentMode() ~= nil then mode:SetValue(currentMode()) end
            sync()
        end
        parent:AddChild(mode)

        for _, key in ipairs(MARK_ORDER) do
            local box = addon:CreateConditionCheckBox()
            box:SetWidth(150)
            box:SetLabel(markName(key))
            box:SetCallback("OnValueChanged", function(_, _, v)
                local list = {}

                for _, other in ipairs(MARK_ORDER) do
                    local ticked = other == key and v or other ~= key and boxes[other]:GetValue()
                    if ticked then list[#list + 1] = other end
                end

                value.mark = #list > 0 and table.concat(list, ",") or "any"
                mode:SetValue(currentMode())
                sync()
                refresh()
            end)
            boxes[key] = box
            parent:AddChild(box)
        end

        sync()
    end,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Matches while the unit carries a raid target marker. Choose Any mark, No mark, or One of these marks and tick the marks you want (skull, cross, square, moon, triangle, diamond, circle, star). A unit that does not exist never matches, not even for No mark. Where the game hides a marker (Retail and Forever restrict some data in combat) the condition is unavailable, also under NOT, never false. To act on whichever unit carries a mark, pick the mark itself as the Unit of another condition: Skull, Cross and the rest, or the highest-priority marked unit, which tries skull first and star last."]))
    end,
})

-- MARK_COUNT: compares the number of marked units the mark table knows (see Platform/raid_marks.lua; a marked unit that
-- is out of reach still counts until the mark is seen gone) with a number, optionally counting only enemies or only
-- friendly units. Returns `nil, reason` when the table is incomplete because a mark could not be read ('unreadable'),
-- when a unit's hostility is unknown for the chosen filter, or when the client cannot follow marks. Stores `filter`,
-- `operator` and `value`.
addon:RegisterCondition("MARK_COUNT", {
    description = L["Raid Mark Count"],
    icon = addon.Artwork.condition["MARK_COUNT"],
    requiredFields = { "operator", "value" },
    fields = { filter = "string", operator = "string", value = "number" },
    -- A known operator, a count from 0 to 8 and, when given, a known filter.
    valid = function(_, value)
        return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
            and type(value.value) == "number" and value.value == value.value and value.value >= 0 and value.value <= 8
            and (value.filter == nil or value.filter == "any" or value.filter == "enemy" or value.filter == "friendly")
    end,
    -- Counts through the table once per poll; the filter is passed on so a count of enemies reads only what it needs.
    evaluate = function(value, cache)
        local count, reason = Functions.cache.getCached(cache, addon.Platform.GetRaidMarkCount, addon.Platform, value.filter or "any")
        if count == nil then return nil, reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Readable summary; the subject names the filter.
    print = function(_, value)
        local subject = L["the number of marked units"]
        if value.filter == "enemy" then subject = L["the number of marked enemy units"] end
        if value.filter == "friendly" then subject = L["the number of marked friendly units"] end
        return Functions.presentation.compareString(value.operator, subject, Functions.presentation.nullable(value.value))
    end,
    -- Builds the editor controls for the MARK_COUNT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the filter dropdown and an operator-and-value control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local filter = addon:CreateConditionDropdown()
        filter:SetLabel(L["Count"])
        filter:SetCallback("OnValueChanged", function(_, _, v)
            value.filter = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        filter.configure = function()
            filter:SetList(
                { any = L["Marked units"], enemy = L["Marked enemies"], friendly = L["Marked friendly units"] },
                { "any", "enemy", "friendly" }
            )
            filter:SetValue(value.filter or "any")
        end
        parent:AddChild(filter)
        parent:AddChild(addon:Widget_OperatorWidget(value, L["Value"], function() top:SetStatusText(funcs:print(root, spec)) end))
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Counts the marked units Rotation Master knows of. It finds them on your target, focus, mouseover, nameplates, group members and their targets, bosses and arena opponents each time a mark changes, so a marked unit you cannot reach right now still counts until the mark is seen to be gone or you leave the area. Count every marked unit, only enemies, or only friendly units. If a marker cannot be read, or a unit's hostility is unknown for the filter you chose, the condition is unavailable, also under NOT. A unit carries at most one mark, so the count is never more than eight."]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Raid Mark Count"], L["Value"],
            L["A number from 0 to 8: there are eight marks, and a unit carries at most one."])
    end,
})

-- ============================================================================
-- One-time seed for existing profiles
-- ============================================================================

-- The id of the Combat category in profile.condition_groups (init.lua), where both conditions are listed.
local COMBAT_CATEGORY = "b3d7df2c-f257-4a2d-961e-66e49336d109"

-- Adds MARKED and MARK_COUNT to the Combat category of a profile created before they existed, once per profile
-- (profile.raidMarkConditionsSeeded); removing them later stays saved. New and reset profiles get them from init.lua.
-- @param _ any  Unused, so the function can serve as an AceDB-style callback.
-- @param db table|nil  The AceDB object whose current profile is seeded; nil or one without a profile is ignored.
function addon:InitializeRaidMarkConditions(_, db)
    local profile = db and db.profile

    if type(profile) ~= "table" or profile.raidMarkConditionsSeeded then
        return
    end

    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and category.id == COMBAT_CATEGORY and type(category.conditions) == "table" then
            for _, tag in ipairs({ "MARKED", "MARK_COUNT" }) do
                local found = false

                for _, existing in ipairs(category.conditions) do
                    if existing == tag then
                        found = true
                    end
                end

                if not found then
                    category.conditions[#category.conditions + 1] = tag
                end
            end
        end
    end

    profile.raidMarkConditionsSeeded = true
end

-- Identity token AceDB keys the callbacks below under, so they do not collide with any other registrant.
local seedOwner = {}

-- Seeds the current profile and re-seeds on every profile event that can bring in an unseeded profile.
-- @param db table|nil  The AceDB object; anything without RegisterCallback is ignored.
function addon:InstallRaidMarkConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then
        return
    end

    for _, event in ipairs({ "OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied" }) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB)
            addon:InitializeRaidMarkConditions(nil, currentDB)
        end)
    end

    self:InitializeRaidMarkConditions(nil, db)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="MARK_KEY" then return MARK_KEY end
        if name=="MARK_NUMBER" then return MARK_NUMBER end
        if name=="MARK_ORDER" then return MARK_ORDER end
        if name=="MODE_ORDER" then return MODE_ORDER end
        if name=="helpers" then return helpers end
        if name=="markListText" then return markListText end
        if name=="markName" then return markName end
        if name=="modeNames" then return modeNames end
        if name=="validMark" then return validMark end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/raid_marks.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/raid_marks.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
