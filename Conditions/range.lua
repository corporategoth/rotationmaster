-- Built In condition BEYOND_MELEE: whether a unit is farther away than melee range. The distance question itself is
-- answered by addon.Platform:IsBeyondMeleeRange (Platform/range.lua), which prefers the game's native Attack range
-- check and falls back to a LibRangeCheck-3.0 estimate; this file only validates the saved fields and checks that the
-- unit exists first.
-- Restricted clients (Retail, Forever): the unit existence read goes through platform:CanReadValue, and an unreadable
-- value makes the condition unavailable, never false. Loaded from RotationMaster.toc after Conditions/spatial.lua.
-- Callback bodies are recorded by tools/generate_builtin_sources.py and saved copies bind to their exact text.
local addon_name, addon = ...

-- Records the definition with the lean-engine witness when Core/condition_runtime.lua is loaded, so the declaration at
-- the end of the file can prove the definition was not replaced; otherwise it passes the definition through unchanged.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/range.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- BEYOND_MELEE: true when the unit is beyond melee range, false when it is within it or does not exist. Returns nil and
-- a reason ("missing-api", "api-error", "restricted-value", "unit-data-unavailable", "invalid-api-result", or the
-- reason from the range reader) when the answer cannot be decided, which includes an interval that straddles the melee
-- boundary. Stores one field, unit.
addon:RegisterCondition("BEYOND_MELEE", runtimeCondition('BEYOND_MELEE', {
    description = L["Beyond Melee Range"],
    icon = addon.Artwork.condition["BEYOND_MELEE"],
    fields = { unit = "string" },
    requiredFields = { "unit" },
    -- Configuration check: unit must be one of the selectable unit tokens.
    valid = function(_, value) return type(value.unit)=="string" and addon.units[value.unit]~=nil end,
    -- Runs each poll. Unavailable cases: UnitExists missing, throwing, secret or nil, and anything the range reader
    -- cannot decide.
    evaluate = function(value)
        if type(UnitExists)~="function" then return nil,"missing-api" end
        local ok,exists=pcall(UnitExists,value.unit)
        if not ok then return nil,"api-error" end
        if not addon.Platform:CanReadValue(exists) then return nil,"restricted-value" end
        if exists==nil then return nil,'unit-data-unavailable' end
        if exists==false then return false end
        if exists~=true and exists~=1 then return nil,"invalid-api-result" end
        return addon.Platform:IsBeyondMeleeRange(value.unit)
    end,
    -- Rule summary; "are" for the player, "is" for other units, with a placeholder while the unit is unset.
    print = function(
        _,
        value
    ) return string.format(value.unit=="player" and L["%s {{!are|are not}} beyond melee range"] or L["%s {{!is|is not}} beyond melee range"],addon.units[value.unit] or L["<unit>"]) end,
    -- Editor control: the unit selector, which refreshes the status line on change.
    widget = function(parent, spec, value)
        local top=parent:GetUserData("top")
        parent:AddChild(addon:Widget_UnitWidget(value,addon.units,function()
            top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"),spec))
        end))
    end,
    -- Help page: the unit selector, then how the range is measured and when it stays unavailable.
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Uses the native Attack range check when available. Otherwise it uses LibRangeCheck's public interval to distinguish close range from beyond five yards; that estimate does not prove exact melee geometry for every target. An interval spanning the boundary, missing data or restricted data stays unavailable, including under NOT."]))
    end,
}))

-- Source-owned configuration validators and optional notification facts.
-- `pure = true` says BEYOND_MELEE's valid callback depends only on the saved fields, so the lean engine may memoize it.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/range.lua', { BEYOND_MELEE = { pure = true } })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/range.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/range.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
