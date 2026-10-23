local addon_name,addon=...
-- Native controls with the compact flat-button conventions used by modern
-- addon workbenches. No dependency on another installed addon's frames.
---@class RMWorkbenchButton: Button
---@field art Texture
---@field SetSelected fun(self: RMWorkbenchButton, value: boolean)
---@return RMWorkbenchButton
-- The client resolves a region's rect on its next layout pass: right after
-- SetWidth/SetSize, or for a frame sized by its anchors, GetWidth/GetHeight
-- still return the previous size, and OnSizeChanged arrives a frame later.
-- Layout code reads sizes it has just assigned, so RM frames answer with the
-- size RM last assigned (or the client last reported) instead of the stale
-- rect. A size the client reports (window sizing, anchors) is noted before
-- the frame's own OnSizeChanged handler runs, so that handler reads it too.
function addon:TrackWorkbenchSize(frame)
    if not frame or frame.rmTracksSize then return frame end
    frame.rmTracksSize=true
    local setWidth,setHeight,setSize,getWidth,getHeight=frame.SetWidth,frame.SetHeight,frame.SetSize,frame.GetWidth,frame.GetHeight
    function frame:SetWidth(value,...) if type(value)=='number' then self.rmWidth=value end;return setWidth(self,value,...) end
    function frame:SetHeight(value,...) if type(value)=='number' then self.rmHeight=value end;return setHeight(self,value,...) end
    if setSize then function frame:SetSize(width,height,...) if type(width)=='number' then self.rmWidth=width end;if type(height)=='number' then self.rmHeight=height end;return setSize(self,width,height,...) end end
    function frame:GetWidth(...) local value=self.rmWidth;if value then return value end;return getWidth(self,...) end
    function frame:GetHeight(...) local value=self.rmHeight;if value then return value end;return getHeight(self,...) end
    if frame.SetScript and frame.HookScript and frame.HasScript and frame:HasScript('OnSizeChanged') then
        local setScript=frame.SetScript
        function frame:SetScript(event,handler,...)
            if event=='OnSizeChanged' and handler then
                local inner=handler
                handler=function(region,width,height,...) addon:NoteWorkbenchSize(region,width,height);return inner(region,width,height,...) end
            end
            return setScript(self,event,handler,...)
        end
        local current=frame:GetScript('OnSizeChanged');if current then frame:SetScript('OnSizeChanged',current) end
        frame:HookScript('OnSizeChanged',function(region,width,height) addon:NoteWorkbenchSize(region,width,height) end)
    end
    return frame
end
-- Pooled builders may return any region or a plain table; only regions
-- with their own geometry are tracked.
function addon:TrackWorkbenchRegion(value)
    if type(value)=='table' and type(value.SetWidth)=='function' and type(value.GetWidth)=='function' and type(value.SetPoint)=='function' then return self:TrackWorkbenchSize(value) end
    return value
end
function addon:NoteWorkbenchSize(frame,width,height)
    if not frame.rmTracksSize then return end
    if type(width)=='number' and width>0 then frame.rmWidth=width end
    if type(height)=='number' and height>0 then frame.rmHeight=height end
end
function addon:CreateWorkbenchButton(parent,label,width)
    local button=CreateFrame("Button",nil,parent);self:TrackWorkbenchSize(button);button:SetSize(width or 28,20);button:EnableMouse(true)
    local caption=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");caption:SetPoint("CENTER")
    button:SetFontString(caption);button:SetText(label or "")
    local background=button:CreateTexture(nil,"BACKGROUND");background:SetAllPoints(button);button.art=background
    local function rest()
        if button.selected then background:SetColorTexture(.24,.24,.24,.8) else background:SetColorTexture(.16,.16,.16,.5) end
    end
    function button:SetSelected(value) self.selected=value==true;rest() end
    addon:SetUIScript(button,"OnEnter",function()
        background:SetColorTexture(.27,.27,.27,.8)
        if button.tooltip and GameTooltip then GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText(button.tooltip,1,1,1,1,true) end
    end)
    addon:SetUIScript(button,"OnLeave",function() rest();if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end end)
    addon:SetUIScript(button,"OnEnable",function() button:SetAlpha(1) end)
    addon:SetUIScript(button,"OnDisable",function() button:SetAlpha(.35) end)
    rest();
    ---@cast button RMWorkbenchButton
    return button
end
function addon:ControlTexture(name)
    return "Interface\\AddOns\\"..addon_name.."\\Assets\\Controls\\"..name..".tga"
end
---@class RMIconButton: RMWorkbenchButton
---@field icon Texture
---@return RMIconButton
function addon:CreateWorkbenchIconButton(parent,name,tooltip)
    local button=self:CreateWorkbenchButton(parent,"",20);button:SetSize(20,20);button.tooltip=tooltip
    button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("CENTER");button.icon:SetSize(16,16)
    button.icon:SetTexture(self:ControlTexture(name));if name=='trash' then button.icon:SetVertexColor(1,.25,.25,1) end;button.art:Hide()
    ---@cast button RMIconButton
    return button
end
---@return RMIconButton
function addon:CreateWorkbenchHelpButton(parent,tooltip)
    local button=self:CreateWorkbenchIconButton(parent,'help',tooltip);button:SetSize(20,20);button.icon:SetSize(18,18);button.icon:SetVertexColor(1,.82,.25,1);return button
end
function addon:CreateWorkbenchHistoryButton(parent,direction,label)
    local button=self:CreateWorkbenchIconButton(parent,direction,label);button:SetSize(68,20);button:SetText(label);button.art:Show()
    button.icon:ClearAllPoints();button.icon:SetPoint('LEFT',3,0)
    -- The caption is bounded by the button so a long label cannot spill out.
    local caption=button:GetFontString();caption:ClearAllPoints();caption:SetPoint('LEFT',24,0);caption:SetPoint('RIGHT',-4,0);caption:SetJustifyH('LEFT');caption:SetWordWrap(false);return button
