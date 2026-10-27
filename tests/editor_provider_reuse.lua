-- Real pinned providers; native frame creation is the external boundary.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua')
 f.env.C_AddOns={IsAddOnLoaded=function(name)return name=='!!!LuaWorkbench'end};f.env.IsAddOnLoaded=f.env.C_AddOns.IsAddOnLoaded
 local n=0;local make=f.env.CreateFrame;f.env.CreateFrame=function(...)n=n+1;return make(...)end
 return f,a,function()return n end
end
local function actual(c)return c.inner or c end
local function tick(c)
 c=actual(c);local frame=c.frame;local update=frame:GetScript('OnUpdate');if update then update(frame,.1)end
 for _,hook in ipairs(frame.hooks.OnUpdate or{})do hook(frame,.1)end
 local edit=c.edit;local updateEdit=edit:GetScript('OnUpdate');if updateEdit then updateEdit(edit,.1)end
end
local function context(id)return {kind='function',id=id,source={args={},returns={},bindings={}}}end
local function count(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
for _,provider in ipairs({'plain','native','LuaWorkbench'})do test(provider..' actual reusable inner settles across12leases',function()
 local f,a,frames=fixture();local owner={};local first,warm
 for i=1,12 do
  local c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,provider);local inner=actual(c)
  if first then assert(inner==first,'fresh engine')else first=inner end
  c.frame:Show();c:SetText('local a='..i..'\nreturn a');c:SetContext(context('owner'..i));tick(c);tick(c)
  local input=(inner.engine or inner.completionEngine).Query.Console.input
  assert(input.queryLineNumbers and #input.queryLineNumbers.positions==2,'missing deferred gutter')
  c:Release();if warm then assert(frames()==warm,'frames grew '..frames()..'/'..warm)else warm=frames()end
 end
 print('CONTROL',provider,'frames='..frames(),'leases=12','engines=1')
end)end
test('two explicit source hosts keep independent provider caches even same parent',function()
 local f,a,frames=fixture();local hosts={{},{}};local controls={{},{}};local providers={'plain','native','LuaWorkbench'}
 local warm
 for cycle=1,6 do
  for h,host in ipairs(hosts)do for _,provider in ipairs(providers)do
   local c=a:AcquireSourceLuaEditor(host,f.env.UIParent,function()end,function()return true end,provider)
   if controls[h][provider]then assert(controls[h][provider]==c,'host/provider recreation')else controls[h][provider]=c end
   c.frame:Show();c:SetReadOnly(false);c:SetText('return '..cycle);c:SetContext(context('host'..h..'-'..cycle));tick(c);c:Release()
  end end
  if warm then assert(frames()==warm,'switch grewframes')else warm=frames()end
 end
 for _,p in ipairs(providers)do assert(controls[1][p]~=controls[2][p])end
 print('CONTROL','twohosts','frames='..frames(),'switchcycles=6','knowncontrols=6')
end)
test('active repeated Acquire refreshes callback and valid without duplicate attach',function()
 local f,a,frames=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()error('old callback')end,function()return true end,'LuaWorkbench');local inner=actual(c)
 local n=0;c:Acquire(function()n=n+1 end,function()return true end);local before=frames()
 c.edit:SetText('a');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(n==1,'new callback not used')
 c:Acquire(function()error('invalid callback')end,function()return false end);c.edit:SetText('ab');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(n==1)
 assert(frames()==before and inner.engine.Query.Console.input.queryEditor)
 c:Release()
end)
test('release clears owner contexts source output maps and suppresses stale events/ticks',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()error('closedchange')end,function()return true end,'LuaWorkbench');local inner=actual(c);local e=inner.engine;local W=e.Workspace;local C=e.Query.Console
 assert(e.Automation.frame==nil,'embedded Automation is intentionally absent')
 local api=e.APIHelp;local oldEvent=api.events:GetScript('OnEvent');local calls=0;local oldLoad=api.Load;api.Load=function(...)calls=calls+1;return oldLoad(...)end
 c:SetText('return 91');c:SetContext(context('deletedOwner'));C.lines={'OLD OUTPUT'};C.characters=11;e.Navigation.history={{id='deletedOwner'}};e.Debugger.breakpoints.deletedOwner={[1]=true};inner.environment.OLD_OWNER={};e.Analysis:Get('OLD_SOURCE')
 c:Release();assert(inner.released and e.released and not inner.changed and not inner.valid() and not inner.closeRequested)
 assert(not next(W.db.snippets)and not next(W.db.drafts)and not next(e.Navigation.history)and not next(e.Debugger.breakpoints))
 assert(inner.context.testOwner==nil and e.rmContext==nil and inner.environment.OLD_OWNER==nil and C.source=='' and #C.lines==0 and count(e.Analysis.cache)==0)
 assert(api.events:GetScript('OnEvent')==nil and api.events.eventsCleared)
 api.pending=true;oldEvent(api.events,'PLAYER_REGEN_ENABLED');tick(c);assert(calls==0,'released event/tick did work')
 c:Acquire(function()end,function()return true end);local newEvent=api.events:GetScript('OnEvent');assert(newEvent and newEvent~=oldEvent)
 local before=calls;api.pending=true;oldEvent(api.events,'PLAYER_REGEN_ENABLED');assert(calls==before,'old event reactivated')
 c:SetText('return 92');c:SetContext(context('newOwner'));c.frame:Show();tick(c);assert(count(W.db.snippets)==1 and W.db.snippets.newOwner and not W.db.snippets.deletedOwner)
 c:Release()
end)
test('new scalar preferences readonly and source replace prior lease',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');c:SetReadOnly(true);c:SetText('old');c:SetContext(context('old'));c:Release()
 f.env.LuaWorkbench.db.options={autocomplete=false,autoIndent=false,indentWidth=2,outputLimit=10,arbitrary={}}
 c:Acquire(function()end,function()return true end);local inner=actual(c);local e=inner.engine
 assert(e.Workspace.db.options.autocomplete==false and e.Workspace.db.options.indentWidth==2 and e.Workspace.db.options.arbitrary==nil)
 c:SetReadOnly(false);c:SetText('return 3');c:SetContext(context('new'));c.frame:Show();tick(c)
 assert(c:GetText()=='return 3' and not e.Query.Console.input.readonly and c.edit:IsEnabled() and inner.context.id=='new')
 a.db.profile.lua_line_numbers=false;tick(c);assert(not inner.lineNumbersVisible);a.db.profile.lua_line_numbers=true;tick(c);tick(c);assert(inner.lineNumbersVisible)
 c:Release()
end)
test('foreign providers without Acquire and replaced factories remain fresh',function()
 local f,a=fixture();local calls=0;local function create(parent)calls=calls+1;local frame=f.env.CreateFrame('Frame',nil,parent);return {frame=frame,GetText=function()return ''end,SetText=function()end,Release=function(self)self.released=true;frame:Hide()end}end
 a:RegisterLuaEditorProvider('foreign',create);local owner={};local first=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'foreign');first:Release()
 local second=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'foreign');assert(second~=first and calls==2)
 a:RegisterLuaEditorProvider('foreign',function(parent)return create(parent)end);second:Release();local third=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'foreign');assert(third~=second and calls==3)
 third:Release()
