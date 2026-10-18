local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(modern)
    local f=F.new()
    f.env.UnitExists=function(unit) return unit~='target' end
    f.env.C_UnitAuras=modern and {GetAuraDataByIndex=function() end} or nil
    for _,path in ipairs({'Platform/client.lua','Platform/auras.lua','Core/conditions.lua',
        'Core/aura_conditions.lua','Conditions/buffs.lua','Conditions/debuffs.lua'}) do f.load(path) end
    return f
end
local function buff(f,records)
    f.env.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter)
        assert(filter=='HELPFUL');return records[index]
    end}
end
local function value(tag,extra)
    local v={type=tag,unit='focus',spell='Earth Shield',operator='LESSTHAN',value=4}
    for k,x in pairs(extra or {}) do v[k]=x end
    return v
end
test('healer maintenance checks the requested unit, caster and charges',function()
    local f=fixture(true)
    buff(f,{{name='Earth Shield',spellId=974,sourceUnit='party2',applications=6,duration=600,expirationTime=200},
            {name='Earth Shield',spellId=974,sourceUnit='player',applications=2,duration=600,expirationTime=103}})
    assert(f.addon:evaluateCondition(value('BUFF',{ownbuff=true})))
    assert(f.addon:evaluateCondition(value('BUFF_REMAIN',{ownbuff=true})))
    assert(f.addon:evaluateCondition(value('BUFF_STACKS',{ownbuff=true})))
    assert(not f.addon:evaluateCondition(value('BUFF_STACKS',{ownbuff=false})))
end)
test('portable spell IDs and legacy saved names both work',function()
    local f=fixture(false)
    f.env.UnitAura=function(_,index,filter)
        assert(filter=='HELPFUL')
        if index==1 then return 'Earth Shield',123,2,nil,600,103,'player',nil,nil,974 end
    end
    assert(f.addon:evaluateCondition(value('BUFF',{spell=974})))
    assert(f.addon:evaluateCondition(value('BUFF')))
    assert(not f.addon:evaluateCondition(value('BUFF',{spell=999})))
end)
test('permanent buffs never trigger refresh thresholds while absent buffs are distinct',function()
    local f=fixture(true)
    buff(f,{{name='Earth Shield',spellId=974,sourceUnit='player',applications=0,duration=0,expirationTime=0}})
    assert(not f.addon:evaluateCondition(value('BUFF_REMAIN')))
    assert(f.addon:evaluateCondition(value('BUFF_REMAIN',{operator='GREATERTHAN',value=600})))
    buff(f,{})
    assert(not f.addon:evaluateCondition(value('BUFF_REMAIN',{operator='EQUALS',value=0})))
    assert(f.addon:evaluateCondition({type='NOT',value=value('BUFF')}))
end)
test('restricted timer is unavailable through NOT while readable presence still works',function()
    local f=fixture(true)
    local opaque={}
    f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    buff(f,{{name='Earth Shield',spellId=974,sourceUnit='player',applications=6,duration=600,expirationTime=opaque}})
    assert(f.addon:evaluateCondition(value('BUFF')))
    local result=f.addon:evaluateConditionResult({type='NOT',value=value('BUFF_REMAIN')})
    assert(result.status=='unavailable' and result.reason=='restricted-value')
    buff(f,{{name=opaque,spellId=opaque}})
    assert(f.addon:evaluateConditionResult({type='NOT',value=value('BUFF')}).status=='unavailable')
end)
test('missing APIs do not look like absent buffs and missing units are ordinary no-match',function()
    local f=fixture(false)
    assert(f.addon:evaluateConditionResult({type='NOT',value=value('BUFF')}).status=='unavailable')
    assert(not f.addon:evaluateCondition(value('BUFF',{unit='target'})))
end)
test('debuff presence, remaining time and charges use the same contracts',function()
    local f=fixture(true)
    f.env.UnitExists=function() return true end
    f.env.C_UnitAuras.GetAuraDataByIndex=function(unit,index,filter)
        assert(unit=='target' and filter=='HARMFUL')
        if index==1 then return {name='Curse',spellId=99,sourceUnit='player',applications=2,duration=30,expirationTime=103} end
    end
    for _,tag in ipairs({'DEBUFF','DEBUFF_REMAIN','DEBUFF_STACKS'}) do
        assert(f.addon:evaluateCondition(value(tag,{unit='target',spell=99,owndebuff=true})),tag)
    end
end)
test('dispellable is passed as the RAID aura filter and enrage uses empty dispel type',function()
    local f=fixture(true)
    f.env.C_UnitAuras.GetAuraDataByIndex=function(_,index,filter)
        if filter=='HARMFUL|RAID' then return nil end
        assert(filter=='HARMFUL')
        if index==1 then return {name='Enrage',spellId=99,dispelName='',sourceUnit='player'} end
    end
    local v={type='DISPELLABLE',unit='focus',debufftype='Enrage',owndebuff=true,dispellable=false}
    assert(f.addon:evaluateCondition(v))
    v.dispellable=true;assert(not f.addon:evaluateCondition(v))
end)
test('a bounded scan can find buffs beyond forty and never treats truncation as absence',function()
    local f=fixture(true)
    local calls=0
    f.env.C_UnitAuras.GetAuraDataByIndex=function(_,index)
        calls=calls+1
        if index==45 then return {name='Earth Shield',spellId=974} end
        return {name='Other',spellId=1}
    end
    assert(f.addon:evaluateCondition(value('BUFF')) and calls==45)
    calls=0
    local result=f.addon:evaluateConditionResult(value('BUFF',{spell='Not Present'}))
    assert(result.status=='unavailable' and result.reason=='aura-scan-limit' and calls==256)
end)
test('one evaluation reuses normalized observations for related maintenance checks',function()
    local f=fixture(true)
    local calls=0
    f.env.C_UnitAuras.GetAuraDataByIndex=function(_,index)
        calls=calls+1
        if index==1 then return {name='Earth Shield',spellId=974,applications=2,expirationTime=103,duration=600} end
    end
    assert(f.addon:evaluateCondition({type='AND',value={value('BUFF'),value('BUFF_REMAIN'),value('BUFF_STACKS')}}))
    assert(calls==1,'related predicates repeatedly queried the client')
end)
test('stealable buffs use modern observations and preserve unavailable under NOT',function()
    local f=fixture(true)
    local opaque={}
    f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    buff(f,{{name='Buff',spellId=1,isStealable=true}})
    local v={type='STEALABLE',unit='focus'}
    assert(f.addon:evaluateCondition(v))
    buff(f,{{name='Buff',spellId=1,isStealable=opaque}})
    assert(f.addon:evaluateConditionResult({type='NOT',value=v}).status=='unavailable')
    buff(f,{})
    assert(f.addon:evaluateCondition({type='NOT',value=v}))
    f.env.C_UnitAuras=nil
    f.env.UnitAura=function(_,index)
        if index==1 then return 'Buff',1,0,nil,0,0,'player',true,nil,1 end
    end
    assert(f.addon:evaluateCondition(v))
end)
test('a later readable presence match is decisive after an unreadable aura',function()
    local f=fixture(true)
    local opaque={}
    f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    buff(f,{{name=opaque,spellId=opaque}, {name='Earth Shield',spellId=974,sourceUnit='player'}})
    assert(f.addon:evaluateCondition(value('BUFF',{ownbuff=true})))
    assert(f.addon:evaluateConditionResult({type='NOT',value=value('BUFF',{spell='Not present'})}).status=='unavailable')
end)
test('the final allowed aura can provide a readable presence match',function()
    local f=fixture(true)
    local calls=0
    f.env.C_UnitAuras.GetAuraDataByIndex=function(_,index)
        calls=calls+1
        return {name=index==256 and 'Earth Shield' or 'Other',spellId=1}
    end
    assert(f.addon:evaluateCondition(value('BUFF')) and calls==256)
end)
finish()
