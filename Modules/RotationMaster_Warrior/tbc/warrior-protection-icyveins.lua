-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Warrior tank, levels 10–70, Icy Veins order (alternative tank variant).
-- Same switch as the Wowhead variant (Defensive Stance), lower priority. Differs where Icy Veins
-- differs: Shield Block whenever the target is hitting you, no single-target Thunder Clap or
-- Demoralizing Shout upkeep (Thunder Clap on packs, Demoralizing Shout for elite packs), and
-- Rend at the start of a fight until Shield Slam is learned.
-- Left manual: taunting, pre-pull rage, stance swaps and other utility.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.warrior.protection.icyveins',revision=7,
 blocks={['tbc.warrior.boundaries']=4,['tbc.warrior.upkeep']=1,['tbc.warrior.prot-upkeep']=1,['tbc.warrior.prot-core']=1,['tbc.warrior.sunder']=1},
 nameKey='Default.TBC.Warrior.Protection.IcyVeins.Name',descriptionKey='Default.TBC.Warrior.Protection.IcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/tbc-classic/protection-warrior-tank-pve-rotation-cooldowns-abilities',title='Icy Veins: Protection Warrior tank rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2026-01-12'},
 {url='https://www.icy-veins.com/tbc-classic/protection-warrior-leveling-guide',title='Icy Veins: Protection Warrior leveling',reviewedAt='2026-10-23',revision='2026-01-12'}},
 body={priority=25,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',form=71}}},
 cooldowns={block('tbc.warrior.upkeep','warrior-prot-'),block('tbc.warrior.prot-upkeep','warrior-prot-'),
  spell('warrior-prot-shield-block',2565,all({type='COMBAT',unit='player'},{type='WEAPON_TYPE',slot='offhand',kind='shield'},negate({type='BUFF',unit='player',spell=2565,anyrank=true}),
   {type='ISSAME',unit='targettarget',otherunit='player'}))},
 rotation={
 block('tbc.warrior.boundaries','warrior-prot-'),
 {id='warrior-prot-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  spell('warrior-prot-aoe-thunder-clap',6343),
  spell('warrior-prot-aoe-demoralizing-shout',1160,all(any(classified('worldboss'),classified('elite')),negate(any(debuff(1160),debuff(99))))),
 }},
 block('tbc.warrior.prot-core','warrior-prot-'),
 block('tbc.warrior.sunder','warrior-prot-'),
 spell('warrior-prot-rend',772,all(negate({type='SPELL_KNOWN',spell=23922}),negate(debuff(772,true)))),
 }},
}))
