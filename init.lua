local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local multiinsert, deepcopy = addon.multiinsert, addon.deepcopy

local CHAR_VERSION = 1
local PROFILE_VERSION = 2
local GLOBAL_VERSION = 1

local classKey = select(2, UnitClass("player"))

local combination_food = {}
local conjured_food = { 22895, 8076, 8075, 1487, 1114, 1113, 5349, }
local conjured_water = { 8079, 8078, 8077, 3772, 2136, 2288, 5350, }
local mana_potions = { 13444, 13443, 6149, 3827, 3385, 2455, }
local healing_potions = { 13446, 3928, 1710, 929, 858, 118, }
local bandages = { 14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251, }
local purchased_water = { 8766, 1645, 1708, 1205, 1179, 159, }
local healthstones = {
    "Major Healthstone",
    "Greater Healthstone",
    "Healthstone",
    "Lesser Healthstone",
    "Minor Healthstone",
}

if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    combination_food = { 113509, 80618, 80610, 65499, 43523, 43518, 65517, 65516, 65515, 65500 }
    multiinsert(mana_potions, { 152495, 127835, 109222, 76098, 57192, 33448, 40067, 31677, 22732, 28101 })
    multiinsert(healing_potions, { 169451, 152494, 127834, 152615, 109223, 57191, 39671, 22829, 28100 })
    multiinsert(bandages, { 158382, 158381, 133942, 133940, 111603, 72986, 72985, 53051, 53050, 53049, 34722, 34721, 21991, 21990 })
    multiinsert(healthstones, {
        "Legion Healthstone",
        "Fel Healthstone",
        "Demonic Healthstone",
        "Master Healthstone",
    })
else
    if (LE_EXPANSION_LEVEL_CURRENT >= 1) then
        combination_food = { 34062 }
        multiinsert(conjured_food, { 22019 })
        multiinsert(conjured_water, { 22018, 30703, })
        multiinsert(mana_potions, { 31677, 33093, 23823, 22832, 32948, 33935, 28101 })
        multiinsert(healing_potions, { 33092, 23822, 22829, 32947, 28100, 33934 })
        multiinsert(bandages, { 21991, 21990, 23684 })
        multiinsert(purchased_water, { 33042, 29395, 27860, 32453, 38430, 28399, 29454, 32455, 24007, 24006, 23161 })
        multiinsert(healthstones, {
            "Master Healthstone",
        })
    end
    if (LE_EXPANSION_LEVEL_CURRENT >= 2) then
        multiinsert(combination_food, { 43523, 43518 })
        multiinsert(mana_potions, { 33448, 40067, 31677, 43570 })
        multiinsert(healing_potions, { 33447, 39671, 43569 })
        multiinsert(bandages, { 38640, 34722, 38643, 34721 })
        multiinsert(purchased_water, { 42777 })
        multiinsert(healthstones, {
            "Fel Healthstone",
            "Demonic Healthstone",
        })
    end
end

local default_itemsets = {
    ["e8d1525c-0412-40c1-95a4-00da22bc169e"] = {
        name = "Combination Food",
        items = combination_food,
    },
    ["e626834f-60b1-413f-9c87-8ddeeb4374aa"] = {
        name = "Conjured Food",
        items = conjured_food,
    },
    ["3b10f7d6-abb2-430c-b153-7189eca75838"] = {
        name = "Conjured Water",
        items = conjured_water,
    },
    ["6079c534-5f69-430e-b1bd-b487a31dcdd3"] = {
        name = "Mana Potions",
        items = mana_potions,
    },
    ["9294d112-681b-43bc-ac62-5d6bec5c1f7d"] = {
        name = "Healing Potions",
        items = healing_potions,
    },
    ["e66d5cfe-a0f0-4276-aa00-40464eab30df"] = {
        name = "Bandages",
        items = bandages,
    },
    ["b1aca4a4-acdd-4885-b63b-b62cca7afdfe"] = {
        name = "Purchased Water",
        items = purchased_water,
    },
    ["fed2659d-cb7b-43e1-8f53-6dda0391b8c6"] = {
        name = "Healthstones",
        items = healthstones,
    },
}

