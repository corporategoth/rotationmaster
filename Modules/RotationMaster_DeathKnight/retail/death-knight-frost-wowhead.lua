-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Frost Death Knight after Wowhead (reference): Empower Rune Weapon at two
-- charges first, then Reaper's Mark, Pillar of Frost, Breath of Sindragosa and Frostwyrm's Fury in the
-- rotation; Obliterate on two Killing Machines (or one with Exterminate), Howling Blast on Rime,
-- Obliterate on Killing Machine, Empower Rune Weapon for a new Killing Machine, Frost Strike,
-- Obliterate, Howling Blast (runic power is secret on Retail, so there is no cap check). Disabled:
-- secret in Midnight combat.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local km=buff(51124)
local strong=BuiltinConditions.any({type='BUFF_STACKS',unit='player',spell=51124,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.all(km,BuiltinConditions.any(buff(441416),buff(447954))))
local function priority(p,builder,spender)return{
 BuiltinConditions.spell(p..'strong',builder,strong),BuiltinConditions.spell(p..'rime',49184,buff(59052)),
 BuiltinConditions.spell(p..'killing-machine',builder,km),BuiltinConditions.spell(p..'empower',47568,BuiltinConditions.negate(km)),BuiltinConditions.spell(p..'spend',spender),BuiltinConditions.spell(p..'build',builder),BuiltinConditions.spell(p..'howling-blast',49184)}end
local aoe=priority('fwh-aoe-',207230,194913)
aoe[#aoe+1]=BuiltinConditions.spell('fwh-aoe-obliterate',49020);aoe[#aoe+1]=BuiltinConditions.spell('fwh-aoe-frost-strike',49143)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.frost.wowhead',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','melee','reference','wowhead'},
 sources={
  {url='https://www.wowhead.com/guide/classes/death-knight/frost/rotation-cooldowns-pve-dps',title='Wowhead: Frost Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-12',notes='Read from a Wayback snapshot.'},
 },
 body={priority=5,disabled=true,specs={251},
  cooldowns={
   BuiltinConditions.block('fwh-utility','retail.deathknight.utility','fwh-'),
   BuiltinConditions.spell('fwh-remorseless-winter',196770,BuiltinConditions.combat()),
   BuiltinConditions.spell('fwh-raise-dead',46585,BuiltinConditions.combat()),
  },
  rotation={
   BuiltinConditions.block('fwh-boundaries','retail.deathknight.boundaries','fwh-'),
   BuiltinConditions.spell('fwh-empower-charges',47568,{type='SPELL_CHARGES',spell=47568,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.spell('fwh-reapers-mark',439843),
   BuiltinConditions.spell('fwh-pillar-of-frost',51271),
   BuiltinConditions.spell('fwh-breath-of-sindragosa',152279),
   BuiltinConditions.spell('fwh-frostwyrms-fury',279302),
   {id='fwh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},
    onTrue=aoe,onFalse=priority('fwh-st-',49020,49143)},
  },
 },
}))
