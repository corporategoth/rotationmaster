local major = "AceGUI-3.0-ItemLoader"
local minor = 1

local ItemLoader = LibStub:NewLibrary(major, minor)
if( not ItemLoader ) then return end

ItemLoader.predictors = ItemLoader.predictors or {}
ItemLoader.itemList = ItemLoader.itemList or {}
ItemLoader.itemListReverse = ItemLoader.itemListReverse or {}

local ITEMS_PER_RUN = 500
local TIMER_THROTTLE = 0.10
local MAX_ATTEMPTS = 5
local items, itemsReverse, predictors = ItemLoader.itemList, ItemLoader.itemListReverse, ItemLoader.predictors

function ItemLoader:RegisterPredictor(frame)
	self.predictors[frame] = true
end

function ItemLoader:UnregisterPredictor(frame)
	self.predictors[frame] = nil
end

local function TableConcat(t1,t2)
	for i=1,#t2 do
		t1[#t1+1] = t2[i]
	end
	return t1
end

local dataset, retry = {}, {}
local timeElapsed, currentIndex = 0, 0

local function AddItem(name, icon, link, itemID, force)
	if not force and items[itemID] ~= nil then
		return
	end

	items[itemID] = {
		name = name,
		icon = icon,
		link = link
	}

	local lcname = string.lower(name)

	if itemsReverse[lcname] == nil then
		local revid, _, _, _, revicon = GetItemInfoInstant(name)
		if revid then
			itemsReverse[lcname] = revid
			if revid ~= itemID and items[revid] == nil then
				items[revid] = {
					name = name,
					icon = revicon,
					link = select(2, GetItemInfo(revid))
				}
			end
		else
			itemsReverse[lcname] = itemID
		end
	end
end

function ItemLoader:StartLoading(limited)
	if dataset == nil then
        dataset = limited
		timeElapsed, currentIndex = 0, 0
	else
		dataset = TableConcat(dataset, limited)
    end

	if not self.loader then
		self.loader = CreateFrame("Frame")
    else
        self.loader:Show()
	end
	self.loader:SetScript("OnUpdate", function(self, elapsed)
		timeElapsed = timeElapsed + elapsed
		if( timeElapsed < TIMER_THROTTLE ) then return end
		timeElapsed = timeElapsed - TIMER_THROTTLE

        for idx=currentIndex + 1, currentIndex + ITEMS_PER_RUN do
			if dataset == nil or idx >= #dataset then
				if #retry > 0 then
					dataset = {}
					for k,_ in pairs(retry) do
						table.insert(dataset, k)
					end
				else
					dataset = nil
					self:Hide()
				end

				for predictor in pairs(predictors) do
					if( predictor:IsVisible() ) then
						predictor:Query()
					end
                end
                return
			end

			local itemID = dataset[idx]
			if itemID ~= 0 then
				if items[itemID] == nil then
					local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
					if( name ) then
						retry[itemID] = nil
						AddItem(name, icon, link, itemID)
					elseif retry[itemID] == nil then
						retry[itemID] = 1
					elseif retry[itemID] > MAX_ATTEMPTS then
						retry[itemID] = nil
					else
						retry[itemID] = retry[itemID] + 1
					end
				end
			end
        end

		-- Every ~1 second it will update any visible predictors to make up for the fact that the data is delay loaded
		if( currentIndex % 5000 == 0 ) then
			for predictor in pairs(predictors) do
				if( predictor:IsVisible() ) then
					predictor:Query()
				end
			end
		end

		-- Increment and do it all over!
		currentIndex = currentIndex + ITEMS_PER_RUN
	end)
end