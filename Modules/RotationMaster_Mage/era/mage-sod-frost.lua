-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Mage Frost (Phase 8 runes, Phase 7 sources), levels 10–60 with Frost as the
-- main tree. Fingers of Frost goes into Ice Lance at three or more of your Glaciate stacks, else Deep
-- Freeze; Balefire Bolt on a Brain Freeze proc and otherwise when safe (never at four of its stacks);
-- Living Bomb and Living Flame when engraved; Spellfrost Bolt, else Frostfire Bolt, else Frostbolt.
-- Frozen Orb, Icy Veins and Cold Snap are reminders. The spell-queue "double dip" stays with you.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local P='mage-sfrost-'
-- Fingers of Frost: simulator names the proc 400647, the client may show 400669/400670.
local fingers=BuiltinConditions.any(BuiltinConditions.buff(400647),BuiltinConditions.buff(400669),BuiltinConditions.buff(400670))
local function fingersStacks(n)return BuiltinConditions.any({type='BUFF_STACKS',unit='player',spell=400647,operator='GREATERTHANOREQUALS',value=n},
 {type='BUFF_STACKS',unit='player',spell=400669,operator='GREATERTHANOREQUALS',value=n},{type='BUFF_STACKS',unit='player',spell=400670,operator='GREATERTHANOREQUALS',value=n})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.frost',revision=6,
 blocks={['era.mage.boundaries']=3,['era.mage.wand-finish']=2,['sod.mage.balefire']=1,['sod.mage.balefire-brain-freeze']=1,
  ['sod.mage.living-bomb']=1,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'frost','raid','single-target','aoe','season-of-discovery'},
 sources={

  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/dps-talent-builds-runes',title='Wowhead: SoD Mage DPS runes (Phase 7)',reviewedAt='2026-10-23',revision='2025-02-07'},
  {url='https://www.icy-veins.com/wow-classic/frost-mage-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Frost Mage rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={
  priority=103,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={BuiltinConditions.block(P..'armor','sod.mage.armor',P),
   BuiltinConditions.spell(P..'frozen-orb',440802,BuiltinConditions.all({type='COMBAT',unit='player'},BuiltinConditions.negate(fingersStacks(2)))),
   BuiltinConditions.block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   BuiltinConditions.block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    BuiltinConditions.spell(P..'pull-spellfrost',412532),BuiltinConditions.spell(P..'pull-frostfire',401502),BuiltinConditions.spell(P..'pull-frostbolt',116),stop(P..'pull-stop')}},
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    BuiltinConditions.spell(P..'moving-ice-lance',400640,fingers),BuiltinConditions.spell(P..'moving-frozen-orb',440802),
    BuiltinConditions.spell(P..'moving-living-bomb',400613,BuiltinConditions.negate(own(400613))),BuiltinConditions.spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    BuiltinConditions.spell(P..'aoe-frozen-orb',440802),
    BuiltinConditions.spell(P..'aoe-living-flame',401556),
    BuiltinConditions.spell(P..'aoe-living-bomb',400613,BuiltinConditions.negate(own(400613))),
    BuiltinConditions.spell(P..'aoe-blizzard',10),
    BuiltinConditions.spell(P..'aoe-cone',120,near(2))}},
   BuiltinConditions.spell(P..'ice-lance',400640,BuiltinConditions.all(fingers,{type='DEBUFF_STACKS',unit='target',spell=1218345,owndebuff=true,operator='GREATERTHANOREQUALS',value=3})),
   BuiltinConditions.spell(P..'deep-freeze',428739,fingers),
   BuiltinConditions.block(P..'balefire-proc','sod.mage.balefire-brain-freeze',P),
   BuiltinConditions.block(P..'living-bomb','sod.mage.living-bomb',P),
   BuiltinConditions.spell(P..'living-flame',401556),
   BuiltinConditions.block(P..'balefire','sod.mage.balefire',P),
   BuiltinConditions.spell(P..'spellfrost',412532),
   BuiltinConditions.spell(P..'frostfire',401502),
   BuiltinConditions.spell(P..'frostbolt',116),
   BuiltinConditions.block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
