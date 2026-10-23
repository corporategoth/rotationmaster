local F=dofile('tests/fixtures/addon.lua')
local fixture=dofile('tests/fixtures/platform.lua')
local test,finish=F.suite()
test('modern metadata is copied as a record and does not imply learned state',function()
    local original={name='Earth Shield',iconID=123,castTime=0,minRange=0,maxRange=40,spellID=974,originalIconID=124}
    local p=fixture({C_Spell={GetSpellInfo=function(id) assert(id==974);return original end}})
    local info=p:GetSpellInfo(974)
    assert(info.name=='Earth Shield' and info.spellID==974 and info.iconID==123)
    assert(info.castTime==0 and info.maxRange==40 and info.originalIconID==124)
    info.name='changed';assert(original.name=='Earth Shield')
    local known,reason=p:IsSpellKnown(974);assert(known==nil and reason=='missing-api')
end)
test('legacy metadata tuple maps rank, icon, ranges and stable ID',function()
    local p=fixture({GetSpellInfo=function(name)
        assert(name=='Earth Shield');return name,'Rank 1',123,0,0,40,974,124
    end})
    local info=p:GetSpellInfo('Earth Shield')
    assert(info.name=='Earth Shield' and info.subtext=='Rank 1' and info.spellID==974)
    assert(info.iconID==123 and info.originalIconID==124 and info.maxRange==40)
end)
test('known spells use supplied player and pet enums including zero',function()
    local banks={}
    local p=fixture({Enum={SpellBookSpellBank={Player=0,Pet=1}},C_SpellBook={IsSpellKnown=function(id,bank)
        assert(id==974);banks[#banks+1]=bank;return bank==0
    end}})
    assert(p:IsSpellKnown(974)==true and p:IsSpellKnown(974,true)==false)
    assert(banks[1]==0 and banks[2]==1)
end)
test('legacy known spells preserve false and receive pet Boolean',function()
    local p=fixture({IsSpellKnown=function(id,pet) assert(id==974);return pet end})
    assert(p:IsSpellKnown(974)==false and p:IsSpellKnown(974,true)==true)
end)
test('modern known spells without enums use only an available legacy contract',function()
    local p=fixture({C_SpellBook={IsSpellKnown=function() error('unknown enum must not be guessed') end}})
    local known,why=p:IsSpellKnown(974);assert(known==nil and why=='missing-spell-bank')
    p=fixture({C_SpellBook={IsSpellKnown=function() error('must use legacy') end},
        IsSpellKnown=function() return false end})
    assert(p:IsSpellKnown(974)==false)
end)
test('an absent pet enum never queries the player spellbook instead',function()
    local p=fixture({Enum={SpellBookSpellBank={Player=0}},C_SpellBook={IsSpellKnown=function()
        error('must not substitute the player bank for a missing pet bank')
    end}})
    local known,reason=p:IsSpellKnown(974,true)
    assert(known==nil and reason=='missing-spell-bank')
end)
test('modern cooldown holds and legacy enabled integers normalize independently',function()
    local p=fixture({C_Spell={GetSpellCooldown=function() return {startTime=100,duration=10,isEnabled=false,modRate=1} end}})
    local cooldown=p:GetSpellCooldown(974)
    assert(cooldown.startTime==100 and cooldown.duration==10 and cooldown.isEnabled==false and cooldown.modRate==1)
    p=fixture({GetSpellCooldown=function() return 0,0,1 end})
    cooldown=p:GetSpellCooldown(974)
    assert(cooldown.startTime==0 and cooldown.duration==0 and cooldown.isEnabled==true and cooldown.modRate==1)
end)
test('missing, failed, absent and malformed spell data have explicit reasons',function()
    local p=fixture()
    for _,method in ipairs({'GetSpellInfo','GetSpellCooldown','IsSpellKnown'}) do
        local value,why=p[method](p,974);assert(value==nil and why=='missing-api',method)
    end
    p=fixture({C_Spell={GetSpellInfo=function() error('unsupported') end,
        GetSpellCooldown=function() return nil end},IsSpellKnown=function() return nil end})
    local value,why=p:GetSpellInfo(974);assert(value==nil and why=='api-error')
    value,why=p:GetSpellCooldown(974);assert(value==nil and why=='spell-data-unavailable')
    value,why=p:IsSpellKnown(974);assert(value==nil and why=='invalid-api-result')
    value,why=p:GetSpellInfo({});assert(value==nil and why=='invalid-spell')
    value,why=p:IsSpellKnown('Earth Shield');assert(value==nil and why=='invalid-spell')
end)
test('restricted records and fields never fall back to a legacy observation',function()
    local opaque=setmetatable({}, {__tostring=function() error('inspected opaque value') end})
    for _,guard in ipairs({'issecretvalue','canaccessvalue'}) do
        local env={C_Spell={GetSpellInfo=function() return {name=opaque} end,
            GetSpellCooldown=function() return {startTime=0,duration=opaque,isEnabled=true} end},
            IsSpellKnown=function() return opaque end,
            GetSpellInfo=function() error('must not fall back') end}
        env[guard]=function(v) if guard=='issecretvalue' then return rawequal(v,opaque) end;return not rawequal(v,opaque) end
        local p=fixture(env)
        for _,method in ipairs({'GetSpellInfo','GetSpellCooldown','IsSpellKnown'}) do
            local value,why=p[method](p,974);assert(value==nil and why=='restricted-value',method)
        end
        env.C_Spell.GetSpellInfo=function() return opaque end
        local value,why=p:GetSpellInfo(974);assert(value==nil and why=='restricted-value')
    end
end)
test('native spell links preserve names and reject unreadable results without legacy fallback',function()
    local link='|cff71d5ff|Hspell:403|h[Lightning Bolt]|h|r'
    local p=fixture({C_Spell={GetSpellLink=function(id) assert(id==403);return link end}})
    assert(p:GetSpellLink(403)==link)
    p=fixture({GetSpellLink=function(id) assert(id==403);return link end})
    assert(p:GetSpellLink(403)==link)
    local opaque={}
    p=fixture({C_Spell={GetSpellLink=function() return opaque end},canaccessvalue=function(v) return not rawequal(v,opaque) end,
        GetSpellLink=function() error('restricted native value must not fall back') end})
    local value,why=p:GetSpellLink(403);assert(value==nil and why=='restricted-value')
end)
test('readiness distinguishes active cooldowns from the GCD and preserves unavailable data',function()
    local records={
        [8042]={startTime=98,duration=6,isEnabled=true,modRate=1},
        [29515]={startTime=99.5,duration=1.5,isEnabled=true,modRate=1},
    }
    local p=fixture({WOW_PROJECT_ID=5,WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5,
        C_Spell={GetSpellCooldown=function(id) return records[id] end}})
    assert(p:IsSpellReady(8042,100)==false)
    records[8042]={startTime=99.5,duration=1.5,isEnabled=true,modRate=1}
    assert(p:IsSpellReady(8042,100)==true)
    records[8042]={startTime=94,duration=6,isEnabled=true,modRate=2}
    assert(p:IsSpellReady(8042,100)==true)
    records[8042]={startTime=0,duration=0,isEnabled=false,modRate=1}
    assert(p:IsSpellReady(8042,100)==false)
    records[8042]=nil
    local ready,why=p:IsSpellReady(8042,100);assert(ready==nil and why=='spell-data-unavailable')
    records[8042]={startTime=98,duration=6,isEnabled=true,modRate=1}
    records[29515]=nil
    ready,why=p:IsSpellReady(8042,100);assert(ready==nil and why=='spell-data-unavailable')
    records[8042]={startTime=0,duration=0,isEnabled=true,modRate=1}
    assert(p:IsSpellReady(8042,100)==true,'ready spells do not require a GCD observation')
end)
test('charge records and legacy tuples normalize full inactive and active recharge state',function()
    local original={currentCharges=1,maxCharges=2,cooldownStartTime=90,cooldownDuration=20,chargeModRate=2,isActive=true}
    local p=fixture({C_Spell={GetSpellCharges=function() return original end}})
    local record=assert(p:GetSpellCharges(974))
    assert(record.currentCharges==1 and record.isActive and record.chargeModRate==2)
    record.currentCharges=0;assert(original.currentCharges==1)
    p=fixture({GetSpellCharges=function() return 2,2,0,20 end})
    record=assert(p:GetSpellCharges(974));assert(not record.isActive and record.chargeModRate==1)
    p=fixture({GetSpellCharges=function() return 0,2,90,20,1 end})
    record=assert(p:GetSpellCharges(974));assert(record.isActive and record.currentCharges==0)
end)
test('charge ambiguity missing and malformed values remain explicit',function()
    for _,env in ipairs({{}, {C_Spell={GetSpellCharges=function() return nil end}},
        {C_Spell={GetSpellCharges=function() return {currentCharges=3,maxCharges=2,cooldownStartTime=0,cooldownDuration=0} end}},
        {C_Spell={GetSpellCharges=function() return {currentCharges=0,maxCharges=2,cooldownStartTime=-1,cooldownDuration=10} end}}}) do
        local p=fixture(env);local record,why=p:GetSpellCharges(974);assert(record==nil and type(why)=='string')
    end
    local opaque={};local p=fixture({C_Spell={GetSpellCharges=function()
        return {currentCharges=opaque,maxCharges=2,cooldownStartTime=0,cooldownDuration=10} end},
        GetSpellCharges=function() error('no legacy fallback') end,canaccessvalue=function(v) return not rawequal(v,opaque) end})
    local record,why=p:GetSpellCharges(974);assert(record==nil and why=='restricted-value')
end)
test('active spell normalization preserves false and refuses native failure fallback',function()
    local p=fixture({C_Spell={IsCurrentSpell=function() return false end}})
    assert(p:IsCurrentSpell(974)==false)
    p=fixture({IsCurrentSpell=function() return 1 end});assert(p:IsCurrentSpell(974))
    p=fixture({IsCurrentSpell=function() return 0 end});assert(p:IsCurrentSpell(974)==false)
    p=fixture({C_Spell={IsCurrentSpell=function() error('unavailable') end},IsCurrentSpell=function() return true end})
    local active,why=p:IsCurrentSpell(974);assert(active==nil and why=='api-error')
end)
test('all charge fields guard secrets and malformed records before arithmetic',function()
    local opaque={}
    for _,field in ipairs({'currentCharges','maxCharges','cooldownStartTime','cooldownDuration','chargeModRate','isActive'}) do
        local record={currentCharges=1,maxCharges=2,cooldownStartTime=90,cooldownDuration=20,chargeModRate=1,isActive=true}
        record[field]=opaque
        local p=fixture({C_Spell={GetSpellCharges=function() return record end},
            canaccessvalue=function(v) return not rawequal(v,opaque) end})
        local value,why=p:GetSpellCharges(974);assert(value==nil and why=='restricted-value',field)
    end
    for _,bad in ipairs({{currentCharges=-1},{currentCharges=.5},{maxCharges=0},{maxCharges=1.5},
        {cooldownDuration=-1},{chargeModRate=0},{cooldownStartTime=0/0},{cooldownDuration=math.huge},
        {currentCharges=2,isActive=true},{cooldownStartTime=0,isActive=true}}) do
        local record={currentCharges=1,maxCharges=2,cooldownStartTime=90,cooldownDuration=20,chargeModRate=1}
        for key,x in pairs(bad) do record[key]=x end
        local p=fixture({C_Spell={GetSpellCharges=function() return record end}})
        local value,why=p:GetSpellCharges(974);assert(value==nil and why=='invalid-api-result')
    end
end)
test('missing nil restricted and invalid active state never become ordinary false',function()
    local opaque={}
    for _,env in ipairs({{}, {C_Spell={IsCurrentSpell=function() end}},
        {C_Spell={IsCurrentSpell=function() return 1 end}},
        {C_Spell={IsCurrentSpell=function() return opaque end},issecretvalue=function(v) return rawequal(v,opaque) end}}) do
        local p=fixture(env);local value,why=p:IsCurrentSpell(974);assert(value==nil and type(why)=='string')
    end
    local p=fixture({C_Spell={GetSpellCharges=function() error('native failure') end},
        GetSpellCharges=function() error('legacy fallback') end})
    local value,why=p:GetSpellCharges(974);assert(value==nil and why=='api-error')
end)
local function repeatFixture(values)
    values=values or {};values.WOW_PROJECT_ID=values.WOW_PROJECT_ID or 5;values.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
    return fixture(values)
end
test('auto-repeat observation uses modern exact IDs and preserves a native false',function()
    local active=true
    local p,e=repeatFixture({C_Spell={IsAutoRepeatSpell=function(id) assert(id==5019);return active end},
        IsAutoRepeatSpell=function() error('native observation fell through') end})
    assert(p.IsAutoRepeatActive,'auto-repeat adapter missing')
    assert(p:IsAutoRepeatActive(5019)==true)
    active=false;assert(p:IsAutoRepeatActive(5019)==false)
    e.C_Spell.IsAutoRepeatSpell=function() error('failed native observation') end
    local value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='api-error')
end)
test('legacy auto-repeat resolves an explicit player book slot without mistaking the spell ID for a slot',function()
    local active=1
    local p,e=repeatFixture({BOOKTYPE_SPELL='spell',FindSpellBookSlotBySpellID=function(id,pet) assert(id==5019 and pet==false);return 17 end,
        IsAutoRepeatSpell=function(slot,bank) assert(slot==17 and bank=='spell');return active end})
    assert(p.IsAutoRepeatActive,'auto-repeat adapter missing')
    assert(p:IsAutoRepeatActive(5019)==true)
    active=0;assert(p:IsAutoRepeatActive(5019)==false)
    active=false;assert(p:IsAutoRepeatActive(5019)==false)
    e.FindSpellBookSlotBySpellID=function() return nil end
    local value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='spell-not-in-book')
