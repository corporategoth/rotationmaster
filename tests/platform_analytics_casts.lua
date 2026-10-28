-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Native boundary doubles only; normalization and reduction use real modules.
local passed,failed=0,0
local function test(name,fn)local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(e))end end
local function fixture(options)
 options=options or{};local f={now=100,calls=0,created=0,timers={},events={},scripts={},hooks={},secret={}}
 local function call(name,...)
  f.calls=f.calls+1;local h=f.hooks[name];if h then h(...)end
  if f.throw==name then error('PRIVATE_NATIVE_ERROR')end
 end
 local frame={}
 function frame:GetScript(k)call('GetScript',k);return f.scripts[k]end
 function frame:SetScript(k,v)call('SetScript',k,v);f.scripts[k]=v end
 function frame:IsEventRegistered(k)call('IsEventRegistered',k);return f.events[k]~=nil end
 function frame:RegisterEvent(k)call('RegisterEvent',k);f.events[k]=true end
 if not options.noUnit then function frame:RegisterUnitEvent(k,u)call('RegisterUnitEvent',k,u);assert(u=='player');f.events[k]=u end end
 function frame:UnregisterEvent(k)call('UnregisterEvent',k);f.events[k]=nil end
 local addon={Platform={}}
 function addon.Platform:GetClientInfo()call('client');return{family=options.family or'tbc',combatDataPolicy=options.policy or'probe',build='70006',interface=20506,version='2.5.6',locale='enUS',runtimeVerified=false}end
 function addon.Platform:CanReadValue(v)call('read',v);return not rawequal(v,f.secret)end
 function addon:ScheduleTimer(fn,d)call('ScheduleTimer',fn,d);local t={fn=fn,duration=d};f.timers[#f.timers+1]=t;if options.syncTimer then fn()end;return t end
 function addon:CancelTimer(t)call('CancelTimer',t);t.cancelled=true;return true end
 local env=setmetatable({GetTime=function()call('time');return f.now end,CreateFrame=function(kind)call('CreateFrame',kind);assert(kind=='Frame');f.created=f.created+1;return frame end},{__index=_G})
 for _,path in ipairs({'Analytics/replay.lua','Analytics/capture.lua','Platform/analytics_casts.lua'})do local fn=loadfile(path);assert(fn,'native receipt adapter missing');setfenv(fn,env);fn('rotationmaster',addon)end
 f.service=assert(addon.Analytics.NativeCasts,'native receipt API missing');f.frame=frame;f.addon=addon
 function f:emit(event,...)local fn=self.scripts.OnEvent;assert(fn,'no active event handler');fn(frame,event,...)end
 function f:start(opts)local l,why=self.service:Start(opts);assert(l,why);return l end
 function f:stop(l)local s,why=self.service:Stop(l);assert(s,why);return s end
 return f
end
local function rows(s)return assert(s.capture and s.capture.trace,'missing real builder trace').records end
local function unavailable(f,reason)local s=f.service:GetSnapshot();assert(s and s.status=='unavailable',s and s.status);if reason then assert(s.reason==reason,s.reason)end;assert(not s.capture or not s.capture.report);return s end
local function clean(f)assert(next(f.events)==nil and f.scripts.OnEvent==nil,'resources leaked')end
local function scan(v,needle)if type(v)=='string'then assert(not v:find(needle,1,true),'private value escaped')elseif type(v)=='table'then for k,x in pairs(v)do scan(k,needle);scan(x,needle)end end end

test('load and cached status are idle; unsupported families never subscribe',function()
 local f=fixture();assert(f.calls==0 and f.created==0);assert(f.service:GetStatus().phase=='idle');assert(f.service:GetSnapshot()==nil);assert(f.calls==0)
 for _,family in ipairs({'retail','era','progression','unknown'})do f=fixture({family=family});assert(f.service:Start()==nil);assert(f.created==0);clean(f)end
end)
test('explicit start owns one frame, eight player events, boundary events and one timer',function()
 local f=fixture();local l=f:start();assert(f.created==1 and#f.timers==1 and f.timers[1].duration==30);assert(f.events.UNIT_SPELLCAST_SENT=='player'and f.events.PLAYER_ENTERING_WORLD==true);assert(f.service:GetSnapshot()==nil);assert(f.service:Start()==nil);local s=f:stop(l);clean(f);assert(s.nativeAcceptance=='unverified'and s.runtimeVerified==false and s.status=='complete');assert(s.advice=='not-wired'and s.ordinary=='unavailable');assert(s.capture.report.agreement.percentage==nil);assert(s.capture.evidence.collection=='not-wired');f:start();assert(f.created==1)
end)
test('all eight tuple prefixes map literally; target and tails stay opaque',function()
 local f=fixture();local l=f:start();local poison=setmetatable({},{__index=function()error('TARGET_READ')end,__tostring=function()error('TARGET_STRING')end})
 f:emit('UNIT_SPELLCAST_SENT','player',poison,'PRIVATE_CAST',10,poison)
 local cases={{'UNIT_SPELLCAST_START','attempt','start'},{'UNIT_SPELLCAST_STOP','result','stop'},{'UNIT_SPELLCAST_SUCCEEDED','result','success'},{'UNIT_SPELLCAST_FAILED','result','failed'},{'UNIT_SPELLCAST_INTERRUPTED','result','interrupted'},{'UNIT_SPELLCAST_CHANNEL_START','attempt','start'},{'UNIT_SPELLCAST_CHANNEL_STOP','result','stop'}}
 for _,c in ipairs(cases)do f:emit(c[1],'player','PRIVATE_CAST',10,poison,poison)end
 local s=f:stop(l);local r=rows(s);assert(#r==8 and r[1].phase=='sent'and r[1].epoch==1);for i,c in ipairs(cases)do assert(r[i+1].type==c[2]);assert((r[i+1].phase or r[i+1].status)==c[3]);assert(r[i+1].castKind=='channel')end;for _,r0 in ipairs(r)do assert(r0.cast==1 and r0.time==0)end;scan(s,'PRIVATE_CAST');scan(s,'TARGET');clean(f)
end)
test('sent plus success and result-only remain unmodeled; nil identity remains zero',function()
 local f=fixture();local l=f:start();f:emit('UNIT_SPELLCAST_SUCCEEDED','player','a',7);f.now=101;f:emit('UNIT_SPELLCAST_SENT','player',{},'b',8);f:emit('UNIT_SPELLCAST_SUCCEEDED','player','b',8);f:emit('UNIT_SPELLCAST_START','player',nil,nil);local s=f:stop(l);local r=rows(s);assert(r[1].type=='result'and r[1].castKind=='unmodeled');assert(r[2].time==1 and r[4].cast==0 and r[4].spell==0);assert(s.capture.report.agreement.scorable==0)
end)
test('foreign readable units ignore opaque remaining fields; opaque unit stops coverage',function()
 local f=fixture();local l=f:start();f:emit('UNIT_SPELLCAST_START','pet',f.secret,f.secret);assert(#rows(f:stop(l))==0)
 f=fixture({noUnit=true});f:start();f:emit('UNIT_SPELLCAST_START',f.secret,'x',2);unavailable(f,'unreadable-value');clean(f)
end)
test('malformed and unreadable keys/spells cannot leak or become guessed identities',function()
 for _,case in ipairs({{'',1},{string.rep('x',129),1},{false,1},{'x',-1},{'x',1.5},{'x',math.huge},{'x','2'}})do local f=fixture();f:start();f:emit('UNIT_SPELLCAST_START','player',case[1],case[2]);unavailable(f,'invalid-payload');clean(f)end
 local f=fixture();f:start();f:emit('UNIT_SPELLCAST_START','player',f.secret,1);unavailable(f,'unreadable-value')
 f=fixture();f:start();f:emit('UNIT_SPELLCAST_START','player','x',f.secret);unavailable(f,'unreadable-value')
end)
test('time regression, nonfinite, opaque and delayed timer fail without clamping',function()
 for _,value in ipairs({99,0/0,math.huge,701})do local f=fixture();f:start();f.now=value;f:emit('UNIT_SPELLCAST_START','player','x',1);unavailable(f,'invalid-time');clean(f)end
 local f=fixture();f:start();f.now=f.secret;f:emit('UNIT_SPELLCAST_START','player','x',1);unavailable(f,'unreadable-value');clean(f)
 f=fixture();f:start({duration=600});f.now=701;f.timers[1].fn();unavailable(f,'invalid-time');clean(f)
end)
test('old handlers and timers are inert after stop, clear and restart',function()
 local f=fixture();local old=f:start();local handler=f.scripts.OnEvent;local timer=f.timers[1].fn;f:stop(old);local l=f:start();local count=f.calls;handler(f.frame,'UNIT_SPELLCAST_START',f.secret,f.secret,f.secret);timer();assert(f.calls==count);assert(f.service:Stop(old)==nil);f:emit('UNIT_SPELLCAST_START','player','new',1);assert(#rows(f:stop(l))==1);f.service:Clear();assert(f.service:GetSnapshot()==nil);clean(f)
end)
test('setup errors roll back; synchronous timer cannot commit a dead run',function()
 for _,name in ipairs({'CreateFrame','SetScript','RegisterUnitEvent','ScheduleTimer'})do local f=fixture();f.throw=name;assert(f.service:Start()==nil);assert(f.service:GetStatus().phase~='running');if name~='SetScript'then clean(f)end;scan(f.service:GetStatus(),'PRIVATE_NATIVE_ERROR')end
 local f=fixture({syncTimer=true});assert(f.service:Start()==nil);assert(f.service:GetStatus().phase~='running');clean(f)
end)
test('Clear reentry from native start calls cannot resurrect a capture',function()
 for _,name in ipairs({'client','read','time','CreateFrame','GetScript','SetScript','RegisterUnitEvent','IsEventRegistered','ScheduleTimer'})do local f=fixture();local fired=false;f.hooks[name]=function()if not fired then fired=true;f.service:Clear()end end;assert(f.service:Start()==nil,name);assert(f.service:GetStatus().phase~='running',name);clean(f)end
end)
test('Clear during receipt readability and stop clock cannot publish stale finalization',function()
 local f=fixture();f:start();local once=false;f.hooks.read=function()if not once then once=true;f.service:Clear()end end;f:emit('UNIT_SPELLCAST_START','player','x',1);assert(f.service:GetSnapshot()==nil);clean(f)
 f=fixture();local l=f:start();f.hooks.time=function()f.service:Clear()end;assert(f.service:Stop(l)==nil);assert(f.service:GetSnapshot()==nil);clean(f)
end)
test('foreign script replacement is preserved and prevents frame reuse',function()
 local f=fixture();local l=f:start();local other=function()end;f.scripts.OnEvent=other;f.service:Stop(l);assert(f.scripts.OnEvent==other);assert(f.service:Start()==nil);assert(f.created==1)
end)
test('builder pending and alias limits are inherited; no partial report survives',function()
 local f=fixture();f:start();for i=1,128 do f:emit('UNIT_SPELLCAST_START','player','p'..i,1);f:emit('UNIT_SPELLCAST_STOP','player','p'..i,1)end;f:emit('UNIT_SPELLCAST_START','player','overflow',1);unavailable(f,'pending-limit');clean(f)
 f=fixture();f:start();for i=1,1024 do f:emit('UNIT_SPELLCAST_FAILED','player','a'..i,1)end;f:emit('UNIT_SPELLCAST_FAILED','player','overflow',1);unavailable(f,'alias-limit')
end)
test('boundary events stop; inputs/status/snapshots detached and unrelated state untouched',function()
 local f=fixture();f.addon.db={profile={x=1}};f.addon.CPU={sentinel=true};local l=f:start();f:emit('PLAYER_CONTROL_LOST',f.secret);local s=f.service:GetSnapshot();assert(s.reason=='context');s.client.family='changed';assert(f.service:GetSnapshot().client.family=='tbc');local status=f.service:GetStatus();status.phase='fake';assert(f.service:GetStatus().phase~='fake');f.service:Clear();assert(f.addon.db.profile.x==1 and f.addon.CPU.sentinel);assert(f.service:Stop(l)==nil);clean(f)
end)
test('ambiguous timer registration and failed cancellation prohibit resource reuse',function()
 local f=fixture();f.throw='ScheduleTimer';assert(f.service:Start()==nil);f.throw=nil;assert(f.service:Start()==nil);assert(f.service:GetStatus().phase=='unusable')
 f=fixture();local l=f:start();f.addon.CancelTimer=function()return nil end -- captured original remains authoritative
 f.throw='CancelTimer';f.service:Stop(l);assert(f.service:Start()==nil);assert(f.created==1)
end)
test('expired timer completes once and permits one-frame restart',function()
 local f=fixture();f:start();f.now=130;f.timers[1].fn();local s=f.service:GetSnapshot();assert(s.status=='complete'and s.reason=='end'and s.capture.trace.duration==30);clean(f);f:start();assert(f.created==1)
end)
test('stop cleanup reserves ownership across Clear and nested Start',function()
 local f=fixture();local l=f:start();local tried=false
 f.hooks.time=function()f.hooks.time=nil;f.service:Clear();tried=true;assert(f.service:Start()==nil)end
 assert(f.service:Stop(l)==nil);assert(tried and f.service:GetSnapshot()==nil);clean(f);f:start();assert(f.created==1)
end)
test('exact thirty-second pending boundary and event payload cap remain builder-owned',function()
 local f=fixture();f:start({duration=100});for i=1,128 do f:emit('UNIT_SPELLCAST_START','player','k'..i,1)end;f.now=130;f:emit('UNIT_SPELLCAST_START','player','new',1);unavailable(f,'pending-limit')
 f=fixture();local l=f:start({duration=100});for i=1,128 do f:emit('UNIT_SPELLCAST_START','player','k'..i,1)end;f.now=130.001;f:emit('UNIT_SPELLCAST_START','player','new',1);assert(#rows(f:stop(l))==129)
 f=fixture();f:start();for i=1,3941 do f:emit('UNIT_SPELLCAST_FAILED','player',nil,1)end;f:emit('UNIT_SPELLCAST_FAILED','player',nil,1);unavailable(f,'payload-limit');clean(f)
end)
test('Stop reentry during a receipt preserves the completed snapshot and ignores remaining payload',function()
 local f=fixture();local l=f:start();local once=false
 f.hooks.read=function(v)if not once then once=true;f.service:Stop(l)end end
 f:emit('UNIT_SPELLCAST_START','player',f.secret,f.secret)
 local s=f.service:GetSnapshot();assert(s.status=='complete'and#rows(s)==0);clean(f)
end)
test('foreign receivers and malformed options cannot disturb an accepted run',function()
 local f=fixture();for _,v in ipairs({false,0,'30',{duration=0},{duration=601},{duration=false},{extra=true}})do assert(f.service:Start(v)==nil)end
 assert(f.calls==0);local l=f:start();assert(f.service.Start({},nil)==nil);assert(f.service.Stop({},l)==nil);assert(f.service.Clear({})==nil);assert(f.service:Stop({})==nil);assert(f.service:Stop(l,'BAD')==nil);assert(f.service:GetStatus().phase=='running');f:stop(l);clean(f)
end)
test('registration cannot silently commit without its exact owned event handler',function()
 local f=fixture();local other=function()end
 f.hooks.RegisterUnitEvent=function()f.scripts.OnEvent=other end
 assert(f.service:Start()==nil);assert(f.scripts.OnEvent==other);assert(f.service:GetStatus().phase=='unusable');assert(f.service:Start()==nil)
end)
test('opaque event identity is refused before native event-name comparisons',function()
 local f=fixture();f:start();f:emit(f.secret,f.secret,f.secret,f.secret);unavailable(f,'unreadable-value');clean(f)
end)
test('ambiguous frame creation cannot cause repeated allocation attempts',function()
 local f=fixture();f.throw='CreateFrame';assert(f.service:Start()==nil);local count=f.calls;f.throw=nil;assert(f.service:Start()==nil);assert(f.calls==count and f.created==0);assert(f.service:GetStatus().phase=='unusable')
end)
test('retired pre-frame Start cleanup cannot unregister an accepted replacement capture',function()
 local f=fixture();local newer
 f.hooks.client=function()f.hooks.client=nil;f.service:Clear();newer=f:start()end
 local old,why=f.service:Start();assert(old==nil and why=='retired-operation');assert(newer and f.service:GetStatus().phase=='running')
 assert(f.events.UNIT_SPELLCAST_START=='player'and f.events.PLAYER_CONTROL_LOST==true,'retired startup removed newer subscriptions')
 f:emit('UNIT_SPELLCAST_START','player','new',7);assert(#rows(f:stop(newer))==1);clean(f)
end)
test('frame and timer setup calls reserve cleanup ownership until their native return',function()
 for _,name in ipairs({'CreateFrame','GetScript','SetScript','IsEventRegistered','RegisterUnitEvent','RegisterEvent','ScheduleTimer'})do
  local f=fixture();local fired=false;local nested,why
  f.hooks[name]=function()if not fired then fired=true;f.service:Clear();nested,why=f.service:Start()end end
  assert(f.service:Start()==nil,name);assert(fired and nested==nil and why=='busy',name);assert(f.service:GetStatus().phase~='running');clean(f)
 end
end)
print(string.format('%d passed; %d failed',passed,failed));if failed>0 then os.exit(1)end
