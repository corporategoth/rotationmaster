local _, addon = ...

local multiinsert, tablelength = addon.multiinsert, addon.tablelength

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
    if (GetServerExpansionLevel() >= 1) then
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
    if (GetServerExpansionLevel() >= 2) then

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
}

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
    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        if addon.db.profile.rotations ~= nil then
            local classID = select(3, UnitClass("player"))
            for j = 1, GetNumSpecializationsForClassID(classID) do
                local specID = GetSpecializationInfoForClassID(classID, j)
                if addon.db.profile.rotations[specID] ~= nil then
                    addon.db.char.rotations[specID] = addon.db.profile.rotations[specID]
                    addon.db.profile.rotations[specID] = nil
                end
            end
        end
    elseif (GetServerExpansionLevel() >= 2) then
        -- Upgrade from TBC -> Wrath
        if addon.db.char.rotations ~= nil and addon.db.char.rotations[0] ~= nil then
            addon.db.char.rotations[1] = addon.db.char.rotations[0]
            addon.db.char.rotations[0] = nil
        end
    else
        if addon.db.profile.rotations ~= nil and addon.db.profile.rotations[0] ~= nil then
            addon.db.char.rotations[0] = addon.db.profile.rotations[0]
            addon.db.profile.rotations[0] = nil
        end
    end
end

local function upgradeConditionItemsToItemSets(cond)
    if cond ~= nil and cond.type ~= nil then
        if cond.type == "NOT" then
            upgradeConditionItemsToItemSets(cond.value)
        elseif cond.type == "AND" or cond.type == "OR" then
            for _, v in pairs(cond.value) do
                upgradeConditionItemsToItemSets(v)
            end
        elseif cond.type == "EQUIPPED" or cond.type == "CARRYING" or
                cond.type == "ITEM" or cond.type == "ITEM_COOLDOWN" then
            if type(cond.item) == "number" or (type(cond.item) == "string" and
                    not string.match(cond.item, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x")) then
                cond.item = { cond.item }
            end
        end
    end
end

function addon:UpgradeRotationItemsToItemSets(rot)
    if rot.cooldowns then
        for _, cond in pairs(rot.cooldowns) do
            if cond.type == "item" and (type(cond.action) == "number" or (type(cond.action) == "string" and
                    not string.match(cond.action, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"))) then
                cond.action = { cond.action }
            end
            upgradeConditionItemsToItemSets(cond.conditions)
        end
    end
    if rot.rotation then
        for _, cond in pairs(rot.rotation) do
            if cond.type == "item" and (type(cond.action) == "number" or (type(cond.action) == "string" and
                    not string.match(cond.action, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"))) then
                cond.action = { cond.action }
            end
            upgradeConditionItemsToItemSets(cond.conditions)
        end
    end
end

local function upgradeItemsToItemSets()
    for _,rots in pairs(addon.db.char.rotations) do
        for _, rot in pairs(rots) do
            addon:UpgradeRotationItemsToItemSets(rot)
        end
    end
end

local function upgradeAddIDToAnnounce()
    for _,announce in pairs(addon.db.char.announces) do
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
    if addon.db.char.rotations ~= nil then
        for _, rotations in pairs(addon.db.char.rotations) do
            for _, rot in pairs(rotations) do
                if rot.cooldowns then
                    for _, cd in pairs(rot.cooldowns) do
                        if cd.effect ~= nil and cd.effect ~= NONE and global.effects[cd.effect] == nil then
                            cd.effect = name2idx[cd.effect]
                        end
                    end
                end
            end
        end
    end
end

function addon:init()
    if tablelength(addon.db.global.itemsets) == 0 then
        addon.db.global.itemsets = default_itemsets
    end
    if tablelength(addon.db.global.effects) == 0 then
        addon.db.global.effects = default_effects
    end

    upgradeTexturesToEffects()
    upgradeGlobalRotationstoPlayer()
    upgradeItemsToItemSets()
    upgradeAddIDToAnnounce()
    upgradeLogLevel()
    upgradeEffectsToGUID()
end