end)
test('auto-repeat input results and policy fail closed without uncertain native fallback',function()
    local opaque={};local calls=0
    local p,e=repeatFixture({canaccessvalue=function(v) return v~=opaque end,
        C_Spell={IsAutoRepeatSpell=function() calls=calls+1;return false end},
        IsAutoRepeatSpell=function() error('must not fall through') end})
    assert(p.IsAutoRepeatActive,'auto-repeat adapter missing')
    for _,id in ipairs({0,-1,1.5,math.huge,0/0,'Shoot',{},opaque}) do assert(p:IsAutoRepeatActive(id)==nil) end
    assert(calls==0,'invalid identifier queried the game')
    for _,result in ipairs({opaque,1,0,'true',{}}) do
        e.C_Spell.IsAutoRepeatSpell=function() return result end
        assert(p:IsAutoRepeatActive(5019)==nil,'malformed native result became an observation')
    end
    e.C_Spell.IsAutoRepeatSpell=function() return nil end;assert(p:IsAutoRepeatActive(5019)==nil)
    e.C_Spell.IsAutoRepeatSpell=function() error('policy must prevent query') end
    e.WOW_PROJECT_ID=999;local value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='unsupported-policy')
    e.WOW_PROJECT_ID=nil;value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='unsupported-policy')
