local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- BEGIN ANALYTICS PREVIEW HANDOFF
local previewCapture
local previewEnvironment=getfenv(1)
local previewType,previewRaw=type,rawget
---@type any
local previewFunctionEnvironment=getfenv
if addon.BindAnalyticsPreviewCapture then
 addon:BindAnalyticsPreviewCapture(function(sink)previewCapture=sink end)
end
-- END ANALYTICS PREVIEW HANDOFF
local sampleProfile
local sampleTextures={'Interface\\Icons\\Spell_Fire_FlameBolt','Interface\\Icons\\Spell_Frost_FrostBolt02',
    'Interface\\Icons\\Spell_Nature_Lightning','Interface\\Icons\\Spell_Holy_Heal','Interface\\Icons\\INV_Misc_QuestionMark'}
function addon:IsPreviewSampleEnabled()
    if sampleProfile~=self.db.profile then sampleProfile=nil end
    return sampleProfile~=nil
end
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
        local frame=addon:TrackWorkbenchSize(CreateFrame('Frame',nil,UIParent));frame:SetFrameStrata('MEDIUM');frame:SetMovable(true);frame:SetResizable(true);frame:SetClampedToScreen(true);frame:EnableMouse(false)
        window={frame=frame,icons={},count=0,nativePreview=true};self.nativePreviewWindow=window
        window.body=frame:CreateTexture(nil,'BACKGROUND');window.body:SetAllPoints(frame);window.body:SetColorTexture(.055,.065,.075,1)
        -- No title bar or close button: the window is only its icons and their
        -- padded background. Unlocked, the whole body is the drag handle and the
        -- lower-right grip appears on hover. Visibility is Preview Spells alone.
        frame:RegisterForDrag('LeftButton')
        window.grip=CreateFrame('Button',nil,frame);window.grip:SetSize(12,12);window.grip:SetPoint('BOTTOMRIGHT',0,0);window.grip:SetFrameLevel(frame:GetFrameLevel()+5)
        local grip=window.grip:CreateTexture(nil,'OVERLAY');grip:SetAllPoints(window.grip);grip:SetTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up');window.grip:SetAlpha(0)
        function window:Valid() return self.active and addon.db.profile==self.profile and addon.nextWindow==self end
        local nativeValid=window.Valid
        function window:EnsureIcon(index)
            local icon=self.icons[index]
            if not icon then
                icon=CreateFrame('Button',nil,self.frame);icon.texture=icon:CreateTexture(nil,'ARTWORK');icon.texture:SetAllPoints(icon);icon:Hide();self.icons[index]=icon
                -- Icons already take the mouse for tooltips. Left-drag moves an
                -- unlocked window; right-click opens the window menu.
                icon:RegisterForDrag('LeftButton');icon:RegisterForClicks('RightButtonUp')
                addon:SetUIScript(icon,'OnDragStart',function() self:BeginMove() end)
                addon:SetUIScript(icon,'OnDragStop',function() self:EndMove() end)
                addon:SetUIScript(icon,'OnClick',function(_,button) if button=='RightButton' then self:OpenMenu() end end)
            end
            return icon
        end
        function window:ReleaseChildren()
            self.count=0;self.sampleCount=0
            for _,icon in ipairs(self.icons) do if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end;icon:Hide();icon.sample,icon.spellId,icon.itemId=nil,nil,nil;addon:SetUIScript(icon,'OnEnter',nil);addon:SetUIScript(icon,'OnLeave',nil) end
            -- Rotation disable also clears directly, outside a publication batch.
            if sampleProfile==self.profile then self:PaintSamples();if self.sampleCount>0 then self:DoLayout() end end
        end
        function window:ClearSampleIcons()
            for _,icon in ipairs(self.icons) do if icon.sample then
                if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
                icon:Hide();icon.sample=nil;addon:SetUIScript(icon,'OnEnter',nil);addon:SetUIScript(icon,'OnLeave',nil)
            end end
            self.sampleCount=0
        end
        function window:PaintSamples()
            if not self:Valid() or self.sampleBatch or self.count~=0 or not addon:IsPreviewSampleEnabled() then return end
            self:ClearSampleIcons()
            local generation=self.generation
            for i=1,self.slots do
                ---@type any
                local icon=self:EnsureIcon(i);local texture=sampleTextures[i]
                icon.sample=true;icon.spellId,icon.itemId=nil,nil;icon.texture:SetTexture(texture)
                if icon.masqueOwner then icon.masqueSurface.texture:SetTexture(texture) end
                addon:SetUIScript(icon,'OnEnter',function()
                    if not self:Valid() or generation~=self.generation or not icon.sample or not GameTooltip then return end
                    GameTooltip:SetOwner(icon,'ANCHOR_BOTTOMRIGHT',3);GameTooltip:SetText(L['Sample icon'])
                end)
                addon:SetUIScript(icon,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end end)
                icon:Show()
            end
            self.sampleCount=self.slots
        end
        function window:DoLayout()
            if not self.active then return end
            local n=self.slots or 1;local size=self.iconSize;local pad=self.opacity>0 and 4 or 0
            local width,height=(self.vertical and 1 or n)*size+2*pad,(self.vertical and n or 1)*size+2*pad
            self.layouting=true
            if not sameGeometry(self.frame:GetWidth(),width) or not sameGeometry(self.frame:GetHeight(),height) then self.frame:SetSize(width,height) end
            self.layouting=false
            for i,icon in ipairs(self.icons) do
                local x,y=pad+(self.vertical and 0 or i-1)*size,-pad-(self.vertical and i-1 or 0)*size
                local pointCount=icon:GetNumPoints();local point,parent,relative,oldx,oldy
                if pointCount==1 then point,parent,relative,oldx,oldy=icon:GetPoint(1) end
                if pointCount~=1 or point~='TOPLEFT' or parent~=self.frame or relative~='TOPLEFT' or not sameGeometry(oldx,x) or not sameGeometry(oldy,y) then
                    icon:ClearAllPoints();icon:SetPoint('TOPLEFT',self.frame,'TOPLEFT',x,y)
                end
                if not sameGeometry(icon:GetWidth(),size) or not sameGeometry(icon:GetHeight(),size) then icon:SetSize(size,size) end
                if icon:GetAlpha()~=1 then icon:SetAlpha(1) end
                if icon.masqueOwner then addon:ResizeMasquePreviewIcon(self,icon) end
            end
        end
        function window:Configure()
            if not self.active then return end
            local profile=self.profile
            self.slots=addon:IsPreviewSampleEnabled() and (profile.preview_spells or 0)<=0 and 3 or math.floor(clamp(profile.preview_spells,1,5,1));self.iconSize=clamp(profile.preview_icon_size,24,160,64);self.vertical=profile.preview_vertical==true;self.locked=profile.preview_locked==true;self.opacity=clamp(profile.preview_opacity,0,1,1)
            self.body:SetAlpha(self.opacity)
            -- Locked or fully transparent, the background never intercepts
            -- the mouse; only the icons keep their own tooltips and clicks.
            self.frame:EnableMouse(not self.locked and self.opacity>0);if self.locked then self.frame:StopMovingOrSizing() end
            if not self.locked and self.opacity>0 then self.grip:Show() else self.grip:Hide();self:SetHover(false) end
            for i,icon in ipairs(self.icons) do if i>self.slots then icon:Hide() end end
            if addon.ConfigureMasquePreview then addon:ConfigureMasquePreview(self) end
            self:PaintSamples()
            self:DoLayout()
        end
        function window:Resize(width,height)
            if not self:Valid() or self.locked then self:DoLayout();return end
            local pad=self.opacity>0 and 4 or 0
            local x=(width-2*pad)/(self.vertical and 1 or self.slots);local y=(height-2*pad)/(self.vertical and self.slots or 1)
            local size=math.abs(x-self.iconSize)>=math.abs(y-self.iconSize) and x or y
            self.profile.preview_icon_size=math.floor(clamp(size,24,160,64)+.5);self:Configure()
        end
        local nativeAddRecommendation
        function window:AddRecommendation(spellId,itemId)
            if not self:Valid() or self.count>=self.slots then return end
            if (self.sampleCount or 0)>0 then self:ClearSampleIcons() end
            self.count=self.count+1;local index=self.count
            ---@type any
            local icon=self:EnsureIcon(index)
            local captureGeneration,captureProfile,captureFrame,captureIcons,captureTexture
            if previewCapture then
                captureGeneration,captureProfile=self.generation,self.profile
                captureFrame,captureIcons,captureTexture=self.frame,self.icons,icon.texture
            end
            local info
            if itemId then info=addon.Platform:GetItemDisplayInfo(itemId) else info=addon.Platform:GetSpellInfo(spellId) end
            icon.spellId,icon.itemId=spellId,itemId;icon.texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark')
            if icon.masqueOwner then icon.masqueSurface.texture:SetTexture(info and info.iconID or 'Interface\\Icons\\INV_Misc_QuestionMark') end
            local generation=self.generation
            addon:SetUIScript(icon,'OnEnter',function()
                if not self:Valid() or generation~=self.generation or not GameTooltip then return end
                GameTooltip:SetOwner(icon,'ANCHOR_BOTTOMRIGHT',3);GameTooltip:SetHyperlink((itemId and 'item:'..itemId or 'spell:'..spellId))
            end)
            addon:SetUIScript(icon,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end end)
            icon:Show();self:DoLayout()
            -- BEGIN ANALYTICS PREVIEW DELIVERY
            if previewCapture and index==1 and self.AddRecommendation==nativeAddRecommendation then
                local owner,profile,generation=self,captureProfile,captureGeneration
                local frame,icons,texture=captureFrame,captureIcons,captureTexture
                local frameVisible,iconVisible,textureGet,displayId,observed
                -- Pure captured-state checks run again after every native read.
                -- Initial property reads are inside the collector's protected call.
                local function eligible()
                    return owner.Valid==nativeValid and previewFunctionEnvironment(nativeAddRecommendation)==previewEnvironment
                        and nativeValid(owner) and owner.profile==profile and owner.generation==generation
                        and owner.AddRecommendation==nativeAddRecommendation and owner.frame==frame and owner.icons==icons
                        and icons[1]==icon and icon.texture==texture and not icon.sample and icon.spellId==spellId
                        and icon.itemId==nil and itemId==nil and previewType(info)=='table'
                        and previewType(displayId)=='number' and displayId==displayId and displayId>0 and displayId<math.huge
                        and previewRaw(info,'iconID')==displayId and frame.IsVisible==frameVisible and icon.IsVisible==iconVisible
                        and previewType(frameVisible)=='function' and previewType(iconVisible)=='function'
                        and texture.GetTexture==textureGet and previewType(textureGet)=='function'
                end
                previewCapture("delivery",self,function()
                    if not observed then
                        frameVisible,iconVisible,textureGet=frame.IsVisible,icon.IsVisible,texture.GetTexture
                        if previewType(info)=='table' then displayId=previewRaw(info,'iconID') end
                        observed=true
                    end
                    if not eligible() then return 'retired' end
                    local frameShown,iconShown=frameVisible(frame),iconVisible(icon)
                    local rendered=textureGet(texture)
                    if not eligible() or rendered~=displayId then return 'retired' end
                    if frameShown==true and iconShown==true then return 'visible' end
                    if frameShown==false or iconShown==false then return 'hidden' end
                    return 'unknown'
                end,nil,spellId)
            end
            -- END ANALYTICS PREVIEW DELIVERY
        end
        nativeAddRecommendation=window.AddRecommendation
        function window:PauseLayout() self.sampleBatch=true;if (self.sampleCount or 0)>0 then self:ClearSampleIcons() end end
        function window:ResumeLayout() self.sampleBatch=false;if sampleProfile==self.profile then self:PaintSamples() end end
        function window:Show() if self:Valid() then self.frame:Show() end end
        function window:Hide()
            if previewCapture then
                local generation,profile=self.generation,self.profile;previewCapture("retire",self)
                if self.generation~=generation or self.profile~=profile then return end
            end
            self.frame:Hide()
        end
        function window:Release()
            if previewCapture then
                local generation,profile=self.generation,self.profile;previewCapture("retire",self)
                if self.generation~=generation or self.profile~=profile then return end
            end
            if sampleProfile==self.profile then sampleProfile=nil end;self.sampleBatch=false;self:ReleaseChildren();self.active=false;self.frame:StopMovingOrSizing();self.frame:Hide();if addon.ReleaseMasquePreview then addon:ReleaseMasquePreview(self) end end
        function window:SetHover(over) self.hovered=over==true;self.grip:SetAlpha((self.hovered or self.gripHovered) and 1 or 0) end
        function window:BeginMove() if self:Valid() and not self.locked then self.moving=true;self.frame:StartMoving() end end
        function window:EndMove()
            local moving=self.moving;self.moving=nil
            if not moving or not self:Valid() or self.locked then return end;self.frame:StopMovingOrSizing()
            local point,_,relative,x,y=self.frame:GetPoint(1);self.profile.preview_window={point=point,relpoint=relative,xoffs=x,yoffs=y};self.profile.previewHeaderlessGeometry=true
        end
        -- The menu never hides the window: it is shown exactly while Preview
        -- Spells is above zero (or samples are on) and hidden at zero.
        function window:MenuEntries()
            if not self:Valid() then return nil end
            local locked,generation=self.locked==true,self.generation
            local function current() return self:Valid() and self.generation==generation end
            return {
                {text=addon.pretty_name or L['Rotation Master'],isTitle=true},
                {text=L['Lock position and size'],checked=locked,func=function() if current() then addon:SetPreviewLocked(not locked) end end},
                {text=L['Open General settings'],func=function() if current() then addon:ShowConfig('General') end end},
            }
        end
        function window:OpenMenu()
            local entries=self:MenuEntries();if not entries then return end
            -- The same dropdown API as the minimap menu; every client provides it natively.
            if UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
                self.menu=self.menu or CreateFrame('Frame',addon_name..'PreviewMenu',UIParent,'UIDropDownMenuTemplate')
                UIDropDownMenu_Initialize(self.menu,function()
                    for _,entry in ipairs(entries) do
                        local info=UIDropDownMenu_CreateInfo();info.text=entry.text
                        if entry.isTitle then info.isTitle=true;info.notCheckable=true
                        elseif entry.checked~=nil then info.isNotRadio=true;info.checked=entry.checked;info.func=entry.func
                        else info.notCheckable=true;info.func=entry.func end
                        UIDropDownMenu_AddButton(info)
                    end
                end,'MENU')
                ToggleDropDownMenu(1,nil,self.menu,'cursor',5,-10)
            end
        end
        function window:SetWidth(width) self:Resize(width,self.frame:GetHeight()) end
        function window:SetHeight(height) self:Resize(self.frame:GetWidth(),height) end
        function window:ClearAllPoints() self.frame:ClearAllPoints() end
        function window:SetPoint(...) self.frame:SetPoint(...) end
        function window:GetPoint(...) return self.frame:GetPoint(...) end
        addon:SetUIScript(frame,'OnSizeChanged',function(_,width,height) if not window.layouting then window:Resize(width,height) end end)
        addon:SetUIScript(frame,'OnDragStart',function() window:BeginMove() end)
        addon:SetUIScript(frame,'OnDragStop',function() window:EndMove() end)
        addon:SetUIScript(frame,'OnMouseUp',function(_,button) if button=='RightButton' then window:OpenMenu() end end)
        addon:SetUIScript(frame,'OnEnter',function() window:SetHover(true) end)
        addon:SetUIScript(frame,'OnLeave',function() window:SetHover(false) end)
        addon:SetUIScript(window.grip,'OnEnter',function() window.gripHovered=true;window:SetHover(window.hovered) end)
        addon:SetUIScript(window.grip,'OnLeave',function() window.gripHovered=false;window:SetHover(window.hovered) end)
        addon:SetUIScript(window.grip,'OnMouseDown',function(_,button) if button=='LeftButton' and window:Valid() and not window.locked and window.opacity>0 then window.frame:StartSizing('BOTTOMRIGHT') end end)
        addon:SetUIScript(window.grip,'OnMouseUp',function() if window:Valid() then window.frame:StopMovingOrSizing() end end)
    end
    if window.active and addon.ReleaseMasquePreview then addon:ReleaseMasquePreview(window) end
    local profile=self.db.profile;window.profile=profile;window.active=true;window.sampleBatch=false;window.generation=(window.generation or 0)+1;window:ReleaseChildren();self.nextWindow=window
    window.moving=nil
    window:Configure();window.frame:ClearAllPoints()
    addon:MigratePreviewHeaderGeometry(profile,window.opacity)
    local position=profile.preview_window
    if type(position)=='table' and position.point and position.relpoint then window.frame:SetPoint(position.point,UIParent,position.relpoint,position.xoffs or 0,position.yoffs or 0) else window.frame:SetPoint('CENTER',UIParent,'CENTER',0,0) end
    window.frame:Show();return window
