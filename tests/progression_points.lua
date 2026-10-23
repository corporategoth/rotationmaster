-- Era and progression POINT: a resource the client's expansion, the class and
-- (Mists of Pandaria) the player's specialization really have, else
-- unavailable, never the Combo Points fallback that answers a confident 0.
-- Mists sources: Gethe/wow-ui-source classic 45eb466ddb (5.5.4.70531),
-- Blizzard_UnitFrame/Mists PaladinPowerBar, MonkHarmonyBar, PriestBar,
-- ShardBar; SPEC_* indices and MAX_POWER_PER_EMBER = 10 in
-- Blizzard_FrameXMLBase/Classic/Constants.lua.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()

local OPAQUE=setmetatable({},{__tostring=function() return 'opaque' end})
local RETAIL,ERA,TBC,WRATH,CATA,MISTS=1,2,5,11,14,19
-- PowerTypeConstantsDocumentation.lua at 5.5.4.70531.
local POWER={Mana=0,Rage=1,Focus=2,Energy=3,ComboPoints=4,Runes=5,RunicPower=6,SoulShards=7,LunarPower=8,HolyPower=9,
    Alternate=10,Maelstrom=11,Chi=12,Insanity=13,BurningEmbers=14,DemonicFury=15,ArcaneCharges=16,Fury=17,Pain=18,Essence=19,
    Balance=26,ShadowOrbs=28}
local CLASSES={'DEATHKNIGHT','DRUID','HUNTER','MAGE','MONK','PALADIN','PRIEST','ROGUE','SHAMAN','WARLOCK','WARRIOR'}

