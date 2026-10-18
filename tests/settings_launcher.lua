local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    local registered,options,profiles={},{},0
    local libs=f.libraries
    libs['AceConfigDialog-3.0']={AddToBlizOptions=function() error('editable child categories must not be registered') end}
    libs['AceConfig-3.0']={RegisterOptionsTable=function(_,key,value) options[key]=value end}
    libs['AceSerializer-3.0']={};libs['LibDBIcon-1.0']={}
    libs['AceDBOptions-3.0']={GetOptionsTable=function() return {handler={SetProfile=function(_,_,name) profiles=profiles+1;a.profileSelected=name end}} end}
    libs['LibAboutPanel-2.0']={AboutOptionsTable=function() return {type='group',args={}} end}
    f.env.LibStub=setmetatable({GetLibrary=function(_,name) return assert(libs[name]) end},{__call=function(_,name) return assert(libs[name],name) end})
    f.env.C_AddOns={GetAddOnMetadata=function(name,key) assert(name=='rotationmaster');return ({Title='Rotation Master',Author='Makiel',Version='test.1'})[key] end}
    a.name='rotationmaster';a.pretty_name='Rotation Master';a.opened=0
    a.ShowConfig=function(_,section) a.opened=a.opened+1;a.openedSection=section end
    a.RegisterOptionsCategory=function(_,frame) registered[#registered+1]=frame end
    a.IterateModules=function() return ipairs({{SetupOptions=function(_,register) register('TestModule','A module') end}}) end
    a.DisableRotation=function() a.disabled=true end;a.EnableRotation=function() a.enabled=true end
    a.RefreshConfiguration=function() a.refreshed=true end
    f.load('UI/settings_launcher.lua');f.load('Options/general.lua')
    return f,registered,options,function() return profiles end,frames
end

test('SetupOptions registers only one native launcher and opens the standalone workbench',function()
    local f,registered,options=fixture();local a=f.addon
    a:SetupOptions();a:SetupOptions()
    assert(#registered==1 and a.settingsLauncher and registered[1]==a.settingsLauncher.frame)
    assert(a.settingsLauncher.open:GetHeight()>=60)
    assert(a.settingsLauncher.commands.text:find('/rm config',1,true) and a.settingsLauncher.commands.text:find('/rm errors',1,true))
    assert(a.settingsLauncher.metadata.text:find('Makiel',1,true) and a.settingsLauncher.metadata.text:find('test.1',1,true))
    a.settingsLauncher.open:Click();assert(a.opened==1 and a.openedSection=='Rotations')
    assert(options.rotationmasterProfiles and options.rotationmasterAbout and a.configModuleApps['A module']=='TestModule')
end)
test('profile selection preserves the AceDB handler and refreshes only the standalone configuration',function()
    local f,_,options,count=fixture();local a=f.addon;a:SetupOptions()
    options.rotationmasterProfiles.handler.SetProfile({},nil,'Different profile')
    assert(count()==1 and a.profileSelected=='Different profile' and a.disabled and a.enabled and a.refreshed)
end)
finish()
