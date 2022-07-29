local AceGUI = LibStub("AceGUI-3.0")

do
	local ItemData = LibStub("AceGUI-3.0-ItemLoader")

	local Type = "Glyph_EditBox"
	local Version = 1
	local unit_class = select(2, UnitClass("player"))
	local classGlyphs = {}
	local frame
	
	local function itemFilter(self, itemID)
		return classGlyphs[itemID]
	end

	local function loadGlyphs(self)
		local addon = _G.RotationMaster
		for _,itemid in pairs(addon.glyphs[unit_class]) do
			classGlyphs[itemid] = true
		end

		ItemData:StartLoading(addon.glyphs[unit_class])
	end

	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("ItemPredictor_Base")
		self.itemFilter = itemFilter

		if( not frame ) then
			frame = CreateFrame("Frame")
			frame.tooltip = self.tooltip

			loadGlyphs(frame)
		end

		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
