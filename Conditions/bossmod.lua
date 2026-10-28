-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Built In conditions fed by the selected boss mod (DBM or BigWigs): BOSSMOD_ENCOUNTER (an encounter, optionally one
-- ID, is in progress), BOSSMOD_STAGE (compares the encounter stage) and BOSSMOD_TIMER (compares the seconds until the
-- boss mod expects an ability). They read addon:GetBossModEncounter and addon:GetBossModTimerRemaining from
-- Integrations/encounters.lua, an event-fed cache: the file never polls a boss mod and reads no game value itself. The
-- adapter exists only on Era, TBC and progression clients; on Retail and Forever, or with no enabled and loaded
-- provider, every condition is unavailable (nil, reason), also under NOT. The file also seeds these conditions into
-- older profiles. Loaded from RotationMaster.toc after Conditions/misc.lua. Callback bodies and the helpers they bind
-- are hashed by saved copies and bundles: never add or change text inside a function body, and leave the generated
-- block at the end alone.
local addon_name, addon = ...

-- Witness wrapper that lets the lean engine prove each registered definition is the packaged one (see
-- DeclareOwnedConditionRuntime at the end of the file); an identity function when Core/condition_runtime.lua is absent.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/bossmod.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Boss-mod observations come from Integrations/encounters.lua: an event-fed
-- cache of the selected boss mod's own callbacks. Reads never poll the boss
-- mod. Without an enabled, loaded provider every predicate is unavailable.
local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
    },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/bossmod.lua"] = {
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
}

-- ============================================================================
-- Validation and editor helpers
-- ============================================================================

-- True for a positive whole number below 2^31, the range of an encounter or spell ID.
local function validID(value)
    return type(value) == "number" and value > 0 and value < 2^31 and value % 1 == 0
end

-- True when value carries a known operator and a finite, non-negative number to compare against.
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
        and type(value.value) == "number" and value.value >= 0 and value.value < math.huge
end

-- Adds a full-width numeric ID edit box to parent, filled with `current`. On Enter it calls changed(id) with the typed
-- ID, or nil when the text is blank or not a valid ID, and rewrites the box to match. Returns the box.
local function idEditor(parent, label, current, changed)
    local edit = addon:CreateConditionEditBox()
    edit:SetFullWidth(true)
    edit:SetLabel(label)
    edit:SetText(current and tostring(current) or "")
    edit:SetCallback("OnEnterPressed", function(_, _, text)
        local id = tonumber(text)
        changed(validID(id) and id or nil)
        edit:SetText(validID(id) and tostring(id) or "")
    end)
    parent:AddChild(edit)
    return edit
end

-- Adds a full-width read-only line of text to parent.
local function note(parent, text)
    local label = addon:CreateConditionLabel()
    label:SetFullWidth(true)
    label:SetText(text)
    parent:AddChild(label)
end

-- Authoring aid: what the selected boss mod is reporting right now. Returns the editor line: the current encounter
-- (name, ID, stage), "no encounter in progress", or why the boss mod data is unavailable.
local function encounterNote()
    if type(addon.GetBossModEncounter) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
    local active, id, stage, detail = addon:GetBossModEncounter()
    if active == nil then return string.format(L["Boss mod data unavailable: %s"], tostring(detail or "unknown")) end
    if not active then return L["No boss-mod encounter is in progress."] end
    return string.format(L["Current encounter: %s (ID %s), stage %s"], detail or L["Unknown"], id and tostring(id) or L["none"], tostring(stage))
end

