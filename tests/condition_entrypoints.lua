local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;local calls={lookups=0}
    a.conditionDefinitions={A={description='Original condition'}}
    a.conditionSpecials={DELETE={icon='delete',desc='Delete'},AND={icon='and',desc='All'},OR={icon='or',desc='Any'},NOT={icon='not',desc='Unless'}}
    local lib=f.env.LibStub
    f.env.LibStub=function(name,...) if name=='AceGUI-3.0' then calls.lookups=calls.lookups+1;if calls.poison then error('Ace lookup forbidden') end end;return lib(name,...) end
    return f,a,calls
end
test('native entry points forward exact arguments and return tuples without any Ace dependency',function()
    local f,a,calls=fixture();calls.poison=true;f.load('UI/condition_entrypoints.lua')
    local value,callback,target={},{},{};a.ShowConditionEditor=function(self,index,spec,v,cb,valid)
        assert(self==a and index==4 and spec==2 and v==value and cb==callback and valid==target);return nil,'native',nil,7
    end
    local function results(...) assert(select('#',...)==4);local first,why,third,last=...;assert(first==nil and why=='native' and third==nil and last==7) end
    results(a:EditCondition(4,2,value,callback,target))
    local frame={};frame.rmCompactRefresh=function(...) assert(select('#',...)==0);return 'compact',nil,3 end
    local function compact(...) assert(select('#',...)==3);local first,second,last=...;assert(first=='compact' and second==nil and last==3) end
    compact(a.LayoutConditionFrame(frame));assert(calls.lookups==0)
end)
test('legacy registration stays inert and factory initialization is cached and retryable',function()
    local f,a,calls=fixture();calls.poison=true;f.load('UI/condition_entrypoints.lua');f.load('Options/conditional.lua')
    assert(calls.lookups==0 and type(a.GetLegacyConditionRenderer)=='function')
    assert(not pcall(a.GetLegacyConditionRenderer,a) and calls.lookups==1)
    calls.poison=false;local api=a:GetLegacyConditionRenderer();assert(type(api.LayoutConditionFrame)=='function' and type(api.EditCondition)=='function')
    assert(a:GetLegacyConditionRenderer()==api and calls.lookups==2)
    calls.poison=true;a.ShowConditionEditor=function() return 'native' end;assert(a:EditCondition()=='native');assert(a.LayoutConditionFrame({rmCompactRefresh=function() return 'compact' end})=='compact')
    assert(calls.lookups==2,'native dispatch initialized or revisited Ace after compatibility activation')
end)
local function realAce(f)
    local e=f.env;local ace=f.libraries['AceGUI-3.0'];local previous=e.LibStub
    e.LibStub=setmetatable({NewLibrary=function() return ace end},{__call=function(_,...) return previous(...) end})
    e.geterrorhandler=function() return error end
    e.xpcall=function(fn,handler,...) local args={n=select('#',...),...};return xpcall(function() return fn(unpack(args,1,args.n)) end,handler) end
    e.table=setmetatable({wipe=function(value) for k in pairs(value) do value[k]=nil end;return value end},{__index=table})
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua')
    local made={};local containers={Frame=true,Window=true,ScrollFrame=true,SimpleGroup=true,DisablableInlineGroup=true}
    -- External widget geometry only; registry, ownership, release, callbacks,
    -- container methods and the complete legacy renderer remain real.
    for _,kind in ipairs({'Frame','Window','ScrollFrame','SimpleGroup','DisablableInlineGroup','Icon','InteractiveLabel','Label','EditBox','Dropdown'}) do
        ace:RegisterWidgetType(kind,function()
            local w={type=kind,frame=e.CreateFrame('Frame'),OnAcquire=function() end};made[#made+1]=w
            function w:Show() self.frame:Show() end;function w:Hide() self.frame:Hide() end
            function w:SetTitle(value) self.title=value end;function w:SetText(value) self.text=value end
            function w:SetStatusText(value) self.statusText=value end;function w:SetDisabled(value) self.disabled=value end
            function w:SetImage(value) self.image=value end;function w:SetImageSize() end;function w:SetJustifyH() end
            function w:DisableButton() end;function w:SetList() end;function w:SetValue() end
            if containers[kind] then w.content=e.CreateFrame('Frame',nil,w.frame);return ace:RegisterAsContainer(w) end
            return ace:RegisterAsWidget(w)
        end,1)
    end
    for _,name in ipairs({'Fill','Flow','Table'}) do ace:RegisterLayout(name,function() end) end
    return ace,made
end
test('actual retained renderer uses shipped Ace ownership and preserves legacy close callbacks',function()
    local f,a=fixture();local ace,made=realAce(f);f.load('UI/condition_entrypoints.lua');f.load('Options/conditional.lua')
    local widgetCalls,sequence=0,{}
    a.printCondition=function(_,root,spec) assert(root.type=='A' and spec==2);return 'Original summary' end
    a.validateCondition=function() return true end;a.listConditions=function() return {'A'} end
    a.describeCondition=function(_,tag) assert(tag=='A');return 'icon','Original condition' end
    a.widgetCondition=function(_,parent,spec,value) assert(spec==2 and value.type=='A');widgetCalls=widgetCalls+1;parent:AddChild(a:CreateConditionLabel()) end
    a.UpdateAutoSwitch=function() sequence[#sequence+1]='auto' end;a.SwitchRotation=function() sequence[#sequence+1]='switch' end
    a:EditCondition(3,2,{type='A'},function() sequence[#sequence+1]='close' end)
    local top=made[1];assert(top.type=='Frame' and top.title=='Edit Condition #3' and widgetCalls==1 and top:GetUserData('spec')==2)
    assert(top.children[1].type=='ScrollFrame' and top.children[1].children[1].type=='DisablableInlineGroup')
    local api=a:GetLegacyConditionRenderer();a.LayoutConditionFrame(top);assert(a:GetLegacyConditionRenderer()==api and widgetCalls==2 and #top.children==1)
    local released=0;top:SetCallback('OnRelease',function() released=released+1 end);top:Fire('OnClose')
    assert(released==1 and not top.frame:IsShown() and #top.children==0 and table.concat(sequence,',')=='close,auto,switch')
    assert(ace:GetWidgetVersion('Frame')==1)
end)
test('deferred helpers keep their registration-time registry special and utility identities',function()
    local f,a=fixture();local _,made=realAce(f);local used=0;local original=a.cleanArray
    a.db.profile.condition_groups={};a.ApplyCustomGlow=function() end;a.HideGlow=function() end;a.findConditionGroup=function() end
    a.cleanArray=function(...) used=used+1;return original(...) end
    f.load('UI/condition_entrypoints.lua');f.load('Options/conditional.lua')
    a.conditionDefinitions={};a.conditionSpecials={};a.cleanArray=function() error('late replacement utility used') end
    a.printCondition=function() return 'Summary' end;a.validateCondition=function() return true end;a.listConditions=function() return {'A'} end
    a.describeCondition=function() return 'icon','Original condition' end;a.widgetCondition=function() end
    a:EditCondition(1,0,{type='OTHER'})
    local top=made[1];local icon=top.children[1].children[1].children[1];icon:Fire('OnClick')
    local popup;for _,w in ipairs(made) do if w.type=='Window' then popup=w end end
    assert(popup and popup.children[2].children[1].text:find('Original condition',1,true),'factory rebound a replacement condition registry')
    local selected=popup.children[2].children[1];top:GetUserData('root').type='OTHER';selected:Fire('OnClick')
    assert(used==1 and top:GetUserData('root').type=='A','deferred type selection rebound captured utilities')
end)
finish()