local default_effects = {
    ["61b36ed1-fa31-4656-ad71-f3d50f193a85"] = {
        type = "texture",
        name = "Ping",
        texture = "Interface\\Cooldown\\ping4",
    },
    ["332c4db5-5134-411d-9af5-f47e12f5f4b8"] = {
        type = "texture",
        name = "Star",
        texture = "Interface\\Cooldown\\star4",
    },
    ["c58ddd8a-26f4-4709-8f82-5e25dc851507"] = {
        type = "texture",
        name = "Starburst",
        texture = "Interface\\Cooldown\\starburst",
    },
    ["102e4302-c7f5-4722-8004-583f95ce473d"] = {
        type = "blizzard",
        name = "Glow",
    },
    ["4d003e1d-cbb3-41c8-b1aa-50afe80561a6"] = {
        type = "pixel",
        name = "Pixel",
    },
    ["b8d33d53-62d7-4a08-a0fa-933d2cf8de9c"] = {
        type = "autocast",
        name = "Auto Cast",
    },
    ["d2ab8d6c-4346-42fd-bb1a-dc967feb32b7"] = {
        ["type"] = "animate",
        ["name"] = "Boom!",
        ["frequency"] = 0.25,
        ["sequence"] = {
            "Interface\\Cooldown\\star4", -- [1]
            "Interface\\Cooldown\\starburst", -- [2]
            "Interface\\Cooldown\\ping4", -- [3]
        },
    },
    ["cbd72b0b-e0f4-4f6e-bef4-459776a5d7a9"] = {
        ["type"] = "rotate",
        ["name"] = "Rotating Starburst",
        ["steps"] = 16,
        ["frequency"] = 0.1,
        ["texture"] = "Interface\\Cooldown\\star4",
    },
    ["ec8946a4-c3aa-4397-b129-a0c8d6fed479"] = {
        ["type"] = "pulse",
        ["name"] = "Pulse",
        ["texture"] = "Interface\\Cooldown\\ping4",
        ["sequence"] = {
            0.4, -- [1]
            0.6, -- [2]
            0.8, -- [3]
            1, -- [4]
            1.2, -- [5]
            1.4, -- [6]
        },
        ["frequency"] = 0.1,
    }
}

local default_condition_groups = {
    {
        id = "b3d7df2c-f257-4a2d-961e-66e49336d109",
        name = L["Combat"],
        conditions = {
            "CASTING", "CASTING_SPELL", "CASTING_REMAIN", "CAST_INTERRUPTABLE",
            "CHANNELING", "CHANNELING_SPELL", "CHANNELING_REMAIN", "CHANNEL_INTERRUPTABLE",
            "COMBAT", "STEALTHED", "INCONTROL", "LOC_TYPE", "LOC_BLOCKED",
            "RUNNER", "RESIST", "IMMUNE", "MOVING", "THREAT", "THREAT_COUNT",
            "ATTACKABLE", "ENEMY", "COMBAT_HISTORY", "COMBAT_HISTORY_TIME",
        }
    },
    {
        id = "b8136123-2bda-4230-a77a-89ea2aed3a1a",
        name = L["Character"],
        conditions = {
            "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION", "LEVEL", "TALENT",
            "ROLE", "GROUP", "FORM", "PET", "PET_NAME",
            "HEALTH", "HEALTHPCT", "TT_HEALTH", "TT_HEALTHPCT",
            "MANA", "MANAPCT", "POWER", "POWERPCT", "POINT", "RUNE", "RUNE_COOLDOWN",
            "TOTEM", "TOTEM_SPELL", "TOTEM_REMAIN", "TOTEM_SPELL_REMAIN",
            "STAT", "ECS_STAT", "ECS_STAT_PCT"
        }
    },
    {
        id = "8034819e-26f5-4f4e-9153-d8cab5e65f31",
        name = L["Spells"],
        conditions = {
            "SPELL_AVAIL", "SPELL_RANGE", "SPELL_COOLDOWN", "SPELL_REMAIN",
            "SPELL_CHARGES", "SPELL_ACTIVE", "SPELL_HISTORY", "SPELL_HISTORY_TIME",
            "PETSPELL_AVAIL", "PETSPELL_RANGE", "PETSPELL_COOLDOWN", "PETSPELL_REMAIN",
            "PETSPELL_CHARGES", "PETSPELL_ACTIVE", "PETSPELL_HISTORY", "PETSPELL_HISTORY_TIME",
            "ANYSPELL_AVAIL", "ANYSPELL_RANGE", "ANYSPELL_COOLDOWN", "ANYSPELL_REMAIN",
            "ANYSPELL_CHARGES",
        }
    },
    {
        id = "fca4ff75-4085-458a-b5bf-27a6b52f2092",
        name = L["Items"],
        conditions = {
            "EQUIPPED", "CARRYING", "ITEM", "ITEM_RANGE", "ITEM_COOLDOWN", "GLYPH",
        }
    },
    {
        id = "e618608c-92ec-4ae9-9dde-40a397d7beb9",
        name = L["Buffs"],
        conditions = {
            "BUFF", "BUFF_REMAIN", "BUFF_STACKS", "STEALABLE",
            "DEBUFF", "DEBUFF_REMAIN", "DEBUFF_STACKS", "DISPELLABLE",
            "WEAPON", "WEAPON_REMAIN", "WEAPON_STACKS", "SWING_TIME", "SWING_TIME_REMAIN",
        }
    },
    {
        id = "fa10aaf8-bc71-480f-9062-c949fd7c74e9",
        name = L["Spatial"],
        conditions = {
            "ZONE", "OUTDOORS", "DISTANCE", "DISTANCE_COUNT", "PROXIMITY",
            "PROXIMITY_HEALTH", "PROXIMITY_HEALTH_COUNT", "PROXIMITY_HEALTHPCT", "PROXIMITY_HEALTHPCT_COUNT",
            "PROXIMITY_MANA", "PROXIMITY_MANA_COUNT", "PROXIMITY_MANAPCT", "PROXIMITY_MANAPCT_COUNT",
        }
    },
}

