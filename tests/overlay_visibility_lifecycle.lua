-- Actual overlay code/timers; only native visibility propagation is modeled here.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local h=assert(io.open('tests/buttons_namespaces.lua'));local source=h:read('*a');h:close()
local fixture=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture','@overlay-visibility-fixture'))()
local function modelVisibility(env,existing)
 local frames={};local create=env.CreateFrame
 local function notify(change)
  local before={};local count=#frames;for i=1,count do before[i]=frames[i]:IsVisible()end
  change()
  for i=1,count do
   local frame=frames[i];local visible=frame:IsVisible()
   if visible~=before[i]then
    local event=visible and'OnShow'or'OnHide';local fn=frame:GetScript(event);if fn then fn(frame)end
    for _,hook in ipairs(frame.hooks and frame.hooks[event]or{})do hook(frame)end
   end
  end
 end
 local function decorate(frame)
  frames[#frames+1]=frame
  function frame:IsVisible()return self.visible and(not self.parent or self.parent:IsVisible())or false end
  function frame:Show()notify(function()self.visible=true end)end
  function frame:Hide()notify(function()self.visible=false end)end
  function frame:SetParent(parent)notify(function()self.parent=parent end)end
  return frame
 end
 decorate(existing)
 env.CreateFrame=function(...)return decorate(create(...))end
end
local function effect()return{type='animate',sequence={'A','B','C'},frequency=.1}end
local function setup(hidden)
 local f,a,timers,button=fixture();a.db.global.effects=a.db.global.effects or{};modelVisibility(f.env,f.env.UIParent)
 local parent=button(73);if hidden then parent:Hide()end
 return {f=f,a=a,timers=timers,parent=parent,button=button}
end
local function glow(c,config,color)
 c.a:Glow(c.parent,'owned',config or effect(),color or{r=.2,g=.3,b=.4,a=.5},1,'CENTER',0,0,.2)
 return assert(c.parent.rmOverlays.owned)
end
local function tick(c,overlay)
 local timer=assert(overlay.sequenceTimer,'visible animation timer missing');assert(c.timers.timers[timer]);timer.callback(unpack(timer.args));return timer
end
local function count(c)local n=0;for _ in pairs(c.timers.timers)do n=n+1 end;return n end

test('parent hide cancels timer and show resumes the preserved phase at next tick',function()
 local c=setup();local overlay=glow(c);local visible=overlay.IsVisible;local queries=0
 overlay.IsVisible=function(self)queries=queries+1;return visible(self)end
 local old=tick(c,overlay);assert(overlay.sequenceIdx==2 and queries==0,'visible tick queried native visibility')
 c.parent:Hide();assert(overlay.sequenceTimer==nil and not c.timers.timers[old],'hidden parent retained sequence timer');assert(overlay.sequenceIdx==2)
 local texture=overlay.texture.texture;old.callback(unpack(old.args));assert(overlay.sequenceIdx==2 and overlay.texture.texture==texture,'queued hidden tick advanced phase')
 c.parent:Show();local resumed=assert(overlay.sequenceTimer);assert(resumed~=old and count(c)==1 and overlay.sequenceIdx==2,'show repainted or duplicated timer')
 old.callback(unpack(old.args));assert(overlay.sequenceIdx==2,'old queued timer revived after resume')
 tick(c,overlay);assert(overlay.sequenceIdx==3 and overlay.texture.texture=='C')
end)
test('initial hidden glow paints once but creates no timer until native show',function()
 local c=setup(true);local overlay=glow(c);assert(overlay.sequenceIdx==1 and overlay.texture.texture=='A')
 assert(overlay.sequenceTimer==nil and count(c)==0,'initial hidden paint started timer')
 c.parent:Show();assert(overlay.sequenceTimer and count(c)==1 and overlay.sequenceIdx==1);tick(c,overlay);assert(overlay.sequenceIdx==2)
end)
test('direct overlay hide pauses without changing logical position',function()
 local c=setup();local overlay=glow(c);tick(c,overlay);overlay:Hide();assert(not overlay.sequenceTimer and overlay.sequenceIdx==2)
 overlay:Show();assert(overlay.sequenceTimer and overlay.sequenceIdx==2);tick(c,overlay);assert(overlay.sequenceIdx==3)
end)
test('explicit HideGlow while paused cannot be resurrected by parent show',function()
 local c=setup();local overlay=glow(c);local old=overlay.sequenceTimer;c.parent:Hide();c.a:HideGlow(c.parent,'owned');c.parent:Show()
 assert(not overlay.sequenceTimer and overlay.sequenceIdx==nil and not overlay:IsShown()and count(c)==0)
 old.callback(unpack(old.args));assert(count(c)==0 and overlay.sequenceIdx==nil,'old callback resurrected stopped glow')
end)
test('paused configuration replacement resumes only the fresh effect and color',function()
 local c=setup();local overlay=glow(c);local old=overlay.sequenceTimer;c.parent:Hide()
 assert(glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2},{r=.9,g=.8,b=.7,a=1})==overlay)
 assert(overlay.texture.texture=='NEW'and count(c)==0);c.parent:Show();old.callback(unpack(old.args));tick(c,overlay)
 assert(overlay.texture.texture=='NEXT'and overlay.texture.color[1]==.9 and count(c)==1)
