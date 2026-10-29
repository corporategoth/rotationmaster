-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Saved-variable defaults and startup upgrades. Owns the stock data new profiles start with (default item sets,
-- cooldown effects, condition-picker groups, switch and hidden condition lists) and the one-way upgrades that bring
-- older saved data forward. It does not evaluate rotations or draw anything. main.lua (OnInitializeInternal) calls
-- addon:augmentDefaults before AceDB opens the saved variables, then addon:init once the database exists; validate.lua
-- runs after init.lua and checks what these upgrades leave behind. Loaded from RotationMaster.toc after main.lua and
-- buttons.lua. Rotation bodies from before the scoped store are reached through the archive walk below, never through
-- the owned records in rotationStore, which are current data.

local addon_name, addon = ...
-- Captured at load (Core/dependency_revisions.lua loads earlier); nil when that module is absent, and every use below
-- tests for nil first.
local invalidateDependencies = addon.InvalidateRotationDependencies

if type(invalidateDependencies) ~= 'function' then
    invalidateDependencies = nil
end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local multiinsert, deepcopy = addon.Functions.collections.multiinsert, addon.Functions.collections.deepcopy

-- Copies plain data with every nested table copied.
-- @param value any  The value to copy.
-- @return any  The deep copy of a table; any other value as it is.
--
-- Functions.collections.deepcopy copies only the top level, so a table built from it still shares its nested tables
-- with the source; use this where the copy is saved data that the player will edit and the source must stay the
-- shipped default.
local function copyTree(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, entry in pairs(value) do
        copy[key] = copyTree(entry)
    end

    return copy
end

-- Schema versions stamped into the saved variables at the end of addon:init, once every upgrade for that level has run.
-- A profile that has the scoped rotation store is stamped 3 instead of PROFILE_VERSION.
local CHAR_VERSION = 1
local PROFILE_VERSION = 2
local GLOBAL_VERSION = 1

local classKey = select(2, UnitClass("player"))

-- ============================================================================
-- Default data
-- ============================================================================

-- Default item set contents, as item ids (the healthstone list holds item names). The lists start with the Classic Era
-- items; the branch below then adds what each expansion level or Retail introduced, so one file serves every client.
local combination_food = {}
local conjured_food = { 22895, 8076, 8075, 1487, 1114, 1113, 5349 }
local conjured_water = { 8079, 8078, 8077, 3772, 2136, 2288, 5350 }
local mana_potions = { 13444, 13443, 6149, 3827, 3385, 2455 }
local healing_potions = { 13446, 3928, 1710, 929, 858, 118 }
local bandages = {14530, 14529, 8545, 8544, 6451, 6450, 3531, 3530, 2581, 1251}
local purchased_water = { 8766, 1645, 1708, 1205, 1179, 159 }

local healthstones = {
    "Major Healthstone",
    "Greater Healthstone",
    "Healthstone",
    "Lesser Healthstone",
    "Minor Healthstone",
}

-- Retail replaces the combination food list and extends the others; Classic clients extend them by expansion level
-- (1 is TBC, 2 is Wrath and later).
if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
    combination_food = {113509, 80618, 80610, 65499, 43523, 43518, 65517, 65516, 65515, 65500}
    multiinsert(mana_potions, {152495, 127835, 109222, 76098, 57192, 33448, 40067, 31677, 22732, 28101})
    multiinsert(healing_potions, {169451, 152494, 127834, 152615, 109223, 57191, 39671, 22829, 28100})

    multiinsert(bandages, {
        158382, 158381, 133942, 133940, 111603, 72986, 72985, 53051, 53050, 53049, 34722, 34721, 21991, 21990
    })

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
        multiinsert(conjured_water, { 22018, 30703 })
        multiinsert(mana_potions, { 31677, 33093, 23823, 22832, 32948, 33935, 28101 })
        multiinsert(healing_potions, { 33092, 23822, 22829, 32947, 28100, 33934 })
        multiinsert(bandages, { 21991, 21990, 23684 })
        multiinsert(purchased_water, {33042, 29395, 27860, 32453, 38430, 28399, 29454, 32455, 24007, 24006, 23161})

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

-- Item sets every new profile gets. The UUID keys are stable identities that saved rotations and the "modified" flag
-- refer to, so they must never change; addon:init refreshes the contents of any set the player has not modified.
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

-- Cooldown highlight effects every new account gets (global.effects), keyed by stable UUID so a rotation's effect field
-- keeps resolving. upgradeEffectsToGUID also matches an old name-keyed effect against these names to adopt the UUID.
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
            "Interface\\Cooldown\\star4",  -- [1]
            "Interface\\Cooldown\\starburst",  -- [2]
            "Interface\\Cooldown\\ping4",  -- [3]
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
            0.4,  -- [1]
            0.6,  -- [2]
            0.8,  -- [3]
            1,  -- [4]
            1.2,  -- [5]
            1.4,  -- [6]
        },
        ["frequency"] = 0.1,
    },
}

