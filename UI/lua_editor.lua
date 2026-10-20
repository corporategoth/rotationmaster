local addon_name,addon=...
local providers={}
-- Saved switches also cover registered extensions; unknown identifiers remain inert.
local function editorDisabled(self,name)
    local profile=self.db and self.db.profile
    local disabled=profile and profile.lua_editor_disabled
    return name~='auto' and name~='plain' and type(disabled)=='table' and disabled[name]==true
end
local function resolveEditor(self,preferred)
    local function available(name)
        return name~='LuaWorkbench' or type(self.IsLuaWorkbenchIntegrationAvailable)=='function' and self:IsLuaWorkbenchIntegrationAvailable()==true
    end
    if preferred=='auto' then
        local names={};for name in pairs(providers) do if not editorDisabled(self,name) and available(name) then names[#names+1]=name end end
        table.sort(names);preferred=names[1] or 'native'
    end
    if editorDisabled(self,preferred) or not available(preferred) then preferred='native' end
    local profile=self.db and self.db.profile
    if preferred=='native' and (editorDisabled(self,'native') or profile and profile.lua_native_highlighting==false) then return 'plain' end
    return preferred
end
function addon:ListLuaEditorProviders()
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local entries={{value='auto',text=L['Automatic']},{value='native',text=L['Built In syntax highlighting']},{value='plain',text=L['Plain text']}}
    local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name} end
    return entries
end
local function hideFrame(frame)
    pcall(function() if frame and type(frame.Hide)=='function' then frame:Hide() end end)
end
local function usableFrame(frame)
    local ok,result=pcall(function() return frame and type(frame.SetParent)=='function' and type(frame.SetAllPoints)=='function' and type(frame.Hide)=='function' end)
    return ok and result
end
-- Optional editor addons may register this RM-owned contract. No dependency or
-- undocumented third-party globals are required by the native fallback.
function addon:RegisterLuaEditorProvider(name,create)
    if type(name)~='string' or #name>128 or not name:find('%S') or name=='native' or name=='plain' or name=='auto' or type(create)~='function' then return false end
    providers[name]=create;return true
