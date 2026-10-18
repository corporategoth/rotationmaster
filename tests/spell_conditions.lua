local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    f.env.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
    f.env.GetBuildInfo=function() return '2.5.6','70006','',20506 end
    f.env.UnitExists=function() return true end
    f.env.Enum.SpellBookSpellBank={Player=0,Pet=1}
    f.env.C_Spell={GetSpellInfo=function(id) return {name='Earth Shock',spellID=type(id)=='number' and id or 8042} end,
        GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true} end,
        IsSpellInRange=function() return true end,SpellHasRange=function() return true end}
    f.env.C_SpellBook={IsSpellKnown=function() return true end}
    local compress=f.libraries.LibCompress
    compress.fcs16init=function() return '' end
    compress.fcs16update=function(_,hash,part) return hash..part..'|' end
    compress.fcs16final=function(_,hash) return hash end
    for _,path in ipairs({'Platform/client.lua','Platform/spells.lua','Platform/actions.lua','Core/conditions.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/petspell.lua','Conditions/anyspell.lua'}) do f.load(path) end
    return f
end
local function value(tag,extra)
    local v={type=tag,spell=8042,ranked=true,operator='EQUALS',value=0}
    for key,x in pairs(extra or {}) do v[key]=x end
    return v
end
for _,prefix in ipairs({'SPELL','PETSPELL','ANYSPELL'}) do
    test(prefix..' modern-only availability and cooldown share GCD/held/expired behavior',function()
        local f=fixture();local a=f.addon;local spell,gcd={startTime=0,duration=0,isEnabled=true},{startTime=99,duration=1.5,isEnabled=true}
        f.env.C_Spell.GetSpellCooldown=function(id) return id==29515 and gcd or spell end
        assert(a:evaluateCondition(value(prefix..'_AVAIL')))
        spell={startTime=98,duration=6,isEnabled=true}
        assert(not a:evaluateCondition(value(prefix..'_AVAIL')),'own cooldown was allowed')
        assert(a:evaluateCondition(value(prefix..'_COOLDOWN',{value=4})))
        spell={startTime=99,duration=1.5,isEnabled=true}
        assert(a:evaluateCondition(value(prefix..'_AVAIL')),'GCD only was suppressed')
        spell={startTime=90,duration=6,isEnabled=true}
        assert(a:evaluateCondition(value(prefix..'_AVAIL')) and a:evaluateCondition(value(prefix..'_COOLDOWN')))
        spell={startTime=0,duration=0,isEnabled=false}
        assert(not a:evaluateCondition(value(prefix..'_AVAIL')))
        assert(a:evaluateConditionResult({type='NOT',value=value(prefix..'_COOLDOWN')}).status=='unavailable')
    end)
    test(prefix..' range preserves readable true/false, rangeless and unknown observations',function()
        local f=fixture();local a=f.addon
        assert(a:evaluateCondition(value(prefix..'_RANGE')))
        f.env.C_Spell.IsSpellInRange=function() return false end
        assert(not a:evaluateCondition(value(prefix..'_RANGE')))
        f.env.C_Spell.IsSpellInRange=function() return nil end
        local result=a:evaluateConditionResult({type='NOT',value=value(prefix..'_RANGE')})
        assert(result.status=='unavailable',result.status)
        f.env.C_Spell.SpellHasRange=function() return false end
        assert(not a:evaluateCondition(value(prefix..'_RANGE')),'a rangeless spell does not satisfy an in-range predicate')
        assert(a:evaluateCondition({type='NOT',value=value(prefix..'_RANGE')}))
    end)