-- The categories the condition picker groups tags under (profile.condition_groups). Each group has a stable id; a tag
-- listed in no group appears under "Other" (see listConditions in Core/condition_catalog.lua). Tags a client cannot
-- support are filtered at display time, so a group may name tags this client lacks.
local default_condition_groups = {
    {
        id = "b3d7df2c-f257-4a2d-961e-66e49336d109",
        name = L["Combat"],
        conditions = {
            "CASTING", "CASTING_SPELL", "CASTING_REMAIN", "CASTING_PROGRESS", "CAST_INTERRUPTABLE", "CHANNELING",
            "CHANNELING_SPELL", "CHANNELING_REMAIN", "CHANNELING_PROGRESS", "CHANNEL_INTERRUPTABLE", "COMBAT",
            "STEALTHED", "INCONTROL", "LOC_TYPE", "LOC_BLOCKED", "RUNNER", "RESIST", "IMMUNE", "MOVING", "THREAT",
            "THREAT_COUNT", "ATTACKABLE", "ENEMY", "COMBAT_HISTORY", "COMBAT_HISTORY_TIME", "TIME_IN_COMBAT",
            "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE", "BOSSMOD_TIMER", "ENCOUNTER", "MARKED", "MARK_COUNT"
        },
    },
    {
        id = "b8136123-2bda-4230-a77a-89ea2aed3a1a",
        name = L["Character"],
        conditions = {
            "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION", "LEVEL", "TALENT", "SPECIALIZATION", "ROLE", "GROUP",
            "RAID_ROLE", "UNIT_EXISTS", "FORM", "PET", "PET_NAME", "HEALTH", "HEALTHPCT", "TT_HEALTH", "TT_HEALTHPCT",
            "MANA", "MANAPCT", "POWER", "POWERPCT", "POINT", "RUNE", "RUNE_COOLDOWN", "TOTEM", "TOTEM_SPELL",
            "TOTEM_REMAIN", "TOTEM_SPELL_REMAIN", "STAT", "ECS_STAT", "ECS_STAT_PCT", "HERO_TALENT", "GROUP_COUNT",
            "PET_HAPPINESS", "STAGGER", "ECLIPSE"
        },
    },
    {
        id = "8034819e-26f5-4f4e-9153-d8cab5e65f31",
        name = L["Spells"],
        conditions = {
            "SPELL_KNOWN", "SPELL_AVAIL", "SPELL_RANGE", "SPELL_COOLDOWN", "SPELL_REMAIN", "SPELL_CHARGES",
            "SPELL_ACTIVE", "SPELL_HISTORY", "SPELL_HISTORY_TIME", "PETSPELL_AVAIL", "PETSPELL_RANGE",
            "PETSPELL_COOLDOWN", "PETSPELL_REMAIN", "PETSPELL_CHARGES", "PETSPELL_ACTIVE", "PETSPELL_HISTORY",
            "PETSPELL_HISTORY_TIME", "ANYSPELL_AVAIL", "ANYSPELL_RANGE", "ANYSPELL_COOLDOWN", "ANYSPELL_REMAIN",
            "ANYSPELL_CHARGES", "SPELL_GLOW"
        },
    },
    {
        id = "fca4ff75-4085-458a-b5bf-27a6b52f2092",
        name = L["Items"],
        conditions = {
            "EQUIPPED",
            "CARRYING",
            "ITEM",
            "ITEM_RANGE",
            "ITEM_COOLDOWN",
            "GLYPH",
            "WEAPON_TYPE",
        },
    },
    {
        id = "e618608c-92ec-4ae9-9dde-40a397d7beb9",
        name = L["Buffs"],
        conditions = {
            "BUFF", "BUFF_REMAIN", "BUFF_STACKS", "STEALABLE", "DEBUFF", "DEBUFF_REMAIN", "DEBUFF_STACKS",
            "DISPELLABLE", "WEAPON", "WEAPON_REMAIN", "WEAPON_STACKS", "SWING_TIME", "SWING_TIME_REMAIN"
        },
    },
    {
        id = "fa10aaf8-bc71-480f-9062-c949fd7c74e9",
        name = L["Spatial"],
        conditions = {
            "ZONE", "OUTDOORS", "DISTANCE", "BEYOND_MELEE", "DISTANCE_COUNT", "PROXIMITY", "PROXIMITY_HEALTH",
            "PROXIMITY_HEALTH_COUNT", "PROXIMITY_HEALTHPCT", "PROXIMITY_HEALTHPCT_COUNT", "PROXIMITY_MANA",
            "PROXIMITY_MANA_COUNT", "PROXIMITY_MANAPCT", "PROXIMITY_MANAPCT_COUNT", "PLAYER_STATE", "KEYSTONE_LEVEL"
        },
    },
}

