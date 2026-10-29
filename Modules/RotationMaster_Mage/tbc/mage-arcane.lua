-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Mage Arcane, levels 10–70 when Arcane is the primary talent tree. Before Arcane Blast (64)
-- it plays Arcane Missiles with a Frostbolt fallback; from 64 it burns with Arcane Blast and
-- conserves with "Arcane Blast to three stacks, Frostbolt until they are about to drop", read
-- from the Arcane Blast debuff instead of a cast counter. Thresholds are RM policy.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local stacks={type='DEBUFF',unit='player',spell=36032}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.arcane',revision=5,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.frostbolt']=1,['tbc.mage.wand-finish']=2,['tbc.mage.moving-fire-blast']=2,['tbc.mage.armor']=1,['tbc.mage.upkeep']=1},
 nameKey='Default.TBC.Mage.Arcane.Name',descriptionKey='Default.TBC.Mage.Arcane.Description',
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'arcane','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/arcane-mage-leveling-guide',title='Icy Veins: Arcane Mage leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/arcane-mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Arcane Mage rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/mage/arcane/leveling-tips',title='Wowhead: Arcane Mage leveling',reviewedAt='2026-10-23',revision='2026-02-02'},
  {url='https://www.wowhead.com/tbc/guide/classes/mage/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Mage DPS rotation',reviewedAt='2026-10-23',revision='2026-05-31'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-arcane-mage-rotation-cooldowns-abilities/',title='Warcraft Tavern: Arcane Mage PvE rotation',reviewedAt='2026-10-23'},
  {url='https://github.com/kaminaris/MaxDps-Mage/tree/886c8e27f48e38e0f9b8c22cf56b5e625dfce3f0/Specialization/TBC',title='MaxDps-Mage TBC Arcane module',reviewedAt='2026-10-23',revision='886c8e2'},
  
 },
 body={
  priority=20,
  switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
  cooldowns={block('mage-arcane-armor','tbc.mage.armor','mage-arcane-'),block('mage-arcane-upkeep','tbc.mage.upkeep','mage-arcane-')},
  rotation={
   block('mage-arcane-boundaries','tbc.mage.boundaries','mage-arcane-'),
   {id='mage-arcane-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('mage-arcane-pull-blast',30451),block('mage-arcane-pull-filler','tbc.mage.frostbolt','mage-arcane-pull-'),stop('mage-arcane-pull-stop')}},
   block('mage-arcane-moving','tbc.mage.moving-fire-blast','mage-arcane-'),
   {id='mage-arcane-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('mage-arcane-cone',120),spell('mage-arcane-explosion',1449)}},
   {id='mage-arcane-blast-known',type='branch',conditions={type='SPELL_KNOWN',spell=30451},
    -- Burn under Arcane Power, Bloodlust/Heroism or above 35% mana; otherwise keep three stacks.
    onTrue={spell('mage-arcane-blast',30451,any(buff(12042),buff(2825),buff(32182),mana('GREATERTHANOREQUALS',.35),negate(stacks),
     {type='DEBUFF_STACKS',unit='player',spell=36032,operator='LESSTHAN',value=3},
     {type='DEBUFF_REMAIN',unit='player',spell=36032,operator='LESSTHAN',value=1.5}))},
    onFalse={spell('mage-arcane-missiles',5143,mana('GREATERTHANOREQUALS',.2))}},
   block('mage-arcane-filler','tbc.mage.frostbolt','mage-arcane-'),
   block('mage-arcane-finish','tbc.mage.wand-finish','mage-arcane-'),
  },
 },
}))
