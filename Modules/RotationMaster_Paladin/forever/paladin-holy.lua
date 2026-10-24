-- WoW Forever Holy Paladin in a group, levels 10–60, once Holy is the main tree with 21 points (Holy
-- Shock's tier) and Righteous Fury is off; a grouped Shockadin lands here too, and the hostile-target list
-- is its damage list. Icy Veins' healing order on your current friendly target: Holy Shock on your
-- Light's Vigil target, Light's Vigil in combat, dispels, Holy Shock on the move, Holy Light with
-- Infusion of Light, Flash of Light as the main heal. Health and mana are secret on Forever, so the
-- target you pick is the only signal of who needs healing, and emergency Holy Shocks and big Holy
-- Lights are the player's call.
-- The Wowhead Holy Shock-on-cooldown variant is rm.forever.paladin.holy.wowhead.
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
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local evil=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.holy',revision=4,
 blocks={['forever.paladin.boundaries']=2,['forever.paladin.aura-blessing']=1,['forever.paladin.dispel']=1,['forever.paladin.healer-upkeep']=2},
 nameKey='Default.Forever.Paladin.Holy.Name',descriptionKey='Default.Forever.Paladin.Holy.Description',
 applicability={families={'forever'},actionContext='player',class='PALADIN'},
 tags={'holy','healer','group','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/holy-paladin-healer-pve-guide',title='Icy Veins: Forever Holy Paladin PvE',reviewedAt='2026-10-23',revision='2026-10-20'},
  {url='https://www.icy-veins.com/wow-forever/holy-paladin-leveling',title='Icy Veins: Forever Holy Paladin leveling',reviewedAt='2026-10-23',revision='2026-10-19'},
  {url='https://www.wowhead.com/forever/guide/classes/paladin/holy/level-30-healer-overview',title='Wowhead: Forever level 30 Holy Paladin',reviewedAt='2026-10-23',revision='2026-10-06',notes='Judgement of Light on an enemy when Seal of Light is up.'},
  {url='https://worldofwarcraft.com/en-us/news/24302099',title='Blizzard: Forever class deep dive, Paladin',reviewedAt='2026-10-23',revision='2026-10-15',notes='Light\'s Vigil, Infusion of Light; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Light\'s Vigil target aura, Infusion of Light buff, ranks.'},
 },
 body={priority=20,switch=all({type='GROUP'},tree(1,21),negate(own(25780))),
  cooldowns={
   block('holy-healer-upkeep','forever.paladin.healer-upkeep','holy-'),
   block('holy-aura-blessing','forever.paladin.aura-blessing','holy-'),
  },
  rotation={
   block('holy-boundaries','forever.paladin.boundaries','holy-'),
   {id='holy-friendly',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    -- Your Light's Vigil on the target: the next Holy Shock heals its whole party.
    spell('holy-vigil-shock',1311606,own(1310909,'target')),
    spell('holy-vigil',1310911,{type='COMBAT',unit='player'}),
    block('holy-dispel','forever.paladin.dispel','holy-'),
    spell('holy-moving-shock',1311606,{type='MOVING'}),
    spell('holy-infused-light',635,{type='BUFF',unit='player',spell=437063}),
    spell('holy-flash',19750),
    stop('holy-healed')}},
   {id='holy-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    spell('holy-judgement',20271,all(own(20165),negate({type='DEBUFF',unit='target',spell=20185,anyrank=true,owndebuff=true}))),
    spell('holy-shock',1311606),
    spell('holy-enemy-vigil',1310911,{type='SPELL_COOLDOWN',spell=1311606,operator='GREATERTHAN',value=3}),
    spell('holy-strike',679),
    spell('holy-exorcism',879,evil),
    stop('holy-hostile-done',nil,true)}},
   stop('holy-done'),
  },
 },
}))
