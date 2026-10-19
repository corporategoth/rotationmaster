local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_data.lua')
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function copy(value)
    if type(value)~='table' then return value end;local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
end
local function address(scope,owner,id,class,spec) return {scope=scope,owner=owner,id=id or 'shared',class=class or 'SHAMAN',spec=spec or 0} end
local ctx={class='SHAMAN',character='A - Realm'}
local function record(name)
    return {body={name=name or 'Mine',switch={},rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}}}
end
local function state()
    return {version=1,classes={SHAMAN={[0]={Default=record('Class fallback'),shared=record('Class')}},MAGE={[0]={shared=record('Mage')}}},
        characters={['A - Realm']={class='SHAMAN',specs={[0]={Default=record('Character fallback'),shared=record('Character')}}},
            ['B - Realm']={class='SHAMAN',specs={[0]={private=record('Other character')}}}},legacy={}}
end
local function fixture(value)
    local data,envelope,validation=make();local addon={RotationData=data}
    local env=setmetatable({}, {__index=function(_,key)
        assert(key~='LibStub' and key~='GetTime' and key~='CreateFrame' and key~='DEFAULT' and key~='UnitClass','pure store requested '..key)
        return _G[key]
    end})
    for _,path in ipairs({'Data/catalog.lua','Data/rotation_store.lua'}) do
        local file=io.open(path);if file then file:close();local load=assert(loadfile(path));setfenv(load,env);load('rotationmaster',addon) end
    end
    assert(type(data.NewRotationStore)=='function','pure rotation store is missing')
    value=value or state()
    return assert(data.NewRotationStore({state=value,fallbackID='Default',validation=validation})),value,data,envelope,validation
