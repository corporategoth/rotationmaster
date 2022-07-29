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

local profession_levels = {
	APPRENTICE,
	JOURNEYMAN,
	EXPERT,
	ARTISAN,
	MASTER,
	GRAND_MASTER,
	ILLUSTRIOUS,
	ZEN_MASTER,
	DRAENOR_MASTER,
	LEGION_MASTER,
}

local function spairs(t, order)
	-- collect the keys
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	-- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys
	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	-- return the iterator function
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

local function AddSpell(name, rank, icon, spellID, force)
	if not force and spells[spellID] ~= nil then
		return
	end

	local lcname = string.lower(name)

	spells[spellID] = {
		name = name,
		icon = icon
	}
	if rank ~= nil and rank ~= "" then
		spells[spellID].rank = rank

		if spellsReverseRank[lcname] == nil then
			spellsReverseRank[lcname] = {}
		end
        spellsReverseRank[lcname][rank] = spellID
	end

	if spellsReverse[lcname] == nil then
		local name, _, icon, _, _, _, revid = GetSpellInfo(name)
		if revid == spellID then
			spellsReverse[lcname] = spellID
		elseif revid ~= nil then
            local rank = GetSpellSubtext(revid)
			AddSpell(name, rank, icon, revid)
		else
			needsUpdate[spellID] = true
			spellsReverse[lcname] = spellID
		end
	end
end

function SpellLoader:RegisterPredictor(frame)
	self.predictors[frame] = true
end

function SpellLoader:UnregisterPredictor(frame)
	self.predictors[frame] = nil
end

function SpellLoader:UpdateSpell(id)
	if self.needsUpdate[id] then
        local name, _, icon = GetSpellInfo(id)
        if name then
            self.needsUpdate[id] = nil
            self.spellListReverse[string.lower(name)] = nil
            local rank = GetSpellSubtext(id)
            AddSpell(name, rank, icon, id, true)
        end
    end
end

function SpellLoader:GetAllSpellIds(spell)
	local lcname
	if type(spell) == "number" then
		if self.spellList[spell] == nil then
            return nil
		end

		lcname = string.lower(self.spellList[spell].name)
	else
		lcname = string.lower(spell)
    end

	if self.spellListReverseRank[lcname] ~= nil then
        local rv = {}
		for _,spellID in spairs(self.spellListReverseRank[lcname], function (t,a,b) return b < a end) do
			table.insert(rv, spellID)
        end
        return rv
	elseif self.spellListReverse[lcname] ~= nil then
		return { self.spellListReverse[lcname] }
    end

	return nil
end

function SpellLoader:GetSpellId(spell, rank)
    if type(spell) == "number" then
        return select(7, GetSpellInfo(spell))
    end

    local lcname = string.lower(spell)
    if rank ~= nil then
        if self.spellListReverseRank[lcname] ~= nil then
            return self.spellListReverseRank[lcname][rank]
        end
	elseif self.spellListReverse[lcname] ~= nil then
		return self.spellListReverse[lcname]
    else
        return select(7, GetSpellInfo(spell))
	end

	return nil
end

function SpellLoader:SpellName(id, norank)
    if spells[id] ~= nil then
		if not norank and spells[id].rank ~= nil then
			return spells[id].name .. "|cFF888888 (" .. spells[id].rank .. ")|r"
		else
			return spells[id].name
		end
    end
    return select(1, GetSpellInfo(id))
end

function SpellLoader:UpdateFromSpellBook(spec)
    local specSpells = {}
    specSpells[spec] = {}
	for i=1, GetNumSpellTabs() do
		local _, _, offset, numSpells, _, offspecId = GetSpellTabInfo(i)
        if offspecId == 0 then
            offspecId = spec
        elseif (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            specSpells[offspecId] = {}
        end

		for j=1,numSpells do
			local name, rank, spellID = GetSpellBookItemName(j+offset, BOOKTYPE_SPELL)
        	if (i == 1 and rank ~= nil and rank ~= "") then
				for _, prof in pairs(profession_levels) do
                    if rank == prof then
						spellID = nil
                        break
					end
				end
			end
			if spellID then
				local icon = GetSpellTexture(spellID)
				if (not blacklist[tostring(icon)] and not IsPassiveSpell(j+offset, BOOKTYPE_SPELL) ) then
					AddSpell(name, rank, icon, spellID, true)
					specSpells[offspecId][spellID] = false
                end
			end
		end
    end
    local petSpells, token = HasPetSpells()
    if petSpells ~= nil then
		for i=1, petSpells do
            local name, rank, spellID = GetSpellBookItemName(i, BOOKTYPE_PET)
            local icon = GetSpellTexture(spellID)
            if (not blacklist[tostring(icon)] and not IsPassiveSpell(i, BOOKTYPE_PET) ) then
                AddSpell(name, rank, icon, spellID, true)
                specSpells[token][spellID] = true
            end
        end
	end

    table.wipe(spellOrdered)
    for k,v in pairs(spellsReverse) do
        table.insert(spellOrdered, k)
    end
    table.sort(spellOrdered)

	return specSpells
end

function SpellLoader:StartLoading()
	if( self.loader ) then return end

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
			local name, _, icon = GetSpellInfo(spellID)

			if name then
                -- Pretty much every profession spell uses Trade_* and 99% of the random spells use the Trade_Engineering icon
                -- we can safely blacklist any of these spells as they are not needed. Can get away with this because things like
                -- Alchemy use two icons, the Trade_* for the actual crafted spell and a different icon for the actual buff
                -- Passive spells have no use as well, since they are well passive and can't actually be used
                local rank = GetSpellSubtext(spellID)
                if not blacklist[tostring(icon)] and rank ~= SPELL_PASSIVE then
                    SpellLoader.spellsLoaded = SpellLoader.spellsLoaded + 1
                    AddSpell(name, rank, icon, spellID)
                    totalInvalid = 0
				end
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
end