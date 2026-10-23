-- Shared Classic Era and Season of Discovery Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.mage.frost, rm.era.mage.frost.icyveins, rm.era.mage.fire,
-- rm.era.mage.fire.warcrafttavern, rm.sod.mage.fire, rm.sod.mage.frost, rm.sod.mage.frost.warcrafttavern,
-- rm.sod.mage.arcane and rm.sod.mage.healer. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
-- Season of Discovery runes: engraved, by the spell the rune teaches (passive runes too).
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id,anyrank)return{type='BUFF',unit='player',spell=id,anyrank=anyrank}end
local function missing(id)return negate(buff(id,true))end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function pct(kind,unit,op,v)return{type=kind,unit=unit,operator=op,value=v}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function lives(seconds)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=seconds}end
local function class(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function cooling(id,v)return{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='MAGE',steps=steps}))end
local group={type='GROUP'}
local solo=negate(group)
local elite=any(class('elite'),class('rareelite'),class('worldboss'))
local onMe={type='THREAT',unit='target',threat=3}

-- Vanilla and Season of Discovery.
-- Casts, channels (Blizzard, Arcane Missiles, Evocation) and a target that is not ours to pull end advice.
block('era.mage.boundaries',{
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('target',negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}))))),
})
-- Frostbolt once learned (level 4); Fireball before that.
block('era.mage.frostbolt',{
 {id='frostbolt-known',type='branch',conditions=known(116),onTrue={spell('frostbolt',116)},onFalse={spell('fireball',133)}},
})
-- Fire Blast to reposition, only with a healthy mana pool; nothing else casts on the move.
block('era.mage.moving',{
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-fire-blast',2136,pct('MANAPCT','player','GREATERTHAN',.4)),stop('moving-stop')}},
})
-- A mob is hitting you: Frost Nova it off (raid bosses are root-immune); Blink stays with you.
block('era.mage.nova',{
 spell('frost-nova',122,all(near(1),onMe,negate(class('worldboss')))),
})
-- Finish an ordinary mob: Fire Blast at 10%, the wand at 15% when solo.
block('era.mage.execute',{
 spell('execute-fire-blast',2136,all(class('normal'),pct('HEALTHPCT','target','LESSTHAN',.1))),
 {id='execute-wand',type='branch',conditions=all(solo,class('normal'),pct('HEALTHPCT','target','LESSTHAN',.15),known(5019)),onFalse={},onTrue={
  stop('execute-wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell('execute-shoot',5019)}},
})
-- Out of mana or spells: wand, never toggling an active wand off; casters never melee.
block('era.mage.wand-finish',{
 {id='wand-known',type='branch',conditions=known(5019),onFalse={},onTrue={
  stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  spell('shoot',5019)}},
 stop('exhausted'),
})
-- Armor: any armor already up is the player's choice. With none up: Mage Armor in a group, Ice
-- Armor solo (or when Mage Armor is not learned), Frost Armor before Ice Armor is learned.
local function bare(...)return all(missing(168),missing(7302),missing(6117),missing(428741),...)end
local mageArmor=all(group,known(6117))
block('era.mage.armor',{
 spell('mage-armor',6117,bare(mageArmor)),
 spell('ice-armor',7302,bare(negate(mageArmor),known(7302))),
 spell('frost-armor',168,bare(negate(mageArmor),negate(known(7302)),known(168))),
})
-- Mana gems: conjure the best learned gem between pulls when it is not in your bags; use one in combat.
local function gem(id,spell,item,better)
 local c={negate(combat()),known(spell),{type='CARRYING',item={item},operator='LESSTHAN',value=1}}
 if better then c[#c+1]=negate(known(better))end
 return{id=id,type='spell',action=spell,ranked=false,conditions=all(unpack(c))}
end
-- Independent reminders shared by every Mage premade. Talent and rune spells light only once learned.
local function upkeep()return{
 spell('intellect',1459,all(negate(combat()),missing(1459),missing(23028))),
 gem('conjure-ruby',10054,8008),gem('conjure-citrine',10053,8007,10054),gem('conjure-jade',3552,5513,10053),gem('conjure-agate',759,5514,3552),
 {id='mana-gem',type='item',action={8008,8007,5513,5514},conditions=all(combat(),pct('MANAPCT','player','LESSTHAN',.7))},
 spell('ice-barrier',11426,missing(11426)),
 spell('mana-shield',1463,all(combat(),onMe,missing(11426),missing(1463),pct('MANAPCT','player','GREATERTHAN',.4))),
 spell('counterspell',2139,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('ice-block',11958,all(combat(),pct('HEALTHPCT','player','LESSTHAN',.2))),
}end
local function decurse(id,action)return spell(id,action,any({type='DISPELLABLE',unit='player',debufftype='Curse'},
 all({type='FRIENDLY',unit='target'},{type='DISPELLABLE',unit='target',debufftype='Curse'})))end
local vanilla=upkeep()
for _,step in ipairs({
 decurse('remove-curse',475),
 spell('evocation',12051,all(combat(),pct('MANAPCT','player','LESSTHAN',.2))),
 -- Cold Snap for a second Frost Nova when the first is spent and you are in trouble.
 spell('cold-snap',12472,all(combat(),cooling(122,5),near(1),any(pct('HEALTHPCT','player','LESSTHAN',.5),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}))),
 spell('arcane-power',12042,all(combat(),any({type='DEBUFF_STACKS',unit='target',spell=12579,operator='GREATERTHANOREQUALS',value=5},solo),any(elite,lives(15)))),
 spell('presence-of-mind',12043,all(combat(),any(buff(12042),negate(known(12042))))),
})do vanilla[#vanilla+1]=step end
block('era.mage.upkeep',vanilla)

-- Season of Discovery only.
-- Molten Armor (wrist rune) is the choice when engraved; otherwise as in vanilla.
block('sod.mage.armor',{
 spell('molten-armor',428741,bare(rune(428741))),
 spell('mage-armor',6117,bare(negate(rune(428741)),mageArmor)),
 spell('ice-armor',7302,bare(negate(rune(428741)),negate(mageArmor),known(7302))),
 spell('frost-armor',168,bare(negate(rune(428741)),negate(mageArmor),negate(known(7302)),known(168))),
},2)
local sod=upkeep()
for _,step in ipairs({
 spell('remove-greater-curse',412113,{type='DISPELLABLE',unit='player',debufftype='Curse'}),
 decurse('remove-curse',475),
 spell('evocation',12051,all(combat(),pct('MANAPCT','player','LESSTHAN',.15))),
 spell('icy-veins',425121,all(combat(),negate(buff(425121)),any(elite,lives(20)))),
 -- Cold Snap refreshes Icy Veins once it, Deep Freeze and Frozen Orb are all spent.
 spell('cold-snap',12472,all(combat(),rune(425121),cooling(425121,20),negate(buff(425121)),
  any(negate(rune(428739)),cooling(428739,2)),any(negate(rune(440802)),cooling(440802,2)))),
})do sod[#sod+1]=step end
block('sod.mage.upkeep',sod,2)
-- Balefire Bolt stacks a Spirit-draining aura on you; the fifth stack kills you. Every Balefire step
-- is gated here: never at four or more stacks (the aura is read as a buff and as a debuff), and never
-- within 2.5 s of the last cast, whose stack may not have landed yet. Older guides' 8-10 stacks are lethal.
local balefire=all(negate({type='BUFF_STACKS',unit='player',spell=428878,operator='GREATERTHANOREQUALS',value=4}),
 negate({type='DEBUFF_STACKS',unit='player',spell=428878,operator='GREATERTHANOREQUALS',value=4}),
 negate({type='SPELL_HISTORY_TIME',spell=428878,operator='LESSTHAN',value=2.5}))
local fireVulnerability={type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}
local scorchTalent={type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1}
block('sod.mage.balefire',{spell('balefire',428878,balefire)})
-- Fire: Balefire once Improved Scorch has five stacks (or without the talent).
block('sod.mage.balefire-scorched',{spell('balefire',428878,all(balefire,any(fireVulnerability,negate(scorchTalent))))})
-- Frost (Brain Freeze builds): Balefire on a "Fireball!" proc.
block('sod.mage.balefire-brain-freeze',{spell('balefire-brain-freeze',428878,all(balefire,buff(400730)))})
-- Living Bomb on a target without yours that will live to see it explode.
block('sod.mage.living-bomb',{spell('living-bomb',400613,all(negate(own(400613)),lives(12)))})
-- Overheat (passive rune 400615) makes Fire Blast off the global cooldown and castable during another
-- cast. A reminder, because the cast Stop hides it.
block('sod.mage.overheat',{
 spell('overheat-fire-blast',2136,all(combat(),rune(400615))),
},2)
