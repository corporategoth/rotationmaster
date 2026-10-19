local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();if not f.addon.CreateConditionLabel then f.load('UI/condition_display.lua') end;local create=f.env.CreateFrame
    f.env.CreateFrame=function(...)
        local frame=create(...);local font=frame.CreateFontString
        function frame:CreateFontString(...)
            local label=font(self,...);local height=label.GetStringHeight
            function label:SetFont(path,size,flags) self.font={path,size,flags};return true end
            function label:SetFontObject(value) self.fontObject=value;self.font=nil end
            function label:SetJustifyH(value) self.justifyH=value end
            function label:GetStringHeight() return height(self)*(self.font and self.font[2]/12 or 1) end
            return label
        end
        return frame
    end
    return f,f.addon
end
local function quantizedFixture(offset)
    local f,a=fixture()
    local create=f.env.CreateFrame;f.env.CreateFrame=function(...)
        local frame=create(...);local width,height=frame:GetWidth(),frame:GetHeight();local requestedHeight=height
        -- Engine dimensions and fractional backing quantization are independent
        -- of requested Lua geometry values.
        function frame:GetWidth() return width end
        function frame:GetHeight() return height end
        function frame:SetSize(nextWidth,nextHeight)
            requestedHeight=nextHeight
            local actualHeight=nextHeight+(offset or 0);local changed=width~=nextWidth or height~=actualHeight
            width,height=nextWidth,actualHeight
            if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,width,height) end
        end
        function frame:SetWidth(value) self:SetSize(value,requestedHeight) end
        function frame:SetHeight(value) self:SetSize(width,value) end
        return frame
    end
    return f,a
