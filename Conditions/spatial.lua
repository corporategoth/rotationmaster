-- Built In conditions about where units are: PROXIMITY (allies within a distance of a unit), DISTANCE (a unit is
-- closer than N yards), DISTANCE_COUNT (observed units within N yards) and ZONE. It also publishes the scan
-- addon.proximity_eval and its editor widgets addon.proximity_widgets, which Conditions/spatial_stats.lua reuses.
-- Positions come from UnitPosition and ranges from LibRangeCheck, read through the protectedRead wrapper from
-- Functions/cache.lua; every result is checked with platform:CanReadValue and an unreadable one is `nil, reason`, never
-- a guess. DISTANCE_COUNT counts addon.nameplateUnits (restricted clients) or addon.unitsInRange (GUID snapshot), both
-- kept by main.lua. Loaded from RotationMaster.toc after Conditions/channeling.lua and before Conditions/range.lua.
-- Callback bodies and the helpers named in the generated block at the end are frozen Built In source: never edit
-- inside them.
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local RangeCheck = LibStub("LibRangeCheck-3.0")
local color, pairs = color, pairs
local helpers = addon.help_funcs

-- Selected canonical helpers stay private to these authored callbacks. The
-- collector verifies these explicit leaves against their stable public IDs.
local LiteralSummary = { phrase = addon.Functions.presentation.phrase }

