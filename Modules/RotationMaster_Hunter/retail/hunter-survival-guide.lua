-- Retail (Midnight 12.x) Survival Hunter after SimulationCraft (reference; Icy Veins' openers
-- agree): Kill Command builds Tip of the Spear, which Takedown, Boomstick, Wildfire Bomb and Raptor
-- Strike spend. Pack Leader: Kill Command on Howl of the Pack Leader; Sentinel: Wildfire Bomb on
-- Sentinel's Mark and Moonlight Chakram. Three or more enemies: Boomstick and Wildfire Bomb first,
-- Raptor Swipe. Disabled: Tip of the Spear, charges and Focus are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local KILL,BOMB,TAKEDOWN,BOOM,RAPTOR,SWIPE,CHAKRAM=259489,259495,1250646,1261193,186270,1262293,1264949
local tip=buff(260286)
local howl=any(buff(471878),buff(472324),buff(472325))
-- Kill Command just before a ready Takedown, without Twin Fangs and with no Tip of the Spear.
local beforeTakedown=all(negate(known(1272139)),negate(tip),{type='SPELL_AVAIL',spell=TAKEDOWN})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.hunter.survival.guide',revision=3,
 blocks={['retail.hunter.boundaries']=1,['retail.hunter.utility']=2,['retail.hunter.mark']=1},
 nameKey='Default.Retail.Hunter.SurvivalGuide.Name',descriptionKey='Default.Retail.Hunter.SurvivalGuide.Description',
 applicability={families={'retail'},actionContext='player',class='HUNTER',specs={255},minLevel=10,maxLevel=90},
 tags={'survival','melee','pet','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/hunter_survival.simc',title='SimulationCraft default action list: Survival',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/survival-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Survival Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Openers only; they match SimulationCraft.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('svguide-utility','retail.hunter.utility','svguide-'),
   spell('svguide-aspect-of-the-eagle',186289,all(combat(),{type='BEYOND_MELEE',unit='target'})),
  },
  rotation={
   block('svguide-boundaries','retail.hunter.boundaries','svguide-'),
   spell('svguide-call-pet',883,negate({type='PET'})),
   {id='svguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    block('svguide-pull-mark','retail.hunter.mark','svguide-pull-'),spell('svguide-pull-bomb',BOMB),stop('svguide-pull-stop')}},
   {id='svguide-cleave',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('svguide-cleave-kill',KILL,negate(tip)),
    spell('svguide-cleave-boomstick',BOOM),
    spell('svguide-cleave-bomb',BOMB),
    spell('svguide-cleave-takedown',TAKEDOWN),
    spell('svguide-cleave-swipe',SWIPE),
    spell('svguide-cleave-raptor',RAPTOR),
    spell('svguide-cleave-kill-filler',KILL),
    stop('svguide-cleave-stop')}},
   {id='svguide-pack-leader',type='branch',conditions=known(471876),
    onTrue={
     spell('svguide-pl-howl',KILL,all(howl,any(negate(tip),{type='BUFF_STACKS',unit='player',spell=260286,ownbuff=true,operator='LESSTHAN',value=2}))),
     spell('svguide-pl-before-takedown',KILL,beforeTakedown),
     spell('svguide-pl-takedown',TAKEDOWN,any(tip,known(1272139))),
     spell('svguide-pl-bomb',BOMB,tip),
     spell('svguide-pl-boomstick',BOOM,tip),
     spell('svguide-pl-raptor',RAPTOR,any(tip,negate(known(1259003)))),
     spell('svguide-pl-kill',KILL),
     spell('svguide-pl-takedown-filler',TAKEDOWN)},
    onFalse={
     spell('svguide-sen-kill',KILL,negate(tip)),
     spell('svguide-sen-boomstick',BOOM),
     spell('svguide-sen-bomb',BOMB,any(buff(1253601),buff(1266960),{type='SPELL_CHARGES',spell=BOMB,operator='GREATERTHANOREQUALS',value=2})),
     spell('svguide-sen-before-takedown',KILL,beforeTakedown),
     spell('svguide-sen-takedown',TAKEDOWN),
     spell('svguide-sen-chakram',CHAKRAM),
     spell('svguide-sen-raptor',RAPTOR),
     spell('svguide-sen-kill-filler',KILL),
     spell('svguide-sen-bomb-filler',BOMB),
     spell('svguide-sen-takedown-filler',TAKEDOWN)}},
  },
 },
}))