end)
test('temporary runtime failure uses one native fallback and retries original reusable engine',function()
 local f,a,frames=fixture();local owner={};local c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local inner=actual(c);local write=inner.SetText;local warm
 for i=1,4 do
  if i>1 then c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'LuaWorkbench') end
  inner.SetText=function()error('temporary source failure')end;c:SetText('fallback'..i);assert(c.provider=='native' and c:GetText()=='fallback'..i)
  inner.SetText=write;c:Release();c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'LuaWorkbench')
  assert(actual(c)==inner and c.provider=='LuaWorkbench','original inner not retried')
  c.frame:Show();c:SetText('return 1');c:SetContext(context('live'));tick(c);c:Release()
  if warm then assert(frames()==warm,'fallback cycle leaked native frames')else warm=frames()end
 end
end)
test('availability and auto choose cached native then retry cached LWB without discarding either',function()
 local f,a,frames=fixture();local owner={};local available=true;f.env.C_AddOns.IsAddOnLoaded=function()return available end
 local c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'auto');local workbench=c;c:Release()
 available=false;c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'auto');assert(c.provider=='native');local fallback=c;c:Release();local warm=frames()
 for i=1,4 do available=true;c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'auto');assert(c==workbench);c:Release()
 available=false;c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'auto');assert(c==fallback);c:Release();assert(frames()==warm)end
