-- Real overlay renderer and scheduled callback; frame APIs are native stand-ins.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local h=assert(io.open('tests/buttons_namespaces.lua'));local source=h:read('*a');h:close()
local fixture=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture','@overlay-animation-fixture'))()
local writes={'ClearAllPoints','SetPoint','SetWidth','SetHeight','SetVertexColor','SetTexture','SetRotation'}
local function watch(object,name,counts)local original=assert(object[name]);object[name]=function(self,...)counts[name]=(counts[name]or 0)+1;return original(self,...)end end
local function setup(effect)
 local f,a,timers,button=fixture();local parent=button(73)
 a:Glow(parent,'dirty',effect,{r=.2,g=.3,b=.4,a=.5},1,'CENTER',0,0,.2)
 local overlay=assert(parent.rmOverlays.dirty);local timer=assert(overlay.sequenceTimer);local counts={}
 for _,name in ipairs({'ClearAllPoints','SetPoint','SetWidth','SetHeight'})do watch(overlay,name,counts)end
 for _,name in ipairs({'SetVertexColor','SetTexture','SetRotation'})do watch(overlay.texture,name,counts)end
 return {a=a,f=f,parent=parent,overlay=overlay,timer=timer,counts=counts,effect=effect,button=button,timers=timers,tick=function(n)for _=1,n or 1 do assert(timers.timers[timer]);timer.callback(unpack(timer.args))end end}
end
local function only(c,allowed,n)
 for _,name in ipairs(writes)do local expected=allowed[name]and n or 0;assert((c.counts[name]or 0)==expected,name..' wrote '..(c.counts[name]or 0)..' rather than '..expected)end
end
local function duplicate()return {type='animate',sequence={'A','A'},frequency=.1}end

test('rotate ticks write only the changing angle after first render',function()
 local c=setup({type='rotate',texture='A',steps=16,frequency=.1});c.tick(8);only(c,{SetRotation=true},8);assert(c.overlay.sequenceIdx==9)
end)
test('animate ticks write only each changed texture frame',function()
 local c=setup({type='animate',sequence={'A','B'},frequency=.1});c.tick(8);only(c,{SetTexture=true},8);assert(c.overlay.texture.texture=='A')
end)
test('dazzle ticks write only changing scalar tint channels',function()
 local c=setup({type='dazzle',texture='A',sequence={{r=1,g=0,b=0,a=1},{r=0,g=1,b=0,a=1}},frequency=.1});c.tick(8);only(c,{SetVertexColor=true},8)
end)
test('pulse geometry changes reassert all later legacy paint channels',function()
 local c=setup({type='pulse',texture='A',sequence={1,1.25},frequency=.1});c.tick(8);only(c,{SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},8);assert(c.overlay:GetWidth()==42 and c.overlay:GetHeight()==30)
end)
test('duplicate sequence values advance phase without native redraw',function()
 local c=setup(duplicate());c.tick(9);only(c,{},0);assert(c.overlay.sequenceIdx==2 and c.timers.timers[c.timer],'constant sequence lost timer or phase')
end)
test('live parent resizing reasserts dimensions and later legacy paint channels',function()
 local c=setup(duplicate());c.parent:SetSize(80,60);c.tick();only(c,{SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},1);assert(c.overlay:GetWidth()==80 and c.overlay:GetHeight()==60)
end)
test('in-place resolved color edits compare scalar channels rather than table identity',function()
 local c=setup(duplicate());c.timer.args[3].r=.8;c.tick();only(c,{SetVertexColor=true},1);assert(c.overlay.texture.color[1]==.8)
end)
test('changed offsets and parent identity repaint the remaining legacy channels',function()
 local c=setup(duplicate());local nextParent=c.button(74);c.overlay:SetParent(nextParent);c.timer.args[6]=4;c.tick();only(c,{ClearAllPoints=true,SetPoint=true,SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},1)
 assert(c.overlay.point[2]==nextParent and c.overlay.point[4]==4)
end)
test('in-place animation sequence edits preserve the next frame and write it once',function()
 local c=setup(duplicate());c.effect.sequence[2]='C';c.tick();only(c,{SetTexture=true},1);assert(c.overlay.texture.texture=='C')
end)
test('hidden parents retain phase and repaint only changed channels on timer callbacks',function()
 local c=setup({type='animate',sequence={'A','B'},frequency=.1});c.parent:Hide();c.tick(5);only(c,{SetTexture=true},5);assert(c.overlay.sequenceIdx==2)
 c.parent:Show();c.tick();assert(c.overlay.texture.texture=='A'and c.overlay.sequenceIdx==1 and c.timers.timers[c.timer])
end)
test('Stop and renewed Glow cancel the prior timer and force a complete first paint',function()
 local c=setup(duplicate());c.a:HideGlow(c.parent,'dirty');assert(not c.timers.timers[c.timer]and c.overlay.sequenceTimer==nil)
 c.a:Glow(c.parent,'dirty',duplicate(),{r=.2,g=.3,b=.4,a=.5},1,'CENTER',0,0,.2)
 only(c,{ClearAllPoints=true,SetPoint=true,SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},1)
 assert(c.parent.rmOverlays.dirty==c.overlay and c.overlay.sequenceTimer~=c.timer and c.overlay:IsShown())
end)
test('nil angle preserves prior rotation instead of forcing a new value',function()
 local c=setup(duplicate());local angle=c.overlay.texture.rotation;c.a:HideGlow(c.parent,'dirty');c.a:Glow(c.parent,'dirty',{type='texture',texture='C'},nil,1,'CENTER',0,0,nil)
 assert(c.overlay.texture.rotation==angle and (c.counts.SetRotation or 0)==0)
end)
test('Hide during native size callback cannot resume the cancelled old animation',function()
 local c=setup({type='pulse',texture='A',sequence={1,1.25},frequency=.1});local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.a:HideGlow(c.parent,'dirty')end end)
 c.tick();assert(once and not c.overlay:IsShown()and c.overlay.sequenceTimer==nil and next(c.timers.timers)==nil,'cancelled size callback rescheduled old animation')
