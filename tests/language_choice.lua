-- The language choice (Locales/language.lua) with the real AceLocale, the real
-- English file and the real generated translations, loaded in locales.xml order
-- as the client loads them: Automatic follows the game, a saved choice is applied
-- while the files load (LoadSavedVariablesFirst) or, on a client that loads
-- SavedVariables late, at OnInitialize; untranslated text stays English; only
-- the language in use stays resident.
local passed,failed=0,0
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(why)) end
end
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local localeFiles={}
for file in read('locales.xml'):gmatch('<Script file="([^"]+)"') do localeFiles[#localeFiles+1]=file:gsub('\\','/') end

local function chooseLanguage(language) return {global={language=language}} end
-- Resident memory after OnInitialize, measured first: the reference tables
-- below share (intern) every string and would hide what a translation costs.
local memory={}
do
    local function boot(client,saved,late)
        local env=setmetatable({GetLocale=function() return client end,NORMAL_FONT_COLOR_CODE='|cffffd200',
            geterrorhandler=function() return function(message) error(message,0) end end},{__index=_G})
        env._G=env
        local function load(path,...) local fn=assert(loadfile(path));setfenv(fn,env);return fn(...) end
        if not late then env.RotationMasterDB=saved end
        load('Libs/LibStub/LibStub.lua');load('Libs/AceLocale-3.0/AceLocale-3.0.lua');load('globals.lua')
        local addon={}
        for _,path in ipairs(localeFiles) do load(path,'RotationMaster',addon) end
        if late then env.RotationMasterDB=saved end
        addon:FinishLanguageSelection()
        return env
    end
    local function resident(name,...)
        collectgarbage('collect');collectgarbage('collect');local before=collectgarbage('count')
        local keep=boot(...);collectgarbage('collect');collectgarbage('collect')
        memory[name]=collectgarbage('count')-before;keep=nil
    end
    resident('englishOnly','enUS');resident('german','deDE');resident('chosen','enUS',chooseLanguage('deDE'))
    resident('lateChosen','frFR',chooseLanguage('deDE'),true);resident('englishChosen','frFR',chooseLanguage('enUS'))
    resident('korean','enUS',chooseLanguage('koKR'))
end

-- The English and each translation's entries, read without the registry.
local english,translations={},{}
do
    local env=setmetatable({NORMAL_FONT_COLOR_CODE='|cffffd200'},{__index=_G})
    local function into(t,first) return setmetatable({},{__newindex=function(_,k,v) if not (first and t[k]~=nil) then t[k]=v==true and k or v end end}) end
    env.LibStub=function() return {NewLocale=function() return into(english,true) end} end
    local function run(path,addon) local fn=assert(loadfile(path));setfenv(fn,env);fn('RotationMaster',addon or {}) end
    run('globals.lua');run('Locales/enUS.lua')
    for _,path in ipairs(localeFiles) do
        local locale=path:match('Locales/(%a%a%u%u)%.lua$')
        if locale and locale~='enUS' then
            translations[locale]={}
            run(path,{RegisterTranslation=function(registered,translate) assert(registered==locale,path..' registered '..tostring(registered));translate(into(translations[locale])) end})
        end
    end
end
-- A key every translation changes, and differently in German and French.
local translated
for key,value in pairs(translations.deDE) do
    if value~=english[key] and translations.frFR[key] and translations.frFR[key]~=english[key] and translations.frFR[key]~=value then translated=key;break end
end
assert(translated,'no key translated in both German and French')
-- An English key German lacks: it must show in English.
local untranslated
for key in pairs(english) do if translations.deDE[key]==nil then untranslated=key;break end end
assert(untranslated,'German translates every key; the fallback test needs one it lacks')

-- saved: RotationMasterDB; late=true loads it after the files, as clients
-- without LoadSavedVariablesFirst do. Returns the addon, the AceLocale table
-- and the env; finish=false stops before OnInitialize.
local function boot(client,saved,late,finish,track)
    local env=setmetatable({GetLocale=function() return client end,NORMAL_FONT_COLOR_CODE='|cffffd200',
        geterrorhandler=function() return function(message) error(message,0) end end},{__index=_G})
    env._G=env
    local function load(path,...) local fn=assert(loadfile(path));setfenv(fn,env);return fn(...) end
    if not late then env.RotationMasterDB=saved end
    load('Libs/LibStub/LibStub.lua');load('Libs/AceLocale-3.0/AceLocale-3.0.lua');load('globals.lua')
    local addon={}
    for _,path in ipairs(localeFiles) do
        load(path,'RotationMaster',addon)
        if track and addon.RegisterTranslation and not addon.trackedRegistry then
            local register=addon.RegisterTranslation;addon.trackedRegistry=true
            addon.RegisterTranslation=function(locale,translate) track[translate]=locale;track.count=(track.count or 0)+1;return register(locale,translate) end
        end
    end
    local L=env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster')
    if late then env.RotationMasterDB=saved end
    if finish~=false then addon:FinishLanguageSelection() end
    addon.db={global=type(saved)=='table' and saved.global or {}}
    return addon,L,env
end
local choose=chooseLanguage
-- Every English key shows `expected`'s text, or English where it has none.
local function shows(L,expected)
    for key,value in pairs(english) do
        local want=expected and expected[key] or value
        if rawget(L,key)~=want then error(string.format('%q shows %q, expected %q',key,tostring(rawget(L,key)),want),2) end
    end
end

test('locales.xml loads the registry before English and every translation, and the TOC loads settings first',function()
    assert(localeFiles[1]=='Locales/language.lua' and localeFiles[2]=='Locales/enUS.lua',table.concat(localeFiles,','))
    local count=0;for _ in pairs(translations) do count=count+1 end;assert(count==10 and #localeFiles==12)
    local toc=read('RotationMaster.toc')
    assert(toc:find('\n## LoadSavedVariablesFirst: 1\n',1,true),'TOC lost LoadSavedVariablesFirst')
    assert(toc:find('\n## SavedVariables: RotationMasterDB\n',1,true) and read('Locales/language.lua'):find('"RotationMasterDB"',1,true),'the registry reads another SavedVariables name')
    local main=read('main.lua');local body=assert(main:match('function addon:OnInitialize%(%)(.-)\nend'))
    assert(body:find('self:FinishLanguageSelection()',1,true)<body:find('Diagnostics',1,true),'OnInitialize reads text before the language is final')
end)

test('Automatic follows the game language, with or without saved settings',function()
    for _,saved in ipairs({false,choose('auto'),{global={}},choose('xxXX'),choose(3)}) do
        local addon,L=boot('frFR',saved or nil)
        assert(L[translated]==translations.frFR[translated]);shows(L,translations.frFR)
        local state=addon:GetLanguageState();assert(state.choice=='auto' and state.active=='frFR' and state.shown=='frFR' and state.automatic=='frFR' and state.client=='frFR')
    end
    local addon,L=boot('enGB');assert(L[translated]==english[translated] and addon:GetLanguageState().active=='enUS' and addon:GetLanguageState().automatic=='enUS')
    -- A game language Rotation Master has no translation for shows English.
    addon,L=boot('xxXX');shows(L);assert(addon:GetLanguageState().automatic=='enUS')
end)

test('a saved choice is in use while the files load, and untranslated text stays English',function()
    local addon,L=boot('enUS',choose('deDE'),false,false)
    -- Before OnInitialize: anything read while loading already sees German.
    assert(L[translated]==translations.deDE[translated],'the chosen language was not in use while the files loaded')
    assert(L[untranslated]==english[untranslated],'a missing German entry did not fall back to English')
    addon:FinishLanguageSelection();shows(L,translations.deDE)
    local state=addon:GetLanguageState();assert(state.choice=='deDE' and state.active=='deDE' and not state.switchedLate)
    -- English chosen on a French client: nothing French is applied.
    addon,L=boot('frFR',choose('enUS'));shows(L);assert(addon:GetLanguageState().active=='enUS' and addon:GetLanguageState().automatic=='frFR')
    addon,L=boot('koKR',choose('zhTW'));shows(L,translations.zhTW)
end)

test('choosing persists account-wide and is in use after a reload',function()
    local saved={global={}}
    local addon,L=boot('enUS',saved);assert(L[translated]==english[translated])
    assert(addon:SetLanguageChoice('deDE')==true and saved.global.language=='deDE','the choice did not persist or needs no reload')
    local state=addon:GetLanguageState();assert(state.choice=='deDE' and state.shown=='deDE' and state.active=='enUS')
    assert(addon:SetLanguageChoice('enUS')==false and addon:SetLanguageChoice('auto')==false,'English is in use: no reload needed')
    assert(addon:SetLanguageChoice('xxXX')==nil and saved.global.language=='auto')
    addon:SetLanguageChoice('deDE')
    -- The reload: the same SavedVariables, a fresh client session.
    local reloaded,L2=boot('enUS',saved);assert(L2[translated]==translations.deDE[translated]);shows(L2,translations.deDE)
    assert(reloaded:GetLanguageState().active=='deDE')
    -- Back to Automatic on the next reload.
    reloaded:SetLanguageChoice('auto');local again,L3=boot('enUS',saved);shows(L3);assert(again:GetLanguageState().active=='enUS')
end)

test('a client that loads settings late switches at OnInitialize and restores English first',function()
    local addon,L=boot('frFR',choose('deDE'),true,false)
    assert(L[translated]==translations.frFR[translated],'provisional game language not applied while loading')
    addon:FinishLanguageSelection();shows(L,translations.deDE)
    local state=addon:GetLanguageState();assert(state.active=='deDE' and state.switchedLate)
    addon,L=boot('frFR',choose('enUS'),true);shows(L);assert(addon:GetLanguageState().active=='enUS' and addon:GetLanguageState().switchedLate)
    addon,L=boot('enUS',choose('ruRU'),true);shows(L,translations.ruRU)
    -- The same language as the game: nothing switches.
    addon,L=boot('frFR',choose('frFR'),true);shows(L,translations.frFR);assert(not addon:GetLanguageState().switchedLate)
    addon,L=boot('frFR',nil,true);shows(L,translations.frFR);assert(not addon:GetLanguageState().switchedLate)
    -- A finished selection ignores later registrations and a second finish.
    assert(addon.RegisterTranslation==nil);addon:FinishLanguageSelection();shows(L,translations.frFR)
end)

test('translations not in use are released, on time and late clients alike',function()
    for _,case in ipairs({{'enUS',choose('deDE'),false},{'deDE',nil,false},{'frFR',choose('deDE'),true},{'enUS',nil,true}}) do
        local track=setmetatable({},{__mode='k'})
        local addon=boot(case[1],case[2],case[3],true,track)
        assert(track.count==10,'tracked '..tostring(track.count)..' translations');track.count=nil
        collectgarbage('collect');collectgarbage('collect')
        local kept={};for _,locale in pairs(track) do kept[#kept+1]=locale end
        assert(#kept==0,'translations still resident after OnInitialize: '..table.concat(kept,','))
        assert(addon.RegisterTranslation==nil)
    end
end)

test('resident memory holds English plus at most the language in use',function()
    print(string.format('  resident KB: English %.0f, deDE game %.0f, deDE chosen %.0f, deDE chosen late %.0f, English chosen on frFR %.0f, koKR chosen %.0f',
        memory.englishOnly,memory.german,memory.chosen,memory.lateChosen,memory.englishChosen,memory.korean))
    assert(memory.german>memory.englishOnly*1.3,'the translation did not load')
    -- One translation costs the same whichever way it was selected.
    assert(math.abs(memory.chosen-memory.german)<memory.german*0.03,'a chosen language costs more than the game language')
    assert(math.abs(memory.lateChosen-memory.german)<memory.german*0.03,'a late switch keeps the provisional language resident')
    assert(math.abs(memory.englishChosen-memory.englishOnly)<memory.englishOnly*0.03,'English chosen keeps the game language resident')
end)

test('the real addon finishes the selection at ADDON_LOADED and reports the saved choice',function()
    local T=dofile('tests/fixtures/toc_addon.lua')
    local f=T.new{saved={global={language='deDE'}}};local a=f.addon
    for _,e in ipairs(f.loadErrors) do assert(e:match('^Libs/'),'addon file failed to load: '..e) end
    assert(a.RegisterTranslation==nil,'OnInitialize did not finish the language selection')
    local state=a:GetLanguageState();assert(state.choice=='deDE' and state.shown=='deDE')
    -- The default is Automatic, and AceDB does not save it.
    local g=T.new{};assert(g.addon:GetLanguageState().choice=='auto' and g.addon.db.global.language=='auto')
end)

print(passed..' passed, '..failed..' failed')
if failed>0 then os.exit(1) end
