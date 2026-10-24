-- Retail (Midnight 12.x) Blood Death Knight after Icy Veins and Wowhead (optimal reference): Death
-- Strike whenever it is affordable (health and runic power are secret on Retail), Bone Shield upkeep,
-- the San'layn Gift window, Crimson Scourge, Blood Boil, Heart Strike. Disabled: own buffs and target
-- debuffs are secret in Midnight combat, so those steps only run where they can be read.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local exterminate=any(buff(441416),buff(447954))
local lowBones=any(negate(buff(195181)),{type='BUFF_STACKS',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=5},
 {type='BUFF_REMAIN',unit='player',spell=195181,ownbuff=true,operator='LESSTHAN',value=3},exterminate)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.blood.guide',revision=5,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.BloodGuide.Name',descriptionKey='Default.Retail.DeathKnight.BloodGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/blood-death-knight-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Blood Death Knight rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/death-knight/blood/rotation-cooldowns-pve-tank',title='Wowhead: Blood Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-13',notes='Read from a Wayback snapshot; Death Strike at 75 runic power.'},
 },
 body={priority=10,disabled=true,switch={type='SPECIALIZATION',spec=250},
  cooldowns={
   block('bguide-utility','retail.deathknight.utility','bguide-'),
   spell('bguide-raise-dead',46585,combat()),
   spell('bguide-vampiric-blood',55233,all(combat(),negate(buff(55233)))),
   spell('bguide-reapers-mark',439843,combat()),
   spell('bguide-dancing-rune-weapon',49028,all(combat(),any(negate(known(439843)),{type='DEBUFF',unit='target',spell=434765,owndebuff=true}))),
  },
  rotation={
   block('bguide-boundaries','retail.deathknight.boundaries','bguide-'),
   {id='bguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('bguide-pull-caress',195292),stop('bguide-pull-stop')}},
   spell('bguide-death-strike',49998),
   {id='bguide-bones',type='branch',conditions=lowBones,onFalse={},onTrue={spell('bguide-marrowrend',195182),spell('bguide-bones-caress',195292)}},
   {id='bguide-gift',type='branch',conditions=all(known(433895),buff(434153)),onFalse={},onTrue={
    spell('bguide-gift-death-strike',49998),
    spell('bguide-gift-blood-boil',50842,negate({type='SPELL_HISTORY_TIME',spell=50842,operator='LESSTHAN',value=10})),
    spell('bguide-gift-death-and-decay',43265,all(buff(81141),negate(buff(434159)))),
    spell('bguide-gift-heart-strike',206930),
    stop('bguide-gift-stop')}},
   spell('bguide-death-and-decay',43265,any(buff(81141),all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},negate(buff(188290))))),
   spell('bguide-vampiric-strike',433895),
   spell('bguide-consumption',1263824),
   spell('bguide-blood-boil',50842,any(buff(1265968),negate({type='DEBUFF',unit='target',spell=55078,owndebuff=true}),{type='SPELL_CHARGES',spell=50842,operator='GREATERTHANOREQUALS',value=2})),
   spell('bguide-heart-strike',206930),
  },
 },
}))
