-- WoW Forever Elemental Shaman, from Lava Burst (21-point talent, level 30) to 60, Icy Veins
-- leveling order. Chosen when Lava Burst is known: RM cannot read Forever talent trees, and
-- before Lava Burst every source plays Elemental as a melee hybrid, which the Enhancement
-- default covers. Lightning Bolt (or Chain Lightning on a pack) from range; instants while
-- moving; Fire Nova and Chain Lightning on packs; Flame Shock on targets that live; Lava Burst
-- on cooldown; Stormstrike into Earth Shock for the Stormcaller hybrid; Fire Nova on a
-- Clearcasting proc in groups; Lightning Bolt. Below 30% mana in melee it stops and lets
-- auto-attack refill mana. Shared parts: Defaults/blocks/forever-shaman.lua.
-- Left manual: totem presets, Earthbind kiting, Frost Shock, Purge and other utility.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function lives(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local shocked={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local melee=negate({type='BEYOND_MELEE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.elemental',revision=1,
 blocks={['forever.shaman.manual']=1,['forever.shaman.upkeep']=1,['forever.shaman.imbue']=1,['forever.shaman.group-totems']=1,
  ['forever.shaman.caster-aoe']=1,['forever.shaman.stormstrike-hybrid']=1},
 nameKey='Default.Forever.Shaman.Elemental.Name',descriptionKey='Default.Forever.Shaman.Elemental.Description',
 applicability={families={'forever'},actionContext='player',class='SHAMAN',minLevel=25,maxLevel=60},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/elemental-shaman-leveling',title='Icy Veins: Forever Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.icy-veins.com/wow-forever/elemental-shaman-ranged-dps-pve-guide',title='Icy Veins: Forever Elemental Shaman PvE guide',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.wowhead.com/forever/guide/stormcaller-shaman-hybrid-guide-for-wow-forever-35072',title='Wowhead (user guide): Stormcaller Shaman hybrid',reviewedAt='2026-10-23',revision='2026-10-20'},
 {url='https://www.wowhead.com/forever/guide/classes/shaman/elemental/level-30-dps-overview',title='Wowhead: Forever level 30 Elemental Shaman (Clearcasting Fire Nova)',reviewedAt='2026-10-23',revision='2026-10-06'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Lava Burst, Elemental Mastery)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=20,switch={type='SPELL_KNOWN',spell=408490},
 cooldowns={block('forever.shaman.upkeep','shaman-ele-'),block('forever.shaman.imbue','shaman-ele-'),block('forever.shaman.group-totems','shaman-ele-'),
  spell('shaman-ele-magma-totem',8190,all(combat(),negate({type='TOTEM',spell=1}),enemies(3))),
  spell('shaman-ele-searing-totem',3599,all(combat(),negate({type='TOTEM',spell=1}),negate(enemies(3)),any(big(),lives('GREATERTHANOREQUALS',15)))),
  spell('shaman-ele-elemental-mastery',16166,combat()),
  spell('shaman-ele-healing-wave',331,all(negate({type='GROUP'}),negate(combat()),health('LESSTHAN',.7))),
  spell('shaman-ele-lesser-healing-wave',8004,all(negate({type='GROUP'}),combat(),health('LESSTHAN',.35)))},
 rotation={
 block('forever.shaman.manual','shaman-ele-'),
 {id='shaman-ele-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='shaman-ele-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
  spell('shaman-ele-pull-chain',421,all(negate({type='MOVING'}),{type='DISTANCE_COUNT',enemy=true,distance=30,operator='GREATERTHANOREQUALS',value=3})),
  spell('shaman-ele-pull-bolt',403,negate({type='MOVING'})),
  {id='shaman-ele-pull-stop',type='none',suppress_attack=true,conditions={}},
 }},
 {id='shaman-ele-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('shaman-ele-moving-flame-shock',8050,negate(shocked)),
  spell('shaman-ele-moving-earth-shock',8042,lives('LESSTHANOREQUALS',3)),
  {id='shaman-ele-moving-stop',type='none',suppress_attack=false,conditions={}},
 }},
 block('forever.shaman.caster-aoe','shaman-ele-'),
 spell('shaman-ele-flame-shock',8050,all(negate(shocked),any(big(),{type='GROUP'},lives('GREATERTHANOREQUALS',12)))),
 spell('shaman-ele-lava-burst',408490),
 block('forever.shaman.stormstrike-hybrid','shaman-ele-'),
 spell('shaman-ele-clearcasting-nova',408341,all({type='GROUP'},{type='BUFF',unit='player',spell=16246},{type='TOTEM',spell=1},melee)),
 {id='shaman-ele-save-mana',type='none',suppress_attack=false,conditions=all(melee,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.3})},
 spell('shaman-ele-bolt',403),
 }},
}))
