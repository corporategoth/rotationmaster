local F=dofile('tests/fixtures/addon.lua');local make=dofile('tests/fixtures/rotation_data.lua');local test,finish=F.suite()
local function body(name) return {name=name,switch={},rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}} end
local function ref(scope,id) return {kind='custom',address={scope=scope or 'class',class='SHAMAN',owner=scope=='character' and 'A - Realm' or 'SHAMAN',spec=0,id=id or 'same'}} end
local function fixture()
    local f=F.new();local a=f.addon;local data,envelope,validation=make();a.RotationData=data;a.conditionDefinitions=validation.conditions
    a.db={keys={char='A - Realm'},char={},global={effects={}},profile={rotationFallbackID='Saved fallback',rotationLibrary={},rotationStore={version=1,classes={SHAMAN={[0]={same={body=body('Class')},['Saved fallback']={body=body('Class fallback')}},[2]={second={body=body('Other specialization')}}},MAGE={[0]={foreign={body=body('Foreign secret')}}}},characters={['A - Realm']={class='SHAMAN',specs={[0]={same={body=body('Character')}}}},['B - Realm']={class='SHAMAN',specs={[0]={other={body=body('Other character secret')}}}}},legacy={rotations={[0]={old=body('Unassigned secret')}}}}}}
    local context={class='SHAMAN',family='tbc',spec=0,actionContext='player',combatDataPolicy='probe'};a.GetRotationContext=function() return context end
    local n=0;a.uuid=function() n=n+1;return 'new-'..n end
    for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/visual_comparison.lua','Data/import_session.lua','Data/rotation_draft.lua','Data/rotation_store.lua','Core/rotation_references.lua','Core/rotation_library.lua','Core/rotation_tags.lua','Core/imports.lua','Core/rotation_scope.lua','Core/rotation_migration.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','UI/settings_layout.lua','UI/settings_roster_order.lua','UI/settings_history.lua','UI/settings_ordered.lua','UI/settings_form.lua','UI/settings_transfer.lua','UI/rotation_reference.lua','UI/rotation_comparison.lua','UI/transfer.lua','UI/settings_profiles.lua'}) do f.load(path) end
    a.GetRotationContext=function() return context end;assert(a:BindRotationProfile());a.Platform.GetSpellInfo=function(_,id) return {name='Spell '..id,spellID=id,iconID=id} end;a.printCondition=function() return 'Always' end
    a.NewRotationCodec=function() return {Encode=function() return 'export' end,Decode=function(_,text) if text=='bad' then return nil,'bad-text' end;return {kind='legacy',original=text,value=body('Incoming')} end} end
    a.ShowConfig=function(_,section,selection) a.selected={section=section,selection=selection};return a.selected end
    return f,a,context,envelope
end
local function pasted(d) d.input:SetText('incoming');d.input:GetScript('OnTextChanged')(d.input,true);d.preview:Click();assert(d.apply:IsEnabled()) end

