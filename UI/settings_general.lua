local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function entries(values)
    local result={};for key,text in pairs(values or {}) do result[#result+1]={value=key,text=text} end
    table.sort(result,function(a,b) return tostring(a.text)<tostring(b.text) end);return result
end
function addon:BuildGeneralSettings(p)
    local store=p:SettingsData()
    local profile=store.profile
    p:Column(1)
    p:Heading(L['Recommendations'])
    p:Check('enable',L['Enable'],profile.enable,function(v) profile.enable=v;p:RunSettingsEffect('enable',function() if v then self:enable() else self:disable() end end) end)
    p:Slider('poll',L['Polling Interval (seconds)'],profile.poll,.05,1,.05,function(v) profile.poll=v;p:RunSettingsEffect('poll',function() if self.rotationTimer then self:DisableRotationTimer();self:EnableRotationTimer() end end) end)
    p:Check('disable_autoswitch',L['Disable Auto-Switching'],profile.disable_autoswitch,function(v) profile.disable_autoswitch=v end)
    local checkY=p.y-30
    local bar=p:Check('disable_buttons',L['Disable Bar Highlighting'],profile.disable_buttons,function(v) profile.disable_buttons=v;p:RunSettingsEffect('buttons',function() if v then self:GlowClear() end end) end)
    local half=(p.width-8)/2;p.fields.disable_autoswitch:SetWidth(half);p.fields.disable_autoswitch:GetFontString():SetWidth(half-22);bar:ClearAllPoints();bar:SetPoint('TOPLEFT',half+8,-checkY);bar:SetWidth(half);bar:GetFontString():SetWidth(half-22);p.y=p.y-30
    p:Slider('live_config_update',L['Live Status Update Frequency (seconds)'],profile.live_config_update,0,60,1,function(v)
        if profile.live_config_update==v then return end;profile.live_config_update=v
        p:RunSettingsEffect('conditionTimer',function()
        if self.conditionEvalTimer then self:CancelTimer(self.conditionEvalTimer);self.conditionEvalTimer=nil end
        if v>0 then self.conditionEvalTimer=self:ScheduleRepeatingTimer('UpdateCurrentCondition',v) end
        end)
    end)
    p:Check('minimap',L['Minimap Icon'],not (profile.minimap or {}).hide,function(v)
        profile.minimap=profile.minimap or {};profile.minimap.hide=not v;p:RunSettingsEffect('minimap',function() local lib=LibStub('LibDBIcon-1.0');if v then lib:Show(self.name) else lib:Hide(self.name) end end)
    end)
    p:Choice('rotation_view',L['Default rotation view'],profile.rotation_view or 'diagram',{{value='diagram',text=L['Diagram view']},{value='list',text=L['List view']}},function(v) profile.rotation_view=v end)
    p:Heading(L['History and preview'])
    for _,entry in ipairs({{'spell_history','Spell History Memory (seconds)'},{'combat_history','Combat History Memory (seconds)'},{'damage_history','Damage History Memory (seconds)'}}) do
        local key=entry[1];p:Slider(key,L[entry[2]],profile[key],0,300,1,function(v) profile[key]=v end)
    end
    local function previewChanged()
        p:RunSettingsEffect('preview',function() if self.RefreshPreviewWindow then self:RefreshPreviewWindow() elseif (profile.preview_spells or 0)>0 then if self.nextWindow then self.nextWindow:SetWidth(profile.preview_spells*128) else self:CreatePreviewWindow() end elseif self.nextWindow then self.nextWindow:Release();self.nextWindow=nil end end)
    end
    p:Slider('preview_spells',L['Preview Spells'],profile.preview_spells,0,5,1,function(v) profile.preview_spells=v;previewChanged() end)
    p:Slider('preview_opacity',L['Preview window opacity'],profile.preview_opacity or 1,0,1,.05,function(v) profile.preview_opacity=v;previewChanged() end)
    local previewY=p.y;local third=p.width/3
    local locked=p:Check('preview_locked',L['Lock position and size'],profile.preview_locked==true,function(v) profile.preview_locked=v;previewChanged() end)
    local orientation=p:Toggle('preview_vertical',nil,profile.preview_vertical==true,L['Horizontal'],L['Vertical'],function(v) profile.preview_vertical=v;previewChanged();p:Draw() end)
    local reset=p:Button('preview_reset',L['Reset'],function() end)
    local resetToken=p.generation
    -- Moving the preview is immediate, like dragging its title bar. Synchronize
    -- only these baselines so an unrelated staged setting stays staged.
    self:SetUIScript(reset,'OnClick',function()
        if not p:Valid(resetToken) then return end
        for _,settings in ipairs({self.db.profile,profile,p.draftBaseline and p.draftBaseline.profile or {}}) do settings.preview_window=nil;settings.preview_icon_size=64 end
        if self.nextWindow then if self.nextWindow.Configure then self.nextWindow:Configure() end;self.nextWindow:ClearAllPoints();self.nextWindow:SetPoint('CENTER',UIParent,'CENTER',0,0) end
        if p.fields.apply then if p:IsSettingsDraftDirty() then p.fields.apply:Enable() else p.fields.apply:Disable() end end
        if p.RefreshUnsaved then p:RefreshUnsaved() end
    end)
    reset.tooltip=L['Reset preview position']
    for i,control in ipairs({locked,orientation,reset}) do control:ClearAllPoints();control:SetPoint('TOPLEFT',(i-1)*third,-previewY);control:SetWidth(third-8) end
    locked:GetFontString():SetWidth(third-30);p.y=previewY+30
    -- This callback belongs to the long-lived preview, never to a released tab.
    local previewOwner=self.db.profile;self.preview_closed_func=function() if addon.db.profile==previewOwner then previewOwner.preview_spells=0 end end
    p:Column(2)
    p:Heading(L['Effect Options'])
    local y=p:Row(L['Highlight preview'],48)
    local preview=p:Acquire('preview',function() local frame=CreateFrame('Frame',nil,p.child);frame.icon=frame:CreateTexture(nil,'ARTWORK');frame.icon:SetAllPoints(frame);return frame end)
    preview:ClearAllPoints();preview:SetPoint('TOPLEFT',224,-y);preview:SetSize(36,36);preview.icon:SetTexture('Interface\\Icons\\Spell_Nature_Lightning')
    local function refresh()
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        if self.HideGlow then self:HideGlow(preview,'settings-preview') end
        local effect=(store.global.effects or {})[profile.effect]
        if effect and self.Glow then self:Glow(preview,'settings-preview',effect,profile.color or {r=1,g=1,b=1,a=1},profile.magnification or 1,profile.setpoint or 'CENTER',profile.xoffs or 0,profile.yoffs or 0) end
    end
    local effectEntries={};for id,effect in pairs(store.global.effects or {}) do if type(effect)=='table' and effect.name then effectEntries[#effectEntries+1]={value=id,text=effect.name} end end;table.sort(effectEntries,function(a,b) return a.text<b.text end)
    p:Choice('effect',L['Effect'],profile.effect,effectEntries,function(v) profile.effect=v;refresh() end)
    p:Slider('magnification',L['Magnification'],profile.magnification or 1,.1,2,.1,function(v) profile.magnification=v;refresh() end)
    p:Color('color',L['Highlight Color'],profile.color,function(v) profile.color=v;refresh() end)
    local positionY=p.y
    local anchor=p:Choice('setpoint',nil,profile.setpoint or 'CENTER',entries(self.setpoints),function(v) profile.setpoint=v;profile.xoffs=0;profile.yoffs=0;refresh();p:Draw() end)
    anchor:ClearAllPoints();anchor:SetPoint('TOPLEFT',0,-positionY-22);anchor:SetWidth(154);p.y=positionY
    p:Position(profile.xoffs,profile.yoffs,function(x,y,center) profile.xoffs=x;profile.yoffs=y;if center then profile.setpoint='CENTER' end;refresh() end,true)
    if WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT>=2 and store.char and store.char.specs then
        p:Heading(L['Specialization Names']);for i,caption in ipairs({PRIMARY,SECONDARY}) do p:Edit('spec'..i,caption,store.char.specs[i],nil,function(v) store.char.specs[i]=v end) end
    end
    p:Heading(L['Debugging Options'])
    p:Choice('loglevel',L['Log Level'],profile.loglevel or 2,entries(self.loglevels),function(v) profile.loglevel=v;p:Draw() end)
    local detail=p:Check('detailed_profiling',L['Detailed Profiling'],profile.detailed_profiling,function(v) profile.detailed_profiling=v end);if (profile.loglevel or 2)<3 then detail:Disable() end
    if self.GetCacheDiagnosticMode and self.SetCacheDiagnosticMode then
        local _,requested=self:GetCacheDiagnosticMode()
        local control=p:Check('cpu_cache_bypass',L['Bypass observation cache (reload required)'],requested=='direct',function() end)
        local modeText=p:Text('')
        local function updateModeText()
            local loaded,nextMode=self:GetCacheDiagnosticMode()
            modeText:SetText(string.format(L['Observation cache: %s\nNext reload: %s'],L[loaded],L[nextMode]))
        end
        updateModeText();modeText:SetHeight(math.max(40,modeText:GetStringHeight()));p.y=p.y+modeText:GetHeight()-20
        -- Diagnostic requests persist independently of pending settings edits.
        self:SetUIScript(control,'OnClick',p:Guard(function()
            local loaded,current=self:GetCacheDiagnosticMode()
            local wanted=current=='direct' and 'cached' or 'direct'
            local ok=self:SetCacheDiagnosticMode(wanted)
            control:SetChecked((ok and wanted or current)=='direct');updateModeText()
            p:Message(ok and string.format(L['Cache diagnostic saved for the next reload. Active mode: %s.'],L[loaded]) or L['Cache diagnostic is unavailable.'],ok)
        end))
    end
    if self.RunCPUProfileAction then
        local controls={
            {key='cpu_capture',text=L['Capture CPU (10s)'],action='start'},
            {key='cpu_report',text=L['CPU report'],action='report'},
            {key='cpu_cancel',text=L['Cancel capture'],action='cancel'},
        }
        local diagnosticY=p.y;local controlWidth=(p.width-8)/3
        for i,entry in ipairs(controls) do
            local control=p:Button(entry.key,entry.text,function() end)
            control:ClearAllPoints();control:SetPoint('TOPLEFT',(i-1)*(controlWidth+4),-diagnosticY);control:SetWidth(controlWidth)
            -- Diagnostics use live runtime settings, without applying/flushing a draft.
            self:SetUIScript(control,'OnClick',p:Guard(function()
                local ok,message=self:RunCPUProfileAction(entry.action);p:Message(message,ok)
            end))
        end
        p.y=diagnosticY+28
    end
    if self.RunCastCaptureAction then
        local controls={
            {key='cast_capture',text=L['Capture casts (30s)'],action='start'},
            {key='cast_stop',text=L['Stop'],action='stop'},
            {key='cast_report',text=L['Cast report'],action='report'},
            {key='cast_clear',text=L['Clear'],action='clear'},
        }
        local diagnosticY=p.y;local buttons={};local minimumWidth=120
        local statusText;local diagnosticToken=p.generation
        for i,entry in ipairs(controls) do
            local control=p:Button(entry.key,entry.text,function() end)
            buttons[i]=control
            minimumWidth=math.max(minimumWidth,control:GetFontString():GetStringWidth()+20)
            self:SetUIScript(control,'OnClick',p:Guard(function()
                local ok,message,current=self:RunCastCaptureAction(entry.action)
                if current==false or not p:Valid(diagnosticToken) then return end
                p:Message(message,ok)
                if statusText then statusText:SetText(self:GetCastCaptureStatusText()) end
            end))
        end
        local columns=p.width>=minimumWidth*4+12 and 4 or p.width>=minimumWidth*2+4 and 2 or 1
        local controlWidth=(p.width-(columns-1)*4)/columns
        for i,control in ipairs(buttons) do
            control:ClearAllPoints();control:SetPoint('TOPLEFT',((i-1)%columns)*(controlWidth+4),-diagnosticY-math.floor((i-1)/columns)*28);control:SetWidth(controlWidth)
        end
        p.y=diagnosticY+math.ceil(#buttons/columns)*28
        if self.GetCastCaptureStatusText then statusText=p:Text(self:GetCastCaptureStatusText()) end
    end
    if self.Glow and store.global.effects and store.global.effects[profile.effect] then self:Glow(preview,'settings-preview',store.global.effects[profile.effect],profile.color or {r=1,g=1,b=1,a=1},profile.magnification or 1,profile.setpoint or 'CENTER',profile.xoffs or 0,profile.yoffs or 0) end
    p:EndColumns()
    p.cleanups[#p.cleanups+1]=function() if self.HideGlow then self:HideGlow(preview,'settings-preview') end end
end
