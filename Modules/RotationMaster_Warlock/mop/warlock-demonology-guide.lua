-- Mists of Pandaria Classic Demonology Warlock, pool Molten Core (guide consensus: Method, wowtbc.gg, Warcraft
-- Tavern, Wowhead), off by default. Same switch as the recommended premade (Demonology specialization) at a lower
-- priority. It differs in caster form: Metamorphosis at 900 fury or inside Dark Soul: Knowledge, and Soul
-- Fire only at eight Molten Core stacks or below 25%, so the stacks are spent in demon form. Metamorphosis
-- itself and the Shadowflame weave are the recommended premade's. Shared parts: mop/blocks.lua.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.demonology.guide',revision=4,
 blocks={['mop.warlock.boundaries']=3,['mop.warlock.upkeep']=1,['mop.warlock.demonology-upkeep']=2,['mop.warlock.demonology-demon']=1,
  ['mop.warlock.demonology-pull']=2,['mop.warlock.demonology-caster']=1,['mop.warlock.demonology-filler']=1},
 nameKey='Default.MoP.Warlock.Demonology.Guide.Name',descriptionKey='Default.MoP.Warlock.Demonology.Guide.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'demonology','dps','caster','ranged','pet','leveling','endgame','method','wowtbc','warcraft-tavern','wowhead'},
 sources={{url='https://www.method.gg/mop-classic/demonology-warlock-class-guide-mop-classic',title='Method: Demonology Warlock guide (MoP Classic)',reviewedAt='2026-10-23',revision='2025-07-23'},
 {url='https://wowtbc.gg/mop/class-guides/demonology-warlock/',title='wowtbc.gg: Demonology Warlock (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/mop/guides/pve-demonology-warlock-rotations-cooldowns/',title='Warcraft Tavern: Demonology Warlock rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.wowhead.com/mop-classic/guide/classes/warlock/demonology/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Demonology Warlock rotation (MoP Classic, pre-patch text)',reviewedAt='2026-10-23',revision='2025-05-26'}},
 body={priority=20,disabled=true,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=266}}},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.demonology-upkeep','warlock-demo-')},
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 block('mop.warlock.demonology-pull','warlock-demo-'),
 {id='warlock-demo-form',type='branch',conditions={type='FORM',form=103958},
  onTrue={block('mop.warlock.demonology-demon','warlock-demo-')},
  onFalse={
  block('mop.warlock.demonology-caster','warlock-demo-'),
  spell('warlock-demo-guide-metamorphosis',103958,any({type='BUFF',unit='player',spell=113861,ownbuff=true},
   {type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=900})),
  spell('warlock-demo-guide-soul-fire',6353,any({type='BUFF_STACKS',unit='player',spell=122355,ownbuff=true,operator='GREATERTHANOREQUALS',value=8},
   {type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.25})),
  block('mop.warlock.demonology-filler','warlock-demo-'),
 }},
 }},
}))
