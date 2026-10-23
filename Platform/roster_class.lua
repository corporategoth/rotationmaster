local _,addon=...
local platform=addon.Platform
local function rosterUnit(unit)
    if unit=='player' or unit:match('^party[1-4]$') then return true end
    local slot=unit:match('^raid(%d+)$');slot=slot and tonumber(slot)
    return slot~=nil and slot>=1 and slot<=40 and unit=='raid'..tostring(slot)
end
-- Public roster facts are available on identified families independently of
-- enemy-combat observation policy. Only exact helper-owned roster tokens route.
function platform:GetRosterClassObservation(unit)
    if not self:CanReadValue(unit) then return nil,'restricted-value' end
    if type(unit)~='string' or not rosterUnit(unit) then return nil,'invalid-roster-unit' end
    if self:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
    if type(UnitExists)~='function' then return nil,'missing-api' end
    local ok,exists=pcall(UnitExists,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(exists) then return nil,'restricted-value' end
    if exists==nil then return nil,'roster-data-unavailable' end
    if type(exists)~='boolean' then return nil,'invalid-api-result' end
    if not exists then return false end
    if type(UnitClass)~='function' then return nil,'missing-api' end
    local success,_,class=pcall(UnitClass,unit)
    if not success then return nil,'api-error' end
    if not self:CanReadValue(class) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(class) then return nil,'restricted-value' end
    if class==nil then return nil,'roster-class-unavailable' end
    if type(class)~='string' or class=='' then return nil,'invalid-api-result' end
    return class
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetRosterClassObservation" then return addon.Platform.GetRosterClassObservation end
        if name=="rosterUnit" then return rosterUnit end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/roster_class.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/roster_class.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
