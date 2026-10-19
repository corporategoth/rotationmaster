local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'ANYSPELL_AVAIL','ANYSPELL_RANGE','ANYSPELL_COOLDOWN','ANYSPELL_REMAIN','ANYSPELL_CHARGES'}
local groups={isin='values',compare='values',nullable='presentation',compareString='presentation',getCached='cache'}
local compared={ANYSPELL_COOLDOWN=true,ANYSPELL_REMAIN=true,ANYSPELL_CHARGES=true,ANYSPELL_HISTORY=true,ANYSPELL_HISTORY_TIME=true}
local function fixture(modern)
    local f=F.new();local a,e=f.addon,f.env
    local state={calls={},ids={},metadata=true,exists=true,range=true,hasRange=true,current=true,repeatActive=true,start=98,duration=6,enabled=true,currentCharges=1,maxCharges=2,chargeStart=90,chargeDuration=20}
    local function call(name,id) state.calls[name]=(state.calls[name] or 0)+1;state.ids[name]=id;if state.throw==name then error('native '..name..' failed') end end
    e.BOOKTYPE_SPELL='spell';e.BOOKTYPE_PET='pet';e.UnitExists=function() call('exists');return state.exists end
    e.GetBuildInfo=function() return '2.5.6','70006','',20506 end
    local function info(id) call('metadata',id);if not state.metadata then return end;if id=='Shoot' then id=5020 end;if id==5019 or id==5020 then return {name='Shoot',spellID=id,iconID=1,subtext=id==5019 and 'Rank 1' or 'Rank 2'} end end
    local function link(id) return '|Hspell:'..id..'|h[Shoot]|h' end
    local function cooldown(id) call('cooldown',id);if id==29515 then return 0,0,true end;return state.start,state.duration,state.enabled end
    local function charges(id) call('charges',id);return state.currentCharges,state.maxCharges,state.chargeStart,state.chargeDuration,1 end
    if modern then
        e.C_Spell={GetSpellInfo=info,GetSpellLink=link,GetSpellCooldown=function(id) local start,duration,enabled=cooldown(id);return {startTime=start,duration=duration,isEnabled=enabled,modRate=1} end,
            GetSpellCharges=function(id) local current,maximum,start,duration,rate=charges(id);return {currentCharges=current,maxCharges=maximum,cooldownStartTime=start,cooldownDuration=duration,chargeModRate=rate} end,
            SpellHasRange=function() return state.hasRange end,IsSpellInRange=function(id) call('range',id);return state.range end,
            IsCurrentSpell=function(id) call('current',id);return state.current end,IsAutoRepeatSpell=function(id) call('repeatActive',id);return state.repeatActive end}
    else
        e.GetSpellInfo=function(id) local record=info(id);if record then return record.name,record.subtext,1,0,0,30,record.spellID end end;e.GetSpellLink=link
        e.GetSpellCooldown=function(id) local start,duration,enabled=cooldown(id);return start,duration,enabled and 1 or 0 end
        e.GetSpellCharges=charges;e.SpellHasRange=function() return state.hasRange end
        e.FindSpellBookSlotBySpellID=function(id,pet) call('slot',id);state.slots=state.slots or {};state.slots[#state.slots+1]={id,pet};if pet then if state.petSlot==false then return end;return id==5019 and 8 or 9 end;if state.playerSlot==false then return end;return id==5019 and 3 or 4 end
        e.IsSpellInRange=function(slot,bank,unit) assert((bank=='spell' or bank=='pet') and unit=='target');state.rangeBank=bank;call('range',slot);if state.range==nil then return end;return state.range and 1 or 0 end
        e.IsCurrentSpell=function(id) call('current',id);return state.current and 1 or 0 end
        e.IsAutoRepeatSpell=function(slot,bank) assert(bank=='spell');call('repeatActive',slot);return state.repeatActive and 1 or 0 end
    end
    for _,path in ipairs({'Platform/spells.lua','Platform/actions.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/common.lua','Conditions/anyspell.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    a.spellHistory={{spell=5019,time=96}}
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state
end
local function value(tag,ranked) return {type=tag,spell=5019,ranked=ranked==nil and true or ranked,operator='EQUALS',value=compared[tag] and (tag=='ANYSPELL_CHARGES' or tag=='ANYSPELL_HISTORY') and 1 or tag=='ANYSPELL_REMAIN' and 10 or 4} end
local function copies(a)
    local clones,baseline={},{}
    for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag));clones[tag]=assert(a:CompileCustomCondition('COPY_'..tag,source));a:RegisterCondition('COPY_'..tag,clones[tag])
        local old=a:CopySettingsData(source)
        for _,callback in ipairs({'valid','evaluate','print'}) do for name,group in pairs(groups) do old[callback]=old[callback]:gsub('Functions%.'..group..'%.'..name..'%(','addon.'..name..'(') end end
        baseline[tag]=assert(a:CompileCustomCondition('LEGACY_'..tag,old));a:RegisterCondition('LEGACY_'..tag,baseline[tag])
    end
    return clones,baseline
end
local function count(text,pattern) local _,n=text:gsub(pattern,'');return n end

test('spell callbacks select exactly 23 direct anyspell calls from five selected leaves',function()
    local f,a=fixture(true);local selected=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/anyspell.lua'],'spell canonical leaf metadata missing');local leaves=0
    for _ in pairs(selected) do leaves=leaves+1 end;assert(leaves==5)
    for name,group in pairs(groups) do assert(selected['Functions.'..group..'.'..name]=='builtin:utils.lua:'..name and a:ResolveFunctionBinding(selected['Functions.'..group..'.'..name])==a.Functions[group][name]) end
    local totals={isin=0,compare=0,nullable=0,compareString=0,getCached=0}
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(not source.bindings.Functions)
        for _,callback in ipairs({'valid','evaluate','print'}) do for name,group in pairs(groups) do
            local n=count(source[callback],'Functions%.'..group..'%.'..name..'%(');local expected=callback=='valid' and name=='isin' and compared[tag] and 1 or callback=='evaluate' and name=='compare' and compared[tag] and 1 or callback=='print' and name=='nullable' and (compared[tag] and 2 or 1) or callback=='print' and name=='compareString' and compared[tag] and 1 or callback=='evaluate' and name=='getCached' and (tag=='ANYSPELL_RANGE' and 2 or 1) or 0
            assert(n==expected,tag..'.'..callback..' '..name..' count changed');totals[name]=totals[name]+n;assert(not source[callback]:find('addon.'..name..'(',1,true))
        end end
    end
    assert(totals.isin==3 and totals.compare==3 and totals.nullable==8 and totals.compareString==3 and totals.getCached==6 and not f.env.Functions)
end)
test('original private captures retain exact source hashes stable IDs and getter identities',function()
    local _,a=fixture(true)
    for name,hash in pairs({color='f35f4765',helpers='47f6d2db',SpellData='bd968be4'}) do local id='builtin:Conditions/anyspell.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash);assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/anyspell.lua'](name)) end
