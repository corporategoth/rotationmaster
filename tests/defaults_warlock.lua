local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new(5,1,'WARLOCK');local a,e=f.addon,f.env
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=1,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[686]=true,[348]=true,[687]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,channel=false,repeatActive=false,mapped={}}
    local families={[348]={348,707},[172]={172,6222},[980]={980,1014},[686]={686,695,705},[689]={689},[687]={687,696},[5019]={5019}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function() return s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id) return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id) return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        SpellHasRange=function(id) return id~=687 and id~=696 end,IsSpellInRange=function(id) return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false,false end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua','Defaults/tbc/warlock-starter.lua'}) do f.load(path) end
    e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function() return 'Rotation Master test' end
    e.UnitGUID=function() return 'Player-test' end
    f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
    f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
    f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
    f.libraries['ThreatClassic-1.0']={Disable=function() end}
    f.load('Core/rotation_sequence.lua');f.load('main.lua')
    for id in pairs(names) do a.SpellCatalog:UpdateSpell(id) end
    assert(a:InitializeRotationLibrary());return f,s,names
end
local function body(a)
    local row=a:ListDefaultRotations(0)[1];assert(row.eligible,row.eligibilityReason);return row.envelope.body
end
local function first(a,s)
    local ready=a:NewActionReadiness(100);local selected
    local result=a:EvaluateRotationSequence(body(a),function(c) return a:evaluateConditionResult(c) end,function(step)
        if a:evaluateCondition(step.conditions) then
            for _,id in ipairs(a:GetSpellIds(step)) do
                if s.mapped[id]~=false and ready(step.type,id) then selected=id;return false end
            end
        end
    end)
    return selected,result
end
local function dots(s,names,caster)
    s.debuffs={};for _,id in ipairs({707,6222,1014}) do s.debuffs[#s.debuffs+1]={spellId=id,name=names[id],sourceUnit=caster or 'player'} end
end
test('warlock trains abilities without assuming trainer visits and selects actual available ranks',function()
    local f,s,names=fixture();local a=f.addon
    assert(first(a,s)==348);s.usable[348]=false;assert(first(a,s)==686)
    s.level=19;assert(first(a,s)==686,'untrained ranks assumed from level')
    s.known[695]=true;s.known[705]=true;assert(first(a,s)==705)
    s.mapped[705]=false;assert(first(a,s)==695)
    s.usable[695]=false;assert(first(a,s)==686)
    s.known[172]=true;assert(first(a,s)==172)
    s.known[6222]=true;assert(first(a,s)==6222)
    dots(s,names);s.known[5019]=true;assert(first(a,s)==5019)
end)
test('warlock owned debuff rank families preserve other casters and prioritize missing dots',function()
    local f,s,names=fixture();local a=f.addon
    s.known[172]=true;s.known[980]=true;s.known[5019]=true
    dots(s,names,'party1');assert(first(a,s)==348,'another caster suppressed our Immolate')
    s.debuffs[1].sourceUnit='player';assert(first(a,s)==172)
    s.debuffs[2].sourceUnit='player';assert(first(a,s)==980)
    s.debuffs[3].sourceUnit='player';assert(first(a,s)==5019)
end)
test('warlock target combat and motion guards never advise inappropriate pulls or cast-time fillers',function()
    local f,s=fixture();local a=f.addon
    s.targetCombat=true;assert(first(a,s)==nil)
    s.combat=true;assert(first(a,s)==348)
    s.hostile=false;assert(first(a,s)==nil);s.hostile=true;s.dead=true;assert(first(a,s)==nil)
    s.dead=false;s.exists=false;assert(first(a,s)==nil);s.exists=true;s.moving=true;assert(first(a,s)==nil)
    s.known[980]=true;assert(first(a,s)==980,'instant curse should remain usable while moving')
end)
test('warlock native usability range cooldown and actual mappings govern all damage candidates',function()
    local f,s=fixture();local a=f.addon
    s.range[348]=false;assert(first(a,s)==686)
    s.usable[686]=false;assert(first(a,s)==nil)
    s.range={};s.cooldown[348]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(a,s)==nil)
    s.cooldown={};s.mapped[348]=false;local id,result=first(a,s)
    assert(not id and result.status=='stopped' and result.suppressAttack,'unavailable ranged actions enabled implicit melee')
end)
test('warlock drain choice preserves any started channel and active wand without toggling it off',function()
    local f,s,names=fixture();local a=f.addon;dots(s,names)
    s.combat=true;s.known[689]=true;s.known[5019]=true
    assert(first(a,s)==5019);s.health=69;assert(first(a,s)==689)
    s.channel=true;local id,result=first(a,s);assert(not id and result.status=='stopped' and result.suppressAttack)
    s.channel=false;s.health=70;s.repeatActive=true;id,result=first(a,s)
    assert(not id and result.status=='stopped' and result.suppressAttack)
    -- A missing DoT intentionally takes priority over continuing wanding.
    s.debuffs={};assert(first(a,s)==348)
end)
test('unknown wand blocks lower priorities while unknown aura checks never authorize DoT advice',function()
    local f,s,names=fixture();local a=f.addon;dots(s,names);s.known[5019]=true;s.repeatError=true
    local id,result=first(a,s);assert(not id and result.status=='unavailable' and result.suppressAttack)
    s.repeatError=false;s.auraError=true;assert(first(a,s)==5019,'unavailable aura data authorized a DoT')
    s.auraError=false;s.known[5019]=nil;s.repeatError=true;assert(first(a,s)==686,'unlearned wand observation blocked a trained filler')
end)
test('warlock independent Demon Skin reminder honors higher ranks and native availability',function()
    local f,s,names=fixture();local a=f.addon;local upkeep=body(a).cooldowns[1]
    local function optional()
        if not a:evaluateCondition(upkeep.conditions) then return false end
        local ready=a:NewActionReadiness(100)
        for _,id in ipairs(a:GetSpellIds(upkeep)) do if s.mapped[id]~=false and ready('spell',id) then return id end end
        return false
    end
    assert(optional()==687 and first(a,s)==348)
    s.buffs={{spellId=696,name=names[696],sourceUnit='player'}};assert(not optional() and first(a,s)==348)
    s.buffs={};s.known[687]=nil;assert(not optional())
    s.known[696]=true;assert(optional()==696)
    s.usable[696]=false;assert(not optional());s.usable={};s.auraError=true;assert(not optional())
end)
test('warlock manifest is localized sourced read-only bounded and clones have independent priorities',function()
    local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1]
    assert(row.id=='rm.tbc.warlock.starter' and row.readOnly and row.validation.valid and row.validation.resolved)
    assert(f.translations[row.nameKey] and f.translations[row.descriptionKey] and #row.envelope.sources==1)
    local id=assert(a:CloneDefaultRotation(0,row.id,'Warlock copy'));local clone=a:GetEditableRotation(0,id)
    clone.rotation[1].onTrue[1].suppress_attack=false;assert(body(a).rotation[1].onTrue[1].suppress_attack)
    s.level=20;assert(not a:ListDefaultRotations(0)[1].eligible)
end)
finish()
