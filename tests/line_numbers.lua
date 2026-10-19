local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(provider)
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.env.IsAddOnLoaded=function() return true end
 local changes=0;local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() changes=changes+1 end,function() return true end,provider or 'plain');local c=code.inner or code
 c.frame:SetSize(620,300);code:SetText('first line\nsecond line\nthird line');code:SetContext({kind='function',id='GUTTER',source={args={},bindings={}}});c.edit:SetCursorPosition(2);c:Layout()
 local engine=c.completionEngine or c.engine;local C=engine.Query.Console;local input=C.input;local state=assert(input.queryLineNumbers)
 local writes=0;local function watch(frame) for _,name in ipairs({'SetFont','SetSpacing','SetText','SetPoint','ClearAllPoints','SetWidth','SetHeight','SetSize','SetShown','SetTextColor','Show','Hide'}) do local original=frame[name];if original then frame[name]=function(self,...) writes=writes+1;return original(self,...) end end end end
 watch(state.measure);for _,row in ipairs(state.rows) do watch(row) end
 local function cursor() c.edit:GetScript('OnCursorChanged')(c.edit,14,-4,1,12) end
 cursor();writes=0
 return f,a,code,c,engine,C,input,state,function() return writes end,function() return changes end,cursor,watch
end
test('identical actual cursor callbacks write no native gutter UI for either provider',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,_,_,_,writes,changes,cursor=fixture(provider);local source=code:GetText();c.edit:SetFocus()
  for i=1,100 do cursor() end
  assert(writes()==0,'100 unchanged cursor callbacks wrote '..writes()..' gutter properties')
  assert(code:GetText()==source and c.edit:GetCursorPosition()==2 and c.edit:HasFocus() and changes()==0,'gutter coalescing changed source caret focus or history')
  c.edit:SetCursorPosition(3);cursor();assert(writes()==0,'same logical line forced a glyph redraw');code:Release()
 end
end)
test('gutter metrics invalidate text wrapping font spacing insets and scale without idle redraws',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,input,state,writes=fixture(provider)
  local function redraw(body,label) local before=writes();body();C:UpdateLineNumbers();assert(writes()>before,label..' did not redraw');local settled=writes();C:UpdateLineNumbers();assert(writes()==settled,label..' did not settle') end
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
  local before=writes();C:UpdateLineNumbers();assert(writes()==before,'fractional native width caused another render');code:Release()
 end
end)
test('gutter rendering follows actual line error scroll viewport and gutter changes',function()
 for _,provider in ipairs({'plain','LuaWorkbench'}) do
  local _,_,code,c,_,C,input,state,writes=fixture(provider)
  local function redraw(body,label) local before=writes();body();C:UpdateLineNumbers();assert(writes()>before,label..' did not redraw');local settled=writes();C:UpdateLineNumbers();assert(writes()==settled,label..' did not settle') end
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
 D:ToggleBreakpoint(W.current,2,C.source);C:UpdateLineNumbers();local marked=false
 for _,button in ipairs(engine.DebugUI.gutterButtons) do if button.line==2 then marked=button.dot:IsShown() end end;assert(marked,'new breakpoint marker not drawn')
 local settled=writes();C:UpdateLineNumbers();assert(writes()==settled,'unchanged breakpoint state redrew')
 D:RemoveBreakpoints(W.current);C:UpdateLineNumbers();assert(writes()>settled,'cleared breakpoint revision did not redraw')
 for _,button in ipairs(engine.DebugUI.gutterButtons) do if button.line==2 then assert(not button.dot:IsShown(),'cleared marker remains visible') end end
 settled=writes();W.db=a:CopySettingsData(W.db);W.db.debugBreakpoints={[W.current]={source=C.source,points={[1]=true}}};C:UpdateLineNumbers();assert(writes()>settled,'database identity did not redraw')
 settled=writes();W.current='OTHER';C:UpdateLineNumbers();assert(writes()>settled,'workspace current source identity did not redraw')
 settled=writes();engine.Workspace=setmetatable({},{__index=W});C:UpdateLineNumbers();assert(writes()>settled,'workspace owner identity did not redraw');engine.Workspace=W
 code:Release()
end)
test('armed and paused gutters settle while stepping source selection drafts and breakpoints invalidate markers',function()
 local _,_,code,c,engine,C,input,state,writes,_,cursor,watch=fixture('LuaWorkbench');local D,W,U=engine.Debugger,engine.Workspace,engine.DebugUI
 local source=C.source;D.scriptId=W.current;D.currentSourceId=nil;D.sources={[W.current]={id=W.current,source=source},OTHER={id='OTHER',source=source}};D.armed=true;D.paused=false;D.line=2
 C:UpdateLineNumbers();for _,button in ipairs(U.gutterButtons) do watch(button);watch(button.dot);watch(button.arrow) end;watch(U.pausedLine)
 local function settled(label) local before=writes();for i=1,100 do cursor() end;assert(writes()==before,label..' repeated callbacks wrote '..(writes()-before)..' gutter properties') end
 local function changed(body,label) local before=writes();body();C:UpdateLineNumbers();assert(writes()>before,label..' did not redraw');settled(label) end
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
 C.lastError={line=2};C:UpdateLineNumbers();assert(nested==1,'reentrant render callback was not bounded');state.measure.SetText=original
 c:SetLineNumbers(false);assert(not input.queryLineNumbers);c:SetLineNumbers(true);assert(input.queryLineNumbers==state,'reused upstream gutter cache changed ownership')
 local settled=writes();C:UpdateLineNumbers();assert(writes()==settled,'reattached gutter did not settle')
 code:Release();code:Acquire(function() end,function() return true end);code:SetText('reopened\nsource');assert(input.queryLineNumbers and #input.queryLineNumbers.positions==2,'reacquisition kept stale source metrics');code:Release();assert(changes()==0,'gutter events created source history')
end)
finish()