end)

test('Ctrl-click navigation and diagnostic observer counts survive reattachment',function()
 local f,a=fixture();local calls=0;f.env.GetCursorPosition=function()return 0,0 end;f.env.IsControlKeyDown=function()return true end;a.NavigateLuaSymbol=function()calls=calls+1 end
 local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local inner=actual(c)
 local frameHooks=#inner.frame.hooks.OnUpdate;local editHooks=#inner.edit.hooks.OnMouseUp
 for i=1,3 do
  c.edit:GetScript('OnMouseUp')(c.edit,'LeftButton');assert(calls==i,'Ctrl-click lost on lease '..i)
  assert(#inner.frame.hooks.OnUpdate==frameHooks and #inner.edit.hooks.OnMouseUp==editHooks,'diagnostic/gutter hooks duplicated')
  c:Release();if i<3 then c:Acquire(function()end,function()return true end)end
 end
end)

test('foreign retained callbacks become inert before cleanup and stay retired after another lease',function()
 local f,a=fixture();local callbacks={};local counts=0
 a:RegisterLuaEditorProvider('foreignLease',function(parent,changed,valid)
  callbacks[#callbacks+1]={changed=changed,valid=valid};local frame=f.env.CreateFrame('Frame',nil,parent)
  return {frame=frame,GetText=function()return ''end,SetText=function()end,Release=function(self)changed('cleanup');assert(not valid(),'foreign cleanup sees retired owner');self.released=true end}
 end)
 local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()counts=counts+1 end,function()return true end,'foreignLease')
 local old=callbacks[1];old.changed('active');assert(counts==1);c:Release();assert(counts==1,'foreign cleanup executed old host callback');old.changed('late');assert(counts==1 and not old.valid())
 c:Acquire(function()counts=counts+10 end,function()return true end);old.changed('old');assert(counts==1);callbacks[2].changed('new');assert(counts==11);c:Release();assert(counts==11)
end)

test('changed constructor and inherited constructor retain fresh factory behavior with one getter',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local first=actual(c);local original=a.CreateLuaWorkbenchControl;c:Release()
 local calls=0;a.CreateLuaWorkbenchControl=function(self,...)calls=calls+1;return original(self,...)end
 c:Acquire(function()end,function()return true end);assert(actual(c)~=first and calls==1,'constructor override masked');c:Release()
 local getterCalls=0;local previous=actual(c);local inherited=a.CreateLuaWorkbenchControl;a.CreateLuaWorkbenchControl=nil
 setmetatable(a,{__index=function(_,key)if key=='CreateLuaWorkbenchControl'then getterCalls=getterCalls+1;return inherited end end})
 c:Acquire(function()end,function()return true end);assert(actual(c)~=previous and getterCalls==1 and calls==2,'inherited lookup order/count changed');c:Release()
end)

test('actual persisted breakpoint records and loaded ids are cleared across deleted entities',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local e=actual(c).engine;local db=e.Workspace.db
 for i=1,12 do
  if i>1 then c:Acquire(function()end,function()return true end)end
  local id='deleted-'..i;local text='local x='..i..'\nreturn x';c:SetText(text);c:SetContext(context(id))
  e.Debugger:ToggleBreakpoint(id,1,text)
  assert(db.debugBreakpoints[id] and db.debugBreakpoints[id].source==text and e.Debugger.loadedBreakpointRecords[id],'actual breakpoint not retained before close')
  c:Release()
  assert(not next(db.debugBreakpoints or{}),'persisted deleted source survived close')
  assert(not next(e.Debugger.loadedBreakpointRecords or{})and e.Debugger.breakpointDB==nil,'deleted load id/db survived close')
 end
end)

test('native Release retires owner before limited reset failure and still restores input',function()
 local f,a=fixture();local calls=0;local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()error('retired callback')end,function()return true end,'plain')
 c:SetText('old source');c:SetContext({id='old',testOwner={old=true}})
 local engine=c.completionEngine;engine.ResetLease=function()
  calls=calls+1;assert(c.released and c.changed==nil and not c.valid() and c.context==nil,'owner alive during limited reset');error('limited-reset-failure')
 end
 local ok,why=pcall(c.Release,c);assert(not ok and tostring(why):find('limited%-reset%-failure'),'reset failure was lost')
 assert(calls==1 and c.released and not c.frame:IsShown() and c.edit:GetText()=='' and c.changed==nil and c.context==nil,'failed reset stranded native control')
 c:Release();assert(calls==1,'Release retried retired cleanup')
end)
test('full Release retires callbacks and finishes event editor and source cleanup after debugger error',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function()error('old owner')end,function()return true end);local e=c.engine
 c:SetText('return 1');c:SetContext(context('old-error'));local event=e.APIHelp.events:GetScript('OnEvent')
 e.Debugger.Stop=function()assert(c.released and c.changed==nil and not c.valid(),'live callbacks at debugger Stop');error('stop-failure')end
 local ok,why=pcall(c.Release,c);assert(not ok and tostring(why):find('stop%-failure'),'first cleanup failure not returned')
 assert(not c.frame:IsShown() and e.released and e.APIHelp.events:GetScript('OnEvent')==nil and e.Query.Console.input.queryEditor==nil,'cleanup stopped early')
 assert(c.context.id==nil and not next(e.Workspace.db.snippets) and e.Query.Console.source=='','old source kept after failure')
 e.APIHelp.pending=true;event(e.APIHelp.events,'PLAYER_REGEN_ENABLED');assert(e.APIHelp.pending==true,'stale event ran after failed close')
