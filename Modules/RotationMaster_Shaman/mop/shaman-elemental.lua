-- Mists of Pandaria Classic Elemental Shaman, levels 10-90: Wowhead's Phase 5 order (Icy Veins agrees once
-- its talent steps are removed), with wowsims' Flame Shock gate on Earth Shock and its Flame Shock refresh
-- before Ascendance. Selected in the Elemental specialization (262)
-- from level 10 (RM stores MoP rotations per talent group). Out of combat a Lightning Bolt (Lava Burst with Unleashed
-- Fury) opens. Four or more engaged enemies: Magma in melee, free Lava Burst on Lava Surge, Lava Beam in
-- Ascendance, Chain Lightning. On the move: instants only. Otherwise Unleash Elements with Unleashed Fury,
-- Flame Shock when missing or under 3 s, Lava Burst into Flame Shock, Elemental Blast, Earth Shock at six
-- Lightning Shield charges with 6 s of Flame Shock left, Chain Lightning on two, Lightning Bolt. Earthquake
-- ships off. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function shock(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator=op,value=n}end
local function talent(i)return{type='TALENT',layout='grid',value=i}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
local ascended=own(114050)
-- Flame Shock when missing or about to tick out on a target that will live, or topped up just before Ascendance.
local refresh=any(all(any(negate(flame),shock('LESSTHAN',3)),any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=6})),
 all(shock('LESSTHAN',16),{type='SPELL_KNOWN',spell=114049},{type='SPELL_COOLDOWN',spell=114049,operator='LESSTHAN',value=2}))
local lava=any(shock('GREATERTHAN',2),own(77762),ascended)
local fulminate=all({type='BUFF_STACKS',unit='player',spell=324,ownbuff=true,operator='GREATERTHANOREQUALS',value=6},shock('GREATERTHANOREQUALS',6))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.elemental',revision=7,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1},
 nameKey='Default.MoP.Shaman.Elemental.Name',descriptionKey='Default.MoP.Shaman.Elemental.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'elemental','dps','caster','ranged','leveling','endgame','wowhead','icy-veins','wowsims'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/shaman/elemental/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Elemental Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/elemental-shaman-pve-rotation-cooldowns-abilities',title='Icy Veins: Elemental Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-22'},
 {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/shaman/elemental/apls/p5.apl.json',title='wowsims/mop: Elemental Shaman P5 APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-elemental-shaman-rotation-cooldowns/',title='Warcraft Tavern: Elemental Shaman rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/elemental-shaman/',title='wowtbc.gg: Elemental Shaman (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=30,specs={262},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.lightning-shield','shaman-ele-'),
  spell('shaman-ele-flametongue',8024,negate({type='WEAPON_IMBUE',enchant=5})),
  block('mop.shaman.fire-totems','shaman-ele-'),
  spell('shaman-ele-elemental-mastery',16166,all(combat(),any(negate({type='SPELL_KNOWN',spell=114049}),
   {type='SPELL_COOLDOWN',spell=114049,operator='LESSTHAN',value=4},{type='SPELL_COOLDOWN',spell=114049,operator='GREATERTHAN',value=85}))),
  spell('shaman-ele-ascendance',114049,all(combat(),negate(ascended),shock('GREATERTHAN',15),negate({type='SPELL_AVAIL',spell=51505}))),
  spell('shaman-ele-ancestral-swiftness',16188,all(combat(),negate(ascended))),
  block('mop.shaman.group','shaman-ele-'),
  spell('shaman-ele-thunderstorm',51490,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.15})),
  spell('shaman-ele-shamanistic-rage',30823,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-ele-'),
 {id='shaman-ele-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('shaman-ele-pull-lava',51505,talent(16)),
  spell('shaman-ele-pull-bolt',403),
  {id='shaman-ele-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-ele-aoe',type='branch',conditions=enemies(4),onFalse={},onTrue={
  spell('shaman-ele-magma',8190,all(negate({type='BEYOND_MELEE',unit='target'}),negate({type='TOTEM_SPELL',spell=2894}),negate({type='TOTEM_SPELL',spell=8190}))),
  {id='shaman-ele-earthquake',type='spell',action=61882,ranked=false,disabled=true,conditions=enemies(5)},
  spell('shaman-ele-aoe-surge',51505,own(77762)),
  spell('shaman-ele-lava-beam',114074,ascended),
  spell('shaman-ele-aoe-chain',421),
  {id='shaman-ele-aoe-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='shaman-ele-moving',type='branch',conditions=all({type='MOVING'},negate(own(79206))),onFalse={},onTrue={
  spell('shaman-ele-moving-unleash',73680,talent(16)),
  spell('shaman-ele-moving-flame-shock',8050,refresh),
  spell('shaman-ele-moving-lava',51505,any(own(77762),ascended)),
  spell('shaman-ele-moving-earth-shock',8042,{type='BUFF_STACKS',unit='player',spell=324,ownbuff=true,operator='GREATERTHANOREQUALS',value=6}),
  spell('shaman-ele-moving-bolt',403),
  {id='shaman-ele-moving-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('shaman-ele-unleash',73680,all(talent(16),negate(ascended))),
 spell('shaman-ele-flame-shock',8050,refresh),
 spell('shaman-ele-lava-burst',51505,lava),
 spell('shaman-ele-elemental-blast',117014),
 spell('shaman-ele-earth-shock',8042,fulminate),
 spell('shaman-ele-chain',421,enemies(2)),
 spell('shaman-ele-bolt',403),
 }},
}))
