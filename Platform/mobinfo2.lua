local _, addon = ...
local platform = addon.Platform

local function finite(self, value)
    if not self:CanReadValue(value) then return false,'restricted-value' end
    if type(value)~='number' or value~=value or value>=math.huge or value<=-math.huge then return false,'invalid-mobinfo2-number' end
    return true
end

local function readField(self, object, key)
    if not self:CanReadValue(object) then return nil,'restricted-value' end
    if type(object)~='table' then return nil,'invalid-mobinfo2-data' end
    local ok,value=pcall(function() return object[key] end)
    if not ok then return nil,'mobinfo2-data-error' end
    if not self:CanReadValue(value) then return nil,'restricted-value' end
    return value
end

-- Only this prerequisite is cached. Provider history and its name/level
-- identity remain fresh on every call, preserving the original boundary.
local function presence(self, unit)
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'unit-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    return exists
end

local function hitCount(self, resists, school)
    local hits,reason=readField(self,resists,school..'Hits')
    if reason then return nil,reason end
    if hits==nil or hits==false then return 1 end
    local valid,why=finite(self,hits)
    if not valid then return nil,why end
    return hits
end

function platform:GetMobInfo2Observation(unit, kind, school, cache)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(unit) or not self:CanReadValue(kind) or not self:CanReadValue(cache) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' then return nil,'invalid-unit' end
    if kind~='runner' and kind~='resist' and kind~='immune' then return nil,'invalid-mobinfo2-kind' end
    if cache~=nil and type(cache)~='table' then return nil,'invalid-mobinfo2-cache' end
    if kind~='runner' then
        if not self:CanReadValue(school) then return nil,'restricted-value' end
        if type(school)~='string' or school=='' then return nil,'invalid-mobinfo2-school' end
    end
    local exists,reason=addon.Functions.cache.getCached(cache,presence,self,unit)
    if exists==nil then return nil,reason end
    if not exists then return {exists=false} end
    local query,queryReason=readField(self,_G,'MI2_GetMobData')
    if queryReason then return nil,queryReason end
    if type(query)~='function' then return nil,'missing-api' end
    if type(UnitName)~='function' then return nil,'missing-api' end
    local nameOk,name=pcall(UnitName,unit)
    if not nameOk then return nil,'api-error' end
    if not self:CanReadValue(name) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(name) then return nil,'restricted-value' end
    if name==nil then return nil,'unit-name-unavailable' end
    if type(name)~='string' or name=='' then return nil,'invalid-api-result' end
    if type(UnitLevel)~='function' then return nil,'missing-api' end
    local levelOk,level=pcall(UnitLevel,unit)
    if not levelOk then return nil,'api-error' end
    if not self:CanReadValue(level) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(level) then return nil,'restricted-value' end
    local valid,why=finite(self,level)
    if not valid then return nil,why end
    local ok,data=pcall(query,name,level,unit)
    if not ok then return nil,'mobinfo2-provider-error' end
    if not self:CanReadValue(data) then return nil,'restricted-value' end
    -- A successful nil lookup means unrecorded data in the publisher API.
    if data==nil then return {exists=true,recorded=false} end
    if type(data)~='table' then return nil,'invalid-mobinfo2-data' end
    if kind=='runner' then
        local action,actionReason=readField(self,data,'lowHpAction')
        if actionReason then return nil,actionReason end
        local actionType=type(action)
        if actionType=='number' then
            valid,why=finite(self,action)
            if not valid then return nil,why end
        elseif actionType~='nil' and actionType~='boolean' and actionType~='string' then
            return nil,'invalid-mobinfo2-action'
        end
        -- Preserve readable scalar truthiness, including numeric zero and ''.
        return {exists=true,recorded=true,runner=action and true or false}
    end
    local resists,resistsReason=readField(self,data,'resists')
    if resistsReason then return nil,resistsReason end
    if resists==nil then return {exists=true,recorded=false} end
    local count,countReason=readField(self,resists,school)
    if countReason then return nil,countReason end
    if count==nil then return {exists=true,recorded=false} end
    valid,why=finite(self,count)
    if not valid then return nil,why end
    if kind=='resist' then
        if count<=0 then return {exists=true,recorded=false} end
        local hits,hitsReason=hitCount(self,resists,school)
        if hits==nil then return nil,hitsReason end
        local ratio=count/hits
        valid,why=finite(self,ratio)
        if not valid then return nil,why end
        return {exists=true,recorded=true,ratio=ratio}
    end
    if count>=0 then return {exists=true,recorded=false} end
    local hits,hitsReason=hitCount(self,resists,school)
    -- Partial immunity needs only the negative observation. Full immunity
    -- separately requires this optional count, including meaningful zero.
    return {exists=true,recorded=true,immune=true,hits=hits,hitsReason=hitsReason}
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetMobInfo2Observation" then return addon.Platform.GetMobInfo2Observation end
        if name=="finite" then return finite end
        if name=="hitCount" then return hitCount end
        if name=="presence" then return presence end
        if name=="readField" then return readField end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/mobinfo2.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/mobinfo2.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
