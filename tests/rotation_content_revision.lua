local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function helper(a)local h=io.open('Data/rotation_revision.lua');if h then h:close();assert(loadfile('Data/rotation_revision.lua'))('rotationmaster',a)end end
local function dataFixture()
 local d,envelope,options=dofile('tests/fixtures/rotation_data.lua')();local a={RotationData=d};helper(a)
 for _,p in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_draft.lua'})do assert(loadfile(p))('rotationmaster',a)end
 return d,envelope,options
end
local scopedSource=assert(read('tests/rotation_scope_workspace.lua'):match('^(.-)\ntest%('))
scopedSource=scopedSource:gsub("{'Data/catalog.lua'","{'Data/rotation_revision.lua','Data/catalog.lua'",1)
local scoped=assert(loadstring(scopedSource..'\nreturn bound,ref','@content-revision-scoped-fixture'))()
local flat=assert(loadstring(assert(read('tests/rotation_workspace.lua'):match('^(.-)\ntest%('))..'\nreturn fixture','@content-revision-flat-fixture'))()
local function fixture()local a,c,e,load=scoped();return a,c,e,load end
local function ref(scope,id)return {kind='custom',address={scope=scope or'class',class='SHAMAN',owner=scope=='character' and'A - Realm'or'SHAMAN',spec=0,id=id or'shared'}}end
local function body(a,r)return assert(a:GetRotationRecordSnapshot(0,r or ref())).body end
local function update(a,r,change,scope)
 local record,token=a:GetRotationRecordSnapshot(0,r);change(record.body);local result,why=a:CommitRotationDraft(r,token,record,scope);return result,why
end