end
function addon:CreateWorkbenchLabeledIconButton(parent,icon,label,width)
    local button=self:CreateWorkbenchHistoryButton(parent,icon,label);button:SetWidth(width or 100);return button
end
function addon:PaintSelectorSelection(button,entry,caption)
    button:SetText(caption or entry and entry.text or '')
    if entry and entry.icon then
        button.valueIcon=button.valueIcon or button:CreateTexture(nil,'ARTWORK');button.valueIcon:ClearAllPoints();button.valueIcon:SetPoint('LEFT',25,0);button.valueIcon:SetSize(18,18);button.valueIcon:SetTexture(entry.icon);button.valueIcon:Show();self:AlignWorkbenchTextLeft(button,48)
    else if button.valueIcon then button.valueIcon:Hide() end;self:AlignWorkbenchTextLeft(button,26) end
end
-- An aligned caption keeps following its button when the button is resized
-- later, rather than keeping the width it had when aligned. A caller that
-- narrows the caption itself afterwards keeps that width until realigned.
local function refitAlignedText(button)
    local label=button:GetFontString();local inset=button.rmAlignInset
    if not label or not inset then return end
    addon:TrackWorkbenchSize(label)
    if math.abs((label:GetWidth() or 0)-(button.rmAlignWidth or -1))>.5 then button.rmAlignInset=nil;return end
    local width=math.max(1,button:GetWidth()-inset-4);label:SetWidth(width);button.rmAlignWidth=width
end
function addon:AlignWorkbenchTextLeft(button,inset)
    local label=button:GetFontString();self:TrackWorkbenchSize(label);label:ClearAllPoints();label:SetPoint('LEFT',inset or 4,0);label:SetJustifyH('LEFT')
    local width=math.max(1,button:GetWidth()-(inset or 4)-4);label:SetWidth(width);button.rmAlignInset=inset or 4;button.rmAlignWidth=width
    if not button.rmAlignFollows then
        button.rmAlignFollows=true;local setWidth,setSize=button.SetWidth,button.SetSize
        function button:SetWidth(...) setWidth(self,...);refitAlignedText(self) end
        function button:SetSize(...) setSize(self,...);refitAlignedText(self) end
    end
end
---@class RMWorkbenchPill: RMWorkbenchButton
---@field SetAccent fun(self: RMWorkbenchPill, r: number, g: number, b: number, alpha?: number)
---@return RMWorkbenchPill
function addon:CreateWorkbenchPill(parent,label,width)
    local button=self:CreateWorkbenchButton(parent,label,width);button:SetSize(width or 56,18);button.art:Hide()
    button.pillDecoration=self:CreateRoundedCardDecoration(button)
    local accent={.35,.65,.4};local accentAlpha=.7
    local function paint(hover)
        local color=button.selected and accent or {.48,.48,.48}
        button.pillDecoration:SetColors(color[1],color[2],color[3],hover and 1 or button.selected and accentAlpha or .7,button.selected and .6 or .25)
    end
    function button:SetSelected(value) self.selected=value==true;paint(false) end
    function button:SetAccent(r,g,b,a) accent={r,g,b};accentAlpha=a or .7;paint(false) end
    addon:SetUIScript(button,'OnEnter',function() paint(true);if button.tooltip and GameTooltip then GameTooltip:SetOwner(button,'ANCHOR_RIGHT');GameTooltip:SetText(button.tooltip,1,1,1,1,true) end end)
    addon:SetUIScript(button,'OnLeave',function() paint(false);if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end end)
    paint(false);
    ---@cast button RMWorkbenchPill
    return button
end
---@class RMWorkbenchCheckBox: RMWorkbenchButton
---@field SetChecked fun(self: RMWorkbenchCheckBox, value: boolean)
---@field GetChecked fun(self: RMWorkbenchCheckBox): boolean
---@return RMWorkbenchCheckBox
function addon:CreateWorkbenchCheckBox(parent,label,width)
    local button=self:CreateWorkbenchButton(parent,label,width);button.art:Hide()
    local box=button:CreateTexture(nil,'BACKGROUND');box:SetPoint('LEFT',0,0);box:SetSize(16,16);box:SetColorTexture(.1,.1,.1,1)
    local check=button:CreateTexture(nil,'ARTWORK');check:SetPoint('LEFT',0,0);check:SetSize(16,16);check:SetTexture(self:ControlTexture('check'));check:SetVertexColor(1,.82,.2,1);button.check=check
    local text=button:GetFontString();text:ClearAllPoints();text:SetPoint('LEFT',22,0);text:SetWidth(math.max(1,(width or 150)-22));text:SetJustifyH('LEFT')
    function button:SetChecked(value) self.checked=value==true;if self.checked then check:Show() else check:Hide() end end
    function button:GetChecked() return self.checked end
    button:SetChecked(false)
    ---@cast button RMWorkbenchCheckBox
    return button
end
function addon:GetConditionIcon(tag)
    local replacement=self.conditionIcons and self.conditionIcons[tag]
    local definition=(self.conditionDefinitions or {})[tag] or (self.conditionSpecials or {})[tag]
    local icon=replacement or definition and definition.icon
    return (type(icon)=="string" or type(icon)=="number") and icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
