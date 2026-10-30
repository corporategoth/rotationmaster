-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Load-on-demand text: answers a key the main table lacks from the text bundle add-on that owns it (Locales/bundles.json,
-- hash index in Data/text_bundle_index.lua). Owns the one-time load of each bundle, its failed/loaded state, and the
-- credits of the language's human translators; it must not read bundle text while the game is loading and must not change
-- what `L["English"]` returns for a key the main table holds. Loaded from RotationMaster.toc straight after locales.xml
-- and the index, before any file that reads text at load. Returns without doing anything if the locale has no
-- missing-key handler.

local addon_name, addon = ...

-- General text is loaded at startup. Class-specific Built In names and descriptions live in each class module's
-- locale files. A translated game can load the owning class on the first missing-key read; English text is already
-- the lookup key. An unavailable class falls back to the key. Legacy text modules are empty compatibility modules.
local ace = LibStub("AceLocale-3.0")
local L = ace:GetLocale(addon_name)
local mainMeta = getmetatable(L)
local reportMissing = mainMeta and mainMeta.__index

if type(reportMissing) ~= "function" then
    return
end

local bundles = addon.textBundleIndex or {}
local HEX = 8
-- Set by Locales/enUS.lua: true when a translation was applied. Unset (a harness that never loaded it) counts as translated.
local englishGame = addon.localeIsTranslated == false

-- Computes the 32-bit hash tools/locales.py uses for the index (h = h * 31 + byte, modulo 2^32).
-- @param value string  The key text.
-- @return number  The hash.
local function keyHash(value)
    local h = 0

    for i = 1, value:len() do
        h = (h * 31 + value:byte(i)) % 4294967296
    end

    return h
end

-- Searches a sorted key-hash string for a hash.
-- @param keys string  The sorted key hashes, 8 hex digits per key.
-- @param count number  How many keys the string holds.
-- @param wanted number  The hash to look for.
-- @return boolean  True when `wanted` is one of the keys.
--
-- Binary search.
local function owns(keys, count, wanted)
    local low, high = 0, count - 1

    while low <= high do
        local middle = math.floor((low + high) / 2)
        local value = tonumber(keys:sub(middle * HEX + 1, middle * HEX + HEX), 16)

        if value == wanted then
            return true
        elseif value < wanted then
            low = middle + 1
        else
            high = middle - 1
        end
    end

    return false
end

-- Finds the bundle that owns a key.
-- @param key string  The English text key.
-- @param loadingOnly boolean|nil  True to count, in an English game, only the keys whose English lives in the bundle.
-- @return table|nil  The bundle record that owns the key; nil when it is a key of the main table or of no catalog.
local function ownerOf(key, loadingOnly)
    local wanted = keyHash(key)
    local symbolic = loadingOnly and englishGame

    for _, bundle in ipairs(bundles) do
        if symbolic then
            if owns(bundle.symbolic, bundle.symbolicCount, wanted) then
                return bundle
            end
        elseif owns(bundle.keys, bundle.count, wanted) then
            return bundle
        end
    end
end

