-- General helpers hung on the addon table: leveled chat output, popups and tooltips, small encoders, spell-spec
-- lookups, the item-name/icon widget updaters, and the legacy addon.* names that saved custom source still calls (each
-- one is a plain alias of a function owned by Functions/*.lua, never a second copy). Loaded from RotationMaster.toc
-- right after the Functions modules it aliases, before profiler.lua and the Diagnostics files. It reads game data only
-- through addon.Platform (the item updaters go through Platform:CanReadValue first). It ends with the generated block
-- that lets saved custom source reach the aliased helpers as builtin:utils.lua:<name>: do not edit that block, and keep
-- function bodies in this file exactly as they are (no comments or blank lines inside them), because saved copies
-- bind to them.

local addon_name, addon = ...

local AceConsole = LibStub("AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

local _G, tostring, tonumber, pairs, color, unpack, type, string =
    _G, tostring, tonumber, pairs, color, unpack, type, string

local random, floor = math.random, math.floor

-- ============================================================================
-- Windows and popups
-- ============================================================================

-- Shows the shared ROTATIONMASTER_ERROR alert with the text s and a single Accept button; onaccept (optional) runs when
-- it is accepted. Reuses one dialog definition, so a second call replaces the text of an alert still on screen.
addon.PopupError = function(s, onaccept)
    StaticPopupDialogs["ROTATIONMASTER_ERROR"] = {
        text = s,
        button1 = ACCEPT,
        OnAccept = onaccept,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }

    StaticPopup_Show("ROTATIONMASTER_ERROR")
end

-- Makes a native window (frame is the widget table, frame.frame its Blizzard frame) close on Escape. Prefers the window
-- registry (addon:RegisterWindowForEscape); if it is absent or declines, falls back to a keyboard handler on the frame
-- that swallows Escape and passes every other key through to the game.
addon.HideOnEscape = function(frame)
    if addon.MakeWindowOpaque then
        addon:MakeWindowOpaque(frame)
    end

    if addon.RegisterWindowForEscape and addon:RegisterWindowForEscape(frame) then
        return
    end

    frame.frame:EnableKeyboard(true)
    frame.frame:SetPropagateKeyboardInput(true)

    frame.frame:SetScript("OnKeyDown", function(self, key)
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")

        if key == "ESCAPE" then
            frame:Hide()
        end
    end)
end

-- ============================================================================
-- Identifiers and legacy aliases
-- ============================================================================

-- Returns a random version-4 style UUID string (also a second value, the substitution count, from string.gsub). Uses
-- math.random, so it is unique enough for record ids but not secure. Callable as addon.uuid() or addon:uuid().
addon.uuid = function()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Compatibility API for saved custom source; Functions.values owns the body.
addon.compare = addon.Functions.values.compare

-- Compatibility APIs for saved source; presentation owns these exact bodies.
addon.nullable = addon.Functions.presentation.nullable
addon.nullable_value = addon.Functions.presentation.nullable_value
addon.playerize = addon.Functions.presentation.playerize
addon.compareString = addon.Functions.presentation.compareString

-- Legacy addon.* names for the collection, value and text helpers below, kept because saved custom source calls them;
-- the owners are Functions/collections.lua, Functions/values.lua and Functions/text.lua.
addon.keys = addon.Functions.collections.keys

addon.spairs = addon.Functions.collections.spairs

addon.tomap = addon.Functions.collections.tomap

addon.index = addon.Functions.collections.index

-- Compatibility API for saved custom source; Functions.values owns the body.
addon.isin = addon.Functions.values.isin

addon.tablelength = addon.Functions.collections.tablelength

addon.round = addon.Functions.values.round

addon.isint = addon.Functions.values.isint

addon.starts_with = addon.Functions.text.starts_with

addon.ends_with = addon.Functions.text.ends_with

addon.multiinsert = addon.Functions.collections.multiinsert

addon.cleanArray = addon.Functions.collections.cleanArray

addon.deepcopy = addon.Functions.collections.deepcopy

addon.compareArray = addon.Functions.collections.compareArray

-- Compatibility APIs for saved custom source; cache owns their shared state.
addon.getCached = addon.Functions.cache.getCached
addon.getRetryCached = addon.Functions.cache.getRetryCached
addon.ReportCacheStats = addon.Functions.cache.ReportCacheStats

-- ============================================================================
-- Spell specialization lookups
-- ============================================================================

-- Returns true when spellid is in the cached spell set of the spec key (addon.specSpells, rebuilt by Core/spell_catalog
-- from the spellbook), false when the spec or spell is unknown or nil. Pass the spec BOOKTYPE_PET ("pet") to get pet
-- spells.
addon.isSpellOnSpec = function(spec, spellid)
    if spec ~= nil and spellid ~= nil and addon.specSpells[spec] ~= nil then
        return addon.specSpells[spec][spellid] ~= nil
    end

    return false
end

-- Returns true when the spell is in the player's pet spellbook right now (a live client query, not the cached spec
-- sets).
addon.isActivePetSpell = function(spellid)
    return FindSpellBookSlotBySpellID(spellid, true) ~= nil
end

-- Returns the best spell id for a spell name in the spec key (addon.specSpellsReverse), or nil when the name is unknown
-- or its id is not in that spec's spell set. Pass the spec BOOKTYPE_PET ("pet") to get pet spells.
addon.getSpecSpellID = function(spec, name)
    if spec ~= nil and name ~= nil and addon.specSpellsReverse[spec] ~= nil then
        local spellid = addon.specSpellsReverse[spec][name]

        if addon.isSpellOnSpec(spec, spellid) then
            return spellid
        end
    end

    return nil
end

-- ============================================================================
-- Chat output
-- ============================================================================

-- Returns the configured log level as a number (profile.loglevel; 4 verbose, 3 debug, 2 info, 1 warn, 0 quiet),
-- defaulting to 2 when the database or profile is not available. Never writes the default back.
local function getLogLevel(self)
    -- AceDB removes default-valued fields during shutdown; events may still
    -- arrive afterwards. Use the normal default without writing it back.
    local profile = self.db and self.db.profile
    return (profile and tonumber(profile.loglevel)) or 2
end

-- The leveled printers below prefix the addon name and print a string.format-style message through AceConsole; each
-- one prints only at or above its level and does nothing otherwise. Verbose is level 4, the chattiest.
function addon:verbose(message, ...)
    if getLogLevel(self) >= 4 then
        AceConsole:Printf(
            color.WHITE
                .. "["
                .. color.CYAN
                .. addon.pretty_name
                .. color.WHITE
                .. "] "
                .. color.DEBUG
                .. message
                .. color.RESET,
            ...
        )
    end
end

-- Debug (level 3) output.
function addon:debug(message, ...)
    if getLogLevel(self) >= 3 then
        AceConsole:Printf(
            color.WHITE
                .. "["
                .. color.CYAN
                .. addon.pretty_name
                .. color.WHITE
                .. "] "
                .. color.DEBUG
                .. message
                .. color.RESET,
            ...
        )
    end
end

-- Information (level 2, the default) output.
function addon:info(message, ...)
    if getLogLevel(self) >= 2 then
        AceConsole:Printf(
            color.WHITE
                .. "["
                .. color.CYAN
                .. addon.pretty_name
                .. color.WHITE
                .. "] "
                .. color.INFO
                .. message
                .. color.RESET,
            ...
        )
    end
end

-- Warning (level 1) output, in the warning color.
function addon:warn(message, ...)
    if getLogLevel(self) >= 1 then
        AceConsole:Printf(
            color.WHITE
                .. "["
                .. color.CYAN
                .. addon.pretty_name
                .. color.WHITE
                .. "] "
                .. color.WARN
                .. message
                .. color.RESET,
            ...
        )
    end
end

-- Unconditional output for command results the player asked for; ignores the log level.
function addon:print(message, ...)
    AceConsole:Printf(
        color.WHITE
            .. "["
            .. color.CYAN
            .. addon.pretty_name
            .. color.WHITE
            .. "] "
            .. color.INFO
            .. message
            .. color.RESET,
        ...
    )
end

-- Unconditional output in the announcement color; ignores the log level.
function addon:announce(message, ...)
    AceConsole:Printf(
        color.WHITE
            .. "["
            .. color.CYAN
            .. addon.pretty_name
            .. color.WHITE
            .. "] "
            .. color.ANNOUNCE
            .. message
            .. color.RESET,
        ...
    )
end

-- ============================================================================
-- Encoders and text helpers
-- ============================================================================

-- The base64 alphabet shared by base64enc and base64dec.
local b64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Returns data (a byte string) as padded base64 text. A global, not an addon field; nothing else in the addon calls it,
-- the export format has its own encoder in Data/codec.lua.
function base64enc(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()

        for i = 8, 1, -1 do
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
        end

        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then
            return ''
        end

        local c = 0

        for i = 1, 6 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end

        return b64_chars:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- Returns the bytes encoded by base64 text, ignoring any character outside the alphabet and the padding sign. A global
-- like base64enc, and likewise not called elsewhere in the addon.
function base64dec(data)
    data = string.gsub(data, '[^' .. b64_chars .. '=]', '')

    return (data:gsub('.', function(x)
        if (x == '=') then
            return ''
        end

        local r, f = '', (b64_chars:find(x) - 1)

        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end

        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then
            return ''
        end

        local c = 0

        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end

        return string.char(c)
    end))
end

-- Breaks s into lines of sz + 1 characters each, joined with newlines (nil in, nil out). Cuts at fixed offsets, not at
-- word boundaries; addon.wrap is the word-aware one. A global, not called elsewhere in the addon.
function width_split(s, sz)
    if s == nil then
        return nil
    end

    local rv = ""
    local offs = 1

    while offs < s:len() do
        if (offs > 1) then
            rv = rv .. "\n"
        end

        rv = rv .. s:sub(offs, offs + sz)
        offs = offs + sz + 1
    end

    return rv
end

addon.split = addon.Functions.text.split
addon.wrap = addon.Functions.text.wrap
addon.trim = addon.Functions.text.trim

-- Trend helpers for saved custom source; Functions/trends.lua owns the bodies. The old one looks at the damage done
-- over damage_history and gives progressively more weight to more recent damage, so the figure adjusts when damage
-- rises or falls.
addon.calculate_trend_old = addon.Functions.trends.calculateOld

addon.calculate_trend = addon.Functions.trends.calculate

-- ============================================================================
-- Widget helpers
-- ============================================================================

-- Shows text in the game tooltip while the pointer is over a native widget (frame is the widget table with SetCallback;
-- frame.frame is the Blizzard frame it anchors to). Hides the tooltip on leave only if this widget still owns it. Note
-- the dot: called as addon.AddTooltip(widget, text), not as a method.
function addon.AddTooltip(frame, text)
    frame:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(frame.frame, "ANCHOR_BOTTOMRIGHT", 3)
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
    end)

    frame:SetCallback("OnLeave", function()
        if GameTooltip:IsOwned(frame.frame) then
            GameTooltip:Hide()
        end
    end)
end

-- Walks a built widget tree (obj and its children, depth first) giving each node spell hyperlink support when
-- addon:InstallSpellHyperlinks exists, then running the node's configure callback if it set one. Children are
-- configured before their parent.
function addon:configure_frame(obj)
    if self.InstallSpellHyperlinks then
        if obj.label then
            self:InstallSpellHyperlinks(obj.frame)
        end
        if obj.statustext and obj.statustext.GetParent then
            self:InstallSpellHyperlinks(obj.statustext:GetParent())
        end
    end

    if obj.children ~= nil then
        for _, child in pairs(obj.children) do
            addon:configure_frame(child)
        end
    end

    if (obj.configure ~= nil) then
        obj.configure()
        -- obj.configure = nil
    end
end

-- Returns the player's rotation specialization index, or nil and a reason when the platform cannot report one.
function addon:GetSpecialization()
    local selection, reason = self.Platform:GetRotationSpecialization()

    if not selection then
        return nil, reason
    end

    return selection.index
end

-- ============================================================================
-- Item name and icon widgets
-- ============================================================================

-- A delayed metadata retry belongs to a particular widget selection. Reusing
-- either widget or clearing it invalidates all older scheduled retries.
-- itemUpdates maps a text or icon widget to the ticket of the newest update that targets it (a retry whose ticket no
-- longer matches stops); itemReleases remembers the OnRelease wrapper installed on a widget. Both are weak-keyed.
local itemUpdates = setmetatable({}, { __mode = 'k' })
local itemReleases = setmetatable({}, { __mode = 'k' })

-- Wraps the widget's OnRelease once so that releasing the widget back to its pool drops its pending update ticket and
-- restores the original handler. Calling it again on an already watched widget does nothing.
local function watchItemRelease(widget)
    if not widget or itemReleases[widget] == widget.OnRelease and widget.OnRelease ~= nil then
        return
    end

    local original = widget.OnRelease
    local release

    release = function(self, ...)
        itemUpdates[self] = nil
        itemReleases[self] = nil

        if self.OnRelease == release then
            self.OnRelease = original
        end

        if original then
            return original(self, ...)
        end
    end

    itemReleases[widget] = release
    widget.OnRelease = release
end

-- Returns the widget's current text, or nil when there is no widget or it has no GetText.
local function itemText(widget)
    if widget and type(widget.GetText) == 'function' then
        return widget:GetText()
    end
end

-- Keeps an item tooltip that is already open on the icon in step with the id just shown: re-points it at the new item,
-- or hides it when there is none. Opens nothing by itself.
local function itemTooltip(icon, id)
    if icon and GameTooltip and GameTooltip:IsOwned(icon.frame) and GameTooltip:IsVisible() then
        if id then
            GameTooltip:SetHyperlink('item:' .. id)
        else
            GameTooltip:Hide()
        end
    end
end

-- True when the text widget still shows what the ticket recorded at the last update (compared by reference id when the
-- widget has one, else by text), i.e. the player has not typed or picked something else since.
local function sameItemText(widget, ticket)
    if widget.GetReferenceID then
        local current = widget:GetReferenceID()

        if current ~= nil or ticket.referenceID ~= nil then
            return current == ticket.referenceID
        end
    end

    return itemText(widget) == ticket.text
end

-- Fills an editor's item text widget and icon widget from an item (id, link or name) and retries while the client is
-- still loading item data. named: show the item name (else the id) in the text widget; image: set the icon as an image
-- (else write the id into it). method is the name of the public wrapper below, which the retry timer calls back with
-- attempt and ticket. Up to 4 attempts, 0.5 seconds apart; a retry is abandoned if the widgets were reused, released or
-- edited since it was scheduled. An item the platform cannot read (restricted client) is shown as empty.
local function updateItem(self, method, named, image, item, text, icon, attempt, ticket)
    if not attempt then
        attempt = 1
        ticket = {}

        if text then
            watchItemRelease(text)
            itemUpdates[text] = ticket
        end

        if icon then
            watchItemRelease(icon)
            itemUpdates[icon] = ticket
        end
    elseif
        not ticket
        or text and (itemUpdates[text] ~= ticket or not sameItemText(text, ticket))
        or icon and (itemUpdates[icon] ~= ticket or icon.rmActionIconRevision ~= ticket.iconRevision)
    then
        return
    end

    if not self.Platform:CanReadValue(item) then
        item = nil
    end

    local id = item and self.Platform:GetItemID(item)
    local info = id and (named or image) and self.Platform:GetItemDisplayInfo(id)
    local complete = id and (not named or info) and (not image or info and info.iconID ~= nil)

    if text then
        if text.rmSpellSearchActive and id then
            text:SetText(id)
        else
            text:SetText(item and (named and (info and info.name or L['Item data loading']) or id) or nil)
        end
    end

    if icon then
        if image then
            icon:SetImage(complete and info.iconID or nil)
        else
            icon:SetText(complete and id or nil)
        end
    end

    itemTooltip(icon, complete and id)
    ticket.text = itemText(text)
    ticket.referenceID = text and text.GetReferenceID and text:GetReferenceID()
    ticket.iconRevision = icon and icon.rmActionIconRevision

    if item and not complete and attempt < 4 then
        self:ScheduleTimer(method, 0.5, item, text, icon, attempt + 1, ticket)
    end
end

-- The four UpdateItem_* methods are the public entry points of updateItem: the first word is what the text widget shows
-- (ID or Name), the second what the icon widget shows (ID or Image). Callers pass only item, text and icon; attempt and
-- ticket belong to the retry timer. Either widget may be nil.
function addon:UpdateItem_ID_ID(item, text, icon, attempt, ticket)
    updateItem(self, 'UpdateItem_ID_ID', false, false, item, text, icon, attempt, ticket)
end

function addon:UpdateItem_ID_Image(item, text, icon, attempt, ticket)
    updateItem(self, 'UpdateItem_ID_Image', false, true, item, text, icon, attempt, ticket)
end

function addon:UpdateItem_Name_ID(item, text, icon, attempt, ticket)
    updateItem(self, 'UpdateItem_Name_ID', true, false, item, text, icon, attempt, ticket)
end

function addon:UpdateItem_Name_Image(item, text, icon, attempt, ticket)
    updateItem(self, 'UpdateItem_Name_Image', true, true, item, text, icon, attempt, ticket)
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="_G" then return _G end
        if name=="cacheHits" then return addon.builtinSourceModules["Functions/cache.lua"]("cacheHits") end
        if name=="cacheMisses" then return addon.builtinSourceModules["Functions/cache.lua"]("cacheMisses") end
        if name=="cachedResult" then return addon.builtinSourceModules["Functions/cache.lua"]("cachedResult") end
        if name=="color" then return color end
        if name=="compare" then return addon.Functions.values.compare end
        if name=="compareString" then return addon.Functions.presentation.compareString end
        if name=="getCached" then return addon.Functions.cache.getCached end
        if name=="getCachedInternal" then return addon.builtinSourceModules["Functions/cache.lua"]("getCachedInternal") end
        if name=="getRetryCached" then return addon.Functions.cache.getRetryCached end
        if name=="isin" then return addon.Functions.values.isin end
        if name=="nilArgument" then return addon.builtinSourceModules["Functions/cache.lua"]("nilArgument") end
        if name=="nullable" then return addon.Functions.presentation.nullable end
        if name=="nullable_value" then return addon.Functions.presentation.nullable_value end
        if name=="packResults" then return addon.builtinSourceModules["Functions/cache.lua"]("packResults") end
        if name=="playerize" then return addon.Functions.presentation.playerize end
        if name=="split" then return addon.Functions.text.split end
        if name=="string" then return string end
        if name=="trim" then return addon.Functions.text.trim end
        if name=="wrap" then return addon.Functions.text.wrap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("utils.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["utils.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
