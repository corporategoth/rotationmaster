local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'BUFF','BUFF_REMAIN','BUFF_STACKS','STEALABLE','DEBUFF','DEBUFF_REMAIN','DEBUFF_STACKS','DISPELLABLE'}
local modes={BUFF={'HELPFUL','present'},BUFF_REMAIN={'HELPFUL','remaining'},BUFF_STACKS={'HELPFUL','stacks'},STEALABLE={'HELPFUL','stealable'},DEBUFF={'HARMFUL','present'},DEBUFF_REMAIN={'HARMFUL','remaining'},DEBUFF_STACKS={'HARMFUL','stacks'},DISPELLABLE={'HARMFUL','dispel'}}
local expected={BUFF={valid={isin=1},print={nullable=1,playerize=1}},BUFF_REMAIN={valid={isin=2},print={nullable=2,playerize=1,compareString=1}},BUFF_STACKS={valid={isin=2},print={nullable=2,compareString=1}},STEALABLE={valid={isin=1},print={nullable=1}},DEBUFF={valid={isin=1},print={nullable=1,playerize=1}},DEBUFF_REMAIN={valid={isin=2},print={nullable=2,playerize=1,compareString=1}},DEBUFF_STACKS={valid={isin=2},print={nullable=2,compareString=1}},DISPELLABLE={valid={isin=2},print={nullable=2,playerize=1}}}
local groups={isin='values',nullable='presentation',compareString='presentation',playerize='presentation'}
local function module(tag) return (tag:find('BUFF',1,true)==1 or tag=='STEALABLE') and 'Conditions/buffs.lua' or 'Conditions/debuffs.lua' end
local function fixture(modern)
    local f=F.new();local a,e=f.addon,f.env
    local harmful={{name='Curse',spellId=20,sourceUnit='player',applications=2,duration=30,expirationTime=103,dispelName='Magic'}}
    local state={exists=true,calls=0,spellReads=0,metadata=true,filters={},records={HELPFUL={{name='Shield',spellId=10,sourceUnit='player',applications=2,duration=30,expirationTime=103,isStealable=true}},HARMFUL=harmful,['HARMFUL|RAID']=harmful}}
    e.UnitExists=function() return state.exists end
    e.C_Spell={GetSpellInfo=function(id) state.spellReads=state.spellReads+1;if state.metadata then return {name=(id==10 or id==11) and 'Shield' or 'Curse',spellID=id} end end}
    local function observe(_,index,filter)
        state.calls=state.calls+1;state.filters[#state.filters+1]=filter
        if state.throw then error('aura observation failed') end
        local raw=(state.records[filter] or {})[index]
        if modern then return raw end
        if raw then return raw.name,123,raw.applications,raw.dispelName,raw.duration,raw.expirationTime,raw.sourceUnit,raw.isStealable,false,raw.spellId end
    end
    if modern then e.C_UnitAuras={GetAuraDataByIndex=observe} else e.UnitAura=observe end
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Core/conditions.lua','Core/aura_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/buffs.lua','Conditions/debuffs.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state
end
local function value(tag)
    local result={type=tag,unit='player'}
    if tag=='DISPELLABLE' then result.debufftype='Magic';result.owndebuff=true;result.dispellable=true
    elseif tag~='STEALABLE' then result.spell=tag:find('DEBUFF',1,true)==1 and 20 or 10;result.anyrank=true;result.ownbuff=true;result.owndebuff=true end
    if modes[tag][2]=='remaining' or modes[tag][2]=='stacks' then result.operator='LESSTHAN';result.value=4 end
    return result
end
local function clones(a)
    local result={}
    for _,tag in ipairs(tags) do local copy=assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag))));a:RegisterCondition('COPY_'..tag,copy);result[tag]=copy end
    return result
end
local function count(text,pattern) local _,n=text:gsub(pattern,'');return n end

test('eight aura declarations select exactly thirty-five owned pure helper calls',function()
    local f,a=fixture(true);local total=0
    for _,file in ipairs({'Conditions/buffs.lua','Conditions/debuffs.lua'}) do
        local declared=assert(a.builtinCallbackBindings and a.builtinCallbackBindings[file],'canonical aura leaves missing')
        for name,group in pairs(groups) do local path='Functions.'..group..'.'..name;assert(declared[path]=='builtin:utils.lua:'..name and a:ResolveFunctionBinding(declared[path])==a.Functions[group][name]) end
    end
    for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag));if tag~='STEALABLE'and tag~='DISPELLABLE'then source=dofile('tests/fixtures/restore_aura_name_summary_literals.lua')(source,tag,'export')end;assert(not source.bindings.Functions,'namespace captured as an opaque value')
        for callback,counts in pairs(expected[tag]) do for name,group in pairs(groups) do
            local path='Functions.'..group..'.'..name;local n=count(source[callback],path:gsub('%.','%%.')..'%(');assert(n==(counts[name] or 0),tag..'.'..callback..' '..name..' count changed');total=total+n
            assert(not source[callback]:find('addon.'..name..'(',1,true),'legacy pure helper remained')
        end end
        assert(source.evaluate=='\n        return addon:EvaluateAuraCondition(value, cache, start, "'..modes[tag][1]..'", "'..modes[tag][2]..'")\n    ','aura evaluation body changed')
        if tag~='STEALABLE' and tag~='DISPELLABLE' then assert(source.fields.anyrank=='boolean' and source.widget:find('Widget_AuraRankWidget',1,true) and source.widget:find('"Spell_EditBox"',1,true)) end
    end
    assert(total==35 and not f.env.Functions)
    local stealable=a:GetBuiltinConditionSource('STEALABLE');assert(count(stealable.widget,'Functions%.collections%.deepcopy%(')==1,'collection helper is not canonical');assert(stealable.bindings['Functions.collections.deepcopy']=='builtin:Functions/collections.lua:deepcopy');local dispel=a:GetBuiltinConditionSource('DISPELLABLE');assert(count(dispel.widget,'Functions%.collections%.keys%(')==1 and dispel.bindings['Functions.collections.keys']=='builtin:Functions/collections.lua:keys')
