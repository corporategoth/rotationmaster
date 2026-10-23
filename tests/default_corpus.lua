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
    local _,packs=corpus.load(5,1,'PRIEST');local wanted={}
    for _,id in ipairs({'rm.tbc.mage.frost','rm.tbc.mage.fire.icyveins','rm.tbc.mage.fire.wowhead','rm.tbc.mage.arcane','rm.tbc.warlock.dps.icyveins','rm.tbc.warlock.dps.wowhead','rm.tbc.priest.dps.icyveins','rm.tbc.priest.dps.wowhead','rm.tbc.priest.healer.wowhead','rm.tbc.priest.healer.icyveins'}) do wanted[id]=true end
    -- TBC Warrior, Rogue and Hunter premades (one per role and source family).
    for _,id in ipairs({'rm.tbc.warrior.dps.wowsims','rm.tbc.warrior.dps.icyveins','rm.tbc.warrior.protection.wowhead','rm.tbc.warrior.protection.icyveins',
        'rm.tbc.rogue.dps.wowsims','rm.tbc.rogue.dps.wowhead','rm.tbc.hunter.ranged.wowsims','rm.tbc.hunter.ranged.wowhead'})do wanted[id]=true end
    -- TBC Shaman, Druid and Paladin premades (one per role and source family).
    for _,id in ipairs({'rm.tbc.shaman.enhancement.icyveins','rm.tbc.shaman.enhancement.wowsims','rm.tbc.shaman.elemental.icyveins','rm.tbc.shaman.elemental.wowhead','rm.tbc.shaman.elemental.nextaction','rm.tbc.shaman.restoration','rm.tbc.druid.balance','rm.tbc.druid.feral.icyveins','rm.tbc.druid.feral.wowhead','rm.tbc.druid.restoration','rm.tbc.paladin.retribution.wowhead','rm.tbc.paladin.retribution.icyveins','rm.tbc.paladin.retribution.twist','rm.tbc.paladin.protection.wowhead','rm.tbc.paladin.protection.icyveins','rm.tbc.paladin.holy','rm.tbc.paladin.holy.wowhead'})do wanted[id]=true end
    -- WoW Forever Rogue, Shaman, Warlock and Warrior premades (one per role and source family).
    for _,id in ipairs({'rm.forever.rogue.dps','rm.forever.rogue.subtlety.warcrafttavern','rm.forever.rogue.subtlety.wowhead',
        'rm.forever.shaman.restoration','rm.forever.shaman.elemental','rm.forever.shaman.enhancement','rm.forever.shaman.enhancement.wowhead',
        'rm.forever.warlock.dps','rm.forever.warlock.dps.icyveins','rm.forever.warlock.dps.wowhead',
        'rm.forever.warrior.protection','rm.forever.warrior.protection.warcrafttavern','rm.forever.warrior.dps','rm.forever.warrior.dps.warcrafttavern'})do wanted[id]=true end
    -- WoW Forever Druid, Hunter, Mage, Paladin and Priest premades.
    for _,id in ipairs({'rm.forever.druid.balance','rm.forever.druid.balance.tavern','rm.forever.druid.feral','rm.forever.druid.restoration','rm.forever.druid.restoration.icyveins','rm.forever.hunter.ranged','rm.forever.hunter.ranged.mobalytics','rm.forever.hunter.survival','rm.forever.hunter.survival.weave','rm.forever.mage.frost','rm.forever.mage.fire','rm.forever.mage.fire.icyveins','rm.forever.mage.arcane','rm.forever.paladin.retribution','rm.forever.paladin.protection','rm.forever.paladin.protection.icyveins','rm.forever.paladin.holy','rm.forever.paladin.holy.wowhead','rm.forever.priest.dps','rm.forever.priest.dps.mobalytics','rm.forever.priest.healer'})do wanted[id]=true end
    -- Retail Death Knight, Demon Hunter, Druid, Evoker, Hunter, Mage and Monk premades (per specialization).
    for _,id in ipairs({'rm.retail.deathknight.blood','rm.retail.deathknight.blood.guide','rm.retail.deathknight.blood.simc','rm.retail.deathknight.frost','rm.retail.deathknight.frost.guide','rm.retail.deathknight.frost.wowhead','rm.retail.deathknight.unholy','rm.retail.deathknight.unholy.guide','rm.retail.deathknight.unholy.simc',
        'rm.retail.demonhunter.havoc','rm.retail.demonhunter.havoc.guide','rm.retail.demonhunter.vengeance','rm.retail.demonhunter.vengeance.guide','rm.retail.demonhunter.vengeance.simc','rm.retail.demonhunter.devourer','rm.retail.demonhunter.devourer.guide','rm.retail.demonhunter.devourer.simc',
        'rm.retail.druid.balance','rm.retail.druid.balance.guide','rm.retail.druid.feral','rm.retail.druid.feral.guide','rm.retail.druid.guardian','rm.retail.druid.guardian.guide','rm.retail.druid.guardian.simc','rm.retail.druid.restoration',
        'rm.retail.evoker.devastation','rm.retail.evoker.devastation.guide','rm.retail.evoker.augmentation','rm.retail.evoker.augmentation.assisted','rm.retail.evoker.preservation',
        'rm.retail.hunter.beastmastery','rm.retail.hunter.beastmastery.guide','rm.retail.hunter.marksmanship','rm.retail.hunter.marksmanship.guide','rm.retail.hunter.survival','rm.retail.hunter.survival.guide',
        'rm.retail.mage.arcane','rm.retail.mage.arcane.guide','rm.retail.mage.fire','rm.retail.mage.fire.guide','rm.retail.mage.frost','rm.retail.mage.frost.guide',
        'rm.retail.monk.brewmaster','rm.retail.monk.brewmaster.guide','rm.retail.monk.windwalker','rm.retail.monk.windwalker.guide','rm.retail.monk.mistweaver'})do wanted[id]=true end
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