end)
test('missing auto-repeat APIs and malformed legacy slots remain unavailable',function()
    local p,e=repeatFixture();assert(p.IsAutoRepeatActive,'auto-repeat adapter missing')
    local value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='missing-api')
    e.IsAutoRepeatSpell=function() error('invalid slot queried') end
    value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='missing-api')
    for _,slot in ipairs({0,-1,1.5,math.huge,{},'17'}) do
        e.FindSpellBookSlotBySpellID=function() return slot end
        assert(p:IsAutoRepeatActive(5019)==nil)
    end
    e.FindSpellBookSlotBySpellID=function() error('book unavailable') end
    value,why=p:IsAutoRepeatActive(5019);assert(value==nil and why=='api-error')
end)
test('readiness from the multi-value cooldown API matches the C_Spell record path',function()
    local spells={}
    local function record(id) local c=spells[id];return c and {startTime=c[1],duration=c[2],isEnabled=c[3]==1,modRate=1} end
    local modern=fixture({C_Spell={GetSpellCooldown=record}})
    local legacy=fixture({C_Spell={GetSpellCooldown=function() error('record API used') end},
        GetSpellCooldown=function(id) local c=spells[id];if c then return c[1],c[2],c[3] end end})
    legacy.secretsUnrestricted=true
    local gcd=modern:GetClientInfo().family=='tbc' and 29515 or 61304
    local cases={
        {'ready',{0,0,1},{0,0,1}},
        {'expired',{90,5,1},{0,0,1}},
        {'cooling past the GCD',{99,30,1},{99,1.5,1}},
        {'inside the GCD',{99,1.5,1},{99,1.5,1}},
        {'disabled',{0,0,0},{0,0,1}},
        {'no GCD running',{99,30,1},{0,0,1}},
    }
    for _,case in ipairs(cases) do
        spells[403],spells[gcd]=case[2],case[3]
        local a,b=modern:IsSpellReady(403,100),legacy:IsSpellReady(403,100)
        assert(a==b,case[1]..': '..tostring(a)..' vs '..tostring(b))
    end
    spells[403]=nil
    local a,why=legacy:IsSpellReady(403,100);assert(a==nil and why=='spell-data-unavailable')
    spells[403]={0/0,0,1};a,why=legacy:IsSpellReady(403,100);assert(a==nil and why=='invalid-api-result')
    spells[403]={0,0,2};a,why=legacy:IsSpellReady(403,100);assert(a==nil and why=='invalid-api-result')
end)
finish()
