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

-- Explicit unit/name observation is separate from the legacy player query.
function platform:GetUnitGroupMembership(unit,raidOnly)
    if not self:CanReadValue(unit) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' or #unit>512 or unit:find('[%z\1-\31\127]') then return nil,'invalid-unit' end
    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end
    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end
    if not raidOnly then
        if type(UnitInParty)~='function' then return nil,'missing-api' end
        local ok,member=pcall(UnitInParty,unit)
        if not ok then return nil,'api-error' end
        if not self:CanReadValue(member) then return nil,'restricted-value' end
        if member==nil then return nil,'group-data-unavailable' end
        if type(member)~='boolean' then return nil,'invalid-api-result' end
        if member then return true end
    end
    if type(UnitInRaid)~='function' then return nil,'missing-api' end
    local ok,index=pcall(UnitInRaid,unit)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(index) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(index) then return nil,'restricted-value' end
    -- The pinned native API returns an optional raid index: nil is nonmember.
    if index==nil then return false end
    if type(index)~='number' or index<1 or index>40 or index%1~=0 then return nil,'invalid-api-result' end
    return true
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetGroupMembership" then return addon.Platform.GetGroupMembership end
        if name=="Platform_GetUnitGroupMembership" then return addon.Platform.GetUnitGroupMembership end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/groups.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/groups.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
