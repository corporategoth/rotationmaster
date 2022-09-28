local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local AceGUI = LibStub("AceGUI-3.0")

local CreateFrame, UIParent = CreateFrame, UIParent

local pairs, color, tonumber = pairs, color, tonumber
local units = addon.units
local HideOnEscape, getCached, getRetryCached, isint, deepcopy, compareArray =
    addon.HideOnEscape, addon.getCached, addon.getRetryCached, addon.isint, addon.deepcopy, addon.compareArray

local function spacer(width)
    local rv = AceGUI:Create("Label")
    rv:SetRelativeWidth(width)
    return rv
end

function addon:FindFirstItemInItems(items)
    if items == nil then
        return nil
    end
    for _,v in pairs(items) do
        if type(v) == "number" then
            return v -- Assume it's an item ID
        else
            local itemid = getRetryCached(addon.longtermCache, GetItemInfoInstant, v)
            if itemid then
                return itemid
            end
        end
    end
    return nil
end

function addon:FindFirstItemInItemSet(id)
    local itemsets = self.db.profile.itemsets
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
        for _,v in pairs(items) do
            if getRetryCached(addon.longtermCache, GetItemInfoInstant, v) == tonumber(item) then
                return tonumber(item)
            end
        end
    else
        for _,v in pairs(items) do
            local name, link = getRetryCached(addon.longtermCache, GetItemInfo, v)
            if name == item then
                return select(1, getRetryCached(addon.longtermCache, GetItemInfoInstant, link))
            end
        end
    end
    return nil
end

function addon:FindItemInItemSet(id, item)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    if itemsets[id] ~= nil then
        return addon:FindItemInItems(itemsets[id].items, item)
    elseif global_itemsets[id] ~= nil then
        return addon:FindItemInItems(global_itemsets[id].items, item)
    end
    return nil
end

function addon:FindFirstItemOfItems(_, items, equipped)
    if items == nil then
        return nil
    end
    for _, item in pairs(items) do
        local itemid
        if isint(item) then
            itemid = tonumber(item)
        else
            itemid = getRetryCached(addon.longtermCache, GetItemInfoInstant, item)
        end
        if itemid then
            if equipped and getCached(addon.combatCache, IsEquippedItem, itemid) then
                return itemid
            end
            if addon.bagContents[itemid] then
                return itemid
            end
        end
    end
    return nil
end

function addon:FindFirstItemOfItemSet(cache, id, equipped)
    local itemsets = self.db.profile.itemsets
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
        elseif cond.type == "EQUIPPED" or cond.type == "CARRYING" or cond.type == "ITEM" or
               cond.type == "ITEM_RANGE" or cond.type == "ITEM_COOLDOWN" then
            if type(cond.item) == "string" and cond.item == id then
                return true
            end
        end
    end
    return false
end

function addon:ItemSetInUse(id)
    local bindings = self.db.char.bindings
    local rotations = self.db.profile.rotations

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

function addon:UpdateItemSetButtons(id)
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    local itemset
    if itemsets[id] ~= nil then
        itemset = itemsets[id]
    elseif global_itemsets[id] ~= nil then
        itemset = global_itemsets[id]
    end

    if not itemset then
        if addon.itemSetButtons[id] then
            for key, button in pairs(addon.itemSetButtons[id]) do
                button:SetParent(nil)
                addon.itemSetButtons[id][key] = nil
                _G[button:GetName()] = nil
            end
            addon.itemSetButtons[id] = nil
        end
    else
        local prefix = "RM_" .. itemset.name:gsub("%W", "")
        if not addon.itemSetButtons[id] then
            addon.itemSetButtons[id] = {}
        end

        for key, _ in pairs(units) do
            local button = addon.itemSetButtons[id][key]
            if button and button:GetName() ~= prefix .. "_" .. key then
                button:SetParent(nil)
                _G[button:GetName()] = nil
                button = nil
            end

            if not button then
                button = CreateFrame("Button", prefix .. "_" .. key, UIParent, "SecureActionButtonTemplate")
                button:Hide()
                button:SetAttribute("type", "macro")
                addon.itemSetButtons[id][key] = button
            end

            local macrotext = ""
            for _, item in pairs(itemset.items) do
                macrotext = macrotext .. "/use [@" .. key .. "] item:" .. item .. "\n"
            end
            button:SetAttribute("macrotext", macrotext)
        end
    end
