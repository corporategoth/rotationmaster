-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Display gates of rotation steps ("shown by the game when health or power is below or above N%"). Where the value is
-- readable, a gate is an ordinary test (GetGateObservation). Where the client hides it (Retail and Forever), RM never
-- reads it: UnitHealthPercent / UnitPowerPercent evaluate it through a step curve and hand back a secret 0 or 1, which a
-- texture's SetAlpha accepts from addon code (GetGateAlphas). The game then decides what shows; the rotation cannot
-- branch on it. Loaded from RotationMaster.toc after Platform/memory.lua; main.lua and UI/preview.lua use it.
local _, addon = ...
local platform = addon.Platform

-- Curves by "operator:percent:inverse", built once; false when the client cannot build one.
local curves = {}

-- Tests a gate against readable values.
-- @param gate table  { unit, kind = 'health'|'power', operator = 'LESSTHAN'|'GREATERTHAN', value = percent }.
-- @return boolean|nil  Whether the step shows; nil when the value cannot be read.
-- @return string|nil  The reason code when the first return is nil ('unit-data-unavailable' for a missing unit).
function platform:GetGateObservation(gate)
    local observed, reason

    if gate.kind == 'health' then
        observed, reason = self:GetUnitHealthObservation(gate.unit, true)
    else
        observed, reason = self:GetUnitPowerObservation(gate.unit, 'current', true)
    end

    if not observed then
        return nil, reason
    end
    if not observed.exists then
        return nil, 'unit-data-unavailable'
    end
    if type(observed.current) ~= 'number' or type(observed.maximum) ~= 'number' or observed.maximum <= 0 then
        return nil, 'gate-data-unavailable'
    end

    local percent = observed.current / observed.maximum * 100

    if gate.operator == 'LESSTHAN' then
        return percent < gate.value
    end

    return percent > gate.value
end

-- Builds (once) the step curve that is 1 on the gate's side of the threshold and 0 on the other, or the reverse.
-- @param operator string  'LESSTHAN' or 'GREATERTHAN'.
-- @param value number  The threshold percent.
-- @param inverse boolean  True for the curve that is 1 where the gate is closed.
-- @return table|nil  The curve; nil when the client cannot build one.
local function curveFor(operator, value, inverse)
    local key = operator .. ':' .. value .. ':' .. tostring(inverse)
    local known = curves[key]

    if known ~= nil then
        return known or nil
    end

    local util, enum = C_CurveUtil, Enum and Enum.LuaCurveType

    local ok, curve = pcall(function()
        local made = util.CreateCurve()

        if enum and enum.Step then
            made:SetType(enum.Step)
        end

        local at = math.max(0.01, math.min(0.99, value / 100))
        local below = operator == 'LESSTHAN'

        if inverse then
            below = not below
        end

        local low, high = below and 1 or 0, below and 0 or 1
        made:AddPoint(0, low)
        made:AddPoint(at, high)
        made:AddPoint(1, high)
        return made
    end)

    curves[key] = ok and type(util) == 'table' and curve or false
    return curves[key] or nil
end

-- Reads a unit's health for a display widget, without looking at it: on Retail and Forever these are secret values a
-- StatusBar accepts from addon code (SetMinMaxValues, SetValue); elsewhere plain numbers. Never compare the returns.
-- @param unit string  The unit token.
-- @return any  The current health; nil when the unit does not exist or the API is missing.
-- @return any  The maximum health.
function platform:GetUnitHealthPassthrough(unit)
    if type(UnitExists) ~= 'function' or type(UnitHealth) ~= 'function' or type(UnitHealthMax) ~= 'function' then
        return nil
    end

    local ok, exists = pcall(UnitExists, unit)

    if not ok or not self:CanReadValue(exists) or not exists then
        return nil
    end

    local currentOk, current = pcall(UnitHealth, unit)
    local maximumOk, maximum = pcall(UnitHealthMax, unit)

    if not currentOk or not maximumOk then
        return nil
    end

    return current, maximum
