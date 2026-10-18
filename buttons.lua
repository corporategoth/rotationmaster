-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local CustomGlow = LibStub("LibCustomGlow-1.0")

local function spellMetadataID(spell)
    local info=addon.Platform:GetSpellInfo(spell)
    return info and info.spellID
end
local function itemUseSpellID(item)
    local info=addon.Platform:GetItemUseSpell(item)
    return info and info.spellID
end

local Spells = {}
local ButtonItems = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}

local HighlightOverlay = {
	type = "dazzle",
	texture = "Interface\\Cooldown\\star4",
	frequency = 0.1,
	sequence = {
		{ r = 1.00, g = 0.00, b = 0.00, a = 1 },
		{ r = 0.75, g = 0.25, b = 0.00, a = 1 },
		{ r = 0.50, g = 0.50, b = 0.00, a = 1 },
		{ r = 0.25, g = 0.75, b = 0.00, a = 1 },
		{ r = 0.00, g = 1.00, b = 0.00, a = 1 },
		{ r = 0.00, g = 0.75, b = 0.25, a = 1 },
		{ r = 0.00, g = 0.50, b = 0.50, a = 1 },
		{ r = 0.00, g = 0.25, b = 0.75, a = 1 },
		{ r = 0.00, g = 0.00, b = 1.00, a = 1 },
		{ r = 0.25, g = 0.00, b = 0.75, a = 1 },
		{ r = 0.50, g = 0.00, b = 0.50, a = 1 },
		{ r = 0.75, g = 0.00, b = 0.25, a = 1 },
	}
}
local Highlight = {}

addon.textured_types = { "texture", "dazzle", "animate", "pulse", "rotate", "custom" }

function addon:ApplyCustomGlow(effect, frame, id, color, xoffs, yoffs)
    local c
	if color ~= nil then
		c = { color.r, color.g, color.b, color.a }
	end
	if effect.type == "pixel" then
		CustomGlow.PixelGlow_Start(frame, c, effect.lines, effect.frequency, effect.length, effect.thickness, xoffs, yoffs, false, id)
	elseif effect.type == "autocast" then
		CustomGlow.AutoCastGlow_Start(frame, c, effect.particles, effect.frequency, effect.scale, xoffs, yoffs, id)
	elseif effect.type == "blizzard" then
		CustomGlow.ButtonGlow_Start(frame, c, effect.frequency)
	end
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs, angle)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", frame:GetParent(), setp, xoffs, yoffs)
	frame:SetWidth(frame:GetParent():GetWidth() * (mags or 1.0))
	frame:SetHeight(frame:GetParent():GetHeight() * (mags or 1.0))
	frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
	if effect then
		frame.texture:SetTexture(effect)
	end
	if angle then
		frame.texture:SetRotation(angle)
	end
end

local function StopOverlay(frame)
	if frame.sequenceTimer then
		addon:CancelTimer(frame.sequenceTimer)
		frame.sequenceTimer = nil
	end
	frame.sequenceIdx = nil
end

function addon:HideGlow(frame, id)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
	if id ~= nil and frame.rmOverlays and frame.rmOverlays[id] then
		StopOverlay(frame.rmOverlays[id])
		frame.rmOverlays[id]:Hide()
	end
end

local function UpdateOverlay(frame, effect, color, mags, setp, xoffs, yoffs, angle)
	local type =  effect.type
    if type == "texture" then
        UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, angle)
        return true
	elseif type == "rotate" and effect.steps and effect.steps > 0 then
		if frame.sequenceIdx then
			frame.sequenceIdx = frame.sequenceIdx >= effect.steps and 1 or (frame.sequenceIdx + 1)
		else
			frame.sequenceIdx = 1
		end
        if effect.reverse then
            UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (effect.steps - (frame.sequenceIdx - 1))))
		else
			UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (frame.sequenceIdx - 1)))
        end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
					frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	elseif effect.sequence and #effect.sequence > 0 then
        local sequence = effect.sequence
        if frame.sequenceIdx then
            frame.sequenceIdx = frame.sequenceIdx >= #sequence and 1 or (frame.sequenceIdx + 1)
        else
            frame.sequenceIdx = 1
        end
        if type == "dazzle" and effect.texture then
			UpdateOverlayRaw(frame, effect.texture, sequence[frame.sequenceIdx], mags, setp, xoffs, yoffs, angle)
		elseif type == "animate" then
			UpdateOverlayRaw(frame, sequence[frame.sequenceIdx], color, mags, setp, xoffs, yoffs, angle)
		elseif type == "pulse" and effect.texture then
			UpdateOverlayRaw(frame, effect.texture, color, sequence[frame.sequenceIdx], setp, xoffs, yoffs, angle)
		elseif type == "custom" and sequence[frame.sequenceIdx].texture and sequence[frame.sequenceIdx].color and sequence[frame.sequenceIdx].magnification then
			UpdateOverlayRaw(frame, sequence[frame.sequenceIdx].texture, sequence[frame.sequenceIdx].color, sequence[frame.sequenceIdx].magnification, setp, xoffs, yoffs, math.rad(sequence[frame.sequenceIdx].angle or 0))
		else
            StopOverlay(frame)
			return false
		end
		if not frame.sequenceTimer then
			frame.sequenceTimer = addon:ScheduleRepeatingTimer(UpdateOverlay, effect.frequency or 0.25,
				frame, effect, color, mags, setp, xoffs, yoffs, angle)
		end
		return true
	end
    return false
