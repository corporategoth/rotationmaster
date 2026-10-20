local test,finish=dofile('tests/fixtures/addon.lua').suite()
-- Actual bundled AceDB/CallbackHandler remain runtime services. No GUI,
-- options registry, DBOptions or About provider is installed in this fixture.
local function fixture()
    local env=setmetatable({MetadataDB={}},{__index=_G});env._G=env;env.LibStub=false
    env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
    env.UnitFactionGroup=function() return 'Horde' end;env.GetLocale=function() return 'enUS' end
    env.UnitClass=function() return 'Shaman','SHAMAN' end;env.UnitRace=function() return 'Orc','Orc' end
    env.GetRealmName=function() return 'Realm' end;env.UnitNameUnmodified=function() return 'Player' end
    env.GetCurrentRegionName=function() return 'US' end;env.GetCurrentRegion=function() return 1 end
    env.strlenutf8=string.len;env.securecallfunction=function(fn,...) return fn(...) end
    local a={name='rotationmaster'}
    local function load(path) local c=assert(loadfile(path));setfenv(c,env);return c('rotationmaster',a) end
    for _,p in ipairs({'Libs/LibStub/LibStub.lua','Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua','Libs/AceDB-3.0/AceDB-3.0.lua'}) do load(p) end
    local lib=env.LibStub
    lib:NewLibrary('AceLocale-3.0',1).GetLocale=function() return setmetatable({},{__index=function(_,k) return k end}) end
    a.db=lib('AceDB-3.0'):New('MetadataDB',{profile={enable=true}},'Shared')
    local counts={categories=0,disable=0,enable=0,refresh=0}
    a.CreateSettingsLauncher=function() return {frame={}} end
    a.RegisterOptionsCategory=function(_,frame) assert(frame==a.settingsLauncher.frame);counts.categories=counts.categories+1 end
    a.IterateModules=function() error('native setup invoked the retired module UI protocol') end
    a.DisableRotation=function() counts.disable=counts.disable+1 end
    a.EnableRotation=function() counts.enable=counts.enable+1 end
    a.RefreshConfiguration=function() counts.refresh=counts.refresh+1 end
    load('Core/rotation_active.lua')
    return a,env,load,counts,lib
end

test('native setup has no GUI metadata applications or legacy module discovery',function()
    local a,_,load,c,lib=fixture();local get=getmetatable(lib).__call
    getmetatable(lib).__call=function(self,name,...)
        assert(not name:find('AceGUI',1,true) and not name:find('AceConfig',1,true) and name~='AceDBOptions-3.0' and name~='LibAboutPanel-2.0','retired GUI library requested: '..name)
        return get(self,name,...)
    end
    load('UI/settings_setup.lua');a:SetupOptions();a:SetupOptions()
    assert(c.categories==1 and not a.BuildModuleConfigurationPane and not a.BuildConfigurationPane)
end)

test('actual AceDB lifecycle owns disabled profile transitions without a GUI handler',function()
    local a,_,load,c=fixture();a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle();a:InstallRotationProfileLifecycle()
    a.db.profiles.Disabled={enable=false};a.db:SetProfile('Disabled')
    assert(a.db.profile.enable==false and c.disable==1 and c.refresh==1 and c.enable==0)
    a.db:SetProfile('Shared');assert(c.disable==2 and c.refresh==2 and c.enable==1)
end)

test('actual lifecycle rebinds A to B and back without reviving retired callbacks or removing other listeners',function()
    local a,env,load,c,lib=fixture();a.InitializeScopedRotationStorage=function() return true end
    load('Core/rotation_lifecycle.lua');a:InstallRotationProfileLifecycle()
    local firstDB=a.db;local events={'OnProfileChanged','OnProfileCopied','OnProfileReset'}
    local retired={};local listener={};local observed=0;local firstOwner=a.rotationProfileLifecycleOwner
    for _,event in ipairs(events) do retired[event]=firstDB.callbacks.events[event][firstOwner];firstDB.RegisterCallback(listener,event,function() observed=observed+1 end) end
    a:InstallRotationProfileLifecycle();for _,event in ipairs(events) do assert(firstDB.callbacks.events[event][firstOwner]==retired[event]) end
    env.SecondMetadataDB={};local secondDB=lib('AceDB-3.0'):New('SecondMetadataDB',{profile={enable=true}},'Second');a.db=secondDB
    a:InstallRotationProfileLifecycle();secondDB.profiles.Disabled={enable=false};secondDB:SetProfile('Disabled')
    assert(c.disable==1 and c.refresh==1 and c.enable==0)
    firstDB.profiles.CopyA={enable=true};firstDB:SetProfile('Another A');firstDB:CopyProfile('CopyA');firstDB:ResetProfile()
    for _,event in ipairs(events) do retired[event](event,firstDB,'Captured') end
    assert(c.disable==1 and c.refresh==1 and c.enable==0 and observed==3 and secondDB:GetCurrentProfile()=='Disabled')
    local retiredB=secondDB.callbacks.events.OnProfileChanged[a.rotationProfileLifecycleOwner]
    a.db=firstDB;a:InstallRotationProfileLifecycle();local owner=a.rotationProfileLifecycleOwner;a:InstallRotationProfileLifecycle();assert(a.rotationProfileLifecycleOwner==owner)
    firstDB:SetProfile('Active A');assert(c.disable==2 and c.refresh==2 and c.enable==1)
    for _,event in ipairs(events) do retired[event](event,firstDB,'Old A binding') end
    secondDB:SetProfile('Retired B');retiredB('OnProfileChanged',secondDB,'Captured B')
    assert(c.disable==2 and c.refresh==2 and c.enable==1 and firstDB:GetCurrentProfile()=='Active A')
end)

test('lifecycle registration preserves the actual init reset seeder on the addon owner',function()
    local a,_,load,c=fixture();a.InitializeScopedRotationStorage=function() return true end
    local file=assert(io.open('init.lua'));local source=file:read('*a');file:close()
    local method=assert(source:match('(function addon:InitializeTalentTreeConditions.-)\nfunction addon:init%(%)'))
    load('Functions/values.lua')
    local function contains(list,tag) for _,value in ipairs(list) do if value==tag then return true end end;return false end
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
    assert(contains(profile.switch_conditions,'TALENT_TREE_POINTS') and contains(profile.switch_conditions,'PRIMARY_TALENT_TREE'))
    assert(contains(profile.condition_groups[1].conditions,'TALENT_TREE_POINTS') and contains(profile.condition_groups[1].conditions,'PRIMARY_TALENT_TREE'))
    assert(contains(profile.condition_groups[2].conditions,'SPELL_AUTOREPEAT'))
    assert(c.disable==1 and c.refresh==1 and c.enable==1)
end)

finish()
