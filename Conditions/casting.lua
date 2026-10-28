-- Built In conditions about cast-time spells: CASTING, CASTING_SPELL, CASTING_REMAIN, CASTING_PROGRESS and
-- CAST_INTERRUPTABLE. All of them read one cached Platform:GetUnitCastObservation(unit, "cast") record per unit per
-- evaluation (Platform/casting.lua, which owns the restricted-client rule: a field the client hides as a secret value
-- comes back as nil plus a reason). A unit that is not casting is a readable false; an unreadable field makes the
-- condition unavailable (nil, reason), also under NOT. The channeling twins, and the one-time seeding of
-- CASTING_PROGRESS into older profiles, are in Conditions/channeling.lua.
-- Loaded with the other Conditions/ files at the end of RotationMaster.toc. Callback bodies and the helpers they bind
-- are hashed by saved copies and bundles: never add or change text inside a function body, and leave the generated
-- block at the end alone.
local addon_name, addon = ...

-- Witness wrapper that lets the lean engine prove the registered CASTING definition is the packaged one (see
-- DeclareOwnedConditionRuntime at the end of the file); an identity function when Core/condition_runtime.lua is absent.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/casting.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

-- Canonical callback leaves preserve the repaired observation contract and
-- the original filtered unit choices, wording and validation semantics.
local LiteralSummary = { phrase = addon.Functions.presentation.phrase }

local Functions = {
    values = { isin = addon.Functions.values.isin, compare = addon.Functions.values.compare },
    presentation = {
        nullable = addon.Functions.presentation.nullable,
        compareString = addon.Functions.presentation.compareString,
        playerize = addon.Functions.presentation.playerize,
    },
    cache = { getCached = addon.Functions.cache.getCached },
    collections = { deepcopy = addon.Functions.collections.deepcopy },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings["Conditions/casting.lua"] = {
    ["LiteralSummary.phrase"] = "builtin:Functions/presentation.lua:phrase",
    ["Functions.values.isin"] = "builtin:utils.lua:isin",
    ["Functions.values.compare"] = "builtin:utils.lua:compare",
    ["Functions.presentation.nullable"] = "builtin:utils.lua:nullable",
    ["Functions.presentation.compareString"] = "builtin:utils.lua:compareString",
    ["Functions.presentation.playerize"] = "builtin:utils.lua:playerize",
    ["Functions.cache.getCached"] = "builtin:utils.lua:getCached",
    ["Functions.collections.deepcopy"] = "builtin:Functions/collections.lua:deepcopy",
}

-- ============================================================================
-- Casting state and spell
-- ============================================================================

-- True while the unit is casting any spell. Stores unit. False when it is not casting; nil and a reason when the cast
-- query itself fails. The only condition here enrolled in the lean engine's owned runtime (end of file).
addon:RegisterCondition("CASTING", runtimeCondition('CASTING', {
    description = L["Casting"],
    icon = addon.Artwork.condition["CASTING"],
    fields = { unit = "string" },
    -- Checks that the saved fields of the CASTING condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Accepts any unit in the full unit list.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    -- Decides whether the unit is casting any spell.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Reads the cached cast record. Unavailable only when the query fails; not casting is a plain false.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        return true
    end,
    -- Builds the readable rule summary for the CASTING condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary; "you are" for the player, "<unit> is" otherwise.
    print = function(_, value)
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!are|are not}} currently casting"], L["%s {{!is|is not}} currently casting"]),
            Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]))
    end,
    -- Builds the editor controls for the CASTING condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds the editor controls (a unit picker); help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    -- Builds the help page for the CASTING condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
}))

