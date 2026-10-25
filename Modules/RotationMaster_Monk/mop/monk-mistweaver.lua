-- Mists of Pandaria Classic Mistweaver Monk, levels 10–90, in the Mistweaver specialization
-- (270). Icy Veins' and Wowhead's modes as one Branch on the target: a friendly
-- target is healed (Renewing Mist, Uplift on a hurt group, Expel Harm, Chi talents, Soothing Mist
-- with instant Enveloping and Surging Mist inside the channel); an enemy target is fistweaved
-- (Muscle Memory Tiger Palm and Blackout Kick for Tiger Power and Serpent's Zeal, Surging Mist at
-- five Vital Mists, Jab). Choosing whom to heal stays with the player. Soothing Mist is recognised
-- by the channel's own spell, so that channel does not end advice.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function mine(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function remain(id,op,v)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(unit,op,v)return{type='HEALTHPCT',unit=unit,operator=op,value=v}end
local function chi(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function hurt(count,below,distance)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=distance or 40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=count}end
local function talent(i)return{type='TALENT',layout='grid',value=i}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local SOOTHING,SURGING,RENEWING,EXPEL=115175,116694,115151,115072
local vital={type='BUFF_STACKS',unit='player',spell=118674,ownbuff=true,operator='GREATERTHANOREQUALS',value=5}
local memory=own(139597)
local capped=negate(chi('GREATERTHANOREQUALS',-1))
local friendly={type='FRIENDLY',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.monk.mistweaver',revision=7,
 blocks={['mop.monk.upkeep']=1},
 nameKey='Default.MoP.Monk.Mistweaver.Name',descriptionKey='Default.MoP.Monk.Mistweaver.Description',
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
   spell('mist-serpent-stance',115070,negate({type='FORM',form=115070})),
   block('mist-class','mop.monk.upkeep','mist-'),
   spell('mist-statue',115313,all({type='GROUP'},negate({type='SPELL_HISTORY_TIME',spell=115313,operator='LESSTHAN',value=900}))),
   spell('mist-mana-tea',115294,all({type='BUFF_STACKS',unit='player',spell=115867,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},
    {type='MANAPCT',unit='player',operator='LESSTHAN',value=.85},negate(hurt(2,.7)),negate({type='MOVING'}))),
   spell('mist-thunder-focus-tea',116680,all(combat(),chi('GREATERTHANOREQUALS',3),hurt(3,.85))),
   spell('mist-chi-brew',115399,all(combat(),chi('GREATERTHANOREQUALS',-2),any(hurt(3,.7),{type='SPELL_CHARGES',spell=115399,operator='EQUALS',value=2}))),
   spell('mist-life-cocoon',116849,all(combat(),friendly,health('target','LESSTHAN',.35))),
   off('mist-revival',115310,all(combat(),hurt(4,.5))),
   spell('mist-xuen',123904,all(combat(),{type='GROUP'})),
   spell('mist-detox',115450,all(friendly,any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'}))),
   spell('mist-fortifying-brew',115203,all(combat(),health('player','LESSTHAN',.4))),
   spell('mist-diffuse-magic',122783,all(combat(),health('player','LESSTHAN',.4))),
   spell('mist-dampen-harm',122278,all(combat(),health('player','LESSTHAN',.4))),
  },
  rotation={
   {id='mist-soothing',type='branch',conditions={type='CHANNELING_SPELL',unit='player',spell=SOOTHING},onFalse={},onTrue={
    spell('mist-soothing-enveloping',124682,all(negate(mine(132120)),negate(mine(124682)),health('target','LESSTHAN',.8))),
    spell('mist-soothing-surging',SURGING,any(health('target','LESSTHAN',.6),vital)),
    stop('mist-soothing-stop')}},
   stop('mist-cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
   {id='mist-heal',type='branch',conditions=all(friendly,negate({type='DEAD',unit='target'})),onTrue={
    spell('mist-renewing',RENEWING),
    spell('mist-uplift',116670,all({type='GROUP'},chi('GREATERTHANOREQUALS',2),hurt(3,.85))),
    spell('mist-expel-harm',EXPEL,chi('GREATERTHANOREQUALS',-1)),
    spell('mist-chi-wave',115098),
    spell('mist-zen-sphere',124081,negate(mine(124081))),
    spell('mist-chi-burst',123986),
    spell('mist-jade-wind',116847,hurt(3,.9,10)),
    spell('mist-crane-kick',101546,all(negate(talent(16)),hurt(3,.85,8),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=.5})),
    spell('mist-vital-surging',SURGING,all(vital,health('target','LESSTHAN',.9))),
    spell('mist-soothing-mist',SOOTHING,health('target','LESSTHAN',.8)),
    stop('mist-healthy')},
   onFalse={
    stop('mist-target',negate({type='ATTACKABLE',unit='target'})),
    {id='mist-pull',type='branch',conditions=combat(),onTrue={},onFalse={
     spell('mist-pull-renewing',RENEWING),
     spell('mist-pull-lightning',117952,{type='BEYOND_MELEE',unit='target'}),
     {id='mist-pull-stop',type='stop',conditions={}}}},
    spell('mist-touch-of-death',115080),
    spell('mist-power-palm',100787,all(memory,any(negate(own(125359)),remain(125359,'LESSTHANOREQUALS',2)))),
    spell('mist-zeal-kick',100784,all(memory,any(negate(own(127722)),remain(127722,'LESSTHAN',2)))),
    spell('mist-memory-kick',100784,all(memory,any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},capped))),
    spell('mist-memory-palm',100787,memory),
    spell('mist-capped-kick',100784,capped),
    spell('mist-free-surging',SURGING,all(vital,chi('GREATERTHANOREQUALS',-1))),
    spell('mist-chi-renewing',RENEWING,chi('GREATERTHANOREQUALS',-2)),
    spell('mist-chi-expel',EXPEL,chi('GREATERTHANOREQUALS',-1)),
    spell('mist-fist-chi-wave',115098),
    spell('mist-fist-zen-sphere',124081,negate(own(124081))),
    spell('mist-fist-chi-burst',123986),
    spell('mist-fist-jade-wind',116847,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},negate(memory),chi('GREATERTHANOREQUALS',-1))),
    spell('mist-fist-crane-kick',101546,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},negate(memory),chi('GREATERTHANOREQUALS',-1),negate(talent(16)))),
    spell('mist-fist-lightning',117952,{type='BEYOND_MELEE',unit='target'}),
    spell('mist-jab',100780)}},
  },
 },
}))
