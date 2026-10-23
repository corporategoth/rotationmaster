-- Mists of Pandaria Classic Warlock before a specialization (levels 1-9, or later with none chosen): the
-- class catch-all, lowest priority, so every specialization premade beats it from level 10. Corruption to
-- pull, Drain Life below half health, Corruption kept up, Shadow Bolt. Reminders: the Voidwalker solo (the
-- Imp in a group or before level 8) and a Healthstone between pulls. No guide covers these levels; this is
-- the level 1-9 kit arranged like the TBC solo branch. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local corrupted={type='DEBUFF',unit='target',spell=172,anyrank=true,owndebuff=true}
local petless=all(negate(combat()),negate({type='PET'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.unspecialized',revision=1,
 blocks={['mop.warlock.boundaries']=1},
 nameKey='Default.MoP.Warlock.Unspecialized.Name',descriptionKey='Default.MoP.Warlock.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK',minLevel=1,maxLevel=90},
 tags={'dps','caster','ranged','leveling'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/affliction-warlock-leveling',title='Icy Veins: Affliction Warlock levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-10'},
 {url='https://wago.tools/db2/SpellLevels?build=5.5.4.70531',title='wago.tools: MoP Classic 5.5.4 SpellLevels (level 1-9 kit)',reviewedAt='2026-10-23',revision='5.5.4.70531'}},
 body={priority=1,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={
  spell('warlock-start-voidwalker',697,all(petless,negate({type='GROUP'}))),
  spell('warlock-start-imp',688,all(petless,any({type='GROUP'},negate({type='SPELL_KNOWN',spell=697})))),
  spell('warlock-start-healthstone',6201,all(negate(combat()),{type='CARRYING',item={5512},operator='LESSTHAN',value=1})),
 },
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 {id='warlock-start-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
  spell('warlock-start-pull-corruption',172,negate(corrupted)),
  spell('warlock-start-pull-shadow-bolt',686),
  {id='warlock-start-pull-stop',type='none',suppress_attack=true,conditions={}},
 }},
 spell('warlock-start-drain-life',689,{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}),
 spell('warlock-start-corruption',172,negate(corrupted)),
 spell('warlock-start-shadow-bolt',686),
 }},
}))