test('profile projection is detached current-owner saved metadata across specs without switching binding',function()
    local _,a=fixture();local selected=a.db.profile;local coordinator=a:GetScopedRotationCoordinator();local other=a:CopySettingsData(selected)
    assert(a.GetProfileRotationHeaders,'profile projection missing')
    local before=a:CopySettingsData(other);local rows=assert(a:GetProfileRotationHeaders(other));assert(#rows==4)
    local names={};for _,row in ipairs(rows) do names[row.name]=true;assert(row.body==nil and row.record==nil and row.key==nil and row.reference.address.class=='SHAMAN');row.reference.address.class='MAGE';row.name='Mutated' end
    assert(names.Class and names.Character and names['Other specialization'] and not names['Foreign secret'] and not names['Unassigned secret'] and not names['Other character secret'])
    assert(a.db.profile==selected and a:GetScopedRotationCoordinator()==coordinator and a:SettingsDataEqual(before,other))
    assert(a:GetProfileRotationHeaders(other)[1].name~='Mutated')
end)
test('profile projection fails explicit legacy or missing configuration without guessing or leaking archive names',function()
    local _,a,c=fixture();local value,why=a:GetProfileRotationHeaders({rotations={[0]={old=body('Hidden')}}});assert(not value and why=='rotation-profile-recovery-required')
    local p=a:CopySettingsData(a.db.profile);p.rotationFallbackID=nil;value,why=a:GetProfileRotationHeaders(p);assert(not value and why=='missing-fallback-configuration')
    c.class='invalid';value,why=a:GetProfileRotationHeaders(a.db.profile);assert(not value and why=='missing-owner-context')
end)
test('native transfer captures exact Character replacement and selects issued key after success',function()
    local _,a=fixture();a.GetEditableRotation=function() error('ordinary UI used mutable getter') end
    local d=a:ShowRotationTransfer(0,ref('character'));assert(d.destination:GetChecked());pasted(d);d.apply:Click()
    -- Closing is the page's job once a successful import selects the new record (the real ShowConfig releases the page, which hides
    -- the dialog); the transfer callback no longer hides a dialog whose page has changed (bc33d965), and this ShowConfig is a stub.
    assert(a:GetRotationRecordSnapshot(0,ref('character')).body.name=='Character')
    assert(a:GetRotationRecordSnapshot(0,ref()).body.name=='Class');local selected=a.selected.selection
    assert(selected.id:sub(1,1)==string.char(1) and a:ResolveRotationReference(0,selected.id).address.scope=='character')
end)
test('native transfer copy scope defaults Class and can explicitly choose This Character',function()
    local _,a=fixture();local d=a:ShowRotationTransfer(0,ref());pasted(d);d.destination:Click();assert(d.scope and d.classScope and d.classScope:GetChecked() and not d.scope:GetChecked())
    d.scope:Click();d.name:SetText('Character copy');d.apply:Click();local r=assert(a:ResolveRotationReference(0,a.selected.selection.id));assert(r.address.scope=='character' and r.address.id~='same')
    assert(a:GetRotationRecordSnapshot(0,r).body.name=='Character copy')
    d=a:ShowRotationTransfer(0,ref());pasted(d);d.destination:Click();assert(not d.scope:GetChecked());d.name:SetText('Class copy');d.apply:Click();r=assert(a:ResolveRotationReference(0,a.selected.selection.id));assert(r.address.scope=='class')
end)
test('transfer stale input and apply callbacks cannot clear or import a reopened session',function()
    local _,a=fixture();local d=a:ShowRotationTransfer(0,ref());pasted(d);local input=d.input:GetScript('OnTextChanged');local apply=d.apply:GetScript('OnClick');local scope=d.scope:GetScript('OnClick')
    d=a:ShowRotationTransfer(0,ref('character'));pasted(d);input(d.input,true);scope();apply();assert(d.apply:IsEnabled() and d.frame:IsShown() and not a.selected)
    d.apply:Click();assert(a.selected)
end)
test('transfer guards record replacement owner and profile changes without mutating wrong records',function()
    local _,a,c=fixture();local d=a:ShowRotationTransfer(0,ref());pasted(d);local record,token=a:GetRotationRecordSnapshot(0,ref());record.body.name='External';assert(a:CommitRotationDraft(ref(),token,record,'class'));d.apply:Click();assert(not a.selected and a:GetRotationRecordSnapshot(0,ref()).body.name=='External')
    d=a:ShowRotationTransfer(0,ref());pasted(d);c.class='MAGE';d.apply:Click();assert(not a.selected);c.class='SHAMAN'
    d=a:ShowRotationTransfer(0,ref());pasted(d);a.db.profile=a:CopySettingsData(a.db.profile);d.apply:Click();assert(not a.selected)
end)
test('comparison uses full-reference self filtering and keeps same-ID different-owner target',function()
    local _,a=fixture();a.GetEditableRotation=function() error('ordinary UI used mutable getter') end
    -- The owner's rotations saved under another specialization key are offered too: where a
    -- rotation applies is its body.specs (none here: any specialization), not its key.
    local d=a:ShowRotationComparison(0,ref());assert(d and #d.chooser.list==3,'must include Character same ID, the rotation saved under key 2 and current saved fallback')
    local labels=table.concat(d.chooser.list,' ');assert(labels:find('Character',1,true) and labels:find('Other specialization',1,true) and not labels:find('Foreign secret',1,true))
    assert(d.summary:GetText():find('Class',1,true))
end)
test('comparison callbacks retire selected and target records and cannot affect a reopened pane',function()
    local _,a=fixture();local d=a:ShowRotationComparison(0,ref());local old=d.chooser.events.OnValueChanged
    d=a:ShowRotationComparison(0,ref('character'));local list=d.direction.list;old(d.chooser,'OnValueChanged',1);assert(d.direction.list==list)
    local record,token=a:GetRotationRecordSnapshot(0,ref('character'));record.body.name='Replaced';assert(a:CommitRotationDraft(ref('character'),token,record,'character'));d.frame:GetScript('OnUpdate')();assert(not d.frame:IsShown())
end)
local function profileForm(f,a)
    f.load('UI/settings_collections.lua')
    local profile=a.db.profile;a.db.profiles={Current=profile,Other=a:CopySettingsData(profile)}
    a.db.GetCurrentProfile=function() return 'Current' end;a.db.GetProfiles=function() return {'Current','Other'} end
    local host=f.env.CreateFrame('Frame');host:SetSize(1100,700);local p=a:CreateSettingsForm(host);p:Open(function(form) a:BuildProfileSettings(form) end)
    return p
end
test('native profile summary uses current-owner projection and recovery feedback without foreign names',function()
    local f,a=fixture();local p=profileForm(f,a);local words={};for _,label in ipairs(p.pool.text or {}) do words[#words+1]=label:GetText() end;local text=table.concat(words,' ')
    assert(text:find('Character',1,true) and text:find('Class',1,true) and not text:find('secret',1,true))
    a.db.profiles.Other={rotations={[0]={old=body('Unassigned secret')}}};p.selection='Other';p:Draw();words={};for _,label in ipairs(p.pool.text or {}) do if label:IsShown() then words[#words+1]=label:GetText() end end;text=table.concat(words,' ')
    assert(not text:find('Unassigned secret',1,true) and text:find('recovery',1,true))
end)
test('native profile import migrates detached exact legacy bodies and refuses missing scoped configuration',function()
    local f,a=fixture();local p=profileForm(f,a);local wire={version=2,rotations={['0']={Untouched={}}}};local decoded=wire
    a.NewRotationCodec=function() return {Encode=function() return 'profile' end,Decode=function() return {value={format='RM-Profile',version=1,name='Imported',profile=decoded}} end} end
    p.fields.transfer:Click();local d=p.textDialog;d.destination:Click();d.name:SetText('Imported');d.apply:Click()
    assert(p.importProfile and next(p.importProfile.rotationStore.legacy.rotations[0].Untouched)==nil and next(wire.rotations['0'].Untouched)==nil)
    p.creating=false;p.importProfile=nil;p:Draw();local invalid=a:ProfileToPortable(a.db.profile);invalid.rotationFallbackID=nil;decoded=invalid
    p.fields.transfer:Click();d=p.textDialog;d.destination:Click();d.name:SetText('Invalid');d.apply:Click();assert(d.frame:IsShown() and not p.importProfile and a.db.profiles.Invalid==nil)
end)
test('native-only services do not install retired flat-map editor entry points',function()
    local f,a=fixture();f.load('UI/settings_setup.lua');f.load('UI/condition_entrypoints.lua')
    a.db.profile.rotations=setmetatable({},{__index=function() error('native services reached old flat map') end})
    assert(a.BuildRotationEditor==nil and a.get_rotation_list==nil and a.get_cooldown_list==nil and a.BuildConfigurationPane==nil)
    local snapshot=assert(a:GetRotationRecordSnapshot(0,ref('character')))
    assert(snapshot.body.name=='Character' and a:ResolveRotationReference(0,ref()).address.scope=='class')
end)
test('session baseline ownership and legacy workspace flags stay explicit and additive',function()
    local _,a=fixture();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w.session:BaselineOwnership()=='class');assert(w:Command('SetOwnership','character'));assert(w.session:Ownership()=='character' and w.session:BaselineOwnership()=='class')
    assert(w.session:Undo() and w.session:Ownership()=='class');assert(w.session:Redo() and w.session:BaselineOwnership()=='class')
    local f=F.new();local old=f.addon;old.RotationData=make();f.load('Data/rotation_draft.lua');f.load('Core/rotation_editor.lua');f.load('Core/rotation_workspace.lua');old.db.profile.rotations={[0]={Default=body('Fallback')}};old.GetDefaultIdForRuntime=function() end;old.uuid=function() return 'new' end
    local legacy=assert(old:GetRotationEditWorkspace(0,'Default'));assert(legacy.canonicalId=='Default' and legacy.fallback and legacy.session:BaselineOwnership()==nil)
end)
test('profile replacement and retired import callbacks preserve changed profiles',function()
    local f,a=fixture();local p=profileForm(f,a);local incoming=assert(a:ProfileToPortable(a.db.profile));incoming.poll=.7
    a.NewRotationCodec=function() return {Encode=function() return 'profile' end,Decode=function() return {value={format='RM-Profile',version=1,name='Imported',profile=incoming}} end} end
    p.fields.transfer:Click();local d=p.textDialog;local old=d.apply:GetScript('OnClick');a.db.profile.poll=.3;d.apply:Click();assert(d.frame:IsShown() and a.db.profile.poll==.3)
    d.cancel:Click();p.fields.transfer:Click();old();assert(d.frame:IsShown() and a.db.profile.poll==.3)
    local baseline=a:CopySettingsData(a.db.profile);a.db.profile=a:CopySettingsData(a.db.profile);d.apply:Click();assert(a:SettingsDataEqual(a.db.profile,baseline))
end)
test('comparison retires captured target replacement and owner changes immediately',function()
    local _,a,c=fixture();local d=a:ShowRotationComparison(0,ref());local index
    for k,v in pairs(d.chooser.list) do if v=='Character · This character' then index=k end end;assert(index);d.chooser:Fire('OnValueChanged',index)
    local record,token=a:GetRotationRecordSnapshot(0,ref('character'));record.body.name='Changed target';assert(a:CommitRotationDraft(ref('character'),token,record,'character'));d.frame:GetScript('OnUpdate')();assert(not d.frame:IsShown())
    d=a:ShowRotationComparison(0,ref());c.class='MAGE';d.frame:GetScript('OnUpdate')();assert(not d.frame:IsShown())
end)
test('profile projection excludes pending Built In and archives but retains invalid saved repair rows',function()
    local _,a,_,envelope=fixture();assert(a:RegisterDefaultRotation(envelope()));assert(a:NewRotationDraftTarget(0));local other=a:CopySettingsData(a.db.profile)
    other.rotationStore.classes.SHAMAN[0].same.body.rotation='invalid but retained';local rows=assert(a:GetProfileRotationHeaders(other,{class='MAGE'}));assert(#rows==4)
    local found=false;for _,row in ipairs(rows) do assert(row.kind=='custom' and not row.pending);if row.name=='Class' then found=true end end;assert(found)
end)
test('transfer without character identity exposes only Class copy and fixed owner replacement',function()
    local _,a=fixture();a.db.keys.char=nil;assert(a:BindRotationProfile());local d=a:ShowRotationTransfer(0,ref());pasted(d);d.destination:Click();assert(d.classScope:IsEnabled() and not d.scope:IsEnabled() and not d.scope:GetChecked());d.scope:GetScript('OnClick')();assert(not d.scope:GetChecked());d.name:SetText('Class only');d.apply:Click();assert(a:ResolveRotationReference(0,a.selected.selection.id).address.scope=='class')
end)
test('a workspace names the class its rotation is for, so tree conditions are named for it',function()
    local _,a=fixture();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w:RotationClass()=='SHAMAN')
    assert(w:Command('SetOwnership','character'));assert(w:RotationClass()=='SHAMAN','a character rotation is still its class\'s')
    local saved=w.reference;w.reference={kind='builtin',id='rm.example'};w.source={applicability={class='DRUID'}}
    assert(w:RotationClass()=='DRUID','a Built In declares its class')
    w.source={applicability={universal=true}};assert(w:RotationClass()==nil,'a Built In that declares none is the player\'s')
    w.reference=saved;assert(w:RotationClass()=='SHAMAN')
end)
finish()
