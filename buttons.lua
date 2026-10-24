-- This file was originally from the MaxDps addon (https://github.com/kaminaris/MaxDps)
-- That addon is writtn by Kaminaris, and is released under the MIT license.
-- Accordingly, this file is also subject to the MIT license (https://opensource.org/licenses/MIT)

-- This file has been heavily modified from the original.  It is no longer compatible with the original.

local addon_name, addon = ...
local function readClientPolicy(current)return current:GetClientInfo().combatDataPolicy end
---@type fun(...): any
local consumeClientPolicy=addon.ConsumeClientPolicyReader
if type(consumeClientPolicy)=='function' then readClientPolicy=consumeClientPolicy(addon) end
addon.ConsumeClientPolicyReader=nil
-- The active-plan receiver is consumed before any library callback. Only the
-- literal cooldown publisher below may qualify its private presentation route.
---@type fun(...): any
local publishActivePresentation=addon.BindActiveRuntimePresentationSource
addon.BindActiveRuntimePresentationSource=nil
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local CustomGlow = LibStub("LibCustomGlow-1.0")

local procSupport,procProbe
local function methods(value,names)
    for _,name in ipairs(names) do if type(value[name])~='function' then return false end end
    return true
end
local function probeProcGlow(atlas)
    for _,name in ipairs({'UI-HUD-ActionBar-Proc-Start-Flipbook','UI-HUD-ActionBar-Proc-Loop-Flipbook'}) do
        if type(atlas(name))~='table' then return false end
    end
    if not procProbe then procProbe=CreateFrame('Frame',nil,UIParent);procProbe:Hide();procProbe:SetSize(40,40) end
    local texture=procProbe:CreateTexture(nil,'ARTWORK');if type(texture.SetAtlas)~='function' then return false end
    texture:SetAtlas('UI-HUD-ActionBar-Proc-Start-Flipbook');texture:SetAtlas('UI-HUD-ActionBar-Proc-Loop-Flipbook')
    procProbe.ProcLoop=texture
    local group=procProbe:CreateAnimationGroup()
    if not methods(group,{'Stop','Play','IsPlaying','SetLooping','SetToFinalAlpha','SetScript'}) then return false end
    group:SetLooping('REPEAT');group:SetToFinalAlpha(true)
    local alpha=group:CreateAnimation('Alpha')
    if not methods(alpha,{'SetChildKey','SetDuration','SetOrder','SetFromAlpha','SetToAlpha'}) then return false end
    alpha:SetChildKey('ProcLoop');alpha:SetDuration(.001);alpha:SetOrder(0);alpha:SetFromAlpha(1);alpha:SetToAlpha(1)
    local flipbook=group:CreateAnimation('FlipBook')
    if not methods(flipbook,{'SetChildKey','SetDuration','SetOrder','SetFlipBookRows','SetFlipBookColumns','SetFlipBookFrames','SetFlipBookFrameWidth','SetFlipBookFrameHeight'}) then return false end
    flipbook:SetChildKey('ProcLoop');flipbook:SetDuration(1);flipbook:SetOrder(0)
    flipbook:SetFlipBookRows(6);flipbook:SetFlipBookColumns(5);flipbook:SetFlipBookFrames(30);flipbook:SetFlipBookFrameWidth(0);flipbook:SetFlipBookFrameHeight(0)
    group:Stop();return true
end
-- Method names alone do not establish animation/atlas support on Classic.
-- This hidden probe never plays, and stable capabilities need no warm allocation.
function addon:GetProcGlowSupport()
    local atlas=C_Texture and C_Texture.GetAtlasInfo or rawget(_G,'GetAtlasInfo')
    if procSupport and procSupport.atlas==atlas and procSupport.create==CreateFrame
        and procSupport.start==CustomGlow.ProcGlow_Start and procSupport.stop==CustomGlow.ProcGlow_Stop then return procSupport.available end
    procSupport={atlas=atlas,create=CreateFrame,start=CustomGlow.ProcGlow_Start,stop=CustomGlow.ProcGlow_Stop,available=false}
    if type(atlas)=='function' and type(CreateFrame)=='function' and type(procSupport.start)=='function' and type(procSupport.stop)=='function' then
        local ok,value=pcall(probeProcGlow,atlas);procSupport.available=ok and value==true
    end
    return procSupport.available
end

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
local ButtonSpells = {}
local MacroButtons = {}
-- Pet bar buttons and their pet action index (class pets, and the possessed
-- unit's abilities on clients that show possession on the pet bar).
local PetButtons = {}
local Flags = {}
local SpellsGlowing = {}
local FramePool = {}
-- For /rm debug glow (Diagnostics/glow.lua): scan count and time, and the
-- last recommendation glow request and what became of it. Written only when
-- the bars are scanned or the recommended spell changes, never per poll.
local FetchCount,LastFetchAt=0,nil
-- Callbacks told when the index changes (a scan, or a macro button that now
-- shows another action), so an open editor can refresh what it derives from
-- the index. Event driven only; nothing runs per poll unless a macro changed.
local indexWatchers={}
local indexContext={module='ui',operation='button-index'}
local function announceIndexChange()
    if next(indexWatchers)==nil then return end
    local diagnostics=addon.Diagnostics
    for key,callback in pairs(indexWatchers) do
        if diagnostics and type(diagnostics.Call)=='function' then diagnostics:Call(indexContext,callback,key)
        else pcall(callback,key) end
    end
end
function addon:WatchButtonIndex(key,callback)
    if key~=nil then indexWatchers[key]=type(callback)=='function' and callback or nil end
end
-- The client data policy the current index was built under (Fetch).
local fetchedPolicy
local LastGlow = {}

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
	elseif effect.type == 'proc' then
        if self:GetProcGlowSupport() then
            local duration=effect.duration
            if type(duration)~='number' or duration~=duration or duration<.1 or duration>5 then duration=1 end
            local ok=pcall(CustomGlow.ProcGlow_Start,frame,{key=tostring(id or ''),color=c,duration=duration,startAnim=effect.startAnim==true,xOffset=xoffs or 0,yOffset=yoffs or 0})
            if ok then return end
            procSupport.available=false
        end
        -- Another frame may have retired shared support while this key was lit.
        if type(CustomGlow.ProcGlow_Stop)=='function' then pcall(CustomGlow.ProcGlow_Stop,frame,tostring(id or '')) end
        CustomGlow.PixelGlow_Start(frame,c,nil,nil,nil,nil,xoffs,yoffs,false,id)
	end
end

local function InvalidateOverlay(frame)
    frame.rmOverlayGeneration=(frame.rmOverlayGeneration or 0)+1
    frame.rmOverlayDirty=true
    frame.rmOverlayParent=nil
end

local function UpdateOverlayRaw(frame, effect, color, mags, setp, xoffs, yoffs, angle)
    local generation=frame.rmOverlayGeneration
    -- Native size scripts can alter any earlier render channel. These frames
    -- keep the complete legacy write path; sample the script each tick so late
    -- registration is covered without an observer or new subscription.
    local sizeScript=frame:GetScript('OnSizeChanged')~=nil
    local parent=frame:GetParent()
    if frame.rmOverlayGeneration~=generation then return false end
    local dirty=frame.rmOverlayDirty~=false or sizeScript
    if dirty or frame.rmOverlayParent~=parent or frame.rmOverlayPoint~=setp
        or frame.rmOverlayX~=xoffs or frame.rmOverlayY~=yoffs then
        -- Native geometry setters may synchronously alter later geometry or
        -- paint channels. Keep the remainder of this invocation on the legacy
        -- write path; only stable geometry can skip unchanged paint channels.
        dirty=true
        frame:ClearAllPoints()
        if frame.rmOverlayGeneration~=generation then return false end
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
        frame:SetPoint("CENTER",parent,setp,xoffs,yoffs)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayParent,frame.rmOverlayPoint=parent,setp
        frame.rmOverlayX,frame.rmOverlayY=xoffs,yoffs
        -- Anchor setters can invoke native callbacks which reparent the frame.
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local sizeChanged=false
    local width=parent:GetWidth() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayWidth~=width then
        dirty=true
        frame:SetWidth(width)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
        parent=frame:GetParent()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    -- Size setters can dispatch native OnSizeChanged callbacks. Read later
    -- inputs only after those callbacks, just as the original renderer did.
    local height=parent:GetHeight() * (mags or 1.0)
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayHeight~=height then
        dirty=true
        frame:SetHeight(height)
        if frame.rmOverlayGeneration~=generation then return false end
        sizeChanged=true
    end
    if sizeChanged then
        -- A size callback can change either dimension again. Cache the final
        -- native dimensions so the next tick corrects any request disagreement.
        frame.rmOverlayWidth,frame.rmOverlayHeight=frame:GetWidth(),frame:GetHeight()
        if frame.rmOverlayGeneration~=generation then return false end
    end
    local r,g,b,a=color.r,color.g,color.b,color.a
    if frame.rmOverlayGeneration~=generation then return false end
    if dirty or frame.rmOverlayR~=r or frame.rmOverlayG~=g or frame.rmOverlayB~=b or frame.rmOverlayA~=a then
        frame.texture:SetVertexColor(r,g,b,a)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayR,frame.rmOverlayG,frame.rmOverlayB,frame.rmOverlayA=r,g,b,a
    end
    if effect and (dirty or frame.rmOverlayTexture~=effect) then
        frame.texture:SetTexture(effect)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayTexture=effect
    end
    if angle and (dirty or frame.rmOverlayAngle~=angle) then
        frame.texture:SetRotation(angle)
        if frame.rmOverlayGeneration~=generation then return false end
        frame.rmOverlayAngle=angle
    end
    -- Leave a final repaint pending after the script is removed.
    frame.rmOverlayDirty=sizeScript
    return true
end


-- Native stepped animation. Every animated effect shows one step at a time:
-- rotate (angles), dazzle (colors), animate (textures), pulse (sizes) and
-- custom (all four per step). Each step becomes its own texture on the
-- overlay, shown by alpha keyframes in one looping AnimationGroup, so the
-- client plays the exact same steps with no Lua per frame. Clients without
-- the animation API, oversized or malformed sequences keep the Lua timer.
-- Steps take the button's size when the glow starts.
local NATIVE_MAX_STEPS = 64

local function nativeSteps(effect, color, mags, angle)
    local kind, sequence = effect.type, effect.sequence
    local result = {}
    if kind == "rotate" then
        local n = effect.steps
        if type(n) ~= "number" or n < 1 or n % 1 ~= 0 or n > NATIVE_MAX_STEPS then return nil end
        for i = 1, n do
            local step = effect.reverse and (n - (i - 1)) or (i - 1)
            result[i] = {effect.texture, color, mags, (2 * math.pi) / n * step}
        end
        return result
    end
    if type(sequence) ~= "table" or #sequence == 0 or #sequence > NATIVE_MAX_STEPS then return nil end
    for i, value in ipairs(sequence) do
        if kind == "dazzle" and effect.texture then result[i] = {effect.texture, value, mags, angle}
        elseif kind == "animate" then result[i] = {value, color, mags, angle}
        elseif kind == "pulse" and effect.texture then result[i] = {effect.texture, color, value, angle}
        elseif kind == "custom" and type(value) == "table" and value.texture and value.color and value.magnification then
            result[i] = {value.texture, value.color, value.magnification, math.rad(value.angle or 0)}
        else return nil end
    end
    return #result == #sequence and result or nil
end

local function nativeSupported(frame)
    if type(frame.CreateAnimationGroup) ~= "function" or type(frame.CreateTexture) ~= "function" then return false end
    local texture = frame.texture
    return texture and type(texture.SetRotation) == "function" and type(texture.SetAlpha) == "function"
end

-- One group per step count and frequency, reused across glows on this frame.
local function nativeGroup(frame, count, frequency)
    frame.rmNativeGroups = frame.rmNativeGroups or {}
    local key = count .. "@" .. frequency
    local group = frame.rmNativeGroups[key]
    if group then return group end
    group = frame:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    for i = 1, count do
        local texture = frame.rmStepTextures[i]
        local on = group:CreateAnimation("Alpha")
        on:SetTarget(texture);on:SetFromAlpha(0);on:SetToAlpha(1)
        on:SetDuration(0.001);on:SetStartDelay((i - 1) * frequency);on:SetOrder(1)
        local off = group:CreateAnimation("Alpha")
        off:SetTarget(texture);off:SetFromAlpha(1);off:SetToAlpha(0)
        off:SetDuration(0.001);off:SetStartDelay(i * frequency);off:SetOrder(1)
    end
    frame.rmNativeGroups[key] = group
    return group
end

local function StopNativeOverlay(frame)
    local native = frame.rmNative
    if not native then return end
    frame.rmNative = nil
    native.group:Stop()
    for i = 1, native.count do frame.rmStepTextures[i]:Hide() end
    frame.texture:Show()
end

local function StartNativeOverlay(frame, effect, color, mags, setp, xoffs, yoffs, angle)
    if not nativeSupported(frame) then return false end
    local steps = nativeSteps(effect, color, mags, angle)
    if not steps then return false end
    local frequency = effect.frequency or .25
    if type(frequency) ~= "number" or frequency <= 0 then return false end
    StopNativeOverlay(frame)
    local parent = frame:GetParent()
    local width, height = parent:GetWidth(), parent:GetHeight()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, setp, xoffs, yoffs)
    frame:SetSize(width, height)
    frame.texture:Hide()
    frame.rmStepTextures = frame.rmStepTextures or {}
    for i, step in ipairs(steps) do
        local texture = frame.rmStepTextures[i]
        if not texture then
            texture = frame:CreateTexture(nil, "OVERLAY")
            texture:SetBlendMode("ADD")
            frame.rmStepTextures[i] = texture
        end
        local c, scale = step[2], step[3] or 1.0
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", frame, "CENTER")
        texture:SetSize(width * scale, height * scale)
        texture:SetTexture(step[1])
        texture:SetVertexColor(c.r, c.g, c.b, c.a)
        texture:SetRotation(step[4] or 0)
        texture:SetAlpha(0)
        texture:Show()
    end
    local group = nativeGroup(frame, #steps, frequency)
    frame.rmNative = {group=group, count=#steps}
    group:Play()
    return true
end

local UpdateOverlay
local function OverlayVisible(frame)
    -- Older external frame stand-ins have no visibility observation. Keep
    -- their legacy timer behavior; ordinary native Frames provide this API.
    if type(frame.IsVisible)=='function' then return frame:IsVisible() end
end

local function StopOverlay(frame)
    StopNativeOverlay(frame)
    InvalidateOverlay(frame)
    local generation,timer=frame.rmOverlayGeneration,frame.sequenceTimer
    frame.rmOverlayAnimation=nil
    frame.sequenceTimer=nil
    frame.sequenceIdx=nil
    if timer then addon:CancelTimer(timer) end
    return frame.rmOverlayGeneration==generation
end

local function PauseOverlay(frame)
    local animation,generation=frame.rmOverlayAnimation,frame.rmOverlayGeneration
    if not animation or OverlayVisible(frame)~=false then return end
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation then return end
    InvalidateOverlay(frame)
    animation.generation=frame.rmOverlayGeneration
    animation.paused=true
    animation.ticket=nil
    local timer=frame.sequenceTimer
    frame.sequenceTimer=nil
    if timer then addon:CancelTimer(timer) end
end

local function StartOverlay(frame,animation)
    local generation=frame.rmOverlayGeneration
    if frame.rmOverlayAnimation~=animation or animation.generation~=generation then return false end
    if frame.sequenceTimer or animation.scheduling and animation.scheduling.generation==generation then return true end
    local visible=OverlayVisible(frame)
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation then return false end
    if visible==false then animation.paused=true;return true end
    animation.paused=false
    local ticket={generation=generation}
    animation.ticket,animation.scheduling=ticket,ticket
    local ok,timer=pcall(addon.ScheduleRepeatingTimer,addon,UpdateOverlay,animation.effect.frequency or .25,
        frame,animation.effect,animation.color,animation.mags,animation.setp,
        animation.xoffs,animation.yoffs,animation.angle,animation,ticket)
    if animation.scheduling==ticket then animation.scheduling=nil end
    if not ok then
        if animation.ticket==ticket then animation.ticket=nil end
        error(timer,0)
    end
    if frame.rmOverlayAnimation~=animation or frame.rmOverlayGeneration~=generation
        or animation.ticket~=ticket or animation.paused then
        if timer then addon:CancelTimer(timer) end
        return false
    end
    frame.sequenceTimer=timer
    return true
end

local function ResumeOverlay(frame)
    local animation=frame.rmOverlayAnimation
    if animation and OverlayVisible(frame)==true then StartOverlay(frame,animation) end
end

function addon:HideGlow(frame, id, keepProc)
	CustomGlow.PixelGlow_Stop(frame, id)
	CustomGlow.AutoCastGlow_Stop(frame, id)
	CustomGlow.ButtonGlow_Stop(frame)
    if not keepProc and type(CustomGlow.ProcGlow_Stop)=='function' then CustomGlow.ProcGlow_Stop(frame,tostring(id or '')) end
	if id ~= nil and frame.rmOverlays and frame.rmOverlays[id] then
        local overlay=frame.rmOverlays[id]
        if StopOverlay(overlay) and frame.rmOverlays and frame.rmOverlays[id]==overlay then overlay:Hide() end
	end
end

UpdateOverlay=function(frame, effect, color, mags, setp, xoffs, yoffs, angle, animation, ticket)
	if animation then
        if frame.rmOverlayAnimation~=animation or animation.generation~=frame.rmOverlayGeneration
            or animation.ticket~=ticket or animation.paused then return false end
    elseif effect.type~='texture' and StartNativeOverlay(frame, effect, color, mags, setp, xoffs, yoffs, angle) then
        return true
    elseif effect.type~='texture' then
        animation={effect=effect,color=color,mags=mags,setp=setp,xoffs=xoffs,yoffs=yoffs,angle=angle,
            generation=frame.rmOverlayGeneration}
        frame.rmOverlayAnimation=animation
    end
	local type =  effect.type
    if type == "texture" then
        return UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, angle)
	elseif type == "rotate" and effect.steps and effect.steps > 0 then
		if frame.sequenceIdx then
			frame.sequenceIdx = frame.sequenceIdx >= effect.steps and 1 or (frame.sequenceIdx + 1)
		else
			frame.sequenceIdx = 1
		end
        if effect.reverse then
            if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (effect.steps - (frame.sequenceIdx - 1)))) then return false end
		else
			if not UpdateOverlayRaw(frame, effect.texture, color, mags, setp, xoffs, yoffs, ((2 * math.pi) / effect.steps * (frame.sequenceIdx - 1))) then return false end
        end
		return StartOverlay(frame,animation)
	elseif effect.sequence and #effect.sequence > 0 then
        local sequence = effect.sequence
        if frame.sequenceIdx then
            frame.sequenceIdx = frame.sequenceIdx >= #sequence and 1 or (frame.sequenceIdx + 1)
        else
            frame.sequenceIdx = 1
        end
        if type == "dazzle" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, sequence[frame.sequenceIdx], mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "animate" then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx], color, mags, setp, xoffs, yoffs, angle) then return false end
		elseif type == "pulse" and effect.texture then
			if not UpdateOverlayRaw(frame, effect.texture, color, sequence[frame.sequenceIdx], setp, xoffs, yoffs, angle) then return false end
		elseif type == "custom" and sequence[frame.sequenceIdx].texture and sequence[frame.sequenceIdx].color and sequence[frame.sequenceIdx].magnification then
			if not UpdateOverlayRaw(frame, sequence[frame.sequenceIdx].texture, sequence[frame.sequenceIdx].color, sequence[frame.sequenceIdx].magnification, setp, xoffs, yoffs, math.rad(sequence[frame.sequenceIdx].angle or 0)) then return false end
		else
            StopOverlay(frame)
			return false
		end
		return StartOverlay(frame,animation)
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
	InvalidateOverlay(frame)

	frame:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'HIGH')
    if frame.SetFrameLevel and parent.GetFrameLevel then frame:SetFrameLevel(parent:GetFrameLevel()+1) end

	local t = frame.texture
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
		t:SetBlendMode('ADD')
		frame.texture = t
	end

	t:SetAllPoints(frame)
    if not frame.rmOverlayLifecycle then
        frame.rmOverlayLifecycle=true
        frame:HookScript('OnHide',PauseOverlay)
        frame:HookScript('OnShow',ResumeOverlay)
    end
	return frame
