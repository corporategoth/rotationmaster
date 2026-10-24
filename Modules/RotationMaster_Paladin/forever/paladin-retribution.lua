-- WoW Forever Retribution Paladin and every melee Paladin, levels 1–60; the Paladin catch-all
-- (lowest priority). Wowhead's level-30 order: keep a damage seal up (Seal of the Crusader judged
-- once on an elite, then Command with a slow weapon, else Righteousness), Holy Strike on cooldown,
-- Holy Shock and Light's Vigil for a Shockadin, Exorcism on Undead and Demons, Consecration on three
-- or more, Hammer of Wrath (usable only in its execute range). Judgement is off the global
-- cooldown, so it is a reminder. Mana, health and the swing timer are secret on Forever, so Icy
-- Veins' mana rules, out-of-combat healing, Lay on Hands and Twist of Light seal swapping are left
-- to the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function remain(id)return{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='GREATERTHANOREQUALS',value=3}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions,attack)return{id=id,type='none',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local evil=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local crusaded={type='DEBUFF',unit='target',spell=21183,anyrank=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.paladin.retribution',revision=3,
 blocks={['forever.paladin.boundaries']=1,['forever.paladin.aura-blessing']=1,['forever.paladin.main-seal']=1},
 nameKey='Default.Forever.Paladin.Retribution.Name',descriptionKey='Default.Forever.Paladin.Retribution.Description',
 applicability={families={'forever'},actionContext='player',class='PALADIN',minLevel=1,maxLevel=60},
 tags={'retribution','melee','leveling','single-target','aoe','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/forever/guide/classes/paladin/retribution/level-30-dps-overview',title='Wowhead: Forever level 30 Retribution Paladin',reviewedAt='2026-10-23',revision='2026-10-10'},
  {url='https://www.icy-veins.com/wow-forever/retribution-paladin-leveling',title='Icy Veins: Forever Retribution Paladin leveling',reviewedAt='2026-10-23',revision='2026-10-17',notes='Mana rules, Hammer of Wrath on runners, out-of-combat healing.'},
  {url='https://www.icy-veins.com/wow-forever/retribution-paladin-melee-dps-pve-guide',title='Icy Veins: Forever Retribution Paladin PvE',reviewedAt='2026-10-23',revision='2026-10-17',notes='Hammer of Justice before a Seal of Command Judgement (optional step).'},
  {url='https://worldofwarcraft.com/en-us/news/24302099',title='Blizzard: Forever class deep dive, Paladin',reviewedAt='2026-10-23',revision='2026-10-15',notes='Holy Strike, non-consuming Judgement, Twist of Light; no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/paladin.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks, cooldowns and GCDs only.'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('ret-aura-blessing','forever.paladin.aura-blessing','ret-'),
   spell('ret-judgement',20271,all(combat(),{type='ATTACKABLE',unit='target'},any(own(20154),own(20375),own(21082),own(20164)))),
   off('ret-hammer-of-justice',853,all(combat(),own(20375),{type='SPELL_COOLDOWN',spell=20271,operator='LESSTHAN',value=1},
    negate({type='CLASSIFICATION',unit='target',value='worldboss'}))),
  },
  rotation={
   block('ret-boundaries','forever.paladin.boundaries','ret-'),
   stop('ret-target',negate({type='ATTACKABLE',unit='target'}),true),
   {id='ret-seal',type='branch',conditions=any(remain(20154),remain(20375),remain(21082)),onTrue={},onFalse={
    spell('ret-crusader',21082,all(negate(crusaded),elite,{type='SPELL_COOLDOWN',spell=20271,operator='LESSTHAN',value=2})),
    block('ret-main-seal','forever.paladin.main-seal','ret-')}},
   {id='ret-swap',type='branch',conditions=all(own(21082),crusaded),onFalse={},onTrue={
    block('ret-swap-seal','forever.paladin.main-seal','ret-swap-')}},
   spell('ret-holy-strike',679),
   spell('ret-holy-shock',1311606),
   spell('ret-lights-vigil',1310911,{type='SPELL_COOLDOWN',spell=1311606,operator='GREATERTHAN',value=3}),
   spell('ret-exorcism',879,evil),
   {id='ret-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('ret-aoe-consecration',26573),spell('ret-aoe-holy-wrath',2812,evil)}},
   spell('ret-hammer-of-wrath',24275),
  },
 },
}))
