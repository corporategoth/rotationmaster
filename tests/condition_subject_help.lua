-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local fixture=assert(loadstring(assert(read('tests/condition_editor_ui.lua'):match('^(.-)\ntest%('))..'\nreturn fixture','@condition-subject-fixture'))()
local function setup(options)
 options=options or{};local f=fixture();local a,e=f.addon,f.env
 dofile('tests/fixtures/workbench_help_contract.lua')(a,e)
 if arg and arg[1] then assert(not a.rmHelpContractAdapter,'actual viewer was not loaded') end
 local count={help=0,widget=0,valid=0,evaluate=0};local definition={description='Subject number',fields={number='number'},requiredFields={'number'},customCode=options.custom,
 valid=function(_,value)count.valid=count.valid+1;return type(value.number)=='number'end,
 evaluate=function()count.evaluate=count.evaluate+1;error('Help must not evaluate')end,
 print=function()return 'Subject number'end,
 widget=function(parent,_,value)count.widget=count.widget+1;local w=a:CreateConditionSlider();w:SetValue(value.number);w:SetCallback('OnValueChanged',function(_,_,v)value.number=v;parent:GetUserData('top'):SetStatusText()end);parent:AddChild(w)end,
 help=function(parent)count.help=count.help+1;local label=a:CreateConditionLabel();label:SetText('Only subject documentation');parent:AddChild(label)end}
 a:RegisterCondition('SUBJECT',definition)
 local root={type='SUBJECT',number=7};local shell=a:ShowConditionEditor(1,0,root,nil,options.targetValid,{readOnly=options.readOnly});local card=shell.canvas.cards[1]
 if options.expanded then card.header:Click();card=shell.canvas.cards[1]end
 for k in pairs(count)do count[k]=0 end
 local request=a.OpenWorkbenchHelp;a.OpenWorkbenchHelp=function(self,descriptor)f.descriptor=descriptor;return request(self,descriptor)end
 return f,a,e,shell,card,count,definition,root
end
local function noEdits(shell)
 local sync=shell.SyncWorking;local render=shell.Render;local command=shell.active.session.Command
 shell.SyncWorking=function()error('Help synchronized fields')end;shell.Render=function()error('Help rerendered fields')end;shell.active.session.Command=function()error('Help edited history')end
 return function()shell.SyncWorking=sync;shell.Render=render;shell.active.session.Command=command end
