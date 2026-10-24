-- Classic Era Warrior melee DPS, levels 1–60, Arms and Fury (the recommended vanilla DPS premade and
-- the catch-all for any warrior outside Defensive Stance; also Hardcore and Self-Found). wowsims
-- order with Icy Veins' three-target area threshold and Wowhead's leveling gates: Charge to pull;
-- Intercept a distant target; Whirlwind (Thunder Clap before it) on three engaged enemies;
-- Execute first below 20%; Sunder to five on bosses with no Expose Armor; Bloodthirst; Mortal
-- Strike; Slam right after a two-hander swing with Improved Slam; Whirlwind while keeping rage for
-- the main strike; Overpower; Rend until the main strike is learned; Sunder on healthy targets;
-- Hamstring near the rage cap. Shared parts: era/blocks.lua. Left manual: stance dancing; the
-- Hardcore emergency buttons (Intimidating Shout, Retaliation) are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function sunders(op,n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator=op,value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return all(known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss={type='CLASSIFICATION',unit='target',value='worldboss'}
local strike=any(known(12294),known(23881))
local unqueued=all(negate(queued(78)),negate(queued(845)))
local immune=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='MECHANICAL'},{type='CREATURE',unit='target',value='ELEMENTAL'})
local near={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warrior.dps',revision=4,
 blocks={['era.warrior.boundaries']=3,['era.warrior.upkeep']=1,['era.warrior.aoe-strikes']=1},
 nameKey='Default.Era.Warrior.DPS.Name',descriptionKey='Default.Era.Warrior.DPS.Description',
 applicability={families={'era'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','wowsims','icy-veins','wowhead'},
 sources={{url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/warrior/apls/dps_reck.apl.json',title='wowsims/classic: Warrior DPS APL',reviewedAt='2026-10-23',revision='7779ebbf79dc7f1341e6ab939b28a3402c9a730a'},
 {url='https://www.icy-veins.com/wow-classic/warrior-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warrior DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/classic-warrior-leveling-guide',title='Icy Veins: Classic Warrior leveling guide',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/hardcore-warrior-class-overview',title='Icy Veins: Hardcore Warrior overview (emergency buttons)',reviewedAt='2026-10-23',revision='2023-05-14'},
 {url='https://www.wowhead.com/classic/guide/classes/warrior/fury/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Fury Warrior DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 {url='https://www.wowhead.com/classic/guide/classes/warrior/arms/leveling-tips',title='Wowhead: Classic Arms Warrior leveling tips',reviewedAt='2026-10-23',revision='2024-12-27'}},
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warrior.upkeep','warrior-dps-'),
  spell('warrior-dps-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),any(rage('GREATERTHANOREQUALS',40),
   all(target('LESSTHAN',.2),rage('GREATERTHANOREQUALS',30)),all(negate(strike),negate(known(1680)),rage('GREATERTHANOREQUALS',20))))),
  spell('warrior-dps-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),any(rage('GREATERTHANOREQUALS',40),target('LESSTHAN',.2)))),
  spell('warrior-dps-bloodrage',2687,all(combat(),rage('LESSTHAN',80),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5})),
  spell('warrior-dps-sweeping-strikes',12292,all(combat(),enemies('GREATERTHANOREQUALS',2))),
  spell('warrior-dps-death-wish',12328,all(combat(),any(negate(boss),target('LESSTHAN',.2),lifetime('LESSTHANOREQUALS',30)))),
  spell('warrior-dps-recklessness',1719,all(combat(),boss,any({type='BUFF',unit='player',spell=12328},lifetime('LESSTHANOREQUALS',15)))),
  optional(spell('warrior-dps-intimidating-shout',5246,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3},near))),
  optional(spell('warrior-dps-retaliation',20230,all(combat(),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.4},
   {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3}))),
 },
 rotation={
 block('era.warrior.boundaries','warrior-dps-'),
 spell('warrior-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 {id='warrior-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={block('era.warrior.aoe-strikes','warrior-dps-')}},
 spell('warrior-dps-execute',5308,target('LESSTHAN',.2)),
 spell('warrior-dps-boss-sunder',7386,all(boss,any(negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),sunders('LESSTHAN',5)),
  negate({type='DEBUFF',unit='target',spell=8647,anyrank=true}))),
 spell('warrior-dps-bloodthirst',23881),
 spell('warrior-dps-mortal-strike',12294),
 spell('warrior-dps-slam',1464,all({type='TALENT',layout='tree',tree=2,talent=12,operator='GREATERTHANOREQUALS',value=3},negate({type='MOVING'}),
  {type='SWING_TIME_REMAIN',offhand=false,operator='GREATERTHANOREQUALS',value=2.5})),
 spell('warrior-dps-whirlwind',1680,any(negate(strike),cooling(12294,1.5),cooling(23881,1.5),rage('GREATERTHANOREQUALS',55))),
 spell('warrior-dps-overpower',7384),
 spell('warrior-dps-rend',772,all(negate(strike),negate({type='DEBUFF',unit='target',spell=772,anyrank=true,owndebuff=true}),target('GREATERTHAN',.3),negate(immune))),
 spell('warrior-dps-sunder',7386,all(target('GREATERTHANOREQUALS',.6),rage('GREATERTHANOREQUALS',25),
  any(negate({type='DEBUFF',unit='target',spell=7386,anyrank=true}),sunders('LESSTHAN',5)))),
 spell('warrior-dps-hamstring',1715,all(rage('GREATERTHANOREQUALS',80),strike,any(cooling(12294,0),cooling(23881,0)),
  any(negate(known(1680)),cooling(1680,0)))),
 }},
}))
