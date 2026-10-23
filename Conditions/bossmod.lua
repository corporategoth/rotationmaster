local addon_name, addon = ...
local runtimeCondition=addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness('Conditions/bossmod.lua') or function(_,definition)return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local helpers = addon.help_funcs

-- Boss-mod observations come from Integrations/encounters.lua: an event-fed
-- cache of the selected boss mod's own callbacks. Reads never poll the boss
-- mod. Without an enabled, loaded provider every predicate is unavailable.
local Functions={
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={nullable=addon.Functions.presentation.nullable,compareString=addon.Functions.presentation.compareString},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/bossmod.lua"]={
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
}

local function validID(value)
    return type(value) == "number" and value > 0 and value < 2^31 and value % 1 == 0
end
local function validCompare(value)
    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)
        and type(value.value) == "number" and value.value >= 0 and value.value < math.huge
end
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
local function note(parent, text)
    local label = addon:CreateConditionLabel()
    label:SetFullWidth(true)
    label:SetText(text)
    parent:AddChild(label)
end
-- Authoring aid: what the selected boss mod is reporting right now.
local function encounterNote()
    if type(addon.GetBossModEncounter) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
    local active, id, stage, detail = addon:GetBossModEncounter()
    if active == nil then return string.format(L["Boss mod data unavailable: %s"], tostring(detail or "unknown")) end
    if not active then return L["No boss-mod encounter is in progress."] end
    return string.format(L["Current encounter: %s (ID %s), stage %s"], detail or L["Unknown"], id and tostring(id) or L["none"], tostring(stage))
end
local function timerNote()
    if type(addon.ListBossModTimers) ~= "function" then return string.format(L["Boss mod data unavailable: %s"], "adapter-unavailable") end
    local rows = addon:ListBossModTimers(6)
    if #rows == 0 then
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

addon:RegisterCondition("BOSSMOD_ENCOUNTER", runtimeCondition('BOSSMOD_ENCOUNTER', {
    description = L["Boss Mod Encounter"],
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    fields = { encounter = "number" },
    valid = function(_, value)
        return value.encounter == nil or validID(value.encounter)
    end,
    evaluate = function(value)
        local active, id, _, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        if value.encounter == nil then return true end
        return id == value.encounter
    end,
    print = function(_, value)
        if validID(value.encounter) then
            return string.format(L["your boss mod reports encounter %s {{!is|is not}} in progress"], tostring(value.encounter))
        end
        return L["your boss mod {{!reports|does not report}} an encounter in progress"]
    end,
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

addon:RegisterCondition("BOSSMOD_STAGE", runtimeCondition('BOSSMOD_STAGE', {
    description = L["Boss Mod Encounter Stage"],
    icon = "Interface\\Icons\\INV_Scroll_03",
    fields = { operator = "string", value = "number" },
    valid = function(_, value)
        return validCompare(value)
    end,
    evaluate = function(value)
        local active, _, stage, reason = addon:GetBossModEncounter()
        if active == nil then return nil, reason or "bossmod-unavailable" end
        if not active then return false end
        return Functions.values.compare(value.operator, stage, value.value)
    end,
    print = function(_, value)
        return Functions.presentation.compareString(value.operator, L["the boss-mod encounter stage"], Functions.presentation.nullable(value.value))
    end,
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

addon:RegisterCondition("BOSSMOD_TIMER", runtimeCondition('BOSSMOD_TIMER', {
    description = L["Boss Mod Timer"],
    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    fields = { spell = "number", operator = "string", value = "number" },
    valid = function(_, value)
        return validID(value.spell) and validCompare(value)
    end,
    evaluate = function(value, _, evalStart)
        local remaining, reason = addon:GetBossModTimerRemaining(value.spell, evalStart)
        if remaining == nil then return nil, reason or "bossmod-unavailable" end
        if not remaining then return false end
        return Functions.values.compare(value.operator, remaining, value.value)
    end,
    print = function(_, value)
        local spell = validID(value.spell) and addon:SpellLabel(value.spell) or L["<spell>"]
        return Functions.presentation.compareString(value.operator, string.format(L["the boss-mod timer for %s"], spell),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
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

-- Cold, one-time seed for profiles created before these predicates existed:
-- add them to the Combat category and Switch picker once. Removing them later
-- stays saved; new and reset profiles get them from the packaged defaults.
local combatCategory="b3d7df2c-f257-4a2d-961e-66e49336d109"
function addon:InitializeBossModConditions(_, db)
    local profile = db and db.profile
    if type(profile) ~= "table" or profile.bossModConditionsSeeded then return end
    local function append(list, tags)
        if type(list) ~= "table" then return end
        for _, tag in ipairs(tags) do
            local found = false
            for _, existing in ipairs(list) do if existing == tag then found = true;break end end
            if not found then list[#list + 1] = tag end
        end
    end
    append(profile.switch_conditions, {"BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE"})
    for _, category in ipairs(type(profile.condition_groups) == "table" and profile.condition_groups or {}) do
        if type(category) == "table" and category.id == combatCategory then
            append(category.conditions, {"BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE", "BOSSMOD_TIMER"})
        end
    end
    profile.bossModConditionsSeeded = true
end
local seedOwner = {}
function addon:InstallBossModConditions(db)
    if type(db) ~= "table" or type(db.RegisterCallback) ~= "function" then return end
    for _, event in ipairs({"OnNewProfile", "OnProfileReset", "OnProfileChanged", "OnProfileCopied"}) do
        db.RegisterCallback(seedOwner, event, function(_, currentDB) addon:InitializeBossModConditions(nil, currentDB) end)
    end
    self:InitializeBossModConditions(nil, db)
end

if addon.DeclareConditionRuntimeHelper then
    addon:DeclareConditionRuntimeHelper('GetBossModEncounter',addon.GetBossModEncounter)
    addon:DeclareConditionRuntimeHelper('GetBossModTimerRemaining',addon.GetBossModTimerRemaining)
end
-- Validation is pure; results change with provider callbacks, so no fact is declared.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/bossmod.lua',{
        BOSSMOD_ENCOUNTER={pure=true,methods={'GetBossModEncounter'}},
        BOSSMOD_STAGE={pure=true,methods={'GetBossModEncounter'}},
        BOSSMOD_TIMER={pure=true,methods={'GetBossModTimerRemaining'}},
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
