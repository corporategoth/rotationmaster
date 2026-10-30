-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Mistweaver Monk, levels 10–90, in the Mistweaver specialization
-- (270). Icy Veins' and Wowhead's modes as one Branch on the target: a friendly
-- target is healed (Renewing Mist, Uplift on a hurt group, Expel Harm, Chi talents, Soothing Mist
-- with instant Enveloping and Surging Mist inside the channel); an enemy target is fistweaved
-- (Muscle Memory Tiger Palm and Blackout Kick for Tiger Power and Serpent's Zeal, Surging Mist at
-- five Vital Mists, Jab). Choosing whom to heal stays with the player. Soothing Mist is recognised
-- by the channel's own spell, so that channel does not end advice.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mine(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function hurt(count,below,distance)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=distance or 40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=count}end
local function talent(i)return{type='TALENT',layout='grid',value=i}end
local function off(id,action,conditions)local step=BuiltinConditions.spell(id,action,conditions);step.disabled=true;return step end
local SOOTHING,SURGING,RENEWING,EXPEL=115175,116694,115151,115072
local vital={type='BUFF_STACKS',unit='player',spell=118674,ownbuff=true,operator='GREATERTHANOREQUALS',value=5}
local memory=BuiltinConditions.ownBuff(139597)
local capped=BuiltinConditions.negate(chi('GREATERTHANOREQUALS',-1))
local friendly={type='FRIENDLY',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.mistweaver',revision=7,
 blocks={['mop.monk.upkeep']=1},
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MONK'},
 tags={'mistweaver','healer','leveling','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/mistweaver-monk-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Mistweaver Monk rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/mistweaver-monk-leveling',title='Icy Veins: MoP Classic Mistweaver Monk leveling',reviewedAt='2026-10-23',revision='2025-06-17',notes='The Eminence (fistweaving) list for questing.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/monk/mistweaver/healer-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Mistweaver Monk rotation (Phase 1)',reviewedAt='2026-10-23',revision='2025-08-10',notes='Read from a Wayback snapshot; group, single-target and downtime modes.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-mistweaver-monk-rotations-cooldowns/',title='Warcraft Tavern: MoP Mistweaver Monk rotation',reviewedAt='2026-10-23',notes='Thunder Focus Tea with Uplift, statue, fistweaving spenders.'},
 },
 body={priority=30,specs={270},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   BuiltinConditions.spell('mist-serpent-stance',115070,BuiltinConditions.negate({type='FORM',form=115070})),
   BuiltinConditions.block('mist-class','mop.monk.upkeep','mist-'),
   BuiltinConditions.spell('mist-statue',115313,BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=115313,operator='LESSTHAN',value=900}))),
   BuiltinConditions.spell('mist-mana-tea',115294,BuiltinConditions.all({type='BUFF_STACKS',unit='player',spell=115867,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},
    {type='MANAPCT',unit='player',operator='LESSTHAN',value=.85},BuiltinConditions.negate(hurt(2,.7)),BuiltinConditions.negate({type='MOVING'}))),
   BuiltinConditions.spell('mist-thunder-focus-tea',116680,BuiltinConditions.all(BuiltinConditions.combat(),chi('GREATERTHANOREQUALS',3),hurt(3,.85))),
   BuiltinConditions.spell('mist-chi-brew',115399,BuiltinConditions.all(BuiltinConditions.combat(),chi('GREATERTHANOREQUALS',-2),BuiltinConditions.any(hurt(3,.7),{type='SPELL_CHARGES',spell=115399,operator='EQUALS',value=2}))),
   BuiltinConditions.spell('mist-life-cocoon',116849,BuiltinConditions.all(BuiltinConditions.combat(),friendly,health('target','LESSTHAN',.35))),
   off('mist-revival',115310,BuiltinConditions.all(BuiltinConditions.combat(),hurt(4,.5))),
   BuiltinConditions.spell('mist-xuen',123904,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'})),
   BuiltinConditions.spell('mist-detox',115450,BuiltinConditions.all(friendly,BuiltinConditions.any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'}))),
   BuiltinConditions.spell('mist-fortifying-brew',115203,BuiltinConditions.all(BuiltinConditions.combat(),health('player','LESSTHAN',.4))),
   BuiltinConditions.spell('mist-diffuse-magic',122783,BuiltinConditions.all(BuiltinConditions.combat(),health('player','LESSTHAN',.4))),
   BuiltinConditions.spell('mist-dampen-harm',122278,BuiltinConditions.all(BuiltinConditions.combat(),health('player','LESSTHAN',.4))),
  },
  rotation={
   {id='mist-soothing',type='branch',conditions={type='CHANNELING_SPELL',unit='player',spell=SOOTHING},onFalse={},onTrue={
    BuiltinConditions.spell('mist-soothing-enveloping',124682,BuiltinConditions.all(BuiltinConditions.negate(mine(132120)),BuiltinConditions.negate(mine(124682)),health('target','LESSTHAN',.8))),
    BuiltinConditions.spell('mist-soothing-surging',SURGING,BuiltinConditions.any(health('target','LESSTHAN',.6),vital)),
    BuiltinConditions.stop('mist-soothing-stop')}},
   BuiltinConditions.stop('mist-cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
   {id='mist-heal',type='branch',conditions=BuiltinConditions.all(friendly,BuiltinConditions.negate({type='DEAD',unit='target'})),onTrue={
    BuiltinConditions.spell('mist-renewing',RENEWING),
    BuiltinConditions.spell('mist-uplift',116670,BuiltinConditions.all({type='GROUP'},chi('GREATERTHANOREQUALS',2),hurt(3,.85))),
    BuiltinConditions.spell('mist-expel-harm',EXPEL,chi('GREATERTHANOREQUALS',-1)),
    BuiltinConditions.spell('mist-chi-wave',115098),
    BuiltinConditions.spell('mist-zen-sphere',124081,BuiltinConditions.negate(mine(124081))),
    BuiltinConditions.spell('mist-chi-burst',123986),
    BuiltinConditions.spell('mist-jade-wind',116847,hurt(3,.9,10)),
    BuiltinConditions.spell('mist-crane-kick',101546,BuiltinConditions.all(BuiltinConditions.negate(talent(16)),hurt(3,.85,8),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=.5})),
    BuiltinConditions.spell('mist-vital-surging',SURGING,BuiltinConditions.all(vital,health('target','LESSTHAN',.9))),
    BuiltinConditions.spell('mist-soothing-mist',SOOTHING,health('target','LESSTHAN',.8)),
    BuiltinConditions.stop('mist-healthy')},
   onFalse={
    BuiltinConditions.stop('mist-target',BuiltinConditions.negate({type='ATTACKABLE',unit='target'})),
    {id='mist-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
     BuiltinConditions.spell('mist-pull-renewing',RENEWING),
     BuiltinConditions.spell('mist-pull-lightning',117952,{type='BEYOND_MELEE',unit='target'}),
     {id='mist-pull-stop',type='stop',conditions={}}}},
    BuiltinConditions.spell('mist-touch-of-death',115080),
    BuiltinConditions.spell('mist-power-palm',100787,BuiltinConditions.all(memory,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(125359)),remain(125359,'LESSTHANOREQUALS',2)))),
    BuiltinConditions.spell('mist-zeal-kick',100784,BuiltinConditions.all(memory,BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.ownBuff(127722)),remain(127722,'LESSTHAN',2)))),
    BuiltinConditions.spell('mist-memory-kick',100784,BuiltinConditions.all(memory,BuiltinConditions.any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},capped))),
    BuiltinConditions.spell('mist-memory-palm',100787,memory),
    BuiltinConditions.spell('mist-capped-kick',100784,capped),
    BuiltinConditions.spell('mist-free-surging',SURGING,BuiltinConditions.all(vital,chi('GREATERTHANOREQUALS',-1))),
    BuiltinConditions.spell('mist-chi-renewing',RENEWING,chi('GREATERTHANOREQUALS',-2)),
    BuiltinConditions.spell('mist-chi-expel',EXPEL,chi('GREATERTHANOREQUALS',-1)),
    BuiltinConditions.spell('mist-fist-chi-wave',115098),
    BuiltinConditions.spell('mist-fist-zen-sphere',124081,BuiltinConditions.negate(BuiltinConditions.ownBuff(124081))),
    BuiltinConditions.spell('mist-fist-chi-burst',123986),
    BuiltinConditions.spell('mist-fist-jade-wind',116847,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.negate(memory),chi('GREATERTHANOREQUALS',-1))),
    BuiltinConditions.spell('mist-fist-crane-kick',101546,BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},BuiltinConditions.negate(memory),chi('GREATERTHANOREQUALS',-1),BuiltinConditions.negate(talent(16)))),
    BuiltinConditions.spell('mist-fist-lightning',117952,{type='BEYOND_MELEE',unit='target'}),
    BuiltinConditions.spell('mist-jab',100780)}},
  },
 },
}))
