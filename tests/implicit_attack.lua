-- The implicit auto-attack (Attack or Shoot): Attack in melee range, Auto Shot
-- or wand Shoot beyond it when that button is on the bars and the target is in
-- its range, nothing out of range or when melee range cannot be read.
-- Engine parity for the same decisions: tests/implicit_attack_engines.lua.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local WAND,BOW=5240,2504
local function fixture(project,class)
    local f=F.new(project or 5,1,class or 'PRIEST');local e,a=f.env,f.addon
    local s={known={[6603]=true,[5019]=true},range={[6603]=true,[75]=true,[5019]=true},bar={},bound={[6603]=true,[5019]=true},
        usable=true,combat=true,hostile=true,dead=false,exists=true,vehicle=false,current={},repeating={},gear={[18]=WAND},calls={}}
    local function note(name)s.calls[name]=(s.calls[name] or 0)+1 end
    e.Enum.SpellBookSpellBank={Player=0,Pet=1}
    e.C_SpellBook={IsSpellKnown=function(id,bank)return bank~=1 and s.known[id]==true end}
    e.C_Spell={GetSpellCooldown=function()return {startTime=0,duration=0,isEnabled=true,modRate=1}end,
        IsSpellUsable=function()return s.usable,false end,SpellHasRange=function()return true end,
        IsSpellInRange=function(id)note('range'..id);return s.range[id]end,
        IsCurrentSpell=function(id)return s.current[id]==true end,
        IsAutoRepeatSpell=function(id)note('repeat'..id);return s.repeating[id]==true end}
    e.C_Item={GetItemInfoInstant=function(item)
        note('iteminfo')
        if item==WAND then return item,'Weapon','Wands','INVTYPE_RANGEDRIGHT',1,2,19 end
        if item==BOW then return item,'Weapon','Bows','INVTYPE_RANGED',1,2,2 end
        return item,'Armor','Cloth','INVTYPE_CHEST',1,4,1 end}
    e.GetInventoryItemID=function(unit,slot)assert(unit=='player');note('gear');return s.gear[slot]end
    e.UnitExists=function()return s.exists end;e.UnitAffectingCombat=function()return s.combat end
    e.UnitCanAttack=function()return s.hostile end;e.UnitIsDeadOrGhost=function()return s.dead end
    e.UnitHasVehicleUI=function()return s.vehicle end
    for _,path in ipairs({'Platform/spells.lua','Platform/actions.lua','Platform/range.lua','Core/action_policy.lua'})do f.load(path)end
    -- The bars: FindSpell maps only what is bound; the button's range indicator
    -- is the bar model (buttons.lua reads it for real in the engine suite).
    a.FindSpell=function(_,ids)local id=ids[1];if s.bound[id] then return id,1 end end
    a.GetBoundActionRange=function(_,id)note('bar'..id);if not s.bound[id] then return nil end;return s.bar[id]end
    local function resolve()return a:ResolveImplicitAttack(a:NewActionReadiness(100))end
    return f,s,resolve
end
local function hunter(project)
    local f,s,resolve=fixture(project,'HUNTER')
    s.known={[6603]=true,[75]=true};s.gear={[18]=BOW};s.bound={[6603]=true,[75]=true}
    return f,s,resolve
end

test('in melee range the implicit action is Attack, exactly as before',function()
    local _,s,resolve=fixture()
    assert(resolve()==6603)
    s.current[6603]=true;assert(resolve()==nil,'Attack recommended while it is already on')
    s.current[6603]=nil;s.bound[6603]=nil;assert(resolve()==nil,'Attack recommended off the bars')
    s.bound[6603]=true;s.usable=false;assert(resolve()==nil,'unusable Attack recommended')
end)