end

local function DestroyOverlay(frame, id)
	if not StopOverlay(frame) then return end
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
		local overlays=parent.rmOverlays
		for id,frame in pairs(overlays) do
			DestroyOverlay(frame, id)
		end
		if parent.rmOverlays==overlays and next(overlays)==nil then parent.rmOverlays = nil end
	end
end

local function OverlaySuperseded(button,id,overlay,generation)
    if (button.rmOverlays and button.rmOverlays[id])~=overlay then return true end
    return overlay and overlay.rmOverlayGeneration~=generation
        and (overlay.rmOverlayGeneration~=generation+1 or overlay.rmOverlayAnimation~=nil)
end

function addon:DestroyAllGlows()
	-- Clear custom glows on fetch.
	for spellid,v in pairs(Flags) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				local overlay=button.rmOverlays and button.rmOverlays[spellid]
				local generation=overlay and overlay.rmOverlayGeneration
				self:HideGlow(button, spellid)
				if not OverlaySuperseded(button,spellid,overlay,generation) then DestroyAllOverlay(button) end
			end
		end
	end

	for spellid,v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellid]) do
				local overlay=button.rmOverlays and button.rmOverlays.next
				local generation=overlay and overlay.rmOverlayGeneration
				self:HideGlow(button, "next")
				if not OverlaySuperseded(button,'next',overlay,generation) then DestroyAllOverlay(button) end
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
			if ActionBarActionEventsFrame then ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW') end
			if LAB then
				LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction
		end
	else
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			if ActionBarActionEventsFrame then ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW') end
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

    local overlay=button.rmOverlays and button.rmOverlays[id]
    local generation=overlay and overlay.rmOverlayGeneration
    color=self:ResolveHighlightColor(color)
    if (button.rmOverlays and button.rmOverlays[id])~=overlay
        or overlay and overlay.rmOverlayGeneration~=generation then return end

	local type = effect.type
	addon:HideGlow(button, id, type=='proc')
    if OverlaySuperseded(button,id,overlay,generation) then return end
	if addon.Functions.collections.index(addon.textured_types, type) then
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
        if ButtonSpells[button]~=spellId then tinsert(Spells[spellId], button) end
        ButtonSpells[button]=spellId
        ButtonItems[button]=itemId
	end
