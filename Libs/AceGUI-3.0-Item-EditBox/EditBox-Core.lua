-- This is basically the main portion of the predictor, the other files handle 
local AceGUI = LibStub("AceGUI-3.0")
local floor = math.floor

do
	local Type = "ItemPredictor_Base"
	local Version = 1
	local RESULT_ROWS = 100
	local PREDICTOR_ROWS = 10
	local ItemData = LibStub("AceGUI-3.0-ItemLoader")
	local tooltip
	local alreadyAdded = {}
	local predictorBackdrop = {
	  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	  edgeSize = 26,
	  insets = {left = 9, right = 9, top = 9, bottom = 9},
	}

	local function OnAcquire(self)
		self:SetHeight(26)
		self:SetWidth(200)
		self:SetDisabled(false)
		self:SetLabel()
		self.showButton = true
		
		ItemData:RegisterPredictor(self.predictFrame)
		-- ItemData:StartLoading()
	end
	
	local function OnRelease(self)
		self.frame:ClearAllPoints()
		self.frame:Hide()
		self.predictFrame:Hide()
		self.itemFilter = nil

		self:SetDisabled(false)

		ItemData:UnregisterPredictor(self.predictFrame)
	end
			
	local function Control_OnEnter(this)
		this.obj:Fire("OnEnter")
	end
	
	local function Control_OnLeave(this)
		this.obj:Fire("OnLeave")
	end

	local function Update_PredictorScroll(self, value)
		value = floor(value)
		if value > self.activeButtons - PREDICTOR_ROWS then value = self.activeButtons - PREDICTOR_ROWS end
		if value < 0 then value = 0 end
		if self.buttonOffset ~= value then
			while value < self.buttonOffset do
				self.buttons[self.buttonOffset + PREDICTOR_ROWS]:Hide()
				self.buttonOffset = self.buttonOffset - 1
				local topButton = self.buttons[self.buttonOffset + 1]
				topButton:SetPoint("TOPLEFT", self, 8, -10)
				topButton:SetPoint("TOPRIGHT", self, -7, 0)
				local nextButton = self.buttons[self.buttonOffset + 2]
				nextButton:SetPoint("TOPLEFT", topButton, "BOTTOMLEFT", 0, 0)
				nextButton:SetPoint("TOPRIGHT", topButton, "BOTTOMRIGHT", 0, 0)
				topButton:Show()
			end
			while value > self.buttonOffset do
				self.buttons[self.buttonOffset + 1]:Hide()
				self.buttonOffset = self.buttonOffset + 1
				local topButton = self.buttons[self.buttonOffset + 1]
				topButton:SetPoint("TOPLEFT", self, 8, -10)
				topButton:SetPoint("TOPRIGHT", self, -7, 0)
				local lastButton = self.buttons[self.buttonOffset + PREDICTOR_ROWS]
				lastButton:Show()
			end
			self.scrollbar:SetValue(value)
		end
	end

	local function Predictor_Query(self)
		for _, button in pairs(self.buttons) do button:Hide() end
		table.wipe(alreadyAdded)

		local query = "^" .. string.gsub(string.lower(self.obj.editBox:GetText()),
			"([().%+-*?^$[])", "%%%1")

		local activeButtons = 0
		for name, itemID in pairs(ItemData.itemListReverse) do
			if( not alreadyAdded[name] and string.match(name, query) and ( not self.obj.itemFilter or self.obj.itemFilter(self.obj, itemID) ) ) then
				activeButtons = activeButtons + 1

				local button = self.buttons[activeButtons]
				local itemInfo = ItemData.itemList[itemID]
				if itemInfo ~= nil and itemInfo.icon ~= nil and itemInfo.link ~= nil then
                    button:SetFormattedText("|T%s:20:20:2:11|t %s", itemInfo.icon, itemInfo.link)
                else
					button:SetFormattedText("[%s]", itemID)
				end

                alreadyAdded[name] = true

				button.itemID = itemID

				-- Highlight if needed
				if( activeButtons ~= self.selectedButton ) then
					button:UnlockHighlight()

					if( GameTooltip:IsOwned(button) ) then
						GameTooltip:Hide()
					end
				end
				
				-- Ran out of text to suggest :<
				if( activeButtons >= PREDICTOR_ROWS ) then break end
			end
		end

		self.activeButtons = activeButtons
		if( activeButtons > 0 ) then
			if activeButtons > PREDICTOR_ROWS then
				self:SetHeight(19 + PREDICTOR_ROWS * 17)
				self.scrollbar:Show()
				self.scrollbar:SetMinMaxValues(0, activeButtons - PREDICTOR_ROWS)
				if self.buttonOffset + PREDICTOR_ROWS > activeButtons then
					self.buttonOffset = activeButtons - PREDICTOR_ROWS
					self.scrollbar:SetValue(self.buttonOffset)
				end
			else
				self:SetHeight(19 + activeButtons * 17)
				self.scrollbar:Hide()
				self.buttonOffset = 0
				self.scrollbar:SetValue(self.buttonOffset)
			end
			for idx,button in pairs(self.buttons) do
				if idx <= self.buttonOffset or idx > self.buttonOffset + activeButtons or idx > self.buttonOffset + PREDICTOR_ROWS then
					button:Hide()
				elseif idx == self.buttonOffset + 1 then
					button:SetPoint("TOPLEFT", self, 8, -10)
					button:SetPoint("TOPRIGHT", self, -7, 0)
					button:Show()
				else
					button:SetPoint("TOPLEFT", self.buttons[idx-1], "BOTTOMLEFT", 0, 0)
					button:SetPoint("TOPRIGHT", self.buttons[idx-1], "BOTTOMRIGHT", 0, 0)
					button:Show()
				end
			end

			self:Show()
		else
			self:Hide()
		end
	end

	local function Predictor_OnMouseWheel(self, value)
		-- DOWN = -1, UP = 1

		if (self.activeButtons > PREDICTOR_ROWS) then
			Update_PredictorScroll(self, self.buttonOffset - value)
		end
	end

	local function ScrollBar_OnScrollValueChanged(frame, value)
		Update_PredictorScroll(frame:GetParent(), value)
	end

	local function ShowButton(self)
		if( self.lastText ~= "" ) then
			self.predictFrame.selectedButton = nil
			Predictor_Query(self.predictFrame)
		else
			self.predictFrame:Hide()
		end
			
		if( self.showButton ) then
			self.button:Show()
			self.editBox:SetTextInsets(0, 20, 3, 3)
		end
	end
	
	local function HideButton(self)
		self.button:Hide()
		self.editBox:SetTextInsets(0, 0, 3, 3)

		self.predictFrame.selectedButton = nil
		self.predictFrame:Hide()
	end

	local function Predictor_OnHide(self)
		-- Allow users to use arrows to go back and forth again without the fix
		self.obj.editBox:SetAltArrowKeyMode(false)
		
		-- Make sure the tooltip isn't kept open if one of the buttons was using it
		for _, button in pairs(self.buttons) do
			if( GameTooltip:IsOwned(button) ) then
				GameTooltip:Hide()
			end
		end
		
		-- Reset all bindings set on this predictor
		ClearOverrideBindings(self)

		self:SetScript("OnKeyDown", nil)
	end

	local function Predictor_OnShow(self)
		-- If the user is using an edit box in a configuration, they will live without arrow keys while the predictor
		-- is opened, this also is the only way of getting up/down arrow for browsing the predictor to work.
		self.obj.editBox:SetAltArrowKeyMode(true)
		
		local name = self:GetName()
		SetOverrideBindingClick(self, true, "DOWN", name, 1)
		SetOverrideBindingClick(self, true, "UP", name, -1)
		SetOverrideBindingClick(self, true, "LEFT", name, "LEFT")
		SetOverrideBindingClick(self, true, "RIGHT", name, "RIGHT")

		self:SetScript("OnKeyDown", function (self, key)
			self:SetPropagateKeyboardInput(key ~= "ESCAPE")
			if key == "ESCAPE" then
				self:Hide()
			end
		end)
	end
	
	local function EditBox_OnEnterPressed(this)
		local self = this.obj

		-- Something is selected in the predictor, use that value instead of whatever is in the input box
		if( self.predictFrame.selectedButton ) then
			self.predictFrame.buttons[self.predictFrame.selectedButton]:Click()
			return
		end
	
		local cancel = self:Fire("OnEnterPressed", this:GetText())
		if( not cancel ) then
			HideButton(self)
		end

		-- Reactive the cursor, odds are if someone is adding items they are adding more than one
		-- and if they aren't, it can't hurt anyway.
		self.editBox:SetFocus()
	end

	local function EditBox_OnEscapePressed(this)
		this:ClearFocus()
	end

	-- When using SetAltArrowKeyMode the ability to move the cursor with left and right arrows is disabled
	-- this reenables that so the user doesn't notice anything wrong
	local function EditBox_FixCursorPosition(self, direction)
		self:SetCursorPosition(self:GetCursorPosition() + (direction == "RIGHT" and 1 or -1))
	end
	
	local function EditBox_OnReceiveDrag(this)
		local self = this.obj
		local type, id = GetCursorInfo()

		if( type == "item" ) then
			local name = GetItemInfo(id)
			self:SetText(name)
			self:Fire("OnEnterPressed", id)
			ClearCursor()
		end
		
		HideButton(self)
		AceGUI:ClearFocus()
	end
	
	local function EditBox_OnTextChanged(this)
		local self = this.obj
		local value = this:GetText()
		if( value ~= self.lastText ) then
			self:Fire("OnTextChanged", value)
			self.lastText = value
			
			ShowButton(self)
		end
	end

	local function EditBox_OnEditFocusLost(self)
		Predictor_OnHide(self.obj.predictFrame)
    end

	local function EditBox_OnHide(self)
		self.obj.predictFrame:Hide()
	end

	local function EditBox_OnEditFocusGained(self)
		if( self.obj.predictFrame:IsVisible() ) then
			Predictor_OnShow(self.obj.predictFrame)
		end
	end
	
	local function Button_OnClick(this)
		EditBox_OnEnterPressed(this.obj.editBox)
	end
	
	local function SetDisabled(self, disabled)
		self.disabled = disabled
		if( disabled ) then
			self.editBox:EnableMouse(false)
			self.editBox:ClearFocus()
			self.editBox:SetTextColor(0.5, 0.5, 0.5)
			self.label:SetTextColor(0.5, 0.5, 0.5)
		else
			self.editBox:EnableMouse(true)
			self.editBox:SetTextColor(1, 1, 1)
			self.label:SetTextColor(1, 0.82, 0)
		end
	end
	
	local function SetText(self, text, cursor)
		self.lastText = text or ""
		self.editBox:SetText(self.lastText)
		self.editBox:SetCursorPosition(cursor or 0)

		HideButton(self)
	end
	
	local function SetLabel(self, text)
		if( text and text ~= "" ) then
			self.label:SetText(text)
			self.label:Show()
			self.editBox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 7, -18)
			self:SetHeight(44)
			self.alignoffset = 30
		else
			self.label:SetText("")
			self.label:Hide()
			self.editBox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 7, 0)
			self:SetHeight(26)
			self.alignoffset = 12
		end
	end
	
	local function Predictor_OnMouseDown(self, direction)
		-- Fix the cursor positioning if left or right arrow key was used
		if( direction == "LEFT" or direction == "RIGHT" ) then
			EditBox_FixCursorPosition(self.editBox, direction)
			return
		end
		
		self.selectedButton = (self.selectedButton or 0) + (direction or 0)
		if( self.selectedButton > self.activeButtons ) then
			self.selectedButton = 1
		elseif( self.selectedButton <= 0 ) then
			self.selectedButton = self.activeButtons
		end
		
		-- Figure out what to highlight and show the item tooltip while we're at it
		for i=1, self.activeButtons do
			local button = self.buttons[i]
			if( i == self.selectedButton ) then
				button:LockHighlight()
				
				GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 3)
				GameTooltip:SetHyperlink("item:" .. button.itemID)
			else
				button:UnlockHighlight()
				
				if( GameTooltip:IsOwned(button) ) then
					GameTooltip:Hide()
				end
			end
		end
	end
				
	local function Item_OnClick(self)
		local name = GetItemInfo(self.itemID)

		self.parent.selectedButton = nil
		self.parent.obj:SetText(name)
		self.parent.obj:Fire("OnEnterPressed", self.itemID)
	end
	
	local function Item_OnEnter(self)
		self.parent.selectedButton = nil
		self:LockHighlight()
		
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 3)
		GameTooltip:SetHyperlink("item:" .. self.itemID)
	end
	
	local function Item_OnLeave(self)
		self:UnlockHighlight()
		GameTooltip:Hide()
	end

	local function Constructor()
		local num  = AceGUI:GetNextWidgetNum(Type)
		local frame = CreateFrame("Frame", nil, UIParent)
		local editBox = CreateFrame("EditBox", "AceGUI30ItemEditBox" .. num, frame, "InputBoxTemplate")
	
		-- Don't feel like looking up the specific callbacks for when a widget resizes, so going to be creative with SetPoint instead!
		local predictFrame = CreateFrame("ScrollFrame", "AceGUI30ItemEditBox" .. num .. "Predictor", UIParent, BackdropTemplateMixin and "BackdropTemplate")
		predictFrame:SetBackdrop(predictorBackdrop)
		predictFrame:SetBackdropColor(0, 0, 0, 0.85)
		predictFrame:SetWidth(1)
		predictFrame:SetHeight(150)
		predictFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -6, 0)
		predictFrame:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
		predictFrame:SetFrameStrata("TOOLTIP")
		predictFrame.buttons = {}
		predictFrame.activeButtons = 0
		predictFrame.buttonOffset = 0
		predictFrame.Query = Predictor_Query
		predictFrame:Hide()

		local scrollbar = CreateFrame("Slider", ("AceConfigDialogScrollFrame%dScrollBar"):format(num), predictFrame, "UIPanelScrollBarTemplate")
		scrollbar:SetPoint("TOPRIGHT", predictFrame, "TOPLEFT", 0, -20)
		scrollbar:SetPoint("BOTTOMRIGHT", predictFrame, "BOTTOMLEFT", 0, 20)
		scrollbar:SetMinMaxValues(0, 1000)
		scrollbar:SetValueStep(1)
		scrollbar:SetValue(0)
		scrollbar:SetWidth(16)
		scrollbar:Hide()
		-- set the script as the last step, so it doesn't fire yet
		scrollbar:SetScript("OnValueChanged", ScrollBar_OnScrollValueChanged)

		local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
		scrollbg:SetAllPoints(scrollbar)
		scrollbg:SetColorTexture(0, 0, 0, 0.4)

		predictFrame.scrollbar = scrollbar

		-- Create the mass of predictor rows
		for i=1, RESULT_ROWS do
			local button = CreateFrame("Button", nil, predictFrame)
			button:SetHeight(17)
			button:SetWidth(1)
			button:SetPushedTextOffset(-2, 0)
			button:SetScript("OnClick", Item_OnClick)
			button:SetScript("OnEnter", Item_OnEnter)
			button:SetScript("OnLeave", Item_OnLeave)
			button.parent = predictFrame
			button.editBox = editBox
			button:Hide()
			
			if( i > 1 ) then
				button:SetPoint("TOPLEFT", predictFrame.buttons[i - 1], "BOTTOMLEFT", 0, 0)
				button:SetPoint("TOPRIGHT", predictFrame.buttons[i - 1], "BOTTOMRIGHT", 0, 0)
			else
				button:SetPoint("TOPLEFT", predictFrame, 8, -10)
				button:SetPoint("TOPRIGHT", predictFrame, -7, 0)
			end

			-- Create the actual text
			local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			text:SetHeight(1)
			text:SetWidth(1)
			text:SetJustifyH("LEFT")
			text:SetAllPoints(button)
			button:SetFontString(text)

			-- Setup the highlighting
			local texture = button:CreateTexture(nil, "ARTWORK")
			texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			texture:ClearAllPoints()
			texture:SetPoint("TOPLEFT", button, 0, -2)
			texture:SetPoint("BOTTOMRIGHT", button, 5, 2)
			texture:SetAlpha(0.70)

			button:SetHighlightTexture(texture)
			button:SetHighlightFontObject(GameFontHighlight)
			button:SetNormalFontObject(GameFontNormal)
			
			table.insert(predictFrame.buttons, button)
		end	
		
		-- Set the main info things for this thingy
		local self = {}
		self.type = Type
		self.num = num

		self.OnRelease = OnRelease
		self.OnAcquire = OnAcquire

		self.SetDisabled = SetDisabled
		self.SetText = SetText
		self.SetLabel = SetLabel
		
		self.frame = frame
		self.predictFrame = predictFrame
		self.editBox = editBox

		self.alignoffset = 30
		
		frame:SetHeight(44)
		frame:SetWidth(200)

		frame.obj = self
		editBox.obj = self
		predictFrame.obj = self
		
		-- Purely meant for a single tooltip for doing scanning
		if( not tooltip ) then
			tooltip = CreateFrame("GameTooltip")
			tooltip:SetOwner(UIParent, "ANCHOR_NONE")
			for i=1, 6 do
				tooltip["TextLeft" .. i] = tooltip:CreateFontString()
				tooltip["TextRight" .. i] = tooltip:CreateFontString()
				tooltip:AddFontStrings(tooltip["TextLeft" .. i], tooltip["TextRight" .. i])
			end
		end
		
		self.tooltip = tooltip

		-- EditBoxes override the OnKeyUp/OnKeyDown events so that they can function, meaning in order to make up and down
		-- arrow navigation of the menu work, I have to do some trickery with temporary bindings.
		predictFrame:SetScript("OnMouseDown", Predictor_OnMouseDown)
		predictFrame:SetScript("OnHide", Predictor_OnHide)
		predictFrame:SetScript("OnShow", Predictor_OnShow)
		predictFrame:EnableMouseWheel(true)
		predictFrame:SetScript("OnMouseWheel", Predictor_OnMouseWheel)
		predictFrame:EnableKeyboard(true)
		predictFrame:SetPropagateKeyboardInput(true)

		editBox:SetScript("OnEnter", Control_OnEnter)
		editBox:SetScript("OnLeave", Control_OnLeave)
		
		editBox:SetAutoFocus(false)
		editBox:SetFontObject(ChatFontNormal)
		editBox:SetScript("OnEscapePressed", EditBox_OnEscapePressed)
		editBox:SetScript("OnEnterPressed", EditBox_OnEnterPressed)
		editBox:SetScript("OnTextChanged", EditBox_OnTextChanged)
		editBox:SetScript("OnReceiveDrag", EditBox_OnReceiveDrag)
		editBox:SetScript("OnMouseDown", EditBox_OnReceiveDrag)
		editBox:SetScript("OnEditFocusGained", EditBox_OnEditFocusGained)
		editBox:SetScript("OnEditFocusLost", EditBox_OnEditFocusLost)
		editBox:SetScript("OnHide", EditBox_OnHide)

		editBox:SetTextInsets(0, 0, 3, 3)
		editBox:SetMaxLetters(256)
		
		editBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 0)
		editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		editBox:SetHeight(19)
		
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
		label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -2)
		label:SetJustifyH("LEFT")
		label:SetHeight(18)

		self.label = label
		
		local button = CreateFrame("Button", nil, editBox, "UIPanelButtonTemplate")
		button:SetPoint("RIGHT", editBox, "RIGHT", -2, 0)
		button:SetScript("OnClick", Button_OnClick)
		button:SetWidth(40)
		button:SetHeight(20)
		button:SetText(OKAY)
		button:Hide()
		
		self.button = button
		button.obj = self

		AceGUI:RegisterAsWidget(self)
		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
