-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- TBC Priest damage after Wowhead's guides, levels 1–70; same switch as the Icy Veins damage
-- premade with a lower priority, shipped disabled: enable it to use it. It differs where Wowhead
-- differs: Mind Blast opens and goes before DoT refreshes, Vampiric Embrace only when your
-- health drops, and a dying solo target gets spells (Spirit Tap) instead of the wand.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function healthy()return{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}end
local P='priest-wh-'
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.dps.wowhead',revision=7,
 blocks={['tbc.priest.dps-boundaries']=2,['tbc.priest.shadowform']=1,['tbc.priest.moving']=2,
  ['tbc.priest.dots']=1,['tbc.priest.filler']=2,['tbc.priest.upkeep']=1},
 nameKey="Damage (Wowhead)",descriptionKey="Damage after Wowhead's guides, an alternative to the recommended Icy Veins damage premade, off by default: enable it and disable that one, or raise its priority. Mind Blast opens and goes before DoT refreshes, Vampiric Embrace only when your health drops, and a dying target gets spells instead of the wand. Otherwise the same as the recommended premade.",
 applicability={families={'tbc'},actionContext='player',class='PRIEST'},
 tags={'shadow','damage','wowhead','leveling','raid','single-target'},
 sources={
  {url='https://www.wowhead.com/tbc/guide/classes/priest/shadow/leveling-tips',title='Wowhead: Shadow Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/priest/holy/leveling-tips',title='Wowhead: Holy Priest leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/priest/shadow/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Shadow Priest rotation',reviewedAt='2026-10-23',revision='2026-02-10'},
 },
 body={
  priority=5,disabled=true,
  switch={type='SPELL_KNOWN',spell=585},
  cooldowns={block(P..'upkeep','tbc.priest.upkeep',P),
   spell(P..'inner-focus',14751,all({type='COMBAT',unit='player'},{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
   spell(P..'scream',8122,all({type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=2},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))},
  rotation={
   block(P..'boundaries','tbc.priest.dps-boundaries',P),
   block(P..'form','tbc.priest.shadowform',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-blast',8092),spell(P..'pull-touch',34914),spell(P..'pull-holy-fire',14914,negate(known(15407))),spell(P..'pull-smite',585),stop(P..'pull-stop')}},
   block(P..'moving','tbc.priest.moving',P),
   {id=P..'dying',type='branch',conditions=all(negate({type='GROUP'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2}),onFalse={},onTrue={
    spell(P..'dying-blast',8092),spell(P..'dying-death',32379,healthy()),spell(P..'dying-flay',15407),spell(P..'dying-smite',585),stop(P..'dying-stop')}},
   spell(P..'embrace',15286,all(negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7})),
   spell(P..'blast',8092),
   block(P..'dots','tbc.priest.dots',P),
   spell(P..'death',32379,healthy()),
   block(P..'filler','tbc.priest.filler',P),
  },
 },
}))
