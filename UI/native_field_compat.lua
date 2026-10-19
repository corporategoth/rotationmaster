local _,addon=...

-- Historical Ace callers share the native field constructors, with ownership
-- assigned by Ace rather than an ordinary factory's already-active RM lease.
local AceGUI=addon:GetConditionWidgetCompatibilityLibrary()
local function constructor(module,name)
    local getter=assert(addon.builtinSourceModules and addon.builtinSourceModules[module],module..' must load before native field compatibility')
    return assert(getter(name),'Missing native field constructor: '..module..':'..name)
end
local selector=constructor('UI/selector.lua','selectorWidget')
local checkbox=constructor('UI/checkbox.lua','constructor')
local input=constructor('UI/condition_inputs.lua','constructor')

AceGUI:RegisterWidgetType('RM-Selector',function() return selector(true) end,1)
AceGUI:RegisterWidgetType('RM-CheckBox',function() return checkbox(true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionEditBox',function() return input(false,true) end,1)
AceGUI:RegisterWidgetType('RM-ConditionSlider',function() return input(true,true) end,1)
