-- Retail (Midnight 12.x) Unholy Death Knight after Icy Veins and Wowhead (optimal reference): ghoul
-- up; Festering Scythe to keep its plague haste; Soul Reaper with Reaping; Putrefy in Dark
-- Transformation; Death Coil (Epidemic on four or more) on Sudden Doom or Forbidden Knowledge;
-- Festering Strike with no Lesser Ghoul charges, Scourge Strike with them; Death Coil. Target health
-- and runic power are secret on Retail, so the execute window and the San'layn runic power spend are
-- left out. Disabled: procs and plagues are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local ghouls=buff(1254252)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.unholy.guide',revision=3,
 blocks={['retail.deathknight.boundaries']=2,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.UnholyGuide.Name',descriptionKey='Default.Retail.DeathKnight.UnholyGuide.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','melee','pet','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/unholy-death-knight-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Unholy Death Knight rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/death-knight/unholy/rotation-cooldowns-pve-dps',title='Wowhead: Unholy Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-09-05',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,switch={type='SPECIALIZATION',spec=252},
  cooldowns={
   block('uguide-utility','retail.deathknight.utility','uguide-'),
   spell('uguide-army-of-the-dead',42650,combat()),
   spell('uguide-dark-transformation',1233448,combat()),
   spell('uguide-outbreak',77575,all(combat(),negate(debuff(191587)),negate(debuff(1240996)))),
  },
  rotation={
   block('uguide-boundaries','retail.deathknight.boundaries','uguide-'),
   spell('uguide-raise-dead',46584,negate({type='PET'})),
   spell('uguide-festering-scythe',85948,all(buff(458123),any(negate(debuff(1241077)),{type='DEBUFF_REMAIN',unit='target',spell=1241077,owndebuff=true,operator='LESSTHAN',value=5}))),
   spell('uguide-soul-reaper',343294,buff(1242654)),
   spell('uguide-putrefy',1247378,{type='BUFF',unit='pet',spell=1233448}),
   {id='uguide-spend',type='branch',conditions=any(buff(81340),buff(1242223)),onFalse={},onTrue={
    spell('uguide-spend-epidemic',207317,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4}),
    spell('uguide-spend-death-coil',47541)}},
   spell('uguide-festering-strike',85948,negate(ghouls)),
   spell('uguide-scourge-strike',55090,ghouls),
   spell('uguide-death-coil',47541),
  },
 },
}))
