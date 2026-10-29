-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Mage Fire (Phase 8 runes, Phase 7 sources), levels 1–60, and the SoD Mage
-- default (lowest SoD priority; above every vanilla premade). Adapts by engraved runes: Hot Streak
-- Pyroblast at once; Living Bomb kept up; Improved Scorch topped up below two stacks (Living Bomb
-- stacks the rest); Living Flame on cooldown; Balefire Bolt at five Fire Vulnerability stacks and
-- never at four of its own stacks or more; Frostfire Bolt, else Fireball. Overheat's Fire Blast and
-- Combustion are reminders. Target switching for Living Bomb spread stays with the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-sfire-'
local scorchTalent={type='TALENT',layout='tree',tree=2,talent=10,operator='GREATERTHANOREQUALS',value=1}
local balefireStack=any({type='BUFF',unit='player',spell=428878},{type='DEBUFF',unit='player',spell=428878})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.fire',revision=6,
 blocks={['era.mage.boundaries']=3,['era.mage.wand-finish']=2,['sod.mage.balefire']=1,['sod.mage.balefire-scorched']=1,
  ['sod.mage.living-bomb']=1,['sod.mage.overheat']=2,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 nameKey='Default.SoD.Mage.Fire.Name',descriptionKey='Default.SoD.Mage.Fire.Description',
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'fire','leveling','raid','single-target','aoe','season-of-discovery'},
 sources={

  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/dps-talent-builds-runes',title='Wowhead: SoD Mage DPS runes (Phase 7)',reviewedAt='2026-10-23',revision='2025-02-07'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/dps-overview',title='Wowhead: SoD Mage DPS overview (Phase 7)',reviewedAt='2026-10-23',revision='2025-01-30'},
  {url='https://www.icy-veins.com/wow-classic/fire-mage-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Fire Mage rotation (Phase 6)',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://www.icy-veins.com/wow-classic/fire-mage-dps-season-of-discovery-leveling',title='Icy Veins: SoD Fire Mage leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
 },
 body={
  priority=101,
  cooldowns={block(P..'armor','sod.mage.armor',P),block(P..'overheat','sod.mage.overheat',P),
   spell(P..'combustion',11129,all({type='COMBAT',unit='player'},{type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=5},
    any(balefireStack,negate({type='RUNE_ENGRAVED',spell=428878})))),
   block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    block(P..'pull-balefire','sod.mage.balefire',P..'pull-'),spell(P..'pull-pyroblast',11366),
    spell(P..'pull-frostfire',401502),spell(P..'pull-fireball',133),stop(P..'pull-stop')}},
   spell(P..'hot-streak',11366,all({type='BUFF',unit='player',spell=48108},negate({type='BUFF',unit='player',spell=28682}))),
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell(P..'moving-living-bomb',400613,negate(own(400613))),spell(P..'moving-living-flame',401556),
    spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-living-flame',401556),
    spell(P..'aoe-living-bomb',400613,negate(own(400613))),
    spell(P..'aoe-blast-wave',11113,near(2)),
    spell(P..'aoe-cone',120,near(2)),
    spell(P..'aoe-flamestrike',2120,negate(own(2120))),
    spell(P..'aoe-blizzard',10)}},
   block(P..'living-bomb','sod.mage.living-bomb',P),
   spell(P..'scorch',2948,all(scorchTalent,any(negate({type='DEBUFF_STACKS',unit='target',spell=22959,operator='GREATERTHANOREQUALS',value=2}),
    {type='DEBUFF_REMAIN',unit='target',spell=22959,operator='LESSTHANOREQUALS',value=3}))),
   spell(P..'living-flame',401556),
   block(P..'balefire','sod.mage.balefire-scorched',P),
   spell(P..'frostfire',401502),
   spell(P..'fireball',133),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