end)
test('source host nested cleanup acquisition wins over the stale outer provider switch',function()
 local f,a=fixture();local owner={};local c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local e=actual(c).engine;local stop=e.Debugger.Stop;local latest;local once=false
 e.Debugger.Stop=function(self,...)
  if not once then once=true;latest=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'native');latest:SetText('nested owner')end
  return stop(self,...)
 end
 local result=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'plain')
 assert(result==latest and owner.code==latest and latest:GetText()=='nested owner' and not latest.released,'stale cleanup continuation overwrote nested control')
 latest:Release()
end)
test('source host nested factory acquisition retires the discarded outer control only',function()
 local f,a=fixture();local owner={};local latest;local released=0
 a:RegisterLuaEditorProvider('nestedFactory',function(parent)
  latest=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'plain');latest:SetText('newer source')
  return {frame=f.env.CreateFrame('Frame',nil,parent),GetText=function()return 'stale'end,SetText=function()end,Release=function(self)released=released+1;self.released=true end}
 end)
 local result=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'nestedFactory')
 assert(result==latest and owner.code==latest and latest:GetText()=='newer source' and not latest.released and released==1,'outer factory replaced/closed nested owner')
 latest:Release()
end)
test('foreign optional callback argument values remain unchanged and do not require valid',function()
 local f,a=fixture();local seen=0
 a:RegisterLuaEditorProvider('optionalCallbacks',function(parent,changed,valid)
  assert(changed==false and valid==nil,'optional callback constructor values changed');seen=seen+1
  return {frame=f.env.CreateFrame('Frame',nil,parent),GetText=function()return ''end,SetText=function()end,Release=function(self)self.released=true end}
 end)
 local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,false,nil,'optionalCallbacks');assert(c.provider=='optionalCallbacks' and seen==1);c:Release();c:Acquire(false,nil);assert(c.provider=='optionalCallbacks' and seen==2);c:Release()
end)
test('paused debugger closed session and per-entity inspector refs do not survive a lease',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function()end,function()return true end);c:SetText('local x=1\nreturn x');c:SetContext(context('debug-old'))
 assert(c:Debug() and c.engine.Debugger.paused,'actual debugger did not pause');local e=c.engine
 e.Inspector.refs.old={owner='old'};e.Inspector.root={value={old=true}};e.Inspector.history={{root=e.Inspector.root}};e.Inspector.target={source='old',input=e.Query.Console.input}
 c:Release();assert(not e.Debugger.armed and not e.Debugger.thread and not e.Debugger.environment and not e.Debugger.source and not e.Debugger.scriptId)
 assert(not next(e.Inspector.refs)and e.Inspector.root==nil and not next(e.Inspector.history or{})and e.Inspector.target==nil,'inspector kept former owner')
 c:Acquire(function()end,function()return true end);c:SetText('return 2');c:SetContext(context('debug-new'));tick(c);assert(c.context.id=='debug-new' and not e.Debugger.armed);c:Release()
