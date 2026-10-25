local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'HEALTH','HEALTHPCT','MANA','MANAPCT','POWER','POWERPCT','POINT','RUNE','RUNE_COOLDOWN','TT_HEALTH','TT_HEALTHPCT'}
local owners={isin='values',compare='values',getCached='cache',nullable='presentation',compareString='presentation'}
local function path(name) return 'Functions.'..owners[name]..'.'..name end
local function fixture(product,expansion,class)
    local f=F.new(product or 11,expansion or 2,class or 'DEATHKNIGHT');local a,e=f.addon,f.env
    local s={calls={},trace={},exists=true,health=70,maximum=100,power=20,powerMaximum=100,powerType=3,class=class or 'DEATHKNIGHT',guid='GUID-target',now=100,runes={1,1,2,2,3,3}}
    local function call(name,...)
        s.calls[name]=(s.calls[name] or 0)+1;s.trace[#s.trace+1]={name=name,n=select('#',...),...}
        if s.throw==name then error('native '..name..' failed') end
    end
    e.Enum.PowerType.Mana=0;e.GetTime=function() call('time');return s.now end
    e.UnitExists=function(unit) call('exists',unit);return s.exists end
    e.UnitHealth=function(unit) call('health',unit);return s.health end;e.UnitHealthMax=function(unit) call('maximum',unit);return s.maximum end
    e.UnitPower=function(unit,kind) call('power',unit,kind);return s.power end;e.UnitPowerMax=function(unit,kind) call('powerMaximum',unit,kind);return s.powerMaximum end
    e.UnitPowerType=function(unit) call('powerType',unit);return s.powerType end
    e.UnitClass=function(unit) call('class',unit);return 'Localized class',s.class,6 end
    e.UnitGUID=function(unit) call('guid',unit);return s.guid end
    e.GetRuneType=function(index) call('runeType',index);return s.runes[index] end
    e.GetRuneCooldown=function(index) call('runeCooldown',index);return s.runeStart or 98,s.runeDuration or 10,index%2==1 end
    a.db.profile.damage_history=10;a.damageHistory={['GUID-target']={damage={{time=100,value=10},{time=99,value=12},{time=97,value=8}},heals={{time=100,value=2},{time=97,value=1}}}}
    a.warn=function() end
    for _,file in ipairs({'Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(file) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    s.calls={};s.trace={};return f,a,s
end
local function node(tag)
    return {type=tag,unit='target',operator='GREATERTHAN',value=tag:find('PCT',1,true) and .5 or 1,rune=1,health=tag=='TT_HEALTHPCT' and .5 or 50,mode='both'}
end
local function legacySource(a,source)
    local old=a:CopySettingsData(source)
    for _,callback in ipairs({'valid','evaluate','print'}) do for name in pairs(owners) do old[callback]=old[callback]:gsub(path(name):gsub('%.','%%.')..'%(','addon.'..name..'(') end end
    for alias in pairs(old.bindings) do if alias:match('^Functions%.') then old.bindings[alias]=nil end end
    return old
end
-- Only these two observations intentionally changed in the readiness repair.
-- Restore their exact historical source solely for the existing whole-corpus byte pin.
local originalHealthEvaluates={
    HEALTH="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local cur = addon.getCached(cache, UnitHealth, value.unit)
        if value.value < 0 then
            local max = addon.getCached(cache, UnitHealthMax, value.unit)
            return addon.compare(value.operator, (max-cur), -value.value)
        else
            return addon.compare(value.operator, cur, value.value)
        end
    ]=],
    HEALTHPCT="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local health = addon.getCached(cache, UnitHealth, value.unit) / addon.getCached(cache, UnitHealthMax, value.unit) * 100;
        return addon.compare(value.operator, health, value.value * 100)
    ]=],
}
local repairedHealthEvaluates={
    HEALTH="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitHealthObservation,addon.Platform,value.unit,value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            return Functions.values.compare(value.operator, (record.maximum-record.current), -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    ]=],
    HEALTHPCT="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitHealthObservation,addon.Platform,value.unit,true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-health-maximum" end
        local health = record.current / record.maximum * 100
        if health~=health or health==math.huge or health==-math.huge then return nil,"invalid-health-percentage" end
        return Functions.values.compare(value.operator, health, value.value * 100)
    ]=],
}
local originalPowerEvaluates={
    MANA="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local cur = addon.getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana)
        if value.value < 0 then
            local max = addon.getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana)
            return addon.compare(value.operator, (max-cur), -value.value)
        else
            return addon.compare(value.operator, cur, value.value)
        end
    ]=],
    MANAPCT="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        local mana = addon.getCached(cache, UnitPower, value.unit, Enum.PowerType.Mana) / addon.getCached(cache, UnitPowerMax, value.unit, Enum.PowerType.Mana) * 100;
        return addon.compare(value.operator, mana, value.value * 100)
    ]=],
    POWER="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = addon.getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end

        local cur = addon.getCached(cache, UnitPower, value.unit, power)
        if value.value < 0 then
            local max = addon.getCached(cache, UnitPowerMax, value.unit, power)
            return addon.compare(value.operator, (max-cur), -value.value)
        else
            return addon.compare(value.operator, cur, value.value)
        end
    ]=],
    POWERPCT="\n"..[=[
        if not addon.getCached(cache, UnitExists, value.unit) then return false end
        -- Cannot use longterm cache for player as different forms may have different powers
        local power = addon.getCached(cache, UnitPowerType, value.unit)

        if (power == nil) then
            return false
        end
        local mana = addon.getCached(cache, UnitPower, value.unit, power) / addon.getCached(cache, UnitPowerMax, value.unit, power) * 100;
        return addon.compare(value.operator, mana, value.value)
    ]=],
}
local repairedPowerEvaluates={
    MANA="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"mana",value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            return Functions.values.compare(value.operator, (record.maximum-record.current), -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    ]=],
    MANAPCT="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"mana",true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-power-maximum" end
        local percentage = record.current / record.maximum * 100
        if percentage~=percentage or percentage==math.huge or percentage==-math.huge then return nil,"invalid-power-percentage" end
        return Functions.values.compare(value.operator, percentage, value.value * 100)
    ]=],
    POWER="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"current",value.value<0)
        if not record then return nil,reason end
        if not record.exists then return false end
        if value.value < 0 then
            local deficit = record.maximum-record.current
            if deficit~=deficit or deficit==math.huge or deficit==-math.huge then return nil,"invalid-power-deficit" end
            return Functions.values.compare(value.operator, deficit, -value.value)
        else
            return Functions.values.compare(value.operator, record.current, value.value)
        end
    ]=],
    POWERPCT="\n"..[=[
        local record,reason=Functions.cache.getCached(cache,addon.Platform.GetUnitPowerObservation,addon.Platform,value.unit,"current",true)
        if not record then return nil,reason end
        if not record.exists then return false end
        if record.maximum<=0 then return nil,"invalid-power-maximum" end
        local percentage = record.current / record.maximum * 100
        if percentage~=percentage or percentage==math.huge or percentage==-math.huge then return nil,"invalid-power-percentage" end
        return Functions.values.compare(value.operator, percentage, value.value * 100)
    ]=],
}
local function copies(a)
    local current,old={},{}
    for _,tag in ipairs(tags) do if a.conditionDefinitions[tag] then
        local source=assert(a:GetBuiltinConditionSource(tag));current[tag]=assert(a:CompileCustomCondition('COPY_'..tag,source));a:RegisterCondition('COPY_'..tag,current[tag])
        old[tag]=assert(a:CompileCustomCondition('LEGACY_'..tag,legacySource(a,source)));a:RegisterCondition('LEGACY_'..tag,old[tag])
    end end
    return current,old
