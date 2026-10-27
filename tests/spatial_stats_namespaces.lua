local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local groups={isin='values',compare='values',nullable='presentation',phrase='presentation',predicate='presentation',keys='collections'}
local tags={'PROXIMITY_HEALTH','PROXIMITY_HEALTH_COUNT','PROXIMITY_HEALTHPCT','PROXIMITY_HEALTHPCT_COUNT','PROXIMITY_MANA','PROXIMITY_MANA_COUNT','PROXIMITY_MANAPCT','PROXIMITY_MANAPCT_COUNT'}
local hashes={observation='83c25a41',statistic='3bd1d048',aggregate='e171a72c',color='e50480ee',helpers='91169864'}
local function qualified(name) return 'Functions.'..groups[name]..'.'..name end
local function binding(name)
    if name=='phrase' or name=='predicate' then return 'builtin:Functions/presentation.lua:'..name end
    return name=='keys' and 'builtin:Functions/collections.lua:keys' or 'builtin:utils.lua:'..name
end
local function fixture(...)
    local f=F.new(...);local a,e=f.addon,f.env
    local state={units={player={x=0,y=0,health=50,maxhealth=100,mana=30,maxmana=100},party1={x=3,y=4,health=20,maxhealth=100,mana=10,maxmana=100}},calls={},opaque={}}
    e.Enum.PowerType.Mana=0;e.PARTY='Party';e.canaccessvalue=function(value) return not rawequal(value,state.opaque) end
    local function observe(name,unit,field)
        state.calls[name]=(state.calls[name] or 0)+1;if state.throw==name then error('native '..name..' failed') end
        return state.units[unit][field]
    end
    e.UnitExists=function(unit) if state.throw=='exists' then error('native exists failed') end;return state.units[unit]~=nil end
    e.IsInRaid=function() return false end;e.IsInGroup=function() return true end
    e.UnitPlayerOrPetInParty=function(unit) return state.units[unit]~=nil end;e.UnitPlayerOrPetInRaid=function() return false end
    e.UnitPosition=function(unit) if state.missingPositions then return end;local u=state.units[unit];if u then return u.y,u.x,0,1 end end
    e.UnitHealth=function(unit) return observe('health',unit,'health') end;e.UnitHealthMax=function(unit) return observe('maxhealth',unit,'maxhealth') end
    e.UnitPower=function(unit,power) assert(power==0);return observe('mana',unit,'mana') end;e.UnitPowerMax=function(unit,power) assert(power==0);return observe('maxmana',unit,'maxmana') end
    f.libraries['LibRangeCheck-3.0'].GetRange=function() return 5,15 end
    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Core/conditions.lua','Conditions/common.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    e.geterrorhandler=function() return function() end end
    return f,a,state
end
local function legacy(code)
    for name in pairs(groups) do if name~='phrase' and name~='predicate' then code=code:gsub(qualified(name):gsub('%.','%%.')..'%(', 'addon.'..name..'(') end end
    return code
end
local function copies(a)
    local result={}
    for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag));local old=a:CopySettingsData(source)
        for _,callback in ipairs({'valid','evaluate','print','widget','help'}) do old[callback]=legacy(old[callback]) end
        local current=assert(a:CompileCustomCondition('COPY_'..tag,source));local historical=assert(a:CompileCustomCondition('LEGACY_'..tag,old))
        a:RegisterCondition('COPY_'..tag,current);a:RegisterCondition('LEGACY_'..tag,historical);result[tag]={a.conditionDefinitions[tag],current,historical}
    end
    return result
end
local function value(tag)
    return {type=tag,unit='player',distance=10,operator='GREATERTHAN',value=.1,operation='minimum',healthoperator='GREATERTHAN',health=.1,manaoperator='GREATERTHAN',mana=.1}
end
local function packed(...) return {n=select('#',...),...} end
local function sameCall(label,functions,callback,...)
    local expected
    for _,definition in ipairs(functions) do
        local result=packed(pcall(definition[callback],...))
        if not result[1] then result[2]=tostring(result[2]):gsub('^.-:%d+: ','') end
        if not expected then expected=result else
            assert(result.n==expected.n,label..' result arity changed')
            for i=1,result.n do assert(result[i]==expected[i],label..' result '..i..' differs: '..tostring(result[i])..' / '..tostring(expected[i])) end
        end
    end
    return expected
end
local function sameEngine(a,tag,node)
    for _,negated in ipairs({false,true}) do
        local expected
        for _,prefix in ipairs({'','COPY_','LEGACY_'}) do
            local v=a:CopySettingsData(node);v.type=prefix..tag;if negated then v={type='NOT',value=v} end
            local result=a:evaluateConditionResult(v)
            if expected then assert(result.status==expected.status and result.reason==expected.reason,tag..' engine/NOT result differs') else expected=result end
        end
    end
