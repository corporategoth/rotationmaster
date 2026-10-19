local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'TALENT','TALENT_TREE_POINTS','PRIMARY_TALENT_TREE'}
local ids={isin='builtin:utils.lua:isin',compare='builtin:utils.lua:compare',compareString='builtin:utils.lua:compareString',nullable='builtin:utils.lua:nullable'}
local helperHashes={integer='e1bd3b0e',treeShape='f0ba2bf9',legacySlot='b8bfb514',group='d6f4e415',info='c0972f2d',treeExists='85703f5a',treeName='19de3afd'}
local function fixture(...)
    local f=F.new(...);local a,e=f.addon,f.env
    local state={rank=2,selected=true,points={5,20,0},calls=0,treeCalls=0,mode='normal',opaque={}}
    e.canaccessvalue=function(value) return not rawequal(value,state.opaque) end
    e.GetNumTalentTabs=function() return 3 end;e.GetNumTalents=function() return 2 end
    e.C_SpecializationInfo={GetSpecializationInfo=function(tree)
        state.treeCalls=state.treeCalls+1
        if state.mode=='failed' then error('talent metadata failed') end
        if state.mode=='missing' then return end
        local points=state.mode=='restricted' and state.opaque or state.mode=='malformed' and -1 or state.points[tree]
        return tree,'Tree '..tree,'Description',1,nil,nil,points
    end,GetTalentInfo=function()
        state.calls=state.calls+1
        if state.mode=='failed' then error('talent observation failed') end
        if state.mode=='missing' then return end
        local rank=state.mode=='restricted' and state.opaque or state.mode=='malformed' and -1 or state.rank
        return {name='Convection',icon=1,rank=rank,maxRank=5,talentID=101,spellID=108269,
            tier=1,column=2,selected=state.selected,available=true,known=true,grantedByAura=false,
            previewRank=0,meetsPrereq=true,meetsPreviewPrereq=true,isExceptional=false,hasGoldBorder=false,isPVPTalentUnlocked=false}
    end}
    for _,path in ipairs({'Platform/talents.lua','Core/conditions.lua','Conditions/common.lua','Conditions/talent.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state
end
local function registerCopies(a)
    local copies={}
    for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag));local copy,why=a:CompileCustomCondition('COPY_'..tag,source)
        assert(copy,tag..': '..tostring(why and why.reason));a:RegisterCondition('COPY_'..tag,copy);copies[tag]=copy
    end
    return copies
end
local function node(a,value,tag)
    local result=a:CopySettingsData(value);result.type=tag;return result
end
local function sameOutcome(a,tag,value)
    local original=node(a,value,tag);local copy=node(a,value,'COPY_'..tag)
    assert(a.conditionDefinitions[tag].valid(0,original)==a.conditionDefinitions['COPY_'..tag].valid(0,copy),tag..' validator differs')
    for _,negated in ipairs({false,true}) do
        local left=a:evaluateConditionResult(negated and {type='NOT',value=original} or original)
        local right=a:evaluateConditionResult(negated and {type='NOT',value=copy} or copy)
        assert(left.status==right.status and left.reason==right.reason,tag..' observation or NOT availability differs')
        assert(a:printCondition(negated and {type='NOT',value=original} or original,0)==a:printCondition(negated and {type='NOT',value=copy} or copy,0),tag..' summary differs')
    end
