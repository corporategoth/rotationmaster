-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery melee (Survival) Hunter, dual-wield or two-hander, levels 1–60 (Phase 8
-- runes). Chosen once a melee rune is engraved (Flanking Strike, Wyvern Strike or Carve) and no
-- ranged hands rune (Chimera or Explosive Shot) is. Keeps the Flanking Strike buff up, Mongoose Bite
-- at four Raptor Fury stacks, Raptor Strike on every reset, Wyvern Strike on Clever Strikes,
-- Immolation Trap and Wing Clip only in empty gaps; Carve and Explosive Trap on packs; shots while
-- out of melee (Wowhead P8 melee guide, simulator P8 melee builds). Falcon (Hawk before 60), Viper
-- below 5% mana; no pet reminders with Lone Wolf engraved. Left manual: positioning, pet commands,
-- Feed Pet and Tranquilizing Shot.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function stacks(id,op,n)return{type='BUFF_STACKS',unit='player',spell=id,operator=op,value=n}end
local function recharge(id,op,n)return{type='SPELL_COOLDOWN',spell=id,ranked=false,operator=op,value=n}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,attack)return{id=id,type='stop',suppress_attack=not attack,conditions={}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local standing=negate({type='MOVING'})
local unmarked=negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
local flankingLeft={type='BUFF_REMAIN',unit='player',spell=415320,operator='GREATERTHAN',value=1.5}
local worth=all(combat(),any(classified('worldboss'),classified('elite'),classified('rareelite'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))
local noAspect=all(negate(buff(415423)),negate(buff(13163)),negate(buff(5118)),negate(buff(13159)),negate(buff(13161)),negate(buff(20043)))
local viperLow=all(mana('LESSTHAN',.5),any(buff(415423),all(known(415423),mana('LESSTHAN',.05))))
local rapid=buff(3045)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.hunter.melee',revision=6,
 blocks={['era.hunter.boundaries']=3,['sod.hunter.upkeep']=1},
 nameKey='Default.SoD.Hunter.Melee.Name',descriptionKey='Default.SoD.Hunter.Melee.Description',
 applicability={families={'era'},actionContext='player',class='HUNTER',rulesets={'season:2'}},
 tags={'dps','melee','survival','leveling','endgame','season-of-discovery','wowhead'},
 sources={
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/hunter/melee-dps-rotation-cooldowns-abilities-pve',title='Wowhead: Melee Hunter rotation, Season of Discovery',reviewedAt='2026-10-23',revision='2025-08-20'},


 },
 body={priority=110,switch=all(any(rune(415320),rune(458479),rune(425711)),negate(rune(409433)),negate(rune(409552))),
 cooldowns={block('sod.hunter.upkeep','hunter-'),
  spell('hunter-falcon',469145,all(negate(buff(469145)),negate(viperLow),any(combat(),noAspect))),
  spell('hunter-hawk',13165,all(negate(known(469145)),negate(buff(13165)),negate(viperLow),any(combat(),noAspect))),
  spell('hunter-viper',415423,all(combat(),mana('LESSTHAN',.05),negate(buff(415423)))),
  spell('hunter-rapid-fire',3045,all(worth,negate(rapid),any(stacks(415320,'GREATERTHANOREQUALS',2),{type='TIME_IN_COMBAT',operator='GREATERTHANOREQUALS',value=10}))),
  spell('hunter-berserking',20554,all(worth,rapid)),
  spell('hunter-blood-fury',20572,all(worth,rapid)),
  spell('hunter-bestial-wrath',19574,all(worth,{type='PET'}))},
 rotation={
  block('era.hunter.boundaries','hunter-'),
  {id='hunter-pull',type='branch',conditions=combat(),onTrue={},onFalse={
   spell('hunter-pull-mark',1130,unmarked),
   spell('hunter-pull-serpent-sting',1978,all(stingless,{type='BEYOND_MELEE',unit='target'})),
   stop('hunter-pull-stop',true),
  }},
  {id='hunter-ranged',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onFalse={},onTrue={
   spell('hunter-ranged-serpent-sting',1978,stingless),
   spell('hunter-ranged-multi-shot',2643),
   spell('hunter-ranged-arcane-shot',3044),
   {id='hunter-ranged-auto-shot',type='spell',action=75,ranked=true,conditions=all(negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
   stop('hunter-ranged-stop'),
  }},
  {id='hunter-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
   spell('hunter-aoe-carve',425711),
   spell('hunter-aoe-explosive-trap',13813),
  }},
  spell('hunter-flanking-refresh',415320,all(stacks(415320,'GREATERTHANOREQUALS',1),{type='BUFF_REMAIN',unit='player',spell=415320,operator='LESSTHANOREQUALS',value=2})),
  spell('hunter-flanking-stack',415320,all(negate(stacks(415320,'GREATERTHANOREQUALS',3)),negate(buff(415358)))),
  spell('hunter-clever-wyvern-strike',458436,buff(467331)),
  spell('hunter-fury-mongoose-bite',1495,stacks(415358,'GREATERTHANOREQUALS',4)),
  spell('hunter-raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
  spell('hunter-mongoose-bite',1495),
  spell('hunter-wyvern-strike',458436),
  spell('hunter-flanking-strike',415320),
  spell('hunter-carve',425711),
  spell('hunter-immolation-trap',13795,all(recharge(2973,'GREATERTHAN',1.5),recharge(1495,'GREATERTHAN',1.5),flankingLeft)),
  spell('hunter-wing-clip',2974,all(recharge(2973,'GREATERTHAN',1.5),recharge(1495,'GREATERTHAN',1.5),flankingLeft)),
  stop('hunter-wait',true),
 }},
}))
