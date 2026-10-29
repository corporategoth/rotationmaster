-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite();local locales={}
local function setup()
 local f=F.new();local a,e=f.addon,f.env;locales[a]=f.libraries['AceLocale-3.0']:GetLocale('RotationMaster');a.db.char={};a.pretty_name='Rotation Master'
 local data=dofile('tests/fixtures/rotation_data.lua')();a.RotationData=data
 for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Core/rotation_library.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Core/function_data.lua','UI/window.lua','UI/help.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_ordered.lua','UI/settings_draft.lua','UI/settings_history.lua','UI/settings_unsaved.lua','UI/settings_form.lua','UI/settings_collections.lua','UI/settings_transfer.lua','UI/settings_profiles.lua','UI/lua_input_diagnostics.lua','UI/lua_editor.lua','UI/function_source_pane.lua','UI/function_bundle_transfer.lua','UI/transfer.lua'})do f.load(path)end
 if arg and arg[1]then f.load(arg[1])end
 local host=e.CreateFrame('Frame',nil,e.UIParent);host:SetSize(1000,650);local p=a:CreateSettingsForm(host);p:Open(function()end)
 return f,a,e,p
end
local function profiles()
 local f,a,e,p=setup();f.load('init.lua');local defaults={profile={poll=.15,rotations={}},global={},char={}};a:augmentDefaults(defaults)
 local current='Default';local values={Default=defaults.profile,Other={poll=.2}};a.db.profiles=values;a.db.profile=values.Default;a.db.global=defaults.global;local calls={decode=0,reset=0,set=0}
 a.db.GetCurrentProfile=function()return current end;a.db.GetProfiles=function()local names={};for name in pairs(values)do names[#names+1]=name end;return names end
 a.db.SetProfile=function(_,name)calls.set=calls.set+1;values[name]=values[name]or{poll=.15};current=name;a.db.profile=values[name]end
 a.db.ResetProfile=function()calls.reset=calls.reset+1;values[current]={poll=.15};a.db.profile=values[current]end
 local wrapper={format='RM-Profile',version=1,name='Incoming',profile={version=2,poll=.4}}
 a.NewRotationCodec=function()return{Encode=function()return'encoded'end,Decode=function()calls.decode=calls.decode+1;return{value=a:CopySettingsData(wrapper)}end}end
 local host=e.CreateFrame('Frame',nil,e.UIParent);host:SetSize(1000,650);p=a:OpenNativeSettings(host,'Profiles');p.fields.transfer:Click();return f,a,e,p,p.textDialog,calls,values
end
local function assertDocument(a,topic)
 if topic:match('^Help%.Transfers%.')then topic=locales[a][topic]end
 assert(a.helpWindow and a.helpWindow.frame:IsShown(),'Help document did not open');local found=false;for _,section in ipairs(a.helpWindow.sections or{})do if section.text:find(topic,1,true)then found=true end end;assert(found,'wrong Help topic '..topic)
end
local function transfer(a,p,extra)
 local options={canReplace=true,selectedName='Selected',fallbackName='Copy',originalName=function()return 'Source'end,help={heading='Transfer help',sections={{title='Transfer',text='exact transfer subject'}},briefs={apply='Import shown destination',copy='Select export text'}}};for k,v in pairs(extra or{})do options[k]=v end
 return a:ShowSettingsTextTransfer(p,'Transfer','Encoded text',function()error('Help accepted import')end,options)
end
test('optional transfer Help opens full subject without changing pending text focus selection or controls',function()
 local _,a,_,p=setup();local d=transfer(a,p);assert(d.help,'missing local transfer Help');assert(d.help:GetWidth()==20 and d.help.icon:GetWidth()==18,'Help chrome size');d.input:SetText('Pending invalid bytes\0\255');d.input:SetFocus();d.input:HighlightText(2,9);local text=d.input:GetText();local enabled=d.apply:IsEnabled();p.FlushEdits=function()error('Help flushed edits')end;p.WithSettingsHistory=function()error('Help entered history')end
 d.help:Click();assertDocument(a,'exact transfer subject');assert(d.input:GetText()==text and d.input:HasFocus()and d.input.selection[1]==2 and d.input.selection[2]==9 and d.apply:IsEnabled()==enabled)
end)
test('unconfigured reuse hides Help and retires captured transfer click',function()
 local _,a,_,p=setup();local d=transfer(a,p);local old=d.help:GetScript('OnClick');d=a:ShowSettingsTextTransfer(p,'No metadata','Other',function()return true end);assert(not d.help:IsShown());old();assert(not a.helpWindow)
end)
test('transfer serial and profile replacement retire old Help handlers',function()
 for _,kind in ipairs({'serial','profile','global','char'})do local _,a,_,p=setup();local d=transfer(a,p);local old=d.help:GetScript('OnClick');if kind=='serial'then transfer(a,p)else a.db[kind]={}end;old();assert(not a.helpWindow,kind)end
end)
test('Help validity callback reentry cannot authorize a replacement transfer or overwrite newer Help',function()
 local _,a,_,p=setup();local changed=false;local d=transfer(a,p,{help={heading='Old',sections={{title='Old',text='old subject'}},valid=function()if not changed then changed=true;a:OpenWorkbenchHelp({heading='Newer',sections={{title='Newer',text='new subject'}}})end;return true end}});d.help:Click();assertDocument(a,'new subject');assert(a.helpWindow.heading=='Newer')
end)
test('read-only report Help retains bytes focus and selection and nil metadata retires previous report',function()
 local _,a=setup();local d=a:CreateWorkbenchTextReport();d:SetReport('Report','Raw report text','Source',{heading='Report Help',sections={{title='Report',text='read-only report subject'}}});assert(d.help);local before=d.input:GetText();local selection=d.input.selection;d.help:Click();assertDocument(a,'read-only report subject');assert(d.input:GetText()==before and d.input:HasFocus()and d.input.selection==selection and not d.apply:IsShown());local old=d.help:GetScript('OnClick');d:SetReport('Other','Second');a.helpWindow.close:Click();old();assert(not a.helpWindow.frame:IsShown())
end)
test('bundle Help and imported source Help do not review compile import or flush code',function()
 local f,a,_,p=setup();local encoded={};a.NewRotationCodec=function()return{Encode=function(_,value)encoded.value=value;return'encoded'end,Decode=function()error('Help decoded source')end}end
 local source={name='Helper',description='Source',args={},returns={},code='return 1',bindings={}}
 local d=a:ShowFunctionBundleTransfer(p,'HELPER',source);assert(d.help,'bundle omitted Help');d.input:SetText('Pending unknown source');local before=d.input:GetText();d.Review=function()error('Help reviewed')end;d.form.FlushEdits=function()error('Help flushed bundle edits')end;a.CompileCustomCondition=function()error('Help compiled imported source')end;a.ApplyFunctionBundleImport=function()error('Help applied source')end;d.help:Click();assertDocument(a,"Export produces a function or condition bundle, optionally with its custom function dependencies. For import, paste bundle text, choose Review import, inspect the proposed identifiers and conflicts, and review source before applying. Apply import can register trusted Lua source; accept only source you intend to run. Changing the text invalidates the prior plan. Opening Help neither reviews nor applies the bundle.");assert(d.input:GetText()==before)
 local row={kind='function',originalID='ORIGINAL',destinationID='IMPORTED',originalName='Imported helper',source=source};d.lastRows={row};d.plan={rows=d.lastRows};local view=a:ShowFunctionBundleSource(d,row,d.OwnerValid);assert(view.help,'source review omitted Help');view.form.FlushEdits=function()error('Help flushed readonly source')end;local code=view.code:GetText();view.help:Click();assertDocument(a,"This view shows the selected imported function or condition source, its original and destination identifiers, and available metadata. For a condition, choose a callback to inspect its text. This view and its Help do not compile, execute, accept, or register the source. Return to the bundle review to decide whether to import it.");assert(view.code:GetText()==code)
end)
test('source review Help retires after row plan or source body replacement',function()
 for _,kind in ipairs({'plan','row','source','body'})do local _,a,e,p=setup();a.NewRotationCodec=function()return{Encode=function()return'encoded'end}end;local source={name='Helper',args={},returns={},code='return 1',bindings={}};local d=a:ShowFunctionBundleTransfer(p,'HELPER',source);local row={kind='function',originalID='HELPER',destinationID='HELPER',originalName='Helper',source=source};d.lastRows={row};d.plan={rows=d.lastRows};local view=a:ShowFunctionBundleSource(d,row,d.OwnerValid);local old=view.help:GetScript('OnClick');if kind=='plan'then d.plan={}elseif kind=='row'then d.lastRows={}elseif kind=='source'then row.source=a:CopySettingsData(source)else source.code='return 2'end;old();assert(not a.helpWindow,kind)end
end)
test('actual profile import Help distinguishes NEW staged draft from REPLACE immediate write without importing',function()
 local _,a,_,p,d,calls,values=profiles();assert(d.help,'profile import omitted local Help');local text=d.input:GetText();local decoded=calls.decode;d.help:Click();assertDocument(a,"REPLACE applies immediately to the selected saved profile after Import. Replacing the active profile resets it and applies the imported settings; replacing another profile writes that profile. Reopen the import if the selected saved profile changes.");assert(calls.decode==decoded and calls.reset==0 and calls.set==0 and d.input:GetText()==text and not p.creating)
 d.destination:Click();d.help:Click();assertDocument(a,"NEW stages the imported profile in the Profiles editor. Import fills a new-profile draft; the new profile is not saved or activated until you complete the creation controls in that editor. Give it an unused name.");assert(calls.reset==0 and calls.set==0 and not values.Incoming);d.name:SetText('Imported');d.name.scripts.OnTextChanged(d.name,true);d.apply:Click();assert(p.creating and not values.Imported and calls.reset==0,'NEW did not remain staged')
end)
test('actual profile REPLACE still writes immediately after Help and changed selected source retires Help',function()
 local _,a,_,p,d,calls=profiles();d.help:Click();assert(calls.reset==0);d.apply:Click();assert(calls.reset==1 and a.db.profile.poll==.4 and not d.frame:IsShown(),'REPLACE behavior changed')
 local _,b,_,_,dialog=profiles();local old=dialog.help:GetScript('OnClick');b.db.profile.poll=.2;old();assert(not b.helpWindow,'changed selected profile retained Help source lease')
end)
test('closed transfer Help handlers cannot revive after direct frame hide and show',function()
 local _,a,_,p=setup();local d=transfer(a,p);local old=d.help:GetScript('OnClick');d.frame:Hide();d.frame:Show();old();assert(not a.helpWindow,'closed Help lease revived')
 d=transfer(a,p);d.help:Click();assertDocument(a,'exact transfer subject')
end)
test('changed bundle export source retires Help even with current form and serial',function()
 for _,kind in ipairs({'identity','body'})do local _,a,_,p=setup();a.NewRotationCodec=function()return{Encode=function()return'encoded'end}end;local source={name='Helper',args={},returns={},code='return 1',bindings={}};local d=a:ShowFunctionBundleTransfer(p,'HELPER',source);local old=d.help:GetScript('OnClick');if kind=='identity'then d.exportSource={}else source.code='return 2'end;old();assert(not a.helpWindow,kind..' source retained Help')end
end)
test('stale profile Help cannot hide an unrelated newer document',function()
 local _,a,_,p=setup();local d=transfer(a,p);local old=d.help:GetScript('OnClick');a:OpenWorkbenchHelp({heading='Unrelated newer',sections={{title='Newer',text='newer unrelated subject'}}});a.db.profile={};old();assertDocument(a,'newer unrelated subject')
end)
test('actual rotation transfer Help preserves text and preview admission without invoking import work',function()
 local f,a=setup();local data,envelope,options=dofile('tests/fixtures/rotation_data.lua')();a.RotationData=data;a.conditionDefinitions=options.conditions;a.db.keys={char='A - Realm'};local n=0;a.uuid=function()n=n+1;return'help-transfer-'..n end
 for _,path in ipairs({'Data/import_session.lua','Data/rotation_draft.lua','Core/imports.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','UI/rotation_comparison.lua'})do f.load(path)end
 local body=envelope().body;a.db.profile={rotationFallbackID='Default',rotationStore={version=1,classes={SHAMAN={[0]={mine={body=body}}}},characters={},legacy={}}}
 a.GetRotationContext=function(_,spec)return{class='SHAMAN',family='tbc',spec=spec,actionContext='player',combatDataPolicy='probe'}end;assert(a:BindRotationProfile())
 local calls=0;a.NewRotationCodec=function()return{Encode=function()return'encoded'end,Decode=function()calls=calls+1;return{kind='legacy',value=data.CopyData(body)}end}end
 local d=a:ShowRotationTransfer(0,'mine');assert(d.help);local decoded=calls;local text=d.input:GetText();local enabled=d.apply:IsEnabled();a.rotationTransferForm.FlushEdits=function()error('Help flushed rotation')end;a.ApplyRotationImport=function()error('Help imported rotation')end
 d.help:Click();assertDocument(a,"Copy the text to export the current rotation, or paste a rotation to import. Choose replacement of the selected editable rotation or a new named copy. Class and This character set the owner of a new copy; replacement keeps the original owner. The imported rotation is opened for editing after a successful import.");assertDocument(a,"With Replace selected entry ticked, the button reads Compare import and shows what would change in that rotation. For a new named copy it reads Preview import and shows everything the import contains, read-only, as the rotation editor shows it. Neither saves anything. Import is enabled only for a ready preview or comparison; changing the text requires another one. Check import shows read-only diagnostics, including unsupported data that prevents import.");assert(calls==decoded and d.input:GetText()==text and d.apply:IsEnabled()==enabled and not enabled)
 local old=d.help:GetScript('OnClick');a.helpWindow.close:Click();a.db.profile={};old();assert(not a.helpWindow.frame:IsShown(),'retired rotation retained Help')
end)
test('actual comparison Help stays read-only and retires on view graph generation or dialog replacement',function()
 for _,kind in ipairs({'view','graph','generation','serial','hide'})do
  local f,a,_,p=setup();for _,path in ipairs({'Data/visual_comparison.lua','UI/rotation_reference.lua','UI/rotation_comparison.lua'})do f.load(path)end
  a.Platform={GetSpellInfo=function(_,id)return{name='Spell '..id,spellID=id,iconID=id}end,GetSpellLink=function(_,id)return'|Hspell:'..id..'|h[Named spell]|h'end};a.printCondition=function()return'Readable conditions'end
  local view={key='import',left={body={rotation={}}},right={body={rotation={}}}};view.diff=a.RotationData.DiffRotations(view.left,view.right)
  local d=a:ShowNativeImportPreview(p,view,0);local graph=d.graph;d.help:Click();assertDocument(a,"This view compares the saved or exported rotation with the current incoming preview. It does not apply changes. Close it to choose the destination and import from the transfer dialog. A changed preview, closed owner, or changed profile retires this comparison Help.");assert(d.graph==graph and graph.rmActive);local old=d.help:GetScript('OnClick');a.helpWindow.close:Click()
  if kind=='view'then view.right.body.rotation[1]={id='changed'}elseif kind=='graph'then a:ReleaseConditionWidget(graph);a:CreateConditionGroup()elseif kind=='generation'then p.generation=p.generation+1 elseif kind=='serial'then a:ShowNativeImportPreview(p,view,0)else d.frame:Hide();d.frame:Show()end
  old();assert(not a.helpWindow.frame:IsShown(),'comparison retained '..kind)
 end
end)
test('lazy transfer sections reentry cannot replace newer Help or mutate replacement dialog',function()
 local _,a,_,p=setup();local replacement;local d=transfer(a,p,{help={heading='Old',sections=function()
  replacement=transfer(a,p,{help={heading='Replacement',sections={{title='New',text='newer transfer subject'}}}});replacement.help:Click();return{{title='Old',text='retired old subject'}}
 end}});d.help:Click();assertDocument(a,'newer transfer subject');assert(a.helpWindow.heading=='Replacement' and replacement.transferHelpLease==d.transferHelpLease)
end)
test('obsolete or reentrant owner admission cannot replace current transfer Help binding',function()
 local _,a,_,p=setup();local d=transfer(a,p);local current=d.transferHelpLease
 a:BindTransferHelp(d,{heading='Retired',sections={{title='Old',text='old'}}},function()return false end);assert(d.transferHelpLease==current,'stale owner replaced current Help binding')
 local changed=false;a:BindTransferHelp(d,{heading='Old reentry',sections={}},function()if not changed then changed=true;transfer(a,p,{help={heading='Current replacement',sections={{title='New',text='current replacement subject'}}}})end;return true end)
 d.help:Click();assertDocument(a,'current replacement subject')
end)
test('transfer brief hover preserves native tooltip behavior and retired hover is inert',function()
 local _,a,e,p=setup();local d=transfer(a,p);local native=0;local tip={}
 function tip:SetOwner(owner)self.owner=owner end;function tip:IsOwned(owner)return self.owner==owner end;function tip:SetText(text)self.text=text end;function tip:AddLine(text)self.line=text end;function tip:Show()self.shown=true end;function tip:Hide()self.shown=false end;e.GameTooltip=tip
 a:SetUIScript(d.copy,'OnEnter',function()native=native+1;tip:SetOwner(d.copy);tip:SetText('native hint')end)
 a:BindTransferHelp(d,{sections={},briefs={copy='Select the export text'}},function()return true end)
 local enter=d.copy:GetScript('OnEnter');enter(d.copy);assert(native==1 and tip.text=='native hint' and tip.line=='Select the export text' and tip.shown)
 d.frame:Hide();tip:Hide();enter(d.copy);assert(native==1 and not tip.shown,'retired hover ran native or brief callbacks')
end)
test('imported condition source Help never compiles callbacks and retains opaque source bytes',function()
 local _,a,_,p=setup();a.NewRotationCodec=function()return{Encode=function()return'encoded'end}end
 local source={name='Imported',description='Readonly',evaluate='invalid Lua\0\255',help='error("imported help executed")',future={bytes='opaque\0\255'}}
 local d=a:ShowFunctionBundleTransfer(p,'CONDITION',nil,{kind='condition'});local row={kind='condition',originalID='ORIGINAL',destinationID='COPY',originalName='Imported',source=source};d.lastRows={row};d.plan={rows=d.lastRows}
 a.CompileCustomCondition=function()error('Help compiled imported condition')end;a.RegisterCustomCondition=function()error('Help registered imported condition')end
 local view=a:ShowFunctionBundleSource(d,row,d.OwnerValid);local code=view.code:GetText();local saved=a:CopySettingsData(source);view.help:Click();assertDocument(a,"This view shows the selected imported function or condition source, its original and destination identifiers, and available metadata. For a condition, choose a callback to inspect its text. This view and its Help do not compile, execute, accept, or register the source. Return to the bundle review to decide whether to import it.");assert(view.code:GetText()==code and a:SettingsDataEqual(source,saved),'Help changed imported condition bytes')
end)
test('owner admission cannot adopt database roots replaced by its own callback',function()
 for _,root in ipairs({'profile','global','char'})do local _,a,_,p=setup();local d=transfer(a,p);local lease=d.transferHelpLease
  a:BindTransferHelp(d,{heading='Obsolete owner',sections={}},function()a.db[root]={};return true end)
  assert(d.transferHelpLease==lease,'adopted replaced '..root..' root')
 end
end)
finish()