end

test('spatial statistics callbacks select exactly92 calls through six canonical leaves across28 callbacks',function()
    local f,a=fixture();local declared=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/spatial_stats.lua'],'spatial statistic canonical dependency manifest missing')
    local leaves=0;for alias,id in pairs(declared) do leaves=leaves+1;local name=alias:match('([%w_]+)$');assert(alias==qualified(name) and id==binding(name)) end;assert(leaves==6)
    local calls,callbacks=0,0
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));local count=tag:find('_COUNT',1,true)
        local expected={valid={isin=3},evaluate={compare=count and 2 or 1},print={nullable=4,phrase=1,predicate=count and 2 or 1}}
        if not count then expected.widget={keys=1} end
        assert(not source.bindings.Functions,'opaque namespace captured')
        for alias,id in pairs(declared) do assert(source.bindings[alias]==id) end
        for callback,counts in pairs(expected) do callbacks=callbacks+1;for name in pairs(groups) do
            local code=source[callback];local _,n=code:gsub(qualified(name):gsub('%.','%%.')..'%(', '')
            assert(n==(counts[name] or 0),tag..'.'..callback..' canonical '..name..' count differs');calls=calls+n
            assert(not code:find('addon.'..name..'(',1,true),'direct callback retained legacy call')
        end end
    end
    assert(calls==92 and callbacks==28 and not f.env.Functions and not f.env.functions)
