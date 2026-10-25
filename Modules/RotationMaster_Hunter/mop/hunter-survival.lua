-- Mists of Pandaria Classic Survival Hunter, levels 10–90, in the Survival
-- specialization (255). Wowhead's Phase 5 order with wowsims' pack gates and Black Arrow
-- refresh: Explosive Shot on cooldown and on every Lock and Load, Kill Shot, Black Arrow on a target
-- that lives 8 s, talents, Serpent Sting kept up by Cobra Shot, Arcane Shot as a focus dump that
-- waits for Black Arrow, Cobra or Steady Shot. Two or more enemies: Multi-Shot on Lock and Load with
-- full focus, Explosive Shot up to five targets, Multi-Shot to spend.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function focus(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local loaded=buff(56453)
local thrill=buff(34720)
local ARROW=3674
local arrow=all(any(negate({type='DEBUFF',unit='target',spell=ARROW,owndebuff=true}),{type='DEBUFF_REMAIN',unit='target',spell=ARROW,owndebuff=true,operator='LESSTHAN',value=2}),
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=8})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.hunter.survival',revision=7,
 blocks={['mop.hunter.boundaries']=3,['mop.hunter.mark']=1,['mop.hunter.pet']=1,['mop.hunter.aspect']=1,['mop.hunter.utility']=1,['mop.hunter.burst']=1,
  ['mop.hunter.talents']=1,['mop.hunter.talent-shots']=1,['mop.hunter.serpent']=1,['mop.hunter.filler']=2},
 nameKey='Default.MoP.Hunter.Survival.Name',descriptionKey='Default.MoP.Hunter.Survival.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='HUNTER'},
 tags={'survival','leveling','single-target','aoe','wowhead','wowsims'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/hunter/survival/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Survival Hunter rotation (Phase 5)',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/hunter/survival/apls/sv.apl.json',title='wowsims/mop Survival APL',reviewedAt='2026-10-23',revision='ec2c6c2552',notes='Multi-Shot on Lock and Load at 90 focus, Explosive Shot up to five targets, Black Arrow refresh.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/survival-hunter-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Survival Hunter rotation',reviewedAt='2026-10-23',revision='2026-05-29',notes='Explosive Shot opener while leveling.'},
 },
 body={priority=10,specs={255},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('sv-pet','mop.hunter.pet','sv-'),
   block('sv-aspect','mop.hunter.aspect','sv-'),
   block('sv-utility','mop.hunter.utility','sv-'),
   block('sv-burst','mop.hunter.burst','sv-'),
  },
  rotation={
   block('sv-boundaries','mop.hunter.boundaries','sv-'),
   {id='sv-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    block('sv-pull-mark','mop.hunter.mark','sv-pull-'),
    spell('sv-pull-black-arrow',ARROW),
    spell('sv-pull-explosive',53301),
    stop('sv-pull-stop')}},
   {id='sv-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
    spell('sv-aoe-loaded-multi',2643,all(loaded,focus('GREATERTHANOREQUALS',90))),
    spell('sv-aoe-explosive',53301,any(loaded,enemies('LESSTHANOREQUALS',5))),
    spell('sv-aoe-kill-shot',53351),
    spell('sv-aoe-black-arrow',ARROW,arrow),
    spell('sv-aoe-explosive-trap',13813,enemies('GREATERTHANOREQUALS',3)),
    block('sv-aoe-shots','mop.hunter.talent-shots','sv-aoe-'),
    spell('sv-aoe-multi-shot',2643,any(focus('GREATERTHANOREQUALS',60),thrill)),
    block('sv-aoe-filler','mop.hunter.filler','sv-aoe-')}},
   spell('sv-explosive',53301),
   spell('sv-kill-shot',53351),
   spell('sv-black-arrow',ARROW,arrow),
   block('sv-talents','mop.hunter.talents','sv-'),
   block('sv-shots','mop.hunter.talent-shots','sv-'),
   block('sv-serpent','mop.hunter.serpent','sv-'),
   spell('sv-arcane',3044,any(thrill,focus('GREATERTHANOREQUALS',75),all(focus('GREATERTHANOREQUALS',55),
    any(negate(known(ARROW)),{type='SPELL_COOLDOWN',spell=ARROW,operator='GREATERTHANOREQUALS',value=4})))),
   block('sv-filler','mop.hunter.filler','sv-'),
  },
 },
}))
