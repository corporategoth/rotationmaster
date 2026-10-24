-- Classic Era Hunter ranged DPS after Icy Veins' "clipped" rotation (for ranged weapons faster than
-- 3.0 s), levels 1–60. Off by default: Rotation Master cannot read weapon speed. Same switch as
-- rm.era.hunter.ranged; differs in a group by casting Aimed Shot and Multi-Shot as soon as they are
-- ready (no Auto Shot window) and never Serpent Sting, and by spending Rapid Fire, Bestial Wrath and
-- racials on every pull.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.hunter.ranged.icyveins',revision=3,
 blocks={['era.hunter.boundaries']=2,['era.hunter.dead-zone']=2,['era.hunter.opening']=2,['era.hunter.solo']=1,
  ['era.hunter.hawk']=1,['era.hunter.upkeep']=1},
 nameKey='Default.Era.Hunter.Ranged.IcyVeins.Name',descriptionKey='Default.Era.Hunter.Ranged.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','leveling','endgame','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/hunter-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Hunter DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/beast-mastery-hunter-leveling-guide-1-60',title='Icy Veins: Beast Mastery Hunter leveling 1-60',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/marksmanship-hunter-leveling-guide-1-60',title='Icy Veins: Marksmanship Hunter leveling 1-60',reviewedAt='2026-10-23',revision='2024-11-17'},
 },
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.hunter.hawk','hunter-'),block('era.hunter.upkeep','hunter-'),
  spell('hunter-rapid-fire',3045,all(combat(),negate(buff(3045)))),
  spell('hunter-bestial-wrath',19574,all(combat(),{type='PET'})),
  spell('hunter-berserking',20554,all(combat(),buff(3045))),
  spell('hunter-blood-fury',20572,all(combat(),buff(3045)))},
 rotation={
  block('era.hunter.boundaries','hunter-'),
  block('era.hunter.dead-zone','hunter-'),
  block('era.hunter.opening','hunter-'),
  {id='hunter-solo',type='branch',conditions={type='GROUP'},onFalse={block('era.hunter.solo','hunter-solo-')},onTrue={
   spell('hunter-aimed-shot',19434),
   spell('hunter-multi-shot',2643),
   spell('hunter-arcane-shot',3044,any(negate({type='SPELL_KNOWN',spell=19434}),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3})),
   {id='hunter-wait-auto',type='none',suppress_attack=true,conditions={}},
  }},
 }},
}))
