-- Strict additive inverse of the explicit-unit GROUP slice; old proofs follow unchanged.
local sourceRecords = {
    ["Conditions/character.lua"] = {
        ["hunks"] = {
            {
                "addon:RegisterCondition(\"GROUP\", {\010    description = L[\"In Group\"],\010    icon = addon.Artwork.condition[\"GROUP\"],\010    fields = { raid = \"boolean\" },\010    valid = function()\010        return true\010    end,\010    evaluate = function(value, cache)\010        return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010    end,\010    print = function(_, value)\010        return value.raid and L[\"you {{!are|are not}} in a raid\"] or L[\"you {{!are|are not}} in a group\"]\010    end,\010    widget = function(parent, spec, value)\010        local top = parent:GetUserData(\"top\")\010        local root = top:GetUserData(\"root\")\010        local funcs = top:GetUserData(\"funcs\")\010\010        local raid = addon:CreateConditionCheckBox()\010        raid:SetWidth(100)\010        raid:SetLabel(L[\"Raid\"])\010        raid:SetValue(value.raid and true or false)\010        raid:SetCallback(\"OnValueChanged\", function(_, _, v)\010            value.raid = v\010            top:SetStatusText(funcs:print(root, spec))\010        end)\010        parent:AddChild(raid)\010    end,\010    help = function(frame)\010        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L[\"Raid\"] .. color.RESET ..\010                \" - \" .. \"Check to see if we are in a raid, instead of just a party (note that with .\"\010                      .. \"this option off, this condition will be true if you are in a part OR a raid).\"))\010    end\010})\010",
                "addon:RegisterCondition(\"GROUP\", {\010    description = L[\"In Group\"],\010    icon = addon.Artwork.condition[\"GROUP\"],\010    fields = { raid = \"boolean\", unit = \"string\" },\010    valid = function(_, value)\010        return addon.Platform:CanReadValue(value.unit) and\010            (value.unit == nil or value.unit == \"spellrecipient\" or Functions.values.isin(addon.units, value.unit))\010    end,\010    evaluate = function(value, cache)\010        local unit=value.unit\010        if unit==nil then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if not addon.Platform:CanReadValue(unit) then return nil,\"restricted-value\" end\010        if unit==\"player\" then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if unit==\"spellrecipient\" then\010            if not addon.Platform:CanReadValue(cache) or type(cache)~=\"table\" then return nil,\"cast-recipient-unavailable\" end\010            unit=rawget(cache,\"announcementRecipient\")\010            if not addon.Platform:CanReadValue(unit) or type(unit)~=\"string\" or unit==\"\" then return nil,\"cast-recipient-unavailable\" end\010        elseif not Functions.values.isin(addon.units,unit) then return nil,\"invalid-unit\" end\010        return Functions.cache.getCached(cache, addon.Platform.GetUnitGroupMembership, addon.Platform, unit, value.raid)\010    end,\010    print = function(_, value)\010        if value.unit==nil or value.unit==\"player\" then\010            return value.raid and L[\"you {{!are|are not}} in a raid\"] or L[\"you {{!are|are not}} in a group\"]\010        end\010        local label=value.unit==\"spellrecipient\" and L[\"Spell recipient\"] or Functions.presentation.nullable(addon.units[value.unit],L[\"<unit>\"])\010        return addon:CreateConditionSummaryPhrase(value.raid and L[\"{unit} {{!is|is not}} in a raid\"] or L[\"{unit} {{!is|is not}} in a group\"],{unit=label})\010    end,\010    widget = function(parent, spec, value)\010        local top = parent:GetUserData(\"top\")\010        local root = top:GetUserData(\"root\")\010        local funcs = top:GetUserData(\"funcs\")\010        local units=Functions.collections.deepcopy(addon.units)\010        if top:GetUserData(\"announcement\")==true or value.unit==\"spellrecipient\" then units.spellrecipient=L[\"Spell recipient\"] end\010        local unit=addon:Widget_UnitWidget(value,units,function() top:SetStatusText(funcs:print(root,spec)) end)\010        unit.configure=function() unit:SetList(units,Functions.collections.keys(units));unit:SetValue(value.unit or \"player\") end\010        parent:AddChild(unit)\010        local raid = addon:CreateConditionCheckBox()\010        raid:SetWidth(100)\010        raid:SetLabel(L[\"Raid\"])\010        raid:SetValue(value.raid and true or false)\010        raid:SetCallback(\"OnValueChanged\", function(_, _, v)\010            value.raid = v\010            top:SetStatusText(funcs:print(root, spec))\010        end)\010        parent:AddChild(raid)\010    end,\010    help = function(frame)\010        frame:AddChild(helpers.CreateText(L[\"Help.GROUP.unit\"]))\010        frame:AddChild(helpers.CreateText(L[\"Help.GROUP.raid\"]))\010    end\010})\010",
            },
        },
        ["newBytes"] = 37824,
        ["newHash"] = "9b6670e4",
        ["oldBytes"] = 36080,
        ["oldHash"] = "1e7f77be",
    },
    ["Platform/groups.lua"] = {
        ["hunks"] = {
            {
                "",
                "-- Explicit unit/name observation is separate from the legacy player query.\010function platform:GetUnitGroupMembership(unit,raidOnly)\010    if not self:CanReadValue(unit) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end\010    if type(unit)~='string' or unit=='' or #unit>512 or unit:find('[%z\\1-\\31\\127]') then return nil,'invalid-unit' end\010    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end\010    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end\010    if not raidOnly then\010        if type(UnitInParty)~='function' then return nil,'missing-api' end\010        local ok,member=pcall(UnitInParty,unit)\010        if not ok then return nil,'api-error' end\010        if not self:CanReadValue(member) then return nil,'restricted-value' end\010        if member==nil then return nil,'group-data-unavailable' end\010        if type(member)~='boolean' then return nil,'invalid-api-result' end\010        if member then return true end\010    end\010    if type(UnitInRaid)~='function' then return nil,'missing-api' end\010    local ok,index=pcall(UnitInRaid,unit)\010    if not ok then return nil,'api-error' end\010    if not self:CanReadValue(index) then return nil,'restricted-value' end\010    if canaccessvalue and not canaccessvalue(index) then return nil,'restricted-value' end\010    -- The pinned native API returns an optional raid index: nil is nonmember.\010    if index==nil then return false end\010    if type(index)~='number' or index<1 or index>40 or index%1~=0 then return nil,'invalid-api-result' end\010    return true\010end\010\010",
            },
            {
                "",
                "        if name==\"Platform_GetUnitGroupMembership\" then return addon.Platform.GetUnitGroupMembership end\010",
            },
        },
        ["newBytes"] = 3138,
        ["newHash"] = "d4c0ed5b",
        ["oldBytes"] = 1453,
        ["oldHash"] = "45843eb8",
    },
}

