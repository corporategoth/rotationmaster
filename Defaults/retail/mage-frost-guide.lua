-- Retail (Midnight 12.x) Frost Mage after SimulationCraft and Icy Veins (optimal reference), one
-- order per hero tree. Frostfire (Frostfire Bolt known): Glacial Spike when ready, Comet Storm on one
-- or two enemies, Flurry on Brain Freeze, Ice Lance on two Fingers of Frost, Ray of Frost, Frozen
-- Orb, Blizzard on packs, Ice Lance on Thermal Void or twelve Freezing, Flurry, Cone of Cold or Ice
-- Nova on five. Spellslinger: Comet Storm first and Ice Lance from six Freezing. Ice Lance on the
-- move; Frostfire Bolt or Frostbolt filler. Disabled: procs, Freezing stacks and cooldowns are secret
-- in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function freezing(v)return{type='DEBUFF_STACKS',unit='target',spell=1221389,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local brainFreeze,fingers,thermal,spike=buff(190446),buff(44544),buff(1247730),buff(199844)
local twoFingers={type='BUFF_STACKS',unit='player',spell=44544,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}
local frozenRain=all(buff(270232),engaged(3))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.frost.guide',revision=1,
 blocks={['retail.mage.boundaries']=1,['retail.mage.utility']=1},
 nameKey='Default.Retail.Mage.FrostGuide.Name',descriptionKey='Default.Retail.Mage.FrostGuide.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE',specs={64},minLevel=10,maxLevel=90},
 tags={'frost','caster','reference','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/frost-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Frost Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_frost.simc',title='SimulationCraft default action list: Frost',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('frguide-utility','retail.mage.utility','frguide-'),
   spell('frguide-barrier',11426,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
   spell('frguide-water-elemental',31687,negate({type='PET'})),
  },
  rotation={
   block('frguide-boundaries','retail.mage.boundaries','frguide-'),
   {id='frguide-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
    spell('frguide-pull-frostfire',431044),spell('frguide-pull-frostbolt',116),stop('frguide-pull-stop')}},
   {id='frguide-frostfire',type='branch',conditions={type='SPELL_KNOWN',spell=431044},
    onTrue={
     spell('frguide-ff-glacial-spike',199786,spike),
     spell('frguide-ff-comet-storm',153595,negate(engaged(3))),
     spell('frguide-ff-brain-freeze',44614,all(brainFreeze,negate(thermal))),
     spell('frguide-ff-two-fingers',30455,twoFingers),
     spell('frguide-ff-ray-of-frost',205021),
     spell('frguide-ff-frozen-orb',84714),
     spell('frguide-ff-blizzard',190356,frozenRain),
     spell('frguide-ff-thermal-void',30455,all(fingers,thermal)),
     spell('frguide-ff-shatter',30455,freezing(12)),
     spell('frguide-ff-flurry',44614),
     spell('frguide-ff-ice-nova',157997,engaged(5)),
     spell('frguide-ff-cone-of-cold',120,engaged(5)),
     spell('frguide-ff-moving-lance',30455,{type='MOVING'}),
     spell('frguide-ff-glacial-spike-filler',199786),
     spell('frguide-ff-frostfire-bolt',431044)},
    onFalse={
     spell('frguide-ss-comet-storm',153595),
     spell('frguide-ss-brain-freeze',44614,all(brainFreeze,negate(thermal))),
     spell('frguide-ss-two-fingers',30455,twoFingers),
     spell('frguide-ss-frozen-orb',84714),
     spell('frguide-ss-glacial-spike',199786,spike),
     spell('frguide-ss-blizzard',190356,frozenRain),
     spell('frguide-ss-fingers',30455,fingers),
     spell('frguide-ss-shatter',30455,freezing(6)),
     spell('frguide-ss-ray-of-frost',205021),
     spell('frguide-ss-flurry',44614),
     spell('frguide-ss-ice-nova',157997,engaged(4)),
     spell('frguide-ss-cone-of-cold',120,engaged(4)),
     spell('frguide-ss-packs-blizzard',190356,engaged(7)),
     spell('frguide-ss-moving-lance',30455,{type='MOVING'}),
     spell('frguide-ss-glacial-spike-filler',199786),
     spell('frguide-ss-frostbolt',116)}},
  },
 },
}))
