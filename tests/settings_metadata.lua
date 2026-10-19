-- Real bundled registry/DB contracts; native frame and optional-module rendering
-- are the explicit boundaries. Run from the repository root.
local test,finish=dofile('tests/fixtures/addon.lua').suite()
local function fixture()
    local env=setmetatable({MetadataDB={}},{__index=_G});env._G=env;env.LibStub=false
    env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
    env.UnitFactionGroup=function() return 'Horde' end;env.GetLocale=function() return 'enUS' end
    env.UnitClass=function() return 'Shaman','SHAMAN' end;env.UnitRace=function() return 'Orc','Orc' end
    env.GetRealmName=function() return 'Realm' end;env.UnitNameUnmodified=function() return 'Player' end
    env.GetCurrentRegionName=function() return 'US' end;env.GetCurrentRegion=function() return 1 end
    env.strlenutf8=string.len;env.securecallfunction=function(fn,...) return fn(...) end
    env.NORMAL_FONT_COLOR_CODE='';env.FONT_COLOR_CODE_CLOSE=''
    local a={name='rotationmaster'}
    local function load(path) local c=assert(loadfile(path));setfenv(c,env);return c('rotationmaster',a) end
    for _,p in ipairs({'Libs/LibStub/LibStub.lua','Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua','Libs/AceDB-3.0/AceDB-3.0.lua','Libs/AceDBOptions-3.0/AceDBOptions-3.0.lua','Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua'}) do load(p) end
    local lib=env.LibStub
    lib:NewLibrary('AceConfigCmd-3.0',1).CreateChatCommand=function() error('metadata must not register slash commands') end
    lib:NewLibrary('AceLocale-3.0',1).GetLocale=function() return setmetatable({},{__index=function(_,k) return k end}) end
    load('Libs/AceConfig-3.0/AceConfig-3.0.lua')
    local counts={profiles=0,about=0,categories=0,modules=0,disable=0,enable=0,refresh=0}
    local dbOptions=lib('AceDBOptions-3.0');local realGet=dbOptions.GetOptionsTable
    dbOptions.GetOptionsTable=function(self,...) counts.profiles=counts.profiles+1;return realGet(self,...) end
    local about={type='group',name='About Rotation Master',args={}}
    lib:NewLibrary('LibAboutPanel-2.0',1).AboutOptionsTable=function(_,name) assert(name=='rotationmaster');counts.about=counts.about+1;return about end
    a.db=lib('AceDB-3.0'):New('MetadataDB',{profile={enable=true}},'Shared')
    a.CreateSettingsLauncher=function() return {frame={}} end
    a.RegisterOptionsCategory=function(_,frame) assert(frame==a.settingsLauncher.frame);counts.categories=counts.categories+1 end
    a.IterateModules=function() return ipairs({{SetupOptions=function(_,register) counts.modules=counts.modules+1;register('ExactModuleApp','Friendly module') end}}) end
    a.DisableRotation=function() counts.disable=counts.disable+1 end
    a.EnableRotation=function() counts.enable=counts.enable+1 end
    a.RefreshConfiguration=function() counts.refresh=counts.refresh+1 end
    local registry=lib('AceConfigRegistry-3.0')
    local function query(suffix) return registry:GetOptionsTable('rotationmaster'..suffix,'dialog','AceConfigDialog-3.0') end
    return a,env,load,counts,lib,query,about
end

test('loading native settings services requires no legacy metadata libraries',function()
    local _,_,load,_,lib=fixture()
    for _,key in ipairs({'AceConfig-3.0','AceDBOptions-3.0','LibAboutPanel-2.0'}) do lib.libs[key]=nil end
    load('UI/settings_setup.lua')
end)

test('native setup registers deferred exact applications once without materializing metadata',function()
    local a,_,load,c,lib=fixture();lib.libs['AceDBOptions-3.0']=nil;lib.libs['LibAboutPanel-2.0']=nil
    load('UI/settings_setup.lua');a:SetupOptions();a:SetupOptions()
    local registry=lib('AceConfigRegistry-3.0')
    assert(type(registry:GetOptionsTable('rotationmasterProfiles'))=='function')
    assert(type(registry:GetOptionsTable('rotationmasterAbout'))=='function')
    assert(c.profiles==0 and c.about==0 and c.categories==1 and c.modules==1)
    assert(a.configModuleApps['Friendly module']=='ExactModuleApp')
end)

