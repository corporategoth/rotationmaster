local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    local registered={}
    local libs=f.libraries
    f.env.LibStub=setmetatable({GetLibrary=function(_,name) return assert(libs[name]) end},{__call=function(_,name)
        assert(not name:find('AceGUI',1,true) and not name:find('AceConfig',1,true) and name~='AceDBOptions-3.0' and name~='LibAboutPanel-2.0','retired settings dependency: '..name)
        return assert(libs[name],name)
    end})
    f.env.C_AddOns={GetAddOnMetadata=function(name,key) assert(name=='rotationmaster');return ({Title='Rotation Master',Author='Makiel',Version='test.1'})[key] end}
    a.name='rotationmaster';a.pretty_name='Rotation Master';a.opened=0
    a.ShowConfig=function(_,section) a.opened=a.opened+1;a.openedSection=section end
    a.RegisterOptionsCategory=function(_,frame) registered[#registered+1]=frame end
    a.IterateModules=function() error('native launcher enumerated legacy module UI') end
    a.DisableRotation=function() a.disabled=true end;a.EnableRotation=function() a.enabled=true end
    a.RefreshConfiguration=function() a.refreshed=true end
    f.load('UI/settings_launcher.lua');f.load('UI/settings_setup.lua')
    return f,registered,frames
end

test('preview forwarding is available without loading the old General renderer',function()
    local f=fixture();local a=f.addon;local native={};a.CreateNativePreviewWindow=function(self) assert(self==a);return native end
    assert(a:CreatePreviewWindow()==native and not a.BuildConfigurationPane)
end)
test('SetupOptions registers only one native launcher and opens the standalone workbench',function()
    local f,registered=fixture();local a=f.addon
    a:SetupOptions();a:SetupOptions()
    assert(#registered==1 and a.settingsLauncher and registered[1]==a.settingsLauncher.frame)
    assert(a.settingsLauncher.open:GetHeight()>=60)
    assert(a.settingsLauncher.commands.text:find('/rm config',1,true) and a.settingsLauncher.commands.text:find('/rm errors',1,true))
    assert(a.settingsLauncher.metadata.text:find('Makiel',1,true) and a.settingsLauncher.metadata.text:find('test.1',1,true))
    a.settingsLauncher.open:Click();assert(a.opened==1 and a.openedSection=='Rotations')
    assert(not a.configModuleApps and not a.BuildModuleConfigurationPane and not a.BuildConfigurationPane)
end)
test('native specialization service keeps platform identities and localized default names',function()
    local f=fixture();local a=f.addon;local entries={{id=0},{id=2},{id=3,name='Named'}}
    a.db.char={specs={[2]='Saved spec'}}
    a.Platform.GetRotationSpecializations=function(_,classID) assert(classID==8);return entries end
    assert(a:GetRotationEditorSpecs(8)==entries and entries[1].name=='Rotations' and entries[2].name=='Saved spec' and entries[3].name=='Named')
    a.Platform.GetRotationSpecializations=function() return nil end
    local missing=a:GetRotationEditorSpecs(8);assert(#missing==1 and missing[1].id==0 and missing[1].name=='Rotations')
end)
test('normal load order retains native services without any retired Options renderer',function()
    local file=assert(io.open('RotationMaster.toc'));local text=file:read('*a');file:close();local entries={}
    for line in text:gmatch('[^\n]+') do if not line:match('^#') then entries[line]=true end end
    for _,name in ipairs({'general','effects','announce','itemset','rotations','custom_condition','conditions','conditional'}) do assert(not entries['Options/'..name..'.lua'],'ordinary TOC still installs '..name..' legacy renderer') end
    for _,path in ipairs({'Core/condition_catalog.lua','Core/itemset_services.lua','Core/custom_condition_services.lua','UI/settings_setup.lua','UI/condition_entrypoints.lua'}) do assert(entries[path],'required native service missing: '..path) end
end)
finish()
