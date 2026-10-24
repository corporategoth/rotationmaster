-- Production property on actual native/plain editor gutters; no opt-in mode.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function actual(code)return code.inner or code end
local function tick(code)
 local c=actual(code);local frame=c.frame;local fn=frame:GetScript('OnUpdate');if fn then fn(frame,.1)end
 for _,hook in ipairs(frame.hooks.OnUpdate or{})do hook(frame,.1)end
 local edit=c.edit;local update=edit:GetScript('OnUpdate');if update then update(edit,.1)end
end
local function fixture(provider,numbers)
 local f,a=dofile('tests/fixtures/lua_workbench.lua')();f.load('UI/lua_input_diagnostics.lua');f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function()return true end
 a.db.profile.lua_line_numbers=numbers~=false
 if provider=='native'then
  f.load('LibsAugment/FAIAP.lua');local enable=a.LuaSyntax.enable
  a.LuaSyntax.enable=function(edit,...)
   local methods={GetText=edit.GetText,SetText=edit.SetText};setmetatable(edit,{__index=methods})
   function edit:GetMaxBytes()return self.maxBytes or 0 end;function edit:SetMaxBytes(v)self.maxBytes=v end
   function edit:GetMaxLetters()return self.maxLetters or 0 end;function edit:IsMultiLine()return self.multiLine end
   return enable(edit,...)
  end
 end
 local changed=0;local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()changed=changed+1 end,function()return true end,provider or'plain');local c=actual(code)
 if provider=='native'then assert(c.syntax,'actual bundled highlighter was not attached')end
 code.frame:Show();code:SetText('local value=1\nreturn value');code:SetContext({kind='function',id='CLIPPING_TEST',source={args={},bindings={}}})
 local input=c.lineNumberInput;local state=input.queryLineNumbers or input.queryLineNumberCache
 return f,a,code,c,input,state,function()return changed end
