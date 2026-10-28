-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict inverse of the three authorized TBC POINT transport deltas only.
local changes = {
    ['Core/point_conditions.lua'] = {
        old = [====[]====],
        new = [====[-- Optional trusted-load capability for the explicitly versioned TBC policy.
-- An inherited or subsequently replaced enum remains on the original transport.
local pointComboTypes,pointComboValue
do
    local platform=addon.Platform
    local enum=Enum
    if platform:CanReadValue(enum) and (not canaccessvalue or canaccessvalue(enum)) and type(enum)=='table' then
        local types=rawget(enum,'PowerType')
        if platform:CanReadValue(types) and (not canaccessvalue or canaccessvalue(types)) and type(types)=='table' then
            pointComboTypes=types
            pointComboValue=rawget(types,'ComboPoints')
        end
    end
end

-- New Built In POINT copies may opt into the player/target transport; old sources keep the API above.
function addon:GetConditionPointResourceV2(unit,cache)
    local platform=self.Platform
    local info=platform:GetClientInfo()
    if info.combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    if not platform:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    local record,reason=addon.Functions.cache.getCached(cache,pointIdentity,self,unit,playerClassCacheKey)
    if not record then return nil,reason end
    if not record.exists then return false end
    local points=self.points
    if not platform:CanReadValue(points) then return nil,'restricted-value' end
    if type(points)~='table' then return nil,'invalid-point-resource-map' end
    local fallbackEnum,fallbackTypes
    local ok,selected=pcall(function() return points[record.class] end)
    if not ok then return nil,'api-error' end
    if not platform:CanReadValue(selected) then return nil,'restricted-value' end
    if selected==nil or selected==false then
        local enum=Enum
        if not platform:CanReadValue(enum) then return nil,'restricted-value' end
        if type(enum)~='table' then return nil,'point-resource-unavailable' end
        local typesOK,types=pcall(function() return enum.PowerType end)
        if not typesOK then return nil,'api-error' end
        if not platform:CanReadValue(types) then return nil,'restricted-value' end
        if type(types)~='table' then return nil,'point-resource-unavailable' end
        local fallbackOK,fallback=pcall(function() return types.ComboPoints end)
        if not fallbackOK then return nil,'api-error' end
        selected=fallback
        if not platform:CanReadValue(selected) then return nil,'restricted-value' end
        fallbackEnum,fallbackTypes=enum,types
    end
    if selected==nil then return nil,'point-resource-unavailable' end
    if type(selected)~='number' or selected~=selected or selected<0 or selected==math.huge or selected%1~=0 then return nil,'invalid-point-resource' end
    local transport='power'
    if unit=='player' and fallbackTypes then
        local rawTypes,rawCombo=rawget(fallbackEnum,'PowerType'),rawget(fallbackTypes,'ComboPoints')
        if platform:CanReadValue(pointComboTypes) and (not canaccessvalue or canaccessvalue(pointComboTypes))
            and platform:CanReadValue(rawTypes) and (not canaccessvalue or canaccessvalue(rawTypes))
            and rawequal(fallbackTypes,pointComboTypes) and rawequal(rawTypes,fallbackTypes)
            and platform:CanReadValue(rawCombo) and (not canaccessvalue or canaccessvalue(rawCombo)) and rawCombo==selected
            and platform:CanReadValue(pointComboValue) and (not canaccessvalue or canaccessvalue(pointComboValue))
            and pointComboValue==selected then
            local family
            if platform:CanReadValue(info) and type(info)=='table' then family=rawget(info,'family') end
            if platform:CanReadValue(family) and (not canaccessvalue or canaccessvalue(family)) and family=='tbc' then transport='target-combo' end
        end
    end
    return selected,nil,transport
end

]====],
        length = 3967,
        hash = '43679b49',
    },
    ['Platform/points.lua'] = {
        old = [====[]====],
        new = [====[-- Explicit player/target combo transport. Other units/resources use the observer above.
function platform:GetPlayerComboPointObservation(powerType,kind)
    local info=self:GetClientInfo()
    if info.combatDataPolicy~='probe' then return nil,'unsupported-policy' end
    local family
    if self:CanReadValue(info) and type(info)=='table' then family=rawget(info,'family') end
    if not self:CanReadValue(family) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(family) then return nil,'restricted-value' end
    if family~='tbc' then return nil,'unsupported-point-transport' end
    if not self:CanReadValue(powerType) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if type(powerType)~='number' or powerType~=powerType or powerType<0 or powerType==math.huge or powerType%1~=0 then return nil,'invalid-point-power-query' end
    if kind~='current' and kind~='maximum' then return nil,'invalid-point-power-query' end
    local api
    if kind=='current' then api=GetComboPoints else api=UnitPowerMax end
    if type(api)~='function' then return nil,'missing-api' end
    local ok,result
    if kind=='current' then ok,result=pcall(api,'player','target') else ok,result=pcall(api,'player',powerType) end
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(result) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(result) then return nil,'restricted-value' end
    if result==nil then return nil,'point-power-unavailable' end
    if type(result)~='number' or result~=result or result==math.huge or result==-math.huge then return nil,'invalid-api-result' end
    return result
end

]====],
        length = 3637,
        hash = '926baaf3',
    },
    ['Conditions/stats.lua'] = {
        old = [====[    evaluate = function(value, cache)
        local point,reason=addon:GetConditionPointResource(value.unit,cache)
        if point==nil then return nil,reason end
        if point==false then return false end
        local cur,why=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"current")
        if cur==nil then return nil,why end
        if value.value < 0 then
            local maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"maximum")
            if maximum==nil then return nil,maximumReason end
            local deficit=maximum-cur
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-point-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,]====],
        new = [====[    evaluate = function(value, cache)
        local point,reason,transport=addon:GetConditionPointResourceV2(value.unit,cache)
        if point==nil then return nil,reason end
        if point==false then return false end
        local cur,why
        if transport=="target-combo" then
            cur,why=Functions.cache.getCached(cache,addon.Platform.GetPlayerComboPointObservation,addon.Platform,point,"current")
        else
            cur,why=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"current")
        end
        if cur==nil then return nil,why end
        if value.value < 0 then
            local maximum,maximumReason
            if transport=="target-combo" then
                maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetPlayerComboPointObservation,addon.Platform,point,"maximum")
            else
                maximum,maximumReason=Functions.cache.getCached(cache,addon.Platform.GetUnitPointPowerObservation,addon.Platform,value.unit,point,"maximum")
            end
            if maximum==nil then return nil,maximumReason end
            local deficit=maximum-cur
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-point-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, cur, value.value)
        end
    end,]====],
        length = 38965,
        hash = 'd72c6f4e',
    },
}