end
local function reason(want,actual,why) assert(actual==nil and why==want,tostring(why)..' instead of '..want) end
test('full addresses separate two classes two characters and profiles without rewriting colliding IDs',function()
    local store,s=fixture();local before=copy(s)
    local rows=assert(store:ListVisible(0,ctx));assert(#rows==4)
    local labels={};for _,row in ipairs(rows) do labels[row.record.body.name]=true;assert(row.address.id=='Default' or row.address.id=='shared') end
    assert(labels.Class and labels.Character and labels['Class fallback'] and labels['Character fallback'] and not labels.Mage)
    assert(store:Get(address('class','SHAMAN'),ctx).body.name=='Class')
    local own=store:Get(address('character',ctx.character),ctx);assert(own.body.name=='Character');own.body.name='Detached'
    assert(store:Get(address('character',ctx.character),ctx).body.name=='Character')
    assert(#store:ListVisible(0,{class='MAGE',character='Mage - Realm'})==1)
    reason('foreign-owner',store:Get(address('class','MAGE',nil,'MAGE'),ctx))
    reason('foreign-owner',store:Get(address('character','B - Realm','private'),ctx))
    reason('missing-owner-context',store:ListVisible(0,{}))
    reason('missing-owner-context',store:Get(address('character',ctx.character),{class='SHAMAN'}))
    assert(#store:ListVisible(0,{class='SHAMAN'})==2 and equal(before,s),'read populated or changed persistence')
    local other=fixture();assert(other:Get(address('class','SHAMAN'),ctx).body.name=='Class')
end)
test('fallback prefers Character and malformed Character data cannot silently select Class',function()
    local store,s=fixture()
    local found=assert(store:GetFallback(0,ctx));assert(found.address.scope=='character' and found.record.body.name=='Character fallback')
    found=assert(store:GetFallback(0,{class='SHAMAN',character='B - Realm'}));assert(found.address.scope=='class')
    s.characters[ctx.character].specs[0].Default.body.rotation=false
    local fallback,why=store:GetFallback(0,ctx);assert(fallback and fallback.address.scope=='character' and not fallback.validation.valid and why=='invalid-fallback')
    assert(#store:ListVisible(0,ctx)==4 and store:Get(address('class','SHAMAN'),ctx).body.name=='Class')
    assert(s.classes.SHAMAN[0].Default.body.name=='Class fallback')
end)
test('store rejects malformed structure keys records aliases with metatables and cycles without normalization',function()
    local _,_,data=fixture()
    local invalid={
        function(s) s.version=2 end,function(s) s.extra=true end,function(s) s.classes.UNKNOWN={} end,
        function(s) s.classes.SHAMAN['0']=s.classes.SHAMAN[0] end,function(s) s.classes.SHAMAN[-1]={} end,
        function(s) s.characters[ctx.character].class=nil end,function(s) s.characters[ctx.character].extra=true end,
        function(s) s.classes.SHAMAN[0].shared.extra=true end,function(s) s.classes.SHAMAN[0].shared.body=false end,
        function(s) setmetatable(s.classes.SHAMAN[0].shared.body,{}) end,
        function(s) s.classes.SHAMAN[0].shared.body.switch=s.classes.SHAMAN[0].shared.body end,
        function(s) s.legacy.unrecognized={} end,
    }
    for _,change in ipairs(invalid) do
        local s=state();change(s);local classes,characters,legacy=s.classes,s.characters,s.legacy
        assert(not data.NewRotationStore({state=s,fallbackID='Default'}))
        assert(s.classes==classes and s.characters==characters and s.legacy==legacy,'validation normalized state')
    end
    for _,target in ipairs({address('all','SHAMAN'),address('class','MAGE'),address('class','SHAMAN',nil,'UNKNOWN'),address('class','SHAMAN',nil,nil,-1)}) do
        local store=fixture();reason('invalid-address',store:Get(target,ctx))
    end
    local store=fixture();local target=address('class','SHAMAN');target.extra=true;reason('invalid-address',store:Get(target,ctx))
    assert(not data.NewRotationStore({state=state()}),'fallback dependency was implicitly read from game globals')
end)
test('create plans detach payload authority and recheck ownership before committing once',function()
    local store,s=fixture();local before=copy(s);local target=address('class','SHAMAN','new');local input=record('New')
    local plan=assert(store:PlanCreate(target,input,ctx));assert(equal(before,s),'planning wrote persistence')
    local other=fixture();reason('invalid-plan',other:Commit(plan,ctx));reason('invalid-plan',store:Commit({operation='create',address=target},ctx))
    input.body.name='Input changed';plan.address=address('class','MAGE',nil,'MAGE');plan.record=record('Forged')
    reason('foreign-owner',store:Commit(plan,{class='MAGE',character='Mage - Realm'}));assert(equal(before,s))
    local ok,result=store:Commit(plan,ctx);assert(ok and result.id=='new' and s.classes.SHAMAN[0].new.body.name=='New')
    reason('invalid-plan',store:Commit(plan,ctx));reason('rotation-id-collision',store:PlanCreate(target,record(),ctx))
end)
test('replace detects stale tokens root replacement and same-object body or sidecar edits',function()
    for _,change in ipairs({
        function(s) s.classes.SHAMAN[0].shared=copy(s.classes.SHAMAN[0].shared) end,
        function(s) s.classes.SHAMAN[0].shared.body.name='Externally edited' end,
        function(s) s.classes.SHAMAN[0].shared.comparison.id='changed-source' end,
        function(s) s.classes=copy(s.classes) end,
    }) do
        local s=state();s.classes.SHAMAN[0].shared.comparison={kind='custom',id='source',origins={step='old-step'}}
        local store=fixture(s);local original,expected=store:Get(address('class','SHAMAN'),ctx)
        original.body.name='Planned';local plan=assert(store:PlanReplace(address('class','SHAMAN'),original,ctx,expected))
        change(s);local before=copy(s);reason('stale-rotation-record',store:Commit(plan,ctx));assert(equal(before,s))
        reason('stale-rotation-record',store:PlanReplace(address('class','SHAMAN'),original,ctx,expected))
    end
end)
test('replace and delete use exact expected records and preserve unrelated changes',function()
    local store,s=fixture();local target=address('class','SHAMAN');local changed,token=store:Get(target,ctx)
    changed.body.name='Edited';reason('stale-rotation-record',store:PlanReplace(target,changed,ctx,{}))
    local other=fixture();local _,foreignToken=other:Get(target,ctx);reason('stale-rotation-record',store:PlanDelete(target,ctx,foreignToken))
    local plan=assert(store:PlanReplace(target,changed,ctx,token));s.classes.MAGE[0].shared.body.name='Unrelated'
    assert(store:Commit(plan,ctx));assert(s.classes.SHAMAN[0].shared.body.name=='Edited' and s.classes.MAGE[0].shared.body.name=='Unrelated')
    reason('stale-rotation-record',store:PlanDelete(target,ctx,token))
    local _,current=store:Get(target,ctx);plan=assert(store:PlanDelete(target,ctx,current));assert(store:Commit(plan,ctx))
    assert(not s.classes.SHAMAN[0].shared and s.characters[ctx.character].specs[0].shared.body.name=='Character')
end)
test('scope moves preserve full records and identity while collisions and changed destinations remain atomic',function()
    local s=state();s.classes.SHAMAN[0].move=record('Move')
    s.classes.SHAMAN[0].move.comparison={kind='custom',id='source',origins={step='old'}}
    local store=fixture(s);local source=address('class','SHAMAN','move');local target=address('character',ctx.character,'move')
    local value,token=store:Get(source,ctx);value.body.description='Draft description'
    local plan=assert(store:PlanMove(source,target,ctx,token,value));local before=copy(s)
    assert(equal(before,s));assert(store:Commit(plan,ctx))
    assert(not s.classes.SHAMAN[0].move and equal(s.characters[ctx.character].specs[0].move,value))
    assert(s.characters[ctx.character].specs[0].move.body.rotation[1].id=='step')
    local _,shared=store:Get(address('class','SHAMAN'),ctx)
    reason('rotation-id-collision',store:PlanMove(address('class','SHAMAN'),address('character',ctx.character),ctx,shared))
    local _,current=store:Get(target,ctx);plan=assert(store:PlanMove(target,source,ctx,current))
    s.classes.SHAMAN[0].move=record('Concurrent destination');before=copy(s)
    reason('rotation-id-collision',store:Commit(plan,ctx));assert(equal(before,s),'collision lost source or destination')
end)
test('canonical source sidecars retain exact contracts and reject destination class relabeling',function()
    local store,s,data,envelope=fixture();local pack=envelope();local catalog=assert(data.NewCatalog({newId=(function() local n=0;return function() n=n+1;return 'copy-'..n end end)()}))
    assert(catalog:RegisterBuiltin(pack));local id=assert(catalog:Clone({kind='builtin',id=pack.id},'Clone'))
    local view=catalog:Get({kind='custom',id=id});local manifest=copy(view.envelope);manifest.body=nil
    local full={body=copy(view.envelope.body),origin={manifest=manifest,lineage=copy(view.lineage)}}
    local target=address('class','SHAMAN',id);assert(store:Commit(assert(store:PlanCreate(target,full,ctx)),ctx))
    assert(equal(s.classes.SHAMAN[0][id],full))
    local wrong=copy(full);wrong.origin.lineage.sourceRevision=999
    local _,expected=store:Get(target,ctx);assert(not store:PlanReplace(target,wrong,ctx,expected))
    wrong=copy(full);wrong.imported={};assert(not store:PlanReplace(target,wrong,ctx,expected))
    local foreign=address('class','MAGE',id,'MAGE');reason('source-class-mismatch',store:PlanCreate(foreign,full,{class='MAGE',character='M - Realm'}))
end)
test('all-stored inventory includes foreign owners legacy bodies and orphan sidecars as detached records',function()
    local s=state();s.legacy={rotations={[0]={legacy=record('Unknown').body}},origins={[0]={orphan={future='retained'}}},evidence={profileName='SHAMAN'}}
    local store=fixture(s);local before=copy(s);local rows=assert(store:AllStored());assert(#rows==8)
    local legacy,orphan,mage=false,false,false
    for _,row in ipairs(rows) do
        if row.address.scope=='legacy' and row.address.id=='legacy' then legacy=true;row.record.body.name='Detached' end
        if row.address.scope=='legacy' and row.address.id=='orphan' then orphan=row.record.origin.future=='retained' end
        if row.address.class=='MAGE' then mage=true end
    end
    assert(legacy and orphan and mage and equal(before,s));assert(#store:ListVisible(0,ctx)==4)
end)
test('migration planning archives unknown data exactly and never infers ownership from names spells or provenance',function()
    local _,_,data,envelope=fixture();assert(data.PlanRotationStoreMigration)
    local pack=envelope();local legacy={rotations={[0]={Default=record('SHAMAN').body,unknown=false}},imports={[0]={orphan={manifest=pack}}},evidence={profileName='SHAMAN',realm='Realm'}}
    local before=copy(legacy);local proposed=assert(data.PlanRotationStoreMigration(legacy))
    assert(proposed.version==1 and next(proposed.classes)==nil and next(proposed.characters)==nil)
    assert(equal(proposed.legacy,legacy) and equal(before,legacy),'planner changed or claimed legacy records')
    proposed.legacy.rotations[0].Default.name='Detached';assert(legacy.rotations[0].Default.name=='SHAMAN')
end)
test('legacy adoption is explicit complete and rejects stale archived components without partial removal',function()
    local s=state();s.legacy={rotations={[0]={adopt=record('Unclaimed').body}},comparisons={[0]={adopt={kind='custom',id='source',origins={step='old'}}}},evidence={profileName='Mage'}}
    local store=fixture(s);local before=copy(s);local target=address('class','SHAMAN','adopt')
    local plan=assert(store:PlanLegacyAdoption({spec=0,id='adopt'},target,ctx));assert(equal(before,s))
    s.legacy.comparisons[0].adopt.id='changed';before=copy(s)
    reason('stale-rotation-record',store:Commit(plan,ctx));assert(equal(before,s))
    plan=assert(store:PlanLegacyAdoption({spec=0,id='adopt'},target,ctx));assert(store:Commit(plan,ctx))
    assert(s.classes.SHAMAN[0].adopt.body.name=='Unclaimed' and s.classes.SHAMAN[0].adopt.comparison.id=='changed')
    assert(s.legacy.rotations[0].adopt==nil and s.legacy.comparisons[0].adopt==nil and s.legacy.evidence.profileName=='Mage')
end)
test('portable incomplete bodies remain inspectable and repairable without hiding unrelated records',function()
    local s=state();s.classes.SHAMAN[0].shared.body.rotation=false
    local store,_,data=fixture(s);local target=address('class','SHAMAN')
    local value,expected,validation=store:Get(target,ctx);assert(not validation.valid and value.body.rotation==false)
    assert(#store:ListVisible(0,ctx)==4 and store:Get(address('character',ctx.character),ctx).body.name=='Character')
    local plan=assert(store:PlanReplace(target,record('Repaired'),ctx,expected));assert(store:Commit(plan,ctx))
    local strict=assert(data.NewRotationStore({state=s,fallbackID='Default',requireValidWrites=true}))
    local bad=record();bad.body.rotation=false
    reason('invalid-rotation-body',strict:PlanCreate(address('class','SHAMAN','incomplete'),bad,ctx))
    local loose=assert(store:PlanCreate(address('class','SHAMAN','incomplete'),bad,ctx));assert(store:Commit(loose,ctx))
    local _,_,invalid=store:Get(address('class','SHAMAN','incomplete'),ctx);assert(not invalid.valid)
end)
test('unknown character identity cannot select a Class fallback when a Character override might exist',function()
    local store=fixture()
    for _,context in ipairs({{class='SHAMAN'},{class='SHAMAN',character=false},{class='SHAMAN',character=''}}) do
        reason('missing-owner-context',store:GetFallback(0,context))
        assert(#store:ListVisible(0,context)==2,'known Class rows were hidden with unknown character')
    end
end)
test('conflicting character bucket classes cannot be read or targeted by a forged current-class address',function()
    local s=state();s.characters[ctx.character].class='MAGE';local store=fixture(s);local before=copy(s)
    local forged=address('character',ctx.character);local valid=address('character',ctx.character,nil,'MAGE')
    local _,expected=store:Get(valid,{class='MAGE',character=ctx.character})
    reason('foreign-owner',store:Get(forged,ctx))
    reason('foreign-owner',store:GetFallback(0,ctx));assert(#store:ListVisible(0,ctx)==2)
    reason('foreign-owner',store:PlanReplace(forged,record(),ctx,expected))
    reason('foreign-owner',store:PlanDelete(forged,ctx,expected))
    reason('foreign-owner',store:PlanMove(forged,address('class','SHAMAN'),ctx,expected))
    reason('foreign-owner',store:PlanCreate(address('character',ctx.character,'new'),record(),ctx))
    local _,token=store:Get(address('class','SHAMAN'),ctx)
    reason('foreign-owner',store:PlanMove(address('class','SHAMAN'),address('character',ctx.character,'shared'),ctx,token))
    s.legacy.rotations={[0]={adopt=record().body}}
    reason('foreign-owner',store:PlanLegacyAdoption({spec=0,id='adopt'},address('character',ctx.character,'adopt'),ctx))
    before.legacy.rotations=copy(s.legacy.rotations);assert(equal(before,s),'rejected owner conflict changed storage')
end)
test('commit rechecks both source and destination character class before any write',function()
    for _,operation in ipairs({'create','replace','delete','move-source','move-destination','adopt'}) do
        local store,s=fixture();local character=address('character',ctx.character);local class=address('class','SHAMAN');local plan
        if operation=='create' then plan=store:PlanCreate(address('character',ctx.character,'new'),record(),ctx)
        elseif operation=='replace' then local value,token=store:Get(character,ctx);plan=store:PlanReplace(character,value,ctx,token)
        elseif operation=='delete' then local _,token=store:Get(character,ctx);plan=store:PlanDelete(character,ctx,token)
        elseif operation=='move-source' then s.classes.SHAMAN[0].shared=nil;local _,token=store:Get(character,ctx);plan=store:PlanMove(character,class,ctx,token)
        elseif operation=='move-destination' then s.characters[ctx.character].specs[0].shared=nil;local _,token=store:Get(class,ctx);plan=store:PlanMove(class,character,ctx,token)
        else s.legacy.rotations={[0]={adopt=record().body}};plan=store:PlanLegacyAdoption({spec=0,id='adopt'},address('character',ctx.character,'adopt'),ctx) end
        assert(plan,operation);s.characters[ctx.character].class='MAGE';local before=copy(s)
        reason('foreign-owner',store:Commit(plan,ctx));assert(equal(before,s),operation..' changed conflicting owner bucket')
    end
end)
test('malformed source manifests and config return errors without indexing unsafe shapes',function()
    local store,_,data,envelope=fixture();local pack=envelope();pack.id='imported';pack.body=nil
    for _,change in ipairs({function(m) m.applicability=1 end,function(m) m.applicability=false end,function(m) m.applicability={} end}) do
        local manifest=copy(pack);change(manifest)
        local value=record();value.imported={manifest=manifest,sourceId='original',stepOrigins={}}
        reason('invalid-record',store:PlanCreate(address('class','SHAMAN','imported'),value,ctx))
    end
    assert(not data.NewRotationStore(true),'invalid constructor options were accepted')
    local s=state();local localized='Par défaut';s.classes.SHAMAN[0][localized]=s.classes.SHAMAN[0].Default;s.classes.SHAMAN[0].Default=nil
    s.characters[ctx.character].specs[0].Default=nil
    local other=assert(data.NewRotationStore({state=s,fallbackID=localized}));assert(other:GetFallback(0,ctx).address.id==localized)
end)
test('shared structural containers cannot let an owned write mutate another owner or legacy archive',function()
    local _,_,data=fixture()
    for _,change in ipairs({
        function(s) s.classes.MAGE[0]=s.classes.SHAMAN[0] end,
        function(s) s.characters[ctx.character].specs[0]=s.classes.SHAMAN[0] end,
        function(s) s.classes.SHAMAN[1]=s.classes.SHAMAN[0] end,
        function(s) s.classes.MAGE=s.classes.SHAMAN end,
        function(s) s.characters['B - Realm'].specs=s.characters[ctx.character].specs end,
        function(s) local root={};s.classes=root;s.characters=root end,
        function(s) s.legacy.rotations=s.classes.SHAMAN end,
        function(s) s.classes.MAGE[0].shared=s.classes.SHAMAN[0].shared end,
        function(s) s.characters={};s.classes.SHAMAN[0].shared.body.switch=s.characters end,
    }) do
        local s=state();change(s);local before=copy(s)
        assert(not data.NewRotationStore({state=s,fallbackID='Default'}),'aliased structural state was accepted')
        assert(equal(before,s),'alias rejection changed saved data')
    end
    local store,s=fixture();local value,token=store:Get(address('class','SHAMAN'),ctx)
    local plan=assert(store:PlanReplace(address('class','SHAMAN'),value,ctx,token))
    s.classes.MAGE[0]=s.classes.SHAMAN[0];local before=copy(s)
    assert(not store:Commit(plan,ctx));assert(equal(before,s),'post-plan structural alias changed both owners')
end)
test('repeated portable payload references remain legal and read snapshots cannot mutate saved bodies',function()
    local s=state();local shared={value='retained'};s.classes.SHAMAN[0].shared.body.switch={left=shared,right=shared}
    local store=fixture(s);local row=assert(store:Get(address('class','SHAMAN'),ctx));row.body.switch.left.value='Changed'
    assert(s.classes.SHAMAN[0].shared.body.switch.left.value=='retained' and s.classes.SHAMAN[0].shared.body.switch.right.value=='retained')
end)
test('portable limits apply independently to body and sidecar rather than whole record or profile',function()
    local s=state();s.classes.SHAMAN[0].large=record('Large')
    local large=s.classes.SHAMAN[0].large
    large.body.description=string.rep('x',200000)
    large.comparison={kind='custom',id='source',origins={}}
    for i=1,9985 do large.comparison.origins['step-'..i]='origin-'..i end
    local store,_,data=fixture(s)
    assert(data.CheckPortable(large.body) and data.CheckPortable(large.comparison))
    assert(not data.CheckPortable(large),'test needs aggregate record over current portable node budget')
    assert(store:Get(address('class','SHAMAN','large'),ctx).comparison.origins['step-9985']=='origin-9985')
    local input,expected=store:Get(address('class','SHAMAN','large'),ctx);input.body.name='Changed'
    assert(store:Commit(assert(store:PlanReplace(address('class','SHAMAN','large'),input,ctx,expected)),ctx))
end)
finish()
