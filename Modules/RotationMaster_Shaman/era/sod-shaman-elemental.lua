-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Elemental Shaman, levels 10–60 (primary tree 1). simulator/sod Phase 6 order,
-- which Wowhead's matches: Earth Shock interrupts; while moving Flame Shock, Rolling Thunder Earth
-- Shock and Power Surge casts; on three engaged enemies Flame Shock, Chain Lightning, Fire Nova,
-- Lava Burst, Earth Shock at eight Lightning Shield charges, Magma; Lava Burst on a Power Surge
-- proc; Flame Shock kept up; Lava Burst while your Flame Shock lasts; Earth Shock at eight
-- charges; Chain Lightning on two; Lightning Bolt. Reminders: Flametongue (Burn), Lightning
-- Shield, Earth Shield on yourself, Spirit of the Alpha, Feral Spirit, Shamanistic Rage,
-- Elemental Mastery, totems. Shared parts: era/blocks.lua. Left manual: trinket timing, Totemic
-- Projection, dispels and purges.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local function flame(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,anyrank=true,owndebuff=true,operator=op,value=n}end
local charged={type='BUFF_STACKS',unit='player',spell=324,anyrank=true,operator='GREATERTHANOREQUALS',value=8}
local surge=buff(440285)
local refresh=BuiltinConditions.any(BuiltinConditions.negate(flamed),flame('LESSTHAN',3))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.elemental',revision=4,
 blocks={['era.shaman.manual-target']=2,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.caster-totems']=1},
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'dps','ranged','caster','leveling','endgame','aoe','season-of-discovery','wowhead','icy-veins'},
 sources={
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/elemental/dps-rotation-cooldowns-abilities',title='Wowhead: SoD Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-01-20'},
 {url='https://www.icy-veins.com/wow-classic/elemental-shaman-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/elemental-shaman-dps-season-of-discovery-leveling',title='Icy Veins: SoD Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=50,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
 cooldowns={
  BuiltinConditions.spell('sod-ele-flametongue',8024,BuiltinConditions.negate(imbue({5,4,3,523,1665,1666,7567}))),
  block('era.shaman.shield','sod-ele-'),
  BuiltinConditions.spell('sod-ele-earth-shield',408514,BuiltinConditions.negate({type='BUFF',unit='player',spell=408514,ownbuff=true})),
  BuiltinConditions.spell('sod-ele-spirit-of-the-alpha',408696,BuiltinConditions.all(BuiltinConditions.negate(buff(443320)),BuiltinConditions.negate({type='BUFF',unit='player',spell=408696,ownbuff=true}))),
  BuiltinConditions.spell('sod-ele-feral-spirit',440580,BuiltinConditions.combat()),
  BuiltinConditions.spell('sod-ele-shamanistic-rage',425336,BuiltinConditions.all(BuiltinConditions.combat(),{type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65})),
  BuiltinConditions.spell('sod-ele-elemental-mastery',16166,BuiltinConditions.all(BuiltinConditions.combat(),flamed,BuiltinConditions.negate({type='SPELL_AVAIL',spell=408490}))),
  block('era.shaman.caster-totems','sod-ele-'),
 },
 rotation={
 block('era.shaman.manual-target','sod-ele-'),
 block('era.shaman.interrupt','sod-ele-'),
 {id='sod-ele-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('sod-ele-moving-flame-shock',8050,refresh),
  BuiltinConditions.spell('sod-ele-moving-earth-shock',8042,charged),
  BuiltinConditions.spell('sod-ele-moving-lava-burst',408490,surge),
  BuiltinConditions.spell('sod-ele-moving-chain-lightning',421,surge),
  {id='sod-ele-moving-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-ele-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('sod-ele-aoe-flame-shock',8050,BuiltinConditions.negate(flamed)),
  BuiltinConditions.spell('sod-ele-aoe-chain-lightning',421),
  BuiltinConditions.spell('sod-ele-aoe-fire-nova',408341),
  BuiltinConditions.spell('sod-ele-aoe-lava-burst',408490,flame('GREATERTHANOREQUALS',2)),
  BuiltinConditions.spell('sod-ele-aoe-earth-shock',8042,charged),
  BuiltinConditions.spell('sod-ele-aoe-magma',8190,BuiltinConditions.negate({type='TOTEM',spell=1})),
 }},
 BuiltinConditions.spell('sod-ele-surge-lava-burst',408490,surge),
 BuiltinConditions.spell('sod-ele-flame-shock',8050,refresh),
 BuiltinConditions.spell('sod-ele-lava-burst',408490,flame('GREATERTHANOREQUALS',2)),
 BuiltinConditions.spell('sod-ele-earth-shock',8042,charged),
 BuiltinConditions.spell('sod-ele-chain-lightning',421,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
 BuiltinConditions.spell('sod-ele-bolt',403),
 }},
}))
