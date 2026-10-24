-- Retail (Midnight 12.x) Vengeance Demon Hunter after SimulationCraft (reference). Aldrachi Reaver:
-- Sigil of Flame and Immolation Aura first, Metamorphosis, the Reaver's Glaive cycle, Fiery Brand,
-- Sigil of Spite, Spirit Bomb on packs, Soul Carver in Fiery Demise, then Fracture, Soul Cleave,
-- Felblade, Fel Devastation. Annihilator: spend a ready Voidfall with Spirit Bomb or Soul Cleave,
-- build it with Fracture. RM cannot count Soul Fragments, so fragment targets become enemy counts;
-- Fury is secret on Retail, so its Fury thresholds are left out. Disabled: secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local demise={type='DEBUFF',unit='target',spell=212818,owndebuff=true}
local charged={type='SPELL_CHARGES',spell=263642,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.vengeance.simc',revision=3,
 blocks={['retail.demonhunter.boundaries']=2,['retail.demonhunter.utility']=2},
 nameKey='Default.Retail.DemonHunter.VengeanceSimc.Name',descriptionKey='Default.Retail.DemonHunter.VengeanceSimc.Description',
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'vengeance','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_vengeance.simc',title='SimulationCraft default action list: Vengeance',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=581},
  cooldowns={
   block('vsimc-utility','retail.demonhunter.utility','vsimc-'),
   spell('vsimc-demon-spikes',203720,all(combat(),negate(buff(203819)))),
  },
  rotation={
   block('vsimc-boundaries','retail.demonhunter.boundaries','vsimc-'),
   {id='vsimc-aldrachi',type='branch',conditions=known(442294),
    onTrue={
     spell('vsimc-sigil-of-flame',204596),
     spell('vsimc-immolation-aura',258920),
     spell('vsimc-metamorphosis',187827,any(buff(1270476),negate(buff(187827)))),
     spell('vsimc-reavers-glaive',204157,any(buff(444686),buff(444764))),
     spell('vsimc-rending-fracture',263642,buff(442442)),
     spell('vsimc-flurry-soul-cleave',228477,buff(442435)),
     spell('vsimc-glaive-felblade',232893,any(buff(442442),buff(442435))),
     spell('vsimc-fiery-brand',204021,any({type='SPELL_CHARGES',spell=204021,operator='GREATERTHANOREQUALS',value=2},negate(demise))),
     spell('vsimc-sigil-of-spite',390163),
     spell('vsimc-spirit-bomb',247454,engaged(3)),
     spell('vsimc-soul-carver',207407,demise),
     spell('vsimc-fracture',263642),
     spell('vsimc-soul-cleave',228477),
     spell('vsimc-felblade',232893),
     spell('vsimc-fel-devastation',212084)},
    onFalse={
     {id='vsimc-voidfall',type='branch',conditions=buff(1256302),onFalse={},onTrue={
      spell('vsimc-voidfall-spirit-bomb',247454,engaged(3)),
      spell('vsimc-voidfall-soul-cleave',228477)}},
     spell('vsimc-build-fracture',263642,{type='BUFF_STACKS',unit='player',spell=1256301,ownbuff=true,operator='GREATERTHANOREQUALS',value=2}),
     spell('vsimc-metamorphosis-entry',187827,negate(buff(187827))),
     spell('vsimc-ann-spirit-bomb',247454,engaged(3)),
     spell('vsimc-ann-sigil-of-spite',390163),
     spell('vsimc-capped-fracture',263642,charged),
     spell('vsimc-ann-immolation-aura',258920),
     spell('vsimc-ann-sigil-of-flame',204596),
     spell('vsimc-ann-fracture',263642),
     spell('vsimc-ann-soul-cleave',228477),
     spell('vsimc-ann-felblade',232893),
     spell('vsimc-ann-throw-glaive',204157)}},
  },
 },
}))
