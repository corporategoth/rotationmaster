-- Retail (Midnight) Enhancement Shaman, Stormbringer (SimulationCraft's single_sb and aoe lists,
-- Icy Veins, Wowhead): the optimal reference, disabled by default because Flame Shock, Crash
-- Lightning, Lashing Flames and cooldown timings are hidden in Midnight combat (Maelstrom Weapon
-- itself stays readable). Three or more engaged enemies: Crash Lightning to keep its buff,
-- Tempest at 10 Maelstrom Weapon, Chain Lightning at 9+, Crash Lightning, Lava Lash, Sundering.
-- Then: Primordial Storm at 9+, Voltaic Blaze or Flame Shock when Flame Shock is missing,
-- Sundering, Crash Lightning to keep its buff, Lava Lash to apply Lashing Flames, Windstrike,
-- Tempest or Lightning Bolt at 10 (8+ with Voltaic Blaze or Crash Lightning about ready),
-- Stormstrike at two charges, Lava Lash, Stormstrike, Voltaic Blaze, Crash Lightning, Lightning
-- Bolt at 5+, Flame Shock. Reminders: Doom Winds, Ascendance, Feral Spirit.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function mw(n)return{type='BUFF_STACKS',unit='player',spell=344179,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function soon(id)return{type='SPELL_COOLDOWN',spell=id,operator='LESSTHAN',value=1.5}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local shocked={type='DEBUFF',unit='target',spell=188389,owndebuff=true}
local nearly=all(mw(8),any(soon(470057),soon(187874)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.enhancement.stormbringer',revision=3,
 blocks={['retail.shaman.boundaries']=1,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 nameKey='Default.Retail.Shaman.Enhancement.Stormbringer.Name',descriptionKey='Default.Retail.Shaman.Enhancement.Stormbringer.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'enhancement','melee','reference','stormbringer','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/shaman_enhancement.simc',title='SimulationCraft: Enhancement Shaman default list (single_sb, aoe)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Enhancement Shaman rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/shaman/enhancement/rotation-cooldowns-pve-dps',title='Wowhead: Enhancement Shaman rotation',reviewedAt='2026-10-23',revision='2026-08-12'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=263},
  cooldowns={
   block('retail.shaman.upkeep','enhsb-'),
   block('retail.shaman.lightning-shield','enhsb-'),
   spell('enhsb-doom-winds',384352,fight),
   spell('enhsb-ascendance',114051,all(fight,negate(own(466772)))),
   spell('enhsb-feral-spirit',51533,fight),
  },
  rotation={
   block('retail.shaman.boundaries','enhsb-'),
   {id='enhsb-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('enhsb-aoe-crash-buff',187874,negate(own(187878))),
    spell('enhsb-aoe-tempest',452201,mw(10)),
    spell('enhsb-aoe-chain-lightning',188443,mw(9)),
    spell('enhsb-aoe-crash-lightning',187874),
    spell('enhsb-aoe-lava-lash',60103),
    spell('enhsb-aoe-sundering',197214),
   }},
   spell('enhsb-primordial-storm',1218090,mw(9)),
   spell('enhsb-voltaic-opener',470057,negate(shocked)),
   spell('enhsb-flame-shock-missing',470411,negate(shocked)),
   spell('enhsb-sundering',197214),
   spell('enhsb-crash-buff',187874,negate(own(187878))),
   spell('enhsb-lashing-flames',60103,negate({type='DEBUFF',unit='target',spell=334168,owndebuff=true})),
   spell('enhsb-windstrike',115356),
   spell('enhsb-tempest-full',452201,mw(10)),
   spell('enhsb-bolt-full',188196,mw(10)),
   spell('enhsb-tempest-early',452201,nearly),
   spell('enhsb-bolt-early',188196,nearly),
   spell('enhsb-stormstrike-capped',17364,{type='SPELL_CHARGES',spell=17364,operator='GREATERTHANOREQUALS',value=2}),
   spell('enhsb-lava-lash',60103),
   spell('enhsb-stormstrike',17364),
   spell('enhsb-voltaic-blaze',470057),
   spell('enhsb-crash-lightning',187874),
   spell('enhsb-bolt',188196,mw(5)),
   spell('enhsb-flame-shock',470411),
  },
 },
}))
