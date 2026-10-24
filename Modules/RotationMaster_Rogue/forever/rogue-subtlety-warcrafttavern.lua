-- WoW Forever Subtlety Rogue, Warcraft Tavern's Ambush/Cutthroat build (player-chosen variant).
-- Applies with Subtlety as the main tree at Hemorrhage's tier (21 points) and Cutthroat talented
-- (trait node 105750), ranks below the recommended premade and ships off by default, so it runs
-- only when the player enables it and disables that one. Differs from the default:
-- Premeditation then Ambush on every opener, Backstab as the builder (Hemorrhage only when you
-- are being hit), Ghostly Strike on cooldown, Slice and Dice and Eviscerate at five points with
-- no Rupture, and Vanish into Ambush on a tanked boss. Shared parts: Defaults/blocks/forever-rogue.lua.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Assassination, 2 Combat, 3 Subtlety; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local behind=negate({type='THREAT',unit='target',threat=3})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.rogue.subtlety.warcrafttavern',revision=3,
 blocks={['forever.rogue.boundaries']=1,['forever.rogue.stealth-fallback']=2,['forever.rogue.reactive']=1,['forever.rogue.expose-armor']=1,['forever.rogue.upkeep']=2},
 nameKey='Default.Forever.Rogue.Subtlety.WarcraftTavern.Name',descriptionKey='Default.Forever.Rogue.Subtlety.WarcraftTavern.Description',
 applicability={families={'forever'},actionContext='player',class='ROGUE',minLevel=25,maxLevel=60},
 tags={'dps','melee','leveling','endgame','subtlety','warcraft-tavern'},
 sources={
 {url='https://github.com/simulationcraft/simc/blob/4dd64b4a212e946cdbf22219f7d7c42f2fe0e23d/engine/dbc/generated/trait_data.inc',title='SimulationCraft Forever trait data (1.60.1.70425): talent node IDs',reviewedAt='2026-10-23',revision='4dd64b4'},
 {url='https://www.warcrafttavern.com/forever/guides/subtlety-rogue/',title='Warcraft Tavern: Forever Subtlety Rogue (Ambush/Cutthroat build)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/warcraftforever/class-guides/subtlety-rogue/',title='wowtbc.gg: WoW Forever Subtlety Rogue (Cutthroat Ambush step)',reviewedAt='2026-10-23'}},
 body={priority=5,disabled=true,switch={type='AND',value={tree(3,21),{type='TALENT',layout='traits',node=105750,operator='GREATERTHANOREQUALS',value=1}}},
 cooldowns={block('forever.rogue.upkeep','rogue-tavern-'),
  spell('rogue-tavern-vanish',1856,all({type='COMBAT',unit='player'},{type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},negate({type='THREAT',unit='target',threat=3}))),
  spell('rogue-tavern-preparation',14185,all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=30}))},
 rotation={
 block('forever.rogue.boundaries','rogue-tavern-'),
 {id='rogue-tavern-stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  spell('rogue-tavern-premeditation',14183,points('LESSTHANOREQUALS',3)),
  block('forever.rogue.stealth-fallback','rogue-tavern-stealth-'),
 }},
 block('forever.rogue.reactive','rogue-tavern-'),
 {id='rogue-tavern-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-tavern-slice',5171,negate({type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true})),
  block('forever.rogue.expose-armor','rogue-tavern-'),
  spell('rogue-tavern-eviscerate',2098),
  {id='rogue-tavern-pool',type='none',suppress_attack=false,conditions={}},
 }},
 spell('rogue-tavern-ghostly-strike',14278),
 spell('rogue-tavern-backstab',53,behind),
 spell('rogue-tavern-hemorrhage',16511),
 spell('rogue-tavern-sinister',1752),
 }},
}))