end

local function ValidActionSlot(slot)
    return addon.Platform:CanReadValue(slot) and type(slot) == 'number' and slot > 0 and slot < math.huge and slot%1 == 0
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

-- Retail 12.0 moved the action-slot queries into C_ActionBar. The old
-- globals (HasAction, IsUsableAction, GetActionCooldown, IsActionInRange...)
-- are defined only by Blizzard_DeprecatedActionBar, and only while the
-- loadDeprecationFallbacks CVar is set; GetActionInfo stays a global.
-- Sources: Gethe/wow-ui-source live b9be9379 (12.0.5),
-- Blizzard_DeprecatedActionBar/Deprecated_ActionBar.lua and
-- Blizzard_APIDocumentationGenerated/ActionBarFrameDocumentation.lua.
-- The namespace is preferred wherever it exists; older clients keep the global.
local function actionBarFunction(name, legacy)
    local namespace=C_ActionBar
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)=='function' then return fn end
    if type(legacy)=='function' then return legacy end
end

local function ReadStandardAction(button)
    local kind=button:GetAttribute('type')
    if not addon.Platform:CanReadValue(kind) then return end
    if kind~='action' and kind~='macro' and kind~='item' and kind~='spell' then return end
    local action=button:GetAttribute(kind)
    if kind=='action' then
        local slot=GetActionSlot(button)
        if not slot then return end
        local present=actionBarFunction('HasAction',HasAction)(slot)
        if not addon.Platform:CanReadValue(present) or not present then return end
        kind,action=GetActionInfo(slot)
    end
    if not addon.Platform:CanReadValue(kind) then return end
    if not addon.Platform:CanReadValue(action) then return kind end
    return kind,action
