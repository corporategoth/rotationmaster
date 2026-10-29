-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Subtlety Rogue, Wowhead's Garrote build (player-chosen variant).
-- Applies with Subtlety as the main tree at Hemorrhage's tier (21 points), Dirty Deeds talented
-- (trait node 105745) and Premeditation known, ranks below the other Rogue premades and ships off
-- by default, so it runs only when the player picks it. Differs from the default:
-- Premeditation then Garrote on every opener, Vanish (then Preparation) spent in the
-- rotation to re-open with Garrote once the last one has run out, Rupture as the standing
-- five-point finisher, Hemorrhage as the only builder and no Ghostly Strike. Vanish is also
-- the class's escape; this premade spends it. Shared parts: Defaults/blocks/forever-rogue.lua.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Assassination, 2 Combat, 3 Subtlety; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=25},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function garroted()return{type='DEBUFF',unit='target',spell=703,anyrank=true,owndebuff=true}end
local function sliced()return{type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.rogue.subtlety.wowhead',revision=6,
 blocks={['forever.rogue.boundaries']=3,['forever.rogue.stealth-fallback']=3,['forever.rogue.expose-armor']=1,['forever.rogue.upkeep']=2},
 nameKey="Subtlety, Garrote build (Wowhead)",descriptionKey="Wowhead's Subtlety: Premeditation and Garrote on every opener, and Vanish (then Preparation) used in the rotation to open with Garrote again once the last one has run out. Slice and Dice kept up, Expose Armor in groups, Rupture as the five-point finisher, Hemorrhage as the only builder. This spends Vanish, your escape, on damage: choose it deliberately. It applies with Subtlety as your main talent tree, Dirty Deeds talented and Premeditation known. Same poison and cooldown reminders as the recommended premade. An alternative to the recommended Rogue DPS premade, off by default: enable it and disable that one, or raise its priority.",
 applicability={families={'forever'},actionContext='player',class='ROGUE'},
 tags={'dps','melee','leveling','endgame','subtlety','wowhead'},
 sources={
 {url='https://github.com/simulationcraft/simc/blob/4dd64b4a212e946cdbf22219f7d7c42f2fe0e23d/engine/dbc/generated/trait_data.inc',title='SimulationCraft Forever trait data (1.60.1.70425): talent node IDs',reviewedAt='2026-10-23',revision='4dd64b4'},
 {url='https://www.wowhead.com/forever/guide/classes/rogue/subtlety/level-30-dps-overview',title='Wowhead: Forever level 30 Subtlety Rogue',reviewedAt='2026-10-23',revision='2026-10-06'},
 {url='https://www.wowhead.com/forever/guide/classes/rogue/subtlety/dps-abilities',title='Wowhead: Forever Subtlety Rogue abilities',reviewedAt='2026-10-23',revision='2026-10-08'}},
 body={priority=4,disabled=true,switch={type='AND',value={tree(3,21),{type='TALENT',layout='traits',node=105745,operator='GREATERTHANOREQUALS',value=1},{type='SPELL_KNOWN',spell=14183}}},
 cooldowns={block('forever.rogue.upkeep','rogue-wowhead-'),
  spell('rogue-wowhead-vanish',1856,all({type='COMBAT',unit='player'},{type='SPELL_KNOWN',spell=703},negate(garroted()))),
  spell('rogue-wowhead-preparation',14185,all({type='COMBAT',unit='player'},negate(garroted()),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=30}))},
 rotation={
 block('forever.rogue.boundaries','rogue-wowhead-'),
 {id='rogue-wowhead-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  spell('rogue-wowhead-premeditation',14183,points('LESSTHANOREQUALS',3)),
  spell('rogue-wowhead-garrote',703),
  block('forever.rogue.stealth-fallback','rogue-wowhead-stealth-'),
 }},
 spell('rogue-wowhead-slice',5171,all(negate(sliced()),points('GREATERTHANOREQUALS',3))),
 block('forever.rogue.expose-armor','rogue-wowhead-'),
 spell('rogue-wowhead-slice-refresh',5171,all(points('GREATERTHANOREQUALS',4),{type='BUFF_REMAIN',unit='player',spell=5171,anyrank=true,ownbuff=true,operator='LESSTHAN',value=1})),
 {id='rogue-wowhead-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-wowhead-rupture',1943,negate({type='DEBUFF',unit='target',spell=1943,anyrank=true,owndebuff=true})),
  spell('rogue-wowhead-eviscerate',2098),
  {id='rogue-wowhead-pool',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('rogue-wowhead-hemorrhage',16511),
 spell('rogue-wowhead-sinister',1752,negate({type='SPELL_KNOWN',spell=16511})),
 }},
}))
