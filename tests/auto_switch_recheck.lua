-- Auto mode re-checks rotation selection every autoswitch_poll seconds, in
-- and out of combat; target/focus/pet changes check at once; 0 turns
-- automatic switching off. An unchanged selection leaves the plan alone.
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local root=assert(io.popen('pwd'):read('*l'))
local function fixture(combat)
 local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=combat,buttons=true,poll=.15})
 local a,e=c.a,c.e;local state={speed=0};e.GetUnitSpeed=function()return state.speed end
 local base=assert(a:GetEditableRotation(0,a.currentRotation));base.priority=500;base.switch={type='SPELL_KNOWN',spell=403}
 local id=assert(a:CloneDefaultRotation(0,'rm.tbc.shaman.starter','Moving selector',{scope='class'}))
 local body=assert(a:GetEditableRotation(0,id));body.priority=1000;body.switch={type='MOVING'}
 -- The fixture chose its rotation manually; return to Auto as a player would.
 a:HandleCommand('set auto');a:UpdateAutoSwitch();a:SwitchRotation();assert(not a.manualRotation,'fixture still manual')
 local function name()return a:GetRuntimeRotation(0,a.currentRotation).name end
 for _=1,4 do c.tick()end
 return c,a,state,name
end
for _,combat in ipairs({false,true})do
 test('a moving selector takes effect at the next re-check (combat='..tostring(combat)..')',function()
  local c,a,state,name=fixture(combat);assert(name()~='Moving selector','fixture started on the moving rotation')
  state.speed=7;for _=1,3 do c.tick()end;assert(name()~='Moving selector','action polling selected unexpectedly')
  a:AutoSwitchTick();assert(name()=='Moving selector','re-check did not select the matching rotation')
  state.speed=0;a:AutoSwitchTick();assert(name()~='Moving selector','re-check did not switch back')
 end)
end
test('a target change in combat checks at once',function()
 local c,a,state,name=fixture(true);state.speed=7;a:PLAYER_TARGET_CHANGED('PLAYER_TARGET_CHANGED')
 assert(name()=='Moving selector','target change in combat did not reselect')
end)
test('an unchanged selection neither calls SwitchRotation nor drops the lean plan',function()
 -- Reading the rotation through the public API starts a new observation; let
 -- the next poll rebuild once before counting.
 local c,a,_,name=fixture(true);for _=1,3 do c.tick()end;local before=name();c.tick()
 local built,polls=a.leanStats.built,a.leanStats.polls;local calls=0;local switch=a.SwitchRotation
 a.SwitchRotation=function(...)calls=calls+1;return switch(...)end
 for _=1,10 do c.tick();a:AutoSwitchTick()end
 assert(a.leanStats.built==built,'re-check rebuilt the lean plan '..(a.leanStats.built-built)..' times')
 assert(a.leanStats.polls-polls==10,'polls did not use the lean plan')
 assert(calls==0 and name()==before,'unchanged selection still went through SwitchRotation '..calls)
end)
test('interval 0 turns automatic switching off; manual choice is left alone',function()
 local c,a,state,name=fixture(true);local before=name();state.speed=7
 a.db.profile.autoswitch_poll=0;a:AutoSwitchTick();a:SwitchRotation();a:PLAYER_TARGET_CHANGED('PLAYER_TARGET_CHANGED');assert(name()==before,'interval 0 still switched')
 a.db.profile.autoswitch_poll=1;a.manualRotation=true;a:AutoSwitchTick();assert(name()==before,'manual choice was overridden')
end)
test('the retired Disable Auto-Switching flag migrates to interval 0',function()
 local _,a=fixture(false);local scheduled
 a.ScheduleRepeatingTimer=function(_,method,delay)scheduled={method=method,delay=delay};return scheduled end;a.CancelTimer=function(_,t)t.cancelled=true end
 a.db.profile.disable_autoswitch=true;a.db.profile.autoswitch_poll=1;scheduled=nil;a:StartAutoSwitchTimer()
 assert(a.db.profile.autoswitch_poll==0 and not a.db.profile.disable_autoswitch and scheduled==nil and a.autoSwitchTimer==nil)
 a.db.profile.autoswitch_poll=1.5;a:StartAutoSwitchTimer();assert(scheduled and scheduled.delay==1.5 and scheduled.method=='AutoSwitchTimer')
end)
print(pass..' passed, '..fail..' failed');if fail>0 then os.exit(1)end
