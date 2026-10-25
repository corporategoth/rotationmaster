-- Mists of Pandaria Classic Warrior catch-all: levels 1-9, or a warrior of 10+ who has not chosen a
-- specialization (the specialization switches do not match then), so it carries the lowest priority.
-- RM policy built from the 1-9 kit (no guide gives a list): Charge to pull, Victory Rush, Execute, Heroic Strike
-- when rage allows, Battle Stance unless you chose another stance. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warrior.unspecialized',revision=7,
 blocks={['mop.warrior.boundaries']=4},
 nameKey='Default.MoP.Warrior.Unspecialized.Name',descriptionKey='Default.MoP.Warrior.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/arms-warrior-leveling',title='Icy Veins: Arms Warrior leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://wago.tools/db2/SpellLevels?build=5.5.4.70531',title='wago.tools: MoP Classic 5.5.4 SpellLevels (the 1-9 kit)',reviewedAt='2026-10-23',revision='5.5.4.70531'}},
 body={priority=1,
 cooldowns={spell('warrior-starter-stance',2457,all(negate({type='FORM',form=2457}),negate({type='FORM',form=71}),negate({type='FORM',form=2458})))},
 rotation={
 block('mop.warrior.boundaries','warrior-'),
 spell('warrior-starter-victory-rush',34428),
 spell('warrior-starter-execute',5308),
 spell('warrior-starter-heroic-strike',78,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=30}),
 }},
}))
