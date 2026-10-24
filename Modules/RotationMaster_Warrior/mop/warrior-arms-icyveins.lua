-- Mists of Pandaria Classic Arms Warrior, pool rage for Colossus Smash (Icy Veins, Wowhead Phase 1, MaxDps;
-- off by default). Same switch as the recommended Arms premade (Arms specialization), lower priority. Differs by
-- rage policy: outside the Colossus Smash window Slam only above 80 rage and Overpower before it, so rage is
-- banked for the window; inside it Mortal Strike, Slam, Overpower, Heroic Throw. Below 20%: Colossus Smash,
-- Mortal Strike, Execute, Overpower, Dragon Roar, shout. Two enemies add Sweeping Strikes; three or more
-- Thunder Clap, Bladestorm, Colossus Smash, Mortal Strike, Slam, Dragon Roar, Overpower. Heroic Strike only at
-- the cap. Shared parts: mop/blocks.lua.
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
local worth=any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=15})
local burst=all(combat(),any(negate({type='SPELL_KNOWN',spell=86346}),smashed),worth)
local function shout(prefix)return{id=prefix..'shout',type='branch',conditions=rage('LESSTHAN',30),onFalse={},onTrue={spell(prefix..'commanding',469,own(469)),spell(prefix..'battle',6673)}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.arms.icyveins',revision=5,
 blocks={['mop.warrior.boundaries']=4,['mop.warrior.gap']=1,['mop.warrior.dps-upkeep']=2},
 nameKey='Default.MoP.Warrior.Arms.IcyVeins.Name',descriptionKey='Default.MoP.Warrior.Arms.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'arms','dps','melee','leveling','endgame','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/arms-warrior-pve-rotation-cooldowns-abilities',title='Icy Veins: Arms Warrior rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.wowhead.com/mop-classic/guide/classes/warrior/arms/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Arms Warrior rotation (MoP Classic, Phase 1 text)',reviewedAt='2026-10-23',revision='2025-07-14'},
 {url='https://github.com/kaminaris/MaxDps-Warrior/blob/c3bf773f3709514aae9aad8647cd6a4ae7fc8756/Specialization/Mop/Arms.lua',title='MaxDps-Warrior: MoP Arms',reviewedAt='2026-10-23',revision='c3bf773f3709514aae9aad8647cd6a4ae7fc8756'}},
 body={priority=20,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=71}}},
 cooldowns={block('mop.warrior.dps-upkeep','warrior-'),
  spell('warrior-arms-iv-berserker-rage',18499,all(combat(),negate({type='BUFF',unit='player',spell=12880}))),
  spell('warrior-arms-iv-recklessness',1719,burst),
  spell('warrior-arms-iv-avatar',107574,burst),
  spell('warrior-arms-iv-bloodbath',12292,burst),
  spell('warrior-arms-iv-heroic-strike',78,all(combat(),enemies('LESSTHAN',2),rage('GREATERTHANOREQUALS',90))),
  spell('warrior-arms-iv-cleave',845,all(combat(),enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',90))),
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 block('mop.warrior.gap','warrior-dps-'),
 {id='warrior-arms-iv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-arms-iv-sweeping-strikes',12328,negate(own(12328))),
  {id='warrior-arms-iv-pack',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
   spell('warrior-arms-iv-thunder-clap',6343,negate({type='DEBUFF',unit='target',spell=115767,owndebuff=true})),
   spell('warrior-arms-iv-aoe-bladestorm',46924),
   spell('warrior-arms-iv-aoe-smash',86346,negate(smashed)),
   spell('warrior-arms-iv-aoe-mortal-strike',12294),
   spell('warrior-arms-iv-aoe-slam',1464),
   spell('warrior-arms-iv-aoe-dragon-roar',118000),
   shout('warrior-arms-iv-aoe-'),
   spell('warrior-arms-iv-aoe-overpower',7384,taste),
   {id='warrior-arms-iv-aoe-stop',type='stop',suppress_attack=false,conditions={}},
  }},
 }},
 {id='warrior-arms-iv-execute-phase',type='branch',conditions=target('LESSTHAN',.2),onTrue={
  spell('warrior-arms-iv-execute-smash',86346,negate(smashed)),
  spell('warrior-arms-iv-execute-mortal-strike',12294),
  spell('warrior-arms-iv-execute',5308),
  spell('warrior-arms-iv-execute-overpower',7384,taste),
  spell('warrior-arms-iv-execute-dragon-roar',118000),
  shout('warrior-arms-iv-execute-'),
 },onFalse={
  {id='warrior-arms-iv-window',type='branch',conditions=smashed,onTrue={
   spell('warrior-arms-iv-window-mortal-strike',12294),
   spell('warrior-arms-iv-window-slam',1464),
   spell('warrior-arms-iv-window-overpower',7384,taste),
   spell('warrior-arms-iv-window-throw',57755),
  },onFalse={
   spell('warrior-arms-iv-smash',86346),
   spell('warrior-arms-iv-bladestorm',46924),
   spell('warrior-arms-iv-dragon-roar',118000),
   spell('warrior-arms-iv-mortal-strike',12294),
   spell('warrior-arms-iv-overpower',7384,taste),
   spell('warrior-arms-iv-slam',1464,rage('GREATERTHANOREQUALS',80)),
   shout('warrior-arms-iv-'),
  }},
 }},
 }},
}))
