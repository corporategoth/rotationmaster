-- A small diagnostic window for the Lua editor's input problems: a plain, unhooked multi-line EditBox with a fixed
-- sample so a player can compare caret and Up/Down behavior in the stock chat font and the RM font. It must stay free
-- of the editor's completion, gutter, paint and diagnostic hooks and must never read or save an owner's buffer; the
-- sample text is temporary. Loaded in the "Code authoring UI" block of RotationMaster.toc, before
-- lua_input_diagnostics.lua. Nothing in the shipped addon opens it; tests/lua_input_probe.lua exercises it.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)
local sample = 'first line: 0123456789\nsecond line: abcdefghij\nthird line: 0123456789'

-- This comparison deliberately has no editor/completion/diagnostic scripts or
-- hooks on its EditBox. Its fixed sample never reads or saves an owner buffer.
-- Opens (or reopens) the probe window with the sample text and the stock font selected, and returns the window
-- record. Each opening starts a new session so click handlers from an earlier opening do nothing.
function addon:ShowLuaInputProbe()
    local d = self.luaInputProbe

    if not d then
        d = { frame = CreateFrame('Frame', nil, UIParent), session = 0 }
        self.luaInputProbe = d
        local frame = d.frame
        frame:SetSize(600, 300)
        frame:SetPoint('CENTER')
        frame:EnableMouse(true)
        d.title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
        d.chrome = self:CreateWorkbenchDialogChrome(frame, d.title)
        d.chrome:SetContext(L['Native input test'], L['Input test'], '')
        local instructions = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        instructions:SetPoint('TOPLEFT', 12, -40)
        instructions:SetWidth(576)
        instructions:SetHeight(38)
        instructions:SetJustifyH('LEFT')
        instructions:SetWordWrap(true)

        instructions:SetText(
            L['Click the sample, then try Up/Down and look for the caret. Compare Stock font and RM font. This temporary text is not saved.']
        )

        d.stockFont = self:CreateWorkbenchButton(frame, L['Stock font'], 110)
        d.stockFont:SetPoint('TOPLEFT', 12, -88)
        d.rmFont = self:CreateWorkbenchButton(frame, L['RM font'], 110)
        d.rmFont:SetPoint('LEFT', d.stockFont, 'RIGHT', 8, 0)
        d.fontState = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        d.fontState:SetPoint('LEFT', d.rmFont, 'RIGHT', 16, 0)
        d.fontState:SetJustifyH('LEFT')
        -- Keep even the scroll host native: no RM range, gutter, paint or
        -- layout callbacks participate in this small fixed sample.
        d.scroll = CreateFrame('ScrollFrame', nil, frame)
        d.scroll:SetPoint('TOPLEFT', 12, -128)
        d.scroll:SetSize(576, 138)
        d.edit = CreateFrame('EditBox', nil, d.scroll)
        local edit = d.edit
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:EnableMouse(true)
        edit:SetAltArrowKeyMode(false)
        edit:SetFontObject('ChatFontNormal')
        edit:SetTextColor(1, 1, 1, 1)
        edit:SetMaxLetters(0)
        edit:SetPoint('TOPLEFT', d.scroll, 'TOPLEFT', 0, 0)
        edit:SetWidth(576)
        edit:SetHeight(1)
        d.scroll:SetScrollChild(edit)

        -- Registry-facing hide: marks the probe inactive and drops edit focus along with the frame.
        function d:Hide()
            self.active = false
            self.edit:ClearFocus()
            self.frame:Hide()
        end

        addon:SetUIScript(frame, 'OnHide', function()
            d.active = false
            edit:ClearFocus()
        end)

        d.close = self:CreateWorkbenchIconButton(frame, 'close', L['Close'])
        d.close:SetPoint('TOPRIGHT', -5, -5)
        frame:Hide()
        addon.HideOnEscape(d)
    end

    d.session = d.session + 1
    d.active = true
    local session = d.session

    -- Switches the sample between the stock chat font ('stock') and the bundled monospace font ('rm'), keeping the
    -- caret position and focus so the player can compare caret behavior in place.
    local function selectFont(mode)
        if not d.active or d.session ~= session or not d.frame:IsShown() then
            return
        end

        local cursor = d.edit:GetCursorPosition()

        if mode == 'rm' then
            d.edit:SetFont('Interface\\AddOns\\' .. addon_name .. '\\Fonts\\Inconsolata-Regular.ttf', 12, '')
        else
            d.edit:SetFontObject('ChatFontNormal')
        end

        d.fontMode = mode
        d.fontState:SetText(mode == 'rm' and L['RM font'] or L['Stock font'])

        if d.edit:GetCursorPosition() ~= cursor then
            d.edit:SetCursorPosition(cursor)
        end

        d.edit:SetFocus()
    end

    self:SetUIScript(d.stockFont, 'OnClick', function()
        selectFont('stock')
    end)

    self:SetUIScript(d.rmFont, 'OnClick', function()
        selectFont('rm')
    end)

    self:SetUIScript(d.close, 'OnClick', function()
        if d.active and d.session == session then
            d:Hide()
        end
    end)

    d.frame:Show()
    addon:OpenPopup(d)
    d.edit:SetText(sample)
    d.edit:SetCursorPosition(0)
    selectFont('stock')
    return d
end
