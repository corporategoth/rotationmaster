-- WoW Forever Subtlety Rogue, Warcraft Tavern's Ambush/Cutthroat build (player-chosen variant).
-- Shares the Subtlety switch (Hemorrhage known) but ranks below the recommended premade, so it
-- runs only when the player disables that one: RM cannot see the passive talents (Cutthroat,
-- Puncturing Wounds) that tell this build from the bleed build. Differs from the default:
-- Premeditation then Ambush on every opener, Backstab as the builder (Hemorrhage only when you
-- are being hit), Ghostly Strike on cooldown, Slice and Dice and Eviscerate at five points with
-- no Rupture, and Vanish into Ambush on a tanked boss. Shared parts: Defaults/blocks/forever-rogue.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local behind=negate({type='ISSAME',unit='targettarget',otherunit='player'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.rogue.subtlety.warcrafttavern',revision=1,
 blocks={['forever.rogue.boundaries']=1,['forever.rogue.stealth-fallback']=1,['forever.rogue.reactive']=1,['forever.rogue.expose-armor']=1,['forever.rogue.upkeep']=1},
 nameKey='Default.Forever.Rogue.Subtlety.WarcraftTavern.Name',descriptionKey='Default.Forever.Rogue.Subtlety.WarcraftTavern.Description',
 applicability={families={'forever'},actionContext='player',class='ROGUE',minLevel=25,maxLevel=60},
 tags={'dps','melee','leveling','endgame','subtlety','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/forever/guides/subtlety-rogue/',title='Warcraft Tavern: Forever Subtlety Rogue (Ambush/Cutthroat build)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/warcraftforever/class-guides/subtlety-rogue/',title='wowtbc.gg: WoW Forever Subtlety Rogue (Cutthroat Ambush step)',reviewedAt='2026-10-23'}},
 body={priority=5,switch={type='SPELL_KNOWN',spell=16511},
 cooldowns={block('forever.rogue.upkeep','rogue-tavern-'),
  spell('rogue-tavern-vanish',1856,all({type='COMBAT',unit='player'},{type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
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
