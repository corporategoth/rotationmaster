-- Classic Era Hunter ranged DPS after the wowsims/classic P1 list, levels 1–60. Off by default:
-- it keeps Serpent Sting up in raids too, which the 16-debuff limit on standard Era realms usually
-- forbids. Same switch as rm.era.hunter.ranged; in a group: Aimed Shot and Multi-Shot after an Auto
-- Shot, then Serpent Sting under 5 s left while both are cooling, never Arcane Shot.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function afterAuto(window)return{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=window}end
local function cooling(id)return any(negate(known(id)),{type='SPELL_COOLDOWN',spell=id,ranked=false,operator='GREATERTHAN',value=.5})end
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.hunter.ranged.wowsims',revision=3,
 blocks={['era.hunter.boundaries']=2,['era.hunter.dead-zone']=2,['era.hunter.opening']=2,['era.hunter.solo']=1,
  ['era.hunter.hawk']=1,['era.hunter.upkeep']=1,['era.hunter.cooldowns']=1},
 nameKey='Default.Era.Hunter.Ranged.Wowsims.Name',descriptionKey='Default.Era.Hunter.Ranged.Wowsims.Description',
 applicability={families={'era'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','endgame','raid','wowsims'},
 sources={
  {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/hunter/apls/p1.apl.json',title='wowsims/classic: Hunter P1 APL',reviewedAt='2026-10-23',revision='7779ebb'},
  {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/sim/hunter/aimed_shot.go',title='wowsims/classic: Aimed Shot model',reviewedAt='2026-10-23',revision='7779ebb'},
 },
 body={priority=4,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.hunter.hawk','hunter-'),block('era.hunter.upkeep','hunter-'),block('era.hunter.cooldowns','hunter-')},
 rotation={
  block('era.hunter.boundaries','hunter-'),
  block('era.hunter.dead-zone','hunter-'),
  block('era.hunter.opening','hunter-'),
  {id='hunter-solo',type='branch',conditions={type='GROUP'},onFalse={block('era.hunter.solo','hunter-solo-')},onTrue={
   spell('hunter-aimed-shot',19434,afterAuto(.5)),
   spell('hunter-multi-shot',2643,afterAuto(1)),
   spell('hunter-serpent-sting',1978,all(any(stingless,{type='DEBUFF_REMAIN',unit='target',spell=1978,owndebuff=true,operator='LESSTHAN',value=5}),cooling(19434),cooling(2643))),
   {id='hunter-wait-auto',type='none',suppress_attack=true,conditions={}},
  }},
 }},
}))
