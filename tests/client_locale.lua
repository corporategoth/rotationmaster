-- Rotation Master follows the game's language: the real AceLocale, English and
-- generated translations, loaded in locales.xml order as the client loads them.
-- The game's translation is applied, untranslated keys stay English, and the
-- other translations are never kept.
local passed, failed = 0, 0

local function test(name, fn)
    local ok, why = pcall(fn)

    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(why))
    end
end

local function read(path)
    local h = assert(io.open(path))
    local s = h:read('*a')
    h:close()
    return s
end

local files = {}

for file in read('locales.xml'):gmatch('<Script file="([^"]+)"') do
    files[#files + 1] = file:gsub('\\', '/')
end

local function boot(client)
    local env = setmetatable({
        GetLocale = function() return client end,
        NORMAL_FONT_COLOR_CODE = '|cffffd200',
        geterrorhandler = function()
            return function(message)
                error(message, 0)
            end
        end,
    }, { __index = _G })

    env._G = env

    local function load(path, ...)
        local fn = assert(loadfile(path))
        setfenv(fn, env)
        return fn(...)
    end

    load('Libs/LibStub/LibStub.lua')
    load('Libs/AceLocale-3.0/AceLocale-3.0.lua')
    load('globals.lua')

    for _, path in ipairs(files) do
        load(path, 'RotationMaster', {})
    end

    -- The TOC loads the bundle index and the loader straight after locales.xml.
    local addon = {}
    load('Data/text_bundle_index.lua', 'RotationMaster', addon)
    load('Core/text_bundles.lua', 'RotationMaster', addon)
    return env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster'), addon, env
end

-- Resident memory first: the reference tables below intern every string and
-- would hide what a translation costs.
local memory = {}

for _, client in ipairs({ 'enUS', 'deDE' }) do
    collectgarbage('collect')
    collectgarbage('collect')
    local before = collectgarbage('count')
    local keep = boot(client)
    collectgarbage('collect')
    collectgarbage('collect')
    memory[client] = collectgarbage('count') - before
    keep = nil
end

-- English and German entries, read without AceLocale's selection.
local english, german = {}, {}

do
    local function into(t, first)
        return setmetatable({}, {
            __newindex = function(_, k, v)
                if not (first and t[k] ~= nil) then
                    t[k] = v == true and k or v
                end
            end,
        })
    end

    local target

    local env = setmetatable({
        NORMAL_FONT_COLOR_CODE = '|cffffd200',
        LibStub = function() return { NewLocale = function() return target end } end,
    }, { __index = _G })

    local function run(path)
        local fn = assert(loadfile(path))
        setfenv(fn, env)
        fn('RotationMaster', {})
    end

    run('globals.lua')
    target = into(english, true)
    run('Locales/enUS.lua')
    target = into(german)
    run('Locales/deDE.lua')
end

local translated, untranslated

for key, value in pairs(german) do
    if value ~= english[key] then
        translated = key
        break
    end
end

for key in pairs(english) do
    if german[key] == nil then
        untranslated = key
        break
    end
end

-- A complete translation lacks no key; the fall-back check then has nothing to prove.
assert(translated, 'need a key German translates')

-- Past 4096 entries the English table's hash part doubles (about 177 KB resident for every player, in every
-- language). Text that is only read when a window opens lives in the load-on-demand bundles (Locales/bundles.json);
-- this is the headroom that keeps the main table below the boundary.
local count = 0

for _ in pairs(english) do
    count = count + 1
end

test('the main English table stays well below the 4096-entry hash boundary', function()
    print('  main enUS entries: ' .. count)

    assert(
        count <= 3900,
        'Locales/enUS.lua holds '
            .. count
            .. ' entries; move text nothing reads at startup into a bundle (tools/locales.py move)'
    )
end)

test('locales.xml loads English first, then every translation', function()
    assert(files[1] == 'Locales/enUS.lua' and #files == 11, table.concat(files, ','))

    assert(
        not read('RotationMaster.toc'):find('LoadSavedVariablesFirst', 1, true),
        'nothing needs SavedVariables before the files any more'
    )
end)

test('the game language is used and missing keys fall back to English', function()
    local L = boot('deDE')
    assert(L[translated] == german[translated], 'German game did not show German')

    if untranslated then
        assert(L[untranslated] == english[untranslated], 'a key German lacks did not fall back to English')
    end

    for _, client in ipairs({ 'enUS', 'enGB', 'xxXX' }) do
        L = boot(client)
        assert(L[translated] == english[translated], client .. ' did not show English')
    end

    L = boot('koKR')
    assert(L[translated] ~= english[translated], 'Korean game did not show Korean')
end)

test('only English and the game language stay resident', function()
    print(string.format('  resident KB: enUS %.0f, deDE %.0f', memory.enUS, memory.deDE))
    assert(memory.deDE > memory.enUS * 1.3, 'the German translation did not load')
    assert(memory.enUS < 1000, 'an English game keeps translations resident: ' .. memory.enUS .. ' KB')
end)

test('a language choice saved by the retired picker is dropped at startup', function()
    local T = dofile('tests/fixtures/toc_addon.lua')
    local saved = { global = { language = 'deDE', uiScale = 1 } }
    local f = T.new({ saved = saved })
    local a = f.addon

    for _, e in ipairs(f.loadErrors) do
        assert(e:match('^Libs/'), 'addon file failed to load: ' .. e)
    end

    assert(a.db.global.language == nil and saved.global.language == nil, 'the retired language choice is still saved')
    assert(a.FinishLanguageSelection == nil and a.GetLanguageState == nil)
end)

print(passed .. ' passed, ' .. failed .. ' failed')

if failed > 0 then
    os.exit(1)
end
