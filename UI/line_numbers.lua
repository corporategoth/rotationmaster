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
    if not control.lineNumberCounts then control.lineNumberCounts={calls=0,skips=0,renders=0,metrics=0,reentries=0,errors=0,detached=0,flushes=0} end
    return control.lineNumberCounts
end

local function metricInput(control,input,options,source)
    local edit=input.editBox;local width=edit:GetWidth();local font,size,flags=edit:GetFont();local spacing=edit:GetSpacing() or 0
    local left,right,top,bottom=edit:GetTextInsets();left,right,top,bottom=left or 0,right or 0,top or 0,bottom or 0
    local metrics={source=source,width=math.max(1,width-left-right),font=font,size=size,flags=flags,spacing=spacing,
        literalPipes=not options.native or control.syntax~=nil,scale=edit:GetEffectiveScale()}
    return metrics,width,left,right,top,bottom
end
local function results(...) return {n=select('#',...),...} end

-- Reuse LuaWorkbench's gutter, callbacks and visible-row renderer. Source-line
-- heights must use the native font's measured glyph metrics, including the
-- trailing spacing between logical lines and any rows introduced by wrapping.
function addon:InstallLuaLineNumberControl(control,console,input,options)
    options=options or {};local update=console.UpdateLineNumbers;control.lineNumberInput=input
    local function render(self,state,counts)
        if state then
            local edit=input.editBox;local source=self.source or ''
            local metrics,width,left,right,top,bottom=metricInput(control,input,options,source)
            local font,size,flags,spacing=metrics.font,metrics.size,metrics.flags,metrics.spacing
            local scale,textWidth,literalPipes=metrics.scale,metrics.width,metrics.literalPipes
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
    function control:ResetLineNumberQueue()
        local queue=self.lineNumberQueue
        if queue then queue.pending=false;queue.paintRetry=nil;queue.navigation=nil end
        self.lineNumberQueue=nil
    end
    local function bindQueue()
        control:ResetLineNumberQueue()
        local queue={edit=input.editBox,pending=false}
        queue.update=function()
            local counts=counters(control);counts.calls=counts.calls+1
            local state=input.queryLineNumbers
            if control.lineNumberQueue~=queue or control.released or console.input~=input or input.editBox~=queue.edit or not state then counts.detached=counts.detached+1;return end
            queue.state=state;queue.pending=true
            if queue.rendering then counts.reentries=counts.reentries+1 end
        end
        control.lineNumberQueue=queue;console.UpdateLineNumbers=queue.update
    end
    local retryPaint
    local editor=not options.native and control.engine and control.engine.Query.Editor
    if editor then
        local paint=editor.Paint
        retryPaint=function() return paint(editor,input) end
        function editor:Paint(target,...)
            if self~=editor or target~=input then return paint(self,target,...) end
            local queue=control.lineNumberQueue;local state=input.queryEditor
            if queue then queue.paintRetry=nil end
            -- Paint itself refuses a gutter with missing/stale viewport rows.
            -- Remember only that actual blocked attempt, not arbitrary pending
            -- color work, so the provider's existing repaint clock stays owned.
            local blocked=queue and state and input.queryLineNumbers and not self:VisibleRange(input,input.editBox:GetText())
            local values=results(paint(self,target,...))
            if blocked and control.lineNumberQueue==queue and not control.released and input.queryEditor==state and state.pending then queue.paintRetry=state end
            return unpack(values,1,values.n)
        end
    end
    local navigation=editor and control.engine.Navigation
    if navigation then
        local position,scrollTo=navigation.Position,navigation.ScrollTo
        local positioning
        function navigation:ScrollTo(target,...)
            if self==navigation and target==input and positioning then return end
            return scrollTo(self,target,...)
        end
        function navigation:Position(target,cursor,...)
            local queue=control.lineNumberQueue;local state=input.queryLineNumbers
            if self~=navigation or target~=input or not queue or not state then return position(self,target,cursor,...) end
            queue.navigation=nil
            if sameRender(state.rmMetrics,metricInput(control,input,options,console.source or '')) then return position(self,target,cursor,...) end
            -- Preserve Position's immediate focus/cursor/selection operations;
            -- only its stale-row scroll waits for this attachment's geometry.
            local request={source=console.source,cursor=cursor};local previous=positioning;positioning=request
            local values=results(pcall(position,self,target,cursor,...));positioning=previous
            if not values[1] then error(values[2],0) end
            if control.lineNumberQueue==queue and input.queryLineNumbers==state and console.source==request.source and input.editBox:GetCursorPosition()==cursor then queue.navigation=request end
            return unpack(values,2,values.n)
        end
    end
    local function flush(queue,counts)
        render(console,queue.state,counts)
        local request=queue.navigation;queue.navigation=nil
        if request and control.lineNumberQueue==queue and console.source==request.source and input.editBox:GetText()==request.source and input.editBox:GetCursorPosition()==request.cursor then
            local line=console:GetLinePosition(request.source,request.cursor);local entry=queue.state.positions[line]
            if entry then navigation:ScrollTo(input,entry.offset-40) end
        end
        local retry=queue.paintRetry;queue.paintRetry=nil
        if retry and control.lineNumberQueue==queue and input.queryEditor==retry and input.queryLineNumbers==queue.state and editor:VisibleRange(input,input.editBox:GetText()) then
            -- Retry the captured renderer once without re-entering this adapter.
            retryPaint()
            queue.paintRetry=nil
        end
    end
    -- Native cursor/scroll callbacks only request work. Read the EditBox and
    -- paint its gutter after the provider's existing frame update has returned.
    control.frame:HookScript('OnUpdate',function()
        local queue=control.lineNumberQueue
        if not queue or not queue.pending or queue.rendering then return end
        if control.released or console.UpdateLineNumbers~=queue.update or console.input~=input or input.queryLineNumbers~=queue.state or input.editBox~=queue.edit or type(control.valid)~='function' then control:ResetLineNumberQueue();return end
        local ok,valid=pcall(control.valid)
        if not ok or not valid then control:ResetLineNumberQueue();return end
        if control.frame.IsVisible then
            if not control.frame:IsVisible() then return end
        elseif not control.frame:IsShown() then return end
        queue.pending=false;queue.rendering=true
        local counts=counters(control);counts.flushes=counts.flushes+1
        local success,result=pcall(flush,queue,counts);queue.rendering=nil
        if not success then queue.pending=false;queue.paintRetry=nil;queue.navigation=nil end
        if not success then counts.errors=counts.errors+1;error(result,0) end
    end)
    local acquire=control.Acquire
    if acquire then
        function control:Acquire(...)
            self:ResetLineNumberQueue()
            local values=results(acquire(self,...))
            -- Native hosts may acquire a newly constructed or already active
            -- control. Refresh can keep its existing attachment in that case.
            if not self.released and input.queryLineNumbers then bindQueue();console:UpdateLineNumbers() end
            return unpack(values,1,values.n)
        end
    end
    local release=control.Release
    if release then function control:Release(...) self:ResetLineNumberQueue();return release(self,...) end end
    bindQueue()
    function control:SetLineNumbers(visible)
        visible=visible~=false
        if self.lineNumbersVisible==visible then return end
        self:ResetLineNumberQueue()
        self.lineNumbersVisible=visible
        local previous=input.queryLineNumbers or input.queryLineNumberCache
        if previous then previous.rmRender=nil end
        if visible then
            bindQueue()
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
