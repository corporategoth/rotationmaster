-- TBC Priest damage, levels 1–70; the default Priest premade whenever the healer premade does
-- not apply (solo, Shadow, or no talents yet). Smite and wand early, Mind Flay once learned,
-- Shadowform, Vampiric Touch and Shadow Word: Death as they arrive; Holy and Discipline
-- questers keep Holy Fire and Smite. DoTs go before Mind Blast (Icy Veins, wowsims, MaxDps);
-- a dying solo target is wanded (Icy Veins). Thresholds are RM policy.
-- The Wowhead variant is rm.tbc.priest.dps.wowhead.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function healthy()return{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}end
local P='priest-iv-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.dps.icyveins',revision=6,
 blocks={['tbc.priest.dps-boundaries']=2,['tbc.priest.shadowform']=1,['tbc.priest.moving']=2,
  ['tbc.priest.dots']=1,['tbc.priest.filler']=2,['tbc.priest.upkeep']=1},
 nameKey='Default.TBC.Priest.DpsIcyVeins.Name',descriptionKey='Default.TBC.Priest.DpsIcyVeins.Description',
 applicability={families={'tbc'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','icy-veins','leveling','raid','single-target'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/shadow-priest-leveling-guide',title='Icy Veins: Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/shadow-priest-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Shadow Priest rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/priest/shadow/rotation.go',title='wowsims TBC Shadow Priest rotation',reviewedAt='2026-10-23',revision='3301fca'},
  {url='https://github.com/kaminaris/MaxDps-Priest/tree/0ecad695ef2548e1aeaab8d7235311d4e211370d/Specialization/TBC',title='MaxDps-Priest TBC modules',reviewedAt='2026-10-23',revision='0ecad69'},
 },
 body={
  priority=10,
  switch={type='SPELL_KNOWN',spell=585},
  cooldowns={block(P..'upkeep','tbc.priest.upkeep',P),
   spell(P..'inner-focus',14751,all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
   spell(P..'scream',8122,all({type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=2},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))},
  rotation={
   block(P..'boundaries','tbc.priest.dps-boundaries',P),
   block(P..'form','tbc.priest.shadowform',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-touch',34914),spell(P..'pull-blast',8092),spell(P..'pull-holy-fire',14914,negate(known(15407))),spell(P..'pull-smite',585),stop(P..'pull-stop')}},
   block(P..'moving','tbc.priest.moving',P),
   {id=P..'dying',type='branch',conditions=all(negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),onFalse={},onTrue={
    {id=P..'dying-wand',type='branch',conditions=known(5019),onFalse={},onTrue={
     stop(P..'dying-wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell(P..'dying-shoot',5019)}},
    spell(P..'dying-blast',8092),spell(P..'dying-death',32379,healthy()),spell(P..'dying-flay',15407),spell(P..'dying-smite',585),stop(P..'dying-stop')}},
   -- Vampiric Embrace on long fights, or solo when your health is dropping.
   spell(P..'embrace',15286,all(negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),any(
    all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7}),
    {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=60}))),
   block(P..'dots','tbc.priest.dots',P),
   spell(P..'blast',8092),
   spell(P..'death',32379,healthy()),
   block(P..'filler','tbc.priest.filler',P),
  },
 },
}))