end
test('talent authored callbacks expose four canonical leaves and preserve local helper identities',function()
    local f,a=fixture();local declared=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/talent.lua'],'talent qualified dependencies missing')
    local count=0;for _ in pairs(declared) do count=count+1 end;assert(count==4,'talent namespace contains extra dependencies')
    for _,tag in ipairs({'TALENT','TALENT_TREE_POINTS'}) do
        local source=assert(a:GetBuiltinConditionSource(tag))
        for _,callback in ipairs({'valid','evaluate','print'}) do assert(not source[callback]:find('addon.isin',1,true) and not source[callback]:find('addon.compare',1,true) and not source[callback]:find('addon.nullable',1,true),'authored callback retains a legacy pure call') end
        assert(source.valid:find('Functions.values.isin',1,true) and source.evaluate:find('Functions.values.compare',1,true))
        assert(source.print:find('Functions.presentation.compareString',1,true) and source.print:find('Functions.presentation.nullable',1,true))
        for _,name in ipairs({'isin','compare','compareString','nullable'}) do
            local alias='Functions.'..((name=='isin' or name=='compare') and 'values.' or 'presentation.')..name
            assert(declared[alias]==ids[name] and source.bindings[alias]==ids[name],'canonical helper identity changed')
        end
        assert(not source.bindings.Functions,'namespace was captured as an opaque table')
    end
    for name,hash in pairs(helperHashes) do
        local id='builtin:Conditions/talent.lua:'..name;local record=assert(a.builtinFunctions[id])
        assert(a:FunctionSourceHash(record.source)==hash,'native/local helper changed: '..name)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/talent.lua'](name),'local helper getter identity changed')
    end
    assert(a:ResolveFunctionBinding('builtin:Conditions/talent.lua:AceGUI')==f.libraries['AceGUI-3.0'],'historical widget capture disappeared')
    assert(not f.env.Functions and not f.env.functions,'namespace leaked into globals')
end)
test('extracted talent clones retain layouts validators and summaries across the reviewed client inventory',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local _,a=fixture(unpack(case[1]));registerCopies(a)
        for _,value in ipairs({{tree=1,talent=1,operator='EQUALS',value=2},{tree=1,talent=1,operator='EQUALS',value=0},{layout='grid',value=3},{value=3},
            {tree=1.5,talent=1,operator='EQUALS',value=2},{tree=1,talent=-1,operator='EQUALS',value=2},{tree=1,talent=1,operator='TYPO',value=2},{layout='future',value=3}}) do sameOutcome(a,'TALENT',value) end
        for _,value in ipairs({{tree=2,operator='GREATERTHAN',value=10},{tree=3,operator='EQUALS',value=0},{tree=16,operator='EQUALS',value=0},{tree=2,operator='TYPO',value=10},{tree=2,operator='EQUALS',value=math.huge}}) do sameOutcome(a,'TALENT_TREE_POINTS',value) end
        for _,value in ipairs({{tree=1},{tree=2},{tree=16},{tree=1.5}}) do sameOutcome(a,'PRIMARY_TALENT_TREE',value) end
    end
end)
test('registered talent clones preserve explicit wording and keep failed observations unavailable under NOT',function()
    local _,a,state=fixture();registerCopies(a)
    local rank={tree=1,talent=1,operator='EQUALS',value=2};local points={tree=2,operator='GREATERTHAN',value=10}
    local summaries={TALENT='talent points in Convection (Tree 1) is equal to 2',TALENT_TREE_POINTS='points spent in Tree 2 is greater than 10',PRIMARY_TALENT_TREE='your primary talent tree is Tree 2'}
    for tag,value in pairs({TALENT=rank,TALENT_TREE_POINTS=points,PRIMARY_TALENT_TREE={tree=2}}) do
        assert(a:printCondition(node(a,value,tag),0)==summaries[tag],'baseline wording changed: '..tag)
        sameOutcome(a,tag,value)
        for _,mode in ipairs({'failed','missing','restricted','malformed'}) do
            state.mode=mode;sameOutcome(a,tag,value)
            assert(a:evaluateConditionResult({type='NOT',value=node(a,value,'COPY_'..tag)}).status=='unavailable',tag..' unknown observation became a match')
        end
        state.mode='normal'
    end
    state.points={20,20,0};sameOutcome(a,'PRIMARY_TALENT_TREE',{tree=2})
    assert(a:evaluateConditionResult({type='NOT',value={type='COPY_PRIMARY_TALENT_TREE',tree=2}}).status=='unavailable')
    state.points={0,0,0};sameOutcome(a,'PRIMARY_TALENT_TREE',{tree=2});sameOutcome(a,'TALENT_TREE_POINTS',{tree=2,operator='EQUALS',value=0})
    assert(a:evaluateCondition({type='COPY_TALENT_TREE_POINTS',tree=2,operator='EQUALS',value=0}),'observed zero points became unavailable')
end)
test('native talent observations remain shared per pass and refresh across respecs alongside cloned consumers',function()
    local _,a,state=fixture();registerCopies(a)
    local value={tree=1,talent=1,operator='EQUALS',value=2};state.calls=0
    assert(a:evaluateCondition({type='AND',value={node(a,value,'TALENT'),node(a,value,'COPY_TALENT')}}) and state.calls==1,'rank clone split the raw observation cache')
    state.rank=0;assert(a:evaluateConditionResult(node(a,value,'TALENT')).status=='no-match' and a:evaluateConditionResult(node(a,value,'COPY_TALENT')).status=='no-match','next pass hid a respec')
    value={tree=2,operator='GREATERTHAN',value=10};state.treeCalls=0
    assert(a:evaluateCondition({type='AND',value={node(a,value,'TALENT_TREE_POINTS'),node(a,value,'COPY_TALENT_TREE_POINTS')}}) and state.treeCalls==1,'tree-point clone split the raw observation cache')
    state.points[2]=0;assert(a:evaluateConditionResult(node(a,value,'TALENT_TREE_POINTS')).status=='no-match' and a:evaluateConditionResult(node(a,value,'COPY_TALENT_TREE_POINTS')).status=='no-match','next pass hid changed tree points')
end)
test('arbitrary saved source keeps original addon helper APIs and stable bindings',function()
    local _,a=fixture()
    for name,id in pairs(ids) do
        local group=(name=='isin' or name=='compare') and a.Functions.values or a.Functions.presentation
        assert(a[name]==group[name] and a.builtinSourceModules['utils.lua'](name)==group[name] and a:ResolveFunctionBinding(id)==group[name])
    end
    local source={description='Legacy talent consumer',args={},returns={},bindings={},code='return addon.isin({flag=false},"flag"),addon.compare("EQUALS",false,false),addon.nullable(false),addon.compareString("EQUALS","left","right")'}
    assert(a:InstallCustomFunction('LEGACY_TALENT_HELPERS',source));local fn=assert(a:ResolveFunctionBinding('LEGACY_TALENT_HELPERS'))
    local present,equal,boolean,summary=fn();assert(present and equal and boolean==false and summary==a.Functions.presentation.compareString('EQUALS','left','right'))
end)
finish()
