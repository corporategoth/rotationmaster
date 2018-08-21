local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local pairs, color = pairs, color

local function AddNewCooldown(spec, rotation)
    local rotation_settings = addon.db.profile.rotations

    if (rotation_settings[spec] == nil) then
        rotation_settings[spec] = {}
    end
    if (rotation_settings[spec][rotation] == nil) then
        rotation_settings[spec][rotation] = { cooldowns = {} }
    end
    if (rotation_settings[spec][rotation].cooldowns == nil) then
        rotation_settings[spec][rotation].cooldowns = {}
    end

    table.insert(rotation_settings[spec][rotation].cooldowns, {
        id = addon:uuid(),
        name = nil,
        overlay = nil,
        color = { r = 0, g = 1.0, b = 0, a = 1.0 },
        type = "spell",
        action = nil,
        conditions = {}
    })
    AceConfigRegistry:NotifyChange(addon.name .. "Class")
end

function addon:get_cooldown_list(spec, rotation)
    local textures = addon.db.global.textures
    local rotation_settings = addon.db.profile.rotations

    local isnew = (rotation ~= DEFAULT and (rotation_settings[spec] == nil or rotation_settings[spec][rotation] == nil))
    local cooldowns = {}

    cooldowns["header"] = {
        order = 1,
        type = "header",
        width = "full",
        name = L["Cooldowns"]
    }

    cooldowns["description"] = {
        order = 2,
        type = "description",
        width = "full",
        name = L["Spells that you wish to conditionally highlight independent of your rotation.  And or all of these may be highlighted at the same time."]
    }

    if (rotation_settings[spec] ~= nil and rotation_settings[spec][rotation] ~= nil and
            rotation_settings[spec][rotation].cooldowns ~= nil) then

        local arraysz = #rotation_settings[spec][rotation].cooldowns
        for idx, rot in pairs(rotation_settings[spec][rotation].cooldowns) do
            local args = {}

            args["moveup"] = {
                order = 1,
                type = "execute",
                width = 0.67,
                name = L["Move Up"],
                disabled = (idx == 1),
                func = function(item)
                    rotation_settings[spec][rotation].cooldowns[idx] = rotation_settings[spec][rotation].cooldowns[idx-1]
                    rotation_settings[spec][rotation].cooldowns[idx-1] = rot
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
                    rotation_settings[spec][rotation].cooldowns[idx] = rotation_settings[spec][rotation].cooldowns[idx+1]
                    rotation_settings[spec][rotation].cooldowns[idx+1] = rot
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["delete"] = {
                order = 3,
                type = "execute",
                width = 0.67,
                name = DELETE,
                func = function(item)
                    table.remove(rotation_settings[spec][rotation].cooldowns, idx)
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["overlay_icon"] = {
                order = 10,
                name = "",
                type = "execute",
                width = 0.3,
                image = function(item)
                    local overlay
                    if (rot.overlay ~= nil) then
                        overlay = rot.overlay
                    else
                        overlay = addon.db.profile.overlay
                    end

                    for k,v in pairs(textures) do
                        if v.name == overlay then
                            return v.texture
                        end
                    end
                    return nil
                end
            }

            args["overlay"] = {
                order = 11,
                name = L["Overlay Texture"],
                type = "select",
                width = 1.0,
                values = function(item)
                    local vals = { DEFAULT=DEFAULT }
                    for k,v in pairs(textures) do
                        vals[v.name] = v.name
                    end
                    return vals
                end,
                get = function(item) if (rot.overlay ~= nil) then return rot.overlay else return "DEFAULT" end end,
                set = function(item, value)
                    if value == "DEFAULT" then
                        rot.overlay = nil
                    else
                        rot.overlay = value
                    end
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            args["color"] = {
                order = 12,
                name = L["Highlight Color"],
                type = "color",
                width = 0.7,
                hasAlpha = true,
                get = function(item) return rot.color.r, rot.color.g, rot.color.b, rot.color.a end,
                set = function(item, r, g, b, a) rot.color = { r = r, g = g, b = b, a = a } end
        }

            args["icon"] = {
                order = 13,
                type = "execute",
                width = 0.3,
                name = "",
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
                order = 14,
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
                order = 15,
                name = L["Action Type"],
                type = "select",
                width = 0.8,
                values = {
                    spell = "Spell",
                    pet = "Pet Spell",
                    item = "Inventory Item",
                },
                get = function(item) return rot.type end,
                set = function(item, value)
                    rot.type = value
                    AceConfigRegistry:NotifyChange(addon.name .. "Class")
                end
            }

            if (rot.type == "spell") then
                args["action"] = {
                    order = 16,
                    name = L["Spell"],
                    type = "input",
                    dialogControl = "Spec_EditBox",
                    width = 1.2,
                    get = function(item) if (rot.action ~= nil) then return select(1, GetSpellInfo(rot.action)) else return nil end end,
                    set = function(item, value)
                        addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot.action)
                        rot.action = addon:GetSpecSpellID(spec, value)
                        AceConfigRegistry:NotifyChange(addon.name .. "Class")
                    end
                }
            elseif (rot.type == "pet") then
                args["action"] = {
                    order = 15,
                    name = L["Spell"],
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
                    order = 17,
                    name = L["Item"],
                    type = "input",
                    dialogControl = "Inventory_EditBox",
                    width = 1.2,
                    get = function(item) if (rot.action ~= nil) then return rot.action else return nil end end,
                    set = function(item, value)
                        addon:RemoveCooldownGlowIfCurrent(spec, rotation, rot.action)
                        rot.action = value
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
                    if (addon:evaluateCondition(rot.conditions)) then
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

            cooldowns[rot.id] = entry
        end
    end

    cooldowns["*"] = {
        order = 999,
        type = "execute",
        name = ADD,
        disabled = isnew,
        func = function(info) AddNewCooldown(spec, rotation) end
    }

    return cooldowns
end
