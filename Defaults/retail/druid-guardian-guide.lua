-- Retail (Midnight 12.x) Guardian Druid after Icy Veins and Wowhead (optimal reference): Thrash and
-- Mangle on cooldown, Red Moon on a single target or Moonfire when missing, Moonfire on Galactic
-- Guardian, Maul or Raze above 80 rage, Swipe. Ironfur at 40 rage and the defensives are reminders.
-- Disabled: rage, debuffs, procs and health are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function rage(v)return{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=v}end
local function health(v)return all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=v})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.guardian.guide',revision=1,
 blocks={['retail.druid.boundaries']=1,['retail.druid.utility']=1},
 nameKey='Default.Retail.Druid.GuardianGuide.Name',descriptionKey='Default.Retail.Druid.GuardianGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID',specs={104},minLevel=10,maxLevel=90},
 tags={'guardian','tank','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/guardian-druid-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Guardian Druid rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/druid/guardian/rotation-cooldowns-pve-tank',title='Wowhead: Guardian Druid rotation (Midnight Season 1)',reviewedAt='2026-10-23',revision='2026-03-07',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('gguide-utility','retail.druid.utility','gguide-'),
   spell('gguide-bear-form',5487,all(negate(combat()),negate(buff(5487)),negate(buff(102558)))),
   spell('gguide-skull-bash',106839,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   spell('gguide-ironfur',192081,all(combat(),rage(40))),
   spell('gguide-frenzied-regeneration',22842,health(.5)),
   spell('gguide-survival-instincts',61336,health(.35)),
   spell('gguide-berserk',50334,combat()),
   spell('gguide-incarnation',102558,combat()),
   spell('gguide-lunar-beam',204066,combat()),
   spell('gguide-convoke',391528,combat()),
   spell('gguide-heart-of-the-wild',1261867,combat()),
  },
  rotation={
   block('gguide-boundaries','retail.druid.boundaries','gguide-'),
   spell('gguide-thrash',77758),
   spell('gguide-mangle',33917),
   spell('gguide-red-moon',1252871,negate({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
   spell('gguide-moonfire',8921,negate({type='DEBUFF',unit='target',spell=164812,owndebuff=true})),
   spell('gguide-galactic-moonfire',8921,buff(213708)),
   spell('gguide-raze',400254,rage(80)),
   spell('gguide-maul',6807,rage(80)),
   spell('gguide-swipe',213771),
  },
 },
}))
