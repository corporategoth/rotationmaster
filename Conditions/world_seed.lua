local addon_name, addon = ...

-- Cold, one-time seed for profiles created before the world-state and
-- edition conditions existed (Conditions/player_state.lua, encounter_state.lua,
-- group_state.lua, hero_talent.lua, proc_glow.lua and edition_state.lua): each
-- joins its category, and the ones that choose a rotation join the Switch
-- picker, once per profile under worldConditionsSeeded. Removing one later
-- stays saved; new and reset profiles get them from the packaged defaults
-- (init.lua).
local worldSeeds = {
    ["fa10aaf8-bc71-480f-9062-c949fd7c74e9"] = { "PLAYER_STATE", "KEYSTONE_LEVEL" },
    ["b3d7df2c-f257-4a2d-961e-66e49336d109"] = { "ENCOUNTER" },
    ["b8136123-2bda-4230-a77a-89ea2aed3a1a"] = { "HERO_TALENT", "GROUP_COUNT", "PET_HAPPINESS", "STAGGER", "ECLIPSE" },
    ["8034819e-26f5-4f4e-9153-d8cab5e65f31"] = { "SPELL_GLOW" },
}

local switchSeeds = { "ENCOUNTER", "KEYSTONE_LEVEL", "HERO_TALENT", "GROUP_COUNT", "PLAYER_STATE" }

-- Conditions of an earlier draft that were folded into the ones above before
-- any release (MOUNTED and its four siblings into PLAYER_STATE, the group and
-- Eclipse pairs into GROUP_COUNT and ECLIPSE, and so on). A development
-- profile that was seeded with them loses the dead tags; a tag nobody saved is
-- untouched, and nothing else is ever removed.
local retiredTags = {
    MOUNTED = true,
    SWIMMING = true,
    FALLING = true,
    FLYING = true,
    RESTING = true,
    INSTANCE_DIFFICULTY = true,
    INSTANCE_ID = true,
    TRINKET_COOLDOWN = true,
    GROUP_SIZE = true,
    GROUP_ROLE_COUNT = true,
    GROUP_DEAD_COUNT = true,
    ECLIPSE_DIRECTION = true,
    ECLIPSE_ENERGY = true,
    RANGED_SWING_REMAIN = true,
}

local function dropRetired(list)
    if type(list) ~= "table" then return end

    for index = #list, 1, -1 do
        if retiredTags[list[index]] then table.remove(list, index) end
    end
end

function addon:InitializeWorldConditions(_, db)
    local profile = db and db.profile
    if type(profile) ~= "table" then return end
    dropRetired(profile.switch_conditions)

    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" then dropRetired(category.conditions) end
    end

    if profile.worldConditionsSeeded then return end

    local function append(list, tags)
        if type(list) ~= "table" then return end

        for _, tag in ipairs(tags) do
            local found = false

            for _, existing in ipairs(list) do
                if existing == tag then
                    found = true
                    break
                end
            end

            if not found then list[#list + 1] = tag end
        end
    end

    append(profile.switch_conditions, switchSeeds)

    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and worldSeeds[category.id] then
            append(category.conditions, worldSeeds[category.id])
        end
    end

    profile.worldConditionsSeeded = true
end

local seedOwner = {}

function addon:InstallWorldConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then return end

    for _, event in ipairs({ "OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied" }) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB)
            addon:InitializeWorldConditions(nil, currentDB)
        end)
    end

    self:InitializeWorldConditions(nil, db)
end