end)
test('compiled canonical and legacy spell callbacks preserve validation summary wording ranks and operators',function()
    for _,modern in ipairs({true,false}) do local _,a=fixture(modern);local clones,baseline=copies(a)
        for _,tag in ipairs(tags) do for _,spell in ipairs({5019,5020,0,-1,1.5,'5019'}) do for _,ranked in ipairs({false,true,'invalid'}) do for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE','UNKNOWN'}) do
            local node=value(tag,ranked);node.spell=spell;node.operator=operator
            assert(a.conditionDefinitions[tag].valid(0,node)==clones[tag].valid(0,node) and clones[tag].valid(0,node)==baseline[tag].valid(0,node))
            for _,negated in ipairs({false,true}) do local text=a.conditionDefinitions[tag].print(0,node,negated);assert(text==clones[tag].print(0,node,negated) and text==baseline[tag].print(0,node,negated)) end
        end end end end
        assert(clones.ANYSPELL_AVAIL.print(0,value('ANYSPELL_AVAIL'),false):find('available',1,true))
    end
end)
test('actual modern and legacy spell adapters share exact cache observations across canonical and legacy clones',function()
    for _,modern in ipairs({true,false}) do local _,a,state=fixture(modern);local clones,baseline=copies(a)
        for _,tag in ipairs(tags) do local node=value(tag);local cache={};local actual,why=a.conditionDefinitions[tag].evaluate(node,cache,100);local before=a:CopySettingsData(state.calls)
            local copied,reason=clones[tag].evaluate(node,cache,100);local legacy,oldReason=baseline[tag].evaluate(node,cache,100)
            assert(actual==copied and copied==legacy and why==reason and reason==oldReason and a:SettingsDataEqual(before,state.calls),tag..' changed observation or cache reuse')
            assert(tag=='ANYSPELL_AVAIL' and actual==false or tag~='ANYSPELL_AVAIL' and actual==true,tag..' positive control failed')
        end
        local node=value('ANYSPELL_RANGE',false);assert(clones.ANYSPELL_RANGE.evaluate(node,{},100));assert(state.ids.range==(modern and 5020 or 4),'unranked range choice changed')
        node.ranked=true;assert(clones.ANYSPELL_RANGE.evaluate(node,{},100) and state.ids.range==(modern and 5019 or 3))
    end
end)
test('cooldown charge history empty and known false cases retain their original comparisons',function()
    for _,modern in ipairs({true,false}) do local _,a,state=fixture(modern);local clones,baseline=copies(a)
        state.start=90;state.duration=5;state.currentCharges=2
        for _,tag in ipairs({'ANYSPELL_COOLDOWN','ANYSPELL_REMAIN'}) do local node=value(tag);node.value=0;assert(clones[tag].evaluate(node,{},100) and baseline[tag].evaluate(node,{},100)) end
        state.range=false;state.current=false;state.repeatActive=false
        for _,tag in ipairs({'ANYSPELL_RANGE'}) do local node=value(tag);node.type='COPY_'..tag;assert(a:evaluateConditionResult({type='NOT',value=node}).status=='match') end

    end
end)
test('unavailable native observations remain unknown under NOT and prevent branch actions for registered clones',function()
    for _,modern in ipairs({true,false}) do local f,a,state=fixture(modern);copies(a)
        for _,entry in ipairs({{'ANYSPELL_AVAIL','cooldown'},{'ANYSPELL_RANGE','range'},{'ANYSPELL_COOLDOWN','cooldown'},{'ANYSPELL_REMAIN','charges'},{'ANYSPELL_CHARGES','charges'}}) do
            state.throw=entry[2];local node=value(entry[1]);node.type='COPY_'..entry[1];local result=a:evaluateConditionResult({type='NOT',value=node});assert(result.status=='unavailable' and result.reason=='api-error',entry[1])
            local body={rotation={{id='guard',type='branch',conditions=node,onTrue={{id='yes',type='spell',action=5019}},onFalse={{id='no',type='spell',action=5019}}}}}
            assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unknown spell selected an action') end).status=='unavailable')
        end
        state.throw=nil;local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;state.duration=opaque
        local node=value('ANYSPELL_COOLDOWN');node.type='COPY_ANYSPELL_COOLDOWN';assert(a:evaluateConditionResult({type='NOT',value=node}).reason=='restricted-value')
    end
end)
test('any-spell range keeps player-first pet-fallback book order rank choice and missing-book unavailability',function()
    local _,a,state=fixture(false);local clones,baseline=copies(a)
    for _,ranked in ipairs({false,true}) do
        state.slots={};state.playerSlot=true;local node=value('ANYSPELL_RANGE',ranked);local id=ranked and 5019 or 5020
        assert(clones.ANYSPELL_RANGE.evaluate(node,{},100));assert(#state.slots==1 and state.slots[1][1]==id and state.slots[1][2]==false and state.rangeBank=='spell')
        state.slots={};state.playerSlot=false;assert(clones.ANYSPELL_RANGE.evaluate(node,{},100));assert(#state.slots==2 and state.slots[1][1]==id and state.slots[1][2]==false and state.slots[2][1]==id and state.slots[2][2]==true and state.rangeBank=='pet')
        assert(baseline.ANYSPELL_RANGE.evaluate(node,{},100))
    end
    state.petSlot=false
    for _,prefix in ipairs({'COPY_','LEGACY_'}) do local node=value('ANYSPELL_RANGE');node.type=prefix..'ANYSPELL_RANGE';local result=a:evaluateConditionResult({type='NOT',value=node});assert(result.status=='unavailable' and result.reason=='spell-not-in-book') end
end)
test('absent targets and known rangeless spells remain false without widening any-spell membership',function()
    for _,modern in ipairs({true,false}) do local _,a,state=fixture(modern);copies(a);state.exists=false
        for _,prefix in ipairs({'COPY_','LEGACY_'}) do local node=value('ANYSPELL_RANGE');node.type=prefix..'ANYSPELL_RANGE';assert(a:evaluateConditionResult({type='NOT',value=node}).status=='match') end
        assert(not state.calls.range and not state.calls.slot,'absent target still queried a range observation')
        state.exists=true;state.hasRange=false
        for _,prefix in ipairs({'COPY_','LEGACY_'}) do local node=value('ANYSPELL_RANGE');node.type=prefix..'ANYSPELL_RANGE';assert(a:evaluateConditionResult({type='NOT',value=node}).status=='match') end
        assert(not state.calls.range,'rangeless spell still queried range')
    end
end)
test('canonical and legacy cache aliases preserve nil tuples exact arguments and no-cache behavior',function()
    local _,a=fixture(true);local canonical=a.Functions.cache.getCached
    assert(canonical==a.getCached and canonical==a:ResolveFunctionBinding('builtin:utils.lua:getCached'))
    local receiver={};local calls=0;local observed
    local method=function(...) calls=calls+1;observed={n=select('#',...),...};return nil,'unavailable',nil,'tail' end
    local cache={};local function check(...) assert(select('#',...)==4);local x,y,z,tail=...;assert(x==nil and y=='unavailable' and z==nil and tail=='tail') end
    check(canonical(cache,method,receiver,5019,nil,'spell'));check(a.getCached(cache,method,receiver,5019,nil,'spell'))
    assert(calls==1 and observed.n==4 and observed[1]==receiver and observed[2]==5019 and observed[3]==nil and observed[4]=='spell')
    check(canonical(cache,method,receiver,'5019',nil,'spell'));assert(calls==2,'numeric and string spell identities collided')
    check(canonical(nil,method,receiver,5019,nil,'spell'));check(a.getCached(nil,method,receiver,5019,nil,'spell'));assert(calls==4)
    assert(select('#',canonical({},nil))==0 and select('#',a.getCached({},nil))==0)
    assert(a:InstallCustomFunction('LEGACY_ANYSPELL_CACHE',{description='Legacy cache consumer',args={},returns={},bindings={},code='return addon.getCached(nil,function() return nil,"tail",nil end)'}))
    local function legacy(...) assert(select('#',...)==3);local first,tail,last=...;assert(first==nil and tail=='tail' and last==nil) end
    legacy(a:ResolveFunctionBinding('LEGACY_ANYSPELL_CACHE')())
end)
test('missing metadata and nil cache methods preserve existing call-time behavior and legacy custom APIs',function()
    local _,a,state=fixture(true);local clones=copies(a);state.metadata=false
    for _,tag in ipairs(tags) do local node=value(tag,false);node.spell=9999;node.type='COPY_'..tag;assert(a:evaluateConditionResult({type='NOT',value=node}).status=='unavailable') end
    state.metadata=true;a.Platform.GetSpellCharges=nil;local actual,why=clones.ANYSPELL_CHARGES.evaluate(value('ANYSPELL_CHARGES'),{},100);assert(actual==nil and why==nil)
    assert(a:InstallCustomFunction('LEGACY_ANYSPELL_HELPERS',{description='Legacy spell helpers',args={},returns={},bindings={},code='return addon.compare("EQUALS",1,1),addon.isin({x=false},"x"),addon.nullable(false),addon.compareString("EQUALS","left","right")'}))
    local comparedValue,included,nullable,wording=a:ResolveFunctionBinding('LEGACY_ANYSPELL_HELPERS')();assert(comparedValue and included and nullable==false and wording==a.compareString('EQUALS','left','right'))
end)
finish()
