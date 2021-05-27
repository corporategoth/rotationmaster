local addon_name, addon = ...

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
        for k, cond in pairs(rot.cooldowns) do
            if cond.type == "item" and (type(cond.action) == "number" or (type(cond.action) == "string" and
                    not string.match(cond.action, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"))) then
                cond.action = { cond.action }
            end
            upgradeConditionItemsToItemSets(cond.conditions)
        end
    end
    if rot.rotation then
        for k, cond in pairs(rot.rotation) do
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

function addon:upgrade()
    upgradeTexturesToEffects()
    upgradeGlobalRotationstoPlayer()
    upgradeItemsToItemSets()
    upgradeAddIDToAnnounce()
    upgradeLogLevel()
end
