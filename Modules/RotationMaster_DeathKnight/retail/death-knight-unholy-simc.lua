-- Retail (Midnight 12.x) Unholy Death Knight after SimulationCraft (reference): Death Coil spent far
-- more often (Sudden Doom, in Dark Transformation or Forbidden Knowledge, and whenever Army of the
-- Dead is more than 5 s away) above Scourge Strike; Soul Reaper in Dark Transformation. Runic power
-- and target health are secret on Retail, so the cap and execute checks are left out. Three or more
-- enemies: Epidemic for Death Coil, Festering Strike below three Lesser Ghoul charges. Disabled:
-- secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function debuff(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local transformed={type='BUFF',unit='pet',spell=1233448}
local ghouls=buff(1254252)
local function scythe(id)return spell(id,85948,all(buff(458123),any(negate(debuff(1241077)),{type='DEBUFF_REMAIN',unit='target',spell=1241077,owndebuff=true,operator='LESSTHAN',value=5})))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.unholy.simc',revision=6,
 blocks={['retail.deathknight.boundaries']=3,['retail.deathknight.utility']=2},
 nameKey='Default.Retail.DeathKnight.UnholySimc.Name',descriptionKey='Default.Retail.DeathKnight.UnholySimc.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT'},
 tags={'unholy','melee','pet','reference','simulationcraft'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/deathknight_unholy.simc',title='SimulationCraft default action list: Unholy',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=5,disabled=true,specs={252},
  cooldowns={
   block('usimc-utility','retail.deathknight.utility','usimc-'),
   spell('usimc-outbreak',77575,all(combat(),negate(debuff(1240996)))),
   spell('usimc-death-and-decay',43265,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3}),
   spell('usimc-army-of-the-dead',42650,combat()),
   spell('usimc-dark-transformation',1233448,combat()),
  },
  rotation={
   block('usimc-boundaries','retail.deathknight.boundaries','usimc-'),
   spell('usimc-raise-dead',46584,negate({type='PET'})),
   {id='usimc-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},
    onTrue={
     scythe('usimc-aoe-festering-scythe'),
     spell('usimc-aoe-epidemic-proc',207317,buff(81340)),
     spell('usimc-aoe-putrefy',1247378,transformed),
     spell('usimc-aoe-epidemic-window',207317,any(transformed,buff(1242223))),
     spell('usimc-aoe-festering-strike',85948,any(negate(ghouls),{type='BUFF_STACKS',unit='player',spell=1254252,ownbuff=true,operator='LESSTHAN',value=3})),
     spell('usimc-aoe-scourge-strike',55090),
     spell('usimc-aoe-epidemic',207317)},
    onFalse={
     scythe('usimc-festering-scythe'),
     spell('usimc-soul-reaper',343294,transformed),
     spell('usimc-death-coil-proc',47541,buff(81340)),
     spell('usimc-putrefy',1247378,transformed),
     spell('usimc-death-coil-window',47541,any(transformed,buff(1242223))),
     spell('usimc-death-coil-army',47541,{type='SPELL_COOLDOWN',spell=42650,operator='GREATERTHAN',value=5}),
     spell('usimc-scourge-strike',55090,ghouls),
     spell('usimc-festering-strike',85948)}},
  },
 },
}))
