-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Guardian Druid, levels 10–90, in the Guardian specialization (104). simulator'
-- default list as Wowhead writes it, with the guides' Tooth and Claw Maul: Savage Defense whenever
-- it is down (Enrage to fund it), Frenzied Regeneration when low or rage-capped, Thrash for Weakened
-- Blows and Faerie Fire for Weakened Armor, Mangle on cooldown, Thrash and Swipe at three enemies,
-- Lacerate, Thrash and Faerie Fire as fillers. A short Cat arm serves Heart of the Wild damage.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function rage(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local function swing(id,conditions)return{id=id,type='stop',conditions=conditions or{}}end
local BEAR,DEFENSE=5487,132402
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local elite=BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local cleave=BuiltinConditions.any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.guardian',revision=7,
 blocks={['mop.druid.melee-boundaries']=2,['mop.druid.mark']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'guardian','tank','leveling','single-target','aoe','wowhead'},
 sources={

  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/guardian/tank-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Guardian Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/guardian-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Guardian Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22',notes='Maul on Tooth and Claw procs; Swipe at three enemies.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-guardian-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Guardian Druid',reviewedAt='2026-10-23',notes='Faerie Fire as a filler for Mangle resets.'},
 },
 body={priority=30,specs={104},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.block('guardian-mark','mop.druid.mark','guardian-'),
   BuiltinConditions.spell('guardian-savage-defense',62606,BuiltinConditions.all(BuiltinConditions.combat(),{type='FORM',form=BEAR},BuiltinConditions.negate(BuiltinConditions.ownBuff(DEFENSE)))),
   BuiltinConditions.spell('guardian-enrage',5229,BuiltinConditions.all(BuiltinConditions.combat(),{type='FORM',form=BEAR},BuiltinConditions.negate(BuiltinConditions.ownBuff(DEFENSE)),rage('LESSTHAN',60))),
   BuiltinConditions.spell('guardian-frenzied',22842,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.all(health('LESSTHAN',.4),{type='SPELL_CHARGES',spell=62606,operator='EQUALS',value=0}),
    BuiltinConditions.all(health('LESSTHAN',.7),rage('GREATERTHANOREQUALS',90))))),
   BuiltinConditions.spell('guardian-maul',6807,BuiltinConditions.all({type='FORM',form=BEAR},BuiltinConditions.any(rage('GREATERTHANOREQUALS',90),BuiltinConditions.all(BuiltinConditions.ownBuff(135286),BuiltinConditions.ownBuff(DEFENSE),rage('GREATERTHANOREQUALS',30))))),
   BuiltinConditions.spell('guardian-barkskin',22812,BuiltinConditions.all(BuiltinConditions.combat(),tanked)),
   BuiltinConditions.spell('guardian-survival-instincts',61336,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.35))),
   off('guardian-might-of-ursoc',106922,BuiltinConditions.all(BuiltinConditions.combat(),health('LESSTHAN',.3))),
   BuiltinConditions.spell('guardian-berserk',106952,BuiltinConditions.all(BuiltinConditions.combat(),cleave,BuiltinConditions.negate(BuiltinConditions.ownBuff(102558)))),
   BuiltinConditions.spell('guardian-incarnation',102558,BuiltinConditions.all(BuiltinConditions.combat(),cleave,BuiltinConditions.negate(BuiltinConditions.ownBuff(50334)))),
   BuiltinConditions.spell('guardian-force-of-nature',102706,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='SPELL_CHARGES',spell=102706,operator='EQUALS',value=3},BuiltinConditions.ownBuff(50334)))),
   BuiltinConditions.spell('guardian-natures-vigil',124974,BuiltinConditions.all(BuiltinConditions.combat(),elite)),
   BuiltinConditions.spell('guardian-cenarion-ward',102351,health('LESSTHAN',.9)),
   BuiltinConditions.spell('guardian-rejuvenation',774,BuiltinConditions.all(BuiltinConditions.ownBuff(108293),BuiltinConditions.negate({type='BUFF',unit='player',spell=774,ownbuff=true}))),
   BuiltinConditions.spell('guardian-skull-bash',106839,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   off('guardian-growl',6795,BuiltinConditions.all({type='GROUP'},BuiltinConditions.combat(),BuiltinConditions.negate(tanked))),
  },
  rotation={
   BuiltinConditions.block('guardian-boundaries','mop.druid.melee-boundaries','guardian-'),
   {id='guardian-cat',type='branch',conditions={type='FORM',form=768},onFalse={},onTrue={
    BuiltinConditions.spell('guardian-cat-rake',1822,BuiltinConditions.negate(bleed(1822))),
    BuiltinConditions.spell('guardian-cat-rip',1079,BuiltinConditions.all(cp('GREATERTHANOREQUALS',5),BuiltinConditions.any(BuiltinConditions.negate(bleed(1079)),{type='DEBUFF_REMAIN',unit='target',spell=1079,owndebuff=true,operator='LESSTHAN',value=4}))),
    BuiltinConditions.spell('guardian-cat-bite',22568,cp('GREATERTHANOREQUALS',5)),
    BuiltinConditions.spell('guardian-cat-mangle',33917),
    swing('guardian-cat-stop')}},
   {id='guardian-shift',type='branch',conditions={type='FORM',form=BEAR},onTrue={},onFalse={
    BuiltinConditions.spell('guardian-bear-form',BEAR),BuiltinConditions.stop('guardian-shift-stop')}},
   {id='guardian-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    BuiltinConditions.spell('guardian-pull-faerie-fire',770,{type='BEYOND_MELEE',unit='target'}),
    BuiltinConditions.spell('guardian-pull-mangle',33917),
    swing('guardian-pull-stop')}},
   BuiltinConditions.spell('guardian-weakened-blows',106832,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=115798})),
   BuiltinConditions.spell('guardian-weakened-armor',770,BuiltinConditions.all(elite,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=113746}))),
   BuiltinConditions.spell('guardian-dream',5185,BuiltinConditions.all(BuiltinConditions.ownBuff(145162),health('LESSTHAN',.7))),
   BuiltinConditions.spell('guardian-mangle',33917),
   {id='guardian-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell('guardian-aoe-thrash',106832),BuiltinConditions.spell('guardian-aoe-swipe',106785),swing('guardian-aoe-stop')}},
   BuiltinConditions.spell('guardian-thrash-bleed',106832,BuiltinConditions.negate(bleed(77758))),
   BuiltinConditions.spell('guardian-lacerate',33745),
   BuiltinConditions.spell('guardian-thrash',106832),
   BuiltinConditions.spell('guardian-faerie-fire',770),
  },
 },
}))
