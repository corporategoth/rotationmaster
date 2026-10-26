local addon_name, addon = ...

-- Cold, one-time seed for profiles created before the world-state and
-- edition conditions existed (Conditions/player_state.lua, encounter_state.lua,
-- group_state.lua, hero_talent.lua, proc_glow.lua, trinket.lua and
-- edition_state.lua): each joins its category, and the ones that choose a
-- rotation join the Switch picker, once per profile under worldConditionsSeeded.
-- Removing one later stays saved; new and reset profiles get them from the
-- packaged defaults (init.lua).
local worldSeeds = {
    ["fa10aaf8-bc71-480f-9062-c949fd7c74e9"] = { "MOUNTED", "SWIMMING", "FALLING", "FLYING", "RESTING",
        "INSTANCE_DIFFICULTY", "INSTANCE_ID", "KEYSTONE_LEVEL" },
    ["b3d7df2c-f257-4a2d-961e-66e49336d109"] = { "ENCOUNTER" },
    ["b8136123-2bda-4230-a77a-89ea2aed3a1a"] = { "HERO_TALENT", "GROUP_SIZE", "GROUP_ROLE_COUNT", "GROUP_DEAD_COUNT",
        "PET_HAPPINESS", "STAGGER", "ECLIPSE_DIRECTION", "ECLIPSE_ENERGY" },
    ["8034819e-26f5-4f4e-9153-d8cab5e65f31"] = { "SPELL_GLOW" },
    ["fca4ff75-4085-458a-b5bf-27a6b52f2092"] = { "TRINKET_COOLDOWN" },
    ["e618608c-92ec-4ae9-9dde-40a397d7beb9"] = { "RANGED_SWING_REMAIN" },
}
local switchSeeds = { "ENCOUNTER", "INSTANCE_DIFFICULTY", "INSTANCE_ID", "KEYSTONE_LEVEL", "HERO_TALENT",
    "GROUP_SIZE", "GROUP_ROLE_COUNT", "MOUNTED", "RESTING" }

function addon:InitializeWorldConditions(_, db)
    local profile = db and db.profile
    if type(profile) ~= "table" or profile.worldConditionsSeeded then return end
    local function append(list, tags)
        if type(list) ~= "table" then return end
        for _, tag in ipairs(tags) do
            local found = false
            for _, existing in ipairs(list) do if existing == tag then found = true; break end end
            if not found then list[#list + 1] = tag end
        end
    end
    append(profile.switch_conditions, switchSeeds)
    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and worldSeeds[category.id] then append(category.conditions, worldSeeds[category.id]) end
    end
    profile.worldConditionsSeeded = true
end

local seedOwner = {}
function addon:InstallWorldConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then return end
    for _, event in ipairs({"OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied"}) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB) addon:InitializeWorldConditions(nil, currentDB) end)
    end
    self:InitializeWorldConditions(nil, db)
end