end)

test('constructor override installed before first creation never gains owned reuse authority',function()
 local f,a=fixture();local original=a.CreateLuaWorkbenchControl;local calls=0
 a.CreateLuaWorkbenchControl=function(self,...)calls=calls+1;return original(self,...)end
 local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local first=c.inner;c:Release()
 c:Acquire(function()end,function()return true end);assert(c.inner~=first and calls==2,'foreign constructor pointer granted owned reuse');c:Release()
end)

test('active fallback Acquire refreshes current callbacks without reviving the failed provider lease',function()
 local f,a=fixture();local oldCalls,newCalls=0,0;local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()oldCalls=oldCalls+1 end,function()return true end,'LuaWorkbench')
 local failed=c.inner;local oldValid=failed.valid
 failed.SetText=function()error('fail source')end;c:SetText('fallback')
 assert(c.provider=='native' and oldValid()==false,'failed provider lease still live')
 c:Acquire(function()newCalls=newCalls+1 end,function()return true end)
 c.edit:SetText('new text');c.edit:GetScript('OnTextChanged')(c.edit,true)
 assert(newCalls==1 and oldCalls==0 and c.inner.valid()==true and oldValid()==false,'fallback did not acquire fresh callback authority');c:Release()
end)

test('released optional debugger snapshots output and inspector rows relinquish prior source data',function()
 local f,a=fixture();local create=f.env.CreateFrame
 f.env.CreateFrame=function(...)local frame=create(...);function frame:GetRight()return 600 end;function frame:SetNormalTexture()end;function frame:GetCenter()return 300,300 end;function frame:GetSize()return self:GetWidth(),self:GetHeight()end;return frame end
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function()end,function()return true end);local e=c.engine;local source='local x="OLD_PAYLOAD"\nreturn x'
 c:SetText(source);c:SetContext(context('old-panels'));tick(c);assert(c:Debug())
 e.DebugUI:ShowSourceSnapshot({id='old-panels',name='old',source=source},0,false)
 e.Navigation:SavedSnapshot({name='old',source=source},{position0=0})
 e.Inspector:Show({old={payload=source}},'old payload')
 e.Query.Console:Write(source);c:ShowDebugOutput()
 local overlay=e.Query.Console.input.queryEditor.overlay;assert(overlay:GetText()~='','actual source overlay was not painted')
 c:Release()
 assert(e.DebugUI.snapshotInput:GetText()=='' and e.Navigation.snapshotInput:GetText()=='' and c.outputWindow.input:GetText()=='' and overlay:GetText()=='','hidden native widgets retained previous payload')
 assert(e.DebugUI.snapshotRecord==nil and e.Inspector.root==nil and e.Inspector.target==nil and not next(e.Inspector.refs))
 for _,row in ipairs(e.Inspector.buttons)do assert(row.node==nil,'native inspector row retained previous values')end
 c:Acquire(function()end,function()return true end);c:SetText('return 7');c:SetContext(context('new-panels'));tick(c);assert(c:GetText()=='return 7');c:Release()
end)
test('native limited engine releases owner context without API subscriptions and binds new owner',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'native');local e=c.completionEngine
 c:SetContext({kind='condition',id='old-native',testOwner={owner='old'},bindFunction=function()error('old binding')end,source={fields={},bindings={}}})
 c:SetText('local OLD_NATIVE_SOURCE=1');tick(c)
 assert(e.rmContext and e.rmContext.id=='old-native');c:Release();assert(c.context==nil and e.rmContext==nil and c.symbolSignature==nil and e.released,'old limited context survived')
 assert((e.Query.Console.input.queryEditor.source or '')=='' and e.Query.Console.input.queryEditor.renderSource==nil and c.layoutInput==nil and c.readOnlyText==nil,'limited editor/geometry retained source payload')
 assert(e.APIHelp.events:GetScript('OnEvent')==nil and not e.Automation.frame)
 c:Acquire(function()end,function()return true end);c:SetContext(context('new-native'));assert(e.rmContext.id=='new-native' and not e.released and e.APIHelp.events:GetScript('OnEvent')==nil);c:Release()
end)

