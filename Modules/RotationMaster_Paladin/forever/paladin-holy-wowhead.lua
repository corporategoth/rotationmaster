-- WoW Forever Holy Paladin after Wowhead's level-30 guide, levels 10–60: a player-chosen
-- alternative to rm.forever.paladin.holy (same switch, lower priority). Holy Shock as a routine
-- heal on cooldown, then Holy Light for big deficits and Flash of Light; on an enemy, keep your
-- Judgement of Light up by swapping to Seal of Light, judging, and swapping back to Righteousness,
-- then Holy Strike, Exorcism on Undead and Demons, Holy Shock and Consecration.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Holy, 2 Protection, 3 Retribution; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id,unit)return{type='BUFF',unit=unit or'player',spell=id,anyrank=true,ownbuff=true}end
local function health(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local judged={type='DEBUFF',unit='target',spell=20185,anyrank=true,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.holy.wowhead',revision=2,
 blocks={['forever.paladin.boundaries']=1,['forever.paladin.aura-blessing']=1,['forever.paladin.dispel']=1,['forever.paladin.healer-upkeep']=1},
 nameKey='Default.Forever.Paladin.HolyWowhead.Name',descriptionKey='Default.Forever.Paladin.HolyWowhead.Description',
 applicability={families={'forever'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=60},
 tags={'holy','healer','group','wowhead'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/paladin/holy/level-30-healer-overview',title='Wowhead: Forever level 30 Holy Paladin',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and debuffs only.'},
 },
 body={priority=15,switch=all({type='GROUP'},tree(1,21),negate(own(25780))),
  cooldowns={
   block('whholy-healer-upkeep','forever.paladin.healer-upkeep','whholy-'),
   block('whholy-aura-blessing','forever.paladin.aura-blessing','whholy-'),
  },
  rotation={
   block('whholy-boundaries','forever.paladin.boundaries','whholy-'),
   {id='whholy-friendly',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('whholy-shock',1311606,health('LESSTHAN',.95)),
    block('whholy-dispel','forever.paladin.dispel','whholy-'),
    spell('whholy-light',635,health('LESSTHAN',.5)),
    spell('whholy-flash',19750,health('LESSTHAN',.9)),
    stop('whholy-healed')}},
   {id='whholy-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    spell('whholy-swap-light',20165,all(negate(own(20165)),negate(judged))),
    spell('whholy-judgement',20271,any(all(own(20165),negate(judged)),own(20154))),
    spell('whholy-swap-righteousness',20154,all(own(20165),judged)),
    spell('whholy-strike',679),
    spell('whholy-exorcism',879,any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})),
    spell('whholy-enemy-shock',1311606),
    spell('whholy-consecration',26573),
    stop('whholy-hostile-done',nil,true)}},
   stop('whholy-done'),
  },
 },
}))
