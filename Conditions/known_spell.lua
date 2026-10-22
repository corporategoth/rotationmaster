local addon_name, addon = ...
local runtimeCondition=addon.CreateConditionRuntimeWitness and addon:CreateConditionRuntimeWitness('Conditions/known_spell.lua') or function(_,definition)return definition end
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local function validID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

addon:RegisterCondition("SPELL_KNOWN", runtimeCondition('SPELL_KNOWN',{
    requiredFields = {"spell"},
    description = L["Spell Known"],
    icon = addon.Artwork.condition["SPELL_KNOWN"],
    fields = {spell="number", pet="boolean"},
    valid = function(_, value)
        return validID(value.spell) and (value.pet == nil or type(value.pet) == "boolean")
    end,
    evaluate = function(value)
        return addon.Platform:IsSpellKnown(value.spell, value.pet)
    end,
    print = function(_, value)
        local label = L["<spell>"]
        if validID(value.spell) then
            label = addon:SpellLabel(value.spell)
        end
        return string.format(value.pet and L["Your pet {{!knows|does not know}} %s"] or L["You {{!know|do not know}} %s"], label)
    end,
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
    help = function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Check whether you or your pet know this exact spell ID. An unlearned spell is a valid condition that returns false, so the same rotation can adapt as you learn abilities. This does not check cooldown, resources, range, or whether the spell can currently be cast. Missing or restricted learned-state data stays unavailable under NOT."]))
    end,
}))

-- Source-owned configuration validators and optional notification facts.
if addon.DeclareOwnedConditionRuntime then
    addon:DeclareOwnedConditionRuntime('Conditions/known_spell.lua',{ SPELL_KNOWN={pure=true} })
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
