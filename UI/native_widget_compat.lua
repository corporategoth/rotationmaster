local _,addon=...

-- Explicit AceGUI registrations share the original constructors with ordinary
-- RM widgets, without acquiring an RM lease before Ace owns the widget.
local AceGUI=LibStub('AceGUI-3.0')
local function constructor(module,name)
    local getter=assert(addon.builtinSourceModules and addon.builtinSourceModules[module],module..' must load before native widget compatibility')
    return assert(getter(name),'Missing native widget constructor: '..module..':'..name)
end
local icon=constructor('UI/condition_icon.lua','constructor')
local position=constructor('UI/condition_position.lua','constructor')
local label=constructor('UI/condition_display.lua','labelConstructor')
local button=constructor('UI/condition_display.lua','buttonConstructor')

AceGUI:RegisterWidgetType('RM-ConditionIcon',function() return icon(true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionPositionPad',function() return position(true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionLink',function() return label(true,true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionLabel',function() return label(true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionButton',function() return button(true) end,1)
