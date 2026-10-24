-- Classic Era Druid Balance after Icy Veins: Starfire and nothing else, no Moonfire or Insect Swarm
-- (the list for raids with the 16-debuff limit), Hurricane on packs. Same switch as the recommended
-- rm.era.druid.balance at a lower priority, shipped disabled.
local _,addon=...
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function moving()return{type='MOVING'}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.balance.icyveins',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.caster-cooldowns']=2,['era.druid.feral-cooldowns']=2,['era.druid.forms']=2,
  ['era.druid.cat']=1,['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['era.druid.bear']=2,['era.druid.bear-pull']=3,
  ['era.druid.caster-pull']=3},
 nameKey='Default.Era.Druid.Balance.IcyVeins.Name',descriptionKey='Default.Era.Druid.Balance.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'endgame','raid','balance','caster','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/balance-druid-ranged-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 },
 body={priority=1,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={ref('era-balance-iv-upkeep','era.druid.upkeep','era-balance-iv-'),ref('era-balance-iv-caster','era.druid.caster-cooldowns','era-balance-iv-'),
   ref('era-balance-iv-feral','era.druid.feral-cooldowns','era-balance-iv-feral-')},
  rotation={
   ref('era-balance-iv-boundaries','era.druid.boundaries','era-balance-iv-'),
   ref('era-balance-iv-forms','era.druid.forms','era-balance-iv-'),
   ref('era-balance-iv-pull','era.druid.caster-pull','era-balance-iv-pull-'),
   {id='era-balance-iv-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    {id='era-balance-iv-hurricane',type='spell',action=16914,ranked=false,conditions={type='NOT',value=moving()}},
    {id='era-balance-iv-aoe-stop',type='stop',suppress_attack=true,conditions={}}}},
   {id='era-balance-iv-moving',type='stop',suppress_attack=true,conditions=moving()},
   {id='era-balance-iv-starfire',type='spell',action=2912,ranked=false,conditions={}},
   {id='era-balance-iv-wrath',type='spell',action=5176,ranked=false,conditions={}},
   {id='era-balance-iv-dry',type='stop',conditions={}},
  },
 },
}))
