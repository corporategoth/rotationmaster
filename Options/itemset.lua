local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceGUI = LibStub("AceGUI-3.0")
local SpellData = LibStub("AceGUI-3.0-SpellLoader")

local pairs, color, tonumber = pairs, color, tonumber
local HideOnEscape, cleanArray, getCached, isint = addon.HideOnEscape, addon.cleanArray, addon.getCached, addon.isint

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetRelativeWidth(width)
    return rv
end

function addon:FindFirstItemInItems(items)
    if items == nil then
        return nil
    end
    for k,v in pairs(items) do
        local itemid = getCached(addon.longtermCache, GetItemInfoInstant, v)
        if itemid then
            return itemid
        end
    end
    return nil
end

function addon:FindFirstItemInItemSet(id)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    if itemsets[id] ~= nil then
        return addon:FindFirstItemInItems(itemsets[id].items)
    elseif global_itemsets[id] ~= nil then
        return addon:FindFirstItemInItems(global_itemsets[id].items)
    end
    return nil
end

function addon:FindItemInItems(items, item)
    if items == nil then
        return nil
    end
    if isint(item) then
        for k,v in pairs(items) do
            if getCached(addon.longtermCache, GetItemInfoInstant, v) == tonumber(item) then
                return tonumber(item)
            end
        end
    else
        for k,v in pairs(items) do
            local name, link = getCached(addon.longtermCache, GetItemInfo, v)
            if name == item then
                return select(1, getCached(addon.longtermCache, GetItemInfoInstant, link))
            end
        end
    end
    return nil
end

function addon:FindItemInItemSet(id, item)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    if itemsets[id] ~= nil then
        return addon:FindItemInItems(itemsets[id].items, item)
    elseif global_itemsets[id] ~= nil then
        return addon:FindItemInItems(global_itemsets[id].items, item)
    end
    return nil
end

function addon:FindFirstItemOfItems(cache, items, equipped)
    if items == nil then
        return nil
    end
    if equipped then
        for _, item in pairs(items) do
            for i=0,20 do
                local inventoryId = getCached(addon.combatCache, GetInventoryItemID, "player", i)
                if inventoryId ~= nil then
                    if isint(item) then
                        if tonumber(item) == inventoryId then
                            return inventoryId
                        end
                    else
                        local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if itemName == item then
                            return inventoryId
                        end
                    end
                end
            end
        end
    end
    for _, item in pairs(items) do
        for i=0,4 do
            for j=1,getCached(addon.combatCache, GetContainerNumSlots, i) do
                local inventoryId = getCached(cache, GetContainerItemID, i, j);
                if inventoryId ~= nil then
                    if isint(item) then
                        if tonumber(item) == inventoryId then
                            return inventoryId
                        end
                    else
                        local itemName = getCached(addon.longtermCache, GetItemInfo, inventoryId)
                        if item == itemName then
                            return inventoryId
                        end
                    end
                end
            end
        end
    end
    return nil
end

function addon:FindFirstItemOfItemSet(cache, id, equipped)
    local itemsets = self.db.char.itemsets
    local global_itemsets = self.db.global.itemsets

    if itemsets[id] ~= nil then
        return addon:FindFirstItemOfItems(cache, itemsets[id].items, equipped)
    elseif global_itemsets[id] ~= nil then
        return addon:FindFirstItemOfItems(cache, global_itemsets[id].items, equipped)
    end
    return nil
end

local function CondIsItem(cond, id)
    if cond then
        if cond.type == "NOT" then
            return CondIsItem(cond.value, id)
        elseif cond.type == "AND" or cond.type == "OR" then
            for _, v in pairs(cond.value) do
                if CondIsItem(v, id) then
                    return true
                end
            end
        elseif cond.type == "EQUIPPED" or cond.type == "CARRYING" or cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" then
            if type(cond.item) == "string" and cond.item == id then
                return true
            end
        end
    end
    return false
end

