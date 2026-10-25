-- Mists of Pandaria Classic Demonology Warlock, levels 10-90 (the recommended variant): wowsims' structure.
-- Selected in the Demonology specialization (266)
-- from level 10 (RM stores MoP rotations per talent group). Pre-cast Soul Fire or Shadow Bolt. In Metamorphosis: leave it
-- when Dark Soul is down and fury is at 300 or less, Doom, Touch of Chaos to extend Corruption, Soul Fire on
-- Molten Core, Immolation Aura / Void Ray on packs, Touch of Chaos. In caster form: Corruption, the
-- Shadowflame weave into Metamorphosis, Hand of Gul'dan by charges, Metamorphosis with more than 10 s of
-- Dark Soul: Knowledge (or at 950 fury, so it never caps), Soul Fire at two Molten Core stacks, an ending
-- Molten Core or below 25%, Hellfire on packs, Shadow Bolt. Shared parts: mop/blocks.lua. The guide variant
-- pools Molten Core for Metamorphosis instead.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.demonology',revision=6,
 blocks={['mop.warlock.boundaries']=4,['mop.warlock.upkeep']=1,['mop.warlock.demonology-upkeep']=2,['mop.warlock.demonology-demon']=2,
  ['mop.warlock.demonology-pull']=3,['mop.warlock.demonology-caster']=2,['mop.warlock.demonology-filler']=1},
 nameKey='Default.MoP.Warlock.Demonology.Name',descriptionKey='Default.MoP.Warlock.Demonology.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'demonology','dps','caster','ranged','pet','leveling','endgame','wowsims','hekili'},
 sources={{url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/warlock/demonology/apls/default.apl.json',title='wowsims/mop: Demonology Warlock APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/WarlockDemonology.simc',title='Hekili (MoP fork): Demonology Warlock priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/demonology-warlock-leveling',title='Icy Veins: Demonology Warlock levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-06-10'}},
 body={priority=30,specs={266},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.demonology-upkeep','warlock-demo-')},
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 block('mop.warlock.demonology-pull','warlock-demo-'),
 {id='warlock-demo-form',type='branch',conditions={type='FORM',form=103958},
  onTrue={block('mop.warlock.demonology-demon','warlock-demo-')},
  onFalse={
  block('mop.warlock.demonology-caster','warlock-demo-'),
  spell('warlock-demo-metamorphosis',103958,any({type='BUFF_REMAIN',unit='player',spell=113861,ownbuff=true,operator='GREATERTHAN',value=10},
   {type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=950})),
  spell('warlock-demo-soul-fire',6353,any({type='BUFF_STACKS',unit='player',spell=122355,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},
   {type='BUFF_REMAIN',unit='player',spell=122355,ownbuff=true,operator='LESSTHAN',value=4},{type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.25})),
  block('mop.warlock.demonology-filler','warlock-demo-'),
 }},
 }},
}))
