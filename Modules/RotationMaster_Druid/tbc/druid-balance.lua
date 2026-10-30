-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Balance (Icy Veins, Wowhead, Warcraft Tavern, simulator agree): Faerie Fire when a group
-- benefits, Moonfire never clipped and dropped first when mana runs short, Force of Nature
-- when the treants will live, Starfire filler (Wrath before Starfire and in melee while
-- leveling), Insect Swarm and Moonfire while moving, Hurricane for packs.
-- Catch-all Druid premade (lowest priority): every level, no talents, ties.
-- Shared blocks: Defaults/blocks/druid.lua. Original priority data, no guide prose.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.balance',revision=6,
 blocks={['tbc.druid.feral-form-target']=2,['tbc.druid.boundaries']=4,['tbc.druid.upkeep']=1},
 applicability={families={'tbc'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','balance','caster','single-target','aoe','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/tbc-classic/balance-druid-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/balance-druid-leveling-guide',title='Icy Veins: Balance Druid leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-03-31'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-balance-druid-boomkin-dps-rotation-cooldowns-abilities/',title='Warcraft Tavern: Balance Druid rotation',reviewedAt='2026-10-23'},
  },
 body={priority=0,
  cooldowns={
   {id='balance-upkeep',type='block',block='tbc.druid.upkeep',prefix='balance-'},
   {id='balance-moonkin',type='spell',action=24858,ranked=false,conditions=BuiltinConditions.negate(BuiltinConditions.any({type='FORM',form=24858},{type='FORM',form=768},{type='FORM',form=5487},{type='FORM',form=9634},{type='FORM',form=783},{type='FORM',form=1066},{type='FORM',form=33943},{type='FORM',form=40120}))},
   {id='balance-force-of-nature',type='spell',action=33831,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})},
   {id='balance-innervate',type='spell',action=29166,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.25})},
  },
  rotation={
   {id='balance-boundaries',type='block',block='tbc.druid.boundaries',prefix='balance-'},
   {id='balance-forms',type='block',block='tbc.druid.feral-form-target',prefix='balance-'},
   {id='balance-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    {id='balance-moving-swarm',type='spell',action=5570,ranked=false,conditions=BuiltinConditions.negate(dot(5570))},
    {id='balance-moving-moonfire',type='spell',action=8921,ranked=false,conditions=BuiltinConditions.negate(dot(8921))},
    {id='balance-moving-stop',type='stop',conditions={}},
   }},
   {id='balance-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
    {id='balance-pull-starfire',type='spell',action=2912,ranked=false,conditions={}},
    {id='balance-pull-wrath',type='spell',action=5176,ranked=false,conditions={}},
    {id='balance-pull-stop',type='stop',conditions={}},
   }},
   {id='balance-faerie-fire',type='spell',action=770,ranked=false,conditions=BuiltinConditions.all({type='GROUP'},BuiltinConditions.negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))},
   {id='balance-hurricane',type='spell',action=16914,ranked=false,conditions={type='DISTANCE_COUNT',enemy=true,distance=20,operator='GREATERTHANOREQUALS',value=3}},
   {id='balance-moonfire',type='spell',action=8921,ranked=false,conditions=BuiltinConditions.all(BuiltinConditions.negate(dot(8921)),{type='MANAPCT',unit='player',operator='GREATERTHANOREQUALS',value=0.3},BuiltinConditions.negate({type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=8}))},
   {id='balance-graceful-starfire',type='spell',action=2912,ranked=false,conditions=BuiltinConditions.ownBuff(16886)},
   {id='balance-melee-wrath',type='spell',action=5176,ranked=false,conditions=BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'})},
   {id='balance-starfire',type='spell',action=2912,ranked=false,conditions={}},
   {id='balance-wrath',type='spell',action=5176,ranked=false,conditions={}},
  },
 },
}))
