local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local fixture=dofile('tests/fixtures/lua_workbench.lua')
local function frameTick(c,elapsed)
 local update=c.frame:GetScript('OnUpdate');if update then update(c.frame,elapsed or .1) end
 for _,hook in ipairs(c.frame.hooks and c.frame.hooks.OnUpdate or {}) do hook(c.frame,elapsed or .1) end
end
test('optional workbench engine keeps namespaces completion and debugger state independent',function()
 local f,a=fixture();assert(a.CreateLuaWorkbenchEngine,'optional engine missing')
 local one=assert(a:CreateLuaWorkbenchEngine({id='one'}));local two=assert(a:CreateLuaWorkbenchEngine({id='two'}))
 assert(one.Query.Editor~=two.Query.Editor and one.Query.Editor~=f.env.LuaWorkbench.Query and one.Debugger~=two.Debugger and one.Autocomplete~=two.Autocomplete)
 one.Query.Console.input={};assert(one.Autocomplete:Enabled(one.Query.Console.input));assert(not one.Autocomplete:Enabled(two.Query.Console.input))
 one.Workspace.db.drafts.one={source='pending'};assert(not two.Workspace.db.drafts.one and f.env.LuaWorkbench.db.drafts.user.source=='KEEP' and f.env.LuaWorkbenchDB.drafts.user.source=='KEEP')
 assert(not next(f.env.SlashCmdList),'embedding stole upstream commands')
 one:Release();assert(one.released and not two.released)
end)
test('actual embedded completion omits compatibility aliases while their hover documentation remains available',function()
 local f,a=fixture();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua')
 local engine=assert(a:CreateLuaWorkbenchEngine({id='aliases',limited=true}));a:ApplyLuaContextSymbols(engine,{kind='condition',callback='evaluate',source={}},true)
 local names={};for _,name in ipairs(engine.Autocomplete:Names()) do names[name]=true end
 assert(names['Functions.cache.getCached'] and not names['addon.getCached'],'real autocomplete still offers compatibility aliases')
 local context=assert(engine.Autocomplete:Context('addon.get',9));for _,entry in ipairs(engine.Autocomplete:Suggest(context,true)) do assert(entry.name~='addon.getCached') end
 local paths=engine.APIHelp:Paths('addon.getCached(cache, fn)',true);assert(paths[7]=='addon.getCached' and engine.APIHelp:FullDescription(paths[7]))
 engine:Release()
end)
test('released workbench compiler and debugger can run host code without altering the live workspace',function()
 local f,a=fixture();assert(a.CreateLuaWorkbenchEngine,'optional engine missing')
 local e=assert(a:CreateLuaWorkbenchEngine({id='test',environment={owner={value=9}}}));local code='local doubled=owner.value*2\nprint(doubled)\nreturn doubled'
 local compiled,metadata=e.DebugCompiler:Compile(code);assert(compiled,metadata)
 assert(e.Debugger:Start('test',code));local count=0
 while e.Debugger.armed and count<20 do count=count+1;if e.Debugger.paused then e.Debugger:StepOver() else e.Debugger:Pump() end end
 assert(not e.Debugger.lastError and not e.Query.Console.statusFailed,tostring(e.Query.Console.statusText));assert(table.concat(e.Query.Console.lines,' '):find('18',1,true),'debugger did not return the host result')
 assert(f.env.LuaWorkbench.db.drafts.user.source=='KEEP');e:Release()
end)
test('advanced control embeds into its host and closes without claiming the installed workspace',function()
 local f,a=fixture();assert(a.CreateLuaWorkbenchControl,'advanced control missing')
 local edits=0;local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() edits=edits+1 end,function() return true end)
 c:SetText('return 1');assert(c:GetText()=='return 1' and edits==0);assert(c.frame:GetParent()==f.env.UIParent and c.engine.Query.Console.input.editBox==c.edit)
 c:SetContext({kind='condition',id='MY_CONDITION',callback='evaluate',source={fields={},bindings={}}});assert(c.engine.Autocomplete:Enabled(c.engine.Query.Console.input))
 c:Release();assert(c.released and c.engine.released and not c.frame:IsShown());assert(f.env.LuaWorkbenchDB.drafts.user.source=='KEEP')
end)
test('native fallback uses released completion for RM symbols and never loads WoW knowledge',function()
 local f,a=fixture();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain')
 code:SetContext({kind='condition',id='TEST',callback='evaluate',source={fields={unit='string'},bindings={}}})
 local e=assert(code.completionEngine);assert(e.APIHelp.events.eventsCleared and not e.APIHelp.events:GetScript('OnEvent'),'limited completion retained a documentation loader');local context=assert(e.Autocomplete:Context('eval',4));local suggestions=e.Autocomplete:Suggest(context,true)
 assert(suggestions[1] and suggestions[1].name=='evalStart');assert(not e.APIHelp.index.UnitHealth and not e.APIHelp.index.GetSpellInfo)
 code:SetText('eval');code.edit:SetFocus();code.edit:SetCursorPosition(4);e.Autocomplete:Update(e.Query.Console.input,true);assert(e.Autocomplete:Accept(e.Query.Console.input));assert(code:GetText()=='evalStart')
 code:Release();assert(not e.Autocomplete.input);code:Acquire(function() end,function() return true end);code:SetText('return true');assert(code:GetText()=='return true');code:Release()
end)
test('optional provider detection and plain opt-out preserve host context and debug test arguments',function()
 local f,a=fixture();f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'LuaWorkbench');assert(code.provider=='LuaWorkbench')
 code:SetText('print(value.amount)');code:SetContext({kind='function',id='CHECK',source={args={{name='value',type='table'}},bindings={}}})
 local c=code.inner;c.arguments:SetText('{ {amount=17} }');assert(c:Debug())
 for i=1,20 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end end
 assert(table.concat(c.engine.Query.Console.lines,' '):find('17',1,true));assert(f.env.LuaWorkbenchDB.drafts.user.source=='KEEP')
 c.engine.Debugger:Stop();c.arguments:SetText('{ {amount=21} }');code:SetContext({kind='function',id='CHECK',source={args={{name='value',type='table'}},bindings={}}});assert(c.arguments:GetText()=='{ {amount=21} }','stable context reset test arguments')
 code:Release();local plain=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');assert(plain.provider=='native' and not plain.syntax);plain:Release()