local catalogDeltas = {
    {
        ["after"] = "\010        local unit=value.unit\010        if unit==nil then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if not addon.Platform:CanReadValue(unit) then return nil,\"restricted-value\" end\010        if unit==\"player\" then\010            return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010        end\010        if unit==\"spellrecipient\" then\010            if not addon.Platform:CanReadValue(cache) or type(cache)~=\"table\" then return nil,\"cast-recipient-unavailable\" end\010            unit=rawget(cache,\"announcementRecipient\")\010            if not addon.Platform:CanReadValue(unit) or type(unit)~=\"string\" or unit==\"\" then return nil,\"cast-recipient-unavailable\" end\010        elseif not Functions.values.isin(addon.units,unit) then return nil,\"invalid-unit\" end\010        return Functions.cache.getCached(cache, addon.Platform.GetUnitGroupMembership, addon.Platform, unit, value.raid)\010    ",
        ["before"] = "\010        return Functions.cache.getCached(cache, addon.Platform.GetGroupMembership, addon.Platform, value.raid)\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "evaluate", "code" },
    },
    {
        ["after"] = 525,
        ["before"] = 524,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "evaluate", "line" },
    },
    {
        ["before"] = "builtin:Conditions/character.lua:color",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "help", "bindings", "color" },
    },
    {
        ["after"] = "\010        frame:AddChild(helpers.CreateText(L[\"Help.GROUP.unit\"]))\010        frame:AddChild(helpers.CreateText(L[\"Help.GROUP.raid\"]))\010    ",
        ["before"] = "\010        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L[\"Raid\"] .. color.RESET ..\010                \" - \" .. \"Check to see if we are in a raid, instead of just a party (note that with .\"\010                      .. \"this option off, this condition will be true if you are in a part OR a raid).\"))\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "help", "code" },
    },
    {
        ["after"] = 567,
        ["before"] = 545,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "help", "line" },
    },
    {
        ["after"] = "builtin:utils.lua:getCached",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.cache.getCached" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:deepcopy",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.collections.deepcopy" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:keys",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.collections.keys" },
    },
    {
        ["after"] = "builtin:utils.lua:compareString",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.presentation.compareString" },
    },
    {
        ["after"] = "builtin:utils.lua:nullable",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.presentation.nullable" },
    },
    {
        ["after"] = "builtin:utils.lua:playerize",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.presentation.playerize" },
    },
    {
        ["after"] = "builtin:utils.lua:compare",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.values.compare" },
    },
    {
        ["after"] = "builtin:utils.lua:isin",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "bindings", "Functions.values.isin" },
    },
    {
        ["after"] = "\010        if value.unit==nil or value.unit==\"player\" then\010            return value.raid and L[\"you {{!are|are not}} in a raid\"] or L[\"you {{!are|are not}} in a group\"]\010        end\010        local label=value.unit==\"spellrecipient\" and L[\"Spell recipient\"] or Functions.presentation.nullable(addon.units[value.unit],L[\"<unit>\"])\010        return addon:CreateConditionSummaryPhrase(value.raid and L[\"{unit} {{!is|is not}} in a raid\"] or L[\"{unit} {{!is|is not}} in a group\"],{unit=label})\010    ",
        ["before"] = "\010        return value.raid and L[\"you {{!are|are not}} in a raid\"] or L[\"you {{!are|are not}} in a group\"]\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "code" },
    },
    {
        ["after"] = 541,
        ["before"] = 527,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "print", "line" },
    },
    {
        ["after"] = "builtin:utils.lua:getCached",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.cache.getCached" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:deepcopy",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.collections.deepcopy" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:keys",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.collections.keys" },
    },
    {
        ["after"] = "builtin:utils.lua:compareString",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.presentation.compareString" },
    },
    {
        ["after"] = "builtin:utils.lua:nullable",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.presentation.nullable" },
    },
    {
        ["after"] = "builtin:utils.lua:playerize",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.presentation.playerize" },
    },
    {
        ["after"] = "builtin:utils.lua:compare",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.values.compare" },
    },
    {
        ["after"] = "builtin:utils.lua:isin",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "bindings", "Functions.values.isin" },
    },
    {
        ["after"] = "\010        return addon.Platform:CanReadValue(value.unit) and\010            (value.unit == nil or value.unit == \"spellrecipient\" or Functions.values.isin(addon.units, value.unit))\010    ",
        ["before"] = "\010        return true\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "code" },
    },
    {
        ["after"] = { "_", "value" },
        ["before"] = {},
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "valid", "parameters" },
    },
    {
        ["after"] = "builtin:utils.lua:getCached",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.cache.getCached" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:deepcopy",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.collections.deepcopy" },
    },
    {
        ["after"] = "builtin:Functions/collections.lua:keys",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.collections.keys" },
    },
    {
        ["after"] = "builtin:utils.lua:compareString",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.presentation.compareString" },
    },
    {
        ["after"] = "builtin:utils.lua:nullable",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.presentation.nullable" },
    },
    {
        ["after"] = "builtin:utils.lua:playerize",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.presentation.playerize" },
    },
    {
        ["after"] = "builtin:utils.lua:compare",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.values.compare" },
    },
    {
        ["after"] = "builtin:utils.lua:isin",
        ["beforePresent"] = false,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "bindings", "Functions.values.isin" },
    },
    {
        ["after"] = "\010        local top = parent:GetUserData(\"top\")\010        local root = top:GetUserData(\"root\")\010        local funcs = top:GetUserData(\"funcs\")\010        local units=Functions.collections.deepcopy(addon.units)\010        if top:GetUserData(\"announcement\")==true or value.unit==\"spellrecipient\" then units.spellrecipient=L[\"Spell recipient\"] end\010        local unit=addon:Widget_UnitWidget(value,units,function() top:SetStatusText(funcs:print(root,spec)) end)\010        unit.configure=function() unit:SetList(units,Functions.collections.keys(units));unit:SetValue(value.unit or \"player\") end\010        parent:AddChild(unit)\010        local raid = addon:CreateConditionCheckBox()\010        raid:SetWidth(100)\010        raid:SetLabel(L[\"Raid\"])\010        raid:SetValue(value.raid and true or false)\010        raid:SetCallback(\"OnValueChanged\", function(_, _, v)\010            value.raid = v\010            top:SetStatusText(funcs:print(root, spec))\010        end)\010        parent:AddChild(raid)\010    ",
        ["before"] = "\010        local top = parent:GetUserData(\"top\")\010        local root = top:GetUserData(\"root\")\010        local funcs = top:GetUserData(\"funcs\")\010\010        local raid = addon:CreateConditionCheckBox()\010        raid:SetWidth(100)\010        raid:SetLabel(L[\"Raid\"])\010        raid:SetValue(value.raid and true or false)\010        raid:SetCallback(\"OnValueChanged\", function(_, _, v)\010            value.raid = v\010            top:SetStatusText(funcs:print(root, spec))\010        end)\010        parent:AddChild(raid)\010    ",
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "code" },
    },
    {
        ["after"] = 548,
        ["before"] = 530,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "GROUP", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 680,
        ["before"] = 659,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 725,
        ["before"] = 704,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "help", "line" },
    },
    {
        ["after"] = 688,
        ["before"] = 667,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "print", "line" },
    },
    {
        ["after"] = 676,
        ["before"] = 655,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 692,
        ["before"] = 671,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "IMMUNE", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 618,
        ["before"] = 597,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 656,
        ["before"] = 635,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "help", "line" },
    },
    {
        ["after"] = 624,
        ["before"] = 603,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "print", "line" },
    },
    {
        ["after"] = 612,
        ["before"] = 591,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 629,
        ["before"] = 608,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RESIST", "callbacks", "widget", "line" },
    },
    {
        ["after"] = 581,
        ["before"] = 560,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "evaluate", "line" },
    },
    {
        ["after"] = 599,
        ["before"] = 578,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "help", "line" },
    },
    {
        ["after"] = 587,
        ["before"] = 566,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "print", "line" },
    },
    {
        ["after"] = 578,
        ["before"] = 557,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "valid", "line" },
    },
    {
        ["after"] = 590,
        ["before"] = 569,
        ["beforePresent"] = true,
        ["path"] = { "conditions", "RUNNER", "callbacks", "widget", "line" },
    },
    {
        ["after"] = "97e40d7aa47696692b8debccf6e0c560375ccfa9350a51722fe20c6aafcd33d2",
        ["before"] = "b088071d6a5b0dc277a19df9013b174599b7fee5e8ddee134dd7c9364fe447c5",
        ["beforePresent"] = true,
        ["path"] = { "modules", "Conditions/character.lua", "hash" },
    },
    {
        ["after"] = {
            ["args"] = {
                {
                    ["description"] = "Rotation Master platform adapter (implicit with colon calls).",
                    ["name"] = "self",
                    ["type"] = "RMPlatform",
                },
                {
                    ["description"] = "Readable nonempty unit token or native-recognized name, passed unchanged.",
                    ["name"] = "unit",
                    ["type"] = "string",
                },
                {
                    ["description"] = "True checks raid membership only; false or nil checks party then raid.",
                    ["name"] = "raidOnly",
                    ["type"] = "boolean | nil",
                },
            },
            ["bindings"] = {},
            ["callName"] = "addon.Platform:GetUnitGroupMembership",
            ["code"] = "\010    if not self:CanReadValue(unit) or not self:CanReadValue(raidOnly) then return nil,'restricted-value' end\010    if type(unit)~='string' or unit=='' or #unit>512 or unit:find('[%z\\1-\\31\\127]') then return nil,'invalid-unit' end\010    if raidOnly~=nil and type(raidOnly)~='boolean' then return nil,'invalid-group-query' end\010    if self:GetClientInfo().family=='unknown' then return nil,'unsupported-client' end\010    if not raidOnly then\010        if type(UnitInParty)~='function' then return nil,'missing-api' end\010        local ok,member=pcall(UnitInParty,unit)\010        if not ok then return nil,'api-error' end\010        if not self:CanReadValue(member) then return nil,'restricted-value' end\010        if member==nil then return nil,'group-data-unavailable' end\010        if type(member)~='boolean' then return nil,'invalid-api-result' end\010        if member then return true end\010    end\010    if type(UnitInRaid)~='function' then return nil,'missing-api' end\010    local ok,index=pcall(UnitInRaid,unit)\010    if not ok then return nil,'api-error' end\010    if not self:CanReadValue(index) then return nil,'restricted-value' end\010    if canaccessvalue and not canaccessvalue(index) then return nil,'restricted-value' end\010    -- The pinned native API returns an optional raid index: nil is nonmember.\010    if index==nil then return false end\010    if type(index)~='number' or index<1 or index>40 or index%1~=0 then return nil,'invalid-api-result' end\010    return true\010",
            ["description"] = "Read a specified unit membership in the player party or raid. True raidOnly queries only UnitInRaid; otherwise a true UnitInParty result short-circuits, false proceeds to UnitInRaid, and unknown remains unavailable. Readable nil raid index means false; integer raid index1..40 means true. Names are passed unchanged to native APIs; native name-query acceptance requires client qualification.",
            ["kind"] = "function",
            ["line"] = 22,
            ["parameters"] = { "self", "unit", "raidOnly" },
            ["returns"] = {
                { ["description"] = "Observed membership, or nil when unavailable.", ["type"] = "boolean | nil" },
                { ["description"] = "Validation or availability reason for a nil result.", ["type"] = "string | nil" },
            },
        },
        ["beforePresent"] = false,
        ["path"] = { "modules", "Platform/groups.lua", "bindings", "Platform_GetUnitGroupMembership" },
    },
    {
        ["after"] = "9e45f31346b55c5bf280b4014f45c7d19188c2eecbc8b4ea8986d28687e3cec7",
        ["before"] = "c9a001ecc3f69a0b3769d5772e6490c4ead926b84c6feb3ffd2eca5065b20115",
        ["beforePresent"] = true,
        ["path"] = { "modules", "Platform/groups.lua", "hash" },
    },
}

