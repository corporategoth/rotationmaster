local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function nativeEdit(f,text)
    local edit=f.env.CreateFrame('EditBox',nil,f.env.UIParent)
    -- Native frame methods live on its type, so removing a per-instance
    -- syntax override reveals the original method again.
    local methods={GetText=edit.GetText,SetText=edit.SetText}
    edit.GetText,edit.SetText=nil,nil;setmetatable(edit,{__index=methods})
    function edit:GetMaxBytes() return self.maxBytes or 0 end
    function edit:SetMaxBytes(value) self.maxBytes=value end
    function edit:GetMaxLetters() return self.maxLetters or 0 end
    function edit:IsMultiLine() return self.multiLine end
    edit:SetMultiLine(true);edit:SetMaxBytes(120);edit:SetMaxLetters(90)
    edit:SetText(text);edit:SetCursorPosition(#text)
    return edit
end
test('native syntax engine loads and exposes its exact default without any Ace lookup',function()
    local f=F.new();f.env.LibStub=function(name) error('engine requested '..name) end
    f.load('LibsAugment/FAIAP.lua')
    local lib=assert(f.addon.LuaSyntax)
    assert(lib.indentCode('if true then\nprint(1)\nend',nil,nil)=='if true then\n  print(1)\nend')
    assert(type(lib.defaultColorTable)=='table' and lib.defaultColorTable[0]=='|r')
    assert(lib.addSmartCode==lib.enable)
end)
test('native syntax engine colors decodes disables and reuses an editbox without Ace',function()
    local f=F.new();f.env.LibStub=function(name) error('engine requested '..name) end
    local now=100;f.env.GetTime=function() return now end
    f.load('LibsAugment/FAIAP.lua');local lib=f.addon.LuaSyntax
    local edit=nativeEdit(f,'if true then\nprint("first")\nend');local events={}
    local changed=function() events.changed=(events.changed or 0)+1 end
    local tab=function() events.tab=(events.tab or 0)+1 end
    local update=function() events.update=(events.update or 0)+1 end
    edit:SetScript('OnTextChanged',changed);edit:SetScript('OnTabPressed',tab);edit:SetScript('OnUpdate',update)
    lib.enable(edit)
    assert(edit:GetText():find('\n  print("first")',1,true),'native default indentation changed')
    assert(lib.coloredGetText(edit):find('|c',1,true),'actual coloring did not run')
    assert(edit:GetMaxBytes()==0 and edit:GetMaxLetters()==0)
    edit:GetScript('OnTabPressed')(edit);assert(events.tab==1)
    edit:SetText('return "next"');edit:SetCursorPosition(3)
    edit:GetScript('OnTextChanged')(edit,true)
    now=101;edit:GetScript('OnUpdate')(edit,.3)
    assert(events.changed==1 and events.update==1 and edit:GetText():find('return "next"',1,true))
    assert(lib.coloredGetText(edit):find('|c',1,true),'update failed to color edited source')
    local decoded=edit:GetText();lib.disable(edit)
    assert(edit:GetText()==decoded and not edit:GetText():find('|c',1,true))
    assert(edit:GetMaxBytes()==120 and edit:GetMaxLetters()==90)
    assert(edit:GetScript('OnTextChanged')==changed and edit:GetScript('OnTabPressed')==tab and edit:GetScript('OnUpdate')==update)
    assert(rawget(edit,'GetText')==nil and rawget(edit,'SetText')==nil,'syntax methods leaked into released native owner')
    edit:SetText('if true then\nreturn 7\nend');lib.enable(edit,nil,3)
    assert(edit:GetText():find('\n   return 7',1,true),'reused editor retained prior indentation cache')
    lib.disable(edit);assert(edit:GetScript('OnTextChanged')==changed)
end)
finish()