end)
test('native completion shortcut removes only its own native space insertion',function()
 local f,a=fixture();f.env.IsControlKeyDown=function() return true end
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain')
 code:SetContext({kind='condition',id='TEST',callback='evaluate',source={fields={},bindings={}}});code:SetText('eval');code.edit:SetCursorPosition(4)
 code.edit:GetScript('OnKeyDown')(code.edit,'SPACE');code.edit:SetText('eval ');code.edit:GetScript('OnChar')(code.edit,' ')
 assert(code:GetText()=='eval' and code.edit:GetCursorPosition()==4,'Ctrl+Space inserted a literal space')
 code.edit:GetScript('OnKeyDown')(code.edit,'SPACE');code.edit:SetText('eval unrelated');code.edit:GetScript('OnChar')(code.edit,' ')
 assert(code:GetText()=='eval unrelated','completion shortcut erased unrelated input');code:Release()
end)
test('optional provider can reopen with its new owner callbacks and context',function()
 local f,a=fixture();f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end
 local oldCalls,newCalls=0,0;local oldValid=true;local newValid=true
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() oldCalls=oldCalls+1 end,function() return oldValid end,'LuaWorkbench')
 code:SetContext({kind='function',id='REOPEN',source={args={},bindings={}}});code:SetText('return 1');local previous=code.inner
 code:Release();oldValid=false;assert(type(code.Acquire)=='function','optional provider cannot be reacquired')
 code:Acquire(function() newCalls=newCalls+1 end,function() return newValid end)
 assert(not code.released and code.inner==previous and not previous.engine.released,'known provider engine was not reacquired')
 assert(code.inner.context.id==nil,'reopening retained the retired source owner')
 code:SetContext({kind='function',id='REOPEN',source={args={},bindings={}}});code:SetText('return 1')
 assert(code.inner.context.id=='REOPEN' and code:GetText()=='return 1','reopening lost explicitly rebound editor state')
 code.edit:SetText('return 2');code.edit:GetScript('OnTextChanged')(code.edit,true)
 assert(newCalls==1 and oldCalls==0,'reopened provider used its old change callback')
 newValid=false;code.edit:SetText('return 3');code.edit:GetScript('OnTextChanged')(code.edit,true)
 assert(newCalls==1,'reopened provider used its old validity callback');code:Release()
end)
test('optional provider failure keeps a read-only buffer protected in native fallback',function()
 local f,a=fixture();a:RegisterLuaEditorProvider('Failing',function(parent)
  return {frame=f.env.CreateFrame('Frame',nil,parent),GetText=function() return 'return 1' end,SetText=function() error('provider failed') end,SetReadOnly=function() end,Release=function() end}
 end)
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() error('read-only change escaped') end,function() return true end,'Failing')
 code:SetReadOnly(true);code:SetText('return 2')
 assert(code.provider=='native' and code.inner.readOnly and not code.edit:IsEnabled(),'fallback made a read-only source editable')
 code.edit:SetText('changed');code.edit:GetScript('OnTextChanged')(code.edit,true)
 assert(code:GetText()=='return 2','fallback failed to restore read-only source');code:Release()
end)
test('advanced editor context menu retains upstream platform text helper',function()
 local f,a=fixture();f.env.IsMouseButtonDown=function() return false end
 local code=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 local input=code.engine.Query.Console.input;input.scrollFrame:GetScript('OnMouseUp')(input.scrollFrame,'RightButton')
 assert(code.engine.Workspace.contextMenu:IsShown(),'editor context menu did not open');code:Release()
end)
test('embedded inspector and navigation snapshots preserve installed frame names and Escape ownership',function()
 local f,a=fixture();f.env.UISpecialFrames={'LuaWorkbenchInspector','LuaWorkbenchSavedHelper'}
 local installedInspector,installedSnapshot,installedPicker={},{},{};f.env.LuaWorkbenchInspector=installedInspector;f.env.LuaWorkbenchSavedHelper=installedSnapshot;f.env.LuaWorkbenchFramePicker=installedPicker
 f.env.LoadAddOn=function() return true end;f.env.KeyCommand={RUN_ON_DOWN=1,RUN_ON_UP=2};f.env.KeyCommand_Create=function() return {} end;f.env.KeyCommand_CreateKey=function(key) return key end
 local create=f.env.CreateFrame;f.env.CreateFrame=function(kind,name,...)
  local frame=create(kind,name,...);if name then f.env[name]=frame end
  function frame:GetRight() return 600 end;function frame:GetCenter() return 300,300 end;function frame:GetSize() return self:GetWidth(),self:GetHeight() end;function frame:SetNormalTexture() end
  function frame:SetOwner() end;function frame:ClearLines() end;function frame:AddLine() end;function frame:SetFrameStack() end
  return frame
 end
 local code=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 code.engine.Inspector:Build();code.engine.Navigation:SavedSnapshot({name='saved',source='return 1'},{position0=0});code.engine.Inspector:Pick()
 assert(f.env.LuaWorkbenchInspector==installedInspector and f.env.LuaWorkbenchSavedHelper==installedSnapshot and f.env.LuaWorkbenchFramePicker==installedPicker,'embedding replaced installed frame globals')
 assert(#f.env.UISpecialFrames==2,'embedding claimed installed Escape registrations');code:Release()
end)
test('hiding or releasing the embedded owner stops its independent frame picker',function()
 local f,a=fixture();local code=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);local inspector=code.engine.Inspector
 inspector.picker=f.env.CreateFrame('Frame',nil,f.env.UIParent);inspector.highlight=f.env.CreateFrame('Frame',nil,f.env.UIParent);inspector.pickerDriver=f.env.CreateFrame('Frame',nil,f.env.UIParent)
 local function start() inspector.picking=true;inspector.picker:Show();inspector.highlight:Show();inspector.pickerDriver:Show() end
 local function stopped() return not inspector.picking and not inspector.picker:IsShown() and not inspector.highlight:IsShown() and not inspector.pickerDriver:IsShown() end
 start();code.frame:Hide();assert(stopped(),'owner hide left the frame picker active')
 code.frame:Show();start();code:Release();assert(stopped(),'owner release left the frame picker active')
end)
test('native multiline growth clears previous hover font height before showing its scrollbar',function()
 local f,a=fixture();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');code.frame:SetSize(600,300)
 code:SetContext({kind='condition',id='SCROLL',callback='evaluate',source={fields={},bindings={}}});code:SetText('return true')
 local naturalHeight=code.measure.GetStringHeight
 function code.measure:GetStringHeight() local natural=naturalHeight(self);local height=self:GetHeight();return height>0 and math.min(natural,height) or natural end
 code.edit:GetScript('OnUpdate')(code.edit,.2) -- Hover hit geometry assigns a fixed font height.
 code:SetText('return true'..string.rep('\n',60))
 assert(code.scroll.workbenchBar:IsShown() and code.scroll.workbenchBar.scrollRange>400,'trailing newlines did not grow the scrollbar range')
 code.scroll.workbenchBar:SetValue(300);assert(code.scroll:GetVerticalScroll()==300,'scrollbar cannot reach added empty lines');code:Release()
end)
test('native editor reserves its scrollbar inside the code host',function()
 local f,a=fixture();local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');code.frame:SetSize(600,300);code:SetText(string.rep('line\n',60))
 local bar=code.scroll.workbenchBar
 assert(4+code.scroll:GetWidth()+4+bar:GetWidth()<=code.frame:GetWidth()-4,'scrollbar lies outside the code host')
 assert(bar:IsShown() and bar.scrollRange>0);code:Release()
end)
test('advanced editor retains scrollbar range when its native multiline child grows',function()
 local f,a=fixture();local code=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);local input=code.engine.Query.Console.input
 input.scrollFrame:SetSize(550,220);code.edit:SetHeight(950);input.scrollFrame:GetScript('OnScrollRangeChanged')(input.scrollFrame)
 local bar=input.scrollFrame.workbenchBar;assert(bar:IsShown() and bar.scrollRange==730,'advanced editor lost its native text range')
 bar:SetValue(500);assert(input.scrollFrame:GetVerticalScroll()==500);code:Release()
