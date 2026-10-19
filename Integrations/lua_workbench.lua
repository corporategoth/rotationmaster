local addon_name,rm=...
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
    self.LuaWorkbenchModules.Localization(addon_name,engine)
    function W:UpdateStatus() if options.status then options.status(engine.Query.Console.statusText,engine.Query.Console.statusFailed) end end
    function W:NormalizeSource(text) return (text or ''):gsub('\r\n','\n') end
    function W:StoreSource(text) return self:NormalizeSource(text) end
    function W:IsSnippetDirty(id) local draft,saved=self.db.drafts[id],self.db.snippets[id];return draft and (not saved or draft.source~=saved.source) or false end
    function W:Capture()
        self.db.drafts[self.current]={name=self.currentName,source=engine.Query.Console.source};self.dirty=self:IsSnippetDirty(self.current);self:UpdateStatus()
    end
    function W:HidePanels(except)
        if engine.Inspector then engine.Inspector:StopPicking() end
        for _,name in ipairs({'KnowledgeBase','Snippets','Navigation','Inspector','DebugUI'}) do
            local object=engine[name];for _,key in ipairs({'panel','snapshot','tooltip','copyPanel'}) do local panel=object and object[key];if panel and panel~=except and panel.Hide then panel:Hide() end end
        end
        if self.contextMenu then self.contextMenu:Hide() end
    end
    function W:Select(id) if options.navigate then return options.navigate(id) end;return false end
    function W:Show() if options.show then options.show() end end
    function W:ShowHelp() if options.help then options.help() end end
    function W:Layout() if engine.control then engine.control:Layout() end end
    function W:RunShortcut(key)
        if engine.DebugUI:Shortcut(key) then return true end
        if engine.Navigation:Shortcut(key) then return true end
        return false
    end
    for _,name in ipairs(moduleOrder) do
        local factory=self.LuaWorkbenchModules[name];if not factory then return nil,'missing-editor-module:'..name end
        factory(addon_name,engine)
    end
    local make=engine.Debugger.MakeEnvironment
    function engine.Debugger:MakeEnvironment(...)
        local environment=make(self,...)
        for name,value in pairs(options.environment or {}) do environment[name]=value;self.environmentBuiltinSets[environment][name]=true end
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

