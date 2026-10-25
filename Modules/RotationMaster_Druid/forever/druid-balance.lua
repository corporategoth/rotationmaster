-- WoW Forever Balance Druid, levels 1–60, and the Druid catch-all (lowest priority): levels 1–9,
-- untalented casters and solo Restoration level here. Icy Veins' Balance order with Warcraft
-- Tavern's moving branch and Clearcasting Starfire: own DoTs, then Starfire while Eclipse charges
-- last (one Wrath, two Starfires), Wrath to fill. Hurricane (no cooldown on Forever) on three or
-- more enemies fighting you (engaged count; RM cannot count enemies around the target).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function aura(id)return{type='BUFF',unit='player',spell=id}end
local function own(id,unit)return{type='BUFF',unit=unit or'player',spell=id,anyrank=true,ownbuff=true}end
local function dot(id,mine)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=mine}end
local function combat()return{type='COMBAT',unit='player'}end
local function solo()return negate({type='GROUP'})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions,attack)return{id=id,type='stop',suppress_attack=not attack,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.druid.balance',revision=6,
 blocks={['forever.druid.boundaries']=3,['forever.druid.upkeep']=1,['forever.druid.dots']=2},
 nameKey='Default.Forever.Druid.Balance.Name',descriptionKey='Default.Forever.Druid.Balance.Description',
 applicability={families={'forever'},actionContext='player',class='DRUID'},
 tags={'balance','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/balance-druid-ranged-dps-pve-guide',title='Icy Veins: Forever Balance Druid PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/balance-druid-leveling',title='Icy Veins: Forever Balance Druid leveling',reviewedAt='2026-10-23',revision='2026-10-15'},
  {url='https://www.warcrafttavern.com/forever/guides/balance-druid/',title='Warcraft Tavern: Forever Balance Druid (Eclipse build)',reviewedAt='2026-10-23',notes='Moving branch and Clearcasting Starfire.'},
  {url='https://worldofwarcraft.blizzard.com/en-us/news/24301515',title='Blizzard: Forever class deep dive, Hunter and Druid',reviewedAt='2026-10-23',revision='2026-09-30',notes='Mechanics only (Eclipse, Hurricane cooldown, Omen of Clarity); no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/druid.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=10,
  cooldowns={
   block('bal-upkeep','forever.druid.upkeep','bal-'),
   spell('bal-moonkin',24858,negate(aura(24858))),
   spell('bal-prepull-rejuvenation',774,all(solo(),negate(combat()),{type='ATTACKABLE',unit='target'},negate(own(774)))),
   spell('bal-natures-grasp',16689,all(combat(),solo(),{type='THREAT',unit='target',threat=3},negate(own(16689)))),
   {id='bal-barkskin',type='spell',action=22812,ranked=false,disabled=true,conditions=all({type='CHANNELING',unit='player'},{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})},
   spell('bal-innervate',29166,all(combat(),solo())),
  },
  rotation={
   block('bal-boundaries','forever.druid.boundaries','bal-'),
   stop('bal-target',negate({type='ATTACKABLE',unit='target'}),true),
   {id='bal-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('bal-pull-wrath',5176),stop('bal-pull-stop')}},
   {id='bal-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('bal-moving-moonfire',8921,negate(dot(8921,true))),
    spell('bal-moving-insect-swarm',5570,negate(dot(5570,true))),
    spell('bal-moving-faerie-fire',770,all({type='GROUP'},negate(dot(770)))),
    stop('bal-moving-stop')}},
   {id='bal-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('bal-hurricane',16914)}},
   block('bal-dots','forever.druid.dots','bal-'),
   spell('bal-eclipse-starfire',2912,aura(408255)),
   spell('bal-clearcasting-starfire',2912,aura(16870)),
   spell('bal-wrath',5176),
   -- Wrath unaffordable (mana is secret on Forever; an unaffordable spell is not ready): let the
   -- DoTs run and melee (implicit Attack).
  },
 },
}))
