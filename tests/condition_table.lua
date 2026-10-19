local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,part in pairs(value) do result[key]=copy(part) end;return result
end
local function fixture()
    local f=F.new();local ace=f.libraries['AceGUI-3.0'];local constructors=ace.constructors;local stub=f.env.LibStub
    f.env.LibStub=setmetatable({NewLibrary=function() return ace end},{__call=function(_,...) return stub(...) end})
    f.env.geterrorhandler=function() return error end
    f.env.xpcall=function(fn,handler,...) local args={n=select('#',...),...};return xpcall(function() return fn(unpack(args,1,args.n)) end,handler) end
    f.env.table=setmetatable({wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end},{__index=table})
    local create=f.env.CreateFrame
    f.env.CreateFrame=function(...)
        local frame=create(...);local size=frame.SetSize;local point=frame.SetPoint;local clear=frame.ClearAllPoints
        function frame:SetSize(width,height) if self.width~=width or self.height~=height then size(self,width,height) end end
        function frame:SetPoint(...)
            point(self,...);self.points=self.points or {};local values={...}
            self.points[values[1]]={values[1],values[3],values[4],values[5]}
            self.anchors=self.anchors or {};self.anchors[values[1]]=values
            local left,right=self.anchors.LEFT,self.anchors.RIGHT
            if left and right and #left==4 and right[2]==left[2] and right[3]=='LEFT' then self:SetWidth(right[4]-left[3]) end
        end
        function frame:ClearAllPoints() clear(self);self.points={};self.anchors={} end
        return frame
    end
    f.load('Libs/AceGUI-3.0/AceGUI-3.0.lua')
    for kind,build in pairs(constructors) do ace:RegisterWidgetType(kind,build,1) end
    return f,f.addon,ace