end

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
local function CreateOverlay(parent)
	local frame = tremove(FramePool)
	if not frame then
		frame = CreateFrame('Frame', addon_name .. '_Overlay_' .. addon.uuid(), parent)
	else
		frame:SetParent(parent)
	end

	frame:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'HIGH')
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()+1) end

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)
	return frame
end

local function DestroyOverlay(frame, id)
	StopOverlay(frame)
	if frame:GetParent().rmOverlays ~= nil and frame:GetParent().rmOverlays[id] then
		frame:GetParent().rmOverlays[id] = nil
	end
	frame:ClearAllPoints()
	frame:Hide()
	frame:SetParent(UIParent)
	frame.width = nil
	frame.height = nil

	tinsert(FramePool, frame)
end

local function DestroyAllOverlay(parent)
	if parent.rmOverlays ~= nil then
		for id,frame in pairs(parent.rmOverlays) do
			DestroyOverlay(frame, id)
		end
		parent.rmOverlays = nil
	end
end

function addon:DestroyAllGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, spellid)
				DestroyAllOverlay(button)
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:HideGlow(button, "next")
				DestroyAllOverlay(button)
			end
		end
	end
end

function addon:UpdateButtonGlow()
	local LAB
	local LBG
	local origShow
	local noFunction = function() end

	if IsAddOnLoaded('ElvUI') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0-ElvUI')
		LBG = LibStub:GetLibrary('LibCustomGlow-1.0')
		origShow = LBG.ShowOverlayGlow
	elseif IsAddOnLoaded('Bartender4') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0')
	end

	if self.db.global.disableButtonGlow then
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
			if LAB then
				LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow
		end
	end
end

function addon:Glow(button, id, effect, color, mags, setp, xoffs, yoffs, angle)
	if not effect then
		return
	end

    color=self:ResolveHighlightColor(color)

	local type = effect.type
	addon:HideGlow(button, id)
	if addon.index(addon.textured_types, type) then
		if not button.rmOverlays then
			button.rmOverlays = {}
		end
		if not button.rmOverlays[id] then
			button.rmOverlays[id] = CreateOverlay(button, id)
		end

        if UpdateOverlay(button.rmOverlays[id], effect, color, mags, setp, xoffs, yoffs, angle) then
            button.rmOverlays[id]:Show()
        end
	else
		addon:ApplyCustomGlow(effect, button, id, color, xoffs, yoffs)
	end
end

local function AddButton(spellId, button, itemId)
    if not addon.Platform:CanReadValue(spellId) then return end
	if type(spellId)=="number" and spellId>0 and spellId<math.huge and spellId%1==0 then
		if Spells[spellId] == nil then
			Spells[spellId] = {}
		end
		tinsert(Spells[spellId], button)
        ButtonItems[button]=itemId
	end
end

local function ValidActionSlot(slot)
    return type(slot) == 'number' and slot > 0
end

local function GetActionSlot(button)
    local slot = button:GetAttribute('action')
    if ValidActionSlot(slot) then return slot end

    -- Anniversary uses the same button methods as Retail. Older clients and
    -- third-party bars may still expose the global helpers or only action.
    if button.GetPagedID then
        slot = button:GetPagedID()
    elseif ActionButton_GetPagedID then
        slot = ActionButton_GetPagedID(button)
    end
    if ValidActionSlot(slot) then return slot end

    if button.CalculateAction then
        slot = button:CalculateAction()
    elseif ActionButton_CalculateAction then
        slot = ActionButton_CalculateAction(button)
    end
    if ValidActionSlot(slot) then return slot end
    if ValidActionSlot(button.action) then return button.action end
end