end

local function ResolveStandardAction(kind,action)
    if kind=='macro' then
        local observed=addon.Platform:GetMacroAction(action)
        if observed then return observed.spellID,observed.itemID end
    elseif kind=='item' then
        local item=addon.Platform:GetItemID(action)
        if item then return itemUseSpellID(item),item end
    elseif kind=='spell' then
        return spellMetadataID(action)
    end
end

-- A spell on the bar is also found under its base spell and its current
-- override (C_Spell.GetBaseSpell/GetOverrideSpell, Retail and Forever): a
-- talent can replace a spell on the button, so the slot may report either ID
-- while a step names the other, and Blizzard's suggestion may be either.
-- Only Spells gains the aliases; the button keeps its one identity.
local function AddAlias(alias, button)
    if alias==nil or not addon.Platform:CanReadValue(alias) then return end
    if type(alias)~="number" or alias<=0 or alias>=math.huge or alias%1~=0 or ButtonSpells[button]==alias then return end
    local buttons=Spells[alias]
    if buttons==nil then buttons={};Spells[alias]=buttons end
    for i=1,#buttons do if buttons[i]==button then return end end
    tinsert(buttons,button)
end
local function SpellRelation(name, spell)
    local namespace=C_Spell
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)~='function' then return nil end
    local ok,value=pcall(fn,spell)
    if ok then return value end
end
local function AddSpellAliases(button, spell, action)
    if ButtonSpells[button]~=spell or fetchedPolicy~='restricted' then return end
    if type(action)=='number' then AddAlias(action,button) end
    AddAlias(SpellRelation('GetBaseSpell',spell),button)
    AddAlias(SpellRelation('GetOverrideSpell',spell),button)
end

local function AddStandardButton(button)
    if not button or ButtonSpells[button] then return end
    local ok,kind,action=pcall(ReadStandardAction,button)
    if not ok then return end
    -- Retain macros whose current observation is unavailable so a later pass
    -- can recover without waiting for a bar-edit event.
    if kind=='macro' then MacroButtons[button]=true end
    local spell,item=ResolveStandardAction(kind,action)
    AddButton(spell,button,item)
    if kind=='spell' and spell then AddSpellAliases(button,spell,action) end
end

-- Pet action slots expose a spell only through GetPetActionInfo. Modern
-- clients return the spell ID seventh; a client without it still names the
-- ability, resolved through spell metadata. Tokens (Attack, Follow, Stay...)
-- are commands, not spells, and are never indexed.
local function PetActionSpell(index)
    if type(GetPetActionInfo)~='function' then return end
    local ok,name,_,isToken,_,_,_,spellID=pcall(GetPetActionInfo,index)
    if not ok or not addon.Platform:CanReadValue(name) or not addon.Platform:CanReadValue(spellID) then return end
    if type(spellID)=='number' and spellID>0 then return spellID end
    if type(name)~='string' or name=='' or isToken==true or isToken==1 then return end
    return spellMetadataID(name)