end)
test('registered editable and legacy-shaped spatial callbacks preserve validators summaries raw errors and engine results across inventory branches',function()
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do local _,a=fixture(unpack(case[1]));local definitions=copies(a)
        for _,tag in ipairs(tags) do
            local vectors={value(tag),{}, {unit='invalid'},value(tag),value(tag),value(tag),value(tag),value(tag)}
            vectors[4].value=-20;vectors[4].health=-30;vectors[4].mana=-30
            vectors[5].operation='average';vectors[6].operation='maximum';vectors[7].operator='TYPO';vectors[8].distance=-1
            for _,v in ipairs(vectors) do sameCall(tag..' validator',definitions[tag],'valid',0,v);sameCall(tag..' summary',definitions[tag],'print',0,v);sameEngine(a,tag,v) end
            for _,bad in ipairs({'raw',false,{}}) do local v=value(tag);v.value=bad;sameCall(tag..' malformed validator',definitions[tag],'valid',0,v);sameCall(tag..' malformed summary',definitions[tag],'print',0,v);sameCall(tag..' malformed evaluation',definitions[tag],'evaluate',v,{}) end
        end
    end
end)
test('spatial deficits percentages counts and raw native failures preserve exact outcomes and unknown negation',function()
    local f,a,state=fixture();local definitions=copies(a)
    for _,tag in ipairs(tags) do local v=value(tag);sameEngine(a,tag,v);assert(a:evaluateConditionResult(v).status==(tag=='PROXIMITY_MANAPCT' and 'no-match' or 'match'),tag..' baseline meaning changed') end
    for _,tag in ipairs(tags) do local v=value(tag);v.operator='LESSTHAN';v.value=0;sameEngine(a,tag,v);assert(a:evaluateConditionResult({type='NOT',value=v}).status=='match') end
    for _,family in ipairs({'HEALTH','MANA'}) do
        local mana=family=='MANA';local field=mana and 'mana' or 'health';local secondary=field..'operator'
        for _,operation in ipairs({'minimum','average','maximum'}) do
            local raw=mana and ({minimum=10,average=20,maximum=30})[operation] or ({minimum=20,average=35,maximum=50})[operation]
            local deficit=mana and ({minimum=70,average=80,maximum=90})[operation] or ({minimum=50,average=65,maximum=80})[operation]
            for _,amount in ipairs({raw,-deficit}) do local tag='PROXIMITY_'..family;local v=value(tag);v.operation=operation;v.operator='EQUALS';v.value=amount
                assert(sameCall(tag..' exact statistic',definitions[tag],'evaluate',v,{})[2]==true);sameEngine(a,tag,v);assert(a:evaluateConditionResult(v).status=='match')
            end
            local tag='PROXIMITY_'..family..'PCT';local v=value(tag);v.operation=operation;v.operator='EQUALS';v.value=raw/100
            assert(sameCall(tag..' exact percentage',definitions[tag],'evaluate',v,{})[2]==true);sameEngine(a,tag,v);assert(a:evaluateConditionResult(v).status=='match')
        end
        local tag='PROXIMITY_'..family..'_COUNT';local v=value(tag);v.operator='EQUALS';v.value=1;v[field]=mana and -80 or -60;v[secondary]='GREATERTHAN'
        assert(sameCall(tag..' exact deficit count',definitions[tag],'evaluate',v,{})[2]==true);sameEngine(a,tag,v);assert(a:evaluateConditionResult(v).status=='match')
        tag='PROXIMITY_'..family..'PCT_COUNT';v=value(tag);v.operator='EQUALS';v.value=1;v[field]=mana and .1 or .2;v[secondary]='GREATERTHAN'
        assert(sameCall(tag..' exact percent count',definitions[tag],'evaluate',v,{})[2]==true);sameEngine(a,tag,v);assert(a:evaluateConditionResult(v).status=='match')
    end
    for _,mode in ipairs({'missing','restricted','throw','zero-max','uncertain'}) do
        for _,tag in ipairs(tags) do
            local field=tag:find('MANA',1,true) and 'mana' or 'health';local v=value(tag);local original=state.units.party1[field]
            if mode=='missing' then state.units.party1[field]=nil elseif mode=='restricted' then state.units.party1[field]=state.opaque elseif mode=='throw' then state.throw=field elseif mode=='zero-max' then state.units.party1['max'..field]=0 else state.missingPositions=true end
            sameCall(tag..' observed failure',definitions[tag],'evaluate',v,{});sameEngine(a,tag,v)
            if mode~='zero-max' or tag:find('PCT',1,true) then assert(a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable',tag..' unknown negation became actionable') end
            state.units.party1[field]=original;state.units.party1['max'..field]=100;state.throw=nil;state.missingPositions=nil
        end
    end
end)
test('built-ins and editable spatial consumers share native observations per evaluation and refresh later values',function()
    local _,a,state=fixture();copies(a);local group={type='AND',value={}}
    for _,tag in ipairs(tags) do for _,prefix in ipairs({'','COPY_','LEGACY_'}) do local v=value(tag);v.type=prefix..tag;v.value=.05;group.value[#group.value+1]=v end end
    assert(a:evaluateConditionResult(group).status=='match')
    assert(state.calls.health==2 and state.calls.maxhealth==2 and state.calls.mana==2 and state.calls.maxmana==2,'namespace consumers split native observations')
    state.units.party1.health=0;local v=value('PROXIMITY_HEALTH');v.operator='EQUALS';v.value=0;sameEngine(a,'PROXIMITY_HEALTH',v);assert(a:evaluateConditionResult(v).status=='match','next evaluation retained the previous raw observation')
end)
test('spatial operation controls Help and arbitrary saved addon helper APIs stay compatible',function()
    local f,a=fixture();local definitions=copies(a)
    for _,tag in ipairs(tags) do
        local v=value(tag);local expected
        for _,definition in ipairs(definitions[tag]) do
            local parent=a:CreateConditionGroup();local top={GetUserData=function(_,key) if key=='root' then return v elseif key=='funcs' then return {print=function() return 'summary' end} end end,SetStatusText=function() end};parent:SetUserData('top',top)
            definition.widget(parent,0,v)
            local operations=0
            for _,child in ipairs(parent.children) do if child.configure then child.configure();if child.caption and child.caption:GetText()=='Operation' then
                operations=operations+1;assert(child.list==a.math_operations and #child.order==3 and child.order[1]=='average' and child.order[2]=='maximum' and child.order[3]=='minimum' and child:GetValue()==v.operation)
            end end end
            assert(operations==(tag:find('_COUNT',1,true) and 0 or 1) and #parent.children==6,'operation controls changed')
            if expected then assert(#parent.children==expected) else expected=#parent.children end
            a:ReleaseConditionWidget(parent)
            local help=f.widget('Group');definition.help(help);assert(F.text(help):find('upper range bound',1,true))
        end
    end
    for name,group in pairs(groups) do
        local current=a.Functions[group][name];assert(a:ResolveFunctionBinding(binding(name))==current)
        if name=='phrase' or name=='predicate' then assert(a.builtinSourceModules['Functions/presentation.lua'](name)==current)
        else assert(a[name]==current and a.builtinSourceModules[name=='keys' and 'Functions/collections.lua' or 'utils.lua'](name)==current) end
    end
    assert(a:InstallCustomFunction('LEGACY_SPATIAL_STATS',{description='Legacy spatial helpers',args={},returns={},bindings={},code='return addon.isin({x=false},"x"),addon.compare("EQUALS",1,1),addon.nullable(false),addon.compareString("EQUALS","left","right"),addon.keys({a=1})[1]'}))
    local present,equal,boolean,summary,key=assert(a:ResolveFunctionBinding('LEGACY_SPATIAL_STATS'))();assert(present and equal and boolean==false and summary==a.Functions.presentation.compareString('EQUALS','left','right') and key=='a')
end)
finish()