end)
test('destroyed pooled overlay receives a full paint and new parent on reuse',function()
 local f,a,timers,button=fixture();local parent=button(73);f.env.ActionButton1=parent;a:Fetch();a.db.global.effects={DIRTY={type='animate',sequence={'A','A'},frequency=.1}}
 a:GlowCooldown(133,true,{id='upkeep',effect='DIRTY',color={r=.2,g=.3,b=.4,a=.5},magnification=1,setpoint='CENTER',xoffs=0,yoffs=0,angle=.2})
 local overlay=assert(parent.rmOverlays[133]);local oldTimer=assert(overlay.sequenceTimer);a:DestroyAllGlows();assert(not timers.timers[oldTimer]and overlay:GetParent()==f.env.UIParent)
 local counts={};for _,name in ipairs({'ClearAllPoints','SetPoint','SetWidth','SetHeight'})do watch(overlay,name,counts)end;for _,name in ipairs({'SetVertexColor','SetTexture','SetRotation'})do watch(overlay.texture,name,counts)end
 local nextParent=button(74);a:Glow(nextParent,'renewed',{type='texture',texture='A'},{r=.2,g=.3,b=.4,a=.5},1,'CENTER',0,0,.2)
 assert(nextParent.rmOverlays.renewed==overlay and overlay:GetParent()==nextParent and overlay:IsShown());only({counts=counts},{ClearAllPoints=true,SetPoint=true,SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},1)
end)
test('equal custom keyframes skip writes while later scalar style edits remain live',function()
 local c=setup({type='custom',frequency=.1,sequence={{texture='A',color={r=1,g=.5,b=.2,a=1},magnification=1,angle=30},{texture='A',color={r=1,g=.5,b=.2,a=1},magnification=1,angle=30}}})
 c.tick();only(c,{},0);c.effect.sequence[1].color.g=.8;c.tick();only(c,{SetVertexColor=true},1);assert(c.overlay.texture.color[2]==.8)
end)
test('newer Glow from a native size callback survives old animation continuation',function()
 local c=setup({type='pulse',texture='A',sequence={1,1.25},frequency=.1});local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.a:Glow(c.parent,'dirty',{type='texture',texture='NEW'},nil,1,'CENTER',0,0,.2)end end)
 c.tick();assert(once and c.overlay:IsShown()and c.overlay.texture.texture=='NEW'and c.overlay.sequenceTimer==nil and next(c.timers.timers)==nil,'old callback overwrote newer Glow or restarted its timer')
end)
test('native size callbacks keep later dimension and tint reads fresh in the same tick',function()
 local c=setup({type='pulse',texture='A',sequence={1,1.25},frequency=.1});local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.parent:SetHeight(80);c.timer.args[3].r=.9 end end)
 c.tick();assert(once and c.overlay:GetHeight()==100 and c.overlay.texture.color[1]==.9,'geometry or tint was prefetched across native size callback')
