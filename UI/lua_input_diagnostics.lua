local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function read(object,method)
    if not object or type(object[method])~='function' then return 'unavailable' end
    local ok,value=pcall(object[method],object)
    if not ok or type(value)~='string' and type(value)~='number' and type(value)~='boolean' then return 'unavailable' end
    return tostring(value)
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
    local counts={};for event,count in pairs(control.inputCounts) do counts[#counts+1]=event..'='..count end;table.sort(counts)
    lines[#lines+1]=table.concat(counts,' ')
    for _,entry in ipairs(control.inputTrace) do lines[#lines+1]=entry end
    return table.concat(lines,'\n')
end
function addon:ShowLuaEditorInputReport()
    self:ShowConditionText(self:LuaEditorInputReport(),L['Lua input diagnostics'])
end
