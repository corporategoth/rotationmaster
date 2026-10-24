-- Shared WoW Forever Mage blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.mage.frost, rm.forever.mage.fire, rm.forever.mage.fire.icyveins and
-- rm.forever.mage.arcane. A content change needs a block revision bump, every consumer's pin and
-- revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local fingers=any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
-- Fingers of Frost while a Frostbolt is still casting: Ice Lance now (cancel, or batch it as the
-- bolt lands; the guides differ, the highlight serves both).
assert(addon:RegisterDefaultBlock({id='forever.mage.lance-batch',revision=1,families={'forever'},class='MAGE',steps={
 spell('lance-batch',1312002,all({type='CASTING',unit='player'},fingers)),
}}))
-- Casts and channels (Missiles, Blizzard, Evocation) and a target that is not attackable end advice.
assert(addon:RegisterDefaultBlock({id='forever.mage.boundaries',revision=2,families={'forever'},class='MAGE',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))),
}}))
-- Frostbolt once learned (level 4); Fireball only before it.
assert(addon:RegisterDefaultBlock({id='forever.mage.frostbolt',revision=1,families={'forever'},class='MAGE',steps={
 spell('frostbolt',116),
 spell('fireball',133,negate(known(116))),
}}))
-- Solo with no spell castable before it (mana is secret on Forever; an unaffordable spell is not
-- ready): wand, never toggling an active wand off. Casters never melee.
assert(addon:RegisterDefaultBlock({id='forever.mage.wand',revision=2,families={'forever'},class='MAGE',steps={
 {id='wand',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  spell('shoot',5019)}},
 stop('exhausted'),
}}))
-- Fire on the move: Fire Blast, then Ice Lance for a Frost-dipping hybrid.
assert(addon:RegisterDefaultBlock({id='forever.mage.fire-moving',revision=1,families={'forever'},class='MAGE',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-fire-blast',2136),spell('moving-ice-lance',1312002),stop('moving-stop')}},
}}))
-- Fire packs (four or more fighting you): Flamestrike unless your burn is already down (it no longer
-- stacks), Blast Wave, Arcane Explosion.
assert(addon:RegisterDefaultBlock({id='forever.mage.fire-aoe',revision=1,families={'forever'},class='MAGE',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  spell('aoe-flamestrike',2120,negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
  spell('aoe-blast-wave',11113),
  spell('aoe-arcane-explosion',1449)}},
}}))
-- Independent reminders for every Mage premade. Armor: none of Frost, Ice or Mage Armor up, then
-- Ice (Frost before 30) solo and Mage Armor in a group; an armor already up is your choice. Mana is
-- secret on Forever, so Evocation is the player's call.
local bare=all(negate(buff(168)),negate(buff(7302)),negate(buff(6117)))
local group={type='GROUP'}
assert(addon:RegisterDefaultBlock({id='forever.mage.upkeep',revision=2,families={'forever'},class='MAGE',steps={
 spell('intellect',1459,all(negate(combat()),negate(buff(1459)),negate(buff(23028)))),
 spell('mage-armor',6117,all(bare,group)),
 spell('ice-armor',7302,all(bare,any(negate(group),negate(known(6117))))),
 spell('frost-armor',168,all(bare,negate(known(7302)),any(negate(group),negate(known(6117))))),
 spell('ice-barrier',11426,negate(buff(11426))),
 spell('counterspell',2139,{type='CAST_INTERRUPTABLE',unit='target'}),
 spell('remove-curse',475,{type='DISPELLABLE',unit='player',debufftype='Curse'}),
 spell('frost-nova',122,all(combat(),{type='DISTANCE',unit='target',value=8},negate({type='CLASSIFICATION',unit='target',value='worldboss'}))),
}}))
