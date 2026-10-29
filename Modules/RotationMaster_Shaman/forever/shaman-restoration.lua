-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Restoration Shaman, from Mana Tide Totem (16-point talent, level 25) to 60,
-- Icy Veins leveling order. Chosen with Restoration as the main tree and 16 points in it (Mana
-- Tide's tier); it outranks the other Shaman premades. With a friendly target: the instant Healing
-- Wave once you pop Nature's Swiftness, Cure Poison/Disease, Riptide when missing, Chain Heal in a
-- group, Healing Wave; then it stops. With a hostile target it helps with damage when healing is
-- quiet: Fire Nova and Chain Lightning on packs, Stormstrike into Earth Shock for the Wavebreaker
-- hybrid, Flame Shock on elites and bosses, Lightning Bolt, then melee. RM cannot pick a heal
-- target, and health and mana are secret on Forever: you choose who to heal by targeting them, and
-- when to use Nature's Swiftness and Lesser Healing Wave.
-- Left manual: downranking, Healing Stream vs Mana Spring, air totem choice, Purge and Ghost Wolf.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Talent trees in the Forever talent window's order (assumed classic: 1 Elemental, 2 Enhancement, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=20},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.restoration',revision=6,
 blocks={['forever.shaman.manual']=3,['forever.shaman.upkeep']=2,['forever.shaman.group-totems']=1,
  ['forever.shaman.caster-aoe']=1,['forever.shaman.stormstrike-hybrid']=1},
 applicability={families={'forever'},actionContext='player',class='SHAMAN'},
 tags={'healer','caster','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/restoration-shaman-leveling',title='Icy Veins: Forever Restoration Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.icy-veins.com/wow-forever/restoration-shaman-healer-pve-guide',title='Icy Veins: Forever Restoration Shaman healer PvE guide',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.wowhead.com/forever/guide/classes/shaman/restoration/level-30-healer-overview',title='Wowhead: Forever level 30 Restoration Shaman',reviewedAt='2026-10-23',revision='2026-10-07'},
 {url='https://www.wowhead.com/forever/guide/wavebreaker-shaman-hybrid-guide-for-wow-forever-35074',title='Wowhead (user guide): Wavebreaker Shaman hybrid',reviewedAt='2026-10-23',revision='2026-10-20'},
 {url='https://worldofwarcraft.com/en-us/news/24302097',title='Blizzard: Forever class deep dives, Mage and Shaman',reviewedAt='2026-10-23',revision='2026-10-07'}},
 body={priority=30,switch=tree(3,16),
 cooldowns={block('forever.shaman.upkeep','shaman-resto-'),block('forever.shaman.group-totems','shaman-resto-'),
  BuiltinConditions.spell('shaman-resto-mana-tide',16190,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'}))},
 rotation={
 block('forever.shaman.manual','shaman-resto-'),
 {id='shaman-resto-heal',type='branch',conditions={type='FRIENDLY',unit='target'},onTrue={
  BuiltinConditions.spell('shaman-resto-swift-wave',331,{type='BUFF',unit='player',spell=16188}),
  BuiltinConditions.spell('shaman-resto-cure-poison',526,{type='DISPELLABLE',unit='target',debufftype='Poison'}),
  BuiltinConditions.spell('shaman-resto-cure-disease',2870,{type='DISPELLABLE',unit='target',debufftype='Disease'}),
  BuiltinConditions.spell('shaman-resto-riptide',408521,BuiltinConditions.negate({type='BUFF',unit='target',spell=408521,anyrank=true,ownbuff=true})),
  BuiltinConditions.spell('shaman-resto-chain-heal',1064,{type='GROUP'}),
  BuiltinConditions.spell('shaman-resto-wave',331),
  {id='shaman-resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
 },onFalse={
  {id='shaman-resto-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
  block('forever.shaman.caster-aoe','shaman-resto-'),
  block('forever.shaman.stormstrike-hybrid','shaman-resto-'),
  BuiltinConditions.spell('shaman-resto-flame-shock',8050,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),
   BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'}))),
  BuiltinConditions.spell('shaman-resto-bolt',403,BuiltinConditions.negate({type='MOVING'})),
 }},
 }},
}))
