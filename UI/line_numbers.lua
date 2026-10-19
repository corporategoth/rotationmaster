local _,addon=...
local function near(left,right) return math.abs(left-right)<=.1 end
local geometry={width=true,textWidth=true,left=true,right=true,top=true,bottom=true,scroll=true,viewport=true,viewportWidth=true,gutterWidth=true}
local function sameRender(before,after)
    if not before then return false,'initial' end
    local changed={}
    for key,value in pairs(after) do
        local old=before[key]
        if geometry[key] and type(old)=='number' and type(value)=='number' then
            if not near(old,value) then changed[#changed+1]=key end
        elseif old~=value then changed[#changed+1]=key end
    end
    for key in pairs(before) do if after[key]==nil then changed[#changed+1]=key end end
    table.sort(changed)
    return #changed==0,table.concat(changed,',')
end
local function counters(control)
    if not control.lineNumberCounts then control.lineNumberCounts={calls=0,skips=0,renders=0,metrics=0,reentries=0,errors=0,detached=0} end
    return control.lineNumberCounts
end

-- Reuse LuaWorkbench's gutter, callbacks and visible-row renderer. Source-line
-- heights must use the native font's measured glyph metrics, including the
-- trailing spacing between logical lines and any rows introduced by wrapping.
function addon:InstallLuaLineNumberControl(control,console,input,options)
    options=options or {};local update=console.UpdateLineNumbers;control.lineNumberInput=input
    local function render(self,state,counts)
        if state then
            local edit=input.editBox;local source=self.source or ''
            local width=edit:GetWidth();local font,size,flags=edit:GetFont();local spacing=edit:GetSpacing() or 0
            local left,right,top,bottom=edit:GetTextInsets();left,right,top,bottom=left or 0,right or 0,top or 0,bottom or 0
            local scale=edit:GetEffectiveScale();local textWidth=math.max(1,width-(left or 0)-(right or 0))
            -- LuaWorkbench's overlay and FAIAP escape source pipes before
            -- rendering; a plain EditBox retains native WoW markup behavior.
            local literalPipes=not options.native or control.syntax~=nil
            local metrics={source=source,width=textWidth,font=font,size=size,flags=flags,spacing=spacing,literalPipes=literalPipes,scale=scale}
            local unchanged,metricKeys=sameRender(state.rmMetrics,metrics)
            if not unchanged then
                counts.metrics=counts.metrics+1;counts.lastMetric=metricKeys
                local measure=state.measure;measure:SetFont(font,size,flags);measure:SetSpacing(spacing);measure:SetWidth(textWidth);measure:SetHeight(0)
                local positions,heights,offset,start={}, {},0,1
                for text in (source..'\n'):gmatch('(.-)\n') do
                    local height=heights[text]
                    if not height then
                        local displayed=text~='' and text or 'M';if literalPipes then displayed=displayed:gsub('|','||') end
                        measure:SetText(displayed);height=measure:GetStringHeight();if height<=0 then height=size end;height=height+spacing;heights[text]=height end
                    positions[#positions+1]={offset=offset,height=height,sourceStart=start,sourceEnd=start+#text}
                    offset=offset+height;start=start+#text+1
                end
                state.positions,state.lineHeights=positions,heights
                state.rmMetrics=metrics
            end
            -- Tell the upstream renderer its layout is current so it does not
            -- replace these exact metrics with its nominal font-size estimate.
            state.source,state.width,state.font,state.size,state.flags,state.spacing=source,width,font,size,flags,spacing
            local engine=control.engine or control.completionEngine
            local workspace=engine and engine.Workspace;local debugger=engine and engine.Debugger;local debugUI=engine and engine.DebugUI
            local record=debugUI and debugUI.CurrentSource and debugUI:CurrentSource()
            local registered=debugger and debugger.armed and debugger.sources and workspace and debugger.sources[workspace.current]
            local scroll=input.scrollFrame
            local view={source=source,metrics=state.rmMetrics,width=width,textWidth=textWidth,font=font,size=size,flags=flags,spacing=spacing,
                left=left,right=right,top=top,bottom=bottom,scale=scale,scroll=scroll:GetVerticalScroll(),viewport=scroll:GetHeight(),viewportWidth=scroll:GetWidth(),gutterWidth=state.gutter:GetWidth(),
                current=self:GetLinePosition(source,edit:GetCursorPosition()),error=self.lastError and self.lastError.line,
                workspace=workspace,db=workspace and workspace.db,script=workspace and workspace.current,debugger=debugger,
                breakpointRevision=debugger and debugger.breakpointRevision,armed=debugger and debugger.armed==true,paused=debugger and debugger.paused==true,debugLine=debugger and debugger.line,
                debugUI=debugUI,pausedLine=debugUI and debugUI.pausedLine,recordId=record and record.id,recordSource=record and record.source,registered=registered,registeredSource=registered and registered.source}
            -- Match UpdateGutter's pause-marker and registered-draft inputs.
            -- CurrentSource may synthesize a new fallback record each call;
            -- only its consumed id/source fields affect the rendered markers.
            local settled,renderKeys=sameRender(state.rmRender,view)
            if settled then counts.skips=counts.skips+1;return end
            counts.renders=counts.renders+1;counts.lastRender=renderKeys
            local result=update(self)
            -- Upstream treats false as a present position when hiding this
            -- texture; clear its highlight when this editor has no pause row.
            local pausedPosition=view.paused and view.recordId==view.script and view.recordSource==source and state.positions[view.debugLine]
            if debugUI and debugUI.pausedLine and not pausedPosition then debugUI.pausedLine:Hide() end
            -- The native renderer can load/remap persisted breakpoints.
            view.breakpointRevision=debugger and debugger.breakpointRevision
            state.rmRender=view;return result
        end
    end
    function console:UpdateLineNumbers()
        local counts=counters(control);counts.calls=counts.calls+1
        local state=input.queryLineNumbers
        if not state then counts.detached=counts.detached+1;return update(self) end
        if state.rmRendering then counts.reentries=counts.reentries+1;return end
        state.rmRendering=true
        local ok,result=pcall(render,self,state,counts);state.rmRendering=nil
        if not ok then counts.errors=counts.errors+1;error(result,0) end
        return result
    end
    local function probeOwner(self,probe)
        if self.released or self.edit~=probe.edit or input.editBox~=probe.edit or input.queryLineNumbers~=probe.state or type(self.valid)~='function' then return false end
        local ok,valid=pcall(self.valid);return ok and not not valid
    end
    function control:ResetDeferredGutterProbe()
        local probe=self.deferredGutterProbe;self.deferredGutterProbe=nil;self.gutterProbeRefresh=nil
        if probe then
            probe.pending=false
            if console.UpdateLineNumbers==probe.queue then console.UpdateLineNumbers=probe.update end
        end
        if self.LayoutInputDiagnostics then self:LayoutInputDiagnostics() end
    end
    function control:ToggleDeferredGutterProbe()
        local probe=self.deferredGutterProbe
        if probe then
            local pending=probe.pending;self:ResetDeferredGutterProbe()
            if pending and probeOwner(self,probe) and console.UpdateLineNumbers==probe.update then self.gutterProbeRefresh=probe end
            return false
        end
        probe={edit=input.editBox,state=input.queryLineNumbers,update=console.UpdateLineNumbers,pending=false}
        if not probe.state or not probeOwner(self,probe) then return nil end
        self.gutterProbeRefresh=nil;self.gutterProbeCounts=self.gutterProbeCounts or {requests=0,flushes=0}
        local counts=self.gutterProbeCounts
        probe.queue=function()
            if self.deferredGutterProbe~=probe or not probeOwner(self,probe) then return end
            counts.requests=counts.requests+1;probe.pending=true
        end
        self.deferredGutterProbe=probe;console.UpdateLineNumbers=probe.queue
        if self.LayoutInputDiagnostics then self:LayoutInputDiagnostics() end
        return true
    end
    -- The temporary probe moves every gutter request out of cursor/scroll
    -- callbacks. Keep the provider's own update handler and normal input intact.
    control.frame:HookScript('OnUpdate',function()
        local probe=control.deferredGutterProbe
        if probe then
            if not probeOwner(control,probe) or console.UpdateLineNumbers~=probe.queue then control:ResetDeferredGutterProbe();return end
            if probe.pending then
                probe.pending=false;control.gutterProbeCounts.flushes=control.gutterProbeCounts.flushes+1
                probe.update(console)
            end
        elseif control.gutterProbeRefresh then
            probe=control.gutterProbeRefresh;control.gutterProbeRefresh=nil
            if probeOwner(control,probe) and console.UpdateLineNumbers==probe.update then probe.update(console) end
        end
    end)
    for _,name in ipairs({'Release','Acquire'}) do
        local original=control[name]
        if original then control[name]=function(self,...) self:ResetDeferredGutterProbe();return original(self,...) end end
    end
    function control:SetLineNumbers(visible)
        visible=visible~=false
        if self.lineNumbersVisible==visible then return end
        if not visible then self:ResetDeferredGutterProbe() end
        self.lineNumbersVisible=visible
        local previous=input.queryLineNumbers or input.queryLineNumberCache
        if previous then previous.rmRender=nil end
        if visible then
            console:AttachLineNumbers(input)
            if options.native then
                local gutter=input.queryLineNumbers.gutter;gutter:ClearAllPoints();gutter:SetPoint('TOPLEFT',self.frame,'TOPLEFT',4,-8);gutter:SetPoint('BOTTOMLEFT',self.frame,'BOTTOMLEFT',4,4)
            end
        else console:DetachLineNumbers() end
        if options.native and not self.layingOut then self:Layout() end
    end
    function control:RefreshLineNumbers()
        if self.released then return end
        local wanted=addon.db.profile.lua_line_numbers~=false
        if self.lineNumberSetting~=wanted then self.lineNumberSetting=wanted;self:SetLineNumbers(wanted) end
        console.source=self:GetText();if self.lineNumbersVisible then console:UpdateLineNumbers() end
    end
    function control:ReleaseLineNumbers() self:SetLineNumbers(false);self.lineNumberSetting=nil end
end
function addon:InstallNativeLuaLineNumbers(control)
    local engine=control.completionEngine
    if not engine then return end
    local console=engine.Query.Console;local input=console.input;input.scrollBG=control.frame
    function console:UpdateEditorLabel() end
    -- The reduced editor has no debugger; its gutter is for line navigation,
    -- not clickable breakpoint buttons that cannot be executed here.
    function engine.DebugUI:UpdateGutter() end
    self:InstallLuaLineNumberControl(control,console,input,{native=true})
    control:RefreshLineNumbers()
end
