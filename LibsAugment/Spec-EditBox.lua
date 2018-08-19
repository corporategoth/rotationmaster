local AceGUI = LibStub("AceGUI-3.0")
do
	local Type = "Spec_EditBox"
	local Version = 1
	local playerSpells = {}
	local frame
	
	local function spellFilter(self, spellID)
		local spec = self:GetUserData("spec")
		return playerSpells[spec][spellID]
	end
	
	local function loadPlayerSpells(self)
        -- Only wipe out the current spec, so you can still see everything for an off spec.
		-- It's a little nicity since WoW doesn't let you see talented spells when not on spec.
		local currentSpec = GetSpecializationInfo(GetSpecialization())
		if playerSpells[currentSpec] == nil then
			playerSpells[currentSpec] = {}
        else
			table.wipe(playerSpells[currentSpec])
        end

    	for tab=2, GetNumSpellTabs() do
			local _, _, offset, numEntries, _, offspecId = GetSpellTabInfo(tab)
			if offspecId == 0 then
				offspecId = currentSpec
			end
			if playerSpells[offspecId] == nil then
				playerSpells[offspecId] = {}
            end
            for i=1,numEntries do
                local _, spellID = GetSpellBookItemInfo(i+offset, BOOKTYPE_SPELL)
				if not IsPassiveSpell(i+offset, BOOKTYPE_SPELL) then
                    playerSpells[offspecId][spellID] = true
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
