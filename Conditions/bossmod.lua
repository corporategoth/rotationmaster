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
-- @param value any  The value to test.
-- @return boolean  True when value is a number in that range with no fractional part.
local function validID(value)
    return type(value) == "number" and value > 0 and value < 2^31 and value % 1 == 0
end

-- True when the saved fields carry a known operator and a finite, non-negative number to compare against.
-- @param value table  The saved condition fields; reads operator and value.
-- @return boolean  True when operator is one of addon.operators and value is a number in [0, math.huge).
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
        and type(value.value) == "number" and value.value >= 0 and value.value < math.huge
end

-- Adds a full-width numeric ID edit box to the parent, filled with the current ID.
-- @param parent table  The editor group the box is added to.
-- @param label string  The label shown on the box.
-- @param current number|nil  The ID to show; nil shows a blank box.
-- @param changed function  Called as changed(id) when Enter is pressed; id is the typed number, or nil when the text is
--     blank or not a valid ID. The box is then rewritten to match.
-- @return table  The edit box that was added.
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

-- Adds a full-width read-only line of text to the parent.
-- @param parent table  The editor group the line is added to.
-- @param text string  The text to show.
local function note(parent, text)
    local label = addon:CreateConditionLabel()
    label:SetFullWidth(true)
    label:SetText(text)
    parent:AddChild(label)
end

-- Builds the authoring-aid line that shows what the selected boss mod is reporting right now.
-- @return string  The current encounter (name, ID, stage), "no encounter in progress", or why the boss mod data is
--     unavailable.
local function encounterNote()
    if type(addon.GetBossModEncounter) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
    local active, id, stage, detail = addon:GetBossModEncounter()
    if active == nil then return string.format(L["Boss mod data unavailable: %s"], tostring(detail or "unknown")) end
    if not active then return L["No boss-mod encounter is in progress."] end
    return string.format(L["Current encounter: %s (ID %s), stage %s"], detail or L["Unknown"], id and tostring(id) or L["none"], tostring(stage))
end

-- Builds the authoring-aid line that lists the soonest running boss mod timers (up to six).
-- @return string  The running timers as "spell (id) seconds", or the same unavailable and "none running" lines as
--     encounterNote when there are no timers to list.
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
    -- Checks that the saved fields of the BOSSMOD_ENCOUNTER condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with no ID (any encounter) or with a valid ID.
    valid = function(_, value)
        return value.encounter == nil or validID(value.encounter)
    end,
    -- Decides whether the boss mod reports an encounter in progress (and, if an ID is stored, that it is that
    -- encounter).
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable (default reason "bossmod-unavailable") when no loaded, enabled provider answers.
    evaluate = function(value)
        local active, id, _, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        if value.encounter == nil then return true end
        return id == value.encounter
    end,
    -- Builds the readable rule summary for the BOSSMOD_ENCOUNTER condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary; names the encounter ID when one is stored.
    print = function(_, value)
        if validID(value.encounter) then
            return string.format(L["your boss mod reports encounter %s {{!is|is not}} in progress"], tostring(value.encounter))
        end
        return L["your boss mod {{!reports|does not report}} an encounter in progress"]
    end,
    -- Builds the editor controls for the BOSSMOD_ENCOUNTER condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the encounter ID box and a line showing the current encounter; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec)) end
        idEditor(parent, L["Encounter ID (blank for any)"], value.encounter, function(id) value.encounter = id; update() end)
        note(parent, encounterNote())
    end,
    -- Builds the help page for the BOSSMOD_ENCOUNTER condition.
    -- @param frame table  The help page container that text and example widgets are added to.
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
    -- Checks that the saved fields of the BOSSMOD_STAGE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a known operator and a finite, non-negative number.
    valid = function(_, value)
        return validCompare(value)
    end,
    -- Compares the encounter stage the boss mod reports with the configured number; false when no encounter is in
    -- progress.
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable (default reason "bossmod-unavailable") when no provider answers; no encounter is false.
    evaluate = function(value)
        local active, _, stage, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        return Functions.values.compare(value.operator, stage, value.value)
    end,
    -- Builds the readable rule summary for the BOSSMOD_STAGE condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the stage comparison.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the boss-mod encounter stage"], Functions.presentation.nullable(value.value))
    end,
    -- Builds the editor controls for the BOSSMOD_STAGE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds an operator-and-stage control and a line showing the current encounter; help draws the page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec)) end
        parent:AddChild(addon:Widget_OperatorWidget(value, L["Stage"], update))
        note(parent, encounterNote())
    end,
    -- Builds the help page for the BOSSMOD_STAGE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
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
    -- Checks that the saved fields of the BOSSMOD_TIMER condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Valid with a valid spell ID plus a known operator and a finite, non-negative number.
    valid = function(_, value)
        return validID(value.spell) and validCompare(value)
    end,
    -- Compares the seconds until the boss mod expects the chosen ability with the configured number.
    -- @param value table  The saved condition fields.
    -- @param _ any  Unused; the boss mod timer is read directly rather than through the per-pass cache.
    -- @param evalStart number  The GetTime() reading taken when this evaluation pass began; the timer's remaining time
    --     is measured against it.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable (default reason "bossmod-unavailable") when no provider answers; no timer for the spell is false.
    evaluate = function(value, _, evalStart)
        local remaining, reason = addon:GetBossModTimerRemaining(value.spell, evalStart)
        if remaining == nil then return nil, reason or "bossmod-unavailable" end
        if not remaining then return false end
        return Functions.values.compare(value.operator, remaining, value.value)
    end,
    -- Builds the readable rule summary for the BOSSMOD_TIMER condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the comparison, naming the spell.
    print = function(_, value)
        local spell = validID(value.spell) and addon:SpellLabel(value.spell) or L["<spell>"]
        return Functions.presentation.compareString(value.operator, string.format(L["the boss-mod timer for %s"], spell),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the BOSSMOD_TIMER condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
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
    -- Builds the help page for the BOSSMOD_TIMER condition.
    -- @param frame table  The help page container that text and example widgets are added to.
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

-- Adds the boss mod conditions to a profile's Switch picker and Combat category once.
-- @param _ any  Unused.
-- @param db table|nil  The AceDB database; a nil or malformed database (or profile) is tolerated and left alone.
--
-- The profile remembers that it has been seeded in bossModConditionsSeeded, so conditions the user later removes stay
-- removed.
function addon:InitializeBossModConditions(_, db)
    local profile = db and db.profile

    if type(profile) ~= "table" or profile.bossModConditionsSeeded then
        return
    end

    -- Appends each tag to the list unless it is already there.
    -- @param list table|nil  The array of condition tags to extend; anything but a table is ignored.
    -- @param tags string[]  The condition tags to add.
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

-- Seeds the profile now and again whenever AceDB creates, resets, switches to or copies a profile.
-- @param db table|nil  The AceDB database; anything without a RegisterCallback function is ignored.
--
-- Called from init.lua once the database exists.
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
