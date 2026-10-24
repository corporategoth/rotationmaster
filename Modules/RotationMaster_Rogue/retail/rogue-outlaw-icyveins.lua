-- Retail (Midnight) Outlaw Rogue, Icy Veins, SimulationCraft and Wowhead: the optimal reference,
-- disabled by default because Roll the Bones buffs, Opportunity stacks and energy are hidden in
-- Midnight combat. From stealth Ambush. One combo point short of full: Between the Eyes, Killing
-- Spree, Coup de Grace, Dispatch. Otherwise build: Ambush with Audacity, Pistol Shot at six
-- Opportunity stacks (three when low on combo points), Ambush (Hidden Opportunity), Sinister
-- Strike. Reminders: Roll the Bones with no roll up, Adrenaline Rush at two or fewer combo points,
-- Blade Flurry kept up on two or more enemies, Blade Rush, Preparation when Adrenaline Rush,
-- Between the Eyes and Blade Rush are all cooling. Keep It Rolling stays manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function opportunity(n)return{type='BUFF_STACKS',unit='player',spell=195627,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function cooling(id)return negate({type='SPELL_AVAIL',spell=id})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local rolled=any(own(193356),own(199600),own(193358),own(193357),own(199603),own(193359))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.outlaw.icyveins',revision=4,
 blocks={['retail.rogue.boundaries']=2,['retail.rogue.upkeep']=2},
 nameKey='Default.Retail.Rogue.Outlaw.IcyVeins.Name',descriptionKey='Default.Retail.Rogue.Outlaw.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='ROGUE'},
 tags={'outlaw','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/outlaw-rogue-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Outlaw Rogue rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/rogue_outlaw.simc',title='SimulationCraft: Outlaw Rogue default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.wowhead.com/guide/classes/rogue/outlaw/rotation-cooldowns-pve-dps',title='Wowhead: Outlaw Rogue rotation (Season 1)',reviewedAt='2026-10-23',revision='2026-04-23'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=260},
  cooldowns={
   block('retail.rogue.upkeep','outlawiv-'),
   spell('outlawiv-roll-the-bones',1214909,all(fight,negate(rolled))),
   spell('outlawiv-adrenaline-rush',13750,all(fight,points('LESSTHANOREQUALS',2))),
   spell('outlawiv-blade-flurry',13877,all(fight,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},
    any(negate(own(13877)),{type='BUFF_REMAIN',unit='player',spell=13877,ownbuff=true,operator='LESSTHAN',value=2}))),
   spell('outlawiv-blade-rush',271877,fight),
   spell('outlawiv-preparation',1277933,all(fight,cooling(13750),cooling(315341),cooling(271877))),
  },
  rotation={
   block('retail.rogue.boundaries','outlawiv-'),
   {id='outlawiv-stealthed',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
    spell('outlawiv-stealthed-ambush',8676),
    {id='outlawiv-stealthed-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='outlawiv-finish',type='branch',conditions=points('LESSTHANOREQUALS',-1),onFalse={
    spell('outlawiv-audacity',8676,own(386270)),
    spell('outlawiv-pistol-shot',185763,any(opportunity(6),all(opportunity(3),points('LESSTHANOREQUALS',3)))),
    spell('outlawiv-ambush',8676),
    spell('outlawiv-sinister-strike',193315),
   },onTrue={
    spell('outlawiv-between-the-eyes',315341),
    spell('outlawiv-killing-spree',51690),
    spell('outlawiv-coup-de-grace',441776),
    spell('outlawiv-dispatch',2098),
   }},
  },
 },
}))
