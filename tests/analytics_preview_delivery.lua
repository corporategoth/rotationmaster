local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture(historical)
 local diskLoad=loadfile
 local inverse=historical and dofile('tests/fixtures/restore_analytics_preview_delivery.lua')
 local restorePaths={['main.lua']=true,['UI/preview.lua']=true,['Platform/analytics_casts.lua']=true,['UI/analytics_capture.lua']=true}
 local loaded,loadedSources={},{}
 local function original(path)
  if restorePaths[path]then loaded[path]=inverse and'historical'or'candidate'end
  if inverse and restorePaths[path]then local source=inverse(read(path),path);loadedSources[path]=source;return assert(loadstring(source,'@'..path))end
  return diskLoad(path)
 end
 -- Preserve the exact actual-main fixture, only loading the real analytics
 -- modules at their production TOC position before main captures its handoff.
 loadfile=function(path)
  local chunk,why=original(path);if path~='main.lua' or not chunk then return chunk,why end
  return function(name,a)
   local env=getfenv(1)
   for _,p in ipairs({'Analytics/replay.lua','Analytics/capture.lua','Platform/analytics_casts.lua'})do local fn=assert(original(p));setfenv(fn,env);fn(name,a)end
   setfenv(chunk,env);return chunk(name,a)
  end
 end
 local ok,c=pcall(function()return dofile('tests/fixtures/rotation_execution.lua')({target=true})end);loadfile=diskLoad;assert(ok,c);c.loaded=loaded;c.loadedSources=loadedSources
 local load=c.load
 c.load=function(path)
  if restorePaths[path]then
   loaded[path]=inverse and'historical'or'candidate'
   local chunk=assert(original(path));setfenv(chunk,c.e);return chunk('rotationmaster',c.a)
  end
  return load(path)
 end
 local a,e=c.a,c.e;dofile('tests/fixtures/native_ui.lua')(e);c.frames={};local create=e.CreateFrame
 e.CreateFrame=function(...)
  local frame=create(...);frame.events={}
  function frame:RegisterEvent(event)self.events[event]=true end
  function frame:RegisterUnitEvent(event,unit)self.events[event]=unit end
  function frame:UnregisterEvent(event)self.events[event]=nil end
  function frame:IsEventRegistered(event)return self.events[event]~=nil end
  function frame:IsVisible()return self:IsShown() and(not self.parent or not self.parent.IsVisible or self.parent:IsVisible())end
  c.frames[#c.frames+1]=frame;return frame
 end
 a.SetUIScript=function(_,frame,event,fn)frame:SetScript(event,fn)end;c.load('UI/controls.lua');c.load('UI/preview.lua')
 a.db.profile.preview_spells=1;a:CreateNativePreviewWindow();c.window=a.nextWindow
 c.timers={};a.ScheduleTimer=function(_,fn,delay)local t={fn=fn,delay=delay};c.timers[#c.timers+1]=t;return t end
 a.CancelTimer=function(_,t)t.cancelled=true;return true end
 c.service=assert(a.Analytics.NativeCasts);c.now=100;e.GetTime=function()if c.clockHook then c.clockHook()end;return c.now end
 function c:start()local l,why=self.service:Start();assert(l,why);self.lease=l;return l end
 function c:stop()return assert(self.service:Stop(self.lease))end
 function c:rows()return self:stop().capture.trace.records end
 function c:emit(event,...)
  for _,f in ipairs(self.frames)do if f.events[event]then f:GetScript('OnEvent')(f,event,...)end end
 end
 return c
end
local function of(rows,kind)local out={};for _,r in ipairs(rows)do if r.type==kind then out[#out+1]=r end end;return out end

test('actual first publisher refreshes deduplicated advice and acknowledges only earlier real preview delivery',function()
 local c=fixture();c:start();c.tick();c.tick();local rows=c:rows();local a,p=of(rows,'advice'),of(rows,'presentation')
 assert(#a==2,'missing actual advice');assert(#p==2 and p[1].state=='visible'and p[1].adviceSeq==a[1].seq and p[1].seq>a[1].seq);assert(a[1].spell==c.a.currentSpell)
end)
test('hidden preview records no positive acknowledgement while advice remains observed',function()
 local c=fixture();c.window:Hide();c:start();c.tick();local rows=c:rows();assert(#of(rows,'advice')==1);for _,r in ipairs(of(rows,'presentation'))do assert(r.state~='visible')end
end)
test('public preview override cannot acknowledge source-owned delivery',function()
 local c=fixture();local original=c.window.AddRecommendation;c.window.AddRecommendation=function(...)return original(...)end;c:start();c.tick();local rows=c:rows();assert(#of(rows,'advice')==1);for _,r in ipairs(of(rows,'presentation'))do assert(r.state~='visible')end
end)
test('cast during glow precedes acknowledgement and never gains ordinary proof or score',function()
 local c=fixture();c.a.IsGlowing=function()return false end;c.a.GlowNextSpell=function()c:emit('UNIT_SPELLCAST_SENT','player','PRIVATE_TARGET','PRIVATE_GUID',403)end
 c:start();c.tick();c:emit('UNIT_SPELLCAST_SUCCEEDED','player','PRIVATE_GUID',403);local s=c:stop();local rows=s.capture.trace.records;local attempt=of(rows,'attempt')[1];local ack=of(rows,'presentation')[1]
 assert(attempt and ack and attempt.seq<ack.seq);assert(attempt.castKind=='unmodeled'and s.capture.report.agreement.scorable==0 and s.capture.report.agreement.percentage==nil)
end)
test('dependency invalidation before native attempt retires prior advice segment',function()
 local c=fixture();c:start();c.tick();c.a:InvalidateRotationDependencies('all');c:emit('UNIT_SPELLCAST_SENT','player','TARGET','KEY',403);local rows=c:rows();local r=of(rows,'retire');local attempt=of(rows,'attempt');assert(#r>=1 and r[#r].seq<attempt[1].seq)
end)
test('hide release disable and error explicitly retire existing capture advice',function()
 for _,how in ipairs({'Hide','Release','DisableRotation','StopAdviceForError'})do local c=fixture();c.a.RemoveAllCurrentGlows=function()end;c.a.DestroyAllGlows=function()end;c:start();c.tick();if how=='Hide'or how=='Release'then c.window[how](c.window)else c.a[how](c.a)end;assert(#of(c:rows(),'retire')>=1,how)end
end)
test('off capture adds no native queries and repeated report reads perform no producer calls',function()
 local c=fixture();c.tick();c.reset(true);c.tick();local before,order=c.snapshot();c.reset(false);c:start();c.tick();c:stop();c.reset(true);c.tick();local after,order2=c.snapshot();assert(#order==#order2);for i=1,#order do assert(order[i]==order2[i],i)end
end)
test('unknown display metadata and sample-only paint never acknowledge an actual action',function()
 local c=fixture();c.a.Platform.GetSpellInfo=function()return nil end;c:start();c.tick();local rows=c:rows();for _,r in ipairs(of(rows,'presentation'))do assert(r.state~='visible')end
 c=fixture();c.a.db.profile.preview_spells=0;c.a:SetPreviewSampleEnabled(true);c:start();c.window:PaintSamples();assert(#c:rows()==0)
end)
test('source body profile or window mutation is retired before an arriving native receipt',function()
 for _,kind in ipairs({'body','profile','window'})do local c=fixture();c:start();c.tick()
  if kind=='body'then local body=assert(c.a:GetEditableRotation(0,c.a.currentRotation));body.extra=true elseif kind=='profile'then c.a.db.profile={}else c.a.nextWindow={}end
  c:emit('UNIT_SPELLCAST_START','player','KEY',403);local rows=c:rows();local retired,attempt=of(rows,'retire'),of(rows,'attempt');assert(#retired>=1 and retired[#retired].seq<attempt[1].seq,kind)
 end
end)
test('no action publication retires prior recommendation instead of retaining coverage',function()
 local c=fixture();c:start();c.tick();c.a.FindSpell=function()return nil end;c.tick();assert(not c.a.currentSpell);assert(#of(c:rows(),'retire')>=1)
end)
test('throwing visibility observation fails capture without suppressing actual advice or retrying',function()
 local c=fixture();local n=0;c.window.frame.IsVisible=function()n=n+1;error('PRIVATE_VISIBILITY')end;c:start();c.tick();assert(c.a.currentSpell==403 and n==1 and not c.a.adviceErrorReport)
 local snapshot=c.service:GetSnapshot();assert(snapshot.status=='unavailable'and snapshot.reason=='native-error'and not snapshot.capture);assert(not tostring(snapshot.reason):find('PRIVATE',1,true))
 c.tick();assert(c.a.currentSpell==403 and n==1)
end)
test('clear and newer capture during visibility cannot attach stale acknowledgement to replacement',function()
 local c=fixture();local old=c.window.frame.IsVisible;local entered=false
 c.window.frame.IsVisible=function(self)if not entered then entered=true;c.service:Clear();c:start()end;return old(self)end
 c:start();c.tick();assert(c.a.currentSpell==403);local rows=c:rows();assert(#rows==0,'stale publication adopted by newer session')
end)
test('stop clear stale event and stale timer keep retired producer inert',function()
 local c=fixture();c:start();c.tick();local oldTimer=c.timers[1];local oldHandler
 for _,frame in ipairs(c.frames)do if frame.events.UNIT_SPELLCAST_SENT then oldHandler=frame:GetScript('OnEvent')end end
 local first=c:stop();c.tick();oldTimer.fn();assert(#c.service:GetSnapshot().capture.trace.records==#first.capture.trace.records)
 c:start();oldHandler(nil,'UNIT_SPELLCAST_START',{}, {}, {});c.tick();local s=c:stop();assert(#of(s.capture.trace.records,'advice')==1)
 c.service:Clear();c.tick();assert(c.service:GetSnapshot()==nil)
end)
test('existing copy report describes advice and delivery coverage while scoring remains unavailable',function()
 local c=fixture();c:start();c.tick();c:stop();c.load('UI/analytics_capture.lua');local shown;c.a.ShowConditionText=function(_,text)shown=text end;assert(c.a:RunCastCaptureAction('report'))
 assert(shown:find('Coverage rows: advice=1 presentation=1 visible=1',1,true),'missing producer coverage')
 assert(shown:find('Scoring: unavailable',1,true)and shown:find('ordinary-cast proof: not available',1,true));assert(not shown:find('PRIVATE',1,true))
end)
test('sixty seven real refreshes create coverage rather than ordinary opportunities',function()
 local c=fixture();c:start();for i=1,67 do c.tick()end;local s=c:stop();local rows=s.capture.trace.records;assert(#of(rows,'advice')==67 and#of(rows,'presentation')==67);assert(s.capture.report.agreement.scorable==0 and s.capture.report.agreement.percentage==nil)
end)
test('equal native timestamps preserve earlier receipt sequence and delivery cannot bootstrap old preview',function()
 local c=fixture();c.tick();c:start();assert(#c:rows()==0)
 c=fixture();c:start();c.tick();c:emit('UNIT_SPELLCAST_SENT','player','TARGET','KEY',403);c:emit('UNIT_SPELLCAST_SUCCEEDED','player','KEY',403);local rows=c:rows();local a,p,t=of(rows,'advice')[1],of(rows,'presentation')[1],of(rows,'attempt')[1];assert(a.time==p.time and p.time==t.time and a.seq<p.seq and p.seq<t.seq)
end)
test('accepted seventeen normalized historical receipts are not promoted retrospectively',function()
 local c=fixture();c:start()
 local seq={{1,547,'sent',2.716},{1,547,'start',2.716},{1,547,'success',5.3},{1,547,'stop',5.3},{2,547,'sent',6.076},{2,547,'start',6.076},{2,547,'success',8.573},{2,547,'stop',8.573},{3,8018,'sent',10.906},{3,8018,'success',10.906},{4,324,'sent',12.415},{4,324,'success',12.415},{5,547,'sent',16.332},{5,547,'start',16.332},{5,547,'success',18.837},{5,547,'stop',18.837},{6,547,'failed',21.031}}
 local events={sent='UNIT_SPELLCAST_SENT',start='UNIT_SPELLCAST_START',success='UNIT_SPELLCAST_SUCCEEDED',stop='UNIT_SPELLCAST_STOP',failed='UNIT_SPELLCAST_FAILED'}
 for _,r in ipairs(seq)do c.now=100+r[4];if r[3]=='sent'then c:emit(events[r[3]],'player','PRIVATE_TARGET','PRIVATE_GUID_'..r[1],r[2])else c:emit(events[r[3]],'player','PRIVATE_GUID_'..r[1],r[2])end end
 local s=c:stop();local rows=s.capture.trace.records;assert(#rows==17);for i,r in ipairs(rows)do assert(r.seq==i and r.cast==seq[i][1]and r.spell==seq[i][2]and r.castKind=='unmodeled'and(r.phase or r.status)==seq[i][3])end
 assert(s.capture.report.agreement.scorable==0 and s.capture.report.agreement.percentage==nil)
end)
test('strict additive inverse preserves complete producer predecessors and rejects unrelated edits',function()
 local inverse=dofile('tests/fixtures/restore_analytics_preview_delivery.lua')
 for _,path in ipairs({'main.lua','UI/preview.lua','Platform/analytics_casts.lua','UI/analytics_capture.lua'})do local now=read(path);local old=inverse(now,path);assert(old~=now);assert(not pcall(inverse,old,path)and not pcall(inverse,now..now,path)and not pcall(inverse,now..'-- unrelated',path))end
end)
test('stop or newer capture reentered from evidence clock never suppresses gameplay or publishes stale rows',function()
 for _,mode in ipairs({'stop','restart'})do local c=fixture();c:start();c.clockHook=function()local inside=false;for i=2,12 do local info=debug.getinfo(i,'S');if not info then break end;if info.source=='@Platform/analytics_casts.lua'then inside=true;break end end;if not inside then return end;c.clockHook=nil;if mode=='stop'then c:stop()else c.service:Clear();c:start()end end;c.tick();assert(c.a.currentSpell==403 and not c.a.adviceErrorReport)
  if mode=='stop'then assert(#c.service:GetSnapshot().capture.trace.records==0)else assert(#c:rows()==0)end
 end
end)
test('shutdown disarms producer before stale normal evaluator callbacks',function()
 local c=fixture();c:start();c.tick();c.load('UI/analytics_capture.lua');c.load('Diagnostics/cpu.lua');c.a:OnDisable();c.tick();assert(c.service:GetSnapshot()==nil and c.service:GetStatus().phase=='idle')
end)
test('resource overflow retires evidence without a partial score or stopping actual recommendation',function()
 local c=fixture();c:start();for i=1,4097 do if c.service:GetStatus().phase~='running'then break end;c:emit('UNIT_SPELLCAST_FAILED','player','same-key',403)end
 local s=c.service:GetSnapshot();assert(s.status=='unavailable'and(s.reason=='record-limit'or s.reason=='payload-limit')and not s.capture);c.tick();assert(c.a.currentSpell==403 and not c.a.adviceErrorReport)
end)
test('unreadable or malformed icon identity never supplies visible acknowledgement',function()
 local c=fixture();c.a.Platform.GetSpellInfo=function()return{iconID={}}end;c:start();c.tick();for _,r in ipairs(of(c:rows(),'presentation'))do assert(r.state~='visible')end
end)
test('diagnostic clock cannot let stale disable or error cleanup replace newer transition ownership',function()
 for _,method in ipairs({'DisableRotation','StopAdviceForError'})do local c=fixture();c.a.RemoveAllCurrentGlows=function()end;c.a.DestroyAllGlows=function()end;c:start();c.tick();local selected=c.a.currentRotation;c.clockHook=function()c.clockHook=nil;c.a:BeginActiveRotationTransition()end
  c.a[method](c.a);assert(c.a.currentRotation==selected and not c.a.adviceErrorReport,method)
 end
end)
test('preview retirement callback cannot release a newly reused owner generation',function()
 local c=fixture();c:start();c.tick();local generation=c.window.generation;c.clockHook=function()c.clockHook=nil;c.a:CreateNativePreviewWindow()end;c.window:Release();assert(c.window.active and c.window.generation>generation and c.window.frame:IsShown())
 c.service:Clear()
end)
test('reusing preview during metadata delivery does not acknowledge the interrupted owner generation',function()
 local c=fixture();local native=c.a.Platform.GetSpellInfo;local entered=false;c.a.Platform.GetSpellInfo=function(...)if not entered then entered=true;c.a:CreateNativePreviewWindow()end;return native(...)end
 c:start();c.tick();local rows=c:rows();for _,r in ipairs(of(rows,'presentation'))do assert(r.state~='visible')end
end)
test('custom validity or changed source method environment cannot certify owned preview delivery',function()
 for _,mode in ipairs({'valid','environment'})do local c=fixture();if mode=='valid'then c.window.Valid=function()return true end else local old=getfenv(c.window.AddRecommendation);local env={};for k,v in pairs(old)do env[k]=v end;setmetatable(env,getmetatable(old));setfenv(c.window.AddRecommendation,env)end
  c:start();c.tick();for _,r in ipairs(of(c:rows(),'presentation'))do assert(r.state~='visible',mode)end
 end
end)

local function hasUpvalue(fn,key)
 for i=1,100 do local name=debug.getupvalue(fn,i);if not name then break end;if name==key then return true end end
 return false
end
local predecessorPins={['main.lua']={86781,'5c9d4420'},['UI/preview.lua']={14343,'0e5de5c8'},['Platform/analytics_casts.lua']={14129,'27eda69e'},['UI/analytics_capture.lua']={8006,'239897df'}}
local function assertArm(c,old)
 assert(hasUpvalue(c.a.EvaluateNextActionInternal,'adviceCapture')==not old,'actual main source arm did not differ')
 assert(hasUpvalue(c.window.AddRecommendation,'previewCapture')==not old,'actual preview source arm did not differ')
 assert(hasUpvalue(c.service.Start,'arm')==not old,'actual collector source arm did not differ')
 if old then for path,pin in pairs(predecessorPins)do
  if path~='UI/analytics_capture.lua'then
   local source=assert(c.loadedSources[path]);local hash=0;for i=1,#source do hash=(hash*33+source:byte(i))%4294967296 end
   assert(#source==pin[1]and string.format('%08x',hash)==pin[2],'actual complete predecessor bytes '..path)
  end
 end end
end

test('capture off actual query and publication order is exact to complete63faccb predecessors',function()
 local traces={};for _,old in ipairs({true,false})do local c=fixture(old);assert(c.loaded['main.lua']==(old and'historical'or'candidate')and c.loaded['UI/preview.lua']==(old and'historical'or'candidate')and c.loaded['Platform/analytics_casts.lua']==(old and'historical'or'candidate'),'paired fixture arm mislabeled');assertArm(c,old);c.tick();c.reset(true);c.tick();local counts,order=c.snapshot();c.reset(false);traces[#traces+1]={counts=counts,order=order}end
 local a,b=traces[1],traces[2];assert(#a.order==#b.order);for i,v in ipairs(a.order)do assert(v==b.order[i],'off query order '..i)end;for k,v in pairs(a.counts)do assert(v==b.counts[k],k)end;for k,v in pairs(b.counts)do assert(v==a.counts[k],k)end
end)
for _,mode in ipairs({'sample','action','item','icon','icons','frame','texture','render','metadata','metadata-type','frame-method','icon-method','source-method','valid-method','environment'})do
 test('final visibility callback retires captured '..mode..' invariant',function()
  local c=fixture();local calls=0;local metadata;local sourceInfo=c.a.Platform.GetSpellInfo
  c.a.Platform.GetSpellInfo=function(...)metadata=sourceInfo(...);return metadata end
  local visible=c.window.frame.IsVisible
  c.window.frame.IsVisible=function(self)
   calls=calls+1
   if calls==4 then
    local icon=c.window.icons[1]
    if mode=='sample'then icon.sample=true
    elseif mode=='action'then icon.spellId=999999
    elseif mode=='item'then icon.itemId=123
    elseif mode=='icon'then c.window.icons[1]=self
    elseif mode=='icons'then c.window.icons={icon}
    elseif mode=='frame'then c.window.frame=c.e.CreateFrame('Frame',nil,c.e.UIParent)
    elseif mode=='texture'then icon.texture=self:CreateTexture(nil,'ARTWORK')
    elseif mode=='render'then icon.texture:SetTexture(metadata.iconID+1)
    elseif mode=='metadata'then metadata.iconID=metadata.iconID+1
    elseif mode=='metadata-type'then metadata.iconID={}
    elseif mode=='frame-method'then self.IsVisible=function()return true end
    elseif mode=='icon-method'then icon.IsVisible=function()return true end
    elseif mode=='source-method'then c.window.AddRecommendation=function()end
    elseif mode=='valid-method'then c.window.Valid=function()return true end
    else local old=getfenv(c.window.AddRecommendation);local env={};for k,v in pairs(old)do env[k]=v end;setmetatable(env,getmetatable(old));setfenv(c.window.AddRecommendation,env)end
   end
   return visible(self)
  end
  c:start();c.tick();assert(calls==4,'control missed final read: '..mode)
  c:emit('UNIT_SPELLCAST_SENT','player','PRIVATE_TARGET','PRIVATE_KEY',403)
  local rows=c:rows();local presentations=of(rows,'presentation');for _,r in ipairs(presentations)do assert(r.state~='visible','late mutation acknowledged: '..mode)end
  local retired,attempts=of(rows,'retire'),of(rows,'attempt');assert(#retired>=1 and retired[#retired].seq<attempts[1].seq,'late mutation not retired: '..mode)
 end)
end
test('actual fixture restores caller loader even when construction throws',function()
 local original=loadfile;local trap=function(path)if path=='main.lua'then error('FIXTURE_LOAD_FAILURE')end;return original(path)end
 loadfile=trap;local ok=pcall(fixture);local restored=loadfile==trap;loadfile=original
 assert(not ok and restored,'fixture loader escaped exception cleanup')
end)
test('final render read revalidates captured state without another visibility pass',function()
 local c=fixture();local icon=c.window:EnsureIcon(1);local original=icon.texture.GetTexture;local reads=0
 icon.texture.GetTexture=function(self)reads=reads+1;local value=original(self);if reads==2 then icon.sample=true end;return value end
 c:start();c.tick();local rows=c:rows();assert(reads==2 and#of(rows,'retire')>=1);for _,r in ipairs(of(rows,'presentation'))do assert(r.state~='visible')end
end)
test('throwing render observation retires capture without retrying or suppressing gameplay',function()
 local c=fixture();local icon=c.window:EnsureIcon(1);local calls=0;icon.texture.GetTexture=function()calls=calls+1;error('PRIVATE_RENDER')end
 c:start();c.tick();assert(c.a.currentSpell==403 and not c.a.adviceErrorReport and calls==1);local s=c.service:GetSnapshot();assert(s.status=='unavailable'and s.reason=='native-error'and not s.capture)
 c.tick();assert(calls==1 and c.a.currentSpell==403)
end)
test('retire then restore during final visibility read cannot acknowledge an old advice lease',function()
 local c=fixture();local calls=0;local original=c.window.frame.IsVisible
 c.window.frame.IsVisible=function(self)calls=calls+1;if calls==4 then c.window:Hide();c.window:Show()end;return original(self)end
 c:start();c.tick();local rows=c:rows();assert(calls==4 and#of(rows,'retire')>=1);assert(#of(rows,'presentation')==0,'retired advice lease acknowledged after restored geometry')
end)
finish()
