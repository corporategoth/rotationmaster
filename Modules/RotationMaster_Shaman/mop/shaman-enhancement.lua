-- Mists of Pandaria Classic Enhancement Shaman, levels 10-90 (the recommended variant): Wowhead's Phase 5
-- order, which Warcraft Tavern, Method and Hekili follow. Selected in the Enhancement specialization (263)
-- from level 10 (RM stores MoP rotations per talent group). Out of combat Unleash
-- Elements while running in (Lightning Bolt from range before it is learned). Two or more engaged enemies:
-- Magma at six, Fire Nova at four once Flame Shock is spread, Chain Lightning at five Maelstrom Weapon (three
-- when it lands before the next swing), Lava Lash on a Flame Shocked target. Then Unleash Elements with
-- Unleashed Fury, Elemental Blast and Lightning Bolt at five stacks (or woven at three when the main-hand swing
-- is 1.1 s away), Stormblast in Ascendance, Stormstrike (Primal Strike before 26), Lava Lash, Flame Shock under
-- Unleash Flame, Unleash Elements, a plain Flame Shock when Unleash is far off, Earth Shock, Fire Nova on two,
-- Lightning Bolt from range. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=53817,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function swing(n)return{type='SWING_TIME_REMAIN',operator='GREATERTHANOREQUALS',value=n}end
local function shock(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,owndebuff=true,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local flame={type='DEBUFF',unit='target',spell=8050,owndebuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.shaman.enhancement',revision=4,
 blocks={['mop.shaman.manual-target']=1,['mop.shaman.lightning-shield']=1,['mop.shaman.group']=1,['mop.shaman.fire-totems']=1,
  ['mop.shaman.enhancement-upkeep']=2,['mop.shaman.enhancement-aoe']=1},
 nameKey='Default.MoP.Shaman.Enhancement.Name',descriptionKey='Default.MoP.Shaman.Enhancement.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='SHAMAN'},
 tags={'enhancement','dps','melee','leveling','endgame','wowhead','warcraft-tavern'},
 sources={{url='https://www.wowhead.com/mop-classic/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Enhancement Shaman rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.wowhead.com/mop-classic/guide/classes/shaman/enhancement/dps-leveling-talent-builds-tips',title='Wowhead: Enhancement Shaman levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2026-06-29'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-enhancement-shaman-rotation-cooldowns/',title='Warcraft Tavern: Enhancement Shaman rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/ShamanEnhancement.simc',title='Hekili (MoP fork): Enhancement Shaman priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=263}}},
 cooldowns={block('mop.shaman.lightning-shield','shaman-enh-'),block('mop.shaman.enhancement-upkeep','shaman-enh-'),block('mop.shaman.fire-totems','shaman-enh-'),
  block('mop.shaman.group','shaman-enh-'),
  spell('shaman-enh-shamanistic-rage',30823,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.6})),
 },
 rotation={
 block('mop.shaman.manual-target','shaman-enh-'),
 {id='shaman-enh-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('shaman-enh-pull-unleash',73680),
  spell('shaman-enh-pull-bolt',403,all(negate(known(73680)),{type='BEYOND_MELEE',unit='target'})),
  {id='shaman-enh-pull-stop',type='none',suppress_attack=false,conditions={}},
 }},
 block('mop.shaman.enhancement-aoe','shaman-enh-aoe-'),
 spell('shaman-enh-unleash-fury',73680,{type='TALENT',layout='grid',value=16}),
 spell('shaman-enh-elemental-blast',117014,any(maelstrom(5),all(maelstrom(1),swing(1.7)))),
 spell('shaman-enh-bolt',403,maelstrom(5)),
 spell('shaman-enh-bolt-weave',403,all(maelstrom(3),swing(1.1))),
 spell('shaman-enh-stormblast',115356,own(114051)),
 spell('shaman-enh-stormstrike',17364),
 spell('shaman-enh-primal-strike',73899,negate(known(17364))),
 spell('shaman-enh-lava-lash',60103),
 spell('shaman-enh-flame-shock-unleashed',8050,all(own(73683),any(negate(flame),shock('LESSTHAN',9)))),
 spell('shaman-enh-unleash',73680),
 spell('shaman-enh-flame-shock',8050,all(negate(flame),any(negate(known(73680)),{type='SPELL_COOLDOWN',spell=73680,operator='GREATERTHAN',value=5}))),
 spell('shaman-enh-earth-shock',8042),
 spell('shaman-enh-fire-nova',1535,all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},flame)),
 spell('shaman-enh-ranged-bolt',403,all(maelstrom(1),{type='BEYOND_MELEE',unit='target'})),
 }},
}))
