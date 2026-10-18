local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local a={};for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua'}) do assert(loadfile(file))('rotationmaster',a) end
local file=io.open('Data/rotation_draft.lua');if file then file:close();assert(loadfile('Data/rotation_draft.lua'))('rotationmaster',a) end
local data=a.RotationData
local function leaf(id) return {id=id,type='spell',action=403,conditions={}} end
local function branch(id) return {id=id,type='branch',conditions={},onTrue={leaf('yes')},onFalse={leaf('no')}} end
local function body() return {name='Mine',switch={},rotation={branch('b'),leaf('tail')},cooldowns={leaf('optional')}} end
local function allocator() local i=0;return function() i=i+1;return 'new-'..i end end
local function draft(value,newId,reserved) return assert(data.NewRotationDraft(value or body(),newId or allocator(),reserved)) end
local function equal(x,y) if type(x)~=type(y) then return false end;if type(x)~='table' then return x==y end;for k,v in pairs(x) do if not equal(v,y[k]) then return false end end;for k in pairs(y) do if x[k]==nil then return false end end;return true end
test('draft snapshots and sibling conditions are detached even for aliased source tables',function()
    local original=body();original.rotation[1].onTrue[1].conditions=original.switch
    local d=draft(original);local snapshot=d:Snapshot();snapshot.switch.type='CUSTOM'
    assert(next(d:Snapshot().switch)==nil and next(original.switch)==nil and next(snapshot.rotation[1].onTrue[1].conditions)==nil)
    assert(d:Command('SetCondition','yes',{type='CUSTOM',payload={onTrue={1,2}}}))
    assert(d:Snapshot().rotation[1].onTrue[1].conditions.type=='CUSTOM' and next(d:Snapshot().switch)==nil)
end)
test('insert and duplicate allocate fresh recursive identities and preserve opaque condition data',function()
    local d=draft();local ok,id=d:Command('Insert',{path={'rotation'},index=2},branch('ignored'));assert(ok and id=='new-1')
    local v=d:Snapshot();assert(v.rotation[2].onTrue[1].id=='new-2' and v.rotation[2].onFalse[1].id=='new-3')
    ok,id=d:Command('Duplicate','b');assert(ok and id=='new-4');v=d:Snapshot()
    assert(v.rotation[2].id==id and v.rotation[2].onTrue[1].id=='new-5' and v.rotation[3].id=='new-1')
    assert(data.IndexRotationSteps(v))
end)
test('moves across arms preserve identity and same-list insertion indexes are adjusted exactly once',function()
    local d=draft();assert(d:Command('Move','yes',{path={'rotation',1,'onFalse'},parentId='b',index=2}))
    local v=d:Snapshot();assert(#v.rotation[1].onTrue==0 and v.rotation[1].onFalse[2].id=='yes')
    assert(d:Command('Move','tail',{path={'rotation'},index=1}));v=d:Snapshot();assert(v.rotation[1].id=='tail')
    assert(d:Command('Move','tail',{path={'rotation'},index=3}));assert(d:Snapshot().rotation[2].id=='tail')
end)
test('cycles optional branches stale paths and protected identity patches fail atomically',function()
    local d=draft();local before=d:Snapshot()
    for _,command in ipairs({{'Move','b',{path={'rotation',1,'onTrue'},parentId='b',index=1}},
        {'Move','b',{path={'cooldowns'},index=1}}, {'Move','tail',{path={'rotation',99,'onTrue'},index=1}},
        {'UpdateStep','b',{id='overwritten'}},{'UpdateStep','b',{onTrue={}}},
        {'UpdateStep','b',{disabled=true}},{'Insert',{path={'cooldowns'},index=1},branch('bad')},
        {'UpdateStep','b',{type='spell'}},{'Move','tail',{path={'rotation',extra=true},index=1}},
        {'Move','tail',{path={'rotation'},index=0}},{'SetBodyField','rotation',{}},{'Execute','anything'}}) do
        assert(not d:Command(unpack(command)),command[1]);assert(equal(before,d:Snapshot()),'failed edit changed the draft')
    end
end)
test('deleted and provenance identities cannot be recycled and failed recursive allocation is atomic',function()
    local value=body();local ids={'yes','historical','fresh'};local n=0
    local d=draft(value,function() n=n+1;return ids[n] end,{baseline={id='historical'}})
    assert(d:Command('Remove','yes'));local ok,id=d:Command('Insert',{path={'rotation'},index=1},leaf('ignored'));assert(ok and id=='fresh')
    local fail=draft(nil,function() return 'only-one' end);local before=fail:Snapshot()
    assert(not fail:Command('Duplicate','b'));assert(equal(before,fail:Snapshot()))
end)
test('step updates and conditions are copied and legacy IDs are allocated without mutating source',function()
    local value=body();value.rotation[2].id=nil
    local d=draft(value);assert(d:Snapshot().rotation[2].id=='new-1' and value.rotation[2].id==nil)
    local patch={name='Renamed',action=8042};assert(d:Command('UpdateStep','new-1',patch));patch.name='bad'
    assert(d:Command('UpdateStep','b',{mode='false'}));assert(d:Command('SetBodyField','name','Edited'))
    local v=d:Snapshot();assert(v.name=='Edited' and v.rotation[2].name=='Renamed' and v.rotation[1].mode=='false')
    assert(value.name=='Mine' and value.rotation[2].name==nil)
end)
test('optional field removal is explicit and cannot erase branch arms or identities',function()
    local d=draft();assert(d:Command('UpdateStep','yes',{name='Named',effect='glow'}))
    assert(d:Command('UnsetStepField','yes','effect'));assert(d:Snapshot().rotation[1].onTrue[1].effect==nil)
    assert(d:Snapshot().rotation[1].onTrue[1].name=='Named')
    assert(not d:Command('UnsetStepField','b','onTrue') and not d:Command('UnsetStepField','yes','id'))
end)
test('nested destinations remain bound to their intended branch after reordering',function()
    local value=body();value.rotation[2]={id='other',type='branch',conditions={},onTrue={},onFalse={}}
    local d=draft(value);local stale={path={'rotation',1,'onTrue'},parentId='b',index=1}
    assert(d:Command('Move','other',{path={'rotation'},index=1}))
    local before=d:Snapshot();local ok,why=d:Command('Move','no',stale)
    assert(not ok and why=='stale-rotation-destination');assert(equal(before,d:Snapshot()))
    assert(not d:Command('Move','no',{path={'rotation',1,'onTrue'},index=1}),'unbound nested destination was accepted')
end)
test('a step named switch is distinct from the rotation switching condition',function()
    local value=body();value.rotation[2].id='switch';local d=draft(value)
    assert(d:Command('SetCondition','switch',{type='STEP'}))
    assert(d:Snapshot().rotation[2].conditions.type=='STEP' and next(d:Snapshot().switch)==nil)
    assert(d:Command('SetCondition',{kind='switch'},{type='ROOT'}));assert(d:Snapshot().switch.type=='ROOT')
end)
test('field patches clear and replace action settings in one atomic edit',function()
    local d=draft();assert(d:Command('PatchStep','yes',{set={type='none',suppress_attack=true},unset={'action','ranked'}}))
    local step=d:Snapshot().rotation[1].onTrue[1];assert(step.type=='none' and step.action==nil and step.suppress_attack)
    local before=d:Snapshot();assert(not d:Command('PatchStep','b',{set={name='Changed'},unset={'onTrue'}}));assert(equal(before,d:Snapshot()))
end)
test('branch insertion captures its following sequence in True with identities intact',function()
    local d=draft();assert(d:Command('Insert',{path={'rotation'},index=1},{type='branch',conditions={},onTrue={},onFalse={}}))
    local v=d:Snapshot();assert(#v.rotation==1 and #v.rotation[1].onTrue==2)
    assert(v.rotation[1].onTrue[1].id=='b' and v.rotation[1].onTrue[2].id=='tail')
    assert(v.rotation[1].onTrue[1].onFalse[1].id=='no')
    assert(#v.cooldowns==1)
end)
test('moving a sequence tail carries later branch subtrees and refuses all carried descendants',function()
    local value=body();value.rotation={leaf('first'),branch('later'),{id='target',type='branch',conditions={},onTrue={},onFalse={}}}
    local d=draft(value);local before=d:Snapshot()
    assert(not d:Command('MoveTail','first',{path={'rotation',2,'onTrue'},parentId='later',index=1}))
    assert(equal(before,d:Snapshot()))
    -- A separate branch before the source remains a valid destination.
    value.rotation={value.rotation[3],value.rotation[1],value.rotation[2]};d=draft(value)
    assert(d:Command('MoveTail','first',{path={'rotation',1,'onFalse'},parentId='target',index=1}))
    local v=d:Snapshot();assert(#v.rotation==1 and #v.rotation[1].onFalse==2)
    assert(v.rotation[1].onFalse[1].id=='first' and v.rotation[1].onFalse[2].onTrue[1].id=='yes')
    assert(not d:Command('MoveTail','optional',{path={'rotation',1,'onTrue'},parentId='target',index=1}))
end)
test('metadata commands detach malformed priority data instead of leaking caller ownership',function()
    local d=draft();local input={unexpected=1};assert(d:Command('SetDetails',{priority=input}))
    input.unexpected=2;assert(d:Snapshot().priority.unexpected==1,'caller changed the draft without a command')
end)
test('tail moves work within a sibling list and back out of an arm without crossing sections',function()
    local value=body();value.rotation={leaf('a'),leaf('b'),leaf('c'),leaf('d')};local d=draft(value)
    assert(d:Command('MoveTail','c',{path={'rotation'},index=1}));local v=d:Snapshot()
    assert(v.rotation[1].id=='c' and v.rotation[2].id=='d' and v.rotation[3].id=='a' and v.rotation[4].id=='b')
    local before=d:Snapshot();assert(not d:Command('MoveTail','a',{path={'rotation'},index=4}));assert(equal(before,d:Snapshot()))
    value.rotation={{id='branch',type='branch',conditions={},onTrue={leaf('a'),leaf('b')},onFalse={}},leaf('tail')};d=draft(value)
    assert(d:Command('MoveTail','a',{path={'rotation'},index=2}));v=d:Snapshot();assert(#v.rotation[1].onTrue==0 and v.rotation[2].id=='a' and v.rotation[3].id=='b')
    assert(not d:Command('MoveTail','a',{path={'cooldowns'},index=1}))
end)
finish()
