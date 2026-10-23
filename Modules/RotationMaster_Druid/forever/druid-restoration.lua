-- WoW Forever Restoration Druid in a group, levels 10–60, after Warcraft Tavern: heals your current
-- friendly target (RM suggests the spell; you choose the target). Swiftmend first when a HoT is
-- on a hurt target (it no longer consumes the HoT), Wild Growth when the party is hurt, Regrowth,
-- Rejuvenation, Healing Touch. On a hostile target: DoTs and Wrath. Solo Restoration levels with
-- the Balance premade. The Icy Veins HoT-first variant is rm.forever.druid.restoration.icyveins.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Balance, 2 Feral Combat, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function health(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.restoration',revision=2,
 blocks={['forever.druid.boundaries']=1,['forever.druid.upkeep']=1,['forever.druid.healer-upkeep']=1,['forever.druid.spare-damage']=1,['forever.druid.dots']=1},
 nameKey='Default.Forever.Druid.Restoration.Name',descriptionKey='Default.Forever.Druid.Restoration.Description',
 applicability={families={'forever'},actionContext='player',class='DRUID',minLevel=10,maxLevel=60},
 tags={'restoration','healer','group','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/forever/guides/restoration-druid/',title='Warcraft Tavern: Forever Restoration Druid',reviewedAt='2026-10-23'},
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-healer-pve-guide',title='Icy Veins: Forever Restoration Druid PvE',reviewedAt='2026-10-23',revision='2026-10-16',notes='Spare-time damage list and Tranquility.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Swiftmend keeps the HoT; Wild Growth cooldown; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs and ranks only.'},
 },
 body={priority=30,
  -- From 11 Restoration points (Gift of the Earthmother's tier), so dungeon healers at 20-24 qualify.
  switch=all({type='GROUP'},tree(3,11)),
  cooldowns={
   block('resto-upkeep','forever.druid.upkeep','resto-'),
   block('resto-healer-upkeep','forever.druid.healer-upkeep','resto-'),
   spell('resto-innervate',29166,all({type='COMBAT',unit='player'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.3})),
  },
  rotation={
   block('resto-boundaries','forever.druid.boundaries','resto-'),
   {id='resto-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    block('resto-damage','forever.druid.spare-damage','resto-hostile-')}},
   stop('resto-target',negate(all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})))),
   spell('resto-swiftmend',18562,all(any(hot(774),hot(8936)),health('LESSTHAN',.7))),
   spell('resto-wild-growth',408120,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=.9,operator='GREATERTHANOREQUALS',value=3}),
   spell('resto-regrowth',8936,all(health('LESSTHAN',.6),negate(hot(8936)))),
   spell('resto-rejuvenation',774,all(negate(hot(774)),any({type='ISSAME',unit='target',otherunit='focus'},health('LESSTHAN',.95)))),
   spell('resto-healing-touch',5185,health('LESSTHAN',.5)),
   stop('resto-done'),
  },
 },
}))