end
local function PetIndex(button,index)
    if type(index)=='number' and index>=1 and index<=10 and index%1==0 then return index end
    local id=type(button.GetID)=='function' and button:GetID() or button.id
    if type(id)=='number' and id>=1 and id<=10 and id%1==0 then return id end
end
local function AddPetButton(button,index)
    if not button or ButtonSpells[button] then return end
    index=PetIndex(button,index);if not index then return end
    PetButtons[button]=index
    AddButton(PetActionSpell(index),button)
end

-- Macro conditionals and cast sequences can change their exposed action
-- without moving a slot or editing the macro. Observe known macro buttons on
-- the existing recommendation cadence; never parse or execute macro bodies.
function addon:RefreshMacroButtons()
    -- Macro observation (Platform/macros.lua) is probe-only. Under the
    -- restricted policy macro buttons resolve to nothing; a scan made under
    -- another policy is redone once so no stale macro mapping survives.
    if readClientPolicy(self.Platform)~='probe' then
        if fetchedPolicy=='probe' then self:Fetch() end
        return
    end
    if next(MacroButtons)==nil then return end
    -- Runs every poll: change lists are only built when a button changed.
    local observations,changes,affected={},nil,nil
    for button in pairs(MacroButtons) do
        local ok,kind,action=pcall(ReadStandardAction,button)
        local spell,item
        if ok then
            local cacheable=kind=='macro' and (type(action)=='string' or
                type(action)=='number' and action>0 and action<math.huge and action%1==0)
            if cacheable then
                local observed=observations[action]
                if observed==nil then
                    observed=self.Platform:GetMacroAction(action) or false
                    observations[action]=observed
                end
                if observed then spell,item=observed.spellID,observed.itemID end
            else
                spell,item=ResolveStandardAction(kind,action)
            end
        end
        local previous=ButtonSpells[button]
        if previous~=spell or ButtonItems[button]~=item then
            changes,affected=changes or {},affected or {}
            changes[#changes+1]={button=button,spell=spell,item=item,previous=previous}
            if previous then affected[previous]=true end
            if spell then affected[spell]=true end
        end
    end
    if not changes then return end
    -- Invalidate the affected identities before reindexing. Other buttons for
    -- those spells need their recommendation/cooldown glow reapplied as well.
    for spell in pairs(affected) do
        for _,button in ipairs(Spells[spell] or {}) do
            self:HideGlow(button,'next')
            self:HideGlow(button,spell)
        end
        SpellsGlowing[spell]=nil
        Flags[spell]=nil
    end
    for _,change in ipairs(changes) do
        local buttons=change.previous and Spells[change.previous]
        if buttons then
            for index=#buttons,1,-1 do
                if buttons[index]==change.button then table.remove(buttons,index) end
            end
            if #buttons==0 then Spells[change.previous]=nil end
        end
        ButtonSpells[change.button],ButtonItems[change.button]=nil,nil
        AddButton(change.spell,change.button,change.item)
    end
    announceIndexChange()
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
			AddPetButton(button, button.id)
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
	-- MultiBar5-7 are Retail's action bars 6-8 (Dragonflight and later).
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft', 'MultiBar5', 'MultiBar6', 'MultiBar7'}
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i]
			AddStandardButton(button)
		end
    end

	for i = 1, 10 do
		AddPetButton(_G['PetActionButton' .. i], i)
	end

	-- Vehicle and override bars (Wrath and later) show their own buttons.
	for i = 1, 6 do
		AddStandardButton(_G['OverrideActionBarButton' .. i])
	end
end

local function FetchElvUIPet()
	for i = 1, 10 do
		AddPetButton(_G['ElvUI_BarPetButton' .. i], i)
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
    ButtonSpells = {}
    MacroButtons = {}
    PetButtons = {}
	Flags = {}
	SpellsGlowing = {}

    fetchedPolicy=readClientPolicy(addon.Platform)
    FetchCount=FetchCount+1;LastFetchAt=type(GetTime)=='function' and GetTime() or nil
    -- Restricted clients (Retail, Forever) run complete rotations too, so
    -- their bars are scanned as well. Action slot contents are not combat
    -- data: every read below is guarded with CanReadValue, so a secret slot
    -- is skipped rather than compared.
	addon:debug(L["Button Fetch triggered."])

	FetchLibActionButton()
	FetchBlizzard()

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('Bartender4') then
		FetchBartender4()
	end

	if IsAddOnLoaded('ElvUI') then
		FetchElvUIPet()
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
    announceIndexChange()
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

