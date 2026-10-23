-- Mists of Pandaria Classic Fire Mage, levels 10–90, in the Fire specialization (63).
-- wowsims' proc handling (Wowhead's Phase 5 page and Hekili agree): Pyroblast! at once unless
-- Combustion is less than 5 s away, then pooled with Fireball until Heating Up; Inferno Blast on
-- Heating Up; Fireball filler, Scorch on the move. Combustion right after a Pyroblast while Ignite and
-- the Pyroblast DoT are up, because RM cannot read Ignite's size. Icy Veins' always-hold rule is
-- rm.mop.mage.fire.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local PYRO,HEAT,ALTER=48108,48107,110909
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.fire',revision=2,
 blocks={['mop.mage.boundaries']=1,['mop.mage.upkeep']=1,['mop.mage.armor-molten']=1,['mop.mage.bombs']=1,['mop.mage.fire-open']=1,['mop.mage.fire-spend']=1,['mop.mage.fire-filler']=1},
 nameKey='Default.MoP.Mage.Fire.Name',descriptionKey='Default.MoP.Mage.Fire.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE',minLevel=10,maxLevel=90},
 tags={'fire','leveling','single-target','aoe','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/mage/fire/apls/fire.apl.json',title='wowsims/mop: Fire Mage APL',reviewedAt='2026-10-23',revision='ec2c6c2552',notes='Pyroblast! pooling before Combustion; Presence of Mind and Alter Time sequence.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/fire/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Fire Mage rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/MageFire.simc',title='Hekili (MoP Classic fork): Fire Mage priority',reviewedAt='2026-10-23',revision='0750b5dd98'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/fire-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Fire Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Inferno Blast spreading, AoE, talent rows.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=63}}},
  cooldowns={
   block('fire-armor','mop.mage.armor-molten','fire-'),
   block('fire-upkeep','mop.mage.upkeep','fire-'),
   {id='fire-mana-gem',type='item',action={36799,81901},conditions=all(combat(),mana('LESSTHAN',.84),negate(buff(ALTER)))},
   spell('fire-presence-of-mind',12043,all(combat(),negate(buff(ALTER)),negate(buff(PYRO)))),
   spell('fire-alter-time',108978,all(combat(),buff(PYRO),buff(HEAT),negate(buff(ALTER)))),
   off('fire-dragons-breath',31661,all(negate({type='GROUP'}),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2})),
  },
  rotation={
   block('fire-boundaries','mop.mage.boundaries','fire-'),
   block('fire-open','mop.mage.fire-open','fire-'),
   block('fire-bombs','mop.mage.bombs','fire-'),
   spell('fire-pyroblast-proc',11366,all(buff(PYRO),any(negate({type='SPELL_KNOWN',spell=11129}),{type='SPELL_COOLDOWN',spell=11129,operator='GREATERTHANOREQUALS',value=5},
    negate({type='DEBUFF',unit='target',spell=11366,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=11366,owndebuff=true,operator='LESSTHAN',value=2},{type='BUFF_REMAIN',unit='player',spell=PYRO,operator='LESSTHAN',value=3}))),
   block('fire-spend','mop.mage.fire-spend','fire-'),
   spell('fire-pyroblast-pooled',11366,all(buff(PYRO),buff(HEAT))),
   block('fire-filler','mop.mage.fire-filler','fire-'),
  },
 },
}))
