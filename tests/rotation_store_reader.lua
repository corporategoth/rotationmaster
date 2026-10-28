-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local make=dofile('tests/fixtures/rotation_data.lua')
local ctx={class='SHAMAN',character='A - Realm'}
local function address(scope,owner,id,class)
    return {scope=scope or 'class',owner=owner or 'SHAMAN',class=class or 'SHAMAN',spec=0,id=id or 'shared'}
end
local function record(name)
    return {body={name=name or 'Mine',switch={},rotation={{id='step',type='spell',action=403,conditions={}}},cooldowns={}}}
end
local function state()
    return {version=1,classes={SHAMAN={[0]={Default=record('Class fallback'),shared=record('Class')}},MAGE={[0]={shared=record('Mage')}}},characters={
        ['A - Realm']={class='SHAMAN',specs={[0]={Default=record('Character fallback'),shared=record('Character')}}},
        ['B - Realm']={class='SHAMAN',specs={[0]={private=record('Other')}}}},legacy={}}
end
local function reason(want,value,why) assert(value==nil and why==want,tostring(why)..' instead of '..want) end
local function model()
    local data=make();local addon={RotationData=data}
    for _,path in ipairs({'Data/catalog.lua','Data/rotation_store.lua'}) do assert(loadfile(path))('rotationmaster',addon) end
    return data
end
local function fixture(s,extra)
    local data=model();local reader;local options={state=s or state(),fallbackID='Default',bindInternalReader=function(value) reader=value end}
    for key,value in pairs(extra or {}) do options[key]=value end
    local service=assert(data.NewRotationStore(options));assert(reader,'private reader was not bound')
    return service,reader,options.state,data
end
local function read(reader,a,c)
    local ok,name,seal=reader:Read(a or address(),c or ctx,function(value) return value.body.name end)
    assert(ok,name);return name,seal
end
local function create(service,a,c,name)
    return service:Commit(assert(service:PlanCreate(a,record(name),c)),c)
end

test('private reader binds once inactive and public store has no reader exposure or write-token authority',function()
    local data=model();local s=state();local captured,count= nil,0
    local service=assert(data.NewRotationStore({state=s,fallbackID='Default',bindInternalReader=function(value)
        captured=value;count=count+1;reason('rotation-reader-not-ready',value:ListOwned(0,ctx))
    end}));assert(count==1 and captured)
    assert(service.reader==nil and service.internalReader==nil and service.Read==nil and service.ListOwned==nil)
    local name,seal=read(captured);assert(name=='Class')
    reason('stale-rotation-record',service:PlanDelete(address(),ctx,seal))
    local snapshot,expected=assert(service:Get(address(),ctx));snapshot.body.name='detached'
    reason('invalid-rotation-read-seal',captured:IsCurrent(expected,ctx))
    assert(read(captured)=='Class' and service:PlanDelete(address(),ctx,expected))
end)
test('bad binder and invalid final state leave captured authority retired and return no service',function()
    local data=model();local captured,count
    reason('invalid-store-options',data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=false}))
    local s=state();s.version=99;count=0
    assert(not data.NewRotationStore({state=s,fallbackID='Default',bindInternalReader=function() count=count+1 end}));assert(count==0)
    reason('internal-reader-bind-failed',data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=function(reader) captured=reader;error('binder failed') end}))
    reason('retired-rotation-reader',captured:ListOwned(0,ctx))
    s=state();assert(not data.NewRotationStore({state=s,fallbackID='Default',bindInternalReader=function(reader) captured=reader;s.classes.SHAMAN[0].shared.body=function() end end}))
    reason('retired-rotation-reader',captured:ListOwned(0,ctx))