end)
test('native hooks preserve existing show and hide handlers',function()
 local c=setup();local create=c.f.env.CreateFrame;local shows,hides=0,0
 c.f.env.CreateFrame=function(...)local frame=create(...);if select(1,...)=='Frame'then frame:SetScript('OnShow',function()shows=shows+1 end);frame:SetScript('OnHide',function()hides=hides+1 end)end;return frame end
 local overlay=glow(c);c.parent:Hide();c.parent:Show();assert(hides==1 and shows==1 and count(c)==1 and overlay.sequenceTimer,'native handlers overwritten')
end)
test('pause cancellation reentry preserves a newer glow configuration',function()
 local c=setup();local overlay=glow(c);local cancel=c.a.CancelTimer;local once=false
 c.a.CancelTimer=function(self,token)cancel(self,token);if not once then once=true;glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2})end end
 c.parent:Hide();assert(once and overlay.texture.texture=='NEW'and count(c)==0);c.parent:Show();tick(c,overlay)
 assert(overlay.texture.texture=='NEXT'and count(c)==1,'old pause overwrote newer animation')
end)
test('explicit stop cancellation reentry does not hide the newer same-key glow',function()
 local c=setup();local overlay=glow(c);local cancel=c.a.CancelTimer;local once=false
 c.a.CancelTimer=function(self,token)cancel(self,token);if not once then once=true;glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2})end end
 c.a:HideGlow(c.parent,'owned');assert(once and overlay:IsVisible()and overlay.texture.texture=='NEW'and count(c)==1,'older stop hid or erased newer glow');tick(c,overlay);assert(overlay.texture.texture=='NEXT')
end)
test('native show scheduling reentry cancels only the obsolete returned handle',function()
 local c=setup(true);local overlay=glow(c);local schedule=c.a.ScheduleRepeatingTimer;local once=false;local stale
 c.a.ScheduleRepeatingTimer=function(self,...)
  local token=schedule(self,...);if not once then once=true;stale=token;glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2})end;return token
 end
 c.parent:Show();assert(once and overlay.sequenceTimer~=stale and not c.timers.timers[stale]and count(c)==1,'older schedule replaced newer timer')
 stale.callback(unpack(stale.args));tick(c,overlay);assert(overlay.texture.texture=='NEXT')