end
local function native(a) assert(a.CreateConditionLabel and a.CreateConditionButton,'native display factories missing') end
test('ordinary Help primitives allocate and release native controls without Ace calls',function()
    local f,a=fixture();native(a);assert(f.libraries['AceGUI-3.0']==nil)
    local helpers=a.help_funcs
    for _,widget in ipairs({helpers.CreateText('Words'),helpers.CreatePictureText('Texture',32,24,'Picture'),helpers.CreateButtonText('Save','Save words'),helpers.Indent(40,helpers.CreateText('Indented')),helpers.Gap()}) do
        assert(widget.rmWidget and widget.rmActive);assert(a:ReleaseConditionWidget(widget))
    end
end)
test('native text preserves wording color reset explicit fonts and font objects',function()
    local f,a=fixture();native(a);local helpers=a.help_funcs
    local group=helpers.CreateText('Literal words','Custom.ttf',20);local label=group.children[1]
    assert(group.type=='RM-ConditionGroup' and label.type=='RM-ConditionLabel' and label.text=='Literal words'..f.env.color.RESET)
    assert(label.label:GetText()==label.text and label.label.font[1]=='Custom.ttf' and label.label.font[2]==20)
    local object={font='Object'};local second=helpers.CreateText('Object text',object);assert(second.children[1].label.fontObject==object)
    a:ReleaseConditionWidget(group);a:ReleaseConditionWidget(second)
end)
test('label width and font changes reflow nested native Help heights',function()
    local _,a=fixture();native(a);local group=a.help_funcs.CreateText(string.rep('word ',70));group:SetWidth(400);local wide=group.frame:GetHeight()
    group:SetWidth(120);local narrow=group.frame:GetHeight();assert(narrow>wide,'wrapped label did not grow with narrow width')
    local label=group.children[1];label:SetFont('Custom.ttf',24);assert(group.frame:GetHeight()>narrow,'font height did not reach the parent')
    local large=group.frame:GetHeight();label:SetText('short');assert(group.frame:GetHeight()<large,'text change retained stale height')
    a:ReleaseConditionWidget(group)
end)
test('picture rows preserve texture coordinates dimensions and fixed text columns',function()
    local _,a=fixture();native(a);local group=a.help_funcs.CreatePictureText('Texture',32,24,'Picture words',nil,nil,.1,.9,.2,.8);group:SetWidth(300)
    local icon,text=group.children[1],group.children[2]
    assert(icon.type=='RM-ConditionIcon' and icon.image:GetTexture()=='Texture' and icon.image:GetWidth()==32 and icon.image:GetHeight()==24)
    assert(icon.frame:GetHeight()==29 and icon.image.texCoord[1]==.1 and icon.image.texCoord[4]==.8)
    assert(icon.frame:GetWidth()==32 and text.frame:GetWidth()==264,'fixed picture column or native table gap changed')
    a:ReleaseConditionWidget(group)
end)
test('button rows indentation and gaps retain their existing Help content contracts',function()
    local _,a=fixture();native(a);local helpers=a.help_funcs;local row=helpers.CreateButtonText('Save','Save words');row:SetWidth(320)
    assert(row.children[1].type=='RM-ConditionButton' and row.children[1].text=='Save' and row.children[1].frame:GetWidth()==125)
    assert(F.text(row):find('Save words',1,true));local indent=helpers.Indent(40,helpers.CreateText('Indented'));indent:SetWidth(320)
    assert(indent.children[1].type=='RM-ConditionLabel' and indent.children[2].frame:GetWidth()==276 and F.text(indent):find('Indented',1,true))
    local gap=helpers.Gap();assert(gap.type=='RM-ConditionLabel' and gap.text==' ' and gap.frame:GetHeight()>0)
    a:ReleaseConditionWidget(row);a:ReleaseConditionWidget(indent);a:ReleaseConditionWidget(gap)
end)
test('button leases suppress retained click callbacks during ancestor release and after reuse',function()
    local _,a=fixture();native(a);local root=a:CreateConditionGroup();local button=a:CreateConditionButton();root:AddChild(button);local old,new=0,0
    button:SetCallback('OnClick',function() old=old+1 end);local stale=button.frame:GetScript('OnClick');local staleEvent=button.events.OnClick
    root:SetCallback('OnRelease',function() stale(button.frame,'LeftButton') end);a:ReleaseConditionWidget(root);assert(old==0,'release clicked a descendant')
    local reused=a:CreateConditionButton();assert(reused==button);reused:SetCallback('OnClick',function() new=new+1 end)
    stale(button.frame,'LeftButton');staleEvent(button,'OnClick','LeftButton');assert(old==0 and new==0,'old lease dispatched a click')
    reused.frame:Click();assert(new==1);reused:SetDisabled(true);reused.frame:Click();assert(new==1)
    a:ReleaseConditionWidget(reused)
end)
test('native parents recycle display leases without stale events or accumulating widgets',function()
    local _,a=fixture();native(a)
    local labels,buttons={},{};local clicks=0
    for _=1,50 do
        local parent=a:CreateConditionGroup();local label=a:CreateConditionLabel();local button=a:CreateConditionButton();labels[label]=true;buttons[button]=true
        label:SetFullWidth(true);label:SetText('Mixed Help words');button:SetText('Mixed button');button:SetCallback('OnClick',function() clicks=clicks+1 end)
        local stale=button.frame:GetScript('OnClick');parent:AddChild(label);parent:AddChild(button);a:ReleaseConditionWidget(parent)
        stale(button.frame,'LeftButton');assert(not label.rmActive and not button.rmActive,'native parent left a native display active')
    end
    local labelCount,buttonCount=0,0;for _ in pairs(labels) do labelCount=labelCount+1 end;for _ in pairs(buttons) do buttonCount=buttonCount+1 end
    assert(labelCount==1 and buttonCount==1 and clicks==0,'native ownership stranded display widgets or fired a stale callback')
end)
test('fractional backing heights stay bounded under a native parent while content grows and shrinks',function()
    local _,a=quantizedFixture(.00001);native(a);local parent=a:CreateConditionGroup();local passes=0;local layout=parent.DoLayout
    parent.DoLayout=function(self,...)
        passes=passes+1;assert(passes<=100,'fractional native height caused repeated native layout')
        return layout(self,...)
    end
    local label=a:CreateConditionLabel();label:SetFullWidth(true);label:SetText('short');parent:AddChild(label)
    assert(passes<10,'initial label did not settle under native layout');local short=parent.frame:GetHeight()
    label:SetText(string.rep('word ',90));assert(parent.frame:GetHeight()>short,'native parent lost content growth')
    local tall=parent.frame:GetHeight();label:SetText('short');assert(parent.frame:GetHeight()<tall,'native parent lost content shrink')
    assert(passes<20,'native label updates repeated sublayouts');a:ReleaseConditionWidget(parent)
end)
test('pooled displays reset fonts text colors alignment disabled state and callback data',function()
    local _,a=fixture();native(a);local label=a:CreateConditionLabel();label:SetText('Old');label:SetFont('Custom.ttf',30);label:SetColor(.2,.3,.4);label:SetJustifyH('RIGHT');label:SetUserData('old',true)
    label:Release();local reused=a:CreateConditionLabel();assert(reused==label and reused.text=='' and reused.label.font==nil and reused:GetUserData('old')==nil)
    assert(reused.label.textColor[1]==1 and reused.label.justifyH=='LEFT' and reused.label.justifyV=='TOP');local button=a:CreateConditionButton();button:SetText('Old');button:SetDisabled(true);button:SetAutoWidth(true);button:Release()
    local nextButton=a:CreateConditionButton();assert(nextButton==button and nextButton.text=='' and not nextButton.disabled and not nextButton.autoWidth and nextButton.frame:GetWidth()==200)
    a:ReleaseConditionWidget(reused);a:ReleaseConditionWidget(nextButton)
end)
finish()
