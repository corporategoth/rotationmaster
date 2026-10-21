local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local groups={compare='values',isin='values',nullable='presentation',playerize='presentation',compareString='presentation',getCached='cache',deepcopy='collections',keys='collections'}
local expected={
    COMBAT={valid={isin=1},evaluate={getCached=1},print={playerize=1,nullable=1}},
    PET={evaluate={getCached=1}},PET_NAME={evaluate={getCached=1},print={nullable=1}},
    STEALTHED={evaluate={getCached=1}},INCONTROL={evaluate={getCached=1}},
    LOC_TYPE={valid={isin=2},evaluate={getCached=2,compare=1},print={compareString=1,nullable=2}},
    LOC_BLOCKED={valid={isin=2},evaluate={getCached=2,compare=1},print={compareString=1,nullable=2}},
    MOVING={evaluate={getCached=1}},THREAT={valid={isin=1},evaluate={getCached=1},print={nullable=2}},
    THREAT_COUNT={valid={isin=1},evaluate={compare=1},print={compareString=1,nullable=2}},
    FORM={evaluate={getCached=1},print={nullable=1}},
    ATTACKABLE={valid={isin=1},evaluate={getCached=1},print={nullable=1}},
    ENEMY={valid={isin=1},evaluate={getCached=1},print={nullable=1}},
    COMBAT_HISTORY={valid={isin=3},evaluate={compare=1},print={compareString=1,playerize=1,nullable=3}},
    COMBAT_HISTORY_TIME={valid={isin=3},evaluate={compare=1},print={compareString=1,playerize=1,nullable=3}},
    TIME_IN_COMBAT={valid={isin=1},evaluate={compare=1},print={compareString=1,nullable=1}},
}
local valueHashes={color='dbda383d',character_class='d17cf4c1',helpers='9e28e933'}
local function id(name) return 'builtin:'..(groups[name]=='collections' and 'Functions/collections.lua' or 'utils.lua')..':'..name end
local function qualified(name) return 'Functions.'..groups[name]..'.'..name end
local function fixture(...)
    local f=F.new(...);local a,e=f.addon,f.env
    local state={exists={player=true,target=true,pet=true},combat=true,enemy=true,attack=true,dead=false,speed=0,threat=2,
        stealth=false,control=true,petName='Wolf',form=0,calls={},events={{kind='STUN_MECHANIC',remain=4,school=4}}}
    local function called(name) state.calls[name]=(state.calls[name] or 0)+1;if state.throw==name then error('native '..name..' failed') end end
    state.observed={nameplate1={enemy=true,threat=0},nameplate2={enemy=true,threat=2},nameplate3={enemy=false,threat=3},nameplate4={enemy=true}}
    state.guids={nameplate1='GUID1',nameplate2='GUID2',nameplate3='GUID3',nameplate4='GUID4'}
    for unit in pairs(state.observed) do state.exists[unit]=true end
    e.UnitExists=function(unit) called('exists');return state.exists[unit] end
    e.UnitGUID=function(unit) called('guid');return state.guids[unit] end
    e.UnitAffectingCombat=function() called('combat');return state.combat end
    e.UnitIsEnemy=function(_,unit) called('enemy');local observed=state.observed[unit];if observed then return observed.enemy end;return state.enemy end
    e.UnitCanAttack=function() called('attack');return state.attack end
    e.UnitIsDead=function() called('dead');return state.dead end
    e.UnitThreatSituation=function(_,unit) called('threat');local observed=state.observed[unit];if observed then return observed.threat end;return state.threat end
    e.GetUnitName=function() called('petName');return state.petName end
    e.IsStealthed=function() called('stealth');return state.stealth end
    e.HasFullControl=function() called('control');return state.control end
    e.GetUnitSpeed=function() called('speed');return state.speed end
    e.GetShapeshiftForm=function() called('form');return state.form end
    e.GetNumShapeshiftForms=function() return 3 end
    e.GetShapeshiftFormInfo=function(index) return 1,'Form '..index,false,100+index end
    e.GetSpellInfo=function(spell) return spell=='Ghost Wolf' and 'Ghost Wolf' or 'Form '..tostring(spell) end
    e.C_LossOfControl={GetActiveLossOfControlDataCount=function() called('eventCount');return #state.events end,
        GetActiveLossOfControlData=function(index) called('eventInfo');local event=state.events[index];return {locType=event.kind,timeRemaining=event.remain,lockoutSchool=event.school} end}
    e.SCHOOL_STRINGS={[1]='Physical',[2]='Holy',[3]='Fire'}
    e.bit={lshift=function(value,count) return value*2^count end,band=function(left,right)
        local value,power=0,1
        while left>0 or right>0 do if left%2==1 and right%2==1 then value=value+power end;left=math.floor(left/2);right=math.floor(right/2);power=power*2 end
        return value
    end}
    a.loc_types={STUN='Stun',FEAR='Fear',INTERRUPT='Interrupt'}
    a.unitsInRange={GUID1={unit='nameplate1',enemy=true,threat=99},GUID2={unit='nameplate2',enemy=false,threat=0},
        GUID3={unit='nameplate3',enemy=true,threat=99},GUID4={unit='nameplate4',enemy=true,threat=99}}
    a.combatHistory={player={{action='WOUND',severity='CRITICAL',time=98},{action='MISS',time=95}},target={{action='HEAL',time=97}}};a.combatStart=95
    for _,path in ipairs({'Platform/spells.lua','Core/conditions.lua','Conditions/common.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state
end
local function registerCopies(a)
    for tag in pairs(expected) do
        local source=assert(a:GetBuiltinConditionSource(tag));local copy,why=a:CompileCustomCondition('COPY_'..tag,source)
        assert(copy,tag..': '..tostring(why and why.reason));a:RegisterCondition('COPY_'..tag,copy)
    end
end
local function node(a,tag,value) local copy=a:CopySettingsData(value);copy.type=tag;return copy end
local function same(a,tag,value)
    local left,right=node(a,tag,value),node(a,'COPY_'..tag,value)
    assert(a.conditionDefinitions[tag].valid(0,left)==a.conditionDefinitions['COPY_'..tag].valid(0,right),tag..' validator differs')
    for _,negated in ipairs({false,true}) do
        local original=negated and {type='NOT',value=left} or left;local clone=negated and {type='NOT',value=right} or right
        local first,second=a:evaluateConditionResult(original),a:evaluateConditionResult(clone)
        assert(first.status==second.status and first.reason==second.reason,tag..' engine outcome differs')
        assert(a:printCondition(original,0)==a:printCondition(clone,0),tag..' summary differs')
    end
end
local vectors={
    COMBAT={{unit='player'},{unit='target'},{unit='pet'},{unit='invalid'},{}},PET={{}},PET_NAME={{value='Wolf'},{value='Other'},{}},STEALTHED={{}},INCONTROL={{}},
    LOC_TYPE={{operator='GREATERTHAN',value=3,loc_type='STUN'},{operator='EQUALS',value=0,loc_type='FEAR'},{operator='TYPO',value=3,loc_type='STUN'},{}},
    LOC_BLOCKED={{operator='GREATERTHAN',value=3,school=3},{operator='LESSTHAN',value=1,school=2},{operator='TYPO',value=3,school=3},{}},MOVING={{}},
    THREAT={{unit='target',threat=3},{unit='target',threat=4},{unit='target',threat=0},{}},
    THREAT_COUNT={{operator='EQUALS',value=1,threat=3},{operator='EQUALS',value=2,threat=3},{operator='TYPO',value=1,threat=3},{}},
    FORM={{value=0},{value=1},{value=2},{}},ATTACKABLE={{unit='target'},{unit='player'},{unit='invalid'},{}},ENEMY={{unit='target'},{unit='invalid'},{}},
    COMBAT_HISTORY={{unit='player',action='WOUND',operator='EQUALS',value=1},{unit='player',action='WOUND_CRITICAL',operator='EQUALS',value=1},{unit='player',action='MISS',operator='EQUALS',value=2},{unit='target',action='WOUND',operator='GREATERTHAN',value=0},{}},
    COMBAT_HISTORY_TIME={{unit='player',action='WOUND_CRITICAL',operator='LESSTHAN',value=3},{unit='player',action='MISS',operator='EQUALS',value=5},{unit='target',action='HEAL',operator='EQUALS',value=3},{}},
    TIME_IN_COMBAT={{operator='EQUALS',value=5},{operator='LESSTHAN',value=5},{operator='TYPO',value=5},{}},
}
test('combat callbacks select eight explicit canonical leaves with exact call counts and retain historical value identities',function()
    local f,a=fixture();local bindings=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/combat.lua'],'combat qualified dependency manifest missing')
    bindings=a:CopySettingsData(bindings)
    assert(bindings['PetSummary.phrase']=='builtin:Functions/presentation.lua:phrase');bindings['PetSummary.phrase']=nil
    local leaves=0;for alias,binding in pairs(bindings) do leaves=leaves+1;local name=alias:match('([%w_]+)$');assert(alias==qualified(name) and binding==id(name)) end;assert(leaves==8)
    local calls,callbacks=0,0
    for tag,changes in pairs(expected) do
        local source=assert(a:GetBuiltinConditionSource(tag));assert(not source.bindings.Functions,'namespace captured as an opaque value')
        for callback,counts in pairs(changes) do
            callbacks=callbacks+1
            for name in pairs(groups) do
                local code=source[callback];if tag=='COMBAT_HISTORY_TIME' and callback=='evaluate' then code=dofile('tests/fixtures/restore_combat_history_time_repairs.lua')(code,true) end;local _,count=code:gsub(qualified(name):gsub('%.','%%.')..'%(', '')
                assert(count==(counts[name] or 0),tag..'.'..callback..' canonical '..name..' call count differs');calls=calls+count
                assert(not code:find('addon.'..name..'(',1,true),'selected callback retains legacy call')
            end
            for name in pairs(groups) do assert(source.bindings[qualified(name)]==id(name),'canonical source binding missing') end
        end
    end
    assert(calls==65 and callbacks==38)
    for name,hash in pairs(valueHashes) do
        local binding='builtin:Conditions/combat.lua:'..name;local record=assert(a.builtinFunctions[binding]);assert(record.valueBinding and a:FunctionSourceHash(record.source)==hash,'historical value metadata changed')
        assert(rawequal(a:ResolveFunctionBinding(binding),a.builtinSourceModules['Conditions/combat.lua'](name)))
    end
    assert(not a.builtinFunctions['builtin:Conditions/combat.lua:AceGUI'] and a:ResolveFunctionBinding('builtin:Conditions/combat.lua:AceGUI')==nil)
    assert(not f.env.Functions and not f.env.functions)
end)
test('all registered combat source clones preserve validators engine outcomes and positive or NOT wording across inventory branches',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local _,a=fixture(unpack(case[1]));registerCopies(a)
        for tag,values in pairs(vectors) do for _,value in ipairs(values) do same(a,tag,value) end end
    end
end)
test('changing native combat pet movement attackability threat and CC observations preserve explicit outcomes',function()
    local _,a,state=fixture();registerCopies(a)
    local checks={{'COMBAT',{unit='target'}},{'PET',{}},{'PET_NAME',{value='Wolf'}},{'STEALTHED',{}},{'INCONTROL',{}},{'MOVING',{}},{'ATTACKABLE',{unit='target'}},{'ENEMY',{unit='target'}},{'THREAT',{unit='target',threat=3}},
        {'LOC_TYPE',{operator='GREATERTHAN',value=3,loc_type='STUN'}},{'LOC_BLOCKED',{operator='GREATERTHAN',value=3,school=3}}}
    for _,entry in ipairs(checks) do same(a,entry[1],entry[2]) end
    assert(a:evaluateCondition({type='ATTACKABLE',unit='target'}) and not a:evaluateCondition({type='MOVING'}))
    state.combat=false;state.exists.pet=nil;state.petName=nil;state.stealth=true;state.control=false;state.speed=7;state.dead=true;state.threat=nil
    for _,entry in ipairs(checks) do same(a,entry[1],entry[2]) end
    assert(not a:evaluateCondition({type='ATTACKABLE',unit='target'}) and a:evaluateCondition({type='MOVING'}))
    state.exists.target=nil;state.enemy=false;state.attack=false;state.events={}
    for _,entry in ipairs(checks) do same(a,entry[1],entry[2]) end
    assert(not a:evaluateCondition({type='LOC_TYPE',operator='GREATERTHAN',value=3,loc_type='STUN'}))
    state.events={{kind='FEAR_MECHANIC',remain=1,school=2},{kind='STUN_MECHANIC',remain=8,school=4}}
    same(a,'LOC_TYPE',{operator='EQUALS',value=8,loc_type='STUN'});assert(a:evaluateCondition({type='COPY_LOC_TYPE',operator='EQUALS',value=8,loc_type='STUN'}))
end)
test('combat history severity elapsed time missing history threat count and baseline summaries keep their meanings',function()
    local _,a=fixture();registerCopies(a)
    for _,tag in ipairs({'COMBAT_HISTORY','COMBAT_HISTORY_TIME','THREAT_COUNT','TIME_IN_COMBAT'}) do for _,value in ipairs(vectors[tag]) do same(a,tag,value) end end
    assert(a:evaluateCondition({type='COPY_THREAT_COUNT',operator='EQUALS',threat=3,value=1}))
    assert(a:evaluateCondition({type='COPY_COMBAT_HISTORY',unit='player',action='WOUND_CRITICAL',operator='EQUALS',value=1}))
    assert(a:evaluateCondition({type='COPY_TIME_IN_COMBAT',operator='EQUALS',value=5}) and not a:evaluateCondition({type='COPY_TIME_IN_COMBAT',operator='LESSTHAN',value=5}))
    assert(a:printCondition({type='COMBAT',unit='player'},0)=='you are in combat')
    assert(a:printCondition({type='NOT',value={type='COMBAT',unit='player'}},0)=='you are not in combat')
    assert(a:printCondition({type='TIME_IN_COMBAT',operator='EQUALS',value=5},0)=='Time in combat is equal to 5 seconds')
    a.combatStart=nil;a.combatHistory={};a.unitsInRange={}
    for _,tag in ipairs({'COMBAT_HISTORY','COMBAT_HISTORY_TIME','THREAT_COUNT','TIME_IN_COMBAT'}) do for _,value in ipairs(vectors[tag]) do same(a,tag,value) end end
    assert(not a:evaluateCondition({type='COPY_TIME_IN_COMBAT',operator='GREATERTHAN',value=0}))
end)
test('built-ins and actual public source clones share native cache observations and refresh on the next evaluation',function()
    local _,a,state=fixture();registerCopies(a);state.calls={}
    assert(a:evaluateCondition({type='AND',value={{type='COMBAT',unit='target'},{type='COPY_COMBAT',unit='target'},{type='ATTACKABLE',unit='target'},{type='COPY_ATTACKABLE',unit='target'}}}))
    assert(state.calls.exists==2 and state.calls.combat==1 and state.calls.attack==1 and state.calls.dead==1,'namespace clone split normalized combat or attackability observations')
    state.combat=false;assert(a:evaluateConditionResult({type='COPY_COMBAT',unit='target'}).status=='no-match' and state.calls.combat==2)
end)
test('native callback failures retain diagnostic unavailability and arbitrary saved source retains addon helper APIs',function()
    local f,a,state=fixture();registerCopies(a)
    f.env.geterrorhandler=function() return function() end end;f.load('Diagnostics/errors.lua');state.throw='exists'
    for _,tag in ipairs({'COMBAT','ATTACKABLE','ENEMY'}) do
        same(a,tag,{unit='target'});assert(a:evaluateConditionResult({type='NOT',value={type='COPY_'..tag,unit='target'}}).status=='unavailable')
    end
    for name,group in pairs(groups) do assert(a[name]==a.Functions[group][name] and a:ResolveFunctionBinding(id(name))==a[name] and a.builtinSourceModules[group=='collections' and 'Functions/collections.lua' or 'utils.lua'](name)==a[name]) end
    assert(a:InstallCustomFunction('LEGACY_COMBAT_API',{description='Legacy combat helper consumer',args={},returns={},bindings={},code='return addon.isin({x=false},"x"),addon.compare("EQUALS",1,1),addon.nullable(false),addon.playerize("player","yes","no"),addon.compareString("EQUALS","left","right"),addon.getCached(nil,function() return 9 end)'}))
    local present,equal,boolean,pronoun,summary,cached=assert(a:ResolveFunctionBinding('LEGACY_COMBAT_API'))()
    assert(present and equal and boolean==false and pronoun=='yes' and summary==a.Functions.presentation.compareString('EQUALS','left','right') and cached==9)
end)
finish()
