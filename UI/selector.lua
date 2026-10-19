local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local AceGUI=LibStub('AceGUI-3.0')
-- Popups are outside scroll children. Their lifetime, focus and dismissal belong
-- to the field that opened them, including when that field is pooled/rebuilt.
function addon:CreateWorkbenchSelector()
    local menu={frame=CreateFrame('Frame',nil,UIParent),rows={},serial=0}
    local frame=menu.frame;frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);self:MakeWindowOpaque(frame)
    menu.search=self:CreateWorkbenchEditBox(frame);self:AttachWorkbenchSearchHint(menu.search);menu.search:SetPoint('TOPLEFT',8,-8);menu.search:SetSize(284,24)
    menu.scroll=self:CreateWorkbenchScrollFrame(frame);menu.scroll:SetPoint('TOPLEFT',8,-40);menu.scroll:SetSize(272,210)
    menu.child=CreateFrame('Frame',nil,menu.scroll);menu.child:SetWidth(272);menu.scroll:SetScrollChild(menu.child)
    function menu:Hide() frame:Hide() end
    function menu:Open(anchor,entries,selected,changed,valid,inline)
        if not inline and frame:IsShown() and self.anchor==anchor then self:Hide();return end
        self.anchor=anchor
        self.serial=self.serial+1;local serial=self.serial;self.valid=valid
        frame:ClearAllPoints();frame:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-2);local width=math.max(180,math.min(720,anchor:GetWidth()));frame:SetWidth(width);self.search:SetWidth(width-16)
        local front=_G.RotationMasterFrontmostDialog;frame:SetFrameLevel(math.max(anchor:GetFrameLevel(),front and front:GetFrameLevel() or 0)+100)
        self.search:SetText('');self.scroll:ClearAllPoints();self.scroll:SetPoint('TOPLEFT',8,inline and -8 or -40)
        if inline then self.search:ClearFocus();self.search:Hide();self.scroll:SetHeight(math.max(24,math.min(8,#entries)*24));frame:SetHeight(self.scroll:GetHeight()+16) else self.search:Show();self.scroll:SetHeight(210) end
        local function draw()
            if not valid() or serial~=menu.serial then return end
            local query=(menu.search:GetText() or ''):lower();local matches={}
            for _,entry in ipairs(entries) do if tostring(entry.text):lower():find(query,1,true) then matches[#matches+1]=entry end end
            local height=math.max(21,math.min(10,#matches)*21);local contentWidth=width-(#matches>10 and 30 or 16)
            menu.scroll:SetSize(contentWidth,height);menu.child:SetWidth(contentWidth);frame:SetHeight((inline and 8 or 40)+height+8)
            for n,entry in ipairs(matches) do
                local row=menu.rows[n];if not row then row=addon:CreateWorkbenchButton(menu.child,'',contentWidth);row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(18,18);row.icon:SetPoint('LEFT',2,0);menu.rows[n]=row end
                row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(n-1)*21);row:SetSize(contentWidth,20);row:SetText(entry.text);row:SetSelected(entry.selected or entry.value==selected);addon:AlignWorkbenchTextLeft(row,entry.icon and 26 or 4);row:Show()
                if entry.icon then row.icon:SetTexture(entry.icon);row.icon:Show() else row.icon:Hide() end
                if entry.color and entry.chooseColor then
                    if not row.colorButton then
                        local swatch=addon:CreateWorkbenchButton(row,'',14);swatch:SetSize(14,14);swatch:SetPoint('RIGHT',-3,0);swatch.fill=swatch:CreateTexture(nil,'ARTWORK');swatch.fill:SetAllPoints(swatch);row.colorButton=swatch
                    end
                    local swatch=row.colorButton;local rgba=entry.color;swatch.fill:SetColorTexture(rgba.r,rgba.g,rgba.b,rgba.a or 1);swatch.tooltip=L['Tag color'];swatch:Show();row:GetFontString():SetWidth(contentWidth-(entry.icon and 48 or 26))
                    addon:SetUIScript(swatch,'OnClick',function() if valid() and frame:IsShown() and serial==menu.serial then entry.chooseColor(swatch,function(color)
                        if valid() and serial==menu.serial then swatch.fill:SetColorTexture(color.r,color.g,color.b,color.a or 1) end
                    end) end end)
                elseif row.colorButton then row.colorButton:Hide();addon:SetUIScript(row.colorButton,'OnClick',nil) end
                if entry.disabled then row:Disable() else row:Enable() end
                addon:SetUIScript(row,'OnClick',function() if valid() and frame:IsShown() and serial==menu.serial then menu:Hide();if not inline and anchor.SetText and anchor.GetFontString then addon:PaintSelectorSelection(anchor,entry,entry.text) end;changed(entry.value,entry.text,entry.icon) end end)
            end
            for i=#matches+1,#menu.rows do menu.rows[i]:Hide() end;menu.child:SetHeight(math.max(1,#matches*21));menu.scroll.workbenchBar:SetValue(0);menu.scroll:UpdateWorkbenchScroll()
        end
        addon:SetUIScript(self.search,'OnTextChanged',draw);draw()
        self.mouseDown=IsMouseButtonDown and IsMouseButtonDown('LeftButton')
        addon:SetUIScript(frame,'OnUpdate',function()
            if not valid() then menu:Hide();return end
            local down=IsMouseButtonDown and IsMouseButtonDown('LeftButton');local over=InputUtil and InputUtil.IsMouseOver or MouseIsOver
            if down and not menu.mouseDown and over and not over(frame) and not over(anchor) then menu:Hide() end;menu.mouseDown=down
        end)
        frame:Show();addon:RegisterWindowForEscape(self);if not inline and valid() then self.search:SetFocus() end
    end
    function menu:Release() self.serial=self.serial+1;self:Hide();if self.OnRelease then self:OnRelease() end end
    addon:SetUIScript(menu.search,'OnEscapePressed',function() menu:Hide() end)
    addon:SetUIScript(frame,'OnHide',function() menu.search:ClearFocus();addon:SetUIScript(frame,'OnUpdate',nil) end)
    frame:Hide();return menu
end

-- AceGUI remains a layout bridge for old condition declarations; no Blizzard
-- dropdown or AceGUI pullout is constructed by this native field adapter.
---@class RMConditionSelector: AceGUIWidget
---@field SetList fun(self: RMConditionSelector, values: table, order?: table)
---@field SetValue fun(self: RMConditionSelector, value: any)
---@field GetValue fun(self: RMConditionSelector): any
---@field SetLabel fun(self: RMConditionSelector, text: string)
---@field SetDisabled fun(self: RMConditionSelector, disabled: boolean)
---@field SetText fun(self: RMConditionSelector, text: string)
local function selectorWidget(legacy)
    local w={type='RM-Selector',list={},order={},disabled=false}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame;frame:SetSize(220,44)
    local caption=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.caption=caption;caption:SetPoint('TOPLEFT',0,0);caption:SetPoint('TOPRIGHT',0,0);caption:SetHeight(18);caption:SetJustifyH('LEFT')
    local button=addon:CreateWorkbenchLabeledIconButton(frame,'chevron-down','',220);w.button=button;button:SetPoint('TOPLEFT',0,-20);button:SetPoint('TOPRIGHT',0,-20)
    local popup=addon:CreateWorkbenchSelector();w.selector=popup
    function w:OnAcquire() self.alive=true;self.list={};self.order={};self:SetDisabled(false);self:SetLabel('');self:SetValue(nil);self:SetWidth(220);self:SetHeight(44) end
    function w:OnRelease() self.alive=false;popup:Release();self.list={};self.order={};self.value=nil end
    function w:SetLabel(text) caption:SetText(text or '');local has=text and text~='';if has then caption:Show() else caption:Hide() end;button:ClearAllPoints();button:SetPoint('TOPLEFT',0,has and -20 or 0);button:SetPoint('TOPRIGHT',0,has and -20 or 0);self:SetHeight(has and 44 or 24) end
    function w:SetText(text) button:SetText(text or L['Select']);addon:AlignWorkbenchTextLeft(button,26) end
    function w:SetValue(value) self.value=value;local entry=self.list[value];if type(entry)=='table' then addon:PaintSelectorSelection(button,entry,entry.text) else self:SetText(entry);if button.valueIcon then button.valueIcon:Hide() end end end
    function w:GetValue() return self.value end
    function w:SetList(values,order)
        self.list=values or {};self.order={};if order then for _,id in ipairs(order) do self.order[#self.order+1]=id end else for id in pairs(self.list) do self.order[#self.order+1]=id end;table.sort(self.order,function(a,b) return tostring(type(self.list[a])=='table' and self.list[a].text or self.list[a])<tostring(type(self.list[b])=='table' and self.list[b].text or self.list[b]) end) end;self:SetValue(self.value)
    end
    function w:SetDisabled(value) self.disabled=value==true;if self.disabled then button:Disable();popup:Hide() else button:Enable() end end
    function w:ClearFocus() popup:Hide() end
    function w:SetPulloutWidth() end
    addon:SetUIScript(button,'OnClick',function()
        if not w.alive or w.disabled then return end
        if popup.frame:IsShown() then popup:Hide();return end
        local entries={};for _,id in ipairs(w.order) do local item=w.list[id];entries[#entries+1]={value=id,text=type(item)=='table' and item.text or item,icon=type(item)=='table' and item.icon or nil} end
        local lifetime=w.userdata
        popup:Open(button,entries,w.value,function(value) if value~=w.value then w:SetValue(value);w:Fire('OnValueChanged',value) end end,function() return w.alive and w.userdata==lifetime and not w.disabled end)
    end)
    addon:SetUIScript(frame,'OnHide',function() popup:Hide() end)
    ---@cast w AceGUIWidget
    return addon:RegisterConditionWidget(w,1,legacy)
end
AceGUI:RegisterWidgetType('RM-Selector',function() return selectorWidget(true) end,1)
---@return RMConditionSelector
function addon:CreateConditionDropdown()
    local w=addon:AcquireConditionWidget('RM-Selector',selectorWidget)
    ---@cast w RMConditionSelector
    return w
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="AceGUI" then return AceGUI end
        if name=="CreateConditionDropdown" then return addon.CreateConditionDropdown end
        if name=="selectorWidget" then return selectorWidget end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/selector.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/selector.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
