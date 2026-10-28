-- Profile seeding for the condition categories and the Switch picker: adds conditions that arrived after a profile was
-- created (action context, set pieces, weapon imbue, Assisted Combat, rune engraving, DEAD and FRIENDLY) to their
-- categories exactly once, each under its own profile flag, so a later removal by the player stays saved. Owns only
-- those seeds and the profile callbacks that run them; it must stay idempotent. Loaded from RotationMaster.toc after
-- the Diagnostics files and before init.lua, whose addon:init() installs it through InstallUnitStateConditions.

local _, addon = ...

-- Cold, one-time profile migration: keep indexed AceDB defaults and custom
-- ordering stable. Once seeded, removing either Switch choice remains saved.
-- Action and build context conditions join their categories once per
-- profile, under their own flag, so existing profiles receive them too and a
-- later removal stays saved.
local contextSeeds = {
    { category = 'b8136123-2bda-4230-a77a-89ea2aed3a1a', tags = { 'ACTION_CONTEXT' } },
    { category = 'fca4ff75-4085-458a-b5bf-27a6b52f2092', tags = { 'SET_PIECES' } },
    { category = 'e618608c-92ec-4ae9-9dde-40a397d7beb9', tags = { 'WEAPON_IMBUE' } },
}

-- Appends each context seed's tags to its category once, guarded by profile.contextConditionsSeeded.
-- @param profile table  The AceDB profile table to seed.
local function seedContextConditions(profile)
    if profile.contextConditionsSeeded then
        return
    end

    -- Adds each tag to a condition list unless it is already there.
    -- @param list table|nil  The condition tag list to extend; anything else is ignored.
    -- @param tags string[]  The tags to add.
    local function append(list, tags)
        if type(list) ~= 'table' then
            return
        end

        for _, tag in ipairs(tags) do
            local found = false

            for _, existing in ipairs(list) do
                if existing == tag then
                    found = true
                    break
                end
            end

            if not found then
                list[#list + 1] = tag
            end
        end
    end

    for _, category in ipairs(type(profile.condition_groups) == 'table' and profile.condition_groups or {}) do
        for _, seed in ipairs(contextSeeds) do
            if category.id == seed.category then
                append(category.conditions, seed.tags)
            end
        end
    end

    profile.contextConditionsSeeded = true
end

-- Adds ASSISTED_SUGGESTION to the Spells category once, guarded by profile.assistedConditionsSeeded.
-- @param profile table  The AceDB profile table to seed.
--
-- Assisted Combat joins the Spells category once per profile, under its own flag, so profiles seeded with the context
-- conditions receive it too.
local function seedAssistedConditions(profile)
    if profile.assistedConditionsSeeded then
        return
    end

    for _, category in ipairs(type(profile.condition_groups) == 'table' and profile.condition_groups or {}) do
        if category.id == '8034819e-26f5-4f4e-9153-d8cab5e65f31' and type(category.conditions) == 'table' then
            local found = false

            for _, existing in ipairs(category.conditions) do
                if existing == 'ASSISTED_SUGGESTION' then
                    found = true
                    break
                end
            end

            if not found then
                category.conditions[#category.conditions + 1] = 'ASSISTED_SUGGESTION'
            end
        end
    end

    profile.assistedConditionsSeeded = true
end

-- Adds the Assisted Combat rotation-set and availability conditions to the Spells category once, guarded by
-- profile.assistedSignalConditionsSeeded.
-- @param profile table  The AceDB profile table to seed.
--
-- They follow under their own flag, since profiles already carry assistedConditionsSeeded.
local function seedAssistedSignalConditions(profile)
    if profile.assistedSignalConditionsSeeded then
        return
    end

    for _, category in ipairs(type(profile.condition_groups) == 'table' and profile.condition_groups or {}) do
        if category.id == '8034819e-26f5-4f4e-9153-d8cab5e65f31' and type(category.conditions) == 'table' then
            for _, tag in ipairs({ 'ASSISTED_ROTATION_SPELL', 'ASSISTED_AVAILABLE' }) do
                local found = false

                for _, existing in ipairs(category.conditions) do
                    if existing == tag then
                        found = true
                        break
                    end
                end

                if not found then
                    category.conditions[#category.conditions + 1] = tag
                end
            end
        end
    end

    profile.assistedSignalConditionsSeeded = true
end

-- Adds RUNE_ENGRAVED to the Switch picker and to its condition category once, guarded by
-- profile.engravingConditionsSeeded.
-- @param profile table  The AceDB profile table to seed.
--
-- Season of Discovery rune engraving joins the Character category and the Switch picker once per profile, under its own
-- flag.
local function seedEngravingConditions(profile)
    if profile.engravingConditionsSeeded then
        return
    end

    -- Adds RUNE_ENGRAVED to a condition list unless it is already there.
    -- @param list table|nil  The condition tag list to extend; anything else is ignored.
    local function append(list)
        if type(list) ~= 'table' then
            return
        end

        for _, existing in ipairs(list) do
            if existing == 'RUNE_ENGRAVED' then
                return
            end
        end

        list[#list + 1] = 'RUNE_ENGRAVED'
    end

    append(profile.switch_conditions)

    for _, category in ipairs(type(profile.condition_groups) == 'table' and profile.condition_groups or {}) do
        if category.id == 'b8136123-2bda-4230-a77a-89ea2aed3a1a' then
            append(category.conditions)
        end
    end

    profile.engravingConditionsSeeded = true
end

-- Runs every seeder for a profile; idempotent.
-- @param _ any  The callback event name; ignored.
-- @param db table  The AceDB database whose current profile is seeded.
--
-- The last block seeds DEAD and FRIENDLY into the Switch list and the Action context category under its own flag.
function addon:InitializeUnitStateConditions(_, db)
    local profile = db.profile
    seedContextConditions(profile)
    seedAssistedConditions(profile)
    seedAssistedSignalConditions(profile)
    seedEngravingConditions(profile)

    if profile.unitStateSwitchSeeded then
        return
    end

    -- Adds DEAD and FRIENDLY to a condition list unless they are already there.
    -- @param list table  The condition tag list to extend.
    local function append(list)
        for _, tag in ipairs({ 'DEAD', 'FRIENDLY' }) do
            local found = false

            for _, existing in ipairs(list) do
                if existing == tag then
                    found = true
                    break
                end
            end

            if not found then
                list[#list + 1] = tag
            end
        end
    end

    append(profile.switch_conditions)

    for _, category in ipairs(profile.condition_groups) do
        if category.id == 'b8136123-2bda-4230-a77a-89ea2aed3a1a' then
            append(category.conditions)
        end
    end

    profile.unitStateSwitchSeeded = true
end

-- CallbackHandler keeps one callback per owner/event. Use a private owner so
-- these seeds coexist with existing profile lifecycle handlers on the addon.
local callbackOwner = {}

-- Seeds the current profile now and again whenever AceDB creates, resets, switches or copies a profile.
-- @param db table  The AceDB database to seed and to register profile callbacks on.
--
-- CallbackHandler keeps one callback per owner/event, so a private owner is used and these seeds coexist with existing
-- profile lifecycle handlers on the addon.
function addon:InstallUnitStateConditions(db)
    for _, event in ipairs({ 'OnNewProfile', 'OnProfileReset', 'OnProfileChanged', 'OnProfileCopied' }) do
        db.RegisterCallback(callbackOwner, event, function(event, currentDB)
            addon:InitializeUnitStateConditions(event, currentDB)
        end)
    end

    self:InitializeUnitStateConditions(nil, db)
end