-- Tags that head the ungrouped "Other" picker list, in this order, ahead of every other ungrouped condition
-- (profile.other_conditions_order).
local default_other_conditions_order = {
    "DELETE",
    "AND",
    "OR",
    "NOT",
    "ISSAME",
}

-- Tags offered when editing a rotation's switch, the rule that selects the rotation automatically
-- (profile.switch_conditions). Includes the combinators and DELETE entry the editor needs.
local default_switch_conditions = {
    "DELETE", "AND", "OR", "NOT", "SELF_LEVEL", "PVP", "ZONEPVP", "ZONE", "INSTANCE", "OUTDOORS", "STEALTHED", "GROUP",
    "FORM", "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION", "PET", "PET_NAME", "EQUIPPED", "DISTANCE_COUNT",
    "THREAT_COUNT", "ROLE", "GLYPH", "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE", "SPECIALIZATION", "WEAPON_TYPE", "ENCOUNTER",
    "KEYSTONE_LEVEL", "HERO_TALENT", "GROUP_COUNT", "PLAYER_STATE"
}

-- Tags left out of the picker's ungrouped "Other" list unless a caller asks for everything
-- (profile.disabled_conditions). These are switch-only conditions; the switch list above still offers them.
local default_disabled_conditions = {
    "SELF_LEVEL",
    "PVP",
    "ZONEPVP",
    "INSTANCE",
}

-- ============================================================================
-- Saved-data upgrades
-- ============================================================================

-- Calls a function for every body the old formats can still be in.
-- @param visit function  Called with each rotation body; it may edit a body but must not add or remove bodies.
--
-- Before the scoped store, that was the active profile's rotations. Under it they are the archive
-- (profile.rotationStore.legacy.rotations, of every profile) and a character's own pre-2.0 roots
-- (sv.char[*].rotations). Owned records (rotationStore.classes and .characters) are 2.0 data and are NEVER visited: the
-- old-format passes below are not no-ops on current data ('pet' is a current step type, PETSPELL_* current
-- conditions). It reads the raw saved variables (addon.db.sv), so profiles other than the active one are covered, and
-- the active profile is visited once even though it is also listed there.
local function eachSavedBody(visit)
    -- Visits every body of a rotation map.
    -- @param map any  A rotation map: spec key -> (rotation id -> body); anything that is not a table is skipped, not
    --   an error.
    local function bodies(map)
        if type(map) ~= "table" then
            return
        end

        for _, rows in pairs(map) do
            if type(rows) == "table" then
                for _, body in pairs(rows) do
                    visit(body)
                end
            end
        end
    end

    local sv = addon.db.sv
    local seen = {}

    -- Visits the old-format bodies of one saved profile.
    -- @param p any  The saved profile; a profile already seen is skipped.
    -- @return nil  Nothing: the rotations branch returns the result of bodies, which returns none.
    --
    -- A profile that has no rotationStore still holds its rotations in the old root; one that has it keeps only the
    -- archive (rotationStore.legacy.rotations) in the old format.
    local function profile(p)
        if type(p) ~= "table" or seen[p] then
            return
        end

        seen[p] = true
        local store = p.rotationStore

        if type(store) ~= "table" then
            return bodies(p.rotations)
        end

        if type(store.legacy) == "table" then
            bodies(store.legacy.rotations)
        end
    end

    for _, p in pairs(sv and sv.profiles or {}) do
        profile(p)
    end

    profile(addon.db.profile)

    for _, char in pairs(sv and sv.char or {}) do
        if type(char) == "table" then
            bodies(char.rotations)
        end
    end
end

