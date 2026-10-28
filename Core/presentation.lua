-- Presentation helpers shared by condition prose and editors: readable spell and aura labels, spell hyperlinks and
-- tooltips on a label widget, and the highlight color with inherited channels. It formats and draws nothing of its own
-- beyond that and must not write saved data. Loaded from the TOC after Core/build_context.lua, before the UI files that
-- call it; the label widgets come from UI/condition_display.lua at call time. Spell data comes through addon.Platform.

local addon_name, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Returns display text for a spell given by ID or name: its hyperlink, else its name, else a placeholder.
-- @param spell number|string|nil  The spell ID or name.
-- @return string  The hyperlink, name or placeholder; never nil (an unresolvable numeric ID reads as "Unknown spell
--   (id)").
function addon:SpellLabel(spell)
    if self.Platform then
        local link = self.Platform:GetSpellLink(spell)

        if link then
            return link
        end

        local info = self.Platform:GetSpellInfo(spell)

        if info then
            return info.name
        end
    end

    if type(spell) == "string" then
        return spell
    end
    if type(spell) == "number" then
        return string.format(L["Unknown spell (%s)"], spell)
    end

    return L["<spell>"]
end

-- Returns the label for an aura condition's spell; an ID matched at any rank is suffixed so the choice is visible.
-- @param value table  The condition value (spell, anyrank).
-- @return string  The spell label, with " (any rank)" appended for a numeric spell with anyrank set.
function addon:AuraSpellLabel(value)
    local label = self:SpellLabel(value.spell)

    if type(value.spell) == 'number' and value.anyrank == true then
        return string.format(L['%s (any rank)'], label)
    end

    return label
end

-- Returns the label for a cast/channel condition's spell.
-- @param value table  The condition value (spell, ranked).
-- @return string  The spell label; a ranked pick by ID appends the rank in gray.
--
-- A cast/channel spell picked by ID matches any rank unless `ranked`.
function addon:CastSpellLabel(value)
    local label = self:SpellLabel(value.spell)

    if type(value.spell) == 'number' and value.ranked == true and self.SpellCatalog then
        local rank = self.SpellCatalog:SpellRank(value.spell)

        if type(rank) == 'string' and rank ~= '' then
            return label .. '|cFF888888 (' .. rank .. ')|r'
        end
    end

    return label
end

-- Reports whether a hyperlink is a spell link.
-- @param link any  The hyperlink text from a hyperlink event.
-- @return boolean  True for a spell hyperlink; other link types are ignored so the label never opens an unrelated
--   tooltip.
local function supportedLink(link)
    return type(link) == "string" and link:match("^spell:%d+") ~= nil
end

-- Makes a text frame show the spell tooltip on hover and open the spell link on click.
-- @param frame table|nil  The text frame to enable; a nil frame or one without hyperlink support is quietly ignored.
--
-- Idempotent per frame (rmSpellHyperlinks).
function addon:InstallSpellHyperlinks(frame)
    if
        not frame
        or not frame.SetHyperlinksEnabled
        or not frame.SetScript
        or not frame.GetScript
        or frame.rmSpellHyperlinks
    then
        return
    end

    frame.rmSpellHyperlinks = true
    frame:SetHyperlinksEnabled(true)

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end

    -- Attaches a handler for a frame script event, hooking when the frame can, else setting it if the event is unused.
    -- @param event string  The script event name, for example "OnHyperlinkEnter".
    -- @param callback function  The handler to attach.
    local function install(event, callback)
        if frame.HookScript then
            frame:HookScript(event, callback)
        elseif not frame:GetScript(event) then
            frame:SetScript(event, callback)
        end
    end

    install("OnHyperlinkEnter", function(owner, link)
        if supportedLink(link) and GameTooltip then
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
        end
    end)

    install("OnHyperlinkLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    install("OnHyperlinkClick", function(_, link, text, button)
        if supportedLink(link) and type(SetItemRef) == "function" then
            SetItemRef(link, text, button)
        end
    end)
end

-- Adds a full-width spell label widget to a container and returns it.
-- @param parent table  The AceGUI container to add the label to.
-- @param spell number|string  The spell ID or name; kept in the widget's user data for the callbacks.
-- @return table  The label widget.
function addon:CreateSpellLabel(parent, spell)
    local widget = self:CreateConditionLink()
    widget:SetFullWidth(true)
    parent:AddChild(widget)
    widget:SetText(self:SpellLabel(spell))
    widget:SetUserData("spell", spell)
    self:InstallSpellHyperlinks(widget.frame)

    -- Whole-label interactions also work when the client cannot enable native
    -- hyperlink regions on a widget frame.
    widget:SetCallback("OnEnter", function(control)
        local id = control:GetUserData("spell")
        local info = addon.Platform and addon.Platform:GetSpellInfo(id)

        if info and info.spellID and GameTooltip then
            GameTooltip:SetOwner(control.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("spell:" .. info.spellID)
        end
    end)

    widget:SetCallback("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    widget:SetCallback("OnClick", function(control, _, button)
        local id = control:GetUserData("spell")
        local info = addon.Platform and addon.Platform:GetSpellInfo(id)

        if info and info.spellID and type(SetItemRef) == "function" then
            SetItemRef("spell:" .. info.spellID, addon:SpellLabel(id), button or "LeftButton")
        end
    end)

    return widget
end

-- Resolves a highlight color, inheriting missing channels without materializing presentation defaults in saved steps.
-- @param value table|nil  The step's color table ({ r, g, b, a }); nil or missing channels are inherited.
-- @return table  A new { r, g, b, a } table, each channel clamped to 0..1 and taken from value, else the profile color,
--   else 1.
function addon:ResolveHighlightColor(value)
    local profile = self.db and self.db.profile
    local fallback = profile and profile.color

    -- Reads one color channel from a table and clamps it to 0..1.
    -- @param source any  The color table; anything else gives nil.
    -- @param key string  The channel key: "r", "g", "b" or "a".
    -- @return number|nil  The clamped channel; nil when it is missing or not a finite number.
    local function channel(source, key)
        local number = type(source) == "table" and source[key]

        if type(number) == "number" and number == number and number ~= math.huge and number ~= -math.huge then
            return math.max(0, math.min(1, number))
        end
    end

    local resolved = {}

    for _, key in ipairs({ "r", "g", "b", "a" }) do
        resolved[key] = channel(value, key) or channel(fallback, key) or 1
    end

    return resolved
end