-- Authoring aid: the soonest running boss-mod timers (up to six) as an editor line. Falls back to the same
-- unavailable and "none running" lines as encounterNote when there are no timers to list.
local function timerNote()
    if type(addon.ListBossModTimers) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
    local rows = addon:ListBossModTimers(6)
    if #rows == 0 then
        -- The timer list alone does not prove the encounter reader exists.
        if type(addon.GetBossModEncounter) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
        local active, _, _, detail = addon:GetBossModEncounter()
        if active == nil then return string.format(L["Boss mod data unavailable: %s"], tostring(detail or "unknown")) end
        return L["No boss-mod timers are running."]
    end
    local parts = {}
    for _, row in ipairs(rows) do
        parts[#parts + 1] = string.format("%s (%d) %.0fs", addon:SpellLabel(row.spellId), row.spellId, row.remaining)
    end
    return L["Running timers:"] .. " " .. table.concat(parts, ", ")
end

-- ============================================================================
-- Boss mod conditions
-- ============================================================================

-- BOSSMOD_ENCOUNTER: true while the boss mod reports an encounter in progress; with an encounter ID stored, only that
-- encounter counts. False when none is in progress or a different ID is. Stores `encounter` (optional). Returns
-- `nil, reason` when the boss mod data is unavailable.
addon:RegisterCondition("BOSSMOD_ENCOUNTER", runtimeCondition('BOSSMOD_ENCOUNTER', {
    description = L["Boss Mod Encounter"],
    icon = addon.Artwork.condition["BOSSMOD_ENCOUNTER"],
    fields = { encounter = "number" },
    -- Valid with no ID (any encounter) or with a valid ID.
    valid = function(_, value)
        return value.encounter == nil or validID(value.encounter)
    end,
    -- Unavailable (default reason "bossmod-unavailable") when no loaded, enabled provider answers.
    evaluate = function(value)
        local active, id, _, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        if value.encounter == nil then return true end
        return id == value.encounter
    end,
    -- Readable summary; names the encounter ID when one is stored.
    print = function(_, value)
        if validID(value.encounter) then
            return string.format(L["your boss mod reports encounter %s {{!is|is not}} in progress"], tostring(value.encounter))
        end
        return L["your boss mod {{!reports|does not report}} an encounter in progress"]
    end,
    -- widget builds the encounter ID box and a line showing the current encounter; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec)) end
        idEditor(parent, L["Encounter ID (blank for any)"], value.encounter, function(id) value.encounter = id; update() end)
        note(parent, encounterNote())
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.BOSSMOD_ENCOUNTER"]))
    end,
}))

-- BOSSMOD_STAGE: compares the stage number the boss mod reports for the current encounter with a number. Stores
-- `operator` and `value`. False when no encounter is in progress; `nil, reason` when the boss mod data is unavailable.
addon:RegisterCondition("BOSSMOD_STAGE", runtimeCondition('BOSSMOD_STAGE', {
    description = L["Boss Mod Encounter Stage"],
    icon = addon.Artwork.condition["BOSSMOD_STAGE"],
    fields = { operator = "string", value = "number" },
    -- Valid with a known operator and a finite, non-negative number.
    valid = function(_, value)
        return validCompare(value)
    end,
    -- Unavailable (default reason "bossmod-unavailable") when no provider answers; no encounter is false.
    evaluate = function(value)
        local active, _, stage, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        return Functions.values.compare(value.operator, stage, value.value)
    end,
    -- Readable summary of the stage comparison.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the boss-mod encounter stage"], Functions.presentation.nullable(value.value))
    end,
    -- widget builds an operator-and-stage control and a line showing the current encounter; help draws the page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec)) end
        parent:AddChild(addon:Widget_OperatorWidget(value, L["Stage"], update))
        note(parent, encounterNote())
    end,
    help = function(frame)
        addon.layout_condition_operatorwidget_help(frame, L["Boss Mod Encounter Stage"], L["Stage"], L["Help.Conditions.BOSSMOD_STAGE"])
    end,
}))

