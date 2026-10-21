local _,addon=...
-- Bounded Enhancement-oriented solo preview; primary allocation does not prove
-- a full build or weapon type. Equipment, interrupts, totems and timing are manual.
local function all(...)return{type='AND',value={...}}end
local function negate(condition)return{type='NOT',value=condition}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function peaceful()return negate({type='COMBAT',unit='player'})end
local function attackable()return{type='ATTACKABLE',unit='target'}end
local function missingEnchant()return negate({type='WEAPON',offhand=false})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.enhancement.50-59',revision=1,
 nameKey='Default.TBC.Shaman.Enhancement50.Name',descriptionKey='Default.TBC.Shaman.Enhancement50.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN',minLevel=50,maxLevel=59},
 tags={'leveling','solo','enhancement','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide',
  title='Icy Veins: Enhancement Shaman leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={
  switch=all(known(403),{type='PRIMARY_TALENT_TREE',tree=2},
   {type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=50},
   {type='LEVEL',unit='player',operator='LESSTHAN',value=60}),
  rotation={
   {id='shaman-enhancement50-pull',type='spell',action=403,ranked=false,
    conditions=all(peaceful(),attackable(),negate({type='COMBAT',unit='target'}))},
   {id='shaman-enhancement50-combat-boundary',type='none',conditions=peaceful()},
   {id='shaman-enhancement50-shock',type='spell',action=8042,ranked=false,conditions=attackable()},
   {id='shaman-enhancement50-ranged-bolt',type='spell',action=403,ranked=false,
    conditions=all(attackable(),{type='BEYOND_MELEE',unit='target'},negate({type='MOVING'}))},
  },
  cooldowns={
   -- Learned Windfury owns the preference even while unready. Existing manual
   -- enchants are preserved; WEAPON observes presence, not an equipped type.
   {id='shaman-enhancement50-rockbiter',type='spell',action=8017,ranked=false,
    conditions=all(negate(known(8232)),missingEnchant())},
   {id='shaman-enhancement50-windfury',type='spell',action=8232,ranked=false,
    conditions=all(known(8232),missingEnchant())},
   {id='shaman-enhancement50-shield',type='spell',action=324,ranked=false,
    conditions=negate({type='BUFF',unit='player',spell=324,ownbuff=true,anyrank=true})},
  },
 },
}))
