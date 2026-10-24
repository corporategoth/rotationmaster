-- Mists of Pandaria Classic Arms Warrior, levels 10-90 (the recommended variant): wowsims' Phase 5 order in
-- wowtbc.gg's simpler shape. Selected in the Arms specialization (71) from level 10 (RM stores MoP
-- rotations per talent group, so the switch reads the specialization). Colossus Smash is the window: refreshed when it is
-- missing or about to end, Mortal Strike, Storm Bolt with it, Dragon Roar and Bladestorm outside it; below
-- 20% Execute in the window, at 100 rage or to keep Sudden Execute, Overpower on Taste for Blood; otherwise
-- Slam in the window, Overpower at four stacks, Slam at 100 rage, Overpower, Slam as the filler. Two or more
-- engaged enemies add Sweeping Strikes, Thunder Clap for Deep Wounds, Bladestorm and Dragon Roar. Before
-- Colossus Smash (81) every window test reads "not up", so the same list is the levelling order. Shared parts:
-- mop/blocks.lua. The Icy Veins variant pools rage for the window instead of Slamming outside it.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,n)return{type='HEALTHPCT',unit='target',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
local taste=own(60503)
-- Long fights only: an elite or boss, or a target forecast to live 15 s.
local worth=any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})
local burst=all(combat(),any(negate({type='SPELL_KNOWN',spell=86346}),smashed),worth)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.arms',revision=5,
 blocks={['mop.warrior.boundaries']=4,['mop.warrior.gap']=1,['mop.warrior.dps-upkeep']=2},
 nameKey='Default.MoP.Warrior.Arms.Name',descriptionKey='Default.MoP.Warrior.Arms.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'arms','dps','melee','leveling','endgame','wowsims','wowtbc'},
 sources={{url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/warrior/arms/apls/arms.apl.json',title='wowsims/mop: Arms Warrior APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://wowtbc.gg/mop/class-guides/arms-warrior/',title='wowtbc.gg: Arms Warrior (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/arms-warrior-leveling',title='Icy Veins: Arms Warrior levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.method.gg/mop-classic/arms-warrior-class-guide-mop-classic',title='Method: Arms Warrior guide (MoP Classic)',reviewedAt='2026-10-23',revision='2025-07-22'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=71}}},
 cooldowns={block('mop.warrior.dps-upkeep','warrior-'),
  spell('warrior-arms-berserker-rage',18499,all(combat(),negate({type='BUFF',unit='player',spell=12880}),any(smashed,{type='SPELL_AVAIL',spell=118000},own(46924)))),
  spell('warrior-arms-recklessness',1719,burst),
  spell('warrior-arms-avatar',107574,burst),
  spell('warrior-arms-bloodbath',12292,burst),
  spell('warrior-arms-heroic-strike',78,all(combat(),enemies('LESSTHAN',2),any(rage('GREATERTHANOREQUALS',110),
   all(target('GREATERTHANOREQUALS',.2),any(rage('GREATERTHANOREQUALS',100),all(smashed,rage('GREATERTHANOREQUALS',50))))))),
  spell('warrior-arms-cleave',845,all(combat(),enemies('GREATERTHANOREQUALS',2),own(12328),negate(smashed),rage('GREATERTHANOREQUALS',100))),
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 block('mop.warrior.gap','warrior-dps-'),
 {id='warrior-arms-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-arms-sweeping-strikes',12328,negate(own(12328))),
  spell('warrior-arms-thunder-clap',6343,all(enemies('GREATERTHANOREQUALS',3),any(negate({type='DEBUFF',unit='target',spell=115767,owndebuff=true}),
   {type='DEBUFF_REMAIN',unit='target',spell=115767,owndebuff=true,operator='LESSTHAN',value=4}))),
  spell('warrior-arms-aoe-bladestorm',46924,enemies('GREATERTHANOREQUALS',3)),
  spell('warrior-arms-aoe-dragon-roar',118000,enemies('GREATERTHANOREQUALS',3)),
  spell('warrior-arms-aoe-smash',86346,all(negate(smashed),enemies('LESSTHANOREQUALS',6))),
  spell('warrior-arms-aoe-mortal-strike',12294),
  spell('warrior-arms-aoe-slam',1464,all(own(12328),any(smashed,rage('GREATERTHANOREQUALS',50)))),
  spell('warrior-arms-whirlwind',1680,all(enemies('GREATERTHANOREQUALS',5),rage('GREATERTHANOREQUALS',30))),
 }},
 spell('warrior-arms-smash',86346,any(negate(smashed),{type='DEBUFF_REMAIN',unit='target',spell=86346,owndebuff=true,operator='LESSTHAN',value=1})),
 spell('warrior-arms-mortal-strike',12294),
 spell('warrior-arms-storm-bolt',107570,any(smashed,{type='SPELL_COOLDOWN',spell=86346,operator='GREATERTHAN',value=1.5})),
 spell('warrior-arms-dragon-roar',118000,negate(smashed)),
 spell('warrior-arms-bladestorm',46924,all(negate(smashed),any(negate({type='TALENT',layout='grid',value=17}),own(12292),target('LESSTHAN',.2)))),
 {id='warrior-arms-execute-phase',type='branch',conditions=target('LESSTHAN',.2),onTrue={
  spell('warrior-arms-execute-window',5308,any(smashed,rage('GREATERTHANOREQUALS',100),negate(own(139958)))),
  spell('warrior-arms-execute-overpower',7384,taste),
  spell('warrior-arms-execute',5308),
 },onFalse={
  spell('warrior-arms-slam-window',1464,smashed),
  spell('warrior-arms-overpower-stacked',7384,{type='BUFF_STACKS',unit='player',spell=60503,ownbuff=true,operator='GREATERTHANOREQUALS',value=4}),
  spell('warrior-arms-slam-rage',1464,rage('GREATERTHANOREQUALS',100)),
  spell('warrior-arms-overpower',7384,taste),
  spell('warrior-arms-slam',1464),
 }},
 {id='warrior-arms-shout-rage',type='branch',conditions=rage('LESSTHAN',30),onFalse={},onTrue={spell('warrior-arms-commanding',469,own(469)),spell('warrior-arms-battle',6673)}},
 spell('warrior-arms-heroic-throw',57755),
 }},
}))
