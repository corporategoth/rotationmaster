local major = "AceGUI-3.0-SpellLoader"
local minor = 1

local SpellLoader = LibStub:NewLibrary(major, minor)
if( not SpellLoader ) then return end

SpellLoader.predictors = SpellLoader.predictors or {}
SpellLoader.spellList = SpellLoader.spellList or {}
SpellLoader.spellListReverse = SpellLoader.spellListReverse or {}
SpellLoader.spellListReverseRank = SpellLoader.spellListReverseRank or {}
SpellLoader.spellListOrdered = SpellLoader.spellListOrdered or {}
SpellLoader.spellsLoaded = SpellLoader.spellsLoaded or 0
SpellLoader.needsUpdate = SpellLoader.needsUpdate or {}

local SPELLS_PER_RUN = 500
local TIMER_THROTTLE = 0.10
local spells, spellsReverse, spellsReverseRank, spellOrdered, predictors, needsUpdate =
    SpellLoader.spellList, SpellLoader.spellListReverse, SpellLoader.spellListReverseRank, SpellLoader.spellListOrdered, SpellLoader.predictors, SpellLoader.needsUpdate

local blacklist = {
	["Interface\\Icons\\Trade_Alchemy"] = true,
	["Interface\\Icons\\Trade_BlackSmithing"] = true,
	["Interface\\Icons\\Trade_BrewPoison"] = true,
	["Interface\\Icons\\Trade_Engineering"] = true,
	["Interface\\Icons\\Trade_Engraving"] = true,
	["Interface\\Icons\\Trade_Fishing"] = true,
	["Interface\\Icons\\Trade_Herbalism"] = true,
	["Interface\\Icons\\Trade_LeatherWorking"] = true,
	["Interface\\Icons\\Trade_Mining"] = true,
	["Interface\\Icons\\Trade_Tailoring"] = true,
	["Interface\\Icons\\Temp"] = true,
	["136243"] = true, -- The engineer icon
}

function SpellLoader:RegisterPredictor(frame)
	self.predictors[frame] = true
end

function SpellLoader:UnregisterPredictor(frame)
	self.predictors[frame] = nil
end

function SpellLoader:UpdateSpell(id, name, rank)
	if self.needsUpdate[id] then
		local lcname = string.lower(name)
		self.spellListReverse[lcname] = id
        if rank ~= nil then
            if self.spellListReverseRank[lcname] == nil then
				self.spellListReverseRank[lcname] = {}
			end
			self.spellListReverseRank[lcname][string.lower(rank)] = id
		end
		self.needUpdate[id] = nil
    end
end

function SpellLoader:SpellName(id)
    if spells[id] ~= nil then
		if spells[id].rank ~= nil then
			return spells[id].name .. "|cFF888888 (" .. spells[id].rank .. ")|r"
		else
			return spells[id].name
		end
    end
    return select(1, GetSpellInfo(id))
end

local function AddSpell(name, rank, icon, spellID, force)
	if not force and spells[spellID] ~= nil then
		return
	end

	spells[spellID] = {
		name = name,
		icon = icon
	}

	local lcname = string.lower(name)

	-- There are multiple spells with the same name, onle one is definitive for this class (which affects
	-- icons, tool tips, etc).  So look up the definitive version if there is one and set that.
	if spellsReverse[lcname] == nil then
		local name, _, icon, _, _, _, revid = GetSpellInfo(name)
		if revid then
			spellsReverse[lcname] = revid
			needsUpdate[spellID] = nil
			if revid ~= spellID and spells[revid] == nil then
				spells[revid] = {
					name = name,
					icon = icon
				}
			end
		else
			-- We could not look up the spell right now.  Maybe later we can!
			-- After we change specs or summon pets or something.  WoW is weird.
			needsUpdate[spellID] = true
			spellsReverse[lcname] = spellID
		end
	end

	if rank ~= nil and rank ~= "" then
		spells[spellID].rank = rank
		if spellsReverseRank[lcname] == nil then
			spellsReverseRank[lcname] = {}
		end
		if spellsReverseRank[lcname][rank] == nil then
			spellsReverseRank[lcname][rank] = spellID
		end
		-- Always use the top spell for the reverse spell ID
		if spells[spellsReverse[lcname]].rank ~= nil and spells[spellsReverse[lcname]].rank < rank then
            spellsReverse[lcname] = spellID
		end
	end
end

function SpellLoader:UpdateFromSpellBook()
	for i=2, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(i)
		for j=1,numSpells do
			local name, rank, spellID = GetSpellBookItemName(j+offset, BOOKTYPE_SPELL)
			local icon = GetSpellTexture(spellID)
			if (not blacklist[tostring(icon)] and not IsPassiveSpell(j+offset, BOOKTYPE_SPELL) ) then
				AddSpell(name, rank, icon, spellID, true)
			end
		end
	end
end

function SpellLoader:StartLoading()
	if( self.loader ) then return end

	SpellLoader:UpdateFromSpellBook()

	local timeElapsed, totalInvalid, currentIndex = 0, 0, 0
	self.loader = CreateFrame("Frame")
	self.loader:SetScript("OnUpdate", function(self, elapsed)
		timeElapsed = timeElapsed + elapsed
		if( timeElapsed < TIMER_THROTTLE ) then return end
		timeElapsed = timeElapsed - TIMER_THROTTLE
		
		-- 5,000 invalid spells in a row means it's a safe assumption that there are no more spells to query
		if( totalInvalid >= 5000 ) then
			self:Hide()
			return
		end

		-- Load as many spells in
		for spellID=currentIndex + 1, currentIndex + SPELLS_PER_RUN do
			local name, rank, icon = GetSpellInfo(spellID)
			
			-- Pretty much every profession spell uses Trade_* and 99% of the random spells use the Trade_Engineering icon
			-- we can safely blacklist any of these spells as they are not needed. Can get away with this because things like
			-- Alchemy use two icons, the Trade_* for the actual crafted spell and a different icon for the actual buff
			-- Passive spells have no use as well, since they are well passive and can't actually be used
			if( name and not blacklist[tostring(icon)] and rank ~= SPELL_PASSIVE ) then
				SpellLoader.spellsLoaded = SpellLoader.spellsLoaded + 1
                AddSpell(name, rank, icon, spellID)
				totalInvalid = 0
			else
				totalInvalid = totalInvalid + 1
			end
		end

    	table.wipe(spellOrdered)
		for k,v in pairs(spellsReverse) do
			table.insert(spellOrdered, k)
		end
		table.sort(spellOrdered)

		-- Every ~1 second it will update any visible predictors to make up for the fact that the data is delay loaded
		if( currentIndex % 5000 == 0 ) then
			for predictor in pairs(predictors) do
				if( predictor:IsVisible() ) then
					predictor:Query()
				end
			end
		end

		-- Increment and do it all over!
		currentIndex = currentIndex + SPELLS_PER_RUN
	end)
	self.loader:RegisterEvent("SPELLS_CHANGED")
	self.loader:SetScript("OnEvent", function(self, event, ...)
		SpellLoader:UpdateFromSpellBook()
	end)
end