-- Season of Discovery Mage Frost (Phase 8 runes, Phase 7 sources), levels 10–60 with Frost as the
-- main tree. Fingers of Frost goes into Ice Lance at three or more of your Glaciate stacks, else Deep
-- Freeze; Balefire Bolt on a Brain Freeze proc and otherwise when safe (never at four of its stacks);
-- Living Bomb and Living Flame when engraved; Spellfrost Bolt, else Frostfire Bolt, else Frostbolt.
-- Frozen Orb, Icy Veins and Cold Snap are reminders. The spell-queue "double dip" stays with you.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function near(n)return{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=n}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-sfrost-'
-- Fingers of Frost: wowsims names the proc 400647, the client may show 400669/400670.
local fingers=any(buff(400647),buff(400669),buff(400670))
local function fingersStacks(n)return any({type='BUFF_STACKS',unit='player',spell=400647,operator='GREATERTHANOREQUALS',value=n},
 {type='BUFF_STACKS',unit='player',spell=400669,operator='GREATERTHANOREQUALS',value=n},{type='BUFF_STACKS',unit='player',spell=400670,operator='GREATERTHANOREQUALS',value=n})end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.frost',revision=3,
 blocks={['era.mage.boundaries']=1,['era.mage.wand-finish']=1,['sod.mage.balefire']=1,['sod.mage.balefire-brain-freeze']=1,
  ['sod.mage.living-bomb']=1,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 nameKey='Default.SoD.Mage.Frost.Name',descriptionKey='Default.SoD.Mage.Frost.Description',
 applicability={families={'era'},actionContext='player',class='MAGE',minLevel=10,maxLevel=60,rulesets={'season:2'}},
 tags={'frost','raid','single-target','aoe','season-of-discovery'},
 sources={
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/mage/builds/p7_frost.build.json',title='wowsims/sod Phase 7 Frost build',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/dps-talent-builds-runes',title='Wowhead: SoD Mage DPS runes (Phase 7)',reviewedAt='2026-10-23',revision='2025-02-07'},
  {url='https://www.icy-veins.com/wow-classic/frost-mage-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Frost Mage rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={
  priority=103,
  switch={type='PRIMARY_TALENT_TREE',tree=3},
  cooldowns={block(P..'armor','sod.mage.armor',P),
   spell(P..'frozen-orb',440802,all({type='COMBAT',unit='player'},negate(fingersStacks(2)))),
   block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell(P..'pull-spellfrost',412532),spell(P..'pull-frostfire',401502),spell(P..'pull-frostbolt',116),stop(P..'pull-stop')}},
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell(P..'moving-ice-lance',400640,fingers),spell(P..'moving-frozen-orb',440802),
    spell(P..'moving-living-bomb',400613,negate(own(400613))),spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-frozen-orb',440802),
    spell(P..'aoe-living-flame',401556),
    spell(P..'aoe-living-bomb',400613,negate(own(400613))),
    spell(P..'aoe-blizzard',10),
    spell(P..'aoe-cone',120,near(2))}},
   spell(P..'ice-lance',400640,all(fingers,{type='DEBUFF_STACKS',unit='target',spell=1218345,owndebuff=true,operator='GREATERTHANOREQUALS',value=3})),
   spell(P..'deep-freeze',428739,fingers),
   block(P..'balefire-proc','sod.mage.balefire-brain-freeze',P),
   block(P..'living-bomb','sod.mage.living-bomb',P),
   spell(P..'living-flame',401556),
   block(P..'balefire','sod.mage.balefire',P),
   spell(P..'spellfrost',412532),
   spell(P..'frostfire',401502),
   spell(P..'frostbolt',116),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
