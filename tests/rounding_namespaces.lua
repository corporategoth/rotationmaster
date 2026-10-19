local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inventory=dofile('tests/fixtures/catalog_inventory.lua').branches
local restore=dofile('tests/fixtures/restore_rounding_qualifiers.lua')
local modules={SPELL_COOLDOWN='spell',PETSPELL_COOLDOWN='petspell',ANYSPELL_COOLDOWN='anyspell',RUNE_COOLDOWN='stats',TOTEM_REMAIN='totem'}
local moduleHashes={spell='cb4b90f9',petspell='a2ea9040',anyspell='af801d0d',stats='d96430e7',totem='2384c0a0'}
local privateHashes={spell={color='906341b8',helpers='769a506e'},petspell={color='fedaa3e7',helpers='60920b9d'},anyspell={color='f35f4765',helpers='47f6d2db',SpellData='bd968be4'},stats={color='89107d36',helpers='c19dbbac'},totem={observe='e59e23eb',remaining='b96f5341',element='5fbfedcc',amount='3bd67a6b',specific='fdeca8ba',findSpecific='f753db9d',platform='c9ee8d33',color='b1a3d66a',helpers='f15cbb60'}}
local function fixture(case,modern)
    local f=F.new(unpack(case[1]));local a,e=f.addon,f.env
    local s={now=100,start=98,duration=3.2346,enabled=true,known=true,active=true,calls={},rounds={},runes={[1]={98,3.2346},[2]={99,5}}}
    local function call(name,...) s.calls[name]=(s.calls[name] or 0)+1;if s.throw==name then error('native '..name..' failed') end end
    e.GetTime=function() return s.now end
    local function info(id) return {name='Fixture spell',spellID=5019,iconID=1,subtext='Rank 1'} end
    local function cooldown(...) assert(select('#',...)==1 and (...)==5019);call('cooldown',...);return s.start,s.duration,s.enabled end
    if modern then e.C_Spell={GetSpellInfo=info,GetSpellCooldown=function(...) local start,duration,enabled=cooldown(...);return {startTime=start,duration=duration,isEnabled=enabled,modRate=1} end}
    else e.C_Spell=nil;e.GetSpellInfo=function(id) local r=info(id);return r.name,r.subtext,r.iconID,0,0,30,r.spellID end;e.GetSpellCooldown=function(...) local start,duration,enabled=cooldown(...);return start,duration,enabled and 1 or 0 end end
    e.IsSpellKnown=function(...) assert(select('#',...)==2 and select(1,...)==5019 and select(2,...)==true);call('known',...);return s.known end
    e.GetRuneType=function(...) assert(select('#',...)==1);local index=...;assert(index>=1 and index<=6);call('runetype',...);return index<=2 and 1 or 2 end
    e.GetRuneCooldown=function(...) assert(select('#',...)==1);local index=...;call('rune',...);return s.runes[index][1],s.runes[index][2],false end
    e.GetTotemInfo=function(...) assert(select('#',...)==1 and (...)==2);call('totem',...);return s.active,'Fixture totem',s.start,s.duration,1,1,5019 end
    for _,path in ipairs({'Platform/spells.lua','Platform/totems.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/petspell.lua','Conditions/anyspell.lua','Conditions/stats.lua','Conditions/totem.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,s
end
local function node(tag,amount) return {type=tag,spell=tag=='TOTEM_REMAIN' and 2 or 5019,rune=1,ranked=true,operator='EQUALS',value=amount or 1.235} end
local function observeRounding(a,s)
    local round=a.Functions.values.round
    a.Functions.values.round=function(...) assert(select('#',...)==2,'round gained receiver/argument');local n,places=...;assert(places==3);s.rounds[#s.rounds+1]=n;return round(n,places) end
    a.round=function() error('retired addon.round used by selected callback') end
end
local function selectedCallCount(tag,s) return s.calls[tag=='TOTEM_REMAIN' and 'totem' or tag=='RUNE_COOLDOWN' and 'rune' or 'cooldown'] or 0 end
for tag in pairs(modules) do
    test(tag..' resolves live canonical rounding with unchanged native tuples time and cache behavior',function()
        local seen=0
        for _,case in ipairs(inventory) do for _,modern in ipairs({false,true}) do local _,a,s=fixture(case,modern);local definition=a.conditionDefinitions[tag]
            if definition then seen=seen+1;local v=node(tag);assert(definition.valid(0,v),'fixture must pass actual validator');observeRounding(a,s)
                assert(a:evaluateConditionResult(v).status=='match',tag..' positive engine control failed')
                s.calls={};s.rounds={};local cache={};assert(definition.evaluate(v,cache,100)==true)
                local before=selectedCallCount(tag,s);s.now=101;local changed=node(tag,.235);assert(definition.evaluate(changed,cache,101)==true)
                assert(selectedCallCount(tag,s)==before,'same cache repeated native observation')
                assert(before==(tag=='RUNE_COOLDOWN' and 2 or 1))
                local rounds=#s.rounds;a.Functions.values.round=function(...) assert(select('#',...)==2 and select(2,...)==3);return 7 end
                assert(definition.evaluate(node(tag,7),cache,101)==true and #s.rounds==rounds,'canonical rounding was captured instead of resolved live')
            end
        end end
        assert(seen>0,'tag never registered in reviewed inventory')
    end)
end
test('rounding receives unclamped spell and rune differences while expired totems skip it',function()
    for tag in pairs(modules) do local _,a,s=fixture(tag=='RUNE_COOLDOWN' and inventory[5] or inventory[3],true);observeRounding(a,s)
        s.start=99;s.duration=.7496;s.runes={[1]={99,.7496},[2]={99,.7496}}
        local result=a.conditionDefinitions[tag].evaluate(node(tag,0),{},100)
        if tag=='TOTEM_REMAIN' then assert(result==false and #s.rounds==0)
        else assert(result==true and #s.rounds>0);for _,n in ipairs(s.rounds) do assert(n<-.25 and n>-.251,'clamp moved before rounding') end end
    end
end)
test('current editable copies share native cache and live canonical rounding on real valid nodes',function()
    for tag in pairs(modules) do for _,modern in ipairs({false,true}) do local _,a,s=fixture(tag=='RUNE_COOLDOWN' and inventory[5] or inventory[3],modern)
        local source=assert(a:GetBuiltinConditionSource(tag));assert(source.evaluate:find('addon.Functions.values.round(',1,true),'rounding source catalog stale')
        local copy=assert(a:CompileCustomCondition('COPY_'..tag,source));a:RegisterCondition('COPY_'..tag,copy);observeRounding(a,s)
        local cache={};assert(a.conditionDefinitions[tag].evaluate(node(tag),cache,100)==true);local before=selectedCallCount(tag,s)
        assert(copy.evaluate(node(tag),cache,100)==true and selectedCallCount(tag,s)==before)
        local cloneNode=node(tag);cloneNode.type='COPY_'..tag;assert(a:evaluateConditionResult(cloneNode).status=='match')
        assert(a:evaluateConditionResult({type='NOT',value=cloneNode}).status=='no-match')
    end end
end)
test('saved raw evaluator source keeps its live legacy rounding lookup without rewriting',function()
    for tag in pairs(modules) do local _,a,s=fixture(tag=='RUNE_COOLDOWN' and inventory[5] or inventory[3],true)
        local source=assert(a:GetBuiltinConditionSource(tag));if tag=='RUNE_COOLDOWN' then source.evaluate=dofile('tests/fixtures/restore_rune_repairs.lua')(source.evaluate,tag) end;source.evaluate=restore(source.evaluate,tag,true);local before=a:CopySettingsData(source)
        local copy=assert(a:CompileCustomCondition('RAW_'..tag,source));a.round=function(...) assert(select('#',...)==2 and select(2,...)==3);return 9 end
        a.Functions.values.round=function() error('saved raw callback was silently canonicalized') end
        assert(copy.evaluate(node(tag,9),{},100)==true and a:SettingsDataEqual(before,source))
    end
end)
test('only five approved callback expressions change full module bytes and every private source remains exact',function()
    local _,a=fixture(inventory[3],true)
    for tag,module in pairs(modules) do local path='Conditions/'..module..'.lua';local file=assert(io.open(path));local text=file:read('*a');file:close()
        if module=='stats' then text=dofile('tests/fixtures/restore_health_forecast_repairs.lua')(text);text=dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')(text);text=dofile('tests/fixtures/restore_rune_repairs.lua')(text);text=dofile('tests/fixtures/restore_health_forecast_deficit.lua')(text);text=dofile('tests/fixtures/restore_point_repairs.lua')(text) end
        local inverse=restore(text,tag);assert(a:FunctionSourceHash(inverse)==moduleHashes[module],module..' changed beyond exact rounding qualification fromf537fe1')
        assert(not pcall(restore,inverse,tag),'inverse accepted missing repaired expression')
        for name,hash in pairs(privateHashes[module]) do local id='builtin:'..path..':'..name
            assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash,'private source changed: '..id)
            assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules[path](name),'private getter changed: '..id)
        end
        for alias in pairs(a.builtinCallbackBindings[path]) do assert(not alias:find('round',1,true),'round added to captured private Functions map') end
    end
end)
finish()