local function fixture(project,expansion,class,spec)
    local f=F.new(project,expansion,class or 'ROGUE');local a,e=f.addon,f.env
    local types={};for name,id in pairs(POWER) do types[name]=id end;e.Enum.PowerType=types
    local s={calls={},class=class or 'ROGUE',exists=true,current=3,maximum=5,combo=2,spec=spec}
    local function call(k,...) s.calls[#s.calls+1]={k,n=select('#',...),...};if s.throw==k then error('native failure') end;return s[k] end
    e.canaccessvalue=function(v) return not rawequal(v,OPAQUE) end
    e.UnitExists=function(unit) return call('exists',unit) end
    e.UnitClass=function(unit) call('class',unit);return 'Class',s.class end
    e.UnitPower=function(...) return call('current',...) end
    e.UnitPowerMax=function(...) return call('maximum',...) end
    e.GetComboPoints=function(...) return call('combo',...) end
    e.C_SpecializationInfo={GetSpecialization=function(...) return call('spec',...) end}
    e.GetSpecialization=function() error('the C_SpecializationInfo method is preferred') end
    e.UnitPowerType=function() error('POINT never reads the primary power type') end
    f.load('Platform/specializations.lua');f.load('Platform/points.lua');f.load('constants.lua')
    for _,p in ipairs({'Core/point_conditions.lua','Diagnostics/errors.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/stats.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(p) end
    e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
    s.calls={}
    return f,a,s
end
local function node(value,unit,operator) return {type='POINT',unit=unit or 'player',operator=operator or 'EQUALS',value=value or 3} end
local function status(a,n) return a:evaluateConditionResult(n).status end
local function count(s,k) local n=0;for _,c in ipairs(s.calls) do if c[1]==k then n=n+1 end end;return n end
local function unknown(a,n,label)
    local r=a:evaluateConditionResult(n);assert(r.status=='unavailable',(label or '')..' became actionable: '..r.status)
    r=a:evaluateConditionResult({type='NOT',value=n});assert(r.status=='unavailable',(label or '')..' NOT became actionable: '..r.status)
end
local function last(s,k) for i=#s.calls,1,-1 do if s.calls[i][1]==k then return s.calls[i] end end end
-- Exactly one UnitPower read of the expected type on the player, with no
-- fragment flag unless asked, and never the TBC GetComboPoints transport.
local function reads(s,id,fragments,label)
    local c=assert(last(s,'current'),label..': no current read')
    assert(count(s,'current')==1 and count(s,'combo')==0,label..': native reads')
    assert(c[2]=='player' and c[3]==id,label..': read '..tostring(c[3]))
    if fragments then assert(c.n==3 and c[4]==true,label..': not read in fragments')
    else assert(c.n==2,label..': unexpected fragment flag') end
end

-- Expected selections, by edition. A table value is keyed by specialization index.
local MAPS={
    era={ROGUE=POWER.ComboPoints,DRUID=POWER.ComboPoints},
    wrath={ROGUE=POWER.ComboPoints,DRUID=POWER.ComboPoints},
    cata={ROGUE=POWER.ComboPoints,DRUID=POWER.ComboPoints,PALADIN=POWER.HolyPower,WARLOCK=POWER.SoulShards},
    mists={ROGUE=POWER.ComboPoints,DRUID=POWER.ComboPoints,PALADIN=POWER.HolyPower,MONK=POWER.Chi,
        PRIEST={[3]=POWER.ShadowOrbs},WARLOCK={POWER.SoulShards,POWER.DemonicFury,POWER.BurningEmbers}},
}
local EDITIONS={{'era',ERA,0},{'wrath',WRATH,2},{'cata',CATA,3},{'mists',MISTS,4}}

test('mapping: every class on every Classic edition reads its own resource or is unavailable',function()
    for _,edition in ipairs(EDITIONS) do for _,class in ipairs(CLASSES) do
        local want=MAPS[edition[1]][class]
        for _,spec in ipairs(type(want)=='table' and {1,2,3,4} or {2}) do
            local _,a,s=fixture(edition[2],edition[3],class,spec)
            local id=want;if type(want)=='table' then id=want[spec] end
            local label=edition[1]..' '..class..' spec '..spec
            if id then
                local fragments=id==POWER.BurningEmbers
                if fragments then s.current=30 end
                assert(status(a,node(3))=='match',label)
                reads(s,id,fragments,label)
            else
                unknown(a,node(3),label);unknown(a,node(0),label);unknown(a,node(-1),label)
                assert(count(s,'current')==0 and count(s,'maximum')==0 and count(s,'combo')==0,label..': read a resource it lacks')
            end
            -- Only a specialization-dependent class reads the specialization.
            assert((count(s,'spec')>0)==(type(want)=='table'),label..': specialization reads')
        end
    end end
end)

test('era: Warlock and Mage have no POINT resource; Rogue and Druid stay on UnitPower, never the TBC target transport',function()
    for _,class in ipairs({'WARLOCK','MAGE'}) do
        local _,a,s=fixture(ERA,0,class);unknown(a,node(0));unknown(a,node(3,'target'))
        local v,why=a.conditionDefinitions.POINT.evaluate(node(0),{})
        assert(v==nil and why=='point-resource-unavailable',class..': '..tostring(why));assert(count(s,'current')==0)
    end
    for _,class in ipairs({'ROGUE','DRUID'}) do
        local _,a,s=fixture(ERA,0,class);s.current=5;s.maximum=5
        assert(status(a,node(5))=='match' and status(a,node(-1))=='no-match' and status(a,node(0,'player','GREATERTHAN'))=='match')
        assert(count(s,'combo')==0 and count(s,'maximum')==1,class)
        for _,c in ipairs(s.calls) do if c[1]=='current' or c[1]=='maximum' then assert(c[2]=='player' and c[3]==POWER.ComboPoints and c.n==2) end end
    end
end)

test('mists: Warlock specializations read Soul Shards, Demonic Fury and Burning Embers',function()
    local _,a,s=fixture(MISTS,4,'WARLOCK',1);s.current=4
    assert(status(a,node(4))=='match');reads(s,POWER.SoulShards,false,'affliction')
    _,a,s=fixture(MISTS,4,'WARLOCK',2);s.current=880;s.maximum=1000
    assert(status(a,node(800,'player','GREATERTHANOREQUALS'))=='match');reads(s,POWER.DemonicFury,false,'demonology')
    s.calls={};assert(status(a,node(-120))=='match','demonic fury deficit')
end)

test('mists: Burning Embers are embers with their fraction, deficit included',function()
    local _,a,s=fixture(MISTS,4,'WARLOCK',3);s.current=35;s.maximum=40
    assert(status(a,node(3.5))=='match');reads(s,POWER.BurningEmbers,true,'embers')
    assert(status(a,node(3,'player','GREATERTHANOREQUALS'))=='match' and status(a,node(4,'player','GREATERTHANOREQUALS'))=='no-match')
    s.calls={};assert(status(a,node(-0.5))=='match','half an ember short of the cap')
    local m=assert(last(s,'maximum'));assert(m[2]=='player' and m[3]==POWER.BurningEmbers and m.n==3 and m[4]==true)
    -- Whole embers are 10 fragments each (MAX_POWER_PER_EMBER), never the raw fragment count.
    s.current=10;assert(status(a,node(1))=='match' and status(a,node(10))=='no-match')
    s.current=33;assert(status(a,node(3.3))=='match','33 fragments are 3.3 embers exactly as authored')
    s.current=0;assert(status(a,node(0))=='match' and status(a,{type='NOT',value=node(1,'player','GREATERTHANOREQUALS')})=='match')
end)

test('mists: Shadow Orbs only for Shadow; Discipline, Holy and an unspecialized Priest are unavailable',function()
    local _,a,s=fixture(MISTS,4,'PRIEST',3);s.current=3
    assert(status(a,node(3))=='match');reads(s,POWER.ShadowOrbs,false,'shadow')
    for _,spec in ipairs({1,2}) do
        _,a,s=fixture(MISTS,4,'PRIEST',spec);unknown(a,node(0));assert(count(s,'current')==0)
        local v,why=a.conditionDefinitions.POINT.evaluate(node(0),{});assert(v==nil and why=='point-resource-unavailable')
    end
    _,a,s=fixture(MISTS,4,'PRIEST',nil);unknown(a,node(0));assert(count(s,'current')==0)
    local v,why=a.conditionDefinitions.POINT.evaluate(node(0),{});assert(v==nil and why=='specialization-unavailable',tostring(why))
end)

test('specialization: unreadable, malformed or failed reads are unavailable and recover next pass',function()
    for _,bad in ipairs({OPAQUE,0,5.5,-1,'3',false,17}) do
        local _,a,s=fixture(MISTS,4,'WARLOCK',bad);unknown(a,node(0),tostring(bad));assert(count(s,'current')==0,tostring(bad))
    end
    local _,a,s=fixture(MISTS,4,'WARLOCK',3);s.throw='spec';unknown(a,node(0));assert(count(s,'current')==0)
    s.throw=nil;s.current=20;assert(status(a,node(2))=='match','a new pass recovers')
    -- The legacy global serves a client without C_SpecializationInfo.
    local f;f,a,s=fixture(MISTS,4,'WARLOCK',2);f.env.C_SpecializationInfo=nil
    f.env.GetSpecialization=function(...) assert(select('#',...)==0);s.calls[#s.calls+1]={'spec'};return 2 end
    s.current=500;assert(status(a,node(500))=='match');reads(s,POWER.DemonicFury,false,'legacy')
    f.env.GetSpecialization=nil;unknown(a,node(0))
    local v,why=a.conditionDefinitions.POINT.evaluate(node(0),{});assert(v==nil and why=='missing-api',tostring(why))
end)

test('specialization: read once per pass with no arguments; a respec is seen by the next pass',function()
    local _,a,s=fixture(MISTS,4,'WARLOCK',1);local eval=a.conditionDefinitions.POINT.evaluate;local cache={}
    assert(eval(node(3),cache)==true and eval(node(-2),cache)==true and eval(node(4,'player','GREATERTHAN'),cache)==false)
    assert(count(s,'spec')==1 and count(s,'current')==1 and count(s,'maximum')==1)
    assert(last(s,'spec').n==0,'GetSpecialization takes no arguments for the active specialization')
    s.spec=3;s.current=35;assert(eval(node(3),cache)==true,'same pass keeps its observations')
    assert(eval(node(3.5),{})==true and last(s,'current')[3]==POWER.BurningEmbers,'next pass follows the respec')
end)

test('units: a specialization resource is only the player; class-wide resources keep the configured unit',function()
    for _,class in ipairs({'PRIEST','WARLOCK'}) do for _,unit in ipairs({'target','party1','focus'}) do
        local _,a,s=fixture(MISTS,4,class,3);unknown(a,node(1,unit))
        assert(count(s,'spec')==0 and count(s,'current')==0,class..' '..unit)
        local v,why=a.conditionDefinitions.POINT.evaluate(node(1,unit),{});assert(v==nil and why=='point-specialization-unavailable')
    end end
    local _,a,s=fixture(MISTS,4,'PALADIN');assert(status(a,node(3,'target'))=='match')
    local c=last(s,'current');assert(c[2]=='target' and c[3]==POWER.HolyPower and c.n==2 and count(s,'spec')==0)
    _,a,s=fixture(MISTS,4,'PALADIN');s.exists=false;assert(status(a,node(3,'target'))=='no-match' and count(s,'current')==0,'absence stays known absence')
end)

test('expansion: an unresearched, unreadable or missing progression expansion maps nothing',function()
    for _,expansion in ipairs({5,1,OPAQUE,'4',false}) do for _,class in ipairs({'ROGUE','PALADIN','WARLOCK'}) do
        local f,a,s=fixture(MISTS,4,class,1);f.env.LE_EXPANSION_LEVEL_CURRENT=expansion
        unknown(a,node(0),tostring(expansion)..' '..class);assert(count(s,'current')==0 and count(s,'spec')==0)
    end end
end)

test('enum: a resource name the client does not define is unavailable, never another type',function()
    for name,class in pairs({ShadowOrbs='PRIEST',HolyPower='PALADIN',ComboPoints='ROGUE'}) do
        local f,a,s=fixture(MISTS,4,class,3);f.env.Enum.PowerType[name]=nil
        unknown(a,node(0),name);assert(count(s,'current')==0,name)
        f.env.Enum.PowerType[name]=OPAQUE;unknown(a,node(0),name);assert(count(s,'current')==0,name)
    end
    local f,a,s=fixture(ERA,0,'ROGUE');f.env.Enum.PowerType=nil;unknown(a,node(0));assert(count(s,'current')==0)
    f.env.Enum=nil;unknown(a,node(0));assert(count(s,'current')==0)
end)

test('fragments: unreadable, failed or nonfinite ember reads are unavailable, never the whole-unit query',function()
    for _,bad in ipairs({OPAQUE,'35',0/0,math.huge,-math.huge}) do
        local _,a,s=fixture(MISTS,4,'WARLOCK',3);s.current=bad;unknown(a,node(3),tostring(bad))
        for _,c in ipairs(s.calls) do if c[1]=='current' then assert(c.n==3 and c[4]==true) end end
    end
    local _,a,s=fixture(MISTS,4,'WARLOCK',3);s.current=nil;unknown(a,node(3))
    _,a,s=fixture(MISTS,4,'WARLOCK',3);s.throw='current';unknown(a,node(3))
    _,a,s=fixture(MISTS,4,'WARLOCK',3);s.maximum=OPAQUE;assert(status(a,node(0.3))=='match','a positive comparison needs no maximum');unknown(a,node(-1))
    local p=a.Platform
    assert(select(2,p:GetUnitPointFragmentObservation('player',14,'other'))=='invalid-point-power-query')
    assert(select(2,p:GetUnitPointFragmentObservation('',14,'current'))=='invalid-unit')
    assert(select(2,p:GetUnitPointFragmentObservation('player',1.5,'current'))=='invalid-point-power-query')
    s.current=25;assert(p:GetUnitPointFragmentObservation('player',14,'current')==2.5)
end)

test('fragments: only progression reads Burning Embers in fragments; TBC and Retail keep their two-argument reads',function()
    for _,project in ipairs({TBC,ERA}) do
        local _,a,s=fixture(project,project==ERA and 0 or 1,'ROGUE')
        local v=a.Platform:GetUnitPointPowerObservation('player',POWER.BurningEmbers,'current')
        local c=assert(last(s,'current'));assert(v==3 and c.n==2 and c[3]==POWER.BurningEmbers,'project '..project)
    end
    -- Retail refuses a type Blizzard does not flag never secret, before any read.
    local _,a,s=fixture(RETAIL,1,'ROGUE')
    local v,why=a.Platform:GetUnitPointPowerObservation('player',POWER.BurningEmbers,'current')
    assert(v==nil and why=='unsupported-policy' and #s.calls==0)
    _,a,s=fixture(MISTS,4,'ROGUE');s.current=12
    assert(a.Platform:GetUnitPointPowerObservation('player',POWER.BurningEmbers,'current')==1.2)
    assert(a.Platform:GetUnitPointPowerObservation('player',POWER.SoulShards,'current')==12 and last(s,'current').n==2)
end)

test('policy: TBC, Retail and Forever keep the class map exactly (tests/retail_points.lua pins their reads)',function()
    local _,a,s=fixture(TBC,1,'WARLOCK');assert(status(a,node(3))=='match');reads(s,POWER.SoulShards,false,'tbc warlock')
    _,a,s=fixture(TBC,1,'ROGUE');assert(status(a,node(2))=='match' and count(s,'combo')==1 and count(s,'current')==0,'tbc player combo transport')
    _,a,s=fixture(TBC,1,'MAGE');assert(status(a,node(3))=='match');reads(s,POWER.ArcaneCharges,false,'tbc mage')
    assert(count(s,'spec')==0)
end)

test('archived V1 API keeps the class map on Classic editions (old saved copies only)',function()
    local _,a,s=fixture(MISTS,4,'MAGE');local point=a:GetConditionPointResource('player',{})
    assert(point==POWER.ArcaneCharges and count(s,'spec')==0)
end)

test('copies: the published POINT source and an editable copy select the same edition resource',function()
    local _,a,s=fixture(MISTS,4,'WARLOCK',3);s.current=35;s.maximum=40
    local source=assert(a:GetBuiltinConditionSource('POINT'))
    a:RegisterCondition('COPY_POINT',assert(a:CompileCustomCondition('COPY_POINT',source)))
    local copy=node(3.5);copy.type='COPY_POINT'
    assert(status(a,copy)=='match' and status(a,node(3.5))=='match')
    for _,c in ipairs(s.calls) do if c[1]=='current' then assert(c[3]==POWER.BurningEmbers and c.n==3) end end
    _,a,s=fixture(MISTS,4,'MAGE');source=assert(a:GetBuiltinConditionSource('POINT'))
    a:RegisterCondition('COPY_POINT',assert(a:CompileCustomCondition('COPY_POINT',source)))
    copy=node(0);copy.type='COPY_POINT';unknown(a,copy);assert(count(s,'current')==0)
end)

finish()
