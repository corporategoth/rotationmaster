-- Rotation Master follows the game's language: the real AceLocale, English and generated translations by stable ID,
-- loaded in locales.xml order as the client loads them. The game's translation is applied once, when the files load
-- (nothing is resolved per lookup), untranslated keys stay English, English loads no translation, and the other
-- translations are never kept.
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local files={}
for file in read('locales.xml'):gmatch('<Script file="([^"]+)"') do files[#files+1]=file:gsub('\\','/') end
local E=dofile('tests/fixtures/locale_entries.lua')

local function boot(client)
    local env=setmetatable({GetLocale=function() return client end,NORMAL_FONT_COLOR_CODE='|cffffd200',
        geterrorhandler=function() return function(message) error(message,0) end end},{__index=_G})
    env._G=env
    local function load(path,...) local fn=assert(loadfile(path));setfenv(fn,env);return fn(...) end
    load('Libs/LibStub/LibStub.lua');load('Libs/AceLocale-3.0/AceLocale-3.0.lua');load('globals.lua')
    -- Every file of the add-on shares one private table, as the client gives it.
    local addon={}
    for _,path in ipairs(files) do load(path,'RotationMaster',addon) end
    -- The TOC loads the bundle index and the loader straight after locales.xml.
    load('Data/text_bundle_index.lua','RotationMaster',addon);load('Core/text_bundles.lua','RotationMaster',addon)
    return env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster'),addon,env
end
-- Resident memory first: the reference tables below intern every string and would hide what a translation costs.
local memory={}
for _,client in ipairs({'enUS','deDE'}) do
    for _=1,6 do collectgarbage('collect') end
    local before=collectgarbage('count')
    local keep=boot(client)
    for _=1,6 do collectgarbage('collect') end
    memory[client]=collectgarbage('count')-before;keep=nil
end

-- English and German entries, read without AceLocale's selection.
local english=E.entries('enUS')
local german=E.entries('deDE')
local translated,untranslated
for key,value in pairs(german) do if value~=english[key] then translated=key;break end end
for key in pairs(english) do if german[key]==nil then untranslated=key;break end end
-- A complete translation lacks no key; the fall-back check then has nothing to prove.
assert(translated,'need a key German translates')

-- Past 4096 entries the English table's hash part doubles (about 177 KB resident for every player, in every
-- language). Text that is only read when a window opens lives in the load-on-demand bundles (Locales/bundles.json);
-- this is the headroom that keeps the main table below the boundary.
local count=0
for _ in pairs(english) do count=count+1 end

test('the main English table stays well below the 4096-entry hash boundary',function()
    print('  main enUS entries: '..count)
    assert(count<=3900,'Locales/enUS.lua holds '..count..' entries; move text nothing reads at startup into a bundle (tools/locales.py move)')
end)

test('locales.xml loads every translation, then English last',function()
    assert(files[#files]=='Locales/enUS.lua' and #files==11,table.concat(files,','))
    assert(not read('RotationMaster.toc'):find('LoadSavedVariablesFirst',1,true),'nothing needs SavedVariables before the files any more')
end)

test('the game language is used and missing keys fall back to English',function()
    local L=boot('deDE')
    assert(L[translated]==german[translated],'German game did not show German')
    if untranslated then assert(L[untranslated]==english[untranslated],'a key German lacks did not fall back to English') end
    for _,client in ipairs({'enUS','enGB','xxXX'}) do L=boot(client);assert(L[translated]==english[translated],client..' did not show English') end
    L=boot('koKR');assert(L[translated]~=english[translated],'Korean game did not show Korean')
end)

test('the translation is applied when the files load: no lazy resolution, no tables left behind',function()
    local L,addon=boot('deDE')
    -- Every translated entry is already an ordinary entry of L.
    for key,value in pairs(german) do
        if value~=english[key] then assert(rawget(L,key)==value,('%q was not written into L'):format(key:sub(1,60))) end
    end
    assert(addon.translation==nil,'the language\'s ID table is still referenced')
    assert(addon.localeIsTranslated==true)
    assert(getmetatable(L).__index~=nil)
end)

test('an English game loads no translation table: only the keys whose English is not their text are entries',function()
    local L,addon=boot('enUS')
    local entries=0
    for key,value in pairs(L) do
        assert(type(key)=='string' and type(value)=='string')
        assert(value~=key,('%q is its own English and should not be resident'):format(key:sub(1,60)))
        entries=entries+1
    end
    print('  resident entries in an English game: '..entries)
    assert(entries>0 and entries<=1000,entries)
    assert(addon.translation==nil and addon.localeIsTranslated==false)
    -- Reading anything still answers with its English.
    for key,value in pairs(english) do assert(L[key]==value,key) end
end)

test('only English and the game language stay resident',function()
    print(string.format('  resident KB: enUS %.0f, deDE %.0f',memory.enUS,memory.deDE))
    assert(memory.deDE>memory.enUS*1.3,'the German translation did not load')
    assert(memory.enUS<500,'an English game keeps translations resident: '..memory.enUS..' KB')
end)

test('a language choice saved by the retired picker is dropped at startup',function()
    local T=dofile('tests/fixtures/toc_addon.lua')
    local saved={global={language='deDE',uiScale=1}}
    local f=T.new{saved=saved};local a=f.addon
    for _,e in ipairs(f.loadErrors) do assert(e:match('^Libs/'),'addon file failed to load: '..e) end
    assert(a.db.global.language==nil and saved.global.language==nil,'the retired language choice is still saved')
    assert(a.FinishLanguageSelection==nil and a.GetLanguageState==nil)
end)

print(passed..' passed, '..failed..' failed')
if failed>0 then os.exit(1) end
