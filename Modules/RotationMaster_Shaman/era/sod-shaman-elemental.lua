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
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local function flame(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=8050,anyrank=true,owndebuff=true,operator=op,value=n}end
local charged={type='BUFF_STACKS',unit='player',spell=324,anyrank=true,operator='GREATERTHANOREQUALS',value=8}
local surge=buff(440285)
local refresh=any(negate(flamed),flame('LESSTHAN',3))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.elemental',revision=4,
 blocks={['era.shaman.manual-target']=2,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.caster-totems']=1},
 nameKey='Default.SoD.Shaman.Elemental.Name',descriptionKey='Default.SoD.Shaman.Elemental.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'dps','ranged','caster','leveling','endgame','aoe','season-of-discovery','wowhead','icy-veins'},
 sources={
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/elemental/dps-rotation-cooldowns-abilities',title='Wowhead: SoD Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-01-20'},
 {url='https://www.icy-veins.com/wow-classic/elemental-shaman-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Elemental Shaman DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.icy-veins.com/wow-classic/elemental-shaman-dps-season-of-discovery-leveling',title='Icy Veins: SoD Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=50,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=1}}},
 cooldowns={
  spell('sod-ele-flametongue',8024,negate(imbue({5,4,3,523,1665,1666,7567}))),
  block('era.shaman.shield','sod-ele-'),
  spell('sod-ele-earth-shield',408514,negate({type='BUFF',unit='player',spell=408514,ownbuff=true})),
  spell('sod-ele-spirit-of-the-alpha',408696,all(negate(buff(443320)),negate({type='BUFF',unit='player',spell=408696,ownbuff=true}))),
  spell('sod-ele-feral-spirit',440580,combat()),
  spell('sod-ele-shamanistic-rage',425336,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65})),
  spell('sod-ele-elemental-mastery',16166,all(combat(),flamed,negate({type='SPELL_AVAIL',spell=408490}))),
  block('era.shaman.caster-totems','sod-ele-'),
 },
 rotation={
 block('era.shaman.manual-target','sod-ele-'),
 block('era.shaman.interrupt','sod-ele-'),
 {id='sod-ele-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('sod-ele-moving-flame-shock',8050,refresh),
  spell('sod-ele-moving-earth-shock',8042,charged),
  spell('sod-ele-moving-lava-burst',408490,surge),
  spell('sod-ele-moving-chain-lightning',421,surge),
  {id='sod-ele-moving-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-ele-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('sod-ele-aoe-flame-shock',8050,negate(flamed)),
  spell('sod-ele-aoe-chain-lightning',421),
  spell('sod-ele-aoe-fire-nova',408341),
  spell('sod-ele-aoe-lava-burst',408490,flame('GREATERTHANOREQUALS',2)),
  spell('sod-ele-aoe-earth-shock',8042,charged),
  spell('sod-ele-aoe-magma',8190,negate({type='TOTEM',spell=1})),
 }},
 spell('sod-ele-surge-lava-burst',408490,surge),
 spell('sod-ele-flame-shock',8050,refresh),
 spell('sod-ele-lava-burst',408490,flame('GREATERTHANOREQUALS',2)),
 spell('sod-ele-earth-shock',8042,charged),
 spell('sod-ele-chain-lightning',421,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
 spell('sod-ele-bolt',403),
 }},
}))
