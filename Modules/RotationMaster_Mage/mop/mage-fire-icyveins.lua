-- Mists of Pandaria Classic Fire Mage after Icy Veins, Method and wowtbc.gg, levels 10–90: hold
-- Pyroblast! until a Heating Up joins it, then cast both (Fireball, then the instant Pyroblast); spend
-- it alone only before it expires. Otherwise as rm.mop.mage.fire, the recommended Fire premade (same
-- switch, higher priority). Off by default.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local PYRO,HEAT,ALTER=48108,48107,110909
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.fire.icyveins',revision=6,
 blocks={['mop.mage.boundaries']=3,['mop.mage.upkeep']=1,['mop.mage.armor-molten']=1,['mop.mage.bombs']=1,['mop.mage.fire-open']=3,['mop.mage.fire-spend']=1,['mop.mage.fire-filler']=2},
 nameKey='Default.MoP.Mage.Fire.IcyVeins.Name',descriptionKey='Default.MoP.Mage.Fire.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'fire','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/fire-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Fire Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17'},
  {url='https://www.method.gg/mop-classic/fire-mage-class-guide-mop-classic',title='Method: MoP Classic Fire Mage guide',reviewedAt='2026-10-23',notes='Phase 1 text.'},
  {url='https://wowtbc.gg/mop/class-guides/fire-mage',title='wowtbc.gg: MoP Classic Fire Mage PvE guide',reviewedAt='2026-10-23'},
 },
 body={priority=25,disabled=true,specs={63},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('fireiv-armor','mop.mage.armor-molten','fireiv-'),
   block('fireiv-upkeep','mop.mage.upkeep','fireiv-'),
   {id='fireiv-mana-gem',type='item',action={36799,81901},conditions=all(combat(),mana('LESSTHAN',.84),negate(buff(ALTER)))},
   spell('fireiv-presence-of-mind',12043,all(combat(),negate(buff(ALTER)),negate(buff(PYRO)))),
   spell('fireiv-alter-time',108978,all(combat(),buff(PYRO),buff(HEAT),negate(buff(ALTER)))),
  },
  rotation={
   block('fireiv-boundaries','mop.mage.boundaries','fireiv-'),
   block('fireiv-open','mop.mage.fire-open','fireiv-'),
   spell('fireiv-pyroblast',11366,all(buff(PYRO),any(buff(HEAT),{type='BUFF_REMAIN',unit='player',spell=PYRO,operator='LESSTHAN',value=3}))),
   block('fireiv-bombs','mop.mage.bombs','fireiv-'),
   block('fireiv-spend','mop.mage.fire-spend','fireiv-'),
   block('fireiv-filler','mop.mage.fire-filler','fireiv-'),
  },
 },
}))