function addon:CreateRoundedCardDecoration(frame)
    local decoration={fill={},border={}}
    for _,layer in ipairs({{key="fill",texture="card-fill",draw="BACKGROUND"},{key="border",texture="card-border",draw="BORDER"}}) do
        for row=1,3 do for column=1,3 do
            local texture=frame:CreateTexture(nil,layer.draw);texture:SetTexture(self:ControlTexture(layer.texture))
            local coords={0,.125,.875,1};texture:SetTexCoord(coords[column],coords[column+1],coords[row],coords[row+1])
            local top=row==1 and "TOP" or row==3 and "BOTTOM" or ""
            local side=column==1 and "LEFT" or column==3 and "RIGHT" or ""
            if row==2 and column==2 then
                texture:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-8);texture:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-8,8)
            elseif row==2 then
                texture:SetPoint("TOP"..side,frame,"TOP"..side,0,-8);texture:SetPoint("BOTTOM"..side,frame,"BOTTOM"..side,0,8);texture:SetWidth(8)
            elseif column==2 then
                texture:SetPoint(top.."LEFT",frame,top.."LEFT",8,0);texture:SetPoint(top.."RIGHT",frame,top.."RIGHT",-8,0);texture:SetHeight(8)
            else texture:SetPoint(top..side,frame,top..side,0,0);texture:SetSize(8,8) end
            decoration[layer.key][#decoration[layer.key]+1]=texture
        end end
    end
    function decoration:SetColors(r,g,b,alpha,fillAlpha)
        for _,part in ipairs(self.border) do part:SetVertexColor(r,g,b,alpha) end
        for _,part in ipairs(self.fill) do part:SetVertexColor(.15,.15,.15,fillAlpha) end
    end
    return decoration
end
---@class RMConditionChevron: RMIconButton
---@field PointDown fun(self: RMConditionChevron, down: boolean)
---@field PointState fun(self: RMConditionChevron, state: string)
---@return RMConditionChevron
function addon:CreateConditionChevron(parent)
    local button=self:CreateWorkbenchIconButton(parent,"chevron-right");button:SetSize(18,18)
    function button:PointDown(down) self.icon:SetTexture(addon:ControlTexture(down and "chevron-down" or "chevron-right")) end
    function button:PointState(state)
        self.icon:SetRotation(state=='compact' and math.pi or 0)
        self.icon:SetTexture(addon:ControlTexture(state=='compact' and 'chevron-down' or state=='expanded' and 'chevron-double-down' or 'chevron-down'))
    end
    button:PointDown(false)
    ---@cast button RMConditionChevron
    return button
end

-- Names are editable labels; spell hyperlinks belong in action summaries.
function addon:PlainWorkbenchName(value)
    if type(value)~='string' then return '' end
    return (value:gsub('|H.-|h%[(.-)%]|h','%1'):gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''))
