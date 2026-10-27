-- Platform adapter that reads the player's own class token (UnitClass) for rotation ownership checks. Returns
-- `class, nil` or `nil, reason`; the value passes platform:CanReadValue first. Must not cache: ownership needs a fresh
-- read. Loaded from RotationMaster.toc right after Platform/client.lua.
-- The generated bindings block at the end is owned by tools/generate_builtin_sources.py; the reader is a Built In
-- helper, so its body is frozen.
local _, addon = ...
local platform = addon.Platform

-- Ownership needs a fresh public player class token, not eligibility facts.
-- Consume only UnitClass's second return and leave its other fields alone.
-- Returns the player's class file name (for example "MAGE"), or nil and a reason.
function platform:GetPlayerOwnerClassObservation()
    if type(UnitClass)~='function' then return nil,'missing-api' end
    local ok,_,class=pcall(UnitClass,'player')
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(class) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(class) then return nil,'restricted-value' end
    if class==nil then return nil,'class-data-unavailable' end
    if type(class)~='string' or class=='' then return nil,'invalid-api-result' end
    return class
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetPlayerOwnerClassObservation" then return addon.Platform.GetPlayerOwnerClassObservation end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/rotation_owner.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/rotation_owner.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