end
test('pet learned state unavailable stays unavailable through NOT for all pet predicates',function()
    local f=fixture();local a=f.addon
    f.env.C_SpellBook.IsSpellKnown=function(_,bank) assert(bank==1);return nil end
    for tag in pairs(a.conditionDefinitions) do if tag:match('^PETSPELL_') then
        assert(a:evaluateConditionResult({type='NOT',value=value(tag)}).status=='unavailable',tag)
    end end
end)
test('duplicate predicates reuse the same normalized observation inside one evaluation',function()
    local f=fixture();local calls=0
    f.env.C_Spell.GetSpellCooldown=function() calls=calls+1;return {startTime=0,duration=0,isEnabled=true} end
    assert(f.addon:evaluateCondition({type='AND',value={value('SPELL_AVAIL'),value('SPELL_AVAIL')}}))
    assert(calls==1,'same spell observed twice in one tree')
end)
test('restricted and failing modern observations stay unavailable under NOT without legacy fallback',function()
    for _,suffix in ipairs({'AVAIL','COOLDOWN','RANGE'}) do
        for _,prefix in ipairs({'SPELL','PETSPELL','ANYSPELL'}) do
            local f=fixture();local opaque={}
            f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
            f.env.GetSpellCooldown=function() error('legacy fallback must not run') end
            f.env.IsSpellInRange=function() error('legacy fallback must not run') end
            f.env.C_Spell.GetSpellCooldown=function() return {startTime=0,duration=opaque,isEnabled=true} end
            f.env.C_Spell.IsSpellInRange=function() return opaque end
            local tree={type='NOT',value=value(prefix..'_'..suffix)}
            local result=f.addon:evaluateConditionResult(tree)
            assert(result.status=='unavailable' and result.reason=='restricted-value',prefix..suffix)
            f.env.C_Spell.GetSpellCooldown=function() error('native failure') end
            f.env.C_Spell.IsSpellInRange=function() error('native failure') end
            result=f.addon:evaluateConditionResult(tree)
            assert(result.status=='unavailable' and result.reason=='api-error',prefix..suffix)
        end
    end
end)
test('legacy range checks preserve player/pet slots and player-or-pet fallback',function()
    local f=fixture();f.env.C_Spell=nil;f.env.C_SpellBook=nil
    f.env.GetSpellInfo=function(id) return 'Earth Shock','Rank 1',1,0,0,20,type(id)=='number' and id or 8042 end
    f.env.IsSpellKnown=function(_,pet) return pet end
    f.env.GetSpellCooldown=function(id) if id==29515 then return 0,0,1 end;return 98,6,1 end
    f.env.FindSpellBookSlotBySpellID=function(_,pet) if pet then return 4 end end
    local checks={}
    f.env.IsSpellInRange=function(slot,bank,unit) checks[#checks+1]={slot,bank,unit};return 1 end
    assert(f.addon:evaluateCondition(value('PETSPELL_RANGE')))
    assert(f.addon:evaluateCondition(value('ANYSPELL_RANGE')))
    assert(#checks==2 and checks[1][1]==4 and checks[1][2]=='pet' and checks[2][2]=='pet')
    assert(f.addon:evaluateConditionResult({type='NOT',value=value('SPELL_RANGE')}).status=='unavailable')
    assert(f.addon:evaluateCondition(value('PETSPELL_COOLDOWN',{value=4})))
    f.env.IsSpellKnown=function() return false end
    assert(not f.addon:evaluateCondition(value('PETSPELL_AVAIL')))
    assert(f.addon:evaluateCondition({type='NOT',value=value('PETSPELL_AVAIL')}))
end)
for _,prefix in ipairs({'SPELL','PETSPELL','ANYSPELL'}) do
    test(prefix..' charge count and next recharge time use modern records without negative/full timers',function()
        local f=fixture();local a=f.addon
        local record={currentCharges=1,maxCharges=2,cooldownStartTime=90,cooldownDuration=20,chargeModRate=2}
        f.env.C_Spell.GetSpellCharges=function() return record end
        assert(a:evaluateCondition(value(prefix..'_CHARGES',{value=1})))
        assert(a:evaluateCondition(value(prefix..'_REMAIN',{value=10})))
        record.currentCharges=2
        assert(a:evaluateCondition(value(prefix..'_REMAIN')),'full charges retained a timer')
        record.currentCharges=0;record.cooldownStartTime=70
        assert(a:evaluateCondition(value(prefix..'_REMAIN')),'expired recharge became negative')
        f.env.C_Spell.GetSpellCharges=function() return nil end
        for _,suffix in ipairs({'CHARGES','REMAIN'}) do
            local result=a:evaluateConditionResult({type='NOT',value=value(prefix..'_'..suffix)})
            assert(result.status=='unavailable' and result.reason=='spell-charges-unavailable')
        end
    end)
end
test('active spell predicates use the guarded modern API and remain unknown under NOT',function()
    for _,prefix in ipairs({'SPELL','PETSPELL'}) do
        local f=fixture();local a=f.addon
        f.env.C_Spell.IsCurrentSpell=function() return true end
        assert(a:evaluateCondition(value(prefix..'_ACTIVE')))
        f.env.C_Spell.IsCurrentSpell=function() return false end
        assert(a:evaluateCondition({type='NOT',value=value(prefix..'_ACTIVE')}))
        f.env.C_Spell.IsCurrentSpell=function() return nil end
        assert(a:evaluateConditionResult({type='NOT',value=value(prefix..'_ACTIVE')}).status=='unavailable')
    end
end)
test('legacy charge tuples and active integers reach real predicates without modern globals',function()
    local f=fixture();local a=f.addon;f.env.C_Spell=nil;f.env.C_SpellBook=nil
    f.env.GetSpellInfo=function(id) return 'Earth Shock','Rank 1',1,0,0,20,type(id)=='number' and id or 8042 end
    f.env.IsSpellKnown=function() return true end
    f.env.GetSpellCharges=function() return 1,2,90,20,2 end
    f.env.IsCurrentSpell=function() return 1 end
    for _,prefix in ipairs({'SPELL','PETSPELL','ANYSPELL'}) do
        assert(a:evaluateCondition(value(prefix..'_CHARGES',{value=1})))
        assert(a:evaluateCondition(value(prefix..'_REMAIN',{value=10})))
    end
    assert(a:evaluateCondition(value('SPELL_ACTIVE')) and a:evaluateCondition(value('PETSPELL_ACTIVE')))
    f.env.GetSpellCharges=nil;f.env.IsCurrentSpell=nil
    for _,tag in ipairs({'SPELL_CHARGES','PETSPELL_REMAIN','ANYSPELL_CHARGES','SPELL_ACTIVE'}) do
        local result=a:evaluateConditionResult({type='NOT',value=value(tag)})
        assert(result.status=='unavailable' and result.reason=='missing-api',tag)
    end
end)
finish()
