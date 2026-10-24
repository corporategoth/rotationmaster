-- Season of Discovery Mage healer (Arcane or Frost, Temporal Beacon), levels 1–60, chosen when
-- Regeneration or Mass Regeneration is engraved. On a friendly target: Rewind Time and Chronostatic
-- Preservation below half health, Regeneration where your beacon is missing, Mass Regeneration,
-- Temporal Anomaly, then stop. On an enemy: damage that heals through the beacons, Spellfrost Bolt
-- for Frost healers, else Arcane Missiles on Missile Barrage, Arcane Barrage at two Arcane Blast
-- stacks, Balefire Bolt when safe (never at four of its stacks), Arcane Blast. Mass Regeneration's
-- channel is not protected: the next spell shows at once, so cancel it as Wowhead advises (its
-- direct healing is negligible). Whom to heal stays with the player.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function hp(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-sheal-'
local combat={type='COMBAT',unit='player'}
local beacon={type='BUFF',unit='target',spell=400735,ownbuff=true}
local fingers=any(buff(400647),buff(400669),buff(400670))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.healer',revision=4,
 blocks={['era.mage.wand-finish']=1,['sod.mage.balefire']=1,['sod.mage.armor']=2,['sod.mage.upkeep']=2},
 nameKey='Default.SoD.Mage.Healer.Name',descriptionKey='Default.SoD.Mage.Healer.Description',
 applicability={families={'era'},actionContext='player',class='MAGE',rulesets={'season:2'}},
 tags={'arcane','healer','group','season-of-discovery'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/arcane-mage-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Arcane Mage healer rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/healer-overview',title='Wowhead: SoD Mage healer overview (Phase 7)',reviewedAt='2026-10-23',revision='2025-01-30'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/mage/healer-talent-builds-runes',title='Wowhead: SoD Mage healer runes (Phase 7)',reviewedAt='2026-10-23',revision='2025-01-30'},
 },
 body={
  priority=105,
  switch=any({type='RUNE_ENGRAVED',spell=412510},{type='RUNE_ENGRAVED',spell=401417}),
  cooldowns={block(P..'armor','sod.mage.armor',P),
   spell(P..'arcane-power',12042,combat),
   spell(P..'presence-of-mind',12043,combat),
   spell(P..'frozen-orb',440802,combat),
   block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   stop(P..'cast',any({type='CASTING',unit='player'},all({type='CHANNELING',unit='player'},negate({type='CHANNELING_SPELL',unit='player',spell=412510})))),
   {id=P..'friend',type='branch',conditions={type='FRIENDLY',unit='target'},onFalse={},onTrue={
    spell(P..'rewind-time',401462,all(beacon,hp('LESSTHAN',.5))),
    spell(P..'chronostatic',436516,hp('LESSTHAN',.5)),
    spell(P..'regeneration',401417,negate(beacon)),
    spell(P..'mass-regeneration',412510,any(negate(beacon),hp('LESSTHAN',.9))),
    spell(P..'temporal-anomaly',428885),
    stop(P..'friend-stop')}},
   stop(P..'target',negate(all({type='ATTACKABLE',unit='target'},any(combat,negate({type='COMBAT',unit='target'}))))),
   {id=P..'pull',type='branch',conditions=combat,onTrue={},onFalse={
    spell(P..'pull-spellfrost',412532),spell(P..'pull-arcane-blast',400574),stop(P..'pull-stop')}},
   -- Optional raw damage on packs; it converts far less healing.
   {id=P..'explosion',type='spell',action=1449,ranked=false,disabled=true,conditions={type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3}},
   {id=P..'frost',type='branch',conditions={type='RUNE_ENGRAVED',spell=412532},onFalse={},onTrue={
    {id=P..'frost-ice-lance',type='spell',action=400640,ranked=false,disabled=true,conditions=fingers},
    {id=P..'frost-deep-freeze',type='spell',action=428739,ranked=false,disabled=true,conditions=fingers},
    spell(P..'frost-spellfrost',412532),stop(P..'frost-stop')}},
   spell(P..'missile-barrage',5143,buff(400589)),
   spell(P..'barrage',400610,{type='BUFF_STACKS',unit='player',spell=400573,operator='GREATERTHANOREQUALS',value=2}),
   block(P..'balefire','sod.mage.balefire',P),
   spell(P..'arcane-blast',400574),
   spell(P..'fireball',133),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
