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

-- Observe the native input path without replacing SetText, SetCursorPosition,
-- focus or keyboard handling. Reports contain state and counts, never source.
function addon:InstallLuaInputDiagnostics(control)
    self.luaInputEditor=control
    function control:ResetInputTrace() self.inputTrace={};self.inputCounts={};self.inputPoll=nil end
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
        'state='..(control.released and 'closed' or 'open')..' highlighting='..tostring(control.syntax~=nil),
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
    local owner=self.nativeCustomConditionDialog
    lines[#lines+1]='matches source editor='..tostring(owner and not owner.closed and owner.code==control)..' session='..tostring(owner and owner.session or 'none')
    local counts={};for event,count in pairs(control.inputCounts) do counts[#counts+1]=event..'='..count end;table.sort(counts)
    lines[#lines+1]=table.concat(counts,' ')
    for _,entry in ipairs(control.inputTrace) do lines[#lines+1]=entry end
    return table.concat(lines,'\n')
end
function addon:ShowLuaEditorInputReport()
    self:ShowConditionText(self:LuaEditorInputReport(),L['Lua input diagnostics'])
end
