-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Enhancement Shaman, Icy Veins variant (player-chosen, off by default). Same switch
-- as the recommended premade (Enhancement specialization). Stormstrike (Stormblast in Ascendance), then Lava Lash ahead of
-- the spender; Lightning Bolt at five Maelstrom Weapon or from three when it lands before the next swing;
-- Unleash Elements then Flame Shock; Earth Shock. Packs: Fire Nova at four once Flame Shock is spread, Flame
-- Shock and Lava Lash to spread it, Chain Lightning in place of Lightning Bolt. Shamanistic Rage on cooldown in
-- combat. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=53817,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
local spend=any(maelstrom(5),all(maelstrom(3),{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=1.1}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.enhancement.icyveins',revision=7,
 blocks={['mop.shaman.manual-target']=2,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1,
  ['mop.shaman.enhancement-upkeep']=2},
 nameKey='Default.MoP.Shaman.Enhancement.IcyVeins.Name',descriptionKey='Default.MoP.Shaman.Enhancement.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'enhancement','dps','melee','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/enhancement-shaman-pve-rotation-cooldowns-abilities',title='Icy Veins: Enhancement Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-22'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/enhancement-shaman-leveling',title='Icy Veins: Enhancement Shaman leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-22'}},
 body={priority=20,disabled=true,specs={263},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.shaman.lightning-shield','shaman-enh-iv-'),block('mop.shaman.enhancement-upkeep','shaman-enh-iv-'),block('mop.shaman.fire-totems','shaman-enh-iv-'),
  block('mop.shaman.group','shaman-enh-iv-'),
  spell('shaman-enh-iv-shamanistic-rage',30823,combat()),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-enh-iv-'),
 {id='shaman-enh-iv-pull',type='stop',suppress_attack=false,conditions=negate(combat())},
 {id='shaman-enh-iv-aoe',type='branch',conditions=enemies(2),onFalse={},onTrue={
  {id='shaman-enh-iv-big-pull',type='branch',conditions=enemies(4),onFalse={},onTrue={
   spell('shaman-enh-iv-fire-nova',1535,flame),
   spell('shaman-enh-iv-spread-shock',8050,negate(flame)),
   spell('shaman-enh-iv-spread-lash',60103,flame),
  }},
  spell('shaman-enh-iv-chain',421,spend),
 }},
 spell('shaman-enh-iv-stormblast',115356,own(114051)),
 spell('shaman-enh-iv-stormstrike',17364),
 spell('shaman-enh-iv-primal-strike',73899,negate(known(17364))),
 spell('shaman-enh-iv-lava-lash',60103),
 spell('shaman-enh-iv-bolt',403,spend),
 spell('shaman-enh-iv-unleash',73680),
 spell('shaman-enh-iv-flame-shock',8050,any(own(73683),negate(flame))),
 spell('shaman-enh-iv-earth-shock',8042),
 }},
}))
