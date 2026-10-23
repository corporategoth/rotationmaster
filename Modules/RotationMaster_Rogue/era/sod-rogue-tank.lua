-- Season of Discovery Rogue tank, levels 1–60, chosen when the Just a Flesh Wound rune (which teaches
-- Tease) is engraved.
-- wowsims/sod Phase 6 Main Gauche order with Icy Veins, Zockify and Warcraft Tavern: Riposte, Main
-- Gauche on cooldown, Blade Dance from one point and refreshed from three, Slice and Dice from
-- three (refreshed from four), Fan of Knives, Crimson Tempest and Blunderbuss on three engaged
-- enemies, Blunderbuss while Blade Dance is up, Eviscerate at five with both buffs up, Poisoned
-- Knife at low energy, builder Saber Slash, Mutilate or Sinister Strike. Reminders: Tease when
-- the target is not on you, Kick, Evasion, Blade Flurry, Adrenaline Rush, Thistle Tea, poisons.
-- Shared parts: era/blocks.lua. Left manual: Shadowstep, Sebacious Poison duty and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function remain(id,n)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHAN',value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local instant={8928,8927,8926,6950,6949,6947}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.rogue.tank',revision=2,
 blocks={['era.rogue.boundaries']=1},
 nameKey='Default.SoD.Rogue.Tank.Name',descriptionKey='Default.SoD.Rogue.Tank.Description',
 applicability={families={'era'},actionContext='player',class='ROGUE',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'tank','melee','endgame','aoe','season-of-discovery','wowsims','icy-veins','zockify','warcraft-tavern'},
 sources={{url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/tank_rogue/apls',title='wowsims/sod: Rogue tank Phase 6 APLs (Main Gauche, Saber Slash)',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'},
 {url='https://www.icy-veins.com/wow-classic/combat-rogue-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Combat Rogue tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.zockify.com/wowclassic/rogue/tank/',title='Zockify: SoD Rogue tank (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-10'},
 {url='https://www.warcrafttavern.com/wow-classic-sod/guides/combat-rogue-tank/',title='Warcraft Tavern: SoD Combat Rogue tank (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=60,switch={type='RUNE_ENGRAVED',spell=400014},
 cooldowns={
  item('rogue-tank-mainhand-poison',instant,negate({type='WEAPON'})),
  item('rogue-tank-offhand-poison',instant,all({type='SWING_TIME',offhand=true,operator='GREATERTHAN',value=0},negate({type='WEAPON',offhand=true}))),
  spell('rogue-tank-tease',410412,all(combat(),{type='GROUP'},negate(tanked))),
  spell('rogue-tank-tease-alt',1219355,all(combat(),{type='GROUP'},negate(tanked))),
  spell('rogue-tank-kick',1766,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
  spell('rogue-tank-evasion',5277,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
  spell('rogue-tank-blade-flurry',13877,all(combat(),own(5171))),
  spell('rogue-tank-adrenaline-rush',13750,combat()),
  item('rogue-tank-thistle-tea',{7676},all(combat(),energy('LESSTHANOREQUALS',10))),
 },
 rotation={
 block('era.rogue.boundaries','rogue-tank-'),
 spell('rogue-tank-riposte',14251),
 spell('rogue-tank-main-gauche',424919),
 spell('rogue-tank-blade-dance',400012,all(points('GREATERTHANOREQUALS',1),negate(own(400012)))),
 spell('rogue-tank-blade-dance-refresh',400012,all(points('GREATERTHANOREQUALS',3),remain(400012,2))),
 spell('rogue-tank-slice',5171,all(points('GREATERTHANOREQUALS',3),negate(own(5171)))),
 spell('rogue-tank-slice-refresh',5171,all(points('GREATERTHANOREQUALS',4),remain(5171,1))),
 {id='rogue-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('rogue-tank-aoe-fan-of-knives',409240),
  spell('rogue-tank-aoe-crimson-tempest',412096,all(points('GREATERTHANOREQUALS',4),negate({type='DEBUFF',unit='target',spell=436611,owndebuff=true}))),
  spell('rogue-tank-aoe-blunderbuss',436564),
 }},
 spell('rogue-tank-blunderbuss',436564,all(own(400012),energy('LESSTHAN',70),points('LESSTHAN',4))),
 spell('rogue-tank-kill-shot',2098,all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',3))),
 {id='rogue-tank-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-tank-eviscerate',2098,all(own(400012),own(5171))),
  {id='rogue-tank-pool',type='none',suppress_attack=false,conditions={}},
 }},
 spell('rogue-tank-poisoned-knife',425012,energy('LESSTHANOREQUALS',30)),
 spell('rogue-tank-saber-slash',424785),
 spell('rogue-tank-mutilate',399956),
 spell('rogue-tank-sinister',1752),
 }},
}))
