-- Live condition dots on rotation, cooldown, Branch/Stop and switch cards
-- (UI/rotation_cards.lua, UI/rotation_editor.lua): the real evaluator, at
-- the General "Live Status Update Frequency" (profile.live_config_update),
-- only while the editor is open and visible; 0 turns the dots off.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function cond(tag) return {type=tag} end
local function body() return {name='Mine',switch=cond('SW'),
    rotation={{id='yes',type='spell',action=100,conditions=cond('YES')},{id='no',type='spell',action=100,conditions=cond('NO')},
        {id='odd',type='spell',action=100,conditions=cond('ODD')},{id='plain',type='spell',action=100,conditions={}},
        {id='stop',type='none',conditions=cond('YES')},
        {id='branch',type='branch',conditions=cond('NO'),onTrue={},onFalse={{id='inner',type='spell',action=100,conditions=cond('YES')}}},
        {id='forced',type='branch',mode='true',conditions=cond('NO'),onTrue={},onFalse={}}},
    cooldowns={{id='cd',type='spell',action=100,conditions=cond('YES')}}} end
local function fixture(interval)
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.nativeFrames=frames
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    a.db.profile.rotations={[0]={mine=body()}};a.configPaneGeneration=1;a.db.profile.live_config_update=interval
    function a:GetEditableRotation(spec,id) return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id] end
    function a:GetDefaultIdForRuntime(_,id) if id=='builtin' then return 'pack' end end
    function a:ListDefaultRotations() return {{id='pack',runtimeKey='builtin',name='Mine',description='Preview',enabled=true,envelope={body=body()}}} end
    function a:GetImportValidationOptions() return {} end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    -- The live state, the evaluator over it, and the timers.
    local live={YES='match',NO='no-match',ODD='unavailable',SW='match'};local evaluated=0
    function a:evaluateConditionResult(value,context)
        evaluated=evaluated+1;assert(type(context)=='table' and context.stepId~=nil,'no step context')
        local status=live[value.type] or 'match'
        if status=='unavailable' then return {status='unavailable',reason='target-unreadable'} end
        return {status=status}
    end
    function a:SwitchConditionMatchesNow(value) evaluated=evaluated+1;local s=live[value.type];if s=='unavailable' then return nil end;return s=='match' end
    local timers={}
    function a:ScheduleRepeatingTimer(fn,delay) local t={fn=fn,delay=delay};timers[#timers+1]=t;return t end
    function a:CancelTimer(t) t.cancelled=true end
    local clock=100;f.env.GetTime=function() return clock end
    for _,file in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/rotation_draft.lua','Data/validation.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_canvas.lua','UI/window.lua'}) do f.load(file) end
    for _,file in ipairs({'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do local h=io.open(file);if h then h:close();f.load(file) end end
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    local parent=create('Frame');parent:SetSize(740,600)
    local env={live=live,timers=timers,evaluated=function() return evaluated end,advance=function(s) clock=clock+s end}
    function env.running() local n=0;for _,t in ipairs(timers) do if not t.cancelled then n=n+1 end end;return n end
    function env.tick() for _,t in ipairs(timers) do if not t.cancelled then t.fn() end end end
    return f,parent,env
end
local function visibleCard(pane,id) for _,c in ipairs(pane.canvas.cards) do if c.model and c.model.id==id and c.frame:IsShown() then return c end end end
local function card(pane,id)
    local snapshot=pane.workspace:Snapshot();local section='rotation'
    for _,step in ipairs(snapshot.cooldowns or {}) do if step.id==id then section='cooldowns';break end end
    if pane.view.section~=section then pane:SelectContent(section) end
    return visibleCard(pane,id)
end
local function dot(c) return c.live:IsShown() and c.live.state end
local function color(c) local t=c.live.dot:GetTexture() or '';return t:match('Indicator%-(%a+)') end
local function hover(control) control.scripts.OnEnter(control);return control.lastTooltip end

test('dots show satisfied, not satisfied and unavailable with the reason; no condition shows nothing',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(env.running()==1 and env.timers[1].delay==2,'timer not started at the live update frequency')
    assert(dot(card(pane,'yes')).status=='satisfied' and color(card(pane,'yes'))=='Green','yes')
    assert(dot(card(pane,'no')).status=='unsatisfied' and color(card(pane,'no'))=='Red','no')
    local odd=card(pane,'odd');assert(dot(odd).status=='unavailable' and color(odd)=='Gray' and dot(odd).reason=='target-unreadable','odd')
    assert(not card(pane,'plain').live:IsShown(),'a card with no condition has a dot')
    assert(dot(card(pane,'stop')).status=='satisfied','Stop')
    assert(dot(card(pane,'branch')).status=='unsatisfied' and dot(card(pane,'inner')).status=='satisfied','Branch and its child')
    assert(not card(pane,'forced').live:IsShown(),'a forced branch (condition skipped) has a dot')
end)

test('the tooltip says the state, the reason and when it was checked',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local tips={}
    f.env.GameTooltip={SetOwner=function() end,SetText=function(_,text) tips[#tips+1]=text end,AddLine=function(_,text) tips[#tips+1]=text end,Show=function() end,Hide=function() end,IsOwned=function() return true end}
    env.advance(3)
    card(pane,'yes').live.scripts.OnEnter(card(pane,'yes').live)
    local text=table.concat(tips,'\n')
    assert(text:find('Currently satisfied') and text:find('Checked 3 seconds ago'),text)
    tips={};card(pane,'odd').live.scripts.OnEnter(card(pane,'odd').live)
    text=table.concat(tips,'\n');assert(text:find('Unavailable: target%-unreadable'),text)
    tips={};card(pane,'no').live.scripts.OnEnter(card(pane,'no').live)
    assert(table.concat(tips,'\n'):find('Not satisfied'))
end)

test('each tick re-evaluates; a changed state repaints the dot',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    env.live.NO='match';env.tick()
    assert(dot(card(pane,'no')).status=='satisfied','tick did not repaint')
    env.live.YES='unavailable';env.tick()
    assert(dot(card(pane,'yes')).status=='unavailable')
end)

test('cooldown cards get the dot where the arrows sit on rotation cards',function()
    local f,parent=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local _,_,_,rx,ry=card(pane,'yes').live:GetPoint()
    local cd=card(pane,'cd');local _,_,_,cx,cy=cd.live:GetPoint()
    assert(dot(cd).status=='satisfied','cooldown dot')
    assert(rx==cx and ry==cy,'cooldown dot not aligned: '..tostring(rx)..','..tostring(ry)..' vs '..tostring(cx)..','..tostring(cy))
end)

test('the switch condition has its own dot',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(pane.switchLive:IsShown() and pane.switchLive.state.status=='satisfied')
    env.live.SW='no-match';env.tick();assert(pane.switchLive.state.status=='unsatisfied')
    env.live.SW='unavailable';env.tick();assert(pane.switchLive.state.status=='unavailable')
end)

test('closing the editor cancels the timer; nothing is evaluated while closed',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local stale=env.timers[1].fn
    pane:Release()
    assert(env.running()==0,'timer survived the closed editor')
    local before=env.evaluated();stale();env.tick()
    assert(env.evaluated()==before,'a closed editor evaluated conditions')
    -- Reopening starts one timer again.
    assert(f.addon:CreateRotationEditor(parent,0,'mine'));assert(env.running()==1)
end)

test('a hidden editor stops its timer at the next tick',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    pane.frame:Hide();local before=env.evaluated();env.tick()
    assert(env.running()==0 and env.evaluated()==before,'hidden editor kept evaluating')
end)

test('0 turns the dots off: no timer, no evaluation, no dots',function()
    local f,parent,env=fixture(0)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(env.running()==0 and env.evaluated()==0)
    assert(not card(pane,'yes').live:IsShown() and not pane.switchLive:IsShown())
end)

test('changing the frequency restarts the open editor\'s timer; 0 clears the dots',function()
    local f,parent,env=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    f.addon.db.profile.live_config_update=5;f.addon:RestartLiveStatus()
    assert(env.running()==1 and env.timers[#env.timers].delay==5)
    f.addon.db.profile.live_config_update=0;f.addon:RestartLiveStatus()
    assert(env.running()==0 and not card(pane,'yes').live:IsShown())
    pane:Release();f.addon.db.profile.live_config_update=3;f.addon:RestartLiveStatus()
    assert(env.running()==0,'a closed editor got a timer')
end)

test('Built In read-only views get the dots',function()
    local f,parent=fixture(2)
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'))
    assert(pane.workspace.readOnly and dot(card(pane,'yes')).status=='satisfied')
end)

test('the dot tooltip names the advised step and shares the not-on-your-bars warning',function()
    local f,parent=fixture(2)
    local a=f.addon
    a.currentSpec=0;a.currentRotation='mine'
    a.GetRecentRecommendations=function() return {{rotation='mine',id='yes',spell=100}} end
    a.GetStepBinding=function(_,step) if step.id=='no' then return false end;return true end
    a.WatchButtonIndex=function() end
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    local tips={}
    f.env.GameTooltip={SetOwner=function() end,SetText=function(_,text) tips[#tips+1]=text end,AddLine=function(_,text) tips[#tips+1]=text end,Show=function() end,Hide=function() end,IsOwned=function() return true end}
    card(pane,'yes').live.scripts.OnEnter(card(pane,'yes').live)
    assert(table.concat(tips,'\n'):find('Rotation Master is advising this step now'),table.concat(tips,'\n'))
    tips={};card(pane,'no').live.scripts.OnEnter(card(pane,'no').live)
    assert(table.concat(tips,'\n'):find("Not on your action bars"),table.concat(tips,'\n'))
end)
test('the addon schedules no live-status timer of its own (zero cost with the editor closed)',function()
    local root=assert(io.popen('pwd'):read('*l'))
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace',root,true,root,true)({buttons=true,target=true,poll=.15})
    local scheduled={}
    local schedule=c.a.ScheduleRepeatingTimer
    c.a.ScheduleRepeatingTimer=function(self,method,delay,...) scheduled[#scheduled+1]=method;return schedule(self,method,delay,...) end
    c.a.db.profile.live_config_update=2;c.a.db.profile.enable=false
    c.e.GetAddOnMetadata=c.e.GetAddOnMetadata or function() return 'test' end
    c.a:OnEnable()
    for _,method in ipairs(scheduled) do assert(method~='UpdateCurrentCondition','OnEnable scheduled the live-status timer') end
    assert(c.a.conditionEvalTimer==nil,'a live-status timer is running with no editor open')
end)
finish()
