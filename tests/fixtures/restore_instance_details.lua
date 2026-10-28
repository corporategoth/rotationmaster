-- Layered inverse for the optional difficulty and instance ID of INSTANCE: the
-- block of Conditions/misc.lua that registers INSTANCE (with the difficulty
-- helpers placed before it) is replaced by the registration as it was before
-- those fields. Apply it first; the older inverses (restore_environment_selector_repairs,
-- restore_instance_repairs) then find the bodies they expect.
local current = [==[
-- The difficulty IDs the INSTANCE editor offers, in the order they are listed.
-- The game names each one (GetDifficultyInfo, in the player's language) and an
-- ID the client does not know is left out. 0 is "not in an instance".
local DIFFICULTIES = { 0, 1, 2, 23, 8, 24, 205, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17, 33, 208, 11, 12 }
-- The words after a difficulty name that say what kind of group it is for.
local function difficultyKind(group)
    if group == "party" then return L["Dungeon"] end
    if group == "raid" then return L["Raid"] end
    if group == "scenario" then return L["Scenario"] end
end
local function difficultyName(id)
    if id == 0 then return L["Not in an instance"] end
    if type(id) ~= "number" then return nil end
    local ok, name, group = pcall(GetDifficultyInfo, id)
    if ok and addon.Platform:CanReadValue(name) and type(name) == "string" and name ~= "" then
        local kind = addon.Platform:CanReadValue(group) and difficultyKind(group)
        if kind then return string.format(L["%s (%s)"], name, kind) end
        return name
    end
    return nil
end
local function validWhole(value)
    return type(value) == "number" and value == value and value >= 0 and value < 2^31 and value % 1 == 0
end

-- INSTANCE tests the kind of instance you are in. Difficulty and the exact
-- instance (by ID, which does not change with the game language the way a zone
-- name does) are optional additions: a condition saved without them is
-- unchanged, and one with them matches only when every part given matches.
addon:RegisterCondition("INSTANCE", {
    description = L["Instance"],
    icon = addon.Artwork.condition["INSTANCE"],
    fields = { value = "string", difficulty = "number", instanceID = "number" },
    valid = function(_, value)
        return (value.value == nil or Functions.values.isin(addon.instances, value.value))
            and (value.difficulty == nil or validWhole(value.difficulty))
            and (value.instanceID == nil or validWhole(value.instanceID))
    end,
    evaluate = function(value, cache)
        local extra = value.difficulty ~= nil or value.instanceID ~= nil
        -- The kind of instance, as before; with no kind chosen and a difficulty
        -- or an ID given, the kind is not part of the question.
        if value.value ~= nil or not extra then
            local record,reason=Functions.cache.getCached(cache, addon.Platform.GetInstanceObservation, addon.Platform)
            if not record then return nil,reason end
            local matches
            if value.value == "none" then matches = not record.inInstance
            elseif not record.inInstance then matches = false
            else
                if record.instanceType==nil then return nil,record.instanceTypeReason end
                matches = value.value == record.instanceType
            end
            if not extra or not matches then return matches end
        end
        local details, why = Functions.cache.getCached(cache, addon.Platform.GetInstanceDetails, addon.Platform)
        if not details then return nil, why end
        if value.difficulty ~= nil then
            if details.difficultyID == nil then return nil, details.reasons.difficultyID or "instance-data-unavailable" end
            if details.difficultyID ~= value.difficulty then return false end
        end
        if value.instanceID ~= nil then
            if details.instanceID == nil then return nil, details.reasons.instanceID or "instance-data-unavailable" end
            if details.instanceID ~= value.instanceID then return false end
        end
        return true
    end,
    print = function(_, value)
        if value.difficulty == nil and value.instanceID == nil then
            return string.format(L["your instance type {{!is|is not}} %s"],
                    Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
        end
        local parts = {}
        if value.value ~= nil then
            parts[#parts + 1] = string.format(L["type %s"], Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
        end
        if value.difficulty ~= nil then
            parts[#parts + 1] = string.format(L["difficulty %s"], difficultyName(value.difficulty) or tostring(value.difficulty))
        end
        if value.instanceID ~= nil then
            parts[#parts + 1] = string.format(L["ID %s"], tostring(value.instanceID))
        end
        return string.format(L["you {{!are|are not}} in an instance (%s)"], table.concat(parts, ", "))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(addon.instances, Functions.collections.keys(addon.instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)

        -- Optional: a difficulty the game names, or any.
        local choices, order = { [""] = L["Any difficulty"] }, { "" }
        for _, id in ipairs(DIFFICULTIES) do
            local name = difficultyName(id)
            if name then choices[id] = name; order[#order + 1] = id end
        end
        -- A difficulty saved for another client is kept and still shown.
        if validWhole(value.difficulty) and choices[value.difficulty] == nil then
            choices[value.difficulty] = difficultyName(value.difficulty) or string.format(L["difficulty %d"], value.difficulty)
            order[#order + 1] = value.difficulty
        end
        local difficulty = addon:CreateConditionDropdown()
        difficulty:SetLabel(L["Instance Difficulty"])
        difficulty:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then value.difficulty = nil else value.difficulty = v end
            top:SetStatusText(funcs:print(root, spec))
        end)
        difficulty.configure = function()
            difficulty:SetList(choices, order)
            difficulty:SetValue(value.difficulty ~= nil and value.difficulty or "")
        end
        parent:AddChild(difficulty)

        -- Optional: one particular instance by its ID (blank for any).
        local edit = addon:CreateConditionEditBox()
        edit:SetFullWidth(true)
        edit:SetLabel(L["Instance ID"])
        edit:SetText(value.instanceID and tostring(value.instanceID) or "")
        edit:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber(text)
            value.instanceID = validWhole(id) and id or nil
            edit:SetText(value.instanceID and tostring(value.instanceID) or "")
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(edit)

        -- Authoring aid: the instance you are in right now.
        local note = addon:CreateConditionLabel()
        note:SetFullWidth(true)
        local platform = addon.Platform
        local details = type(platform.GetInstanceDetails) == "function" and platform:GetInstanceDetails()
        if details and details.instanceID ~= nil and details.name ~= nil then
            note:SetText(string.format(L["You are in %s (instance ID %d)."], details.name, details.instanceID))
        else
            note:SetText(L["The instance you are in cannot be read right now."])
        end
        parent:AddChild(note)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The type of instance you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Outside"] .. color.RESET .. " - " ..
                "You are not in an instance (this does not necessarily mean you are outdoors, just not in any " ..
                "kind of instance.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Battleground"] .. color.RESET .. " - " ..
                "You are in a battleground (an ad-hoc instance where the opponent is the opposing faction.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "A close quarters fight with the opposing faction, where death is a loss.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Dungeon"] .. color.RESET .. " - " ..
                "A five-person dungeon, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Raid"] .. color.RESET .. " - " ..
                "An instance that accommodates more than five people, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Scenario"] .. color.RESET .. " - " ..
                "A single-person instance, similar to a dungeon but completed solo.")))
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(L["Help.Conditions.INSTANCE_DETAILS"]))
    end
})

]==]

