-- TBC Hunter ranged DPS, levels 1–70, wowsims/rotationtools shot timing (the recommended variant).
-- One premade for every spec: spec spells (Aimed Shot, Bestial Wrath, Trueshot Aura, Readiness,
-- Silencing Shot) are offered once known. Before Steady Shot: own sting, then mana-gated shots.
-- From Steady Shot: Multi-Shot when ready, Steady Shot straight after an Auto Shot, Arcane Shot
-- when a Steady would clip the next Auto, Serpent Sting only solo or while moving (Icy Veins).
-- Viper below 20% mana in combat, back to Hawk at 50%. The Wowhead variant drops Arcane/Sting/Viper.
-- Shared parts: Defaults/blocks/hunter.lua. Left manual: melee weaving, pet commands and
-- Misdirection, traps, Volley, Feign Death, ammunition and positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.hunter.ranged.wowsims',revision=2,
 blocks={['tbc.hunter.opening']=2,['tbc.hunter.leveling']=1,['tbc.hunter.upkeep']=1},
 nameKey='Default.TBC.Hunter.Ranged.Wowsims.Name',descriptionKey='Default.TBC.Hunter.Ranged.Wowsims.Description',
 applicability={families={'tbc'},actionContext='player',class='HUNTER',minLevel=1,maxLevel=70},
 tags={'dps','ranged','leveling','endgame','wowsims','icy-veins'},
 sources={{url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/hunter/rotation.go',title='wowsims/tbc: Hunter rotation',reviewedAt='2026-10-23',revision='3301fca59306a747e521274c36e073e69acc7b77'},
 {url='https://diziet559.github.io/rotationtools/',title='diziet559 rotationtools: TBC Hunter shot rotations',reviewedAt='2026-10-23',revision='2bd1759b0e0d04bea7b4bb3a4dc356f484423ced'},
 {url='https://www.icy-veins.com/tbc-classic/beast-mastery-hunter-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Beast Mastery Hunter rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/hunter-leveling-guide',title='Icy Veins: Hunter leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('tbc.hunter.upkeep','hunter-'),
  spell('hunter-viper',34074,all({type='COMBAT',unit='player'},mana('LESSTHAN',.2),negate(buff(34074)))),
  spell('hunter-hawk',13165,all(negate(buff(13165)),any(negate(buff(34074)),mana('GREATERTHANOREQUALS',.5)),
   any({type='COMBAT',unit='player'},all(negate(buff(5118)),negate(buff(13159)),negate(buff(20043)),negate(buff(13161))))))},
 rotation={
 block('tbc.hunter.opening','hunter-'),
 {id='hunter-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('hunter-moving-multi-shot',2643),
  spell('hunter-moving-arcane-shot',3044),
  spell('hunter-moving-serpent-sting',1978,stingless),
  {id='hunter-moving-stop',type='none',suppress_attack=true,conditions={}},
 }},
 {id='hunter-steady',type='branch',conditions={type='SPELL_KNOWN',spell=34120},onTrue={
  spell('hunter-multi-shot',2643),
  spell('hunter-steady-shot',34120,{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=.5}),
  spell('hunter-arcane-shot',3044,any(mana('GREATERTHAN',.5),negate({type='SPELL_KNOWN',spell=34074}))),
  spell('hunter-serpent-sting',1978,all(negate({type='GROUP'}),stingless,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3})),
  {id='hunter-wait-auto',type='none',suppress_attack=true,conditions={}},
 },onFalse={block('tbc.hunter.leveling','hunter-leveling-')}},
 }},
}))
