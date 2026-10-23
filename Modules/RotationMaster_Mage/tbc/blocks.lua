-- Shared TBC Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.mage.frost, rm.tbc.mage.fire.icyveins, rm.tbc.mage.fire.wowhead and
-- rm.tbc.mage.arcane. A content change needs a block revision bump, every consumer's pin
-- and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id,anyrank)return{type='BUFF',unit='player',spell=id,anyrank=anyrank}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
-- Casts, channels (Missiles, Blizzard, Evocation) and a target that is not ours to pull end advice.
assert(addon:RegisterDefaultBlock({id='tbc.mage.boundaries',revision=1,families={'tbc'},class='MAGE',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
 stop('target',negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}))))),
}}))
-- Frostbolt is the filler once learned (level 4); Fireball only before that.
assert(addon:RegisterDefaultBlock({id='tbc.mage.frostbolt',revision=1,families={'tbc'},class='MAGE',steps={
 {id='frostbolt-known',type='branch',conditions=known(116),onTrue={spell('frostbolt',116)},onFalse={spell('fireball',133)}},
}}))
-- Out of spells: wand, never toggling an active wand off; casters never melee.
assert(addon:RegisterDefaultBlock({id='tbc.mage.wand-finish',revision=1,families={'tbc'},class='MAGE',steps={
 {id='wand-known',type='branch',conditions=known(5019),onFalse={},onTrue={
  stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  spell('shoot',5019)}},
 stop('exhausted'),
}}))
-- Instants while moving (Fire and Arcane): Fire Blast, then Ice Lance.
assert(addon:RegisterDefaultBlock({id='tbc.mage.moving-fire-blast',revision=1,families={'tbc'},class='MAGE',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={spell('fire-blast',2136),spell('ice-lance',30455),stop('moving-stop')}},
}}))
-- Fire AoE: Blast Wave and Dragon's Breath when ready, Flamestrike when its burn is not on the target.
assert(addon:RegisterDefaultBlock({id='tbc.mage.fire-aoe',revision=1,families={'tbc'},class='MAGE',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('blast-wave',11113),spell('dragons-breath',31661),
  spell('flamestrike',2120,negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true}))}},
}}))
-- Improved Scorch (Fire talent 10) keeps five Fire Vulnerability stacks, refreshed before 5.5 s.
assert(addon:RegisterDefaultBlock({id='tbc.mage.improved-scorch',revision=1,families={'tbc'},class='MAGE',steps={
 spell('scorch',2948,all({type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1},
  any(negate({type='DEBUFF',unit='target',spell=22959}),
   {type='DEBUFF_STACKS',unit='target',spell=22959,operator='LESSTHAN',value=5},
   {type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHAN',value=5.5}))),
}}))
-- Armor: any armor already up is the player's choice. With none up and learning readable,
-- offer the preferred learned armor; an unready preferred armor never licenses a lower one.
local function missing(id)return negate(buff(id,true))end
local function readable(id)return any(known(id),negate(known(id)))end
local function armor(...)return all(missing(168),missing(7302),missing(6117),missing(30482),
 readable(168),readable(7302),readable(6117),...)end
assert(addon:RegisterDefaultBlock({id='tbc.mage.armor',revision=1,families={'tbc'},class='MAGE',steps={
 spell('mage-armor',6117,armor(known(6117))),
 spell('ice-armor',7302,armor(negate(known(6117)),known(7302))),
 spell('frost-armor',168,armor(negate(known(6117)),negate(known(7302)),known(168))),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.mage.armor-molten',revision=1,families={'tbc'},class='MAGE',steps={
 spell('molten-armor',30482,armor(readable(30482),known(30482))),
 spell('mage-armor',6117,armor(readable(30482),negate(known(30482)),known(6117))),
 spell('ice-armor',7302,armor(readable(30482),negate(known(30482)),negate(known(6117)),known(7302))),
 spell('frost-armor',168,armor(readable(30482),negate(known(30482)),negate(known(6117)),negate(known(7302)),known(168))),
}}))
-- Independent reminders shared by every Mage premade. Talent cooldowns need the talent
-- learned (native readiness), so a spec that lacks one never sees it.
local lust=any(buff(2825),buff(32182))
assert(addon:RegisterDefaultBlock({id='tbc.mage.upkeep',revision=1,families={'tbc'},class='MAGE',steps={
 spell('intellect',1459,all(negate(combat()),missing(1459),missing(23028))),
 {id='mana-gem',type='item',action={22044,8008,8007,5513,5514},conditions=all(combat(),mana('LESSTHAN',.75))},
 spell('evocation',12051,all(combat(),mana('LESSTHAN',.2),negate(buff(12042)),negate(buff(12472)),negate(lust))),
 spell('counterspell',2139,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('spellsteal',30449,{type='STEALABLE',unit='target'}),
 spell('remove-curse',475,all({type='FRIENDLY',unit='target'},{type='DISPELLABLE',unit='target',debufftype='Curse'})),
 spell('ice-barrier',11426,all(negate(buff(11426,true)),any(negate(combat()),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.6}))),
 spell('mana-shield',1463,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},missing(1463),missing(11426))),
 spell('icy-veins',12472,all(combat(),negate(buff(12472)))),
 spell('cold-snap',11958,all(combat(),negate(buff(12472)),{type='SPELL_COOLDOWN',spell=12472,operator='GREATERTHAN',value=20})),
 spell('water-elemental',31687,all(combat(),negate({type='PET'}))),
 spell('arcane-power',12042,all(combat(),mana('GREATERTHAN',.4))),
 spell('presence-of-mind',12043,all(combat(),any(buff(12042),{type='MOVING'}))),
 spell('combustion',11129,all(combat(),any({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},
  {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=200}))),
}}))