local previous = [==[
addon:RegisterCondition("INSTANCE", {
    description = L["Instance"],
    icon = addon.Artwork.condition["INSTANCE"],
    fields = { value = "string" },
    valid = function(_, value)
        return value.value == nil or Functions.values.isin(addon.instances, value.value);
    end,
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache, addon.Platform.GetInstanceObservation, addon.Platform)
        if not record then return nil,reason end
        if value.value == "none" then return not record.inInstance end
        if not record.inInstance then return false end
        if record.instanceType==nil then return nil,record.instanceTypeReason end
        return value.value == record.instanceType
    end,
    print = function(_, value)
        return string.format(L["your instance type {{!is|is not}} %s"],
                Functions.presentation.nullable(addon.instances[value.value], L["Other (scenario)"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(addon.instances, Functions.collections.keys(addon.instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Mode"] .. color.RESET .. " - " ..
                "The type of instance you are in."))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Outside"] .. color.RESET .. " - " ..
                "You are not in an instance (this does not necessarily mean you are outdoors, just not in any " ..
                "kind of instance.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Battleground"] .. color.RESET .. " - " ..
                "You are in a battleground (an ad-hoc instance where the opponent is the opposing faction.)")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Arena"] .. color.RESET .. " - " ..
                "A close quarters fight with the opposing faction, where death is a loss.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Dungeon"] .. color.RESET .. " - " ..
                "A five-person dungeon, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Raid"] .. color.RESET .. " - " ..
                "An instance that accommodates more than five people, where your opponents are all NPCs.")))
        frame:AddChild(helpers.Indent(40, helpers.CreateText(color.GREEN .. L["Scenario"] .. color.RESET .. " - " ..
                "A single-person instance, similar to a dungeon but completed solo.")))
    end
})

]==]

-- The generated source getter at the foot of the module names the new locals as well.
local currentGetter = [==[
        if name=="DIFFICULTIES" then return DIFFICULTIES end
        if name=="color" then return color end
        if name=="difficultyKind" then return difficultyKind end
        if name=="difficultyName" then return difficultyName end
        if name=="helpers" then return helpers end
        if name=="validWhole" then return validWhole end
]==]

