-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("RotationMaster")

local Spells = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}
local Frames = {}
local Textures = {}

local function UpdateOverlay(frame, texture, color, mags, setp, xoffs, yoffs)
    frame:ClearAllPoints()
	frame:SetPoint("CENTER", frame:GetParent(), setp, xoffs, yoffs)
	frame:SetWidth(frame:GetParent():GetWidth() * mags)
	frame:SetHeight(frame:GetParent():GetHeight() * mags)
	frame.texture:SetVertexColor(color.r, color.g, color.b, color.a)
	if Textures[texture] then
		frame.texture:SetTexture(Textures[texture])
	end
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
		ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
		if LAB then
			LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
		if LAB then
			LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow
		end
	end
end

local function Glow(button, id, texture, color, mags, setp, xoffs, yoffs)
	if button.addonOverlays and button.addonOverlays[id] then
		UpdateOverlay(button.addonOverlays[id], texture, color, mags, setp, xoffs, yoffs)
		button.addonOverlays[id]:Show()
	else
		if not button.addonOverlays then
			button.addonOverlays = {}
		end

		button.addonOverlays[id] = CreateOverlay(button, id)
		UpdateOverlay(button.addonOverlays[id], texture, color, mags, setp, xoffs, yoffs)
		button.addonOverlays[id]:Show()
	end
end

local function HideGlow(button, id)
	if button.addonOverlays and button.addonOverlays[id] then
		button.addonOverlays[id]:Hide()
	end
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
			spellId = GetMacroSpell(actionType)
			if not spellId then
				return
			end
			addon:verbose("Found macro button with spell ID %s", spellId)
		elseif type == 'item' then
			local _
			_, spellId = GetItemSpell(actionType)
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

		addon:AddStandardButton(button)
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
	Spells = {}
	Flags = {}
	SpellsGlowing = {}
	Textures = {}

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

	for k,v in pairs(self.db.global.textures) do
		if v.name and v.texture then
			Textures[v.name] = v.texture
		end
    end

	if self.currentRotation then
		self:EnableRotationTimer()
		self:EvaluateNextAction()
	end
end

function addon:FindSpell(spellId)
    if spellId == nil then
        return false
	end
	return Spells[spellId]
end

function addon:IsGlowing(spellId)
	for k, v in pairs(SpellsGlowing) do
		if k == spellId then
			return v == 1
        end
    end
end

local function GlowIndependent(spellId, id, texture, color, mags, setpoint, xoffs, yoffs)
	if Spells[spellId] ~= nil then
		for k, button in pairs(Spells[spellId]) do
			Glow(button, id, texture, color, mags, setpoint, xoffs, yoffs)
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
		GlowIndependent(spellId, spellId, cooldown.texture or self.db.profile.overlay, cooldown.color,
                cooldown.magnification or self.db.profile.magnification,
                cooldown.setpoint or self.db.profile.setpoint,
                cooldown.xoffs or self.db.profile.xoffs,
                cooldown.yoffs or self.db.profile.yoffs)
	elseif not condition and Flags[spellId] then
		Flags[spellId] = false
		ClearGlowIndependent(spellId, spellId)
	end
end

function addon:GlowSpell(spellId)
	if spellId == nil then
		return
	end

	if Spells[spellId] ~= nil then
		for k, button in pairs(Spells[spellId]) do
			Glow(button, 'next', self.db.profile.overlay, self.db.profile.color,
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

