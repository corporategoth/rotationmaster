local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:CreateRotationTagPicker(parent,options)
    local picker={frame=CreateFrame('Frame',nil,parent),tags={},chips={},width=300,options=options,serial=0}
    local frame=picker.frame
    picker.input=addon:CreateWorkbenchEditBox(frame);picker.input:SetPoint('TOPLEFT',0,0);picker.input:SetHeight(24);picker.input:SetMaxLetters(256);picker.input:SetText('')
    picker.input.tooltip=options.allowCustom and L['Type a tag and press Enter, or choose an existing tag. Click a tag to remove it; right-click to choose its color.'] or L['Search existing tags and select any number of them. Click a selected tag to remove it; right-click to choose its color.']
    picker.menu=addon:CreateWorkbenchSelector()
    local function valid() return not picker.released and (not options.valid or options.valid()) end
    local function color(tag) return options.color and options.color(tag) or {r=1,g=1,b=1,a=1} end
    function picker:Layout()
        self.input:SetWidth(self.width);local x,y=0,28
        for i,tag in ipairs(self.tags) do
            local chip=self.chips[i]
            if not chip then chip=addon:CreateWorkbenchPill(frame,'',72);chip:RegisterForClicks('LeftButtonUp','RightButtonUp');self.chips[i]=chip end
            local width=math.min(self.width,math.max(40,#tag*7+20));if x>0 and x+width>self.width then x=0;y=y+22 end
            chip:ClearAllPoints();chip:SetPoint('TOPLEFT',x,-y);chip:SetWidth(width);chip:SetText(tag..' ×');local rgba=color(tag);chip:GetFontString():SetTextColor(rgba.r,rgba.g,rgba.b,rgba.a or 1);chip:SetAccent(.55,.55,.55);chip:Show()
            if options.readOnly then chip:Disable() else chip:Enable() end
            addon:SetUIScript(chip,'OnClick',function(_,button)
                if not valid() or options.readOnly then return end
                if button=='RightButton' and options.setColor and addon.CreateWorkbenchColorPicker then
                    self.colorPicker=self.colorPicker or addon:CreateWorkbenchColorPicker(frame)
                    self.colorPicker:Open(color(tag),function(r,g,b,a) if valid() then options.setColor(tag,{r=r,g=g,b=b,a=a});self:Layout() end end,valid,chip)
                else local tags=addon.RotationData.CopyData(self.tags);table.remove(tags,i);self:Change(tags) end
            end)
            x=x+width+4
        end
        for i=#self.tags+1,#self.chips do self.chips[i]:Hide() end
        local height=#self.tags>0 and y+20 or 24;local changed=height~=self.height;self.height=height;frame:SetHeight(height)
        if changed and options.layout then options.layout(height) end
    end
    function picker:SetWidth(width) self.width=math.max(80,width);frame:SetWidth(self.width);self:Layout() end
    function picker:SetTags(tags) self.tags=addon.RotationData.NormalizeRotationTags(tags or {}) or {};self:Layout() end
    function picker:Change(tags)
        local normalized=addon.RotationData.NormalizeRotationTags(tags);if not normalized then return false end
        self:SetTags(normalized);self.input:SetText('');self.menu:Hide();if options.changed then options.changed(addon.RotationData.CopyData(normalized)) end;return true
    end
    function picker:Add(tag)
        if not valid() or options.readOnly then return false end
        local normalized=addon.RotationData.NormalizeRotationTags({tag});if not normalized then return false end;tag=normalized[1]
        if not options.allowCustom then local found;for _,known in ipairs(options.available() or {}) do if known:lower()==tag:lower() then tag=known;found=true;break end end;if not found then return false end end
        local tags=addon.RotationData.CopyData(self.tags);tags[#tags+1]=tag;return self:Change(tags)
    end
    function picker:Suggest()
        if not valid() or options.readOnly then return end
        local query=(self.input:GetText() or ''):lower();local entries={};local selected={};for _,tag in ipairs(self.tags) do selected[tag:lower()]=true end
        for _,tag in ipairs(options.available() or {}) do if not selected[tag:lower()] and tag:lower():find(query,1,true) then entries[#entries+1]={value=tag,text=tag} end end
        if #entries==0 then self.menu:Hide();return end
        self.menu:Open(self.input,entries,nil,function(tag) if valid() then self:Add(tag) end end,valid,true)
    end
    addon:SetUIScript(picker.input,'OnTextChanged',function(_,user) if user then picker:Suggest() end end)
    addon:SetUIScript(picker.input,'OnEditFocusGained',function() picker:Suggest() end)
    addon:SetUIScript(picker.input,'OnEnterPressed',function() if picker:Add(picker.input:GetText()) then picker.input:ClearFocus() end end)
    addon:SetUIScript(picker.input,'OnEscapePressed',function() picker.menu:Hide();picker.input:SetText('');picker.input:ClearFocus() end)
    addon:SetUIScript(picker.input,'OnEnter',function() if valid() and GameTooltip then GameTooltip:SetOwner(picker.input,'ANCHOR_RIGHT');GameTooltip:SetText(picker.input.tooltip,1,1,1,1,true) end end)
    addon:SetUIScript(picker.input,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(picker.input) then GameTooltip:Hide() end end)
    function picker:Hide() self.menu:Hide();self.input:ClearFocus();if self.colorPicker then self.colorPicker:Close(true) end;frame:Hide() end
    function picker:Release() self.released=true;self.menu:Release();self:Hide() end
    addon:SetUIScript(frame,'OnHide',function() picker.menu:Hide();picker.input:ClearFocus();if picker.colorPicker then picker.colorPicker:Close(true) end end)
    picker:Layout();return picker
end
