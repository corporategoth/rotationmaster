-- Classic Era Elemental Shaman, levels 10–60 (the recommended vanilla Elemental premade; primary
-- tree 1). Icy Veins and Wowhead order: Earth Shock interrupts and finishes; while moving Flame
-- Shock then Frost Shock; solo with the target in melee, Earth Shock above 30% and melee; on three
-- engaged enemies Fire Nova and Magma totems in melee and Chain Lightning; Chain Lightning under
-- Elemental Mastery or Clearcasting; Lightning Bolt. Reminders: Lightning Shield, Rockbiter
-- outside raids, Searing or Magma, Mana Spring or Healing Stream, Elemental Mastery with Chain
-- Lightning ready, Nature's Swiftness below 30%, solo healing. Shared parts: era/blocks.lua.
-- Left manual: dispels, purges, downranking and the Elemental Mastery shock batch.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function optional(step)step.disabled=true;return step end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local melee=negate({type='BEYOND_MELEE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.elemental',revision=1,
 blocks={['era.shaman.manual']=1,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.caster-totems']=1},
 nameKey='Default.Era.Shaman.Elemental.Name',descriptionKey='Default.Era.Shaman.Elemental.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN',minLevel=10,maxLevel=60},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/wow-classic/elemental-shaman-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
 {url='https://www.icy-veins.com/wow-classic/elemental-shaman-leveling-guide-1-60',title='Icy Veins: Classic Elemental Shaman leveling 1-60',reviewedAt='2026-10-23',revision='2026-07-18'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/elemental/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 {url='https://www.wowhead.com/classic/guide/classes/shaman/elemental/leveling-tips',title='Wowhead: Classic Elemental Shaman leveling tips',reviewedAt='2026-10-23',revision='2024-11-20'}},
 body={priority=30,switch={type='PRIMARY_TALENT_TREE',tree=1},
 cooldowns={
  block('era.shaman.shield','ele-'),
  spell('ele-rockbiter-weapon',8017,all(negate({type='WEAPON'}),negate({type='INSTANCE',value='raid'}))),
  block('era.shaman.caster-totems','ele-'),
  spell('ele-elemental-mastery',16166,all(combat(),{type='SPELL_AVAIL',spell=421})),
  spell('ele-natures-swiftness',16188,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
  spell('ele-swift-healing-wave',331,buff(16188)),
  block('era.shaman.self-heal','ele-'),
  optional(spell('ele-blood-fury',20572,all(combat(),buff(16166)))),
  optional(spell('ele-berserking',26297,all(combat(),buff(16166)))),
 },
 rotation={
 block('era.shaman.manual','ele-'),
 {id='ele-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','ele-'),
 spell('ele-execute-shock',8042,lifetime('LESSTHAN',2.5)),
 {id='ele-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('ele-moving-flame-shock',8050,all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),any(big,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}))),
  spell('ele-moving-frost-shock',8056),
  {id='ele-moving-stop',type='none',suppress_attack=false,conditions={}},
 }},
 {id='ele-solo-melee',type='branch',conditions=all(negate({type='GROUP'}),melee),onFalse={},onTrue={
  spell('ele-melee-shock',8042,{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3}),
  {id='ele-melee-stop',type='none',suppress_attack=false,conditions={}},
 }},
 {id='ele-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('ele-aoe-fire-nova',1535,melee),
  spell('ele-aoe-chain-lightning',421),
  spell('ele-aoe-magma',8190,melee),
 }},
 spell('ele-mastery-chain',421,buff(16166)),
 spell('ele-clearcasting-chain',421,buff(16246)),
 spell('ele-bolt',403),
 }},
}))
