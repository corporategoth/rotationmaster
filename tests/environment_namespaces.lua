local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local tags={'SELF_LEVEL','PVP','ZONEPVP','INSTANCE','OUTDOORS'}
local owners={isin='values',compare='values',nullable='presentation',compareString='presentation',playerize='presentation',getCached='cache',deepcopy='collections',keys='collections'}
local counts={isin=4,compare=1,nullable=4,compareString=1,playerize=1,getCached=4,deepcopy=2,keys=2}
local function path(name) return 'Functions.'..owners[name]..'.'..name end
local function identity(name) return 'builtin:'..(owners[name]=='collections' and 'Functions/collections.lua' or 'utils.lua')..':'..name end
local function fixture()
    local f=F.new();local a,e=f.addon,f.env
    local state={level=20,exists=true,pvp=false,zone=nil,inInstance=false,instance='none',outdoors=true,calls={},arguments={}}
    local function call(name,...)
        state.calls[name]=(state.calls[name] or 0)+1;state.arguments[name]={n=select('#',...),...}
        if state.throw==name then error('native '..name..' failed') end
    end
    e.UnitLevel=function(...) call('level',...);return state.level end
    e.UnitExists=function(...) call('exists',...);return state.exists end
    e.UnitIsPVP=function(...) call('pvp',...);return state.pvp end
    e.GetZonePVPInfo=function(...) call('zone',...);return state.zone,nil,'ignored' end
    e.IsInInstance=function(...) call('instance',...);return state.inInstance,state.instance,nil,'tail' end
    e.IsOutdoors=function(...) call('outdoors',...);return state.outdoors end
    a.longtermCache={}
    for _,file in ipairs({'Core/conditions.lua','Conditions/misc.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(file) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    return f,a,state
end
local selfLevelRepair={original="\n"..[=[
        return Functions.values.compare(value.operator, Functions.cache.getCached(addon.longtermCache, UnitLevel, "player"), value.value)
    ]=],repaired="\n"..[=[
        local level,reason=addon:GetConditionUnitLevel("player",cache)
        if level==nil then return nil,reason end
        if level==false then return false end
        return Functions.values.compare(value.operator, level, value.value)
    ]=]}
local function copies(a,legacy)
    local result={}
    for _,tag in ipairs(tags) do
        local source=assert(a:GetBuiltinConditionSource(tag));local prefix=legacy and 'OLD_' or 'COPY_'
        if legacy then
            for _,callback in ipairs({'valid','evaluate','print','widget','help'}) do
                if source[callback] then for name in pairs(owners) do source[callback]=source[callback]:gsub(path(name):gsub('%.','%%.'),'addon.'..name) end end
            end
            for name in pairs(owners) do source.bindings[path(name)]=nil end
        end
        local compiled,why=a:CompileCustomCondition(prefix..tag,source);assert(compiled,tostring(why and why.reason))
        result[tag]=compiled;a:RegisterCondition(prefix..tag,compiled)
    end
    return result
end
local function equal(a,tag,value)
    for _,prefix in ipairs({'','COPY_','OLD_'}) do
        local copy=a:CopySettingsData(value);copy.type=prefix..tag
        for _,negate in ipairs({false,true}) do
            local original=a:CopySettingsData(value);original.type=tag
            local left=negate and {type='NOT',value=original} or original
            local right=negate and {type='NOT',value=copy} or copy
            local x,y=a:evaluateConditionResult(left),a:evaluateConditionResult(right)
            assert(x.status==y.status and x.reason==y.reason,tag..' evaluation differed')
            assert(a:printCondition(left,0)==a:printCondition(right,0),tag..' wording differed')
        end
    end
end
test('environment callbacks select current direct calls with eight exact owning leaves',function()
    local f,a=fixture();local manifest=assert(a.builtinCallbackBindings and a.builtinCallbackBindings['Conditions/misc.lua'],'environment namespace manifest missing')
    local leaves=0;for alias,id in pairs(manifest) do
        leaves=leaves+1;local name=alias:match('([%w_]+)$');assert(alias==path(name) and id==identity(name))
        assert(a:ResolveFunctionBinding(id)==a.Functions[owners[name]][name])
    end;assert(leaves==8)
    local found={};for _,tag in ipairs(tags) do local src=assert(a:GetBuiltinConditionSource(tag));assert(not src.bindings.Functions)
        for _,callback in ipairs({'valid','evaluate','print','widget','help'}) do if src[callback] then for name in pairs(owners) do
            local _,number=src[callback]:gsub(path(name):gsub('%.','%%.')..'%(','');found[name]=(found[name] or 0)+number
            assert(not src[callback]:find('addon.'..name..'(',1,true),'legacy call remains')
        end end end
    end
    for name,count in pairs(counts) do assert(found[name]==count,name..' count changed') end
    assert(not f.env.Functions)
end)
test('only the explicitly repaired SELF_LEVEL and PVP evaluators differ from prior environment sources',function()
    local _,a=fixture();local baseline={}
    for _,tag in ipairs(tags) do local source=assert(a:GetBuiltinConditionSource(tag))
        if tag=='SELF_LEVEL' then
            assert(source.evaluate==selfLevelRepair.repaired and table.concat(source.parameters.evaluate,',')=='value,cache')
            source.evaluate=selfLevelRepair.original;source.parameters.evaluate={'value'}
        end
        if tag=='PVP' then
            assert(source.evaluate=='\n        return Functions.cache.getCached(cache, addon.Platform.GetUnitFlagObservation, addon.Platform, value.unit, "pvp")\n    ','unexpected PVP evaluator repair')
            source.evaluate='\n        if not Functions.cache.getCached(cache, UnitExists, value.unit) then return false end\n        return Functions.cache.getCached(cache, UnitIsPVP, value.unit)\n    '
        end
        baseline[tag]=source
    end
    assert(a:FunctionSourceHash(baseline)=='4eb1d87c','unrelated environment source changed')
end)
test('level operators zone kinds instance tuples and unit flags agree for registered canonical and legacy-shaped copies',function()
    local _,a,s=fixture();copies(a);copies(a,true)
    for _,operator in ipairs({'LESSTHAN','LESSTHANOREQUALS','GREATERTHAN','GREATERTHANOREQUALS','EQUALS','NOTEQUALS','DIVISIBLE','INVALID'}) do
        for _,number in ipairs({0,1,19,20,21,-1}) do equal(a,'SELF_LEVEL',{operator=operator,value=number}) end
    end
    equal(a,'SELF_LEVEL',{})
    for _,unit in ipairs({'player','target','pet','missing'}) do for _,exists in ipairs({false,true}) do for _,flag in ipairs({false,true}) do
        s.exists=exists;s.pvp=flag;equal(a,'PVP',{unit=unit})
    end end end
    for _,kind in ipairs({'none','party','raid','arena','pvp','scenario','unknown'}) do for _,present in ipairs({false,true}) do
        s.inInstance=present;s.instance=kind
        for _,requested in ipairs({'none','party','raid','unknown'}) do equal(a,'INSTANCE',{value=requested}) end
    end end
    for _,zone in ipairs({'friendly','hostile','contested','arena','sanctuary','combat'}) do s.zone=zone;equal(a,'ZONEPVP',{value=zone});equal(a,'ZONEPVP',{}) end
    s.zone=nil;equal(a,'ZONEPVP',{});equal(a,'ZONEPVP',{value='hostile'})
    for _,outside in ipairs({false,true}) do s.outdoors=outside;equal(a,'OUTDOORS',{}) end
end)
test('canonical and old copies share exact cache observations including longterm level and nil multi-return slots',function()
    local _,a,s=fixture();local canonical=copies(a);local old=copies(a,true)
    for _,tag in ipairs(tags) do
        local value={unit='target',operator='EQUALS',value=tag=='SELF_LEVEL' and 20 or nil};local cache={}
        local expected=a.conditionDefinitions[tag].evaluate(value,cache);local calls=a:CopySettingsData(s.calls)
        assert(canonical[tag].evaluate(value,cache)==expected and old[tag].evaluate(value,cache)==expected)
        assert(a:SettingsDataEqual(calls,s.calls),tag..' did not share observation cache')
    end
    assert(s.arguments.level.n==1 and s.arguments.level[1]=='player')
    assert(s.arguments.exists.n==1 and s.arguments.exists[1]=='target' and s.arguments.pvp[1]=='target')
    assert(s.arguments.zone.n==0 and s.arguments.instance.n==0 and s.arguments.outdoors.n==0)
    local one,two,three,four=a.Functions.cache.getCached({},function() return false,nil,'tail',nil end)
    assert(one==false and two==nil and three=='tail' and four==nil)
    s.calls={};a.longtermCache={};s.inInstance=true;s.instance='party'
    assert(canonical.INSTANCE.evaluate({value='party'},{})==true)
    assert(old.INSTANCE.evaluate({value='none'},{})==false)
    s.exists=false;s.calls={};assert(canonical.PVP.evaluate({unit='target'},{})==false and not s.calls.pvp)
end)
test('normalized level and PVP failures stay unavailable while other raw error boundaries remain exact',function()
    local _,a,s=fixture();copies(a);copies(a,true)
    for _,entry in ipairs({{'SELF_LEVEL','level'},{'PVP','exists'},{'PVP','pvp'},{'ZONEPVP','zone'},{'INSTANCE','instance'},{'OUTDOORS','outdoors'}}) do
        s.throw=entry[2];s.exists=true
        for _,prefix in ipairs({'','COPY_','OLD_'}) do
            a.longtermCache={};local node={type=prefix..entry[1],unit='target',operator='EQUALS',value=entry[1]=='SELF_LEVEL' and 20 or nil}
            local ok,why=pcall(a.evaluateConditionResult,a,{type='NOT',value=node})
            if entry[1]=='PVP' then assert(ok and why.status=='unavailable' and why.reason=='api-error') elseif entry[1]=='SELF_LEVEL' then assert(ok and why.status=='unavailable') else assert(not ok and tostring(why):find('native '..entry[2]..' failed',1,true),entry[1]..' error boundary changed') end
            a.longtermCache={};ok,why=pcall(a.evaluateConditionResult,a,{type='AND',value={node,{type='OUTDOORS'}}})
            if entry[1]=='PVP' then assert(ok and why.status=='unavailable' and why.reason=='api-error') elseif entry[1]=='SELF_LEVEL' then assert(ok and why.status=='unavailable') else assert(not ok and tostring(why):find('native '..entry[2]..' failed',1,true)) end
        end
    end
end)
test('namespace widgets preserve detached unit options dropdown ordering and original capture values',function()
    local f,a=fixture();local canonical=copies(a);local old=copies(a,true)
    for _,definition in ipairs({a.conditionDefinitions.PVP,canonical.PVP,old.PVP}) do
        local parent=f.widget('Group');local top=f.widget('Frame');top:SetUserData('root',{});top:SetUserData('funcs',{print=function() return 'summary' end});parent:SetUserData('top',top)
        local options;a.Widget_UnitWidget=function(_,_,values) options=values;return f.widget('Dropdown') end
        definition.widget(parent,0,{unit='target'});assert(options~=a.units and options.pet==nil and options.player==a.units.player and a.units.pet~=nil)
    end
    for _,tag in ipairs({'ZONEPVP','INSTANCE'}) do for _,definition in ipairs({a.conditionDefinitions[tag],canonical[tag],old[tag]}) do
        local parent=f.widget('Group');local top=f.widget('Frame');top:SetUserData('root',{});top:SetUserData('funcs',{print=function() return 'summary' end});parent:SetUserData('top',top)
        definition.widget(parent,0,{});local dropdown=assert(parent.children[1]);dropdown.configure();assert(dropdown.value=='')
        local expected=tag=='ZONEPVP' and a:CopySettingsData(a.zonepvp) or a.instances;if tag=='ZONEPVP' then expected['']='no PVP' end
        assert(a:SettingsDataEqual(dropdown.list,expected));assert(a:SettingsDataEqual(dropdown.order,a.keys(expected)))
    end end
    for name,hash in pairs({color='89a5436e',helpers='3ab28a24'}) do
        local id='builtin:Conditions/misc.lua:'..name
        assert(a:ResolveFunctionBinding(id)==a.builtinSourceModules['Conditions/misc.lua'](name))
        assert(a:FunctionSourceHash(assert(a.builtinFunctions[id]).source)==hash,'unchanged capture metadata drifted')
    end
end)
finish()
