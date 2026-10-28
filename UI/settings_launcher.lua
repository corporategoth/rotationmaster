-- Landing page registered with the game's AddOns settings panel: logo, version and author, an Open Options button, the
-- slash-command list and credits. It owns only this page frame; the real options live in the Rotation Master window.
-- Loaded from RotationMaster.toc just before UI/settings_setup.lua, which calls addon:CreateSettingsLauncher once.
-- Metadata comes from the TOC through whichever GetAddOnMetadata the client provides.
local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- The longest list of translator names the page shows (bytes); the rest is an ellipsis. The credits block starts 460
-- points down a 600-point page, so even a list this long wraps inside the page.
local TRANSLATION_CREDIT_LIMIT = 480

-- Reads one TOC field for this addon (Version, Author, X-License, ...); returns the localized 'Unknown' when the
-- client API is missing, errors or the field is empty.
local function metadata(key)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

    if getter then
        local ok, value = pcall(getter, addon_name, key)
        if ok and type(value) == "string" and value ~= "" then return value end
    end

    return L["Unknown"]
end

-- Builds the hidden launcher page and returns { frame = ..., open = ..., ... }; the caller registers page.frame with
-- the settings panel. Widths follow the panel through OnSizeChanged so the wrapped text never overflows.
function addon:CreateSettingsLauncher()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.name = self.pretty_name
    local page = { frame = frame }

    -- Creates a left-justified, word-wrapped font string on the page frame (width is set later by OnSizeChanged).
    local function label(font)
        local result = frame:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        result:SetJustifyH("LEFT")
        result:SetWordWrap(true)
        return result
    end

    page.icon = frame:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(96, 96)
    page.icon:SetPoint("TOPLEFT", 24, -24)
    page.icon:SetTexture(addon.logoArtworkTexture or addon.logoTexture)
    page.title = label("GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 136, -34)
    page.title:SetText(self.pretty_name)
    page.metadata = label("GameFontHighlightSmall")
    page.metadata:SetPoint("TOPLEFT", 136, -64)
    page.metadata:SetText(string.format(L["Version: %s  ·  Author: %s"], metadata("Version"), metadata("Author")))
    page.description = label()
    page.description:SetPoint("TOPLEFT", 24, -136)
    page.description:SetText(L["Configure rotations, conditions and highlights in the Rotation Master window."])
    page.open = addon:CreateWorkbenchButton(frame, L["Open Options"], 380)
    page.open:SetSize(380, 72)
    page.open:SetPoint("TOPLEFT", 24, -182)
    page.open:SetText(L["Open Options"])
    page.open:GetFontString():SetFontObject("GameFontNormalLarge")
    addon:SetUIScript(page.open, "OnClick", function() addon:ShowConfig("Rotations") end)
    page.commands = label()
    page.commands:SetPoint("TOPLEFT", 24, -278)

    page.commands:SetText(table.concat({
        L["/rm config              - Open the config dialog."],
        L["/rm errors              - View and copy Rotation Master errors."],
        L["/rm help                - This text."],
        L["/rm toggle              - Toggle between enabled and disabled."],
        L["/rm current             - Print out the name of the current rotation."],
    }, "\n\n"))

    page.credits = label('GameFontHighlightSmall')
    page.credits:SetPoint('TOPLEFT', 24, -460)

    local credits = {
        L['License'] .. ': ' .. metadata('X-License'),
        L['Credits'] .. ': ' .. metadata('X-Credits'),
        L['Localizations'] .. ': ' .. metadata('X-Localizations'),
    }
    -- The human translators of the game's language, when it has any (never English): one more wrapped line, with the
    -- list capped so it always fits the room under the other credits.
    local translation = type(self.GetTranslationCredit) == 'function' and self:GetTranslationCredit(TRANSLATION_CREDIT_LIMIT) or nil

    if translation then credits[#credits + 1] = translation end

    -- Names and the line's own text may have no spaces (Chinese, Korean): let them wrap anywhere, inside the width.
    if page.credits.SetNonSpaceWrap then page.credits:SetNonSpaceWrap(true) end

    page.credits:SetText(table.concat(credits, '\n'))

    page.credits:SetWidth(592)

    addon:SetUIScript(frame, "OnSizeChanged", function(_, width)
        local available = math.max(180, width - 48)
        page.credits:SetWidth(available)
        page.description:SetWidth(available)
        page.commands:SetWidth(available)
        page.open:SetWidth(math.min(380, available))
        page.metadata:SetWidth(math.max(120, width - 160))
    end)

    frame:SetSize(640, 600)
    frame:Hide()
    return page
end
