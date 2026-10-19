local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local module='UI/condition_layout.lua'
local hashes={constructor='a71fe07c',CreateConditionGroup='d55214ba',verticalAlignment='4de23615',AceGUI='262048d5'}
local function fixture()
    local f=F.new();local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    f.libraries['AceGUI-3.0'].constructors['RM-ConditionGroup']=nil
    return f,f.addon,frames
end
local function sources(f)
    for _,path in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    f.env.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env) end;return fn,why end
end
local function realAce(f)
    local e=f.env;local ace=f.libraries['AceGUI-3.0'];local constructors=ace.constructors;local stub=e.LibStub
    e.LibStub=setmetatable({NewLibrary=function() return ace end},{__call=function(_,...) return stub(...) end})
    e.geterrorhandler=function() return error end
    e.xpcall=function(fn,handler,...) local args={n=select('#',...),...};return xpcall(function() return fn(unpack(args,1,args.n)) end,handler) end
    e.table=setmetatable({wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end},{__index=table})
    local create=e.CreateFrame
    e.CreateFrame=function(...)
        local frame=create(...);local width,height=frame:GetWidth(),frame:GetHeight()
        function frame:GetWidth() return width end;function frame:GetHeight() return height end
        function frame:SetSize(w,h) local changed=width~=w or height~=h;width,height=w,h;if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
        function frame:SetWidth(value) self:SetSize(value,height) end;function frame:SetHeight(value) self:SetSize(width,value) end
        return frame
    end
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua')
    for kind,build in pairs(constructors) do ace:RegisterWidgetType(kind,build,1) end
    f.load('Libs/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua')
    return ace
end
test('native group module loading and ordinary layouts never look up or register Ace',function()
    local f,a,frames=fixture();local stub=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native group looked up Ace');return stub(name,...) end
    f.libraries['AceGUI-3.0'].RegisterWidgetType=function() error('native group registered an Ace widget') end
    local before=#frames;f.load(module);assert(#frames==before,'group import allocated native controls')
    local group=a:CreateConditionGroup();group:SetWidth(320);local child=a:CreateConditionEditBox();child:SetFullWidth(true);group:AddChild(child)
    assert(group.rmActive and not group.rmLegacyOwned and child.frame:GetWidth()==320)
    group:SetUserData('table',{columns={1}});group:SetLayout('Table');group:SetLayout('RM-SpellField')
    local calls=0;child:SetText('saved');child:SetCallback('OnEnterPressed',function() calls=calls+1 end);child.editbox:SetText('pending');child.editbox:GetScript('OnTextChanged')(child.editbox,true)
    group.frame:SetScript('OnHide',function() child.editbox:GetScript('OnEditFocusLost')(child.editbox) end)
    local retired;group:SetCallback('Probe',function() calls=calls+1 end);retired=group.events.Probe
    assert(a:ReleaseConditionWidget(group) and not child:IsPending() and calls==0)
    local nextGroup=a:CreateConditionGroup();assert(nextGroup==group);retired(group,'Probe');assert(calls==0);a:ReleaseConditionWidget(nextGroup)
end)
test('group constructor factory alignment and actual library value retain exact original source identities',function()
    local f,a=fixture();f.load(module);sources(f)
    for name,hash in pairs(hashes) do local id='builtin:'..module..':'..name;local record=assert(a.builtinFunctions[id]);assert(a:FunctionSourceHash(record.source)==hash,'group source hash changed: '..name)
        if name~='AceGUI' then assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules[module](name)) end
    end
    local stub=f.env.LibStub;f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native factory source clone looked up Ace');return stub(name,...) end
    assert(a:InstallCustomFunction('NATIVE_GROUP_FACTORY',a.builtinFunctions['builtin:'..module..':CreateConditionGroup'].source))
    local group=a:ResolveFunctionBinding('NATIVE_GROUP_FACTORY')(a);assert(group.rmActive and not group.rmLegacyOwned and group.type=='RM-ConditionGroup');a:ReleaseConditionWidget(group)
