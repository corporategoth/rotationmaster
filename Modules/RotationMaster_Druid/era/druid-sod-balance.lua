-- Season of Discovery Druid Balance, levels 1-60, and the SoD default for every Druid no other SoD
-- premade fits. After wowsims P6 with Wowhead's Phase 8 thresholds: Starsurge whenever its buff is
-- down, Hurricane on six or more (four with the Gale Winds rune), Insect Swarm only on the move, Sunfire and Moonfire on
-- targets that live, Starfire only when empowered (Starsurge or Lunar Eclipse), Wrath filler.
-- In Cat or Bear Form it plays the SoD Feral sections.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function moving()return{type='MOVING'}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function ttd(v)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=v}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.balance',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['sod.druid.maul']=2,['sod.druid.balance-cooldowns']=1,
  ['sod.druid.forms']=2,['sod.druid.cat']=2,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.bear']=2,
  ['sod.druid.caster-pull']=3},
 nameKey='Default.SoD.Druid.Balance.Name',descriptionKey='Default.SoD.Druid.Balance.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','balance','caster','single-target','aoe','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/balance_druid/apls/phase_6.apl.json',title='wowsims/sod Balance Phase 6 APL',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Balance Druid rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-11'},
  {url='https://www.icy-veins.com/wow-classic/balance-druid-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={priority=103,
  cooldowns={ref('sod-balance-upkeep','era.druid.upkeep','sod-balance-'),ref('sod-balance-caster','era.druid.caster-cooldowns','sod-balance-'),
   ref('sod-balance-maul','sod.druid.maul','sod-balance-'),ref('sod-balance-cooldowns','sod.druid.balance-cooldowns','sod-balance-')},
  rotation={
   ref('sod-balance-boundaries','era.druid.boundaries','sod-balance-'),
   ref('sod-balance-forms','sod.druid.forms','sod-balance-'),
   ref('sod-balance-pull','sod.druid.caster-pull','sod-balance-pull-'),
   spell('sod-balance-starsurge',417157,negate({type='BUFF',unit='player',spell=417157,ownbuff=true}),true),
   -- Gale Winds (passive) makes Hurricane free of cooldown and twice as strong: worth it from four.
   {id='sod-balance-aoe',type='branch',conditions=any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=6},
    all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},{type='RUNE_ENGRAVED',spell=417135})),onFalse={},onTrue={
    spell('sod-balance-hurricane',16914,negate(moving()))}},
   {id='sod-balance-moving',type='branch',conditions=moving(),onFalse={},onTrue={
    spell('sod-balance-moving-insect-swarm',5570,negate(mine(5570))),spell('sod-balance-moving-sunfire',414684,negate(mine(414684)),true),
    spell('sod-balance-moving-moonfire',8921,negate(mine(8921))),{id='sod-balance-moving-stop',type='stop',suppress_attack=true,conditions={}}}},
   spell('sod-balance-sunfire',414684,all(negate(mine(414684)),ttd(8)),true),
   spell('sod-balance-moonfire',8921,all(negate(mine(8921)),ttd(8))),
   spell('sod-balance-starfire',2912,any({type='BUFF',unit='player',spell=417157,ownbuff=true},{type='BUFF',unit='player',spell=408255,anyrank=true})),
   spell('sod-balance-wrath',5176),
   {id='sod-balance-dry',type='stop',conditions={}},
  },
 },
}))