end
function addon:BindWorkbenchInlineName(input,finish)
    local function down() return IsMouseButtonDown and (IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton')) or false end
    input.rmNameMouseDown=down()
    addon:SetUIScript(input,'OnEditFocusGained',function() input.rmNameMouseDown=down() end)
    addon:SetUIScript(input,'OnEditFocusLost',finish)
    addon:SetUIScript(input,'OnUpdate',function()
        local pressed=down()
        if pressed and not input.rmNameMouseDown and not addon:IsWorkbenchDropZoneUnderPointer(input,input) then input:ClearFocus();finish() end
        input.rmNameMouseDown=pressed
    end)
end
function addon:CreateWorkbenchListRow(parent,width,height)
    local row=self:CreateWorkbenchButton(parent,'',width)
    row:SetHeight(height or 32)
    return row
end
function addon:SetWorkbenchListSelection(control,selected)
    if control.SetSelected then control:SetSelected(selected) end
    if not control.selection then control.selection=control:CreateTexture(nil,'BACKGROUND');control.selection:SetAllPoints(control) end
    control.selection:SetColorTexture(.1,.25,.3,.8)
    if selected then control.selection:Show() else control.selection:Hide() end
end
function addon:CreateWorkbenchEditBox(parent)
    local input=CreateFrame("EditBox",nil,parent);self:TrackWorkbenchSize(input);input:SetFontObject("GameFontHighlightSmall");input:SetAutoFocus(false)
    input:SetTextInsets(6,6,0,0);input:SetHeight(24)
    local background=input:CreateTexture(nil,"BACKGROUND");background:SetAllPoints(input);background:SetColorTexture(.08,.09,.10,.95)
    local line=input:CreateTexture(nil,"BORDER");line:SetPoint("BOTTOMLEFT");line:SetPoint("BOTTOMRIGHT");line:SetHeight(1);line:SetColorTexture(.38,.43,.48,.8)
    input.art=background;return input
end
function addon:AttachWorkbenchSearchHint(input,text)
    if input.searchHint then return input.searchHint end
    local hint=input:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');input.searchHint=hint
    hint:SetPoint('LEFT',6,0);hint:SetJustifyH('LEFT');hint:SetText(text or LibStub('AceLocale-3.0'):GetLocale(addon_name)['Search...'])
    local focused=false
    local function refresh()
        hint:SetWidth(math.max(1,input:GetWidth()-12))
        if not focused and (input:GetText() or '')=='' then hint:Show() else hint:Hide() end
    end
    input:HookScript('OnEditFocusGained',function() focused=true;refresh() end)
    input:HookScript('OnEditFocusLost',function() focused=false;refresh() end)
    input:HookScript('OnTextChanged',refresh);input:HookScript('OnSizeChanged',refresh)
    input:HookScript('OnHide',function() focused=false;refresh() end);input.RefreshWorkbenchSearchHint=refresh;refresh();return hint
end
function addon:CreateWorkbenchSlider(parent,minimum,maximum,step,width)
    local slider=CreateFrame("Slider",nil,parent);self:TrackWorkbenchSize(slider);slider:SetOrientation("HORIZONTAL");slider:SetSize(width or 112,12)
    slider:SetMinMaxValues(minimum,maximum);slider:SetValueStep(step);if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track=slider:CreateTexture(nil,"BACKGROUND");track:SetPoint("LEFT",0,0);track:SetPoint("RIGHT",0,0);track:SetHeight(3);track:SetColorTexture(.3,.32,.34,1)
    local thumb=slider:CreateTexture(nil,"ARTWORK");thumb:SetSize(7,12);thumb:SetColorTexture(.78,.8,.82,1);slider:SetThumbTexture(thumb)
    return slider
end

-- Flat, narrow tracks and proportional rectangular thumbs follow the modern
-- Details/Plater convention. These frames belong to RM, without a provider.
function addon:CreateWorkbenchScrollBar(parent,orientation)
    local horizontal=orientation=='HORIZONTAL'
    local bar=CreateFrame('Slider',nil,parent);bar:SetOrientation(orientation or 'VERTICAL');bar:SetSize(horizontal and 160 or 10,horizontal and 10 or 160)
    bar:SetMinMaxValues(0,0);bar:SetValueStep(1);bar:EnableMouseWheel(true)
    local track=bar:CreateTexture(nil,'BACKGROUND');track:SetAllPoints(bar);track:SetColorTexture(.08,.08,.08,.85)
    local thumb=bar:CreateTexture(nil,'ARTWORK');thumb:SetSize(horizontal and 30 or 8,horizontal and 8 or 30);thumb:SetColorTexture(.48,.48,.48,.9);bar.thumbTexture=thumb
    for _,entry in ipairs({{'back','up',-1},{'forward','down',1}}) do
        local direction=entry[3];local control=self:CreateWorkbenchIconButton(bar,entry[2]);control:SetSize(10,10);control.icon:SetSize(9,9);bar[entry[1]]=control;if horizontal then control.icon:SetRotation(math.pi/2) end
        control:SetPoint(horizontal and (direction<0 and 'RIGHT' or 'LEFT') or (direction<0 and 'BOTTOM' or 'TOP'),bar,
            horizontal and (direction<0 and 'LEFT' or 'RIGHT') or (direction<0 and 'TOP' or 'BOTTOM'),0,0)
        addon:SetUIScript(control,'OnClick',function() bar:SetValue((bar:GetValue() or 0)+direction*40) end)
    end
    local function placeThumb()
        local length=horizontal and bar:GetWidth() or bar:GetHeight()
        local travel=math.max(0,length-(bar.thumbLength or 18))
        local fraction=(bar.scrollRange or 0)>0 and bar:GetValue()/bar.scrollRange or 0
        thumb:ClearAllPoints();thumb:SetPoint(horizontal and 'LEFT' or 'TOP',horizontal and travel*fraction or 0,horizontal and 0 or -travel*fraction)
    end
    -- Keep repaint owned by this control, independently of consumer callbacks.
    -- Reflow can clamp the native value before its value-change hook runs.
    local nativeSetValue=bar.SetValue
    function bar:SetValue(value)
        nativeSetValue(self,value)
        placeThumb()
    end
    local drag=CreateFrame('Button',nil,bar);bar.thumbButton=drag;drag:SetAllPoints(thumb)
    addon:SetUIScript(drag,'OnMouseDown',function(_,button)
        if button~='LeftButton' or not GetCursorPosition then return end
        local x,y=GetCursorPosition();bar.dragStart={position=horizontal and x or y,value=bar:GetValue()}
    end)
    local function stop() bar.dragStart=nil end
    addon:SetUIScript(drag,'OnMouseUp',stop);addon:SetUIScript(drag,'OnHide',stop)
    addon:SetUIScript(drag,'OnUpdate',function()
        local start=bar.dragStart;if not start then return end
        if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then stop();return end
        local x,y=GetCursorPosition();local delta=((horizontal and x or y)-start.position)/bar:GetEffectiveScale()
        local length=horizontal and bar:GetWidth() or bar:GetHeight();local travel=math.max(1,length-(bar.thumbLength or 18))
        bar:SetValue(start.value+(horizontal and delta or -delta)*(bar.scrollRange or 0)/travel)
    end)
    drag:EnableMouseWheel(true);addon:SetUIScript(drag,'OnMouseWheel',function(_,delta) bar:SetValue(bar:GetValue()-delta*40) end)
    -- These regions cover only the empty track around the owned thumb.

    for _,entry in ipairs({{'pageBack',-1},{'pageForward',1}}) do
        local control=CreateFrame('Button',nil,bar);bar[entry[1]]=control
        if horizontal then
            control:SetPoint('TOP',bar,'TOP');control:SetPoint('BOTTOM',bar,'BOTTOM')
            control:SetPoint('LEFT',entry[2]<0 and bar or thumb,entry[2]<0 and 'LEFT' or 'RIGHT')
            control:SetPoint('RIGHT',entry[2]<0 and thumb or bar,entry[2]<0 and 'LEFT' or 'RIGHT')
        else
            control:SetPoint('LEFT',bar,'LEFT');control:SetPoint('RIGHT',bar,'RIGHT')
            control:SetPoint('TOP',entry[2]<0 and bar or thumb,entry[2]<0 and 'TOP' or 'BOTTOM')
            control:SetPoint('BOTTOM',entry[2]<0 and thumb or bar,entry[2]<0 and 'TOP' or 'BOTTOM')
        end
        local direction=entry[2]
        addon:SetUIScript(control,'OnMouseDown',function(_,button)
            if button=='LeftButton' then bar:SetValue((bar:GetValue() or 0)+direction*(bar.pageSize or 1)) end
        end)
        control:EnableMouseWheel(true);addon:SetUIScript(control,'OnMouseWheel',function(_,delta) bar:SetValue((bar:GetValue() or 0)-delta*40) end)
    end
    addon:SetUIScript(bar,'OnMouseWheel',function(_,delta) bar:SetValue((bar:GetValue() or 0)-delta*40) end)
    addon:SetUIScript(bar,'OnEnter',function() thumb:SetColorTexture(.7,.7,.7,1) end)
    addon:SetUIScript(bar,'OnLeave',function() thumb:SetColorTexture(.48,.48,.48,.9) end)
    function bar:UpdateExtent(content,visible)
        self.extentRevision=(self.extentRevision or 0)+1;local revision=self.extentRevision
        self.pageSize=math.max(1,visible)
        local range=math.max(0,content-visible);self.scrollRange=range;self:SetMinMaxValues(0,range)
        if self.extentRevision~=revision then return end
        self:SetValue(math.min(self:GetValue() or 0,range))
        if self.extentRevision~=revision then return end
        local length=horizontal and self:GetWidth() or self:GetHeight()
        local size=math.min(length,math.max(18,length*math.min(1,visible/math.max(1,content))))
        if size~=self.thumbLength then
            self.thumbLength=size;if horizontal then thumb:SetWidth(size) else thumb:SetHeight(size) end
        end
        placeThumb();if range>0 then self:Show() else self.dragStart=nil;self:Hide() end
    end
    return bar
end
function addon:CreateWorkbenchScrollFrame(parent)
    local scroll=CreateFrame('ScrollFrame',nil,parent);self:TrackWorkbenchSize(scroll)
    local bar=self:CreateWorkbenchScrollBar(scroll,'VERTICAL');self:TrackWorkbenchSize(bar);scroll.workbenchBar=bar
    local setScrollChild=scroll.SetScrollChild
    function scroll:SetScrollChild(child,...) addon:TrackWorkbenchSize(child);return setScrollChild(self,child,...) end
    bar:SetPoint('TOPLEFT',scroll,'TOPRIGHT',4,-10);bar:SetPoint('BOTTOMLEFT',scroll,'BOTTOMRIGHT',4,10)
    addon:SetUIScript(bar,'OnValueChanged',function(_,value)
        local current=scroll.GetVerticalScroll and scroll:GetVerticalScroll() or scroll.lastAppliedOffset
        if current==nil or math.abs(current-value)>.001 then scroll.lastAppliedOffset=value;scroll:SetVerticalScroll(value) end
    end)
    function scroll:UpdateWorkbenchScroll()
        local child=self:GetScrollChild();if not child then return end
        bar:UpdateExtent(child:GetHeight(),self:GetHeight())
        self:FitWorkbenchColumn()
    end
    -- A list column keeps its rows flush with the column's right edge: the
    -- bar takes its reserve only while the list actually scrolls. The owner's
    -- OnWorkbenchColumnResized refreshes row widths after a change.
    function scroll:SetWorkbenchColumnWidth(width)
        self.workbenchColumnWidth=math.max(1,width);self:FitWorkbenchColumn()
    end
    function scroll:FitWorkbenchColumn()
        local column=self.workbenchColumnWidth;if not column or self.fittingColumn then return end
        local wanted=math.max(1,column-(bar:IsShown() and addon.WorkbenchLayout.scrollReserve or 0))
        local child=self:GetScrollChild()
        if math.abs(self:GetWidth()-wanted)<.01 and (not child or math.abs(child:GetWidth()-wanted)<.01) then return end
        self.fittingColumn=true;self:SetWidth(wanted);if child then child:SetWidth(wanted) end;self.fittingColumn=nil
        if self.OnWorkbenchColumnResized then self:OnWorkbenchColumnResized(wanted) end
    end
    addon:SetUIScript(scroll,'OnScrollRangeChanged',function() scroll:UpdateWorkbenchScroll() end)
    addon:SetUIScript(scroll,'OnSizeChanged',function() scroll:UpdateWorkbenchScroll() end)
    scroll:EnableMouseWheel(true);addon:SetUIScript(scroll,'OnMouseWheel',function(_,delta) bar:SetValue((bar:GetValue() or 0)-delta*40) end)
    return scroll
end

-- A single native scroll host for measured RM groups. Content ownership and
-- its callback lease are detached before recycling, so old windows cannot
-- resize a root that has already been borrowed by another editor.
function addon:CreateWorkbenchGroupViewport(parent)
    local scroll=self:CreateWorkbenchScrollFrame(parent)
    local empty=CreateFrame('Frame',nil,scroll);empty:SetSize(1,1);scroll:SetScrollChild(empty)
    function scroll:ReleaseConditionContent()
        local root,lease,finish=self.contentWidget,self.contentLease,self.originalLayoutFinished
        self.contentWidget=nil;self.contentLease=nil;self.originalLayoutFinished=nil;self:SetScrollChild(empty)
        if root and root.rmLease==lease and root.rmActive then root.LayoutFinished=finish;addon:ReleaseConditionWidget(root) end
        self:UpdateWorkbenchScroll()
    end
    function scroll:SetConditionContent(root)
        if root then assert(root.rmWidget and root.rmActive and root.DoLayout,'native-condition-group-required') end
        if self.contentWidget==root and (not root or self.contentLease==root.rmLease) then if root then root:SetWidth(self:GetWidth()) end;return end
        self:ReleaseConditionContent();if not root then return end
        self.contentWidget=root;local lease=root.rmLease;self.contentLease=lease;local finish=root.LayoutFinished;self.originalLayoutFinished=finish
        root.LayoutFinished=function(widget,width,height)
            if scroll.contentWidget~=widget or widget.rmLease~=lease or not widget.rmActive then return end
            if finish then finish(widget,width,height) end;scroll:UpdateWorkbenchScroll()
        end
        root.frame:SetParent(self);root.frame:ClearAllPoints();root.frame:SetPoint('TOPLEFT',self,'TOPLEFT',0,0)
        self:SetScrollChild(root.frame);root:SetWidth(self:GetWidth());root.frame:Show();self:UpdateWorkbenchScroll()
    end
    local resized=scroll:GetScript('OnSizeChanged')
    addon:SetUIScript(scroll,'OnSizeChanged',function(frame,width,height)
        local root=frame.contentWidget
        if root then
            if root.rmActive and root.rmLease==frame.contentLease then root:SetWidth(width) else frame:ReleaseConditionContent() end
        end
        if resized then resized(frame,width,height) end
    end)
    return scroll
end

function addon:IsWorkbenchDropZoneUnderPointer(zone,viewport)
    if GetCursorPosition and zone.GetLeft and zone.GetRight and zone.GetTop and zone.GetBottom then
        local x,y=GetCursorPosition()
        local function inside(frame)
            local left,right,top,bottom=frame:GetLeft(),frame:GetRight(),frame:GetTop(),frame:GetBottom()
            if not left or not right or not top or not bottom then return false end
            local scale=frame:GetEffectiveScale();local cx,cy=x/scale,y/scale
            return cx>=left and cx<=right and cy>=bottom and cy<=top
        end
        return inside(viewport) and inside(zone)
    end
    local over=InputUtil and InputUtil.IsMouseOver or MouseIsOver
    return over and over(zone) and (not viewport or over(viewport)) or false
end
function addon:CreateWorkbenchDragCard()
    local frame=CreateFrame('Frame',nil,UIParent);frame:SetSize(340,76);frame:SetFrameStrata('TOOLTIP');frame:EnableMouse(false)
    local art=self:CreateRoundedCardDecoration(frame);art:SetColors(.7,.7,.7,1,.9)
    frame.label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');frame.label:SetPoint('TOPLEFT',10,-8);frame.label:SetWidth(320);frame.label:SetJustifyH('LEFT')
    frame.label:SetMaxLines(1)
    frame.count=frame:CreateFontString(nil,'OVERLAY','GameFontNormalSmall');frame.count:SetPoint('TOPRIGHT',-10,-8);frame.count:SetWidth(84);frame.count:SetJustifyH('RIGHT')
    frame.stack={}
    for i=1,2 do local layer=frame:CreateTexture(nil,'BACKGROUND',nil,-2);layer:SetTexture(addon:ControlTexture('card-border'));layer:SetPoint('TOPLEFT',frame,'TOPLEFT',i*4,-i*4);layer:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',i*4,-i*4);layer:SetVertexColor(.7,.7,.7,.8);layer:Hide();frame.stack[i]=layer end
    frame.summary=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');frame.summary:SetPoint('TOPLEFT',10,-28);frame.summary:SetWidth(320);frame.summary:SetWordWrap(true);frame.summary:SetJustifyH('LEFT');frame.summary:SetMaxLines(3)
    function frame:FollowPointer()
        if GetCursorPosition then local x,y=GetCursorPosition();local scale=self:GetEffectiveScale();self:ClearAllPoints();self:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',x/scale+16,y/scale-16) end
    end
    function frame:Present(title,summary,source,count)
        self:SetFrameStrata('TOOLTIP');self:SetFrameLevel((source and source:GetFrameLevel() or 0)+500);self:SetClampedToScreen(true);self:SetToplevel(true)
        count=type(count)=='number' and count or 1
        if count>1 then self.count:SetText(string.format(LibStub('AceLocale-3.0'):GetLocale(addon_name)['%d cards'],count));self.count:Show();self.label:SetWidth(230) else self.count:Hide();self.label:SetWidth(320) end
        for _,layer in ipairs(self.stack) do if count>1 then layer:Show() else layer:Hide() end end
        self.label:SetText(title);self.summary:SetText(summary)
        if source and UIParent.GetEffectiveScale then self:SetScale(source:GetEffectiveScale()/UIParent:GetEffectiveScale()) end
        self:SetAlpha(.9);self:FollowPointer();self:Show()
    end
    self:InstallDragPresentation(frame,art);frame:Hide();return frame
end

-- Gap indices refer to the original list. A suffix cannot be dropped into
-- itself; manual arrow controls always request a single entry.
function addon:CanReorderWorkbenchRange(items,from,gap,tail)
    return type(items)=='table' and type(from)=='number' and from%1==0 and from>=1 and from<=#items
        and type(gap)=='number' and gap%1==0 and gap>=1 and gap<=#items+1
        and (tail and gap<from or not tail and gap~=from and gap~=from+1)
end
function addon:ReorderWorkbenchRange(items,from,gap,tail)
    if not self:CanReorderWorkbenchRange(items,from,gap,tail) then return false end
    local count=tail and #items-from+1 or 1;local moved={}
    for _=1,count do moved[#moved+1]=table.remove(items,from) end
    local at=gap>from and gap-count or gap
    for i,value in ipairs(moved) do table.insert(items,at+i-1,value) end
    return true
end

-- Drag release may be followed by the source button's click callback. Keep
-- that release from also appending a card or opening the condition picker.
function addon:BindWorkbenchDragSource(control,start,stop)
    control:RegisterForDrag('LeftButton')
    local clickable=control:HasScript('OnClick')
    local click=clickable and control:GetScript('OnClick');local current=control:GetScript('OnMouseDown')
    if current~=control.rmDragDownWrapper then control.rmDragOriginalDown=current end
    local down=control.rmDragOriginalDown
    local wrapper=function(frame,button,...) frame.rmDragged=false;if down then down(frame,button,...) end end
    addon:SetUIScript(control,'OnMouseDown',wrapper);control.rmDragDownWrapper=control:GetScript('OnMouseDown')
    addon:SetUIScript(control,'OnDragStart',function(...) control.rmDragged=true;start(...) end)
    addon:SetUIScript(control,'OnDragStop',stop)
    if clickable then addon:SetUIScript(control,'OnClick',function(...)
        if control.rmDragged then control.rmDragged=false;return end
        if click then return click(...) end
    end) end
end

-- Explicit boundary for native RM scripts; no global handler or frame API is
-- replaced. Clear callbacks using the native API as usual.
function addon:SetUIScript(frame,event,callback)
    local handler=callback
    if handler and self.Diagnostics then handler=self.Diagnostics:Wrap({module='ui',operation=event},handler) end
    frame:SetScript(event,handler)
    return handler
end

-- One tightly packed position pad for profile and per-card highlight settings.
function addon:CreateWorkbenchPositionPad(parent)
    local pad=CreateFrame('Frame',nil,parent);pad:SetSize(48,48);pad.buttons={}
    for _,entry in ipairs({{'Up','up',1,0,0,1},{'Down','down',1,2,0,-1},{'Left','up',0,1,-1,0},{'Right','down',2,1,1,0},{'Center','center',1,1,0,0}}) do
        local button=self:CreateWorkbenchIconButton(pad,entry[2]);button:SetPoint('TOPLEFT',entry[3]*16,-entry[4]*16);button:SetSize(16,16);button.icon:SetSize(18,18);button.icon:SetTexCoord(.125,.875,.125,.875)
        button.icon:SetRotation((entry[1]=='Left' or entry[1]=='Right') and math.pi/2 or 0);pad.buttons[entry[1]]=button
        self:SetUIScript(button,'OnClick',function() if pad.valid and pad.valid() then pad.change(entry[5],entry[6],entry[1]=='Center',IsShiftKeyDown and IsShiftKeyDown() and 10 or 1) end end)
    end
    function pad:Bind(change,valid,readOnly)
        self.change=change;self.valid=valid
        for _,button in pairs(self.buttons) do if readOnly then button:Disable() else button:Enable() end end
    end
    return pad
end

-- Flat result lists retain complete data while leasing nearby native rows.
function addon:GetWorkbenchVisibleRowRange(count,pitch,offset,height,margin)
    return math.max(1,math.floor((offset-margin)/pitch)+1),math.min(count,math.floor((offset+height+margin)/pitch)+1)
end

-- Shared workbench sizing. The window minimum is the smallest width at which
-- every page keeps its controls inside the pane; list/detail pages share one
-- divider position, which each page clamps to its own width.
addon.WorkbenchLayout={windowMinWidth=800,windowMinHeight=500,sidebarMin=200,detailMin=440,splitGap=18,scrollReserve=14}
function addon:GetWorkbenchSidebarBounds(width)
    local layout=self.WorkbenchLayout
    local maximum=math.min(math.floor(width*.5),width-layout.splitGap-layout.detailMin)
    return layout.sidebarMin,math.max(layout.sidebarMin,maximum)
end
function addon:GetWorkbenchSidebarPreference()
    local global=self.db and self.db.global;local value=global and global.workbenchSidebarWidth
    if type(value)=='number' and value==value and value>0 and value<100000 then return value end
end
-- nil returns the divider to its automatic position.
function addon:SetWorkbenchSidebarPreference(value)
    local global=self.db and self.db.global;if not global then return end
    if value==nil then global.workbenchSidebarWidth=nil
    elseif type(value)=='number' and value==value and value>0 and value<100000 then global.workbenchSidebarWidth=math.floor(value+.5) end
end
function addon:GetWorkbenchSidebarWidth(width)
    local minimum,maximum=self:GetWorkbenchSidebarBounds(width)
    local value=self:GetWorkbenchSidebarPreference() or math.max(210,math.min(270,width*.26))
    return math.max(minimum,math.min(maximum,value))
end

function addon:GetWorkbenchSidebarHeight(height,top)
    return math.max(1,height-(top or 0))
end
function addon:GetWorkbenchRosterGeometry(width,height,top)
    local side=self:GetWorkbenchSidebarWidth(width);local gap=self.WorkbenchLayout.splitGap
    return {width=width,top=top or 0,sidebarWidth=side,sidebarHeight=self:GetWorkbenchSidebarHeight(height,top),detailX=side+gap,detailWidth=math.max(1,width-side-gap)}
end

-- The draggable divider between a list column and its detail pane. It lives in
-- the gap between them; dragging stores the shared preference and asks the
-- owner to lay out again, passing the previous preference so an owner that
-- cannot follow may restore it. Double-click restores the automatic position.
function addon:CreateWorkbenchSplitter(parent,changed)
    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local splitter=CreateFrame('Button',nil,parent);splitter:SetSize(10,1);splitter:EnableMouse(true)
    local line=splitter:CreateTexture(nil,'ARTWORK');line:SetPoint('TOP',splitter,'TOP',0,0);line:SetPoint('BOTTOM',splitter,'BOTTOM',0,0);splitter.line=line
    local function paint()
        if splitter.drag then line:SetColorTexture(.9,.75,.3,1);line:SetWidth(2)
        elseif splitter.hover then line:SetColorTexture(.62,.66,.69,1);line:SetWidth(2)
        else line:SetColorTexture(.33,.35,.37,.8);line:SetWidth(1) end
    end
    function splitter:Place(geometry)
        self.geometry=geometry;self:ClearAllPoints()
        self:SetPoint('TOPLEFT',parent,'TOPLEFT',geometry.sidebarWidth+(addon.WorkbenchLayout.splitGap-10)/2,-(geometry.top or 0))
        self:SetSize(10,math.max(1,geometry.sidebarHeight));self:Show()
    end
    -- Returns true when the divider moved.
    function splitter:Resize(value)
        local geometry=self.geometry;if not geometry or type(value)~='number' or value~=value then return false end
        local minimum,maximum=addon:GetWorkbenchSidebarBounds(geometry.width)
        value=math.floor(math.max(minimum,math.min(maximum,value))+.5)
        if value==addon:GetWorkbenchSidebarWidth(geometry.width) then return false end
        local previous=addon:GetWorkbenchSidebarPreference()
        addon:SetWorkbenchSidebarPreference(value);changed(previous);return true
    end
    function splitter:Reset() local previous=addon:GetWorkbenchSidebarPreference();addon:SetWorkbenchSidebarPreference(nil);changed(previous) end
    local function stop()
        if not splitter.drag then return end
        splitter.drag=nil;addon:SetUIScript(splitter,'OnUpdate',nil);paint()
    end
    splitter.Stop=stop
    addon:SetUIScript(splitter,'OnMouseDown',function(_,button)
        if button~='LeftButton' or not splitter.geometry or not GetCursorPosition then return end
        local x=GetCursorPosition();splitter.drag={x=x,width=splitter.geometry.sidebarWidth};paint()
        addon:SetUIScript(splitter,'OnUpdate',function()
            local drag=splitter.drag;if not drag then return end
            if IsMouseButtonDown and not IsMouseButtonDown('LeftButton') then stop();return end
            local current=GetCursorPosition();local scale=splitter:GetEffectiveScale() or 1
            splitter:Resize(drag.width+(current-drag.x)/(scale>0 and scale or 1))
        end)
    end)
    addon:SetUIScript(splitter,'OnMouseUp',stop);addon:SetUIScript(splitter,'OnHide',stop)
    addon:SetUIScript(splitter,'OnDoubleClick',function() stop();splitter:Reset() end)
    addon:SetUIScript(splitter,'OnEnter',function()
        splitter.hover=true;paint()
        if GameTooltip then GameTooltip:SetOwner(splitter,'ANCHOR_RIGHT');GameTooltip:SetText(L['Drag to resize the list. Double-click to reset.'],1,1,1,1,true) end
    end)
    addon:SetUIScript(splitter,'OnLeave',function() splitter.hover=nil;paint();if GameTooltip and GameTooltip:IsOwned(splitter) then GameTooltip:Hide() end end)
    paint();return splitter
end

-- Places same-row controls left to right within their parent, sharing the
-- row width evenly. A control never shrinks below `minimum`; when the row
-- cannot hold them all, it wraps onto further lines. Returns the height used.
function addon:LayoutWorkbenchRow(controls,x,y,width,options)
    options=options or {};local gap=options.gap or 4;local pitch=options.pitch or 28
    local count=#controls;if count==0 then return 0 end
    local minimum=options.minimum or 1
    local columns=math.max(1,math.min(count,math.floor((width+gap)/(minimum+gap))))
    if options.columns then columns=math.max(1,math.min(columns,options.columns)) end
    local each=math.max(1,(width-(columns-1)*gap)/columns)
    for index,control in ipairs(controls) do
        local column=(index-1)%columns;local line=math.floor((index-1)/columns)
        control:ClearAllPoints();control:SetPoint('TOPLEFT',x+column*(each+gap),-(y+line*pitch));control:SetWidth(each)
        if options.text then local label=control.GetFontString and control:GetFontString();if label then label:SetWidth(math.max(1,each-options.text)) end end
    end
    return math.ceil(count/columns)*pitch,each,columns
end

-- In-pane confirmation prompts keep their designed width but never exceed
-- the pane they cover. Returns the width used.
function addon:FitWorkbenchPrompt(frame,owner,preferred)
    local available=owner and owner.GetWidth and owner:GetWidth() or preferred
    local width=math.max(1,math.min(preferred,(available or preferred)-16))
    frame:SetWidth(width);return width
end

-- Shared value-field/checkbox geometry for cards and settings. Labels remain
-- outside this region; a wrapped option starts exactly under the value field.
function addon:LayoutWorkbenchFieldOption(field,option,parent,x,y,width,minimum)
    local label=option:GetFontString();local desired=math.ceil(label:GetStringWidth())+26
    local optionWidth=math.min(width,desired);local inline=width>=desired+(minimum or 200)+8
    local inputWidth=inline and width-desired-8 or width
    field:SetParent(parent);field:ClearAllPoints();field:SetPoint('TOPLEFT',x,-y);field:SetWidth(inputWidth)
    option:SetParent(parent);option:ClearAllPoints();option:SetPoint('TOPLEFT',inline and x+inputWidth+8 or x,inline and -y or -y-28)
    option:SetWidth(optionWidth);label:SetWidth(math.max(1,optionWidth-22));label:SetWordWrap(true)
    local optionHeight=math.max(24,label:GetStringHeight());option:SetHeight(optionHeight)
    return inline and math.max(24,optionHeight) or 28+optionHeight,inputWidth,inline
end

-- The old condition declaration adapter retains widget ownership, while all
-- sizing uses the same native rule as action cards and settings fields.
function addon:LayoutWorkbenchSpellGroup(content,children)
    local icon,spell,rank=children[1],children[2],children[3]
    if not icon or not spell then return 0 end
    local width=math.max(1,content:GetWidth()-44);local height,inputWidth
    icon.frame:SetParent(content);icon.frame:ClearAllPoints();icon.frame:SetPoint('TOPLEFT',0,0);icon.frame:SetSize(40,40)
    if rank then height,inputWidth=self:LayoutWorkbenchFieldOption(spell.frame,rank.frame,content,44,6,width)
    else spell.frame:SetParent(content);spell.frame:ClearAllPoints();spell.frame:SetPoint('TOPLEFT',44,-6);spell.frame:SetWidth(width);height,inputWidth=24,width end
    spell:SetWidth(inputWidth);height=math.max(44,height+6)
    if content.obj and content.obj.LayoutFinished then content.obj:LayoutFinished(nil,height) end
    return height
end

-- Editable combobox suggestions share the flat selector used by tags. The
-- edit retains its ordinary parser/commit handlers, so typed new values work.
function addon:AttachWorkbenchEditSuggestions(form,input,entries,changed,valid)
    local menu=input.suggestions or self:CreateWorkbenchSelector();input.suggestions=menu
    local function alive() return not valid or valid() end
    local function suggest(all)
        if not alive() or not input:IsEnabled() then menu:Hide();return end
        local query=all and '' or (input:GetText() or ''):lower();local matches={}
        local values=type(entries)=='function' and entries() or entries
        for _,entry in ipairs(values or {}) do if tostring(entry.text):lower():find(query,1,true) then matches[#matches+1]=entry end end
        if #matches==0 then menu:Hide();return end
        menu:Open(input,matches,input:GetText(),function(value)
            if not alive() then return end
            input:SetText(value);input:SetTextColor(1,1,1)
            for _,record in ipairs(form.edits or {}) do if record.control==input then record.dirty=false;record.baseline=tostring(value) end end
            changed(value);input:ClearFocus()
        end,alive,true)
    end
    for _,event in ipairs({'OnTextChanged','OnEditFocusGained'}) do
        local previous=input:GetScript(event)
        self:SetUIScript(input,event,function(control,user,...)
            if previous then previous(control,user,...) end
            if event=='OnEditFocusGained' or user then suggest(event=='OnEditFocusGained') end
        end)
    end
    for _,event in ipairs({'OnEscapePressed','OnEnterPressed'}) do
        local previous=input:GetScript(event)
        self:SetUIScript(input,event,function(...) menu:Hide();if previous then return previous(...) end end)
    end
    form.cleanups[#form.cleanups+1]=function() menu:Release() end
    return menu
end