end)
test('group compatibility binder is strict and assigns the exact real library to the original constructor cell',function()
    local f,a=fixture();f.load(module);assert(a.BindConditionGroupCompatibilityLibrary,'group compatibility binder missing')
    local ace=f.libraries['AceGUI-3.0'];assert(a:BindConditionGroupCompatibilityLibrary()==ace)
    local layouts=0;ace.GetLayout=function(self,name) assert(self==ace and name=='ReviewProbe');return function(content,children) layouts=layouts+1;assert(content.obj.children==children);content.obj:LayoutFinished(content:GetWidth(),91) end end
    local group=a:CreateConditionGroup();group:SetLayout('ReviewProbe');assert(layouts==1 and group.frame:GetHeight()==91);a:ReleaseConditionWidget(group)
    local lookups=0;f.env.LibStub=function(name,...) assert(name=='AceGUI-3.0' and select('#',...)==0);lookups=lookups+1;error('real group library unavailable') end
    local ok,why=pcall(a.BindConditionGroupCompatibilityLibrary,a);assert(not ok and tostring(why):find('real group library unavailable',1,true) and lookups==1)
end)
test('explicit group bridge registers version1 using only the original constructor with legacy true',function()
    local f,a,frames=fixture();f.load(module);local ace=realAce(f);local registrations,calls={},{}
    local register=ace.RegisterWidgetType;ace.RegisterWidgetType=function(self,name,build,version) registrations[#registrations+1]={name,version};return register(self,name,build,version) end
    local getter=a.builtinSourceModules[module]
    a.builtinSourceModules[module]=function(name) local original=getter(name);if name=='constructor' then return function(...) calls[#calls+1]={n=select('#',...),...};return original(...) end end;return original end
    local before=#frames;f.load('UI/native_group_compat.lua');assert(#frames==before and #registrations==1 and registrations[1][1]=='RM-ConditionGroup' and registrations[1][2]==1)
    local group=ace:Create('RM-ConditionGroup');assert(#calls==1 and calls[1].n==1 and calls[1][1]==true and group.rmActive and group.rmLegacyOwned);ace:Release(group);assert(not group.rmActive)
end)
test('historical group library getter initializes advanced layouts even without loading the bridge',function()
    local f,a=fixture();f.load(module);sources(f);local ace=realAce(f);local layouts=0
    ace:RegisterLayout('SavedLayout',function(content,children) layouts=layouts+1;assert(content.obj.children==children);content.obj:LayoutFinished(content:GetWidth(),73) end)
    local getter=a.builtinSourceModules[module];assert(getter('AceGUI')==ace and a:ResolveFunctionBinding('builtin:'..module..':AceGUI')==ace)
    local group=a:CreateConditionGroup();group:SetLayout('SavedLayout');assert(layouts==1 and group.frame:GetHeight()==73);a:ReleaseConditionWidget(group)
    local record=a.builtinFunctions['builtin:'..module..':constructor'];assert(a:InstallCustomFunction('SAVED_GROUP_CONSTRUCTOR',record.source))
    local historical=a:ResolveFunctionBinding('SAVED_GROUP_CONSTRUCTOR')(false);historical:OnAcquire();historical:SetLayout('SavedLayout');assert(layouts==2 and historical.frame:GetHeight()==73)
    local tableLayout=ace:GetLayout('Table');local tables=0;ace:RegisterLayout('Table',function(...) tables=tables+1;return tableLayout(...) end)
    historical:PauseLayout();historical:SetWidth(320);historical:SetLayout('Table');historical:SetUserData('table',{columns={1,1},alignV='bottom',spaceV=12})
    local children={};for i,height in ipairs({60,24,40,20}) do local child=a:CreateConditionCheckBox();child:SetHeight(height);if i==1 then child:SetUserData('cell',{alignV='top'}) end;historical:AddChild(child);children[i]=child end
    historical:ResumeLayout();assert(tables==1 and children[2].frame.point[4]==-36 and children[4].frame.point[4]==-92 and historical.frame:GetHeight()==112,'saved constructor lost shipped advanced Table semantics');a:ReleaseConditionWidget(historical)
end)
test('collector rejects missing proxy and foreign retained actual group library values',function()
    local function collect(mode)
        local wrapped={new=function(...)
            local f=F.new(...)
            if mode then local getter=f.addon.builtinSourceModules[module];local replacement=mode=='proxy' and setmetatable({},{__index=f.libraries['AceGUI-3.0']}) or mode=='foreign' and {} or nil
                f.addon.builtinSourceModules[module]=function(name) if name=='AceGUI' then return replacement end;return getter(name) end
            end
            return f
        end}
        local env=setmetatable({dofile=function(path) if path=='tests/fixtures/addon.lua' then return wrapped end;return dofile(path) end,print=function() end},{__index=_G})
        local tool=assert(loadfile('tools/collect_builtin_sources.lua'));setfenv(tool,env);return pcall(tool)
    end
    local ok,why=collect();assert(ok,why)
    for _,mode in ipairs({'missing','proxy','foreign'}) do ok,why=collect(mode);assert(not ok and tostring(why):find('retained widget library identity mismatch: '..module,1,true),'collector accepted '..mode..' group library: '..tostring(why)) end
end)
test('shipped Ace pools release mixed group owners discard pending descendants and retire captured callbacks',function()
    local f,a=fixture();f.load(module);local ace=realAce(f);f.load('UI/native_group_compat.lua');local seen={};local calls=0
    sources(f);assert(a:InstallCustomFunction('SAVED_ACE_GROUP',{description='Saved group factory',args={},returns={},bindings={AceGUI='builtin:'..module..':AceGUI'},code='return AceGUI:Create("RM-ConditionGroup")'}))
    local saved=a:ResolveFunctionBinding('SAVED_ACE_GROUP')();assert(saved.rmLegacyOwned and saved.rmActive);ace:Release(saved)
    for _=1,40 do
        local parent=ace:Create('SimpleGroup');local group=a:CreateConditionGroup();seen[group]=true;local child=a:CreateConditionEditBox();group:AddChild(child)
        child:SetText('saved');child:SetCallback('OnEnterPressed',function() calls=calls+1 end);child.editbox:SetText('pending');child.editbox:GetScript('OnTextChanged')(child.editbox,true)
        group:SetCallback('Probe',function() calls=calls+1 end);local old=group.events.Probe
        parent:AddChild(group);parent:SetCallback('OnRelease',function() group:Fire('Probe') end);ace:Release(parent)
        assert(not group.rmActive and not child.rmActive and not child:IsPending() and calls==0)
        local nextGroup=a:CreateConditionGroup();seen[nextGroup]=true;old(group,'Probe');assert(calls==0)
        local legacy=ace:Create('RM-ConditionGroup');seen[legacy]=true;nextGroup:AddChild(legacy);a:ReleaseConditionWidget(nextGroup);assert(not legacy.rmActive)
    end
    local count=0;for _ in pairs(seen) do count=count+1 end;assert(count<=2,'group compatibility stranded mixed-owner controls: '..count)
end)
finish()