local Functions = {
    cache = { getCached = addon.Functions.cache.getCached },
    values = { compare = addon.Functions.values.compare, isin = addon.Functions.values.isin },
    presentation = {
        compareString = addon.Functions.presentation.compareString,
        nullable = addon.Functions.presentation.nullable,
        playerize = addon.Functions.presentation.playerize,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/spatial.lua"] = {
    ["LiteralSummary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
}

-- ============================================================================
-- Protected reads and positions
-- ============================================================================

-- Provides LibRangeCheck's yard bounds for a unit; handed to the cached reader as the range provider.
-- @param unit string  The unit token to measure.
-- @return number|nil  The minimum possible distance in yards, or nil when unknown.
-- @return number|nil  The maximum possible distance in yards, or nil when unknown.
local rcf = function(unit) return RangeCheck:GetRange(unit) end

-- Calls a game function under pcall through the per-poll cache; returns ok, then the function's results.
local protectedRead = addon.Functions.cache.protectedRead

-- True for a real, finite number (not NaN, not infinite).
-- @param value any  The value to test.
-- @return boolean  True when value is a number that is neither NaN nor infinite.
local function finite(value) return type(value)=="number" and value==value and value>-math.huge and value<math.huge end

-- Reads a game predicate through the per-poll cache and normalizes it to a boolean.
-- @param cache table  The per-pass memo table the read is cached in.
-- @param method function  The game function to call.
-- @param ... any  Arguments passed to method.
-- @return boolean|nil  True or false (legacy 0/1 answers count as booleans, and nil or 0 as false); nil when the answer
--     cannot be decided.
-- @return string|nil  The reason code when the first value is nil ("missing-api", "api-error", "restricted-value" or
--     "invalid-api-result"); nil otherwise.
--
-- An unreadable (secret) answer is never treated as false.
local function booleanRead(cache, method, ...)
    local ok,result=protectedRead(cache,method,...)
    if not ok then return nil,result=="missing-api" and result or "api-error" end
    if not addon.Platform:CanReadValue(result) then return nil,"restricted-value" end
    if result==nil or result==false or result==0 then return false end
    if result==true or result==1 then return true end
    return nil,"invalid-api-result"
end

-- Reads the world position of a unit.
-- @param cache table  The per-pass memo table the read is cached in.
-- @param unit string  The unit token to locate.
-- @return number|nil  The y coordinate; nil when the position cannot be read.
-- @return number|nil  The x coordinate; nil when the position cannot be read.
-- @return number|nil  The instance ID; nil when the position cannot be read.
-- @return string|nil  The reason code when the position cannot be read; nil otherwise. The reasons are "missing-api",
--     "api-error", "restricted-value", "position-unavailable" (the client has no position for the unit, as for most
--     units outside your instance or party) and "invalid-position-result".
--
-- Note the y-then-x order of UnitPosition.
local function position(cache, unit)
    local ok, y, x, _, instance = protectedRead(cache, UnitPosition, unit)

    if not ok then
        return nil, nil, nil, y == "missing-api" and y or "api-error"
    end
    if
        not addon.Platform:CanReadValue(x)
        or not addon.Platform:CanReadValue(y)
        or not addon.Platform:CanReadValue(instance)
    then
        return nil, nil, nil, "restricted-value"
    end
    if x == nil or y == nil or instance == nil then
        return nil, nil, nil, "position-unavailable"
    end
    if not finite(x) or not finite(y) or not finite(instance) then
        return nil, nil, nil, "invalid-position-result"
    end

    return y, x, instance
end

-- Decides whether another unit is within a radius of an anchor unit.
-- @param cache table  The per-pass memo table the reads are cached in.
-- @param unit string  The anchor unit token.
-- @param y number|nil  The anchor's y coordinate, as already read by the caller.
-- @param x number|nil  The anchor's x coordinate.
-- @param instance number|nil  The anchor's instance ID.
-- @param positionReason string|nil  The reason the anchor's position could not be read; nil when it was read.
-- @param other string  The unit token to test against the anchor.
-- @param radius number  The distance in yards.
-- @return boolean|nil  True when other is within radius, false when it is not; nil when it cannot be decided.
-- @return number|string|nil  The distance (the measured one, or the proven upper bound for a range estimate) when it is
--     known, the reason code when the first value is nil; nil otherwise.
--
-- With coordinates on both units it measures the straight-line distance (units in different instances are never in
-- range). When the anchor has no position and is the player, it falls back to LibRangeCheck's bounds for other; any
-- other position failure is passed through.
local function inRange(cache, unit, y, x, instance, positionReason, other, radius)
    if unit == other then
        return true, 0
    end

    if not positionReason then
        local otherY, otherX, otherInstance, reason = position(cache, other)

        if reason then
            return nil, reason
        end
        if instance ~= otherInstance then
            return false
        end

        local distance = ((x - otherX) ^ 2 + (y - otherY) ^ 2) ^ .5

        if not finite(distance) then
            return nil, "invalid-position-result"
        end

        return distance <= radius, distance
    end

    if positionReason ~= "position-unavailable" or unit ~= "player" then
        return nil, positionReason
    end

    local ok, minimum, maximum = protectedRead(cache, rcf, other)

    if not ok then
        return nil, "range-provider-error"
    end
    if not addon.Platform:CanReadValue(minimum) or not addon.Platform:CanReadValue(maximum) then
        return nil, "restricted-value"
    end
    if
        minimum ~= nil and (not finite(minimum) or minimum < 0)
        or maximum ~= nil and (not finite(maximum) or maximum < 0)
        or minimum and maximum and minimum > maximum
    then
        return nil, "invalid-range-result"
    end
    if minimum == nil and maximum == nil then
        return nil, "range-unavailable"
    end

    -- The shipped range checker's successful upper bound is inclusive. A
    -- positive lower bound comes from a failed checker, so equality is outside;
    -- its synthetic zero floor does not prove a failed zero-yard check.
    if maximum and maximum <= radius then
        return true, maximum
    end
    if minimum and (minimum > radius or minimum > 0 and minimum == radius) then
        return false
    end

    return nil, "range-uncertain"
end

-- Finds the raid subgroup of a raid roster entry.
-- @param cache table  The per-pass memo table the read is cached in.
-- @param index number  The raid roster index.
-- @return number|nil  The subgroup (1 or higher); nil when the roster entry is unreadable.
-- @return string|nil  The reason code when the first value is nil ("raid-roster-unavailable" or "restricted-value");
--     nil otherwise.
local function raidGroup(cache, index)
    local ok, _, _, group = protectedRead(cache, GetRaidRosterInfo, index)

    if not ok then
        return nil, "raid-roster-unavailable"
    end
    if not addon.Platform:CanReadValue(group) then
        return nil, "restricted-value"
    end
    if not finite(group) or group < 1 or group % 1 ~= 0 then
        return nil, "raid-roster-unavailable"
    end

    return group
end

-- ============================================================================
-- Proximity scan
-- ============================================================================

-- Scans the party or raid members (and optionally their pets) within a distance of a unit and calls func for each one.
-- @param value table  The saved condition fields: unit, distance (yards), samegroup and includepets.
-- @param cache table  The per-pass memo table the reads are cached in.
-- @param func function  Called as func(cache, unit, distance) for each member inside the distance. A second return
--     value from it other than nil aborts the scan with that value as the reason.
-- @return boolean|nil  True when the whole roster was decided; nil when it was not.
-- @return string|nil  The reason code when the first value is nil; nil otherwise. A unit that is not in your party or
--     raid gives "proximity-anchor-unavailable".
--
-- One undecidable member invalidates the scan, so a caller must check completion before using what the callback
-- accumulated. Shared with Conditions/spatial_stats.lua.
--
-- Retain the callback(cache,unit,distance) API. A successful estimate supplies its proven upper bound, never an
-- invented exact distance.
addon.proximity_eval = function(value, cache, func)
    if not finite(value.distance) or value.distance < 0 then
        return nil, "invalid-proximity-distance"
    end

    local exists, reason = booleanRead(cache, UnitExists, value.unit)

    if exists == nil then
        return nil, reason
    end
    if not exists then
        return nil, "proximity-anchor-unavailable"
    end

    local prefix, size, group
    local raid, why = booleanRead(cache, IsInRaid)

    if raid == nil then
        return nil, why
    end

    if raid then
        local belongs, issue = booleanRead(cache, UnitPlayerOrPetInRaid, value.unit)

        if belongs == nil then
            return nil, issue
        end

        if belongs then
            prefix, size = "raid", 40
        end
    end

    if not prefix then
        local grouped, issue = booleanRead(cache, IsInGroup)

        if grouped == nil then
            return nil, issue
        end

        if grouped then
            local belongs, problem = booleanRead(cache, UnitPlayerOrPetInParty, value.unit)

            if belongs == nil then
                return nil, problem
            end

            if belongs then
                prefix, size = "party", 4
            end
        elseif value.unit == "player" or value.unit == "pet" then
            prefix, size = "party", 0
        end
    end

    if not prefix then
        return nil, "proximity-anchor-unavailable"
    end

    if prefix == "raid" and value.samegroup then
        local ok, index = protectedRead(cache, UnitInRaid, value.unit)

        if not ok then
            return nil, "raid-roster-unavailable"
        end
        if not addon.Platform:CanReadValue(index) then
            return nil, "restricted-value"
        end

        if index == nil then
            for i = 1, size do
                local matches, issue = booleanRead(cache, UnitIsUnit, value.unit, "raidpet" .. i)

                if matches == nil then
                    return nil, issue
                end

                if matches then
                    index = i
                    break
                end
            end
        end

        if not finite(index) or index < 1 or index > size or index % 1 ~= 0 then
            return nil, "raid-roster-unavailable"
        end

        group, reason = raidGroup(cache, index)

        if not group then
            return nil, reason
        end
    end

    local y, x, instance, positionReason = position(cache, value.unit)

    -- Tests one roster unit and calls func for it when it exists, is in the wanted subgroup and is inside the distance.
    -- @param unit string  The unit token to visit.
    -- @param index number|nil  The unit's raid roster index, used to look up its subgroup.
    -- @return boolean|nil  True when the unit was handled or skipped; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    local function visit(unit, index)
        local present, issue = booleanRead(cache, UnitExists, unit)

        if present == nil then
            return nil, issue
        end
        if not present then
            return true
        end

        if group then
            local memberGroup, problem = raidGroup(cache, index)

            if not memberGroup then
                return nil, problem
            end
            if memberGroup ~= group then
                return true
            end
        end

        local inside, distance = inRange(cache, value.unit, y, x, instance, positionReason, unit, value.distance)

        if inside == nil then
            return nil, distance
        end

        if inside then
            local _, problem = func(cache, unit, distance)

            if problem ~= nil then
                return nil, problem
            end
        end

        return true
    end

    if prefix == "party" then
        local complete, issue = visit("player")

        if not complete then
            return nil, issue
        end
    end

    for i = 1, size do
        local complete, issue = visit(prefix .. i, i)

        if not complete then
            return nil, issue
        end
    end

    if value.includepets then
        if prefix == "party" then
            local complete, issue = visit("pet")

            if not complete then
                return nil, issue
            end
        end

        for i = 1, size do
            local complete, issue = visit(prefix .. "pet" .. i, i)

            if not complete then
                return nil, issue
            end
        end
    end

    return true
end

-- Adds the Distance box and the Same Group and Include Pets checkboxes to a proximity condition's editor.
-- @param top table  The owning condition window; its status line is refreshed after each change.
-- @param root table  The condition tree root passed to funcs:print to rebuild the status text.
-- @param funcs table  The object whose print(root, spec) method builds the status text.
-- @param parent table  The editor group the controls are added to.
-- @param spec any  The specialization the condition is being edited for.
-- @param value table  The saved condition fields; distance, samegroup and includepets are written.
--
-- Each change writes the field and refreshes the status text. Shared with Conditions/spatial_stats.lua.
addon.proximity_widgets = function(top, root, funcs, parent, spec, value)
    local distance = addon:CreateConditionEditBox()
    distance:SetWidth(100)
    distance:SetLabel(L["Distance"])
    distance:SetText(value.distance)

    distance:SetCallback("OnEnterPressed", function(_, _, v)
        value.distance = tonumber(v)
        top:SetStatusText(funcs:print(root, spec))
    end)

    parent:AddChild(distance)

    local samegroup = addon:CreateConditionCheckBox()
    samegroup:SetWidth(100)
    samegroup:SetLabel(L["Same Group"])
    samegroup:SetValue(value.samegroup and true or false)

    samegroup:SetCallback("OnValueChanged", function(_, _, v)
        value.samegroup = v
        top:SetStatusText(funcs:print(root, spec))
    end)

    parent:AddChild(samegroup)

    local includepets = addon:CreateConditionCheckBox()
    includepets:SetWidth(100)
    includepets:SetLabel(L["Include Pets"])
    includepets:SetValue(value.includepets and true or false)

    includepets:SetCallback("OnValueChanged", function(_, _, v)
        value.includepets = v
        top:SetStatusText(funcs:print(root, spec))
    end)

    parent:AddChild(includepets)
end

-- PROXIMITY: compares the number of allies in your party or raid within `distance` yards of a unit with `value` using
-- `operator`. Returns `nil, reason` when addon.proximity_eval cannot decide every member (uncertain positions or
-- ranges), so the whole condition is unavailable rather than counting a guess. Stores `unit`, `operator`, `value`,
-- `distance`, `samegroup` and `includepets`. The editor adds the shared proximity widgets after the unit and operator.
addon:RegisterCondition("PROXIMITY", {
    description = L["Allies Within Range"],
    icon = addon.Artwork.condition["PROXIMITY"],
    fields = {
        unit = "string",
        operator = "string",
        value = "number",
        distance = "number",
        samegroup = "boolean",
        includepets = "boolean",
    },
    -- Checks that the saved fields of the PROXIMITY condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- A known unit and operator, and a non-negative count and distance.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and
                value.distance ~= nil and value.distance >= 0)
    end,
    -- Compares the number of allies in your party or raid within the configured distance of a unit with the configured
    -- number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Counts the members the scan reports inside the distance; unavailable (`nil, reason`) when the scan is incomplete.
    evaluate = function(value, cache)
        local count = 0
        local complete,reason=addon.proximity_eval(value, cache, function()
            count = count + 1
        end)
        if not complete then return nil,reason end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Builds the readable rule summary for the PROXIMITY condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
                string.format(L["the number of %s members%s within %s yards of %s"],
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        Functions.presentation.nullable(value.distance, L["<distance>"]),
                        Functions.presentation.nullable(addon.units[value.unit], L["<unit>"])),
                Functions.presentation.nullable(value.value))
    end,
    -- Builds the editor controls for the PROXIMITY condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        addon.proximity_widgets(top, root, funcs, parent, spec, value)
    end,
    -- Builds the help page for the PROXIMITY condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Allies Within Range"], L["Count"],
                "The number of allies whose proximity is measured in relation to " .. color.BLIZ_YELLOW .. L["Unit"] ..
                        color.RESET .. ".  This will only measure the proximity of allies you are in a party or raid with.")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                "The distance (in yards) allies are measured against."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Same Group"] .. color.RESET .. " - " ..
                "Only count units in the same raid group."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Include Pets"] .. color.RESET .. " - " ..
                "Include pets in the count."))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Uses readable positions in the same instance, or player-centered range estimates when positions are unavailable. A unit counts only when its upper range bound is within Distance. Uncertain positions, range, subgroup membership or required health/mana values keep the whole condition unavailable, including under Unless. Percentage checks require a positive maximum; empty aggregates have no result."]))
    end,
})