test('released native context menu rows drop captured source insertion actions',function()
 local f,a=fixture();f.env.IsMouseButtonDown=function()return false end;f.env.GetCursorPosition=function()return 0,0 end
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function()end,function()return true end);c:SetText('local old_source=1\nreturn old_source');c:SetContext(context('old-menu'))
 local e=c.engine;e.Snippets:OpenCodeMenu(e.Query.Console.input);local menu=e.Workspace.contextMenu;local action=menu.buttons[1].action
 assert(type(action)=='function','actual source menu missing');c:Release()
 assert(not menu:IsShown() and menu.buttons[1].action~=action,'native menu kept captured source action')
 menu.buttons[1].action();assert(e.Query.Console.source=='','retired menu mutated source')
end)


test('active foreign refresh ignores noncallable optional Acquire metadata',function()
 for _,metadata in ipairs({'label',{}})do
  local f,a=fixture();local calls,newCalls=0,0;local signal
  a:RegisterLuaEditorProvider('foreignMetadata',function(parent,changed)
   calls=calls+1;signal=changed
   return {frame=f.env.CreateFrame('Frame',nil,parent),Acquire=metadata,GetText=function()return 'source'end,SetText=function()end,Release=function(self)self.released=true end}
  end)
  local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()error('old callback')end,function()return true end,'foreignMetadata')
  c:Acquire(function()newCalls=newCalls+1 end,function()return true end);signal('source')
  assert(calls==1 and newCalls==1 and c:GetText()=='source','foreign active control was recreated or lost callback');c:Release()
 end
end)

test('released LWB Acquire recovers actual layout work after a failed context layout',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local inner=c.inner;local layout=inner.engine.DebugUI.Layout
 inner.engine.DebugUI.Layout=function()error('failed context layout')end;c:SetContext(context('failed-layout'));assert(c.provider=='native' and inner.layingOut==true,'actual layout failure/fallback missing')
 inner.engine.DebugUI.Layout=layout;c:Release();c:Acquire(function()end,function()return true end)
 assert(c.inner==inner and c.provider=='LuaWorkbench','owned engine retry missing');inner.frame:SetSize(401,215)
 assert(not inner.layingOut and inner.layoutWidth==401 and inner.engine.Query.Console.input.frame:GetWidth()==401,'failed guard disabled future layout');c:Release()
end)
test('released native Acquire recovers actual measuring after a failed native layout',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'plain');local measure=c.measure.SetText
 c.measure.SetText=function()error('failed native measurement')end;local ok=pcall(c.SetText,c,'old source');assert(not ok and c.layingOut==true,'actual native layout failure missing')
 c.measure.SetText=measure;c:Release();c:Acquire(function()end,function()return true end);c.frame:SetSize(501,333)
 assert(not c.layingOut and c.layoutInput and c.layoutInput.width==501,'native failed guard disabled later geometry');c:Release()
end)

test('active acquisition preserves an in-progress native or LWB layout guard',function()
 local f,a=fixture()
 for _,provider in ipairs({'plain','LuaWorkbench'})do
  local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,provider);local inner=c.inner or c
  inner.layingOut=true;c:Acquire(function()end,function()return true end)
  assert(inner.layingOut==true,'active refresh cleared a live layout guard');inner.layingOut=nil;c:Release()
 end
end)

