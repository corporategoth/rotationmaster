local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);f.env.C_Timer={After=function(_,callback) callback() end};f.env.GetLocale=function() return "enUS" end;f.env.SlashCmdList={};f.env.StaticPopupDialogs={}
 local create=f.env.CreateFrame;local function augmented(frame) function frame:RegisterEvent() end;function frame:SetShown(value) if value then self:Show() else self:Hide() end end
 function frame:SetEnabled(value) if value then self:Enable() else self:Disable() end end
 function frame:GetTextColor() return unpack(self.textColor or {1,1,1,1}) end
 function frame:GetFont() return 'Fonts\\FRIZQT__.TTF',12,'' end
 function frame:SetFont() end
 function frame:SetSpacing(value) self.spacing=value end;function frame:GetSpacing() return self.spacing or 0 end
 function frame:SetJustifyH(value) self.justifyH=value end
 function frame:SetNonSpaceWrap() end
 function frame:GetTextInsets() return unpack(self.textInsets or {0,0,0,0}) end
 function frame:GetVerticalScroll() return self.scrollOffset or 0 end
 function frame:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight()) end
 function frame:GetPoint() return unpack(self.point or {'CENTER'}) end
 function frame:GetTop() return 500 end;function frame:GetBottom() return 200 end;function frame:GetLeft() return 0 end;function frame:SetClipsChildren() end;function frame:IsMouseOver() return false end;function frame:GetAltArrowKeyMode() return self.altArrowKeyMode end;function frame:SetHistoryLines() end;function frame:SetObeyStepOnDrag() end;function frame:GetFontObject() return "ChatFontNormal" end
 function frame:UnregisterAllEvents() self.eventsCleared=true end;local texture,fontstring=frame.CreateTexture,frame.CreateFontString
 function frame:CreateTexture(...) return augmented(texture(self,...)) end
 function frame:CreateFontString(...) return augmented(fontstring(self,...)) end
 function frame:CreateLine(...) return self:CreateTexture(...) end;function frame:SetStartPoint() end;function frame:SetEndPoint() end;function frame:SetThickness() end
 function frame:CreateMaskTexture(...) return self:CreateTexture(...) end;function frame:AddMaskTexture() end
 return frame end
 f.env.CreateFrame=function(...) return augmented(create(...)) end
 local ace=f.libraries['AceGUI-3.0'];local aceCreate=ace.Create
 ace.Create=function(self,kind)
  local widget=aceCreate(self,kind);widget.frame=widget.frame or f.env.CreateFrame('Frame');widget.userdata=widget.userdata or {}
  if kind=='SimpleGroup' then
   function widget:DoLayout() local height=0;for _,child in ipairs(self.children) do height=height+(child.frame and child.frame:GetHeight() or 20) end;self.frame:SetHeight(math.max(1,height));if self.LayoutFinished then self:LayoutFinished(self.frame:GetWidth(),height) end end
   local add=widget.AddChild;function widget:AddChild(child) add(self,child);if child.frame then child.frame:SetParent(self.frame) end;self:DoLayout() end
  end;return widget
 end
 ace.Release=function(self,widget) if widget.isQueuedForRelease then return end;widget.isQueuedForRelease=true;for _,child in ipairs(widget.children or {}) do self:Release(child) end;if widget.OnRelease then widget:OnRelease() end;if widget.frame then widget.frame:Hide() end end
 f.load('Core/custom_authoring.lua');f.load('Core/lua_symbols.lua');f.load('UI/settings_transfer.lua');f.load('UI/condition_source_preview.lua');f.load('UI/lua_debug_output.lua');f.load('UI/lua_completion.lua');f.load('UI/lua_editor.lua');f.load('Libs/LuaWorkbench-Embed/modules.lua');local file=io.open('Integrations/lua_workbench.lua');if file then file:close();f.load('Integrations/lua_workbench.lua') end
 f.env.LuaWorkbench={db={options={autocomplete=true},drafts={user={source='KEEP'}}}};f.env.LuaWorkbenchDB={drafts={user={source='KEEP'}}}
 return f,f.addon
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
 local f,a=fixture();f.env.IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end
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
 local f,a=fixture();f.env.IsAddOnLoaded=function(name) return name=='!!!LuaWorkbench' end
 local oldCalls,newCalls=0,0;local oldValid=true;local newValid=true
 local code=a:CreateWorkbenchLuaEditor(f.env.UIParent,function() oldCalls=oldCalls+1 end,function() return oldValid end,'LuaWorkbench')
 code:SetContext({kind='function',id='REOPEN',source={args={},bindings={}}});code:SetText('return 1');local previous=code.inner
 code:Release();oldValid=false;assert(type(code.Acquire)=='function','optional provider cannot be reacquired')
 code:Acquire(function() newCalls=newCalls+1 end,function() return newValid end)
 assert(not code.released and code.inner~=previous and previous.engine.released,'released provider engine was reused')
 assert(code.inner.context.id=='REOPEN' and code:GetText()=='return 1','reopening lost editor state')
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
 local create=a.CreateConditionEditBox;local ace=f.libraries['AceGUI-3.0'];local aceCreate=ace.Create
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetText('addon.orphan=addon:CreateConditionEditBox(); error("orphan-error")');c:SetContext({kind='condition',id='ORPHAN',callback='widget',source=body,testOwner=owner});assert(c:Debug())
 for i=1,40 do if c.engine.Debugger.paused then c.engine.Debugger:StepOver() else c.engine.Debugger:Pump() end;assert(a.CreateConditionEditBox==create and ace.Create==aceCreate,'shared factories changed while the debugger is paused') end
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
 c.edit:GetScript('OnUpdate')(c.edit,.2);local input=c.completionEngine.Query.Console.input;local editor=c.completionEngine.Query.Editor
 for character=1,7 do assert(editor:HoverSourcePosition(input,(character-.5)*7,205)==1,'native hover misses function-name character '..character) end
 assert(editor:HoverSourcePosition(input,7.5*7,205)==nil,'opening parenthesis is included in the function hitbox')
 assert(editor:HoverSourcePosition(input,8.5*7,205)==9,'argument did not keep its own separate identifier hitbox')
 assert(font.justifyV=='TOP','hover geometry is not aligned to the EditBox text top');c:Release()
end)
test('advanced documentation resolves complete bare function references passed as arguments',function()
 local f,a=fixture();f.env.UnitExists=function() end;f.env.APIDocumentation={functions={{Name='UnitExists',Type='Function',Documentation={'Whether the unit exists'}}}}
 local c=a:CreateLuaWorkbenchControl(f.env.UIParent,function() end,function() return true end);c:SetReadOnly(true);assert(not c.edit:IsEnabled(),'readonly documentation view permits typing');c:SetContext({kind='function',id='REF',source={args={},bindings={}}})
 local source='getCached(cache, UnitExists, value.unit)';c:SetText(source);local input=c.engine.Query.Console.input;local state=input.queryEditor;local editor=c.engine.Query.Editor
 editor:Paint(input);local paths=c.engine.APIHelp:Paths(source,true);local first=assert(source:find('UnitExists',1,true));assert(paths[first]=='UnitExists','bare documented reference lost its documentation')
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
finish()
