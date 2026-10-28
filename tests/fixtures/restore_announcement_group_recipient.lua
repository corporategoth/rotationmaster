-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact recipient-resolver composition before the original GROUP proof.
local deltas = {
    {
        ["after"] = "\010        local unit=value.unit\010        if unit==nil then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if not addon.Platform:CanReadValue(unit) then return nil,\"restricted-value\" end\010        if unit==\"player\" then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if unit==\"spellrecipient\" then\010            if not addon.Platform:CanReadValue(cache) or type(cache)~=\"table\" then return nil,\"cast-recipient-unavailable\" end\010            unit=rawget(cache,\"announcementRecipient\")\010            if not addon.Platform:CanReadValue(unit) or type(unit)~=\"string\" or unit==\"\" then return nil,\"cast-recipient-unavailable\" end\010            return Functions.cache.getCached(cache, addon.Platform.GetAnnouncementRecipientGroupMembership, addon.Platform, unit, value.raid)\010        elseif not Functions.values.isin(addon.units,unit) then return nil,\"invalid-unit\" end\010        return Functions.cache.getCached(cache, addon.Platform.GetUnitGroupMembership, addon.Platform, unit, value.raid)\010    ",
        ["before"] = "\010        local unit=value.unit\010        if unit==nil then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if not addon.Platform:CanReadValue(unit) then return nil,\"restricted-value\" end\010        if unit==\"player\" then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if unit==\"spellrecipient\" then\010            if not addon.Platform:CanReadValue(cache) or type(cache)~=\"table\" then return nil,\"cast-recipient-unavailable\" end\010            unit=rawget(cache,\"announcementRecipient\")\010            if not addon.Platform:CanReadValue(unit) or type(unit)~=\"string\" or unit==\"\" then return nil,\"cast-recipient-unavailable\" end\010        elseif not Functions.values.isin(addon.units,unit) then return nil,\"invalid-unit\" end\010        return Functions.cache.getCached(cache, addon.Platform.GetUnitGroupMembership, addon.Platform, unit, value.raid)\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "evaluate", "code" },
    },
    {
        ["after"] = 568,
        ["before"] = 567,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "help", "line" },
    },
    {
        ["after"] = 542,
        ["before"] = 541,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "line" },
    },
    {
        ["after"] = 549,
        ["before"] = 548,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 681,
        ["before"] = 680,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 726,
        ["before"] = 725,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "help", "line" },
    },
    {
        ["after"] = 689,
        ["before"] = 688,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "print", "line" },
    },
    {
        ["after"] = 677,
        ["before"] = 676,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 693,
        ["before"] = 692,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 619,
        ["before"] = 618,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 657,
        ["before"] = 656,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "help", "line" },
    },
    {
        ["after"] = 625,
        ["before"] = 624,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "print", "line" },
    },
    {
        ["after"] = 613,
        ["before"] = 612,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 630,
        ["before"] = 629,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 582,
        ["before"] = 581,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 600,
        ["before"] = 599,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "help", "line" },
    },
    {
        ["after"] = 588,
        ["before"] = 587,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "print", "line" },
    },
    {
        ["after"] = 579,
        ["before"] = 578,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 591,
        ["before"] = 590,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "widget", "line" },
    },
    {
        ["after"] = "8fd5c81a5e36dbd672fbb823282e4d020c9b81f932ba6d00c46f10c956fae8f7",
        ["before"] = "97e40d7aa47696692b8debccf6e0c560375ccfa9350a51722fe20c6aafcd33d2",
        ["beforePresent"] = true,
        ["path"] = { "modules", "Conditions/character.lua", "hash" },
    },
    {
        ["after"] = {
            ["bindings"] = {
                ["Platform_GetAnnouncementRecipientGroupMembership"] = {
                    ["args"] = {
                        {
                            ["description"] = "Rotation Master platform adapter (implicit with colon calls).",
                            ["name"] = "self",
                            ["type"] = "RMPlatform",
                        },
                        {
                            ["description"] = "Exact readable recipient name recorded for this cast.",
                            ["name"] = "recipient",
                            ["type"] = "string",
                        },
                        {
                            ["description"] = "True checks raid membership only; false or nil checks party or raid.",
                            ["name"] = "raidOnly",
                            ["type"] = "boolean | nil",
                        },
                    },
                    ["bindings"] = {},
                    ["callName"] = "addon.Platform:GetAnnouncementRecipientGroupMembership",
                    ["code"] = "\010    if not self:CanReadValue(recipient) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end\010    if type(recipient)~='string' or recipient=='' or #recipient>256 then return nil,'cast-recipient-unavailable' end\010    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end\010    local grouped,reason=self:GetGroupMembership(raidOnly)\010    if grouped~=true then return grouped,reason end\010    local raid,why=self:GetGroupMembership(true)\010    if raid==nil then return nil,why end\010    local exists,name,guid,normalized=UnitExists,UnitName,UnitGUID,GetNormalizedRealmName\010    local groupQuery=self.GetGroupMembership\010    local membership=self.GetUnitGroupMembership\010    if type(exists)~='function' or type(name)~='function' or type(guid)~='function' or type(membership)~='function' then return nil,'missing-api' end\010    local function read(unit)\010        local ok,present=pcall(exists,unit)\010        if not ok or not self:CanReadValue(present) or type(present)~='boolean' then return nil end\010        if not present then return false end\010        local named,first,realm=pcall(name,unit)\010        local identified,identity=pcall(guid,unit)\010        if not named or not identified or not self:CanReadValue(first) or not self:CanReadValue(realm) or not self:CanReadValue(identity) then return nil end\010        if canaccessvalue and not canaccessvalue(first) then return nil end\010        if canaccessvalue and not canaccessvalue(realm) then return nil end\010        if canaccessvalue and not canaccessvalue(identity) then return nil end\010        if type(first)~='string' or first=='' or #first>256 or type(identity)~='string' or identity=='' or #identity>256 then return nil end\010        if realm~=nil and type(realm)~='string' then return nil end\010        if realm==nil or realm=='' then\010            if type(normalized)=='function' then\010                local got,value=pcall(normalized)\010                if not got or not self:CanReadValue(value) then return nil end\010                if canaccessvalue and not canaccessvalue(value) then return nil end\010                if type(value)=='string' and value~='' and #value<=256 then realm=value end\010            end\010        end\010        return {first=first,full=type(realm)=='string' and realm~='' and first..'-'..realm or nil,guid=identity}\010    end\010    local function scan()\010        local rows,selected,count={},nil,0\010        for index=raid and 1 or 0,raid and 40 or 4 do\010            local unit=raid and 'raid'..index or index==0 and 'player' or 'party'..index\010            local record=read(unit)\010            if record==nil then return nil,'group-data-unavailable' end\010            rows[unit]=record\010            if record then\010                count=count+1\010                if recipient==record.first or recipient==record.full then\010                    if selected then return nil,'cast-recipient-ambiguous' end\010                    selected=unit\010                elseif not record.full and recipient:sub(1,#record.first+1)==record.first..'-' then\010                    return nil,'cast-recipient-unavailable'\010                end\010            end\010        end\010        if count==0 then return nil,'group-data-unavailable' end\010        return rows,selected\010    end\010    local before,selected=scan()\010    if not before then return nil,selected end\010    local member,failure=false,nil\010    if selected then member,failure=membership(self,selected,raidOnly) end\010    -- Native calls and extension callbacks may reenter. Re-read the complete\010    -- bounded roster after membership/context reads, including negative results:\010    -- a stale false must not turn a NOT condition into permission to announce.\010    local currentGroup=self:GetGroupMembership(raidOnly)\010    local currentRaid=self:GetGroupMembership(true)\010    local after,matched=scan()\010    if exists~=UnitExists or name~=UnitName or guid~=UnitGUID or normalized~=GetNormalizedRealmName\010        or membership~=self.GetUnitGroupMembership or groupQuery~=self.GetGroupMembership\010        or currentGroup~=grouped or currentRaid~=raid or not after or matched~=selected then return nil,'group-data-unavailable' end\010    for unit,record in pairs(before) do\010        local fresh=after[unit]\010        if type(record)~=type(fresh) then return nil,'group-data-unavailable' end\010        if record and (fresh.guid~=record.guid or fresh.first~=record.first or fresh.full~=record.full) then return nil,'group-data-unavailable' end\010    end\010    return member,failure\010",
                    ["description"] = "Resolve an exact cast-recipient name against the current bounded party or raid roster, then observe membership through a unit token. Missing, ambiguous or changing roster data remains unavailable; never reads the selected target or retains state across casts.",
                    ["kind"] = "function",
                    ["line"] = 7,
                    ["parameters"] = { "self", "recipient", "raidOnly" },
                    ["returns"] = {
                        {
                            ["description"] = "Observed membership, or nil when unavailable.",
                            ["type"] = "boolean | nil",
                        },
                        {
                            ["description"] = "Validation or availability reason for a nil result.",
                            ["type"] = "string | nil",
                        },
                    },
                },
            },
            ["hash"] = "ddcafba6e2071bfaaa871272fc1ede1874b7d7a1db4359563f76a4b11b8ecb7d",
        },
        ["beforePresent"] = false,
        ["path"] = { "modules", "Platform/announcement_recipient.lua" },
    },
}

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= 'table' then
        return a == b
    end

    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local function copy(v)
    if type(v) ~= 'table' then
        return v
    end

    local r = {}

    for k, x in pairs(v) do
        r[k] = copy(x)
    end

    return r
