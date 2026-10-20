local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
-- Explicit, session-only native experiment; default gutters remain untouched.
local clippingArmed=false
local clippingGeneration={}
local clippingApplied={}
local function clippingValue(gutter)
    local ok,value=pcall(function() return gutter:DoesClipChildren() end)
    if ok and type(value)=='boolean' then return value end
end
local function clippingOwned(control,record)
    local input=control.lineNumberInput
    return input==record.input and record.state.gutter==record.gutter
        and (input.queryLineNumbers==record.state or input.queryLineNumberCache==record.state)
end
function addon:RestoreLuaGutterClippingProbe(control)
    local record=clippingApplied[control]
    if not record then return true end
    if record.restoring then return true end
    if not clippingOwned(control,record) then clippingApplied[control]=nil;return true end
    local generation,queue,released=clippingGeneration,control.lineNumberQueue,control.released
    local function current()
        return clippingApplied[control]==record and clippingGeneration==generation and clippingOwned(control,record)
            and control.lineNumberQueue==queue and control.released==released
    end
    -- Keep the baseline reserved during native callbacks. A reentrant new
    -- attachment may inherit it, rather than treating our false as native state.
    record.restoring=true
    local value=clippingValue(record.gutter)
    local setterOk,setter=pcall(function() return record.gutter.SetClipsChildren end)
    if current() and value~=record.original and value==false and setterOk and type(setter)=='function' then pcall(setter,record.gutter,record.original) end
    local restored=current() and clippingValue(record.gutter)==record.original
    record.restoring=nil
    if not current() then
        if clippingApplied[control]==record and clippingOwned(control,record) and (not clippingArmed or control.released) then
            record.restorePending=true;return nil,'clipping-restore-unavailable'
        end
        return true
    end
    if restored then clippingApplied[control]=nil;return true end
    record.restorePending=true;return nil,'clipping-restore-unavailable'
end
function addon:ApplyLuaGutterClippingProbe(control,state)
    if not clippingArmed then return end
    if type(control)~='table' or control.provider~='native' or control.engine or control.released then return end
    local input=control.lineNumberInput
    if not input or input.queryLineNumbers~=state or not state or not state.gutter then return end
    local generation,gutter,ownerValid=clippingGeneration,state.gutter,control.valid
    if type(ownerValid)~='function' then return end
    local function current()
        return clippingArmed and clippingGeneration==generation and not control.released and control.valid==ownerValid
            and control.lineNumberInput==input and input.queryLineNumbers==state and state.gutter==gutter
    end
    local validOk,valid=pcall(ownerValid);if not validOk or not valid or not current() then return end
    local previous=clippingApplied[control]
    local inherited
    if previous and previous.state==state and previous.gutter==state.gutter then
        if not previous.restoring then return end
        inherited=previous
    elseif previous and previous.restoring then return
    elseif not self:RestoreLuaGutterClippingProbe(control) or not current() then return end
    local count=0;for _ in pairs(clippingApplied) do count=count+1 end;if count>=8 and not inherited then return end
    local value=clippingValue(gutter)
    local setterOk,setter=pcall(function() return gutter.SetClipsChildren end)
    if value==nil or not setterOk or type(setter)~='function' or not current() then return end
    local original=value;if inherited then original=inherited.original end
    local record={input=input,state=state,gutter=gutter,original=original};clippingApplied[control]=record
    local ok=true
    if value then ok=pcall(setter,gutter,false) end
    if clippingApplied[control]~=record then return end
    if not ok or not clippingOwned(control,record) or control.released or clippingValue(record.gutter)~=false then self:RestoreLuaGutterClippingProbe(control) end
end
function addon:SetLuaGutterClippingProbe(enabled)
    if not rawequal(self,addon) or type(enabled)~='boolean' then return nil,'invalid-clipping-probe' end
    clippingArmed=enabled;clippingGeneration={}
    local generation,failed=clippingGeneration,nil
    if not enabled then for control in pairs(clippingApplied) do
        if clippingGeneration~=generation then return nil,'clipping-probe-superseded' end
        local restored=self:RestoreLuaGutterClippingProbe(control)
        if clippingGeneration~=generation then return nil,'clipping-probe-superseded' end
        if not restored then failed=true end
    end end
    if failed then return nil,'clipping-restore-unavailable' end
    return true