test('actual registry queries preserve real DBOptions/About identity and install one legacy wrapper',function()
    local a,_,load,c,lib,query,about=fixture();load('UI/settings_setup.lua');a:SetupOptions()
    assert(c.profiles==0 and c.about==0,'metadata was materialized during native setup')
    local p=query('Profiles');local handler=p.handler;local wrapped=handler.SetProfile
    assert(p==lib('AceDBOptions-3.0').optionTables[a.db] and handler.db==a.db)
    for _=1,4 do a:SetupOptions();assert(query('Profiles')==p and p.handler.SetProfile==wrapped) end
    assert(c.profiles==1,'repeated GetOptionsTable resets the real library handler')
    handler:SetProfile({},'Other');assert(a.db:GetCurrentProfile()=='Other')
    assert(c.disable==1 and c.refresh==1 and c.enable==1,'legacy handler was wrapped more than once')
    assert(query('About')==about and query('About')==about and about.order==-1 and c.about==1)
end)

test('missing legacy provider dependencies fail only explicit queries and retry without caching failure',function()
    local a,_,load,c,lib,query=fixture();local profiles,about=lib.libs['AceDBOptions-3.0'],lib.libs['LibAboutPanel-2.0']
    lib.libs['AceDBOptions-3.0']=nil;lib.libs['LibAboutPanel-2.0']=nil
    load('UI/settings_setup.lua');a:SetupOptions()
    assert(not pcall(query,'Profiles') and not pcall(query,'About'))
    assert(c.profiles==0 and c.about==0 and c.categories==1)
    lib.libs['AceDBOptions-3.0']=profiles;lib.libs['LibAboutPanel-2.0']=about
    assert(query('Profiles').handler.db==a.db and query('About').order==-1)
    assert(c.profiles==1 and c.about==1)
end)

test('provider cache follows actual DB identity without changing a previously issued handler',function()
    local a,env,load,c,lib,query=fixture();load('UI/settings_setup.lua');a:SetupOptions()
    local firstDB=a.db;local first=query('Profiles');local firstMethod=first.handler.SetProfile
    env.SecondMetadataDB={};a.db=lib('AceDB-3.0'):New('SecondMetadataDB',{profile={enable=true}},'Second')
    local second=query('Profiles');assert(second~=first and second.handler.db==a.db and first.handler.db==firstDB)
    assert(first.handler.SetProfile==firstMethod and c.profiles==2)
    second.handler:SetProfile({},'New second');assert(a.db:GetCurrentProfile()=='New second' and firstDB:GetCurrentProfile()=='Shared')
    a.db=firstDB;assert(query('Profiles')==first and c.profiles==2)
end)

test('actual AceDB lifecycle owns profile transitions and keeps a disabled target disabled',function()
    local a,_,load,c,_,query=fixture()
    a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle();a:InstallRotationProfileLifecycle()
    a.db.profiles.Disabled={enable=false}
    load('UI/settings_setup.lua');a:SetupOptions();local p=query('Profiles')
    for _=1,3 do assert(query('Profiles')==p) end
    p.handler:SetProfile({},'Disabled')
    assert(a.db:GetCurrentProfile()=='Disabled' and a.db.profile.enable==false)
    assert(c.disable==1 and c.refresh==1 and c.enable==0,'legacy metadata duplicated or bypassed installed lifecycle')
    p.handler:SetProfile({},'Shared')
    assert(c.disable==2 and c.refresh==2 and c.enable==1)
end)

test('optional module bridge preserves the exact app name without querying metadata',function()
    local a,_,load,c,lib=fixture();load('UI/settings_setup.lua');a:SetupOptions();local host={};local calls=0
    lib:NewLibrary('AceConfigDialog-3.0',1).Open=function(_,app,parent) assert(app=='ExactModuleApp' and parent==host);calls=calls+1 end
    assert(a:BuildModuleConfigurationPane(host,'module:Friendly module') and calls==1)
    for _,name in ipairs({'Profiles','About','General','module:ExactModuleApp','module:unknown'}) do assert(not a:BuildModuleConfigurationPane(host,name)) end
    assert(c.profiles==0 and c.about==0)
end)
test('a cached legacy handler honors a lifecycle installed after its first query',function()
    local a,_,load,c,_,query=fixture();load('UI/settings_setup.lua');a:SetupOptions()
    local p=query('Profiles');local method=p.handler.SetProfile
    a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle()
    a.db.profiles.Disabled={enable=false};p.handler:SetProfile({},'Disabled')
    assert(p.handler.SetProfile==method and c.disable==1 and c.refresh==1 and c.enable==0)
end)

