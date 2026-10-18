local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local d,envelope,options=make();local a=f.addon;a.RotationData=d;a.conditionDefinitions=options.conditions
    a.db.profile={rotations={[0]={old={name='Existing',rotation={},cooldowns={}}}},itemsets={}}
    a.db.global.effects={};a.currentSpec=0
    local n=0;a.uuid=function() n=n+1;return 'fresh-'..n end
    local context={family='tbc',class='SHAMAN',level=11,spec=0,actionContext='player',combatDataPolicy='probe'}
    for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/import_session.lua','Core/rotation_library.lua','Core/rotation_tags.lua','Core/imports.lua'}) do f.load(path) end
    a.GetRotationContext=function() return context end
    assert(a:InitializeRotationLibrary())
    local objects={legacy=envelope().body,modern=envelope()}
    local session=d.NewImportSession({Decode=function(_,text) return {kind=text=='modern' and 'envelope' or 'legacy',original=text,value=d.CopyData(objects[text])} end},options)
    return a,session,objects,context,d
end
test('legacy import adds an independent fresh custom rotation without replacing existing data',function()
    local a,session,objects=fixture();local candidate=assert(session:Stage('legacy'))
    local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Imported copy'))
    local body=a:GetEditableRotation(0,id)
    assert(id~='old' and body.name=='Imported copy' and body.rotation[1].id~='step-1')
    assert(a:GetEditableRotation(0,'old').name=='Existing' and objects.legacy.rotation[1].id=='step-1')
    body.rotation[1].action=974;assert(objects.legacy.rotation[1].action==403)
end)
test('envelope metadata and applicability survive import duplication and export with one saved body',function()
    local a,session,objects,context=fixture();local candidate=assert(session:Stage('modern'))
    local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Imported shaman'))
    assert(a:GetRuntimeRotations(0)[id])
    context.level=80;assert(not a:GetRuntimeRotations(0)[id],'import lost its level scope')
    local duplicate=assert(a:DuplicateCustomRotation(0,id,'Duplicate'))
    assert(not a:GetRuntimeRotations(0)[duplicate],'duplication dropped imported scope')
    local exported=assert(a:GetRotationExportData(0,duplicate))
    assert(exported.format=='RotationMaster' and exported.applicability.maxLevel==70 and exported.sources[1].url==objects.modern.sources[1].url)
    assert(exported.body.name=='Duplicate' and exported.id==duplicate)
    assert(not a.db.profile.rotationLibrary.imports[0][id].manifest.body,'import persisted a second body')
    context.level=11;assert(a:GetRuntimeRotations(0)[id] and a:GetRuntimeRotations(0)[duplicate])
end)
test('failed validation stale candidates and ID collisions apply atomically',function()
    local a,session,objects=fixture();objects.legacy.rotation[1].action='403'
    local candidate=assert(session:Stage('legacy'))
    assert(not a:ApplyRotationImport(session,candidate.token,0,'Invalid'))
    assert(next(a.db.profile.rotationLibrary.imports)==nil)
    objects.legacy.rotation[1].action=403;candidate=assert(session:Stage('legacy'))
    a.uuid=function() return 'old' end
    local id,why=a:ApplyRotationImport(session,candidate.token,0,'Collision')
    assert(not id and why=='id-collision' and a:GetEditableRotation(0,'old').name=='Existing')
    session:Clear();id,why=a:ApplyRotationImport(session,candidate.token,0,'Stale')
    assert(not id and why=='stale-import')
end)
test('imported copies retain graphical step correspondence and corrupt library state cannot drop scope',function()
    local a,session=fixture();local candidate=assert(session:Stage('modern'))
    local id=assert(a:ApplyRotationImport(session,candidate.token,0,'First'))
    local duplicate=assert(a:DuplicateCustomRotation(0,id,'Second'))
    a:GetEditableRotation(0,duplicate).rotation[1].action=974
    local diff=assert(a:BuildRotationComparison(0,duplicate,{kind='custom',id=id}))
    for _,change in ipairs(diff.changes) do assert(change.kind~='added' and change.kind~='removed','imported duplicate steps look replaced') end
    a.db.profile.rotationLibrary.imports=false
    assert(not a:GetRuntimeRotations(0)[id],'corrupt manifest storage silently removed imported scope')
end)
test('malformed destination containers are preserved and refused before ID allocation',function()
    for _,value in ipairs({false,42}) do
        for _,root in ipairs({false,true}) do
            local a,session=fixture();local candidate=assert(session:Stage('legacy'))
            if root then a.db.profile.rotations=value else a.db.profile.rotations[0]=value end
            a.uuid=function() error('invalid destination reached ID allocation') end
            local ok,id,why=pcall(a.ApplyRotationImport,a,session,candidate.token,0,'Imported')
            assert(ok and not id and why=='invalid-rotation-storage','malformed destination threw or was silently repaired')
            if root then assert(a.db.profile.rotations==value) else assert(a.db.profile.rotations[0]==value) end
            assert(next(a.db.profile.rotationLibrary.imports)==nil)
        end
    end
end)
test('nested imported branches reidentify both arms and keep their source correspondence through duplication',function()
    local a,session,objects=fixture()
    objects.modern.body.rotation={{id='branch',type='branch',mode='false',conditions={},onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='spell',action=324}}}}
    local candidate=assert(session:Stage('modern'));local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Nested import'))
    local b=a:GetEditableRotation(0,id).rotation[1]
    assert(b.id~='branch' and b.onTrue[1].id~='yes' and b.onFalse[1].id~='no' and b.mode=='false')
    local view=assert(a:GetImportedRotationView(0,id));assert(view.stepOrigins[b.onFalse[1].id]=='no')
    local duplicate=assert(a:DuplicateCustomRotation(0,id,'Nested duplicate'));local copy=a:GetEditableRotation(0,duplicate).rotation[1]
    assert(copy.onTrue[1].id~=b.onTrue[1].id)
    local diff=assert(a:BuildRotationComparison(0,duplicate,{kind='custom',id=id}))
    for _,change in ipairs(diff.changes) do assert(change.kind~='added' and change.kind~='removed','nested import correspondence lost') end