-- ============================================================================
-- Distance
-- ============================================================================

-- DISTANCE: true when the unit is within `value` yards of you, judged by the upper bound of LibRangeCheck's range (it
-- reports a range, not an exact distance). False when the unit does not exist; `nil, reason` when presence or the
-- range is unreadable, there is no usable bound ("range-unavailable", "invalid-range-result") or the range provider
-- fails. Stores `unit` and `value`; LibRangeCheck cannot measure past 40 yards, so larger values are invalid.
addon:RegisterCondition("DISTANCE", {
    description = L["Distance"],
    icon = addon.Artwork.condition["DISTANCE"],
    fields = { unit = "string", value = "number" },
    -- Checks that the saved fields of the DISTANCE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- A known unit and a distance of 0 to 40 yards.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.value ~= nil and value.value >= 0 and value.value <= 40)
    end,
    -- Decides whether the unit is within the configured number of yards of you, judged by the upper bound of
    -- LibRangeCheck's range.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable cases are listed above; a missing unit is false.
    evaluate = function(value, cache)
        local exists,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPresenceObservation,addon.Platform,value.unit)
        if exists==nil then return nil,reason or 'unit-data-unavailable' end
        if exists==false then return false end
        if exists~=true then return nil,'invalid-api-result' end
        -- pcall preserves both range bounds returned by the cached observation.
        ---@diagnostic disable-next-line: unbalanced-assignments
        local ok, minRange, maxRange = pcall(Functions.cache.getCached, cache, rcf, value.unit)
        if not ok then return nil, "range-provider-error" end
        if not addon.Platform:CanReadValue(minRange) or not addon.Platform:CanReadValue(maxRange) then return nil, "restricted-value" end
        for index=1,2 do
            local distance=minRange;if index==2 then distance=maxRange end
            if distance~=nil and (type(distance)~="number" or distance~=distance or distance<0 or distance==math.huge) then return nil, "invalid-range-result" end
        end
        if maxRange==nil then return nil, "range-unavailable" end
        if minRange and minRange>maxRange then return nil, "invalid-range-result" end
        return maxRange <= value.value
    end,
    -- Builds the readable rule summary for the DISTANCE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} %s"], L["%s {{!is|is not}} %s"]),
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                string.format(L["closer than %s yards"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the DISTANCE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local distance = addon:CreateConditionEditBox()
        distance:SetWidth(75)
        distance:SetLabel(L["Distance"])
        distance:SetText(value.value)
        distance:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(distance)
    end,
    -- Builds the help page for the DISTANCE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
            "This distance " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " must be within, in yards.  " ..
            "There are significant restrictions on how accurately distances can be measured, and all distances " ..
            "are within a range.  This will assume the unit is at the maximum of the measurable range.  Only " ..
            "distances less than or equal to 40 yards can be measured."))
    end,
})