end
for _,provider in ipairs({'plain','native'})do test(provider..' numbers ON uses nonclipping gutter without a diagnostic command',function()
 local _,_,code,c,input,state=fixture(provider)
 assert(state and not state.gutter:DoesClipChildren(),'native gutter still clips child text')
 assert(state.gutter.clippingWrites==2,'expected vendor initialization plus one native override')
 assert(not state.positions,'gutter rendered synchronously during input construction')
 tick(code);tick(code);assert(input.queryLineNumbers==state and #state.positions==2 and state.rows[1]:IsShown())
 assert(code:GetText()=='local value=1\nreturn value'and c.edit:GetAlpha()==1);code:Release()
end)end
test('full LuaWorkbench retains upstream clipping through source and lease changes',function()
 local _,_,code,_,input,state=fixture('LuaWorkbench');assert(state.gutter:DoesClipChildren()and state.gutter.clippingWrites==1)
 tick(code);code:SetText('return 2');tick(code);assert(#state.positions==1)
 code:Release();assert(state.gutter:DoesClipChildren());code:Acquire(function()end,function()return true end);code.frame:Show();tick(code)
 assert(input.queryLineNumbers==state and state.gutter:DoesClipChildren()and state.gutter.clippingWrites==1)
end)
test('numbers OFF does not create a gutter and later ON attaches the native production property',function()
 for _,provider in ipairs({'plain','native'})do local _,a,code,c,input=fixture(provider,false)
  assert(not input.queryLineNumbers and not input.queryLineNumberCache);a.db.profile.lua_line_numbers=true;tick(code);tick(code)
  local state=assert(input.queryLineNumbers);assert(not state.gutter:DoesClipChildren()and #state.positions==2);code:Release()
 end
end)
test('native OFF ON and released reacquisition retain one owned gutter with the same clipping policy',function()
 for _,provider in ipairs({'plain','native'})do local _,_,code,c,input,state=fixture(provider);tick(code)
  c:SetLineNumbers(false);assert(not input.queryLineNumbers and not state.gutter:IsShown()and not state.gutter:DoesClipChildren())
  c:SetLineNumbers(true);tick(code);assert(input.queryLineNumbers==state and not state.gutter:DoesClipChildren())
  code:Release();assert(not state.gutter:IsShown()and not state.gutter:DoesClipChildren());code:Acquire(function()end,function()return true end);code.frame:Show();code:SetText('return 3');tick(code)
  assert(input.queryLineNumbers==state and #state.positions==1 and not state.gutter:DoesClipChildren());code:Release()
 end
end)
test('active acquisition preserves pending queue latest callbacks readonly and no extra clipping writes',function()
 local _,_,code,c,input,state,changes=fixture('plain');local queue=c.lineNumberQueue;assert(queue.pending);local writes=state.gutter.clippingWrites;local latest=0
 code:SetReadOnly(true);local source=code:GetText();code:Acquire(function()latest=latest+1 end,function()return true end)
 assert(c.lineNumberQueue==queue and queue.pending and state.gutter.clippingWrites==writes and c.readOnly)
 tick(code);assert(input.queryLineNumbers==state and #state.positions==2 and code:GetText()==source and changes()==0 and latest==0)
 code:SetReadOnly(false);c.nativeSetText(c.edit,'return 4');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(latest==1 and changes()==0);code:Release()
end)
test('settled cursor scroll and frame updates perform no clipping reads or writes',function()
 for _,provider in ipairs({'plain','native','LuaWorkbench'})do local _,_,code,c,_,state,changes=fixture(provider);tick(code);tick(code)
  local text=code:GetText();c.edit:SetCursorPosition(2);c.edit:SetFocus();local reads,writes=0,0;local get,set=state.gutter.DoesClipChildren,state.gutter.SetClipsChildren
  state.gutter.DoesClipChildren=function(self)reads=reads+1;return get(self)end
  state.gutter.SetClipsChildren=function(self,...)writes=writes+1;return set(self,...)end
  for i=1,100 do local cursor=c.edit:GetScript('OnCursorChanged');if cursor then cursor(c.edit,14,-4,1,12)end;local scroll=c.scroll or c.lineNumberInput.scrollFrame;local update=scroll:GetScript('OnVerticalScroll');if update then update(scroll,0)end;tick(code)end
  assert(reads==0 and writes==0 and code:GetText()==text and c.edit:GetCursorPosition()==2 and c.edit:HasFocus()and changes()==0,'settled events changed clipping/input')
  code:Release();assert(writes==0,'release restored a retired probe property')
 end
end)
test('more than eight native attachments receive production policy and stay independent of full provider',function()
 local f,a,first,_,_,state=fixture('plain');local controls={first};for i=2,10 do controls[i]=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'plain')end
 local full=a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,'LuaWorkbench');assert(actual(full).lineNumberInput.queryLineNumbers.gutter:DoesClipChildren())
 for _,code in ipairs(controls)do assert(not actual(code).lineNumberInput.queryLineNumbers.gutter:DoesClipChildren());code:Release()end;full:Release();assert(not state.gutter:DoesClipChildren())
end)
test('source-host provider switches reopen bounded native and full gutters without sharing policy',function()
 local f,a=fixture('plain');local owner={};local saved={};local count=0;local create=f.env.CreateFrame;f.env.CreateFrame=function(...)count=count+1;return create(...)end;local warm
 for cycle=1,4 do
  for _,provider in ipairs({'plain','native','LuaWorkbench'})do
   local code=a:AcquireSourceLuaEditor(owner,f.env.UIParent,function()end,function()return true end,provider);local c=actual(code);code.frame:Show();code:SetText('return '..cycle);tick(code);local state=assert(c.lineNumberInput.queryLineNumbers)
   if saved[provider]then assert(saved[provider]==state)else saved[provider]=state end
   assert(state.gutter:DoesClipChildren()==(provider=='LuaWorkbench'));code:Release()
  end
  if warm then assert(count==warm,'provider switches allocated new gutter frames')else warm=count end
 end
end)
test('temporary clipping probe state APIs hooks and report claims are retired',function()
 local _,a,code=fixture('plain')
 for _,name in ipairs({'SetLuaGutterClippingProbe','ApplyLuaGutterClippingProbe','RestoreLuaGutterClippingProbe'})do assert(a[name]==nil,'retired probe API remains '..name)end
 local report=a:LuaEditorInputReport();assert(not report:find('clipping probe',1,true)and report:find('gutter queue=deferred',1,true)and not report:find('local value',1,true));code:Release()
end)
test('strict six-module provider inverse retains every actual historical module contract',function()
 local inverse=dofile('tests/fixtures/restore_editor_provider_reuse.lua')
 for _,path in ipairs({'Integrations/lua_workbench.lua','UI/lua_editor.lua','UI/lua_completion.lua','UI/custom_condition_editor.lua','UI/function_source_pane.lua','UI/line_numbers.lua'})do
  local h=assert(io.open(path));local s=h:read('*a');h:close();assert(type(inverse(s,path))=='string');assert(not pcall(inverse,s..'\n-- unrelated',path))
 end
end)
finish()
