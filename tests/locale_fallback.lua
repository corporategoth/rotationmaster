-- Focused runtime control: real bundled AceLocale plus the actual locale files, loaded in locales.xml order.
-- Synthetic registrations below exist only in this test, never in locales.xml.
local passed=0
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local files={}
for file in read('locales.xml'):gmatch('<Script file="([^"]+)"') do files[#files+1]=file:gsub('\\','/') end
local E=dofile('tests/fixtures/locale_entries.lua')
local english,french=E.entries('enUS'),E.entries('frFR')

local function check(locale)
    local env=setmetatable({GetLocale=function() return locale end,
        geterrorhandler=function() return function(message) error(message) end end,
        NORMAL_FONT_COLOR_CODE='|cffffd200'}, {__index=_G})
    env._G=env
    local function load(path,...)
        local fn=assert(loadfile(path));setfenv(fn,env);return fn(...)
    end
    load('Libs/LibStub/LibStub.lua')
    load('Libs/AceLocale-3.0/AceLocale-3.0.lua')
    load('globals.lua')
    local addon={}
    for _,path in ipairs(files) do load(path,'RotationMaster',addon) end
    local ace=env.LibStub('AceLocale-3.0')
    local base=ace:GetLocale('RotationMaster')
    -- Whatever is resident is text; the rest answers with its key.
    for key,value in pairs(base) do
        if key~=0 then assert(type(key)=='string' and type(value)=='string') end
    end
    local want=(locale=='frFR') and french or english
    -- A computed English key (built from the color codes) is a key like any other.
    local dynamic='The current rotation is '..env.color.WHITE..'%s'..env.color.INFO
    assert(base[dynamic]==want[dynamic],'actual computed English key missing')
    -- AceLocale first-write wins for the default language, and the registration is silent: an unknown key is its own text.
    local again=ace:NewLocale('RotationMaster','enUS',true,true)
    assert(again~=nil)
    assert(base.Report==want.Report,'Report reads '..tostring(base.Report))
    assert(base['CPU report']==want['CPU report'],'missing target translation did not fall back')
    assert(base['No such text anywhere']=='No such text anywhere')
    local translation=ace:NewLocale('RotationMaster','frFR',false,true)
    if locale=='frFR' then
        assert(translation and base.Report~='Report','French was not applied')
    else
        assert(translation==nil)
        assert(base.Report=='Report')
    end
    if locale=='enGB' then
        assert(ace:NewLocale('RotationMaster','enGB',false,true)==nil,'bundled enGB normalization changed')
    end
    passed=passed+1;print('PASS actual AceLocale fallback/'..locale)
end
for _,locale in ipairs({'enUS','enGB','frFR'}) do check(locale) end
print(passed..' passed, 0 failed')
