local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local modules={'UI/condition_icon.lua','UI/condition_position.lua','UI/condition_display.lua'}
local entries={{'RM-ConditionIcon','CreateConditionIcon',modules[1],'constructor',{true}},
    {'RM-ConditionPositionPad','CreateConditionPositionPad',modules[2],'constructor',{true}},
    {'RM-ConditionLink','CreateConditionLink',modules[3],'labelConstructor',{true,true}},
    {'RM-ConditionLabel','CreateConditionLabel',modules[3],'labelConstructor',{true}},
    {'RM-ConditionButton','CreateConditionButton',modules[3],'buttonConstructor',{true}}}
local hashes={
    [modules[1]]={constructor='b621f061',CreateConditionIcon='8b53eb7c'},
    [modules[2]]={constructor='516616ff',CreateConditionPositionPad='241fdcff'},
    [modules[3]]={labelConstructor='e60529cf',buttonConstructor='2f5f1302',defaultFont='da8d3722',CreateConditionLink='c6d1df57',CreateConditionLabel='141a187a',CreateConditionButton='e402e1de'},
}
local function fixture()
    local f=F.new();local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    for _,entry in ipairs(entries) do f.libraries['AceGUI-3.0'].constructors[entry[1]]=nil end
    return f,f.addon,frames
end
local function loadNative(f) for _,path in ipairs(modules) do f.load(path) end end
test('native implementation scripts load and acquire without Ace lookups or registration side effects',function()
    local f,a,frames=fixture();local stub=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native implementation looked up Ace');return stub(name,...) end
    f.libraries['AceGUI-3.0'].RegisterWidgetType=function() error('native implementation registered an Ace widget') end
    local before=#frames;loadNative(f);assert(#frames==before,'loading native implementation constructed frames')
    for _,entry in ipairs(entries) do
        local w=a[entry[2]](a);assert(w.type==entry[1] and w.rmActive and not w.rmLegacyOwned)
        local calls=0;w:SetCallback('Probe',function() calls=calls+1 end);local old=w.events.Probe
        assert(a:ReleaseConditionWidget(w));local reused=a[entry[2]](a);assert(reused==w);old(w,'Probe');assert(calls==0)
        assert(a:ReleaseConditionWidget(reused))
    end
end)
test('original constructor factory and private value source IDs retain exact hashes and native clones',function()
    local f,a=fixture();local stub=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native source clone looked up Ace');return stub(name,...) end
    loadNative(f)
    for _,path in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    for module,values in pairs(hashes) do for name,hash in pairs(values) do
        local id='builtin:'..module..':'..name;local record=assert(a.builtinFunctions[id]);assert(a:FunctionSourceHash(record.source)==hash,'source identity changed: '..id)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules[module](name))
    end end
    for index,entry in ipairs(entries) do
        local record=assert(a.builtinFunctions['builtin:'..entry[3]..':'..entry[2]])
        assert(a:InstallCustomFunction('NATIVE_FACTORY_'..index,a:CopySettingsData(record.source)))
        local widget=a:ResolveFunctionBinding('NATIVE_FACTORY_'..index)(a)
        assert(widget.type==entry[1] and widget.rmActive and not widget.rmLegacyOwned);a:ReleaseConditionWidget(widget)
    end
end)
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
test('explicit compatibility registers original names versions order and actual constructor arguments',function()
    local f,a,frames=fixture();loadNative(f);local ace=realAce(f);local registration,invocations={},{}
    local register=ace.RegisterWidgetType
    ace.RegisterWidgetType=function(self,name,build,version) registration[#registration+1]={name,version};return register(self,name,build,version) end
    for _,module in ipairs(modules) do
        local getter=a.builtinSourceModules[module]
        a.builtinSourceModules[module]=function(name)
            local original=getter(name)
            if name=='constructor' or name=='labelConstructor' or name=='buttonConstructor' then
                return function(...) invocations[#invocations+1]={module,name,n=select('#',...),...};return original(...) end
            end
            return original
        end
    end
    local before=#frames;f.load('UI/native_widget_compat.lua');assert(#frames==before and #registration==5,'compatibility registration allocated controls')
    for index,entry in ipairs(entries) do
        assert(registration[index][1]==entry[1] and registration[index][2]==1 and ace:GetWidgetVersion(entry[1])==1)
        local w=ace:Create(entry[1]);local call=invocations[index]
        assert(call[1]==entry[3] and call[2]==entry[4] and call.n==#entry[5])
        for i,value in ipairs(entry[5]) do assert(call[i+2]==value) end
        assert(w.rmLegacyOwned and w.rmActive and w.type==entry[1]);ace:Release(w);assert(not w.rmActive)
    end
end)
test('shared shipped Ace pools preserve native transfer queued release and stale callback ownership',function()
    local f,a=fixture();loadNative(f);local ace=realAce(f);f.load('UI/native_widget_compat.lua')
    for _,entry in ipairs(entries) do
        local seen={};local calls=0
        for _=1,20 do
            local parent=ace:Create('SimpleGroup');local widget=a[entry[2]](a);seen[widget]=true
            widget:SetCallback('Probe',function() calls=calls+1 end);local retired=widget.events.Probe
            parent:AddChild(widget);parent:SetCallback('OnRelease',function() widget:Fire('Probe') end)
            ace:Release(parent);assert(not widget.rmActive and calls==0)
            local nextWidget=a[entry[2]](a);seen[nextWidget]=true;retired(widget,'Probe');assert(calls==0)
            a:ReleaseConditionWidget(nextWidget)
            local root=a:CreateConditionGroup();local legacy=ace:Create(entry[1]);seen[legacy]=true;root:AddChild(legacy)
            a:ReleaseConditionWidget(root);assert(not legacy.rmActive and not a:ReleaseConditionWidget(legacy))
        end
        local count=0;for _ in pairs(seen) do count=count+1 end
        assert(count<=2,'mixed pool transfer stranded '..entry[1]..' controls')
    end
end)
finish()
