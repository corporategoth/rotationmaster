local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function tick(frame)
 local update=frame:GetScript('OnUpdate');if update then update(frame,.1) end
 for _,hook in ipairs(frame.hooks and frame.hooks.OnUpdate or {}) do hook(frame,.1) end
end
local function flush(c,C) if C then C:UpdateLineNumbers() end;tick(c.frame) end
local function fixture(provider)
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua');f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function() return true end
 local changes=0;local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() changes=changes+1 end,function() return true end,provider or 'plain');local c=code.inner or code
 c.frame:SetSize(620,300);code:SetText('first line\nsecond line\nthird line');code:SetContext({kind='function',id='GUTTER',source={args={},bindings={}}});c.edit:SetCursorPosition(2);c:Layout();tick(c.frame)
 local engine=c.completionEngine or c.engine;local C=engine.Query.Console;local input=C.input;local state=assert(input.queryLineNumbers)
 local writes=0;local function watch(frame) for _,name in ipairs({'SetFont','SetSpacing','SetText','SetPoint','ClearAllPoints','SetWidth','SetHeight','SetSize','SetShown','SetTextColor','Show','Hide'}) do local original=frame[name];if original then frame[name]=function(self,...) writes=writes+1;return original(self,...) end end end end
 watch(state.measure);for _,row in ipairs(state.rows) do watch(row) end
 local function cursor() c.edit:GetScript('OnCursorChanged')(c.edit,14,-4,1,12) end
 cursor();tick(c.frame);writes=0
 return f,a,code,c,engine,C,input,state,function() return writes end,function() return changes end,cursor,watch