test('beyond melee range a wand user is told to Shoot while the target is in wand range',function()
    local _,s,resolve=fixture()
    s.range[6603]=false
    assert(resolve()==5019)
    s.range[5019]=false;assert(resolve()==nil,'Shoot recommended out of wand range')
    s.range[5019]=true;s.gear={};assert(resolve()==nil,'Shoot recommended with no wand')
    s.gear={[16]=WAND};assert(resolve()==5019,'a Mists main-hand wand was not seen')
    s.gear={[18]=BOW};assert(resolve()==nil,'a bow counted as a wand')
end)

test('a hunter on a Classic client gets Auto Shot beyond melee range and Attack inside it',function()
    for _,project in ipairs({2,5,19})do
        local _,s,resolve=hunter(project)
        s.range[6603]=false
        assert(resolve()==75,'no Auto Shot on project '..project)
        s.range[6603]=true;assert(resolve()==6603,'no Attack in melee on project '..project)
    end
end)

test('out of range of everything there is no implicit action',function()
    local _,s,resolve=fixture()
    s.range[6603],s.range[5019]=false,false
    assert(resolve()==nil)
    local _,h,hunterResolve=hunter(2)
    h.range[6603],h.range[75]=false,false
    assert(hunterResolve()==nil)
end)

test('the ranged auto-attack must be on the action bars, otherwise nothing beyond melee',function()
    local _,s,resolve=fixture()
    s.range[6603]=false;s.bound[5019]=nil
    assert(resolve()==nil)
    local _,h,hunterResolve=hunter(5)
    h.range[6603]=false;h.bound[75]=nil
    assert(hunterResolve()==nil)
end)

test('the button range indicator decides first, and an absent one falls back to the spell range',function()
    local _,s,resolve=fixture()
    s.range[6603]=false
    s.bar[5019]=false;assert(resolve()==nil,'button said out of range')
    s.bar[5019]=true;s.range[5019]=false;assert(resolve()==5019,'button said in range')
    s.bar[5019]=nil;assert(resolve()==nil,'no indicator and the spell range says out')
    s.range[5019]=true;assert(resolve()==5019,'no indicator and the spell range says in')
end)

test('a ranged auto-attack already repeating, or one whose state is unknown, is not recommended again',function()
    local f,s,resolve=fixture()
    s.range[6603]=false;s.repeating[5019]=true
    assert(resolve()==nil)
    s.repeating[5019]=nil;f.env.C_Spell.IsAutoRepeatSpell=function()return nil end
    assert(resolve()==nil,'an unknown repeat state counted as idle')
    local _,h,hunterResolve=hunter(2)
    h.range[6603]=false;h.repeating[75]=true
    assert(hunterResolve()==nil)
end)

test('with Attack on, range is read only for a character with a ranged auto-attack on the bars',function()
    local _,s,resolve=fixture()
    s.current[6603]=true;s.range[6603]=false
    assert(resolve()==5019,'Attack on beyond melee range blocked wand Shoot')
    s.range[6603]=true;assert(resolve()==nil,'Shoot recommended in melee range with Attack on')
    s.bound[5019]=nil;s.calls={}
    assert(resolve()==nil and not s.calls.range6603,'melee range read for a character with no ranged auto-attack')
end)

test('melee range that cannot be determined keeps the previous behavior: nothing',function()
    local f,s,resolve=fixture()
    s.range[6603]=nil
    assert(resolve()==nil,'unsupported native range')
    f.libraries['LibRangeCheck-3.0'].GetRange=function()return 0,10 end
    assert(resolve()==nil,'an interval spanning melee range became a decision')
    f.libraries['LibRangeCheck-3.0'].GetRange=function()return 8,30 end
    assert(resolve()==5019,'a confirmed estimate beyond melee range was ignored')
    f.libraries['LibRangeCheck-3.0'].GetRange=function()return 0,5 end
    assert(resolve()==6603,'a confirmed estimate inside melee range was ignored')
end)