-- Decides whether a unit is provably within a distance of you from its LibRangeCheck bounds.
-- @param cache table  The per-pass memo table the bounds are cached in.
-- @param unit string  The unit token to test.
-- @param distance number  The distance in yards.
-- @return boolean|nil  True when the upper bound is inside, false when the lower bound is outside; nil when neither
--     proves it.
-- @return string|nil  The reason code when the first value is nil ("range-uncertain", or why the bounds cannot be
--     read); nil otherwise.
local function rangeMember(cache, unit, distance)
    local bounds,why=Functions.cache.getCached(cache,addon.Platform.GetRangeCheckBounds,addon.Platform,unit)
    if not bounds then return nil,why end
    if bounds.maximum and bounds.maximum<=distance then return true end
    if bounds.minimum and (bounds.minimum>distance or bounds.minimum>0 and bounds.minimum==distance) then return false end
    return nil,"range-uncertain"
end

-- Applies the in-combat filter to a unit.
-- @param value table  The saved condition fields; reads incombat.
-- @param cache table  The per-pass memo table the read is cached in.
-- @param unit string  The unit token to test.
-- @return boolean|nil  True when the filter is off or the unit is in combat, false when it is not; nil when it cannot
--     be read.
-- @return string|nil  The reason code when the first value is nil; nil otherwise.
--
-- UnitAffectingCombat takes a token and carries no secret annotation; the answer is still read through booleanRead.
local function combatFilter(value, cache, unit)
    if not value.incombat then return true end
    local fighting,why=booleanRead(cache,UnitAffectingCombat,unit)
    if fighting==nil then return nil,why end
    return fighting