end
local function observed(s)
    local result={};for name,n in pairs(s.calls) do if name~='time' and name~='realHealth' then result[name]=n end end;return result
end
local function sameRun(a,actual,copy,legacy,value,cache)
    local function run(fn)
        local ok,result,reason=pcall(fn,value,cache or {},100)
        if ok then return {ok=true,result=result,reason=reason} end
        return {ok=false}
    end
    local first=run(actual.evaluate);assert(a:SettingsDataEqual(first,run(copy.evaluate)) and a:SettingsDataEqual(first,run(legacy.evaluate)),value.type..' evaluator result/error boundary changed')
    return first
end
local function unavailable(a,value)
    local result=a:evaluateConditionResult(value);assert(result.status=='unavailable')
    assert(a:evaluateConditionResult({type='NOT',value=value}).status=='unavailable')
    local body={rotation={{id='guard',type='branch',conditions=value,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    assert(a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() error('unavailable statistic selected a branch') end).status=='unavailable')
end

test('eleven statistics namespace substitutions retain their exact historical104 calls outside approved readiness repairs',function()
    local f,a=fixture();local manifest=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/stats.lua'],'statistics canonical bindings missing');local leaves=0
    for alias,id in pairs(manifest) do local name=alias:match('([%w_]+)$');leaves=leaves+1;assert(alias==path(name) and id=='builtin:utils.lua:'..name and a:ResolveFunctionBinding(id)==a.Functions[owners[name]][name]) end;assert(leaves==5)
    local totals={isin=0,compare=0,getCached=0,nullable=0,compareString=0};local callbacks=0
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag));assert(not source.bindings.Functions,'opaque namespace table capture')
        if tag=='POINT' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_point_repairs.lua')(source.evaluate,true) end
        if tag=='RUNE' or tag=='RUNE_COOLDOWN' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_rune_repairs.lua')(source.evaluate,tag) end
        if tag=='TT_HEALTH' or tag=='TT_HEALTHPCT' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_health_forecast_repairs.lua')(source.evaluate,tag,true) end
        for _,callback in ipairs({'valid','evaluate','print'}) do callbacks=callbacks+1;for name in pairs(owners) do
            local _,n=source[callback]:gsub(path(name):gsub('%.','%%.')..'%(','');totals[name]=totals[name]+n;assert(not source[callback]:find('addon.'..name..'(',1,true))
        end end
    end
    assert(callbacks==33 and totals.isin==22 and totals.compare==17 and totals.getCached==23 and totals.nullable==27 and totals.compareString==15 and not f.env.Functions)
end)
test('legacy-shaped full sources retain every original native expression field Help body parameter and private capture hash',function()
    local _,a=fixture();local baseline={};for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag))
        if tag=='POINT' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_point_repairs.lua')(source.evaluate,true) end
        if tag=='RUNE' or tag=='RUNE_COOLDOWN' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_rune_repairs.lua')(source.evaluate,tag) end
        if tag=='TT_HEALTH' or tag=='TT_HEALTHPCT' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_health_forecast_repairs.lua')(source.evaluate,tag,true) end
        if tag=='TT_HEALTH' or tag=='TT_HEALTHPCT' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_trend_consumer_qualifiers.lua')(source.evaluate,tag,true) end
        if tag=='TT_HEALTH' then source=a:CopySettingsData(source);source.evaluate=dofile('tests/fixtures/restore_health_forecast_deficit.lua')(source.evaluate,tag) end
        if tag=='POWER' or tag=='POINT' then source=a:CopySettingsData(source);source.print=dofile('tests/fixtures/restore_resource_deficit_summary_repairs.lua')(source.print,tag) end
        baseline[tag]=legacySource(a,source)
        if tag=='RUNE_COOLDOWN' then baseline[tag].evaluate=dofile('tests/fixtures/restore_rounding_qualifiers.lua')(baseline[tag].evaluate,tag,true) end
        if originalHealthEvaluates[tag] then
            assert(a:GetBuiltinConditionSource(tag).evaluate==repairedHealthEvaluates[tag],tag.." changed beyond the explicit health repair")
            baseline[tag].evaluate=originalHealthEvaluates[tag]
        end
        if originalPowerEvaluates[tag] then
            local source=a:GetBuiltinConditionSource(tag)
            assert(source.evaluate==repairedPowerEvaluates[tag] and table.concat(source.parameters.evaluate,',')=='value,cache',tag.." changed beyond the explicit power repair")
            baseline[tag].evaluate=originalPowerEvaluates[tag]
        end
        baseline[tag].icon='Interface\\AddOns\\rotationmaster\\Assets\\Conditions\\'..(tag=='RUNE_COOLDOWN' and 'time' or 'resources')
    end
    assert(a:FunctionSourceHash(baseline)=='2289ce64','source changed beyond the selected call substitutions')
    for name,hash in pairs({color='89107d36',helpers='c19dbbac'}) do local id='builtin:Conditions/stats.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/stats.lua'](name)) end