end
test('collapsed expanded custom and readonly leaf cards render only registered subject Help',function()
 for _,options in ipairs({{},{expanded=true},{custom=true},{readOnly=true},{expanded=true,readOnly=true}})do
  local f,a,_,shell,card,count,_,root=setup(options);local pane=card.pane;local working=shell.active.working;local restore=noEdits(shell);card.controls.help:Click();restore()
  assert(count.help==1,'subject Help not invoked exactly once');assert(count.widget==0 and count.valid==0 and count.evaluate==0,'Help ran field/evaluation callbacks');assert(a.helpWindow and a.helpWindow.frame:IsShown());assert(shell.active.working==working and card.pane==pane and root.number==7);assert(not shell.view.help[''],'Help toggled field state')
 end
end)
test('invalid pending numeric text focus and session history survive subject Help',function()
 local _,a,_,shell,card,count,_,root=setup({expanded=true});local field=card.pane.children[1];field.editbox:SetText('invalid pending');field.editbox.scripts.OnTextChanged(field.editbox,true);field.editbox:SetFocus();local before=shell.active.session:HistoryState();local restore=noEdits(shell);card.controls.help:Click();restore()
 assert(count.help==1 and count.widget==0 and count.valid==0 and count.evaluate==0);assert(field.editbox:GetText()=='invalid pending'and field.editbox:HasFocus()and field:IsPending());assert(root.number==7 and shell.active.working.number==7);local after=shell.active.session:HistoryState();assert(before.canUndo==after.canUndo and before.canRedo==after.canRedo)
end)
test('logical group Help is static and leaves expansion geometry and fields untouched',function()
 local f=fixture();local a=f.addon;dofile('tests/fixtures/workbench_help_contract.lua')(a,f.env);local shell=a:EditCondition(1,0,{type='AND',value={{type='NUMBER',number=1}}});local card=shell.canvas.cards[1];local before=card.model.ownHeight;local restore=noEdits(shell);card.controls.help:Click();restore();assert(a.helpWindow and a.helpWindow.sections[1].text:find('AND',1,true));assert(card.model.ownHeight==before and not card.model.expanded and not card.pane)
end)
test('missing disabled suspended and function-unavailable definitions never run Help or pending source',function()
 for _,kind in ipairs({'missing','disabled','functionUnavailable','functionSuspended','no-help'})do
  local f,a,_,shell,card,count,definition=setup();if kind=='missing'then a.conditionDefinitions.SUBJECT=nil elseif kind=='no-help'then definition.help=nil else definition[kind]=true end
  a.db.global.custom_conditions={SUBJECT={help='error("pending source executed")'}};a.CompileCustomCondition=function()error('Help compiled pending source')end
  card.controls.help:Click();assert(count.help==0 and count.widget==0 and count.valid==0 and count.evaluate==0,kind);assert(a.helpWindow and #a.helpWindow.sections>0,kind..' needs static unavailable document')
 end
end)
test('retained card callback cannot open Help after card rebind or editor release',function()
 for _,kind in ipairs({'rebind','release'})do local f,_,_,shell,card,count=setup();local old=card.controls.help:GetScript('OnClick');if kind=='rebind'then shell:Render()else shell:Finish(false)end;old();assert(not f.descriptor and count.help==0,kind)end
end)
test('owner profile replacement and validity callback reentry retire Help before callback',function()
 local shell;local mutate=false;local f,a,_,opened,card,count=setup({targetValid=function()if mutate then shell.active=nil end;return true end});shell=opened;mutate=true;card.controls.help:Click();assert(count.help==0 and not a.helpWindow)
 f,a,_,shell,card,count=setup();local previous=a.db.profile;a.db.profile={};card.controls.help:Click();assert(count.help==0 and not a.helpWindow);a.db.profile=previous
end)
test('definition help lookup mutation cannot invoke a replaced definition',function()
 local _,a,_,_,card,count,definition=setup();definition.help=nil;setmetatable(definition,{__index=function(_,key)if key=='help'then a.conditionDefinitions.SUBJECT={description='Replacement'};a.conditionRegistryVersion=a.conditionRegistryVersion+1;return function()count.help=count.help+1 end end end});card.controls.help:Click();assert(count.help==0,'retired help getter function ran')
end)
test('registered Help exceptions release partial output and cannot alter editor draft',function()
 local _,a,_,shell,card,count,definition,root=setup();local created;definition.help=function(parent)count.help=count.help+1;created=a:CreateConditionLabel();created:SetText('partial');parent:AddChild(created);error('subject help failure')end
 local ok=pcall(function()card.controls.help:Click()end);assert(ok and count.help==1);assert(created and not created.rmActive,'failed Help leaked widgets');assert(shell.active and root.number==7 and shell.active.working.number==7 and count.widget==0 and count.evaluate==0)
end)
test('Help callback definition replacement retires output while newer reentrant Help survives',function()
 local f,a,_,shell,card,_,definition=setup();local oldLabel,newLabel
 definition.help=function(parent)
  oldLabel=a:CreateConditionLabel();oldLabel:SetText('old');parent:AddChild(oldLabel)
  local replacement={description='New subject',help=function(nextParent)newLabel=a:CreateConditionLabel();newLabel:SetText('new');nextParent:AddChild(newLabel)end};a.conditionDefinitions.SUBJECT=replacement;a.conditionRegistryVersion=a.conditionRegistryVersion+1;shell:ShowSubjectHelp(card.model,function()return true end)
 end
 card.controls.help:Click();assert(oldLabel and not oldLabel.rmActive,'old request output survived');assert(newLabel and newLabel.rmActive and a.helpWindow and a.helpWindow.frame:IsShown(),'old request released newer document')
end)
test('Help mount releases once and cannot release widgets reused by a newer document',function()
 local f,a,_,_,card,_,definition=setup();local label;definition.help=function(parent)label=a:CreateConditionLabel();label:SetText('owned');parent:AddChild(label)end;card.controls.help:Click();local descriptor=f.descriptor;local releaseLabel=label;local oldDocument=a.helpWindow;oldDocument.close:Click();assert(not releaseLabel.rmActive);local mount
 local parent=f.env.CreateFrame('Frame',nil,f.env.UIParent);mount=descriptor.render(parent,function()return descriptor.valid()end,0,490);assert(mount);mount:Release();mount:Release();assert(not label.rmActive)
end)
test('actual authored known-spell Help renders unchanged without its Fields UI',function()
 local f=fixture();local a=f.addon;a.Platform.GetSpellInfo=function(_,id)return {spellID=id,name='Lightning Bolt'}end;f.load('Conditions/known_spell.lua');local definition=a.conditionDefinitions.SPELL_KNOWN;local originalHelp=definition.help;local root={type='SPELL_KNOWN',spell=403};local shell=a:EditCondition(1,0,root);local count=0;definition.help=function(parent)count=count+1;return originalHelp(parent)end;a.widgetCondition=function()error('Help entered actual Fields UI')end;a.evaluateConditionResult=function()error('Help entered evaluation')end;local restore=noEdits(shell);shell.canvas.cards[1].controls.help:Click();restore();assert(count==1 and root.spell==403);assert(a.helpWindow and a.helpWindow.frame:IsShown())
end)
test('rendered Help callbacks retire with their source owner',function()
 local _,a,_,shell,card,_,definition=setup();local button;local calls=0;definition.help=function(parent)button=a:CreateConditionButton();button:SetText('Example');button:SetCallback('OnClick',function()calls=calls+1 end);parent:AddChild(button)end;card.controls.help:Click();assert(button and button.rmActive);local callback=button.events.OnClick;callback();assert(calls==1);shell:Finish(false);callback();assert(calls==1,'retired source Help callback ran')
end)
test('pre-render definition lookup reentry cannot replace a newer Help request',function()
 local _,a,_,_,card,count,definition=setup();local original=definition.help;definition.help=nil;local entered=false
 setmetatable(definition,{__index=function(_,key)if key=='help'then if not entered then entered=true;a:OpenWorkbenchHelp({heading='Newer Help',sections={{title='Newer',text='new subject'}}})end;return original end end})
 card.controls.help:Click();assert(entered and a.helpWindow and a.helpWindow.heading=='Newer Help','older lookup replaced newer document');assert(count.help==0)
end)
test('retired mount cannot rebind callbacks belonging to its recycled output group',function()
 local _,a,_,_,card,_,definition=setup();local replacement,button,callback
 definition.help=function(parent)
  a:ReleaseConditionWidget(parent);replacement=a:CreateConditionGroup();assert(replacement==parent,'group reuse fixture failed');button=a:CreateConditionButton();button:SetText('Other owner');button:SetCallback('OnClick',function()end);replacement:AddChild(button);callback=button.events.OnClick
 end
 card.controls.help:Click();assert(replacement.rmActive and button.rmActive);assert(button.events.OnClick==callback,'old mount rebound recycled group');a:ReleaseConditionWidget(replacement)
end)
finish()
