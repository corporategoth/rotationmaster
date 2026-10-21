local _,addon=...
local platform=addon.Platform

-- Cast receipts contain names; membership APIs consume unit tokens. Resolve
-- only at a matching announcement event, never from the selected target and
-- never into a cache shared by polls or casts.
function platform:GetAnnouncementRecipientGroupMembership(recipient,raidOnly)
    if not self:CanReadValue(recipient) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end
    if type(recipient)~='string' or recipient=='' or #recipient>256 then return nil,'cast-recipient-unavailable' end
    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end
    local grouped,reason=self:GetGroupMembership(raidOnly)
    if grouped~=true then return grouped,reason end
    local raid,why=self:GetGroupMembership(true)
    if raid==nil then return nil,why end
    local exists,name,guid,normalized=UnitExists,UnitName,UnitGUID,GetNormalizedRealmName
    local groupQuery=self.GetGroupMembership
    local membership=self.GetUnitGroupMembership
    if type(exists)~='function' or type(name)~='function' or type(guid)~='function' or type(membership)~='function' then return nil,'missing-api' end
    local function read(unit)
        local ok,present=pcall(exists,unit)
        if not ok or not self:CanReadValue(present) or type(present)~='boolean' then return nil end
        if not present then return false end
        local named,first,realm=pcall(name,unit)
        local identified,identity=pcall(guid,unit)
        if not named or not identified or not self:CanReadValue(first) or not self:CanReadValue(realm) or not self:CanReadValue(identity) then return nil end
        if canaccessvalue and not canaccessvalue(first) then return nil end
        if canaccessvalue and not canaccessvalue(realm) then return nil end
        if canaccessvalue and not canaccessvalue(identity) then return nil end
        if type(first)~='string' or first=='' or #first>256 or type(identity)~='string' or identity=='' or #identity>256 then return nil end
        if realm~=nil and type(realm)~='string' then return nil end
        if realm==nil or realm=='' then
            if type(normalized)=='function' then
                local got,value=pcall(normalized)
                if not got or not self:CanReadValue(value) then return nil end
                if canaccessvalue and not canaccessvalue(value) then return nil end
                if type(value)=='string' and value~='' and #value<=256 then realm=value end
            end
        end
        return {first=first,full=type(realm)=='string' and realm~='' and first..'-'..realm or nil,guid=identity}
    end
    local function scan()
        local rows,selected,count={},nil,0
        for index=raid and 1 or 0,raid and 40 or 4 do
            local unit=raid and 'raid'..index or index==0 and 'player' or 'party'..index
            local record=read(unit)
            if record==nil then return nil,'group-data-unavailable' end
            rows[unit]=record
            if record then
                count=count+1
                if recipient==record.first or recipient==record.full then
                    if selected then return nil,'cast-recipient-ambiguous' end
                    selected=unit
                elseif not record.full and recipient:sub(1,#record.first+1)==record.first..'-' then
                    return nil,'cast-recipient-unavailable'
                end
            end
        end
        if count==0 then return nil,'group-data-unavailable' end
        return rows,selected
    end
    local before,selected=scan()
    if not before then return nil,selected end
    local member,failure=false,nil
    if selected then member,failure=membership(self,selected,raidOnly) end
    -- Native calls and extension callbacks may reenter. Re-read the complete
    -- bounded roster after membership/context reads, including negative results:
    -- a stale false must not turn a NOT condition into permission to announce.
    local currentGroup=self:GetGroupMembership(raidOnly)
    local currentRaid=self:GetGroupMembership(true)
    local after,matched=scan()
    if exists~=UnitExists or name~=UnitName or guid~=UnitGUID or normalized~=GetNormalizedRealmName
        or membership~=self.GetUnitGroupMembership or groupQuery~=self.GetGroupMembership
        or currentGroup~=grouped or currentRaid~=raid or not after or matched~=selected then return nil,'group-data-unavailable' end
    for unit,record in pairs(before) do
        local fresh=after[unit]
        if type(record)~=type(fresh) then return nil,'group-data-unavailable' end
        if record and (fresh.guid~=record.guid or fresh.first~=record.first or fresh.full~=record.full) then return nil,'group-data-unavailable' end
    end
    return member,failure
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetAnnouncementRecipientGroupMembership" then return addon.Platform.GetAnnouncementRecipientGroupMembership end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/announcement_recipient.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/announcement_recipient.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