-- BOSSMOD_TIMER: compares the seconds until the boss mod expects the given ability (a boss spell ID) with a number,
-- measured at this poll's time `evalStart`. A paused timer keeps its remaining time. Stores `spell`, `operator` and
-- `value`. False when the boss mod has no timer for the spell; `nil, reason` when the boss mod data is unavailable.
addon:RegisterCondition("BOSSMOD_TIMER", runtimeCondition('BOSSMOD_TIMER', {
    description = L["Boss Mod Timer"],
    icon = addon.Artwork.condition["BOSSMOD_TIMER"],
    fields = { spell = "number", operator = "string", value = "number" },
    -- Valid with a valid spell ID plus a known operator and a finite, non-negative number.
    valid = function(_, value)
        return validID(value.spell) and validCompare(value)
    end,
    -- Unavailable (default reason "bossmod-unavailable") when no provider answers; no timer for the spell is false.
    evaluate = function(value, _, evalStart)
        local remaining, reason = addon:GetBossModTimerRemaining(value.spell, evalStart)
        if remaining == nil then return nil, reason or "bossmod-unavailable" end
        if not remaining then return false end
        return Functions.values.compare(value.operator, remaining, value.value)
    end,
    -- Readable summary of the comparison, naming the spell.
    print = function(_, value)
        local spell = validID(value.spell) and addon:SpellLabel(value.spell) or L["<spell>"]
        return Functions.presentation.compareString(value.operator, string.format(L["the boss-mod timer for %s"], spell),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    -- widget builds the spell ID box with a spell preview, an operator-and-seconds control and a line listing the
    -- running timers; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local preview
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec)) end
        idEditor(parent, L["Boss ability spell ID"], value.spell, function(id)
            value.spell = id
            preview:SetUserData("spell", id);preview:SetText(addon:SpellLabel(id))
            update()
        end)
        preview = addon:CreateSpellLabel(parent, value.spell)
        parent:AddChild(addon:Widget_OperatorWidget(value, L["Seconds"], update))
        note(parent, timerNote())
    end,
    help = function(frame)
        frame:AddChild(helpers.CreateText(L["Help.Conditions.BOSSMOD_TIMER"]))
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Boss Mod Timer"], L["Seconds"],
            L["Seconds until the boss mod expects the ability. A paused timer keeps its remaining time."])
    end,
}))

-- ============================================================================
-- Seeding older profiles
-- ============================================================================

-- Cold, one-time seed for profiles created before these predicates existed:
-- add them to the Combat category and Switch picker once. Removing them later
-- stays saved; new and reset profiles get them from the packaged defaults.
local combatCategory = "b3d7df2c-f257-4a2d-961e-66e49336d109"

-- Adds the boss mod conditions to db.profile's Switch picker and Combat category once (the profile remembers it in
-- bossModConditionsSeeded). Tolerates a malformed profile; the first argument is unused.
function addon:InitializeBossModConditions(_, db)
    local profile = db and db.profile

    if type(profile) ~= "table" or profile.bossModConditionsSeeded then
        return
    end

    local function append(list, tags)
        if type(list) ~= "table" then
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

    append(profile.switch_conditions, { "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE" })

    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and category.id == combatCategory then
            append(category.conditions, { "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE", "BOSSMOD_TIMER" })
        end
    end

    profile.bossModConditionsSeeded = true
end

local seedOwner = {}

-- Seeds the profile now and again whenever AceDB creates, resets, switches to or copies a profile. Called from
-- init.lua once the database exists.
function addon:InstallBossModConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then
        return
    end

    for _, event in ipairs({ "OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied" }) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB)
            addon:InitializeBossModConditions(nil, currentDB)
        end)
    end

    self:InitializeBossModConditions(nil, db)
end

-- ============================================================================
-- Lean engine enrollment
-- ============================================================================

-- Records the shipped boss mod readers so the enrollment below can prove nothing replaced them.
if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('GetBossModEncounter', addon.GetBossModEncounter)
    addon:DeclareConditionRuntimeHelper('GetBossModTimerRemaining', addon.GetBossModTimerRemaining)
end

-- Validation is pure; results change with provider callbacks, so no fact is declared.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/bossmod.lua', {
        BOSSMOD_ENCOUNTER = { pure = true, methods = { 'GetBossModEncounter' } },
        BOSSMOD_STAGE = { pure = true, methods = { 'GetBossModEncounter' } },
        BOSSMOD_TIMER = { pure = true, methods = { 'GetBossModTimerRemaining' } },
    })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="encounterNote" then return encounterNote end
        if name=="helpers" then return helpers end
        if name=="idEditor" then return idEditor end
        if name=="note" then return note end
        if name=="timerNote" then return timerNote end
        if name=="validCompare" then return validCompare end
        if name=="validID" then return validID end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/bossmod.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/bossmod.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
