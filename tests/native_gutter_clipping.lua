local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(armed,provider)
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua');f.env.IsAddOnLoaded=function()return true end
 assert(type(a.SetLuaGutterClippingProbe)=='function','clipping probe API absent')
 if armed then assert(a:SetLuaGutterClippingProbe(true))end
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,provider or 'plain');local c=code.inner or code
 code.frame:Show();code:SetText('return 1');code:SetContext({kind='function',id='PROBE',source={args={},bindings={}}})
 local input=c.lineNumberInput;local state=input.queryLineNumbers or input.queryLineNumberCache
 return f,a,code,c,input,state
end
test('unset probe makes no additional native clipping write and leaves full provider untouched',function()
 for _,provider in ipairs({'plain','LuaWorkbench'})do local _,a,code,_,_,state=fixture(false,provider)
  assert(state.gutter:DoesClipChildren() and state.gutter.clippingWrites==1)
  assert(a:LuaEditorInputReport():find('clipping probe armed=false applied=false',1,true));code:Release();assert(state.gutter.clippingWrites==1)
 end
end)
test('arm before opening applies only native gutter and disable restores the exact Boolean',function()
 local _,a,code,c,_,state=fixture(true);assert(not state.gutter:DoesClipChildren()and state.gutter.clippingWrites==2)
 assert(a:LuaEditorInputReport():find('clipping probe armed=true applied=true',1,true))
 local text,cursor,focus=code:GetText(),c.edit:GetCursorPosition(),c.edit:HasFocus();assert(a:SetLuaGutterClippingProbe(false))
 assert(state.gutter:DoesClipChildren()and state.gutter.clippingWrites==3 and code:GetText()==text and c.edit:GetCursorPosition()==cursor and c.edit:HasFocus()==focus)
 assert(a:SetLuaGutterClippingProbe(false)and state.gutter.clippingWrites==3);code:Release()
end)
test('armed mode persists over numbers OFF and release while cached native controls restore and reapply',function()
 local _,a,code,c,input,state=fixture(true)
 c:SetLineNumbers(false);assert(state.gutter:DoesClipChildren());c:SetLineNumbers(true);assert(not state.gutter:DoesClipChildren())
 code:Release();assert(state.gutter:DoesClipChildren());code:Acquire(function()end,function()return true end);code.frame:Show();assert(not state.gutter:DoesClipChildren()and input.queryLineNumbers==state)
 code:Release();assert(state.gutter:DoesClipChildren());a:SetLuaGutterClippingProbe(false)
end)
test('full LuaWorkbench is unchanged while native probe is armed',function()
 local _,a,code,_,_,state=fixture(true,'LuaWorkbench');assert(state.gutter:DoesClipChildren()and state.gutter.clippingWrites==1)
 a:SetLuaGutterClippingProbe(false);assert(state.gutter.clippingWrites==1);code:Release()
end)
test('native original false clipping restores false without redundant writes',function()
 local _,a,code,c,_,state=fixture(false);c:SetLineNumbers(false);state.gutter:SetClipsChildren(false);local n=state.gutter.clippingWrites
 a:SetLuaGutterClippingProbe(true);c:SetLineNumbers(true);assert(not state.gutter:DoesClipChildren()and state.gutter.clippingWrites==n)
 a:SetLuaGutterClippingProbe(false);assert(not state.gutter:DoesClipChildren()and state.gutter.clippingWrites==n);code:Release()
end)
test('missing malformed and throwing capabilities leave native state untouched and expose no error source',function()
 for _,mode in ipairs({'missing','malformed','throw'})do
  local _,a,code,c,_,state=fixture(false);c:SetLineNumbers(false);local n=state.gutter.clippingWrites
  if mode=='missing'then state.gutter.DoesClipChildren=false elseif mode=='malformed'then state.gutter.DoesClipChildren=function()return 'true'end else state.gutter.DoesClipChildren=function()error('PRIVATE SOURCE MARKER')end end
  a:SetLuaGutterClippingProbe(true);c:SetLineNumbers(true);assert(state.gutter.clippingWrites==n)
  local report=a:LuaEditorInputReport();assert(report:find('clipping probe armed=true applied=false',1,true)and not report:find('PRIVATE SOURCE MARKER',1,true));code:Release()
 end
end)
test('stale gutter identity never restores through a replacement and owner arguments are validated',function()
 local f,a,code,c,input,state=fixture(true);local old=state.gutter;local replacement=f.env.CreateFrame('Frame',nil,c.frame);replacement:SetClipsChildren(false);state.gutter=replacement
 assert(a:SetLuaGutterClippingProbe(false));assert(not replacement:DoesClipChildren()and replacement.clippingWrites==1)
 assert(a.SetLuaGutterClippingProbe({},true)==nil and a:SetLuaGutterClippingProbe('yes')==nil)
 state.gutter=old;old:SetClipsChildren(true);code:Release()
end)
test('setter failure and callback-driven release do not revive a stale probe attachment',function()
 local _,a,code,c,_,state=fixture(false);c:SetLineNumbers(false);local original=state.gutter.SetClipsChildren
 state.gutter.SetClipsChildren=function()error('PRIVATE SETTER ERROR')end
 a:SetLuaGutterClippingProbe(true);c:SetLineNumbers(true);assert(state.gutter:DoesClipChildren())
 assert(not a:LuaEditorInputReport():find('PRIVATE SETTER ERROR',1,true));state.gutter.SetClipsChildren=original
 c:SetLineNumbers(false);state.gutter.SetClipsChildren=function(self,value)original(self,value);if not value then code:Release()end end
 c:SetLineNumbers(true);assert(c.released and state.gutter:DoesClipChildren());a:SetLuaGutterClippingProbe(false)
end)
test('invalid native owners are not probed and restoration failures remain honest and retryable',function()
 local _,a,code,c,_,state=fixture(false);c:SetLineNumbers(false);c.valid=function()return false end
 local n=state.gutter.clippingWrites;a:SetLuaGutterClippingProbe(true);c:SetLineNumbers(true);assert(state.gutter.clippingWrites==n)
 c:SetLineNumbers(false);c.valid=function()return true end;c:SetLineNumbers(true);assert(not state.gutter:DoesClipChildren())
 local original=state.gutter.SetClipsChildren;state.gutter.SetClipsChildren=function(self,value)if value then error('PRIVATE RESTORE ERROR')end;return original(self,value)end
 local ok,why=a:SetLuaGutterClippingProbe(false);assert(ok==nil and why=='clipping-restore-unavailable')
 local report=a:LuaEditorInputReport();assert(report:find('armed=false applied=true restorePending=true',1,true)and not report:find('PRIVATE RESTORE ERROR',1,true))
 state.gutter.SetClipsChildren=original;assert(a:SetLuaGutterClippingProbe(false)and state.gutter:DoesClipChildren());code:Release()
end)
test('armed probe performs no idle clipping work and bounds simultaneous native attachments',function()
 local f,a,code,c,_,state=fixture(true);local n=state.gutter.clippingWrites;local reads=0;local read=state.gutter.DoesClipChildren
 state.gutter.DoesClipChildren=function(self)reads=reads+1;return read(self)end
 for i=1,10 do local update=c.frame:GetScript('OnUpdate');if update then update(c.frame,.1)end;for _,hook in ipairs(c.frame.hooks.OnUpdate or{})do hook(c.frame,.1)end end
 assert(state.gutter.clippingWrites==n and reads==0,'idle work touched clipping')
 local controls={code}
 for i=2,9 do controls[i]=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'plain')end
 local clipped=0
 for _,control in ipairs(controls)do if not control.lineNumberInput.queryLineNumbers.gutter:DoesClipChildren()then clipped=clipped+1 end end
 assert(clipped==8,'native probe attachment bound changed');assert(a:SetLuaGutterClippingProbe(false))
 for _,control in ipairs(controls)do assert(control.lineNumberInput.queryLineNumbers.gutter:DoesClipChildren());control:Release()end
