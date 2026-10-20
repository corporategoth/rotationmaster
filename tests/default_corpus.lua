local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local corpus=dofile('tests/fixtures/default_corpus.lua')
local clients={{'retail',1,12},{'era',2,0},{'progression',19,4},{'tbc',5,1},{'forever',18,12}}
local classes={'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID','DEATHKNIGHT','MONK','DEMONHUNTER','EVOKER'}
local visited,runnable={},{}
local function matches(scope,family,class)
    return corpus.contains(scope.families,family) and (not scope.class or scope.class==class)
end
local function samples(packs,family,class)
    local result,seen={},{}
    for _,pack in ipairs(packs) do
        local scope=pack.applicability;local applicable=matches(scope,family,class)
        local levels={1,19,20,60,70,90,100};local specs={0,1};local builds={70006}
        if applicable then
            for _,key in ipairs({'minLevel','maxLevel'}) do if scope[key] then levels[#levels+1]=scope[key];if scope[key]>1 then levels[#levels+1]=scope[key]-1 end;levels[#levels+1]=scope[key]+1 end end
            local largest=0;for _,spec in ipairs(scope.specs or {}) do specs[#specs+1]=spec;largest=math.max(largest,spec) end;specs[#specs+1]=largest+1
            for _,key in ipairs({'minBuild','maxBuild'}) do if scope[key] then builds[#builds+1]=scope[key];if scope[key]>1 then builds[#builds+1]=scope[key]-1 end;builds[#builds+1]=scope[key]+1 end end
        end
        for _,level in ipairs(levels) do for _,spec in ipairs(specs) do for _,context in ipairs({'player','vehicle','petbattle'}) do for _,build in ipairs(builds) do
            local key=table.concat({level,spec,context,build},':')
            if not seen[key] then seen[key]=true;result[#result+1]={level=level,spec=spec,context=context,build=build} end
        end end end end
    end
    return result
end
for _,client in ipairs(clients) do for _,class in ipairs(classes) do
    test('all shipped defaults load and retain safe scope on '..client[1]..'/'..class,function()
        local f,packs,state=corpus.load(client[2],client[3],class);local a=f.addon;local witnesses={}
        assert(#packs>0,'no default packs loaded')
        local visibleCount=0
        for _,pack in ipairs(packs) do
            corpus.check(f,pack,false)
            if not pack.applicability.class or pack.applicability.class==class then visibleCount=visibleCount+1 end
            if matches(pack.applicability,client[1],class) then corpus.check(f,pack,true);visited[pack.id]=true end
        end
        for _,sample in ipairs(samples(packs,client[1],class)) do
            state.level,state.context,state.build=sample.level,sample.context,sample.build
            local rows=a:ListDefaultRotations(sample.spec);assert(#rows==visibleCount,'default list did not enforce declared class')
            local runtime=a:GetRuntimeRotations(sample.spec)
            for _,row in ipairs(rows) do
                assert(row.readOnly and row.builtin)
                assert(not row.applicability.class or row.applicability.class==class,'foreign default remained visible')
                assert((runtime[row.runtimeKey]~=nil)==row.eligible,'runtime and catalog eligibility differ')
                if row.eligible then
                    runnable[row.id]=true;witnesses[row.id]=sample
                    local scope=row.applicability
                    assert(matches(scope,client[1],class))
                    assert(not scope.specs or corpus.contains(scope.specs,sample.spec))
                    assert(scope.actionContext==sample.context and (not scope.minLevel or sample.level>=scope.minLevel) and (not scope.maxLevel or sample.level<=scope.maxLevel))
                    assert((not scope.minBuild or sample.build>=scope.minBuild) and (not scope.maxBuild or sample.build<=scope.maxBuild))
                    assert(client[1]~='retail' and client[1]~='forever' and not scope.roles and not scope.intent and not scope.rulesets)
                end
            end
        end
        for _,pack in ipairs(packs) do
            local witness=witnesses[pack.id];local spec=witness and witness.spec or 0
            if witness then state.level,state.context,state.build=witness.level,witness.context,witness.build end
            assert(a:SetDefaultRotationEnabled(pack.id,false));assert(#a:ListDefaultRotations(spec)==visibleCount)
            local view=a:GetDefaultRotation(pack.id);assert(view.readOnly and not view.enabled)
            local key;for _,row in ipairs(a:ListDefaultRotations(spec)) do if row.id==pack.id then key=row.runtimeKey end end
            assert(not a:GetRuntimeRotations(spec)[key],'disabled default remained runnable')
            view.envelope.body.disabled=not pack.body.disabled
            assert(a:GetDefaultRotation(pack.id).envelope.body.disabled==pack.body.disabled,'source snapshot mutated the packaged body')
            assert(a:SetDefaultRotationEnabled(pack.id,true))
            if witness then assert(a:GetRuntimeRotations(spec)[key],'enabled default failed to resume in its eligible context') end
        end
    end)
end end
test('TOC includes every reviewed starter pack exactly once',function()
    local _,packs=corpus.load(5,1,'PRIEST');local wanted={['rm.tbc.shaman.starter']=true,['rm.tbc.shaman.enhancement.30-39']=true,['rm.tbc.mage.starter']=true,['rm.tbc.mage.starter.30-39']=true,['rm.tbc.warlock.starter']=true,['rm.tbc.warlock.starter.30-39']=true,['rm.tbc.priest.starter']=true,['rm.tbc.priest.starter.20-29']=true,['rm.tbc.priest.shadow.30-39']=true,['rm.tbc.warrior.starter']=true,['rm.tbc.warrior.starter.20-29']=true,['rm.tbc.paladin.starter']=true,['rm.tbc.paladin.starter.20-29']=true,['rm.tbc.hunter.starter']=true,['rm.tbc.hunter.starter.20-29']=true,['rm.tbc.druid.caster.starter']=true,['rm.tbc.druid.caster.starter.20-29']=true,['rm.tbc.rogue.starter']=true,['rm.tbc.rogue.starter.20-29']=true}
    for _,pack in ipairs(packs)do assert(wanted[pack.id],pack.id..' is unexpected or duplicated');wanted[pack.id]=nil end
    assert(not next(wanted),'reviewed starter pack missing from TOC')
end)
test('every shipped pack has a matching family and class schema fixture',function()
    local _,packs=corpus.load(5,1,'SHAMAN');for _,pack in ipairs(packs) do
        assert(visited[pack.id],pack.id..' has no matching schema fixture')
        local scope=pack.applicability
        if not scope.roles and not scope.intent and not scope.rulesets and not pack.body.disabled
            and (corpus.contains(scope.families,'tbc') or corpus.contains(scope.families,'era') or corpus.contains(scope.families,'progression')) then
            assert(runnable[pack.id],pack.id..' never became eligible in its sampled supported context')
        end
    end
end)
test('corpus gate rejects untranslated unsourced malformed and incomplete nested authoring data',function()
    local _,initial=corpus.load(5,1,'SHAMAN');local target=initial[1];local client
    for _,candidate in ipairs(clients) do if candidate[1]==target.applicability.families[1] then client=candidate;break end end
    assert(client,'mutation baseline has an unknown family')
    local f,packs=corpus.load(client[2],client[3],target.applicability.class or 'SHAMAN');local a=f.addon;local baseline
    for _,pack in ipairs(packs) do if pack.id==target.id then baseline=pack;break end end
    assert(corpus.check(f,baseline,true),'pristine mutation baseline must pass')
    for _,mutate in ipairs({
        function(p) p.nameKey='Missing.default.name' end,
        function(p) p.descriptionKey='Missing.default.description' end,
        function(p) p.sources={} end,
        function(p) p.sources[1].reviewedAt='2026-99-99' end,
        function(p) p.sources[1].url='https:///' end,
        function(p) p.sources[1].url='https://localhost/source' end,
        function(p) p.sources[1].url='https://127.0.0.1/source' end,
        function(p) p.body.rotation={{id='corpus-probe',type='none',conditions={type='UNKNOWN_BUILTIN_CONDITION'}}} end,
        function(p) p.body.rotation={{id='corpus-probe',type='none',conditions={type='COMBAT'}}} end,
        function(p) p.body.rotation={{id='branch',type='branch',conditions={},onTrue={{type='none'}},onFalse={}}} end,
    }) do
        local candidate=assert(a.RotationData.CopyData(baseline));mutate(candidate)
        assert(not pcall(corpus.check,f,candidate,true),'invalid shipped manifest escaped the corpus gate')
    end
end)
finish()
