-- Built In condition SPELL_KNOWN: whether you (or your pet) have learned an exact spell ID. It reads the learned state
-- through addon.Platform:IsSpellKnown, which returns the answer or nil and a reason; this file never calls a game API
-- itself, so restricted-client handling stays in the Platform adapter. It stores `spell` (a spell ID) and `pet`
-- (boolean) in the condition value. Loaded from RotationMaster.toc after Conditions/assisted.lua and before
-- Conditions/petspell.lua. Every callback body and the validID helper are recorded Built In source that saved custom
-- copies bind to byte for byte, so never edit inside them; the generated block at the end is rewritten by
-- tools/generate_builtin_sources.py.
local addon_name, addon = ...

-- Registers each definition with the runtime witness (Core/condition_runtime.lua) when it exists, so the enrollment at
-- the bottom of the file can prove the definition was not replaced; otherwise it passes the definition through.
local runtimeCondition = addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness(
    'Conditions/known_spell.lua'
)
    or function(_, definition) return definition end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- True for a positive whole-number spell ID; the same test as addon.IsConditionSpellID in Conditions/common.lua.
-- @param value any  The value to test.
-- @return boolean  True when value is a number greater than 0, below math.huge, with no fractional part.
local function validID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

-- SPELL_KNOWN: true when the spell is in your spell book (the pet's, when `pet` is set), false when it is not. It
-- returns `nil, reason` when the Platform cannot answer (unreadable or restricted learned state, missing spell bank);
-- it does not look at cooldown, resources or range. Stores `spell` and `pet`.
addon:RegisterCondition("SPELL_KNOWN", runtimeCondition('SPELL_KNOWN', {
    -- A condition without a spell is incomplete, not merely false.
    requiredFields = { "spell" },
    description = L["Spell Known"],
    icon = addon.Artwork.condition["SPELL_KNOWN"],
    fields = { spell = "number", pet = "boolean" },
    -- Checks that the saved fields of the SPELL_KNOWN condition are complete and in range.
    -- @param _ any  Unused; the current specialization the engine passes.
    -- @param value table  The saved condition fields.
    -- @return boolean  True when the saved fields are complete and in range.
    --
    -- Accepts a positive integer spell ID and an absent or boolean `pet`.
    valid = function(_, value)
        return validID(value.spell) and (value.pet == nil or type(value.pet) == "boolean")
    end,
    -- Decides whether the spell is in your spell book (the pet's, when the pet flag is set).
    -- @param value table  The saved condition fields.
    -- @return boolean|nil  True when the condition holds, false when it does not; nil when it cannot be decided.
    -- @return string|nil  The reason code when the first value is nil; nil otherwise.
    --
    -- Passes the Platform answer through unchanged, so an unreadable state is `nil, reason` (unavailable), never false.
    evaluate = function(value)
        return addon.Platform:IsSpellKnown(value.spell, value.pet)
    end,
    -- Builds the readable rule summary for the SPELL_KNOWN condition.
    -- @param _ any  Unused; the specialization the summary is printed for.
    -- @param value table  The saved condition fields.
    -- @return string  The readable summary, with {{!a|b}} alternatives so the negated form can be rendered.
    --
    -- Readable summary; the spell shows as a placeholder until a valid ID is chosen.
    print = function(_, value)
        local label = L["<spell>"]
        if validID(value.spell) then
            label = addon:SpellLabel(value.spell)
        end
        return string.format(value.pet and L["Your pet {{!knows|does not know}} %s"] or L["You {{!know|do not know}} %s"], label)
    end,
    -- Builds the editor controls for the SPELL_KNOWN condition's fields.
    -- @param parent table  The editor group the controls are added to.
    -- @param spec any  The specialization the condition is being edited for.
    -- @param value table  The saved condition fields; the controls edit it in place.
    --
    -- Editor: a spell edit box that accepts an ID or a name, a label preview of the choice, and the pet checkbox.
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local function update()
            top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"), spec))
        end
        local spell = addon:CreateSpellEditBox("Spell_EditBox",value.spell)
        spell:SetLabel(L["Spell"])
        spell:SetUserData("spec",spec)
        spell:SetUserData("norank",false)
        spell:SetFullWidth(true)
        local displayed
        local function showSelection()
            local info=value.spell and addon.Platform:GetSpellInfo(value.spell)
            displayed=info and info.name or value.spell and tostring(value.spell) or ""
            if info and info.subtext and info.subtext~="" then displayed=displayed.." ("..info.subtext..")" end
            spell:SetText(displayed)
        end
        showSelection()
        spell:SetDisabled(value.disabled)
        local preview
        spell:SetCallback("OnEnterPressed", function(_, _, text)
            local id=text==displayed and value.spell or tonumber(text)
            local metadata=not validID(id) and addon.Platform:GetSpellInfo(text)
            id=id or metadata and metadata.spellID
            value.spell=validID(id) and id or nil
            showSelection()
            preview:SetUserData("spell",value.spell);preview:SetText(addon:SpellLabel(value.spell))
            update()
        end)
        parent:AddChild(spell)
        preview=addon:CreateSpellLabel(parent,value.spell)
        local pet = addon:CreateConditionCheckBox()
        pet:SetLabel(L["Pet spell"])
        pet:SetValue(value.pet == true)
        pet:SetDisabled(value.disabled)
        pet:SetCallback("OnValueChanged", function(_, _, checked)
            value.pet = checked == true
            update()
        end)
        parent:AddChild(pet)
    end,
    -- Builds the help page for the SPELL_KNOWN condition.
    -- @param frame table  The help page container that text and example widgets are added to.
    --
    -- Help page text.
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Check whether you or your pet know this exact spell ID. An unlearned spell is a valid condition that returns false, so the same rotation can adapt as you learn abilities. This does not check cooldown, resources, range, or whether the spell can currently be cast. Missing or restricted learned-state data stays unavailable under NOT."]))
    end,
}))

-- Source-owned configuration validators and optional notification facts.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/known_spell.lua', { SPELL_KNOWN = { pure = true } })
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="validID" then return validID end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/known_spell.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/known_spell.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
