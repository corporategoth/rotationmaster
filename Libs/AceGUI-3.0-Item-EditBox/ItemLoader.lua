local major = "AceGUI-3.0-ItemLoader"
local minor = 1

local ItemLoader = LibStub:NewLibrary(major, minor)
if( not ItemLoader ) then return end

ItemLoader.predictors = ItemLoader.predictors or {}
ItemLoader.itemList = ItemLoader.itemList or {}

local ITEMS_PER_RUN = 500
local TIMER_THROTTLE = 0.10
local items, predictors = ItemLoader.itemList, ItemLoader.predictors

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

local dataset
local timeElapsed, currentIndex = 0, 0

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
				dataset = nil
				self:Hide()

				for predictor in pairs(predictors) do
					if( predictor:IsVisible() ) then
						predictor:Query()
					end
                end
                return
			end

			local itemID = dataset[idx]
        	if items[itemID] == nil then
                local name = GetItemInfo(itemID)
                if( name ) then
                    items[itemID] = string.lower(name)
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