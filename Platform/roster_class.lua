-- Platform adapter for the class of a player, party or raid roster member (UnitExists and UnitClass). Returns
-- `class, nil`, `false` for a known-absent unit, or `nil, reason`; game values pass platform:CanReadValue first. Only
-- the helper-owned roster tokens (player, party1-4, raid1-40) are accepted, so it never reads enemies or arbitrary
-- units. Loaded from RotationMaster.toc after Platform/announcement_recipient.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; rosterUnit and the reader
-- are Built In helpers, so their bodies are frozen.
local _, addon = ...
local platform = addon.Platform

-- Returns true for exactly "player", "party1" to "party4" and "raid1" to "raid40" (no leading zeros). unit must be a
-- string.
local function rosterUnit(unit)
    if unit=='player' or unit:match('^party[1-4]$') then return true end
    local slot=unit:match('^raid(%d+)$');slot=slot and tonumber(slot)
    return slot~=nil and slot>=1 and slot<=40 and unit=='raid'..tostring(slot)
end

-- Public roster facts are available on identified families independently of
-- enemy-combat observation policy. Only exact helper-owned roster tokens route.
-- Returns the class file name (second UnitClass return), false when the unit does not exist, or nil and a reason.
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
