-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Mage Fire, levels 10–60, chosen when you have Fire points and none in Frost, or Fire
-- is your main tree. Pyroblast (else Fireball) opens; Presence of Mind goes into Pyroblast; Improved
-- Scorch keeps five Fire Vulnerability stacks on targets that will live; Fire Blast and Scorch
-- finish; Fireball fills. Blast Wave, Flamestrike, Arcane Explosion, Cone of Cold and Blizzard on
-- three or more engaged enemies. Combustion at five stacks on elites or long fights.
-- The Warcraft Tavern variant (rm.era.mage.fire.warcrafttavern) spends Combustion at the pull.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function class(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function lives(op,seconds)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=seconds}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local P='mage-fire-'
local scorch={type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1}
local stacked={type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5}
local elite=BuiltinConditions.any(class('elite'),class('rareelite'),class('worldboss'))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.mage.fire',revision=5,
 blocks={['era.mage.boundaries']=3,['era.mage.moving']=2,['era.mage.nova']=1,['era.mage.execute']=2,
  ['era.mage.wand-finish']=2,['era.mage.armor']=1,['era.mage.upkeep']=1},
 applicability={families={'era'},actionContext='player',class='MAGE'},
 tags={'fire','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Mage DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/fire-mage-leveling-talent-build-from-1-to-60',title='Icy Veins: Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Mage DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.wowhead.com/classic/guide/classes/mage/fire/leveling-tips',title='Wowhead: Classic Fire Mage leveling',reviewedAt='2026-10-23',revision='2024-11-20'},

  {url='https://github.com/kaminaris/MaxDps-Mage/tree/886c8e27f48e38e0f9b8c22cf56b5e625dfce3f0/Specialization/Classic',title='MaxDps-Mage Classic Fire module',reviewedAt='2026-10-23',revision='886c8e2'},
 },
 body={
  priority=10,
  -- Readable arm first: any Fire point and no Frost point; then Fire as the main tree.
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},BuiltinConditions.any(BuiltinConditions.all({type='TALENT_TREE_POINTS',tree=3,operator='EQUALS',value=0},{type='TALENT_TREE_POINTS',tree=2,operator='GREATERTHANOREQUALS',value=1}),
   {type='PRIMARY_TALENT_TREE',tree=2})}},
  cooldowns={BuiltinConditions.block(P..'armor','era.mage.armor',P),
   BuiltinConditions.spell(P..'combustion',11129,BuiltinConditions.all({type='COMBAT',unit='player'},BuiltinConditions.any(stacked,BuiltinConditions.negate(scorch)),BuiltinConditions.any(elite,lives('GREATERTHAN',10)))),
   BuiltinConditions.block(P..'upkeep','era.mage.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-pyroblast',11366),BuiltinConditions.spell(P..'pull-fireball',133),stop(P..'pull-stop')}},
   BuiltinConditions.spell(P..'presence-pyroblast',11366,{type='BUFF',unit='player',spell=12043}),
   BuiltinConditions.block(P..'moving','era.mage.moving',P),
   BuiltinConditions.block(P..'nova','era.mage.nova',P),
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell(P..'aoe-blast-wave',11113,near(2)),
    BuiltinConditions.spell(P..'aoe-flamestrike',2120,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
    BuiltinConditions.spell(P..'aoe-explosion',1449,near(3)),
    BuiltinConditions.spell(P..'aoe-cone',120,near(2)),
    BuiltinConditions.spell(P..'aoe-blizzard',10)}},
   BuiltinConditions.spell(P..'scorch',2948,BuiltinConditions.all(scorch,BuiltinConditions.any(BuiltinConditions.negate(stacked),{type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5}),
    BuiltinConditions.any(elite,lives('GREATERTHAN',15)))),
   BuiltinConditions.block(P..'execute','era.mage.execute',P),
   BuiltinConditions.spell(P..'execute-scorch',2948,lives('LESSTHAN',3)),
   -- Optional: weave Fire Blast whenever ready with spare mana (MaxDps); the guides keep it for moving.
   {id=P..'fire-blast-weave',type='spell',action=2136,ranked=false,disabled=true,conditions={type='MANAPCT',unit='player',operator='GREATERTHAN',value=.6}},
   BuiltinConditions.spell(P..'fireball',133),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
