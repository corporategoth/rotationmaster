-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Protection Warrior, levels 10-90: simulator' Phase 5 Generic order, with Weakened Armor
-- kept only on elites and bosses so trash pulls do not waste globals. Selected in the Protection
-- specialization (73). Rage goes to Shield Block whenever it is down and Shield Barrier when hurt with rage to
-- spare; Heroic Strike / Cleave on Ultimatum, Incite or near the cap. Rotation: Devastate for three Weakened Armor
-- on elites, Dragon Roar, Bladestorm, Shockwave on three; Thunder Clap on cooldown on three or more engaged enemies;
-- Revenge for the last rage of a Block, Shield Slam, Revenge on Hold the Line, Devastate for Deep Wounds, Victory
-- Rush under 60%, Revenge, Thunder Clap for Weakened Blows, Execute, Storm Bolt, shout for rage, Devastate (Sunder
-- Armor before 26). Shared parts: mop/blocks.lua. Left manual: taunting, Shield Wall/Last Stand timing beyond the
-- low-health reminders, physical-vs-magic mitigation choice.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function health(op,n)return{type='HEALTHPCT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local boss=any(classified('worldboss'),classified('elite'))
local blocking=own(132404)
local dump=all(combat(),{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.2},any(own(122510),own(122016),rage('GREATERTHANOREQUALS',90)))
local armor={type='DEBUFF',unit='target',spell=113746}
local function devastate(id,conditions)return{id=id,type='branch',conditions={type='SPELL_KNOWN',spell=20243},onTrue={spell(id..'-devastate',20243,conditions)},onFalse={spell(id..'-sunder',7386,conditions)}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.protection',revision=8,
 blocks={['mop.warrior.boundaries']=4},
 nameKey='Default.MoP.Warrior.Protection.Name',descriptionKey='Default.MoP.Warrior.Protection.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'protection','tank','melee','leveling','endgame','icy-veins'},
 sources={
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-warrior-pve-rotation-cooldowns-abilities',title='Icy Veins: Protection Warrior rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/protection-warrior-leveling',title='Icy Veins: Protection Warrior leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-protection-warrior-tank-rotation-cooldowns/',title='Warcraft Tavern: Protection Warrior rotation (MoP)',reviewedAt='2026-10-23'}},
 body={priority=30,specs={73},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={
  spell('warrior-prot-stance',71,negate({type='FORM',form=71})),
  spell('warrior-prot-shout',6673,all(negate(buff(6673)),negate(buff(469)))),
  spell('warrior-prot-shield-block',2565,all(combat(),negate(blocking))),
  spell('warrior-prot-shield-barrier',112048,all(combat(),negate(own(112048)),any(all(health('LESSTHANOREQUALS',.5),rage('GREATERTHANOREQUALS',80)),all(health('LESSTHANOREQUALS',.8),blocking)))),
  spell('warrior-prot-heroic-strike',78,all(enemies('LESSTHAN',2),dump)),
  spell('warrior-prot-cleave',845,all(enemies('GREATERTHANOREQUALS',2),dump)),
  spell('warrior-prot-demoralizing-shout',1160,all(combat(),boss,health('LESSTHAN',.8))),
  spell('warrior-prot-berserker-rage',18499,all(combat(),negate(buff(12880)))),
  spell('warrior-prot-enraged-regeneration',55694,all(buff(12880),health('LESSTHANOREQUALS',.5))),
  spell('warrior-prot-last-stand',12975,all(combat(),health('LESSTHAN',.35))),
  spell('warrior-prot-shield-wall',871,all(combat(),health('LESSTHAN',.3))),
  spell('warrior-prot-bloodbath',12292,combat()),
  spell('warrior-prot-avatar',107574,all(combat(),blocking,boss)),
  spell('warrior-prot-recklessness',1719,all(combat(),blocking,boss)),
  spell('warrior-prot-skull-banner',114207,all(combat(),{type='GROUP'},blocking,boss)),
  spell('warrior-prot-pummel',6552,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
  {id='warrior-prot-taunt',type='spell',action=355,ranked=false,disabled=true,conditions=all({type='GROUP'},combat(),{type='COMBAT',unit='target'},negate({type='ISSAME',unit='targettarget',otherunit='player'}))},
  {id='warrior-prot-leap',type='spell',action=6544,ranked=false,disabled=true,conditions=combat()},
 },
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 spell('warrior-prot-charge',100,{type='BEYOND_MELEE',unit='target'}),
 spell('warrior-prot-throw',57755,{type='BEYOND_MELEE',unit='target'}),
 devastate('warrior-prot-weaken',all(boss,any(negate(armor),{type='DEBUFF_STACKS',unit='target',spell=113746,operator='LESSTHAN',value=3},
  {type='DEBUFF_REMAIN',unit='target',spell=113746,operator='LESSTHAN',value=2}))),
 spell('warrior-prot-dragon-roar',118000),
 spell('warrior-prot-bladestorm',46924),
 spell('warrior-prot-shockwave',46968,enemies('GREATERTHANOREQUALS',3)),
 {id='warrior-prot-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={spell('warrior-prot-aoe-thunder-clap',6343)}},
 spell('warrior-prot-revenge-block',6572,all(rage('GREATERTHANOREQUALS',40),rage('LESSTHAN',60),{type='SPELL_CHARGES',spell=2565,operator='GREATERTHANOREQUALS',value=1},negate(blocking))),
 spell('warrior-prot-shield-slam',23922),
 spell('warrior-prot-revenge-hold',6572,own(84619)),
 devastate('warrior-prot-deep-wounds',negate({type='DEBUFF',unit='target',spell=115767,owndebuff=true})),
 {id='warrior-prot-sustain',type='branch',conditions=health('LESSTHAN',.6),onFalse={},onTrue={spell('warrior-prot-impending-victory',103840),spell('warrior-prot-victory-rush',34428)}},
 spell('warrior-prot-revenge',6572),
 spell('warrior-prot-thunder-clap',6343,any(negate({type='DEBUFF',unit='target',spell=115798}),{type='DEBUFF_REMAIN',unit='target',spell=115798,operator='LESSTHAN',value=2})),
 spell('warrior-prot-execute',5308),
 spell('warrior-prot-storm-bolt',107570),
 {id='warrior-prot-shout-rage',type='branch',conditions=rage('LESSTHANOREQUALS',60),onFalse={},onTrue={spell('warrior-prot-commanding',469,own(469)),spell('warrior-prot-battle',6673)}},
 devastate('warrior-prot-filler'),
 }},
}))
