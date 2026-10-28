-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Blood Death Knight after SimulationCraft's Deathbringer list (reference):
-- Death and Decay kept up, Death's Caress for Bone Shield while runes are short, runic power spent on
-- Death Strike whenever it is affordable (runic power is secret on Retail, so its cap dump is gone).
-- Disabled: its buffs and debuffs are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local exterminate=any(buff(441416),buff(447954))
local runeWeapon=buff(81256)
local lowBones=any(negate(buff(195181)),{type='BUFF_REMAIN',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=3},
 {type='BUFF_STACKS',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=6})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.blood.simc',revision=7,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.BloodSimc.Name',descriptionKey='Default.Retail.DeathKnight.BloodSimc.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/deathknight_blood.simc',title='SimulationCraft default action list: Blood (Deathbringer)',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={250},
  cooldowns={
   block('bsimc-utility','retail.deathknight.utility','bsimc-'),
   spell('bsimc-raise-dead',46585,combat()),
   spell('bsimc-dancing-rune-weapon',49028,all(combat(),negate(exterminate),negate({type='DEBUFF',unit='target',spell=434765,owndebuff=true}))),
   spell('bsimc-vampiric-blood',55233,all(combat(),negate(buff(55233)))),
  },
  rotation={
   block('bsimc-boundaries','retail.deathknight.boundaries','bsimc-'),
   {id='bsimc-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('bsimc-pull-caress',195292),stop('bsimc-pull-stop')}},
   spell('bsimc-death-and-decay',43265,negate(buff(188290))),
   spell('bsimc-reapers-mark',439843),
   spell('bsimc-exterminate',195182,exterminate),
   {id='bsimc-bones',type='branch',conditions=lowBones,onFalse={},onTrue={
    spell('bsimc-bones-caress',195292,{type='POINT',unit='player',operator='LESSTHAN',value=4}),
    spell('bsimc-marrowrend',195182)}},
   spell('bsimc-death-strike',49998),
   spell('bsimc-blood-boil',50842),
   spell('bsimc-consumption',1263824,negate(runeWeapon)),
   spell('bsimc-heart-strike',206930),
   spell('bsimc-late-consumption',1263824),
  },
 },
}))