local function AddStandardButton(button)
	if not button then return end
	local type = button:GetAttribute('type')
	if type then
		local actionType = button:GetAttribute(type)
		local spellId,itemId

		if type == 'action' then
			local slot = GetActionSlot(button)
			if slot and HasAction(slot) then
				type, actionType = GetActionInfo(slot);
			else
				return;
			end
		end

		if type == 'macro' then
			local item = select(2, GetMacroItem(actionType))
        	if item ~= nil then
				itemId=addon.Platform:GetItemID(item)
                if not itemId then return end
                spellId = itemUseSpellID(itemId)
			else
				spellId = GetMacroSpell(actionType)
            end
			if not spellId then
				return
			end
			addon:verbose("Found macro button with spell ID %s", spellId)
		elseif type == 'item' then
			itemId=addon.Platform:GetItemID(actionType)
            if not itemId then return end
            spellId = itemUseSpellID(itemId)
			if not spellId then
				return
            end
			addon:verbose("Found item button with spell ID %s", spellId)
		elseif type == 'spell' then
			spellId = spellMetadataID(actionType)
			addon:verbose("Found button with spell ID %s", spellId)
		end

		AddButton(spellId, button, itemId)
	end
end

function FetchNeuron()
	for x = 1, 12 do
		for i = 1, 12 do
			local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchDiabolic()
	local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'};
	for _, bar in pairs(diabolicBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				AddStandardButton(button);
			end
		end
	end
end

local function FetchBartender4()
    -- Non-pet buttons are done via. LibActionButton
	for i = 1, 10 do
		local button = _G['BT4PetButton' .. i];
		if button then
		    local spell = select(7, GetPetActionInfo(button.id))
			AddButton(spell, button);
		end
		button = _G['BT4StanceButton' .. i];
		if button then
			local spell = select(4, GetShapeshiftFormInfo(button:GetID()))
			AddButton(spell, button);
		end
	end
end

local function FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i]
		if button then
			AddStandardButton(button)
		end
	end
end

local function FetchFarmingBar()
	local i = 1
	while true do
		local button = _G['FarmingBar_Button' .. i]
		if not button then
			break
		end
		local hyperlink = button.obj:GetHyperlink()
		if hyperlink then
			local itemid = tonumber(hyperlink:match("item:(%d+)"))
			if itemid then
				local spellid = itemUseSpellID(itemid)
				if spellid then
					AddButton(spellid, button, itemid)
				end
			end
		end
		i = i + 1
	end
end

local function FetchAzeriteUI()
	for i = 1, 24 do
		local button = _G['AzeriteUIActionButton' .. i];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchSamyTotemTimers()
	for i = 1, 6 do
		local button = _G['SamyTotemTimers' .. i .. "CastTotemButton"];
		if button then
			AddStandardButton(button);
		end
	end
end

local function FetchTotemTimers()
    for i=1,10 do
		local button = _G['XiTimers_Timer' .. i];
		if not button then
            break
        end
		local spellid = spellMetadataID(button:GetAttribute("*spell1"))
    	if not spellid then
			spellid = spellMetadataID(button:GetAttribute("spell1"))
		end
		if spellid then
			AddButton(spellid, button)
        end

    	for j=1,10 do
			button = _G['TT_ActionButton' .. i .. j];
			if not button then
				break
            end
			spellid = spellMetadataID(button:GetAttribute("*spell1"))
			if spellid then
				AddButton(spellid, button)
            end
		end
    end
end

local function FetchLUI()
	local luiBars = {
		'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
		'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
	}

	for _, bar in pairs(luiBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchSyncUI()
	local syncbars = {}

	syncbars[1] = SyncUI_ActionBar
	syncbars[2] = SyncUI_MultiBar
	syncbars[3] = SyncUI_SideBar.Bar1
	syncbars[4] = SyncUI_SideBar.Bar2
	syncbars[5] = SyncUI_SideBar.Bar3
	syncbars[6] = SyncUI_PetBar

	for _, bar in pairs(syncbars) do
		for i = 1, 12 do
			local button = bar['Button' .. i]
			if button then
				AddStandardButton(button)
			end
		end
	end
end

local function FetchLibActionButton()
	local LAB = {
		original = LibStub:GetLibrary('LibActionButton-1.0', true),
		elvui = LibStub:GetLibrary('LibActionButton-1.0-ElvUI', true),
	}

	for _, lib in pairs(LAB) do
		if lib and lib.GetAllButtons then
			for button in pairs(lib:GetAllButtons()) do
                AddStandardButton(button)
			end
		end
	end
end

local function FetchBlizzard()
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'}
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i]
			AddStandardButton(button)
		end
    end

	for i = 1, 10 do
		local button = _G['PetActionButton' .. i]
		AddStandardButton(button)
	end
end

