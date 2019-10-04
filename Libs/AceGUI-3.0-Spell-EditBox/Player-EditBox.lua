local AceGUI = LibStub("AceGUI-3.0")
do
	local Type = "Player_EditBox"
	local Version = 1
	local playerSpells = {}
	local frame
	
	local function spellFilter(self, spellID)
		return playerSpells[spellID]
	end
	
	local function loadPlayerSpells(self)
		table.wipe(playerSpells)

		for tab=1, GetNumSpellTabs() do
			local _, _, offset, numEntries = GetSpellTabInfo(tab)
            for i=1,numEntries do
                local _, spellID = GetSpellBookItemInfo(i+offset, BOOKTYPE_SPELL)
				if not IsPassiveSpell(i+offset, BOOKTYPE_SPELL) then
                    playerSpells[spellID] = true
                end
			end
		end
	end
	
	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("Predictor_Base")
		self.spellFilter = spellFilter

		if( not frame ) then
			frame = CreateFrame("Frame")
			frame:RegisterEvent("SPELLS_CHANGED")
			frame:SetScript("OnEvent", loadPlayerSpells)
			frame.tooltip = self.tooltip
			
			loadPlayerSpells(frame)
		end

		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
