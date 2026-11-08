-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Extra display under and on the preview window, all fed by values passed straight to widgets (Platform/gates.lua), so
-- they show real numbers in combat on Retail and Forever even though RM never reads them: your power bar
-- (preview_player_power), your target's cast bar (preview_target_cast), and graying a recommended spell you cannot
-- afford yet (preview_gray_unaffordable). Display only; nothing here feeds a rotation decision. Loaded from the TOC
-- after UI/preview.lua, which calls UpdatePreviewBars and ShadePreviewIcon.
local _, addon = ...

-- Makes a thin status bar under the preview window.
-- @param window table  The preview window.
-- @param r number  Red of the bar color.
-- @param g number  Green.
-- @param b number  Blue.
-- @return table|nil  The bar; nil when the client refuses to make one.
local function makeBar(window, r, g, b)
    local made, bar = pcall(CreateFrame, 'StatusBar', nil, window.frame)

    if not made or not bar then
        return nil
    end

    bar:SetHeight(6)

    if bar.SetStatusBarTexture then
        pcall(bar.SetStatusBarTexture, bar, 'Interface\\TargetingFrame\\UI-StatusBar')
    end
    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(r, g, b)
    end

    return bar
end

-- Fills your power bar from the passthrough values; hides it when they cannot be had.
-- @param bar table  The bar.
-- @return boolean  Whether the bar shows.
local function fillPower(bar)
    local current, maximum, color = addon.Platform:GetUnitPowerPassthrough('player')

    if current == nil or not pcall(bar.SetMinMaxValues, bar, 0, maximum) or not pcall(bar.SetValue, bar, current) then
        return false
    end

    if color and bar.SetStatusBarColor then
        bar:SetStatusBarColor(color.r, color.g, color.b)
    end

    return true
end

-- Fills your target's cast bar: the game's duration object animates it where the client has one, else the readable
-- start and end times place it on this poll.
-- @param bar table  The bar.
-- @return boolean  Whether the bar shows.
local function fillCast(bar)
    local kind, a, b = addon.Platform:GetUnitCastPassthrough('target')

    if kind == 'duration' and type(bar.SetTimerDuration) == 'function' then
        return pcall(bar.SetTimerDuration, bar, a) == true
    end

    if kind == 'times' and type(GetTime) == 'function' then
        local now = GetTime() * 1000

        return pcall(bar.SetMinMaxValues, bar, a, b) and pcall(bar.SetValue, bar, math.min(b, math.max(a, now)))
            or false
    end

    return false
end

-- Bars under the preview, top to bottom after the target health bar: { field, option, color, fill }.
local BARS = {
    { field = 'powerBar', option = 'preview_player_power', color = { 0, .45, 1 }, fill = fillPower },
    { field = 'castBar', option = 'preview_target_cast', color = { 1, .7, 0 }, fill = fillCast },
}

-- Shows or hides the power and cast bars for this poll, and stacks every shown bar (target health first) under the
-- window.
-- @param window table  The preview window.
function addon:UpdatePreviewBars(window)
    local profile = window.profile or {}
    local anchor = window.healthBar and window.healthBar:IsShown() and window.healthBar or nil

    if anchor then
        anchor:ClearAllPoints()
        anchor:SetPoint('TOPLEFT', window.frame, 'BOTTOMLEFT', 0, -2)
        anchor:SetPoint('TOPRIGHT', window.frame, 'BOTTOMRIGHT', 0, -2)
    end

    for _, spec in ipairs(BARS) do
        local bar = window[spec.field]

        if profile[spec.option] == true then
            if not bar then
                bar = makeBar(window, spec.color[1], spec.color[2], spec.color[3])
                window[spec.field] = bar
            end

            if bar and spec.fill(bar) then
                local above = anchor or window.frame
                bar:ClearAllPoints()
                bar:SetPoint('TOPLEFT', above, 'BOTTOMLEFT', 0, -2)
                bar:SetPoint('TOPRIGHT', above, 'BOTTOMRIGHT', 0, -2)
                bar:Show()
                anchor = bar
            elseif bar then
                bar:Hide()
            end
        elseif bar then
            bar:Hide()
        end
    end
end

-- Grays a preview icon whose spell you lack the power to cast (IsSpellUsable's second answer, readable on every
-- client), when preview_gray_unaffordable is on; clears it otherwise. Such a spell is only shown with Ignore Mana on.
-- @param icon table  The preview icon.
-- @param spellId number|nil  Its spell; nil (a sample, an item, a cleared icon) clears the gray.
-- @param profile table|nil  The window's profile.
function addon:ShadePreviewIcon(icon, spellId, profile)
    local gray = false

    if spellId and profile and profile.preview_gray_unaffordable ~= false then
        local _, noPower = self.Platform:IsSpellUsable(spellId)
        gray = noPower == true
    end

    for _, texture in ipairs({ icon.texture, icon.masqueSurface and icon.masqueSurface.texture }) do
        if texture and texture.SetDesaturated then
            texture:SetDesaturated(gray)
        end
    end
end
