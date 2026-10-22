local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('UI/cpu_profile.lua');local a=f.addon
    local messages={};a.print=function(_,message) messages[#messages+1]=message end
    return a,messages
end
test('CPU controls start a bounded capture and report prerequisites without changing settings',function()
    local a,messages=fixture();local original=a.db.profile
    a.StartCPUProfile=function(_,duration) assert(duration==10);return false,'script-profile-disabled' end
    local ok,text=a:RunCPUProfileAction('start');assert(not ok and text:find('scriptProfile',1,true));assert(messages[#messages]==text and a.db.profile==original)
    a.StartCPUProfile=function(_,duration) assert(duration==10);return true end
    ok,text=a:RunCPUProfileAction('start');assert(ok and text:find('10',1,true));assert(a.db.profile==original)
end)
test('CPU report opens the shared copyable text window and cancellation stays explicit',function()
    local a,messages=fixture();local shown
    a.GetCPUProfileReport=function() return nil,'running' end
    local ok,text=a:RunCPUProfileAction('report');assert(not ok and text:find('running',1,true))
    a.GetCPUProfileReport=function() return 'measured function costs' end
    a.ShowConditionText=function(_,report,title) shown={report,title} end
    ok=a:RunCPUProfileAction('report');assert(ok and shown[1]=='measured function costs' and shown[2]=='CPU profile')
    a.CancelCPUProfile=function() return true end
    ok,text=a:RunCPUProfileAction('cancel');assert(ok and text:find('cancel',1,true))
    local count=#messages;a:OnCPUProfileFinished('report','complete');assert(#messages==count+1 and messages[#messages]:find('/rm perf cpu report',1,true))
    a:OnCPUProfileFinished('report','cancelled');assert(#messages==count+1,'cancel should not announce twice')
end)
test('unknown CPU commands show usage without starting or changing a capture',function()
    local a=fixture();a.StartCPUProfile=function() error('must not start') end
    local ok,text=a:RunCPUProfileAction('other');assert(not ok and text:find('/rm cpu',1,true))
end)
test('CPU reports reuse a themed movable window with copy and close controls',function()
    local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env)
    f.load('UI/condition_text.lua');f.load('UI/cpu_profile.lua');local a=f.addon
    a.GetCPUProfileReport=function() return 'one\ntwo\nthree' end
    assert(a:RunCPUProfileAction('report'));local d=a.conditionTextWindow
    assert(d.chrome and d.chrome.drag and d.chrome.background,'shared report must use dialog chrome')
    assert(d.edit:GetText()=='one\ntwo\nthree' and d.copy:GetText()=='Copy report')
    d.copy:Click();assert(d.edit.focused and d.edit.selection[2]==-1)
    d.close:Click();assert(not d.frame:IsShown())
    a:RunCPUProfileAction('report');assert(a.conditionTextWindow==d and d.frame:IsShown())
end)
finish()
