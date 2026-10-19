local _,addon=...
local platform=addon.Platform

-- Public roster membership is readable state, independent of enemy-combat
-- observation policy. A false selected result must not invoke another query.
function platform:GetGroupMembership(raidOnly)
    if not self:CanReadValue(raidOnly) then return nil,'restricted-value' end
    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end
    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end
    local fn
    if raidOnly then fn=IsInRaid else fn=IsInGroup end
    if type(fn)~='function' then return nil,'missing-api' end
    local ok,member=pcall(fn)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(member) then return nil,'restricted-value' end
    if member==nil then return nil,'group-data-unavailable' end
    if type(member)~='boolean' then return nil,'invalid-api-result' end
    return member
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetGroupMembership" then return addon.Platform.GetGroupMembership end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/groups.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/groups.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