end

-- Compares the number of nameplate units that qualify with the configured number.
-- @param value table  The saved condition fields: enemy, incombat, distance, operator and value.
-- @param cache table  The per-pass memo table the reads are cached in.
-- @param plates table|nil  The nameplate unit tokens as table keys; anything but a table is unavailable.
-- @return boolean|nil  The comparison of the count of units that exist, match the enemy flag, pass the combat filter
--     and are provably within the distance; nil when any unit cannot be decided.
-- @return string|nil  The reason code when the first value is nil; nil otherwise.
--
-- Nameplate tokens are reported by NAME_PLATE_UNIT_ADDED/REMOVED on restricted clients (main.lua). UnitExists,
-- UnitIsEnemy and the range provider carry no secret annotation; every result is still checked before use.
local function nameplateDistanceCount(value, cache, plates)
    if type(plates)~="table" then return nil,"unit-snapshot-unavailable" end
    local count = 0
    for unit in pairs(plates) do
        if not addon.Platform:CanReadValue(unit) then return nil,"restricted-value" end
        if type(unit)~="string" or unit=="" then return nil,"invalid-unit-snapshot" end
        local present,issue=booleanRead(cache,UnitExists,unit)
        if present==nil then return nil,issue end
        if present then
            local enemy,problem=booleanRead(cache,UnitIsEnemy,"player",unit)
            if enemy==nil then return nil,problem end
            if enemy==value.enemy then
                local fighting,combatWhy=combatFilter(value,cache,unit)
                if fighting==nil then return nil,combatWhy end
                if fighting then
                    local member,why=rangeMember(cache,unit,value.distance)
                    if member==nil then return nil,why end
                    if member then count=count+1 end
                end
            end
        end
    end
    return Functions.values.compare(value.operator, count, value.value)
