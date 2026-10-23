-- Classic Era Warlock, Warcraft Tavern "drain tank" (alternative premade; same switch, lower
-- priority). The Imp, then the Succubus from level 20 (Dark Pact mana); solo: Immolate, Agony,
-- Corruption and Siphon Life, then Drain Life as the filler once its fourth rank is learned
-- (level 38; the wand before), Life Tap whenever health is nearly full, Dark Pact before the pet
-- is full; in raids every DoT the slots allow (Siphon Life on Shadow Vulnerability), Shadow Bolt.
-- Same boundaries, finishers, curse and safety reminders as the recommended premade
-- (era/blocks.lua). Left manual: fearing a second mob.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local raid={type='INSTANCE',value='raid'}
local summon=all(negate({type='PET'}),negate({type='COMBAT',unit='player'}))
local blocks={['era.warlock.boundaries']=1,['era.warlock.procs']=1,['era.warlock.group-finish']=1,['era.warlock.dying']=1,['era.warlock.curse']=2,
 ['era.warlock.moving']=1,['era.warlock.aoe']=1,['era.warlock.filler']=1,['era.warlock.armor']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warlock.dps.warcrafttavern',revision=2,blocks=blocks,
 nameKey='Default.Era.Warlock.DPS.WarcraftTavern.Name',descriptionKey='Default.Era.Warlock.DPS.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='WARLOCK',minLevel=1,maxLevel=60},
 tags={'dps','ranged','caster','leveling','endgame','warcraft-tavern'},
 sources={{url='https://www.warcrafttavern.com/wow-classic/guides/warlock-leveling-guide/',title='Warcraft Tavern: Classic Warlock leveling guide',reviewedAt='2026-10-23'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/pve-warlock-rotation/',title='Warcraft Tavern: Classic Warlock rotation',reviewedAt='2026-10-23'}},
 body={priority=5,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warlock.armor','lock-wt-'),
  spell('lock-wt-succubus',712,summon),
  spell('lock-wt-imp',688,all(summon,negate(known(712)))),
  block('era.warlock.safety','lock-wt-')},
 rotation={
 block('era.warlock.boundaries','lock-wt-'),
 block('era.warlock.procs','lock-wt-'),
 block('era.warlock.group-finish','lock-wt-'),
 block('era.warlock.dying','lock-wt-'),
 block('era.warlock.moving','lock-wt-'),
 block('era.warlock.aoe','lock-wt-'),
 block('era.warlock.curse','lock-wt-'),
 spell('lock-wt-immolate',348,negate(own(348))),
 spell('lock-wt-siphon-life',18265,all(negate(own(18265)),any(negate(raid),{type='DEBUFF',unit='target',spell=17800,anyrank=true}))),
 spell('lock-wt-corruption',172,negate(own(172))),
 {id='lock-wt-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  spell('lock-wt-dark-pact',18220,all(mana('LESSTHAN',.8),{type='MANAPCT',unit='pet',operator='GREATERTHAN',value=.5})),
  spell('lock-wt-life-tap',1454,all(mana('LESSTHAN',.9),{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.9})),
  spell('lock-wt-drain-life',689,known(7651)),
  {id='lock-wt-wanding',type='none',suppress_attack=true,conditions={type='SPELL_AUTOREPEAT',spell=5019,ranked=true}},
  spell('lock-wt-wand',5019),
 }},
 block('era.warlock.filler','lock-wt-'),
 }},
}))
