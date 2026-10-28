-- Platform adapter for group membership: IsInGroup, IsInRaid, UnitInParty and UnitInRaid.
-- Owns the `value or nil, reason` readers for "is the player (or a named unit) in my party or raid"; it must not
-- decide what a rotation does with the answer. Roster membership is public state, so these readers do not depend on
-- the combat data policy. Both readers are Built In helpers: their bodies are recorded in the generated block at the
-- end of the file and must keep their exact text. Loaded early in RotationMaster.toc, right after
-- Platform/rotation_owner.lua.
local _, addon = ...
local platform = addon.Platform

-- Reads whether the player is in a group.
-- @param raidOnly boolean|nil  True to ask about a raid group only (IsInRaid); nil or false asks about any group
--   (IsInGroup).
-- @return boolean|nil  Whether the player is in the selected kind of group; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Public roster membership is readable state, independent of enemy-combat observation policy. A false selected result
-- must not invoke another query.
function platform:GetGroupMembership(raidOnly)
    if not self:CanReadValue(raidOnly) then return nil,'restricted-value' end
    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end
    if self:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
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

-- Reads whether a named unit is in the player's party or raid (UnitInParty, UnitInRaid).
-- @param unit string  The unit token or name; a non-empty string of at most 512 characters with no control
--   characters.
-- @param raidOnly boolean|nil  True to check the raid only; nil or false checks the party first, then the raid.
-- @return boolean|nil  True when the unit is in the party or raid, false when it is in neither; nil when it cannot be
--   read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Explicit unit/name observation is separate from the legacy player query. A unit string of any other shape is
-- rejected before a native call is made.
function platform:GetUnitGroupMembership(unit, raidOnly)
    if not self:CanReadValue(unit) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end
    if type(unit)~='string' or unit=='' or #unit>512 or unit:find('[%z\1-\31\127]') then return nil,'invalid-unit' end
    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end
    if self:GetClientFamily()=='unknown' then return nil,'unsupported-client' end
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
