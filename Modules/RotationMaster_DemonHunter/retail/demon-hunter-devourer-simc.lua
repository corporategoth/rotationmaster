-- Retail (Midnight 12.x) Devourer Demon Hunter after SimulationCraft's Annihilator list (reference):
-- Void Metamorphosis as soon as it is ready, Voidblade only with Devourer's Bite on up to three
-- enemies; outside it Consume on Soulburst, Reap, Void Ray, Soul Immolation on packs, Consume;
-- inside it Devour on Soulburst against one target, The Hunt and Voidblade with Devourer's Bite,
-- Void Ray on packs, Collapsing Star, Cull, Void Ray, Soul Immolation, Devour. Disabled: secret in
-- Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local soulburst=buff(1297433)
local bite=known(1240201)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.devourer.simc',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 nameKey='Default.Retail.DemonHunter.DevourerSimc.Name',descriptionKey='Default.Retail.DemonHunter.DevourerSimc.Description',
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'devourer','ranged','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_devourer.simc',title='SimulationCraft default action list: Devourer (Annihilator)',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={1480},
  cooldowns={block('dsimc-utility','retail.demonhunter.utility','dsimc-')},
  rotation={
   block('dsimc-boundaries','retail.demonhunter.boundaries','dsimc-'),
   {id='dsimc-meta',type='branch',conditions=buff(1217607),
    onTrue={
     spell('dsimc-meta-soulburst',1217610,all(soulburst,negate(engaged(2)))),
     spell('dsimc-meta-the-hunt',1246167,bite),
     spell('dsimc-meta-voidblade',1245412,bite),
     spell('dsimc-meta-void-ray-aoe',473728,engaged(2)),
     spell('dsimc-meta-collapsing-star',1221150),
     spell('dsimc-meta-cull',1245453),
     spell('dsimc-meta-void-ray',473728),
     spell('dsimc-meta-soul-immolation',1241937,negate(buff(1241937))),
     spell('dsimc-meta-devour',1217610)},
    onFalse={
     spell('dsimc-voidblade',1245412,all(bite,negate(engaged(4)),{type='BUFF_STACKS',unit='player',spell=1225789,ownbuff=true,operator='GREATERTHANOREQUALS',value=50})),
     spell('dsimc-void-metamorphosis',1217605),
     spell('dsimc-soulburst',473662,soulburst),
     spell('dsimc-reap',1226019),
     spell('dsimc-void-ray',473728),
     spell('dsimc-soul-immolation',1241937,engaged(2)),
     spell('dsimc-consume',473662)}},
  },
 },
}))