local function replace(text, old, new)
    local first, last = text:find(old, 1, true)
    assert(first and not text:find(old, last + 1, true), 'unexpected TBC POINT bytes/count')
    return text:sub(1, first - 1) .. new .. text:sub(last + 1)
end

local function hash(text)
    local h = 2166136261

    for i = 1, #text do
        local byte = text:byte(i)
        local low = h % 256
        local xor = 0
        local bit = 1

        for _ = 1, 8 do
            if low % 2 ~= byte % 2 then
                xor = xor + bit
            end

            low = math.floor(low / 2)
            byte = math.floor(byte / 2)
            bit = bit * 2
        end

        h = h - h % 256 + xor
        h = (h * 403 + (h % 256) * 16777216) % 4294967296
    end

    return string.format('%08x', h)
end

local oldBody = assert(changes['Conditions/stats.lua'].old:match('^    evaluate = function%b()(.*)end,$'))
local newBody = assert(changes['Conditions/stats.lua'].new:match('^    evaluate = function%b()(.*)end,$'))

local getters = {
    ['Core/point_conditions.lua'] = {
        '        if name=="GetConditionPointResourceV2" then return addon.GetConditionPointResourceV2 end\n',
        '        if name=="pointComboTypes" then return pointComboTypes end\n',
        '        if name=="pointComboValue" then return pointComboValue end\n',
    },
    ['Platform/points.lua'] = {
        '        if name=="Platform_GetPlayerComboPointObservation" then return addon.Platform.GetPlayerComboPointObservation end\n',
    },
}

return function(text, path, body)
    if body then
        assert(path == 'POINT' and text == newBody, 'unexpected POINT callback bytes')
        return oldBody
    end

    local row = assert(changes[path], 'unexpected TBC POINT module')
    text = replace(text, row.new, row.old)

    for _, line in ipairs(getters[path] or {}) do
        if text:find(line, 1, true) then
            text = replace(text, line, '')
        end
    end

    assert(#text == row.length and hash(text) == row.hash, 'unexpected unrelated TBC POINT module bytes: ' .. path)
    return text
end,
    oldBody,
    newBody
