local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function read(object,method)
    if not object or type(object[method])~='function' then return 'unavailable' end
    local ok,value=pcall(object[method],object)
    if not ok or type(value)~='string' and type(value)~='number' and type(value)~='boolean' then return 'unavailable' end
    return tostring(value)
end
local function focusRole(frame,control)
    if frame==control.edit then return 'code EditBox' end
    if frame==control.scroll then return 'code ScrollFrame' end
    if frame==control.frame then return 'code container' end
    if not frame then return 'none' end
    local path={};for _=1,12 do
        path[#path+1]=read(frame,'GetObjectType')..'['..read(frame,'GetName')..']'
        if frame==control.frame then path[#path+1]='code container';break end
        if type(frame.GetParent)~='function' then break end;frame=frame:GetParent();if not frame then break end
    end
    return table.concat(path,' > ')
end

local function ownsControl(code,control)
    local seen={}
    for _=1,8 do
        if code==control then return true end
        if type(code)~='table' or seen[code] then return false end
        seen[code]=true;code=code.inner
    end
    return false
end

local function sourceOwner(addon,control)
    local shell=addon.configWindow;local pane=shell and shell.pane;local candidates={}
    local function add(owner,kind) if owner then candidates[#candidates+1]={owner=owner,kind=kind} end end
    if pane then add(pane.inlineFunction,'function');add(pane.inlineCondition,'condition') end
    add(addon.nativeCustomConditionDialog,'condition')
    if not shell then add(control.context and control.context.testOwner,'condition') end
    local historical,fallback
    for _,entry in ipairs(candidates) do
        local owner=entry.owner;local matches=ownsControl(owner.code,control)
        if matches and not owner.closed then return owner,entry.kind,true end
        if owner.closed then
            fallback=fallback or entry
            if matches then historical=historical or entry end
        end
    end
    local entry=historical or fallback
    if entry then return entry.owner,entry.kind,false end
    return nil,nil,false
end

local function activeControl(control)
    if control.released or type(control.valid)~='function' then return false end
    local ok,valid=pcall(control.valid);return ok and not not valid
end

function addon:GetLuaEditorDiagnosticsWidth(code,width)
    local seen={}
    for _=1,8 do
        if type(code)~='table' or seen[code] then return 0 end
        if code.inputDiagnosticsToolbar then code:LayoutInputDiagnostics(width);return code.inputDiagnosticsToolbar.width end
        seen[code]=true;code=code.inner
    end
    return 0
end

-- Observe input without changing its state. Only the explicit temporary arrow
-- probe removes a handler; ordinary reports contain counts, never source.
function addon:InstallLuaInputDiagnostics(control)
    self.luaInputEditor=control
    if not control.inputDiagnosticsToolbar then
        local toolbar={};control.inputDiagnosticsToolbar=toolbar
        toolbar.diagnostics=self:CreateWorkbenchButton(control.frame,L['Diagnostics'],90)
        toolbar.arrows=self:CreateWorkbenchButton(control.frame,L['Arrow test'],90)
        toolbar.input=self:CreateWorkbenchButton(control.frame,L['Input test'],90)
        for _,button in ipairs({toolbar.diagnostics,toolbar.arrows,toolbar.input}) do button:SetHeight(22);button:SetFrameLevel(control.frame:GetFrameLevel()+30);button:GetFontString():SetWordWrap(false) end
        self:SetUIScript(toolbar.diagnostics,'OnClick',function()
            if not activeControl(control) then return end
            addon.luaInputEditor=control;addon:ShowLuaEditorInputReport()
        end)
        self:SetUIScript(toolbar.arrows,'OnClick',function()
            if not activeControl(control) then return end
            addon.luaInputEditor=control;addon:ShowLuaEditorArrowProbe()
        end)
        self:SetUIScript(toolbar.input,'OnClick',function()
            if not activeControl(control) then return end
            addon.luaInputEditor=control;addon:ShowLuaInputProbe()
        end)
        control.frame:HookScript('OnSizeChanged',function() control:LayoutInputDiagnostics() end)
    end
    function control:LayoutInputDiagnostics(width)
        local toolbar=self.inputDiagnosticsToolbar;local buttonWidth=math.min(90,math.max(1,((width or self.frame:GetWidth())-56)/3))
        if toolbar.buttonWidth==nil or math.abs(toolbar.buttonWidth-buttonWidth)>.1 then
            toolbar.buttonWidth=buttonWidth
            for _,button in ipairs({toolbar.diagnostics,toolbar.arrows,toolbar.input}) do button:SetWidth(buttonWidth);button:GetFontString():SetWidth(math.max(1,buttonWidth-8)) end
            toolbar.diagnostics:ClearAllPoints();toolbar.diagnostics:SetPoint('BOTTOMRIGHT',self.frame,'TOPRIGHT',-2*(buttonWidth+4),0)
            toolbar.arrows:ClearAllPoints();toolbar.arrows:SetPoint('BOTTOMRIGHT',self.frame,'TOPRIGHT',-buttonWidth-4,0)
            toolbar.input:ClearAllPoints();toolbar.input:SetPoint('BOTTOMRIGHT',self.frame,'TOPRIGHT',0,0)
        end
        buttonWidth=toolbar.buttonWidth;toolbar.width=buttonWidth*3+16
        local compact=buttonWidth<78;local probe=self.nativeArrowProbe~=nil
        local diagnosticLabel=compact and L['Info'] or L['Diagnostics']
        local inputLabel=compact and L['Test'] or L['Input test']
        if toolbar.input:GetText()~=inputLabel then toolbar.input:SetText(inputLabel) end
        local arrowLabel=probe and (compact and L['On'] or L['Arrows: on']) or (compact and L['Arrows'] or L['Arrow test'])
        if toolbar.diagnostics:GetText()~=diagnosticLabel then toolbar.diagnostics:SetText(diagnosticLabel) end
        if toolbar.arrows:GetText()~=arrowLabel then toolbar.arrows:SetText(arrowLabel) end
        if toolbar.probe~=probe then toolbar.probe=probe;toolbar.arrows:SetSelected(probe) end
        toolbar.input.tooltip=L['Input test']
        toolbar.diagnostics.tooltip=L['Show input diagnostics for this open Lua editor.']
        toolbar.arrows.tooltip=probe and L['Temporary native arrow test enabled. Click to restore the editor hook.'] or L['Temporarily remove the editor arrow hook to test native navigation.']
    end
    function control:ResetNativeArrowProbe()
        local probe=self.nativeArrowProbe;self.nativeArrowProbe=nil
        if probe and probe.edit==self.edit and probe.edit:GetScript('OnArrowPressed')==nil then probe.edit:SetScript('OnArrowPressed',probe.handler) end
        self:LayoutInputDiagnostics()
    end
    function control:ToggleNativeArrowProbe()
        if self.released or type(self.valid)~='function' then return nil end
        local ok,valid=pcall(self.valid);if not ok or not valid then return nil end
        if self.nativeArrowProbe then self:ResetNativeArrowProbe();return false end
        self.nativeArrowProbe={edit=self.edit,handler=self.edit:GetScript('OnArrowPressed')}
        self.edit:SetScript('OnArrowPressed',nil);self:LayoutInputDiagnostics();return true
    end
    -- End the old lease before completion/provider release or acquisition
    -- replaces handlers. Never restore the old probe over a newer hook.
    if not control.arrowProbeLifecycle then
        control.arrowProbeLifecycle=true
        for _,name in ipairs({'Release','Acquire'}) do
            local original=control[name]
            if original then control[name]=function(self,...) self:ResetNativeArrowProbe();return original(self,...) end end
        end
    end
    function control:ResetInputTrace() self:ResetNativeArrowProbe();self.inputTrace={};self.inputCounts={};self.inputPoll=nil;self.layoutCounts=nil;self.lineNumberCounts=nil end
    function control:ObserveInput(event,...)
        if self.released then return end
        local edit=self.edit;local raw=self.nativeGetText or edit.GetText
        local ok,value=pcall(raw,edit);local bytes=ok and type(value)=='string' and #value or -1
        local state='cursor='..read(edit,'GetCursorPosition')..' bytes='..bytes..' focus='..read(edit,'HasFocus')
        if event=='poll' and state==self.inputPoll then return end
        self.inputPoll=state;self.inputCounts[event]=(self.inputCounts[event] or 0)+1
        local detail=''
        if event=='OnCursorChanged' then
            local values={...};local coords={};for i=1,4 do coords[i]=type(values[i])=='number' and string.format('%.2f',values[i]) or '?' end;detail=' rect='..table.concat(coords,',')
        elseif event=='OnTextChanged' then detail=' user='..tostring((...))
        elseif event=='OnMouseDown' or event=='OnMouseUp' or event=='OnArrowPressed' then
            local value=(...);if type(value)=='string' and value:match('^[A-Za-z]+$') then detail=' key='..value end
        end
        self.inputTrace[#self.inputTrace+1]=event..' '..state..detail
        if #self.inputTrace>32 then table.remove(self.inputTrace,1) end
    end
    control:ResetInputTrace()
    for _,event in ipairs({'OnMouseDown','OnMouseUp','OnTextSet','OnTextChanged','OnCursorChanged','OnEditFocusGained','OnEditFocusLost','OnArrowPressed'}) do
        control.edit:HookScript(event,function(_,...) control:ObserveInput(event,...) end)
    end
    control.frame:HookScript('OnUpdate',function() control:ObserveInput('poll') end)
end
function addon:LuaEditorInputReport()
    local control=self.luaInputEditor
    if not control then return L['No native Lua editor has been opened this session.'] end
    local edit=control.edit;local lines={'Rotation Master native input diagnostics',
        'state='..(control.released and 'closed' or 'open')..' provider='..tostring(control.provider or 'native')..' highlighting='..tostring(control.provider=='LuaWorkbench' or control.syntax~=nil),
        'cursor='..read(edit,'GetCursorPosition')..' focus='..read(edit,'HasFocus'),
        'enabled='..read(edit,'IsEnabled')..' keyboard='..read(edit,'IsKeyboardEnabled')..' mouse='..read(edit,'IsMouseEnabled'),
        'arrowsRequireAlt='..read(edit,'GetAltArrowKeyMode')..' blink='..read(edit,'GetBlinkSpeed'),
        'width='..read(edit,'GetWidth')..' height='..read(edit,'GetHeight')..' alpha='..read(edit,'GetAlpha'),
        'font='..read(edit,'GetFont')..' scroll='..read(control.scroll,'GetVerticalScroll')}
    local mouse,keyboard
    if type(GetMouseFoci)=='function' then local ok,list=pcall(GetMouseFoci);if ok and type(list)=='table' then mouse=list[1] end
    elseif type(GetMouseFocus)=='function' then local ok,value=pcall(GetMouseFocus);if ok then mouse=value end end
    if type(GetCurrentKeyBoardFocus)=='function' then local ok,value=pcall(GetCurrentKeyBoardFocus);if ok then keyboard=value end end
    lines[#lines+1]='mouseFocus='..focusRole(mouse,control)
    lines[#lines+1]='keyboardFocus='..focusRole(keyboard,control)
    lines[#lines+1]='code visible='..read(control.frame,'IsVisible')..' shown='..read(control.frame,'IsShown')..' edit visible='..read(edit,'IsVisible')
    local owner,kind,matches=sourceOwner(self,control)
    lines[#lines+1]='matches source editor='..tostring(matches)..' session='..tostring(owner and owner.session or 'none')..' source editor='..(owner and (owner.closed and 'closed' or 'active') or 'none')..' source kind='..(kind or 'none')
    if control.released then lines[#lines+1]='Closed editor: historical trace; reopen the editor to capture active input.' end
    if control.provider=='LuaWorkbench' then
        lines[#lines+1]='native layout counters=unavailable (LuaWorkbench overlay)'
    else
        local layout=control.layoutCounts or {};lines[#lines+1]='layout calls='..tostring(layout.calls or 0)..' skips='..tostring(layout.skips or 0)..' editWidthWrites='..tostring(layout.width or 0)..' contentSizeWrites='..tostring(layout.content or 0)
        local origins={};for _,name in ipairs({'set-text','text-changed','owner-size','line-number-setting','direct'}) do origins[#origins+1]=name..'='..tostring(layout.origins and layout.origins[name] or 0) end
        lines[#lines+1]='layout origins='..table.concat(origins,' ')
        if layout.ownerWidth then lines[#lines+1]='last owner-size='..tostring(layout.ownerWidth)..'x'..tostring(layout.ownerHeight) end
    end
    lines[#lines+1]='arrowHook='..tostring(type(edit:GetScript('OnArrowPressed'))=='function')..' probe='..tostring(control.nativeArrowProbe~=nil)
    lines[#lines+1]='lineNumbers visible='..tostring(control.lineNumbersVisible)..' setting='..tostring(control.lineNumberSetting)
    local gutter=control.lineNumberCounts
    if gutter then
        lines[#lines+1]='gutter calls='..gutter.calls..' skips='..gutter.skips..' renders='..gutter.renders..' metricRebuilds='..gutter.metrics..' reentries='..gutter.reentries..' errors='..gutter.errors..' detached='..gutter.detached
        lines[#lines+1]='gutter last render keys='..(gutter.lastRender or 'none')
        lines[#lines+1]='gutter last metric keys='..(gutter.lastMetric or 'none')
    else lines[#lines+1]='gutter counters=unavailable' end
    local input=control.lineNumberInput;local state=input and (input.queryLineNumbers or input.queryLineNumberCache)
    local function frameInfo(label,frame)
        lines[#lines+1]='gutter '..label..' width='..read(frame,'GetWidth')..' height='..read(frame,'GetHeight')..' scale='..read(frame,'GetEffectiveScale')..' level='..read(frame,'GetFrameLevel')..' mouse='..read(frame,'IsMouseEnabled')..' bounds='..read(frame,'GetLeft')..','..read(frame,'GetRight')..','..read(frame,'GetTop')..','..read(frame,'GetBottom')
    end
    local function object(frame,method)
        if not frame or type(frame[method])~='function' then return nil end
        local ok,value=pcall(frame[method],frame);if ok then return value end
    end
    frameInfo('frame',state and state.gutter);frameInfo('container',control.frame);frameInfo('edit',edit);frameInfo('scroll',control.scroll)
    frameInfo('child',object(control.scroll,'GetScrollChild'));frameInfo('edit parent',object(edit,'GetParent'))
    local counts={};for event,count in pairs(control.inputCounts) do counts[#counts+1]=event..'='..count end;table.sort(counts)
    lines[#lines+1]=table.concat(counts,' ')
    for _,entry in ipairs(control.inputTrace) do lines[#lines+1]=entry end
    return table.concat(lines,'\n')
end
function addon:ShowLuaEditorInputReport()
    self:ShowConditionText(self:LuaEditorInputReport(),L['Lua input diagnostics'])
end

function addon:ShowLuaEditorArrowProbe()
    local control=self.luaInputEditor
    local enabled
    if control and control.ToggleNativeArrowProbe then enabled=control:ToggleNativeArrowProbe() end
    if enabled==nil then self:print(L['Open or reopen a Lua editor before using /rm editorarrows.'])
    elseif enabled then self:print(L['Temporary native arrow test enabled. Try up/down; run /rm editorarrows again to restore the editor hook.'])
    else self:print(L['Temporary native arrow test disabled; the editor hook is restored.']) end
end
