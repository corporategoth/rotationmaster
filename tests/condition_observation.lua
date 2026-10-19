local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('UI/condition_observation.lua');return f,f.addon
end
local function noAce(f)
    local stub=f.env.LibStub
    f.env.LibStub=function(name,...) if name=='AceGUI-3.0' then error('Ace is unavailable') end;return stub(name,...) end
end
local function realAce(f)
    local e=f.env;local ace=f.libraries['AceGUI-3.0'];local stub=e.LibStub
    e.LibStub=setmetatable({NewLibrary=function() return ace end},{__call=function(_,...) return stub(...) end})
    e.geterrorhandler=function() return error end
    e.xpcall=function(fn,handler,...) local args={n=select('#',...),...};return xpcall(function() return fn(unpack(args,1,args.n)) end,handler) end
    e.table=setmetatable({wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end},{__index=table})
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua');f.load('Libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua')
    return ace
end
for _,path in ipairs({'UI/condition_observation.lua','UI/config.lua','UI/rotation_browser.lua','UI/condition_source_preview.lua','Help/conditions.lua'}) do
    test('native module loads without Ace: '..path,function() local f=F.new();noAce(f);f.load(path) end)
end
test('native observation preserves nil tuples and removes tracking after invocation',function()
    local f,a=fixture();noAce(f);local seen={}
    local function results(...) assert(select('#',...)==5);local ok,first,second,third,last=...;assert(ok and first==nil and second=='value' and third==nil and last==7) end
    results(a:WithConditionWidgetObservation(function(w) seen[#seen+1]=w end,pcall,function()
        local w=a:CreateConditionIcon();assert(seen[1]==w);w:Release();return nil,'value',nil,7
    end))
    local w=a:CreateConditionIcon();assert(#seen==1,'observer survived callback');w:Release()
end)
test('mixed tracking catches orphan legacy controls and restores the exact factory on failure',function()
    local f,a=fixture();local ace=realAce(f);local original=ace.Create;local seen={}
    local ok,why=a:WithConditionWidgetObservation(function(w) seen[#seen+1]=w end,pcall,function()
        ace:Create('Label');a:CreateConditionIcon();error('render failed')
    end)
    assert(not ok and tostring(why):find('render failed',1,true) and #seen==2 and ace.Create==original)
    for _,w in ipairs(seen) do a:ReleaseConditionWidget(w) end
    ace:Create('Label');local w=a:CreateConditionIcon();assert(#seen==2);w:Release()
end)
test('nested observation restores each surrounding scope and preserves callback arguments',function()
    local f,a=fixture();local ace=f.libraries['AceGUI-3.0'];local original=ace.Create;local outer,inner=0,0
    local ok=a:WithConditionWidgetObservation(function() outer=outer+1 end,pcall,function(...)
        assert(select('#',...)==3 and select(2,...)==nil);local surrounding=ace.Create
        local child,first,last=a:WithConditionWidgetObservation(function() inner=inner+1 end,pcall,function() ace:Create('Label');return nil,9 end)
        assert(child and first==nil and last==9 and ace.Create==surrounding);ace:Create('Label')
    end,'one',nil,'three')
    assert(ok and outer==2 and inner==1 and ace.Create==original)
end)
test('throwing guards and executors cannot strand shared factories or native observers',function()
    local f,a=fixture();local ace=f.libraries['AceGUI-3.0'];local original=ace.Create;local seen=0
    local ok,why=a:WithConditionWidgetObservation(function() seen=seen+1;error('guard failed') end,pcall,function() ace:Create('Label') end)
    assert(not ok and tostring(why):find('guard failed',1,true) and ace.Create==original)
    local invokeOk,invokeWhy=pcall(a.WithConditionWidgetObservation,a,function() seen=seen+1 end,function() error('executor failed') end,function() end)
    assert(not invokeOk and tostring(invokeWhy):find('executor failed',1,true) and ace.Create==original)
    local w=a:CreateConditionIcon();w:Release();assert(seen==1,'failed scopes retained native observers')
end)
test('caller protected executor preserves its diagnostics result convention',function()
    local f,a=fixture();local callback=function(v) assert(v==4);return nil,'reason' end
    local function executor(fn,...) assert(fn==callback);local ok,first,why=pcall(fn,...);return ok,first,why,'diagnostics' end
    local function result(...) assert(select('#',...)==4);local ok,first,why,kind=...;assert(ok and first==nil and why=='reason' and kind=='diagnostics') end
    result(a:WithConditionWidgetObservation(function() end,executor,callback,4))
end)
test('native focus clears without Ace and mixed cleanup uses the actual library',function()
    local f,a=fixture();local focus={cleared=0};function focus:ClearFocus() self.cleared=self.cleared+1 end
    f.env.GetCurrentKeyBoardFocus=function() return focus end;local ace=f.libraries['AceGUI-3.0'];local cleared=0
    ace.ClearFocus=function(self) assert(self==ace);cleared=cleared+1 end
    a:ClearConditionWidgetFocus();assert(focus.cleared==1 and cleared==1)
    noAce(f);a:ClearConditionWidgetFocus();assert(focus.cleared==2 and cleared==1)
end)
test('native shell has no required Ace dependency while borrowed module panes keep actual ownership',function()
    local f,a=fixture();f.load('UI/help.lua');f.load('UI/config.lua');a.pretty_name='Rotation Master';a.name='rotationmaster';a.SetupOptions=function() end
    a.OpenNativeSettings=function(_,parent) local pane={frame=f.env.CreateFrame('Frame',nil,parent)};function pane:SetWidth(v) self.frame:SetWidth(v) end;function pane:SetHeight(v) self.frame:SetHeight(v) end;function pane:Release() self.released=true end;return pane end
    noAce(f);local shell=a:ShowConfig('General');local pane=shell.pane;shell:Hide(true);assert(pane.released)
    local g,b=fixture();g.load('UI/help.lua');g.load('UI/config.lua');b.pretty_name='Rotation Master';b.name='rotationmaster';b.SetupOptions=function() end;b.configModuleApps={Example='example-options'}
    local ace=g.libraries['AceGUI-3.0'];local create=ace.Create;local released=0
    ace.Create=function(self,kind) assert(self==ace and kind=='SimpleGroup');local w=create(self,kind);w.frame=g.env.CreateFrame('Frame');return w end
    ace.Release=function(self,w) assert(self==ace);released=released+1;w.frame:Hide() end
    b.BuildModuleConfigurationPane=function(_,host,key) assert(host.kind=='SimpleGroup' and key=='module:Example') end
    local module=b:ShowConfig('module:Example');module:Hide(true);assert(released==1)
end)
test('actual native Test compiles and renders fields without Ace and retires saved callbacks',function()
    local f,a=fixture();f.load('Core/custom_condition_services.lua');f.load('Core/custom_authoring.lua');f.load('UI/condition_source_preview.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    local source=a:CopySettingsData(a.empty_condition);source.description='Native observation';source.fields={text='string'}
    source.valid='return type(value.text)=="string"';source.evaluate='return value.text=="changed"'
    source.widget=[[local input=addon:CreateConditionEditBox();input:SetText(value.text);input:SetCallback('OnEnterPressed',function(_,_,text) value.text=text end);parent:AddChild(input)]]
    source.help=''
    local baseline=a:CopySettingsData(source);local active=true;local owner={model={key='TEST_NATIVE'},frame=f.env.CreateFrame('Frame')}
    owner.OwnerValid=function() return active end;function owner:Flush() return true end;function owner:PendingSource() return source end
    function owner:HideForChild() self.frame:Hide() end;function owner:Show() self.frame:Show() end
    noAce(f);local surface=a:ShowConditionSourceTest(owner);assert(surface and not surface.failed)
    local input=surface.pane.children[1];local stale=input.events.OnEnterPressed
    input:Fire('OnEnterPressed','changed');surface.check:Click();assert(surface.lastResult and surface.lastResult.status=='match')
    surface:Close();assert(not input.rmActive and owner.frame:IsShown());local reused=a:CreateConditionEditBox();local text=surface.sample
    stale(input,'OnEnterPressed','retired');assert(surface.sample==text and not surface.active);reused:Release()
    local second=a:ShowConditionSourceTest(owner);assert(second==surface and second.active and not second.failed)
    active=false;second.frame.scripts.OnUpdate(second.frame,1);assert(not second.active and not second.frame:IsShown())
    assert(a:SettingsDataEqual(source,baseline),'Test changed authored source')
end)
test('actual debug surface releases a shipped Ace orphan on failure and retires invocation',function()
    local f,a=fixture();local ace=realAce(f);f.load('UI/condition_source_preview.lua')
    local owner={model={key='TEST_LEGACY'},frame=f.env.CreateFrame('Frame'),OwnerValid=function() return true end}
    function owner:Flush() return true end;function owner:PendingSource() return {description='Legacy test',fields={}} end;function owner:Show() end
    local surface=a:CreateConditionDebugSurface(owner,'widget');assert(surface and surface.parent and not surface.failed)
    local original=ace.Create;local orphan
    surface:Invoke('orphan-error',function() orphan=ace:Create('Label');error('legacy orphan failed') end)
    assert(surface.failed and orphan and not orphan.frame:IsShown() and ace.Create==original and not next(surface.owned))
    surface:Close();surface:Invoke('retired',function() error('retired callback ran') end);assert(not surface.active)
end)
finish()