end)
test('registered and canonical and legacy clones agree on validation and positive negative summary matrices',function()
    local _,a=fixture();local current,old=copies(a)
    for _,tag in ipairs(tags) do for _,unit in ipairs({'player','target','pet','missing'}) do for _,operator in ipairs({'EQUALS','NOTEQUALS','LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','DIVISIBLE','UNKNOWN'}) do for _,amount in ipairs({-5,0,.5,1,2,50,101}) do
        local value=node(tag);value.unit=unit;value.operator=operator;value.value=amount
        local valid=a.conditionDefinitions[tag].valid(0,value);assert(current[tag].valid(0,value)==valid and old[tag].valid(0,value)==valid)
        for _,negated in ipairs({false,true}) do local words=a.conditionDefinitions[tag].print(0,value,negated);assert(current[tag].print(0,value,negated)==words and old[tag].print(0,value,negated)==words) end
    end end end end
    for _,tag in ipairs(tags) do local value=node(tag);value.value=nil;value.health=nil;value.rune=nil;value.unit=nil
        assert(current[tag].valid(0,value)==a.conditionDefinitions[tag].valid(0,value));assert(current[tag].print(0,value)==old[tag].print(0,value))
    end
end)
test('all native statistics observations retain exact argument tuples and share caches across clone forms',function()
    local _,a,s=fixture();local current,old=copies(a)
    for _,tag in ipairs(tags) do local value=node(tag);local cache={};local actual=a.conditionDefinitions[tag].evaluate(value,cache,100);local before=observed(s)
        assert(current[tag].evaluate(value,cache,100)==actual and old[tag].evaluate(value,cache,100)==actual and a:SettingsDataEqual(before,observed(s)),tag..' repeated a cached observation')
    end
    local saw={};for _,entry in ipairs(s.trace) do
        if entry.name=='power' or entry.name=='powerMaximum' then assert(entry.n==2 and entry[1]=='target' and (entry[2]==0 or entry[2]==3 or entry[2]==5));saw[entry[2]]=true
        elseif entry.name=='runeType' or entry.name=='runeCooldown' then assert(entry.n==1 and entry[1]>=1 and entry[1]<=6)
        elseif entry.name~='time' then assert(entry.n==1 and entry[1]=='target') end
    end
    assert(saw[0] and saw[3],'mana and form resource arguments were lost')
    -- A progression Death Knight has no POINT resource: runes are RUNE conditions (tests/progression_points.lua).
    assert(not saw[5],'progression Death Knight POINT read Runes through UnitPower')
end)
test('deficit percentage trend RealMobHealth and rune calculations preserve their existing edge semantics',function()
    for _,real in ipairs({false,true}) do local f,a,s=fixture();local current,old=copies(a)
        if real then f.env.RealMobHealth={GetUnitHealth=function(unit) assert(unit=='target');s.calls.realHealth=(s.calls.realHealth or 0)+1;return s.realHealth,s.realMaximum end} end
        for _,tag in ipairs(tags) do for _,amount in ipairs({-5,0,.5,1,5,75}) do for _,operator in ipairs({'EQUALS','GREATERTHAN','LESSTHAN'}) do
            local value=node(tag);value.value=amount
            for _,mode in ipairs({'both','noheals','nodmg'}) do value.mode=mode;s.realHealth=80;s.realMaximum=120;sameRun(a,a.conditionDefinitions[tag],current[tag],old[tag],value) end
        end end end
        s.realHealth=nil;s.realMaximum=150;sameRun(a,a.conditionDefinitions.TT_HEALTHPCT,current.TT_HEALTHPCT,old.TT_HEALTHPCT,node('TT_HEALTHPCT'))
        local value=node('POWERPCT');value.operator='EQUALS';value.value=.2;assert(current.POWERPCT.evaluate(value,{})==true,'repaired power percentage did not use its stored fractional threshold')
        value=node('RUNE');value.operator='EQUALS';value.value=1;assert(current.RUNE.evaluate(value,{})==true)
        value=node('RUNE_COOLDOWN');value.operator='EQUALS';value.value=8;assert(current.RUNE_COOLDOWN.evaluate(value,{})==true)
    end
end)
test('player class remains longterm-cached while target class and current power type remain per-observation',function()
    local _,a,s=fixture();local current,old=copies(a);local value=node('POINT');value.unit='player'
    sameRun(a,a.conditionDefinitions.POINT,current.POINT,old.POINT,value,{});assert(s.calls.class==1)
    s.class='MAGE';sameRun(a,a.conditionDefinitions.POINT,current.POINT,old.POINT,value,{});assert(s.calls.class==1)
    value.unit='target';sameRun(a,a.conditionDefinitions.POINT,current.POINT,old.POINT,value,{});assert(s.calls.class==2)
    sameRun(a,a.conditionDefinitions.POINT,current.POINT,old.POINT,value,{});assert(s.calls.class==3)
    value=node('POWER');sameRun(a,a.conditionDefinitions.POWER,current.POWER,old.POWER,value,{});local reads=s.calls.powerType;s.powerType=1
    sameRun(a,a.conditionDefinitions.POWER,current.POWER,old.POWER,value,{});assert(s.calls.powerType==reads+1)
end)
test('known missing units or power identities remain invertible while native errors and invalid arithmetic stay unavailable',function()
    for _,mode in ipairs({'nil-health','nil-maximum','throw-health','missing-api','opaque-health','nil-exists','nil-power-type'}) do local f,a,s=fixture();copies(a)
        local opaque={};f.env.canaccessvalue=function(value) return not rawequal(value,opaque) end
        local tag='HEALTH';if mode=='nil-power-type' then s.powerType=nil;tag='POWER' elseif mode=='nil-exists' then s.exists=nil elseif mode=='nil-health' then s.health=nil elseif mode=='nil-maximum' then s.maximum=nil;tag='HEALTHPCT' elseif mode=='throw-health' then s.throw='health' elseif mode=='missing-api' then f.env.UnitHealth=nil else s.health=opaque end
        for _,prefix in ipairs({'','COPY_','LEGACY_'}) do local value=node(tag);value.type=prefix..tag;unavailable(a,value) end
    end
    for _,mode in ipairs({'false-exists','nil-class'}) do local _,a,s=fixture();copies(a)
        if mode=='false-exists' then s.exists=false else s.class=nil end
        local tag=mode=='nil-class' and 'POINT' or 'HEALTH'
        for _,prefix in ipairs({'','COPY_','LEGACY_'}) do local value=node(tag);value.type=prefix..tag
            if mode=='nil-class' then unavailable(a,value)
            else assert(a:evaluateConditionResult(value).status=='no-match' and a:evaluateConditionResult({type='NOT',value=value}).status=='match') end
        end
    end
end)
test('registration branches and legacy addon helper consumers retain their original public contracts',function()
    for _,case in ipairs({{1,12,'DEATHKNIGHT',false},{5,1,'DEATHKNIGHT',false},{11,2,'SHAMAN',false},{11,2,'DEATHKNIGHT',true}}) do
        local _,a=fixture(case[1],case[2],case[3]);assert((a.conditionDefinitions.RUNE~=nil)==case[4] and (a.conditionDefinitions.RUNE_COOLDOWN~=nil)==case[4])
    end
    local _,a=fixture();assert(a:InstallCustomFunction('SAVED_STATS_HELPERS',{description='Historical helper consumer',args={},returns={},bindings={},code='return addon.isin({x=false},"x"),addon.compare("EQUALS",1,1),addon.nullable(false),addon.getCached({},function() return 3,nil,"tail" end)'}))
    local member,equal,value,first,second,tail=a:ResolveFunctionBinding('SAVED_STATS_HELPERS')();assert(member and equal and value==false and first==3 and second==nil and tail=='tail')
end)
finish()