end)
test('record and listing seals are opaque issuer-bound and preserve stable managed identity',function()
    local _,reader=fixture();local _,other=fixture();local _,seal=read(reader)
    local _,again=read(reader);assert(again==seal and reader:IsCurrent(seal,ctx))
    local rows,list=assert(reader:ListOwned(0,ctx));assert(#rows==4 and reader:IsCurrent(list,ctx))
    local selected;for _,row in ipairs(rows) do if row.address.scope=='class' and row.address.id=='shared' then selected=row end end
    assert(selected and selected.seal==seal and selected.record==nil and selected.body==nil and selected.validation==nil)
    selected.address.class='MAGE';assert(reader:IsCurrent(seal,ctx),'detached address mutated authority')
    seal.address=address('class','MAGE','shared','MAGE');assert(reader:IsCurrent(seal,ctx),'seal public field changed its meaning')
    reason('invalid-rotation-read-seal',reader:IsCurrent({},ctx));reason('invalid-rotation-read-seal',other:IsCurrent(seal,ctx))
    reason('foreign-owner',reader:IsCurrent(seal,{class='MAGE',character='Mage - Realm'}))
end)
test('managed create replace delete and move retire exact seals while unrelated changes stay current',function()
    local service,reader=fixture();local _,classSeal=read(reader);local _,characterSeal=read(reader,address('character',ctx.character))
    local _,list=reader:ListOwned(0,ctx)
    assert(create(service,address('class','MAGE','new','MAGE'),{class='MAGE',character='Mage - Realm'},'Foreign'))
    assert(reader:IsCurrent(classSeal,ctx) and reader:IsCurrent(characterSeal,ctx) and reader:IsCurrent(list,ctx))
    local value,expected=service:Get(address(),ctx);value.body.name='Updated';assert(service:Commit(assert(service:PlanReplace(address(),value,ctx,expected)),ctx))
    reason('stale-rotation-read-seal',reader:IsCurrent(classSeal,ctx));assert(reader:IsCurrent(characterSeal,ctx))
    reason('stale-rotation-read-seal',reader:IsCurrent(list,ctx))
    local _,replacement=read(reader);assert(replacement~=classSeal)
    local _,token=service:Get(address(),ctx);assert(service:Commit(assert(service:PlanDelete(address(),ctx,token)),ctx))
    assert(create(service,address(),ctx,'Recreated'));local _,recreated=read(reader);assert(recreated~=replacement)
    reason('stale-rotation-read-seal',reader:IsCurrent(replacement,ctx))
    assert(create(service,address('class','SHAMAN','move'),ctx,'Move'))
    local _,moving=read(reader,address('class','SHAMAN','move'));local _,moveExpected=service:Get(address('class','SHAMAN','move'),ctx)
    assert(service:Commit(assert(service:PlanMove(address('class','SHAMAN','move'),address('character',ctx.character,'move'),ctx,moveExpected)),ctx))
    reason('stale-rotation-read-seal',reader:IsCurrent(moving,ctx));assert(read(reader,address('character',ctx.character,'move'))=='Move')
end)
test('Refresh succeeds atomically retires old epochs and failed writes or refresh preserve authority',function()
    local service,reader,s=fixture();local _,seal=read(reader);local _,list=reader:ListOwned(0,ctx)
    local original=s.classes.MAGE[0];s.classes.MAGE[0]=s.classes.SHAMAN[0]
    reason('aliased-store',service:Refresh());s.classes.MAGE[0]=original
    assert(reader:IsCurrent(seal,ctx) and reader:IsCurrent(list,ctx))
    local value,expected=service:Get(address(),ctx);local plan=assert(service:PlanReplace(address(),value,ctx,expected))
    value.body.name='outside';assert(reader:IsCurrent(seal,ctx),'detached snapshot changed state')
    s.classes.SHAMAN[0].raw=record('Raw')
    reason('stale-store-index',reader:ListOwned(0,ctx));assert(service:Refresh())
    reason('stale-rotation-read-seal',reader:IsCurrent(seal,ctx));reason('stale-rotation-read-seal',reader:IsCurrent(list,ctx))
    reason('invalid-plan',service:Commit(plan,ctx));assert(#reader:ListOwned(0,ctx)==5)
    assert(reader:Retire() and reader:Retire());reason('retired-rotation-reader',reader:IsCurrent(seal,ctx));reason('retired-rotation-reader',reader:ListOwned(0,ctx))
end)
test('external component root replacement stays stale after unrelated commit until explicit Refresh',function()
    local service,reader,s=fixture();local _,seal=read(reader)
    s.classes.SHAMAN[0].shared.body=record('External root').body
    reason('stale-rotation-read-seal',reader:IsCurrent(seal,ctx))
    reason('stale-store-index',reader:Read(address(),ctx,function() error('stale record reached projection') end))
    assert(create(service,address('class','MAGE','unrelated','MAGE'),{class='MAGE',character='Mage - Realm'},'Foreign'))
    reason('stale-rotation-read-seal',reader:IsCurrent(seal,ctx))
    reason('stale-store-index',reader:Read(address(),ctx,function() error('unrelated commit admitted stale body') end))
    assert(service:Get(address(),ctx).body.name=='External root','public fresh snapshot changed contract')
    assert(service:Refresh());assert(read(reader)=='External root')
end)
test('complete listing separates colliding owners and retains invalid Character fallback without payload snapshots',function()
    local s=state();s.characters[ctx.character].specs[0].Default.body={name='Repair me'}
    local _,reader=fixture(s);local rows=assert(reader:ListOwned(0,ctx));assert(#rows==4)
    local names={};for _,row in ipairs(rows) do names[#names+1]=row.address.scope..':'..row.address.id end
    assert(table.concat(names,',')=='character:Default,character:shared,class:Default,class:shared')
    assert(#reader:ListOwned(0,{class='SHAMAN'})==2)
    reason('missing-owner-context',reader:Read(address('character',ctx.character),{class='SHAMAN'},function() end))
    reason('foreign-owner',reader:Read(address('character','B - Realm','private'),ctx,function() end))
    s.classes.SHAMAN[0].later=record('Unindexed last');reason('stale-store-index',reader:ListOwned(0,ctx))
end)
test('callback errors false nil and same-reader reentrancy leave no busy state or partial result',function()
    local _,reader=fixture()
    local ok,value=reader:Read(address(),ctx,function() return false end);assert(ok and value==false)
    ok,value=reader:Read(address(),ctx,function() return nil end);assert(ok and value==nil)
    reason('rotation-read-callback-failed',reader:Read(address(),ctx,function() error('projection failed') end))
    ok,value=reader:Read(address(),ctx,function(record)
        reason('reentrant-rotation-read',reader:Read(address(),ctx,function() end))
        reason('reentrant-rotation-read',reader:ListOwned(0,ctx));return record.body.name
    end);assert(ok and value=='Class' and read(reader)=='Class')
end)
test('callback retirement refresh selected commit and context mutation discard staged results',function()
    for _,mode in ipairs({'retire','refresh','commit','context'}) do
        local service,reader=fixture();local context={class=ctx.class,character=ctx.character}
        local ok,why=reader:Read(address(),context,function()
            if mode=='retire' then reader:Retire()
            elseif mode=='refresh' then assert(service:Refresh())
            elseif mode=='commit' then local value,token=service:Get(address(),ctx);value.body.name='Changed';assert(service:Commit(assert(service:PlanReplace(address(),value,ctx,token)),ctx))
            else context.class='MAGE' end
            return 'must not publish'
        end)
        assert(ok==nil and why~='must not publish')
        if mode=='context' then assert(why=='rotation-read-context-changed') elseif mode=='retire' then assert(why=='retired-rotation-reader') else assert(why=='stale-rotation-read-seal') end
    end
    local service,reader=fixture();assert(reader:Read(address(),ctx,function(record)
        assert(create(service,address('class','MAGE','foreign','MAGE'),{class='MAGE',character='M - Realm'},'Foreign'));return record.body.name
    end))
end)
test('private Read rejects coroutine use and protected main-thread yield cannot suspend a borrow',function()
    local _,reader=fixture()
    local co=coroutine.create(function() reason('invalid-rotation-read-context',reader:Read(address(),ctx,function() error('coroutine projection ran') end)) end)
    assert(coroutine.resume(co) and coroutine.status(co)=='dead')
    reason('rotation-read-callback-failed',reader:Read(address(),ctx,function() coroutine.yield('borrow suspended') end))
    assert(read(reader)=='Class')
end)
test('managed warm reads and listing traverse no payload at100 and1000 foreign rows',function()
    for _,count in ipairs({100,1000}) do
        local s=state();for i=1,count do s.classes.MAGE[0]['foreign-'..i]=record('Foreign '..i) end
        local template,envelope=make();assert(loadfile('Data/catalog.lua'))('rotationmaster',{RotationData=template})
        local pack=envelope();pack.body.description=string.rep('large current and baseline ',500)
        local allocated=0;local catalog=assert(template.NewCatalog({newId=function() allocated=allocated+1;return allocated==1 and 'shared' or 'step-'..allocated end}));assert(catalog:RegisterBuiltin(pack))
        assert(catalog:Clone({kind='builtin',id=pack.id},'Clone'))
        local view=assert(catalog:Get({kind='custom',id='shared'}));local manifest=template.CopyData(view.envelope);manifest.body=nil
        s.classes.SHAMAN[0].shared={body=template.CopyData(view.envelope.body),origin={manifest=manifest,lineage=template.CopyData(view.lineage)}}
        local _,reader,_,data=fixture(s);local _,seal=read(reader)
        local counters={copy=0,portable=0,validate=0,catalog=0};local originals={CopyData=data.CopyData,CheckPortable=data.CheckPortable,ValidateBody=data.ValidateBody,NewCatalog=data.NewCatalog}
        for name,counter in pairs({CopyData='copy',CheckPortable='portable',ValidateBody='validate',NewCatalog='catalog'}) do local key=counter;local fn=originals[name];data[name]=function(...) counters[key]=counters[key]+1;return fn(...) end end
        for _=1,20 do assert(reader:IsCurrent(seal,ctx));assert(reader:Read(address(),ctx,function(value) return value.body.name end));assert(#reader:ListOwned(0,ctx)==4) end
        for name,value in pairs(counters) do assert(value==0,name..' traversed managed payload or copied addresses through deep copier') end
        for name,fn in pairs(originals) do data[name]=fn end
    end
end)
test('retirement during inactive binding cannot be reactivated by constructor publication',function()
    local data=model();local captured
    reason('retired-rotation-reader',data.NewRotationStore({state=state(),fallbackID='Default',bindInternalReader=function(reader) captured=reader;reader:Retire() end}))
    reason('retired-rotation-reader',captured:ListOwned(0,ctx))
end)
test('corrupt Character buckets cannot disappear into a partial Class-only private listing',function()
    local _,reader,s=fixture();s.characters[ctx.character]=false
    reason('invalid-store',reader:ListOwned(0,ctx))
end)
test('external structural and membership changes remain unadmitted across unrelated managed commits',function()
    local changes={
        function(s) s.classes={SHAMAN=s.classes.SHAMAN,MAGE=s.classes.MAGE} end,
        function(s) s.classes.SHAMAN={[0]=s.classes.SHAMAN[0]} end,
        function(s) local rows={};for id,value in pairs(s.classes.SHAMAN[0]) do rows[id]=value end;s.classes.SHAMAN[0]=rows end,
        function(s) s.classes.SHAMAN[0].shared=record('External record') end,
        function(s) s.characters[ctx.character]={class='SHAMAN',specs=s.characters[ctx.character].specs} end,
        function(s) s.characters[ctx.character].specs={[0]=s.characters[ctx.character].specs[0]} end,
        function(s) s.classes.SHAMAN[0].unindexed=record('Raw row') end,
    }
    for _,change in ipairs(changes) do
        local service,reader,s=fixture();change(s)
        reason('stale-store-index',reader:ListOwned(0,ctx))
        assert(create(service,address('class','MAGE','unrelated','MAGE'),{class='MAGE',character='Mage - Realm'},'Foreign'))
        reason('stale-store-index',reader:ListOwned(0,ctx))
        assert(service:Refresh());assert(#reader:ListOwned(0,ctx)>=4)
    end
end)
test('all four component-root seals remain stale through unrelated commits until Refresh',function()
    for _,component in ipairs({'body','origin','imported','comparison'}) do
        local data,envelope=make();assert(loadfile('Data/catalog.lua'))('rotationmaster',{RotationData=data})
        local pack=envelope();local allocated=0
        local catalog=assert(data.NewCatalog({newId=function() allocated=allocated+1;return allocated==1 and 'shared' or 'copy-step-'..allocated end}))
        assert(catalog:RegisterBuiltin(pack));assert(catalog:Clone({kind='builtin',id=pack.id},'Clone'))
        local view=catalog:Get({kind='custom',id='shared'});local manifest=data.CopyData(view.envelope);manifest.body=nil
        local full={body=data.CopyData(view.envelope.body)}
        if component=='origin' then full.origin={manifest=manifest,lineage=data.CopyData(view.lineage)}
        elseif component=='imported' then full.imported={manifest=manifest,sourceId=pack.id,sourceRevision=1,stepOrigins=data.CopyData(view.lineage.stepOrigins)}
        elseif component=='comparison' then full.comparison={kind='builtin',id=pack.id,origins=data.CopyData(view.lineage.stepOrigins)} end
        local s=state();s.classes.SHAMAN[0].shared=full;local service,reader=fixture(s);local _,seal=read(reader)
        full[component]=data.CopyData(full[component])
        reason('stale-store-index',reader:Read(address(),ctx,function() error('changed component reached projector') end))
        assert(create(service,address('class','MAGE','unrelated','MAGE'),{class='MAGE',character='Mage - Realm'},'Foreign'))
        reason('stale-rotation-read-seal',reader:IsCurrent(seal,ctx))
        reason('stale-store-index',reader:Read(address(),ctx,function() error('component swap was admitted') end))
        assert(service:Refresh());assert(read(reader)=='Clone')
    end
end)
test('optional private Character context is bounded text rather than an arbitrary cache key',function()
    local _,reader=fixture();local _,seal=read(reader)
    for _,character in ipairs({0/0,42,true,{},'',string.rep('x',513)}) do
        local context={class='SHAMAN',character=character}
        reason('missing-owner-context',reader:Read(address(),context,function() error('invalid context reached projection') end))
        reason('missing-owner-context',reader:ListOwned(0,context))
        reason('missing-owner-context',reader:IsCurrent(seal,context))
    end
    assert(reader:Read(address(),{class='SHAMAN'},function(value) return value.body.name end))
end)
test('selected nested changes remain public snapshots and do not falsely claim private managed invalidation',function()
    local service,reader,s=fixture();local _,seal=read(reader)
    s.classes.SHAMAN[0].shared.body.name='Nested external edit'
    assert(service:Get(address(),ctx).body.name=='Nested external edit')
    assert(reader:IsCurrent(seal,ctx),'private identity seals must not pretend to detect arbitrary nested writes')
    assert(service:Refresh());reason('stale-rotation-read-seal',reader:IsCurrent(seal,ctx))
    assert(read(reader)=='Nested external edit')
end)
finish()
