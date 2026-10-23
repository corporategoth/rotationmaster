-- WoW Forever Restoration Druid after Icy Veins, levels 10–60: a player-chosen alternative to
-- rm.forever.druid.restoration (same switch, lower priority). HoT-first: Rejuvenation on the tank
-- (your focus) and on anyone taking light damage, Regrowth for stronger heals, Healing Touch only
-- with both HoTs already running, Swiftmend when a HoT target drops low; Innervate on cooldown.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function health(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.restoration.icyveins',revision=1,
 blocks={['forever.druid.boundaries']=1,['forever.druid.upkeep']=1,['forever.druid.healer-upkeep']=1,['forever.druid.spare-damage']=1,['forever.druid.dots']=1},
 nameKey='Default.Forever.Druid.RestorationIcyVeins.Name',descriptionKey='Default.Forever.Druid.RestorationIcyVeins.Description',
 applicability={families={'forever'},actionContext='player',class='DRUID',minLevel=10,maxLevel=60},
 tags={'restoration','healer','group','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-healer-pve-guide',title='Icy Veins: Forever Restoration Druid PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/restoration-druid-leveling',title='Icy Veins: Forever Restoration Druid leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs and ranks only.'},
 },
 body={priority=25,
  switch=all({type='GROUP'},any(known(18562),known(408120),known(1238214),known(1238215))),
  cooldowns={
   block('rejuv-upkeep','forever.druid.upkeep','rejuv-'),
   block('rejuv-healer-upkeep','forever.druid.healer-upkeep','rejuv-'),
   spell('rejuv-innervate',29166,{type='COMBAT',unit='player'}),
  },
  rotation={
   block('rejuv-boundaries','forever.druid.boundaries','rejuv-'),
   {id='rejuv-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
    block('rejuv-damage','forever.druid.spare-damage','rejuv-hostile-')}},
   stop('rejuv-target',negate(all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})))),
   spell('rejuv-rejuvenation',774,all(negate(hot(774)),any({type='ISSAME',unit='target',otherunit='focus'},health('LESSTHAN',.95)))),
   spell('rejuv-regrowth',8936,all(health('LESSTHAN',.6),negate(hot(8936)))),
   spell('rejuv-healing-touch',5185,all(health('LESSTHAN',.5),hot(774),hot(8936))),
   spell('rejuv-swiftmend',18562,all(any(hot(774),hot(8936)),health('LESSTHAN',.5))),
   spell('rejuv-wild-growth',408120,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=.9,operator='GREATERTHANOREQUALS',value=3}),
   stop('rejuv-done'),
  },
 },
}))
