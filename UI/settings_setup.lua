-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Settings entry points that are not a window of their own: opening the preview window from the General page, the
-- specialization list the rotation editor and selection code offer, and the one-time options setup (launcher panel
-- registered with the game's Settings UI). Owns no saved data. Loaded from RotationMaster.toc after the settings pages
-- (UI/settings_roster_order.lua) and before UI/settings_layout.lua; every function is a method on the addon table.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Opens (or reopens) the native preview window (UI/preview.lua); the compatibility name for the settings page.
-- @return any  What CreateNativePreviewWindow returns.
function addon:CreatePreviewWindow()
    return self:CreateNativePreviewWindow()
end

-- Returns the specialization entries the rotation editor and Core/rotation_selection.lua list for a class. Always
-- returns at least the id-0 "Rotations" entry when the client has no spec model; entries are named here ("No
-- specialization" for a Retail initial spec, else the saved label or the id).
-- @param classID number|nil  The class id; nil means the player's class.
-- @return table[]  The entries, each { id, name, ... }.
function addon:GetRotationEditorSpecs(classID)
    if classID == nil and type(UnitClass) == "function" then
        local ok, _, _, id = pcall(UnitClass, "player")

        if ok then
            classID = id
        end
    end

    local entries = self.Platform:GetRotationSpecializations(classID)

    if not entries then
        return { { id = 0, name = L["Rotations"] } }
    end

    for _, entry in ipairs(entries) do
        if entry.id == 0 then
            entry.name = L["Rotations"]
        elseif entry.initial then
            entry.name = L["No specialization"]
        elseif not entry.name then
            local label = self.db.char.specs[entry.id]
            entry.name = type(label) == "string" and label or tostring(entry.id)
        end
    end

    return entries
end

-- Creates the settings launcher and registers it with the game's options UI. Idempotent; runs on PLAYER_ENTERING_WORLD
-- and before the configuration window opens, so it must stay cheap after the first call.
function addon:SetupOptions()
    if self.optionsConfigured then
        return
    end

    self.optionsConfigured = true

    self.settingsLauncher = self:CreateSettingsLauncher()
    self:RegisterOptionsCategory(self.settingsLauncher.frame)
end