-- Returns the add-on loader.
-- @param self table  The addon, whose textBundleLoader test override is consulted.
-- @return function  The test override `addon.textBundleLoader`, else C_AddOns.LoadAddOn, else the older LoadAddOn.
local function loader(self)
    local custom = self.textBundleLoader

    if type(custom) == "function" then
        return custom
    end

    return (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
end

-- Moves everything a loaded bundle holds into the main table and lets go of the bundle's own table.
-- @param bundle table  The bundle record; its translators are recorded on it.
-- @param text table  The bundle's own AceLocale table, which is emptied.
local function absorb(bundle, text)
    for key, value in pairs(text) do
        if type(key) == "string" then
            if rawget(L, key) == nil then
                rawset(L, key, value)
            end
        elseif key == 0 then
            bundle.translators = value
        end
    end

    for key in pairs(text) do
        text[key] = nil
    end

    -- AceLocale keeps every application it registered; the emptied one is of no use to anybody.
    local apps, names = rawget(ace, "apps"), rawget(ace, "appnames")

    if type(apps) == "table" and apps[bundle.module] == text then
        apps[bundle.module] = nil

        if type(names) == "table" then
            names[text] = nil
        end
    end
end

-- Loads the add-on of one bundle (once).
-- @param bundle table  The bundle record; bundle.state is nil (never asked), "loaded" or "failed".
-- @return boolean  True when the bundle's text is available.
local function attach(bundle)
    if bundle.state == "loaded" then
        return true
    end
    if bundle.state == "failed" then
        return false
    end

    local load = loader(addon)
    local ok, loaded, reason = false, false, "no-loader"

    if type(load) == "function" then
        ok, loaded, reason = pcall(load, bundle.module)
    end

    local text = ok and ace:GetLocale(bundle.module, true) or nil

    if text then
        bundle.state = "loaded"
        absorb(bundle, text)
        return true
    end

    bundle.state, bundle.reason = "failed", ok and (reason or loaded) or loaded
    return false
end

setmetatable(L, {
    -- Answers a read of a key the main table lacks from the bundle that owns it.
    -- @param self table  The locale table.
    -- @param key any  The key being read.
    -- @return string  The text; the key itself (the English text) when the bundle holds nothing for it or failed. Keys
    --   no bundle owns go to the original missing-key handler, whose result is returned.
    __index = function(self, key)
        if type(key) == "string" then
            local bundle = ownerOf(key, true)

            if bundle then
                attach(bundle)
                local value = rawget(self, key)

                if value ~= nil then
                    return value
                end

                -- The English text is the key itself, whether the bundle held nothing for it, failed or is not needed.
                rawset(self, key, key)
                return key
            end

            -- An English game owes a bundle's own-English key nothing but the key.
            if englishGame and ownerOf(key) then
                rawset(self, key, key)
                return key
            end
        end

        return reportMissing(self, key)
    end,
})

-- Loads a text bundle ahead of its first read.
-- @param id string  The bundle id ("help", "conditions", ...).
-- @return boolean  True when the bundle is available.
-- @return string|nil  'unknown-bundle' when no bundle has that id; nil otherwise.
function addon:LoadTextBundle(id)
    for _, bundle in ipairs(bundles) do
        if bundle.id == id then
            return attach(bundle)
        end
    end

    return false, "unknown-bundle"
end

-- Says which bundle holds this English text, and whether it is loaded.
-- @param key any  The English text; a non-string gives nil.
-- @return string|nil  The bundle id; nil for a key of the main table.
-- @return string|nil  The bundle state: "idle", "loaded" or "failed"; nil when the first return is nil.
function addon:GetTextBundleOf(key)
    local bundle = type(key) == "string" and ownerOf(key) or nil

    if bundle then
        return bundle.id, bundle.state or "idle"
    end
end

-- Returns the state of every bundle, for diagnostics and tests.
-- @return table  { [bundleId] = "idle" | "loaded" | "failed" }.
function addon:GetTextBundleStates()
    local states = {}

    for _, bundle in ipairs(bundles) do
        states[bundle.id] = bundle.state or "idle"
    end

    return states
end

-- Returns the display names of the human translators of the game's language, for the About page.
-- @return string[]  Every name the language's files credit (the main file lists those of all catalogs), once each;
--   empty for English and while only an AI has translated.
--
-- The AI is named in the files' headers and never here.
function addon:GetLocaleTranslators()
    local names, seen = {}, {}

    -- Adds the names of a translator list to the result, skipping any already seen (case-insensitively).
    -- @param list table|nil  The translator names; anything else is ignored.
    local function add(list)
        if type(list) ~= "table" then
            return
        end

        for _, name in ipairs(list) do
            local folded = type(name) == "string" and name:lower() or nil

            if folded and not seen[folded] then
                seen[folded] = true
                names[#names + 1] = name
            end
        end
    end

    add(rawget(L, 0))

    for _, bundle in ipairs(bundles) do
        add(bundle.translators)
    end

    return names
end

-- Each language's name in that language (an autonym, as a language picker shows it): the same text whatever language the
-- interface is in, so it is not a translated string. Keyed by the game locale.
local LANGUAGE_NAMES = {
    deDE = "Deutsch",
    esES = "Español",
    esMX = "Español (México)",
    frFR = "Français",
    itIT = "Italiano",
    koKR = "한국어",
    ptBR = "Português (Brasil)",
    ruRU = "Русский",
    zhCN = "简体中文",
    zhTW = "繁體中文",
}

-- Returns the name of the game's language in that language.
-- @return string  The autonym, or the locale code for a language this addon has no name for.
local function languageName()
    local code = rawget(_G, "GAME_LOCALE") or (type(GetLocale) == "function" and GetLocale()) or ""
    return LANGUAGE_NAMES[code] or code
end

-- Builds the About-page line crediting the human translators of the game's language.
-- @param limit number|nil  Caps the list's length in bytes: whole names are kept and the rest is replaced by an
--   ellipsis, so a long list can never run out of the room the page gives it.
-- @return string|nil  The credit line; nil when there are no human translators (always for English, and while only an
--   AI has translated).
function addon:GetTranslationCredit(limit)
    local names = self:GetLocaleTranslators()

    if #names == 0 then
        return nil
    end

    local list = names[1]

    for i = 2, #names do
        local nextList = list .. ", " .. names[i]

        if limit and nextList:len() > limit then
            list = list .. ", \226\128\166"
            break
        end

        list = nextList
    end

    return string.format(L["Translation (%s): %s"], languageName(), list)
end
