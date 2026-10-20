-- Focused runtime control: real bundled AceLocale plus the actual English file.
-- Synthetic registrations below exist only in this test, never in locales.xml.
local passed=0
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
    load('Locales/enUS.lua','RotationMaster')
    local ace=env.LibStub('AceLocale-3.0')
    local base=ace:GetLocale('RotationMaster')
    local count=0;for key,value in pairs(base) do assert(type(key)=='string' and type(value)=='string');count=count+1 end
    assert(count>2300,'actual base dictionary unexpectedly incomplete')
    local dynamic='The current rotation is '..env.color.WHITE..'%s'..env.color.INFO
    assert(rawget(base,dynamic)==dynamic,'actual computed English key missing')
    -- AceLocale default first-write, true conversion and unrelated fallback.
    local again=ace:NewLocale('RotationMaster','enUS',true)
    again.Report='must not overwrite English'
    assert(base.Report=='Report')
    local translation=ace:NewLocale('RotationMaster','frFR')
    if locale=='frFR' then
        assert(translation);translation.Report='Rapport';translation['CPU profile']=true
        assert(base.Report=='Rapport' and base['CPU profile']=='CPU profile')
    else
        assert(translation==nil)
        assert(base.Report=='Report')
    end
    assert(base['CPU report']=='CPU report','missing target translation did not fall back')
    if locale=='enGB' then
        assert(ace:NewLocale('RotationMaster','enGB')==nil,'bundled enGB normalization changed')
    end
    passed=passed+1;print('PASS actual AceLocale fallback/'..locale)
end
for _,locale in ipairs({'enUS','enGB','frFR'}) do check(locale) end
print(passed..' passed, 0 failed')