-- Calls a function on every leaf condition of a condition tree, looking through NOT, AND and OR wrappers.
-- @param cond any  The condition tree; malformed values are ignored.
-- @param func function  Called with each leaf condition.
-- @param depth number|nil  The nesting depth; the cap (64) stops a cyclic or absurdly deep saved tree from recursing
--   forever.
local function updateConditionData(cond, func, depth)
    depth = depth or 0

    if type(cond) ~= "table" or depth > 64 then
        return
    end

    if cond.type == "NOT" and type(cond.value) == "table" then
        updateConditionData(cond.value, func, depth + 1)
    elseif (cond.type == "AND" or cond.type == "OR") and type(cond.value) == "table" then
        for _, subcond in pairs(cond.value) do
            updateConditionData(subcond, func, depth + 1)
        end
    else
        func(cond)
    end
end

-- Applies every pass to one saved rotation body with a single index of its steps.
-- @param rotation table  The body; edited in place.
-- @param passes table[]  The passes, each { stepFunc, condFunc }: stepFunc(step, isCooldown) runs on each non-Branch
--   step and condFunc(cond) on each leaf condition of the step's condition tree; either may be nil.
--
-- A body is walked once however many passes there are.
local function upgradeBody(rotation, passes)
    local tree = addon.RotationData.IndexRotationSteps(rotation, { allowMissingIds = true })

    -- Malformed data is retained for inspection, never flattened or
    -- partially upgraded by a best-effort walk over unknown structure.
    if tree then
        for _, row in ipairs(tree.rows) do
            local step = row.step

            for _, pass in ipairs(passes) do
                if pass[1] and step.type ~= "branch" then
                    pass[1](step, row.section == "cooldowns")
                end
                if pass[2] and step.conditions then
                    updateConditionData(step.conditions, pass[2])
                end
            end
        end
    end
end

-- Under scoped storage the passes are collected here and run by
-- upgradeSavedBodies, in ONE walk over the archive: a body is indexed once
-- however many passes there are, and the walk is skipped while the archive
-- is exactly what the last successful walk left (the marker below holds the
-- upgrade version and the number of bodies; adopting one, or a profile or
-- character with old bodies arriving, changes the count and walks again).
-- LEGACY_BODY_UPGRADE is that upgrade version: changing it makes every settled archive walk once more.
local LEGACY_BODY_UPGRADE = 1
local pendingPasses = {}