end
local function group(a,settings,rows,width)
    local root=a:CreateConditionGroup();root:PauseLayout();root:SetWidth(width or 400);root:SetLayout('Table');root:SetUserData('table',copy(settings))
    local children={}
    for _,row in ipairs(rows) do
        local child=a:CreateConditionCheckBox();child:SetWidth(row.width or 40);child:SetHeight(row.height or 24)
        child:SetFullWidth(row.fill);child:SetFullHeight(row.fillHeight);child:SetUserData('cell',copy(row.cell))
        root:AddChild(child);if row.hidden then child.frame:Hide() end;children[#children+1]=child
    end
    return root,children
end
local function snapshot(root,children)
    local result={height=root.frame:GetHeight(),children={}}
    for index,child in ipairs(children) do result.children[index]={width=child.frame:GetWidth(),height=child.frame:GetHeight(),points=copy(child.frame.points)} end
    return result
end
local function equal(left,right,path)
    path=path or 'geometry';assert(type(left)==type(right),path..' type mismatch')
    if type(left)=='number' then assert(math.abs(left-right)<.0001,path..': '..left..' ~= '..right)
    elseif type(left)=='table' then
        for key,value in pairs(left) do equal(value,right[key],path..'.'..key) end
        for key in pairs(right) do assert(left[key]~=nil,path..' extra '..key) end
    else assert(left==right,path..' differs') end
end
local function compare(settings,rows,widths)
    local f,a,ace=fixture();local oracle=ace:GetLayout('Table');local actual,children=group(a,settings,rows)
    local expected,other=group(a,settings,rows)
    ace.GetLayout=function() error('native advanced Table requested Ace geometry') end
    for _,width in ipairs(widths or {400}) do
        actual:SetWidth(width);expected:SetWidth(width)
        actual:ResumeLayout();expected.layingOut=true;oracle(expected.frame,other);expected.layingOut=false
        equal(snapshot(actual,children),snapshot(expected,other))
        actual:PauseLayout();expected:PauseLayout()
    end
    return f,a,actual,children
end
test('native advanced Table uses descriptor widths and explicit spacing without Ace',function()
    compare({columns={{width=65},{weight=2},{weight=1}},spaceH=6,spaceV=9},{{height=45},{height=20,fill=true},{height=30},{height=18},{height=28,fill=true}}, {400,650,280})
end)
test('content min max relative and absolute columns match the shipped geometry',function()
    compare({columns={{min=55,max=80},{width=.25},{width=90},{weight=1}},space=7},{{width=35},{width=25},{width=30},{width=45},{width=110},{width=25}}, {400,600})
end)
test('cell column and container alignment precedence matches the shipped geometry',function()
    compare({columns={{width=120,align='BOTTOMRIGHT'},{weight=1,alignH='middle'}},align='TOPLEFT',spaceV=8},{{width=50,height=45},{width=60,height=20,cell={alignV='end'}},{width=35,height=18,cell={align='TOPLEFT'}},{width=70,height=38}}, {400,510})
end)
test('numeric and callback alignments and full height match the shipped geometry',function()
    local function alignment(child,cell,direction) return direction=='H' and cell-child-3 or 4 end
    compare({columns={{weight=1},{weight=1}},alignV=alignment,spaceH=3},{{height=60},{height=20,cell={alignH=14}},{height=35,fillHeight=true,cell={alignV='fill'}},{height=50,cell={alignH=alignment}}})
end)
test('noncompact vertical alignment strings use native shipped alignment semantics',function()
    compare({columns={1,1}},{{height=60},{height=20,cell={alignV='LEFT'}}})
end)
test('colspans rowspans partial rows and hidden children match the shipped geometry',function()
    compare({columns={{width=55},{weight=1},{weight=2}},space=6},{{height=80,cell={rowspan=2}},{height=25,cell={colspan=2},fill=true},{height=100,hidden=true},{height=35},{height=50},{height=20,cell={colspan=2}}}, {400,580})
end)
test('native descriptors are not rewritten as layout runs',function()
    local _,a,ace=fixture();local root=group(a,{columns={1,2},space=8},{{},{}});local settings=root:GetUserData('table');local before=copy(settings)
    ace.GetLayout=function() error('native Table queried Ace') end;root:ResumeLayout();equal(settings,before,'settings')
end)
test('alignment errors release native layout lock for a later valid pass',function()
    local _,a,ace=fixture();local root=group(a,{columns={{weight=1}},alignV=function() error('alignment failed') end},{{}})
    ace.GetLayout=function() error('native Table queried Ace') end
    local ok,why=pcall(root.ResumeLayout,root);assert(not ok and tostring(why):find('alignment failed',1,true),why)
    assert(not root.layingOut and not root.paused,'failed alignment stranded the layout lock')
    root:GetUserData('table').alignV='top';root:DoLayout();assert(root.frame:GetHeight()==24)
end)
test('plain numeric native tables retain compact geometry and parent height propagation',function()
    local _,a,ace=fixture();local parent=a:CreateConditionGroup();local root,children=group(a,{columns={44,1}},{{height=50},{height=24}},320)
    parent:AddChild(root);ace.GetLayout=function() error('basic Table requested Ace') end;root:ResumeLayout()
    assert(children[2].frame:GetWidth()==272 and root.frame:GetHeight()==50 and parent.frame:GetHeight()==50)
end)
test('native and historical layout modes follow each acquisition lease through real Ace pools',function()
    local _,a,ace=fixture();local original=ace.GetLayout;local calls=0
    ace.GetLayout=function(self,name) calls=calls+1;return original(self,name) end
    local root=group(a,{columns={{weight=1}},space=8},{{}});root:ResumeLayout();assert(calls==0)
    ace:Release(root);local legacy=ace:Create('RM-ConditionGroup');assert(legacy==root,'fixture did not cross pools')
    legacy:PauseLayout();legacy:SetUserData('table',{columns={{weight=1}},space=8});legacy:SetLayout('Table');legacy:AddChild(a:CreateConditionCheckBox());legacy:ResumeLayout()
    assert(calls==1,'native override leaked into historical Ace acquisition')
    ace:Release(legacy);local native=a:CreateConditionGroup();assert(native==root)
    native:PauseLayout();native:SetUserData('table',{columns={{weight=1}},space=8});native:SetLayout('Table');native:AddChild(a:CreateConditionCheckBox());native:ResumeLayout()
    assert(calls==1,'reused ordinary native acquisition fell back to Ace')
    a:ReleaseConditionWidget(native)
end)
test('explicit arbitrary named layouts retain the actual compatibility renderer',function()
    local _,a,ace=fixture();local root=a:CreateConditionGroup();local calls=0
    ace:RegisterLayout('ReviewedExternal',function(content) calls=calls+1;content.obj:LayoutFinished(nil,74) end)
    root:SetLayout('ReviewedExternal');assert(calls==1 and root.frame:GetHeight()==74)
end)
test('pathological native spans fail promptly even with hidden trailing children',function()
    local _,a,ace=fixture();local root=group(a,{columns={{weight=1}}},{{cell={rowspan=1000000000}},{},{hidden=true}})
    ace.GetLayout=function() error('unsafe span escaped into Ace') end
    local instructions=0;debug.sethook(function() instructions=instructions+1000;if instructions>100000 then error('unbounded table traversal') end end,'',1000)
    local ok,why=pcall(root.ResumeLayout,root);debug.sethook()
    assert(not ok and tostring(why):find('condition-table-work-limit',1,true),why)
    assert(not root.layingOut and not root.paused)
    root.children[1]:SetUserData('cell',nil);root:DoLayout();assert(root.frame:GetHeight()==48)
end)
test('native advanced widths reflow actual nested label groups and propagate new height',function()
    local _,a,ace=fixture();local outer=a:CreateConditionGroup()
    local root=a:CreateConditionGroup();root:PauseLayout();root:SetWidth(720);root:SetLayout('Table');root:SetUserData('table',{columns={{width=80},{weight=1}},spaceH=8})
    local first=a:CreateConditionCheckBox();root:AddChild(first)
    local nested=a:CreateConditionGroup();nested:SetFullWidth(true)
    local label=a:CreateConditionLabel();label:SetFullWidth(true);label:SetText(string.rep('Wrapped information ',10));nested:AddChild(label);root:AddChild(nested)
    outer:AddChild(root);ace.GetLayout=function() error('nested native geometry requested Ace') end;root:ResumeLayout()
    local wide=root.frame:GetHeight();assert(nested.frame:GetWidth()==632 and outer.frame:GetHeight()==wide)
    root:SetWidth(320);local narrow=root.frame:GetHeight()
    assert(nested.frame:GetWidth()==232 and narrow>wide and outer.frame:GetHeight()==narrow,'nested wrapped height did not propagate')
    root:SetWidth(720);assert(root.frame:GetHeight()==wide and label.frame:GetHeight()==wide)
end)
finish()
