-- Retail (Midnight) Enhancement Shaman, Totemic (SimulationCraft's single_totemic list, Icy Veins
-- and Wowhead notes): the optimal reference, disabled by default because Flame Shock, Hot Hand,
-- Whirling Fire, Crash Lightning and Doom Winds are hidden in Midnight combat. Three or more
-- engaged enemies: Crash Lightning, Chain Lightning at 5+ Maelstrom Weapon. Then: Voltaic Blaze or
-- Flame Shock when Flame Shock is missing, Surging Totem, Sundering, Lava Lash with Hot Hand or
-- Whirling Fire, Crash Lightning to keep its buff, Primordial Storm at 10, Windstrike, Crash
-- Lightning and Stormstrike in Doom Winds, Lightning Bolt at 5+ (resets Lava Lash), Crash
-- Lightning, Lava Lash, Sundering, Stormstrike, Voltaic Blaze, Flame Shock. Reminders: Doom Winds,
-- Ascendance, Feral Spirit.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function mw(n)return{type='BUFF_STACKS',unit='player',spell=344179,ownbuff=true,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local shocked={type='DEBUFF',unit='target',spell=188389,owndebuff=true}
local winds=own(466772)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.enhancement.totemic',revision=6,
 blocks={['retail.shaman.boundaries']=2,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 nameKey='Default.Retail.Shaman.Enhancement.Totemic.Name',descriptionKey='Default.Retail.Shaman.Enhancement.Totemic.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'enhancement','melee','reference','totemic','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/shaman_enhancement.simc',title='SimulationCraft: Enhancement Shaman default list (single_totemic)',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.icy-veins.com/wow/enhancement-shaman-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Enhancement Shaman rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/shaman/enhancement/rotation-cooldowns-pve-dps',title='Wowhead: Enhancement Shaman rotation',reviewedAt='2026-10-23',revision='2026-08-12'},
 },
 body={priority=4,disabled=true,specs={263},
  cooldowns={
   block('retail.shaman.upkeep','enhtot-'),
   block('retail.shaman.lightning-shield','enhtot-'),
   spell('enhtot-doom-winds',384352,fight),
   spell('enhtot-ascendance',114051,all(fight,negate(winds))),
   spell('enhtot-feral-spirit',51533,fight),
  },
  rotation={
   block('retail.shaman.boundaries','enhtot-'),
   {id='enhtot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('enhtot-aoe-crash-lightning',187874),
    spell('enhtot-aoe-chain-lightning',188443,mw(5)),
   }},
   spell('enhtot-voltaic-opener',470057,negate(shocked)),
   spell('enhtot-flame-shock-missing',470411,negate(shocked)),
   spell('enhtot-surging-totem',444995),
   spell('enhtot-sundering',197214),
   spell('enhtot-hot-hand',60103,any(own(215785),own(453405))),
   spell('enhtot-crash-buff',187874,negate(own(187878))),
   spell('enhtot-primordial-storm',1218090,mw(10)),
   spell('enhtot-windstrike',115356),
   spell('enhtot-winds-crash',187874,winds),
   spell('enhtot-winds-stormstrike',17364,winds),
   spell('enhtot-bolt',188196,mw(5)),
   spell('enhtot-crash-lightning',187874),
   spell('enhtot-lava-lash',60103),
   spell('enhtot-stormstrike',17364),
   spell('enhtot-voltaic-blaze',470057),
   spell('enhtot-flame-shock',470411),
  },
 },
}))
