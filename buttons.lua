-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")
local CustomGlow = LibStub("LibCustomGlow-1.0")

local Spells = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}
local Frames = {}
local Effects = {}

local math = math

local Highlight = {}
local HighlightIdx = 1
local HighlightTimer = nil
local HighlightTexture = "Interface\\Cooldown\\star4"
local HighlightAnimationSpeed = 0.1
local HighlightColors = {
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

function addon:StopCustomGlow(frame, id)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", frame:GetParent(), setp, xoffs, yoffs)
	frame:SetWidth(frame:GetParent():GetWidth() * mags)
	frame:SetHeight(frame:GetParent():GetHeight() * mags)
	frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
	if effect then
		frame.texture:SetTexture(effect)
	end
end

local function UpdateOverlay(frame, effect, color, mags, setp, xoffs, yoffs)
	UpdateOverlayRaw(frame, Effects[effect].texture, color, mags, setp, xoffs, yoffs)
end

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
local function CreateOverlay(parent, id)
	local frame = tremove(FramePool)
	if not frame then
		frame = CreateFrame('Frame', 'RotationMaster_Overlay_' .. id, parent)
	end

	frame:SetParent(parent)
	frame:SetFrameStrata('HIGH')

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)

	tinsert(Frames, frame)
	return frame
end

function addon:DestroyAllOverlays()
	for key, frame in pairs(Frames) do
		frame:GetParent().addonOverlays = nil
		frame:ClearAllPoints()
		frame:Hide()
		frame:SetParent(UIParent)
		frame.width = nil
		frame.height = nil
	end

	for key, frame in pairs(Frames) do
		tinsert(FramePool, frame)
		Frames[key] = nil
	end
end

function addon:DestroyAllCustomGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:StopCustomGlow(button, spellid)
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				self:StopCustomGlow(button, "next")
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
		LBG = LibStub:GetLibrary('LibButtonGlow-1.0')
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

local function Glow(button, id, effect, color, mags, setp, xoffs, yoffs)
	if Effects[effect] == nil then
		return
	end

    if Effects[effect].type == "texture" then
		addon:StopCustomGlow(button, id)
		if button.addonOverlays and button.addonOverlays[id] then
			UpdateOverlay(button.addonOverlays[id], effect, color, mags, setp, xoffs, yoffs)
			button.addonOverlays[id]:Show()
		else
			if not button.addonOverlays then
				button.addonOverlays = {}
			end

			button.addonOverlays[id] = CreateOverlay(button, id)
			UpdateOverlay(button.addonOverlays[id], effect, color, mags, setp, xoffs, yoffs)
			button.addonOverlays[id]:Show()
		end
	else
		if button.addonOverlays and button.addonOverlays[id] then
			button.addonOverlays[id]:Hide()
		end
		addon:ApplyCustomGlow(Effects[effect], button, id, color, xoffs, yoffs)
	end
end

local function HideGlow(button, id)
	if button.addonOverlays and button.addonOverlays[id] then
		button.addonOverlays[id]:Hide()
	end
    addon:StopCustomGlow(button, id)
end

local function AddButton(spellId, button)
	if spellId then
		if Spells[spellId] == nil then
			Spells[spellId] = {}
		end
		tinsert(Spells[spellId], button)
	end
end

local function AddStandardButton(button)
	local type = button:GetAttribute('type')
	if type then
		local actionType = button:GetAttribute(type)
		local id
		local spellId

		if type == 'action' then
			local slot = button:GetAttribute('action');
			if not slot or slot == 0 then
				slot = ActionButton_GetPagedID(button);
			end
			if not slot or slot == 0 then
				slot = ActionButton_CalculateAction(button);
			end

			if HasAction(slot) then
				type, actionType = GetActionInfo(slot);
			else
				return;
			end
		end

		if type == 'macro' then
			local item = select(2, GetMacroItem(actionType))
        	if item ~= nil then
				spellId = select(2, GetItemSpell(item))
			else
				spellId = GetMacroSpell(actionType)
            end
			if not spellId then
				return
			end
			addon:verbose("Found macro button with spell ID %s", spellId)
		elseif type == 'item' then
			spellId = select(2, GetItemSpell(actionType))
			if not spellId then
				return
            end
			addon:verbose("Found item button with spell ID %s", spellId)
		elseif type == 'spell' then
			spellId = select(7, GetSpellInfo(actionType))
			addon:verbose("Found button with spell ID %s", spellId)
		end

		AddButton(spellId, button)
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

