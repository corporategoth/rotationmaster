local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a,e=f.addon,f.env
    e.WOW_PROJECT_BURNING_CRUSADE_CLASSIC=5
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    a.getCached=function(_,fn,...) return fn(...) end
    local state={level=11,combat=false,known={[6603]=true,[403]=true,[8017]=true,[324]=true,[8042]=true},enchanted=false,auras={},hostile=true,targetCombat=false,near=true,moving=false,attacking=false,dead=false}
    e.UnitExists=function(unit) return unit=='player' or unit=='target' end
    e.UnitLevel=function() return state.level end
    e.UnitAffectingCombat=function(unit) if unit=='player' then return state.combat end;return state.targetCombat end
    e.UnitCanAttack=function() return state.hostile end
    e.UnitIsDead=function() return state.dead end
    e.UnitHasVehicleUI=function() return false end
    e.IsSpellKnown=function(id) return state.known[id]==true end
    e.C_Spell={IsSpellInRange=function(id) if id==6603 then return state.near end;return true end,
        SpellHasRange=function(id) return id~=324 and id~=8017 end,
        IsSpellUsable=function() return true,false end,
        GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true,modRate=1} end,
        IsCurrentSpell=function(id) assert(id==6603);return state.attacking end}
    e.GetUnitSpeed=function() return state.moving and 7 or 0 end
    e.GetWeaponEnchantInfo=function() return state.enchanted end
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index) return state.auras[index] end}
    for _,path in ipairs({'Platform/client.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua',
        'Core/aura_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua',
        'Core/rotation_library.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua',
        'Conditions/combat.lua','Conditions/weapon.lua','Conditions/range.lua','Defaults/tbc/shaman-starter.lua'}) do f.load(path) end
    assert(a:InitializeRotationLibrary())
    return f,state
end
local function first(a)
    local row=a:ListDefaultRotations(0)[1]
    assert(row.eligible,row.eligibilityReason)
    local ready=a:NewActionReadiness(100)
    for _,step in ipairs(row.envelope.body.rotation) do
        if step.type=='none' and a:evaluateCondition(step.conditions) then return nil end
        if ready(step.type,step.action) and a:evaluateCondition(step.conditions) then return step.action end
    end
end
test('shipped starter pack is sourced, localized, valid and scoped to early TBC shaman',function()
    local f,state=fixture();local a=f.addon
    local row=a:ListDefaultRotations(0)[1]
    assert(row.validation.valid and row.validation.supported and row.validation.resolved)
    assert(f.translations[row.nameKey] and f.translations[row.descriptionKey])
    assert(#row.envelope.sources>0 and row.envelope.sources[1].reviewedAt)
    for _,step in ipairs(row.envelope.body.rotation) do assert(a:validateCondition(step.conditions,0)) end
    state.level=20
    assert(not a:ListDefaultRotations(0)[1].eligible)
end)
test('upkeep stays optional and cannot block the sequential damage recommendation',function()
    local f,state=fixture();local a=f.addon
    local row=a:ListDefaultRotations(0)[1]
    assert(#row.envelope.body.cooldowns==2,'upkeep is not in optional highlights')
    local function optional()
        local actions={};local ready=a:NewActionReadiness(100)
        for _,step in ipairs(row.envelope.body.cooldowns) do if ready(step.type,step.action) and a:evaluateCondition(step.conditions) then actions[step.action]=true end end
        return actions
    end
    assert(first(a)==403,'missing upkeep blocked the opener')
    assert(optional()[8017] and optional()[324])
    state.enchanted=true;state.auras={{name='Localized shield',spellId=324,sourceUnit='player'}}
    assert(not optional()[8017] and not optional()[324])
    state.level=16;state.auras={{name='Localized shield',spellId=325,sourceUnit='player'}}
    assert(not optional()[324],'rank2 shield must not prompt a rank1 refresh')
    state.combat=true;state.enchanted=false;state.auras={}
    assert(first(a)==8042 and optional()[8017] and optional()[324],'combat must retain independent upkeep highlights')
    state.known[8042]=nil
    assert(first(a)==nil,'unlearned shock was recommended in melee')
    state.near=false;assert(first(a)==403,'ranged target should retain Lightning Bolt as a filler')
    state.moving=true;assert(first(a)==nil,'do not recommend a cast-time filler while moving')
    state.moving=false;state.near=true
    state.combat=false;state.targetCombat=true
    assert(first(a)==nil,'do not prompt a pull on an engaged target')
    state.targetCombat=false;state.hostile=false
    assert(first(a)==nil,'friendly target must not suggest an attack')
    state.known[324]=nil;state.known[8017]=nil
    assert(not optional()[8017] and not optional()[324])
end)
test('unavailable learned-state and aura identity cannot recommend upkeep under NOT',function()
    local f,state=fixture();local a=f.addon
    state.enchanted=true
    f.env.IsSpellKnown=nil
    assert(first(a)==nil,'missing learned state became a recommended action')
    f.env.IsSpellKnown=function(id) return state.known[id]==true end
    f.env.C_UnitAuras.GetAuraDataByIndex=function() error('aura query unavailable') end
    local row=a:ListDefaultRotations(0)[1]
    local result=a:evaluateConditionResult(row.envelope.body.cooldowns[2].conditions)
    assert(result.status=='unavailable')
end)
test('starter leaves weapon Attack to the implicit final priority and keeps authored upkeep optional',function()
    local f=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1]
    for _,section in ipairs({'rotation','cooldowns'}) do
        for _,step in ipairs(row.envelope.body[section]) do assert(step.action~=6603,'starter still authors an independent Attack reminder') end
    end
    for _,step in ipairs(row.envelope.body.cooldowns) do
        assert(step.action==8017 or step.action==324,'non-upkeep action occupies the optional section')
    end
end)
test('starter separates its opener from combat priorities with one Stop when out of combat',function()
    local f,s=fixture();local a=f.addon
    local body=a:ListDefaultRotations(0)[1].envelope.body
    assert(body.rotation[1].action==403 and body.rotation[2].type=='none','missing explicit pre-combat boundary after opener')
    assert(body.rotation[2].suppress_attack~=true,'default boundary should not suppress the independent melee fallback')
    assert(a:evaluateCondition(body.rotation[2].conditions))
    s.combat=true;assert(not a:evaluateCondition(body.rotation[2].conditions))
    for index=3,#body.rotation do
        local step=body.rotation[index]
        assert(a:validateCondition(step.conditions,0))
    end
end)
finish()
