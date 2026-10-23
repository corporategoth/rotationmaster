-- Mists of Pandaria Classic Affliction Warlock, levels 10-90 (the recommended variant): wowsims' order with
-- Hekili's one-shard Haunt reserve. Selected in the Affliction specialization (265)
-- from level 10 (RM stores MoP rotations per talent group). Pre-cast Haunt or Unstable
-- Affliction; Soulburn + Soul Swap on a fresh target; Seed of Corruption on packs; Agony, Corruption and
-- Unstable Affliction kept up and refreshed early inside Dark Soul: Misery; Drain Soul for a shard when
-- Haunt is ending with none; Haunt at two or more shards (or in Dark Soul); Drain Soul below 20%; Malefic
-- Grasp; Life Tap. Shared parts: mop/blocks.lua. The Warcraft Tavern variant pools Haunt for four shards or
-- Dark Soul instead.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function shards(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.affliction',revision=2,
 blocks={['mop.warlock.boundaries']=2,['mop.warlock.upkeep']=1,['mop.warlock.pet-felhunter']=1,['mop.warlock.affliction-upkeep']=1,
  ['mop.warlock.affliction-dots']=1,['mop.warlock.affliction-filler']=1},
 nameKey='Default.MoP.Warlock.Affliction.Name',descriptionKey='Default.MoP.Warlock.Affliction.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK',minLevel=10,maxLevel=90},
 tags={'affliction','dps','caster','ranged','leveling','endgame','wowsims','hekili'},
 sources={{url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/warlock/affliction/apls/default.apl.json',title='wowsims/mop: Affliction Warlock APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/WarlockAffliction.simc',title='Hekili (MoP fork): Affliction Warlock priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'},
 {url='https://wowtbc.gg/mop/class-guides/affliction-warlock/',title='wowtbc.gg: Affliction Warlock (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/affliction-warlock-leveling',title='Icy Veins: Affliction Warlock levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-10'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=265}}},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.pet-felhunter','warlock-'),block('mop.warlock.affliction-upkeep','warlock-aff-')},
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 block('mop.warlock.affliction-dots','warlock-aff-'),
 spell('warlock-aff-shard-drain',1120,all({type='SPELL_KNOWN',spell=48181},shards('LESSTHAN',1),any(negate(dot(48181)),remain(48181,'LESSTHAN',1)))),
 spell('warlock-aff-haunt',48181,all(any(negate(dot(48181)),remain(48181,'LESSTHAN',3.5)),
  any(shards('GREATERTHANOREQUALS',2),{type='BUFF',unit='player',spell=113860,ownbuff=true}))),
 block('mop.warlock.affliction-filler','warlock-aff-'),
 }},
}))
