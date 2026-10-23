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
    local enableY=p.y
    p:Check('enable',L['Enable'],profile.enable,function(v) profile.enable=v;p:RunSettingsEffect('enable',function() if v then self:enable() else self:disable() end end) end)
    p:Check('disable_buttons',L['Disable Bar Highlighting'],profile.disable_buttons,function(v) profile.disable_buttons=v;p:RunSettingsEffect('buttons',function() if v then self:GlowClear() end end) end)
    p:Check('minimap',L['Minimap Icon'],not (profile.minimap or {}).hide,function(v)
        profile.minimap=profile.minimap or {};profile.minimap.hide=not v;p:RunSettingsEffect('minimap',function() local lib=LibStub('LibDBIcon-1.0');if v then lib:Show(self.name) else lib:Hide(self.name) end end)
    end)
    -- Enable, Disable Bar Highlighting and Minimap Icon share one row in thirds.
    self:LayoutWorkbenchRow({p.fields.enable,p.fields.disable_buttons,p.fields.minimap},0,enableY,p.width,{text=22});p.y=enableY+30
    p:Slider('poll',L['Polling Interval (seconds)'],profile.poll,.05,1,.05,function(v) profile.poll=v;p:RunSettingsEffect('poll',function() if self.rotationTimer then self:DisableRotationTimer();self:EnableRotationTimer() end end) end)
    p:Slider('idle_poll',L['Idle Re-check Interval (seconds)'],profile.idle_poll or 1,0,5,.25,function(v) profile.idle_poll=v end)
    p:Slider('autoswitch_poll',L['Auto-Switch Re-check Interval (seconds)'],profile.autoswitch_poll or 1,0,10,.25,function(v) profile.autoswitch_poll=v;profile.disable_autoswitch=nil;p:RunSettingsEffect('autoswitch_poll',function() self:StartAutoSwitchTimer() end) end)
    p:Slider('live_config_update',L['Live Status Update Frequency (seconds)'],profile.live_config_update,0,60,1,function(v)
        if profile.live_config_update==v then return end;profile.live_config_update=v
        p:RunSettingsEffect('conditionTimer',function()
        if self.conditionEvalTimer then self:CancelTimer(self.conditionEvalTimer);self.conditionEvalTimer=nil end
        if v>0 then self.conditionEvalTimer=self:ScheduleRepeatingTimer('UpdateCurrentCondition',v) end
        end)
    end)
    p:Choice('rotation_view',L['Default rotation view'],profile.rotation_view or 'diagram',{{value='diagram',text=L['Diagram view']},{value='list',text=L['List view']}},function(v) profile.rotation_view=v end)
    p:Heading(L['History'])
    for _,entry in ipairs({{'spell_history','Spell History Memory (seconds)'},{'combat_history','Combat History Memory (seconds)'},{'damage_history','Damage History Memory (seconds)'}}) do
        local key=entry[1];p:Slider(key,L[entry[2]],profile[key],0,300,1,function(v) profile[key]=v end)
    end
    p:Heading(L['Preview'])
    local function previewChanged()
        p:RunSettingsEffect('preview',function() if self.RefreshPreviewWindow then self:RefreshPreviewWindow() elseif (profile.preview_spells or 0)>0 then if self.nextWindow then self.nextWindow:SetWidth(profile.preview_spells*128) else self:CreatePreviewWindow() end elseif self.nextWindow then self.nextWindow:Release();self.nextWindow=nil end end)
    end
    p:Slider('preview_spells',L['Preview Spells'],profile.preview_spells,0,5,1,function(v) profile.preview_spells=v;previewChanged() end)
    p:Slider('preview_opacity',L['Preview window opacity'],profile.preview_opacity or 1,0,1,.05,function(v) profile.preview_opacity=v;previewChanged() end)
    local previewY=p.y;local third=p.width/3
    local locked=p:Check('preview_locked',L['Lock position and size'],self.db.profile.preview_locked==true,function() end)
    -- Locking is an immediate window action, like moving or resetting it.
    -- Synchronize only this field so unrelated General edits remain pending.
    self:SetUIScript(locked,'OnClick',p:Guard(function()
        local value=self.db.profile.preview_locked~=true
        for _,settings in ipairs({self.db.profile,profile,p.draftBaseline and p.draftBaseline.profile or {}}) do settings.preview_locked=value end
        locked:SetChecked(value)
        if p.BindUnsaved then p:BindUnsaved('preview_locked',locked,value,'Check') end
        if self.RefreshPreviewWindow then self:RefreshPreviewWindow() end
    end))
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
    -- Masque owns this immediate appearance preference. Keep it outside the
    -- General draft so Discard never rewinds another addon's skin settings.
    local skinY=p:Row(L['Skin'],28)
    local skin=p:Acquire('previewSkins',function() return self:CreateWorkbenchLabeledIconButton(p.child,'chevron-down','',220) end)
    p.fields.preview_skin=skin
    local skinToken=p.generation
    local function currentSkinPage() return p:Valid(skinToken) end
    local function skinChoices()
        if not currentSkinPage() then return end
        if self.db.profile.preview_masque==true and self.GetPreviewSkinChoices then
            local choices,available=self:GetPreviewSkinChoices()
            if not currentSkinPage() then return end
            if available then return choices,true end
        end
        return {{value='Blizzard Classic',text=L['Blizzard Classic']}},false
    end
    local function paintSkin()
        local choices,available=skinChoices()
        if not currentSkinPage() or not choices then return end
        local value=available and self.GetPreviewSkin and self:GetPreviewSkin() or 'Blizzard Classic'
        if not currentSkinPage() then return end
        local selected
        for _,entry in ipairs(choices) do if entry.value==value then selected=entry;break end end
        self:PaintSelectorSelection(skin,selected,selected and selected.text or L['Blizzard Classic'])
        if available then skin:Enable() else skin:Disable() end
        return choices
    end
    if not paintSkin() then return end
    local skinChanged=p:Guard(function() paintSkin() end)
    self.previewSkinChanged=skinChanged
    p.cleanups[#p.cleanups+1]=function() if self.previewSkinChanged==skinChanged then self.previewSkinChanged=nil end end
    self:SetUIScript(skin,'OnClick',p:Guard(function()
        local choices=paintSkin()
        if not choices or not currentSkinPage() or not skin:IsEnabled() then return end
        p:ShowChoices(skin,choices,function(value)
            local ok=self.SetPreviewSkin and self:SetPreviewSkin(value)
            if paintSkin() and currentSkinPage() then p:Message(ok and '' or L['Preview skin is unavailable.'],ok) end
        end)
    end))
    local sample=p:Button('preview_sample',L['Preview'],function() end)
    local buttonWidth=math.min((p.width-8)/3,math.max(96,sample:GetFontString():GetStringWidth()+24))
    local skinX=math.min(220,math.max(72,p.width*.25))
    skin:ClearAllPoints();skin:SetPoint('TOPLEFT',skinX,-skinY);skin:SetWidth(math.max(1,p.width-skinX-buttonWidth-8))
    sample:ClearAllPoints();sample:SetPoint('TOPLEFT',p.width-buttonWidth,-skinY);sample:SetWidth(buttonWidth)
    p.y=skinY+28
    if type(self.SetPreviewSampleEnabled)=='function' and type(self.IsPreviewSampleEnabled)=='function' then
        self:SetUIScript(sample,'OnClick',p:Guard(function() self:SetPreviewSampleEnabled(not self:IsPreviewSampleEnabled()) end))
    else sample:Disable() end
    -- This callback belongs to the long-lived preview, never to a released tab.
    local previewOwner=self.db.profile;self.preview_closed_func=function() if addon.db.profile==previewOwner then previewOwner.preview_spells=0 end end
    p:Column(2)
    p:Heading(L['Effect Options'])
    -- The preview icon has no caption: it sits left of Effect and
    -- Magnification and spans both rows, their captions beside it.
    local y=p.y
    local preview=p:Acquire('preview',function() local frame=CreateFrame('Frame',nil,p.child);frame.icon=frame:CreateTexture(nil,'ARTWORK');frame.icon:SetAllPoints(frame);return frame end)
    preview:ClearAllPoints();preview:SetPoint('TOPLEFT',4,-y-4);preview:SetSize(48,48);preview.icon:SetTexture('Interface\\Icons\\Spell_Nature_Lightning');p.fields.preview=preview
    local function besidePreview(build)
        local count=p.counts.labels or 0;local rowY=p.y;local control=build();local caption=p.pool.labels[count+1]
        if caption then caption:ClearAllPoints();caption:SetPoint('TOPLEFT',64,-rowY);caption:SetWidth(148) end
        return control
    end
    local function refresh()
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
        if self.HideGlow then self:HideGlow(preview,'settings-preview') end
        local effect=(store.global.effects or {})[profile.effect]
        if effect and self.Glow then self:Glow(preview,'settings-preview',effect,profile.color or {r=1,g=1,b=1,a=1},profile.magnification or 1,profile.setpoint or 'CENTER',profile.xoffs or 0,profile.yoffs or 0) end
    end
    local effectEntries={};for id,effect in pairs(store.global.effects or {}) do if type(effect)=='table' and effect.name then effectEntries[#effectEntries+1]={value=id,text=effect.name} end end;table.sort(effectEntries,function(a,b) return a.text<b.text end)
    besidePreview(function() return p:Choice('effect',L['Effect'],profile.effect,effectEntries,function(v) profile.effect=v;refresh() end) end)
    besidePreview(function() return p:Slider('magnification',L['Magnification'],profile.magnification or 1,.1,2,.1,function(v) profile.magnification=v;refresh() end) end)
    p.y=math.max(p.y,y+60)
    p:Color('color',L['Highlight Color'],profile.color,function(v) profile.color=v;refresh() end)
    local positionY=p.y
    local anchor=p:Choice('setpoint',nil,profile.setpoint or 'CENTER',entries(self.setpoints),function(v) profile.setpoint=v;profile.xoffs=0;profile.yoffs=0;refresh();p:Draw() end)
    anchor:ClearAllPoints();anchor:SetPoint('TOPLEFT',0,-positionY-22);anchor:SetWidth(204);p.y=positionY
    p:Position(profile.xoffs,profile.yoffs,function(x,y,center) profile.xoffs=x;profile.yoffs=y;if center then profile.setpoint='CENTER' end;refresh() end,true)
    if WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE and LE_EXPANSION_LEVEL_CURRENT>=2 and store.char and store.char.specs then
        p:Heading(L['Specialization Names']);for i,caption in ipairs({PRIMARY,SECONDARY}) do p:Edit('spec'..i,caption,store.char.specs[i],nil,function(v) store.char.specs[i]=v end) end
    end
    p:Heading(L['Debugging Options'])
    local logEntries={{value=4,text=self.loglevels[4]},{value=3,text=self.loglevels[3]},
        {value=2,text=self.loglevels[2]},{value=1,text=L['Silent']}}
    local logY=p.y
    local logLevel=p:Choice('loglevel',L['Log Level'],profile.loglevel or 2,logEntries,function(v) profile.loglevel=v;p:RunSettingsEffect('loglevel',function() if self.RefreshEvaluationProfilerPolicy then self:RefreshEvaluationProfilerPolicy()end end);p:Draw() end)
    local detail=p:Check('detailed_profiling',L['Detailed Profiling'],profile.detailed_profiling,function(v) profile.detailed_profiling=v end);if (profile.loglevel or 2)<3 then detail:Disable() end
    -- Detailed Profiling follows Log Level on its row, only as wide as its
    -- box and caption.
    local detailText=detail:GetFontString();detailText:SetWidth(300)
    local detailWidth=22+math.min(180,math.max(40,math.ceil(detailText:GetStringWidth() or 0)+2))
    detailText:SetWidth(detailWidth-22);detail:SetWidth(detailWidth);detail:ClearAllPoints();detail:SetPoint('TOPLEFT',math.max(0,p.width-detailWidth),-logY-3)
    logLevel:SetWidth(math.max(60,p.width-220-detailWidth-8));p.y=logY+30
    if self.GetCacheDiagnosticMode and self.SetCacheDiagnosticMode then
        local _,requested=self:GetCacheDiagnosticMode()
        local control=p:Check('cpu_cache_bypass','',requested=='cached',function() end)
        control.tooltip=L['Observation caching can reduce repeated lookups but increases table allocations. Off by default; reload to change the running mode.']
        local function updateModeCaption()
            local loaded,nextMode=self:GetCacheDiagnosticMode()
            control:SetText(loaded==nextMode and L['Enable observation cache (reload required)'] or L['Enable observation cache (pending)'])
            control:SetChecked(nextMode=='cached')
        end
        updateModeCaption()
        -- Diagnostic requests persist independently of pending settings edits.
        self:SetUIScript(control,'OnClick',p:Guard(function()
            local _,current=self:GetCacheDiagnosticMode()
            local wanted=current=='direct' and 'cached' or 'direct'
            local ok=self:SetCacheDiagnosticMode(wanted)
            updateModeCaption()
            p:Message(ok and '' or L['Cache diagnostic is unavailable.'],ok)
        end))
    end
    -- Diagnostics: one column per capture kind, its capture button above its
    -- report button. While a capture runs its button stops it (the report is
    -- kept); a report button stays disabled until that kind has a report.
    -- Labels follow live state, whoever started or ended the capture, but only
    -- while this page is shown. Each action uses live settings, never a draft.
    local captures={}
    local function call(method,...) local fn=self[method];if type(fn)~='function' then return false end;local ok,value=pcall(fn,self,...);return ok and value end
    local function stopper(kind,method) return function()
        if type(self.HandlePerformanceCommand)=='function' then return self:HandlePerformanceCommand(kind..' stop') end
        local ok=call(method);return ok,''
    end end
    local function stored(method) return function() local fn=self[method];if type(fn)~='function' then return false end;local ok,value=pcall(fn,self);return ok and type(value)=='string' end end
    if self.RunCPUProfileAction then
        captures[#captures+1]={key='cpu_capture',reportKey='cpu_report',start=L['Capture CPU (10s)'],stop=L['Stop CPU capture'],report=L['CPU report'],
            running=function() return call('IsCPUProfileRunning')==true end,hasReport=stored('GetCPUProfileReport'),
            begin=function() return self:RunCPUProfileAction('start') end,finish=stopper('cpu','StopCPUProfile'),open=function() return self:RunCPUProfileAction('report') end}
        if type(self.StartCPURuntimeCapture)=='function' then
            captures[#captures+1]={key='cpu_runtime_capture',reportKey='cpu_runtime_report',start=L['Capture runtime (10s)'],stop=L['Stop runtime capture'],report=L['Runtime report'],
                running=function() return call('IsCPURuntimeCaptureRunning')==true end,hasReport=stored('GetCPURuntimeCaptureReport'),
                begin=function() return self:RunCPUProfileAction('runtime') end,finish=stopper('runtime','StopCPURuntimeCapture'),open=function() return self:RunCPUProfileAction('runtimereport') end}
        end
        if type(self.StartMemoryCapture)=='function' then
            captures[#captures+1]={key='memory_capture',reportKey='memory_report',start=L['Capture memory (10m)'],stop=L['Stop memory capture'],report=L['Memory report'],
                running=function() return call('IsMemoryCaptureRunning')==true end,hasReport=stored('GetMemoryCaptureReport'),
                begin=function() return self:RunCPUProfileAction('memory') end,finish=stopper('memory','CompleteMemoryCapture'),open=function() return self:RunCPUProfileAction('memoryreport') end}
        end
    end
    if self.RunCastCaptureAction then
        -- The cast report copies its snapshot, so it is checked only when the
        -- running state changes (and now and then as a safety net).
        captures[#captures+1]={key='cast_capture',reportKey='cast_report',start=L['Capture casts (30s)'],stop=L['Stop cast capture'],report=L['Cast report'],costly=true,
            running=function() return type(self.GetCastCaptureState)=='function' and self:GetCastCaptureState()==true end,
            hasReport=function() if type(self.GetCastCaptureState)~='function' then return true end;local _,available=self:GetCastCaptureState(true);return available==true end,
            begin=function() return self:RunCastCaptureAction('start') end,finish=function() return self:RunCastCaptureAction('stop') end,open=function() return self:RunCastCaptureAction('report') end}
    end
    if #captures>0 then
        local token=p.generation;local minimumWidth=120;local diagnosticY=p.y
        local function paint(entry,force)
            local running=entry.running()
            local has=entry.has
            if not running and (force or not entry.costly or running~=entry.wasRunning or (entry.age or 0)>=2) then has=entry.hasReport()==true;entry.age=0 end
            if running then has=false end
            entry.wasRunning=running;entry.has=has
            entry.button:SetText(running and entry.stop or entry.start)
            if has then entry.reportButton:Enable() else entry.reportButton:Disable() end
        end
        local function repaint(force) if p:Valid(token) then for _,entry in ipairs(captures) do paint(entry,force) end end end
        for _,entry in ipairs(captures) do
            local button=p:Button(entry.key,entry.start,function() end);local reportButton=p:Button(entry.reportKey,entry.report,function() end)
            entry.button,entry.reportButton=button,reportButton
            for _,text in ipairs({entry.start,entry.stop}) do button:SetText(text);minimumWidth=math.max(minimumWidth,button:GetFontString():GetStringWidth()+20) end
            self:SetUIScript(button,'OnClick',p:Guard(function()
                local action=entry.running() and entry.finish or entry.begin
                local ok,message,current=action()
                if current==false or not p:Valid(token) then return end
                if message and message~='' then p:Message(message,ok) end;repaint(true)
            end))
            self:SetUIScript(reportButton,'OnClick',p:Guard(function()
                local ok,message,current=entry.open()
                if current==false or not p:Valid(token) then return end
                p:Message(message or '',ok);repaint(true)
            end))
        end
        local gap=4
        local columns=math.max(1,math.min(#captures,math.floor((p.width+gap)/(minimumWidth+gap))))
        local each=(p.width-(columns-1)*gap)/columns
        for i,entry in ipairs(captures) do
            local x=((i-1)%columns)*(each+gap);local top=diagnosticY+math.floor((i-1)/columns)*58
            entry.button:ClearAllPoints();entry.button:SetPoint('TOPLEFT',x,-top);entry.button:SetWidth(each)
            entry.reportButton:ClearAllPoints();entry.reportButton:SetPoint('TOPLEFT',x,-top-28);entry.reportButton:SetWidth(each)
        end
        p.y=diagnosticY+math.ceil(#captures/columns)*58
        repaint(true)
        local watcher=p:Acquire('captureWatcher',function() return CreateFrame('Frame',nil,p.child) end);local elapsed=0
        self:SetUIScript(watcher,'OnUpdate',function(frame,delta)
            if not p:Valid(token) then self:SetUIScript(frame,'OnUpdate',nil);return end
            elapsed=elapsed+(delta or 0);if elapsed<.25 then return end
            for _,entry in ipairs(captures) do entry.age=(entry.age or 0)+elapsed end;elapsed=0;repaint(false)
        end)
    end
    if self.Glow and store.global.effects and store.global.effects[profile.effect] then self:Glow(preview,'settings-preview',store.global.effects[profile.effect],profile.color or {r=1,g=1,b=1,a=1},profile.magnification or 1,profile.setpoint or 'CENTER',profile.xoffs or 0,profile.yoffs or 0) end
    p:EndColumns()
    p.cleanups[#p.cleanups+1]=function() if self.HideGlow then self:HideGlow(preview,'settings-preview') end end
end