end)
test('original color and Help captured identities and public helper APIs remain stable',function()
    local _,a=fixture(true)
    for file,hashes in pairs({['Conditions/buffs.lua']={color='89c33f24',helpers='e55d7b5a'},['Conditions/debuffs.lua']={color='cd0b6691',helpers='785d08c7'}}) do for name,hash in pairs(hashes) do
        local id='builtin:'..file..':'..name;local record=assert(a.builtinFunctions[id]);assert(record.valueBinding and a:FunctionSourceHash(record.source)==hash)
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules[file](name))
    end end
    for name,group in pairs(groups) do assert(a[name]==a.Functions[group][name] and a:ResolveFunctionBinding('builtin:utils.lua:'..name)==a[name]) end
end)
test('baseline aura summaries preserve positive negative rank caster and existing grammar wording',function()
    local _,a=fixture(true);local copies=clones(a)
    local baseline={
        BUFF={'you have your own Shield (any rank)','you do not have your own Shield (any rank)'},
        BUFF_REMAIN={'you have your own Shield (any rank) where the remaining time is less than 4 seconds','you do not have your own Shield (any rank) where the remaining time is less than 4 seconds'},
        BUFF_STACKS={'your stacks of your own Shield (any rank) is less than 4','your stacks of your own Shield (any rank) is not less than 4'},
        STEALABLE={'you has a stealable buff','you does not have a stealable buff'},
        DEBUFF={'you have your own Curse (any rank)','you do not have your own Curse (any rank)'},
        DEBUFF_REMAIN={'you have your own Curse (any rank) where the remaining time is less than 4 seconds','you do not have your own Curse (any rank) where the remaining time is less than 4 seconds'},
        DEBUFF_STACKS={'your stacks of your own Curse (any rank) is less than 4','your stacks of your own Curse (any rank) is not less than 4'},
        DISPELLABLE={'you have a your own Magic debuff that is dispellable','you do not have a your own Magic debuff that is dispellable'},
    }
    for _,tag in ipairs(tags) do local node=value(tag);assert(a.conditionDefinitions[tag].print(0,node)==baseline[tag][1] and copies[tag].print(0,node,true)==baseline[tag][2],tag..' baseline wording changed') end
end)
test('registered clones preserve aura validation and summary matrices for units identities and options',function()
    for _,modern in ipairs({true,false}) do
        local _,a=fixture(modern);local copies=clones(a)
        for _,tag in ipairs(tags) do for _,unit in ipairs({'player','target','focus','unknown'}) do for _,spell in ipairs({10,20,'Shield','Curse',false}) do for _,operator in ipairs({'LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','EQUALS','NOTEQUALS','DIVISIBLE','UNKNOWN'}) do
            local node=value(tag);node.unit=unit;node.spell=spell;node.operator=operator;node.value=4
            for _,enabled in ipairs({false,true}) do
                node.anyrank=enabled;node.ownbuff=enabled;node.owndebuff=enabled;node.dispellable=enabled
                assert(a.conditionDefinitions[tag].valid(0,node)==copies[tag].valid(0,node),tag..' validation changed')
                for _,negated in ipairs({false,true}) do assert(a.conditionDefinitions[tag].print(0,node,negated)==copies[tag].print(0,node,negated),tag..' summary changed') end
            end
        end end end end
    end
end)
test('real modern and legacy aura observations preserve caster modes filters and shared cache reuse',function()
    for _,modern in ipairs({true,false}) do
        local _,a,state=fixture(modern);local copies=clones(a)
        for _,tag in ipairs(tags) do local node=value(tag);local cache={};local original,why=a.conditionDefinitions[tag].evaluate(node,cache,100);local before=state.calls;local actual,reason=copies[tag].evaluate(node,cache,100)
            assert(original==true and actual==original and why==reason and state.calls==before,tag..' observation/cache behavior changed')
            assert(state.filters[#state.filters]==(tag=='DISPELLABLE' and 'HARMFUL|RAID' or modes[tag][1]))
        end
        state.records.HELPFUL[1].sourceUnit='party1';state.records.HARMFUL[1].sourceUnit='party1'
        for _,tag in ipairs({'BUFF','BUFF_REMAIN','BUFF_STACKS','DEBUFF','DEBUFF_REMAIN','DEBUFF_STACKS','DISPELLABLE'}) do assert(copies[tag].evaluate(value(tag),{},100)==false,'own caster filter changed') end
        state.records.HARMFUL[1].sourceUnit='player';state.records.HARMFUL[1].dispelName='';local node=value('DISPELLABLE');node.debufftype='Enrage';assert(copies.DISPELLABLE.evaluate(node,{},100))
    end
end)
test('numeric exact identities localized rank families and portable schemas remain unchanged',function()
    for _,modern in ipairs({true,false}) do
        local _,a,state=fixture(modern);local copies=clones(a)
        state.records.HELPFUL[1].spellId=11;state.records.HARMFUL[1].spellId=21
        for _,tag in ipairs({'BUFF','BUFF_REMAIN','BUFF_STACKS','DEBUFF','DEBUFF_REMAIN','DEBUFF_STACKS'}) do
            local node=value(tag);node.anyrank=false;assert(copies[tag].evaluate(node,{},100)==false)
            node.anyrank=true;state.spellReads=0;assert(copies[tag].evaluate(node,{},100)==true and state.spellReads==1,'rank family lookup changed')
            local data=dofile('tests/fixtures/rotation_data.lua')();node.ownbuff=nil;node.owndebuff=nil
            local flag=tag:find('DEBUFF',1,true)==1 and 'owndebuff' or 'ownbuff';node[flag]=true
            assert(data.ValidateBody({switch=node,rotation={},cooldowns={}},{conditions=a.conditionDefinitions}).valid)
            node.anyrank='invalid';assert(not data.ValidateBody({switch=node,rotation={},cooldowns={}},{conditions=a.conditionDefinitions}).valid)
        end
        state.metadata=false;local node=value('BUFF');local copy=a:CopySettingsData(node);copy.type='COPY_BUFF'
        assert(a:evaluateConditionResult({type='NOT',value=node}).status=='unavailable' and a:evaluateConditionResult({type='NOT',value=copy}).status=='unavailable')
    end
end)
test('absent permanent failed restricted and missing aura states keep tri-state NOT and branch behavior',function()
    for _,modern in ipairs({true,false}) do
        local f,a,state=fixture(modern);clones(a)
        for _,tag in ipairs(tags) do
            state.throw=true;local node=value(tag);local copy=a:CopySettingsData(node);copy.type='COPY_'..tag
            local original=a:evaluateConditionResult({type='NOT',value=node});local compiled=a:evaluateConditionResult({type='NOT',value=copy});assert(original.status=='unavailable' and compiled.status==original.status and compiled.reason==original.reason)
            local rotation={rotation={{id='guard',type='branch',conditions=copy,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}},{id='tail',type='spell',action=3}}}
            local result=a:EvaluateRotationSequence(rotation,function(v) return a:evaluateConditionResult(v) end,function() error('unavailable aura chose a branch or fallthrough') end);assert(result.status=='unavailable')
        end
        state.throw=false;state.records.HELPFUL={};state.records.HARMFUL={};state.records['HARMFUL|RAID']={}
        for _,tag in ipairs(tags) do local node=value(tag);node.type='COPY_'..tag;assert(a:evaluateConditionResult({type='NOT',value=node}).status=='match','known absence stopped being invertible') end
        f.env.C_UnitAuras=nil;f.env.UnitAura=nil
        assert(a:evaluateConditionResult({type='NOT',value={type='COPY_BUFF',unit='player',spell=10}}).status=='unavailable')
    end
    local f,a,state=fixture(true);local copies=clones(a);local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    state.records.HELPFUL[1].expirationTime=opaque;local node=value('BUFF_REMAIN');node.type='COPY_BUFF_REMAIN';assert(a:evaluateConditionResult({type='NOT',value=node}).status=='unavailable')
    state.records.HELPFUL[1].expirationTime=0;state.records.HELPFUL[1].duration=0
    assert(copies.BUFF_REMAIN.evaluate(value('BUFF_REMAIN'),{},100)==false);node=value('BUFF_REMAIN');node.operator='GREATERTHAN';node.value=600;assert(copies.BUFF_REMAIN.evaluate(node,{},100)==true)
    state.records.HELPFUL[1].name=opaque;state.records.HELPFUL[1].spellId=opaque
    assert(a:evaluateConditionResult({type='NOT',value={type='COPY_BUFF',unit='player',spell=10}}).status=='unavailable')
end)
test('legacy saved source retains all original addon helper APIs',function()
    local _,a=fixture(true)
    assert(a:InstallCustomFunction('LEGACY_AURA_HELPERS',{description='Legacy aura helper consumer',args={},returns={},bindings={},code='return addon.isin({x=false},"x"),addon.nullable(false),addon.playerize("player","yes","no"),addon.compareString("EQUALS","left","right")'}))
    local included,nullable,player,words=a:ResolveFunctionBinding('LEGACY_AURA_HELPERS')();assert(included and nullable==false and player=='yes' and words==a.compareString('EQUALS','left','right'))
end)
finish()
