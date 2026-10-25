-- Mists of Pandaria Classic Affliction Warlock, Haunt pooling (Warcraft Tavern and Method), off by default.
-- Same switch as the recommended premade (Affliction specialization) at a lower priority. It differs only in
-- the shard policy: Haunt is cast at four shards or inside Dark Soul: Misery (not kept rolling), and below
-- 20% Soulburn + Soul Swap re-snapshots every DoT whenever a shard is free. No Drain Soul shard fishing.
-- Shared parts: mop/blocks.lua.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function shards(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.affliction.warcrafttavern',revision=7,
 blocks={['mop.warlock.boundaries']=4,['mop.warlock.upkeep']=1,['mop.warlock.pet-felhunter']=1,['mop.warlock.affliction-upkeep']=1,
  ['mop.warlock.affliction-dots']=3,['mop.warlock.affliction-filler']=1},
 nameKey='Default.MoP.Warlock.Affliction.WarcraftTavern.Name',descriptionKey='Default.MoP.Warlock.Affliction.WarcraftTavern.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'affliction','dps','caster','ranged','leveling','endgame','warcraft-tavern','method'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-affliction-warlock-rotations-cooldowns/',title='Warcraft Tavern: Affliction Warlock rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/affliction-warlock-class-guide-mop-classic',title='Method: Affliction Warlock guide (MoP Classic)',reviewedAt='2026-10-23',revision='2025-07-23'}},
 body={priority=20,disabled=true,specs={265},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.pet-felhunter','warlock-'),block('mop.warlock.affliction-upkeep','warlock-aff-')},
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 block('mop.warlock.affliction-dots','warlock-aff-'),
 {id='warlock-aff-tavern-execute',type='branch',conditions={type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},onFalse={},onTrue={
  spell('warlock-aff-tavern-execute-soulburn',74434,all({type='SPELL_KNOWN',spell=86121},negate(own(74434)),shards('GREATERTHANOREQUALS',1),
   negate({type='SPELL_HISTORY_TIME',spell=86121,operator='LESSTHAN',value=8}))),
  spell('warlock-aff-tavern-execute-soul-swap',86121,own(74434)),
 }},
 spell('warlock-aff-tavern-haunt',48181,any(shards('GREATERTHANOREQUALS',4),own(113860))),
 block('mop.warlock.affliction-filler','warlock-aff-'),
 }},
}))
