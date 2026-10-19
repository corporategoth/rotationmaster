local _,addon=...

-- Named layout retained for historical custom Fields UI using Ace directly.
local AceGUI=addon:GetConditionWidgetCompatibilityLibrary()
if AceGUI.RegisterLayout then AceGUI:RegisterLayout('RM-SpellField',function(content,children) addon:LayoutWorkbenchSpellGroup(content,children) end) end