local function hash(text)
    local n = 5381

    for i = 1, #text do
        n = (n * 33 + text:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

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

return function(value, path, mode)
    value = dofile('tests/fixtures/restore_announcement_group_recipient.lua')(value, path, mode)

    if mode == 'catalog' then
        for _, d in ipairs(catalogDeltas) do
            local parent = value

            for i = 1, #d.path - 1 do
                parent = assert(parent[d.path[i]], 'missing GROUP catalog owner')
            end

            local key = d.path[#d.path]
            assert(equal(parent[key], d.after), 'unexpected GROUP catalog selected field')
            parent[key] = d.beforePresent and copy(d.before) or nil
        end

        return value
    end

    local r = assert(sourceRecords[path], 'unexpected GROUP source owner')

    if #value == r.oldBytes and hash(value) == r.oldHash then
        return value
    end

    assert(#value == r.newBytes and hash(value) == r.newHash, 'unexpected complete GROUP source')

    for _, h in ipairs(r.hunks) do
        local first, last = value:find(h[2], 1, true)
        assert(first and not value:find(h[2], last + 1, true), 'missing or duplicate GROUP inverse hunk')
        value = value:sub(1, first - 1) .. h[1] .. value:sub(last + 1)
    end

    assert(#value == r.oldBytes and hash(value) == r.oldHash, 'GROUP inverse failed complete predecessor proof')
    return value
end