-- Whether a step's action is on an action button now: the test the engine
-- applies before it may select a step or show a cooldown (main.lua, "the
-- first mapped and ready spell"), read from the last scan with no bar call.
-- Bound means FindSpell maps one of the IDs GetSpellIds gives the step: a
-- spell under its own ID or any rank (Classic), or under its base or
-- override spell where the client relates them (the aliases above); an item
-- or item set through a button holding that same item; a pet spell through
-- the pet bar. Returns true, or false when no button holds it (the engine
-- skips it), or nil when there is nothing to check: no action (Stop,
-- Branch), IDs that cannot be resolved yet, or no scan has run.
-- Blizzard's suggestion changes every poll, so it is checked against the
-- specialization's suggestion set: false and the known spells that are on
-- no button, when any is missing.
local function assistedBinding(self)
    local platform=self.Platform
    if type(platform)~='table' or type(platform.GetAssistedRotationSpells)~='function' then return nil end
    local spells=platform:GetAssistedRotationSpells()
    if type(spells)~='table' or #spells==0 then return nil end
    local missing
    for _,spell in ipairs(spells) do
        if platform:IsSpellKnown(spell,false)==true then
            local mapped=false
            for _,id in ipairs(platform:GetAssistedSpellCandidates(spell)) do
                if Spells[id] then mapped=true;break end
            end
            if not mapped then missing=missing or {};missing[#missing+1]=spell end
        end
    end
    if missing then return false,missing end
    return true
end
local BINDABLE={spell=true,pet=true,any=true,item=true}
function addon:GetStepBinding(step)
    if type(step)~='table' or FetchCount==0 or step.type=='branch' or step.type=='stop' then return nil end
    if step.type=='assisted' then return assistedBinding(self) end
    if step.action==nil or not BINDABLE[step.type] then return nil end
    local ok,spellIds,itemIds=pcall(self.GetSpellIds,self,step)
    if not ok or type(spellIds)~='table' or #spellIds==0 then return nil end
    for index,id in ipairs(spellIds) do
        if step.type=='item' then
            if self:FindSpell({id},{itemIds and itemIds[index]}) then return true end
        elseif self:FindSpell({id}) then return true end
    end
    return false
end

-- The enabled, reachable steps of one rotation body whose action is on no
-- action button now, in walk order: {step=, section=, ordinal=, missing=}.
-- For /rm why and /rm debug glow; nothing reads it per poll.
function addon:ListUnboundSteps(body)
    local data=self.RotationData
    if type(body)~='table' or type(data)~='table' or type(data.IndexRotationSteps)~='function' then return {} end
    local ok,index=pcall(data.IndexRotationSteps,body,{allowMissingIds=true})
    if not ok or type(index)~='table' or type(index.rows)~='table' then return {} end
    local list={}
    for _,row in ipairs(index.rows) do
        local step=row.step
        if type(step)=='table' and not step.disabled and not row.unreachable then
            local bound,missing=self:GetStepBinding(step)
            if bound==false then list[#list+1]={step=step,section=row.section,ordinal=row.ordinal,missing=missing} end
        end
    end
    return list
end

-- One step's action, named for a report line.
function addon:DescribeStepAction(step)
    if type(step)~='table' then return '?' end
    local function spellName(id)
        local info=self.Platform and self.Platform:GetSpellInfo(id)
        return info and info.name or tostring(id)
    end
    if step.type=='assisted' then return L["Blizzard's suggestion"] end
    if step.type=='item' then
        if type(step.action)=='string' then
            local set=(self.db.profile.itemsets or {})[step.action] or (self.db.global.itemsets or {})[step.action]
            return type(set)=='table' and type(set.name)=='string' and set.name or L['Item']
        end
        return L['Item']
    end
    return spellName(step.action)
end
function addon:DescribeUnboundStep(entry)
    local step=entry.step
    local where=entry.section=='cooldowns' and L['cooldown'] or string.format(L['step %s'],tostring(entry.ordinal or '?'))
    local name=type(step.name)=='string' and step.name:find('%S') and step.name or self:DescribeStepAction(step)
    if entry.missing then
        local names={}
        for i,id in ipairs(entry.missing) do
            local info=self.Platform and self.Platform:GetSpellInfo(id)
            names[i]=info and info.name or tostring(id)
        end
        return string.format('%s (%s: %s)',name,where,table.concat(names,', '))
    end
    return string.format('%s (%s)',name,where)
end

-- Readiness through the bar itself, for actions outside the player's and pet's
-- spellbooks: vehicle, override and possession abilities. Consulted only in a
-- special action context (Core/action_policy.lua), never on the player path.
local function readable(...)
    for i=1,select('#',...) do if not addon.Platform:CanReadValue((select(i,...))) then return false end end
    return true
end
local function cooldownReady(start,duration,now)
    if type(start)~='number' or type(duration)~='number' or type(now)~='number' then return nil end
    if duration==0 or start+duration<=now then return true end
    local gcd=addon.Platform.GetGlobalCooldown and addon.Platform:GetGlobalCooldown()
    if type(gcd)~='table' or not gcd.isEnabled or gcd.duration==0 then return false end
    local gcdExpires=gcd.startTime+gcd.duration
    return gcdExpires>now and start+duration<=gcdExpires+0.001
end
local function petActionReady(index,now)
    if type(GetPetActionCooldown)~='function' then return false end
    local ok,start,duration,enabled=pcall(GetPetActionCooldown,index)
    if not ok or not readable(start,duration,enabled) or enabled==0 or enabled==false then return false end
    if type(GetPetActionSlotUsable)=='function' then
        local usableOk,usable=pcall(GetPetActionSlotUsable,index)
        if usableOk and readable(usable) and (usable==false or usable==nil) then return false end
    end
    return cooldownReady(start,duration,now)==true
end
-- C_ActionBar.GetActionCooldown (Retail 12.0) returns a SpellCooldownInfo
-- whose times may be secret while cooldowns are restricted; isEnabled and
-- isActive never are. With the times hidden, an inactive cooldown is ready
-- and an active one only while it is the running global cooldown.
local function actionCooldownReady(slot,now)
    local namespace=C_ActionBar
    local modern=type(namespace)=='table' and namespace.GetActionCooldown or nil
    if type(modern)=='function' then
        local ok,info=pcall(modern,slot)
        if not ok or type(info)~='table' then return false end
        local enabled,active=info.isEnabled,info.isActive
        if readable(enabled) and (enabled==false or enabled==0) then return false end
        local start,duration=info.startTime,info.duration
        if readable(start,duration) and type(start)=='number' and type(duration)=='number' then
            return readable(enabled) and cooldownReady(start,duration,now)==true
        end
        if not readable(enabled,active) or type(active)~='boolean' then return false end
        if not active then return true end
        if not readable(info.isOnGCD) or info.isOnGCD~=true then return false end
        if type(addon.Platform.GetGlobalCooldown)~='function' then return false end
        local gcd,_,gcdEnabled,gcdActive=addon.Platform:GetGlobalCooldown()
        if type(gcd)=='table' then return gcd.isEnabled==true and gcd.duration>0 and gcd.startTime+gcd.duration>now end
        return gcdEnabled==true and gcdActive==true
    end
    if type(GetActionCooldown)~='function' then return false end
    local cdOk,start,duration,enabled=pcall(GetActionCooldown,slot)
    if not cdOk or not readable(start,duration,enabled) or enabled==0 or enabled==false then return false end
    return cooldownReady(start,duration,now)==true
end
local function actionSlotReady(slot,now)
    local usableFn=actionBarFunction('IsUsableAction',IsUsableAction)
    if not usableFn then return false end
    local ok,usable,noMana=pcall(usableFn,slot)
    if not ok or not readable(usable,noMana) or not usable or noMana then return false end
    if not actionCooldownReady(slot,now) then return false end
    local rangeFn=actionBarFunction('IsActionInRange',IsActionInRange)
    if rangeFn then
        local rangeOk,inRange=pcall(rangeFn,slot)
        if rangeOk and readable(inRange) and (inRange==false or inRange==0) then return false end
    end
    return true
end
function addon:IsBoundActionReady(spellId,now)
    local buttons=Spells[spellId]
    if not buttons then return false end
    for _,button in ipairs(buttons) do
        local index=PetButtons[button]
        if index then
            if petActionReady(index,now) then return true end
        else
            local ok,slot=pcall(GetActionSlot,button)
            if ok and slot and actionSlotReady(slot,now) then return true end
        end
    end
    return false
end
-- The range indicator of the first action button holding a spell: true or
-- false, or nil when no standard button holds it, the slot has no range
-- requirement or the answer is unreadable. Read for the implicit Shoot or
-- Auto Shot only (Core/action_policy.lua), whose button must be on the bars.
function addon:GetBoundActionRange(spellId)
    local buttons=Spells[spellId]
    if not buttons then return nil end
    local rangeFn=actionBarFunction('IsActionInRange',IsActionInRange)
    if not rangeFn then return nil end
    for _,button in ipairs(buttons) do
        if not PetButtons[button] then
            local ok,slot=pcall(GetActionSlot,button)
            if ok and slot then
                local rangeOk,inRange=pcall(rangeFn,slot)
                if rangeOk and readable(inRange) then
                    if inRange==true or inRange==1 then return true end
                    if inRange==false or inRange==0 then return false end
                end
            end
        end
    end
    return nil
end
function addon:GetPetActionButtonIndex(button) return PetButtons[button] end

-- hidden: the spell is the recommendation but Blizzard's Assisted Highlight
-- draws it (Core/assisted_highlight.lua), so RM recorded it without a glow.
function addon:IsGlowing(spellId,itemId,hidden)
    local current=SpellsGlowing[spellId]
    return current~=nil and current.itemId==itemId and (current.hidden==true)==(hidden==true)
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
    local changed=false
    if condition and cooldown and (not previous or previous.id~=cooldown.id or previous.itemId~=itemId) then
        changed=true
        if previous then ClearGlowIndependent(spellId,spellId) end
		Flags[spellId] = {id=cooldown.id,itemId=itemId}
		GlowIndependent(spellId, spellId, cooldown.effect or self.db.profile.effect, cooldown.color,
				cooldown.magnification or self.db.profile.magnification,
				cooldown.setpoint or self.db.profile.setpoint,
				cooldown.xoffs or self.db.profile.xoffs,
				cooldown.yoffs or self.db.profile.yoffs,
				cooldown.angle or self.db.profile.angle, itemId)
	elseif not condition and Flags[spellId] then
        changed=true
		Flags[spellId] = nil
		ClearGlowIndependent(spellId, spellId)
	end

    -- This runs for every cooldown on every poll; tell WeakAuras only when a
    -- cooldown glow actually starts or stops. The payload is unchanged.
	local weakAuras = changed and _G.WeakAuras
	if weakAuras then weakAuras.ScanEvents('ROTATIONMASTER_COOLDOWN_UPDATE', self.Flags); end
end

if type(publishActivePresentation)=='function' then
    publishActivePresentation(addon,addon.GlowCooldown,getfenv(1))
end

function addon:GlowSpell(spellId,itemId)
	if spellId == nil then
		return
	end
    LastGlow.spell,LastGlow.item,LastGlow.hidden,LastGlow.lit=spellId,itemId,false,0
    LastGlow.at=type(GetTime)=='function' and GetTime() or nil

	if Spells[spellId] ~= nil and addon.db.global.effects[self.db.profile.effect] then
		for _, button in pairs(Spells[spellId]) do
            if not itemId or ButtonItems[button]==itemId then
			addon:Glow(button, 'next', addon.db.global.effects[self.db.profile.effect], self.db.profile.color,
				 self.db.profile.magnification, self.db.profile.setpoint,
				 self.db.profile.xoffs, self.db.profile.yoffs, self.db.profile.angle)
                LastGlow.lit=LastGlow.lit+1
            end
		end

		SpellsGlowing[spellId] = {itemId=itemId}
        LastGlow.result='lit'
		addon:verbose(spellId .. " is now glowing")
    else
        LastGlow.result=Spells[spellId]==nil and 'no-button' or 'no-effect'
	end
end

function addon:GlowClear()
	for spellId, v in pairs(SpellsGlowing) do
		if v then
			for _, button in pairs(Spells[spellId]) do
				addon:HideGlow(button, 'next')
			end
			SpellsGlowing[spellId] = nil
            LastGlow.clearedAt=type(GetTime)=='function' and GetTime() or nil
			addon:verbose(spellId .. " is no longer glowing")
		end
	end
end

function addon:GlowNextSpell(spellId,itemId,hidden)
	self:GlowClear()
	if hidden then
		if spellId~=nil and Spells[spellId]~=nil then SpellsGlowing[spellId]={itemId=itemId,hidden=true} end
        LastGlow.spell,LastGlow.item,LastGlow.hidden,LastGlow.lit,LastGlow.result=spellId,itemId,true,0,'hidden'
		return
	end
	self:GlowSpell(spellId,itemId)
end

function addon:EndHighlightSlot()
	for _, button in pairs(Highlight) do
        self:HideGlow(button, "highlight")
    end
    Highlight = {}
end

-- Item-set binding observes the indexed action buttons and resolves their
-- slots exactly as highlighting does. Read-only; no secure state is touched.
function addon:ResolveActionButtonSlot(button) return GetActionSlot(button) end
function addon:ForEachActionButton(callback)
    for button in pairs(ButtonSpells) do
        local ok,kind=pcall(button.GetAttribute,button,'type')
        if ok and kind=='action' then callback(button,GetActionSlot(button)) end
    end
end

function addon:HighlightSlots(slots)
	addon:EndHighlightSlot()
	-- A button listed under its base or override spell too is lit once.
	local seen = {}
	for _, buttons in pairs(Spells) do
		for _, button in pairs(buttons) do
			local type = not seen[button] and button:GetAttribute('type')
			seen[button] = true
			if type == 'action' then
				local bslot = GetActionSlot(button)

				if bslot and addon.Functions.collections.index(slots, bslot) ~= nil then
                    self:Glow(button, "highlight", HighlightOverlay, {}, 1.0, "CENTER", 0, 0)
                	table.insert(Highlight, button)
				end
			end
		end
	end
end


-- BEGIN GLOW DIAGNOSTIC SUPPORT
-- Read-only observations for /rm debug glow (Diagnostics/glow.lua). Nothing
-- here runs unless that command does, and every native read is protected.
local function diagnosticName(frame)
    if type(frame)~='table' then return tostring(frame) end
    if type(frame.GetName)=='function' then
        local ok,name=pcall(frame.GetName,frame)
        if ok and type(name)=='string' then return name end
    end
    return tostring(frame)
end
local function diagnosticRead(frame,method)
    if type(frame)~='table' or type(frame[method])~='function' then return nil end
    local ok,value=pcall(frame[method],frame)
    if ok and addon.Platform:CanReadValue(value) then return value end
end
-- The Blizzard bars a Retail client builds (Blizzard_ActionBar ActionBar.lua
-- names them ActionButtonN and <bar>ButtonN), whether or not the scan reads them.
local DIAGNOSED_BARS={'Action','MultiBarBottomLeft','MultiBarBottomRight','MultiBarRight','MultiBarLeft','MultiBar5','MultiBar6','MultiBar7'}
function addon:GetGlowDiagnosticBars() return DIAGNOSED_BARS end

-- One standard action button, read exactly the way the scan reads it.
function addon:DiagnoseActionButton(button)
    local record={name=diagnosticName(button),shown=diagnosticRead(button,'IsShown'),visible=diagnosticRead(button,'IsVisible')}
    if type(button)~='table' or type(button.GetAttribute)~='function' then record.error='not a button';return record end
    local ok,kind=pcall(button.GetAttribute,button,'type')
    record.kind=not ok and 'error' or self.Platform:CanReadValue(kind) and kind or 'secret'
    local slotOk,slot=pcall(GetActionSlot,button)
    if slotOk then record.slot=slot else record.slotError=tostring(slot) end
    local readOk,actionKind,action=pcall(ReadStandardAction,button)
    if not readOk then record.error=tostring(actionKind)
    else
        record.actionKind,record.action=actionKind,action
        if actionKind then
            local resolved,spell,item=pcall(ResolveStandardAction,actionKind,action)
            if resolved then record.spell,record.item=spell,item else record.error=tostring(spell) end
        end
    end
    record.indexed=ButtonSpells[button]
    return record
end

-- Counts in the live index, and the buttons one spell maps to.
function addon:GetButtonIndexDiagnostic()
    local buttons,spells,ids=0,0,{}
    for _ in pairs(ButtonSpells) do buttons=buttons+1 end
    for spell in pairs(Spells) do spells=spells+1;if #ids<24 then ids[#ids+1]=spell end end
    table.sort(ids)
    return {buttons=buttons,spells=spells,ids=ids,policy=fetchedPolicy,fetches=FetchCount,lastFetch=LastFetchAt}
end
function addon:GetSpellButtonNames(spellId)
    local names={}
    for _,button in ipairs(Spells[spellId] or {}) do names[#names+1]=diagnosticName(button) end
    return names
end

-- What the last recommendation glow did, and what is lit now, frame by frame.
function addon:GetGlowDiagnostic()
    local result={last={},glowing={}}
    for key,value in pairs(LastGlow) do result.last[key]=value end
    for spell,state in pairs(SpellsGlowing) do
        local entry={spell=spell,item=state.itemId,hidden=state.hidden==true,buttons={}}
        for _,button in ipairs(Spells[spell] or {}) do
            local overlay=type(button.rmOverlays)=='table' and button.rmOverlays.next or nil
            local row={name=diagnosticName(button),shown=diagnosticRead(button,'IsShown'),visible=diagnosticRead(button,'IsVisible'),
                strata=diagnosticRead(button,'GetFrameStrata'),level=diagnosticRead(button,'GetFrameLevel'),
                width=diagnosticRead(button,'GetWidth'),height=diagnosticRead(button,'GetHeight'),
                pixel=rawget(button,'_PixelGlownext')~=nil,autocast=rawget(button,'_AutoCastGlownext')~=nil,
                blizzard=rawget(button,'_ButtonGlow')~=nil,proc=rawget(button,'_ProcGlownext')~=nil}
            if overlay then
                row.overlay={shown=diagnosticRead(overlay,'IsShown'),visible=diagnosticRead(overlay,'IsVisible'),
                    strata=diagnosticRead(overlay,'GetFrameStrata'),level=diagnosticRead(overlay,'GetFrameLevel'),
                    width=diagnosticRead(overlay,'GetWidth'),height=diagnosticRead(overlay,'GetHeight'),
                    alpha=diagnosticRead(overlay,'GetAlpha'),native=overlay.rmNative~=nil,timer=overlay.sequenceTimer~=nil,
                    texture=overlay.rmOverlayTexture}
            end
            entry.buttons[#entry.buttons+1]=row
        end
        result.glowing[#result.glowing+1]=entry
    end
    return result
end
-- END GLOW DIAGNOSTIC SUPPORT

-- BEGIN CPU ACTIVITY HANDOFF
-- Only the private RM button maps and their current logical slots are inspected.
-- Shared glow fields establish association, never exclusive caller ownership.
do
    local raw,nextKey,kind,equal,protect,text=rawget,next,type,rawequal,pcall,tostring
    local ownedGlow,ownedFetch=addon.Glow,addon.Fetch
    local starts={pixel=CustomGlow.PixelGlow_Start,autocast=CustomGlow.AutoCastGlow_Start,blizzard=CustomGlow.ButtonGlow_Start}
    local bind=raw(addon,'BindCPUActivityDiagnostic')
    if kind(bind)=='function' then bind(addon,'visual',function(api)
        if not equal(raw(addon,'Glow'),ownedGlow) or not equal(raw(addon,'Fetch'),ownedFetch) then return end
        for name,method in nextKey,starts do
            local key=name=='pixel' and 'PixelGlow_Start' or name=='autocast' and 'AutoCastGlow_Start' or 'ButtonGlow_Start'
            if not equal(raw(CustomGlow,key),method) then return end
        end
        local result={buttons=0,slots=0,logical=0,overlays=0,sequence=0,pixel=0,autocast=0,blizzard=0,proc=0,capped=false,callbacks={overlay=UpdateOverlay},ambiguous={}}
        if kind(api)~='table' or kind(raw(api,'GetParent'))~='function' or kind(raw(api,'IsVisible'))~='function' or kind(raw(api,'GetScript'))~='function' then result.unsupported=true;return result end
        local highlighted,seen={},{};local n=0
        for _,button in nextKey,Highlight do n=n+1;if n>128 then result.capped=true;break end;highlighted[button]=true end
        local function inspect(frame,button,name)
            result.slots=result.slots+1;if result.slots>512 then result.slots=512;result.capped=true;return end
            if kind(frame)~='table' or seen[frame] then return end
            local ok,parent=protect(api.GetParent,frame);if not ok or not equal(parent,button) then return end
            seen[frame]=true
            if name=='overlays' and raw(frame,'sequenceTimer')~=nil then result.sequence=result.sequence+1 end
            local visible,shown=protect(api.IsVisible,frame)
            if not visible then result.unsupported=true;return end
            if shown~=true then return end
            result[name]=result[name]+1
            if name=='overlays' or name=='proc' then return end
            local success,fn=protect(api.GetScript,frame,'OnUpdate')
            if not success or kind(fn)~='function' then return end
            if result.callbacks[name] and not equal(result.callbacks[name],fn) then result.callbacks[name]=nil;result.ambiguous[name]=true
            elseif not result.ambiguous[name] then result.callbacks[name]=fn end
        end
        for button,spell in nextKey,ButtonSpells do
            result.buttons=result.buttons+1;if result.buttons>128 then result.buttons=128;result.capped=true;break end
            if result.capped and result.slots>=512 then break end
            if kind(button)=='table' then
                local ids={}
                local glowing,flag=SpellsGlowing[spell],Flags[spell]
                if glowing and (glowing.itemId==nil or equal(glowing.itemId,ButtonItems[button])) then ids[#ids+1]='next' end
                if flag and (flag.itemId==nil or equal(flag.itemId,ButtonItems[button])) then ids[#ids+1]=spell end
                if highlighted[button] then ids[#ids+1]='highlight' end
                for _,id in nextKey,ids do
                    result.logical=result.logical+1
                    local overlays=raw(button,'rmOverlays');inspect(kind(overlays)=='table' and raw(overlays,id),button,'overlays')
                    local key=text(id)
                    inspect(raw(button,'_PixelGlow'..key),button,'pixel')
                    inspect(raw(button,'_AutoCastGlow'..key),button,'autocast')
                    inspect(raw(button,'_ProcGlow'..key),button,'proc')
                    if result.slots>=512 then result.capped=true;break end
                end
                if #ids>0 then inspect(raw(button,'_ButtonGlow'),button,'blizzard') end
            end
        end
        return result
    end) end
end
-- END CPU ACTIVITY HANDOFF
