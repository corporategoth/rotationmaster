local _,addon=...

-- Historical Ace groups share the original constructor and its library cell.
local AceGUI=addon:BindConditionGroupCompatibilityLibrary()
local getter=assert(addon.builtinSourceModules and addon.builtinSourceModules['UI/condition_layout.lua'],'Native group must load before compatibility')
local constructor=assert(getter('constructor'),'Missing original condition group constructor')
AceGUI:RegisterWidgetType('RM-ConditionGroup',function() return constructor(true) end,1)