-- Order of other conditions
local default_other_conditions_order = {
    "DELETE", "AND", "OR", "NOT", "ISSAME",
}

-- Default switch conditions
local default_switch_conditions = {
    "DELETE", "AND", "OR", "NOT", "SELF_LEVEL", "PVP", "ZONEPVP", "ZONE", "INSTANCE", "OUTDOORS",
    "STEALTHED", "GROUP", "FORM", "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION",
    "PET", "PET_NAME", "EQUIPPED", "DISTANCE_COUNT", "THREAT_COUNT", "ROLE", "GLYPH"
}

-- Default 'switch only' conditions
local default_disabled_conditions = {
    "SELF_LEVEL", "PVP", "ZONEPVP", "INSTANCE",
}

local function updateRotationData(rot_func, cond_func)
    if not addon.db.profile.rotations then
        return
    end

    local function updateConditionData(cond, func)
        if cond.type == "NOT" and cond.value ~= nil then
            updateConditionData(cond.value, func)
        elseif cond.type == "AND" or cond.type == "OR" and cond.value ~= nil then
            for _, subcond in pairs(cond.value) do
                updateConditionData(subcond, func)
            end
        else
            func(cond)
        end
    end

    for _, rotations in pairs(addon.db.profile.rotations) do -- Spec -> Rotations
        for _, rotation in pairs(rotations) do -- Rotation ID -> Rotation Struct
            if rotation.rotation ~= nil then
                for _, rot in pairs(rotation.rotation) do -- Individual Rotation Steps
                    if rot_func ~= nil then
                        rot_func(rot, false)
                    end
                    if cond_func ~= nil and rot.conditions ~= nil then
                        updateConditionData(rot.conditions, cond_func)
                    end
                end
            end
            if rotation.cooldowns ~= nil then
                for _, rot in pairs(rotation.cooldowns) do -- Individual Rotation Steps
                    if rot_func ~= nil then
                        rot_func(rot, true)
                    end
                    if cond_func ~= nil and rot.conditions ~= nil then
                        updateConditionData(rot.conditions, cond_func)
                    end
                end
            end
        end
    end
end

local function upgradeTexturesToEffects()
    if addon.db.global.textures ~= nil then
        addon.db.global.effects = addon.db.global.textures
        for _, ent in pairs(addon.db.global.effects) do
            ent["type"] = "texture"
        end
        addon.db.global.textures = nil
    end
    if addon.db.profile.overlay ~= nil then
        addon.db.profile.effect = addon.db.profile.overlay
        addon.db.profile.overlay = nil
    end
end

