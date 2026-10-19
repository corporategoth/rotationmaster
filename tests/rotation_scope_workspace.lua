local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_data.lua')
local function body(name) return {name=name,switch={},rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}} end
local function ref(scope,id,owner,class) return {kind='custom',address={scope=scope or 'class',class=class or 'SHAMAN',owner=owner or (scope=='character' and 'A - Realm' or 'SHAMAN'),spec=0,id=id or 'shared'}} end
local function fixture()
    local data,envelope,validation=make();local a={RotationData=data,conditionDefinitions=validation.conditions,db={keys={char='A - Realm'},global={effects={}},profile={rotationFallbackID='Saved fallback',rotationStore={version=1,classes={SHAMAN={[0]={shared={body=body('Class')},['Saved fallback']={body=body('Class fallback')}}},MAGE={[0]={shared={body=body('Foreign')}}}},characters={['A - Realm']={class='SHAMAN',specs={[0]={shared={body=body('Character')},['Saved fallback']={body=body('Character fallback')}}}}},legacy={rotations={[0]={old=body('Unassigned')}}}},rotationLibrary={}}}}
    local context={family='tbc',class='SHAMAN',level=11,spec=0,actionContext='player',combatDataPolicy='probe'}
    local n=0;a.uuid=function() n=n+1;return 'new-'..n end
    local env=setmetatable({DEFAULT='Localized fallback',NEW='New',LibStub=function() return {GetLocale=function() return setmetatable({}, {__index=function(_,k) return k end}) end} end},{__index=_G})
    local function load(path) local file=io.open(path);if file then file:close();local chunk=assert(loadfile(path));setfenv(chunk,env);chunk('rotationmaster',a) end end
    for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Core/rotation_references.lua','Core/rotation_library.lua','Core/rotation_tags.lua','Core/imports.lua','Data/rotation_draft.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_scope.lua'}) do load(path) end
    a.GetRotationContext=function() return context end
    a.validateCondition=function() return true end
    return a,context,envelope,load
end
local function bound()
    local a,c,e,load=fixture();assert(type(a.BindRotationProfile)=='function','scoped facade missing');assert(a:BindRotationProfile());return a,c,e,load
end
local function reason(want,value,why) assert(value==nil and why==want,tostring(why)..' instead of '..want) end


test('scope edits share one bounded undo history and apply a complete record atomically',function()
    local a=bound();local w=assert(a:GetRotationEditWorkspace(0,ref()))
    assert(w.reference.address.scope=='class' and w.scope=='class' and w.id:sub(1,1)==string.char(1))
    assert(w:Command('SetOwnership','class') and not w:IsDirty() and not w.session:HistoryState().canUndo)
    assert(w:Command('SetOwnership','character') and w:IsDirty());assert(w.session:Undo());assert(w.session:Ownership()=='class' and not w:IsDirty());assert(w.session:Redo())
    local ok,why=w:Apply();assert(not ok and why=='rotation-id-collision');assert(w:IsDirty() and w.session:HistoryState().canUndo)
    local _,token=a:GetRotationRecordSnapshot(0,ref('character'));assert(a:DeleteRotationRecord(ref('character'),token))
    assert(w:Command('SetBodyField','name','Moved together'));assert(w:Apply());assert(w.reference.address.scope=='character' and not w:IsDirty())
    assert(a:GetRotationRecordSnapshot(0,w.reference).body.name=='Moved together');reason('unknown-rotation',a:GetRotationRecordSnapshot(0,ref()))
end)
test('pending workspace keeps stable key and no saved row until first Apply',function()
    local a=bound();local reference,key=a:NewRotationDraftTarget(0);local w=assert(a:GetRotationEditWorkspace(0,key));assert(w.pending and w.id==key)
    assert(w:Command('SetBodyField','name','My draft'));assert(w:Command('SetOwnership','character'))
    assert(w.reference.address.scope=='character' and a:GetRotationEditWorkspace(0,w.reference)==w)
    local pending=a:ListPendingRotationDrafts(0);assert(#pending==1 and pending[1].key==key and pending[1].scope=='character' and pending[1].reference.address.id==reference.address.id)
    assert(w:Apply());assert(w.id==key and not w.pending and w.reference.address.scope=='character');assert(a:GetRotationEditWorkspace(0,key)==w)
end)
test('same address replacement and profile switch invalidate dirty workspace without losing draft',function()
    local a=bound();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w:Command('SetBodyField','name','Keep me'))
    local record,token=a:GetRotationRecordSnapshot(0,ref());record.body.name='External';assert(a:CommitRotationDraft(ref(),token,record))
    assert(not w:ValidTarget() and not w:Apply());assert(w:Snapshot().name=='Keep me')
    local fresh=assert(a:GetRotationEditWorkspace(0,ref()));assert(fresh~=w and fresh:Snapshot().name=='External')
end)
test('legacy identity detachment preserves unchanged draft authority while actual legacy edits still block Apply',function()
    local a=bound();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w:Command('SetBodyField','name','My draft'))
    local raw=assert(a:GetEditableRotation(0,ref()));assert(raw.name=='Class');assert(w:ValidTarget() and w:IsDirty(),'read-only legacy exposure invalidated the draft')
    assert(w:Apply());assert(w:Command('SetBodyField','name','Another draft'));raw=a:GetEditableRotation(0,ref());raw.name='Real external edit'
    assert(not w:ValidTarget() and not w:Apply());assert(w:Snapshot().name=='Another draft' and raw.name=='Real external edit')
end)
test('legacy detachment cannot resurrect a stale same-value replacement lease',function()
    local a=bound();local w=assert(a:GetRotationEditWorkspace(0,ref()));assert(w:Command('SetBodyField','name','Stale draft'))
    local record,expected=a:GetRotationRecordSnapshot(0,ref());assert(a:CommitRotationDraft(ref(),expected,record));assert(not w:ValidTarget())
    assert(a:GetEditableRotation(0,ref()));assert(not w:ValidTarget() and not w:Apply(),'identity-stale lease was resurrected')
end)
test('old workspace fresh-ID creation stays unsaved Class scoped and never reclaims a reserved hidden ID',function()
    local a=bound();local w=assert(a:GetRotationEditWorkspace(0,'explicit-fresh-id'));assert(w.pending and w.scope=='class' and w.canonicalId=='explicit-fresh-id')
    assert(a:GetRotationEditWorkspace(0,'explicit-fresh-id')==w);assert(w:Command('SetBodyField','name','Legacy caller draft'));assert(w:Apply())
    assert(a:GetRotationRecordSnapshot(0,w.reference).body.name=='Legacy caller draft')
    a.db.profile.rotationStore.classes.MAGE[0].hidden={body={name='Foreign'}};assert(a:BindRotationProfile());assert(not a:GetRotationEditWorkspace(0,'hidden'))
    assert(not a:GetRotationEditWorkspace(0,string.char(1)..'rm:rotation:expired'))
end)
finish()
