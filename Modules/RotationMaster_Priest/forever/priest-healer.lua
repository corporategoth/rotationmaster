-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever healing Priest (Discipline and Holy) in a group, levels 10–60: selected without
-- Shadowform when Discipline or Holy is the main talent tree. Heals your current friendly target (RM suggests the spell; you pick the target):
-- shield, Prayer of Mending and Renew before the pull; dispels; Prayer of Mending, Holy Nova on Holy
-- Purpose, Penance, Renew when missing, Heal (Lesser Heal before it). Spare time on an enemy: DoTs,
-- Smite, wand. Health and mana are secret on Forever, so the target you pick is the only signal of
-- who needs healing; emergency heals, Prayer of Healing, Binding Heal, Greater and Flash Heal,
-- Desperate Prayer and Dark Sacrifice are the player's call.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Discipline, 2 Holy, 3 Shadow; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(...)local list={};for i,id in ipairs({...})do list[i]={type='SPELL_KNOWN',spell=id}end;return{type='OR',value=list}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local renewed={type='BUFF',unit='target',spell=139,anyrank=true,ownbuff=true}
local unshielded=negate({type='DEBUFF',unit='target',spell=6788})
local friendly={type='FRIENDLY',unit='target'}
local function dispel(kind)return{type='DISPELLABLE',unit='target',debufftype=kind}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.priest.healer',revision=7,
 blocks={['forever.priest.boundaries']=3,['forever.priest.upkeep']=1,['forever.priest.wand']=2},
 nameKey="Discipline and Holy healing",descriptionKey="Group healing once Discipline or Holy is your main talent tree and you do not know Shadowform. Heals your current friendly target: before the pull Power Word: Shield, Prayer of Mending and Renew; Dispel Magic and Abolish or Cure Disease; Prayer of Mending; Holy Nova on Holy Purpose; Penance; Renew when missing; Heal (Lesser Heal before it). On an enemy: Shadow Word: Pain, Holy Fire, Penance, Smite, wand. Reminders: Inner Fire, Fortitude, Divine Spirit, Power Infusion on another player, Inner Focus in combat and the racial spells. Health and mana are hidden from addons on Forever, so the target you pick is the only sign of who needs healing; emergency heals, Prayer of Healing, Binding Heal, Greater and Flash Heal, Desperate Prayer and Dark Sacrifice are your call. You pick who to heal and the rank; a Discipline healer before Penance (20–29) selects it by hand.",
 applicability={families={'forever'},actionContext='player',class='PRIEST'},
 tags={'discipline','holy','healer','group','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/discipline-priest-healer-pve-guide',title='Icy Veins: Forever Discipline Priest PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/holy-priest-healer-pve-guide',title='Icy Veins: Forever Holy Priest PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.wowhead.com/forever/guide/classes/priest/holy/level-30-healer-overview',title='Wowhead: Forever level 30 Holy Priest',reviewedAt='2026-10-23',revision='2026-10-06',notes='Binding Heal, Prayer of Healing; dungeon shield.'},
  {url='https://www.wowhead.com/forever/guide/classes/priest/discipline/level-30-healer-overview',title='Wowhead: Forever level 30 Discipline Priest',reviewedAt='2026-10-23',revision='2026-10-06'},
  {url='https://worldofwarcraft.com/en-us/news/24301514',title='Blizzard: Forever class deep dive, Priest and Warrior',reviewedAt='2026-10-23',revision='2026-09-30',notes='Rage from damage ignores absorbs, so tanks are shielded; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/priest.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, Holy Purpose proc.'},
 },
 body={priority=20,
  switch=all({type='GROUP'},negate(known(15473)),any(tree(1,1),tree(2,1))),
  cooldowns={
   block('heal-upkeep','forever.priest.upkeep','heal-'),
   spell('heal-power-infusion',10060,all({type='COMBAT',unit='player'},friendly,negate({type='ISSAME',unit='target',otherunit='player'}))),
   spell('heal-inner-focus',14751,{type='COMBAT',unit='player'}),
   spell('heal-divine-grace',1277370,all(friendly,{type='DEBUFF',unit='target',spell=6788})),
   spell('heal-contingency-plan',1277462,all({type='COMBAT',unit='player'},friendly)),
  },
  rotation={
   block('heal-boundaries','forever.priest.boundaries','heal-'),
   {id='heal-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    spell('heal-pain',589,negate(dot(589))),
    spell('heal-holy-fire',14914,negate(dot(14914))),
    spell('heal-enemy-penance',402174),
    spell('heal-smite',585),
    block('heal-wand','forever.priest.wand','heal-'),
    stop('heal-hostile-stop')}},
   stop('heal-target',negate(all(friendly,negate({type='DEAD',unit='target'})))),
   {id='heal-prepull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('heal-prepull-shield',17,unshielded),
    spell('heal-prepull-mending',401859),
    spell('heal-prepull-renew',139,negate(renewed)),
    stop('heal-prepull-stop')}},
   spell('heal-dispel-magic',527,dispel('Magic')),
   spell('heal-abolish-disease',552,dispel('Disease')),
   spell('heal-cure-disease',528,all(negate(known(552)),dispel('Disease'))),
   spell('heal-mending',401859),
   spell('heal-holy-nova',15237,{type='BUFF',unit='player',spell=1284536}),
   spell('heal-penance',402174),
   spell('heal-renew',139,negate(renewed)),
   spell('heal-heal',2054),
   spell('heal-lesser',2050,negate(known(2054))),
   stop('heal-done'),
  },
 },
}))