test('native text events preserve active readonly protection and leave released buffers empty',function()
 for _,provider in ipairs({'plain','native'})do
  local f,a=fixture();local enables=0
  if provider=='native' then
   f.load('LibsAugment/FAIAP.lua');local enable=a.LuaSyntax.enable
   a.LuaSyntax.enable=function(edit,...)
    enables=enables+1
    local methods={GetText=edit.GetText,SetText=edit.SetText};setmetatable(edit,{__index=methods})
    function edit:GetMaxBytes()return self.maxBytes or 0 end;function edit:SetMaxBytes(v)self.maxBytes=v end;function edit:GetMaxLetters()return self.maxLetters or 0 end;function edit:IsMultiLine()return self.multiLine end
    return enable(edit,...)
   end
  end
  local changes=0;local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()changes=changes+1 end,function()return true end,provider)
  if provider=='native' then assert(c.syntax,'actual syntax provider absent')end
  c:SetText('return 4');c:SetReadOnly(true)
  local enabled=enables;local trace,queue=c.inputTrace,c.lineNumberQueue
  c:Acquire(function()changes=changes+1 end,function()return true end)
  assert(c.readOnly and not c.edit:IsEnabled() and enables==enabled and c.inputTrace==trace and c.lineNumberQueue==queue,'active syntax refresh reset input/readonly/attachment')
  -- WoW SetText emits OnTextChanged; the external primitive normally leaves
  -- dispatch explicit, so model that native boundary for the retired clear.
  local set=c.nativeSetText
  c.nativeSetText=function(edit,text)local result=set(edit,text);local handler=edit:GetScript('OnTextChanged');if handler then handler(edit,false)end;return result end
  c.nativeSetText(c.edit,'readonly tampering');assert(c:GetText()=='return 4' and changes==0,'active readonly guard changed')
  c:Release();assert(c:GetText()=='' and c.edit:GetText()=='' and c.measure:GetText()=='' and changes==0,'readonly guard restored retired source')
  c:Acquire(function()changes=changes+1 end,function()return true end);c:SetReadOnly(false);c:SetText('return 5');c.nativeSetText(c.edit,'return 6')
  assert(c:GetText()=='return 6' and changes==1,'fresh writable lease failed after readonly clear');c:Release()
 end
end)

test('LuaWorkbench released leases restore the visible input subtree with either gutter preference',function()
 local f,a,frames=fixture();local owner={};local first,warm
 local function visible(frame)
  while frame do
   if not frame:IsShown() then return false end
   frame=frame:GetParent()
  end
  return true
 end
 for _,numbers in ipairs({true,false,true})do
  a.db.profile.lua_line_numbers=numbers
  for cycle=1,3 do
   local c=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,'LuaWorkbench');local inner=actual(c)
   if first then assert(inner==first,'visibility repair recreated provider')else first=inner end
   c.frame:Show();c:SetText('local visible='..cycle..'\nreturn visible');c:SetContext(context('visible'));tick(c);tick(c)
   local input=inner.engine.Query.Console.input
   assert(input.frame:IsShown() and visible(c.edit),'released embedded input stayed hidden')
   assert(input.queryEditor.renderSource==c:GetText(),'visible source did not paint')
   if numbers then assert(input.queryLineNumbers and #input.queryLineNumbers.positions==2)else assert(not inner.lineNumbersVisible)end
   c:Release();assert(not input.frame:IsShown() and not visible(c.edit),'released input remained visible')
   if warm then assert(frames()==warm,'visibility repair allocated frames')else warm=frames()end
  end
 end
end)

test('active native refresh retains readonly focus layout trace and latest callbacks',function()
 for _,provider in ipairs({'plain','native'})do
  local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()error('old callback')end,function()return true end,provider)
  c:SetText('return 1');c:SetContext(context('active'));c.frame:Show();tick(c)
  c:SetReadOnly(true);local trace,layout,queue=c.inputTrace,c.layoutInput,c.lineNumberQueue
  local enables=0;local enable=c.edit.Enable;c.edit.Enable=function(self,...)enables=enables+1;return enable(self,...)end
  c:Acquire(function()error('readonly callback')end,function()return true end)
  assert(c.readOnly and not c.edit:IsEnabled() and c.layoutInput==layout and c.inputTrace==trace and c.lineNumberQueue==queue,'active native refresh reset readonly/layout/trace/queue')
  assert(enables==0,'active native refresh enabled readonly input')
  c:SetReadOnly(false);local changes=0;c:Acquire(function()changes=changes+1 end,function()return true end)
  c.edit:SetText('return 2');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(changes==1,'latest callback not used')
  local retired=c.lineNumberQueue;c:Release();c:Acquire(function()changes=changes+10 end,function()return true end)
  c.frame:Show();c:SetText('return 3');c:SetContext(context('restored'));tick(c)
  assert(not c.readOnly and c.edit:IsEnabled() and c.lineNumberQueue~=retired,'released native restore skipped')
  local pending=c.lineNumberQueue.pending;retired.update();assert(c.lineNumberQueue.pending==pending,'retired queue reached restored input')
  c.edit:SetText('return 4');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(changes==11,'released callback not rebound');c:Release()
 end
end)
finish()