local function upgradeGlobalRotationstoPlayer()
    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        -- Upgrade from TBC -> Wrath
        if (LE_EXPANSION_LEVEL_CURRENT >= 2) and
            addon.db.profile.rotations ~= nil and addon.db.profile.rotations[0] ~= nil then
            local rot = addon.db.profile.rotations[0]
            addon.db.profile.rotations = {}
            addon.db.profile.rotations[1] = rot
        end
    end
end

local function upgradeItemsToItemSets()
    updateRotationData(function(rot)
        if rot.type == "item" and (type(rot.action) == "number" or (type(rot.action) == "string" and
                not string.match(rot.action, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"))) then
            rot.action = { rot.action }
        end
    end, function(cond)
        if cond.type == "EQUIPPED" or cond.type == "CARRYING" or
                cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" or
                cond.type == "ITEM_RANGE" then
            if type(cond.item) == "number" or (type(cond.item) == "string" and
                    not string.match(cond.item, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x")) then
                cond.item = { cond.item }
            end
        end
    end)
end

local function cacheItems()
    updateRotationData(function(rot)
        if rot.type == "item" and rot.action ~= nil and type(rot.action) == "table" then
            for _,item in pairs(rot.action) do
                GetItemInfo(item)
            end
        end
    end, function(cond)
        if cond.type == "EQUIPPED" or cond.type == "CARRYING" or
                cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" or
                cond.type == "ITEM_RANGE" then
            if cond.item ~= nil and type(cond.item) == "table" then
                for _,item in pairs(cond.item) do
                    GetItemInfo(item)
                end
            end
        end
    end)

    if addon.db.global.itemsets then
        for _,itemset in pairs(addon.db.global.itemsets) do
            if itemset.items ~= nil then
                for _,item in pairs(itemset.items) do
                    GetItemInfo(item)
                end
            end
        end
    end
    if addon.db.profile.itemsets then
        for _,itemset in pairs(addon.db.profile.itemsets) do
            if itemset.items ~= nil then
                for _,item in pairs(itemset.items) do
                    GetItemInfo(item)
                end
            end
        end
    end
end

local function upgradeAddIDToAnnounce()
    for _,announce in pairs(addon.db.profile.announces) do
        if announce.id == nil then
            announce.id = addon:uuid()
        end
    end
end

local function upgradeLogLevel()
    if addon.db.profile.debug then
        if addon.db.profile.verbose then
            addon.db.profile.loglevel = 4
        else
            addon.db.profile.loglevel = 3
        end
    end
    addon.db.profile.debug = nil
    addon.db.profile.verbose = nil
end

local function upgradeEffectsToGUID()
    local global = addon.db.global
    local name2idx = {}
    if #global.effects > 0 then
        local new_effects = {}
        for _,effect in ipairs(global.effects) do
            local uuid = addon:uuid()
            for k, v in pairs(default_effects) do
                if effect.name == v.name then
                    uuid = k
                end
            end
            new_effects[uuid] = effect
        end
        global.effects = new_effects
    end
    for k,v in pairs(global.effects) do
        if v.name and #v.name > 0 then
            name2idx[v.name] = k
        end
    end
    if global.effects[addon.db.profile.effect] == nil then
        addon.db.profile.effect = name2idx[addon.db.profile.effect]
    end

    updateRotationData(function(rot, is_cooldown)
        if is_cooldown and rot.effect ~= nil and rot.effect ~= NONE and global.effects[rot.effect] == nil then
            rot.effect = name2idx[rot.effect]
        end
    end)

    if addon.db.global.version == nil or addon.db.global.version < 1 then
        StaticPopupDialogs["ROTATIONMASTER_RESET_EFFECTS"] = {
            text = addon.pretty_name,
            subText = L["Default effects have changed since the previous release, do you want to reset the effect list?"],
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                addon.db.global.effects = deepcopy(default_effects)
            end,
            showAlert = 1,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        StaticPopup_Show("ROTATIONMASTER_RESET_EFFECTS")
    end
end

local function upgradePetSpellToAnySpell()
    if addon.db.profile.version == nil or addon.db.profile.version < 1 then
        updateRotationData(function(rot)
            if rot.type ~= nil and rot.type == BOOKTYPE_PET then
                rot.type = "any"
            end
        end, function(cond)
            if cond.type == "PETSPELL_AVAIL" then
                cond.type = "ANYSPELL_AVAIL"
            elseif cond.type == "PETSPELL_RANGE" then
                cond.type = "ANYSPELL_RANGE"
            elseif cond.type == "PETSPELL_COOLDOWN" then
                cond.type = "ANYSPELL_COOLDOWN"
            elseif cond.type == "PETSPELL_REMAIN" then
                cond.type = "ANYSPELL_REMAIN"
            elseif cond.type == "PETSPELL_CHARGES" then
                cond.type = "ANYSPELL_CHARGES"
            end
        end)
    end
end

local function upgradeRuneTypes()
    updateRotationData(nil, function(cond)
        if cond.type == "RUNE" or cond.type == "RUNE_COOLDOWN" then
            if cond.rune == "BLOOD" then
                cond.rune = 1
            elseif cond.rune == "FROST" then
                cond.rune = 2
            elseif cond.rune == "UNHOLY" then
                cond.rune = 3
            elseif cond.rune == "DEATH" then
                cond.rune = 4
            end
        end
    end)
end

local function upgradeBindingSlots()
    local DB = _G[addon_name .. "DB"]
    if DB.char then
        for _,char in pairs(DB.char) do
            if char.bindings then
                for id,val in pairs(char.bindings) do
                    if type(val) == "number" then
                        char.bindings[id] = { val }
                    end
                end
            end
        end
    end
end

function addon:getDefaultItemset(id)
    if default_itemsets[id] ~= nil then
        return default_itemsets[id].items
    end
end

local function moveProfileItems()
    if not addon.db.profile.version or addon.db.profile.version < 2 then
        local rotations = addon.db.char.rotations
        addon.db.char.rotations = nil
        local itemsets = addon.db.char.itemsets
        addon.db.char.itemsets = nil
        local announces = addon.db.char.announces
        addon.db.char.announces = nil

        local notempty = ((rotations and next(rotations) ~= nil) or
                          (itemsets and next(itemsets) ~= nil) or
                          (announces and next(announces) ~= nil))

        if addon.db:GetCurrentProfile() == DEFAULT then
            addon.db:SetProfile(classKey)
            local modified = ((addon.db.profile.rotations and next(addon.db.profile.rotations) ~= nil) or
                              (addon.db.profile.itemsets and next(addon.db.profile.itemsets) ~= nil) or
                              (addon.db.profile.announces and next(addon.db.profile.announces) ~= nil))

            if modified then
                if notempty then
                    addon.db:SetProfile(UnitName("player") .. " - " .. GetRealmName())
                    addon.db:CopyProfile(DEFAULT, true)
                end
            else
                addon.db:CopyProfile(DEFAULT, true)
            end
        end

        if rotations and next(rotations) ~= nil then
            addon.db.profile.rotations = rotations
        end

        if itemsets and next(itemsets) ~= nil then
            addon.db.profile.itemsets = itemsets
        end

        if announces and next(announces) ~= nil then
            addon.db.profile.announces = announces
        end
    end
end

function addon:augmentDefaults(defaults)
    defaults.char.version = CHAR_VERSION

    defaults.global.itemsets = deepcopy(default_itemsets)
    defaults.global.effects = deepcopy(default_effects)
    defaults.global.version = GLOBAL_VERSION

    defaults.profile.condition_groups = deepcopy(default_condition_groups)
    defaults.profile.switch_conditions = deepcopy(default_switch_conditions)
    defaults.profile.other_conditions_order = deepcopy(default_other_conditions_order)
    defaults.profile.disabled_conditions = deepcopy(default_disabled_conditions)
    defaults.profile.version = PROFILE_VERSION
end

function addon:init()
    moveProfileItems()

    for k,v in pairs(default_itemsets) do
        if addon.db.global.itemsets[k] ~= nil and not addon.db.global.itemsets[k].modified then
            addon.db.global.itemsets[k].items = deepcopy(v.items)
        end
    end

    upgradeTexturesToEffects()
    upgradeGlobalRotationstoPlayer()
    upgradeItemsToItemSets()
    cacheItems()
    upgradeAddIDToAnnounce()
    upgradeLogLevel()
    upgradeEffectsToGUID()
    upgradePetSpellToAnySpell()
    upgradeRuneTypes()
    upgradeBindingSlots()

    addon.db.char.version = CHAR_VERSION
    addon.db.profile.version = PROFILE_VERSION
    addon.db.global.version = GLOBAL_VERSION
end

