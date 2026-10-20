local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function clamp(value,lo,hi,fallback)
    return type(value)=='number' and value==value and math.max(lo,math.min(hi,value)) or fallback
end
-- Native geometry can read back with small floating-point differences.
local function sameGeometry(a,b)
    return type(a)=='number' and type(b)=='number' and math.abs(a-b)<=.1
end
---@class RMRecommendationPreview
---@field ReleaseChildren fun(self: RMRecommendationPreview)
---@field PauseLayout fun(self: RMRecommendationPreview)
---@field ResumeLayout fun(self: RMRecommendationPreview)
---@field DoLayout fun(self: RMRecommendationPreview)
---@field AddRecommendation fun(self: RMRecommendationPreview, spellId: number, itemId?: number)
function addon:CreateNativePreviewWindow()
    local window=self.nativePreviewWindow
    if not window then
        local frame=CreateFrame('Frame',nil,UIParent);frame:SetFrameStrata('MEDIUM');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(false)
        window={frame=frame,icons={},count=0,nativePreview=true};self.nativePreviewWindow=window
        window.body=frame:CreateTexture(nil,'BACKGROUND');window.body:SetAllPoints(frame);window.body:SetColorTexture(.055,.065,.075,1)
        window.header=CreateFrame('Frame',nil,frame);window.header:SetPoint('TOPLEFT');window.header:SetPoint('TOPRIGHT');window.header:SetHeight(20);window.header:EnableMouse(true);window.header:RegisterForDrag('LeftButton')
        window.header.art=window.header:CreateTexture(nil,'BACKGROUND');window.header.art:SetAllPoints(window.header);window.header.art:SetColorTexture(.15,.16,.18,1)
        window.title=window.header:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');window.title:SetPoint('LEFT',5,0);window.title:SetJustifyH('LEFT');window.title:SetText(addon.pretty_name or L['Rotation Master'])
        window.close=addon:CreateWorkbenchIconButton(window.header,'close',L['Close']);window.close:SetSize(18,18);window.close.icon:SetSize(14,14);window.close:SetPoint('TOPRIGHT',-1,-1)
        window.grip=CreateFrame('Button',nil,frame);window.grip:SetSize(12,12);window.grip:SetPoint('BOTTOMRIGHT',0,0)
        local grip=window.grip:CreateTexture(nil,'OVERLAY');grip:SetAllPoints(window.grip);grip:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
        function window:Valid() return self.active and addon.db.profile==self.profile and addon.nextWindow==self end
        function window:ReleaseChildren()
            self.count=0
            for _,icon in ipairs(self.icons) do if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end;icon:Hide();addon:SetUIScript(icon,'OnEnter',nil);addon:SetUIScript(icon,'OnLeave',nil) end
        end
        function window:DoLayout()
            if not self.active then return end
            local n=self.slots or 1;local size=self.iconSize;local pad=self.opacity>0 and 4 or 0;local title=self.opacity>0 and 20 or 0
            local width,height=(self.vertical and 1 or n)*size+2*pad,(self.vertical and n or 1)*size+2*pad+title
            self.layouting=true
            local currentWidth=self.frame:GetWidth()
            if not sameGeometry(currentWidth,width) or not sameGeometry(self.frame:GetHeight(),height) or (currentWidth<140)~=(width<140) then self.frame:SetSize(width,height) end
            self.layouting=false
            local titleWidth=math.max(0,self.frame:GetWidth()-28)
            if not sameGeometry(self.title:GetWidth(),titleWidth) then self.title:SetWidth(titleWidth) end
            local text=self.frame:GetWidth()<140 and 'RM' or addon.pretty_name or L['Rotation Master']
            if self.title:GetText()~=text then self.title:SetText(text) end
            for i,icon in ipairs(self.icons) do
                local x,y=pad+(self.vertical and 0 or i-1)*size,-title-pad-(self.vertical and i-1 or 0)*size
                local pointCount=icon:GetNumPoints();local point,parent,relative,oldx,oldy
                if pointCount==1 then point,parent,relative,oldx,oldy=icon:GetPoint(1) end
                if pointCount~=1 or point~='TOPLEFT' or parent~=self.frame or relative~='TOPLEFT' or not sameGeometry(oldx,x) or not sameGeometry(oldy,y) then
                    icon:ClearAllPoints();icon:SetPoint('TOPLEFT',self.frame,'TOPLEFT',x,y)
                end
                if not sameGeometry(icon:GetWidth(),size) or not sameGeometry(icon:GetHeight(),size) then icon:SetSize(size,size) end
                if icon:GetAlpha()~=1 then icon:SetAlpha(1) end
            end
        end
        function window:Configure()
            if not self.active then return end
            local profile=self.profile
            self.slots=math.floor(clamp(profile.preview_spells,1,5,1));self.iconSize=clamp(profile.preview_icon_size,24,160,64);self.vertical=profile.preview_vertical==true;self.locked=profile.preview_locked==true;self.opacity=clamp(profile.preview_opacity,0,1,1)
            self.body:SetAlpha(self.opacity);self.header:SetAlpha(self.opacity)
            if self.opacity>0 then self.header:Show() else self.header:Hide() end
            self.header:EnableMouse(not self.locked and self.opacity>0);if self.locked then self.frame:StopMovingOrSizing() end
            if not self.locked and self.opacity>0 then self.grip:Show() else self.grip:Hide() end
            for i,icon in ipairs(self.icons) do if i>self.slots then icon:Hide() end end
            self:DoLayout()
        end
        function window:Resize(width,height)
            if not self:Valid() or self.locked then self:DoLayout();return end
            local pad=self.opacity>0 and 4 or 0;local title=self.opacity>0 and 20 or 0
            local x=(width-2*pad)/(self.vertical and 1 or self.slots);local y=(height-2*pad-title)/(self.vertical and self.slots or 1)
            local size=math.abs(x-self.iconSize)>=math.abs(y-self.iconSize) and x or y
            self.profile.preview_icon_size=math.floor(clamp(size,24,160,64)+.5);self:Configure()
        end
        function window:AddRecommendation(spellId,itemId)
            if not self:Valid() or self.count>=self.slots then return end
            self.count=self.count+1;local index=self.count;local icon=self.icons[index]
            if not icon then icon=CreateFrame('Button',nil,self.frame);icon.texture=icon:CreateTexture(nil,'ARTWORK');icon.texture:SetAllPoints(icon);self.icons[index]=icon end
            local info
            if itemId then info=addon.Platform:GetItemDisplayInfo(itemId) else info=addon.Platform:GetSpellInfo(spellId) end
            icon.spellId,icon.itemId=spellId,itemId;icon.texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark')
            local generation=self.generation
            addon:SetUIScript(icon,'OnEnter',function()
                if not self:Valid() or generation~=self.generation or not GameTooltip then return end
                GameTooltip:SetOwner(icon,'ANCHOR_BOTTOMRIGHT',3);GameTooltip:SetHyperlink((itemId and 'item:'..itemId or 'spell:'..spellId))
            end)
            addon:SetUIScript(icon,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end end)
            icon:Show();self:DoLayout()
        end
        function window:PauseLayout() end
        function window:ResumeLayout() end
        function window:Show() if self:Valid() then self.frame:Show() end end
        function window:Hide() self.frame:Hide() end
        function window:Release() self:ReleaseChildren();self.active=false;self.frame:StopMovingOrSizing();self.frame:Hide() end
        function window:SetWidth(width) self:Resize(width,self.frame:GetHeight()) end
        function window:SetHeight(height) self:Resize(self.frame:GetWidth(),height) end
        function window:ClearAllPoints() self.frame:ClearAllPoints() end
        function window:SetPoint(...) self.frame:SetPoint(...) end
        function window:GetPoint(...) return self.frame:GetPoint(...) end
        addon:SetUIScript(frame,'OnSizeChanged',function(_,width,height) if not window.layouting then window:Resize(width,height) end end)
    end
    local profile=self.db.profile;window.profile=profile;window.active=true;window.generation=(window.generation or 0)+1;window:ReleaseChildren();self.nextWindow=window
    local generation=window.generation
    local function valid() return window:Valid() and generation==window.generation end
    addon:SetUIScript(window.close,'OnClick',function()
        if not valid() then return end
        window:Release();addon.nextWindow=nil;profile.preview_spells=0;if addon.preview_closed_func then addon.preview_closed_func() end
    end)
    addon:SetUIScript(window.header,'OnDragStart',function() if valid() and not window.locked and window.opacity>0 then window.frame:StartMoving() end end)
    addon:SetUIScript(window.header,'OnDragStop',function()
        if not valid() or window.locked then return end;window.frame:StopMovingOrSizing()
        local point,_,relative,x,y=window.frame:GetPoint(1);profile.preview_window={point=point,relpoint=relative,xoffs=x,yoffs=y}
    end)
    addon:SetUIScript(window.grip,'OnMouseDown',function(_,button) if valid() and button=='LeftButton' and not window.locked and window.opacity>0 then window.frame:StartSizing('BOTTOMRIGHT') end end)
    addon:SetUIScript(window.grip,'OnMouseUp',function() if valid() then window.frame:StopMovingOrSizing() end end)
    window:Configure();window.frame:ClearAllPoints()
    local position=profile.preview_window
    if type(position)=='table' and position.point and position.relpoint then window.frame:SetPoint(position.point,UIParent,position.relpoint,position.xoffs or 0,position.yoffs or 0) else window.frame:SetPoint('CENTER',UIParent,'CENTER',0,0) end
    window.frame:Show();return window
end
function addon:RefreshPreviewWindow()
    local count=self.db.profile.preview_spells or 0
    if count<=0 then if self.nextWindow then self.nextWindow:Release();self.nextWindow=nil end
    elseif self.nextWindow and self.nextWindow.nativePreview and self.nextWindow.profile==self.db.profile then self.nextWindow:Configure();self.nextWindow:Show()
    else if self.nextWindow then self.nextWindow:Release() end;self:CreateNativePreviewWindow() end
end
