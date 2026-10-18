local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new(5,1,'MAGE');local a,e=f.addon,f.env
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=1,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[133]=true,[1459]=true,[168]=true},usable={},range={},cooldown={},auras={}}
    local names={[133]='Localized Fireball',[143]='Localized Fireball',[116]='Localized Frostbolt',[205]='Localized Frostbolt',
        [1459]='Localized Intellect',[1460]='Localized Intellect',[168]='Localized Armor',[7300]='Localized Armor'}
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.IsSpellKnown=function(id) return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id) return {name=names[id] or 'Spell '..id,spellID=id,subtext=(id==143 or id==205) and 'Rank 2' or 'Rank 1'} end,
        SpellHasRange=function(id) return id==133 or id==116 or id==143 or id==205 end,IsSpellInRange=function(id) return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false,false end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index) return s.auras[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/combat.lua',
        'Defaults/tbc/mage-starter.lua'}) do f.load(path) end
    e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet'
    e.GetAddOnMetadata=function() return 'Rotation Master test' end
    e.UnitGUID=function() return 'Player-test' end
    f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end}
    f.libraries['AceEvent-3.0']={}
    f.libraries['LibDBIcon-1.0']={}
    f.libraries['LibSharedMedia-3.0']={}
    f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
    f.libraries['ThreatClassic-1.0']={Disable=function() end}
    f.load('Core/rotation_sequence.lua');f.load('main.lua')
    for id in pairs(names) do a.SpellCatalog:UpdateSpell(id) end
    assert(a:InitializeRotationLibrary());return f,s
end
local function body(a)
    local row=a:ListDefaultRotations(0)[1];assert(row.eligible,row.eligibilityReason);return row.envelope.body
end
local function first(a)
    local ready=a:NewActionReadiness(100)
    local selected
    a:EvaluateRotationSequence(body(a),function(condition) return a:evaluateConditionResult(condition) end,function(step)
        if ready(step.type,step.action) and a:evaluateCondition(step.conditions) then selected=step.action;return false end
    end)
    return selected
end
local function optional(a)
    local actions={};local ready=a:NewActionReadiness(100)
    for _,step in ipairs(body(a).cooldowns) do if ready(step.type,step.action) and a:evaluateCondition(step.conditions) then actions[step.action]=true end end
    return actions
end
test('mage starter adapts to trained rank preferences rather than assuming trainer visits by level',function()
    local f,s=fixture();local a=f.addon
    assert(first(a)==133)
    s.level=4;s.known[116]=true;assert(first(a)==116)
    s.level=6;s.known[143]=true;assert(first(a)==133)
    s.level=8;s.known[205]=true;assert(first(a)==116)
    s.level=14;s.known[205]=nil;assert(first(a)==133,'untrained frost rank2 was assumed from level')
    s.known[143]=nil;assert(first(a)==116)
    s.known[116]=nil;assert(first(a)==133)
    s.combat=true;s.known[116]=true;s.known[143]=true;s.known[205]=true;assert(first(a)==116)
end)
test('preferred fillers cannot override native range usability or cooldown availability',function()
    local f,s=fixture();local a=f.addon;s.level=11;s.combat=true;s.known[116]=true;s.known[143]=true;s.known[205]=true
    s.range[116]=false;assert(first(a)==133)
    s.range[133]=false;assert(first(a)==nil)
    s.range={};s.usable[116]=false;assert(first(a)==133)
    s.usable={};s.cooldown[116]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(a)==133)
    s.cooldown[133]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(a)==nil)
end)
test('mage openers and combat priorities require stationary living hostile targets and respect the combat boundary',function()
    local f,s=fixture();local a=f.addon
    s.targetCombat=true;assert(first(a)==nil,'engaged target was pulled')
    s.targetCombat=false;s.moving=true;assert(first(a)==nil)
    s.moving=false;s.hostile=false;assert(first(a)==nil)
    s.hostile=true;s.dead=true;assert(first(a)==nil)
    s.dead=false;s.exists=false;assert(first(a)==nil)
    s.exists=true;s.combat=true;s.targetCombat=true;assert(first(a)==133)
    s.combat=false;assert(first(a)==nil,'combat filler escaped past the out-of-combat Stop')
    local found=false;for _,step in ipairs(body(a).rotation) do if step.type=='none' then found=true;assert(a:evaluateCondition(step.conditions) and not step.suppress_attack) end end;assert(found)
end)
test('optional upkeep recognizes higher ranks and other casters without blocking damage',function()
    local f,s=fixture();local a=f.addon
    assert(optional(a)[1459] and optional(a)[168] and first(a)==133)
    s.auras={{spellId=1460,name='Localized Intellect',sourceUnit='party1'},{spellId=7300,name='Localized Armor',sourceUnit='player'}}
    assert(not optional(a)[1459] and not optional(a)[168] and first(a)==133)
    s.auras={};s.known[1459]=nil;s.known[168]=nil
    assert(not optional(a)[1459] and not optional(a)[168] and first(a)==133)
end)
test('unavailable aura observations and learned state never become positive missing-buff advice',function()
    local f,s=fixture();local a=f.addon
    f.env.C_UnitAuras.GetAuraDataByIndex=function() error('auras unavailable') end
    assert(not optional(a)[1459] and not optional(a)[168])
    f.env.IsSpellKnown=nil;assert(not optional(a)[1459] and not optional(a)[168])
    local row=a:ListDefaultRotations(0)[1];assert(a:evaluateConditionResult(row.envelope.body.switch).status=='unavailable')
end)
test('mage preview is sourced localized read-only and expires at level20',function()
    local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1]
    assert(row.id=='rm.tbc.mage.starter' and row.readOnly and row.validation.valid and row.validation.supported and row.validation.resolved)
    assert(f.translations[row.nameKey] and f.translations[row.descriptionKey] and #row.envelope.sources>=2)
    s.level=20;assert(not a:ListDefaultRotations(0)[1].eligible)
end)
test('rank-expanded multi-step preview visits each filler family once per selected priority arm',function()
    local f,s=fixture();local a=f.addon
    local function preview()
        local ids={};local ready=a:NewActionReadiness(100)
        a:EvaluateRotationSequence(body(a),function(condition) return a:evaluateConditionResult(condition) end,function(step)
            if a:evaluateCondition(step.conditions) then
                for _,id in ipairs(a:GetSpellIds(step)) do
                    if ready(step.type,id) then ids[#ids+1]=id;break end
                end
            end
        end)
        return table.concat(ids,',')
    end
    s.known[116]=true;s.known[143]=true;s.known[205]=true
    assert(preview()=='205,143',preview())
    s.combat=true;assert(preview()=='205,143',preview())
    s.known[205]=nil;assert(preview()=='143,116',preview())
    s.known[143]=nil;assert(preview()=='116,133',preview())
    s.known[143]=true;s.known[205]=true;s.usable[205]=false
    assert(preview()=='116,143','existing rank fallback changed: '..preview())
    s.usable[116]=false;assert(preview()=='143',preview())
    s.usable[143]=false;s.usable[133]=false;assert(preview()=='',preview())
end)
finish()
