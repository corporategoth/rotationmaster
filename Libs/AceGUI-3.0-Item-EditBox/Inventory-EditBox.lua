local AceGUI = LibStub("AceGUI-3.0")
do
	local ItemData = LibStub("AceGUI-3.0-ItemLoader")

	local Type = "Inventory_EditBox"
	local Version = 1
	local playerItems = {}
	local frame
	
	local function itemFilter(self, itemID)
		return playerItems[itemID]
	end
	
	local function loadPlayerItems(self)
		table.wipe(playerItems)

		for i=0,20 do
			local itemId = GetInventoryItemID("player", i)
        	if itemId ~= nil then
                playerItems[itemId] = true
            end
		end
		for i=0,4 do
			for j=1,C_Container.GetContainerNumSlots(i) do
				local itemId = C_Container.GetContainerItemID(i, j)
				if itemId ~= nil then
					playerItems[itemId] = true
				end
			end
        end

		local items = {}
		for k,v in pairs(playerItems) do
			table.insert(items, k)
		end
		ItemData:StartLoading(items)
	end
	
	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("ItemPredictor_Base")
		self.itemFilter = itemFilter

		if( not frame ) then
			frame = CreateFrame("Frame")
			frame:RegisterEvent("BAG_UPDATE")
			frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
			frame:SetScript("OnEvent", loadPlayerItems)
			frame.tooltip = self.tooltip
			
			loadPlayerItems(frame)
		end

		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
