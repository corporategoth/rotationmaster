local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

local Functions = {
    values = { isin = addon.Functions.values.isin },
    cache = { getCached = addon.Functions.cache.getCached },
}

addon.builtinCallbackBindings = addon.builtinCallbackBindings or {}

addon.builtinCallbackBindings['Conditions/unit_states.lua'] = {
    ['Functions.values.isin'] = 'builtin:utils.lua:isin',
    ['Functions.cache.getCached'] = 'builtin:utils.lua:getCached',
}

local function valid(_, value) return value.unit~=nil and Functions.values.isin(addon.units,value.unit) end

local function widget(parent, spec, value)
    local top=parent:GetUserData('top')
    parent:AddChild(addon:Widget_UnitWidget(value,addon.units,function()
        top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec))
    end))
end

addon:RegisterCondition('DEAD', {
    description = L['Is Dead or Ghost'],
    icon = addon.Artwork.condition['DEAD'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = valid,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'dead')
    end,
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are dead or a ghost|are alive}}'] or L['{unit} {{!is dead or a ghost|is alive}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Matches when the selected unit is dead or a ghost. A missing or unreadable unit is unavailable, including under NOT. In a Via Macro announcement, choose Announcement target to follow the supplied unit.']))
    end,
})

addon:RegisterCondition('FRIENDLY', {
    description = L['Is Friendly'],
    icon = addon.Artwork.condition['FRIENDLY'],
    fields = { unit = 'string' },
    requiredFields = { 'unit' },
    valid = valid,
    evaluate = function(value, cache)
        return Functions.cache.getCached(cache,addon.Platform.GetUnitStateObservation,addon.Platform,value.unit,'friendly')
    end,
    print = function(_, value)
        return addon.Functions.presentation.phrase(value.unit=='player' and L['{unit} {{!are friendly|are not friendly}}'] or L['{unit} {{!is friendly to you|is not friendly to you}}'],{unit=addon.units[value.unit] or L['<unit>']})
    end,
    widget = widget,
    help = function(frame)
        addon.layout_condition_unitwidget_help(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Matches when the game reports the selected unit as friendly to you. This does not imply party or raid membership. A missing or unreadable unit is unavailable.']))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/unit_states.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/unit_states.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