test('legacy wrappers preserve receiver, argument and return tuples and original errors',function()
    local a,_,load,c,lib,query=fixture();local info={};local marker={};local calls=0
    local options={type='group',name='Profiles',args={},handler={}}
    local original=function(self,received,value,...)
        calls=calls+1;assert(self==options.handler and received==info and value=='Target')
        assert(select('#',...)==2 and select(1,...)==nil and select(2,...)==marker)
        return marker,nil,'tail',nil
    end
    options.handler.SetProfile=original
    lib.libs['AceDBOptions-3.0'].GetOptionsTable=function() c.profiles=c.profiles+1;return options end
    load('UI/settings_setup.lua');a:SetupOptions();assert(query('Profiles')==options)
    local function check(...) assert(select('#',...)==4 and select(1,...)==marker and select(2,...)==nil and select(3,...)=='tail' and select(4,...)==nil) end
    check(options.handler:SetProfile(info,'Target',nil,marker));assert(calls==1 and c.disable==1 and c.refresh==1 and c.enable==1)
    a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle()
    check(options.handler:SetProfile(info,'Target',nil,marker));assert(calls==2 and c.disable==1 and c.refresh==1 and c.enable==1)
    local activeDB=a.db;a.db={};check(options.handler:SetProfile(info,'Target',nil,marker));a.db=activeDB
    assert(calls==3 and c.disable==1 and c.refresh==1 and c.enable==1)
    -- A separate real provider table catches failure behavior without replacing
    -- the wrapper under test or relying on DBOptions prototype mutation.
    local b,_,loadB,counts,libs,queryB=fixture();local failure={};local failedOptions={type='group',name='Profiles',args={},handler={SetProfile=function() error(failure) end}}
    libs.libs['AceDBOptions-3.0'].GetOptionsTable=function() return failedOptions end
    loadB('UI/settings_setup.lua');b:SetupOptions();queryB('Profiles')
    local ok,err=pcall(failedOptions.handler.SetProfile,failedOptions.handler,nil,'Bad')
    assert(not ok and err==failure and counts.disable==1 and counts.refresh==0 and counts.enable==0)
    b.InitializeScopedRotationStorage=function() return true end
    loadB('Core/rotation_lifecycle.lua');b:InstallRotationProfileLifecycle()
    ok,err=pcall(failedOptions.handler.SetProfile,failedOptions.handler,nil,'Bad')
    assert(not ok and err==failure and counts.disable==1 and counts.refresh==0 and counts.enable==0)
end)
test('actual lifecycle rebinds A to B and back while retired handlers and callbacks stay on their DB',function()
    local a,env,load,c,lib,query=fixture();a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle()
    local firstDB=a.db;local events={'OnProfileChanged','OnProfileCopied','OnProfileReset'}
    local retired={};local listener={};local observed=0;local firstOwner=a.rotationProfileLifecycleOwner
    for _,event in ipairs(events) do
        retired[event]=firstDB.callbacks.events[event][firstOwner]
        firstDB.RegisterCallback(listener,event,function() observed=observed+1 end)
    end
    a:InstallRotationProfileLifecycle()
    for _,event in ipairs(events) do assert(firstDB.callbacks.events[event][firstOwner]==retired[event],'duplicate install replaced callback') end
    load('UI/settings_setup.lua');a:SetupOptions();local first=query('Profiles')
    env.SecondMetadataDB={};local secondDB=lib('AceDB-3.0'):New('SecondMetadataDB',{profile={enable=true}},'Second');a.db=secondDB
    secondDB.profiles.Disabled={enable=false};local second=query('Profiles')
    assert(a.rotationProfileLifecycleDB==secondDB,'query retained authority from another database')
    second.handler:SetProfile({},'Active B')
    assert(c.disable==1 and c.refresh==1 and c.enable==1)
    second.handler:SetProfile({},'Disabled');assert(c.disable==2 and c.refresh==2 and c.enable==1)
    local active=secondDB.profile
    first.handler:SetProfile({},'Old handler target')
    firstDB.profiles.CopyA={enable=true};firstDB:SetProfile('Another A');firstDB:CopyProfile('CopyA');firstDB:ResetProfile()
    for _,event in ipairs(events) do retired[event](event,firstDB,'Captured') end
    assert(c.disable==2 and c.refresh==2 and c.enable==1 and secondDB.profile==active,'old database altered the active addon')
    assert(firstDB:GetCurrentProfile()=='Another A' and observed==4,'old DB receiver or other listeners were lost')
    local retiredB=secondDB.callbacks.events.OnProfileChanged[a.rotationProfileLifecycleOwner]
    a.db=firstDB;assert(query('Profiles')==first and a.rotationProfileLifecycleDB==firstDB)
    local currentOwner=a.rotationProfileLifecycleOwner;local current=firstDB.callbacks.events.OnProfileChanged[currentOwner];a:InstallRotationProfileLifecycle();assert(firstDB.callbacks.events.OnProfileChanged[currentOwner]==current)
    first.handler:SetProfile({},'Active A');assert(c.disable==3 and c.refresh==3 and c.enable==2)
    for _,event in ipairs(events) do retired[event](event,firstDB,'Old A binding') end
    assert(c.disable==3 and c.refresh==3 and c.enable==2,'retired A callbacks revived after returning to A')
    secondDB:SetProfile('Retired B');retiredB('OnProfileChanged',secondDB,'Captured B')
    assert(c.disable==3 and c.refresh==3 and c.enable==2 and firstDB:GetCurrentProfile()=='Active A')
end)

