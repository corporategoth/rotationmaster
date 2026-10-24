-- Retail (Midnight) Assassination Rogue, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because bleed timers and buffs are hidden in Midnight
-- combat. Bleeds first in their last 30%: Garrote while not at full combo points, Rupture at 5+.
-- At 5+ combo points spend (Coup de Grace, Envenom); below, build: Crimson Tempest on three or
-- more enemies, Fan of Knives on two or more close by, Ambush (Blindside), Mutilate. From stealth
-- Garrote, then Ambush. Reminders: Deathmark with both bleeds up, Kingsbane alongside it, Vanish
-- with Deathmark ready, Shiv on a Deathstalker's Mark target, Thistle Tea whenever it is ready in
-- combat (energy is secret on Retail).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function refresh(id,v)return any(negate(dot(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v})end
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local bled=all(dot(703),dot(1943))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.assassination.icyveins',revision=4,
 blocks={['retail.rogue.boundaries']=2,['retail.rogue.upkeep']=2},
 nameKey='Default.Retail.Rogue.Assassination.IcyVeins.Name',descriptionKey='Default.Retail.Rogue.Assassination.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'assassination','melee','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Assassination Rogue rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/rogue_assassination.simc',title='SimulationCraft: Assassination Rogue default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=259},
  cooldowns={
   block('retail.rogue.upkeep','assaiv-'),
   spell('assaiv-deathmark',360194,all(fight,bled)),
   spell('assaiv-kingsbane',385627,all(fight,bled,any(dot(360194),negate({type='SPELL_AVAIL',spell=360194})))),
   spell('assaiv-vanish',1856,all(fight,negate({type='STEALTHED'}),{type='SPELL_AVAIL',spell=360194})),
   spell('assaiv-shiv',5938,all(fight,dot(457129))),
   spell('assaiv-thistle-tea',381623,fight),
  },
  rotation={
   block('retail.rogue.boundaries','assaiv-'),
   {id='assaiv-stealthed',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
    spell('assaiv-stealthed-garrote',703),
    spell('assaiv-stealthed-ambush',8676),
    {id='assaiv-stealthed-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   spell('assaiv-garrote',703,all(refresh(703,5.4),points('GREATERTHANOREQUALS',-1))),
   spell('assaiv-rupture',1943,all(points('GREATERTHANOREQUALS',5),refresh(1943,6))),
   {id='assaiv-spend',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={
    spell('assaiv-crimson-tempest',1247227,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},negate(dot(1247227)))),
    spell('assaiv-fan-of-knives',51723,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=2}),
    spell('assaiv-ambush',8676),
    spell('assaiv-mutilate',1329),
   },onTrue={
    spell('assaiv-coup-de-grace',441776),
    spell('assaiv-envenom',32645),
   }},
  },
 },
}))
