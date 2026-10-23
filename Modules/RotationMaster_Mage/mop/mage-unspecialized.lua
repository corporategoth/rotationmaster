-- Mists of Pandaria Classic Mage before a specialization: levels 1–9, and any Mage who has not
-- chosen one (the spec premades switch on the specialization and outrank this). Frostfire
-- Bolt, Fire Blast to finish or on the move, Ice Lance on the move, Arcane Explosion on packs,
-- Frost Nova when a mob reaches you. RM policy assembled from the spells' training levels; no source
-- writes a level 1–9 list.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.unspecialized',revision=2,
 blocks={['mop.mage.boundaries']=1,['mop.mage.upkeep']=1,['mop.mage.armor-molten']=1},
 nameKey='Default.MoP.Mage.Unspecialized.Name',descriptionKey='Default.MoP.Mage.Unspecialized.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE',minLevel=1,maxLevel=90},
 tags={'leveling','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-mage-leveling',title='Icy Veins: MoP Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2025-06-17',notes='Spell training levels only; no level 1-9 priority.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/frost/dps-leveling-talent-builds-tips',title='Wowhead: MoP Classic Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-06-29',notes='Frost Nova when mobs get close.'},
 },
 body={priority=0,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('mage-armor','mop.mage.armor-molten','mage-'),
   block('mage-upkeep','mop.mage.upkeep','mage-'),
   spell('mage-frost-nova',122,all(combat(),negate({type='BEYOND_MELEE',unit='target'}),{type='ISSAME',unit='targettarget',otherunit='player'})),
  },
  rotation={
   block('mage-boundaries','mop.mage.boundaries','mage-'),
   {id='mage-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('mage-pull-frostfire',44614),stop('mage-pull-stop')}},
   {id='mage-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('mage-aoe-explosion',1449,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3})}},
   spell('mage-fire-blast',2136,any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.15},{type='MOVING'})),
   spell('mage-ice-lance',30455,{type='MOVING'}),
   spell('mage-frostfire',44614),
  },
 },
}))
