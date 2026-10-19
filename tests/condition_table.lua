local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,part in pairs(value) do result[key]=copy(part) end;return result
end
local function fixture()
    local f=F.new();local lookup=f.env.LibStub
    f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','native Table requested a GUI library');return lookup(name,...) end
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
    return f,f.addon
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
local function near(actual,expected) assert(math.abs(actual-expected)<.0001,tostring(actual)..' ~= '..tostring(expected)) end
local function box(child,width,height,left,top)
    near(child.frame:GetWidth(),width);near(child.frame:GetHeight(),height)
    near(child.frame.points.LEFT[2],left);near(child.frame.points.TOP[3],-top)
end
test('native advanced descriptor weights and spacing retain explicit geometry across widths',function()
    local _,a=fixture();local root,children=group(a,{columns={{width=65},{weight=2},{weight=1}},spaceH=6,spaceV=9},{{height=45},{height=20,fill=true},{height=30},{height=18},{height=28,fill=true}})
    for _,case in ipairs({{400,215+1/3,107+2/3},{650,382,191},{280,135+1/3,67+2/3}}) do root:SetWidth(case[1]);root:ResumeLayout()
        near(root.frame:GetHeight(),82);box(children[1],40,45,0,0);box(children[2],case[2],20,71,12.5);box(children[3],40,30,77+case[2],7.5)
        box(children[4],40,18,0,59);box(children[5],case[2],28,71,54);root:PauseLayout()
    end
end)
test('content min max relative and absolute columns retain independent width constraints',function()
    local _,a=fixture();local root,children=group(a,{columns={{min=55,max=80},{width=.25},{width=90},{weight=1}},space=7},{{width=35},{width=25},{width=30},{width=45},{width=110},{width=25}})
    for _,case in ipairs({{400,94.75},{600,144.75}}) do root:SetWidth(case[1]);root:ResumeLayout();near(root.frame:GetHeight(),55)
        box(children[1],35,24,0,0);box(children[2],25,24,87,0);box(children[3],30,24,94+case[2],0);box(children[4],45,24,191+case[2],0)
        box(children[5],80,24,0,31);box(children[6],25,24,87,31);root:PauseLayout()
    end
end)
test('cell column and container alignment precedence retains explicit row positions',function()
    local _,a=fixture();local root,children=group(a,{columns={{width=120,align='BOTTOMRIGHT'},{weight=1,alignH='middle'}},align='TOPLEFT',spaceV=8},{{width=50,height=45},{width=60,height=20,cell={alignV='end'}},{width=35,height=18,cell={align='TOPLEFT'}},{width=70,height=38}})
    for _,width in ipairs({400,510}) do root:SetWidth(width);root:ResumeLayout();near(root.frame:GetHeight(),91)
        box(children[1],50,45,70,0);box(children[2],60,20,120+(width-180)/2,25);box(children[3],35,18,0,53);box(children[4],70,38,120+(width-190)/2,53);root:PauseLayout()
    end
end)
test('numeric callback alignments and full height preserve their native geometry',function()
    local function alignment(child,cell,direction) return direction=='H' and cell-child-3 or 4 end
    local _,a=fixture();local root,children=group(a,{columns={{weight=1},{weight=1}},alignV=alignment,spaceH=3},{{height=60},{height=20,cell={alignH=14}},{height=35,fillHeight=true,cell={alignV='fill'}},{height=50,cell={alignH=alignment}}})
    root:ResumeLayout();near(root.frame:GetHeight(),110);box(children[1],40,60,0,4);box(children[2],40,20,215.5,4);box(children[3],40,50,0,60);box(children[4],40,50,357,64)
end)
test('noncompact vertical alignment strings retain centered native placement',function()
    local _,a=fixture();local root,children=group(a,{columns={1,1}},{{height=60},{height=20,cell={alignV='LEFT'}}})
    root:ResumeLayout();near(root.frame:GetHeight(),60);box(children[1],40,60,0,0);box(children[2],40,20,200,20)
end)
test('colspans rowspans partial rows and hidden children retain explicit measured geometry',function()
    local _,a=fixture();local root,children=group(a,{columns={{width=55},{weight=1},{weight=2}},space=6},{{height=80,cell={rowspan=2}},{height=25,cell={colspan=2},fill=true},{height=100,hidden=true},{height=35},{height=50},{height=20,cell={colspan=2}}})
    for _,case in ipairs({{400,339,178},{580,519,238}}) do root:SetWidth(case[1]);root:ResumeLayout();near(root.frame:GetHeight(),112)
        box(children[1],40,80,0,3);box(children[2],case[2],25,61,0);assert(not children[3]:IsShown());box(children[4],40,35,61,41);box(children[5],40,50,case[3],33.5);box(children[6],40,20,0,92);root:PauseLayout()
    end
end)
test('native descriptors are not rewritten as layout runs',function()
    local _,a=fixture();local root=group(a,{columns={1,2},space=8},{{},{}});local settings=root:GetUserData('table');local before=copy(settings)
root:ResumeLayout();equal(settings,before,'settings')
end)
test('alignment errors release native layout lock for a later valid pass',function()
    local _,a=fixture();local root=group(a,{columns={{weight=1}},alignV=function() error('alignment failed') end},{{}})

    local ok,why=pcall(root.ResumeLayout,root);assert(not ok and tostring(why):find('alignment failed',1,true),why)
    assert(not root.layingOut and not root.paused,'failed alignment stranded the layout lock')
    root:GetUserData('table').alignV='top';root:DoLayout();assert(root.frame:GetHeight()==24)
end)
test('plain numeric native tables retain compact geometry and parent height propagation',function()
    local _,a=fixture();local parent=a:CreateConditionGroup();local root,children=group(a,{columns={44,1}},{{height=50},{height=24}},320)
    parent:AddChild(root);root:ResumeLayout()
    assert(children[2].frame:GetWidth()==272 and root.frame:GetHeight()==50 and parent.frame:GetHeight()==50)
end)
test('native rich geometry survives pooled release and re-acquisition with no foreign lease mode',function()
    local _,a=fixture();local root=group(a,{columns={{weight=1}},space=8},{{}});root:ResumeLayout();a:ReleaseConditionWidget(root)
    local reused=a:CreateConditionGroup();assert(reused==root);reused:PauseLayout();reused:SetLayout('Table');reused:SetUserData('table',{columns={{width=75},{weight=1}},spaceH=8})
    local first=a:CreateConditionCheckBox();local second=a:CreateConditionCheckBox();second:SetFullWidth(true);reused:AddChildren(first,second);reused:ResumeLayout();assert(second.frame:GetWidth()==217);a:ReleaseConditionWidget(reused)
end)
test('unsupported named layouts reject before changing an existing native table',function()
    local _,a=fixture();local root=group(a,{columns={{weight=1}}},{{}});root:ResumeLayout();local height=root.frame:GetHeight()
    assert(not pcall(root.SetLayout,root,'ReviewedExternal'));assert(root.layout=='Table' and root.frame:GetHeight()==height);a:ReleaseConditionWidget(root)
end)
test('pathological native spans fail promptly even with hidden trailing children',function()
    local _,a=fixture();local root=group(a,{columns={{weight=1}}},{{cell={rowspan=1000000000}},{},{hidden=true}})

    local instructions=0;debug.sethook(function() instructions=instructions+1000;if instructions>100000 then error('unbounded table traversal') end end,'',1000)
    local ok,why=pcall(root.ResumeLayout,root);debug.sethook()
    assert(not ok and tostring(why):find('condition-table-work-limit',1,true),why)
    assert(not root.layingOut and not root.paused)
    root.children[1]:SetUserData('cell',nil);root:DoLayout();assert(root.frame:GetHeight()==48)
end)
test('native advanced widths reflow actual nested label groups and propagate new height',function()
    local _,a=fixture();local outer=a:CreateConditionGroup()
    local root=a:CreateConditionGroup();root:PauseLayout();root:SetWidth(720);root:SetLayout('Table');root:SetUserData('table',{columns={{width=80},{weight=1}},spaceH=8})
    local first=a:CreateConditionCheckBox();root:AddChild(first)
    local nested=a:CreateConditionGroup();nested:SetFullWidth(true)
    local label=a:CreateConditionLabel();label:SetFullWidth(true);label:SetText(string.rep('Wrapped information ',10));nested:AddChild(label);root:AddChild(nested)
    outer:AddChild(root);root:ResumeLayout()
    local wide=root.frame:GetHeight();assert(nested.frame:GetWidth()==632 and outer.frame:GetHeight()==wide)
    root:SetWidth(320);local narrow=root.frame:GetHeight()
    assert(nested.frame:GetWidth()==232 and narrow>wide and outer.frame:GetHeight()==narrow,'nested wrapped height did not propagate')
    root:SetWidth(720);assert(root.frame:GetHeight()==wide and label.frame:GetHeight()==wide)
end)
test('malformed populated Table descriptors reject before touching owned geometry and recover',function()
    for _,settings in ipairs({{columns={}},{columns={1,[3]=1}},{columns={{width=0/0}}},{columns={{weight=-1}}}}) do
        local _,a=fixture();local root=a:CreateConditionGroup();local child=a:CreateConditionCheckBox();root:AddChild(child)
        local point=child.frame.point;local width=child.frame:GetWidth();root:PauseLayout();root:SetLayout('Table');root:SetUserData('table',settings)
        assert(not pcall(root.ResumeLayout,root));assert(child.frame.point==point and child.frame:GetWidth()==width and child.parent==root and not root.layingOut and not root.paused)
        root:SetUserData('table',{columns={1}});root:DoLayout();assert(root.frame:GetHeight()==24);root:Release()
    end
end)
finish()
