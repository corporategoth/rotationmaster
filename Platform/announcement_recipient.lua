-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Platform adapter for announcements: group membership of a cast recipient, and the chat channels a message can go to.
-- Owns the `value or nil, reason` readers over UnitExists, UnitName, UnitGUID, GetNormalizedRealmName and
-- GetChannelName; it must not send anything or cache a roster. Both channel readers return an "ownership" check that
-- reports whether the answer still holds. GetAnnouncementRecipientGroupMembership is a Built In helper: its body is
-- recorded in the generated block at the end of the file and must keep its exact text.
-- Loaded from RotationMaster.toc after Platform/group_units.lua; needs Platform/groups.lua.
local _, addon = ...
local platform = addon.Platform

-- Reads whether the named recipient of a cast receipt is in the player's party or raid.
-- @param recipient string  The recipient's name as it appears in the receipt; a non-empty string of at most 256
--   characters.
-- @param raidOnly boolean|nil  True to check the raid only; nil or false checks the party first, then the raid.
-- @return boolean|nil  True when the recipient is in the party or raid, false when not; nil when it cannot be decided
--   (an ambiguous name, an unreadable roster or a roster that changed during the read).
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Cast receipts contain names; membership APIs consume unit tokens. The name is resolved only at a matching
-- announcement event, never from the selected target and never into a cache shared by polls or casts. Native calls and
-- extension callbacks may reenter, so the complete bounded roster is read again after the membership reads (including
-- negative results); a stale false must not turn a NOT condition into permission to announce.
function platform:GetAnnouncementRecipientGroupMembership(recipient, raidOnly)
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

-- Scans the joined chat channels (slots 1 to 20).
-- @param self table  The platform table, used for its CanReadValue method.
-- @param current function|nil  Callback polled between native calls; the scan ends with "announcement-retired" once it
--   stops returning true.
-- @return table[]|nil  The channels as { id, value, text } rows; nil when it cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Joined names are configuration; local ids are fresh invocation-only addresses.
local function channelScan(self, current)
    local query = GetChannelName
    local readable = self.CanReadValue

    if type(query) ~= 'function' or type(readable) ~= 'function' then
        return nil, 'missing-api'
    end

    -- Whether the scan still owns its inputs.
    -- @return boolean  True when the owner callback still returns true and neither GetChannelName nor CanReadValue has
    --   been replaced.
    local function owned()
        if current then
            local ok, live = pcall(current)

            if not ok or live ~= true then
                return false
            end
        end

        return query == GetChannelName and readable == self.CanReadValue
    end

    -- Whether a value is readable and accessible.
    -- @param value any  The value to test.
    -- @return boolean  True when the value may be inspected.
    local function read(value)
        return readable(self, value) and (not canaccessvalue or canaccessvalue(value))
    end

    local rows = {}

    for slot = 1, 20 do
        if not owned() then
            return nil, 'announcement-retired'
        end

        local ok, id, name = pcall(query, slot)

        if not ok or not read(id) or not read(name) or not owned() then
            return nil, 'channel-unavailable'
        end

        if id ~= 0 and id ~= nil then
            if
                type(id) ~= 'number'
                or id % 1 ~= 0
                or id < 1
                or id > 20
                or type(name) ~= 'string'
                or name == ''
                or #name > 256
                or name:find('[%z\1-\31\127]')
            then
                return nil, 'channel-unavailable'
            end

            rows[#rows + 1] = { id = id, value = name, text = name }
        end
    end

    if not owned() then
        return nil, 'announcement-retired'
    end

    return rows
end

-- Lists the joined chat channels for the settings picker.
-- @param current function|nil  Callback polled between native calls; the scan ends with "announcement-retired" once it
--   stops returning true.
-- @return table[]|nil  The channels as { value, text } rows (no channel numbers, which change); nil when it cannot be
--   read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
function platform:GetJoinedAnnouncementChannels(current)
    local rows, why = channelScan(self, current)

    if not rows then
        return nil, why
    end

    local result = {}

    for _, row in ipairs(rows) do
        result[#result + 1] = { value = row.value, text = row.text }
    end

    return result
end

-- Turns a configured channel name into its current numeric id at the moment of use.
-- @param name string  The channel name; a non-empty string of at most 256 characters with no control characters.
-- @param current function|nil  Callback polled between native calls; the scan ends once it stops returning true.
-- @return number|nil  The channel id; nil when the name is invalid, absent or joined twice.
-- @return function|nil  A function that re-resolves and reports (as a boolean) whether the id is still the same; nil
--   when the first return is nil.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The numeric id must never be stored: a channel's number changes when others are joined.
function platform:ResolveAnnouncementChannel(name, current)
    if not self:CanReadValue(name) or type(name) ~= 'string' or name == '' or #name > 256 or name:find(
        '[%z\1-\31\127]'
    ) then
        return nil, nil, 'invalid-channel'
    end

    local query, readable = GetChannelName, self.CanReadValue

    -- Re-reads the channel list and finds the id for the configured name.
    -- @return number|nil  The channel id; nil when it is absent, ambiguous or the inputs changed during the read.
    local function resolve()
        if query ~= GetChannelName or readable ~= self.CanReadValue then
            return nil
        end

        local rows = channelScan(self, current)

        if not rows then
            return nil
        end

        local selected

        for _, row in ipairs(rows) do
            if row.value == name then
                if selected then
                    return nil
                end

                selected = row.id
            end
        end

        if not selected or query ~= GetChannelName or readable ~= self.CanReadValue then
            return nil
        end

        if current then
            local ok, live = pcall(current)

            if not ok or live ~= true then
                return nil
            end
        end

        -- A later slot or owner callback can change an earlier address. Finish
        -- with that selected slot, not the old row from the complete scan.
        local ok, id, fresh = pcall(query, selected)

        if not ok or not readable(self, id) or not readable(self, fresh) then
            return nil
        end
        if query ~= GetChannelName or readable ~= self.CanReadValue then
            return nil
        end

        -- Readability is an extension boundary too. The final native read has
        -- only native restricted-value guards before its exact comparison.
        local got, finalID, finalName = pcall(query, selected)

        if not got then
            return nil
        end
        if canaccessvalue and (not canaccessvalue(finalID) or not canaccessvalue(finalName)) then
            return nil
        end
        if issecretvalue and (issecretvalue(finalID) or issecretvalue(finalName)) then
            return nil
        end
        if query ~= GetChannelName or readable ~= self.CanReadValue or finalID ~= selected or finalName ~= name then
            return nil
        end

        return selected
    end

    local id = resolve()

    if not id then
        return nil, nil, 'channel-unavailable'
    end

    return id, function() return resolve() == id end
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