-- Registers one upgrade pass.
-- @param rot_func function|nil  rot_func(step, isCooldown), called for each non-Branch step.
-- @param cond_func function|nil  cond_func(cond), called for each leaf condition.
-- @param opts table|nil  { activeOnly = true } for a pass over the rotations the player runs now (prefetching item data
--   for archived bodies would be work nobody asked for); under the scoped store such a pass is dropped, because this
--   function never visits the owned records.
--
-- What happens depends on the storage generation. With the scoped store the pass is only queued in pendingPasses for
-- upgradeSavedBodies, so it must be called before that runs (addon:init does). Without it, and only while the profile
-- still has its old rotations root, the pass runs at once over those rotations.
local function updateRotationData(rot_func, cond_func, opts)
    local scoped = addon.InitializeScopedRotationStorage ~= nil

    if not scoped and (addon.db.profile.rotationStore ~= nil or not addon.db.profile.rotations) then
        return
    end

    if scoped then
        if opts and opts.activeOnly then
            return
        end

        pendingPasses[#pendingPasses + 1] = { rot_func, cond_func }
        return
    end

    local passes = { { rot_func, cond_func } }

    for _, rotations in pairs(addon.db.profile.rotations) do
        for _, rotation in pairs(rotations) do
            upgradeBody(rotation, passes)
        end
    end
end

-- Runs the queued passes in one walk over every archived and pre-2.0 body.
--
-- Afterwards it records the marker global.legacyBodyUpgrade ("<LEGACY_BODY_UPGRADE>:<body count>"). Takes and clears
-- the queue, so a second call is a no-op; an unchanged marker (same version, same number of bodies) means the archive
-- is settled and nothing is walked. The marker is written after the walk, so a walk that errors part way is repeated
-- at the next login.
local function upgradeSavedBodies()
    local passes = pendingPasses
    pendingPasses = {}

    if #passes == 0 then
        return
    end

    local count = 0

    eachSavedBody(function()
        count = count + 1
    end)

    local mark = LEGACY_BODY_UPGRADE .. ":" .. count

    if addon.db.global.legacyBodyUpgrade == mark then
        return
    end

    eachSavedBody(function(body)
        upgradeBody(body, passes)
    end)

    addon.db.global.legacyBodyUpgrade = mark
end

-- Renames the old texture list to the effect list.
--
-- global.textures becomes global.effects (each entry typed "texture") and the profile's selected overlay becomes its
-- selected effect. Does nothing once the old fields are gone.
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

-- Moves a TBC-layout rotation set from index 0 to index 1.
--
-- Pre-scoped storage only: on Classic clients at expansion level 2 (Wrath) or later, a profile whose single rotation
-- set sits at index 0 (the TBC layout) is moved to index 1. Skipped on Retail and under the scoped store, where
-- rotation ownership is handled by Core/rotation_migration.lua.
local function upgradeGlobalRotationstoPlayer()
    if addon.InitializeScopedRotationStorage or addon.db.profile.rotationStore ~= nil then
        return
    end

    if (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE) then
        -- Upgrade from TBC -> Wrath
        if
            (LE_EXPANSION_LEVEL_CURRENT >= 2)
            and addon.db.profile.rotations ~= nil
            and addon.db.profile.rotations[0] ~= nil
        then
            local rot = addon.db.profile.rotations[0]
            addon.db.profile.rotations = {}
            addon.db.profile.rotations[1] = rot
        end
    end
end

-- Queues the pass that wraps a bare item id or name in a list, the shape item sets introduced.
--
-- Applies to item steps and the item conditions. A string that already looks like an item set UUID is left alone.
local function upgradeItemsToItemSets()
    updateRotationData(function(rot)
        if
            rot.type == "item"
            and (type(rot.action) == "number"
                or (type(rot.action) == "string"
                    and not string.match(
                        rot.action,
                        "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"
                    )))
        then
            rot.action = { rot.action }
        end
    end, function(cond)
        if
            cond.type == "EQUIPPED"
            or cond.type == "CARRYING"
            or cond.type == "ITEM"
            or cond.type == "ITEM_COOLDOWN"
            or cond.type == "ITEM_RANGE"
        then
            if
                type(cond.item) == "number"
                or (type(cond.item) == "string"
                    and not string.match(
                        cond.item,
                        "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"
                    ))
            then
                cond.item = { cond.item }
            end
        end
    end)
end

-- Asks the platform for the display info (name, icon) of every item the active rotations and the item sets mention.
--
-- This starts the client loading item data the editors will want. Changes no saved data. The rotation pass is
-- activeOnly: archived bodies are not worth prefetching.
local function cacheItems()
    updateRotationData(function(rot)
        if rot.type == "item" and rot.action ~= nil and type(rot.action) == "table" then
            for _, item in pairs(rot.action) do
                addon.Platform:GetItemDisplayInfo(item)
            end
        end
    end, function(cond)
        if
            cond.type == "EQUIPPED"
            or cond.type == "CARRYING"
            or cond.type == "ITEM"
            or cond.type == "ITEM_COOLDOWN"
            or cond.type == "ITEM_RANGE"
        then
            if cond.item ~= nil and type(cond.item) == "table" then
                for _, item in pairs(cond.item) do
                    addon.Platform:GetItemDisplayInfo(item)
                end
            end
        end
    end, { activeOnly = true })

    if addon.db.global.itemsets then
        for _, itemset in pairs(addon.db.global.itemsets) do
            if itemset.items ~= nil then
                for _, item in pairs(itemset.items) do
                    addon.Platform:GetItemDisplayInfo(item)
                end
            end
        end
    end

    if addon.db.profile.itemsets then
        for _, itemset in pairs(addon.db.profile.itemsets) do
            if itemset.items ~= nil then
                for _, item in pairs(itemset.items) do
                    addon.Platform:GetItemDisplayInfo(item)
                end
            end
        end
    end
end

-- Gives every saved announcement that predates announcement ids a new UUID.
local function upgradeAddIDToAnnounce()
    for _, announce in pairs(addon.db.profile.announces) do
        if announce.id == nil then
            announce.id = addon:uuid()
        end
    end
end

-- Folds the retired debug and verbose booleans into profile.loglevel and clears them.
--
-- Debug alone is 3, debug with verbose is 4. A profile that never set debug keeps the default level.
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

-- Drops profile.transfer_format from every saved profile.
--
-- The rotation transfer window's Format choice (Rotation Master or WowSims, written by the 2.0 betas) was retired
-- together with the WowSims converter, nothing reads the value any more, and the validator would report the key in
-- each profile that still carries it.
local function dropRetiredTransferFormat()
    for _, profile in pairs(addon.db.sv and addon.db.sv.profiles or {}) do
        if type(profile) == 'table' then
            profile.transfer_format = nil
        end
    end

    addon.db.profile.transfer_format = nil
end

-- Converts effects from a name-ordered list to UUID keys.
--
-- Reuses the default effect's UUID when the names match, maps the profile's selected effect and each cooldown step's
-- effect from a name to its UUID, and, for a pre-version-1 account, offers to reset the effect list because the
-- defaults changed. Must run after upgradeTexturesToEffects.
local function upgradeEffectsToGUID()
    local global = addon.db.global
    local name2idx = {}

    if #global.effects > 0 then
        local new_effects = {}

        for _, effect in ipairs(global.effects) do
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

    for k, v in pairs(global.effects) do
        if v.name and #v.name > 0 then
            name2idx[v.name] = k
        end
    end

    if global.effects[addon.db.profile.effect] == nil then
        addon.db.profile.effect = name2idx[addon.db.profile.effect]
    end

    updateRotationData(function(rot, is_cooldown)
        if is_cooldown and rot.effect ~= nil and rot.effect ~= NONE and global.effects[rot.effect] == nil then
            -- An archived body keeps an effect it cannot resolve (it is
            -- evidence, and the editor reports it); only a name that maps
            -- to a known effect is rewritten.
            if name2idx[rot.effect] ~= nil or not addon.InitializeScopedRotationStorage then
                rot.effect = name2idx[rot.effect]
            end
        end
    end)

    if addon.db.global.version == nil or addon.db.global.version < 1 then
        StaticPopupDialogs["ROTATIONMASTER_RESET_EFFECTS"] = {
            text = addon.pretty_name,
            subText = L["Default effects have changed since the previous release, do you want to reset the effect list?"],
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                addon.db.global.effects = copyTree(default_effects)

                if invalidateDependencies then
                    invalidateDependencies(addon, 'effect', nil)
                end
            end,
            showAlert = 1,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }

        StaticPopup_Show("ROTATIONMASTER_RESET_EFFECTS")
    end
end

-- Queues the pass that turns the retired pet step type into "any" and the PETSPELL_* conditions into their ANYSPELL_*
-- equivalents.
--
-- Runs for profiles saved before version 1, and always under the scoped store (for the archive).
local function upgradePetSpellToAnySpell()
    -- The profile version is no evidence for an archive: the archive step
    -- sets it before this runs. Archived bodies are always converted; the
    -- conversion changes nothing that is already current.
    if addon.InitializeScopedRotationStorage or addon.db.profile.version == nil or addon.db.profile.version < 1 then
        updateRotationData(function(rot)
            if rot.type ~= nil and rot.type == (BOOKTYPE_PET or "pet") then
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

-- Queues the pass that replaces rune names in RUNE and RUNE_COOLDOWN conditions with the numeric rune types.
--
-- Blood 1, Frost 2, Unholy 3, Death 4.
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

-- Wraps each character's saved binding entry that is still a single number in a one-element list.
--
-- Entries that are already lists are untouched.
local function upgradeBindingSlots()
    -- Upgrade the exact store AceDB opened; folder casing is not persistence identity.
    local DB = addon.db.sv

    if DB.char then
        for _, char in pairs(DB.char) do
            if char.bindings then
                for id, val in pairs(char.bindings) do
                    if type(val) == "number" then
                        char.bindings[id] = { val }
                    end
                end
            end
        end
    end
end

-- Returns the stock item list for a default item set id.
-- @param id string  The item set id (UUID).
-- @return table|nil  The stock item list; nil when the id is not one of the default sets.
--
-- The item settings page uses it to enable and perform Reset on a set.
function addon:getDefaultItemset(id)
    if default_itemsets[id] ~= nil then
        return default_itemsets[id].items
    end
end

-- Moves item sets and announcements out of the per-character store into the profile.
--
-- Under the scoped store it only copies into an empty profile field and otherwise keeps the character data and warns.
-- Before the scoped store, a pre-version-2 profile also gets its rotations moved, and a character still on the Default
-- profile is switched to a profile named for its class (or, when that profile already holds data and the character has
-- its own, one named for the character and realm, seeded with a copy of Default). Runs first among the upgrades so the
-- later passes see the final profile.
local function moveProfileItems()
    if addon.InitializeScopedRotationStorage or addon.db.profile.rotationStore ~= nil then
        -- Rotation ownership migration never chooses a different profile or
        -- consumes char archives. Keep the unrelated old settings migration
        -- narrow: only an empty active-profile destination may receive data.
        for _, kind in ipairs({ 'itemsets', 'announces' }) do
            local source = addon.db.char[kind]

            if source ~= nil and (type(source) ~= 'table' or getmetatable(source) ~= nil or next(source) ~= nil) then
                local destination = addon.db.profile[kind]
                local copied = addon.RotationData.CopyData(source)

                if
                    type(copied) == 'table'
                    and (destination == nil or type(destination) == 'table' and next(destination) == nil)
                then
                    addon.db.profile[kind] = copied
                    addon.db.char[kind] = nil
                elseif addon.warn then
                    addon:warn(
                        L['Legacy character %s data conflicts with the active profile; character data preserved.'],
                        kind
                    )
                end
            end
        end

        return
    end

    if not addon.db.profile.version or addon.db.profile.version < 2 then
        local rotations = addon.db.char.rotations
        addon.db.char.rotations = nil
        local itemsets = addon.db.char.itemsets
        addon.db.char.itemsets = nil
        local announces = addon.db.char.announces
        addon.db.char.announces = nil

        local notempty = ((rotations and next(rotations) ~= nil)
            or (itemsets and next(itemsets) ~= nil)
            or (announces and next(announces) ~= nil))

        if addon.db:GetCurrentProfile() == DEFAULT then
            addon.db:SetProfile(classKey)

            local modified = ((addon.db.profile.rotations and next(addon.db.profile.rotations) ~= nil)
                or (addon.db.profile.itemsets and next(addon.db.profile.itemsets) ~= nil)
                or (addon.db.profile.announces and next(addon.db.profile.announces) ~= nil))

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

-- ============================================================================
-- Defaults and seeding
-- ============================================================================

-- Adds this file's stock data and schema versions to the AceDB defaults table main.lua builds.
-- @param defaults table  The AceDB defaults table, with char, global and profile sections.
--
-- Called before AceDB opens the saved variables. Each stock list is deep-copied so the defaults table owns its tables
-- and the locals above stay pristine.
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

-- Appends the talent-tree conditions to the switch list and the Character group, and SPELL_AUTOREPEAT to the Spells
-- group.
-- @param _ string  The AceDB callback event name; unused.
-- @param db table  The AceDB object.
--
-- Registered in addon:init as the OnNewProfile and OnProfileReset handler. Indexed AceDB defaults are kept stable:
-- extending them recursively fills numeric holes in existing customized or reordered lists, so new predicates are
-- seeded only when a profile is created or explicitly reset; copying a profile keeps its lists.
function addon:InitializeTalentTreeConditions(_, db)
    local profile = db.profile

    -- Appends the talent-tree tags missing from a list.
    -- @param list table  The tag list.
    local function append(list)
        for _, tag in ipairs({ 'TALENT_TREE_POINTS', 'PRIMARY_TALENT_TREE' }) do
            if not addon.Functions.values.isin(list, tag) then
                list[#list + 1] = tag
            end
        end
    end

    append(profile.switch_conditions)

    for _, category in ipairs(profile.condition_groups) do
        if category.id == 'b8136123-2bda-4230-a77a-89ea2aed3a1a' then
            append(category.conditions)
        elseif
            category.id == '8034819e-26f5-4f4e-9153-d8cab5e65f31'
            and not addon.Functions.values.isin(category.conditions, 'SPELL_AUTOREPEAT')
        then
            category.conditions[#category.conditions + 1] = 'SPELL_AUTOREPEAT'
        end
    end
end

-- Optional picker preferences have no AceDB defaults: logout must preserve an
-- explicit empty list. Only absent fields receive this cold, bounded seed.
-- Key object for the AceDB callbacks below (AceDB callbacks are registered per owner); its .db field records which
-- database object they were registered on, so a repeated install does not stack handlers.
local announcementPreferenceOwner = {}

-- Tags offered in the announcement condition picker (profile.announcement_conditions) when a profile has no list yet.
local defaultAnnouncementConditions = {
    'AND', 'OR', 'NOT', 'COMBAT', 'GROUP', 'ENEMY', 'DEAD', 'FRIENDLY', 'LEVEL', 'SELF_LEVEL', 'PVP', 'ZONEPVP', 'ZONE',
    'INSTANCE', 'OUTDOORS', 'STEALTHED', 'FORM', 'CLASS', 'CLASS_GROUP', 'CREATURE', 'CLASSIFICATION', 'PET',
    'PET_NAME', 'ROLE'
}

-- Gives a profile its own copy of the default announcement conditions.
-- @param profile any  The profile; non-table profiles are ignored.
--
-- Only when the field is absent (rawget, so a saved empty list is respected).
local function seedAnnouncementPreferences(profile)
    if type(profile) == 'table' and rawget(profile, 'announcement_conditions') == nil then
        profile.announcement_conditions = deepcopy(defaultAnnouncementConditions)
    end
end

-- Seeds announcement_conditions into every existing profile and into each profile created, changed, copied or reset
-- later.
--
-- The callbacks are registered once per database object and only act while that database is still addon.db. Called
-- from addon:init once the database exists. Optional picker preferences have no AceDB defaults: logout must preserve
-- an explicit empty list, so only absent fields receive this cold, bounded seed.
function addon:InstallAnnouncementConditionPreferences()
    local db = self.db

    if not db then
        return
    end

    if announcementPreferenceOwner.db ~= db then
        announcementPreferenceOwner.db = db

        -- Seeds a profile after the database announced a change.
        -- @param _ string  The AceDB callback event name; unused.
        -- @param currentDB table  The AceDB object.
        local function changed(_, currentDB)
            if currentDB == addon.db and currentDB == announcementPreferenceOwner.db then
                seedAnnouncementPreferences(currentDB.profile)
            end
        end

        for _, event in ipairs({ 'OnNewProfile', 'OnProfileChanged', 'OnProfileCopied', 'OnProfileReset' }) do
            db.RegisterCallback(announcementPreferenceOwner, event, changed)
        end
    end

    for _, profile in pairs(db.sv and db.sv.profiles or {}) do
        seedAnnouncementPreferences(profile)
    end

    seedAnnouncementPreferences(db.profile)
end

-- ============================================================================
-- Startup
-- ============================================================================

-- Runs the startup upgrades of the saved variables.
--
-- Called once by main.lua right after AceDB opens the saved variables and before validate runs. Installs the seeders
-- for the condition lists, runs every saved-data upgrade in dependency order, stamps the schema versions and tells the
-- dependency tracker that everything may have changed. The order of the upgrade calls below matters: queued passes
-- only run in upgradeSavedBodies, and upgradeEffectsToGUID needs the effects upgradeTexturesToEffects produced.
function addon:init()
    -- Before anything else touches db.profile: AceDB creates a new character's profile (and fires OnNewProfile) the first
    -- time it is read, and the seeders below read it, so a later registration never saw the first profile of a new
    -- character and its pickers lacked the tree conditions and auto-repeat.
    self.db.RegisterCallback(self, 'OnNewProfile', 'InitializeTalentTreeConditions')
    self.db.RegisterCallback(self, 'OnProfileReset', 'InitializeTalentTreeConditions')
    self:InstallUnitStateConditions(self.db)

    if self.InstallBossModConditions then
        self:InstallBossModConditions(self.db)
    end
    if self.InstallLoadoutConditions then
        self:InstallLoadoutConditions(self.db)
    end
    if self.InstallWorldConditions then
        self:InstallWorldConditions(self.db)
    end
    if self.InstallRaidMarkConditions then
        self:InstallRaidMarkConditions(self.db)
    end
    if self.InstallCastProgressConditions then
        self:InstallCastProgressConditions(self.db)
    end

    self:InstallAnnouncementConditionPreferences()
    moveProfileItems()

    -- An item set the player has not edited follows the shipped list, so a new release's item ids reach existing users.
    for k, v in pairs(default_itemsets) do
        if addon.db.global.itemsets[k] ~= nil and not addon.db.global.itemsets[k].modified then
            addon.db.global.itemsets[k].items = deepcopy(v.items)
        end
    end

    upgradeTexturesToEffects()
    -- The language picker was retired: Rotation Master follows the game's
    -- language. Drop a choice it saved, which the validator would report.
    addon.db.global.language = nil
    dropRetiredTransferFormat()
    upgradeGlobalRotationstoPlayer()
    upgradeItemsToItemSets()
    cacheItems()
    upgradeAddIDToAnnounce()
    upgradeLogLevel()
    upgradeEffectsToGUID()
    upgradePetSpellToAnySpell()
    upgradeRuneTypes()
    -- Every updateRotationData pass above has queued itself by now; this is the one walk that applies them to the
    -- archive.
    upgradeSavedBodies()
    upgradeBindingSlots()

    addon.db.char.version = CHAR_VERSION

    -- Stamp the profile only after the upgrades ran: 3 marks a profile that has the scoped rotation store,
    -- PROFILE_VERSION the last pre-scoped layout. With the scoped module loaded but no store yet, the version is left
    -- for its migration.
    if addon.db.profile.rotationStore ~= nil then
        addon.db.profile.version = 3
    elseif not addon.InitializeScopedRotationStorage then
        addon.db.profile.version = PROFILE_VERSION
    end

    addon.db.global.version = GLOBAL_VERSION

    if invalidateDependencies then
        invalidateDependencies(addon, 'all', nil)
    end
end