end)
test('native size reparenting refreshes the later parent dimension',function()
 local c=setup({type='pulse',texture='A',sequence={1,1.25},frequency=.1});local nextParent=c.button(74);nextParent:SetSize(70,90);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:SetParent(nextParent)end end)
 c.tick();assert(once and c.overlay:GetHeight()==112.5,'height read a parent captured before native size callback')
end)
test('anchor callbacks refresh later parent dimensions',function()
 local c=setup(duplicate());local nextParent=c.button(74);nextParent:SetSize(70,90);local point=c.overlay.SetPoint;local once=false
 c.overlay.SetPoint=function(self,...)point(self,...);if not once then once=true;self:SetParent(nextParent)end end
 c.timer.args[6]=4;c.tick();assert(once and c.overlay:GetWidth()==70 and c.overlay:GetHeight()==90,'dimensions read a parent captured before anchor callback')
end)
test('clearing anchors refreshes the parent before the new anchor is installed',function()
 local c=setup(duplicate());local nextParent=c.button(74);local clear=c.overlay.ClearAllPoints;local once=false
 c.overlay.ClearAllPoints=function(self,...)clear(self,...);if not once then once=true;self:SetParent(nextParent)end end
 c.timer.args[6]=4;c.tick();assert(once and c.overlay.point[2]==nextParent,'anchor used a parent captured before native clear callback')
end)
test('callback-adjusted native width is corrected on the next animation tick',function()
 local c=setup(duplicate());c.parent:SetWidth(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:SetWidth(70)end end)
 c.tick();assert(c.overlay:GetWidth()==70);c.tick();assert(c.overlay:GetWidth()==80,'requested width cache hid native callback mutation')
end)
test('callback-adjusted native height is corrected on the next animation tick',function()
 local c=setup(duplicate());c.parent:SetHeight(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once and c.overlay:GetHeight()==80 then once=true;c.overlay:SetHeight(70)end end)
 c.tick();assert(c.overlay:GetHeight()==70);c.tick();assert(c.overlay:GetHeight()==80,'requested height cache hid native callback mutation')
end)
test('height callback width changes are included in the final native size cache',function()
 local c=setup(duplicate());c.parent:SetHeight(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:SetWidth(70)end end)
 c.tick();assert(c.overlay:GetWidth()==70);c.tick();assert(c.overlay:GetWidth()==42,'later height callback hid native width mutation')
end)
test('width callback height changes are reasserted later in the same tick',function()
 local c=setup(duplicate());c.parent:SetWidth(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:SetHeight(70)end end)
 c.tick();assert(once and c.overlay:GetWidth()==80 and c.overlay:GetHeight()==30,'later legacy height write was skipped')
end)
test('native geometry callbacks cannot leave changed texture and tint behind',function()
 local c=setup(duplicate());c.parent:SetWidth(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay.texture:SetTexture('CALLBACK');c.overlay.texture:SetVertexColor(1,0,0,1);c.overlay.texture:SetRotation(.9)end end)
 c.tick();assert(once and c.overlay.texture.texture=='A'and c.overlay.texture.color[1]==.2 and c.overlay.texture.color[2]==.3 and c.overlay.texture.rotation==.2,'later legacy appearance writes were skipped')
end)
test('frames with native size scripts restore earlier anchor changes on the next tick',function()
 local c=setup(duplicate());c.parent:SetWidth(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:ClearAllPoints();c.overlay:SetPoint('TOP',c.parent,'TOP',9,9)end end)
 c.tick();assert(c.overlay.point[1]=='TOP');c.tick();assert(c.overlay.point[1]=='CENTER'and c.overlay.point[4]==0,'script-bearing frame kept a stale wanted anchor')
end)
test('removing a native size script forces one final legacy repaint',function()
 local c=setup(duplicate());c.parent:SetWidth(80);local once=false
 c.overlay:SetScript('OnSizeChanged',function()if not once then once=true;c.overlay:ClearAllPoints();c.overlay:SetPoint('TOP',c.parent,'TOP',9,9)end end)
 c.tick();assert(c.overlay.point[1]=='TOP');c.overlay:SetScript('OnSizeChanged',nil);c.tick();assert(c.overlay.point[1]=='CENTER','removed script left stale anchor')
 for key in pairs(c.counts)do c.counts[key]=nil end;c.tick();only(c,{},0)
end)
test('size script installation selects full legacy writes while it remains installed',function()
 local c=setup(duplicate());c.overlay:SetScript('OnSizeChanged',function()end);c.tick(3)
 only(c,{ClearAllPoints=true,SetPoint=true,SetWidth=true,SetHeight=true,SetVertexColor=true,SetTexture=true,SetRotation=true},3)
end)
finish()
