local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture()
    local data,envelope,validation=make()
    local addon={RotationData=data,conditionDefinitions=validation.conditions,
        db={profile={rotations={[0]={user={name='Existing custom',rotation={}}}},itemsets={}},global={effects={}}}}
    local context={family='tbc',class='SHAMAN',level=11,spec=0,actionContext='player',combatDataPolicy='probe'}
    local n=0;addon.uuid=function() n=n+1;return '00000000-0000-0000-0000-'..string.format('%012d',n) end
    local env=setmetatable({LibStub=function() return {GetLocale=function() return setmetatable({}, {__index=function(_,k) return k end}) end} end},{__index=_G})
    local function load(p) local f=assert(loadfile(p));setfenv(f,env);f('rotationmaster',addon) end
    load('Core/rotation_active.lua')
    load('Core/rotation_references.lua')
    load('Data/catalog.lua');load('Data/diff.lua');load('Core/rotation_library.lua');load('Core/rotation_tags.lua')
    addon.GetRotationContext=function() return context end
    return addon,envelope,context,load
end
test('current-class defaults stay visible but only eligible enabled defaults reach runtime',function()
    local addon,envelope,context=fixture()
    local pack=envelope();pack.applicability.maxLevel=19
    assert(addon:RegisterDefaultRotation(pack))
    assert(addon:InitializeRotationLibrary())
    local rows=addon:ListDefaultRotations(0)
    assert(#rows==1 and rows[1].readOnly and rows[1].eligible)
    local key=rows[1].runtimeKey
    assert(addon:GetRuntimeRotations(0)[key].rotation[1].action==403)
    assert(addon:GetRuntimeRotations(0).user.name=='Existing custom')
    assert(addon:SetDefaultRotationEnabled(pack.id,false))
    assert(#addon:ListDefaultRotations(0)==1 and not addon:GetRuntimeRotations(0)[key])
    assert(addon:SetDefaultRotationEnabled(pack.id,true))
    for _,change in ipairs({{'level',20},{'family','retail'},{'actionContext','vehicle'},{'level',false}}) do
        local old=context[change[1]];context[change[1]]=change[2]
        assert(not addon:GetRuntimeRotations(0)[key],change[1]..' failed applicability')
        assert(#addon:ListDefaultRotations(0)==1)
        context[change[1]]=old
    end
    context.combatDataPolicy='restricted'
    assert(not addon:GetRuntimeRotations(0)[key])
end)
test('declared class is a hard listing and candidate gate while saved references remain intact',function()
    local a,envelope,context,load=fixture();local pack=envelope()
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local key=a:ListDefaultRotations(0)[1].runtimeKey
    local clone=assert(a:CloneDefaultRotation(0,pack.id,'My clone'))
    load('Core/imports.lua')
    local manifest=a.RotationData.CopyData(pack);manifest.body=nil
    local imported=assert(a:CreateImportedRotation({body=pack.body,manifest=manifest},0,'Imported'))
    local body=a:GetEditableRotation(0,clone);local origin=a.db.profile.rotationLibrary.origins[0][clone]
    local importedBody=a:GetEditableRotation(0,imported);local importedOrigin=a.db.profile.rotationLibrary.imports[0][imported]
    assert(a:GetRotationCandidates(0)[key] and a:GetRotationCandidates(0)[clone] and a:GetRotationCandidates(0)[imported])
    for _,class in ipairs({{value='MAGE'}, {}}) do
        context.class=class.value
        assert(#a:ListDefaultRotations(0)==0,'foreign or unknown class remained in the list')
        local runtime,candidates=a:GetRuntimeRotations(0),a:GetRotationCandidates(0)
        for _,id in ipairs({key,clone,imported}) do
            assert(not runtime[id] and not candidates[id],'declared class escaped the hard eligibility gate')
        end
        assert(candidates.user==a.db.profile.rotations[0].user,'unscoped custom behavior changed')
        assert(a:GetDefaultRotation(pack.id).envelope.body.rotation[1].action==403,'reference getter lost foreign definition')
        assert(a:GetRotationForCleanup(0,key).rotation[1].action==403,'cleanup lost previous Built In')
        assert(a:GetRotationForCleanup(0,clone)==body and a:GetEditableRotation(0,imported)==importedBody)
        assert(a.db.profile.rotationLibrary.origins[0][clone]==origin and a.db.profile.rotationLibrary.imports[0][imported]==importedOrigin)
    end
    context.class='SHAMAN'
    assert(#a:ListDefaultRotations(0)==1 and a:GetRuntimeRotation(0,key) and a:GetRotationCandidates(0)[clone])
    assert(a:GetRuntimeRotation(0,imported)==importedBody)
end)
test('direct clone rejects foreign and missing class before allocating or writing saved data',function()
    local a,envelope,context=fixture();local pack=envelope()
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local saved=a.db.profile.rotations[0].user
    a.uuid=function() error('rejected clone allocated an identity') end
    for _,class in ipairs({{value='MAGE'}, {}}) do
        context.class=class.value
        local id,why=a:CloneDefaultRotation(0,pack.id,'Rejected')
        assert(not id and why=='class-mismatch','foreign or missing class clone was accepted')
        assert(a.db.profile.rotations[0].user==saved and next(a.db.profile.rotationLibrary.origins)==nil)
        local count=0;for _ in pairs(a.db.profile.rotations[0]) do count=count+1 end
        assert(count==1,'rejected clone left a body')
    end
end)
test('matching class keeps candidate broadening and direct clone behavior for other constraints',function()
    local a,envelope,context=fixture();local pack=envelope()
    pack.applicability.specs={0};pack.applicability.maxLevel=19
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local key=a:ListDefaultRotations(0)[1].runtimeKey
    local clone=assert(a:CloneDefaultRotation(0,pack.id,'Clone'))
    for _,change in ipairs({{'level',20},{'family','retail'},{'actionContext','vehicle'},{'level',false}}) do
        local old=context[change[1]];context[change[1]]=change[2]
        local rows=a:ListDefaultRotations(0)
        assert(#rows==1 and not rows[1].eligible)
        assert(not a:GetRuntimeRotation(0,key) and not a:GetRuntimeRotation(0,clone))
        assert(a:GetRotationCandidates(0)[key] and a:GetRotationCandidates(0)[clone],'non-class candidate broadening changed')
        context[change[1]]=old
    end
    assert(not a:GetRuntimeRotation(262,key) and a:GetRotationCandidates(262)[key],'specialization candidate broadening changed')
    assert(a:SetDefaultRotationEnabled(pack.id,false));context.level=20
    assert(a:CloneDefaultRotation(262,pack.id,'Inspectable disabled default'),'clone incorrectly required runtime eligibility')
end)
test('packaged classless definitions require explicit Universal while clones belong to the current class',function()
    local a,envelope,context=fixture();local pack=envelope();pack.applicability.class=nil
    local registered,why=a:RegisterDefaultRotation(pack);assert(not registered and why=='missing-class-scope')
    pack.applicability.universal=true
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local rows=a:ListDefaultRotations(0);assert(#rows==1 and rows[1].eligible)
    local clone=assert(a:CloneDefaultRotation(0,pack.id,'Universal clone'))
    local source=a:GetSourcedRotationView(0,clone)
    assert(source.applicability.class=='SHAMAN' and not source.applicability.universal)
    assert(source.lineage.baseline.applicability.universal and not source.lineage.baseline.applicability.class,'clone rewrote source baseline')
    assert(a:GetRotationCandidates(0)[rows[1].runtimeKey] and a:GetRuntimeRotation(0,clone))
    context.class='MAGE';assert(#a:ListDefaultRotations(0)==1 and a:GetRuntimeRotation(0,rows[1].runtimeKey))
    assert(not a:GetRuntimeRotation(0,clone) and not a:GetRotationCandidates(0)[clone],'Universal clone became cross-class custom data')
    context.class=nil;a.uuid=function() error('clone allocated without class context') end
    local id,reason=a:CloneDefaultRotation(0,pack.id,'Unknown class');assert(not id and reason=='class-mismatch')
    context.class='UNKNOWN';id,reason=a:CloneDefaultRotation(0,pack.id,'Unknown class');assert(not id and reason=='class-mismatch')
end)
test('packaged snapshots cannot be edited and custom key collisions cannot overwrite data',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));pack.body.rotation[1].action=974
    assert(addon:InitializeRotationLibrary())
    local rows=addon:ListDefaultRotations(0);local key=rows[1].runtimeKey
    addon.db.profile.rotations[0][key]={name='Collision survives'}
    local runtime=addon:GetRuntimeRotations(0)
    assert(runtime[key].name=='Collision survives')
    rows=addon:ListDefaultRotations(0);key=rows[1].runtimeKey
    assert(runtime[key].rotation[1].action==403)
    runtime[key].rotation[1].action=529
    assert(addon:GetRuntimeRotations(0)[key].rotation[1].action==403)
    assert(addon:GetEditableRotation(0,key)==nil)
end)
test('clones have one independent saved body, fresh IDs and a retained update baseline',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local id=assert(addon:CloneDefaultRotation(0,pack.id,'My leveling'))
    local body=addon:GetEditableRotation(0,id)
    assert(body and body.name=='My leveling' and body.rotation[1].id~='step-1')
    body.rotation[1].action=974
    local view=assert(addon:GetSourcedRotationView(0,id))
    assert(view.envelope.body.rotation[1].action==974 and view.lineage.baseline.body.rotation[1].action==403)
    assert(addon:GetDefaultRotation(pack.id).envelope.body.rotation[1].action==403)
    assert(not addon.db.profile.rotationLibrary.custom,'duplicate persisted custom body')
    local context=addon:GetRotationContext();local old=context.class;context.class='MAGE'
    assert(not addon:GetRuntimeRotations(0)[id],'sourced clone escaped class applicability')
    context.class=old
    assert(addon:InitializeRotationLibrary()) -- reload/profile bridge reconstructs from persisted data
    view=assert(addon:GetSourcedRotationView(0,id))
    local result=addon.RotationData.CompareClone(view,addon:GetDefaultRotation(pack.id))
    assert(result.valid and #result.customChanges.changes>0)
end)
test('profile changes rebind enable preferences and preserve unrelated saved data',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local original=addon.db.profile
    assert(addon:SetDefaultRotationEnabled(pack.id,false))
    addon.db.profile={rotations={}}
    assert(addon:ListDefaultRotations(0)[1].enabled)
    addon.db.profile=original
    assert(not addon:ListDefaultRotations(0)[1].enabled)
    assert(original.rotations[0].user.name=='Existing custom')
end)
test('unknown applicability constraints and malformed state remain inert and preserved',function()
    local addon,envelope=fixture();local pack=envelope();pack.applicability.specs={262}
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    assert(not addon:ListDefaultRotations(0)[1].eligible)
    assert(addon:ListDefaultRotations(262)[1].eligible)
    addon.db.profile.rotationLibrary=false
    local rows,why=addon:ListDefaultRotations(0)
    assert(#rows==0 and why=='invalid-library-state' and addon.db.profile.rotationLibrary==false)
end)
test('runtime validation follows edits after reload rather than retaining an old result',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local id=assert(addon:CloneDefaultRotation(0,pack.id,'Edited'))
    local body=addon:GetEditableRotation(0,id);body.rotation[1].action=nil
    assert(addon:InitializeRotationLibrary())
    assert(not addon:GetRuntimeRotations(0)[id])
    body.rotation[1].action=974
    assert(addon:GetRuntimeRotations(0)[id],'completed clone remained unavailable')
    body.rotation[1].action='bad'
    assert(not addon:GetRuntimeRotations(0)[id],'invalid edit retained positive validation')
end)
test('duplicating a sourced clone preserves its original baseline with independent fresh steps',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local first=assert(addon:CloneDefaultRotation(0,pack.id,'First'))
    local original=addon:GetEditableRotation(0,first);original.rotation[1].conditions.spell=324
    original.rotation[2]={id='user-added',type='spell',action=529,conditions={}}
    local second=assert(addon:DuplicateCustomRotation(0,first,'Second'))
    local duplicate=addon:GetEditableRotation(0,second)
    assert(duplicate.rotation[1].id~=original.rotation[1].id)
    duplicate.rotation[1].conditions.spell=974
    assert(original.rotation[1].conditions.spell==324)
    local view=assert(addon:GetSourcedRotationView(0,second))
    assert(view.lineage.sourceId==pack.id and view.lineage.baseline.body.rotation[1].conditions.spell==403)
    assert(view.lineage.stepOrigins[duplicate.rotation[1].id]=='step-1')
    local result=addon.RotationData.CompareClone(view,addon:GetDefaultRotation(pack.id))
    assert(result.valid and result.complete)
    local changedPredicate=false
    for _,change in ipairs(result.currentDifferences.changes) do
        if change.stepId~='user-added' and change.path~='$.body.rotation['..duplicate.rotation[2].id..']' then
            assert(change.kind~='added' and change.kind~='removed','fresh IDs hid clone ancestry')
        end
        if change.path=='$.body.rotation[step-1].conditions.spell' then changedPredicate=true end
    end
    assert(changedPredicate)
    local related=assert(addon:BuildRotationComparison(0,second,{kind='custom',id=first}))
    for _,change in ipairs(related.changes) do
        assert(change.kind~='added' and change.kind~='removed','copied user-added step lost correspondence')
    end
end)
test('ordinary incomplete custom rotations duplicate without sharing conditions or retaining step IDs',function()
    local addon=fixture();local source={name='Incomplete',rotation={{id='old-step',conditions={type='NOT',value={type='BUFF',spell=324}}}}}
    addon.db.profile.rotations[0].user=source
    local id=assert(addon:DuplicateCustomRotation(0,'user','Duplicate'))
    local duplicate=addon:GetEditableRotation(0,id)
    duplicate.rotation[1].conditions.value.spell=974
    assert(source.rotation[1].conditions.value.spell==324 and duplicate.rotation[1].id~='old-step')
end)
test('comparison of two clones uses their shared original step identities',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local first=assert(addon:CloneDefaultRotation(0,pack.id,'First'))
    local second=assert(addon:DuplicateCustomRotation(0,first,'Second'))
    addon:GetEditableRotation(0,second).rotation[1].action=974
    local result=assert(addon:BuildRotationComparison(0,second,{kind='custom',id=first}))
    assert(result.valid and result.complete)
    local found=false
    for _,change in ipairs(result.changes) do
        assert(change.kind~='added' and change.kind~='removed','related steps appeared replaced')
        if change.path=='$.body.rotation[step-1].action' then found=true end
    end
    assert(found)
end)
test('ordinary duplicate comparisons retain correspondence without inventing a source baseline',function()
    local addon=fixture()
    addon.db.profile.rotations[0].user={name='Original',rotation={{id='old-step',type='spell',action=403,conditions={}}}}
    local duplicate=assert(addon:DuplicateCustomRotation(0,'user','Duplicate'))
    addon:GetEditableRotation(0,duplicate).rotation[1].action=324
    local result=assert(addon:BuildRotationComparison(0,duplicate,{kind='custom',id='user'}))
    assert(result.valid and result.complete and not result.sourceChanges)
    local found=false
    for _,change in ipairs(result.changes) do
        assert(change.kind~='added' and change.kind~='removed')
        if change.path=='$.body.rotation[old-step].action' then found=true end
    end
    assert(found)
end)
test('duplication refuses collisions with retained baseline identities atomically',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local id=assert(addon:CloneDefaultRotation(0,pack.id,'First'))
    addon:GetEditableRotation(0,id).rotation={{id='user-added',type='spell',action=403,conditions={type='SPELL_KNOWN',spell=403}}}
    local n=0;addon.uuid=function() n=n+1;return n==1 and 'copy-root' or 'step-1' end
    local generated,why=addon:DuplicateCustomRotation(0,id,'Second')
    assert(not generated and why=='id-collision')
    assert(not addon.db.profile.rotations[0]['copy-root'],'collision left a partial saved duplicate')
end)
test('corrupt saved lineage cannot silently downgrade an expected three-way comparison',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local id=assert(addon:CloneDefaultRotation(0,pack.id,'First'))
    addon.db.profile.rotationLibrary.origins[0][id].lineage.sourceRevision=999
    local result,why=addon:BuildRotationComparison(0,id,{kind='builtin',id=pack.id})
    assert(result==nil and why=='invalid-origin-state','corrupt provenance silently became a complete two-way report')
end)
test('comparison snapshots expose all three directions without live saved-variable references',function()
    local addon,envelope=fixture();local pack=envelope()
    assert(addon:RegisterDefaultRotation(pack));assert(addon:InitializeRotationLibrary())
    local id=assert(addon:CloneDefaultRotation(0,pack.id,'Mine'))
    local result=assert(addon:BuildRotationComparison(0,id,{kind='builtin',id=pack.id}))
    assert(result.views and #result.views==3,'graphical comparison lacks source snapshots')
    assert(result.views[1].key=='current' and result.views[2].key=='source' and result.views[3].key=='custom')
    local origins=result.views[1].rightOrigins
    assert(origins[result.views[1].right.body.rotation[1].id]=='step-1')
    result.views[1].right.body.rotation[1].action=999
    result.views[1].left.body.rotation[1].action=999
    assert(addon:GetEditableRotation(0,id).rotation[1].action==403)
    assert(addon:GetDefaultRotation(pack.id).envelope.body.rotation[1].action==403)
end)
test('restricted and unsupported clients keep custom editing without executing unscoped legacy advice',function()
    local addon,_,context=fixture();assert(addon:InitializeRotationLibrary())
    assert(addon:GetRuntimeRotation(0,'user'))
    for _,policy in ipairs({'restricted','unsupported'}) do
        context.combatDataPolicy=policy
        assert(not addon:GetRuntimeRotation(0,'user'),'legacy custom body bypassed client capability policy')
        assert(addon:GetEditableRotation(0,'user').name=='Existing custom','reference editing was lost')
    end
end)
test('self comparison is rejected while a fresh clone pairs every unchanged step',function()
    local a,envelope,_,load=fixture();load('Data/visual_comparison.lua');local pack=envelope()
    pack.body.cooldowns={{id='buff',type='spell',action=324,conditions={type='SPELL_KNOWN',spell=324}}}
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local id=assert(a:CloneDefaultRotation(0,pack.id,'My clone'))
    local result=assert(a:BuildRotationComparison(0,id,{kind='builtin',id=pack.id}))
    for _,view in ipairs(result.views) do
        local model=assert(a.RotationData.BuildVisualComparison(view))
        for _,rows in pairs(model.groups) do for _,row in ipairs(rows) do
            assert(row.left and row.right and not row.changed and not row.moved and not row.added and not row.removed)
        end end
    end
    local selfResult,why=a:BuildRotationComparison(0,id,{kind='custom',id=id})
    assert(selfResult==nil and why=='self-comparison','self-comparison was allowed')
end)
test('missing current specialization cannot activate even a generic packaged rotation while references stay visible',function()
    local a,envelope=fixture();local pack=envelope();pack.applicability.spec=nil
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    assert(next(a:GetRuntimeRotations(0)) and #a:ListDefaultRotations(0)==1)
    assert(next(a:GetRuntimeRotations(nil))==nil,'unknown current selection activated a generic default')
    assert(next(a:GetRotationCandidates(nil))==nil)
    assert(#a:ListDefaultRotations(0)==1 and a:GetEditableRotation(0,'user').name=='Existing custom')
end)
test('ordinary nested duplicates reidentify both arms and preserve comparison correspondence',function()
    local a=fixture();a.db.profile.rotations[0].user={name='Tree',rotation={{id='branch',type='branch',mode='true',conditions={},
        onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='spell',action=324}}}},cooldowns={}}
    local id=assert(a:DuplicateCustomRotation(0,'user','Copy'));local copy=a:GetEditableRotation(0,id)
    local b=copy.rotation[1];assert(b.id~='branch' and b.onTrue[1].id~='yes' and b.onFalse[1].id~='no')
    local identity=assert(a:GetRotationComparisonIdentity(0,id))
    assert(identity.origins[b.id]=='branch' and identity.origins[b.onTrue[1].id]=='yes' and identity.origins[b.onFalse[1].id]=='no')
    b.onTrue[1].action=8042;assert(a:GetEditableRotation(0,'user').rotation[1].onTrue[1].action==403)
end)
test('a nested identity collision in a saved rotation prevents duplicate allocation atomically',function()
    local a=fixture();a.db.profile.rotations[0].other={name='Other',rotation={{id='branch',type='branch',onTrue={{id='nested-collision',type='none'}},onFalse={}}}}
    local calls=0;a.uuid=function() calls=calls+1;return calls==1 and 'new-copy' or 'nested-collision' end
    a.db.profile.rotations[0].user={name='Original',rotation={{id='original',type='spell',action=403}}}
    local id,why=a:DuplicateCustomRotation(0,'user','Copy')
    assert(not id and why=='id-collision' and a.db.profile.rotations[0]['new-copy']==nil)
    assert(a.db.profile.rotations[0].other.rotation[1].onTrue[1].id=='nested-collision')
end)
test('condition ownership includes nested saved nodes and refuses stale or value-equal replacements',function()
    local a=fixture();local leaf={id='yes',type='spell',action=403,conditions={type='SPELL_KNOWN',spell=403}}
    local b={id='b',type='branch',conditions={},onTrue={leaf},onFalse={}}
    a.db.profile.rotations[0].user={name='Tree',rotation={b}}
    assert(a:OwnsRotationCondition(0,'user',leaf,leaf.conditions))
    assert(a:OwnsRotationCondition(0,'user',b,b.conditions))
    local old=leaf.conditions;leaf.conditions=a.RotationData.CopyData(old)
    assert(not a:OwnsRotationCondition(0,'user',leaf,old))
    b.onTrue[1]=a.RotationData.CopyData(leaf);assert(not a:OwnsRotationCondition(0,'user',leaf,leaf.conditions))
end)
test('custom deletion removes only its provenance and refuses defaults fallback and corrupt state',function()
    local a,envelope=fixture();assert(a:RegisterDefaultRotation(envelope()));assert(a:InitializeRotationLibrary())
    local key=a:ListDefaultRotations(0)[1].runtimeKey
    assert(not a:DeleteCustomRotation(0,key));assert(not a:DeleteCustomRotation(0,'Default'))
    local state=a.db.profile.rotationLibrary
    for _,field in ipairs({'origins','comparisons','imports'}) do state[field][0]={user={retained=true},other={retained=true}} end
    state.imports[0]='bad';assert(not a:DeleteCustomRotation(0,'user'));assert(a:GetEditableRotation(0,'user'))
    state.imports[0]={user={},other={}}
    a.currentRotation='user';a.manualRotation=true;local cleared=false
    a.RemoveAllCurrentGlows=function() cleared=true end
    assert(a:DeleteCustomRotation(0,'user'));assert(cleared and not a.currentRotation and not a.manualRotation)
    assert(not a:GetEditableRotation(0,'user'))
    for _,field in ipairs({'origins','comparisons','imports'}) do assert(state[field][0].user==nil and state[field][0].other) end
end)
test('packaged and cloned item actions resolve global sets while explicit personal entries keep precedence',function()
    local a,envelope=fixture();local pack=envelope();pack.body.rotation[1]={id='item-step',type='item',action='shared',conditions={}}
    a.db.global.itemsets={shared={name='Shared',items={5512}}}
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    local row=a:ListDefaultRotations(0)[1];assert(row.eligible,'global set was omitted from default validation')
    local clone=assert(a:CloneDefaultRotation(0,pack.id,'Items'));assert(a:GetRuntimeRotations(0)[clone])
    a.db.profile.itemsets.shared=false
    assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotations(0)[clone],'personal false fell through to global data')
    a.db.profile.itemsets.shared=nil;assert(a:ListDefaultRotations(0)[1].eligible and a:GetRuntimeRotations(0)[clone])
end)
test('reference additions removal and effect recovery refresh default eligibility without reloading',function()
    local a,envelope=fixture();local pack=envelope();pack.body.rotation[1]={id='item-step',type='item',action='shared',conditions={},effect='outline'}
    assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary());assert(not a:ListDefaultRotations(0)[1].eligible)
    a.db.global.itemsets={shared={items={5512}}};a.db.global.effects.outline={}
    assert(a:ListDefaultRotations(0)[1].eligible,'added references did not refresh the cached default')
    a.db.global.effects.outline=nil;assert(not a:ListDefaultRotations(0)[1].eligible)
    a.db.global.effects.outline={};assert(a:ListDefaultRotations(0)[1].eligible)
    a.db.global.itemsets.shared=nil;assert(not a:ListDefaultRotations(0)[1].eligible)
end)
test('schema changes refresh defaults while unchanged lookups avoid revalidating packaged graphs',function()
    local a,envelope=fixture();assert(a:RegisterDefaultRotation(envelope()));assert(a:InitializeRotationLibrary())
    local validate=a.RotationData.ValidateEnvelope;local calls=0
    a.RotationData.ValidateEnvelope=function(...) calls=calls+1;return validate(...) end
    for _=1,3 do assert(a:ListDefaultRotations(0)[1].eligible);a:GetRuntimeRotations(0) end
    assert(calls==0,'unchanged lookups revalidated packaged graphs')
    local schema=a.conditionDefinitions.SPELL_KNOWN;a.conditionDefinitions.SPELL_KNOWN=nil
    assert(not a:ListDefaultRotations(0)[1].eligible,'removed schema stayed resolved')
    a.conditionDefinitions.SPELL_KNOWN=schema;assert(a:ListDefaultRotations(0)[1].eligible)
    schema.fields.spell='string';a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1
    assert(not a:ListDefaultRotations(0)[1].eligible,'same-object registered schema change was ignored')
    schema.fields.spell='number';a.conditionRegistryVersion=a.conditionRegistryVersion+1;assert(a:ListDefaultRotations(0)[1].eligible)
end)
test('public merged reference options cannot poison private snapshots and malformed namespace maps stay inert',function()
    local a,envelope=fixture();assert(a.GetRotationValidationOptions,'shared reference context missing')
    a.db.global.itemsets={shared={items={5512}}}
    local options,stamp=a:GetRotationValidationOptions();options.itemsets.shared=nil
    local fresh,nextStamp=a:GetRotationValidationOptions();assert(fresh.itemsets.shared and stamp==nextStamp)
    assert(a.db.global.itemsets.shared.items[1]==5512)
    for _,value in ipairs({false,17,'invalid'}) do
        a.db.profile.itemsets=value
        assert(next(a:GetRotationValidationOptions().itemsets)==nil,'malformed personal map exposed global references')
    end
    a.db.profile.itemsets={personal={items={5512}}}
    for _,value in ipairs({false,17,'invalid'}) do
        a.db.global.itemsets=value
        assert(next(a:GetRotationValidationOptions().itemsets)==nil,'malformed global map exposed references runtime cannot use')
    end
end)
test('missing reference maps return isolated fallbacks without cross-aliasing or stamp churn',function()
    local a=fixture();a.conditionDefinitions=nil;a.db.global.effects=nil
    assert(a.GetRotationValidationOptions)
    local options,stamp=a:GetRotationValidationOptions();options.effects.injected={};options.conditions.phantom={fields={}}
    local fresh,nextStamp=a:GetRotationValidationOptions()
    assert(next(fresh.effects)==nil and next(fresh.conditions)==nil,'fallback mutation escaped into later contexts')
    assert(stamp==nextStamp,'unchanged empty namespaces caused stamp churn')
end)
test('malformed non-table reference entries remain unresolved without recursive clone initialization',function()
    local a,envelope=fixture();local pack=envelope();assert(a:RegisterDefaultRotation(pack));assert(a:InitializeRotationLibrary())
    assert(a:CloneDefaultRotation(0,pack.id,'Clone'))
    a.db.global.effects.poison=0/0
    local initialize=a.InitializeRotationLibrary;local calls=0
    a.InitializeRotationLibrary=function(self) calls=calls+1;assert(calls<=6,'recursive dependency initialization');return initialize(self) end
    local ok,rows=pcall(a.ListDefaultRotations,a,0);assert(ok,'malformed reference caused recursive initialization')
    assert(#rows==1 and rows[1].eligible and calls==1)
    a:ListDefaultRotations(0);assert(calls==1,'unchanged malformed entry caused repeated rebuilds')
    local bad=envelope();bad.id='rm.tbc.bad-effect';bad.body.rotation[1].effect='poison';assert(a:RegisterDefaultRotation(bad))
    for _,row in ipairs(a:ListDefaultRotations(0)) do if row.id==bad.id then assert(not row.eligible and not row.validation.resolved) end end
end)
test('disabled dependencies block entire legacy bodies including switch optional and nested fields',function()
    local a=fixture();a.conditionDefinitions.OFF={fields={},disabled=true}
    a.conditionDefinitions.WRAP={fields={child='condition',children='condition[]'}}
    local body=a:GetEditableRotation(0,'user');body.rotation={{type='spell',action=403,conditions={type='OFF'}},{type='spell',action=529,conditions={}}}
    assert(not a:GetRuntimeRotation(0,'user'),'later action can run after disabled dependency')
    body.rotation[1].conditions={};body.switch={type='NOT',value={type='OFF'}}
    assert(not a:GetRuntimeRotation(0,'user'),'manual rotation escaped disabled switch dependency')
    body.switch={};body.cooldowns={{type='spell',action=403,conditions={type='WRAP',children={{type='OFF'}}}}}
    assert(not a:GetRuntimeRotation(0,'user'),'optional dependency escaped guard')
    body.cooldowns={};body.rotation={{type='branch',mode='false',conditions={},onTrue={{type='spell',action=403,conditions={type='WRAP',child={type='OFF'}}}},onFalse={}}}
    assert(not a:GetRuntimeRotation(0,'user'),'nested arm dependency escaped guard')
    assert(a:GetEditableRotation(0,'user')==body,'repair access lost')
    a.conditionDefinitions.OFF={fields={}};a.conditionRegistryVersion=1
    assert(a:GetRuntimeRotation(0,'user')==body,'reenabled dependency did not restore body')
end)
finish()