end

local function HandleDelete(id, update)
    local bindings = addon.db.char.bindings
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets

    StaticPopupDialogs["ROTATIONMASTER_DELETE_ITEMSET"] = {
        text = L["This item set is in use, are you sure you wish to delete it?"],
        button1 = ACCEPT,
        button2 = CANCEL,
        OnAccept = function()
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
    frame:SetTitle(L["Import/Export Item Set"])
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)
    frame:SetLayout("List")
    frame:SetWidth(485)
    frame:SetHeight(485)
    frame:EnableResize(false)
    HideOnEscape(frame)

    frame:PauseLayout()

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText(L["Copy and paste this text share your item set with others, or import someone else's."])
    frame:AddChild(desc)

    local import = AceGUI:Create("Button")
    local editbox = AceGUI:Create("MultiLineEditBox")

    editbox:SetFullHeight(true)
    editbox:SetFullWidth(true)
    editbox:SetLabel("")
    editbox:SetNumLines(27)
    editbox:DisableButton(true)
    editbox:SetFocus(true)
    if items and #items > 0 then
        local body = items[1]
        for i=2,#items do
            body = body .. "\n" .. items[i]
        end
        editbox:SetText(body)
    end
    -- editbox.editBox:GetRegions():SetFont("Interface\\AddOns\\" .. addon_name .. "\\Fonts\\Inconsolata-Bold.ttf", 13)
    editbox:SetCallback("OnTextChanged", function()
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
    import:SetCallback("OnClick", function()
        local body = addon.split(editbox:GetText():gsub(",", "\n"), "\n")
        for _, v in ipairs(body) do
            v = addon.trim(v)
        end

        frame:Hide()
        update(body)
    end)
    group:AddChild(import)

    local close = AceGUI:Create("Button")
    close:SetText(CANCEL)
    close:SetCallback("OnClick", function()
        frame:Hide()
    end)
    group:AddChild(close)

    frame:AddChild(group)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

local function create_item_list(frame, editbox, items, isvalid, update)
    frame:ReleaseChildren()
    frame:PauseLayout()

    if items then
        for idx,item in ipairs(items) do
            local row = frame

            local icon = AceGUI:Create("ActionSlotItem")
            local name = AceGUI:Create(editbox)

            icon:SetWidth(44)
            icon:SetHeight(44)
            icon.text:Hide()
            icon:SetCallback("OnEnterPressed", function(_, _, v)
                v = tonumber(v)
                if isvalid(v) then
                    items[idx] = v
                    addon:UpdateItem_Name_ID(v, name, icon)
                    if GameTooltip:IsOwned(icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:SetHyperlink("item:" .. v)
                    end
                    update()
                else
                    table.remove(items, idx)
                    if GameTooltip:IsOwned(icon.frame) and GameTooltip:IsVisible() then
                        GameTooltip:Hide()
                    end
                    update()
                    create_item_list(frame, editbox, items, isvalid, update)
                end
            end)
            icon:SetCallback("OnEnter", function()
                if items[idx] ~= nil then
                    local itemid = getRetryCached(addon.longtermCache, GetItemInfoInstant, items[idx])
                    if itemid then
                        GameTooltip:SetOwner(icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
                        GameTooltip:SetHyperlink("item:" .. itemid)
                    end
                end
            end)
            icon:SetCallback("OnLeave", function()
                if GameTooltip:IsOwned(icon.frame) then
                    GameTooltip:Hide()
                end
            end)
            row:AddChild(icon)

            name:SetFullWidth(true)
            name:SetLabel(L["Item"])
            name:SetCallback("OnEnterPressed", function(_, _, v)
                local itemid
                if not isint(v) then
                    itemid = getRetryCached(addon.longtermCache, GetItemInfoInstant, v)
                else
                    itemid = tonumber(v)
                end
                if isvalid(itemid or v) then
                    items[idx] = itemid or v
                    addon:UpdateItem_Name_ID(itemid or v, name, icon)
                    update()
                else
                    table.remove(items, idx)
                    update()
                    create_item_list(frame, editbox, items, isvalid, update)
                end
            end)
            row:AddChild(name)
            addon:UpdateItem_Name_ID(item, name, icon)

            local movetop = AceGUI:Create("Icon")
            movetop:SetImageSize(24, 24)
            if (idx == 1) then
                movetop:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Disabled")
                movetop:SetDisabled(true)
            else
                movetop:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Up")
                movetop:SetDisabled(false)
            end
            movetop:SetCallback("OnClick", function()
                local tmp = table.remove(items, idx)
                table.insert(items, 1, tmp)
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end)
            addon.AddTooltip(movetop, L["Move to Top"])
            row:AddChild(movetop)

            local moveup = AceGUI:Create("Icon")
            moveup:SetImageSize(24, 24)
            if (idx == 1) then
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
                moveup:SetDisabled(true)
            else
                moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
                moveup:SetDisabled(false)
            end
            moveup:SetCallback("OnClick", function()
                local tmp = items[idx-1]
                items[idx-1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end)
            addon.AddTooltip(moveup, L["Move Up"])
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
            movedown:SetCallback("OnClick", function()
                local tmp = items[idx+1]
                items[idx+1] = items[idx]
                items[idx] = tmp
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end)
            addon.AddTooltip(movedown, L["Move Down"])
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
            movebottom:SetCallback("OnClick", function()
                local tmp = table.remove(items, idx)
                table.insert(items, tmp)
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end)
            addon.AddTooltip(movebottom, L["Move to Bottom"])
            row:AddChild(movebottom)

            local delete = AceGUI:Create("Icon")
            delete:SetImageSize(24, 24)
            delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
            delete:SetCallback("OnClick", function()
                table.remove(items, idx)
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end)
            addon.AddTooltip(delete, DELETE)
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
        icon:SetCallback("OnEnterPressed", function(_, _, v)
            local item = getRetryCached(addon.longtermCache, GetItemInfo, v)
            if item then
                items[#items + 1] = item
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end
        end)
        row:AddChild(icon)

        local name = AceGUI:Create(editbox)
        name:SetFullWidth(true)
        name:SetLabel(L["Item"])
        name:SetDisabled(items == nil)
        name:SetText(nil)
        name:SetCallback("OnEnterPressed", function(_, _, val)
            if val ~= nil then
                items[#items + 1] = val
                update()
                create_item_list(frame, editbox, items, isvalid, update)
            end
        end)
        row:AddChild(name)

        local movetop = AceGUI:Create("Icon")
        movetop:SetImageSize(24, 24)
        movetop:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-ScrollHome-Disabled")
        movetop:SetDisabled(true)
        addon.AddTooltip(movetop, L["Move to Top"])
        row:AddChild(movetop)

        local moveup = AceGUI:Create("Icon")
        moveup:SetImageSize(24, 24)
        moveup:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
        moveup:SetDisabled(true)
        addon.AddTooltip(moveup, L["Move Up"])
        row:AddChild(moveup)

        local movedown = AceGUI:Create("Icon")
        movedown:SetImageSize(24, 24)
        movedown:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        movedown:SetDisabled(true)
        addon.AddTooltip(movedown, L["Move Down"])
        row:AddChild(movedown)

        local movebottom = AceGUI:Create("Icon")
        movebottom:SetImageSize(24, 24)
        movebottom:SetImage("Interface\\ChatFrame\\UI-ChatIcon-ScrollEnd-Disabled")
        movebottom:SetDisabled(true)
        addon.AddTooltip(movebottom, L["Move to Bottom"])
        row:AddChild(movebottom)

        local delete = AceGUI:Create("Icon")
        delete:SetImageSize(24, 24)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
        delete:SetDisabled(true)
        addon.AddTooltip(delete, DELETE)
        row:AddChild(delete)
    end

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:item_list_popup(name, editbox, items, isvalid, update, onclose)
    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    frame:SetTitle(L["Item Set"] .. ": " .. name)
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

    create_item_list(scrollwin, editbox, items, isvalid, update)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_item_list_help)
    help:SetTitle(L["Item Set"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 16)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()
end

function addon:bind_popup(name, _, _, onclose)
    local frame = AceGUI:Create("Frame")
    frame:PauseLayout()

    frame:SetTitle(L["Bind"] .. ": " .. name)
    frame:SetFullWidth(true)
    frame:SetFullHeight(true)
    frame:SetLayout("Fill")
    if onclose then
        frame:SetCallback("OnClose", function(widget)
            onclose(widget)
        end)
    end
    HideOnEscape(frame)

end

local function item_list(frame, selected, editbox, itemset, isvalid, update)
    local bindings = addon.db.char.bindings
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets

    frame:ReleaseChildren()
    frame:PauseLayout()

    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Table")
    group:SetUserData("table", { columns = { 44, 1, 35, 24, 24, 24, 24 } })
    frame:AddChild(group)

    local icon = AceGUI:Create("InteractiveLabel")
    local name = AceGUI:Create("EditBox")
    local glob_button = AceGUI:Create("CheckBox")
    local reset = AceGUI:Create("Icon")
    local importexport = AceGUI:Create("Icon")
    local duplicate = AceGUI:Create("Icon")
    local delete = AceGUI:Create("Icon")
    local scrollwin = AceGUI:Create("ScrollFrame")

    local itemSetCallback = function()
        local sel = frame:GetUserData("selected")
        if bindings[sel] ~= nil then
            addon:ScheduleTimer("HighlightSlots", 0.5, bindings[sel])
        else
            addon:EndHighlightSlot()
        end
    end
    addon.itemSetCallback = itemSetCallback

    frame.frame:SetScript("OnShow", function()
        addon.itemSetCallback = itemSetCallback
        itemSetCallback(frame:GetUserData("selected"))
    end)
    frame.frame:SetScript("OnHide", function()
        if addon.bindingItemSet then
            addon.bindingItemSet = nil
            if GetCursorInfo() == "item" then
                ClearCursor()
            end
        end
        addon.itemSetCallback = nil
        addon:EndHighlightSlot()
    end)

    local itemid
    local function update_itemid()
        if itemset then
            itemid = addon:FindFirstItemOfItems({}, itemset.items, true)
            if itemid == nil and #itemset.items > 0 then
                itemid = addon:FindFirstItemInItems(itemset.items)
            end
            addon:UpdateItem_ID_Image(itemid, nil, icon)
            addon:UpdateBoundButton(selected)
            addon:UpdateItemSetButtons(selected)
        end
    end
    update_itemid()

    local function list_update()
        update_itemid()
        local defset = addon:getDefaultItemset(selected)
        if defset ~= nil then
            itemset.modified = not compareArray(defset, itemset.items)
        else
            itemset.modified = true
        end

        if itemset.modified then
            reset:SetDisabled(false)
            reset:SetImage("Interface\\Buttons\\UI-RotationLeft-Button-Up")
        else
            reset:SetDisabled(true)
            reset:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-RotationLeft-Button-Disabled")
        end
        update()
    end

    icon:SetImageSize(36, 36)
    icon:SetCallback("OnEnter", function()
        if itemid then
            GameTooltip:SetOwner(icon.frame, "ANCHOR_BOTTOMRIGHT", 3)
            GameTooltip:SetHyperlink("item:" .. itemid)
        end
    end)
    icon:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(icon.frame) then
            GameTooltip:Hide()
        end
    end)
    icon:SetCallback("OnClick", function()
        addon.bindingItemSet = selected
        PickupItem(itemid)
    end)
    group:AddChild(icon)

    name:SetLabel(NAME)
    name:SetFullWidth(true)
    if itemset then
        name:SetText(itemset.name)
    end
    name:SetCallback("OnEnterPressed", function(_, _, v)
        if not itemset then
            itemset = { name = v, items = {} }
            if glob_button:GetValue() then
                global_itemsets[selected] = itemset
            else
                itemsets[selected] = itemset
            end
            delete:SetDisabled(false)
            duplicate:SetDisabled(false)
            importexport:SetDisabled(false)
            create_item_list(scrollwin, editbox, itemset.items, isvalid, list_update)
        else
            itemset.name = v
        end
        addon:UpdateItemSetButtons(selected)
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
    glob_button:SetCallback("OnValueChanged", function(_, _, val)
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

    reset:SetImageSize(24, 24)
    if itemset == nil or not itemset.modified then
        reset:SetDisabled(true)
        reset:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-RotationLeft-Button-Disabled")
    else
        reset:SetDisabled(false)
        reset:SetImage("Interface\\Buttons\\UI-RotationLeft-Button-Up")
    end
    reset:SetUserData("cell", { alignV = "bottom" })
    reset:SetCallback("OnClick", function()
        itemset.items = deepcopy(addon:getDefaultItemset(selected))
        itemset.modified = nil
        reset:SetDisabled(true)
        create_item_list(scrollwin, editbox, itemset.items, isvalid, list_update)
        update_itemid()
    end)
    addon.AddTooltip(reset, RESET)
    group:AddChild(reset)

    importexport:SetImageSize(24, 24)
    if itemset == nil then
        importexport:SetDisabled(true)
        importexport:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-FriendsList-Small-Disabled")
    else
        importexport:SetDisabled(false)
        importexport:SetImage("Interface\\FriendsFrame\\UI-FriendsList-Small-Up")
    end
    importexport:SetUserData("cell", { alignV = "bottom" })
    importexport:SetCallback("OnClick", function()
        ImportExport(itemset.items, function(items)
            create_item_list(scrollwin, editbox, items, isvalid, list_update)
            list_update()
        end)
    end)
    addon.AddTooltip(importexport, L["Import/Export"])
    group:AddChild(importexport)

    duplicate:SetImageSize(24, 24)
    duplicate:SetUserData("cell", { alignV = "bottom" })
    if itemset == nil then
        duplicate:SetImage("Interface\\AddOns\\" .. addon_name .. "\\textures\\UI-ChatIcon-Maximize-Disabled")
        duplicate:SetDisabled(true)
    else
        duplicate:SetImage("Interface\\ChatFrame\\UI-ChatIcon-Maximize-Up")
        duplicate:SetDisabled(false)
    end
    duplicate:SetCallback("OnClick", function()
        local tmp = deepcopy(itemset)
        tmp.name = string.format(L["Copy of %s"], tmp.name)
        tmp.modified = nil
        local newid = addon:uuid()
        if glob_button:GetValue() then
            global_itemsets[newid] = tmp
        else
            itemsets[newid] = tmp
        end

        addon:UpdateItemSetButtons(newid)
        update(newid)
    end)
    addon.AddTooltip(duplicate, L["Duplicate"])
    group:AddChild(duplicate)

    delete:SetImageSize(24, 24)
    delete:SetUserData("cell", { alignV = "bottom" })
    if itemset == nil then
        delete:SetDisabled(true)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
    else
        delete:SetDisabled(false)
        delete:SetImage("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    end
    delete:SetCallback("OnClick", function()
        if addon:ItemSetInUse(selected) then
            HandleDelete(selected, update)
        else
            bindings[selected] = nil
            itemsets[selected] = nil
            global_itemsets[selected] = nil
            addon:UpdateItemSetButtons(selected)
            update()
        end
    end)
    addon.AddTooltip(delete, DELETE)
    group:AddChild(delete)

    local separator = AceGUI:Create("Heading")
    separator:SetFullWidth(true)
    frame:AddChild(separator)

    scrollwin:SetFullWidth(true)
    scrollwin:SetFullHeight(true)
    scrollwin:SetLayout("Table")
    scrollwin:SetUserData("table", { columns = { 44, 1, 24, 24, 24, 24, 24 } })
    frame:AddChild(scrollwin)
    create_item_list(scrollwin, editbox, itemset and itemset.items or nil, isvalid, list_update)

    local help = AceGUI:Create("Help")
    help:SetLayout(addon.layout_itemsets_options_help)
    help:SetTitle(L["Item Sets"])
    frame:AddChild(help)
    help:SetPoint("TOPRIGHT", 8, 8)

    addon:configure_frame(frame)
    frame:ResumeLayout()
    frame:DoLayout()

    itemSetCallback(group:GetUserData("selected"))
end

function addon:get_item_list(empty)
    local itemsets = self.db.profile.itemsets
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
    local itemsets = self.db.profile.itemsets
    local global_itemsets = self.db.global.itemsets

    frame:ReleaseChildren()
    frame:PauseLayout()

    local select = AceGUI:Create("DropdownGroup")
    select:SetTitle(addon.pretty_name .. " - " .. L["Item Set"])
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
    select:SetCallback("OnGroupSelected", function(_, _, val)
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

            local itemset
            if itemsets[selected] ~= nil then
                itemset = itemsets[selected]
            elseif global_itemsets[selected] ~= nil then
                itemset = global_itemsets[selected]
            end
            group:SetUserData("selected", selected)
            item_list(group, selected, "Inventory_EditBox", itemset, function() return true end, function(newsel)
                local selects, sorted = self:get_item_list(NEW)
                select:SetGroupList(selects, sorted)
                if selects[newsel or selected] then
                    select:SetGroup(newsel or selected)
                else
                    select:SetGroup("")
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
