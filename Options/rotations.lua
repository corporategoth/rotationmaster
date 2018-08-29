local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local isint, isSpellOnSpec = addon.isint, addon.isSpellOnSpec
local pairs, color, tonumber = pairs, color, tonumber

local function AddNewRotation(spec, rotation)
    local rotation_settings = addon.db.profile.rotations

    if (rotation_settings[spec] == nil) then
        rotation_settings[spec] = {}
    end
    if (rotation_settings[spec][rotation] == nil) then
        rotation_settings[spec][rotation] = { rotation = {} }
    end
    if (rotation_settings[spec][rotation].rotation == nil) then
        rotation_settings[spec][rotation].rotation = {}
    end

    table.insert(rotation_settings[spec][rotation].rotation, {
        id = addon:uuid(),
        name = nil,
        type = "spell",
        action = nil,
        conditions = {}
    })
    AceConfigRegistry:NotifyChange(addon.name .. "Class")
end

function addon:get_rotation_list(spec, rotation)
    local rotation_settings = addon.db.profile.rotations

    local isnew = (rotation ~= DEFAULT and (rotation_settings[spec] == nil or rotation_settings[spec][rotation] == nil))
    local rotations = {}

    rotations["header"] = {
        order = 1,
        type = "header",
        width = "full",
        name = L["Rotations"]
    }

    rotations["description"] = {
        order = 2,
        type = "description",
        width = "full",
        name = L["Your main spell rotation.  Only one spell will be highlighted at once, which spell being based on the first satisfied condition."]
    }

    if (rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and
            rotation_settings[spec][rotation].rotation ~= nil) then

        local arraysz = #rotation_settings[spec][rotation].rotation
        for idx, rot in pairs(rotation_settings[spec][rotation].rotation) do
            local args = {}

            args["moveup"] = {
                order = 1,
                type = "execute",
                width = 0.67,
                name = L["Move Up"],
                disabled = (idx == 1),
                func = function(item)
                    rotation_settings[spec][rotation].rotation[idx] = rotation_settings[spec][rotation].rotation[idx-1]
                    rotation_settings[spec][rotation].rotation[idx-1] = rot
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["movedown"] = {
                order = 2,
                type = "execute",
                width = 0.67,
                name = L["Move Down"],
                disabled = (idx >= arraysz),
                func = function(item)
                    rotation_settings[spec][rotation].rotation[idx] = rotation_settings[spec][rotation].rotation[idx+1]
                    rotation_settings[spec][rotation].rotation[idx+1] = rot
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["delete"] = {
                order = 3,
                type = "execute",
                width = 0.67,
                name = DELETE,
                func = function(item)
                    table.remove(rotation_settings[spec][rotation].rotation, idx)
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["icon"] = {
                order = 10,
                name = "",
                type = "execute",
                width = 0.3,
                image = function(item)
                    if (rot.action ~= nil) then
                        if (rot.type == "spell" or rot.type == "pet") then
                            local _, _, icon = GetSpellInfo(rot.action)
                            return icon
                        elseif rot.type == "item" then
                            local itemID, _, _, _, icon = GetItemInfoInstant(rot.action)
                            if itemID ~= nil then
                                return icon
                            end
                        end
                    end
                    return "Interface\\Icons\\INV_Misc_QuestionMark"
                end,
            }

            args["name"] = {
                order = 11,
                name = NAME,
                type = "input",
                width = 1.7,
                get = function(item) if (rot.name ~= nil) then return rot.name else return nil end end,
                set = function(item, value)
                    rot.name = value
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["type"] = {
                order = 12,
                name = L["Action Type"],
                type = "select",
                width = 0.8,
                values = {
                    spell = "Spell",
                    pet = "Pet Spell",
                    item = "Item",
                },
                get = function(item) return rot.type end,
                set = function(item, value)
                    rot.type = value
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            if (rot.type == "spell") then
                args["action"] = {
                    order = 15,
                    name = L["Spell"],
                    type = "input",
                    dialogControl = "Player_EditBox",
                    width = 1.2,
                    get = function(item) if (rot.action ~= nil) then return select(1, GetSpellInfo(rot.action)) else return nil end end,
                    set = function(item, value)
                        addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot.action)
                        if isint(value) then
                            if isSpellOnSpec(spec, tonumber(value)) then
                                rot.action = tonumber(value)
                            else
                                rot.action = nil
                            end
                        else
                            rot.action = addon:GetSpecSpellID(spec, value)
                        end
                        AceConfigRegistry:NotifyChange(addon.name .. "Class")
                    end
                }
            elseif (rot.type == "pet") then
                args["action"] = {
                    order = 15,
                    name = L["Spell"],
                    desc = L["NOTE: Some spells can not be selected (even if auto-completed) due to WoW internals.  It may reequire you to switch specs or summon the requisite pet first before being able to populate this field."],
                    type = "input",
                    dialogControl = "Spell_EditBox",
                    width = 1.2,
                    get = function(item) if (rot.action ~= nil) then return select(1, GetSpellInfo(rot.action)) else return nil end end,
                    set = function(item, value)
                        addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot.action)
                        rot.action = select(7, GetSpellInfo(value))
                        AceConfigRegistry:NotifyChange(addon.name .. "Class")
                    end
                }
            else
                args["action"] = {
                    order = 15,
                    name = L["Item"],
                    type = "input",
                    dialogControl = "Inventory_EditBox",
                    width = 1.2,
                    get = function(item) if (rot.action ~= nil) then return rot.action else return nil end end,
                    set = function(item, value)
                        -- local itemID, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(value)
                        -- if itemID ~= nil then
                            rot.action = value
                        -- end
                        AceConfigRegistry:NotifyChange(addon.name .. "Class")
                    end
                }
            end

            args["conditions"] = {
                order = 20,
                name = L["Conditions"],
                type = "group",
                inline = true,
                args = {
                    default_desc = {
                        order = 10,
                        type = "description",
                        width = "full",
                        name = addon:printCondition(rot.conditions, spec),
                    },
                    validated = {
                        order = 15,
                        type = "header",
                        width = "full",
                        name = color.RED .. L["THIS CONDITION DOES NOT VALIDATE"] .. color.RESET,
                        hidden = function(info) return addon:validateCondition(rot.conditions, spec) end
                    },
                    edit_button = {
                        order = 20,
                        type = "execute",
                        name = EDIT,
                        func = function(info)
                            if (rot.conditions == nil) then
                                rot.conditions = { type = nil }
                            end
                            addon:EditCondition(idx, spec, rot.conditions)
                        end
                    },
                }
            }

            args["evaluation" ] = {
                order = 30,
                type = "description",
                name = function (info)
                    if addon:validateCondition(rot.conditions, spec) and addon:evaluateCondition(rot.conditions) then
                        return color.GREEN .. L["This conditions is currently satisfied."] .. color.RESET
                    else
                        return color.RED .. L["This conditions is currently not satisfied."] .. color.RESET
                    end
                end,
                hidden = function(info) return spec ~= addon.currentSpec or not addon:validateCondition(rot.conditions, spec) end
            }

            local name
            if rot.type == nil or rot.action == nil or not addon:validateCondition(rot.conditions, spec) then
                name = color.RED .. tostring(idx) .. color.RESET
            else
                name = tostring(idx)
            end
            if (rot.name ~= nil) then
                name = name .. " - " .. rot.name
            end

            local entry = {
                name = name,
                order = idx + 10,
                type = "group",
                args = args
            }

            rotations[rot.id] = entry
        end
    end

    rotations["*"] = {
        order = 999,
        type = "execute",
        name = ADD,
        disabled = isnew,
        func = function(info) AddNewRotation(spec, rotation) end
    }

    return rotations
end