-- True while the unit is casting the chosen spell. Stores unit, spell (a spell ID, or a name saved before IDs
-- existed) and ranked (ID picks only: match that exact rank instead of any rank). False when nothing is being cast.
-- Unavailable when the cast's name or spell ID cannot be read.
addon:RegisterCondition("CASTING_SPELL", {
    description = L["Specific Spell Casting"],
    icon = addon.Artwork.condition["CASTING_SPELL"],
    fields = { unit = "string", spell = { "string", "number" }, ranked = "boolean" },
    -- Checks that the saved fields of the CASTING_SPELL condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a known unit and a spell; a numeric spell must be a positive whole number.
    valid = function(_, value)
        -- A name (saved before spell IDs) or a spell ID picked in the editor.
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and value.spell ~= nil and
                (type(value.spell) ~= "number" or (value.spell > 0 and value.spell < math.huge and value.spell % 1 == 0)))
    end,
    -- Decides whether the unit is casting the chosen spell, matching a saved name by name and an ID by spell identity.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- A name pick compares the cast's name; an ID pick goes through Platform:MatchSpellIdentity. Both give nil and a
    -- reason when the observed name or ID is unreadable.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if type(value.spell) ~= "number" then
            if record.name==nil then return nil,record.nameReason or "cast-spell-unavailable" end
            return record.name==value.spell
        end
        -- By ID, any rank unless the exact rank was asked for (locale-safe).
        return addon.Platform:MatchSpellIdentity(record.spellID, record.spellReason, record.name, value.spell, value.ranked == true)
    end,
    -- Builds the readable rule summary for the CASTING_SPELL condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary with the spell link (and rank, when ranked) for an ID pick.
    print = function(_, value)
        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L["{unit} {{!are|are not}} currently casting {spell}"], L["{unit} {{!is|is not}} currently casting {spell}"]), {
            unit = Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
            spell = Functions.presentation.nullable(type(value.spell) == "number" and addon:CastSpellLabel(value) or value.spell, L["<spell>"]),
        })
    end,
    -- Builds the editor controls for the CASTING_SPELL condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds a unit picker, the spell box and, on clients with ranks, the exact-rank checkbox; help draws the
    -- help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local spell_group = addon:Widget_SpellNameWidget(spec, "Spell_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end, true)
        parent:AddChild(spell_group)
        local rank = addon:Widget_SpellRankWidget(value, function() top:SetStatusText(funcs:print(root, spec)) end)
        if rank then parent:AddChild(rank) end
    end,
    -- Builds the help page for the CASTING_SPELL condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_spellnamewidget_help(frame)
        addon.layout_condition_castspell_help(frame)
    end,
})

-- ============================================================================
-- Cast timing
-- ============================================================================

-- Compares the seconds left on the unit's cast with a number. Stores unit, operator and value (seconds, 0 or more).
-- False when the unit is not casting, whatever the operator; unavailable when the remaining time cannot be read.
addon:RegisterCondition("CASTING_REMAIN", {
    description = L["Cast Time Remaining"],
    icon = addon.Artwork.condition["CASTING_REMAIN"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the CASTING_REMAIN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Needs a known unit, a known operator and a non-negative number of seconds.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    -- Compares the seconds left on the unit's cast with the configured number; false when it is not casting.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Unavailable when the cast's remaining time is hidden or missing; not casting is false.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.remainingSeconds==nil then return nil,record.remainingReason end
        return Functions.values.compare(value.operator,record.remainingSeconds,value.value)
    end,
    -- Builds the readable rule summary for the CASTING_REMAIN condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary of the comparison against the unit's remaining cast time, in seconds.
    print = function(_, value)
        return Functions.presentation.compareString(value.operator,
            string.format(L["the time remaining on %s cast"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])),
            string.format(L["%s seconds"], Functions.presentation.nullable(value.value)))
    end,
    -- Builds the editor controls for the CASTING_REMAIN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds a unit picker and an operator-and-seconds control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the CASTING_REMAIN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Cast Time Remaining"], L["Seconds"],
            "The number of seconds before the current spell being cast by " .. color.BLIZ_YELLOW .. L["Unit"] ..
            color.RESET .. " is complete.  If the " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. " is " ..
            "not currently casting, this condition will not be successful (regardless of the " ..
            color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
    end,
})

