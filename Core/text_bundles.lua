-- Load-on-demand text: answers a key the main table lacks from the text bundle add-on that owns it (Locales/bundles.json,
-- hash index in Data/text_bundle_index.lua). Owns the one-time load of each bundle, its failed/loaded state, and the
-- credits of the language's human translators; it must not read bundle text while the game is loading and must not change
-- what `L["English"]` returns for a key the main table holds. Loaded from RotationMaster.toc straight after locales.xml
-- and the index, before any file that reads text at load. Returns without doing anything if the locale has no
-- missing-key handler.

local addon_name, addon = ...

-- Load-on-demand text. Most of Rotation Master's English (and its ten translations) is read only when a window is
-- opened, a report is written or a condition is described, never while the game is loading. Keeping all of it in the
-- one AceLocale table makes every player carry it: past 4096 entries the table's hash part doubles (about 177 KB
-- resident, for every player, whatever language they play in).
--
-- The text is split into bundles (Locales/bundles.json): each is a load-on-demand add-on under Modules/ that holds the
-- English and the ten translations of its keys by stable ID, in an AceLocale application of its own. This file makes
-- that invisible to the rest of the addon: `L["English text"]` reads the same wherever the text lives. A read that the
-- main table cannot answer asks which bundle owns the key (Data/text_bundle_index.lua) and loads that add-on the first
-- time. The bundle's files turn their ID tables into `key = text` entries as they run, exactly as the main catalog does;
-- this file then moves every entry into the main table and releases the bundle's own table, so afterwards the bundle
-- is simply part of `L`. A bundle that cannot load (disabled, missing) answers with the key, which is the English text.
-- Nothing a bundle holds may be read while the game is loading: tests/text_bundles.lua proves a normal start loads
-- none, and tools/locales.py (check) proves a key lives in exactly one catalog.
--
-- An English game has no translation to apply: a key that is its own English needs no bundle at all. Only the keys read
-- under another key (the `symbolic` list of the index, such as "Help.Effects.delete") load one, for their English.
local ace = LibStub("AceLocale-3.0")
local L = ace:GetLocale(addon_name)
local mainMeta = getmetatable(L)
local reportMissing = mainMeta and mainMeta.__index
if type(reportMissing) ~= "function" then return end

local bundles = addon.textBundleIndex or {}
local HEX = 8
-- Set by Locales/enUS.lua: true when a translation was applied. Unset (a harness that never loaded it) counts as translated.
local englishGame = addon.localeIsTranslated == false

-- The 32-bit hash tools/locales.py computes for the index (h = h * 31 + byte, modulo 2^32).
local function keyHash(value)
    local h = 0

    for i = 1, value:len() do
        h = (h * 31 + value:byte(i)) % 4294967296
    end

    return h
end

-- Binary search of a sorted key-hash string (8 hex digits per key); true when `wanted` is one of its keys.
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

-- Returns the bundle record that owns this key, or nil when it is a key of the main table or of no catalog. With
-- `loadingOnly` an English game only counts the keys whose English lives in the bundle.
local function ownerOf(key, loadingOnly)
    local wanted = keyHash(key)
    local symbolic = loadingOnly and englishGame

    for _, bundle in ipairs(bundles) do
        if symbolic then
            if owns(bundle.symbolic, bundle.symbolicCount, wanted) then return bundle end
        elseif owns(bundle.keys, bundle.count, wanted) then
            return bundle
        end
    end
end

-- Returns the add-on loader: the test override `addon.textBundleLoader`, else C_AddOns.LoadAddOn, else the older
-- LoadAddOn.
local function loader(self)
    local custom = self.textBundleLoader
    if type(custom) == "function" then return custom end
    return (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
end

-- Moves everything a loaded bundle holds into the main table and lets go of the bundle's own table.
local function absorb(bundle, text)
    for key, value in pairs(text) do
        if type(key) == "string" then
            if rawget(L, key) == nil then rawset(L, key, value) end
        elseif key == 0 then
            bundle.translators = value
        end
    end

    for key in pairs(text) do text[key] = nil end

    -- AceLocale keeps every application it registered; the emptied one is of no use to anybody.
    local apps, names = rawget(ace, "apps"), rawget(ace, "appnames")

    if type(apps) == "table" and apps[bundle.module] == text then
        apps[bundle.module] = nil
        if type(names) == "table" then names[text] = nil end
    end
end

-- bundle.state: nil (never asked), "loaded" or "failed".
-- Loads the add-on of one bundle (once). Returns true when its text is available.
local function attach(bundle)
    if bundle.state == "loaded" then return true end
    if bundle.state == "failed" then return false end
    local load = loader(addon)
    local ok, loaded, reason = false, false, "no-loader"
    if type(load) == "function" then ok, loaded, reason = pcall(load, bundle.module) end
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
    __index = function(self, key)
        if type(key) == "string" then
            local bundle = ownerOf(key, true)

            if bundle then
                attach(bundle)
                local value = rawget(self, key)
                if value ~= nil then return value end

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

--- Loads a text bundle ahead of its first read, by id ("help", "conditions", ...). Returns true when it is available.
function addon:LoadTextBundle(id)
    for _, bundle in ipairs(bundles) do
        if bundle.id == id then return attach(bundle) end
    end

    return false, "unknown-bundle"
end

--- Which bundle holds this English text, and whether it is loaded: nil for a key of the main table.
function addon:GetTextBundleOf(key)
    local bundle = type(key) == "string" and ownerOf(key) or nil
    if bundle then return bundle.id, bundle.state or "idle" end
end

--- The state of every bundle: { id = "idle" | "loaded" | "failed" }, for diagnostics and tests.
function addon:GetTextBundleStates()
    local states = {}

    for _, bundle in ipairs(bundles) do
        states[bundle.id] = bundle.state or "idle"
    end

    return states
end

--- The display names of the human translators of the game's language, for the About page: every name the language's
--- files credit (the main file lists those of all catalogs), once each. Empty for English and while only an AI has
--- translated. The AI is named in the files' headers and never here.
function addon:GetLocaleTranslators()
    local names, seen = {}, {}

    local function add(list)
        if type(list) ~= "table" then return end

        for _, name in ipairs(list) do
            local folded = type(name) == "string" and name:lower() or nil

            if folded and not seen[folded] then
                seen[folded] = true
                names[#names + 1] = name
            end
        end
    end

    add(rawget(L, 0))

    for _, bundle in ipairs(bundles) do add(bundle.translators) end

    return names
end

--- The About-page line crediting the human translators of the game's language, or nil when there are none (always for
--- English, and while only an AI has translated). `limit` caps the list's length in bytes: whole names are kept and
--- the rest is replaced by an ellipsis, so a long list can never run out of the room the page gives it.
function addon:GetTranslationCredit(limit)
    local names = self:GetLocaleTranslators()
    if #names == 0 then return nil end
    local list = names[1]

    for i = 2, #names do
        local nextList = list .. ", " .. names[i]

        if limit and nextList:len() > limit then
            list = list .. ", \226\128\166"
            break
        end

        list = nextList
    end

    return string.format(L["Translation (%s): %s"], L["Locale.LanguageName"], list)
end
