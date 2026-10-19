local _,addon=...
-- Reuse LuaWorkbench's gutter, callbacks and visible-row renderer. Source-line
-- heights must use the native font's measured glyph metrics, including the
-- trailing spacing between logical lines and any rows introduced by wrapping.
function addon:InstallLuaLineNumberControl(control,console,input,options)
    options=options or {};local update=console.UpdateLineNumbers
    function console:UpdateLineNumbers()
        local state=input.queryLineNumbers
        if state then
            local edit=input.editBox;local source=self.source or ''
            local width=edit:GetWidth();local font,size,flags=edit:GetFont();local spacing=edit:GetSpacing() or 0
            local left,right=edit:GetTextInsets();local textWidth=math.max(1,width-(left or 0)-(right or 0))
            -- LuaWorkbench's overlay and FAIAP escape source pipes before
            -- rendering; a plain EditBox retains native WoW markup behavior.
            local literalPipes=not options.native or control.syntax~=nil
            local cache=state.rmMetrics
            if not cache or cache.source~=source or cache.width~=textWidth or cache.font~=font or cache.size~=size or cache.flags~=flags or cache.spacing~=spacing or cache.literalPipes~=literalPipes then
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
                state.rmMetrics={source=source,width=textWidth,font=font,size=size,flags=flags,spacing=spacing,literalPipes=literalPipes}
            end
            -- Tell the upstream renderer its layout is current so it does not
            -- replace these exact metrics with its nominal font-size estimate.
            state.source,state.width,state.font,state.size,state.flags,state.spacing=source,width,font,size,flags,spacing
        end
        return update(self)
    end
    function control:SetLineNumbers(visible)
        visible=visible~=false
        if self.lineNumbersVisible==visible then return end
        self.lineNumbersVisible=visible
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