test('positive safe revisions are optional portable body metadata while malformed revisions are invalid',function()
 local d,envelope,options=dataFixture();local v=envelope();assert(d.ValidateEnvelope(v,options).supported)
 for _,n in ipairs({1,9,9007199254740991})do v.body.revision=n;local r=d.ValidateEnvelope(v,options);assert(r.valid and r.supported,'valid revision rejected')end
 for _,n in ipairs({0,-1,1.5,0/0,math.huge,9007199254740992,'1',false,function()end})do v.body.revision=n;assert(not d.ValidateEnvelope(v,options).valid,'malformed revision accepted')end
end)
test('local revision is semantic metadata only at exact structural body path',function()
 local d,envelope=dataFixture();local a=envelope();local b=d.CopyData(a);b.body.revision=5
 assert(#d.DiffRotations(a,b).changes==0,'local revision appears as source content')
 a.body.switch={type='TEST',revision=1};b.body.switch={type='TEST',revision=2};assert(#d.DiffRotations(a,b).changes==1,'nested revision disappeared')
 a=envelope();b=d.CopyData(a);b.revision=2;assert(#d.DiffRotations(a,b).changes==1,'source revision disappeared')
end)
test('legacy read and identity detach do not materialize revision; real save first becomes two',function()
 local a=fixture();local r=ref();assert(body(a,r).revision==nil);local raw=assert(a:GetEditableRotation(0,r));assert(raw.revision==nil and body(a,r).revision==nil)
 assert(update(a,r,function(b)b.description='Saved'end));assert(body(a,r).revision==2 and raw.revision==nil)
end)
test('scoped ordinary new authoring forces baseline one despite valid forged draft value',function()
 local a=fixture();local r=assert(a:NewRotationDraftTarget(0));local saved=assert(a:CommitRotationDraft(r,nil,{body={name='New',revision=999,rotation={},cooldowns={}}}));assert(body(a,saved).revision==1)
end)
test('canonical saved revisions advance once and valid draft numbers cannot jump them',function()
 local a=fixture();assert(update(a,ref(),function(b)b.name='First';b.revision=500 end));assert(body(a).revision==2)
 assert(update(a,ref(),function(b)b.name='Second';b.revision=1 end));assert(body(a).revision==3)
end)
test('revision-only and semantic noop commits preserve legacy absence and saved count',function()
 local a=fixture();assert(update(a,ref(),function(b)b.revision=100 end));assert(body(a).revision==nil,'noop legacy revision materialized')
 assert(update(a,ref(),function(b)b.name='Edited'end));assert(update(a,ref(),function(b)b.revision=700 end));assert(body(a).revision==2)
end)
test('scope-only move advances once and stale failed commits cannot advance',function()
 local a=fixture();local r=ref();local original,stale=a:GetRotationRecordSnapshot(0,r)
 local _,ct=a:GetRotationRecordSnapshot(0,ref('character'));assert(a:DeleteRotationRecord(ref('character'),ct))
 local moved=assert(update(a,r,function()end,'character'));assert(body(a,moved).revision==2)
 assert(not a:CommitRotationDraft(r,stale,original));assert(body(a,moved).revision==2)
end)
test('malformed draft and canonical revisions fail atomically; max cannot overflow',function()
 local a=fixture();local record,token=a:GetRotationRecordSnapshot(0,ref());record.body.revision=0/0;assert(not a:CommitRotationDraft(ref(),token,record));assert(body(a).revision==nil)
 local raw=assert(a:GetEditableRotation(0,ref()));raw.revision=9007199254740991
 assert(not update(a,ref(),function(b)b.name='Overflow'end));assert(body(a).revision==9007199254740991)
 raw.revision='invalid';assert(not update(a,ref(),function(b)b.revision=1;b.name='Do not reset'end));assert(body(a).revision=='invalid')
end)
test('scoped staged commands apply once and discard/readonly/failed validation do not advance',function()
 local a=fixture();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w:Command('SetBodyField','description','One'));assert(w:Command('SetBodyField','name','Two'));assert(w.session:Undo());assert(w.session:Redo());assert(body(a).revision==nil)
 assert(w:Apply());assert(body(a).revision==2);assert(w:Apply());assert(body(a).revision==2)
 assert(w:Command('SetBodyField','name','Discard'));assert(w:Discard());assert(body(a).revision==2)
 assert(not w:Command('SetBodyField','revision',80));assert(w:Command('SetBodyField','priority','bad'));assert(not w:Apply());assert(body(a).revision==2)
end)
test('pending workspace first save is one then next real apply is two',function()
 local a=fixture();local r,key=a:NewRotationDraftTarget(0);local w=assert(a:GetRotationEditWorkspace(0,key));assert(w:Command('SetBodyField','name','Created'));assert(w:Apply());assert(body(a,w.reference).revision==1)
 assert(w:Command('SetBodyField','description','Changed'));assert(w:Apply());assert(body(a,w.reference).revision==2)
end)
test('built-in and custom clones start one with exact source provenance and unchanged source diff',function()
 local a,_,envelope=fixture();local source=envelope();assert(a:RegisterDefaultRotation(source));local id,why,saved=a:CloneDefaultRotation(0,source.id,'Clone');assert(id,why);local r=saved or assert(a:ResolveRotationReference(0,id));assert(body(a,r).revision==1)
 local view=assert(a:GetSourcedRotationView(0,r));assert(view.lineage.sourceRevision==source.revision)
 local comparison=assert(a:BuildRotationComparison(0,r,{kind='builtin',id=source.id}));for _,row in ipairs(comparison.customChanges.changes)do assert(row.path~='$.body.revision')end
 assert(update(a,r,function(b)b.description='Edit'end));local second,reason,copy=a:DuplicateCustomRotation(0,r,'Second');assert(second,reason);assert(body(a,copy or assert(a:ResolveRotationReference(0,second))).revision==1)
 assert(source.body.revision==nil and a:GetDefaultRotation(source.id).envelope.body.revision==nil)
end)
test('scoped import preserves new incoming revision and replacement follows local history',function()
 local a=fixture();local input={body={name='Incoming',revision=37,rotation={},cooldowns={}}};local id,why,r=a:CreateImportedRotation(input,0,'Imported');assert(id,why);assert(body(a,r).revision==37 and input.body.revision==37)
 local current,token=a:GetRotationRecordSnapshot(0,r);local result,reason=a:CreateImportedRotation({body={name='Replacement',revision=2,rotation={},cooldowns={}}},0,'Replaced',{reference=r,recordToken=token});assert(result,reason);assert(body(a,r).revision==38)
 assert(a:GetRotationExportData(0,r).revision==38)
end)
test('scoped import missing revision starts one and malformed incoming data cannot publish',function()
 local a=fixture();local id,why,r=a:CreateImportedRotation({body={rotation={},cooldowns={}}},0,'Imported');assert(id,why);assert(body(a,r).revision==1)
 assert(not a:CreateImportedRotation({body={revision=false,rotation={},cooldowns={}}},0,'Bad'))
end)
test('flat workspace new/edit/noop/discard follows same saved revision policy',function()
 local a=flat();helper(a);local w=assert(a:GetRotationEditWorkspace(0,'mine'));assert(w:Apply());assert(a:GetEditableRotation(0,'mine').revision==nil)
 assert(w:Command('SetBodyField','name','Edited'));assert(w:Apply());assert(a:GetEditableRotation(0,'mine').revision==2)
 assert(w:Command('SetBodyField','name','Discard'));assert(w:Discard());assert(a:GetEditableRotation(0,'mine').revision==2)
 local n=assert(a:GetRotationEditWorkspace(0,'new'));assert(n:Command('SetBodyField','name','New'));assert(n:Apply());assert(a:GetEditableRotation(0,'new').revision==1)
end)
test('direct edit session valid revision-only draft remains noop while concurrency observes canonical changes',function()
 local a=flat();helper(a);local original=a:GetEditableRotation(0,'mine');original.revision=7;local s=assert(a:NewRotationEditSession(0,original));assert(s:Command('SetBodyField','name','Changed'))
 original.revision=8;assert(not s:Apply());assert(original.revision==8 and original.name=='Mine')
end)
test('catalog clone/save uses local body revision separately from source envelope revision',function()
 local d,envelope,options=dataFixture();local n=0;local c=assert(d.NewCatalog({validation=options,newId=function()n=n+1;return 'generated-'..n end}));local source=envelope();assert(c:RegisterBuiltin(source));local id=assert(c:Clone(source.id,'Clone'));local v=c:Get(id).envelope;assert(v.body.revision==1 and v.revision==1)
 v.body.description='Edited';v.body.revision=999;assert(c:Save(id,v));local saved=c:Get(id).envelope;assert(saved.body.revision==2 and saved.revision==2)
 saved.body.revision=500;assert(c:Save(id,saved));assert(c:Get(id).envelope.body.revision==2,'catalog noop local revision advanced')
 assert(c:Clone(id,'Clone again'));assert(source.body.revision==nil)
end)
test('legacy imports preserve incoming count while raw and sourced duplicates reset to one',function()
 local source=assert(read('tests/rotation_import.lua'):match('^(.-)\ntest%('))
 local make=assert(loadstring(source..'\nreturn fixture','@revision-legacy-import-fixture'))()
 local a,_,objects=make()
 for _,withManifest in ipairs({false,true})do
  local b=a.RotationData.CopyData(objects.modern.body);b.revision=41
  local prepared={body=b};if withManifest then prepared.manifest=a.RotationData.CopyData(objects.modern);prepared.manifest.body=nil end
  local id=assert(a:CreateImportedRotation(prepared,0,'Imported'));assert(a:GetEditableRotation(0,id).revision==41)
  local clone=assert(a:DuplicateCustomRotation(0,id,'Clone'));assert(a:GetEditableRotation(0,clone).revision==1)
  local original=a:GetEditableRotation(0,id)
  assert(a:CreateImportedRotation({body={name='Replacement',revision=1,rotation={},cooldowns={}}},0,'Replacement',{id=id,valid=function()return a:GetEditableRotation(0,id)==original end}))
  assert(a:GetEditableRotation(0,id).revision==42)
 end
end)
test('profile transport and reload binding preserve saved revision data',function()
 local a,_,_,load=fixture();assert(update(a,ref(),function(b)b.name='Saved'end));load('UI/settings_draft.lua');load('Core/profile_data.lua')
 local wire=assert(a:ProfileToPortable(a.db.profile));local recovered=assert(a:ProfileFromPortable(assert(a.RotationData.CopyData(wire)),{preserveLegacyBodies=true}))
 assert(recovered.rotationStore.classes.SHAMAN[0].shared.body.revision==2)
 a.db.profile=recovered;assert(a:BindRotationProfile());assert(body(a).revision==2)
end)
test('explicit flat Repair preserves the valid readonly revision',function()
 local f=F.new();f.addon.RotationData=dataFixture();f.addon.warn=function()end;f.load('validate.lua')
 local b={name='Saved',revision=7,switch={},rotation={},cooldowns={}}
 f.addon:validate_rotation('profile','61b36ed1-fa31-4656-ad71-f3d50f193a85',b,true);assert(b.revision==7,'Repair removed local revision')
 for _,bad in ipairs({-1,1.5,0/0,math.huge})do b.revision=bad;f.addon:validate_rotation('profile','61b36ed1-fa31-4656-ad71-f3d50f193a85',b,true);assert(not f.addon.RotationData.ValidateBody(b).valid,'malformed repaired revision claimed valid')end
end)
test('malformed record fields and getter-bearing bodies are rejected before callbacks',function()
 local a=fixture();local record,token=a:GetRotationRecordSnapshot(0,ref());record.extra=true;assert(not a:CommitRotationDraft(ref(),token,record),'record whitelist was bypassed')
 local hits=0;local fake=setmetatable({name='Bad',rotation={},cooldowns={}},{__index=function()hits=hits+1;error('must not read')end})
 local ok,result=pcall(a.CommitRotationDraft,a,ref(),token,{body=fake});assert(ok and not result and hits==0,'malformed body invoked getter')
end)
test('cloning an invalid canonical revision cannot silently repair its history',function()
 local a=fixture();local raw=assert(a:GetEditableRotation(0,ref()));raw.revision='bad';assert(not a:DuplicateCustomRotation(0,ref(),'Do not repair'))
end)
test('explicit replacement import advances local history even with equal empty payload',function()
 local a=fixture();local input={body={name='Same',revision=9,rotation={},cooldowns={}}};local _,_,r=a:CreateImportedRotation(input,0,'Same');local _,token=a:GetRotationRecordSnapshot(0,r)
 assert(a:CreateImportedRotation(input,0,'Same',{reference=r,recordToken=token}));assert(body(a,r).revision==10)
end)
test('revision preparation cannot overwrite a flat target changed by a reentrant copy callback',function()
 local a=flat();helper(a);local original=a:GetEditableRotation(0,'mine');local session=assert(a:NewRotationEditSession(0,original));assert(session:Command('SetBodyField','name','Draft'))
 local prepare=a.RotationData.PrepareRotationContentRevision;a.RotationData.PrepareRotationContentRevision=function(...)
  local saved,why,changed=prepare(...);original.name='External';return saved,why,changed
 end
 assert(not session:Apply(),'stale target was overwritten after preparation');assert(original.name=='External' and original.revision==nil)
end)
test('catalog reentrant saves preserve newer canonical payload and counter',function()
 local d,envelope,options=dataFixture();local n=0;local state={};local c=assert(d.NewCatalog({state=state,validation=options,newId=function()n=n+1;return 'id-'..n end}));local source=envelope();assert(c:RegisterBuiltin(source));local id=assert(c:Clone(source.id));local outer=c:Get(id).envelope;outer.body.name='Outer'
 local prepare=d.PrepareRotationContentRevision;local nested=false;d.PrepareRotationContentRevision=function(...)
  local saved,why,changed=prepare(...);if not nested then nested=true;local inner=c:Get(id).envelope;inner.body.name='Inner';assert(c:Save(id,inner))end;return saved,why,changed
 end
 assert(not c:Save(id,outer),'outer overwrote newer save');local final=c:Get(id).envelope;assert(final.body.name=='Inner' and final.body.revision==2)
end)
test('catalog reentrant add preserves the newer destination record',function()
 local d,envelope,options=dataFixture();local c=assert(d.NewCatalog({validation=options}));local outer=envelope();outer.id='new-id';outer.body.revision=5
 local prepare=d.PrepareRotationContentRevision;local nested=false;d.PrepareRotationContentRevision=function(...)
  local saved,why,changed=prepare(...);if not nested then nested=true;local inner=envelope();inner.id='new-id';inner.body.revision=9;inner.body.name='Inner';assert(c:AddCustom(inner))end;return saved,why,changed
 end
 assert(not c:AddCustom(outer));assert(c:Get('new-id').envelope.body.revision==9)
end)
test('scoped preparation cannot write to a retired owner profile',function()
 local a=fixture();local old=a.db.profile;local record,token=a:GetRotationRecordSnapshot(0,ref());record.body.name='Outer';local fresh={marker=true};local prepare=a.RotationData.PrepareRotationContentRevision
 a.RotationData.PrepareRotationContentRevision=function(...)local saved,why,changed=prepare(...);a.db.profile=fresh;return saved,why,changed end
 local saved,why=a:CommitRotationDraft(ref(),token,record);assert(not saved and why=='rotation-profile-changed');assert(a.db.profile==fresh and old.rotationStore.classes.SHAMAN[0].shared.body.name=='Class')
end)
local function legacyFixture()
 local source=assert(read('tests/rotation_import.lua'):match('^(.-)\ntest%('));return assert(loadstring(source..'\nreturn fixture','@revision-reentrant-legacy-fixture'))()()
end
test('legacy import preparation cannot overwrite a newly active profile',function()
 local a=legacyFixture();local old=a.db.profile;local fresh={rotations={[0]={foreign={name='Foreign'}}}};local prepare=a.RotationData.PrepareRotationContentRevision
 a.RotationData.PrepareRotationContentRevision=function(...)local saved,why,changed=prepare(...);a.db.profile=fresh;return saved,why,changed end
 assert(not a:CreateImportedRotation({body={rotation={},cooldowns={}}},0,'Outer'));assert(a.db.profile==fresh and fresh.rotations[0].foreign and old.rotations[0].old.name=='Existing')
end)
test('legacy default clone cannot publish after nested preparation retires its profile',function()
 local a,_,objects=legacyFixture();local source=objects.modern;assert(a:RegisterDefaultRotation(source));local old=a.db.profile;local fresh={rotations={[0]={foreign={name='Foreign'}}}};local prepare=a.RotationData.PrepareRotationContentRevision
 a.RotationData.PrepareRotationContentRevision=function(...)local saved,why,changed=prepare(...);a.db.profile=fresh;return saved,why,changed end
 assert(not a:CloneDefaultRotation(0,source.id,'Clone'));assert(a.db.profile==fresh and fresh.rotations[0].foreign and next(fresh.rotations[0])=='foreign');assert(old.rotations[0].old.name=='Existing')
end)
test('catalog semantic envelope edits advance local history while forged counters alone do not',function()
 for _,edit in ipairs({function(v)v.applicability.maxLevel=69 end,function(v)v.nameKey='Renamed display'end,function(v)v.tags={'updated'}end,function(v)v.sources[1].revision='nested change'end})do
  local d,envelope,options=dataFixture();local n=0;local c=assert(d.NewCatalog({validation=options,newId=function()n=n+1;return 'new-'..n end}));assert(c:RegisterBuiltin(envelope()));local id=assert(c:Clone(envelope().id));local v=c:Get(id).envelope;edit(v);assert(c:Save(id,v));assert(c:Get(id).envelope.body.revision==2)
  v=c:Get(id).envelope;v.revision=999;v.body.revision=888;assert(c:Save(id,v));assert(c:Get(id).envelope.body.revision==2)
 end
end)
test('catalog exact baseline rejects in-place mutation and replacement storage roots',function()
 for _,kind in ipairs({'body','envelope','root'})do
  local d,envelope,options=dataFixture();local state={};local n=0;local c=assert(d.NewCatalog({state=state,validation=options,newId=function()n=n+1;return 'new-'..n end}));assert(c:RegisterBuiltin(envelope()));local id=assert(c:Clone(envelope().id));local outer=c:Get(id).envelope;outer.body.name='Outer';local prepare=d.PrepareRotationContentRevision
  d.PrepareRotationContentRevision=function(...)local saved,why,changed=prepare(...);if kind=='body'then state.custom[id].body.revision=9 elseif kind=='envelope'then state.custom[id].nameKey='Newer'else state.custom={[id]=state.custom[id]}end;return saved,why,changed end
  assert(not c:Save(id,outer));assert(c:Get(id).envelope.body.name~='Outer')
 end
end)
test('scoped final detached copy and import replacement callback cannot retire ownership unnoticed',function()
 local a=fixture();local old=a.db.profile;local record,token=a:GetRotationRecordSnapshot(0,ref());record.body.name='Outer';local copy=a.RotationData.CopyData;local fresh={marker=true}
 a.RotationData.CopyData=function(value,...)local result,why=copy(value,...);if type(value)=='table'and value.body and value.body.name=='Outer'then a.db.profile=fresh end;return result,why end
 assert(not a:CommitRotationDraft(ref(),token,record));assert(a.db.profile==fresh and old.rotationStore.classes.SHAMAN[0].shared.body.name=='Class')
 local b=legacyFixture();local previous=b:GetEditableRotation(0,'old');local newer={rotations={[0]={foreign={name='Newer'}}}}
 assert(not b:CreateImportedRotation({body={rotation={},cooldowns={}}},0,'Replacement',{id='old',valid=function()b.db.profile=newer;return true end}));assert(b.db.profile==newer and newer.rotations[0].foreign and previous.name=='Existing')
end)
test('legacy absent priority lists remain a no-op in flat and scoped editors',function()
 local a=flat();local original=a:GetEditableRotation(0,'mine');for key in pairs(original)do original[key]=nil end;original.name='Legacy'
 local w=assert(a:GetRotationEditWorkspace(0,'mine'));assert(not w:IsDirty());assert(w:Apply());assert(original.revision==nil,'flat empty-list normalization advanced revision')
 local b=fixture();local raw=assert(b:GetEditableRotation(0,ref()));for key in pairs(raw)do raw[key]=nil end;raw.name='Legacy'
 assert(update(b,ref(),function()end));assert(body(b).revision==nil,'direct minimal snapshot advanced revision')
 local scopedWorkspace=assert(b:GetRotationEditWorkspace(0,ref()));assert(not scopedWorkspace:IsDirty());assert(scopedWorkspace:Apply());assert(body(b).revision==nil,'scoped empty-list normalization advanced revision')
 assert(scopedWorkspace:Command('SetBodyField','description','Real edit'));assert(scopedWorkspace:Apply());assert(body(b).revision==2)
end)
test('catalog revision callbacks cannot forge the private freshness seal',function()
 for _,mode in ipairs({'argument','copy-result'})do
  local d,envelope,options=dataFixture();local state={};local n=0;local c=assert(d.NewCatalog({state=state,validation=options,newId=function()n=n+1;return 'seal-'..n end}));assert(c:RegisterBuiltin(envelope()));local id=assert(c:Clone(envelope().id));local outer=c:Get(id).envelope;outer.body.description='Outer'
  local retained;local copy=d.CopyData;d.CopyData=function(value,...)local result,why=copy(value,...);if value==state.custom[id]then retained=result end;return result,why end
  local prepare=d.PrepareRotationContentRevision;d.PrepareRotationContentRevision=function(value,previous,...)
   local saved,why,changed=prepare(value,previous,...);state.custom[id].body.description='Inner';state.custom[id].body.revision=2
   local escaped=mode=='argument'and previous or retained and retained.body;if escaped then escaped.description='Inner';escaped.revision=2 end;return saved,why,changed
  end
  assert(not c:Save(id,outer),'callback forged private seal through '..mode);assert(state.custom[id].body.description=='Inner'and state.custom[id].body.revision==2)
 end
end)
finish()