end

local function hash(s)
    local n = 0

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(value, path, mode)
    value = dofile('tests/fixtures/restore_announcement_unit_context.lua')(value, path, mode)

    if mode == 'catalog' then
        if not value.modules['Platform/announcement_recipient.lua'] then
            return value
        end

        for _, d in ipairs(deltas) do
            local parent = value

            for i = 1, #d.path - 1 do
                parent = assert(parent[d.path[i]])
            end

            local key = d.path[#d.path]
            assert(equal(parent[key], d.after), 'unexpected complete recipient catalog field')
            parent[key] = d.beforePresent and copy(d.before) or nil
        end

        return value
    end

    if path ~= 'Conditions/character.lua' then
        return value
    end
    if not value:find(
        'return Functions.cache.getCached(cache, addon.Platform.GetAnnouncementRecipientGroupMembership, addon.Platform, unit, value.raid)',
        1,
        true
    ) then
        return value
    end
    if #value == 37824 and hash(value) == "61b783df" then
        return value
    end

    assert(#value == 37966 and hash(value) == "3be05091", 'unexpected complete recipient GROUP source')
    local added = "            return Functions.cache.getCached(cache, addon.Platform.GetAnnouncementRecipientGroupMembership, addon.Platform, unit, value.raid)\010"
    local first, last = value:find(added, 1, true)
    assert(first and not value:find(added, last + 1, true))
    value = value:sub(1, first - 1) .. value:sub(last + 1)
    assert(#value == 37824 and hash(value) == "61b783df", 'recipient GROUP predecessor differs')
    return value
end
