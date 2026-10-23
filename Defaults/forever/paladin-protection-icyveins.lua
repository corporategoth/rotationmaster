-- WoW Forever Protection Paladin after Icy Veins, levels 10–60: a player-chosen alternative to
-- rm.forever.paladin.protection (same switch, lower priority). Consecration first whenever mana
-- allows, on one target too; Judgement is held for taunts (no on-cooldown reminder), with Swift
-- Judgement to reset it; then Holy Strike and Exorcism on Undead and Demons.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.protection.icyveins',revision=1,
 blocks={['forever.paladin.boundaries']=1,['forever.paladin.aura-blessing']=1,['forever.paladin.taunt']=1,['forever.paladin.tank-upkeep']=1},
 nameKey='Default.Forever.Paladin.ProtectionIcyVeins.Name',descriptionKey='Default.Forever.Paladin.ProtectionIcyVeins.Description',
 applicability={families={'forever'},actionContext='player',class='PALADIN',minLevel=10,maxLevel=60},
 tags={'protection','tank','group','leveling','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/protection-paladin-tank-pve-guide',title='Icy Veins: Forever Protection Paladin PvE',reviewedAt='2026-10-23',revision='2026-10-19'},
  {url='https://www.icy-veins.com/wow-forever/protection-paladin-leveling',title='Icy Veins: Forever Protection Paladin leveling',reviewedAt='2026-10-23',revision='2026-10-19'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, cooldowns and GCDs only.'},
 },
 body={priority=35,switch=any(known(1310994),known(1311015),own(25780)),
  cooldowns={
   block('ivprot-tank-upkeep','forever.paladin.tank-upkeep','ivprot-'),
   block('ivprot-aura-blessing','forever.paladin.aura-blessing','ivprot-'),
  },
  rotation={
   block('ivprot-boundaries','forever.paladin.boundaries','ivprot-'),
   stop('ivprot-target',negate({type='ATTACKABLE',unit='target'}),true),
   spell('ivprot-consecration',26573,{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.3}),
   block('ivprot-taunt','forever.paladin.taunt','ivprot-'),
   spell('ivprot-holy-strike',679),
   spell('ivprot-exorcism',879,any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})),
  },
 },
}))
