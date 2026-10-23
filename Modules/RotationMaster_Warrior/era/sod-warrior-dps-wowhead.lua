-- Season of Discovery Warrior melee DPS, Wowhead Phase 7/8 Battle Forecaster stance dance
-- (alternative premade; same catch-all switch, lower priority). Needs Soul of the Battle
-- Forecaster (shoulder) or the Tier 1 six-piece, which Rotation Master cannot see: the stance
-- swaps keep the forecast buffs up (verify the buff logic in game), Heroic Strike almost always,
-- then Bloodthirst, Blood Surge Slam, Whirlwind, Raging Blow and Hamstring; no Rend and no
-- Overpower. Same boundaries and reminders as the recommended SoD premade (era/blocks.lua).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function forecast(id)return any(negate(buff(id)),{type='BUFF_REMAIN',unit='player',spell=id,operator='LESSTHAN',value=3})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local unqueued=all(negate(queued(78)),negate(queued(845)))
local berserker={type='FORM',value=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warrior.dps.wowhead',revision=1,
 blocks={['era.warrior.boundaries']=1,['era.warrior.upkeep']=1},
 nameKey='Default.SoD.Warrior.DPS.Wowhead.Name',descriptionKey='Default.SoD.Warrior.DPS.Wowhead.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'dps','melee','endgame','season-of-discovery','wowhead'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warrior/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Warrior DPS rotation (Battle Forecaster, Phase 7/8)',reviewedAt='2026-10-23',revision='2025-04-12'}},
 body={priority=45,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warrior.upkeep','sod-fc-'),
  spell('sod-fc-berserker-stance',2458,all(combat(),negate(berserker),negate({type='FORM',value=2}),forecast(457816))),
  spell('sod-fc-battle-stance',2457,all(combat(),berserker,forecast(457817))),
  spell('sod-fc-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',20))),
  spell('sod-fc-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',30))),
  spell('sod-fc-bloodrage',2687,all(combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4})),
  spell('sod-fc-death-wish',12328,combat()),
 },
 rotation={
 block('era.warrior.boundaries','sod-fc-'),
 spell('sod-fc-bloodthirst',23881),
 spell('sod-fc-blood-surge-slam',1464,buff(413399)),
 spell('sod-fc-whirlwind',1680),
 spell('sod-fc-raging-blow',402911),
 spell('sod-fc-hamstring',1715,rage('GREATERTHANOREQUALS',60)),
 }},
}))
