-- Retail (Midnight 12.x) Preservation Evoker (reference only, off by default). Ally health, Echo,
-- Reversion, Essence Burst and every cooldown are secret in Midnight combat, RM cannot choose a heal
-- target, and Blizzard ships no Assisted Combat rotation for healers, so this keeps only what the
-- Icy Veins guide asks for outside the healing itself: Blessing of the Bronze and Source of Magic out
-- of combat (utility block), and a damage filler when your target is an enemy (Fire Breath,
-- Disintegrate, Living Flame, Azure Strike on the move).
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.preservation',revision=1,
 blocks={['retail.evoker.boundaries']=1,['retail.evoker.utility']=1},
 nameKey='Default.Retail.Evoker.Preservation.Name',descriptionKey='Default.Retail.Evoker.Preservation.Description',
 applicability={families={'retail'},actionContext='player',class='EVOKER',specs={1468},minLevel=10,maxLevel=90},
 tags={'preservation','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/preservation-evoker-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Preservation Evoker healing rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Healing order kept as reference text only; Disintegrate when nobody needs healing.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={block('pres-utility','retail.evoker.utility','pres-')},
  rotation={
   block('pres-boundaries','retail.evoker.boundaries','pres-'),
   stop('pres-not-hostile',negate({type='ATTACKABLE',unit='target'})),
   spell('pres-moving-azure-strike',362969,{type='MOVING'}),
   spell('pres-fire-breath',357208),
   spell('pres-disintegrate',356995),
   spell('pres-living-flame',361469),
   spell('pres-azure-strike',362969),
  },
 },
}))
