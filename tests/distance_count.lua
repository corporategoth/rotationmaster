local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;f.units={nameplate1={guid='Creature-1',enemy=true,minimum=0,maximum=5}};f.cap='40';f.calls=0
    a.unitsInRange={['Creature-1']={unit='nameplate1',enemy=true}}
    f.env.UnitExists=function(unit) return f.units[unit]~=nil end
    f.env.UnitGUID=function(unit) return f.units[unit] and f.units[unit].guid end
    f.env.UnitIsEnemy=function(_,unit) return f.units[unit].enemy end
    f.env.C_CVar={GetCVar=function(name) assert(name=='nameplateMaxDistance');return f.cap end}
    f.libraries['LibRangeCheck-3.0'].GetRange=function(_,unit) f.calls=f.calls+1;local u=f.units[unit];if u.fail then error('blocked') end;return u.minimum,u.maximum end
    for _,path in ipairs({'Platform/range.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Core/conditions.lua','Conditions/common.lua','Conditions/spatial.lua'}) do f.load(path) end
    return f,a
end
local function value() return {type='DISTANCE_COUNT',enemy=true,distance=10,operator='EQUALS',value=0} end
local function unavailable(a,v) assert(a:evaluateConditionResult(v).status=='unavailable','unknown observation became actionable');assert(a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable','unknown observation authorized Unless') end
test('uncertain and unobserved ranges invalidate complete distance counts including Unless',function()
    local f,a=fixture();local u=f.units.nameplate1
    for _,bounds in ipairs({{5,15},{0,15},{},{0,math.huge},{20,10},{-1,5},{0/0,5}}) do u.minimum,u.maximum=bounds[1],bounds[2];unavailable(a,value()) end
    u.minimum,u.maximum=0,5;u.fail=true;unavailable(a,value())
end)
test('range boundaries distinguish proven inside outside and synthetic zero',function()
    local f,a=fixture();local v=value();local u=f.units.nameplate1
    u.minimum,u.maximum=5,10;v.value=1;assert(a:evaluateCondition(v))
    u.minimum,u.maximum=10,15;v.value=0;assert(a:evaluateCondition(v))
    u.maximum=nil;assert(a:evaluateCondition(v))
    u.minimum,u.maximum=0,5;v.distance=0;unavailable(a,v)
end)
test('stale vanished and reused unit tokens never count a replacement identity',function()
    local f,a=fixture();local v=value();f.units.nameplate1.guid='Creature-2';assert(a:evaluateCondition(v),'reused token counted replacement')
    f.units.nameplate1=nil;assert(a:evaluateCondition(v),'vanished token counted')
    a.unitsInRange={};assert(a:evaluateCondition(v),'known empty snapshot lost zero')
    a.unitsInRange=nil;unavailable(a,v)
end)
test('live hostility replaces stale snapshot classification without querying excluded ranges',function()
    local f,a=fixture();local v=value();f.units.nameplate1.enemy=false;f.units.nameplate1.maximum=nil
    assert(a:evaluateCondition(v) and f.calls==0,'stale enemy classification measured an excluded ally')
    v.enemy=false;unavailable(a,v)
end)
test('restricted identity hostility and bounds never enter comparisons',function()
    local f,a=fixture();local opaque={};a.Platform.CanReadValue=function(_,v) return v~=opaque end;local u=f.units.nameplate1
    local guid=u.guid;u.guid=opaque;unavailable(a,value());u.guid=guid
    u.enemy=opaque;unavailable(a,value());u.enemy=true
    u.maximum=opaque;unavailable(a,value())
end)
test('missing invalid restricted or failed configured nameplate distance remains unavailable',function()
    local f,a=fixture();local opaque={};a.Platform.CanReadValue=function(_,v) return v~=opaque end
    for _,cap in ipairs({'invalid','0','-5','inf',opaque}) do f.cap=cap;unavailable(a,value()) end
    f.cap=nil;unavailable(a,value());f.env.C_CVar.GetCVar=function() error('blocked') end;unavailable(a,value())
    f.env.C_CVar=nil;f.env.GetCVar=function() return '40' end;local v=value();v.value=1;assert(a:evaluateCondition(v),'legacy GetCVar observation unsupported')
end)
test('unknown distance count chooses neither branch and never falls through',function()
    local f,a=fixture();f.units.nameplate1.minimum,f.units.nameplate1.maximum=5,15
    local rotation={rotation={{id='guard',type='branch',conditions=value(),onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}},{id='tail',type='spell',action=3}}}
    local result=a:EvaluateRotationSequence(rotation,function(v) return a:evaluateConditionResult(v) end,function() error('unknown chose an action') end)
    assert(result.status=='unavailable' and result.suppressAttack)
end)
test('fully observed false counts remain invertible and choose the False arm',function()
    local f,a=fixture();local v=value();assert(a:evaluateConditionResult(v).status=='no-match');assert(a:evaluateConditionResult({type='NOT',value=v}).status=='match')
    local selected;local rotation={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
    local result=a:EvaluateRotationSequence(rotation,function(c) return a:evaluateConditionResult(c) end,function(step) selected=step.id;return false end)
    assert(result.status=='selected' and selected=='no')
end)
test('partial known counts and unreadable live unit observations invalidate the whole scan',function()
    local f,a=fixture();local v=value();v.value=1
    a.unitsInRange['Creature-2']={unit='nameplate2',enemy=true};f.units.nameplate2={guid='Creature-2',enemy=true,minimum=5,maximum=15};unavailable(a,v)
    f.units.nameplate2=nil;a.unitsInRange['Creature-2']=nil
    for _,name in ipairs({'UnitExists','UnitGUID','UnitIsEnemy'}) do
        local saved=f.env[name];f.env[name]=function() error('blocked') end;unavailable(a,v);f.env[name]=nil;unavailable(a,v);f.env[name]=saved
    end
    f.units.nameplate1.guid=nil;unavailable(a,v)
end)
test('repeated count predicates reuse raw range and identity observations',function()
    local f,a=fixture();local calls=0;local guid=f.env.UnitGUID;f.env.UnitGUID=function(unit) calls=calls+1;return guid(unit) end
    local one=value();one.value=1;local two=value();two.distance=20;two.value=1
    assert(a:evaluateCondition({type='AND',value={one,two}}) and f.calls==1 and calls==1,'same-cycle predicates repeated unit observations')
end)
test('authored numeric and hostility fields are validated without querying client settings',function()
    local f,a=fixture();f.env.C_CVar.GetCVar=function() error('validation observed settings') end
    local definition=a.conditionDefinitions.DISTANCE_COUNT;local v=value();assert(definition.valid(nil,v))
    for _,field in ipairs({'distance','value'}) do
        local saved=v[field]
        for _,invalid in ipairs({-1,0/0,math.huge,'10'}) do v[field]=invalid;assert(not definition.valid(nil,v),'invalid '..field..' accepted') end
        v[field]=saved
    end
    v.enemy=nil;assert(not definition.valid(nil,v));v.enemy=1;assert(not definition.valid(nil,v))
    f.env.C_CVar=nil;f.env.GetCVar=nil;v=value();unavailable(a,v)
    f.env.C_CVar={GetCVar=function() return '5' end};unavailable(a,v)
end)
test('restricted public unit inputs are rejected before comparison or provider access',function()
    local f,a=fixture();a.Platform.CanReadValue=function(_,v) return v~='restricted-token' end
    local result,why=a.Platform:GetRangeCheckBounds('restricted-token')
    assert(result==nil and why=='restricted-value' and f.calls==0,'restricted token reached the range provider')
    a.unitsInRange['Creature-1'].unit='restricted-token';unavailable(a,value())
end)
test('public range helper source clones retain stable bindings and actual adapter behavior',function()
    local f,a=fixture();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Core/custom_authoring.lua')
    f.env.loadstring=function(text,name) local fn,why=loadstring(text,name);if fn then setfenv(fn,f.env) end;return fn,why end
    for name,member in pairs({Platform_GetNameplateMaxDistance='GetNameplateMaxDistance',Platform_GetRangeCheckBounds='GetRangeCheckBounds'}) do
        local id='builtin:Platform/range.lua:'..name;local record=assert(a.builtinFunctions[id],'new range helper source missing')
        assert(record.public and a:ResolveFunctionBinding(id)==a.Platform[member],'stable binding detached from actual method')
        assert(a:InstallCustomFunction('COPY_'..name,a:CopySettingsData(record.source)))
        local clone=assert(a:ResolveFunctionBinding('COPY_'..name))
        local result,why=clone(a.Platform,'nameplate1');assert(why==nil)
        if member=='GetRangeCheckBounds' then
            assert(result.minimum==0 and result.maximum==5)
            local read=a.Platform.CanReadValue;a.Platform.CanReadValue=function(_,v) return v~='restricted-token' end
            result,why=clone(a.Platform,'restricted-token');assert(result==nil and why=='restricted-value','compiled helper lost the restricted input guard');a.Platform.CanReadValue=read
        else assert(result==40) end
    end
    local source=assert(a:GetBuiltinConditionSource('DISTANCE_COUNT'));local copy=assert(a:CompileCustomCondition('COPY_DISTANCE_COUNT',source));local v=value();v.value=1
    assert(copy.evaluate(v,{})==a.conditionDefinitions.DISTANCE_COUNT.evaluate(v,{}),'compiled condition changed its callback contract')
    local legacy=assert(a:ResolveFunctionBinding('builtin:Conditions/spatial.lua:rcf'));local minimum,maximum=legacy('nameplate1');assert(minimum==0 and maximum==5,'legacy tuple binding changed')
end)
test('Distance Count Help explains observed snapshot and unknown counts',function()
    local f,a=fixture();local frame=f.widget('Group');a.conditionDefinitions.DISTANCE_COUNT.help(frame);local text=F.text(frame)
    assert(text:find('observed',1,true) and text:find('unavailable',1,true) and not text:find('addon.units',1,true))
end)
test('incombat counts only units that are fighting, in the snapshot route and the nameplate route',function()
    local f,a=fixture();local u=f.units.nameplate1;u.minimum,u.maximum=0,5
    local throws=false
    f.env.UnitAffectingCombat=function(unit) if throws then error('blocked') end;return f.units[unit].combat end
    local original=a.Platform.CanReadValue;local opaque={}
    local function count(n,extra) local v=value();v.operator='EQUALS';v.value=n;for k,x in pairs(extra or {}) do v[k]=x end;return v end
    for _,route in ipairs({'snapshot','nameplates'}) do
        if route=='nameplates' then a.unitsInRange=nil;a.nameplateUnits={nameplate1=true} end
        u.combat=false
        assert(a:evaluateCondition(count(1)),route..': a plate counts without the option')
        assert(a:evaluateCondition(count(0,{incombat=true})),route..': an idle enemy was counted as in combat')
        assert(a:evaluateCondition(count(1,{incombat=false})),route..': an explicit false is the plain count')
        u.combat=true;assert(a:evaluateCondition(count(1,{incombat=true})),route..': a fighting enemy was not counted')
        u.combat=nil;assert(a:evaluateCondition(count(0,{incombat=true})),route..': nil is not fighting')
        throws=true;unavailable(a,count(1,{incombat=true}));assert(a:evaluateCondition(count(1)),route..': without the option combat is never read');throws=false
        a.Platform.CanReadValue=function(_,x) return x~=opaque end
        u.combat=opaque;unavailable(a,count(1,{incombat=true}));assert(a:evaluateCondition(count(1)),route..': a hidden combat state is not read without the option')
        a.Platform.CanReadValue=original
    end
    local def=a.conditionDefinitions.DISTANCE_COUNT
    assert(def.valid(0,count(1,{incombat=true})) and def.valid(0,count(1,{incombat=false})) and not def.valid(0,count(1,{incombat='yes'})))
    assert(def.print(0,count(1,{incombat=true})):find('in combat',1,true) and not def.print(0,count(1)):find('in combat',1,true))
    def.help({AddChild=function() end})
end)
finish()
