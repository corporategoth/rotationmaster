-- Mists of Pandaria Classic Fury Warrior, levels 10-90 (the recommended variant): wowsims' Phase 5 order,
-- simplified. Selected while Bloodthirst is known (Fury's own spell). Titan's Grip and Single-Minded Fury play
-- the same here (RM cannot read the weapon type). Colossus Smash when two Raging Blow charges are banked (one
-- with Recklessness); Raging Blow to spend charges as the window closes; Bloodthirst; Colossus Smash; Storm Bolt
-- with it; Dragon Roar outside it; Execute; Bladestorm outside the window while Bloodthirst is cooling; Wild
-- Strike on Bloodsurge; Raging Blow keeping one charge for the next window; Wild Strike as the filler; Heroic
-- Throw; Battle Shout for rage. Two or more engaged enemies add Bladestorm, Dragon Roar, Whirlwind for Meat
-- Cleaver and Raging Blow cleaves. Before Colossus Smash (81) the "not known" arms keep Raging Blow and Wild
-- Strike open. Shared parts: mop/blocks.lua. The Icy Veins variant spends the tier-4 talent inside the window.
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
local function charges(op,n)return{type='BUFF_STACKS',unit='player',spell=131116,ownbuff=true,operator=op,value=n}end
local function smash(op,n)return{type='SPELL_COOLDOWN',spell=86346,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local smashed={type='DEBUFF',unit='target',spell=86346,owndebuff=true}
local unsmashed={type='NOT',value={type='SPELL_KNOWN',spell=86346}}
local worth=any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})
-- Heroic Strike / Cleave dump: 60 rage in the window, 90 outside it (not in execute).
local dump=any(all(smashed,rage('GREATERTHANOREQUALS',60)),all(target('GREATERTHANOREQUALS',.2),rage('GREATERTHANOREQUALS',90)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.fury',revision=1,
 blocks={['mop.warrior.boundaries']=1,['mop.warrior.gap']=1,['mop.warrior.dps-upkeep']=1},
 nameKey='Default.MoP.Warrior.Fury.Name',descriptionKey='Default.MoP.Warrior.Fury.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR',minLevel=10,maxLevel=90},
 tags={'fury','dps','melee','leveling','endgame','wowsims'},
 sources={{url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/warrior/fury/apls/default.apl.json',title='wowsims/mop: Fury Warrior APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://wowtbc.gg/mop/class-guides/fury-warrior/',title='wowtbc.gg: Fury Warrior (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-fury-warrior-dps-rotation-cooldowns/',title='Warcraft Tavern: Fury Warrior rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/fury-warrior-leveling',title='Icy Veins: Fury Warrior levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=30,switch={type='SPELL_KNOWN',spell=23881},
 cooldowns={block('mop.warrior.dps-upkeep','warrior-'),
  spell('warrior-fury-berserker-rage',18499,all(combat(),any(negate({type='BUFF',unit='player',spell=12880}),all(smashed,charges('EQUALS',0),target('GREATERTHANOREQUALS',.2))))),
  spell('warrior-fury-recklessness',1719,all(combat(),any(unsmashed,smashed,smash('LESSTHANOREQUALS',1.5),enemies('GREATERTHANOREQUALS',4)),worth)),
  spell('warrior-fury-avatar',107574,all(combat(),any(unsmashed,smashed),worth)),
  spell('warrior-fury-bloodbath',12292,all(combat(),any(unsmashed,smashed),worth)),
  spell('warrior-fury-heroic-strike',78,all(combat(),enemies('LESSTHAN',2),dump)),
  spell('warrior-fury-cleave',845,all(combat(),enemies('GREATERTHANOREQUALS',2),dump)),
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 block('mop.warrior.gap','warrior-dps-'),
 {id='warrior-fury-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-fury-aoe-bladestorm',46924,enemies('GREATERTHANOREQUALS',3)),
  spell('warrior-fury-aoe-dragon-roar',118000,negate(smashed)),
  spell('warrior-fury-aoe-enrage',23881,negate({type='BUFF',unit='player',spell=12880})),
  spell('warrior-fury-meat-cleaver',1680,any(negate(own(85739)),all(enemies('GREATERTHANOREQUALS',4),{type='BUFF_STACKS',unit='player',spell=85739,ownbuff=true,operator='LESSTHAN',value=3}))),
  spell('warrior-fury-aoe-raging-blow',85288,own(85739)),
  spell('warrior-fury-aoe-smash',86346,negate(smashed)),
  spell('warrior-fury-aoe-bloodthirst',23881),
  spell('warrior-fury-whirlwind',1680,enemies('GREATERTHANOREQUALS',3)),
 }},
 spell('warrior-fury-smash-setup',86346,all(negate(smashed),any(charges('EQUALS',2),all(charges('EQUALS',1),own(1719))))),
 spell('warrior-fury-raging-blow-closing',85288,all(smashed,{type='DEBUFF_REMAIN',unit='target',spell=86346,owndebuff=true,operator='LESSTHANOREQUALS',value=1.5})),
 spell('warrior-fury-bloodthirst',23881),
 spell('warrior-fury-smash',86346,negate(smashed)),
 spell('warrior-fury-storm-bolt',107570,any(smashed,smash('GREATERTHAN',1.5))),
 spell('warrior-fury-dragon-roar',118000,negate(smashed)),
 spell('warrior-fury-execute',5308),
 spell('warrior-fury-bladestorm',46924,all(negate(smashed),{type='SPELL_COOLDOWN',spell=23881,operator='GREATERTHANOREQUALS',value=2.5})),
 spell('warrior-fury-bloodsurge',100130,all(own(46916),charges('LESSTHANOREQUALS',1))),
 spell('warrior-fury-raging-blow',85288,any(unsmashed,charges('EQUALS',2),smashed,smash('GREATERTHAN',1.5))),
 spell('warrior-fury-wild-strike',100130,all(target('GREATERTHANOREQUALS',.2),any(unsmashed,smashed,smash('GREATERTHAN',3),rage('GREATERTHANOREQUALS',80)))),
 spell('warrior-fury-heroic-throw',57755,any(unsmashed,smash('GREATERTHAN',1))),
 {id='warrior-fury-shout-rage',type='branch',conditions=all(rage('LESSTHANOREQUALS',80),negate({type='SPELL_KNOWN',spell=46924})),onFalse={},onTrue={
  spell('warrior-fury-commanding',469,own(469)),spell('warrior-fury-battle',6673)}},
 }},
}))