end)
test('RM public helpers complete as methods and debug exposes the full callback contract',function()
 local f,a=fixture();a.builtinFunctions={['builtin:field']={public=true,callName='addon:MakeField',source={description='Native field',args={{name='self',type='RMAddon'}},returns={{type='RMInput'}}}}}
 local plain=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');plain:SetContext({kind='condition',id='COMPLETE',callback='evaluate',source={fields={},bindings={}}})
 local autocomplete=plain.completionEngine.Autocomplete;local context=assert(autocomplete:Context('addon:Make',10));local choices=autocomplete:Suggest(context,true);assert(choices[1] and choices[1].name=='addon:MakeField','public method is absent from completion');plain:Release()
 local advanced=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);local body={parameters={evaluate={'candidate','cache'}},fields={amount='number'},bindings={}}
 local owner={model={key='DEBUG_ALIAS'},OwnerValid=function() return true end,PendingSource=function() return body end};owner.conditionTestState={configured=true,key='DEBUG_ALIAS',values={amount=17},source=body,profile=a.db.profile,global=a.db.global}
 advanced:SetText('print(value.amount, candidate.amount, evalStart)');advanced:SetContext({kind='condition',id='DEBUG_ALIAS',callback='evaluate',source=body,testOwner=owner});assert(advanced:Debug())
 for i=1,20 do if advanced.engine.Debugger.paused then advanced.engine.Debugger:StepOver() else advanced.engine.Debugger:Pump() end end
 local output=table.concat(advanced.engine.Query.Console.lines,' ');assert(output:find('17',1,true) and output:find('100',1,true),output);advanced:Release()