end

-- DISTANCE_COUNT: compares the number of observed enemies (or non-enemies, per `enemy`) within `distance` yards of you
-- with `value` using `operator`; with `incombat`, only units in combat count. It counts the addon's observed unit
-- snapshot, not every nearby unit. Returns `nil, reason` when the snapshot is missing, any counted unit's identity,
-- hostility or range is unreadable or uncertain, or the distance exceeds the nameplate distance setting
-- ("distance-exceeds-nameplate-limit"). Stores `value`, `operator`, `distance`, `enemy` and `incombat`.
addon:RegisterCondition("DISTANCE_COUNT", {
    description = L["Distance Count"],
    icon = addon.Artwork.condition["DISTANCE_COUNT"],
    fields = { value = "number", operator = "string", distance = "number", enemy = "boolean", incombat = "boolean" },
    -- Checks that the saved fields of the DISTANCE_COUNT condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Every field must be present and well formed: finite non-negative numbers, a known operator, a boolean `enemy`.
    valid = function(_, value)
        return finite(value.value) and value.value >= 0 and
            Functions.values.isin(addon.operators, value.operator) and type(value.enemy)=="boolean" and
            (value.incombat==nil or type(value.incombat)=="boolean") and
            finite(value.distance) and value.distance >= 0
    end,
    -- Compares the number of observed enemies (or non-enemies) within the configured distance of you with the
    -- configured number.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Restricted clients count nameplate tokens; other clients count the GUID snapshot after checking that each token
    -- still belongs to the recorded GUID. One uncertain unit makes the whole count unavailable.
    evaluate = function(value, cache)
        local maximum,reason=Functions.cache.getCached(cache,addon.Platform.GetNameplateMaxDistance,addon.Platform)
        if maximum==nil then return nil,reason end
        if value.distance>maximum then return nil,"distance-exceeds-nameplate-limit" end
        -- Restricted clients keep nameplate unit tokens instead of the GUID
        -- snapshot (an NPC's GUID is secret there); each token is read live.
        local plates=addon.nameplateUnits
        if plates~=nil then return nameplateDistanceCount(value,cache,plates) end
        if type(addon.unitsInRange)~="table" then return nil,"unit-snapshot-unavailable" end
        local count = 0
        for guid, entity in pairs(addon.unitsInRange) do
            if not addon.Platform:CanReadValue(guid) then return nil,"restricted-value" end
            if type(guid)~="string" or guid=="" or type(entity)~="table" then return nil,"invalid-unit-snapshot" end
            if not addon.Platform:CanReadValue(entity.unit) then return nil,"restricted-value" end
            if type(entity.unit)~="string" or entity.unit=="" then return nil,"invalid-unit-snapshot" end
            local present,issue=booleanRead(cache,UnitExists,entity.unit)
            if present==nil then return nil,issue end
            if present then
                local ok,current=protectedRead(cache,UnitGUID,entity.unit)
                if not ok then return nil,current=="missing-api" and current or "api-error" end
                if not addon.Platform:CanReadValue(current) then return nil,"restricted-value" end
                if type(current)~="string" or current=="" then return nil,"unit-identity-unavailable" end
                -- A recycled token belongs to another identity. Do not expand
                -- the snapshot to include that replacement before its event.
                if current==guid then
                    local enemy,problem=booleanRead(cache,UnitIsEnemy,"player",entity.unit)
                    if enemy==nil then return nil,problem end
                    if enemy==value.enemy then
                        local fighting,combatWhy=combatFilter(value,cache,entity.unit)
                        if fighting==nil then return nil,combatWhy end
                        if fighting then
                            local bounds,why=Functions.cache.getCached(cache,addon.Platform.GetRangeCheckBounds,addon.Platform,entity.unit)
                            if not bounds then return nil,why end
                            if bounds.maximum and bounds.maximum<=value.distance then count=count+1
                            elseif not (bounds.minimum and (bounds.minimum>value.distance or bounds.minimum>0 and bounds.minimum==value.distance)) then return nil,"range-uncertain" end
                        end
                    end
                end
            end
        end
        return Functions.values.compare(value.operator, count, value.value)
    end,
    -- Builds the readable rule summary for the DISTANCE_COUNT condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
                        string.format(value.incombat and L["Number of %s in combat within %s yards"] or L["Number of %s within %s yards"],
                            (value.enemy and L["enemies"] or L["allies"]),
                            Functions.presentation.nullable(value.distance, L["<distance>"])),
                        Functions.presentation.nullable(value.value))
    end,
    -- Builds the editor controls for the DISTANCE_COUNT condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local enemy = addon:CreateConditionCheckBox()
        enemy:SetWidth(100)
        enemy:SetLabel(L["Enemy"])
        enemy:SetValue(value.enemy==true)
        enemy:SetCallback("OnValueChanged", function(_, _, v)
            value.enemy = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(enemy)

        local incombat = addon:CreateConditionCheckBox()
        incombat:SetWidth(150)
        incombat:SetLabel(L["In Combat"])
        incombat:SetValue(value.incombat==true)
        incombat:SetCallback("OnValueChanged", function(_, _, v)
            value.incombat = v or nil
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(incombat)

        local operator_group = addon:Widget_OperatorWidget(value, L["Count"],
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local distance = addon:CreateConditionSlider()
        distance:SetWidth(150)
        distance:SetLabel(L["Distance"])
        distance:SetValue(value.distance)
        local maximum=addon.Platform:GetNameplateMaxDistance()
        distance:SetSliderValues(0, maximum or math.max(1,finite(value.distance) and value.distance or 1), 1)
        distance:SetDisabled(maximum==nil)
        distance:SetCallback("OnValueChanged", function(_, _, v)
            value.distance = tonumber(v)
            top:SetStatusText(funcs:print(root, spec))
        end)

        parent:AddChild(distance)
    end,
    -- Builds the help page for the DISTANCE_COUNT condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Enemy"] .. color.RESET .. " - " ..
            L["Count enemies when selected, or non-enemies when cleared."]))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["In Combat"] .. color.RESET .. " - " ..
            L["Help.Conditions.DISTANCE_COUNT_COMBAT"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Distance Count"], L["Count"],
            L["The number of observed units proven within Distance of you."])
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Distance"] .. color.RESET .. " - " ..
                L["Counts the addon's observed unit snapshot, including nameplates and tracked unit aliases, rather than every nearby unit. A unit counts only when its upper range bound is within Distance; uncertain membership or unreadable identity, hostility, range or nameplate settings makes the whole count unavailable, including under Unless. Known vanished or reused unit tokens are excluded. Distance cannot exceed the current nameplate distance setting; that setting does not guarantee a complete scan."]))
        frame:AddChild(helpers.Gap())
    end,
})

