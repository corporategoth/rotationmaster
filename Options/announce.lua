local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local table, ipairs = table, ipairs
local isSpellOnSpec = addon.isSpellOnSpec

function addon:create_announce_list(frame)
    local announces = self.db.char.announces

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("ScrollFrame")

    group:SetFullWidth(true)
    group:SetFullHeight(true)
    -- group:SetLayout("Flow")
    group:SetLayout("Table")
    -- group:SetUserData("table", { columns = { 100, 1, 125, 150, 24 } })
    group:SetUserData("table", { columns = { 1 } })

    local types = {
        spell = L["Spell"],
        item = L["Item"],
    }

    local announce_types = {
        partyraid = L["Raid or Party"],
        party = L["Party Only"],
        raidwarn = L["Raid Warning"],
        say = L["Say"],
        yell = L["Yell"],
        ["local"] = L["Local Only"],
    }

    for idx, value in ipairs(announces) do
        local row1 = AceGUI:Create("SimpleGroup")
        row1:SetFullWidth(true)
        row1:SetLayout("Table")
        row1:SetUserData("table", { columns = { 100, 1, 125, 24 } })
        local row2 = AceGUI:Create("SimpleGroup")
        row2:SetFullWidth(true)
        row2:SetLayout("Table")
        row2:SetUserData("table", { columns = { 150, 1 } })

        local action_group = AceGUI:Create("SimpleGroup")
        action_group:SetFullWidth(true)

        local function draw_action_group(ag, ent)
            ag:ReleaseChildren()
            ag:PauseLayout()

            if ent.type == "spell" then
                local spell_group = addon:Widget_SpellWidget(addon.currentSpec, "Spec_EditBox", ent,
                    function(v) return addon:GetSpecSpellID(addon.currentSpec, v) end,
                    function(v) return isSpellOnSpec(addon.currentSpec, v) end,
                    function() end)
                spell_group:SetFullWidth(true)
                ag:AddChild(spell_group)
            elseif ent.type == "item" then
                local item_group = addon:Widget_ItemWidget(nil, ent, function() end)
                item_group:SetFullWidth(true)
                ag:AddChild(item_group)
            end

            addon:configure_frame(ag)
            ag:ResumeLayout()
            ag:DoLayout()
        end

        local action_type = AceGUI:Create("Dropdown")
        action_type:SetFullWidth(true)
        action_type:SetLabel(L["Action Type"])
        action_type:SetCallback("OnValueChanged", function(widget, event, val)
            if value.type ~= val then
                value.type = val
                value.spell = nil
                value.item = nil
                addon:create_announce_list(frame)
                draw_action_group(action_group, value)
            end
        end)
        action_type.configure = function()
            action_type:SetList(types, { "spell", "item" })
            action_type:SetValue(value.type)
        end

        row1:AddChild(action_type)

        draw_action_group(action_group, value)
        row1:AddChild(action_group)

        local event = AceGUI:Create("Dropdown")
        event:SetFullWidth(true)
        event:SetLabel(L["Event"])
        event:SetCallback("OnValueChanged", function(widget, event, val)
            value.event = val
        end)
        event.configure = function()
            event:SetList(addon.events)
            event:SetValue(value.event)
        end
        row1:AddChild(event)

        local delete = AceGUI:Create("Icon")
        delete:SetImageSize(24, 24)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        delete:SetCallback("OnClick", function(widget, ewvent, ...)
            table.remove(announces, idx)
            addon:create_announce_list(frame)
        end)
        addon.AddTooltip(delete, DELETE)
        row1:AddChild(delete)

        local type = AceGUI:Create("Dropdown")
        type:SetFullWidth(true)
        type:SetLabel(L["Announce"])
        type:SetCallback("OnValueChanged", function(widget, event, val)
            value.announce = val
        end)
        type.configure = function()
            type:SetList(announce_types, { "partyraid", "party", "raidwarn", "say", "yell", "local" })
            type:SetValue(value.announce)
        end
        row2:AddChild(type)

        local type = AceGUI:Create("EditBox")
        type:SetFullWidth(true)
        type:SetLabel(L["Text"])
        type:SetText(value.value)
        type:SetCallback("OnEnterPressed", function(widget, event, val)
            value.value = val
        end)
        row2:AddChild(type)

        local separator = AceGUI:Create("Heading")
        separator:SetFullWidth(true)

        group:AddChild(row1)
        group:AddChild(row2)
        group:AddChild(separator)
    end

    local newentry = {
        type = "spell",
        announce = "partyraid",
        event = "SUCCEEDED",
    }

    local row1 = AceGUI:Create("SimpleGroup")
    row1:SetFullWidth(true)
    row1:SetLayout("Table")
    row1:SetUserData("table", { columns = { 100, 1, 125, 24 } })
    local row2 = AceGUI:Create("SimpleGroup")
    row2:SetFullWidth(true)
    row2:SetLayout("Table")
    row2:SetUserData("table", { columns = { 150, 1 } })

    local action_group = AceGUI:Create("SimpleGroup")
    action_group:SetFullWidth(true)

    local function draw_action_group(ag, ent)
        ag:ReleaseChildren()
        ag:PauseLayout()

        if ent.type == "spell" then
            local spell_group = addon:Widget_SpellWidget(addon.currentSpec, "Spec_EditBox", ent,
                function(v) return addon:GetSpecSpellID(addon.currentSpec, v) end,
                function(v) return isSpellOnSpec(addon.currentSpec, v) end,
                function()
                    if ent.spell then
                        table.insert(announces, ent)
                        addon:create_announce_list(frame)
                    end
                end)
            spell_group:SetFullWidth(true)
            ag:AddChild(spell_group)
        elseif ent.type == "item" then
            local item_group = addon:Widget_ItemWidget(nil, ent, function()
                if ent.item then
                    table.insert(announces, ent)
                    addon:create_announce_list(frame)
                end
            end)
            item_group:SetFullWidth(true)
            ag:AddChild(item_group)
        end

        addon:configure_frame(ag)
        ag:ResumeLayout()
        ag:DoLayout()
    end

    local action_type = AceGUI:Create("Dropdown")
    action_type:SetFullWidth(true)
    action_type:SetLabel(L["Action Type"])
    action_type:SetCallback("OnValueChanged", function(widget, event, val)
        if newentry.type ~= val then
            newentry.type = val
            draw_action_group(action_group, newentry)
        end
    end)
    action_type.configure = function()
        action_type:SetList(types, { "spell", "item" })
        action_type:SetValue(newentry.type)
    end

    row1:AddChild(action_type)

    draw_action_group(action_group, newentry)
    row1:AddChild(action_group)

    local event = AceGUI:Create("Dropdown")
    event:SetFullWidth(true)
    event:SetLabel(L["Event"])
    event:SetDisabled(true)
    event.configure = function()
        event:SetList(addon.events)
        event:SetValue("SUCCEEDED")
    end
    row1:AddChild(event)

    local delete = AceGUI:Create("Icon")
    delete:SetImageSize(24, 24)
    delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    delete:SetDisabled(true)
    addon.AddTooltip(delete, DELETE)
    row1:AddChild(delete)

    local type = AceGUI:Create("Dropdown")
    type:SetFullWidth(true)
    type:SetLabel(L["Announce"])
    type:SetDisabled(true)
    type.configure = function()
        type:SetList(announce_types, { "partyraid", "party", "raidwarn", "say", "yell", "local" })
        type:SetValue("partyraid")
    end
    row2:AddChild(type)

    local type = AceGUI:Create("EditBox")
    type:SetFullWidth(true)
    type:SetLabel("Text")
    type:SetDisabled(true)
    row2:AddChild(type)

    group:AddChild(row1)
    group:AddChild(row2)

    frame:AddChild(group)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_announce_options_help)
    help:SetTitle(L["Effects"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 38)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end