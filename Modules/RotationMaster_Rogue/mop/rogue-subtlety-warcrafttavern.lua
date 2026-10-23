-- Mists of Pandaria Classic Subtlety Rogue with Subterfuge (Warcraft Tavern): selected instead of the recommended
-- Subtlety premade when the tier-1 talent is Subterfuge (grid TALENT 2), which RM can read. Premeditation and Slice and
-- Dice before the pull; in Stealth, Shadow Dance or the Subterfuge linger: finishers at five points, then Ambush as
-- often as it lands. Two or three engaged enemies keep Rupture up and spend five points on Crimson Tempest instead of
-- Eviscerate; four or more add Fan of Knives. One target: Slice and Dice, Rupture, Eviscerate, Hemorrhage for its
-- bleed, Backstab with a dagger when the target is not on you, else Hemorrhage. Shadow Dance and Vanish are reminders with Slice and
-- Dice up and 60 energy (Tavern times them to trinket procs, which RM cannot generalise). Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function points(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function energy(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function buffRemain(id,op,n)return{type='BUFF_REMAIN',unit='player',spell=id,ownbuff=true,operator=op,value=n}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local sliced=own(5171)
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local hidden={type='STEALTHED'}
local worth=any(boss,lifetime('GREATERTHAN',8))
local ruptureDue=any(negate(mine(1943)),remain(1943,'LESSTHANOREQUALS',2))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.rogue.subtlety.warcrafttavern',revision=3,
 blocks={['mop.rogue.boundaries']=1,['mop.rogue.out-of-combat']=2,['mop.rogue.solo']=2,['mop.rogue.upkeep']=1,['mop.rogue.subtlety-builders']=2},
 nameKey='Default.MoP.Rogue.Subtlety.WarcraftTavern.Name',descriptionKey='Default.MoP.Rogue.Subtlety.WarcraftTavern.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='ROGUE',minLevel=15,maxLevel=90},
 tags={'subtlety','dps','melee','leveling','endgame','subterfuge','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-subtlety-rogue-dps-rotations-cooldowns/',title='Warcraft Tavern: Subtlety Rogue rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-subtlety-rogue-dps-talents-builds-glyphs/',title='Warcraft Tavern: Subtlety Rogue talents (MoP Classic)',reviewedAt='2026-10-23'}},
 body={priority=35,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=261},{type='TALENT',layout='grid',value=2}}},
 cooldowns={block('mop.rogue.upkeep','rogue-'),
  spell('rogue-subtlety-wt-shadow-dance',51713,all(combat(),negate(hidden),sliced,energy('GREATERTHANOREQUALS',60))),
  spell('rogue-subtlety-wt-vanish',1856,all(combat(),negate(hidden),negate(own(51713)),negate(own(115192)),sliced,energy('GREATERTHANOREQUALS',60))),
  spell('rogue-subtlety-wt-preparation',14185,all(combat(),negate(hidden),{type='SPELL_COOLDOWN',spell=1856,operator='GREATERTHAN',value=60})),
  spell('rogue-subtlety-wt-shadow-blades',121471,all(combat(),sliced,negate(own(51713)),negate(hidden))),
 },
 rotation={
 block('mop.rogue.boundaries','rogue-'),
 {id='rogue-subtlety-wt-window',type='branch',conditions=any(hidden,own(51713),own(115192)),onFalse={},onTrue={
  spell('rogue-subtlety-wt-premeditation',14183,points('LESSTHANOREQUALS',3)),
  spell('rogue-subtlety-wt-prepull-slice',5171,all(negate(combat()),points('GREATERTHANOREQUALS',1),negate(sliced))),
  {id='rogue-subtlety-wt-window-finisher',type='branch',conditions=all(combat(),points('GREATERTHANOREQUALS',5)),onFalse={},onTrue={
   spell('rogue-subtlety-wt-window-slice',5171,any(negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2))),
   spell('rogue-subtlety-wt-window-rupture',1943,ruptureDue),
   spell('rogue-subtlety-wt-window-eviscerate',2098),
  }},
  spell('rogue-subtlety-wt-ambush',8676),
  {id='rogue-subtlety-wt-window-stop',type='none',suppress_attack=true,conditions={}},
 }},
 block('mop.rogue.out-of-combat','rogue-'),
 {id='rogue-subtlety-wt-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('rogue-subtlety-wt-aoe-slice',5171,all(points('GREATERTHANOREQUALS',1),any(negate(sliced),buffRemain(5171,'LESSTHANOREQUALS',2)))),
  spell('rogue-subtlety-wt-aoe-rupture',1943,all(points('GREATERTHANOREQUALS',5),negate(mine(1943)),worth)),
  spell('rogue-subtlety-wt-crimson-tempest',121411,points('GREATERTHANOREQUALS',5)),
  spell('rogue-subtlety-wt-fan',51723,enemies('GREATERTHANOREQUALS',4)),
  {id='rogue-subtlety-wt-aoe-stop',type='none',suppress_attack=false,conditions=enemies('GREATERTHANOREQUALS',4)},
 }},
 spell('rogue-subtlety-wt-slice',5171,all(points('GREATERTHANOREQUALS',1),negate(sliced))),
 block('mop.rogue.solo','rogue-'),
 {id='rogue-subtlety-wt-finisher',type='branch',conditions=points('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('rogue-subtlety-wt-finisher-slice',5171,buffRemain(5171,'LESSTHANOREQUALS',2)),
  spell('rogue-subtlety-wt-rupture',1943,all(ruptureDue,worth)),
  spell('rogue-subtlety-wt-eviscerate',2098),
  {id='rogue-subtlety-wt-pool',type='none',suppress_attack=false,conditions={}},
 }},
 spell('rogue-subtlety-wt-dying',2098,all(points('GREATERTHANOREQUALS',2),lifetime('LESSTHAN',4))),
 block('mop.rogue.subtlety-builders','rogue-'),
 spell('rogue-subtlety-wt-shuriken-toss',114014,{type='BEYOND_MELEE',unit='target'}),
 }},
}))
