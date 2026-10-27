local addon_name, addon = ...

-- Load-on-demand text. Most of Rotation Master's English (and its ten translations) is read only when a window is
-- opened, a report is written or a condition is described, never while the game is loading. Keeping all of it in the
-- one AceLocale table makes every player carry it: past 4096 entries the table's hash part doubles (about 177 KB
-- resident, for every player, whatever language they play in).
--
-- The text is split into bundles (Locales/bundles.json): each is a load-on-demand add-on under Modules/ that holds the
-- English and the ten translations of its keys in an AceLocale application of its own. This file makes that
-- invisible to the rest of the addon: `L["English text"]` reads the same wherever the text lives. A read that the main
-- table cannot answer asks which bundle owns the key (Data/text_bundle_index.lua), loads that add-on the first time,
-- and answers from its table. A bundle that cannot load (disabled, missing) answers with the key, which is the
-- English text. Nothing a bundle holds may be read while the game is loading: tests/text_bundles.lua proves a normal
-- start loads none, and tools/locales.py (check) proves a key lives in exactly one catalog.
local ace = LibStub("AceLocale-3.0")
local L = ace:GetLocale(addon_name)
local mainMeta = getmetatable(L)
local reportMissing = mainMeta and mainMeta.__index
if type(reportMissing) ~= "function" then return end

local bundles = addon.textBundleIndex or {}
local HEX = 8

-- The 32-bit hash tools/locales.py computes for the index (h = h * 31 + byte, modulo 2^32).
local function keyHash(value)
    local h = 0

    for i = 1, value:len() do
        h = (h * 31 + value:byte(i)) % 4294967296
    end

    return h
end

local function owns(bundle, wanted)
    local keys, low, high = bundle.keys, 0, bundle.count - 1

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

local function ownerOf(english)
    local wanted = keyHash(english)

    for _, bundle in ipairs(bundles) do
        if owns(bundle, wanted) then return bundle end
    end
end

-- bundle.state: nil (never asked), "loaded" or "failed". bundle.text is its AceLocale table once loaded.
local loadedTexts = {}

local function loader(self)
    local custom = self.textBundleLoader
    if type(custom) == "function" then return custom end
    return (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
end

-- Loads the add-on of one bundle (once). Returns true when its text is available.
local function attach(bundle)
    if bundle.state == "loaded" then return true end
    if bundle.state == "failed" then return false end
    local load = loader(addon)
    local ok, loaded, reason = false, false, "no-loader"
    if type(load) == "function" then ok, loaded, reason = pcall(load, bundle.module) end
    local text = ok and ace:GetLocale(bundle.module, true) or nil

    if text then
        bundle.state, bundle.text = "loaded", text
        loadedTexts[#loadedTexts + 1] = text
        return true
    end

    bundle.state, bundle.reason = "failed", ok and (reason or loaded) or loaded
    return false
end

setmetatable(L, {
    __index = function(self, key)
        if type(key) == "string" then
            for i = 1, #loadedTexts do
                local value = rawget(loadedTexts[i], key)
                if value ~= nil then return value end
            end

            local bundle = ownerOf(key)

            if bundle then
                if attach(bundle) then
                    local value = rawget(bundle.text, key)
                    if value ~= nil then return value end
                elseif bundle.state == "failed" then
                    -- The English text is the key itself.
                    return key
                end
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
