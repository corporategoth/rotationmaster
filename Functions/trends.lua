-- Historical health-trend formulas: calculateOld works from health snapshots, calculate from damage and heal history.
-- utils.lua re-exports them as addon.calculate_trend_old and addon.calculate_trend for saved custom source.
-- Loaded from RotationMaster.toc after Functions/cache.lua and before Functions/forecast.lua. They read the live
-- profile window, GetTime() and addon.round, and do not validate their input; the checked replacement is
-- Functions/forecast.lua. Callers must not pass restricted (secret) values.
-- The function bodies are recorded as Built In helpers and are frozen: saved copies hash their exact text.
local _, addon = ...
local trends = {}
addon.Functions = addon.Functions or {}
addon.Functions.trends = trends

-- Estimates the health change per second from newest-first snapshots of time/value/max.
-- @param health table[]|nil  Snapshots {time=number, value=number, max=number}, newest first.
-- @return number  The rate (0 when there is nothing to weigh).
-- @return number|nil  The bucket count; nil when only 0 is returned.
--
-- Weights each one-second bucket within the profile's damage_history window. Runtime history services keep their live
-- addon/profile, clock and legacy rounding lookups; canonical ownership does not change those contracts.
function trends.calculateOld(health)
    if not health then
        return 0
    end

    local damage_history = addon.db.profile.damage_history
    local now = GetTime()
    local total, count, seconds = 0, 0, 0

    local last_health, last_offs, last_max
    local offs_total = 0
    for _,v in ipairs(health) do
        if v.value >= v.max or v.value == 0 then
            break
        end

        if last_max ~= v.max then
            last_health = nil
            last_max = v.max
        end

        local offs = addon.round(now - v.time)
        if last_health ~= nil then
            offs_total = offs_total + (last_health - v.value)

            if last_offs ~= offs then
                local scale = damage_history - offs
                count = count + scale
                total = total + (offs_total * scale)
                seconds = seconds + 1
                offs_total = 0
            end
        end
        last_health = v.value
        last_offs = offs
    end

    -- seconds is a number, so test it: with no change recorded (or no weight)
    -- total/count is 0/0, and the trend is zero, not NaN.
    if seconds > 0 and count ~= 0 then
        return total / count, seconds
    end
    return 0
end

-- Estimates the signed health change from history.damage (negative) and history.heals (positive), weighting newer
-- entries more across the window.
-- @param history table|nil  {damage=table[], heals=table[]} rows of {time=number, value=number}; a falsy history
--   returns 0.
-- @param window number|nil  The weighting window in seconds; nil means the profile damage_history setting.
-- @param noheals boolean|nil  True to skip the heal stream.
-- @param nodmg boolean|nil  True to skip the damage stream.
-- @return number  The combined rate (0 for a falsy history).
-- @return number|nil  The larger rounded stream age; nil when only 0 is returned.
function trends.calculate(history, window, noheals, nodmg)
    if not history then
        return 0
    end

    if not window then
        window = addon.db.profile.damage_history
    end

    local now = GetTime()
    local damage_total, damage_count, damage_seconds = 0, 0, 0
    local heal_total, heal_count, heal_seconds = 0, 0, 0

    local maxoffs, data = 0, {}
    if not nodmg then
        for _,v in ipairs(history.damage) do
            local diff = now - v.time
            local scale = window - diff
            maxoffs = addon.round(diff)
            if maxoffs > window then
                break
            end

            if v.value then
                data[maxoffs] = (data[maxoffs] or 0) + (v.value * scale)
            end
        end
        damage_seconds = maxoffs
        for i=0,maxoffs do
            damage_total = damage_total + (data[i] or 0)
            damage_count = damage_count + (window - i)
        end
    end

    if not noheals then
        maxoffs, data = 0, {}
        for _,v in ipairs(history.heals) do
            local diff = now - v.time
            local scale = window - diff
            maxoffs = addon.round(diff)
            if maxoffs > window then
                break
            end

            if v.value then
                data[maxoffs] = (data[maxoffs] or 0) + (v.value * scale)
            end
        end
        heal_seconds = maxoffs
        for i=0,maxoffs do
            heal_total = heal_total + (data[i] or 0)
            heal_count = heal_count + (window - i)
        end
    end

    return (((damage_count > 0) and (-damage_total / damage_count) or 0) +
           ((heal_count > 0) and (heal_total / heal_count) or 0)),
           (damage_seconds > heal_seconds and damage_seconds or heal_seconds)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="calculate" then return addon.Functions.trends.calculate end
        if name=="calculateOld" then return addon.Functions.trends.calculateOld end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/trends.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/trends.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
