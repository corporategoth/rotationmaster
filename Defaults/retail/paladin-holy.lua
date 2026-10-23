-- Retail (Midnight) Holy Paladin, Icy Veins (with Wowhead's damage order on an enemy). RM picks a
-- spell, not a target, and every unit's health is hidden in Midnight combat, so this keeps the
-- Holy Power economy going on whatever you target and leaves triage to you. Friendly target:
-- Flash of Light on Infusion of Light, Holy Shock, Word of Glory (Eternal Flame) to spend, Holy
-- Light, Flash of Light. Enemy: Shield of the Righteous, Holy Shock, Judgment, Crusader Strike,
-- Consecration. Reminders: Divine Toll, Holy Prism, Holy Bulwark or Sacred Weapon and Beacon of
-- Virtue on cooldown in combat, aura, Rebuke, Divine Protection, Lay on Hands. The friendly test
-- is guarded by "target level above 0", which is false (not unavailable) without a target.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.holy',revision=1,
 blocks={['retail.paladin.upkeep']=1},
 nameKey='Default.Retail.Paladin.Holy.Name',descriptionKey='Default.Retail.Paladin.Holy.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN',specs={65},minLevel=10,maxLevel=90},
 tags={'holy','healer','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/holy-paladin-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Holy Paladin healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer',title='Wowhead: Holy Paladin rotation',reviewedAt='2026-10-23',revision='2026-08-18',notes='Damage order on an enemy target.'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('retail.paladin.upkeep','holy-'),
   spell('holy-divine-toll',375576,combat()),
   spell('holy-holy-prism',114165,combat()),
   spell('holy-holy-bulwark',432459,combat()),
   spell('holy-sacred-weapon',432472,combat()),
   spell('holy-beacon-of-virtue',200025,all(combat(),{type='FRIENDLY',unit='target'})),
   spell('holy-divine-protection',498,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
  },
  rotation={
   {id='holy-casting',type='none',suppress_attack=false,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='holy-friendly',type='branch',conditions=all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('holy-infusion',19750,own(54149)),
    spell('holy-shock',20473),
    spell('holy-eternal-flame',156322),
    spell('holy-word-of-glory',85673),
    spell('holy-light',82326),
    spell('holy-flash-of-light',19750),
    {id='holy-friendly-stop',type='none',suppress_attack=true,conditions={}},
   }},
   {id='holy-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
   spell('holy-shield-of-the-righteous',415091),
   spell('holy-shock-enemy',20473),
   spell('holy-judgment',275773),
   spell('holy-crusader-strike',35395),
   spell('holy-consecration',26573),
  },
 },
}))
