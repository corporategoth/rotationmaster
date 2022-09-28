local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
do
	local Type = "Spec_EditBox"
	local Version = 1
	local frame

	local function spellFilter(self, spellID)
		local spec = self:GetUserData("spec")
		return addon.isSpellOnSpec(spec, spellID)
	end
	
	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("Predictor_Base")
		self.spellFilter = spellFilter

		if( not frame ) then
			frame = CreateFrame("Frame")
			frame.tooltip = self.tooltip
		end

		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
