-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- What the locale files say, read through the very files the game runs (no copy of their format): `key -> displayed text`
-- for the English or for a game language, without AceLocale. Tests that need the strings of a catalog use this instead of
-- reading Locales/*.lua as text.
--   local M = dofile('tests/fixtures/locale_entries.lua')
--   M.entries('enUS')            main catalog, English
--   M.entries('deDE')            main catalog, German (English where German has no translation)
--   M.entries('deDE', true)      every catalog (the load-on-demand text bundles too)
--   M.catalogs(true)             { 'Locales', 'Modules/RotationMaster_HelpText', ... }
local M = {}

local function read(path)
    local h = assert(io.open(path, 'rb'))
    local text = h:read('*a')
    h:close()
    return text
end

function M.catalogs(bundles)
    local found = { 'Locales' }

    if bundles then
        for module in read('Locales/bundles.json'):gmatch('"module"%s*:%s*"([^"]+)"') do
            found[#found + 1] = 'Modules/' .. module
        end
    end

    return found
end

-- Runs one locale file with a recording stand-in for AceLocale; `into[key] = text` as AceLocale would write it.
local function run(path, addon, into)
    local target = setmetatable({}, {
        __newindex = function(_, key, value)
            if type(key) == 'string' and into[key] == nil then
                into[key] = value == true and key or value
            end
        end,
    })

    local env = setmetatable({
        LibStub = function() return { NewLocale = function() return target end } end,
        NORMAL_FONT_COLOR_CODE = '|cffffd200',
    }, { __index = _G })

    local globals = assert(loadfile('globals.lua'))
    setfenv(globals, env)
    globals('RotationMaster', {})
    local fn = assert(loadfile(path))
    setfenv(fn, env)
    fn('RotationMaster', addon)
end

local cache = {}

-- key -> English for one catalog directory: the symbolic entries as written, every other key as itself.
local function english(dir)
    if cache[dir] then
        return cache[dir]
    end

    local plain, every = {}, {}
    run(dir .. '/enUS.lua', {}, plain)
    -- Every other entry is its own English: a translation that answers every ID shows which keys exist.
    local everything = setmetatable({}, { __index = function() return '\0' end })
    run(dir .. '/enUS.lua', { translation = everything }, every)
    local result = {}

    for key in pairs(every) do
        result[key] = plain[key] or key
    end

    cache[dir] = result
    return result
end

function M.english(bundles)
    local out = {}

    for _, dir in ipairs(M.catalogs(bundles)) do
        for key, text in pairs(english(dir)) do
            out[key] = text
        end
    end

    return out
end

-- key -> displayed text of one catalog directory ('Locales', 'Modules/RotationMaster_HelpText') in a game language.
function M.dir_entries(dir, client)
    local base, found, out = english(dir), {}, {}

    if client ~= 'enUS' then
        local addon = {}
        run(dir .. '/' .. client .. '.lua', addon, {})

        if addon.translation then
            run(dir .. '/enUS.lua', addon, found)
        end
    end

    for key, text in pairs(base) do
        out[key] = found[key] or text
    end

    return out
end

function M.entries(client, bundles)
    local out = {}

    for _, dir in ipairs(M.catalogs(bundles)) do
        for key, text in pairs(M.dir_entries(dir, client)) do
            out[key] = text
        end
    end

    return out
end

-- The translators a game language's file credits (the L[0] table), or {}.
function M.translators(dir, client)
    if client == 'enUS' then
        return {}
    end

    local credited = {}

    local target = setmetatable({}, {
        __newindex = function(_, key, value)
            if key == 0 then
                credited = value
            end
        end,
    })

    local env = setmetatable({ LibStub = function() return { NewLocale = function() return target end } end }, {
        __index = _G,
    })

    local fn = assert(loadfile(dir .. '/' .. client .. '.lua'))
    setfenv(fn, env)
    fn('RotationMaster', {})
    return credited
end

return M