end
function addon:CreateWorkbenchLuaEditor(parent,changed,valid,preferred)
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    preferred=resolveEditor(self,preferred)
    if preferred and providers[preferred] then
        local function setCallbacks(cell,callback,ownerValid)
            cell.changed,cell.valid=callback,ownerValid
            -- Preserve optional nil/false constructor arguments exactly.
            cell.change=type(callback)=='function' and cell.forwardChange or callback
            cell.check=type(ownerValid)=='function' and cell.forwardCheck or ownerValid
        end
        local function callbackLease(callback,ownerValid)
            local cell={active=true}
            cell.forwardChange=function(...) if cell.active and type(cell.changed)=='function' then return cell.changed(...) end end
            cell.forwardCheck=function(...) if cell.active and type(cell.valid)=='function' then return cell.valid(...) end;return false end
            setCallbacks(cell,callback,ownerValid);return cell
        end
        local function retire(cell) cell.active=false;cell.changed=nil;cell.valid=nil end
        local function usable(control)
            return type(control)=='table' and usableFrame(control.frame) and type(control.GetText)=='function'
                and type(control.SetText)=='function' and type(control.Release)=='function'
        end
        local function release(control)
            if type(control)=='table' then if type(control.Release)=='function' then pcall(control.Release,control) end;hideFrame(control.frame) end
        end
        local lease=callbackLease(changed,valid)
        local host=CreateFrame('Frame',nil,parent)
        local factory=providers[preferred]
        local ok,control,constructor=pcall(factory,host,lease.change,lease.check)
        if ok and type(control)=='table' and usable(control) then
            local c={frame=host,provider=preferred,inner=control,edit=control.edit,lastText='',factory=factory,constructor=constructor,preferredInner=control}
            local function fallback()
                local operation=c.operation
                retire(lease);release(c.inner)
                if c.operation~=operation or c.released then return end
                lease=callbackLease(changed,valid)
                local nextControl=c.fallbackInner
                if nextControl then nextControl:Acquire(lease.change,lease.check) else nextControl=addon:CreateWorkbenchLuaEditor(host,lease.change,lease.check,'native') end
                if c.operation~=operation or c.released then if nextControl~=c.inner then release(nextControl) end;return end
                c.fallbackInner=nextControl;c.inner=nextControl;c.provider='native';c.edit=nextControl.edit
                nextControl.frame:SetAllPoints(host);nextControl:SetText(c.lastText);nextControl:SetReadOnly(c.readOnly)
                if c.closeRequested then nextControl:SetCloseHandler(c.closeRequested) end
                if c.context then nextControl:SetContext(c.context) end
            end
            ---@return string
            function c:GetText()
                local operation=self.operation;local current=self.inner
                local read,text=pcall(current.GetText,current)
                if self.operation~=operation then return self.lastText end
                if not read or type(text)~='string' then fallback();text=self.inner:GetText() end
                self.lastText=text;return text
            end
            function c:SetContext(context)
                self.context=context;local operation=self.operation;local current=self.inner
                if current.SetContext and not pcall(current.SetContext,current,context) and self.operation==operation then fallback() end
            end
            function c:SetReadOnly(value)
                self.readOnly=value==true;local operation=self.operation;local current=self.inner
                if type(current.SetReadOnly)=='function' then
                    if not pcall(current.SetReadOnly,current,self.readOnly) and self.operation==operation then fallback() end
                elseif self.readOnly then fallback() end
            end
            function c:SetLineNumbers(visible)
                local operation=self.operation;local current=self.inner
                if current.SetLineNumbers and not pcall(current.SetLineNumbers,current,visible) and self.operation==operation then fallback() end
            end
            function c:SetCloseHandler(callback) self.closeRequested=callback;if self.inner.SetCloseHandler then self.inner:SetCloseHandler(callback) end end
            function c:SetText(text)
                self.lastText=text or '';local operation=self.operation;local current=self.inner
                if not pcall(current.SetText,current,self.lastText) and self.operation==operation then fallback() end
            end
            function c:Acquire(callback,ownerValid)
                if self.closing then error('editor-release-in-progress',0) end
                changed,valid=callback,ownerValid
                local operation={};self.operation=operation
                if not self.released then
                    setCallbacks(lease,changed,valid)
                    if type(self.inner.Acquire)=='function' then self.inner:Acquire(lease.change,lease.check) end
                    return
                end
                retire(lease);lease=callbackLease(changed,valid);self.released=false
                local previous=self.preferredInner
                local canReuse=preferred=='LuaWorkbench' and self.factory==providers[preferred] and type(self.constructor)=='function'
                    and rawget(addon,'CreateLuaWorkbenchControl')==self.constructor and type(previous.Acquire)=='function' and previous.provider=='LuaWorkbench'
                    and addon:IsLuaWorkbenchIntegrationAvailable()
                local created,nextControl,nextConstructor
                if canReuse then created=pcall(previous.Acquire,previous,lease.change,lease.check);nextControl=previous;nextConstructor=self.constructor
                else created,nextControl,nextConstructor=pcall(providers[preferred],host,lease.change,lease.check) end
                if self.operation~=operation then if created and nextControl~=self.inner then release(nextControl) end;return end
                if created and type(nextControl)=='table' and usable(nextControl) then
                    self.inner=nextControl;self.preferredInner=nextControl;self.constructor=nextConstructor;self.factory=providers[preferred]
                    self.provider=preferred;self.edit=nextControl.edit
                    local attached=pcall(function() nextControl.frame:SetParent(host);nextControl.frame:SetAllPoints(host) end)
                    if not attached then fallback() end
                else
                    if created then release(nextControl) end
                    fallback()
                end
                if self.operation~=operation or self.released then return end
                self:SetText(self.lastText);if self.operation~=operation then return end
                self:SetReadOnly(self.readOnly);if self.operation~=operation then return end
                if self.context then self:SetContext(self.context) end
                if self.operation==operation and not self.released then self.inner.frame:Show() end
            end
            function c:Release()
                if self.released then return end
                self.operation={};self.released=true;self.closing=true;retire(lease)
                changed=nil;valid=nil;self.closeRequested=nil;self.context=nil
                local read,text=pcall(self.inner.GetText,self.inner);if read and type(text)=='string' then self.lastText=text end
                release(self.inner);hideFrame(self.frame);self.closing=nil
            end
            local attached=pcall(function() control.frame:SetParent(host);control.frame:SetAllPoints(host) end)
            if not attached then fallback() end
            return c
        end
        retire(lease);if ok then release(control) end;host:Hide()
    end
    preferred=resolveEditor(self,preferred=='plain' and 'plain' or 'native')
    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}
    c.scroll=self:CreateWorkbenchScrollFrame(c.frame);c.scroll:SetPoint('TOPLEFT',4,-4);c.content=CreateFrame('Frame',nil,c.scroll);c.content:EnableMouse(false);c.scroll:SetScrollChild(c.content);c.edit=CreateFrame('EditBox',nil,c.content);c.edit:SetMultiLine(true);c.edit:SetAutoFocus(false);c.edit:EnableMouse(true);c.edit:SetAltArrowKeyMode(false);c.edit:SetBlinkSpeed(.5);c.edit:SetCountInvisibleLetters(false);c.edit:SetTextColor(1,1,1);c.edit:SetJustifyH('LEFT');c.edit:SetJustifyV('TOP');c.edit:SetFontObject('GameFontHighlightSmall');c.edit:SetTextInsets(6,6,4,4);c.edit:SetMaxLetters(0);c.edit:SetHeight(1);c.edit:SetPoint('TOPLEFT',c.content,'TOPLEFT',0,0)
    -- Let the native EditBox own mouse placement and keyboard navigation.
    -- Focusing it from the covering scroll frame resets placement to the end.
    c.scroll:EnableMouse(false);c.frame:EnableMouseWheel(true)
    -- Only the backing frame fills the viewport. A bottom anchor on the
    -- multiline input would constrain its native text height and caret layout.
    -- Blank-space clicks can focus short/empty text without replacing native
    -- mouse placement or moving an existing insertion point to the end.
    c.content:EnableMouse(true)
    addon:SetUIScript(c.content,'OnMouseDown',function(_,button)
        if button=='LeftButton' and not c.readOnly and not c.released and c.valid() then c.edit:SetFocus()
        elseif button=='RightButton' then local handler=c.edit:GetScript('OnMouseDown');if handler then handler(c.edit,button) end end
    end)
    addon:SetUIScript(c.frame,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end)
    c.editorDecoration=self:CreateRoundedCardDecoration(c.frame);c.editorDecoration:SetColors(.38,.43,.48,1,.95)
    addon:SetUIScript(c.edit,'OnEditFocusGained',function() c.editorDecoration:SetColors(.45,.7,.85,1,.95) end)
    addon:SetUIScript(c.edit,'OnEditFocusLost',function() c.editorDecoration:SetColors(.38,.43,.48,1,.95) end)
    c.measure=c.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');c.measure:SetJustifyH('LEFT');c.measure:SetJustifyV('TOP');c.measure:SetWordWrap(true);c.measure:Hide()
    if c.edit.SetFont then c.edit:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    if c.measure.SetFont then c.measure:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    function c:Layout(origin)
        if self.layingOut then return end;self.layingOut=true
        self.layoutCounts=self.layoutCounts or {calls=0,width=0,content=0};self.layoutCounts.calls=self.layoutCounts.calls+1
        if origin~='set-text' and origin~='text-changed' and origin~='owner-size' and origin~='line-number-setting' then origin='direct' end
        local counts=self.layoutCounts;counts.origins=counts.origins or {};counts.origins[origin]=(counts.origins[origin] or 0)+1
        if origin=='owner-size' then counts.ownerWidth,counts.ownerHeight=self.frame:GetWidth(),self.frame:GetHeight() end
        -- Native coordinates round through effective UI scale. Rewriting an
        -- almost-identical size reflows EditBox text and can reset its caret.
        local function differs(current,wanted) return math.abs(current-wanted)>.1 end
        -- Keep incoming event counts while coalescing unchanged text geometry.
        -- Cursor and scrolling callbacks continue to own visible gutter updates.
        local frameWidth,frameHeight=self.frame:GetWidth(),self.frame:GetHeight()
        local scale,source=self.frame:GetEffectiveScale(),self:GetText()
        local font,size,flags,measureFont,measureSize,measureFlags
        if self.edit.GetFont then font,size,flags=self.edit:GetFont() end
        if self.measure.GetFont then measureFont,measureSize,measureFlags=self.measure:GetFont() end
        local spacing=self.edit.GetSpacing and self.edit:GetSpacing()
        local measureSpacing=self.measure.GetSpacing and self.measure:GetSpacing()
        local wanted=addon.db.profile.lua_line_numbers~=false
        local last=self.layoutInput
        if last and not differs(last.width,frameWidth) and not differs(last.height,frameHeight) and last.scale==scale and last.source==source
            and last.wanted==wanted and last.setting==self.lineNumberSetting and last.visible==self.lineNumbersVisible
            and last.font==font and last.size==size and last.flags==flags and last.spacing==spacing
            and last.measureFont==measureFont and last.measureSize==measureSize and last.measureFlags==measureFlags and last.measureSpacing==measureSpacing then
            counts.skips=(counts.skips or 0)+1;self.layingOut=nil;return
        end
        -- The shared track sits beyond the viewport. Reserve its space here,
        -- keeping both the text and the track within the editor card.
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        local gutter=self.lineNumbersVisible and 56 or 0
        if self.lineNumberLayoutGutter~=gutter then self.lineNumberLayoutGutter=gutter;self.scroll:SetPoint('TOPLEFT',4+gutter,-4) end
        local scrollWidth=math.max(1,frameWidth-32-gutter);local width=scrollWidth;local height=math.max(1,frameHeight-8)
        if differs(self.scroll:GetWidth(),scrollWidth) or differs(self.scroll:GetHeight(),height) then self.scroll:SetSize(scrollWidth,height) end
        if differs(self.edit:GetWidth(),width) then self.layoutCounts.width=self.layoutCounts.width+1;self.edit:SetWidth(width) end
        -- Hover hit geometry gives this font a fixed height. Let it measure
        -- the complete new source before sizing the backing scroll child.
        self.measure:SetHeight(0);self.measure:SetWidth(math.max(1,width-12));self.measure:SetText(source);local editHeight=math.max(height,self.measure:GetStringHeight()+16)
        -- Multiline EditBoxes own their text height. Size a backing frame
        -- without a bottom anchor on the edit, preserving native text layout.
        if differs(self.content:GetWidth(),width) or differs(self.content:GetHeight(),editHeight) then self.layoutCounts.content=self.layoutCounts.content+1;self.content:SetSize(width,editHeight) end
        self.scroll:UpdateWorkbenchScroll();if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        self.layoutInput={width=frameWidth,height=frameHeight,scale=scale,source=source,wanted=wanted,setting=self.lineNumberSetting,visible=self.lineNumbersVisible,
            font=font,size=size,flags=flags,spacing=spacing,measureFont=measureFont,measureSize=measureSize,measureFlags=measureFlags,measureSpacing=measureSpacing}
        self.layingOut=nil
    end
    ---@return string
    function c:GetText()
        -- FAIAP's cached GetText can lag a keystroke until its coloring update.
        -- Apply and callback switches must always read the current source.
        if self.syntax then local text=self.syntax.decode(self.nativeGetText(self.edit));return type(text)=='string' and text or '' end
        return self.edit:GetText() or ''
    end
    function c:SetText(text) self.setting=true;self.edit:SetText(text or '');self.readOnlyText=text or '';self.setting=false;self:Layout('set-text') end
    function c:SetContext(context) self.context=context;if self.UpdateSymbols then self:UpdateSymbols(context) end end
    function c:SetReadOnly(value) self.readOnly=value==true;self.readOnlyText=self:GetText();if self.readOnly then self.edit:ClearFocus();self.edit:Disable() else self.edit:Enable() end end
    function c:SetChanged(callback) self.changed=callback end
    function c:SetCloseHandler(callback) self.closeRequested=callback end
    function c:Acquire(callback,ownerValid)
        if self.closing then error('editor-release-in-progress',0) end
        self.changed,self.valid=callback,ownerValid
        if not self.released then return end
        if self.released then self.layingOut=nil end
        self.released=false;self.readOnly=false;self.readOnlyText=nil;self.changed=callback;self.valid=ownerValid;self.layoutCounts=nil;self.layoutInput=nil
        self.edit:Enable()
        if self.ResetInputTrace then addon.luaInputEditor=self;self:ResetInputTrace() end
        if self.syntax then pcall(self.syntax.enable,self.edit,self.syntaxColors,4) end
        if self.AcquireCompletion then self:AcquireCompletion() end
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
    end
    function c:Release()
        if self.released then return end
        self.released=true;self.closing=true;self.changed=nil;self.closeRequested=nil;self.context=nil;self.valid=function() return false end
        local failed,why
        local function attempt(callback,...)
            local ok,result=pcall(callback,...);if not ok and not failed then failed,why=true,result end
        end
        if self.ReleaseLineNumbers then attempt(self.ReleaseLineNumbers,self) end
        if self.ReleaseCompletion then attempt(self.ReleaseCompletion,self) end
        attempt(self.edit.ClearFocus,self.edit)
        if self.syntax then pcall(self.syntax.disable,self.edit) end
        self.edit.GetText=self.nativeGetText;self.edit.SetText=self.nativeSetText
        for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do attempt(self.edit.SetScript,self.edit,event,self.nativeScripts[event]) end
        attempt(self.edit.SetText,self.edit,'');attempt(self.measure.SetText,self.measure,'');attempt(self.frame.Hide,self.frame)
        self.layoutInput=nil;self.readOnlyText=nil
        self.closing=nil;if failed then error(why,0) end
    end
    addon:SetUIScript(c.edit,'OnTextChanged',function() if c.released then return end;if c.readOnly and not c.setting and c:GetText()~=c.readOnlyText then c:SetText(c.readOnlyText);return end;c:Layout('text-changed');if not c.setting and not c.released and c.valid() and c.changed then c.changed(c:GetText()) end end)
    addon:SetUIScript(c.frame,'OnSizeChanged',function() c:Layout('owner-size') end)
    addon:SetUIScript(c.edit,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end);c.edit:EnableMouseWheel(true)
    addon:SetUIScript(c.edit,'OnCursorChanged',function(_,_,y,_,height) local bar=c.scroll.workbenchBar;local top=-y;if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+c.scroll:GetHeight() then bar:SetValue(top+height-c.scroll:GetHeight()) end end)
    local function closeEditor(mouse)
        if c.released or not c.valid() then return end
        c.edit:ClearFocus();if c.closeRequested then c.closeRequested(mouse) end
    end
    addon:SetUIScript(c.edit,'OnEscapePressed',function() closeEditor(false) end)
    addon:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='RightButton' then closeEditor(true) end end)
    c.edit:SetText('')
    c.nativeGetText=c.edit.GetText;c.nativeSetText=c.edit.SetText;c.nativeScripts={}
    for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.nativeScripts[event]=c.edit:GetScript(event) end
    local syntax=preferred~='plain' and self.LuaSyntax
    if syntax then
        local getText,setText=c.edit.GetText,c.edit.SetText;local scripts={};for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do scripts[event]=c.edit:GetScript(event) end
        c.syntaxColors={};for token,color in pairs(syntax.defaultColorTable or {}) do c.syntaxColors[token]=type(color)=='string' and color:gsub('^|c00','|cff') or color end
        local ok=pcall(syntax.enable,c.edit,c.syntaxColors,4)
        if ok then c.syntax=syntax else
            pcall(syntax.disable,c.edit);c.edit.GetText=getText;c.edit.SetText=setText
            for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.edit:SetScript(event,scripts[event]) end
        end
    end
    -- Install the provider handler before post-hooks: native SetScript clears
    -- existing HookScript callbacks, including deferred gutters/diagnostics.
    if self.InstallNativeLuaLineNumbers then
        addon:SetUIScript(c.frame,'OnUpdate',function() if not c.released and c.valid() and c.RefreshLineNumbers and c.lineNumberSetting~=(addon.db.profile.lua_line_numbers~=false) then c:Layout('line-number-setting') end end)
    end
    if self.InstallLuaInputDiagnostics then self:InstallLuaInputDiagnostics(c) end
    if self.InstallRMCodeCompletion then self:InstallRMCodeCompletion(c) end
    if self.InstallNativeLuaLineNumbers then self:InstallNativeLuaLineNumbers(c) end
    c:SetText('');return c