end

-- Asks the game for a gate's alpha pair without reading the value.
-- @param gate table  The gate.
-- @return any  The alpha for the gated icon (a secret 0 or 1); nil when the client cannot do this.
-- @return any  The alpha for what shows when the gate is closed (the inverse).
function platform:GetGateAlphas(gate)
    if type(C_CurveUtil) ~= 'table' or type(C_CurveUtil.CreateCurve) ~= 'function' then
        return nil
    end

    local open, closed = curveFor(gate.operator, gate.value, false), curveFor(gate.operator, gate.value, true)

    if not open or not closed then
        return nil
    end

    local evaluate

    if gate.kind == 'health' then
        if type(UnitHealthPercent) ~= 'function' then
            return nil
        end

        evaluate = function(curve) return UnitHealthPercent(gate.unit, true, curve) end
    else
        if type(UnitPowerPercent) ~= 'function' then
            return nil
        end

        evaluate = function(curve) return UnitPowerPercent(gate.unit, nil, false, curve) end
    end

    local ok, alpha = pcall(evaluate, open)
    local ok2, inverse = pcall(evaluate, closed)

    if not ok or not ok2 or alpha == nil or inverse == nil then
        return nil
    end

    return alpha, inverse
end

-- Reads a unit's primary power for a display widget, without looking at it (as GetUnitHealthPassthrough). Never compare
-- the first two returns.
-- @param unit string  The unit token.
-- @return any  The current power; nil when the unit does not exist or the API is missing.
-- @return any  The maximum power.
-- @return table|nil  The power type's bar color { r, g, b } when the type is readable.
function platform:GetUnitPowerPassthrough(unit)
    if type(UnitExists) ~= 'function' or type(UnitPower) ~= 'function' or type(UnitPowerMax) ~= 'function' then
        return nil
    end

    local ok, exists = pcall(UnitExists, unit)

    if not ok or not self:CanReadValue(exists) or not exists then
        return nil
    end

    local currentOk, current = pcall(UnitPower, unit)
    local maximumOk, maximum = pcall(UnitPowerMax, unit)

    if not currentOk or not maximumOk then
        return nil
    end

    local color

    if type(UnitPowerType) == 'function' and type(PowerBarColor) == 'table' then
        local typeOk, _, token = pcall(UnitPowerType, unit)

        if typeOk and self:CanReadValue(token) and type(token) == 'string' then
            color = PowerBarColor[token]
        end
    end

    return current, maximum, color
end

-- Reads what a unit is casting or channeling for a cast bar, without looking at the times where they are hidden.
-- @param unit string  The unit token.
-- @return string|nil  'duration' (a duration object for StatusBar:SetTimerDuration), 'times' (readable start and end in
--   milliseconds), or nil when the unit is not casting or nothing usable can be had.
-- @return any  The duration object, or the start time.
-- @return number|nil  The end time, for 'times'.
function platform:GetUnitCastPassthrough(unit)
    for _, pair in ipairs({ { UnitCastingInfo, UnitCastingDuration }, { UnitChannelInfo, UnitChannelDuration } }) do
        local info, duration = pair[1], pair[2]

        if type(info) == 'function' then
            -- A secret name is never nil, so presence is known even where the details are hidden.
            local ok, name, _, _, start, finish = pcall(info, unit)

            if ok and name ~= nil then
                if type(duration) == 'function' then
                    local durationOk, object = pcall(duration, unit)

                    if durationOk and object ~= nil then
                        return 'duration', object
                    end
                end

                if
                    self:CanReadValue(start)
                    and self:CanReadValue(finish)
                    and type(start) == 'number'
                    and type(finish) == 'number'
                    and finish > start
                then
                    return 'times', start, finish
                end

                return nil
            end
        end
    end

    return nil
end