function addon:ItemSetInUse(id)
    local bindings = self.db.char.bindings
    local rotations = self.db.char.rotations

    if bindings[id] ~= nil then
        return true
    end

    for _, rots in pairs(rotations) do
        for _, rot in pairs(rots) do
            if rot.cooldowns then
                for _, cond in pairs(rot.cooldowns) do
                    if cond.type == "item" and type(cond.action) == "string" and cond.action == id then
                        return true
                    end
                    if CondIsItem(cond.conditions, id) then
                        return true
                    end
                end
            end
            if rot.rotation then
                for _, cond in pairs(rot.rotation) do
                    if cond.type == "item" and type(cond.action) == "string" and cond.action == id then
                        return true
                    end
                    if CondIsItem(cond.conditions, id) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function HandleDelete(id, update)
    local bindings = addon.db.char.bindings
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    StaticPopupDialogs["ROTATIONMASTER_DELETE_ITEMSET"] = {
        text = L["This item set is in use, are you sure you wish to delete it?"],
        button1 = ACCEPT,
        button2 = CANCEL,
        OnAccept = function(self)
            bindings[id] = nil
            itemsets[id] = nil
            global_itemsets[id] = nil
            if update then
                update()
            end
        end,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    StaticPopup_Show("ROTATIONMASTER_DELETE_ITEMSET")
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
        local initems = addon.split(editbox:GetText():gsub(",", "\n"), "\n")
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
        for idx,item in ipairs(items) do
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
            icon:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                GameTooltip:SetHyperlink("item:" .. items[idx])
            end)
            icon:SetCallback("OnLeave", function(widget)
                GameTooltip:Hide()
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

            local angle = math.rad(180)
            local cos, sin = math.cos(angle), math.sin(angle)

            local movetop = AceGUI:Create("Icon")
            movetop:SetImageSize(24, 24)
            if (idx == 1) then
                movetop:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
                movetop:SetDisabled(true)
            else
                movetop:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
                movetop:SetDisabled(false)
            end
            movetop:SetCallback("OnClick", function(widget, event, ...)
                local tmp = table.remove(items, idx)
                table.insert(items, 1, tmp)
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(movetop)

            local moveup = AceGUI:Create("Icon")
            moveup:SetImageSize(24, 24)
            if (idx == 1) then
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
                moveup:SetDisabled(true)
            else
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
                moveup:SetDisabled(false)
            end
            moveup:SetCallback("OnClick", function(widget, event, ...)
                local tmp = items[idx-1]
                items[idx-1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(moveup)

            local movedown = AceGUI:Create("Icon")
            movedown:SetImageSize(24, 24)
            if (idx == #items or items[idx+1] == "") then
                movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
                movedown:SetDisabled(true)
            else
                movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
                movedown:SetDisabled(false)
            end
            movedown:SetCallback("OnClick", function(widget, event, ...)
                local tmp = items[idx+1]
                items[idx+1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(movedown)

            local movebottom = AceGUI:Create("Icon")
            movebottom:SetImageSize(24, 24)
            if (idx == #items or items[idx+1] == "") then
                movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
                movebottom:SetDisabled(true)
            else
                movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Up")
                movebottom:SetDisabled(false)
            end
            movebottom:SetCallback("OnClick", function(widget, event, ...)
                local tmp = table.remove(items, idx)
                table.insert(items, tmp)
                update()
                create_item_list(frame, items, update)
            end)
            row:AddChild(movebottom)

            local delete = AceGUI:Create("Icon")
            delete:SetImageSize(24, 24)
            delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            delete:SetCallback("OnClick", function(widget, event, ...)
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

        local angle = math.rad(180)
        local cos, sin = math.cos(angle), math.sin(angle)

        local movetop = AceGUI:Create("Icon")
        movetop:SetImageSize(24, 24)
        movetop:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        movetop:SetDisabled(true)
        row:AddChild(movetop)

        local moveup = AceGUI:Create("Icon")
        moveup:SetImageSize(24, 24)
        moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled", (sin - cos), -(cos + sin), -cos, -sin, sin, -cos, 0, 0)
        moveup:SetDisabled(true)
        row:AddChild(moveup)

        local movedown = AceGUI:Create("Icon")
        movedown:SetImageSize(24, 24)
        movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        movedown:SetDisabled(true)
        row:AddChild(movedown)

        local movebottom = AceGUI:Create("Icon")
        movebottom:SetImageSize(24, 24)
        movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
        movebottom:SetDisabled(true)
        row:AddChild(movebottom)

        local delete = AceGUI:Create("Icon")
        delete:SetImageSize(24, 24)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
        movebottom:SetDisabled(true)
        row:AddChild(delete)
    end

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
    scrollwin:SetUserData("table", { columns = { 44, 1, 24, 24, 24, 24, 24 } })
    group:AddChild(scrollwin)

    create_item_list(scrollwin, items, update)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function item_list(frame, selected, itemset, update)
    local bindings = addon.db.char.bindings
    local itemsets = addon.db.char.itemsets
    local global_itemsets = addon.db.global.itemsets

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 44, 1, 35, 140, 140 } })
    group.frame:SetScript("OnHide", function()
        if addon.bindingItemSet then
            addon.bindingItemSet = nil
            if GetCursorInfo() == "item" then
                ClearCursor()
            end
        end
        addon.itemSetCallback = nil
        addon:EndHighlightSlot()
    end)
    frame:AddChild(group)

    local icon = AceGUI:Create("Icon")
    local name = AceGUI:Create("EditBox")
    local glob_button = AceGUI:Create("CheckBox")
    local delete = AceGUI:Create("Button")
    local importexport = AceGUI:Create("Button")
    local clicktobind = AceGUI:Create("Heading")
    local scrollwin = AceGUI:Create("ScrollFrame")

    addon.itemSetCallback = function(id)
        if id == selected then
            if bindings[selected] ~= nil then
                addon:ScheduleTimer("HighlightSlot", 0.5, bindings[selected])
                clicktobind:SetText(nil)
            elseif itemset and #itemset.items > 0 then
                clicktobind:SetText(color.WHITE .. L["Click the icon above to bind to your action bar"])
            end
        end
    end

    local itemid
    local function update_itemid()
        if itemset then
            itemid = addon:FindFirstItemOfItems({}, itemset.items, true)
            if itemid == nil and #itemset.items > 0 then
                itemid = addon:FindFirstItemInItems(itemset.items)
            end
            if itemid then
                icon:SetImage(select(5, GetItemInfoInstant(itemid)))
            end
            addon:UpdateBoundButton(selected)
        end
        addon.itemSetCallback(selected)
    end
    update_itemid()

    icon:SetImageSize(36, 36)
    icon:SetCallback("OnClick", function(widget)
        if itemid then
            addon.bindingItemSet = selected
            PickupItem(itemid)
        end
    end)
    icon:SetCallback("OnEnter", function(widget)
        if itemid then
            GameTooltip:SetOwner(icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("item:" .. itemid)
        end
    end)
    icon:SetCallback("OnLeave", function(widget)
        GameTooltip:Hide()
    end)
    group:AddChild(icon)

    name:SetLabel(NAME)
    name:SetFullWidth(true)
    if itemset then
        name:SetText(itemset.name)
    end
    name:SetCallback("OnEnterPressed", function(widget, event, v)
        if not itemset then
            itemset = { name = v, items = {} }
            if glob_button:GetValue() then
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

    local global = AceGUI:Create("SimpleGroup")
    global:SetFullWidth(true)
    global:SetLayout("Table")
    global:SetUserData("table", { columns = { 1 } })
    global:SetUserData("cell", { alignV = "middle", alignH = "center" })

    local glob_label = AceGUI:Create("Label")
    glob_label:SetText(L["Global"])
    glob_label:SetColor(1.0, 0.82, 0.0)
    global:AddChild(glob_label)

    glob_button:SetLabel("")
    glob_button:SetValue(selected and global_itemsets[selected] ~= nil)
    glob_button:SetCallback("OnValueChanged", function(widget, event, val)
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
    global:AddChild(glob_button)

    group:AddChild(global)

    delete:SetText(DELETE)
    delete:SetDisabled(itemset == nil)
    delete:SetCallback("OnClick", function(widget, event)
        if addon:ItemSetInUse(selected) then
            HandleDelete(selected, update)
        else
            bindings[selected] = nil
            itemsets[selected] = nil
            global_itemsets[selected] = nil
            update()
        end
    end)
    group:AddChild(delete)

    importexport:SetText(L["Import/Export"])
    importexport:SetDisabled(itemset == nil)
    importexport:SetCallback("OnClick", function(widget, event)
        ImportExport(itemset.items, function()
            create_item_list(scrollwin, itemset and itemset.items or nil, update_itemid)
        end)
    end)
    group:AddChild(importexport)

    clicktobind:SetFullWidth(true)
    frame:AddChild(clicktobind)

    scrollwin:SetFullWidth(true)
    scrollwin:SetFullHeight(true)
    scrollwin:SetLayout("Table")
    scrollwin:SetUserData("table", { columns = { 44, 1, 24, 24, 24, 24, 24 } })
    frame:AddChild(scrollwin)
    create_item_list(scrollwin, itemset and itemset.items or nil, function()
        update_itemid()
        update()
    end)

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
                if selects[selected] then
                    select:SetGroup(selected)
                else
                    select:SetGroup(nil)
                end
            end)
        end
    end)
    select.configure = function()
        local selects, sorted = self:get_item_list(NEW)
        select:SetGroupList(selects, sorted)
        select:SetGroup("")
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end
