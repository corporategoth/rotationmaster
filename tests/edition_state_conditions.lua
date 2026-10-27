-- The conditions that belong to particular editions (Conditions/edition_state.lua):
-- PET_HAPPINESS (Classic Era, Burning Crusade, Wrath), STAGGER (Mists of
-- Pandaria, Retail, Forever), ECLIPSE (Wrath through Mists of Pandaria) and the
-- Ranged option of SWING_TIME and SWING_TIME_REMAIN (Conditions/weapon.lua; the
-- remaining time needs a client that exposes the combat log). Which edition has
-- each (the website's red X reads the same table), the values, secrets, the
-- combat log producer in main.lua and the ranged shot timestamp.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local C=dofile('tests/fixtures/condition_client.lua')
local SECRET,expect,status,support=C.SECRET,C.expect,C.status,C.support

local function client(name,class)
    local f,a,e=C.load(name,class,{'Platform/world_state.lua','Platform/edition_state.lua','Platform/spells.lua'})
    local s={calls={},mood=nil,stagger=0,maxhealth=100000,direction='none',balance=0,speed=2.5,ranged=true}
    local function hit(n) s.calls[n]=(s.calls[n] or 0)+1 end
    e.GetPetHappiness=function() hit('GetPetHappiness');return s.mood,100,2 end
    e.UnitStagger=function(unit) assert(unit=='player');hit('UnitStagger');return s.stagger end
    e.UnitHealthMax=function(unit) assert(unit=='player');hit('UnitHealthMax');return s.maxhealth end
    e.GetEclipseDirection=function() hit('GetEclipseDirection');return s.direction end
    e.UnitPower=function(unit,kind) assert(unit=='player' and kind==26,'Eclipse is Enum.PowerType.Balance');hit('UnitPower');return s.balance end
    e.UnitRangedDamage=function(unit) assert(unit=='player');hit('UnitRangedDamage');if not s.ranged then return 0 end;return s.speed,1,2,0,0,0 end
    e.GetTime=function() return 100 end
    return f,a,e,s
end

-- tag -> clients that lack it, with the reason.
local MISSING={
    PET_HAPPINESS={retail='no-pet-happiness',forever='no-pet-happiness',mists='no-pet-happiness',cata='no-pet-happiness'},
    STAGGER={tbc='no-stagger',era='no-stagger',wrath='no-stagger',cata='no-stagger'},
    ECLIPSE={retail='no-eclipse',forever='no-eclipse',tbc='no-eclipse',era='no-eclipse'},
}
-- The same, for a value: the ranged timers read UnitRangedDamage everywhere, and the remaining time needs the combat log.
local RANGED_MISSING={
    SWING_TIME={},
    SWING_TIME_REMAIN={retail='combat-log-unavailable',forever='combat-log-unavailable'},
}
test('each edition mechanic is declared available exactly where the edition has it',function()
    for _,name in ipairs({'retail','forever','mists','tbc','era','wrath','cata'}) do
        local _,a=client(name)
        for tag,missing in pairs(MISSING) do
            assert(a.conditionDefinitions[tag],tag..' is not registered on '..name)
            local got=support(a,tag);assert(got==missing[name],tag..' on '..name..': '..tostring(got)..', wanted '..tostring(missing[name]))
        end
    end
end)

test('the ranged option of the swing timers is declared available exactly where its readers are',function()
    for _,name in ipairs({'retail','forever','mists','tbc','era','wrath','cata'}) do
        local _,a,e=client(name);e.UnitAttackSpeed=function() return 3,2 end
        for tag,missing in pairs(RANGED_MISSING) do
            local got=support(a,tag,{ranged=true});assert(got==missing[name],tag..' ranged on '..name..': '..tostring(got)..', wanted '..tostring(missing[name]))
        end
        -- The melee hands are unchanged: attack speed everywhere, the remaining time needs the combat log.
        assert(support(a,'SWING_TIME',{})==nil,'melee SWING_TIME on '..name)
        assert(support(a,'SWING_TIME_REMAIN',{})==RANGED_MISSING.SWING_TIME_REMAIN[name],'melee SWING_TIME_REMAIN on '..name)
    end
    local _,a,e=client('era');e.UnitAttackSpeed=function() return 3,2 end;e.UnitRangedDamage=nil
    assert(support(a,'SWING_TIME',{ranged=true})=='missing-api' and support(a,'SWING_TIME',{})==nil,'only the ranged option needs UnitRangedDamage')
end)

test('PET_HAPPINESS reads the Hunter pet mood and is false without a Hunter pet',function()
    for _,name in ipairs({'tbc','era','wrath'}) do
        local _,a,_,s=client(name,'HUNTER')
        s.mood=3;expect(a,{type='PET_HAPPINESS',value=3},'match',name);expect(a,{type='PET_HAPPINESS',value=1},'no-match',name)
        s.mood=1;expect(a,{type='PET_HAPPINESS',value=1},'match',name)
        s.mood=nil;expect(a,{type='PET_HAPPINESS',value=3},'no-match',name..' no Hunter pet')
        s.mood=SECRET;expect(a,{type='PET_HAPPINESS',value=3},'unavailable',name)
        s.mood=7;expect(a,{type='PET_HAPPINESS',value=3},'unavailable',name..' malformed')
    end
    local _,a,e=client('era','HUNTER');e.GetPetHappiness=nil;expect(a,{type='PET_HAPPINESS',value=3},'unavailable','missing')
    local def=a.conditionDefinitions.PET_HAPPINESS
    assert(def.valid(0,{value=2}) and not def.valid(0,{value=4}) and not def.valid(0,{}))
    assert(def.print(0,{value=3}):find('Happy',1,true))
end)

test('STAGGER compares the pool as an amount, or as a percent of maximum health where that can be read',function()
    for _,name in ipairs({'retail','forever','mists'}) do
        local _,a,_,s=client(name,'MONK')
        s.stagger=15000
        expect(a,{type='STAGGER',operator='GREATERTHAN',value=10000},'match',name);expect(a,{type='STAGGER',operator='GREATERTHAN',value=20000},'no-match',name)
        expect(a,{type='STAGGER',operator='GREATERTHANOREQUALS',value=15,percent=true},'match',name..' 15 percent of 100000')
        expect(a,{type='STAGGER',operator='GREATERTHAN',value=15,percent=true},'no-match',name)
        s.stagger=SECRET;expect(a,{type='STAGGER',operator='GREATERTHAN',value=1},'unavailable',name..' a hidden pool')
        s.stagger=15000;s.maxhealth=SECRET
        expect(a,{type='STAGGER',operator='GREATERTHAN',value=1,percent=true},'unavailable',name..' hidden maximum health')
        expect(a,{type='STAGGER',operator='GREATERTHAN',value=1},'match',name..' the amount does not need maximum health')
        s.maxhealth=0;expect(a,{type='STAGGER',operator='GREATERTHAN',value=1,percent=true},'unavailable',name..' malformed maximum')
        s.maxhealth=100000;s.stagger=-5;expect(a,{type='STAGGER',operator='GREATERTHAN',value=1},'unavailable',name..' malformed pool')
    end
    local _,a=client('mists','MONK');local def=a.conditionDefinitions.STAGGER
    assert(def.valid(0,{operator='EQUALS',value=0}) and def.valid(0,{operator='EQUALS',value=1,percent=true}) and not def.valid(0,{operator='EQUALS',value=-1}) and not def.valid(0,{operator='EQUALS',value=1,percent='x'}))
    assert(def.print(0,{operator='GREATERTHAN',value=5,percent=true}):find('percent',1,true))
end)

test('ECLIPSE reads the Balance bar on a Druid in Wrath through Mists',function()
    local function dir(value) return {type='ECLIPSE',measure='direction',direction=value} end
    local function energy(operator,value) return {type='ECLIPSE',measure='energy',operator=operator,value=value} end
    for _,name in ipairs({'mists','wrath','cata'}) do
        local _,a,_,s=client(name,'DRUID')
        s.direction='sun';expect(a,dir('sun'),'match',name);expect(a,dir('moon'),'no-match',name)
        s.direction='none';expect(a,dir('sun'),'no-match',name..' no direction matches neither')
        expect(a,dir('moon'),'no-match',name)
        s.direction=nil;expect(a,dir('moon'),'no-match',name..' nil direction is none')
        s.direction='sideways';expect(a,dir('moon'),'unavailable',name..' malformed')
        s.direction=SECRET;expect(a,dir('moon'),'unavailable',name)
        s.balance=-60;expect(a,energy('LESSTHAN',0),'match',name..' lunar side')
        expect(a,energy('GREATERTHANOREQUALS',-100),'match',name)
        s.balance=100;expect(a,energy('EQUALS',100),'match',name..' full solar')
        s.balance=SECRET;expect(a,energy('EQUALS',100),'unavailable',name)
        s.balance=nil;expect(a,energy('EQUALS',100),'unavailable',name..' no value')
        s.balance=1/0;expect(a,energy('EQUALS',100),'unavailable',name..' infinite')
        s.balance=50;s.direction='sun'
        local before=s.calls.GetEclipseDirection or 0
        assert(a:evaluateConditionResult({type='AND',value={dir('sun'),dir('sun')}}).status=='match' and s.calls.GetEclipseDirection==before+1,name..' one read per evaluation')
    end
    local _,a=client('mists','WARRIOR')
    expect(a,dir('sun'),'unavailable','another class has no Eclipse bar')
    expect(a,energy('EQUALS',0),'unavailable','another class has no Eclipse bar')
    local def=a.conditionDefinitions.ECLIPSE
    assert(def.valid(0,{measure='energy',operator='LESSTHAN',value=-100}) and def.valid(0,{measure='energy',operator='LESSTHAN',value=100}))
    assert(not def.valid(0,{measure='energy',operator='LESSTHAN',value=101}) and not def.valid(0,{measure='energy',operator='LESSTHAN',value=-101}))
    assert(not def.valid(0,{measure='energy',value=1}) and not def.valid(0,{measure='energy',operator='LESSTHAN'}))
    assert(def.valid(0,{measure='direction',direction='sun'}) and def.valid(0,{measure='direction',direction='moon'}))
    assert(not def.valid(0,{measure='direction',direction='none'}) and not def.valid(0,{measure='direction'}) and not def.valid(0,{}) and not def.valid(0,{measure='speed'}))
    -- Each measure needs only its own API.
    local _,b,e=client('mists','DRUID');e.GetEclipseDirection=nil
    assert(support(b,'ECLIPSE',{measure='direction'})=='missing-api' and support(b,'ECLIPSE',{measure='energy'})==nil)
    assert(def.print(0,{measure='direction',direction='sun'}):find('Solar',1,true) or def.print(0,{measure='direction',direction='sun'}):find('solar',1,true))
    assert(def.print(0,{measure='energy',operator='GREATERTHAN',value=10}):find('Eclipse energy',1,true))
end)

-- The real combat log producer (main.lua handle_combat_log), driven the way tests/swing_countdown.lua does.
local function readFile(path) local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local producer=assert(readFile('main.lua'):match('(local function handle_combat_log%(_.-\nend)\n%-%- Classic reads'))
local function shooter(name)
    local f,a,e,s=client(name,'HUNTER')
    a.damageHistory={}
    s.now=100;e.GetTime=function() return s.now end
    s.auto={}
    local factory=assert(loadstring('return function(addon,playerGUID) '..producer..';return handle_combat_log end','@actual-combat-log-producer'))
    setfenv(factory,e)
    local append=factory()(a,'Player-A')
    return f,a,e,s,append
end
local function shot(append,event,spellId,source)
    if event=='RANGE_DAMAGE' then append(nil,event,nil,source or 'Player-A',nil,nil,nil,'Creature-A',nil,nil,nil,spellId,'Auto Shot',1,50,0,1,0,0,0,false,false,false)
    else append(nil,event,nil,source or 'Player-A',nil,nil,nil,'Creature-A',nil,nil,nil,spellId,'Auto Shot',1,'MISS') end
end

test('Auto Shot and wand shots start the ranged timer; other ranged casts, melee swings and other players do not',function()
    local _,a,e,s,append=shooter('tbc')
    -- IsAutoRepeatActive asks C_Spell.IsAutoRepeatSpell, else the spellbook (Platform/spells.lua).
    local repeating={[5019]=true}
    a.Platform.IsAutoRepeatActive=function(_,id) return repeating[id]==true end
    for _,event in ipairs({'RANGE_DAMAGE','RANGE_MISSED'}) do
        a.lastRangedShot=nil;s.now=101;shot(append,event,75);assert(a.lastRangedShot==101,event..' Auto Shot')
        a.lastRangedShot=nil;s.now=102;shot(append,event,5019);assert(a.lastRangedShot==102,event..' wand Shoot, an auto-repeat spell')
        a.lastRangedShot=nil;shot(append,event,2764);assert(a.lastRangedShot==nil,event..' Throw is a single cast')
        shot(append,event,75,'Player-B');assert(a.lastRangedShot==nil,event..' another player')
    end
    s.now=103;append(nil,'SWING_DAMAGE',nil,'Player-A',nil,nil,nil,'Creature-A',nil,nil,nil,10,0,1,0,0,0,false,false,false,false)
    assert(a.lastRangedShot==nil and a.lastMainSwing==103,'a melee swing is not a ranged shot')
    shot(append,'SPELL_DAMAGE',75);assert(a.lastRangedShot==nil)
end)

test('the ranged swing time remaining counts down from the last shot and reads the full interval before the first',function()
    for _,name in ipairs({'era','tbc','mists'}) do
        local _,a,_,s=client(name,'HUNTER')
        s.speed=2.5;a.lastRangedShot=nil
        local function remaining(operator,value) return {type='SWING_TIME_REMAIN',ranged=true,operator=operator,value=value} end
        expect(a,remaining('EQUALS',2.5),'match',name..' before the first shot');expect(a,remaining('LESSTHAN',2.5),'no-match',name)
        a.lastRangedShot=99;expect(a,remaining('EQUALS',1.5),'match',name..' one second after a shot')
        expect(a,remaining('LESSTHANOREQUALS',1.5),'match',name)
        a.lastRangedShot=90;expect(a,remaining('EQUALS',0),'match',name..' the interval has run out, never negative')
        a.lastRangedShot=101;expect(a,remaining('EQUALS',2.5),'match',name..' a clock behind the shot stays at the full interval')
        s.ranged=false;expect(a,remaining('LESSTHAN',99),'no-match',name..' no ranged attack is false')
        s.ranged=true;s.speed=SECRET;expect(a,remaining('LESSTHAN',99),'unavailable',name)
        s.speed=-1;expect(a,remaining('LESSTHAN',99),'unavailable',name..' malformed')
        s.speed=2.5;a.lastRangedShot=99
        local before=s.calls.UnitRangedDamage or 0
        assert(a:evaluateConditionResult({type='AND',value={remaining('LESSTHAN',9),remaining('GREATERTHAN',0)}}).status=='match')
        assert(s.calls.UnitRangedDamage==before+1,name..' one speed read for the whole evaluation')
        -- A cast does not pause the ranged timer the way it pauses a melee swing.
    end
    local _,a=client('era','HUNTER');local def=a.conditionDefinitions.SWING_TIME_REMAIN
    assert(def.valid(0,{ranged=true,operator='LESSTHAN',value=0}) and not def.valid(0,{ranged=true,operator='LESSTHAN',value=-1}) and not def.valid(0,{ranged=true,value=1}))
    assert(not def.valid(0,{ranged=true,offhand=true,operator='LESSTHAN',value=1}),'one weapon at a time')
    assert(not def.valid(0,{ranged='yes',operator='LESSTHAN',value=1}))
    assert(def.print(0,{ranged=true,operator='LESSTHAN',value=1}):find('ranged',1,true))
end)

test('the ranged option of SWING_TIME reads the Auto Shot or wand interval, and the melee hands stay as they were',function()
    for _,name in ipairs({'retail','forever','mists','tbc','era'}) do
        local _,a,e,s=client(name,'HUNTER')
        e.UnitAttackSpeed=function() return 3.6,1.8 end
        s.speed=2.5
        local function speed(operator,value,extra) local c={type='SWING_TIME',operator=operator,value=value};for k,v in pairs(extra or {}) do c[k]=v end;return c end
        expect(a,speed('EQUALS',2.5,{ranged=true}),'match',name..' ranged interval')
        expect(a,speed('EQUALS',3.6),'match',name..' main hand is untouched');expect(a,speed('EQUALS',1.8,{offhand=true}),'match',name..' off hand is untouched')
        s.ranged=false;expect(a,speed('LESSTHAN',99,{ranged=true}),'no-match',name..' no ranged attack')
        s.ranged=true;s.speed=SECRET;expect(a,speed('LESSTHAN',99,{ranged=true}),'unavailable',name)
        s.speed=2.5;e.UnitRangedDamage=nil;expect(a,speed('LESSTHAN',99,{ranged=true}),'unavailable',name..' missing')
    end
    local _,a=client('era','HUNTER');local def=a.conditionDefinitions.SWING_TIME
    assert(def.valid(0,{ranged=true,operator='LESSTHAN',value=2}) and not def.valid(0,{ranged=true,offhand=true,operator='LESSTHAN',value=2}))
end)

test('the ranged timer resets when you leave combat and never on a spell cast or target change',function()
    local text=readFile('main.lua')
    local leave=text:match('addon%.PLAYER_REGEN_ENABLED = wrapEvent%(function%(self%).-\nend%)')
    assert(leave and leave:find('self.lastRangedShot = nil',1,true),'leaving combat clears the ranged timer')
    local cast=text:match('addon%.UNIT_SPELLCAST_STOP = wrapCombatEvent%(function.-\nend%)')
    assert(cast and not cast:find('lastRangedShot',1,true),'a cast stop must not clear the ranged timer')
    local target=text:match('addon%.PLAYER_TARGET_CHANGED = wrapEvent%(function%(self%).-\nend%)')
    assert(target and not target:find('lastRangedShot',1,true),'a target change must not clear the ranged timer')
end)

test('every edition condition builds its editor help and a complete summary',function()
    local _,a=client('mists','DRUID')
    local fields={PET_HAPPINESS={value=2},STAGGER={operator='LESSTHAN',value=3},ECLIPSE={measure='direction',direction='moon'},
        SWING_TIME_REMAIN={ranged=true,operator='LESSTHAN',value=1},SWING_TIME={ranged=true,operator='LESSTHAN',value=3}}
    for tag,value in pairs(fields) do
        local def=a.conditionDefinitions[tag];value.type=tag
        assert(def.valid(0,value),tag);def.help({AddChild=function() end})
        local text=def.print(0,value);assert(type(text)=='string' and not text:find('<',1,true),tag..': '..text)
    end
end)

finish()
