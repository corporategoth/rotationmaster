local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local e,a=f.env,f.addon
    local state={known={spell={[403]=true,[6603]=true},pet={[974]=true}},range=true,usable=true,power=false,
        cooldown=0,count=1,itemRange=true,combat=true,hostile=true,dead=false,exists=true,vehicle=false,active=false}
    e.Enum.SpellBookSpellBank={Player=0,Pet=1}
    e.C_SpellBook={IsSpellKnown=function(id,bank) return state.known[bank==1 and 'pet' or 'spell'][id]==true end}
    e.C_Spell={GetSpellCooldown=function() return {startTime=99,duration=state.cooldown,isEnabled=true,modRate=1} end,
        IsSpellUsable=function() return state.usable,state.power end,
        SpellHasRange=function() return true end,IsSpellInRange=function() return state.range end,
        IsCurrentSpell=function() return state.active end}
    e.C_Item={GetItemCount=function() return state.count end,IsUsableItem=function() return true,false end,
        ItemHasRange=function() return true end,IsItemInRange=function() return state.itemRange end}
    e.C_Container={GetItemCooldown=function() return 99,state.cooldown,1 end}
    e.UnitExists=function() return state.exists end;e.UnitAffectingCombat=function() return state.combat end
    e.UnitCanAttack=function() return state.hostile end;e.UnitIsDeadOrGhost=function() return state.dead end
    e.UnitHasVehicleUI=function() return state.vehicle end
    for _,path in ipairs({'Platform/spells.lua','Platform/actions.lua','Platform/items.lua','Platform/range.lua','Core/action_policy.lua'}) do f.load(path) end
    return f,state