end)
test('Evaluate debug cannot bypass condition Test and uses its detached fields once configured',function()
 local f,a=fixture();local body={fields={amount='number'},bindings={}};local owner={model={key='TESTED'},OwnerValid=function() return true end,PendingSource=function() return body end}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('print(value.amount)');c:SetContext({kind='condition',id='TESTED',callback='evaluate',source=body,testOwner=owner});c.arguments:SetText('{{amount=999}}')
 assert(not c:Debug() and not c.engine.Debugger.armed,'raw argument field bypasses Test')
 owner.conditionTestState={configured=true,key='TESTED',values={amount=31},source=body,profile=a.db.profile,global=a.db.global};assert(c:Debug())
 for i=1,20 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end end
 assert(table.concat(c.engine.Query.Console.lines,' '):find('31',1,true));assert(owner.conditionTestState.values.amount==31);c:Release()
end)
test('debug error output keeps the complete message in a themed scrollable copy view',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetContext({kind='function',id='FAIL',source={args={},bindings={}}})
 c:SetText('error(string.rep("x",5000).."END_OF_ERROR")');assert(c:Debug());for i=1,20 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end end
 assert(c.ShowDebugOutput,'copyable output view missing');local report=c:ShowDebugOutput();assert(report.input:GetText():find('END_OF_ERROR',1,true),'full error was truncated');assert(report.chrome and report.scroll and report.frame:IsShown())
 report.copy:Click();assert(report.input:HasFocus() and report.input.selection,'copy did not select the report');c:Release();assert(not report.frame:IsShown())
end)
test('condition callback debugging supplies typed values tags and real disposable render containers',function()
 local f,a=fixture();local body={fields={amount='number'},bindings={}};local owner={frame=f.env.UIParent,model={key='CALLBACK'},OwnerValid=function() return true end,Flush=function() return true end,PendingSource=function() return body end,Show=function() end}
 owner.conditionTestState={configured=true,key='CALLBACK',values={amount=31},source=body,profile=a.db.profile,global=a.db.global}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 local function run(callback,code)
  c:SetText(code);c:SetContext({kind='condition',id='CALLBACK',callback=callback,source=body,testOwner=owner});assert(c:Debug())
  for i=1,40 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end end
  assert(not c.engine.Query.Console.statusFailed,tostring(c.engine.Query.Console.statusText))
 end
 run('valid','assert(spec==0 and value.amount==31)');run('print','print(spec,value.amount)');run('on_register','assert(tag=="CALLBACK")')
 run('widget','assert(parent:GetUserData("top"):GetUserData("root")==value); addon.debugInput=addon:CreateConditionEditBox();addon.debugInput:SetText("rendered");parent:AddChild(addon.debugInput)')
 local surface=assert(c.debugSurface);assert(a.debugInput.alive);surface:Close();assert(not c.engine.Debugger.armed and not a.debugInput.alive,'closed render surface retained active debug resources')
 run('help','frame:AddChild(addon.help_funcs.CreateText("Help output"))');assert(c.debugSurface.parent.children[1]);c:Release()
end)
test('debugger tracks orphan controls only during resume and restores every shared factory',function()
 local f,a=fixture();local body={fields={},bindings={}};local owner={frame=f.env.UIParent,model={key='ORPHAN'},OwnerValid=function() return true end,Flush=function() return true end,PendingSource=function() return body end,Show=function() end}
 local create=a.CreateConditionEditBox;a.capturedConditionFactory=create
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('addon.orphan=addon.capturedConditionFactory(addon); error("orphan-error")');c:SetContext({kind='condition',id='ORPHAN',callback='widget',source=body,testOwner=owner});assert(c:Debug())
 for i=1,40 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end;assert(a.CreateConditionEditBox==create,'shared factories changed while the debugger is paused') end
 assert(c.debugError:find('orphan-error',1,true));c:Release();assert(not a.orphan.alive,'failed unattached control leaked')
end)
test('function hover keeps interline spacing out of glyph scaling',function()
 local f,a=fixture();local e=assert(a:CreateLuaWorkbenchEngine({id='HOVER'}));local font=f.env.CreateFrame('FontString')
 font:SetSize(400,40);font:SetSpacing(2);font:SetText('first\nsecond\nthird')
 function font:GetStringHeight() return 40 end;function font:GetNumLines() return 3 end
 function font:CalculateScreenAreaFromCharacterSpan(first) return {{left=10,bottom=first==1 and 28 or 14,width=36,height=12}} end
 local input={queryEditor={overlay=font,renderSource='first\nsecond\nthird',renderSpans={{kind='identifier',text='first',source=1,first=1,last=5},{kind='identifier',text='second',source=7,first=7,last=12}}}}
 assert(e.Query.Editor:HoverSourcePosition(input,12,229)==1,'hover missed the first function on its actual row')
 assert(e.Query.Editor:HoverSourcePosition(input,12,243)==nil,'hover matched a function from above its row')
 assert(e.Query.Editor:HoverSourcePosition(input,12,215)==7,'hover missed the second function on its actual row')
 -- Rectangles are local; moving or scrolling the text must move the hit rows.
 function font:GetBottom() return 240 end
 assert(e.Query.Editor:HoverSourcePosition(input,12,255)==7,'scrolling left hover geometry at the previous position')
 e:Release()
end)
test('native hover covers every character of function names and excludes the arguments',function()
 local f,a=fixture();a.builtinFunctions={['builtin:hover']={source={description='Hover helper',args={},returns={}}}}
 local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');c.frame:SetSize(600,300)
 c:SetContext({kind='condition',callback='evaluate',source={fields={},bindings={isReady='builtin:hover'}}});c:SetText('isReady(value)')
 local font=c.measure
 function font:CalculateScreenAreaFromCharacterSpan(first,last)
  local inset=self.justifyH=='LEFT' and 0 or (self:GetWidth()-#self:GetText()*7)/2
  return {{left=inset+(first-1)*7,bottom=0,width=(last-first+1)*7,height=12}}
 end
 frameTick(c);c.edit:GetScript('OnUpdate')(c.edit,.2);local input=c.completionEngine.Query.Console.input;local editor=c.completionEngine.Query.Editor
 for character=1,7 do assert(editor:HoverSourcePosition(input,(character-.5)*7,205)==1,'native hover misses function-name character '..character) end
 assert(editor:HoverSourcePosition(input,7.5*7,205)==nil,'opening parenthesis is included in the function hitbox')
 assert(editor:HoverSourcePosition(input,8.5*7,205)==9,'argument did not keep its own separate identifier hitbox')
 assert(font.justifyV=='TOP','hover geometry is not aligned to the EditBox text top');c:Release()
end)
test('advanced documentation resolves complete bare function references passed as arguments',function()
 local f,a=fixture();f.env.UnitExists=function() end;f.env.APIDocumentation={functions={{Name='UnitExists',Type='Function',Documentation={'Whether the unit exists'}}}}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetReadOnly(true);assert(not c.edit:IsEnabled(),'readonly documentation view permits typing');c:SetContext({kind='function',id='REF',source={args={},bindings={}}})
 local source='getCached(cache, UnitExists, value.unit)';c:SetText(source);local input=c.engine.Query.Console.input;local state=input.queryEditor;local editor=c.engine.Query.Editor
 frameTick(c);editor:Paint(input);local paths=c.engine.APIHelp:Paths(source,true);local first=assert(source:find('UnitExists',1,true));assert(paths[first]=='UnitExists','bare documented reference lost its documentation')
 local font=state.overlay;local target
 for _,span in ipairs(state.renderSpans) do if span.source==first then target=span end end;assert(target and target.text=='UnitExists')
 function font:GetNumLines() return 1 end;function font:GetStringHeight() return 12 end;function font:GetHeight() return 12 end
 function font:CalculateScreenAreaFromCharacterSpan(start,finish)
  if start~=target.first then return {} end
  return {{left=100,bottom=0,width=70,height=12}}
 end
 for character=1,10 do assert(editor:HoverSourcePosition(input,100+(character-.5)*7,205)==first,'advanced hover misses function-name character '..character) end
 assert(editor:HoverSourcePosition(input,171,205)==nil,'argument separator was included in reference hitbox')
 c:Release()
end)
test('clicked Run executes without arming and clicked debugger controls advance above the text viewport',function()
 local f,a=fixture();f.env.GameTooltip={Hide=function() end};local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 c.frame:SetSize(600,220);c:SetText('local first=2\nlocal second=first+3\nreturn second');c:SetContext({kind='function',id='CLICKED',source={args={},bindings={}}})
 c.play:Click();assert(not c.engine.Debugger.armed,'Run started the debugger instead of running');assert(table.concat(c.engine.Query.Console.lines,' '):find('5',1,true),'Run lost returned values')
 local u,d=c.engine.DebugUI,c.engine.Debugger
 local topOffset;local bg=c.engine.Query.Console.input.scrollBG;local setPoint=bg.SetPoint;function bg:SetPoint(...) local point={...};if point[1]=='TOPLEFT' then topOffset=point[5] end;return setPoint(self,...) end
 c.engine.Workspace.debugButton:Click();assert(d.armed and d.paused,'Debug did not start at a checkpoint')
 assert(u.toolbar:GetFrameLevel()>c.edit:GetFrameLevel(),'code viewport can intercept debugger button clicks')
 assert(u.dock:IsShown(),'terminal is hidden in a minimum-height code pane')
 assert(topOffset==-60,'debug toolbar does not reserve a compact strip above the editor')
 local line=d.line;u.buttons[2]:Click();assert(d.line~=line and d.paused,'clicked Step over did not move')
 u.buttons[3]:Click();assert(d.paused,'clicked Step into did not pause')
 u.buttons[1]:Click();assert(not d.thread and not d.lastError,'clicked Continue did not complete')
 c:Release();assert(not d.armed and not u.dock:IsShown(),'released host retained debugger UI')
end)
test('Run shares Test callback context preserves nil returns and displays full errors',function()
 local f,a=fixture();local body={fields={amount='number'},bindings={}};local owner={model={key='RUN_TEST'},OwnerValid=function() return true end,PendingSource=function() return body end}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('return value.amount,nil,evalStart');c:SetContext({kind='condition',id='RUN_TEST',callback='evaluate',source=body,testOwner=owner})
 assert(c.Run and not c:Run(),'Run bypassed condition Test setup');owner.conditionTestState={configured=true,key='RUN_TEST',values={amount=42},source=body,profile=a.db.profile,global=a.db.global}
 assert(c:Run() and not c.engine.Debugger.armed);assert(table.concat(c.engine.Query.Console.lines,' '):find('42  nil  100',1,true),'Run lost the complete callback arguments or nil results')
 c:SetText('error(string.rep("x",5000).."RUN_ERROR_END")');assert(not c:Run());local output=c:ShowDebugOutput();assert(output.input:GetText():find('RUN_ERROR_END',1,true),'Run error is truncated');c:Release()
end)
test('Run and Debug keep lexical parameters varargs and namespaced bindings consistent',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 a.builtinFunctions={CHECK={source={description='check',args={},returns={}},get=function() return function(value) return value*2 end end}}
 c:SetContext({kind='function',id='VARARGS',source={args={{name='first',type='number'},{name='...',type='any'}},bindings={twice='CHECK'}}})
 c.arguments:SetText('{ n=3, 7, nil, 9 }');c:SetText('print(first, select("#", ...), functions.twice(9)); return ...')
 assert(c:Run());local text=table.concat(c.engine.Query.Console.lines,' ');assert(text:find('7  2  18',1,true) and text:find('return  nil  9',1,true),text)
 c.engine.Query.Console:Clear();assert(c:Debug());c.engine.Debugger:Continue();local output=table.concat(c.engine.Query.Console.lines,' ');assert(output:find('7  2  18',1,true),output)
 c:SetReadOnly(true);c.arguments:SetText('{ 1, 2 }');assert(c:Run() and not c.edit:IsEnabled(),'readonly source cannot run explicitly or became editable');c:Release()
end)
test('line numbers follow native glyph heights spacing wrapped source lines and blank lines',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('short\n'..string.rep('w',100)..'\n\nlast')
 local input=c.engine.Query.Console.input;local state=input.queryLineNumbers;assert(state,'default line numbers missing')
 function state.measure:GetStringHeight() local rows=math.max(1,math.ceil(#(self:GetText() or '')*7/math.max(1,self:GetWidth())));return rows*12.1875+(rows-1)*2 end
 state.source=nil;state.rmMetrics=nil;input.editBox:SetWidth(100);c.engine.Query.Console:UpdateLineNumbers();frameTick(c)
 assert(math.abs(state.positions[2].offset-14.1875)<.0001,'font spacing was omitted from native logical-line advance')
 assert(math.abs(state.positions[3].offset-(14.1875+7*14.1875))<.0001,'wrapped line did not reserve all native rows')
 assert(math.abs(state.positions[4].offset-state.positions[3].offset-14.1875)<.0001,'blank line lost its row spacing')
 c:SetText(string.rep('return true\n',60));state.source=nil;c.engine.Query.Console:UpdateLineNumbers();frameTick(c);assert(math.abs(state.positions[61].offset-60*14.1875)<.0001,'fractional glyph spacing drifted over a long snippet');c:Release()
end)
test('line number preference controls advanced and native gutters without rewriting source or cursor',function()
 local f,a=fixture();local advanced=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 local native=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain')
 for _,c in ipairs({advanced,native}) do
  c.frame:SetSize(600,300);c:SetText('return true\nreturn false');c.edit:SetCursorPosition(5);c:Layout()
  assert(type(c.SetLineNumbers)=='function' and c.lineNumbersVisible,'editor has no visible shared gutter')
  c:SetLineNumbers(false);assert(not c.lineNumbersVisible,'explicit gutter hide failed');c:SetLineNumbers(true)
 end
 a.db.profile.lua_line_numbers=false
 for _,c in ipairs({advanced,native}) do c:Layout();assert(not c.lineNumbersVisible,'global preference left a gutter visible');assert(c:GetText()=='return true\nreturn false' and c.edit:GetCursorPosition()==5,'gutter preference rewrote code/cursor') end
 a.db.profile.lua_line_numbers=true
 for _,c in ipairs({advanced,native}) do c:Layout();assert(c.lineNumbersVisible,'global preference did not restore gutter');c:Release() end
end)
test('native gutters measure inside text insets and survive release and reacquire without input hooks leaking',function()
 local f,a=fixture();local c=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain');c.frame:SetSize(188,300);c:SetText('abcdefghijklmn\nnext')
 local console=c.completionEngine.Query.Console;local state=console.input.queryLineNumbers;frameTick(c)
 assert(c.edit:GetWidth()==100 and state.positions[2].offset==24,'native line wrapping ignored the edit text insets')
 local width=c.scroll:GetWidth();c:SetLineNumbers(false);assert(c.scroll:GetWidth()==width+56,'hidden gutter kept its blank margin')
 c:Release();assert(not console.input.queryLineNumbers,'released native gutter still owns cursor handlers')
 c:Acquire(function() end,function() return true end);c:SetText('return true');assert(console.input.queryLineNumbers and c.lineNumbersVisible,'reopened editor lost line numbers')
 a.db.profile.lua_line_numbers=false;frameTick(c,.1);assert(not console.input.queryLineNumbers,'open native editor did not notice the global preference');c:Release()
end)
test('Run and Debug match private qualified binding namespaces and explicit method receivers',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 a.builtinFunctions={READY={source={description='ready',args={},returns={}},get=function() return function(receiver,value) assert(receiver==a);return value+10 end end},DOUBLE={source={description='double',args={},returns={}},get=function() return function(value) return value*2 end end}}
 f.env.myTools={sentinel=true};local source={args={},bindings={['myTools.nested.ready']='READY',loose='DOUBLE',['functions.ready2']='READY'}}
 c:SetContext({kind='function',id='QUALIFIED',source=source});c:SetText('assert(myTools.sentinel==nil)\nprint(myTools.nested.ready(addon,2),loose(3),functions.loose(4),functions.ready2(addon,5))')
 assert(c:Run(),'qualified binding failed to run');assert(table.concat(c.engine.Query.Console.lines,' '):find('12  6  8  15',1,true),'Run did not match live binding paths')
 c.engine.Query.Console:Clear();assert(c:Debug());c.engine.Debugger:Continue();assert(table.concat(c.engine.Query.Console.lines,' '):find('12  6  8  15',1,true),'Debug did not match live binding paths');assert(f.env.myTools.sentinel and not f.env.myTools.nested,'binding namespaces leaked into game globals')
 source={args={{name='functions',type='table'}},bindings={['myTools.ready']='READY'}};c:SetContext({kind='function',id='SHADOW',source=source});c.arguments:SetText('{{legacy="kept"}}');c:SetText('print(functions.legacy,myTools.ready(addon,1))');assert(c:Run());assert(table.concat(c.engine.Query.Console.lines,' '):find('kept  11',1,true),'canonical functions parameter was replaced')
 a.builtinFunctions.NOTHING={source={description='empty',args={},returns={}},get=function() return nil end,valueBinding=true};f.env.hidden='game global';c:SetContext({kind='function',id='NIL_BINDING',source={args={},bindings={hidden='NOTHING'}}});c.arguments:SetText('{}');c:SetText('assert(hidden==nil and functions.hidden==nil)');assert(c:Run(),'nil binding fell through to a game global');assert(c:Debug());c.engine.Debugger:Continue();assert(not c.debugError,'debug nil binding fell through to a game global');c:Release()
end)
test('condition legacy parameter aliases shadow qualified namespace roots exactly as live callbacks do',function()
 local f,a=fixture();local body={fields={amount='number'},parameters={evaluate={'myTools','cache'}},bindings={['myTools.ready']='READY'}}
 a.builtinFunctions={READY={source={description='ready',args={},returns={}},get=function() return function() return 99 end end}}
 local owner={model={key='LEGACY_ROOT'},OwnerValid=function() return true end,PendingSource=function() return body end};owner.conditionTestState={configured=true,key='LEGACY_ROOT',values={amount=7},source=body,profile=a.db.profile,global=a.db.global}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetContext({kind='condition',id='LEGACY_ROOT',callback='evaluate',source=body,testOwner=owner});c:SetText('assert(myTools==value and myTools.ready==nil);print(myTools.amount)');assert(c:Run(),'legacy alias was overwritten by a namespace root')
 c.engine.Query.Console:Clear();assert(c:Debug());c.engine.Debugger:Continue();assert(not c.debugError and table.concat(c.engine.Query.Console.lines,' '):find('7',1,true),'Debug lost the legacy root shadow');c:Release()
end)
test('advanced gutter toggles preserve editor caret handlers and release unwinds both layers',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('return true\nreturn false')
 local input=c.engine.Query.Console.input;local state=input.queryEditor
 c:SetLineNumbers(false);c.edit:SetCursorPosition(6);c.edit:GetScript('OnCursorChanged')(c.edit,42,-14,2,12)
 assert(state.lastCursor==6 and state.caret.point[4]==42 and state.caret.point[5]==-14,'hiding gutter removed the active editor caret handler')
 c:SetLineNumbers(true);c.edit:SetCursorPosition(3);c.edit:GetScript('OnCursorChanged')(c.edit,21,0,2,12)
 assert(state.lastCursor==3 and state.caret.point[4]==21,'restoring gutter lost native editor cursor behavior')
 c:Release();assert(not input.queryEditor and not input.queryLineNumbers,'release left a live editor/gutter state')
 local calls=0;c.engine.Query.Console.UpdateLineNumbers=function() calls=calls+1 end
 c.edit:GetScript('OnCursorChanged')(c.edit,14,0,2,12);assert(calls==0,'release restored a stale gutter callback')
end)
test('Output Clear clears both printed and terminal output before refreshing the visible report',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetContext({kind='function',id='CLEAR_OUTPUT',source={args={},bindings={}}})
 c.engine.Query.Console:Write('printed output');c.engine.Debugger:TerminalWrite('terminal output');c.debugError='runtime error'
 local output=c:ShowDebugOutput();assert(output.input:GetText():find('terminal output',1,true));output.clear:Click()
 assert(#c.engine.Query.Console.lines==0 and #c.engine.Debugger.terminalLines==0,'Clear left terminal entries retained')
 assert(c.engine.DebugUI.terminalOutput:GetText()=='','Clear left the dock terminal populated')
 assert(not output.input:GetText():find('terminal output',1,true) and not output.input:GetText():find('runtime error',1,true),'Clear report still contains previous output');c:Release()
end)
test('line metrics measure literal markup in advanced and highlighted editors while plain uses native rendering',function()
 local f,a=fixture();local first='local text = "|cffaabbcclong|r |Hspell:1234|h[Lightning]|h |TInterface\\Icons\\Test:16|t"';local source=first..'\nreturn true'
 local function rendered(text)
  return (text:gsub('||','\1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|H.-|h(.-)|h','%1'):gsub('|T.-|t','x'):gsub('\1','|'))
 end
 local function check(c,advanced,literal)
  c.frame:SetSize(188,300);c:SetText(source)
  local input=advanced and c.engine.Query.Console.input or c.completionEngine.Query.Console.input
  local console=advanced and c.engine.Query.Console or c.completionEngine.Query.Console;local state=input.queryLineNumbers
  function state.measure:GetStringHeight()
   local rows=math.max(1,math.ceil(#rendered(self:GetText() or '')*7/math.max(1,self:GetWidth())))
   return rows*12+(rows-1)*self:GetSpacing()
  end
  state.rmMetrics=nil;console:UpdateLineNumbers();frameTick(c)
  local left,right=c.edit:GetTextInsets();local width=c.edit:GetWidth()-left-right;local display=literal and first or rendered(first)
  local rows=math.max(1,math.ceil(#display*7/width));local expected=rows*(12+c.edit:GetSpacing())
  assert(state.positions[2].offset==expected,'line wrapping does not match provider markup rendering')
  assert(c:GetText()==source and state.positions[2].sourceStart==#first+2,'measuring markup altered source bytes or line starts');c:Release()
 end
 check(a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end),true,true)
 check(a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'plain'),false,false)
 f.load('LibsAugment/FAIAP.lua');local enable=a.LuaSyntax.enable
 a.LuaSyntax.enable=function(edit,...)
  local methods={GetText=edit.GetText,SetText=edit.SetText};setmetatable(edit,{__index=methods})
  function edit:GetMaxBytes() return self.maxBytes or 0 end;function edit:SetMaxBytes(value) self.maxBytes=value end;function edit:GetMaxLetters() return self.maxLetters or 0 end;function edit:IsMultiLine() return self.multiLine end
  return enable(edit,...)
 end
 local highlighted=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return true end,'native');assert(highlighted.syntax,'native syntax engine did not attach');check(highlighted,false,true)
end)
test('unconfigured condition actions stay clickable and explain the required Test setup visibly',function()
 local f,a=fixture();local body={fields={unit='string'},bindings={}};f.env.GameTooltip={Hide=function() end};local owner={model={key='MISSING_TEST'},OwnerValid=function() return true end,PendingSource=function() return body end}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('return value.unit');c:SetContext({kind='condition',id='MISSING_TEST',callback='evaluate',source=body,testOwner=owner})
 assert(c.play:IsEnabled() and c.engine.Workspace.debugButton:IsEnabled(),'unconfigured actions silently disable mouse feedback')
 c.play:Click();assert(c.status and c.status:IsShown() and c.status:GetText():find('Test',1,true),'Run prerequisite feedback is invisible')
 assert(not c.engine.Debugger.armed and not c.outputWindow,'missing Test unexpectedly executed or opened output')
 c.engine.Workspace.debugButton:Click();assert(c.status:GetText():find('Test',1,true) and not c.engine.Debugger.armed,'Debug prerequisite feedback is invisible');c:Release()
end)
test('running render callbacks shows their preview without a second empty output dialog',function()
 local f,a=fixture();local body={fields={},bindings={}};local owner={frame=f.env.UIParent,model={key='RENDER_RUN'},OwnerValid=function() return true end,Flush=function() return true end,PendingSource=function() return body end,Show=function() end}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 c:SetContext({kind='condition',id='RENDER_RUN',callback='help',source=body,testOwner=owner});c:SetText('frame:AddChild(addon.help_funcs.CreateText("rendered help"))');assert(c:Run())
 assert(c.debugSurface and c.debugSurface.frame:IsShown() and c.debugSurface.parent.children[1],'render callback produced no visible preview')
 assert(not c.outputWindow or not c.outputWindow.frame:IsShown(),'successful render opened a redundant Output window')
 assert(c.status and c.status:GetText():find('Preview',1,true),'render result has no visible inline feedback')
 c:SetText('error("RENDER_ERROR")');assert(not c:Run() and c.outputWindow.frame:IsShown(),'render failures lost their copyable output');c:Release()
end)
test('Run renders typed condition summaries without changing extra nil returns or function table results',function()
 local f,a=fixture();f.load('Core/conditions.lua')
 local body={fields={unit='string'},bindings={}};local owner={model={key='SUMMARY'},OwnerValid=function() return true end,PendingSource=function() return body end}
 owner.conditionTestState={configured=true,key='SUMMARY',values={unit='you {literal} 50%'},source=body,profile=a.db.profile,global=a.db.global}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end)
 c:SetContext({kind='condition',id='SUMMARY',callback='print',source=body,testOwner=owner});c:SetText('return addon.Functions.presentation.phrase("{unit} {{!is|is not}} ready",{unit=value.unit}),nil,7')
 assert(c:Run());local text=table.concat(c.engine.Query.Console.lines,' ')
 assert(text:find('you {literal} 50% is ready  nil  7',1,true),'typed callback summary is hidden as an opaque table')
 c:SetContext({kind='function',id='TABLE_RESULT',source={args={},bindings={}}});c.arguments:SetText('{}');c:SetText('return {note="raw function result"}')
 assert(c:Run());local raw=table.concat(c.engine.Query.Console.lines,' ');assert(not raw:find('Condition summary unavailable',1,true),'function table was mistaken for a condition summary');c:Release()
end)
test('advanced insertion and deletion repaint despite repeated native caret notifications',function()
 for _,gutter in ipairs({false,true}) do for _,case in ipairs({{'return 1','return 12',9},{'return 12','return 1',8}}) do
  local f,a=fixture();a.db.profile.lua_line_numbers=gutter;local changes=0
  local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() changes=changes+1 end,function() return true end)
  c.frame:SetSize(600,300);c:Layout();c:SetText(case[1]);frameTick(c);frameTick(c);c.edit:SetFocus()
  local input=c.engine.Query.Console.input;local state=input.queryEditor;local editor=c.engine.Query.Editor
  local paint=editor.Paint;local paints=0;function editor:Paint(target) paints=paints+1;return paint(self,target) end
  local setText=c.edit.SetText;local writes=0;function c.edit:SetText(text) writes=writes+1;return setText(self,text) end
  local oldOverlay=state.overlay:GetText();c.edit:SetText(case[2]);c.edit:SetCursorPosition(case[3]);c.edit:GetScript('OnTextChanged')(c.edit,true)
  assert(c:GetText()==case[2] and changes==1 and c.engine.Query.Console.source==case[2],'source or change notification was delayed')
  for tick=1,6 do
   c.edit:GetScript('OnCursorChanged')(c.edit,case[3]*7,0,2,12)
   c.edit:GetScript('OnUpdate')(c.edit,1/60);frameTick(c,1/60)
  end
  assert(state.renderSource==case[2] and state.overlay:GetText()~=oldOverlay,'native caret notifications starved the changed text overlay')
  assert(c.edit:GetCursorPosition()==case[3] and changes==1 and writes==1,'repaint rewrote source cursor or host history')
  assert(paints==1 and not state.pending,'pending repaint was not coalesced')
  for tick=1,60 do c.edit:GetScript('OnCursorChanged')(c.edit,case[3]*7,0,2,12);c.edit:GetScript('OnUpdate')(c.edit,1/60);frameTick(c,1/60) end
  assert(paints==1 and writes==1 and changes==1,'settled editor kept repainting or rewriting source');c:Release()
 end end
end)
test('advanced continuous input coalesces bounded repaint independently of the caret blink clock',function()
 for _,gutter in ipairs({false,true}) do
  local f,a=fixture();a.db.profile.lua_line_numbers=gutter;local changes=0
  local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() changes=changes+1 end,function() return true end)
  c.frame:SetSize(600,300);c:Layout();c:SetText('return 1');frameTick(c);frameTick(c);c.edit:SetFocus()
  -- Settle upstream's initial documentation/color refresh before counting the
  -- paints caused by this edit sequence and its subsequent idle notifications.
  c.engine.Autocomplete:Update(c.engine.Query.Console.input,false)
  local input=c.engine.Query.Console.input;local state=input.queryEditor;local editor=c.engine.Query.Editor
  local paint=editor.Paint;local paints,lastPaint=0,0;function editor:Paint(target) paints=paints+1;return paint(self,target) end
  for tick=1,30 do
   local text='return '..string.rep('1',tick+1);c.edit:SetText(text);c.edit:SetCursorPosition(#text);c.edit:GetScript('OnTextChanged')(c.edit,true)
   c.edit:GetScript('OnCursorChanged')(c.edit,#text*7,0,2,12);c.edit:GetScript('OnUpdate')(c.edit,1/60);frameTick(c,1/60)
   if state.renderSource==text then lastPaint=tick end
   assert(tick-lastPaint<=5,'continuous input postponed rendering beyond the repaint bound')
   assert(c.edit:GetCursorPosition()==#text and changes==tick,'repaint disturbed ongoing native input')
  end
  assert(paints>=5 and paints<=7 and state.renderSource==c:GetText(),'continuous repaint was missing or ran every frame')
  local before=paints;for tick=1,30 do c.edit:GetScript('OnCursorChanged')(c.edit,259,0,2,12);c.edit:GetScript('OnUpdate')(c.edit,1/60);frameTick(c,1/60) end
  assert(paints==before,'idle caret notifications triggered redundant paints');c:Release()
 end
end)
test('advanced pending repaint respects invalid owners read-only input and released callbacks',function()
 local f,a=fixture();local valid=true;local changes=0
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() changes=changes+1 end,function() return valid end)
 c.frame:SetSize(600,300);c:Layout();c:SetText('return 1');frameTick(c);frameTick(c);local input=c.engine.Query.Console.input;local editor=c.engine.Query.Editor
 local paint=editor.Paint;local paints=0;function editor:Paint(target) paints=paints+1;return paint(self,target) end
 c:SetReadOnly(true);c.edit:SetText('forbidden');c.edit:GetScript('OnTextChanged')(c.edit,true)
 assert(c:GetText()=='return 1' and changes==0 and not c.edit:IsEnabled(),'read-only native input was accepted')
 for tick=1,10 do frameTick(c,1/60) end;assert(paints==0,'read-only rollback created a pending repaint')
 c:SetReadOnly(false);c.edit:SetText('return 12');c.edit:GetScript('OnTextChanged')(c.edit,true);assert(changes==1)
 valid=false;local update=c.frame:GetScript('OnUpdate');for tick=1,10 do update(c.frame,1/60) end;assert(paints==0,'invalid owner repainted')
 c:Release();update(c.frame,1);assert(paints==0 and not input.queryEditor,'released callback repainted or revived editor state')
end)
test('actual workbench provider supports source-free diagnostics across release',function()
 local f,a=fixture();f.load('UI/lua_input_diagnostics.lua');f.env.C_AddOns=f.env.C_AddOns or {};f.env.C_AddOns.IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end
 local valid=true;local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() end,function() return valid end,'LuaWorkbench');local c=code.inner
 assert(c.provider=='LuaWorkbench' and c.scroll==c.engine.Query.Console.input.scrollFrame and c.valid,'workbench diagnostics control contract missing')
 assert(a.luaInputEditor==c and c.ResetInputTrace,'actual provider was not registered with diagnostics')
 assert(c.ToggleNativeArrowProbe==nil,'the retired native arrow probe is still installed')
 code:SetText('SECRET_BUFFER_TEXT');local owner={code=code,session=91};a.configWindow={pane={inlineFunction=owner}}
 local report=a:LuaEditorInputReport();assert(report:find('provider=LuaWorkbench',1,true) and report:find('matches source editor=true',1,true) and report:find('source kind=function',1,true),'wrapped provider owner not matched')
 assert(not report:find('SECRET_BUFFER_TEXT',1,true),'diagnostics included source text')
 local arrow=c.edit:GetScript('OnArrowPressed');assert(type(arrow)=='function');assert(report:find('arrowHook=true',1,true),'attached arrow handler missing from report')
 code:Release();assert(c.released and not c.engine.Query.Console.input.queryEditor,'release retained editor state')
end)
test('settled workbench layouts and idle ticks do not rewrite geometry or redraw gutters',function()
 for _,gutter in ipairs({false,true}) do
  local f,a=fixture();a.db.profile.lua_line_numbers=gutter;local changes=0
  local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() changes=changes+1 end,function() return true end);c.frame:SetSize(600,300);c:SetText('first\nsecond\nthird');c.edit:SetFocus();c.edit:SetCursorPosition(2);c:Layout()
  local input=c.engine.Query.Console.input;local counts={geometry=0,gutter=0,text=0,cursor=0,focus=0,chrome=0}
  local function watch(object,method,bucket) local original=object[method];object[method]=function(self,...) counts[bucket]=counts[bucket]+1;return original(self,...) end end
  for _,entry in ipairs({{input.frame,'SetAllPoints'},{input.frame,'SetSize'},{input.scrollBG,'SetPoint'},{c.engine.DebugUI.toolbar,'ClearAllPoints'},{c.engine.DebugUI.dock,'ClearAllPoints'},{c.engine.DebugUI.dock,'SetHeight'},{c.engine.DebugUI.terminalOutput.frame,'SetWidth'}}) do watch(entry[1],entry[2],'geometry') end
  watch(c.engine.Query.Console,'UpdateLineNumbers','gutter');watch(c.edit,'SetText','text');watch(c.edit,'SetCursorPosition','cursor');watch(c.edit,'SetFocus','focus')
  watch(c.argumentLabel,'SetText','chrome')
  for _,button in ipairs({c.play,c.engine.Workspace.debugButton}) do watch(button,'SetEnabled','chrome');watch(button,'Enable','chrome') end
  -- Real native size reads round through effective scale; an immaterial
  -- difference must not keep rebuilding the anchored native input.
  local getWidth=input.frame.GetWidth;input.frame.GetWidth=function(self) return getWidth(self)+.00003051758 end
  for tick=1,100 do c:Layout();frameTick(c,1/60) end
  assert(counts.geometry==0,'settled workbench kept writing anchored input/debugger geometry')
  assert(counts.gutter==0,'settled workbench kept redrawing its gutter')
  assert(counts.chrome==0,'settled workbench kept rewriting labels or enabling action buttons')
  assert(counts.text==0 and counts.cursor==0 and counts.focus==0 and changes==0 and c.edit:GetCursorPosition()==2 and c.edit:HasFocus(),'idle workbench changed source caret focus or history')
  c.play:Disable();c.engine.Workspace.debugButton:Disable();frameTick(c,1/60)
  assert(c.play:IsEnabled() and c.engine.Workspace.debugButton:IsEnabled(),'prerequisite actions were left disabled')
  c:SetContext({kind='condition',id='LABEL',callback='evaluate',source={fields={},bindings={}}});assert(c.argumentLabel:GetText()=='Arguments from Test','changed context retained old argument label');c:Release()
 end
end)
test('workbench resize reentry settles and debugger drawer geometry follows real bounds',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c.frame:SetSize(600,300);c:SetText('first\nsecond');c.edit:SetCursorPosition(3)
 local input=c.engine.Query.Console.input;local D=c.engine.Debugger;local U=c.engine.DebugUI;local setSize=input.frame.SetSize;local writes=0
 input.frame.SetSize=function(self,...)
  writes=writes+1;assert(writes<=4,'native size feedback recursively rebuilt workbench');setSize(self,...);c:Layout()
 end
 local points={};local setPoint=input.scrollBG.SetPoint;input.scrollBG.SetPoint=function(self,anchor,...) points[anchor]={...};return setPoint(self,anchor,...) end
 c.frame:SetSize(720,420);assert(writes==1 and input.frame:GetWidth()==720 and input.frame:GetHeight()==420,'actual resize did not settle once')
 D.armed=true;U.drawerOpen=true;c:Layout();assert(U.toolbar:IsShown() and U.dock:IsShown() and U.dock:GetHeight()==168,'debugger drawer did not open within bounds')
 assert(points.TOPLEFT[4]==-60 and points.BOTTOMRIGHT[4]==196,'active debugger did not reserve drawer edges')
 c.frame:SetSize(720,180);assert(not U.dock:IsShown() and points.BOTTOMRIGHT[4]==28,'small owner did not collapse debugger drawer')
 c.frame:SetSize(720,420);assert(U.dock:IsShown(),'drawer did not recover after resize');D.armed=false;c:Layout();assert(not U.toolbar:IsShown() and not U.dock:IsShown() and points.TOPLEFT[4]==-28,'stopped debugger retained code inset')
 local settled=writes;for i=1,50 do c:Layout() end;assert(writes==settled and c.edit:GetCursorPosition()==3 and c:GetText()=='first\nsecond','resized workbench kept rewriting its input');c:Release()
end)
test('workbench gutter follows queued text cursor scroll resize and preference events without idle polling',function()
 local f,a=fixture();local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c.frame:SetSize(600,300);c:SetText('first');c.edit:SetCursorPosition(2);c:Layout();frameTick(c)
 local C=c.engine.Query.Console;local input=C.input;local counts=c.lineNumberCounts
 c:SetText('first\nsecond\nthird');assert(c.lineNumberQueue.pending,'source change did not queue gutter');frameTick(c);assert(#input.queryLineNumbers.positions==3,'source change left gutter stale')
 local before=counts.calls;c.edit:SetCursorPosition(8);c.edit:GetScript('OnCursorChanged')(c.edit,14,-14,2,12);assert(counts.calls>before,'cursor no longer queues gutter');frameTick(c)
 before=counts.calls;input.scrollFrame:SetVerticalScroll(10);input.scrollFrame:GetScript('OnVerticalScroll')(input.scrollFrame,10);assert(counts.calls>before,'scroll no longer queues gutter');frameTick(c)
 before=counts.calls;input.scrollFrame:SetSize(500,200);assert(counts.calls>before,'viewport size no longer queues gutter');frameTick(c)
 before=counts.flushes;for i=1,100 do frameTick(c,1/60) end;assert(counts.flushes==before,'idle frames flush unchanged gutter')
 a.db.profile.lua_line_numbers=false;frameTick(c,1/60);assert(not c.lineNumbersVisible and not input.queryLineNumbers and not c.lineNumberQueue,'preference did not detach gutter')
 a.db.profile.lua_line_numbers=true;frameTick(c,1/60);assert(c.lineNumbersVisible and #input.queryLineNumbers.positions==3,'preference did not restore current gutter')
 assert(c.edit:GetCursorPosition()==8 and c:GetText()=='first\nsecond\nthird','gutter preference changed caret/source');c:Release()
end)

finish()