end)
test('collision with an existing nested saved ID leaves no partially imported body or manifest',function()
    local a,session=fixture();a.db.profile.rotations[0].existing={name='Existing tree',rotation={{id='b',type='branch',conditions={},onTrue={{id='nested-collision',type='none'}},onFalse={}}},cooldowns={}}
    local candidate=assert(session:Stage('modern'));local n=0
    a.uuid=function() n=n+1;return n==1 and 'new-import' or 'nested-collision' end
    local id,why=a:ApplyRotationImport(session,candidate.token,0,'Collision')
    assert(not id and why=='id-collision' and a.db.profile.rotations[0]['new-import']==nil and next(a.db.profile.rotationLibrary.imports)==nil)
end)
test('separate description and supplied authorship survive import clone and export',function()
    local a,session,objects=fixture();objects.modern.body.description='Upkeep and ranged priorities'
    objects.modern.body.metadata={author='PreZ',version='2',website='https://example.test/rotation'}
    local candidate=assert(session:Stage('modern'));local id=assert(a:ApplyRotationImport(session,candidate.token,0,'With metadata'))
    local duplicate=assert(a:DuplicateCustomRotation(0,id,'Copy'));local exported=assert(a:GetRotationExportData(0,duplicate))
    assert(exported.body.description=='Upkeep and ranged priorities' and exported.body.metadata.author=='PreZ')
    exported.body.metadata.author='Other';assert(a:GetEditableRotation(0,duplicate).metadata.author=='PreZ')
end)
test('overwrite preserves selected identity and name with fresh step provenance and rejects changed targets',function()
    local a,session,_,_,d=fixture();local original=a:GetEditableRotation(0,'old');local expected={profile=a.db.profile,target=original,body=d.CopyData(original)};local candidate=assert(session:Stage('modern'))
    local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Ignored new name','old',expected));assert(id=='old' and a:GetEditableRotation(0,'old').name=='Existing' and #a:GetEditableRotation(0,'old').rotation>0);assert(a:GetRotationExportData(0,'old').id=='old')
    local after=a:GetEditableRotation(0,'old');assert(not a:ApplyRotationImport(session,candidate.token,0,'Ignored','old',expected) and a:GetEditableRotation(0,'old')==after)
end)
test('replacement refuses malformed retained provenance before touching the target',function()
    for _,kind in ipairs({'origins','comparisons','imports'}) do
        local a,session,_,_,d=fixture();local original=a:GetEditableRotation(0,'old');local expected={profile=a.db.profile,target=original,body=d.CopyData(original)};local candidate=assert(session:Stage('modern'));a.db.profile.rotationLibrary[kind][0]=false
        local id,why=a:ApplyRotationImport(session,candidate.token,0,'Overwrite','old',expected);assert(not id and why=='invalid-import-state' and a:GetEditableRotation(0,'old')==original)
    end
end)
test('inherited and edited tags survive imports duplicates and export while source manifests remain unchanged',function()
    local a,session,objects=fixture();objects.modern.tags={'Raid','MyLittlePony'};local candidate=assert(session:Stage('modern'));local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Tagged'));local view=assert(a:GetRotationExportData(0,id));assert(a.RotationData.GetRotationTags(view)[2]=='MyLittlePony');a:GetEditableRotation(0,id).tags={'PVP'};view=assert(a:GetRotationExportData(0,id));assert(view.tags[1]=='PVP' and a.db.profile.rotationLibrary.imports[0][id].manifest.tags[1]=='Raid');local copy=assert(a:DuplicateCustomRotation(0,id,'Copy'));assert(a:GetRotationExportData(0,copy).tags[1]=='PVP')
end)
test('comparison preserves inherited tags across custom default and import-preview routes',function()
    local a,session,objects,_,d=fixture()
    local load=assert(loadfile('Data/visual_comparison.lua'));load('rotationmaster',a)
    local tags=assert(loadfile('Core/rotation_tags.lua'));tags('rotationmaster',a)
    objects.modern.tags={'Raid'};local candidate=assert(session:Stage('modern'));local first=assert(a:ApplyRotationImport(session,candidate.token,0,'Same'))
    objects.modern.tags={'PVP'};candidate=assert(session:Stage('modern'));local second=assert(a:ApplyRotationImport(session,candidate.token,0,'Same'))
    local report=assert(a:BuildRotationComparison(0,second,{kind='custom',id=first}));local model=assert(d.BuildVisualComparison(report.views[1]))
    assert(model.tagsChanged and model.leftTags[1]=='Raid' and model.rightTags[1]=='PVP','custom comparison lost inherited tags')
    a:GetEditableRotation(0,second).tags={'Solo'}
    model=assert(d.BuildVisualComparison(assert(a:BuildRotationComparison(0,second,{kind='custom',id=first})).views[1]))
    assert(model.leftTags[1]=='Raid' and model.rightTags[1]=='Solo')
    local pack=d.CopyData(objects.modern);pack.id='unrelated.pack';pack.tags={'Dungeon'};assert(a:RegisterDefaultRotation(pack))
    model=assert(d.BuildVisualComparison(assert(a:BuildRotationComparison(0,first,{kind='builtin',id=pack.id})).views[1]))
    assert(model.tagsChanged and model.leftTags[1]=='Dungeon' and model.rightTags[1]=='Raid','default comparison lost inherited tags')
    local own=a:GetRotationExportData(0,first)
    model=assert(d.BuildVisualComparison(assert(session:Compare(candidate.token,own.body,d.GetRotationTags(own)))))
    assert(model.tagsChanged and model.leftTags[1]=='Raid' and model.rightTags[1]=='PVP','import preview lost inherited tags')
    assert(a:GetEditableRotation(0,first).tags==nil,'comparison materialized inherited tags')
end)
test('switch priority survives importing duplication and export',function()
    local a,session,objects=fixture();objects.modern.body.priority=80;local candidate=assert(session:Stage('modern'));local id=assert(a:ApplyRotationImport(session,candidate.token,0,'Priority'))
    local duplicate=assert(a:DuplicateCustomRotation(0,id,'Copy'));assert(a:GetRotationExportData(0,duplicate).body.priority==80)
end)
finish()