local function FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i]
		if button then
			AddStandardButton(button)
		end
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
		local spellid = select(7, GetSpellInfo(button:GetAttribute("*spell1")))
    	if not spellid then
			spellid = select(7, GetSpellInfo(button:GetAttribute("spell1")))
		end
		if spellid then
			AddButton(spellid, button)
        end

    	for j=1,10 do
			local button = _G['TT_ActionButton' .. i .. j];
			if not button then
				break
            end
			local spellid = select(7, GetSpellInfo(button:GetAttribute("*spell1")))
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
	self:DestroyAllOverlays()
	self:DestroyAllCustomGlows()

	Spells = {}
	Flags = {}
	SpellsGlowing = {}
    Effects = {}

	for _,v in pairs(addon.db.global.effects) do
        if v.name ~= nil then
            Effects[v.name] = v
        end
	end

	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
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

function addon:FindSpell(spellIds)
    if spellIds == nil then
        return nil
	end
	for _, spellId in ipairs(spellIds) do
        if Spells[spellId] ~= nil then
			return spellId, Spells[spellId]
        end
	end
	return nil
end

function addon:IsGlowing(spellId)
    return SpellsGlowing[spellId] == 1
end

local function GlowIndependent(spellId, id, effect, color, mags, setpoint, xoffs, yoffs)
	if Spells[spellId] ~= nil then
		for k, button in pairs(Spells[spellId]) do
			Glow(button, id, effect, color, mags, setpoint, xoffs, yoffs)
			addon:verbose(spellId .. " is now glowing")
		end
	end
end

local function ClearGlowIndependent(spellId, id)
	if Spells[spellId] ~= nil then
		for k, button in pairs(Spells[spellId]) do
			HideGlow(button, id)
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowCooldown(spellId, condition, cooldown)
    if spellId == nil then
		return
    end

	if Flags[spellId] == nil then
		Flags[spellId] = false
	end
	if condition and cooldown and not Flags[spellId] then
		Flags[spellId] = true
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = false
		ClearGlowIndependent(spellId, spellId)
	end

	if WeakAuras then WeakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

function addon:GlowSpell(spellId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil then
		for k, button in pairs(Spells[spellId]) do
			Glow(button, 'next', self.db.profile.effect, self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs)
		end

		SpellsGlowing[spellId] = 1
		addon:verbose(spellId .. " is now glowing")
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v == 1 then
			for k, button in pairs(Spells[spellId]) do
				HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = 0
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId)
	self:GlowClear()
	self:GlowSpell(spellId)
end

local UpdateHighlight = function()
	HighlightIdx = HighlightIdx + 1
	if HighlightIdx > #HighlightColors then
		HighlightIdx = 1
	end
	for _, overlay in pairs(Highlight) do
		UpdateOverlayRaw(overlay, HighlightTexture, HighlightColors[HighlightIdx], 1.0, "CENTER", 0, 0)
	end
end

function addon:EndHighlightSlot()
	if (HighlightTimer) then
		addon:CancelTimer(HighlightTimer)
        HighlightTimer = nil
	end
	for _, overlay in pairs(Highlight) do
        overlay:Hide()
    end
    Highlight = {}
end

function addon:HighlightSlot(slot)
	addon:EndHighlightSlot()
	for spellid, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = button:GetAttribute('type')
			if type == 'action' then
				local bslot = button:GetAttribute('action');
				if not bslot or bslot == 0 then
					bslot = ActionButton_GetPagedID(button);
				end
				if not bslot or bslot == 0 then
					bslot = ActionButton_CalculateAction(button);
				end

				if bslot and slot == bslot then
                    local overlay = CreateOverlay(button, "Highlight")
                	table.insert(Highlight, overlay)
					HighlightIdx = 1
					UpdateOverlayRaw(overlay, HighlightTexture, HighlightColors[HighlightIdx], 1.0, "CENTER", 0, 0)
                	overlay:Show()

					if not HighlightTimer then
						HighlightTimer = addon:ScheduleRepeatingTimer(UpdateHighlight, HighlightAnimationSpeed)
					end
					break
				end
			end
		end
	end
end