end)
test('hide during scheduling cannot publish a timer into a paused overlay',function()
 local c=setup(true);local overlay=glow(c);local schedule=c.a.ScheduleRepeatingTimer;local once=false
 c.a.ScheduleRepeatingTimer=function(self,...)local token=schedule(self,...);if not once then once=true;c.parent:Hide()end;return token end
 c.parent:Show();assert(once and not overlay.sequenceTimer and count(c)==0,'hidden schedule retained timer');c.parent:Show();assert(count(c)==1);tick(c,overlay);assert(overlay.sequenceIdx==2)
end)
test('destroy and pooled reuse cannot restore an old hidden-parent animation',function()
 local c=setup();c.f.env.ActionButton1=c.parent;c.a:Fetch();c.a.db.global.effects.HIDDEN=effect()
 c.a:GlowCooldown(133,true,{id='hidden',effect='HIDDEN',color={r=1,g=0,b=0,a=1}})
 local old=assert(c.parent.rmOverlays[133]);local timer=assert(old.sequenceTimer);c.parent:Hide();c.a:DestroyAllGlows();assert(not old.sequenceTimer and old.sequenceIdx==nil)
 local nextParent=c.button(74);c.a:Glow(nextParent,'new',effect(),nil,1,'CENTER',0,0,.2);local reused=assert(nextParent.rmOverlays.new);assert(reused==old)
 c.parent:Show();timer.callback(unpack(timer.args));assert(reused:GetParent()==nextParent and count(c)==1);tick(c,reused);assert(reused.sequenceIdx==2)
end)
test('unchanged cooldown publisher neither restarts nor repaints an active timer',function()
 local c=setup();c.f.env.ActionButton1=c.parent;c.a:Fetch();c.a.db.global.effects.HIDDEN=effect();local style={id='same',effect='HIDDEN',color={r=1,g=0,b=0,a=1}}
 c.a:GlowCooldown(133,true,style);local overlay=assert(c.parent.rmOverlays[133]);local timer=assert(overlay.sequenceTimer);tick(c,overlay);local texture=overlay.texture.texture
 for i=1,8 do c.a:GlowCooldown(133,true,style)end
 assert(overlay.sequenceTimer==timer and count(c)==1 and overlay.sequenceIdx==2 and overlay.texture.texture==texture)
end)
test('outer Glow replacement yields to a newer glow from cancellation',function()
 local c=setup();local overlay=glow(c);local cancel=c.a.CancelTimer;local once=false
 c.a.CancelTimer=function(self,token)cancel(self,token);if not once then once=true;glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2})end end
 glow(c,{type='animate',sequence={'OLD','OUTER'},frequency=.3})
 assert(once and overlay.texture.texture=='NEW'and count(c)==1,'outer Glow overwrote newer cancellation replacement');tick(c,overlay);assert(overlay.texture.texture=='NEXT')
end)
test('destroy cancellation cannot pool or detach a newer same-key glow',function()
 local c=setup();c.f.env.ActionButton1=c.parent;c.a:Fetch();c.a.db.global.effects.HIDDEN=effect();c.a:GlowCooldown(133,true,{id='active',effect='HIDDEN'})
 local overlay=assert(c.parent.rmOverlays[133]);local cancel=c.a.CancelTimer;local once=false
 c.a.CancelTimer=function(self,token)cancel(self,token);if not once then once=true;self:Glow(c.parent,133,{type='animate',sequence={'NEW','NEXT'},frequency=.2},nil,1,'CENTER',0,0,.2)end end
 c.a:DestroyAllGlows();assert(once and c.parent.rmOverlays and c.parent.rmOverlays[133]==overlay and overlay:GetParent()==c.parent and overlay:IsVisible()and count(c)==1,'destroy detached or pooled newer glow');tick(c,overlay);assert(overlay.texture.texture=='NEXT')
end)
test('hide and reshow during scheduling publishes only the newer visible timer',function()
 local c=setup(true);local overlay=glow(c);local schedule=c.a.ScheduleRepeatingTimer;local once=false;local stale
 c.a.ScheduleRepeatingTimer=function(self,...)
  local token=schedule(self,...);if not once then once=true;stale=token;c.parent:Hide();c.parent:Show()end;return token
 end
 c.parent:Show();assert(once and overlay:IsVisible()and overlay.sequenceTimer and overlay.sequenceTimer~=stale and count(c)==1,'visible overlay lost its deferred resume')
 stale.callback(unpack(stale.args));tick(c,overlay);assert(overlay.sequenceIdx==2)
end)
test('pause visibility reentry cannot invalidate a newer glow configuration',function()
 local c=setup();local overlay=glow(c);local visible=overlay.IsVisible;local armed,once=false,false
 overlay:SetScript('OnHide',function()armed=true end)
 overlay.IsVisible=function(self)
  if armed and not once then once=true;glow(c,{type='animate',sequence={'NEW','NEXT'},frequency=.2})end
  return visible(self)
 end
 c.parent:Hide();assert(once and overlay.texture.texture=='NEW'and count(c)==0)
 c.parent:Show();assert(overlay.sequenceTimer and count(c)==1,'old pause invalidated the replacement configuration');tick(c,overlay)
 assert(overlay.texture.texture=='NEXT')
end)
finish()