end)
test('validity and native getter callbacks cannot apply a probe after unarming it',function()
 for _,mode in ipairs({'valid','getter'})do
  local _,a,code,c,_,state=fixture(false);c:SetLineNumbers(false);local writes=state.gutter.clippingWrites
  a:SetLuaGutterClippingProbe(true)
  if mode=='valid'then c.valid=function()a:SetLuaGutterClippingProbe(false);return true end
  else local original=state.gutter.DoesClipChildren;state.gutter.DoesClipChildren=function(self)self.DoesClipChildren=original;a:SetLuaGutterClippingProbe(false);return original(self)end end
  c:SetLineNumbers(true);assert(state.gutter:DoesClipChildren()and state.gutter.clippingWrites==writes,'callback installed clipping after unarm')
  assert(a:LuaEditorInputReport():find('armed=false applied=false',1,true));code:Release()
 end
end)
test('older restoration cannot overwrite a rearmed attachment or lose its original clipping baseline',function()
 for _,mode in ipairs({'getter','setter'})do
  local _,a,code,c,_,state=fixture(true)
  local function rearm()assert(a:SetLuaGutterClippingProbe(true));c:SetLineNumbers(false);c:SetLineNumbers(true)end
  if mode=='getter'then local original=state.gutter.DoesClipChildren;state.gutter.DoesClipChildren=function(self)self.DoesClipChildren=original;rearm();return original(self)end
  else local original=state.gutter.SetClipsChildren;state.gutter.SetClipsChildren=function(self,value)self.SetClipsChildren=original;original(self,value);rearm()end end
  a:SetLuaGutterClippingProbe(false)
  assert(not state.gutter:DoesClipChildren(),'retired restoration overwrote newer probe')
  assert(a:LuaEditorInputReport():find('armed=true applied=true',1,true))
  assert(a:SetLuaGutterClippingProbe(false)and state.gutter:DoesClipChildren(),'rearmed probe lost original true baseline')
  code:Release()
 end
end)
test('superseded disable stops before other newly rearmed native records',function()
 local f,a,first=fixture(true);local second=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'plain')
 local controls={first,second};local fired=false
 for _,c in ipairs(controls)do local gutter=c.lineNumberInput.queryLineNumbers.gutter;local original=gutter.DoesClipChildren
  gutter.DoesClipChildren=function(self)
   self.DoesClipChildren=original
   if not fired then fired=true;assert(a:SetLuaGutterClippingProbe(true));for _,other in ipairs(controls)do other:SetLineNumbers(false);other:SetLineNumbers(true)end end
   return original(self)
  end
 end
 local ok,why=a:SetLuaGutterClippingProbe(false);assert(ok==nil and why=='clipping-probe-superseded')
 for _,c in ipairs(controls)do assert(not c.lineNumberInput.queryLineNumbers.gutter:DoesClipChildren(),'superseded loop touched a new attachment')end
 assert(a:SetLuaGutterClippingProbe(false))
 for _,c in ipairs(controls)do assert(c.lineNumberInput.queryLineNumbers.gutter:DoesClipChildren());c:Release()end
end)
finish()
