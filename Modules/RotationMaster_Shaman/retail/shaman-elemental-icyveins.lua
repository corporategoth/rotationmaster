-- Retail (Midnight) Elemental Shaman, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Flame Shock, Master of the Elements and Stormkeeper are
-- hidden in Midnight combat. Before the pull Stormkeeper and Lava Burst. Three or
-- more engaged enemies: Stormkeeper, Ancestral Swiftness, Flame Shock, Chain Lightning with
-- Stormkeeper, Elemental Blast, Earthquake, Lava Burst on Lava Surge, Tempest, Chain Lightning.
-- One or two: Stormkeeper, Ancestral Swiftness, Flame Shock and Voltaic Blaze in their last 30%
-- outside Master of the Elements, Lava Burst to start it, Tempest and Stormkeeper's Lightning Bolt
-- inside it, Elemental Blast or Earth Shock inside it, Voltaic Blaze, Tempest; moving Flame Shock
-- and Frost Shock; Elemental Blast or Earth Shock whenever affordable; Lightning Bolt. Maelstrom is
-- secret on Retail, so the spenders go at their cost instead of near full Maelstrom.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local motE=own(260734)
local shocked={type='DEBUFF',unit='target',spell=188389,owndebuff=true}
local refresh=any(negate(shocked),{type='DEBUFF_REMAIN',unit='target',spell=188389,owndebuff=true,operator='LESSTHAN',value=5.4})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.elemental.icyveins',revision=4,
 blocks={['retail.shaman.boundaries']=1,['retail.shaman.upkeep']=2,['retail.shaman.lightning-shield']=1},
 nameKey='Default.Retail.Shaman.Elemental.IcyVeins.Name',descriptionKey='Default.Retail.Shaman.Elemental.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'elemental','ranged','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/elemental-shaman-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Elemental Shaman rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/shaman_elemental.simc',title='SimulationCraft: Elemental Shaman default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=262},
  cooldowns={
   block('retail.shaman.upkeep','eleiv-'),
   block('retail.shaman.lightning-shield','eleiv-'),
   spell('eleiv-ascendance',114050,all(fight,negate({type='SPELL_AVAIL',spell=191634}))),
   spell('eleiv-fire-elemental',198067,fight),
   spell('eleiv-storm-elemental',192249,fight),
   spell('eleiv-spiritwalkers-grace',79206,all(fight,{type='MOVING'})),
  },
  rotation={
   block('retail.shaman.boundaries','eleiv-'),
   {id='eleiv-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('eleiv-pull-stormkeeper',191634),
    spell('eleiv-pull-lava-burst',51505),
    {id='eleiv-pull-stop',type='none',suppress_attack=true,conditions={}},
   }},
   {id='eleiv-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('eleiv-aoe-stormkeeper',191634),
    spell('eleiv-aoe-ancestral-swiftness',443454),
    spell('eleiv-aoe-flame-shock',470411,all(negate(shocked),negate(motE))),
    spell('eleiv-aoe-stormkeeper-chain',188443,own(191634)),
    spell('eleiv-aoe-elemental-blast',117014),
    spell('eleiv-aoe-earthquake',61882),
    spell('eleiv-aoe-earthquake-targeted',462620),
    spell('eleiv-aoe-lava-surge',51505,own(77762)),
    spell('eleiv-aoe-tempest',452201),
    spell('eleiv-aoe-chain-lightning',188443),
   }},
   spell('eleiv-stormkeeper',191634),
   spell('eleiv-ancestral-swiftness',443454),
   spell('eleiv-flame-shock',470411,all(refresh,negate(motE))),
   spell('eleiv-voltaic-blaze-refresh',470057,all(refresh,negate(motE))),
   spell('eleiv-lava-burst',51505,all(negate(motE),any(own(77762),{type='SPELL_CHARGES',spell=51505,operator='GREATERTHANOREQUALS',value=2}))),
   spell('eleiv-tempest-mote',452201,motE),
   spell('eleiv-stormkeeper-bolt',188196,all(own(191634),motE)),
   spell('eleiv-elemental-blast',117014,motE),
   spell('eleiv-earth-shock',8042,motE),
   spell('eleiv-voltaic-blaze',470057),
   spell('eleiv-tempest',452201),
   {id='eleiv-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('eleiv-moving-flame-shock',470411),
    spell('eleiv-moving-frost-shock',196840),
   }},
   spell('eleiv-elemental-blast-spend',117014),
   spell('eleiv-earth-shock-spend',8042),
   spell('eleiv-lightning-bolt',188196),
  },
 },
}))
