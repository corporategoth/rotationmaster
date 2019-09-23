local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local pairs, color, tonumber = pairs, color, tonumber
local HideOnEscape, cleanArray = addon.HideOnEscape, addon.cleanArray

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetRelativeWidth(width)
    return rv
end

local function ImportExport(items, update)
    local frame = AceGUI:Create("Window")
    frame:SetTitle(L["Import/Export Item List"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetWidth(485)
    frame:SetHeight(485)
    frame:EnableResize(false)
    HideOnEscape(frame)

    frame:PauseLayout()

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")

    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    editbox:SetLabel("")
    editbox:SetNumLines(28)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if items and #items > 0 then
        local body = items[1]
        for i=2,#items do
            body = body .. "\n" .. items[i]
        end
        editbox:SetText(body)
    end
    -- editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\RotationMaster\\Fonts\\Inconsolata-Bold.ttf", 13)
    editbox:SetCallback("OnTextChanged", function(widget, event, text)
        import:SetDisabled(false)
    end)

    editbox:HighlightText(0, string.len(editbox:GetText()))
    frame:AddChild(editbox)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 1, 0.25, 0.25 } })

    group:AddChild(spacer(1))

    import:SetText(L["Import"])
    import:SetDisabled(true)
    import:SetCallback("OnClick", function(wiget, event)
        cleanArray(items)
        local initems = addon.split(editbox:GetText(), "\n")
        for _, v in ipairs(initems) do
            table.insert(items, addon.trim(v))
        end

        frame:Hide()
        update()
    end)
    group:AddChild(import)

    local close = AceGUI:Create("Button")
    close:SetText(CANCEL)
    close:SetCallback("OnClick", function(wiget, event)
        frame:Hide()
    end)
    group:AddChild(close)

    frame:AddChild(group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function create_item_list(frame, items, update)
    frame:ReleaseChildren()
    frame:PauseLayout()

    if items then
        for idx,item in pairs(items) do
            local row = frame

            local icon = AceGUI:Create("ActionSlotItem")
            local name = AceGUI:Create("Inventory_EditBox")

            icon:SetWidth(44)
            icon:SetHeight(44)
            if item then
                icon:SetText(GetItemInfoInstant(item))
            end
            icon.text:Hide()
            icon:SetCallback("OnEnterPressed", function(widget, event, v)
                if v then
                    items[idx] = v
                    icon:SetText(v)
                    name:SetText(v and GetItemInfo(v) or nil)
                    update()
                else
                    table.remove(items, idx)
                    update()
                    create_item_list(frame, items, update)
                end
            end)
            row:AddChild(icon)

            name:SetFullWidth(true)
            name:SetLabel(L["Item"])
            if item then
                name:SetText(GetItemInfo(item) or item)
            end
            name:SetCallback("OnEnterPressed", function(widget, event, v)
                if v == "" then
                    table.remove(items, idx)
                    update()
                    create_item_list(frame, items, update)
                else
                    local itemid = GetItemInfoInstant(v)
                    items[idx] = itemid or v
                    icon:SetText(itemid)
                    name:SetText(itemid and GetItemInfo(itemid) or v)
                    update()
                end
            end)
            row:AddChild(name)

            local moveup = AceGUI:Create("Button")
            moveup:SetWidth(40)
            moveup:SetText("^")
            moveup:SetDisabled(idx == 1)
            moveup:SetCallback("OnClick", function(widget, ewvent, ...)
                local tmp = items[idx-1]
                items[idx-1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(moveup)

            local movedown = AceGUI:Create("Button")
            movedown:SetWidth(40)
            movedown:SetText("v")
            movedown:SetDisabled(idx == #items or items[idx+1] == "")
            movedown:SetCallback("OnClick", function(widget, ewvent, ...)
                local tmp = items[idx+1]
                items[idx+1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(movedown)

            local delete = AceGUI:Create("Button")
            delete:SetWidth(40)
            delete:SetText("X")
            delete:SetCallback("OnClick", function(widget, ewvent, ...)
                table.remove(items, idx)
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(delete)
        end
    end

    if items == nil or #items == 0 or (items[#items] ~= nil and items[#items] ~= "") then
        local row = frame

        local icon = AceGUI:Create("ActionSlotItem")
        icon:SetWidth(44)
        icon:SetHeight(44)
        icon:SetDisabled(items == nil)
        icon.text:Hide()
        icon:SetCallback("OnEnterPressed", function(widget, event, v)
            v = GetItemInfo(v)
            if v then
                items[#items + 1] = v
                update()
                create_item_list(frame, items, update)
            end
        end)
        row:AddChild(icon)

        local name = AceGUI:Create("Inventory_EditBox")
        name:SetFullWidth(true)
        name:SetLabel(L["Item"])
        name:SetDisabled(items == nil)
        name:SetText(nil)
        name:SetCallback("OnEnterPressed", function(widget, event, val)
            if val ~= nil then
                items[#items + 1] = val
                update()
                create_item_list(frame, items, update)
            end
        end)
        row:AddChild(name)

        local moveup = AceGUI:Create("Button")
        moveup:SetWidth(40)
        moveup:SetText("^")
        moveup:SetDisabled(true)
        row:AddChild(moveup)

        local movedown = AceGUI:Create("Button")
        movedown:SetWidth(40)
        movedown:SetText("v")
        movedown:SetDisabled(true)
        row:AddChild(movedown)

        local delete = AceGUI:Create("Button")
        delete:SetWidth(40)
        delete:SetText("X")
        delete:SetDisabled(true)
        row:AddChild(delete)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function item_list(frame, selected, itemset, update)
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 1, 70, 140, 140 } })
    frame:AddChild(group)

    local name = AceGUI:Create("EditBox")
    local global = AceGUI:Create("CheckBox")
    local delete = AceGUI:Create("Button")
    local importexport = AceGUI:Create("Button")
    local scrollwin = AceGUI:Create("ScrollFrame")

    name:SetLabel(NAME)
    name:SetFullWidth(true)
    if itemset then
        name:SetText(itemset.name)
    end
    name:SetCallback("OnEnterPressed", function(widget, event, v)
        if not itemset then
            itemset = { name = v, items = {} }
            if global:GetValue() then
                global_itemsets[selected] = itemset
            else
                itemsets[selected] = itemset
            end
            delete:SetDisabled(false)
            importexport:SetDisabled(false)
            create_item_list(scrollwin, itemset.items, update)
        else
            itemset.name = v
        end
        update()
    end)
    group:AddChild(name)

    global:SetLabel(L["Global"])
    global:SetValue(selected and global_itemsets[selected] ~= nil)
    global:SetCallback("OnValueChanged", function(widget, event, val)
        if itemset then
            if val then
                global_itemsets[selected] = itemsets[selected]
                itemsets[selected] = nil
            else
                itemsets[selected] = global_itemsets[selected]
                global_itemsets[selected] = nil
            end
            update()
        end
    end)
    group:AddChild(global)

    delete:SetText(DELETE)
    delete:SetDisabled(itemset == nil)
    delete:SetCallback("OnClick", function(widget, event)
        -- TODO: Warn if in use!
        itemsets[selected] = nil
        global_itemsets[selected] = nil
        update()
    end)
    group:AddChild(delete)

    importexport:SetText(L["Import/Export"])
    importexport:SetDisabled(itemset == nil)
    importexport:SetCallback("OnClick", function(widget, event)
        ImportExport(itemset.items, function()
            create_item_list(scrollwin, itemset and itemset.items or nil, update)
        end)
    end)
    group:AddChild(importexport)

    scrollwin:SetFullWidth(true)
    scrollwin:SetFullHeight(true)
    scrollwin:SetLayout("Table")
    scrollwin:SetUserData("table", { columns = { 44, 1, 40, 40, 40 } })
    frame:AddChild(scrollwin)
    create_item_list(scrollwin, itemset and itemset.items or nil, update)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:item_list_popup(name, items, update, onclose)
    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    frame:SetTitle(L["Item List"] .. ": " .. name)
    frame:SetFullWidth(true)
    frame:SetFullHeight(true)
    frame:SetLayout("Fill")
    if onclose then
        frame:SetCallback("OnClose", function(widget)
            onclose(widget)
        end)
    end
    HideOnEscape(frame)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("List")
    frame:AddChild(group)

    local scrollwin = AceGUI:Create("ScrollFrame")
    scrollwin:SetFullWidth(true)
    scrollwin:SetFullHeight(true)
    scrollwin:SetLayout("Table")
    scrollwin:SetUserData("table", { columns = { 44, 1, 40, 40, 40 } })
    group:AddChild(scrollwin)

    create_item_list(scrollwin, items, update)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:get_item_list(empty)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    local selects = {}
    local sorted = {}
    for k,v in pairs(itemsets) do
        selects[k] = v.name
        table.insert(sorted, k)
    end
    table.sort(sorted, function(lhs, rhs)
        return selects[lhs] < selects[rhs]
    end)

    local sorted2 = {}
    for k,v in pairs(global_itemsets) do
        selects[k] = color.CYAN .. v.name .. color.RESET
        table.insert(sorted2, k)
    end
    table.sort(sorted2, function(lhs, rhs)
        return selects[lhs] < selects[rhs]
    end)
    for _, v in ipairs(sorted2) do
        table.insert(sorted, v)
    end

    selects[""] = empty
    table.insert(sorted, "")

    return selects, sorted
end

function addon:create_itemset_list(frame)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    frame:ReleaseChildren()
    frame:PauseLayout()

    local select = AceGUI:Create("DropdownGroup")
    select:SetTitle(addon.pretty_name .. " - " .. L["Item List"])
    select:SetFullWidth(true)
    select:SetFullHeight(true)
    select:SetLayout("Fill")
    frame:AddChild(select)

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    group:SetLayout("Flow")
    select:AddChild(group)

    local selected
    select:SetCallback("OnGroupSelected", function(widget, event, val)
        if val == nil then
            selected = nil
            group:ReleaseChildren()
            group:DoLayout()
        elseif val ~= selected then
            if val == "" then
                selected = addon:uuid()
            else
                selected = val
            end

            local itemset = nil
            if itemsets[selected] ~= nil then
                itemset = itemsets[selected]
            elseif global_itemsets[selected] ~= nil then
                itemset = global_itemsets[selected]
            end
            item_list(group, selected, itemset, function()
                local selects, sorted = self:get_item_list(NEW)
                select:SetGroupList(selects, sorted)
                select:SetGroup(selected)
            end)
        end
    end)
    select.configure = function()
        local selects, sorted = self:get_item_list(NEW)
        select:SetGroupList(selects, sorted)
        select:SetGroup(selected)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end