local function FetchG15Buttons()
	local i = 2; -- it starts from 2
	while true do
		local button = _G['objG15_btn_' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

local function FetchButtonForge()
	local i = 1
	while true do
		local button = _G['ButtonForge' .. i]
		if not button then
			break
		end
		i = i + 1

		AddStandardButton(button)
	end
end

function addon:Fetch()
	self = addon
	if self.currentRotation then
		self:DisableRotationTimer()
	end
	self.Spell = nil

	self:GlowClear()
	self:DestroyAllGlows()

	Spells = {}
    ButtonItems = {}
	Flags = {}
	SpellsGlowing = {}

    -- The reference/editor modes on restricted clients do not inspect combat
    -- actions. Clear outgoing mappings above before leaving the scanner.
    if addon.Platform:GetClientInfo().combatDataPolicy~="probe" then return end
	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('Bartender4') then
		FetchBartender4()
	end

	if IsAddOnLoaded('ButtonForge') then
		FetchButtonForge()
	end

	if IsAddOnLoaded('G15Buttons') then
		FetchG15Buttons()
	end

	if IsAddOnLoaded('SyncUI') then
		FetchSyncUI()
	end

	if IsAddOnLoaded('LUI') then
		FetchLUI()
	end

	if IsAddOnLoaded('Dominos') then
		FetchDominos()
	end

	if IsAddOnLoaded('DiabolicUI') then
		FetchDiabolic();
	end

	if IsAddOnLoaded('AzeriteUI') then
		FetchAzeriteUI();
    end

	if IsAddOnLoaded('Neuron') then
		FetchNeuron();
	end

	if IsAddOnLoaded('FarmingBar') then
		FetchFarmingBar();
	end

	if IsAddOnLoaded('TotemTimers') then
		FetchTotemTimers();
	end

	if IsAddOnLoaded('SamyTotemTimers') then
		FetchSamyTotemTimers();
	end

	if self.currentRotation then
		self:EnableRotationTimer()
		self:EvaluateNextAction()
	end
end

function addon:FindSpell(spellIds,itemIds)
    for index,id in ipairs(spellIds or {}) do
        if Spells[id] then
            if not itemIds then return id,index end
            local wanted=itemIds[index]
            if self.Platform:CanReadValue(wanted) and type(wanted)=="number" then
                for _,button in ipairs(Spells[id]) do
                    if ButtonItems[button]==wanted then return id,index end
                end
            end
        end
    end
end

function addon:IsGlowing(spellId,itemId)
    local current=SpellsGlowing[spellId]
    return current~=nil and current.itemId==itemId
end

local function GlowIndependent(spellId, id, effect, color, mags, setpoint, xoffs, yoffs, angle, itemId)
	if Spells[spellId] ~= nil and addon.db.global.effects[effect] then
		for _, button in pairs(Spells[spellId]) do
			if not itemId or ButtonItems[button]==itemId then
                addon:Glow(button, id, addon.db.global.effects[effect], color, mags, setpoint, xoffs, yoffs, angle)
            end
			addon:verbose(spellId .. " is now glowing")
		end
	end
end

local function ClearGlowIndependent(spellId, id)
	if Spells[spellId] ~= nil then
		for _, button in pairs(Spells[spellId]) do
			addon:HideGlow(button, id)
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowCooldown(spellId, condition, cooldown, itemId)
    if spellId == nil then
		return
    end

	local previous=Flags[spellId]
    if condition and cooldown and (not previous or previous.id~=cooldown.id or previous.itemId~=itemId) then
        if previous then ClearGlowIndependent(spellId,spellId) end
		Flags[spellId] = {id=cooldown.id,itemId=itemId}
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs,
				cooldown.angle or self.db.profile.angle, itemId)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = nil
		ClearGlowIndependent(spellId, spellId)
	end

	if WeakAuras then WeakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

function addon:GlowSpell(spellId,itemId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil and addon.db.global.effects[self.db.profile.effect] then
		for _, button in pairs(Spells[spellId]) do
            if not itemId or ButtonItems[button]==itemId then
			addon:Glow(button, 'next', addon.db.global.effects[self.db.profile.effect], self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs, self.db.profile.angle)
            end
		end

		SpellsGlowing[spellId] = {itemId=itemId}
		addon:verbose(spellId .. " is now glowing")
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellId]) do
				addon:HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = nil
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId,itemId)
	self:GlowClear()
	self:GlowSpell(spellId,itemId)
end

function addon:EndHighlightSlot()
	for _, button in pairs(Highlight) do
        self:HideGlow(button, "highlight")
    end
    Highlight = {}
end

function addon:HighlightSlots(slots)
	addon:EndHighlightSlot()
	for _, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = button:GetAttribute('type')
			if type == 'action' then
				local bslot = GetActionSlot(button)

				if bslot and addon.index(slots, bslot) ~= nil then
                    self:Glow(button, "highlight", HighlightOverlay, {}, 1.0, "CENTER", 0, 0)
                	table.insert(Highlight, button)
				end
			end
		end
	end
end

