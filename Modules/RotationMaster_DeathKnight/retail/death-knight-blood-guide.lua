-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Blood Death Knight after Icy Veins and Wowhead (optimal reference): Death
-- Strike whenever it is affordable (health and runic power are secret on Retail), Bone Shield upkeep,
-- the San'layn Gift window, Crimson Scourge, Blood Boil, Heart Strike. Disabled: own buffs and target
-- debuffs are secret in Midnight combat, so those steps only run where they can be read.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local exterminate=BuiltinConditions.any(buff(441416),buff(447954))
local lowBones=BuiltinConditions.any(BuiltinConditions.negate(buff(195181)),{type='BUFF_STACKS',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=5},
 {type='BUFF_REMAIN',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=3},exterminate)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.blood.guide',revision=7,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/blood-death-knight-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Blood Death Knight rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/death-knight/blood/rotation-cooldowns-pve-tank',title='Wowhead: Blood Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-13',notes='Read from a Wayback snapshot; Death Strike at 75 runic power.'},
 },
 body={priority=10,disabled=true,specs={250},
  cooldowns={
   BuiltinConditions.block('bguide-utility','retail.deathknight.utility','bguide-'),
   BuiltinConditions.spell('bguide-raise-dead',46585,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-vampiric-blood',55233,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(buff(55233)))),
   BuiltinConditions.spell('bguide-reapers-mark',439843,BuiltinConditions.combat()),
   BuiltinConditions.spell('bguide-dancing-rune-weapon',49028,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(439843)),{type='DEBUFF',unit='target',spell=434765,owndebuff=true}))),
  },
  rotation={
   BuiltinConditions.block('bguide-boundaries','retail.deathknight.boundaries','bguide-'),
   {id='bguide-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={BuiltinConditions.spell('bguide-pull-caress',195292),BuiltinConditions.stop('bguide-pull-stop')}},
   BuiltinConditions.spell('bguide-death-strike',49998),
   {id='bguide-bones',type='branch',conditions=lowBones,onFalse={},onTrue={BuiltinConditions.spell('bguide-marrowrend',195182),BuiltinConditions.spell('bguide-bones-caress',195292)}},
   {id='bguide-gift',type='branch',conditions=BuiltinConditions.all(BuiltinConditions.known(433895),buff(434153)),onFalse={},onTrue={
    BuiltinConditions.spell('bguide-gift-death-strike',49998),
    BuiltinConditions.spell('bguide-gift-blood-boil',50842,BuiltinConditions.negate({type='SPELL_HISTORY_TIME',spell=50842,operator='LESSTHAN',value=10})),
    BuiltinConditions.spell('bguide-gift-death-and-decay',43265,BuiltinConditions.all(buff(81141),BuiltinConditions.negate(buff(434159)))),
    BuiltinConditions.spell('bguide-gift-heart-strike',206930),
    BuiltinConditions.stop('bguide-gift-stop')}},
   BuiltinConditions.spell('bguide-death-and-decay',43265,BuiltinConditions.any(buff(81141),BuiltinConditions.all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},BuiltinConditions.negate(buff(188290))))),
   BuiltinConditions.spell('bguide-vampiric-strike',433895),
   BuiltinConditions.spell('bguide-consumption',1263824),
   BuiltinConditions.spell('bguide-blood-boil',50842,BuiltinConditions.any(buff(1265968),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=55078,owndebuff=true}),{type='SPELL_CHARGES',spell=50842,operator='GREATERTHANOREQUALS',value=2})),
   BuiltinConditions.spell('bguide-heart-strike',206930),
  },
 },
}))