test('a cached active handler rebinds before dispatch even without another registry query',function()
    local a,env,load,c,lib,query=fixture();load('UI/settings_setup.lua');a:SetupOptions()
    local firstDB=a.db;local first=query('Profiles')
    env.SecondMetadataDB={};a.db=lib('AceDB-3.0'):New('SecondMetadataDB',{profile={enable=true}},'Second');local secondDB=a.db
    local second=query('Profiles');a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle()
    a.db=firstDB;first.handler:SetProfile({},'Cached A')
    assert(a.rotationProfileLifecycleDB==firstDB and c.disable==1 and c.refresh==1 and c.enable==1)
    second.handler:SetProfile({},'Retired B');assert(secondDB:GetCurrentProfile()=='Retired B' and c.disable==1 and c.refresh==1 and c.enable==1)
end)

test('lifecycle registration preserves the actual init reset seeder on the addon owner',function()
    local a,_,load,c=fixture();a.InitializeScopedRotationStorage=function() return true end
    local file=assert(io.open('init.lua'));local source=file:read('*a');file:close()
    local method=assert(source:match('(function addon:InitializeTalentTreeConditions.-)\nfunction addon:init%(%)'))
    a.isin=function(list,tag) for _,value in ipairs(list) do if value==tag then return true end end;return false end
    assert(loadstring('local addon=...; '..method))(a)
    a.db:RegisterDefaults({profile={enable=true,switch_conditions={},condition_groups={
        {id='b8136123-2bda-4230-a77a-89ea2aed3a1a',conditions={}},
        {id='8034819e-26f5-4f4e-9153-d8cab5e65f31',conditions={}},
    }}})
    a.db.RegisterCallback(a,'OnProfileReset','InitializeTalentTreeConditions')
    local seed=a.db.callbacks.events.OnProfileReset[a]
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle();a.db:ResetProfile()
    assert(a.db.callbacks.events.OnProfileReset[a]==seed,'lifecycle replaced the addon-owned reset initializer')
    local profile=a.db.profile
    assert(a.isin(profile.switch_conditions,'TALENT_TREE_POINTS') and a.isin(profile.switch_conditions,'PRIMARY_TALENT_TREE'))
    assert(a.isin(profile.condition_groups[1].conditions,'TALENT_TREE_POINTS') and a.isin(profile.condition_groups[1].conditions,'PRIMARY_TALENT_TREE'))
    assert(a.isin(profile.condition_groups[2].conditions,'SPELL_AUTOREPEAT'))
    assert(c.disable==1 and c.refresh==1 and c.enable==1)
end)

finish()
