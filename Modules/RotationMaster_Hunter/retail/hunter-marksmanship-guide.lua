-- Retail (Midnight 12.x) Marksmanship Hunter after SimulationCraft and Icy Veins (optimal
-- reference): Explosive Shot, Volley and Trueshot on cooldown, Precise Shots spent before the next
-- Aimed Shot, Aimed Shot in Trueshot or before it caps. Dark Ranger: Black Arrow on Precise Shots and
-- Wailing Arrow; Sentinel: Moonlight Chakram before its window ends. Three or more enemies with Trick
-- Shots: Multi-Shot to apply it, then Rapid Fire and Aimed Shot while it lasts. Disabled: procs,
-- charges and Focus are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local AIMED,RAPID,TRUESHOT,EXPLOSIVE,VOLLEY,KILLSHOT,MULTI,ARCANE,STEADY,BLACK,WAILING,CHAKRAM=19434,257044,288613,212431,260243,53351,257620,185358,56641,466930,392060,1264949
local precise=buff(260242)
local trueshot=buff(TRUESHOT)
local trick=buff(257622)
local aimedCap={type='SPELL_CHARGES',spell=AIMED,operator='GREATERTHANOREQUALS',value=2}
local hydra=all(precise,engaged(2),known(470945))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.marksmanship.guide',revision=1,
 blocks={['retail.hunter.boundaries']=1,['retail.hunter.utility']=1,['retail.hunter.mark']=1},
 nameKey='Default.Retail.Hunter.MarksmanshipGuide.Name',descriptionKey='Default.Retail.Hunter.MarksmanshipGuide.Description',
 applicability={families={'retail'},actionContext='player',class='HUNTER',specs={254},minLevel=10,maxLevel=90},
 tags={'marksmanship','ranged','reference','simulationcraft','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/hunter_marksmanship.simc',title='SimulationCraft default action list: Marksmanship',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/marksmanship-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Marksmanship Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-14'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={block('mmguide-utility','retail.hunter.utility','mmguide-')},
  rotation={
   block('mmguide-boundaries','retail.hunter.boundaries','mmguide-'),
   spell('mmguide-call-pet',883,all(known(1223323),negate({type='PET'}))),
   {id='mmguide-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
    block('mmguide-pull-mark','retail.hunter.mark','mmguide-pull-'),spell('mmguide-pull-aimed',AIMED),stop('mmguide-pull-stop')}},
   {id='mmguide-aoe',type='branch',conditions=all(known(257621),engaged(3)),onFalse={},onTrue={
    spell('mmguide-aoe-explosive',EXPLOSIVE),spell('mmguide-aoe-volley',VOLLEY),
    spell('mmguide-aoe-black-arrow',BLACK,precise),
    spell('mmguide-aoe-trick',MULTI,negate(trick)),
    spell('mmguide-aoe-trueshot',TRUESHOT),
    spell('mmguide-aoe-rapid',RAPID,trick),spell('mmguide-aoe-aimed',AIMED,trick),
    spell('mmguide-aoe-multi',MULTI,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=70}),
    spell('mmguide-aoe-steady',STEADY),stop('mmguide-aoe-stop')}},
   {id='mmguide-dark-ranger',type='branch',conditions=known(BLACK),
    onTrue={
     spell('mmguide-dr-black-arrow',BLACK,precise),
     spell('mmguide-dr-explosive',EXPLOSIVE,negate(buff(194594))),
     spell('mmguide-dr-volley',VOLLEY),
     spell('mmguide-dr-aimed-window',AIMED,any(all(trueshot,negate(precise),{type='SPELL_AVAIL',spell=BLACK}),aimedCap)),
     spell('mmguide-dr-trueshot',TRUESHOT),
     spell('mmguide-dr-rapid',RAPID),
     spell('mmguide-dr-wailing',WAILING),
     spell('mmguide-dr-multi',MULTI,hydra),
     spell('mmguide-dr-arcane',ARCANE,precise),
     spell('mmguide-dr-aimed',AIMED),
     spell('mmguide-dr-black-arrow-filler',BLACK),
     spell('mmguide-dr-steady',STEADY)},
    onFalse={
     spell('mmguide-sen-explosive',EXPLOSIVE),
     spell('mmguide-sen-volley',VOLLEY),
     spell('mmguide-sen-trueshot',TRUESHOT),
     spell('mmguide-sen-chakram-ending',CHAKRAM,{type='BUFF_REMAIN',unit='player',spell=1264946,ownbuff=true,operator='LESSTHAN',value=5}),
     spell('mmguide-sen-aimed-window',AIMED,all(trueshot,negate(precise))),
     spell('mmguide-sen-rapid',RAPID,any(negate(precise),trueshot)),
     spell('mmguide-sen-kill-shot',KILLSHOT,precise),
     spell('mmguide-sen-multi',MULTI,hydra),
     spell('mmguide-sen-arcane',ARCANE,precise),
     spell('mmguide-sen-aimed',AIMED),
     spell('mmguide-sen-chakram',CHAKRAM),
     spell('mmguide-sen-steady',STEADY)}},
  },
 },
}))