end

-- Each source host owns these three slots; parent frames are not identities.
function addon:AcquireSourceLuaEditor(owner,parent,changed,valid,preferred)
    local operation={};owner.sourceEditorOperation=operation
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    if owner.sourceEditorOperation~=operation then return owner.code end
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    local resolved=resolveEditor(self,preferred)
    if resolved=='LuaWorkbench' and not self:IsLuaWorkbenchIntegrationAvailable() then resolved=resolveEditor(self,'native') end
    if editorDisabled(self,resolved) then resolved='plain' end
    if owner.sourceEditorOperation~=operation then return owner.code end
    local known=resolved=='native' or resolved=='plain' or resolved=='LuaWorkbench'
    local factory=providers[resolved]
    owner.sourceEditorPool=owner.sourceEditorPool or {}
    local old=owner.code
    local entry=known and owner.sourceEditorPool[resolved]
    local code=entry and entry.factory==factory and entry.control or nil
    -- An unchanged active foreign control retains its original refresh behavior;
    -- released or replaced foreign factories still construct fresh controls.
    if not known and old and not old.released and old.preference==preferred and old.factory==factory then code=old end
    if old and old~=code then
        owner.code=nil
        if not old.released then pcall(old.Release,old) end
        if owner.sourceEditorOperation~=operation then return owner.code end
    end
    if code then
        local ok=pcall(code.Acquire,code,changed,valid)
        if owner.sourceEditorOperation~=operation then return owner.code end
        if not ok then
            if owner.sourceEditorPool[resolved]==entry then owner.sourceEditorPool[resolved]=nil end
            pcall(code.Release,code);code=nil
            if owner.sourceEditorOperation~=operation then return owner.code end
        end
    end
    if not code then
        local ok,created=pcall(self.CreateWorkbenchLuaEditor,self,parent,changed,valid,resolved)
        if owner.sourceEditorOperation~=operation then
            if ok and created~=owner.code then pcall(created.Release,created) end
            return owner.code
        end
        if not ok then error(created,0) end
        code=created
        if known and type(code.Acquire)=='function' and (resolved~='LuaWorkbench' or code.provider=='LuaWorkbench') then owner.sourceEditorPool[resolved]={factory=factory,control=code} end
    end
    code.preference=preferred;owner.code=code
    return code
end
