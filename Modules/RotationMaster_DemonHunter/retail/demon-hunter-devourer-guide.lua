-- Retail (Midnight 12.x) Devourer Demon Hunter after Icy Veins' Annihilator list (optimal reference).
-- Outside Void Metamorphosis: Consume on Soulburst, Reap, Soul Immolation, Voidblade and The Hunt
-- once Void Metamorphosis is ready, Void Metamorphosis, Hungering Slash, Void Ray at 100 Fury,
-- Consume. Inside: Devour on Soulburst, Void Ray (Void-Scarred melee actives next), Collapsing
-- Star, Cull, Devour, Soul Immolation. RM cannot count Soul Fragments, so Reap and Cull go on
-- cooldown and charges. Disabled: Fury and buffs are secret in Midnight combat.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local soulburst=buff(1297433)
local metaReady={type='BUFF_STACKS',unit='player',spell=1225789,ownbuff=true,operator='GREATERTHANOREQUALS',value=50}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.devourer.guide',revision=1,
 blocks={['retail.demonhunter.boundaries']=1,['retail.demonhunter.utility']=1},
 nameKey='Default.Retail.DemonHunter.DevourerGuide.Name',descriptionKey='Default.Retail.DemonHunter.DevourerGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER',specs={1480},minLevel=8,maxLevel=90},
 tags={'devourer','ranged','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/devourer-demon-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Devourer Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Annihilator list; Void-Scarred actives follow Void Ray inside Void Metamorphosis.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=8},
  cooldowns={block('dguide-utility','retail.demonhunter.utility','dguide-')},
  rotation={
   block('dguide-boundaries','retail.demonhunter.boundaries','dguide-'),
   {id='dguide-meta',type='branch',conditions=buff(1217607),
    onTrue={
     spell('dguide-meta-soulburst',1217610,soulburst),
     spell('dguide-meta-void-ray',473728),
     spell('dguide-meta-reapers-toll',1245470),
     spell('dguide-meta-pierce-the-veil',1245483),
     spell('dguide-meta-predators-wake',1259431),
     spell('dguide-meta-collapsing-star',1221150),
     spell('dguide-meta-cull',1245453),
     spell('dguide-meta-devour',1217610),
     spell('dguide-meta-soul-immolation',1241937)},
    onFalse={
     spell('dguide-soulburst',473662,soulburst),
     spell('dguide-reap',1226019),
     spell('dguide-soul-immolation',1241937,negate(buff(1241937))),
     spell('dguide-voidblade',1245412,metaReady),
     spell('dguide-the-hunt',1246167,metaReady),
     spell('dguide-void-metamorphosis',1217605),
     spell('dguide-hungering-slash',1239123),
     spell('dguide-void-ray',473728,{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=100}),
     spell('dguide-consume',473662)}},
  },
 },
}))
