-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Extra display under and on the preview window: the target health bar's place under it, and graying a recommended spell
-- you cannot afford yet (preview_gray_unaffordable). Display only; nothing here feeds a rotation decision. Loaded from the
-- TOC after UI/preview.lua, which calls UpdatePreviewBars and ShadePreviewIcon.
local _, addon = ...

-- Stacks the target health bar under the window.
-- @param window table  The preview window.
function addon:UpdatePreviewBars(window)
    local bar = window.healthBar

    if bar and bar:IsShown() then
        bar:ClearAllPoints()
        bar:SetPoint('TOPLEFT', window.frame, 'BOTTOMLEFT', 0, -2)
        bar:SetPoint('TOPRIGHT', window.frame, 'BOTTOMRIGHT', 0, -2)
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
