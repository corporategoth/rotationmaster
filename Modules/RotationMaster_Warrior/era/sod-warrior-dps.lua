-- Season of Discovery Warrior melee DPS, levels 1–60: two-hander, dual wield, Gladiator and
-- leveling (the SoD catch-all outside Defensive Stance). wowsims/sod Phase 6 with Wowhead Phase
-- 7/8: Charge; Victory Rush; Intercept; Whirlwind (Thunder Clap before it) on two engaged enemies;
-- Slam at three Slammin' stacks (Phase 8 four-piece); Rend kept up; Slam on Blood Surge (on
-- cooldown with the Precise Timing rune);
-- Bloodthirst; Mortal Strike; Shield Slam; Overpower; then by build: Quick Strike for two-handers
-- (the engraved glove rune), or Whirlwind, Raging Blow and Devastate (Sunder before it) for dual
-- wield; Execute with 30 rage or Sudden Death; Hamstring near the rage cap. Reminders: Battle and
-- Commanding Shout, Heroic Strike from 50 rage (always while Consumed by Rage enrages you), Cleave,
-- Bloodrage, Rampage, Death Wish, Recklessness, Sweeping Strikes, interrupts. Shared parts:
-- era/blocks.lua. Left manual: stance dancing; Berserker Rage and the Taste for Blood Battle
-- Stance dip are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return all(known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local big=any(boss,{type='CLASSIFICATION',unit='target',value='elite'})
local strike=any(known(12294),known(23881))
local unqueued=all(negate(queued(78)),negate(queued(845)))
local immune=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='MECHANICAL'},{type='CREATURE',unit='target',value='ELEMENTAL'})
local enraged=any(buff(12880),buff(425415),buff(427066),buff(29131),buff(18499))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.dps',revision=2,
 blocks={['era.warrior.boundaries']=1,['era.warrior.upkeep']=1,['era.warrior.aoe-strikes']=1},
 nameKey='Default.SoD.Warrior.DPS.Name',descriptionKey='Default.SoD.Warrior.DPS.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'dps','melee','leveling','endgame','aoe','season-of-discovery','wowsims','wowhead'},
 sources={{url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/warrior/apls',title='wowsims/sod: Warrior APLs (Phase 1-6, two-hander and dual wield)',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Warrior DPS rotation (Phase 7/8)',reviewedAt='2026-10-23',revision='2025-04-12'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-talent-builds-runes',title='Wowhead: SoD Warrior DPS talents and runes (Phase 8)',reviewedAt='2026-10-23',revision='2025-04-08'}},
 body={priority=50,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warrior.upkeep','sod-dps-'),
  spell('sod-dps-commanding-shout',403215,negate(buff(403215))),
  spell('sod-dps-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),any(rage('GREATERTHANOREQUALS',50),all(strike,buff(425415))))),
  spell('sod-dps-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',50))),
  spell('sod-dps-bloodrage',2687,all(combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4})),
  spell('sod-dps-rampage',426940,all(combat(),big)),
  spell('sod-dps-death-wish',12328,combat()),
  spell('sod-dps-recklessness',1719,all(combat(),boss,any(buff(12328),lifetime('LESSTHANOREQUALS',25)))),
  spell('sod-dps-sweeping-strikes',12292,all(combat(),enemies('GREATERTHANOREQUALS',2))),
  optional(spell('sod-dps-berserker-rage',18499,all(combat(),any(rune(402911),rune(426940)),negate(enraged)))),
  optional(spell('sod-dps-battle-stance-dip',2457,all(combat(),buff(426969),negate({type='FORM',value=1}),rage('LESSTHANOREQUALS',25)))),
 },
 rotation={
 block('era.warrior.boundaries','sod-dps-'),
 spell('sod-dps-victory-rush',402927),
 spell('sod-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 {id='sod-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={block('era.warrior.aoe-strikes','sod-dps-')}},
 spell('sod-dps-slammin',1464,{type='BUFF_STACKS',unit='player',spell=1234005,operator='GREATERTHANOREQUALS',value=3}),
 spell('sod-dps-rend',772,all(negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}),any(big,target('GREATERTHAN',.3)),negate(immune))),
 spell('sod-dps-blood-surge-slam',1464,any(buff(413399),rune(402922))),
 spell('sod-dps-bloodthirst',23881),
 spell('sod-dps-mortal-strike',12294),
 spell('sod-dps-shield-slam',23922),
 spell('sod-dps-overpower',7384),
 {id='sod-dps-two-hand',type='branch',conditions=rune(429765),onTrue={
  spell('sod-dps-quick-strike',429765,any(rage('GREATERTHANOREQUALS',30),cooling(23881,1.5),cooling(12294,1.5))),
 },onFalse={
  spell('sod-dps-whirlwind',1680),
  spell('sod-dps-raging-blow',402911),
  spell('sod-dps-devastate',403196),
  spell('sod-dps-sunder',7386,all(negate(rune(403195)),target('GREATERTHANOREQUALS',.6),any(negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),
   {type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='LESSTHAN',value=5}))),
 }},
 spell('sod-dps-execute',5308,any(buff(440114),all(target('LESSTHAN',.2),rage('GREATERTHANOREQUALS',30)))),
 spell('sod-dps-hamstring',1715,all(rage('GREATERTHANOREQUALS',80),any(negate(known(23881)),cooling(23881,0)),any(negate(known(1680)),cooling(1680,0)))),
 }},
}))
