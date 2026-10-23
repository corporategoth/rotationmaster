-- WoW Forever Restoration Shaman, from Mana Tide Totem (16-point talent, level 25) to 60,
-- Icy Veins leveling order. Chosen when Mana Tide Totem is known; it outranks the other
-- Shaman premades. With a friendly target: Nature's Swiftness for an emergency instant Healing
-- Wave, Cure Poison/Disease, Riptide, Chain Heal when three nearby group members are hurt,
-- Lesser Healing Wave on a low target, Healing Wave; then it stops. With a hostile target it
-- helps with damage when healing is quiet: Fire Nova and Chain Lightning on packs, Stormstrike
-- into Earth Shock for the Wavebreaker hybrid, Flame Shock on targets that live, Lightning Bolt,
-- then melee. RM cannot pick a heal target: you choose who to heal by targeting them.
-- Left manual: downranking, Healing Stream vs Mana Spring, air totem choice, Purge and Ghost Wolf.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function hurt(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.restoration',revision=1,
 blocks={['forever.shaman.manual']=1,['forever.shaman.upkeep']=1,['forever.shaman.group-totems']=1,
  ['forever.shaman.caster-aoe']=1,['forever.shaman.stormstrike-hybrid']=1},
 nameKey='Default.Forever.Shaman.Restoration.Name',descriptionKey='Default.Forever.Shaman.Restoration.Description',
 applicability={families={'forever'},actionContext='player',class='SHAMAN',minLevel=20,maxLevel=60},
 tags={'healer','caster','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/restoration-shaman-leveling',title='Icy Veins: Forever Restoration Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.icy-veins.com/wow-forever/restoration-shaman-healer-pve-guide',title='Icy Veins: Forever Restoration Shaman healer PvE guide',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.wowhead.com/forever/guide/classes/shaman/restoration/level-30-healer-overview',title='Wowhead: Forever level 30 Restoration Shaman',reviewedAt='2026-10-23',revision='2026-10-07'},
 {url='https://www.wowhead.com/forever/guide/wavebreaker-shaman-hybrid-guide-for-wow-forever-35074',title='Wowhead (user guide): Wavebreaker Shaman hybrid',reviewedAt='2026-10-23',revision='2026-10-20'},
 {url='https://worldofwarcraft.com/en-us/news/24302097',title='Blizzard: Forever class deep dives, Mage and Shaman',reviewedAt='2026-10-23',revision='2026-10-07'}},
 body={priority=30,switch={type='SPELL_KNOWN',spell=16190},
 cooldowns={block('forever.shaman.upkeep','shaman-resto-'),block('forever.shaman.group-totems','shaman-resto-'),
  spell('shaman-resto-mana-tide',16190,all(combat(),{type='GROUP'},{type='MANAPCT',unit='player',operator='LESSTHAN',value=.6}))},
 rotation={
 block('forever.shaman.manual','shaman-resto-'),
 {id='shaman-resto-heal',type='branch',conditions={type='FRIENDLY',unit='target'},onTrue={
  spell('shaman-resto-swift-wave',331,{type='BUFF',unit='player',spell=16188}),
  spell('shaman-resto-swiftness',16188,hurt('LESSTHAN',.3)),
  spell('shaman-resto-cure-poison',526,{type='DISPELLABLE',unit='target',debufftype='Poison'}),
  spell('shaman-resto-cure-disease',2870,{type='DISPELLABLE',unit='target',debufftype='Disease'}),
  spell('shaman-resto-riptide',408521,all(hurt('LESSTHAN',.9),negate({type='BUFF',unit='target',spell=408521,anyrank=true,ownbuff=true}))),
  spell('shaman-resto-chain-heal',1064,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3}),
  spell('shaman-resto-lesser-wave',8004,hurt('LESSTHAN',.4)),
  spell('shaman-resto-wave',331,hurt('LESSTHAN',.9)),
  {id='shaman-resto-heal-stop',type='none',suppress_attack=true,conditions={}},
 },onFalse={
  {id='shaman-resto-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
  block('forever.shaman.caster-aoe','shaman-resto-'),
  block('forever.shaman.stormstrike-hybrid','shaman-resto-'),
  spell('shaman-resto-flame-shock',8050,all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),
   any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12}))),
  spell('shaman-resto-bolt',403,negate({type='MOVING'})),
 }},
 }},
}))
