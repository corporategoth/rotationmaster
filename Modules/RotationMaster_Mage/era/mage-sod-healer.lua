-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Mage healer (Arcane or Frost, Temporal Beacon), levels 1–60, chosen when
-- Regeneration or Mass Regeneration is engraved. On a friendly target: Rewind Time and Chronostatic
-- Preservation below half health, Regeneration where your beacon is missing, Mass Regeneration,
-- Temporal Anomaly, then stop. On an enemy: damage that heals through the beacons, Spellfrost Bolt
-- for Frost healers, else Arcane Missiles on Missile Barrage, Arcane Barrage at two Arcane Blast
-- stacks, Balefire Bolt when safe (never at four of its stacks), Arcane Blast. Mass Regeneration's
-- channel is not protected: the next spell shows at once, so cancel it as Wowhead advises (its
-- direct healing is negligible). Whom to heal stays with the player.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function hp(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local P='mage-sheal-'
local combat={type='COMBAT',unit='player'}
local beacon={type='BUFF',unit='target',spell=400735,ownbuff=true}
local fingers=BuiltinConditions.any(BuiltinConditions.buff(400647),BuiltinConditions.buff(400669),BuiltinConditions.buff(400670))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.healer',revision=6,
 blocks={['era.mage.wand-finish']=2,['sod.mage.balefire']=1,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'arcane','healer','group','season-of-discovery'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/arcane-mage-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Arcane Mage healer rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/healer-overview',title='Wowhead: SoD Mage healer overview (Phase 7)',reviewedAt='2026-10-23',revision='2025-01-30'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/healer-talent-builds-runes',title='Wowhead: SoD Mage healer runes (Phase 7)',reviewedAt='2026-10-23',revision='2025-01-30'},
 },
 body={
  priority=105,
  switch=BuiltinConditions.any({type='RUNE_ENGRAVED',spell=412510},{type='RUNE_ENGRAVED',spell=401417}),
  cooldowns={BuiltinConditions.block(P..'armor','sod.mage.armor',P),
   BuiltinConditions.spell(P..'arcane-power',12042,combat),
   BuiltinConditions.spell(P..'presence-of-mind',12043,combat),
   BuiltinConditions.spell(P..'frozen-orb',440802,combat),
   BuiltinConditions.block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   BuiltinConditions.stop(P..'cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate({type='CHANNELING_SPELL',unit='player',spell=412510})))),
   {id=P..'friend',type='branch',conditions={type='FRIENDLY',unit='target'},onFalse={},onTrue={
    BuiltinConditions.spell(P..'rewind-time',401462,BuiltinConditions.all(beacon,hp('LESSTHAN',.5))),
    BuiltinConditions.spell(P..'chronostatic',436516,hp('LESSTHAN',.5)),
    BuiltinConditions.spell(P..'regeneration',401417,BuiltinConditions.negate(beacon)),
    BuiltinConditions.spell(P..'mass-regeneration',412510,BuiltinConditions.any(BuiltinConditions.negate(beacon),hp('LESSTHAN',.9))),
    BuiltinConditions.spell(P..'temporal-anomaly',428885),
    BuiltinConditions.stop(P..'friend-stop')}},
   BuiltinConditions.stop(P..'target',BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(combat,BuiltinConditions.negate({type='COMBAT',unit='target'}))))),
   {id=P..'pull',type='branch',conditions=combat,onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-spellfrost',412532),BuiltinConditions.spell(P..'pull-arcane-blast',400574),BuiltinConditions.stop(P..'pull-stop')}},
   -- Optional raw damage on packs; it converts far less healing.
   {id=P..'explosion',type='spell',action=1449,ranked=false,disabled=true,conditions={type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3}},
   {id=P..'frost',type='branch',conditions={type='RUNE_ENGRAVED',spell=412532},onFalse={},onTrue={
    {id=P..'frost-ice-lance',type='spell',action=400640,ranked=false,disabled=true,conditions=fingers},
    {id=P..'frost-deep-freeze',type='spell',action=428739,ranked=false,disabled=true,conditions=fingers},
    BuiltinConditions.spell(P..'frost-spellfrost',412532),BuiltinConditions.stop(P..'frost-stop')}},
   BuiltinConditions.spell(P..'missile-barrage',5143,BuiltinConditions.buff(400589)),
   BuiltinConditions.spell(P..'barrage',400610,{type='BUFF_STACKS',unit='player',spell=400573,operator='GREATERTHANOREQUALS',value=2}),
   BuiltinConditions.block(P..'balefire','sod.mage.balefire',P),
   BuiltinConditions.spell(P..'arcane-blast',400574),
   BuiltinConditions.spell(P..'fireball',133),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
