-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Combat Rogue, levels 10-90 (the recommended variant): Wowhead's Phase 5 page and simulator
-- after the Siege of Orgrimmar patch (Sinister Strike now costs 50 energy), so Revealing Strike is the builder and
-- Sinister Strike is used only under a Bloodlust effect with Adrenaline Rush. Selected in the Combat specialization (260).
-- Stealth opens with Cheap Shot solo, else Ambush. Eight or more engaged enemies: Slice and Dice, Crimson Tempest,
-- Fan of Knives. One target: Slice and Dice from two points; five-point finishers only with Revealing Strike up
-- (Slice and Dice, Rupture on a long single fight without Blade Flurry, Eviscerate), pooling at five; Marked for
-- Death; Revealing Strike when its debuff is ending; Sinister Strike before 20. Reminders: Blade Flurry on and off by
-- engaged enemies, Adrenaline Rush under 35 energy with Shadow Blades, Killing Spree, Vanish and Preparation for
-- Ambush in Deep Insight. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local lust=any(buff(2825),buff(32182),buff(80353),buff(90355))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.combat',revision=8,
 blocks={['mop.rogue.boundaries']=3,['mop.rogue.combat-opener']=2,['mop.rogue.out-of-combat']=3,['mop.rogue.combat-aoe']=2,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.combat-upkeep']=1},
 nameKey="Recommended",descriptionKey="Recommended for Combat, from level 10 to 90 (Wowhead and simulator for Phase 5). Since the Siege of Orgrimmar patch Sinister Strike costs 50 energy, so Revealing Strike is the builder and Sinister Strike is used only under Bloodlust or Heroism with Adrenaline Rush (and before level 20). Opens with Cheap Shot solo, otherwise Ambush. Keeps Slice and Dice up from two points and Revealing Strike on the target, spends five points only while Revealing Strike is up (Slice and Dice, Rupture on a long single-target fight without Blade Flurry, Eviscerate) and waits for energy at five. Against eight or more enemies: Slice and Dice, Crimson Tempest and Fan of Knives. Solo it adds Recuperate and Kidney Shot. Reminders: poisons, Kick, Blade Flurry on against two or more enemies and off again, Adrenaline Rush at low energy with Shadow Blades, Killing Spree, Vanish and Preparation for Ambush in Deep Insight, Shadowstep, Evasion solo. Left to you: Tricks of the Trade and Expose Armor (listed but off), Feint and positioning behind the target for Ambush.",
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE'},
 tags={'combat','dps','melee','leveling','endgame','wowhead'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/rogue/combat/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Combat Rogue rotation (MoP Classic, Phase 5)',reviewedAt='2026-10-23',revision='2026-06-29'},

 {url='https://www.wowhead.com/mop-classic/guide/classes/rogue/combat/dps-leveling-talent-builds-tips',title='Wowhead: Combat Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/combat-rogue-leveling',title='Icy Veins: Combat Rogue leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-09-23'}},
 body={priority=30,specs={260},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.rogue.upkeep','rogue-'),block('mop.rogue.combat-upkeep','rogue-')},
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 block('mop.rogue.combat-opener','rogue-'),
 block('mop.rogue.out-of-combat','rogue-'),
 block('mop.rogue.combat-aoe','rogue-'),
 spell('rogue-combat-slice',5171,all(points('GREATERTHANOREQUALS',2),negate(own(5171)))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-combat-finisher',type='branch',conditions=all(points('GREATERTHANOREQUALS',5),any(negate(known(84617)),mine(84617))),onFalse={},onTrue={
  spell('rogue-combat-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  spell('rogue-combat-rupture',1943,all(any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2)),negate(own(13877)),any(boss,lifetime('GREATERTHAN',26)))),
  spell('rogue-combat-eviscerate',2098),
  {id='rogue-combat-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-combat-dying',2098,all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',4))),
 spell('rogue-combat-marked-for-death',137619,points('LESSTHANOREQUALS',0)),
 spell('rogue-combat-revealing-refresh',84617,any(negate(mine(84617)),remain(84617,'LESSTHANOREQUALS',3))),
 spell('rogue-combat-lust-sinister',1752,all(own(13750),lust)),
 spell('rogue-combat-revealing-strike',84617),
 spell('rogue-combat-sinister',1752),
 spell('rogue-combat-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