local previousGetter = [==[
        if name=="color" then return color end
        if name=="helpers" then return helpers end
]==]

-- The evaluate and widget callback bodies the exported source of INSTANCE carries now.
local evaluateBody = '\n'
    .. [==[
        local extra = value.difficulty ~= nil or value.instanceID ~= nil
        -- The kind of instance, as before; with no kind chosen and a difficulty
        -- or an ID given, the kind is not part of the question.
        if value.value ~= nil or not extra then
            local record,reason=Functions.cache.getCached(cache, addon.Platform.GetInstanceObservation, addon.Platform)
            if not record then return nil,reason end
            local matches
            if value.value == "none" then matches = not record.inInstance
            elseif not record.inInstance then matches = false
            else
                if record.instanceType==nil then return nil,record.instanceTypeReason end
                matches = value.value == record.instanceType
            end
            if not extra or not matches then return matches end
        end
        local details, why = Functions.cache.getCached(cache, addon.Platform.GetInstanceDetails, addon.Platform)
        if not details then return nil, why end
        if value.difficulty ~= nil then
            if details.difficultyID == nil then return nil, details.reasons.difficultyID or "instance-data-unavailable" end
            if details.difficultyID ~= value.difficulty then return false end
        end
        if value.instanceID ~= nil then
            if details.instanceID == nil then return nil, details.reasons.instanceID or "instance-data-unavailable" end
            if details.instanceID ~= value.instanceID then return false end
        end
        return true
    ]==]

local widgetBody = '\n'
    .. [==[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        instance.configure = function()
            instance:SetList(addon.instances, Functions.collections.keys(addon.instances))
            if (value.value ~= nil) then
                instance:SetValue(value.value)
            else
                instance:SetValue("")
            end
        end
        parent:AddChild(instance)

        -- Optional: a difficulty the game names, or any.
        local choices, order = { [""] = L["Any difficulty"] }, { "" }
        for _, id in ipairs(DIFFICULTIES) do
            local name = difficultyName(id)
            if name then choices[id] = name; order[#order + 1] = id end
        end
        -- A difficulty saved for another client is kept and still shown.
        if validWhole(value.difficulty) and choices[value.difficulty] == nil then
            choices[value.difficulty] = difficultyName(value.difficulty) or string.format(L["difficulty %d"], value.difficulty)
            order[#order + 1] = value.difficulty
        end
        local difficulty = addon:CreateConditionDropdown()
        difficulty:SetLabel(L["Instance Difficulty"])
        difficulty:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then value.difficulty = nil else value.difficulty = v end
            top:SetStatusText(funcs:print(root, spec))
        end)
        difficulty.configure = function()
            difficulty:SetList(choices, order)
            difficulty:SetValue(value.difficulty ~= nil and value.difficulty or "")
        end
        parent:AddChild(difficulty)

        -- Optional: one particular instance by its ID (blank for any).
        local edit = addon:CreateConditionEditBox()
        edit:SetFullWidth(true)
        edit:SetLabel(L["Instance ID"])
        edit:SetText(value.instanceID and tostring(value.instanceID) or "")
        edit:SetCallback("OnEnterPressed", function(_, _, text)
            local id = tonumber(text)
            value.instanceID = validWhole(id) and id or nil
            edit:SetText(value.instanceID and tostring(value.instanceID) or "")
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(edit)

        -- Authoring aid: the instance you are in right now.
        local note = addon:CreateConditionLabel()
        note:SetFullWidth(true)
        local platform = addon.Platform
        local details = type(platform.GetInstanceDetails) == "function" and platform:GetInstanceDetails()
        if details and details.instanceID ~= nil and details.name ~= nil then
            note:SetText(string.format(L["You are in %s (instance ID %d)."], details.name, details.instanceID))
        else
            note:SetText(L["The instance you are in cannot be read right now."])
        end
        parent:AddChild(note)
    ]==]

local function swap(text, from, to, what)
    local start, ending = text:find(from, 1, true)
    assert(start and not text:find(from, ending + 1, true), 'unexpected INSTANCE details ' .. what .. '/count')
    return text:sub(1, start - 1) .. to .. text:sub(ending + 1)
end

return function(text)
    assert(type(text) == 'string', 'instance details inverse needs source text')
    return swap(swap(text, current, previous, 'block'), currentGetter, previousGetter, 'getter')
end,
    previous,
    current,
    evaluateBody,
    widgetBody
