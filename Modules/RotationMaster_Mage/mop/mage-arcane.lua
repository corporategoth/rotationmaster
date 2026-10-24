-- Mists of Pandaria Classic Arcane Mage, levels 10–90, in the Arcane specialization
-- (62). wowsims' measured list (Hekili matches it): Arcane Blast builds four Arcane
-- Charges; with four, a single Arcane Missiles! proc is spent above 95% mana and Barrage comes out
-- below 90%, so between 90% and 95% it keeps blasting. Arcane Power and Alter Time at four charges
-- with a proc, Missiles never left at two procs, Barrage every four charges with two or more enemies.
-- The guides' rule (Barrage at four charges without a proc, no mana gate) is rm.mop.mage.arcane.icyveins.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function charges(v)return{type='DEBUFF_STACKS',unit='player',spell=36032,owndebuff=true,operator='GREATERTHANOREQUALS',value=v}end
local function procs(v)return{type='BUFF_STACKS',unit='player',spell=79683,operator='EQUALS',value=v}end
local function ending()return{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=25}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local MISSILES=79683
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.mage.arcane',revision=4,
 blocks={['mop.mage.boundaries']=2,['mop.mage.upkeep']=1,['mop.mage.armor-frost']=1,['mop.mage.bombs']=1,['mop.mage.arcane-open']=2,['mop.mage.arcane-aoe-moving']=1},
 nameKey='Default.MoP.Mage.Arcane.Name',descriptionKey='Default.MoP.Mage.Arcane.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='MAGE'},
 tags={'arcane','leveling','single-target','aoe','wowsims','hekili'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/mage/arcane/apls/default.apl.json',title='wowsims/mop: Arcane Mage default APL',reviewedAt='2026-10-23',revision='ec2c6c2552',notes='Mana-gated four-charge spend, Alter Time and Arcane Power timing, end-of-fight dump.'},
  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/MageArcane.simc',title='Hekili (MoP Classic fork): Arcane Mage priority',reviewedAt='2026-10-23',revision='0750b5dd98'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/arcane-mage-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Arcane Mage rotation',reviewedAt='2026-10-23',revision='2025-06-17',notes='Bomb upkeep, AoE and Alter Time handling, talent rows.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/mage/arcane/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Arcane Mage rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20',notes='Barrage every four charges in cleave; Frost Armor.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=62}}},
  cooldowns={
   block('arcane-armor','mop.mage.armor-frost','arcane-'),
   block('arcane-upkeep','mop.mage.upkeep','arcane-'),
   {id='arcane-mana-gem',type='item',action={36799,81901},conditions=all(combat(),mana('LESSTHAN',.84),charges(2))},
   spell('arcane-power',12042,all(combat(),charges(4),buff(MISSILES))),
   spell('arcane-alter-time',108978,all(combat(),charges(4),buff(MISSILES),buff(12042),negate(buff(110909)),{type='TIME_IN_COMBAT',operator='GREATERTHANOREQUALS',value=10})),
   off('arcane-presence-of-mind',12043,all(combat(),negate(buff(110909)))),
  },
  rotation={
   block('arcane-boundaries','mop.mage.boundaries','arcane-'),
   block('arcane-open','mop.mage.arcane-open','arcane-'),
   spell('arcane-missiles-capped',5143,procs(2)),
   block('arcane-aoe-moving','mop.mage.arcane-aoe-moving','arcane-'),
   spell('arcane-end-missiles',5143,all(buff(MISSILES),ending())),
   spell('arcane-end-blast',30451,ending()),
   spell('arcane-blast-proc-high',30451,all(charges(4),procs(1),mana('GREATERTHANOREQUALS',.95))),
   spell('arcane-missiles',5143,all(charges(4),buff(MISSILES))),
   spell('arcane-blast-high',30451,all(charges(4),negate(buff(MISSILES)),mana('GREATERTHANOREQUALS',.95))),
   spell('arcane-barrage',44425,all(charges(4),negate(buff(MISSILES)),mana('LESSTHAN',.9))),
   spell('arcane-blast',30451),
  },
 },
}))
