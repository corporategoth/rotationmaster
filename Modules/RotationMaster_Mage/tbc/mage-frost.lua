-- TBC Mage Frost, levels 1–70, and the default for an unspecced Mage (lowest priority, so the
-- talent-specific Mage premades win when their tree is primary). Adapts by learned spells:
-- Fireball until Frostbolt, Ice Lance from 66, talents as learned. Enemy count is the number of
-- enemies you are engaged with (THREAT_COUNT), because TBC range checks cannot tell 8 from 20
-- yards in combat. Blink, kiting, Ice Block and positioning stay with the player.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='stop',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local frozen=any({type='DEBUFF',unit='target',spell=122,anyrank=true},{type='DEBUFF',unit='target',spell=33395},{type='DEBUFF',unit='target',spell=12494})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.frost',revision=5,
 blocks={['tbc.mage.boundaries']=3,['tbc.mage.frostbolt']=1,['tbc.mage.wand-finish']=2,['tbc.mage.armor']=1,['tbc.mage.upkeep']=1},
 nameKey='Default.TBC.Mage.Frost.Name',descriptionKey='Default.TBC.Mage.Frost.Description',
 applicability={families={'tbc'},actionContext='player',class='MAGE'},
 tags={'frost','leveling','raid','single-target','aoe'},
 sources={
  {url='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide',title='Icy Veins: Frost single-target Mage leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/frost-aoe-mage-leveling-guide',title='Icy Veins: Frost AoE Mage leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/frost-mage-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Frost Mage rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/mage/frost/leveling-tips',title='Wowhead: Frost Mage leveling',reviewedAt='2026-10-23',revision='2026-01-04'},
  {url='https://www.wowhead.com/tbc/guide/frost-aoe-mage-leveling-outland-farming-guide-burning-crusade-classic',title='Wowhead: Frost AoE grinding',reviewedAt='2026-10-23',revision='2026-01-08'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-frost-mage-rotation-cooldowns-abilities/',title='Warcraft Tavern: Frost Mage PvE rotation',reviewedAt='2026-10-23'},
  {url='https://github.com/kaminaris/MaxDps-Mage/tree/886c8e27f48e38e0f9b8c22cf56b5e625dfce3f0/Specialization/TBC',title='MaxDps-Mage TBC Frost module',reviewedAt='2026-10-23',revision='886c8e2'},
  {url='https://github.com/wowsims/tbc/blob/3301fca59306a747e521274c36e073e69acc7b77/sim/mage/rotations.go',title='wowsims TBC Mage rotations',reviewedAt='2026-10-23',revision='3301fca'},
 },
 body={
  switch={type='SPELL_KNOWN',spell=133},
  cooldowns={block('mage-frost-armor','tbc.mage.armor','mage-frost-'),block('mage-frost-upkeep','tbc.mage.upkeep','mage-frost-')},
  rotation={
   block('mage-frost-boundaries','tbc.mage.boundaries','mage-frost-'),
   {id='mage-frost-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    block('mage-frost-pull-filler','tbc.mage.frostbolt','mage-frost-pull-'),stop('mage-frost-pull-stop')}},
   {id='mage-frost-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('mage-frost-moving-ice-lance',30455),spell('mage-frost-moving-fire-blast',2136),stop('mage-frost-moving-stop')}},
   -- Something is hitting you: Frost Nova it off (bosses are root-immune).
   spell('mage-frost-nova',122,{type='AND',value={{type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=1},
    negate({type='CLASSIFICATION',unit='target',value='worldboss'})}}),
   {id='mage-frost-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('mage-frost-cone',120),
    {id='mage-frost-aoe-frozen',type='branch',conditions=frozen,
     onTrue={spell('mage-frost-blizzard',10)},onFalse={spell('mage-frost-explosion',1449)}}}},
   spell('mage-frost-ice-lance',30455,frozen),
   block('mage-frost-filler','tbc.mage.frostbolt','mage-frost-'),
   block('mage-frost-finish','tbc.mage.wand-finish','mage-frost-'),
  },
 },
}))