test('a client without the range and auto-repeat APIs never guesses',function()
    local f,s,resolve=fixture()
    f.env.C_Spell.IsSpellInRange=nil;f.env.IsSpellInRange=nil
    assert(resolve()==nil,'no melee range provider still recommended')
    local g,t,resolve2=fixture()
    t.range[6603]=false;g.env.C_Spell.IsAutoRepeatSpell=nil;g.env.IsAutoRepeatSpell=nil
    assert(resolve2()==nil,'no auto-repeat API still recommended Shoot')
    local h,u,resolve3=fixture()
    u.range[6603]=false;h.env.GetInventoryItemID=nil
    assert(resolve3()==nil,'no equipment API still recommended Shoot')
end)

test('secret range results keep the previous behavior',function()
    local f,s,resolve=fixture()
    local opaque={};f.env.canaccessvalue=function(value)return value~=opaque end
    s.range[6603]=opaque
    assert(resolve()==nil,'a secret melee range became a decision')
    s.range[6603]=false;s.range[5019]=opaque;s.bar[5019]=opaque
    assert(resolve()==nil,'a secret ranged result became a decision')
    s.bar[5019]=true;assert(resolve()==5019,'a readable button indicator was not used')
end)

test('restricted clients keep no implicit action at all',function()
    for _,project in ipairs({1,18})do
        local _,s,resolve=fixture(project)
        assert(resolve()==nil,'melee on project '..project)
        s.range[6603]=false;assert(resolve()==nil,'ranged on project '..project)
    end
end)

test('the poll memo reads each ranged observation once and only when the implicit action is considered',function()
    local f,s=fixture()
    s.range[6603]=false;s.calls={}
    local ready=f.addon:NewActionReadiness(100)
    assert(f.addon:ResolveImplicitAttack(ready)==5019 and f.addon:ResolveImplicitAttack(ready)==5019)
    assert(s.calls.bar5019==1,'button range read '..tostring(s.calls.bar5019)..' times')
    assert(s.calls.iteminfo==1,'wand classification repeated')
    assert(not ready('nonsense',5019),'unknown kinds stay unready')
    assert(not ready('ranged',974),'a pet or unknown spell became a ranged auto-attack')
end)

test('IsMeleeAttackNeeded names why it declined an attackable target in combat',function()
    local f,s=fixture();local p=f.addon.Platform
    assert(p:IsMeleeAttackNeeded('target')==true)
    s.current[6603]=true
    local value,reason,why=p:IsMeleeAttackNeeded('target');assert(value==false and reason==nil and why=='attack-active')
    s.current[6603]=nil;s.range[6603]=false
    value,reason,why=p:IsMeleeAttackNeeded('target');assert(value==false and reason==nil and why=='beyond-melee')
    s.combat=false
    value,reason,why=p:IsMeleeAttackNeeded('target');assert(value==false and why==nil,'out of combat looked like a range decision')
end)

test('IsWandEquipped reads the ranged slot and the Mists main hand, and never guesses',function()
    local f,s=fixture();local p=f.addon.Platform
    assert(p:IsWandEquipped()==true)
    s.gear={[16]=WAND};assert(p:IsWandEquipped()==true)
    s.gear={[18]=BOW,[16]=4000};assert(p:IsWandEquipped()==false)
    s.gear={};assert(p:IsWandEquipped()==false)
    f.env.C_Item.GetItemInfoInstant=function()return nil end
    s.gear={[18]=6000};local value,why=p:IsWandEquipped();assert(value==nil and why=='item-data-unavailable')
    local opaque={};f.env.canaccessvalue=function(v)return v~=opaque end
    s.gear={[18]=opaque};value,why=p:IsWandEquipped();assert(value==nil and why=='restricted-value')
    f.env.GetInventoryItemID=function()error('unavailable')end
    value,why=p:IsWandEquipped();assert(value==nil and why=='api-error')
    f.env.GetInventoryItemID=nil
    value,why=p:IsWandEquipped();assert(value==nil and why=='missing-api')
end)

finish()