end
-- The window lost its 20-pixel title bar. A position saved with it anchored
-- the old outer frame, so shift it once per profile to keep the icons where
-- they were: the header sat on top, so top anchors drop 20 pixels, middle
-- anchors 10 and bottom anchors stay. Opacity zero reserved no header.
-- The flag means "the saved position is headerless"; a drag saves one too.
-- With no saved position there is nothing to shift and nothing is written.
function addon:MigratePreviewHeaderGeometry(profile,opacity)
    if type(profile)~='table' or profile.previewHeaderlessGeometry==true then return end
    local position=profile.preview_window
    if type(position)~='table' or type(position.point)~='string' or type(position.relpoint)~='string' then return end
    local point=position.point:upper();local shift=(opacity or 1)<=0 and 0 or point:find('^TOP') and 20 or point:find('^BOTTOM') and 0 or 10
    if shift>0 then profile.preview_window={point=position.point,relpoint=position.relpoint,xoffs=position.xoffs or 0,yoffs=(position.yoffs or 0)-shift} end
    profile.previewHeaderlessGeometry=true
end
function addon:SetPreviewLocked(locked)
    locked=locked==true;self.db.profile.preview_locked=locked
    if self.previewLockChanged then self.previewLockChanged(locked) end
    if self.RefreshPreviewWindow then self:RefreshPreviewWindow() end
    return locked
end
function addon:RefreshPreviewWindow()
    local count=self.db.profile.preview_spells or 0
    if count<=0 and not self:IsPreviewSampleEnabled() then if self.nextWindow then self.nextWindow:Release();self.nextWindow=nil end
    elseif self.nextWindow and self.nextWindow.nativePreview and self.nextWindow.active and self.nextWindow.profile==self.db.profile then self.nextWindow:Configure();self.nextWindow:Show()
    else if self.nextWindow and not (self.nextWindow.nativePreview and self.nextWindow.active==false) then self.nextWindow:Release() end;self:CreateNativePreviewWindow() end
end
-- Returns the resulting enabled state. Non-Boolean input leaves it unchanged.
-- The mode belongs only to this loaded UI and current profile; no saved field.
function addon:SetPreviewSampleEnabled(enabled)
    if type(enabled)~='boolean' then return self:IsPreviewSampleEnabled() end
    sampleProfile=enabled and self.db.profile or nil
    local window=self.nextWindow
    if not enabled and window and window.nativePreview and window.profile==self.db.profile then window:ClearSampleIcons() end
    self:RefreshPreviewWindow()
    return self:IsPreviewSampleEnabled()
end