function rm:CreateLuaWorkbenchControl(parent,changed,valid)
    local frame=CreateFrame('Frame',nil,parent);frame:SetSize(600,300)
    local c={frame=frame,changed=changed,valid=valid,setting=false,context={},environment={addon=self,L=L}}
    local engine=assert(self:CreateLuaWorkbenchEngine({id='RM',environment=c.environment,status=function(text,failed) if c.status then c.status:SetText(text or '');c.status:SetTextColor(failed and 1 or .5,failed and .3 or .85,.5) end end,show=function() if c.showOwner then c.showOwner() end end,help=function() self:ShowWorkbenchHelp(L['Lua editor'],{{text=L['LuaWorkbench supplies editing, completion, API knowledge and debugging. Debug runs this buffer explicitly using the test arguments. It does not replace the saved rotation or live callback.']}},frame) end}))
    c.engine=engine;engine.control=c
    local UI,W,C,E=engine.UI,engine.Workspace,engine.Query.Console,engine.Query.Editor
    W.window=frame;W.helpFrame={};UI.colors.background={.055,.06,.065,1};UI.colors.panel={.09,.10,.11,1};UI.colors.hover={.15,.17,.18,1}
    local baseEditor=UI.Editor
    function UI:Editor(owner,label,readonly) local input=baseEditor(self,owner,label,readonly);input.editBox:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'');return input end
    function UI:Scroll(owner) local scroll=rm:CreateWorkbenchScrollFrame(owner);scroll.bar=scroll.workbenchBar;return scroll end
    local input=UI:Editor(frame,'');input.editBox:SetText('');C.input=input;c.edit=input.editBox;input.frame:SetAllPoints(frame)
    c.arguments=rm:CreateWorkbenchEditBox(input.frame);c.arguments:SetText('{}');c.arguments:SetPoint('TOPLEFT',88,-2);c.arguments:SetPoint('RIGHT',input.frame,'RIGHT',-94,0);c.arguments:SetHeight(22)
    c.argumentLabel=input.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');c.argumentLabel:SetPoint('TOPLEFT',4,-7);c.argumentLabel:SetText(L['Test arguments'])
    c.play=UI:Button(input.frame,'play',engine.L.debugStart,function() c:Debug() end);c.play:SetPoint('TOPRIGHT',-3,-1)
    engine.DebugUI:Build(c.play)
    c.knowledge=rm:CreateWorkbenchIconButton(input.frame,'search',L['API knowledge']);c.knowledge:SetPoint('RIGHT',W.debugButton,'LEFT',-2,0)
    rm:SetUIScript(c.knowledge,'OnClick',function() if not c.released and valid() then engine.KnowledgeBase:Show() end end)
    function engine.DebugUI:Start() return c:Debug() end
    function engine.DebugUI:Menu(owner)
        W:OpenMenu(owner,{{text=engine.L.debugStart,action=function() c:Debug() end},{text=engine.L.debugBreakpoint,action=function() self:ToggleLine(C:GetLinePosition(C.source,c.edit:GetCursorPosition())) end},{text=engine.L.debugStop,action=function() engine.Debugger:Stop() end}})
    end
    function c:Debug()
        if self.released or not valid() or input.readonly then return false end
        local parse,why=loadstring('return '..self.arguments:GetText(),'@RotationMaster:test-arguments')
        if not parse then C:SetStatus(why,true);return false end
        local environment=setmetatable({addon=rm,L=L},{__index=_G});setfenv(parse,environment)
        local ok,arguments=pcall(parse)
        if not ok or type(arguments)~='table' then C:SetStatus(ok and L['Test arguments must be a Lua table.'] or tostring(arguments),true);return false end
        local source=self.context.source or {};local names={}
        if self.context.kind=='function' then for _,entry in ipairs(source.args or {}) do names[#names+1]=entry.name end
        else
            for name in (rm.CustomConditionCallbacks[self.context.callback or 'evaluate'] or ''):gmatch('[%w_]+') do names[#names+1]=name end
        end
        for name in pairs(self.environment) do self.environment[name]=nil end;self.environment.addon=rm;self.environment.L=L
        engine.embeddingOptions.parameterNames={}
        for i,name in ipairs(names or {}) do if name~='...' then self.environment[name]=arguments[i];engine.embeddingOptions.parameterNames[name]=true end end
        if self.context.kind~='function' then for alias,canonical in pairs(rm:CustomConditionParameterAliases(source,self.context.callback or 'evaluate')) do self.environment[alias]=self.environment[canonical];engine.embeddingOptions.parameterNames[alias]=true end end
        for alias,id in pairs(source.bindings or {}) do local value,errorText=rm:ResolveFunctionBinding(id);if errorText then C:SetStatus(errorText,true);return false end;self.environment[alias]=value end
        engine.DebugUI.drawerOpen=true;return engine.Debugger:Start(W.current,self:GetText())
    end
    local updateLabel=C.UpdateEditorLabel
    function C:UpdateEditorLabel() updateLabel(self);input.label:Hide() end
    function c:Layout()
        if self.released then return end
        input.frame:SetAllPoints(frame);input.frame:SetSize(frame:GetWidth(),frame:GetHeight())
        input.scrollBG:SetPoint('TOPLEFT',input.frame,'TOPLEFT',6,-28)
        if engine.DebugUI.toolbar then
            engine.DebugUI:Layout()
            input.scrollBG:SetPoint('TOPLEFT',input.frame,'TOPLEFT',6,engine.Debugger.armed and -60 or -28)
            engine.DebugUI.toolbar:SetPoint('TOPLEFT',6,-28);engine.DebugUI.toolbar:SetPoint('TOPRIGHT',-6,-28)
        end
        C:UpdateLineNumbers();self.arguments:SetShown(not engine.Debugger.armed);self.argumentLabel:SetShown(not engine.Debugger.armed)
    end
    input.changed=function(text)
        if c.released or not valid() then return end
        C.source=text;C.lastError=nil;engine.DebugUI:SourceChanged(text);W:Capture();C:UpdateLineNumbers()
        if not c.setting and changed then changed(text) end
    end
    function c:GetText() return input:GetText() end
    function c:SetText(text)
        if self.released then return end
        self.setting=true;engine.Debugger:Stop();local readonly=input.readonly;input.readonly=false;E:SetSource(input,text or '',0);input.readonly=readonly;C.source=text or '';self.setting=false
    end
    function c:SetReadOnly(value) input.readonly=value==true;if input.readonly then self.edit:ClearFocus();self.edit:Disable() else self.edit:Enable() end end
    function c:SetCloseHandler(callback) self.closeRequested=callback end
    function c:SetContext(context)
        self.context=context or {};local source=self.context.source or {};local signature={kind=self.context.kind,id=self.context.id,callback=self.context.callback,args=source.args,returns=source.returns,bindings=source.bindings,fields=source.fields,parameters=source.parameters,revision=rm.functionRegistryVersion}
        if rm:SettingsDataEqual(signature,self.contextSignature) then return end;self.contextSignature=rm:CopySettingsData(signature)
        if rm.ApplyLuaContextSymbols then rm:ApplyLuaContextSymbols(engine,self.context,false) end
        W.current=self.context.id or 'RM';W.currentName=self.context.name or W.current
        local defaults=self.context.kind=='condition' and self.context.callback=='evaluate' and '{ {}, {}, GetTime() }' or '{}'
        self.arguments:SetText(defaults)
        W.db.snippets[W.current]={name=W.currentName,source=self:GetText()};W.db.drafts[W.current]={name=W.currentName,source=self:GetText()}
    end
    function c:Release() if self.released then return end;self.released=true;engine:Release();frame:Hide();self.changed=nil;self.closeRequested=nil end
    self:SetUIScript(c.edit,'OnEscapePressed',function() if c.closeRequested then c.edit:ClearFocus();c.closeRequested(false) end end)
    self:SetUIScript(c.edit,'OnKeyDown',function(_,key) W:RunShortcut(key) end)
    self:SetUIScript(c.edit,'OnKeyUp',function(_,key) engine.DebugUI:KeyUp(key);engine.Navigation.held=nil;W.f5Held=nil end)
    self:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='RightButton' and c.closeRequested then c.edit:ClearFocus();c.closeRequested(true) end end)
    C:AttachLineNumbers(input);E:Attach(input)
    self:SetUIScript(frame,'OnSizeChanged',function() c:Layout() end)
    self:SetUIScript(frame,'OnUpdate',function(_,elapsed) if not c.released and valid() then engine.DebugUI:HoverUpdate(elapsed) end end)
    self:SetUIScript(frame,'OnHide',function() engine.Debugger:Stop();engine.Autocomplete:Hide();W:HidePanels() end)
    local mouseUp=c.edit:GetScript('OnMouseUp')
    self:SetUIScript(c.edit,'OnMouseUp',function(edit,button)
        if mouseUp then mouseUp(edit,button) end
        if button=='LeftButton' and IsControlKeyDown and IsControlKeyDown() and rm.NavigateLuaSymbol then rm:NavigateLuaSymbol(engine,input,c:GetText(),edit:GetCursorPosition()) end
    end)
    engine.APIHelp:Load()
    c:Layout();return c
end

function rm:IsLuaWorkbenchIntegrationAvailable()
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
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