end
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

-- Reports contain counts, never source. Keep explicit diagnostic commands
-- available without adding temporary test controls to the editor chrome.
function addon:InstallLuaInputDiagnostics(control)
    self.luaInputEditor=control
    function control:ResetNativeArrowProbe()
        local probe=self.nativeArrowProbe;self.nativeArrowProbe=nil
        if probe and probe.edit==self.edit and probe.edit:GetScript('OnArrowPressed')==nil then probe.edit:SetScript('OnArrowPressed',probe.handler) end
    end
    function control:ToggleNativeArrowProbe()
        if self.released or type(self.valid)~='function' then return nil end
        local ok,valid=pcall(self.valid);if not ok or not valid then return nil end
        if self.nativeArrowProbe then self:ResetNativeArrowProbe();return false end
        self.nativeArrowProbe={edit=self.edit,handler=self.edit:GetScript('OnArrowPressed')}
        self.edit:SetScript('OnArrowPressed',nil);return true
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
    function control:ResetInputTrace()
        self:ResetNativeArrowProbe()
        self.inputTrace={};self.inputCounts={};self.inputPoll=nil;self.layoutCounts=nil;self.lineNumberCounts=nil
    end
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
    local clipping=clippingApplied[control]
    lines[#lines+1]='clipping probe armed='..tostring(clippingArmed)..' applied='..tostring(clipping~=nil and clippingOwned(control,clipping) and clippingValue(clipping.gutter)==false)..' restorePending='..tostring(clipping~=nil and clipping.restorePending==true)
    local input=control.lineNumberInput;local queue=control.lineNumberQueue
    local engine=control.engine or control.completionEngine;local console=engine and engine.Query and engine.Query.Console
    lines[#lines+1]='gutter queue=deferred pending='..tostring(queue~=nil and queue.pending==true)
    lines[#lines+1]='gutter attachment present='..tostring(queue~=nil)..' updaterMatch='..tostring(queue~=nil and console~=nil and console.UpdateLineNumbers==queue.update)
        ..' inputMatch='..tostring(console~=nil and console.input==input)..' editMatch='..tostring(queue~=nil and queue.edit==edit)
        ..' stateMatch='..tostring(queue~=nil and queue.state~=nil and input~=nil and queue.state==input.queryLineNumbers)
    if control.provider=='LuaWorkbench' then
        local painted=input and input.queryEditor;local source
        local ok,value=pcall(control.nativeGetText or edit.GetText,edit);if ok and type(value)=='string' then source=value end
        local function bytes(value) return type(value)=='string' and #value or -1 end
        local overlay=painted and painted.overlay;local overlayText
        if overlay and type(overlay.GetText)=='function' then local success,text=pcall(overlay.GetText,overlay);if success then overlayText=text end end
        lines[#lines+1]='provider render attached='..tostring(painted~=nil)..' pending='..tostring(painted~=nil and painted.pending==true)
            ..' sourceBytes='..bytes(source)..' renderBytes='..bytes(painted and painted.renderSource)..' sourceMatch='..tostring(source~=nil and painted~=nil and painted.renderSource==source)
            ..' renderedBytes='..bytes(painted and painted.renderedText)..' nativeText='..tostring(painted and painted.nativeText==true)
        lines[#lines+1]='overlay shown='..read(overlay,'IsShown')..' visible='..read(overlay,'IsVisible')..' alpha='..read(overlay,'GetAlpha')
            ..' bytes='..bytes(overlayText)..' width='..read(overlay,'GetWidth')..' height='..read(overlay,'GetHeight')
    end
    local gutter=control.lineNumberCounts
    if gutter then
        lines[#lines+1]='gutter calls='..gutter.calls..' flushes='..gutter.flushes..' skips='..gutter.skips..' renders='..gutter.renders..' metricRebuilds='..gutter.metrics..' reentries='..gutter.reentries..' errors='..gutter.errors..' detached='..gutter.detached
        lines[#lines+1]='gutter last render keys='..(gutter.lastRender or 'none')
        lines[#lines+1]='gutter last metric keys='..(gutter.lastMetric or 'none')
    else lines[#lines+1]='gutter counters=unavailable' end
    local state=input and (input.queryLineNumbers or input.queryLineNumberCache)
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
