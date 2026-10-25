-- WoW Forever Frost Mage, levels 1–60, and the Mage catch-all (lowest priority): every Mage before
-- a talent spell (levels 1–19) and Missile-Barrage-only builds level here. Icy Veins' Frost order
-- with Warcraft Tavern's Missile Barrage rule: Ice Lance on Fingers of Frost or a frozen target,
-- Cone of Cold at five Winter's Chill, Arcane Missiles on Barrage, Frostbolt. Instants first while
-- moving. AoE on three or more fighting you: Cone of Cold; Blizzard (Arcane Explosion with a mob on
-- you) from five. Warcraft Tavern's Flamestrike/Explosion AoE is in the AoE branch, off by default.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local fingers=any({type='BUFF',unit='player',spell=400669},{type='BUFF',unit='player',spell=400670})
local frozen=any({type='DEBUFF',unit='target',spell=122,anyrank=true},{type='DEBUFF',unit='target',spell=12494})
local barrage=any({type='BUFF',unit='player',spell=400589},{type='BUFF',unit='player',spell=1326083})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.mage.frost',revision=6,
 blocks={['forever.mage.lance-batch']=1,['forever.mage.boundaries']=3,['forever.mage.frostbolt']=1,['forever.mage.wand']=3,['forever.mage.upkeep']=2},
 nameKey='Default.Forever.Mage.Frost.Name',descriptionKey='Default.Forever.Mage.Frost.Description',
 applicability={families={'forever'},actionContext='player',class='MAGE'},
 tags={'frost','leveling','single-target','aoe','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-forever/frost-mage-ranged-dps-pve-guide',title='Icy Veins: Forever Frost Mage PvE',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.icy-veins.com/wow-forever/frost-mage-leveling',title='Icy Veins: Forever Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-10-16'},
  {url='https://www.warcrafttavern.com/forever/guides/frost-mage/',title='Warcraft Tavern: Forever Frost Mage',reviewedAt='2026-10-23',notes='Missile Barrage on every proc; the optional Flamestrike/Explosion AoE.'},
  {url='https://www.wowhead.com/forever/guide/classes/mage/frost/level-30-dps-overview',title='Wowhead: Forever level 30 Frost Mage',reviewedAt='2026-10-23',revision='2026-10-09'},
  {url='https://www.warcrafttavern.com/forever/news/scrolls-totems-mage-shaman-deep-dive-for-wow-forever/',title='Blizzard Mage and Shaman deep dive (as published by Warcraft Tavern)',reviewedAt='2026-10-23',revision='2026-10-07',notes='Mechanics only (Winter\'s Chill, Fingers of Frost); no priority.'},
  {url='https://github.com/simulationcraft/simc/blob/forever/SpellDataDump/mage.txt',title='SimulationCraft Forever spell data (1.60.1.70425)',reviewedAt='2026-10-23',revision='4dd64b4a21',notes='Spell IDs, ranks and auras only.'},
 },
 body={priority=10,
  cooldowns={
   block('frost-upkeep','forever.mage.upkeep','frost-'),
   spell('frost-cold-snap',12472,all(combat(),{type='SPELL_COOLDOWN',spell=122,operator='GREATERTHAN',value=2},{type='DISTANCE',unit='target',value=8})),
  },
  rotation={
   block('frost-lance-batch','forever.mage.lance-batch','frost-'),
   block('frost-boundaries','forever.mage.boundaries','frost-'),
   {id='frost-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    block('frost-pull-filler','forever.mage.frostbolt','frost-pull-'),stop('frost-pull-stop')}},
   spell('frost-fingers-lance',1312002,fingers),
   spell('frost-frozen-lance',1312002,frozen),
   spell('frost-chill-cone',120,all({type='DEBUFF_STACKS',unit='target',spell=12579,owndebuff=true,operator='GREATERTHANOREQUALS',value=5},{type='DISTANCE',unit='target',value=10})),
   {id='frost-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('frost-moving-lance',1312002),spell('frost-moving-fire-blast',2136),stop('frost-moving-stop')}},
   spell('frost-missiles',5143,barrage),
   {id='frost-aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={
    off('frost-aoe-tavern-flamestrike',2120,negate({type='DEBUFF',unit='target',spell=2120,anyrank=true,owndebuff=true})),
    off('frost-aoe-tavern-explosion',1449),
    spell('frost-aoe-cone',120),
    {id='frost-aoe-five',type='branch',conditions=engaged(5),onFalse={},onTrue={
     {id='frost-aoe-close',type='branch',conditions={type='BEYOND_MELEE',unit='target'},
      onTrue={spell('frost-aoe-blizzard',10)},onFalse={spell('frost-aoe-explosion',1449)}}}}}},
   block('frost-filler','forever.mage.frostbolt','frost-'),
   block('frost-wand','forever.mage.wand','frost-'),
  },
 },
}))
