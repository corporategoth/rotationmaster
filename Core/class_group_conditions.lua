local _, addon = ...

-- A count is complete only after every selected fixed roster slot is known.
-- Current player observations are pass snapshots; archived source keeps its
-- original load-time class binding independently of this live path.
function addon:GetClassGroupCount(cache, class, raid)
    local platform=self.Platform
    if not platform:CanReadValue(class) or not platform:CanReadValue(raid) then return nil,'restricted-value' end
    if type(class)~='string' or class=='' then return nil,'invalid-class-group-query' end
    if raid~=nil and type(raid)~='boolean' then return nil,'invalid-class-group-query' end
    local grouped,reason=self.Functions.cache.getCached(cache,platform.GetGroupMembership,platform,false)
    if grouped==nil then return nil,reason end
    local prefix,size='party',4
    if grouped and raid then
        local inRaid,why=self.Functions.cache.getCached(cache,platform.GetGroupMembership,platform,true)
        if inRaid==nil then return nil,why end
        if inRaid then prefix,size='raid',40 end
    end
    local count=0
    if not grouped or prefix=='party' then
        local player,why=self.Functions.cache.getCached(cache,platform.GetRosterClassObservation,platform,'player')
        if player==nil then return nil,why end
        if player==class then count=1 end
        if not grouped then return count end
    end
    for index=1,size do
        local observed,why=self.Functions.cache.getCached(cache,platform.GetRosterClassObservation,platform,prefix..tostring(index))
        if observed==nil then return nil,why end
        if observed==class then count=count+1 end
    end
    return count
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GetClassGroupCount" then return addon.GetClassGroupCount end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Core/class_group_conditions.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Core/class_group_conditions.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