end
test('identical actual cursor callbacks write no native gutter UI for either provider',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,_,_,_,writes,changes,cursor=fixture(provider);local source=code:GetText();c.edit:SetFocus()
  for i=1,100 do cursor() end;tick(c.frame)
  assert(writes()==0,'100 unchanged cursor callbacks wrote '..writes()..' gutter properties')
  assert(code:GetText()==source and c.edit:GetCursorPosition()==2 and c.edit:HasFocus() and changes()==0,'gutter coalescing changed source caret focus or history')
  c.edit:SetCursorPosition(3);cursor();tick(c.frame);assert(writes()==0,'same logical line forced a glyph redraw');code:Release()
 end
end)
test('gutter metrics invalidate text wrapping font spacing insets and scale without idle redraws',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,input,state,writes=fixture(provider)
  local function redraw(body,label) local before=writes();body();flush(c,C);assert(writes()>before,label..' did not redraw');local settled=writes();flush(c,C);assert(writes()==settled,label..' did not settle') end
  redraw(function() c.edit:SetWidth(60) end,'text width');assert(state.positions[3].offset>24,'wrapping metrics were not rebuilt')
  redraw(function() code:SetText('short\nnew source') end,'source');assert(#state.positions==2)
  redraw(function() code:SetText('one\ntwo\nthree\nfour') end,'source growth');assert(#state.positions==4)
  local font=c.edit.GetFont;redraw(function() c.edit.GetFont=function(self) local name,size,flags=font(self);return name,size+1,flags end end,'font size')
  local changed=c.edit.GetFont;redraw(function() c.edit.GetFont=function(self) local name,size=changed(self);return name,size,'OUTLINE' end end,'font flags')
  redraw(function() c.edit:SetSpacing(c.edit:GetSpacing()+1) end,'spacing')
  redraw(function() c.edit:SetTextInsets(2,3,4,5) end,'insets')
  redraw(function() c.edit:SetTextInsets(1,4,4,5) end,'equal-width shifted insets')
  redraw(function() c.edit:SetScale(1.25) end,'effective scale')
  local getWidth=c.edit.GetWidth;c.edit.GetWidth=function(self) return getWidth(self)+.00003051758 end
  local before=writes();flush(c,C);assert(writes()==before,'fractional native width caused another render');code:Release()
 end
end)
test('gutter rendering follows actual line error scroll viewport and gutter changes',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,input,state,writes=fixture(provider)
  local function redraw(body,label) local before=writes();body();flush(c,C);assert(writes()>before,label..' did not redraw');local settled=writes();flush(c,C);assert(writes()==settled,label..' did not settle') end
  redraw(function() c.edit:SetCursorPosition(14);c.edit:GetScript('OnCursorChanged')(c.edit,21,-16,1,12) end,'current logical line')
  redraw(function() C.lastError={line=3} end,'error line');assert(state.rows[3].textColor[1]==1 and state.rows[3].textColor[2]==.25)
  redraw(function() C.lastError=nil end,'error reset')
  redraw(function() input.scrollFrame:SetVerticalScroll(12);input.scrollFrame:GetScript('OnVerticalScroll')(input.scrollFrame,12) end,'scroll')
  redraw(function() input.scrollFrame:SetHeight(input.scrollFrame:GetHeight()+20) end,'viewport height')
  redraw(function() state.gutter:SetWidth(state.gutter:GetWidth()+4) end,'gutter width');code:Release()
 end
end)
test('inactive debugger breakpoint revisions workspace and database invalidate render state',function()
 local _,a,code,c,engine,C,input,state,writes=fixture('LuaWorkbench');local D,W=engine.Debugger,engine.Workspace
 D:ToggleBreakpoint(W.current,2,C.source);flush(c,C);local marked=false
 for _,button in ipairs(engine.DebugUI.gutterButtons) do if button.line==2 then marked=button.dot:IsShown() end end;assert(marked,'new breakpoint marker not drawn')
 local settled=writes();flush(c,C);assert(writes()==settled,'unchanged breakpoint state redrew')
 D:RemoveBreakpoints(W.current);flush(c,C);assert(writes()>settled,'cleared breakpoint revision did not redraw')
 for _,button in ipairs(engine.DebugUI.gutterButtons) do if button.line==2 then assert(not button.dot:IsShown(),'cleared marker remains visible') end end
 settled=writes();W.db=a:CopySettingsData(W.db);W.db.debugBreakpoints={[W.current]={source=C.source,points={[1]=true}}};flush(c,C);assert(writes()>settled,'database identity did not redraw')
 settled=writes();W.current='OTHER';flush(c,C);assert(writes()>settled,'workspace current source identity did not redraw')
 settled=writes();engine.Workspace=setmetatable({},{__index=W});flush(c,C);assert(writes()>settled,'workspace owner identity did not redraw');engine.Workspace=W
 code:Release()
end)
test('armed and paused gutters settle while stepping source selection drafts and breakpoints invalidate markers',function()
 local _,_,code,c,engine,C,input,state,writes,_,cursor,watch=fixture('LuaWorkbench');local D,W,U=engine.Debugger,engine.Workspace,engine.DebugUI
 local source=C.source;D.scriptId=W.current;D.currentSourceId=nil;D.sources={[W.current]={id=W.current,source=source},OTHER={id='OTHER',source=source}};D.armed=true;D.paused=false;D.line=2
 flush(c,C);for _,button in ipairs(U.gutterButtons) do watch(button);watch(button.dot);watch(button.arrow) end;watch(U.pausedLine)
 local function settled(label) local before=writes();for i=1,100 do cursor() end;tick(c.frame);assert(writes()==before,label..' repeated callbacks wrote '..(writes()-before)..' gutter properties') end
 local function changed(body,label) local before=writes();body();flush(c,C);assert(writes()>before,label..' did not redraw');settled(label) end
 local function marker(line) for _,button in ipairs(U.gutterButtons) do if button.line==line then return button end end;error('line marker not visible: '..line) end
 settled('armed')
 changed(function() D.paused=true end,'pause');assert(marker(2).arrow:IsShown() and U.pausedLine:IsShown(),'pause marker missing')
 changed(function() D.line=3 end,'step');assert(not marker(2).arrow:IsShown() and marker(3).arrow:IsShown(),'step marker stale');assert(U.pausedLine.point[5]==-state.positions[3].offset,'step highlight position stale')
 changed(function() D.line=99 end,'invalid pause line');assert(not U.pausedLine:IsShown(),'invalid pause line retained highlight');changed(function() D.line=3 end,'valid pause line');assert(U.pausedLine:IsShown(),'valid pause line lost highlight')
 changed(function() D.currentSourceId='OTHER' end,'selected frame source');assert(not marker(3).arrow:IsShown() and not U.pausedLine:IsShown(),'other frame retained pause marker')
 changed(function() D.currentSourceId=W.current end,'selected editor source');assert(marker(3).arrow:IsShown(),'returning to source lost pause marker')
 changed(function() D.sources[W.current].id='OTHER' end,'current record id');assert(not marker(3).arrow:IsShown(),'changed record id retained marker')
 changed(function() D.sources[W.current].id=W.current;D.sources[W.current].source=source..' draft' end,'registered source draft');assert(not marker(3).arrow:IsShown(),'mismatched source retained marker')
 changed(function() D.sources[W.current].source=source end,'registered source restoration');assert(marker(3).arrow:IsShown(),'restored source lost marker')
 changed(function() D:ToggleBreakpoint(W.current,2,source) end,'paused breakpoint');assert(marker(2).dot:IsShown(),'paused breakpoint missing')
 changed(function() D.sources[W.current]={id=W.current,source=source..' changed'} end,'registered record replacement');assert(not marker(2).dot:IsShown(),'different registered draft retained breakpoint')
 changed(function() D.sources[W.current]={id=W.current,source=source} end,'registered record restoration');assert(marker(2).dot:IsShown(),'restored registered source lost breakpoint')
 changed(function() D.paused=false end,'continue');assert(not marker(3).arrow:IsShown() and not U.pausedLine:IsShown(),'continue retained pause marker')
 changed(function() D.armed=false end,'stop');code:Release()
end)
test('gutter detach and reacquisition retire cached rendering and reject synchronous reentry',function()
 local _,_,code,c,_,C,input,state,writes,changes,cursor=fixture('plain')
 local original=state.measure.SetText;local nested=0;state.measure.SetText=function(self,text) nested=nested+1;assert(nested<8,'native cursor feedback recursively repainted gutter');cursor();return original(self,text) end
 C.lastError={line=2};flush(c,C);assert(nested==1,'reentrant render callback was not bounded');state.measure.SetText=original
 c:SetLineNumbers(false);assert(not input.queryLineNumbers);c:SetLineNumbers(true);assert(input.queryLineNumbers==state,'reused upstream gutter cache changed ownership');tick(c.frame)
 local settled=writes();flush(c,C);assert(writes()==settled,'reattached gutter did not settle')
 code:Release();code:Acquire(function() end,function() return true end);c.frame:Show();code:SetText('reopened\nsource');tick(c.frame);assert(input.queryLineNumbers and #input.queryLineNumbers.positions==2,'reacquisition kept stale source metrics');code:Release();assert(changes()==0,'gutter events created source history')
end)
test('gutter diagnostics count settling and invalidation keys without source for active providers',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,a,code,c,_,C,input,state,_,_,cursor=fixture(provider);local counts=assert(c.lineNumberCounts,'missing gutter counters')
  local calls,skips,renders,metrics=counts.calls,counts.skips,counts.renders,counts.metrics
  for i=1,100 do cursor() end;tick(c.frame)
  assert(counts.calls==calls+100 and counts.skips==skips+1 and counts.renders==renders and counts.metrics==metrics,'settled gutter counts disagree')
  c.edit:SetWidth(c.edit:GetWidth()-20);flush(c,C);assert(counts.metrics==metrics+1 and counts.lastMetric:find('width',1,true) and counts.lastRender:find('metrics',1,true),'metric reason missing')
  local rebuilt=counts.metrics;code:SetText('PRIVATE_GUTTER_DIAGNOSTIC_BODY');flush(c,C);assert(counts.metrics>rebuilt and state.rmMetrics.source==C.source,'source metrics not counted')
  local report=a:LuaEditorInputReport();for _,text in ipairs({'gutter calls=','skips=','renders=','metricRebuilds=','reentries=','gutter last render keys=','gutter last metric keys=','gutter frame ','gutter scroll ','gutter child ','gutter edit parent '}) do assert(report:find(text,1,true),'missing '..text) end
  assert(report:find('provider='..(provider=='plain' and 'native' or provider),1,true),'wrong active provider');assert(not report:find('PRIVATE_GUTTER_DIAGNOSTIC_BODY',1,true),'source leaked into report')
  local original=state.gutter.GetHeight;state.gutter.GetHeight=function() error('PRIVATE_GEOMETRY_FAILURE') end;report=a:LuaEditorInputReport();assert(report:find('height=unavailable',1,true) and not report:find('PRIVATE_GEOMETRY_FAILURE',1,true),'geometry failure leaked or threw');state.gutter.GetHeight=original
  code:Release();assert(a:LuaEditorInputReport():find('state=closed',1,true),'historical report missing');code:Acquire(function() end,function() return true end);local active=code.inner or code;assert(active.lineNumberCounts~=counts,'reopening retained prior counters');code:Release()
 end
end)
test('gutter diagnostics count reentry and protected rendering failure without error text',function()
 local _,a,code,c,_,C,input,state=fixture('plain');local counts=c.lineNumberCounts;local original=state.measure.SetText
 state.measure.SetText=function(self,text) C:UpdateLineNumbers();return original(self,text) end;C.lastError={line=2};flush(c,C);assert(counts.reentries>0,'reentry counter missing');state.measure.SetText=original
 local getFont=c.edit.GetFont;c.edit.GetFont=function() error('PRIVATE_GUTTER_ERROR') end;local ok=pcall(flush,c,C);assert(not ok and counts.errors==1 and not c.lineNumberQueue.rendering,'failed render was not counted or cleared');c.edit.GetFont=getFont
 flush(c,C);local report=a:LuaEditorInputReport();assert(report:find('errors=1',1,true) and not report:find('PRIVATE_GUTTER_ERROR',1,true),'failure report leaked source');code:Release()
end)

test('production gutter defers cursor nested scroll size and direct routes to the owner update',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,a,code,c,_,C,input,state,_,changes=fixture(provider);local base=c.frame:GetScript('OnUpdate');local arrow=c.edit:GetScript('OnArrowPressed')
  input.scrollFrame:SetHeight(10);flush(c,C)
  local source,caret,width,height=code:GetText(),c.edit:GetCursorPosition(),c.edit:GetWidth(),c.edit:GetHeight();c.edit:SetFocus()
  local depth,reads=0,0;local font=c.edit.GetFont;c.edit.GetFont=function(self) assert(depth==0,'default gutter read inside input event');reads=reads+1;return font(self) end
  local scroll=input.scrollFrame.SetVerticalScroll;input.scrollFrame.SetVerticalScroll=function(self,value) scroll(self,value);local handler=self:GetScript('OnVerticalScroll');if handler then handler(self,value) end end
  local counts=c.lineNumberCounts;local calls,flushes=counts.calls,counts.flushes
  depth=1;c.edit:GetScript('OnCursorChanged')(c.edit,14,-400,1,12);input.scrollFrame:GetScript('OnSizeChanged')(input.scrollFrame,input.scrollFrame:GetWidth(),input.scrollFrame:GetHeight());C:UpdateLineNumbers();depth=0
  assert(reads==0 and counts.calls>=calls+4 and counts.flushes==flushes and c.lineNumberQueue.pending,'default event route escaped queue')
  tick(c.frame);assert(reads>0 and counts.flushes==flushes+1 and not c.lineNumberQueue.pending,'default queue did not coalesce');local before=reads;tick(c.frame);assert(reads==before and counts.flushes==flushes+1,'idle frame repainted')
  assert(c.frame:GetScript('OnUpdate')==base and c.edit:GetScript('OnArrowPressed')==arrow,'default queue replaced provider/input handler')
  assert(code:GetText()==source and c.edit:GetCursorPosition()==caret and c.edit:GetWidth()==width and c.edit:GetHeight()==height and state.gutter:IsShown() and c.edit:HasFocus() and changes()==0,'default queue changed input or gutter geometry '..provider..' dimensions '..width..'/'..height..' to '..c.edit:GetWidth()..'/'..c.edit:GetHeight()..' focus='..tostring(c.edit:HasFocus())..' changes='..changes())
  assert(a:LuaEditorInputReport():find('gutter queue=deferred pending=false',1,true),'normal deferred status missing');assert(not c.ToggleDeferredGutterProbe and not c.deferredGutterProbe,'temporary probe remains');code:Release()
 end
end)
test('default gutter drains feedback later and retains hidden work until shown',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,_,state=fixture(provider);local original=state.measure.SetText;local feedback=true
  state.measure.SetText=function(self,text) if feedback then feedback=false;C:UpdateLineNumbers() end;return original(self,text) end
  C.lastError={line=2};local counts=c.lineNumberCounts;local before=counts.flushes;flush(c,C);assert(counts.flushes==before+1 and c.lineNumberQueue.pending,'feedback was dropped or recursively flushed')
  tick(c.frame);assert(counts.flushes==before+2 and not c.lineNumberQueue.pending,'feedback did not settle');state.measure.SetText=original
  c.frame:Hide();C.lastError={line=3};C:UpdateLineNumbers();before=counts.flushes;tick(c.frame);assert(counts.flushes==before and c.lineNumberQueue.pending,'hidden editor rendered or lost pending work');c.frame:Show();tick(c.frame);assert(counts.flushes==before+1 and state.rmRender.error==3,'shown editor missed queued state');code:Release()
 end
end)
test('default queue lease changes retire old pending work across detach release acquire and new owners',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,input=fixture(provider);local stale=C.UpdateLineNumbers;stale(C);local counts=c.lineNumberCounts;local before=counts.flushes
  c:SetLineNumbers(false);tick(c.frame);stale(C);assert(counts.flushes==before and not c.lineNumberQueue,'detached queue rendered');c:SetLineNumbers(true);assert(C.UpdateLineNumbers~=stale);tick(c.frame);local active=c.lineNumberQueue;stale(C);assert(not active.pending,'retired attachment queued into new owner')
  C:UpdateLineNumbers();code:Release();assert(not c.lineNumberQueue,'release retained queue');before=counts.flushes;tick(c.frame);assert(counts.flushes==before,'released frame rendered')
  code:Acquire(function() end,function() return true end);local nextControl=code.inner or code;assert(nextControl.lineNumberQueue and nextControl.lineNumberQueue~=active,'reacquisition did not create a queue');nextControl.frame:Show();tick(nextControl.frame);tick(nextControl.frame);stale(C);assert(not nextControl.lineNumberQueue.pending,'old owner dirtied new lease');code:Release()
 end
end)
test('default queue validates owners preserves newer updaters and recovers from render errors',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C=fixture(provider);local valid=c.valid;local counts=c.lineNumberCounts;local before=counts.flushes
  C:UpdateLineNumbers();c.valid=function() error('PRIVATE_OWNER_ERROR') end;for _,hook in ipairs(c.frame.hooks.OnUpdate) do hook(c.frame,.1) end;assert(not c.lineNumberQueue and counts.flushes==before,'invalid owner rendered');c.valid=valid;c:SetLineNumbers(false);c:SetLineNumbers(true);tick(c.frame)
  local original=C.UpdateLineNumbers;C:UpdateLineNumbers();local newer=function() end;C.UpdateLineNumbers=newer;tick(c.frame);assert(not c.lineNumberQueue and C.UpdateLineNumbers==newer,'flush overwrote newer updater');c:SetLineNumbers(false);c:SetLineNumbers(true);tick(c.frame)
  local font=c.edit.GetFont;C:UpdateLineNumbers();c.edit.GetFont=function() error('PRIVATE_RENDER_ERROR') end;assert(not pcall(tick,c.frame));assert(not c.lineNumberQueue.pending and not c.lineNumberQueue.rendering and counts.errors==1,'failed flush retained recursion state');c.edit.GetFont=font;flush(c,C);assert(not c.lineNumberQueue.pending,'render did not recover')
  local measure=C.input.queryLineNumbers.measure;local setText=measure.SetText;measure.SetText=function() C:UpdateLineNumbers();error('PRIVATE_FEEDBACK_ERROR') end;C.lastError={line=2};C:UpdateLineNumbers();assert(not pcall(tick,c.frame));assert(not c.lineNumberQueue.pending,'failed render feedback kept an idle retry loop');measure.SetText=setText;flush(c,C);code:Release()
 end
end)
test('paint retry requires an actual geometry-blocked owned-input attempt and respects gutter absence',function()
 local _,_,code,c,engine,C,input=fixture('LuaWorkbench');local E=engine.Query.Editor;local state=input.queryEditor;local before=state.renderSource
 state.pending=true;C:UpdateLineNumbers();local update=c.frame:GetScript('OnUpdate');for _,hook in ipairs(c.frame.hooks.OnUpdate) do hook(c.frame,.001) end
 assert(state.pending and state.renderSource==before and not c.lineNumberQueue.paintRetry,'arbitrary pending work triggered paint retry')
 c.edit:SetText('return 987');C.source='return 987';C:UpdateLineNumbers();E:Paint(input);assert(c.lineNumberQueue.paintRetry==state,'blocked owned paint was not remembered')
 for _,hook in ipairs(c.frame.hooks.OnUpdate) do hook(c.frame,.001) end;assert(state.renderSource=='return 987' and not state.pending and not c.lineNumberQueue.paintRetry,'actual blocked paint was not retried after geometry')
 c:SetLineNumbers(false);c.edit:SetText('return 321');C.source='return 321';E:Paint(input);assert(state.renderSource=='return 321' and not c.lineNumberQueue,'numbers OFF painting acquired deferred dependency');code:Release()
end)
test('paint adapter delegates other inputs and exact varargs nil results without retry ownership',function()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();local target={};local create=a.CreateLuaWorkbenchEngine
 function a:CreateLuaWorkbenchEngine(...) local engine=create(self,...);local E=engine.Query.Editor;local paint=E.Paint
  function E:Paint(input,...) if input==target then assert(self==E);return input,... end;return paint(self,input,...) end
  return engine end
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);local E=c.engine.Query.Editor
 local retry=c.lineNumberQueue.paintRetry;local function pack(...) return {n=select('#',...),...} end;local values=pack(E:Paint(target,7,nil,9));assert(values.n==4 and values[1]==target and values[2]==7 and values[3]==nil and values[4]==9,'other-input call args/results changed');assert(c.lineNumberQueue.paintRetry==retry,'other input changed retry ownership');c:Release()
end)

test('navigation uses fresh queued metrics for source wrapping width and missing old rows',function()
 for _,provider in ipairs({'LuaWorkbench'}) do for _,mode in ipairs({'source','width','missing'}) do
  local _,_,code,c,engine,C,input=fixture(provider);local N=engine.Navigation;code:SetText(mode=='missing' and 'short' or string.rep('small\n',80));flush(c,C)
  local source=mode=='width' and code:GetText() or string.rep('x',1800)..'\n'..string.rep('small\n',79)
  if mode=='width' then c.edit:SetWidth(30) else code:SetText(source) end
  local position=mode=='width' and 39*6 or 1801+38*6;local calls=0;local setScroll=input.scrollFrame.SetVerticalScroll;input.scrollFrame.SetVerticalScroll=function(self,value) calls=calls+1;return setScroll(self,value) end
  local scroll=N.ScrollTo;local requested;N.ScrollTo=function(self,target,offset,...) requested=offset;return scroll(self,target,offset,...) end
  N:Position(input,position,false);assert(c.edit:GetCursorPosition()==position,'navigation cursor was deferred');assert(calls==0,'stale navigation scrolled before queued geometry '..provider..'/'..mode)
  tick(c.frame);local line=C:GetLinePosition(source,position);assert(requested==input.queryLineNumbers.positions[line].offset-40 and calls==1,'navigation missed fresh row '..provider..'/'..mode);code:Release()
 end end
end)
test('deferred navigation cancels changed source cursor attachment and released owners',function()
 for _,mode in ipairs({'source','cursor','detach','release'}) do
  local _,_,code,c,engine,C,input=fixture('LuaWorkbench');code:SetText('small');flush(c,C);local source=string.rep('long line\n',80);code:SetText(source)
  local calls=0;local scroll=input.scrollFrame.SetVerticalScroll;input.scrollFrame.SetVerticalScroll=function(self,value) calls=calls+1;return scroll(self,value) end
  engine.Navigation:Position(input,100,false);assert(calls==0,'navigation did not defer')
  if mode=='source' then code:SetText(source..'changed') elseif mode=='cursor' then c.edit:SetCursorPosition(101) elseif mode=='detach' then c:SetLineNumbers(false) else code:Release() end
  tick(c.frame);assert(calls==0,'stale navigation scrolled '..mode);code:Release()
 end
end)
test('current geometry other inputs and no-gutter navigation preserve immediate behavior',function()
 local _,_,code,c,engine,C,input=fixture('LuaWorkbench');local N=engine.Navigation;local calls=0;local scroll=input.scrollFrame.SetVerticalScroll
 input.scrollFrame.SetVerticalScroll=function(self,value) calls=calls+1;return scroll(self,value) end
 N:Position(input,14,false);assert(calls==1,'current metric navigation was deferred')
 c:SetLineNumbers(false);calls=0;N:Position(input,1,false);assert(c.edit:GetCursorPosition()==1 and not c.lineNumberQueue,'no-gutter cursor changed semantics')
 local other={editBox=c.edit,scrollFrame=input.scrollFrame,SetFocus=function() end,SetCursorPosition=function(_,value) c.edit:SetCursorPosition(value) end,HighlightText=function() end,GetText=function() return 'other\ninput' end};N:Position(other,7,false);assert(calls==1 and c.edit:GetCursorPosition()==7,'other-input navigation was intercepted');code:Release()
end)

test('fresh native acquisition before first frame and repeated active acquisition retain a working queue',function()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');local input=code.completionEngine.Query.Console.input
 assert(code.lineNumberQueue and not input.queryLineNumbers.positions,'construction rendered synchronously');code.frame:SetSize(620,300)
 for i=1,3 do code:Acquire(function() end,function() return true end);code:SetText('return 1\nreturn 2');code.frame:Show();tick(code.frame);assert(code.lineNumberQueue and input.queryLineNumbers.positions and #input.queryLineNumbers.positions==2 and #input.queryLineNumbers.rows==2,'active acquisition lost gutter queue '..i) end
 code:Release()
end)

test('navigation adapter preserves other-input args results and clears scoped scroll suppression on errors',function()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();local target={};local create=a.CreateLuaWorkbenchEngine;local fail=false
 function a:CreateLuaWorkbenchEngine(...) local engine=create(self,...);local N=engine.Navigation;local position=N.Position
  function N:Position(input,cursor,...) if input==target then assert(self==N);return input,cursor,... end;local value=position(self,input,cursor,...);if fail then error('PRIVATE_NAV_ERROR') end;return value end
  return engine end
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('old');tick(c.frame);local N,C=c.engine.Navigation,c.engine.Query.Console;local input=C.input
 local function pack(...) return {n=select('#',...),...} end;local values=pack(N:Position(target,7,nil,9));assert(values.n==4 and values[1]==target and values[2]==7 and values[3]==nil and values[4]==9,'other-input navigation args/results changed')
 c:SetText(string.rep('new source\n',50));fail=true;assert(not pcall(N.Position,N,input,100,false),'owned navigation error disappeared');assert(not c.lineNumberQueue.navigation,'failed Position retained navigation')
 local calls=0;local scroll=input.scrollFrame.SetVerticalScroll;input.scrollFrame.SetVerticalScroll=function(self,value) calls=calls+1;return scroll(self,value) end
 N:ScrollTo(input,10);assert(calls==1,'failed Position left scroll suppression active');fail=false;c:Release()
end)

test('render diagnostics distinguish detached queues and stale or hidden overlays without exposing source',function()
 local _,a,code,c,engine,C,input,state=fixture('LuaWorkbench');local source='PRIVATE_RENDER_DIAGNOSTIC_BODY'
 code:SetText(source);C.source=source;C:UpdateLineNumbers()
 local before=code:GetText();local cursor=c.edit:GetCursorPosition();local queue=c.lineNumberQueue
 local report=a:LuaEditorInputReport()
 assert(report:find('gutter attachment present=true updaterMatch=true inputMatch=true editMatch=true stateMatch=true',1,true),'active queue identity absent')
 assert(report:find('provider render attached=true pending=true',1,true) and report:find('sourceMatch=false',1,true),'stale overlay not identified')
 flush(c,C);report=a:LuaEditorInputReport()
 assert(report:find('provider render attached=true pending=false',1,true) and report:find('sourceMatch=true',1,true),'painted overlay not identified')
 assert(report:find('overlay shown=true',1,true),'overlay visibility absent')
 input.queryEditor.overlay:Hide();report=a:LuaEditorInputReport();assert(report:find('overlay shown=false',1,true),'hidden overlay not identified')
 local updater=C.UpdateLineNumbers;C.UpdateLineNumbers=function() end;report=a:LuaEditorInputReport();assert(report:find('updaterMatch=false',1,true),'replaced updater not identified');C.UpdateLineNumbers=updater
 c:ResetLineNumberQueue();report=a:LuaEditorInputReport();assert(report:find('gutter attachment present=false',1,true),'missing queue mistaken for settled queue')
 assert(not report:find(source,1,true) and not report:find('first line',1,true),'render diagnostics exposed source')
 assert(code:GetText()==before and c.edit:GetCursorPosition()==cursor and not queue.pending,'report changed source/caret or revived retired queue')
 code:Release();report=a:LuaEditorInputReport();assert(report:find('provider render attached=false',1,true),'released overlay appears attached')
end)

for _,provider in ipairs({'plain','LuaWorkbench'}) do
 test(provider..' frame update installation preserves deferred hooks under native SetScript replacement',function()
  local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua');f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function() return true end
  local create=f.env.CreateFrame
  f.env.CreateFrame=function(...)
   local frame=create(...);local set=frame.SetScript
   function frame:SetScript(event,callback)
    set(self,event,callback)
    -- Native SetScript replaces existing hooks for that event. The generic
    -- fixture stores hooks separately, so reproduce that boundary explicitly.
    if event=='OnUpdate' and self.hooks then self.hooks[event]=nil end
   end
   return frame
  end
  local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,provider);code:Acquire(function() end,function() return true end)
  local c=code.inner or code;local engine=c.engine or c.completionEngine;local C=engine.Query.Console;local input=C.input
  code.frame:SetSize(620,300);code:SetText('return 1\nreturn 2');code.frame:Show();c.edit:SetCursorPosition(3);c.edit:SetFocus();tick(c.frame)
  assert(c.lineNumberCounts and c.lineNumberCounts.flushes>0,provider..' queued gutter never reached owner update')
  assert(#input.queryLineNumbers.positions==2 and #input.queryLineNumbers.rows==2,provider..' failed to paint numbers')
  if provider=='LuaWorkbench' then assert(input.queryEditor.renderSource==code:GetText() and #input.queryEditor.renderedText>0 and input.queryEditor.overlay:IsShown(),'provider waiting for gutter left source blank') end
  assert(c.inputCounts.poll and c.edit:GetCursorPosition()==3 and c.edit:HasFocus(),'provider replacement lost diagnostic poll or changed input')
  code:Release()
 end)
end

test('active acquire retains pending attachment without native or completion lease reset',function()
 for _,provider in ipairs({'plain','LuaWorkbench'})do
  local _,_,code,c,_,C,_,state=fixture(provider)
  local queue,trace=c.lineNumberQueue,c.inputTrace;C:UpdateLineNumbers();assert(queue.pending)
  local writes=0
  for _,key in ipairs({'Enable','SetTextColor','SetAlpha','SetFont','SetCursorPosition'})do
   local original=c.edit[key];if original then c.edit[key]=function(self,...)writes=writes+1;return original(self,...)end end
  end
  local reset=c.ResetInputTrace;c.ResetInputTrace=function(self,...)writes=writes+1;return reset(self,...)end
  local completion=c.AcquireCompletion;if completion then c.AcquireCompletion=function(self,...)writes=writes+1;return completion(self,...)end end
  local changed=0;code:Acquire(function()changed=changed+1 end,function()return true end)
  assert(c.lineNumberQueue==queue and queue.pending and c.inputTrace==trace,'active acquire replaced pending queue or trace')
  assert(writes==0,'active acquire reset native input/completion')
  tick(c.frame);assert(c.lineNumberQueue==queue and not queue.pending and c.lineNumberInput.queryLineNumbers==state)
  c.edit:SetText('latest callback');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(changed==1,'new callback missing')
  code:Acquire(function()error('invalid owner callback')end,function()return false end)
  c.edit:SetText('invalid owner');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(changed==1,'new validity ignored')
  code:Release()
 end
end)
test('active acquire repairs invalidated or stale gutter attachments without resetting input',function()
 for _,provider in ipairs({'plain','LuaWorkbench'})do
  local _,_,code,c,_,C,input,state=fixture(provider);local source=code:GetText();local cursor=c.edit:GetCursorPosition();c.edit:SetFocus()
  code:Acquire(function()end,function()return false end);C:UpdateLineNumbers();tick(c.frame);assert(not c.lineNumberQueue)
  local resets=0;local reset=c.ResetInputTrace;c.ResetInputTrace=function(self,...)resets=resets+1;return reset(self,...)end
  code:Acquire(function()end,function()return true end)
  assert(c.lineNumberQueue and c.lineNumberQueue.pending,'valid owner did not recover missing attachment')
  tick(c.frame);assert(c.lineNumberInput.queryLineNumbers==state and #state.rows==3)
  local old=c.lineNumberQueue;old.state={};code:Acquire(function()end,function()return true end)
  assert(c.lineNumberQueue~=old and c.lineNumberQueue.pending,'stale attachment did not rebind')
  tick(c.frame);assert(resets==0 and code:GetText()==source and c.edit:GetCursorPosition()==cursor and c.edit:HasFocus(),'queue recovery reset input source cursor or focus')
  c:SetLineNumbers(false);local hiddenTrace=c.inputTrace;code:Acquire(function()end,function()return true end)
  assert(not input.queryLineNumbers and not c.lineNumberQueue and c.inputTrace==hiddenTrace,'numbers OFF reattached gutter or reset trace')
  code:Release()
 end
end)
test('active and recovered acquisition preserve callback argument and nil-result arity',function()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua');f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function()return true end
 local install=a.InstallLuaLineNumberControl
 a.InstallLuaLineNumberControl=function(self,c,...)
  local acquire=c.Acquire
  c.Acquire=function(control,callback,valid,...)
   assert(select('#',...)==2 and (...)=='tail' and select(2,...)==false,'Acquire varargs changed')
   acquire(control,callback,valid);return 'return',nil,false
  end
  return install(self,c,...)
 end
 local function packed(...)return {n=select('#',...),...}end
 for _,provider in ipairs({'plain','LuaWorkbench'})do
  local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,provider);local c=code.inner or code;assert(c.provider==(provider=='plain'and'native'or provider),'wrong tuple test provider')
  local function acquire()
   local result=packed(c:Acquire(function()end,function()return true end,'tail',false))
   assert(result.n==3 and result[1]=='return'and result[2]==nil and result[3]==false,'Acquire tuple changed')
  end
  acquire();c:ResetLineNumberQueue();acquire();code:Release();acquire();code:Release()
 end
end)
finish()
