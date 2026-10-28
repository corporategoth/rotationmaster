-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict test-only inverse for exactly the two approved widget bodies.
local old = {
    ZONEPVP = '\n'
        .. [=[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp_local = Functions.collections.deepcopy(addon.zonepvp)
        zonepvp_local[""] = L["no PVP"]

        local zone = addon:CreateConditionDropdown()
        zone:SetLabel(L["Mode"])
        zone:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.vlaue = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        zone.configure = function()
            zone:SetList(zonepvp_local, Functions.collections.keys(zonepvp_local))
            if (value.value ~= nil) then
                zone:SetValue(value.value)
            else
                zone:SetValue("")
            end
        end
        parent:AddChild(zone)
    ]=],
    INSTANCE = '\n'
        .. [=[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local instance = addon:CreateConditionDropdown()
        instance:SetLabel(L["Mode"])
        instance:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.vlaue = nil
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
    ]=],
}

local repaired = {
    ZONEPVP = '\n'
        .. [=[
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")
        local zonepvp_local = Functions.collections.deepcopy(addon.zonepvp)
        zonepvp_local[""] = L["no PVP"]

        local zone = addon:CreateConditionDropdown()
        zone:SetLabel(L["Mode"])
        zone:SetCallback("OnValueChanged", function(_, _, v)
            if v == "" then
                value.value = nil
            else
                value.value = v
            end
            top:SetStatusText(funcs:print(root, spec))
        end)
        zone.configure = function()
            zone:SetList(zonepvp_local, Functions.collections.keys(zonepvp_local))
            if (value.value ~= nil) then
                zone:SetValue(value.value)
            else
                zone:SetValue("")
            end
        end
        parent:AddChild(zone)
    ]=],
    INSTANCE = '\n'
        .. [=[
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
    ]=],
}

local function inverse(text, tag)
    assert(type(text) == 'string', 'selector inverse needs source text')

    if tag ~= nil then
        assert(repaired[tag] and text == repaired[tag], 'unexpected selector widget callback body/tag')
        return old[tag]
    end

    for _, name in ipairs({ 'ZONEPVP', 'INSTANCE' }) do
        local first, last = text:find(repaired[name], 1, true)

        assert(
            first and not text:find(repaired[name], last + 1, true),
            'unexpected selector widget body/count: ' .. name
        )

        text = text:sub(1, first - 1) .. old[name] .. text:sub(last + 1)
    end

    return text
end

return inverse, old, repaired
