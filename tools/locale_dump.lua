-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
-- Boots the locale machinery of an add-on tree exactly as the game does and dumps what the addon reads.
--   lua5.1 tools/locale_dump.lua ROOT CLIENT KEYS OUT
-- ROOT is a checkout (or an older copy of one) holding Libs/, globals.lua, locales.xml, Data/text_bundle_index.lua,
-- Core/text_bundles.lua and Modules/*Text/; CLIENT is the game language (enUS, deDE, ...); KEYS is a file of hex-encoded
-- UTF-8 keys, one per line. OUT receives one `hexkey hexvalue` line per key, `L[key]` read as the addon reads it, in order.
-- Standard output: `boot=<KB>` (resident memory after the locale files and the bundle loader ran, after a full collection)
-- and `all=<KB>` (after every key was read, which loads every text bundle), both net of the libraries.
local root, client, keysPath, outPath = ...
root = root:gsub('/$', '')

-- Encodes a string as hexadecimal.
-- @param s string  The string.
-- @return string  Two lowercase hex digits per byte.
local function hex(s)
    return (s:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

-- Decodes a hexadecimal string.
-- @param h string  Pairs of hex digits.
-- @return string  The decoded bytes.
local function unhex(h)
    return (h:gsub('%x%x', function(c) return string.char(tonumber(c, 16)) end))
end

-- Reads a text file into a list of lines.
-- @param path string  The file path.
-- @return string[]  The lines, without line endings.
local function lines(path)
    local out = {}

    for line in io.lines(path) do
        out[#out + 1] = (line:gsub('\r$', ''))
    end

    return out
end

-- Several full collections: Lua 5.1 halves its string table once per cycle, and a measurement should not include that slack.
local function settle()
    for _ = 1, 8 do
        collectgarbage('collect')
    end
end

local errors = {}

local env = setmetatable({
    GetLocale = function() return client end,
    NORMAL_FONT_COLOR_CODE = '|cffffd200',
    geterrorhandler = function()
        return function(message)
            errors[#errors + 1] = tostring(message)
        end
    end,
}, { __index = _G })

env._G = env

-- Loads a file of the add-on tree into the game-like environment and runs it.
-- @param path string  The path relative to the tree root.
-- @param ... any  The arguments passed to the chunk (the addon name and namespace).
-- @return any  The chunk's results.
local function load(path, ...)
    local fn = assert(loadfile(root .. '/' .. path))
    setfenv(fn, env)
    return fn(...)
end

load('Libs/LibStub/LibStub.lua')
load('Libs/AceLocale-3.0/AceLocale-3.0.lua')
load('globals.lua')
settle()
local base = collectgarbage('count')

-- The add-on's own namespace, shared by every file of one add-on as the client shares it.
local main = {}
local f = assert(io.open(root .. '/locales.xml', 'rb'))
local xml = f:read('*a')
f:close()

for file in xml:gmatch('<Script file="([^"]+)"') do
    load((file:gsub('\\', '/')), 'RotationMaster', main)
end

local loaded = {}

env.C_AddOns = {
    -- Stand-in for C_AddOns.LoadAddOn: loads the text files of a Built In text module into its own namespace.
    -- @param name string  The module name; its TOC under Modules/<name>/ lists the files.
    -- @return boolean  Always true.
    --
    -- Only the text files are loaded: a converter add-on also lists code that needs the whole client.
    LoadAddOn = function(name)
        local dir = 'Modules/' .. name
        local namespace = {}

        for _, line in ipairs(lines(root .. '/' .. dir .. '/' .. name .. '.toc')) do
            -- Only the text: a converter add-on also lists code that needs the whole client.
            if line:match('^%a%a%a%a%.lua$') then
                load(dir .. '/' .. line, name, namespace)
            end
        end

        loaded[#loaded + 1] = name
        return true
    end,
}

load('Data/text_bundle_index.lua', 'RotationMaster', main)
load('Core/text_bundles.lua', 'RotationMaster', main)

local L = env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster')
settle()
local boot = collectgarbage('count') - base

local out = assert(io.open(outPath, 'wb'))

for _, h in ipairs(lines(keysPath)) do
    if h ~= '' then
        local key = unhex(h)
        out:write(h, ' ', hex(tostring(L[key])), '\n')
    end
end

out:close()
settle()
local all = collectgarbage('count') - base
print(string.format('boot=%.1f', boot))
print(string.format('all=%.1f', all))
print('bundles=' .. #loaded)
print('errors=' .. #errors)
local credited = main.GetLocaleTranslators and main:GetLocaleTranslators() or {}
print('translators=' .. table.concat(credited, ';'))