-- Share of the cast done (0..1, shown as a percentage), from the same cached
-- observation as CASTING_REMAIN: haste-proof, so a tick threshold is N/K.
-- Stores unit, operator and value (a fraction from 0 to 1). False when the unit is not casting; unavailable when the
-- remaining time or the total duration cannot be read.
addon:RegisterCondition("CASTING_PROGRESS", {
    description = L["Cast Progress"],
    icon = addon.Artwork.condition["CASTING_PROGRESS"],
    fields = { unit = "string", operator = "string", value = "number" },
    -- Checks that the saved fields of the CASTING_PROGRESS condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Like CASTING_REMAIN, but the value must also be at most 1.
    valid = function(_, value)
        return (value.unit ~= nil and Functions.values.isin(addon.units, value.unit) and
                value.operator ~= nil and Functions.values.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0 and value.value <= 1)
    end,
    -- Compares the fraction of the unit's cast already done (0 to 1) with the configured number; false when it is not
    -- casting.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Progress is 1 - remaining / duration, floored at 0.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.remainingSeconds==nil then return nil,record.remainingReason end
        if record.durationSeconds==nil then return nil,record.durationReason end
        local done=1-record.remainingSeconds/record.durationSeconds
        if done<0 then done=0 end
        return Functions.values.compare(value.operator,done,value.value)
    end,
    -- Builds the readable rule summary for the CASTING_PROGRESS condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Shows the stored fraction as a percentage.
    print = function(_, value)
        local v = value.value
        if v ~= nil then v = v * 100 end
        return Functions.presentation.compareString(value.operator, string.format(L["%s cast progress"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(v) .. "%")
    end,
    -- Builds the editor controls for the CASTING_PROGRESS condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget builds a unit picker and an operator-and-percent control; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, addon.units,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)

        local operator_group = addon:Widget_OperatorPercentWidget(value, L["Progress"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    -- Builds the help page for the CASTING_PROGRESS condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorpercentwidget_help(frame, L["Cast Progress"], L["Progress"],
            (L["How much of the current cast of {unit} is done, from 0% when it starts to 100% when it completes. It follows haste and pushback, because it is measured against the cast's own start and end. If the unit is not casting, this condition is not successful, whatever the operator; if the cast's times cannot be read, it is unavailable, including under NOT."]:gsub("{unit}", color.BLIZ_YELLOW .. L["Unit"] .. color.RESET)))
    end,
})

-- ============================================================================
-- Interruptibility
-- ============================================================================

-- True when the unit's current cast can be interrupted. Stores unit. False when the unit is not casting; unavailable
-- when the client hides the interruptible flag.
addon:RegisterCondition("CAST_INTERRUPTABLE", {
    description = L["Cast Interruptible"],
    icon = addon.Artwork.condition["CAST_INTERRUPTABLE"],
    fields = { unit = "string" },
    -- Checks that the saved fields of the CAST_INTERRUPTABLE condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Accepts any unit in the full unit list.
    valid = function(_, value)
        return value.unit ~= nil and Functions.values.isin(addon.units, value.unit)
    end,
    -- Decides whether the unit's current cast can be interrupted; false when it is not casting.
    -- @param value table  The saved condition fields.
    -- @param cache table  The per-pass memo table shared by every condition in one evaluation; read it through
    --     Functions.cache.getCached.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Returns the observed interruptible flag itself, or nil and its reason when it is unreadable.
    evaluate = function(value, cache)
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitCastObservation,addon.Platform,value.unit,"cast")
        if not record then return nil,reason end
        if not record.active then return false end
        if record.interruptible==nil then return nil,record.interruptibleReason end
        return record.interruptible
    end,
    -- Builds the readable rule summary for the CAST_INTERRUPTABLE condition.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary naming the unit whose spell is tested.
    print = function(_, value)
        return string.format(L["%s spell {{!is|is not}} interruptible"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"]))
    end,
    -- Builds the editor controls for the CAST_INTERRUPTABLE condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The current specialization (addon.currentSpec).
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- widget offers every unit except player and pet; help draws the help page.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local unit = addon:Widget_UnitWidget(value, Functions.collections.deepcopy(addon.units, { "player", "pet" }),
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(unit)
    end,
    -- Builds the help page for the CAST_INTERRUPTABLE condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
    end,
})

-- ============================================================================
-- Lean engine enrollment
-- ============================================================================

-- Source-owned volatile observations; only configuration-only validators memoize.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/casting.lua', { CASTING = { pure = true } })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="color" then return color end
        if name=="helpers" then return helpers end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/casting.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/casting.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