-- ============================================================================
-- Zone
-- ============================================================================

-- ZONE: true when the zone text (or the subzone text, with `subzone`) equals the saved name exactly. Returns `nil,
-- reason` when the text API is missing or fails, or the text is restricted or not a string. Stores `value` (the name,
-- as the client spells it in its own language) and `subzone`.
addon:RegisterCondition("ZONE", {
    description = L["Zone"],
    icon = addon.Artwork.condition["ZONE"],
    fields = { value = "string", subzone = "boolean" },
    -- Checks that the saved fields of the ZONE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid once a name is entered.
    valid = function(_, value)
        return value.value ~= nil
    end,
    -- Decides whether the zone text (or the subzone text, when subzone is set) equals the saved name exactly.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable cases are listed above; otherwise a plain string comparison.
    evaluate = function(value, cache)
        local method
        if value.subzone then method=GetSubZoneText else method=GetZoneText end
        if type(method)~='function' then return nil,'missing-api' end
        local ok,zoneName=pcall(Functions.cache.getCached,cache,method)
        if not ok then return nil,'api-error' end
        if not addon.Platform:CanReadValue(zoneName) then return nil,'restricted-value' end
        if type(zoneName)~='string' then return nil,'zone-text-unavailable' end
        return value.value == zoneName
    end,
    -- Builds the readable rule summary for the ZONE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    print = function(_, value)
        return LiteralSummary.phrase(L["{{!in|not in}} {zone}"], {zone = Functions.presentation.nullable(value.value, L["<zone>"])})
    end,
    -- Builds the editor controls for the ZONE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local subzone = addon:CreateConditionCheckBox()
        subzone:SetWidth(100)
        subzone:SetLabel(L["SubZone"])
        subzone:SetValue(value.subzone and true or false)
        subzone:SetCallback("OnValueChanged", function(_, _, v)
            value.subzone = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(subzone)

        local zone = addon:CreateConditionEditBox()
        zone:SetLabel(L["Zone"])
        zone:SetCallback("OnEnterPressed", function(_, _, v)
            value.value = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        if (value.value ~= nil) then
            zone:SetText(value.value)
        end
        parent:AddChild(zone)
    end,
    -- Builds the help page for the ZONE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["SubZone"] .. color.RESET ..
                " - " .. "Use the SubZone text instead of Zone text (eg. Valley of Strength instead of Orgrimmar)"))
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Zone"] .. color.RESET ..
                " - " .. "The zone you are in."))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="RangeCheck" then return RangeCheck end
        if name=="booleanRead" then return booleanRead end
        if name=="color" then return color end
        if name=="combatFilter" then return combatFilter end
        if name=="finite" then return finite end
        if name=="helpers" then return helpers end
        if name=="nameplateDistanceCount" then return nameplateDistanceCount end
        if name=="protectedRead" then return addon.builtinSourceModules["Functions/cache.lua"]("protectedRead") end
        if name=="rangeMember" then return rangeMember end
        if name=="rcf" then return rcf end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/spatial.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/spatial.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