end
test('all spell banks implicitly require learned state readiness usability and range independently of explicit conditions',function()
    local f,s=fixture();local a=f.addon
    assert(a:NewActionReadiness(100)('spell',403))
    assert(a:NewActionReadiness(100)('pet',974))
    assert(a:NewActionReadiness(100)('any',974))
    assert(not a:NewActionReadiness(100)('spell',974) and not a:NewActionReadiness(100)('pet',403))
    s.known.spell[403]=nil;assert(not a:NewActionReadiness(100)('spell',403))
    s.known.spell[403]=true;s.cooldown=6
    -- The GCD is explicitly clear, so an ability's own cooldown cannot qualify.
    local original=f.env.C_Spell.GetSpellCooldown
    f.env.C_Spell.GetSpellCooldown=function(id) if id==29515 then return {startTime=0,duration=0,isEnabled=true,modRate=1} end;return original(id) end
    assert(not a:NewActionReadiness(100)('spell',403))
    s.cooldown=0;s.range=false
    assert(not a:NewActionReadiness(100)('spell',403),'an out-of-range spell was ready')
    s.range=true;s.usable=false;assert(not a:NewActionReadiness(100)('spell',403))
    s.usable=true;assert(a:NewActionReadiness(100)('spell',403))
end)
test('Ignore Range lets an out-of-range spell, pet spell and item through and still requires learned, usable and off cooldown',function()
    local f,s=fixture();local a=f.addon
    s.range=false;s.itemRange=false;assert(not a:NewActionReadiness(100)('spell',403) and not a:NewActionReadiness(100)('item',234,5512))
    a.db.profile.ignore_range=true
    assert(a:NewActionReadiness(100)('spell',403),'Ignore Range did not skip the spell range check')
    assert(a:NewActionReadiness(100)('pet',974) and a:NewActionReadiness(100)('any',974))
    assert(a:NewActionReadiness(100)('item',234,5512),'Ignore Range did not skip the item range check')
    s.known.spell[403]=nil;assert(not a:NewActionReadiness(100)('spell',403),'an unlearned spell was ready')
    s.known.spell[403]=true;s.usable=false;assert(not a:NewActionReadiness(100)('spell',403),'an unusable spell was ready')
    s.usable=true;s.cooldown=6;f.env.C_Spell.GetSpellCooldown=function(id) return {startTime=id==29515 and 0 or 99,duration=id==29515 and 0 or 6,isEnabled=true,modRate=1} end
    assert(not a:NewActionReadiness(100)('spell',403),'a spell on cooldown was ready')
    s.cooldown=0;s.count=0;assert(not a:NewActionReadiness(100)('item',234,5512),'an item you do not have was ready')
    a.db.profile.ignore_range=false;s.cooldown=0;s.count=1
    f.env.C_Spell.GetSpellCooldown=function() return {startTime=99,duration=0,isEnabled=true,modRate=1} end
    assert(not a:NewActionReadiness(100)('spell',403),'turning Ignore Range off did not restore the range check')
end)
test('Ignore Range does not read the range at all, and an unreadable range cannot hold a spell back',function()
    local f,s=fixture();local a=f.addon;local reads=0
    f.env.C_Spell.IsSpellInRange=function() reads=reads+1;return s.range end
    a.db.profile.ignore_range=true;s.range=nil
    assert(a:NewActionReadiness(100)('spell',403) and reads==0,'the range was read although it is ignored')
end)
test('Ignore Mana accepts the unusable-for-want-of-resource answer and nothing else',function()
    local f,s=fixture();local a=f.addon
    s.usable=false;s.power=true
    assert(not a:NewActionReadiness(100)('spell',403),'a spell without mana was ready by default')
    a.db.profile.ignore_mana=true
    assert(a:NewActionReadiness(100)('spell',403),'Ignore Mana did not accept the no-mana answer')
    s.usable=true;s.power=true;assert(a:NewActionReadiness(100)('spell',403))
    s.usable=false;s.power=false;assert(not a:NewActionReadiness(100)('spell',403),'an unusable spell with mana was ready')
    s.usable=false;s.power=true;s.range=false;assert(not a:NewActionReadiness(100)('spell',403),'Ignore Mana also ignored range')
    s.range=true;f.env.C_Spell.IsSpellUsable=function() return nil end
    assert(not a:NewActionReadiness(100)('spell',403),'an unreadable usability answer was accepted')
    local secret={};f.env.canaccessvalue=function(value) return value~=secret end
    f.env.C_Spell.IsSpellUsable=function() return secret,true end
    assert(not a:NewActionReadiness(100)('spell',403),'a hidden usability answer was accepted under Ignore Mana')
end)
test('both options are read at the start of every poll, including by the shared steady-state memo',function()
    local f,s=fixture();local a=f.addon;s.range=false;s.usable=false;s.power=true
    assert(not a:ResetActionReadiness(100)('spell',403))
    a.db.profile.ignore_mana=true;assert(not a:ResetActionReadiness(101)('spell',403),'range still holds the spell back')
    a.db.profile.ignore_range=true;assert(a:ResetActionReadiness(102)('spell',403),'the next poll did not see both options')
    a.db.profile.ignore_mana=false;assert(not a:ResetActionReadiness(103)('spell',403),'the next poll kept a cleared option')
end)
test('item availability uses its item ID rather than requiring its use spell to be learned',function()
    local f,s=fixture();local a=f.addon
    assert(a:NewActionReadiness(100)('item',234,5512))
    s.count=0;assert(not a:NewActionReadiness(100)('item',234,5512))
    s.count=1;s.cooldown=120;assert(not a:NewActionReadiness(100)('item',234,5512))
    s.cooldown=0;s.itemRange=false;assert(not a:NewActionReadiness(100)('item',234,5512))
    s.itemRange=true;assert(a:NewActionReadiness(100)('item',234,5512))
end)
-- C_Item.GetItemCooldown exists on Retail and Forever only (tests/fixtures/client_api_*.lua).
test('current boolean item cooldowns reach per-pass advice and unavailable results retry next pass',function()
    local f=fixture(1);local a=f.addon;local enabled,calls=true,0
    f.env.C_Container=nil
    f.env.C_Item.GetItemCooldown=function(id) assert(id==5512);calls=calls+1;return 0,0,enabled end
    f.env.GetItemCooldown=function() error('failed native observation must not fall back') end
    local ready=a:NewActionReadiness(100)
    assert(ready('item',234,5512) and ready('item',234,5512) and calls==1)
    enabled=nil;assert(not a:NewActionReadiness(100)('item',234,5512) and calls==2)
    enabled=true;assert(a:NewActionReadiness(100)('item',234,5512) and calls==3)
    enabled=false;assert(not a:NewActionReadiness(100)('item',234,5512))
end)
test('per-pass policy shares observations but retries unavailable and changed state on the next pass',function()
    local f,s=fixture();local a=f.addon;local count=0
    f.env.C_Spell.IsSpellInRange=function() count=count+1;return s.range end
    local read=a:NewActionReadiness(100)
    assert(read('spell',403) and read('spell',403) and count==1)
    s.range=nil;assert(not a:NewActionReadiness(100)('spell',403) and count==2)
    s.range=true;assert(a:NewActionReadiness(100)('spell',403) and count==3)
    f.env.C_SpellBook.IsSpellKnown=function() error('unavailable') end
    assert(not a:NewActionReadiness(100)('spell',403))
    assert(not a:NewActionReadiness(100)('nonsense',403))
end)
test('implicit melee Attack requires readable living hostile player combat confirmed melee range and inactive autoattack',function()
    local f,s=fixture();local p=f.addon.Platform
    assert(p:IsMeleeAttackNeeded('target'))
    for _,field in ipairs({'combat','hostile','exists'}) do s[field]=false;assert(not p:IsMeleeAttackNeeded('target'));s[field]=true end
    for _,field in ipairs({'dead','vehicle','active'}) do s[field]=true;assert(not p:IsMeleeAttackNeeded('target'));s[field]=false end
    s.range=false;assert(not p:IsMeleeAttackNeeded('target'))
    s.range=nil;assert(not p:IsMeleeAttackNeeded('target'))
    s.range=true;f.env.C_Spell.IsCurrentSpell=function() return nil end
    assert(not p:IsMeleeAttackNeeded('target'))
    f.env.C_Spell.IsCurrentSpell=function() return false end
    local opaque={};f.env.canaccessvalue=function(value) return value~=opaque end
    f.env.UnitCanAttack=function() return opaque end;assert(not p:IsMeleeAttackNeeded('target'))
    f.env.WOW_PROJECT_ID=1;assert(not p:IsMeleeAttackNeeded('target'),'restricted client invoked a custom fallback')
end)
test('Attack uses the same confirmed melee observation when its native spell range is unsupported',function()
    local f,s=fixture();local a=f.addon
    s.range=nil
    f.libraries['LibRangeCheck-3.0'].GetRange=function() return 0,5 end
    assert(a.Platform:IsMeleeAttackNeeded('target'))
    assert(a:NewActionReadiness(100)('spell',6603),'a successful public melee estimate was discarded by a second unsupported Attack range test')
    f.libraries['LibRangeCheck-3.0'].GetRange=function() return 0,10 end
    assert(not a:NewActionReadiness(100)('spell',6603),'uncertain melee interval became in range')
end)
finish()
