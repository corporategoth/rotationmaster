local _,addon=...
local playerClassCacheKey={}

-- This whole identity gate is cached once per pass, independently of whether
-- its first query promotes a successful player class to the longterm cache.
local function pointIdentity(self,unit,key)
    local platform=self.Platform
    local nativeClass=UnitClass
    local longterm=self.longtermCache
    if not platform:CanReadValue(longterm) or type(longterm)~='table' then longterm=nil end
    local class
    if unit=='player' and longterm and platform:CanReadValue(nativeClass) and type(nativeClass)=='function' then
        local entry=rawget(longterm,key)
        if platform:CanReadValue(entry) and type(entry)=='table' then
            local api,candidate=rawget(entry,'api'),rawget(entry,'class')
            if platform:CanReadValue(api) and api==nativeClass and platform:CanReadValue(candidate) and type(candidate)=='string' and candidate~='' then class=candidate end
        end
    end
    local record,reason=platform:GetUnitPointIdentityObservation(unit,class==nil)
    if not record then return nil,reason end
    if not record.exists then return record end
    if class then record.class=class
    elseif unit=='player' and longterm and type(nativeClass)=='function' and nativeClass==UnitClass then
        rawset(longterm,key,{api=nativeClass,class=record.class})
    end
    return record
end

function addon:GetConditionPointResource(unit,cache)
    local platform=self.Platform
    if platform:GetCombatDataPolicy()~='probe' then return nil,'unsupported-policy' end
    if not platform:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    local record,reason=addon.Functions.cache.getCached(cache,pointIdentity,self,unit,playerClassCacheKey)
    if not record then return nil,reason end
    if not record.exists then return false end
    local points=self.points
    if not platform:CanReadValue(points) then return nil,'restricted-value' end
    if type(points)~='table' then return nil,'invalid-point-resource-map' end
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
    end
    if selected==nil then return nil,'point-resource-unavailable' end
    if type(selected)~='number' or selected~=selected or selected<0 or selected==math.huge or selected%1~=0 then return nil,'invalid-point-resource' end
    return selected
end

-- Optional trusted-load capability for the explicitly versioned TBC policy.
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

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetConditionPointResource" then return addon.GetConditionPointResource end
        if name=="GetConditionPointResourceV2" then return addon.GetConditionPointResourceV2 end
        if name=="playerClassCacheKey" then return playerClassCacheKey end
        if name=="pointComboTypes" then return pointComboTypes end
        if name=="pointComboValue" then return pointComboValue end
        if name=="pointIdentity" then return pointIdentity end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/point_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/point_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
