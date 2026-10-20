-- Strict complete-module inverse of source-host provider reuse from0f73dbf.
local records={
 [ [=[Integrations/lua_workbench.lua]=] ]={bytes=28485,hash=[=[ac736727]=],patches={
  {old=[=[local addon_name,rm=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local moduleOrder={'BufferedPaste','LuaEditor','Analysis','LuaConsole','UI','Search','Organization','Helpers','Navigation','DebugProbe','DebugCompiler','Debugger','DebugUI','APIHelp','KnowledgeBase','Inspector','Autocomplete','EditorActions','Snippets','Automation'}
function rm:CreateLuaWorkbenchEngine(options)
    options=options or {}
    -- Only documented-looking scalar preferences cross this boundary. Never use
    -- the installed workspace's drafts, runtime debugger or mutable namespace.
    local installed=type(_G.LuaWorkbench)=='table' and _G.LuaWorkbench.db;local source=type(installed)=='table' and type(installed.options)=='table' and installed.options or {}
    local settings={}
    for _,key in ipairs({'autocomplete','autoIndent','autoPairs','apiHelp','debugReadOnly','indentWidth','outputLimit'}) do
        local value=source[key];if type(value)=='boolean' or type(value)=='number' then settings[key]=value end
    end
    local W={current=options.id or 'RM',currentName=options.name or L['Custom condition']}
    W.db={options=settings,snippets={},drafts={},folders={},folderBySnippet={},clearOnRun={},autoRun={},helperModules={},textSnippets={},panelPositions={},split=.65}
    local engine={embedded=true,L={},Workspace=W,embeddingOptions=options}
    -- Use upstream's own translations rather than translating its UI in RM.
]=],current=[=[local addon_name,rm=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local moduleOrder={'BufferedPaste','LuaEditor','Analysis','LuaConsole','UI','Search','Organization','Helpers','Navigation','DebugProbe','DebugCompiler','Debugger','DebugUI','APIHelp','KnowledgeBase','Inspector','Autocomplete','EditorActions','Snippets','Automation'}
local function editorPreferences()
    local installed=type(_G.LuaWorkbench)=='table' and _G.LuaWorkbench.db
    local source=type(installed)=='table' and type(installed.options)=='table' and installed.options or {}
    local result={}
    for _,key in ipairs({'autocomplete','autoIndent','autoPairs','apiHelp','debugReadOnly','indentWidth','outputLimit'}) do local value=source[key];if type(value)=='boolean' or type(value)=='number' then result[key]=value end end
    return result
end
-- Cleanup retires the lease first and finishes independent native resources
-- even if one optional provider/debugger cleanup fails.
local function cleanup()
    local failed,why
    local function attempt(callback,...)
        local ok,result=pcall(callback,...)
        if not ok and not failed then failed,why=true,result end
        return ok
    end
    local function finish() if failed then error(why,0) end end
    return attempt,finish
end
local function inactive() return false end
function rm:CreateLuaWorkbenchEngine(options)
    options=options or {}
    -- Only documented-looking scalar preferences cross this boundary. Never use
    -- the installed workspace's drafts, runtime debugger or mutable namespace.
    local settings=editorPreferences()
    local W={current=options.id or 'RM',currentName=options.name or L['Custom condition']}
    W.db={options=settings,snippets={},drafts={},folders={},folderBySnippet={},clearOnRun={},autoRun={},helperModules={},textSnippets={},panelPositions={},split=.65}
    local engine={embedded=true,L={},Workspace=W,embeddingOptions=options}
    -- Use upstream's own translations rather than translating its UI in RM.
]=]},
  {old=[=[        for name,value in pairs(options.environment or {}) do environment[name]=value;self.environmentBuiltinSets[environment][name]=true end
        local meta=getmetatable(environment);local previous=meta.__index;meta.__index=function(table,key) if options.parameterNames and options.parameterNames[key] then return nil end;if type(previous)=='function' then return previous(table,key) end;return previous and previous[key] end
        return environment
    end
    function engine:Release()
        if self.released then return end;self.released=true;self.Debugger:Stop();self.DebugProbe:Stop();self.Autocomplete:Hide();self.Workspace:HidePanels()
        if self.APIHelp.events then self.APIHelp.events:UnregisterAllEvents();self.APIHelp.events:SetScript('OnEvent',nil) end
        if self.Automation.probe then self.Automation.probe:UnregisterAllEvents() end
        local input=self.Query.Console.input
        if input and input.editBox then self.Query.Editor:Detach(input);input.editBox:ClearFocus();input.frame:Hide() end
    end
    return engine
end

]=],current=[=[        for name,value in pairs(options.environment or {}) do environment[name]=value;self.environmentBuiltinSets[environment][name]=true end
        local meta=getmetatable(environment);local previous=meta.__index;meta.__index=function(table,key) if options.parameterNames and options.parameterNames[key] then return nil end;if type(previous)=='function' then return previous(table,key) end;return previous and previous[key] end
        return environment
    end
    local event=engine.APIHelp.events
    local eventHandler=event and event:GetScript('OnEvent')
    local eventLease
    local stopDebugger=engine.Debugger.Stop
    function engine:Acquire()
        if self.closing then error('editor-release-in-progress',0) end
        if self.released==false then return end
        self.released=false;self.Workspace.db.options=editorPreferences()
        local lease={};eventLease=lease
        -- Limited completion never subscribes or loads Blizzard API docs.
        if event and not options.limited then
            event:RegisterEvent('PLAYER_REGEN_ENABLED')
            event:SetScript('OnEvent',function(...) if not self.released and eventLease==lease and eventHandler then return eventHandler(...) end end)
        end
    end
    engine:Acquire()
    local refresh=engine.Query.Console.Refresh
    function engine.Query.Console:Refresh(...) if not engine.released then return refresh(self,...) end end
    function engine:Release()
        if self.released then return end
        self.released=true;self.closing=true;eventLease=nil
        local attempt,finish=cleanup()
        if not attempt(self.Debugger.Stop,self.Debugger) and self.Debugger.Stop~=stopDebugger then attempt(stopDebugger,self.Debugger) end
        attempt(self.DebugProbe.Stop,self.DebugProbe)
        attempt(self.Autocomplete.Hide,self.Autocomplete)
        attempt(self.Workspace.HidePanels,self.Workspace)
        if event then attempt(event.UnregisterAllEvents,event);attempt(event.SetScript,event,'OnEvent',nil) end
        if self.Automation.probe then attempt(self.Automation.probe.UnregisterAllEvents,self.Automation.probe) end
        local input=self.Query.Console.input
        if input and input.editBox then
            attempt(self.Query.Editor.Detach,self.Query.Editor,input)
            attempt(input.editBox.ClearFocus,input.editBox);attempt(input.frame.Hide,input.frame)
        end
        self.closing=nil;finish()
    end
    function engine:ResetLease()
        self.released=true;eventLease=nil
        local attempt,finish=cleanup()
        local console,editor=self.Query.Console,self.Query.Editor;local input=console.input
        self.rmContext=nil;self.rmSymbols={}
        if self.APIHelp.rmSyncSymbols then attempt(self.APIHelp.rmSyncSymbols,self.APIHelp) end
        local api=self.APIHelp;api.rmUndocumented=nil;api.source=nil;api.paths=nil;api.text={};api.pending=nil;api.pendingForce=nil
        local autocomplete=self.Autocomplete
        autocomplete.context,autocomplete.items,autocomplete.input,autocomplete.pending=nil,nil,nil,nil
        autocomplete.rmNameSymbols,autocomplete.rmNameSource,autocomplete.rmVisibleNames=nil,nil,nil
        self.Navigation.history={};self.Navigation.held=nil
        self.Analysis.cache={};self.Analysis.order={};self.Analysis.tokenCount=0;self.Analysis.byteCount=0
        editor.lexicalCache=nil;editor.viewportLexicalCache=nil
        console.source='';console.environment=nil;console.linePositionCache=nil;console.lines={};console.characters=0
        console.undoLines=nil;console.undoDumpLineLimit=nil;console.undoDumpCharacterLimit=nil;console.dumpLineLimit=nil;console.dumpCharacterLimit=nil
        console.statusText=nil;console.statusFailed=nil;console.lastError=nil
        for _,key in ipairs({'snippets','drafts','folders','folderBySnippet','clearOnRun','autoRun','helperModules','textSnippets','debugBreakpoints'}) do W.db[key]={} end
        W.db.startupDebug=nil;W.current='RM';W.currentName='RM';W.dirty=nil;W.f5Held=nil
        local debugger=self.Debugger
        debugger.breakpoints={};debugger.breakpointSources={};debugger.loadedBreakpointRecords=nil;debugger.breakpointDB=nil
        debugger.source=nil;debugger.scriptId=nil;debugger.terminalLines={}
        local probe=self.DebugProbe;probe.source=nil;probe.scriptId=nil;probe.terminalLines={}
        local ui=self.DebugUI;ui.snapshotRecord=nil;ui.snapshotLine=nil;ui.snapshotMeasureCache=nil;ui.drawerOpen=false;ui.renderedVariables=nil
        local inspector=self.Inspector;inspector.refs={};inspector.root=nil;inspector.target=nil;inspector.history={};inspector.rows={}
        for _,row in ipairs(inspector.buttons or {}) do row.node=nil;attempt(row.Hide,row);if row.text then attempt(row.text.SetText,row.text,'') end end
        self.Automation.environments={};self.Automation.running={};self.EditorActions.lineClipboard=nil
        local function clearText(widget) if widget then attempt(widget.SetText,widget,'') end end
        local function clearInput(value)
            if not value then return end
            clearText(value.editBox)
            local state=value.queryEditor
            if state then
                clearText(state.overlay)
                for key in pairs(state) do if key~='overlay' and key~='caret' and key~='active' then state[key]=nil end end
            end
        end
        clearInput(ui.terminalOutput);clearText(ui.terminalInput)
        clearInput(ui.snapshotInput);clearText(ui.snapshotTitle);clearText(ui.snapshotMeasure)
        if probe.terminal then clearInput(probe.terminal.output);clearText(probe.terminal.input) end
        if probe.snapshot then clearInput(probe.snapshot.code) end
        if self.Navigation.snapshotInput then clearInput(self.Navigation.snapshotInput) end
        self.KnowledgeBase.history={}
        if self.Snippets.panel then self.Snippets.panel.target=nil;self.Snippets.panel.selected=nil end
        if W.contextMenu then
            for _,button in ipairs(W.contextMenu.buttons) do button.action=inactive;button.tooltipText=nil;clearText(button.text) end
            clearText(W.contextMenu.measure)
        end
        if input then
            input.debugHitLayout=nil
            local state=options.limited and input.queryEditor or input.queryEditorCache
            if state then
                clearText(state.overlay)
                for key in pairs(state) do if key~='overlay' and key~='caret' and key~='active' then state[key]=nil end end
                if options.limited then state.source='';state.elapsed=0 end
            end
            local lines=input.queryLineNumberCache
            if lines then lines.source=nil;lines.rmMetrics=nil;lines.rmRender=nil;lines.positions=nil;lines.lineHeights=nil;clearText(lines.measure) end
            -- Native completion keeps its accepted text-clearing order in the
            -- outer control; never emit a live OnTextChanged from this reset.
            if not options.limited then clearText(input.editBox) end
        end
        finish()
    end
    return engine
end

]=]},
  {old=[=[        self.arguments:SetText(defaults)
        W.db.snippets[W.current]={name=W.currentName,source=self:GetText()};W.db.drafts[W.current]={name=W.currentName,source=self:GetText()}
        self:Layout()
    end
    function c:Release() if self.released then return end;if self.ReleaseLineNumbers then self:ReleaseLineNumbers() else C:DetachLineNumbers() end;self.released=true;engine:Release();if self.outputWindow then self.outputWindow:Hide() end;frame:Hide();self.changed=nil;self.closeRequested=nil end
    self:SetUIScript(c.edit,'OnEscapePressed',function() if c.closeRequested then c.edit:ClearFocus();c.closeRequested(false) end end)
    self:SetUIScript(c.edit,'OnKeyDown',function(_,key) W:RunShortcut(key) end)
    self:SetUIScript(c.edit,'OnKeyUp',function(_,key) engine.DebugUI:KeyUp(key);engine.Navigation.held=nil;W.f5Held=nil end)
    self:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='RightButton' and c.closeRequested then c.edit:ClearFocus();c.closeRequested(true) end end)
    -- Layer ownership in attach order, then unwind gutter before editor on
    -- release. Toggling the gutter must restore the active editor handlers.
    E:Attach(input)
    self:SetUIScript(frame,'OnSizeChanged',function() c:Layout() end)
    local pendingPaintElapsed=0
    self:SetUIScript(frame,'OnUpdate',function(_,elapsed)
        if c.released or not valid() then return end
        c:UpdateDebugAvailability()
        if c.RefreshLineNumbers and c.lineNumberSetting~=(rm.db.profile.lua_line_numbers~=false) then c:RefreshLineNumbers() end
]=],current=[=[        self.arguments:SetText(defaults)
        W.db.snippets[W.current]={name=W.currentName,source=self:GetText()};W.db.drafts[W.current]={name=W.currentName,source=self:GetText()}
        self:Layout()
    end
    local pendingPaintElapsed=0
    local attachMouseUp
    function c:Acquire(callback,ownerValid)
        if self.closing then error('editor-release-in-progress',0) end
        changed,valid=callback,ownerValid;self.changed,self.valid=callback,ownerValid
        if not self.released then return end
        self.layingOut=nil
        self.released=false;self.readOnly=false;input.readonly=false;self.edit:Enable()
        if self.ResetInputTrace then rm.luaInputEditor=self;self:ResetInputTrace() end
        self.layoutWidth,self.layoutHeight,self.executionReady=nil,nil,nil;pendingPaintElapsed=0
        self.edit:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'')
        engine:Acquire();E:Attach(input);attachMouseUp()
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        engine.APIHelp:Load();self.frame:Show();self:Layout()
    end
    function c:Release()
        if self.released then return end
        self.released=true;self.closing=true;self.changed=nil;self.valid=inactive
        changed=nil;valid=inactive;self.closeRequested=nil;self.showOwner=nil
        self.context={};self.contextSignature=nil;self.debugError=nil;self.startArguments=nil
        local attempt,finish=cleanup()
        if self.ReleaseLineNumbers then attempt(self.ReleaseLineNumbers,self) else attempt(C.DetachLineNumbers,C) end
        attempt(engine.Release,engine);attempt(self.CloseDebugSurface,self)
        self.setting=true;attempt(engine.ResetLease,engine);self.setting=false
        for key in pairs(self.environment) do self.environment[key]=nil end
        self.environment.addon=rm;self.environment.L=L;engine.embeddingOptions.parameterNames=nil
        attempt(self.arguments.SetText,self.arguments,'{}');attempt(self.status.SetText,self.status,'')
        if self.outputWindow then
            attempt(self.outputWindow.Hide,self.outputWindow)
            self.outputWindow.text='';self.outputWindow.setting=true
            attempt(self.outputWindow.input.SetText,self.outputWindow.input,'');self.outputWindow.setting=false
            attempt(self.outputWindow.measure.SetText,self.outputWindow.measure,'')
        end
        attempt(frame.Hide,frame);self.closing=nil;finish()
    end
    self:SetUIScript(c.edit,'OnEscapePressed',function() if c.closeRequested then c.edit:ClearFocus();c.closeRequested(false) end end)
    self:SetUIScript(c.edit,'OnKeyDown',function(_,key) W:RunShortcut(key) end)
    self:SetUIScript(c.edit,'OnKeyUp',function(_,key) engine.DebugUI:KeyUp(key);engine.Navigation.held=nil;W.f5Held=nil end)
    self:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='RightButton' and c.closeRequested then c.edit:ClearFocus();c.closeRequested(true) end end)
    -- Layer ownership in attach order, then unwind gutter before editor on
    -- release. Toggling the gutter must restore the active editor handlers.
    E:Attach(input)
    self:SetUIScript(frame,'OnSizeChanged',function() c:Layout() end)
    self:SetUIScript(frame,'OnUpdate',function(_,elapsed)
        if c.released or not valid() then return end
        c:UpdateDebugAvailability()
        if c.RefreshLineNumbers and c.lineNumberSetting~=(rm.db.profile.lua_line_numbers~=false) then c:RefreshLineNumbers() end
]=]},
  {old=[=[    end)
    -- Hook the completed provider handler; later SetScript would erase it.
    if rm.InstallLuaLineNumberControl then rm:InstallLuaLineNumberControl(c,C,input);c:RefreshLineNumbers() else C:AttachLineNumbers(input) end
    self:SetUIScript(frame,'OnHide',function() engine.Debugger:Stop();engine.Autocomplete:Hide();W:HidePanels();if c.outputWindow then c.outputWindow:Hide() end end)
    local mouseUp=c.edit:GetScript('OnMouseUp')
    self:SetUIScript(c.edit,'OnMouseUp',function(edit,button)
        if mouseUp then mouseUp(edit,button) end
        if button=='LeftButton' and IsControlKeyDown and IsControlKeyDown() and rm.NavigateLuaSymbol then rm:NavigateLuaSymbol(engine,input,c:GetText(),edit:GetCursorPosition()) end
    end)
    if self.InstallLuaInputDiagnostics then self:InstallLuaInputDiagnostics(c) end
    engine.APIHelp:Load()
    c:Layout();return c
end
]=],current=[=[    end)
    -- Hook the completed provider handler; later SetScript would erase it.
    if rm.InstallLuaLineNumberControl then rm:InstallLuaLineNumberControl(c,C,input);c:RefreshLineNumbers() else C:AttachLineNumbers(input) end
    self:SetUIScript(frame,'OnHide',function() engine.Debugger:Stop();engine.Autocomplete:Hide();W:HidePanels();if c.outputWindow then c.outputWindow:Hide() end end)
    attachMouseUp=function()
        local mouseUp=c.edit:GetScript('OnMouseUp')
        rm:SetUIScript(c.edit,'OnMouseUp',function(edit,button)
            if mouseUp then mouseUp(edit,button) end
            if not c.released and valid() and button=='LeftButton' and IsControlKeyDown and IsControlKeyDown() and rm.NavigateLuaSymbol then rm:NavigateLuaSymbol(engine,input,c:GetText(),edit:GetCursorPosition()) end
        end)
    end
    attachMouseUp()
    if self.InstallLuaInputDiagnostics then self:InstallLuaInputDiagnostics(c) end
    engine.APIHelp:Load()
    c:Layout();return c
end
]=]},
  {old=[=[    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(loaded)~='function' then return false end
    local ok,value=pcall(loaded,'!!!LuaWorkbench');return ok and value==true and type(_G.LuaWorkbench)=='table'
end
function rm:DiscoverLuaEditorIntegrations()
    if not self.RegisterLuaEditorProvider then return end
    if self:IsLuaWorkbenchIntegrationAvailable() then
        self:RegisterLuaEditorProvider('LuaWorkbench',function(parent,changed,valid)
            if not self:IsLuaWorkbenchIntegrationAvailable() then return nil end
            return self:CreateLuaWorkbenchControl(parent,changed,valid)
        end)
    end
end
]=],current=[=[    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(loaded)~='function' then return false end
    local ok,value=pcall(loaded,'!!!LuaWorkbench');return ok and value==true and type(_G.LuaWorkbench)=='table'
end
local ownedWorkbenchControl=rm.CreateLuaWorkbenchControl
local workbenchProvider
function rm:DiscoverLuaEditorIntegrations()
    if not self.RegisterLuaEditorProvider then return end
    if self:IsLuaWorkbenchIntegrationAvailable() then
        if not workbenchProvider then workbenchProvider=function(parent,changed,valid)
            if not self:IsLuaWorkbenchIntegrationAvailable() then return nil end
            local create=self.CreateLuaWorkbenchControl
            return create(self,parent,changed,valid),create==ownedWorkbenchControl and create or nil
        end end
        self:RegisterLuaEditorProvider('LuaWorkbench',workbenchProvider)
    end
end
]=]},
 }},
 [ [=[UI/lua_editor.lua]=] ]={bytes=17792,hash=[=[dc80a10e]=],patches={
  {old=[=[    if preferred=='auto' then
        local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);preferred=names[1] or 'native'
    end
    if preferred and providers[preferred] then
        local host=CreateFrame('Frame',nil,parent)
        local ok,control=pcall(providers[preferred],host,changed,valid)
        if ok and type(control)=='table' and usableFrame(control.frame) and type(control.GetText)=='function' and type(control.SetText)=='function' and type(control.Release)=='function' then
            local c={frame=host,provider=preferred,inner=control,edit=control.edit,lastText=''}
            local function fallback()
                pcall(c.inner.Release,c.inner);hideFrame(c.inner.frame)
                c.inner=addon:CreateWorkbenchLuaEditor(host,changed,valid,'native');c.inner.frame:SetAllPoints(host);c.provider='native';c.edit=c.inner.edit;c.inner:SetText(c.lastText);c.inner:SetReadOnly(c.readOnly);if c.closeRequested then c.inner:SetCloseHandler(c.closeRequested) end;if c.context and c.inner.SetContext then c.inner:SetContext(c.context) end
            end
            ---@return string
    function c:GetText()
                local read,text=pcall(self.inner.GetText,self.inner)
                if not read or type(text)~='string' then fallback();text=self.inner:GetText() end
                self.lastText=text;return text
            end
            function c:SetContext(context) self.context=context;if self.inner.SetContext and not pcall(self.inner.SetContext,self.inner,context) then fallback() end end
            function c:SetReadOnly(value)
                self.readOnly=value==true
                if type(self.inner.SetReadOnly)=='function' then
                    if not pcall(self.inner.SetReadOnly,self.inner,self.readOnly) then fallback() end
                elseif self.readOnly then fallback() end
            end
            function c:SetLineNumbers(visible) if self.inner.SetLineNumbers and not pcall(self.inner.SetLineNumbers,self.inner,visible) then fallback() end end
            function c:SetCloseHandler(callback) self.closeRequested=callback;if self.inner.SetCloseHandler then self.inner:SetCloseHandler(callback) end end
            function c:SetText(text)
                self.lastText=text or '';if not pcall(self.inner.SetText,self.inner,self.lastText) then fallback() end
            end
            function c:Acquire(callback,ownerValid)
                changed,valid=callback,ownerValid
                if not self.released then return end
                self.released=false
                local created,nextControl=pcall(providers[preferred],host,changed,valid)
                if created and type(nextControl)=='table' and usableFrame(nextControl.frame) and type(nextControl.GetText)=='function' and type(nextControl.SetText)=='function' and type(nextControl.Release)=='function' then
                    self.inner=nextControl;self.provider=preferred;self.edit=nextControl.edit
                    local attached=pcall(function() nextControl.frame:SetParent(host);nextControl.frame:SetAllPoints(host) end)
                    if not attached then fallback() end
                else
                    if created and type(nextControl)=='table' then if type(nextControl.Release)=='function' then pcall(nextControl.Release,nextControl) end;hideFrame(nextControl.frame) end
                    fallback()
                end
                self:SetText(self.lastText);self:SetReadOnly(self.readOnly)
                if self.context then self:SetContext(self.context) end
                self.inner.frame:Show()
            end
            function c:Release()
                if self.released then return end
                local read,text=pcall(self.inner.GetText,self.inner);if read and type(text)=='string' then self.lastText=text end
                self.released=true;self.closeRequested=nil;pcall(self.inner.Release,self.inner);self.frame:Hide()
            end
            local attached=pcall(function() control.frame:SetParent(host);control.frame:SetAllPoints(host) end)
            if not attached then fallback() end
            return c
        end
        if ok and type(control)=='table' then if type(control.Release)=='function' then pcall(control.Release,control) end;hideFrame(control.frame) end
        host:Hide()
    end
    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}
    c.scroll=self:CreateWorkbenchScrollFrame(c.frame);c.scroll:SetPoint('TOPLEFT',4,-4);c.content=CreateFrame('Frame',nil,c.scroll);c.content:EnableMouse(false);c.scroll:SetScrollChild(c.content);c.edit=CreateFrame('EditBox',nil,c.content);c.edit:SetMultiLine(true);c.edit:SetAutoFocus(false);c.edit:EnableMouse(true);c.edit:SetAltArrowKeyMode(false);c.edit:SetBlinkSpeed(.5);c.edit:SetCountInvisibleLetters(false);c.edit:SetTextColor(1,1,1);c.edit:SetJustifyH('LEFT');c.edit:SetJustifyV('TOP');c.edit:SetFontObject('GameFontHighlightSmall');c.edit:SetTextInsets(6,6,4,4);c.edit:SetMaxLetters(0);c.edit:SetHeight(1);c.edit:SetPoint('TOPLEFT',c.content,'TOPLEFT',0,0)
    -- Let the native EditBox own mouse placement and keyboard navigation.
]=],current=[=[    if preferred=='auto' then
        local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);preferred=names[1] or 'native'
    end
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
    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}
    c.scroll=self:CreateWorkbenchScrollFrame(c.frame);c.scroll:SetPoint('TOPLEFT',4,-4);c.content=CreateFrame('Frame',nil,c.scroll);c.content:EnableMouse(false);c.scroll:SetScrollChild(c.content);c.edit=CreateFrame('EditBox',nil,c.content);c.edit:SetMultiLine(true);c.edit:SetAutoFocus(false);c.edit:EnableMouse(true);c.edit:SetAltArrowKeyMode(false);c.edit:SetBlinkSpeed(.5);c.edit:SetCountInvisibleLetters(false);c.edit:SetTextColor(1,1,1);c.edit:SetJustifyH('LEFT');c.edit:SetJustifyV('TOP');c.edit:SetFontObject('GameFontHighlightSmall');c.edit:SetTextInsets(6,6,4,4);c.edit:SetMaxLetters(0);c.edit:SetHeight(1);c.edit:SetPoint('TOPLEFT',c.content,'TOPLEFT',0,0)
    -- Let the native EditBox own mouse placement and keyboard navigation.
]=]},
  {old=[=[    function c:SetReadOnly(value) self.readOnly=value==true;self.readOnlyText=self:GetText();if self.readOnly then self.edit:ClearFocus();self.edit:Disable() else self.edit:Enable() end end
    function c:SetChanged(callback) self.changed=callback end
    function c:SetCloseHandler(callback) self.closeRequested=callback end
    function c:Acquire(callback,ownerValid)
        self.released=false;self.readOnly=false;self.readOnlyText=nil;self.changed=callback;self.valid=ownerValid;self.layoutCounts=nil;self.layoutInput=nil
        if self.ResetInputTrace then addon.luaInputEditor=self;self:ResetInputTrace() end
        if self.syntax then pcall(self.syntax.enable,self.edit,self.syntaxColors,4) end
        if self.AcquireCompletion then self:AcquireCompletion() end
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
    end
    function c:Release()
        if self.released then return end;if self.ReleaseLineNumbers then self:ReleaseLineNumbers() end;if self.ReleaseCompletion then self:ReleaseCompletion() end;self.released=true;self.edit:ClearFocus()
        if self.syntax then pcall(self.syntax.disable,self.edit) end
        self.changed=nil;self.closeRequested=nil;self.valid=function() return false end
        self.edit.GetText=self.nativeGetText;self.edit.SetText=self.nativeSetText
        for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do self.edit:SetScript(event,self.nativeScripts[event]) end
        self.edit:SetText('');self.frame:Hide()
    end
    addon:SetUIScript(c.edit,'OnTextChanged',function() if c.readOnly and not c.setting and c:GetText()~=c.readOnlyText then c:SetText(c.readOnlyText);return end;c:Layout('text-changed');if not c.setting and not c.released and c.valid() and c.changed then c.changed(c:GetText()) end end)
    addon:SetUIScript(c.frame,'OnSizeChanged',function() c:Layout('owner-size') end)
    addon:SetUIScript(c.edit,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end);c.edit:EnableMouseWheel(true)
    addon:SetUIScript(c.edit,'OnCursorChanged',function(_,_,y,_,height) local bar=c.scroll.workbenchBar;local top=-y;if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+c.scroll:GetHeight() then bar:SetValue(top+height-c.scroll:GetHeight()) end end)
    local function closeEditor(mouse)
]=],current=[=[    function c:SetReadOnly(value) self.readOnly=value==true;self.readOnlyText=self:GetText();if self.readOnly then self.edit:ClearFocus();self.edit:Disable() else self.edit:Enable() end end
    function c:SetChanged(callback) self.changed=callback end
    function c:SetCloseHandler(callback) self.closeRequested=callback end
    function c:Acquire(callback,ownerValid)
        if self.closing then error('editor-release-in-progress',0) end
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
]=]},
  {old=[=[    if self.InstallRMCodeCompletion then self:InstallRMCodeCompletion(c) end
    if self.InstallNativeLuaLineNumbers then self:InstallNativeLuaLineNumbers(c) end
    c:SetText('');return c
end
]=],current=[=[    if self.InstallRMCodeCompletion then self:InstallRMCodeCompletion(c) end
    if self.InstallNativeLuaLineNumbers then self:InstallNativeLuaLineNumbers(c) end
    c:SetText('');return c
end

-- Each source host owns these three slots; parent frames are not identities.
function addon:AcquireSourceLuaEditor(owner,parent,changed,valid,preferred)
    local operation={};owner.sourceEditorOperation=operation
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    if owner.sourceEditorOperation~=operation then return owner.code end
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    local resolved=preferred
    if resolved=='auto' then local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);resolved=names[1] or 'native' end
    if resolved=='LuaWorkbench' and not self:IsLuaWorkbenchIntegrationAvailable() then resolved='native' end
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
]=]},
 }},
 [ [=[UI/lua_completion.lua]=] ]={bytes=5966,hash=[=[98b42492]=],patches={
  {old=[=[        if addon:SettingsDataEqual(signature,self.symbolSignature) then return end;self.symbolSignature=addon:CopySettingsData(signature)
        engine.Workspace.current=context and context.id or 'RM-native';addon:ApplyLuaContextSymbols(engine,context,true)
    end
    function c:ReleaseCompletion()
        A:Hide();engine.DebugUI:HideTooltip(nil,'owner-closed');engine.Query.Console.source='';if not attached then return end;attached=false
        for event,script in pairs(originals) do addon:SetUIScript(self.edit,event,script or nil) end;originals={}
    end
    function c:AcquireCompletion() attachedHandler();if self.context then self:UpdateSymbols(self.context) end end
    c.completionEngine=engine;c:AcquireCompletion()
end
]=],current=[=[        if addon:SettingsDataEqual(signature,self.symbolSignature) then return end;self.symbolSignature=addon:CopySettingsData(signature)
        engine.Workspace.current=context and context.id or 'RM-native';addon:ApplyLuaContextSymbols(engine,context,true)
    end
    function c:ReleaseCompletion()
        self.context=nil;self.symbolSignature=nil
        local failed,why
        local function attempt(callback,...)
            local ok,result=pcall(callback,...);if not ok and not failed then failed,why=true,result end
        end
        attempt(A.Hide,A);attempt(engine.DebugUI.HideTooltip,engine.DebugUI,nil,'owner-closed')
        local scripts=originals;originals={};attached=false
        for event,script in pairs(scripts) do attempt(addon.SetUIScript,addon,self.edit,event,script or nil) end
        attempt(engine.ResetLease,engine)
        if failed then error(why,0) end
    end
    function c:AcquireCompletion() engine:Acquire();attachedHandler();if self.context then self:UpdateSymbols(self.context) end end
    c.completionEngine=engine;c:AcquireCompletion()
end
]=]},
 }},
 [ [=[UI/custom_condition_editor.lua]=] ]={bytes=37284,hash=[=[ad0919b6]=],patches={
  {old=[=[            if self.code then self.code.frame:ClearAllPoints();self.code.frame:SetPoint('TOPLEFT',0,-codeTop);self.code.frame:SetSize(form.width,codeHeight) end
            form.y=codeTop+codeHeight;form.child:SetHeight(form.y+12);form.scroll:Hide()
        end
        local preference=addon.db.profile.lua_editor or 'auto'
        if d.code and (d.code.preference~=preference or d.code.released and not d.code.Acquire) then d.code:Release();d.code=nil end
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(form.child,function() if valid() then d:CodeChanged() end end,valid,preference);d.code.preference=preference elseif d.code.released then d.code:Acquire(function() if valid() then d:CodeChanged() end end,valid) end
        if d.code.SetReadOnly then d.code:SetReadOnly(d.readOnly) end
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse)
            if not valid() then return end
            if embedded and embedded.closeOwner then embedded.closeOwner(mouse) else d:Hide() end
]=],current=[=[            if self.code then self.code.frame:ClearAllPoints();self.code.frame:SetPoint('TOPLEFT',0,-codeTop);self.code.frame:SetSize(form.width,codeHeight) end
            form.y=codeTop+codeHeight;form.child:SetHeight(form.y+12);form.scroll:Hide()
        end
        local preference=addon.db.profile.lua_editor or 'auto'
        d.code=addon:AcquireSourceLuaEditor(d,form.child,function() if valid() then d:CodeChanged() end end,valid,preference)
        if d.code.SetReadOnly then d.code:SetReadOnly(d.readOnly) end
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse)
            if not valid() then return end
            if embedded and embedded.closeOwner then embedded.closeOwner(mouse) else d:Hide() end
]=]},
 }},
 [ [=[UI/function_source_pane.lua]=] ]={bytes=31725,hash=[=[b7ae6968]=],patches={
  {old=[=[            end)
        end
        d.signature=f:Text(addon:FunctionSignature(key,d.value));local codeTop=f.y;d.codeTop=codeTop
        local preference=addon.db.profile.lua_editor or 'auto'
        if d.code and d.code.preference~=preference then d.code:Release();d.code=nil end
        if not d.code then d.code=addon:CreateWorkbenchLuaEditor(f.child,function() if valid() then d:CodeChanged() end end,valid,preference);d.code.preference=preference elseif d.code.released then d.code:Acquire(function() if valid() then d:CodeChanged() end end,valid) end
        d.code:SetReadOnly(d.readOnly);d.code.frame:SetParent(f.child);d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-codeTop);d.code.frame:SetSize(f.width,math.max(220,d.frame:GetHeight()-codeTop-30));d.code.frame:Show();d:SetCode(d.value.code);d:UpdateSignature();codeTop=d.codeTop
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse) local shell=addon.configWindow;if valid() and shell and shell.pane==p then if mouse then shell.rightDown=true end;shell:Hide() end end) end
        d.codeExpand=d.codeExpand or addon:CreateWorkbenchIconButton(d.code.frame,'expand-all',L['Expand code editor'])
        d.codeExpand:SetParent(d.code.frame);d.codeExpand:ClearAllPoints();d.codeExpand:SetPoint('BOTTOMRIGHT',-18,2);d.codeExpand:SetFrameLevel(d.code.frame:GetFrameLevel()+20);d.codeExpand.icon:SetTexture(addon:ControlTexture(d.codeExpanded and 'collapse-all' or 'expand-all'));d.codeExpand.tooltip=d.codeExpanded and L['Restore code editor'] or L['Expand code editor'];d.codeExpand:Show()
]=],current=[=[            end)
        end
        d.signature=f:Text(addon:FunctionSignature(key,d.value));local codeTop=f.y;d.codeTop=codeTop
        local preference=addon.db.profile.lua_editor or 'auto'
        d.code=addon:AcquireSourceLuaEditor(d,f.child,function() if valid() then d:CodeChanged() end end,valid,preference)
        d.code:SetReadOnly(d.readOnly);d.code.frame:SetParent(f.child);d.code.frame:ClearAllPoints();d.code.frame:SetPoint('TOPLEFT',0,-codeTop);d.code.frame:SetSize(f.width,math.max(220,d.frame:GetHeight()-codeTop-30));d.code.frame:Show();d:SetCode(d.value.code);d:UpdateSignature();codeTop=d.codeTop
        if d.code.SetCloseHandler then d.code:SetCloseHandler(function(mouse) local shell=addon.configWindow;if valid() and shell and shell.pane==p then if mouse then shell.rightDown=true end;shell:Hide() end end) end
        d.codeExpand=d.codeExpand or addon:CreateWorkbenchIconButton(d.code.frame,'expand-all',L['Expand code editor'])
        d.codeExpand:SetParent(d.code.frame);d.codeExpand:ClearAllPoints();d.codeExpand:SetPoint('BOTTOMRIGHT',-18,2);d.codeExpand:SetFrameLevel(d.code.frame:GetFrameLevel()+20);d.codeExpand.icon:SetTexture(addon:ControlTexture(d.codeExpanded and 'collapse-all' or 'expand-all'));d.codeExpand.tooltip=d.codeExpanded and L['Restore code editor'] or L['Expand code editor'];d.codeExpand:Show()
]=]},
 }},
}
local function hash(text)
 local value=5381;for i=1,#text do value=(value*33+string.byte(text,i))%4294967296 end
 return string.format('%08x',value)
end
return function(text,path)
 local record=records[path];assert(type(text)=='string' and record,'unknown editor reuse inverse input')
 for _,patch in ipairs(record.patches) do
  local first,last=text:find(patch.current,1,true)
  assert(first and not text:find(patch.current,last+1,true),'missing or repeated editor reuse change')
  text=text:sub(1,first-1)..patch.old..text:sub(last+1)
 end
 assert(#text==record.bytes and hash(text)==record.hash,'module changed outside editor provider reuse scope')
 return text
end
