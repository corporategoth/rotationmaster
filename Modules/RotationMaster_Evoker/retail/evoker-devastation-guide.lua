-- Retail (Midnight 12.x) Devastation Evoker after SimulationCraft and Icy Veins (optimal
-- reference), one list per hero tree (Mass Disintegrate known = Scalecommander, else Flameshaper):
-- empowers on cooldown, Disintegrate to spend (Mass Disintegrate stacks first), Pyre on five or more,
-- Unbound Flame, Living Flame on Burnout with Leaping Flames, Azure Sweep, Living Flame, Azure Strike
-- on the move. Disabled: procs, cooldowns and target debuffs are secret in Midnight combat, and RM
-- cannot pick an empower rank (Icy Veins: rank 1 on one target).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local burstRoom={type='BUFF_STACKS',unit='player',spell=359618,ownbuff=true,operator='LESSTHAN',value=2}
local flames=all(buff(375802),buff(370901))
local sweep=buff(1265871)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.evoker.devastation.guide',revision=7,
 blocks={['retail.evoker.boundaries']=3,['retail.evoker.utility']=2},
 nameKey='Default.Retail.Evoker.DevastationGuide.Name',descriptionKey='Default.Retail.Evoker.DevastationGuide.Description',
 applicability={families={'retail'},actionContext='player',class='EVOKER'},
 tags={'devastation','ranged','reference','simulationcraft','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/evoker_devastation.simc',title='SimulationCraft default action list: Devastation',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.icy-veins.com/wow/devastation-evoker-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Devastation Evoker rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Empowers at rank 1 on a single target; Azure Strike while moving.'},
 },
 body={priority=10,disabled=true,specs={1467},
  cooldowns={
   block('dguide-utility','retail.evoker.utility','dguide-'),
   spell('dguide-dragonrage',375087,combat()),
   spell('dguide-tip-the-scales',370553,all(combat(),any(buff(375087),{type='SPELL_AVAIL',spell=357208}))),
   spell('dguide-deep-breath',357210,all(combat(),known(436335))),
  },
  rotation={
   block('dguide-boundaries','retail.evoker.boundaries','dguide-'),
   {id='dguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('dguide-pull-living-flame',361469),stop('dguide-pull-stop')}},
   {id='dguide-tree',type='branch',conditions=known(436335),
    onTrue={
     spell('dguide-sc-eternity-surge',359073),
     spell('dguide-sc-fire-breath',357208),
     spell('dguide-sc-deep-breath',357210,engaged(2)),
     spell('dguide-sc-mass-disintegrate',356995,buff(436336)),
     spell('dguide-sc-pyre',357211,engaged(5)),
     spell('dguide-sc-disintegrate',356995),
     spell('dguide-sc-flames',361469,flames),
     spell('dguide-sc-unbound-flame',1292321,burstRoom),
     spell('dguide-sc-azure-sweep',362969,sweep)},
    onFalse={
     spell('dguide-fs-eternity-surge',359073),
     spell('dguide-fs-fire-breath',357208,any(negate({type='DEBUFF',unit='target',spell=357209,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=357209,owndebuff=true,operator='LESSTHAN',value=4})),
     spell('dguide-fs-pyre',357211,engaged(5)),
     spell('dguide-fs-disintegrate',356995),
     spell('dguide-fs-deep-breath',357210,engaged(4)),
     spell('dguide-fs-unbound-flame',1292321),
     spell('dguide-fs-flames',361469,flames),
     spell('dguide-fs-azure-sweep',362969,sweep)}},
   spell('dguide-moving-azure-strike',362969,{type='MOVING'}),
   spell('dguide-living-flame',361469),
   spell('dguide-azure-strike',362969),
  },
 },
}))
