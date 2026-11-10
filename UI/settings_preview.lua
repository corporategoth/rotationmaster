-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Settings > Preview page: the preview window (how many spells, opacity, background art, color, lock, direction, position,
-- Masque skin, title, target health and its own readiness options) and the forecast that fills it with predictions, laid out
-- in two columns on a pooled settings form `p`. Every field edits the page's settings draft (p:SettingsData()) and applies
-- its side effect through p:RunSettingsEffect, so Discard undoes it; the exceptions are the preview lock, the preview
-- position reset, the Masque skin and the sample toggle, which act immediately on live state and say why where they are
-- built. Loaded from RotationMaster.toc after UI/settings_general.lua; the settings window picks it from the section table
-- in UI/settings_collections.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Draws the Preview page into the settings pane. Runs on every redraw of the page, so each call rebuilds all controls from
-- the draft in `p:SettingsData()` and registers its cleanups on p.cleanups; nothing it creates may outlive the drawing
-- (every callback checks the drawing's generation through p:Guard or p:Valid).
-- @param p table  The settings pane.
function addon:BuildPreviewSettings(p)
    local store = p:SettingsData()
    local profile = store.profile

    -- Applies a preview setting change to the preview window: refresh it, create it when preview spells were just
    -- raised above zero, resize it, or release it when set back to zero.
    local function previewChanged()
        p:RunSettingsEffect('preview', function()
            if self.RefreshPreviewWindow then
                self:RefreshPreviewWindow()
            elseif (profile.preview_spells or 0) > 0 then
                if self.nextWindow then
                    self.nextWindow:SetWidth(profile.preview_spells * 128)
                else
                    self:CreatePreviewWindow()
                end
            elseif self.nextWindow then
                self.nextWindow:Release()
                self.nextWindow = nil
            end
        end)
    end

    p:Heading(L['Appearance'])

    local classNames = LOCALIZED_CLASS_NAMES_MALE or {}

    -- The client names only the classes it has; the others are named here.
    local classLabels = {
        DEATHKNIGHT = L['Death Knight'],
        DEMONHUNTER = L['Demon Hunter'],
        DRUID = L['Druid'],
        EVOKER = L['Evoker'],
        HUNTER = L['Hunter'],
        MAGE = L['Mage'],
        MONK = L['Monk'],
        PALADIN = L['Paladin'],
        PRIEST = L['Priest'],
        ROGUE = L['Rogue'],
        SHAMAN = L['Shaman'],
        WARLOCK = L['Warlock'],
        WARRIOR = L['Warrior'],
        ROTATION_MASTER = L['Rotation Master'],
    }

    local ok, myClass = pcall(UnitClass, 'player')
    myClass = ok and type(myClass) == 'string' and myClass or L['Unknown']
    local choice = profile.preview_background == false and 'solid' or profile.preview_art or 'class'

    local entries = { { value = 'class', text = string.format(L['My class (%s)'], myClass) } }

    for _, token in ipairs(self.GetPreviewArtChoices and self:GetPreviewArtChoices() or {}) do
        entries[#entries + 1] = {
            value = token,
            text = classNames[token] or classLabels[token] or token,
        }
    end

    entries[#entries + 1] = { value = 'solid', text = L['Solid background'] }

    p:Choice('preview_art', L['Preview background'], choice, entries, function(value)
        profile.preview_art = value
        -- The old background switch: a painting turns it back on, so it never overrules the choice.
        profile.preview_background = value ~= 'solid'
        previewChanged()
        p:Draw()
    end)

    -- The chosen painting, as a row of its five cells in the middle of the page; a plain box has its color chosen here instead.
    local theme = choice ~= 'solid' and self.GetPreviewArtFor and self:GetPreviewArtFor(choice) or nil

    if theme then
        local cell = math.max(24, math.min(96, math.floor((p.width - 8) / 5)))
        local rowY = p:Row(nil, cell + 12)

        local frame = p:Acquire('previewArt', function()
            local created = CreateFrame('Frame', nil, p.child)
            created.cells = {}

            for index = 1, 5 do
                created.cells[index] = created:CreateTexture(nil, 'ARTWORK')
            end

            return created
        end)

        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', math.floor((p.width - cell * 5) / 2), -rowY - 4)
        frame:SetSize(cell * 5, cell)
        p.fields.preview_art_image = frame

        for index, texture in ipairs(frame.cells) do
            texture:ClearAllPoints()
            texture:SetPoint('TOPLEFT', frame, 'TOPLEFT', (index - 1) * cell, 0)
            texture:SetSize(cell, cell)
            texture:SetTexture(self:GetPreviewArtDirectory() .. theme.wide[index])
            texture:Show()
        end
    else
        p:Color('preview_color', L['Preview window color'], profile.preview_color, function(v)
            profile.preview_color = v
            previewChanged()
        end)
    end

    p:Slider('preview_opacity', L['Preview window opacity'], profile.preview_opacity or 1, 0, 1, .05, function(v)
        profile.preview_opacity = v
        previewChanged()
    end)

    -- The title and the target health bar share a row; the preview's own readiness options have a row of their own, with
    -- the three they hold under it. The preview can judge readiness by its own three options (Core/action_policy.lua, both
    -- engines in main.lua); off, it follows the ones above. The three are disabled while it is off.
    local pairY = p.y

    local title = p:Check(
        'preview_title',
        L['Show a title above the preview'],
        profile.preview_title ~= false,
        function(v)
            profile.preview_title = v
            previewChanged()
        end
    )

    p.y = pairY

    local health = p:Check(
        'preview_target_health',
        L['Show target health under the preview'],
        profile.preview_target_health == true,
        function(v)
            profile.preview_target_health = v
            previewChanged()
        end
    )

    local half = p.width / 2

    for i, control in ipairs({ title, health }) do
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', (i - 1) * half, -pairY)
        control:SetWidth(half - 8)
        control:GetFontString():SetWidth(half - 30)
    end

    p.y = pairY + 30

    local previewY = p.y
    local third = p.width / 3

    local locked = p:Check(
        'preview_locked',
        L['Lock position and size'],
        self.db.profile.preview_locked == true,
        function() end
    )

    -- Synchronizes the Lock position and size setting everywhere at once (live profile, draft and draft baseline) and
    -- repaints the check box. Locking is an immediate window action, like moving or resetting it; only this field is
    -- synchronized so unrelated General edits remain pending.
    -- @param value boolean  The new locked state.
    local function syncLocked(value)
        for _, settings in ipairs({ self.db.profile, profile, p.draftBaseline and p.draftBaseline.profile or {} }) do
            settings.preview_locked = value
        end

        locked:SetChecked(value)

        if p.BindUnsaved then
            p:BindUnsaved('preview_locked', locked, value, 'Check')
        end
    end

    self:SetUIScript(locked, 'OnClick', p:Guard(function()
        syncLocked(self.db.profile.preview_locked ~= true)

        if self.RefreshPreviewWindow then
            self:RefreshPreviewWindow()
        end
    end))

    -- The preview's right-click menu locks too; keep this page's field and
    -- draft in step so a later Apply cannot write the old value back.
    local lockChanged = p:Guard(function(value)
        syncLocked(value == true)
    end)

    self.previewLockChanged = lockChanged

    p.cleanups[#p.cleanups + 1] = function()
        if self.previewLockChanged == lockChanged then
            self.previewLockChanged = nil
        end
    end

    local orientation = p:Toggle(
        'preview_vertical',
        nil,
        profile.preview_vertical == true,
        L['Horizontal'],
        L['Vertical'],
        function(v)
            profile.preview_vertical = v
            previewChanged()
            p:Draw()
        end
    )

    local reset = p:Button('preview_reset', L['Reset'], function() end)
    local resetToken = p.generation

    -- Resets the preview window to the middle of the screen at the default icon size. Moving the preview is immediate,
    -- like dragging the window: only these baselines are synchronized so an unrelated staged setting stays staged.
    self:SetUIScript(reset, 'OnClick', function()
        if not p:Valid(resetToken) then
            return
        end

        for _, settings in ipairs({ self.db.profile, profile, p.draftBaseline and p.draftBaseline.profile or {} }) do
            settings.preview_window = nil
            settings.preview_icon_size = 64
        end

        if self.nextWindow then
            if self.nextWindow.Configure then
                self.nextWindow:Configure()
            end

            self.nextWindow:ClearAllPoints()
            self.nextWindow:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
        end

        if p.fields.apply then
            if p:IsSettingsDraftDirty() then
                p.fields.apply:Enable()
            else
                p.fields.apply:Disable()
            end
        end

        if p.RefreshUnsaved then
            p:RefreshUnsaved()
        end
    end)

    reset.tooltip = L['Reset preview position']

    for i, control in ipairs({ locked, orientation, reset }) do
        control:ClearAllPoints()
        control:SetPoint('TOPLEFT', (i - 1) * third, -previewY)
        control:SetWidth(third - 8)
    end

    locked:GetFontString():SetWidth(third - 30)
    p.y = previewY + 30

    p:Column(1)
    p:Heading(L['Preview'])

    p:Slider('preview_spells', L['Preview Spells'], profile.preview_spells, 0, 5, 1, function(v)
        profile.preview_spells = v
        previewChanged()
    end)

    -- Masque owns this immediate appearance preference. Keep it outside the
    -- General draft so Discard never rewinds another addon's skin settings.
    local skinY = p:Row(L['Skin'], 28)

    local skin = p:Acquire('previewSkins', function()
        return self:CreateWorkbenchLabeledIconButton(p.child, 'chevron-down', '', 220)
    end)

    p.fields.preview_skin = skin
    local skinToken = p.generation

    -- Tells whether this drawing of the page is still the live one; Masque and the skin chooser answer late.
    -- @return boolean  True while the skin controls may be updated.
    local function currentSkinPage()
        return p:Valid(skinToken)
    end

    -- Returns the skin choices and whether skinning is available.
    -- @return table[]|nil  The choices { value, text }: Masque's list when the Masque option is on and the addon is
    --   present, otherwise the single built-in skin; nil when the page is no longer current.
    -- @return boolean|nil  True when skinning is available (the chooser is disabled otherwise).
    local function skinChoices()
        if not currentSkinPage() then
            return
        end

        if self.db.profile.preview_masque == true and self.GetPreviewSkinChoices then
            local choices, available = self:GetPreviewSkinChoices()

            if not currentSkinPage() then
                return
            end
            if available then
                return choices, true
            end
        end

        return { { value = 'Blizzard Classic', text = L['Blizzard Classic'] } }, false
    end

    -- Shows the current skin on the chooser button and enables it only when skinning is available.
    -- @return table[]|nil  The skin choices; nil when the page is no longer current.
    local function paintSkin()
        local choices, available = skinChoices()

        if not currentSkinPage() or not choices then
            return
        end

        local value = available and self.GetPreviewSkin and self:GetPreviewSkin() or 'Blizzard Classic'

        if not currentSkinPage() then
            return
        end

        local selected

        for _, entry in ipairs(choices) do
            if entry.value == value then
                selected = entry
                break
            end
        end

        self:PaintSelectorSelection(skin, selected, selected and selected.text or L['Blizzard Classic'])

        if available then
            skin:Enable()
        else
            skin:Disable()
        end

        return choices
    end

    if not paintSkin() then
        return
    end

    local skinChanged = p:Guard(function()
        paintSkin()
    end)

    self.previewSkinChanged = skinChanged

    p.cleanups[#p.cleanups + 1] = function()
        if self.previewSkinChanged == skinChanged then
            self.previewSkinChanged = nil
        end
    end

    self:SetUIScript(skin, 'OnClick', p:Guard(function()
        local choices = paintSkin()

        if not choices or not currentSkinPage() or not skin:IsEnabled() then
            return
        end

        p:ShowChoices(skin, choices, function(value)
            local ok = self.SetPreviewSkin and self:SetPreviewSkin(value)

            if paintSkin() and currentSkinPage() then
                p:Message(ok and '' or L['Preview skin is unavailable.'], ok)
            end
        end)
    end))

    local sample = p:Button('preview_sample', L['Preview'], function() end)
    local buttonWidth = math.min((p.width - 8) / 3, math.max(96, sample:GetFontString():GetStringWidth() + 24))
    local skinX = math.min(220, math.max(72, p.width * .25))
    skin:ClearAllPoints()
    skin:SetPoint('TOPLEFT', skinX, -skinY)
    skin:SetWidth(math.max(1, p.width - skinX - buttonWidth - 8))
    sample:ClearAllPoints()
    sample:SetPoint('TOPLEFT', p.width - buttonWidth, -skinY)
    sample:SetWidth(buttonWidth)
    p.y = skinY + 28

    if type(self.SetPreviewSampleEnabled) == 'function' and type(self.IsPreviewSampleEnabled) == 'function' then
        self:SetUIScript(sample, 'OnClick', p:Guard(function()
            self:SetPreviewSampleEnabled(not self:IsPreviewSampleEnabled())
        end))
    else
        sample:Disable()
    end

    p:Check(
        'preview_readiness',
        L['Preview uses its own readiness options'],
        profile.preview_readiness == true,
        function(v)
            profile.preview_readiness = v
            p:Draw()
        end
    )

    local previewReadinessY = p.y

    for _, entry in ipairs({
        { 'preview_ignore_mana', 'Ignore Mana' },
        { 'preview_ignore_range', 'Ignore Range' },
        { 'preview_ignore_moving', 'Ignore Moving' },
    }) do
        local key = entry[1]

        local box = p:Check(key, L[entry[2]], profile[key] == true, function(v)
            profile[key] = v

            if key == 'preview_ignore_mana' then
                p:Draw()
            end
        end)

        if profile.preview_readiness ~= true then
            box:Disable()
        end
    end

    self:LayoutWorkbenchRow(
        { p.fields.preview_ignore_mana, p.fields.preview_ignore_range, p.fields.preview_ignore_moving },
        0,
        previewReadinessY,
        p.width,
        { text = 22 }
    )

    p.y = previewReadinessY + 30

    -- A spell the player cannot afford is only shown while Ignore Mana is on (the preview's own when it has them), so the
    -- gray only has something to act on then.
    local gray = p:Check(
        'preview_gray_unaffordable',
        L['Gray out preview spells you cannot afford yet'],
        profile.preview_gray_unaffordable ~= false,
        function(v)
            profile.preview_gray_unaffordable = v
            previewChanged()
        end
    )

    if not (profile.preview_readiness == true and profile.preview_ignore_mana == true
        or profile.preview_readiness ~= true and profile.ignore_mana == true) then
        gray:Disable()
    end

    p:Column(2)
    p:Heading(L['Forecast'])

    p:Check(
        'forecast',
        L['Predict upcoming recommendations from the expected state'],
        profile.forecast == true,
        function(v)
            profile.forecast = v

            p:RunSettingsEffect('forecast', function()
                self:ApplyForecastSettings()
            end)
        end
    )

    p:Check(
        'forecast_confidence',
        L['Fade predictions that are less certain'],
        profile.forecast_confidence ~= false,
        function(v)
            profile.forecast_confidence = v
        end
    )

    p:Check('forecast_percent', L['Show how sure each prediction is'], profile.forecast_percent ~= false, function(v)
        profile.forecast_percent = v
    end)

    p:Check(
        'forecast_delay',
        L['Show the seconds until each prediction is cast'],
        profile.forecast_delay ~= false,
        function(v)
            profile.forecast_delay = v
        end
    )

    -- What the forecast has learned, in a window that can be copied, and a button to forget it.
    p:Button('forecast_learned', L['Show what the forecast has learned'], function()
        if self.ShowForecastLearned then
            self:ShowForecastLearned()
        end
    end)

    p:Button('forecast_clear', L['Forget what the forecast has learned'], function()
        self:ClearForecast()
    end)
end
