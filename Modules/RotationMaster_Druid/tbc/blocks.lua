-- Shared TBC Druid blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.druid.balance, rm.tbc.druid.feral.* and rm.tbc.druid.restoration.
-- A content change needs a revision bump, every consumer's `blocks` pin and revision
-- bumped, and ledger rows in tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read from their auras: FORM is a shapeshift-bar index that moves as forms are learned.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function anyBuff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function feral()return any(own(768),own(5487),own(9634))end
local function travelling()return any(own(783),own(1066),own(33943),own(40120))end
local function druid(id,steps)assert(addon:RegisterDefaultBlock({id=id,revision=1,families={'tbc'},class='DRUID',steps=steps}))end
-- Casts and channels (Starfire, Hurricane, Tranquility) and travel forms halt advice and Attack.
druid('tbc.druid.boundaries',{
 {id='casting',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='travelling',type='none',suppress_attack=true,conditions=travelling()},
})
-- A caster spec in Cat or Bear form chose to be there; no caster advice.
druid('tbc.druid.feral-form-stop',{
 {id='feral-form',type='none',conditions=feral()},
})
-- Out-of-combat self buffs every source keeps: Mark (unless Gift is up), Thorns while
-- soloing, Omen of Clarity once talented.
druid('tbc.druid.upkeep',{
 {id='mark-of-the-wild',type='spell',action=1126,ranked=false,conditions=all(negate(combat()),negate(anyBuff(1126)),negate(anyBuff(21849)))},
 {id='thorns',type='spell',action=467,ranked=false,conditions=all(negate(combat()),negate({type='GROUP'}),negate(anyBuff(467)))},
 {id='omen-of-clarity',type='spell',action=16864,ranked=false,conditions=all(negate(combat()),negate(own(16864)))},
})
-- Shared cat finishers, Mangle upkeep and positional builder (both Feral sources).
druid('tbc.druid.cat-builders',{
 {id='mangle-debuff',type='spell',action=33876,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=33876,anyrank=true}),negate({type='DEBUFF',unit='target',spell=33878,anyrank=true}))},
 {id='facing',type='branch',conditions={type='ISSAME',unit='targettarget',otherunit='player'},onTrue={
  {id='front-mangle',type='spell',action=33876,ranked=false,conditions={}},
  {id='front-claw',type='spell',action=1082,ranked=false,conditions={}},
 },onFalse={
  {id='behind-shred',type='spell',action=5221,ranked=false,conditions={}},
  {id='behind-claw',type='spell',action=1082,ranked=false,conditions={}},
 }},
})
-- Cat entry both Feral sources share: stop without a target, a stealth opener, a
-- Faerie Fire (Feral) pull or debuff when nobody else has Faerie Fire up.
druid('tbc.druid.cat-opening',{
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  {id='pounce',type='spell',action=9005,ranked=false,conditions={}},
  {id='ravage',type='spell',action=6785,ranked=false,conditions={}},
  {id='shred',type='spell',action=5221,ranked=false,conditions={}},
  {id='claw',type='spell',action=1082,ranked=false,conditions={}},
  {id='stealth-stop',type='none',suppress_attack=true,conditions={}},
 }},
 {id='faerie-fire',type='spell',action=16857,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}),
  any({type='GROUP'},all(negate(combat()),{type='BEYOND_MELEE',unit='target'})))},
})
-- Bear upkeep both Feral sources share: Faerie Fire (Feral), a Lacerate stack about to
-- drop, Demoralizing Roar unless a warrior's Shout already covers it, Swipe for packs, Mangle.
druid('tbc.druid.bear-core',{
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='faerie-fire',type='spell',action=16857,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))},
 {id='lacerate-save',type='spell',action=33745,ranked=false,conditions=all({type='DEBUFF_STACKS',unit='target',spell=33745,owndebuff=true,operator='GREATERTHANOREQUALS',value=5},
  {type='DEBUFF_REMAIN',unit='target',spell=33745,owndebuff=true,operator='LESSTHANOREQUALS',value=1.5})},
 {id='demoralizing-roar',type='spell',action=99,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=99,anyrank=true}),negate({type='DEBUFF',unit='target',spell=1160,anyrank=true}))},
 {id='swipe-aoe',type='spell',action=779,ranked=false,conditions={type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3}},
 {id='mangle',type='spell',action=33878,ranked=false,conditions={}},
})
-- Feral cooldowns both sources share: Maul as the bear's rage dump (off the GCD, so it
-- is highlighted beside the priority) and Tiger's Fury only at full energy before a pull.
druid('tbc.druid.feral-cooldowns',{
 {id='maul',type='spell',action=6807,ranked=false,conditions=all(any(own(5487),own(9634)),combat(),{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=50},negate({type='SPELL_ACTIVE',spell=6807}))},
 {id='tigers-fury',type='spell',action=5217,ranked=false,conditions=all(own(768),negate(combat()),{type='ATTACKABLE',unit='target'},{type='POWER',unit='player',operator='GREATERTHANOREQUALS',value=100})},
})
-- A Feral druid in caster form: shift (Cat once learned, else Bear), else caster filler.
druid('tbc.druid.feral-humanoid',{
 {id='no-target',type='none',conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='cat-form',type='spell',action=768,ranked=false,conditions={}},
 {id='dire-bear-form',type='spell',action=9634,ranked=false,conditions=negate({type='SPELL_KNOWN',spell=768})},
 {id='bear-form',type='spell',action=5487,ranked=false,conditions=negate({type='SPELL_KNOWN',spell=768})},
 {id='moonfire',type='spell',action=8921,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8921,anyrank=true,owndebuff=true})},
 {id='wrath',type='spell',action=5176,ranked=false,conditions=negate({type='MOVING'})},
})
