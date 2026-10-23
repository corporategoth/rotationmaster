-- Season of Discovery Mage Arcane damage (Icy Veins, with the current five-stack Balefire rule),
-- levels 10–60 with Arcane as the main tree and Arcane Blast engraved. Arcane Missiles on Missile
-- Barrage; Arcane Barrage at four Arcane Blast stacks; Balefire Bolt when safe (never at four of its
-- stacks); Living Flame on cooldown; Arcane Blast filler. Arcane Barrage and Fire Blast while moving;
-- Living Flame and Arcane Explosion on packs. Arcane Power, Presence of Mind and Icy Veins are reminders.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function class(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local P='mage-sarcane-'
local combat={type='COMBAT',unit='player'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.mage.arcane',revision=1,
 blocks={['era.mage.boundaries']=1,['era.mage.wand-finish']=1,['sod.mage.balefire']=1,['sod.mage.armor']=1,['sod.mage.upkeep']=1},
 nameKey='Default.SoD.Mage.Arcane.Name',descriptionKey='Default.SoD.Mage.Arcane.Description',
 applicability={families={'era'},actionContext='player',class='MAGE',minLevel=10,maxLevel=60,rulesets={'season:2'}},
 tags={'arcane','raid','single-target','aoe','season-of-discovery','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/arcane-mage-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Arcane Mage rotation (Phase 4)',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/mage/apls/p4_arcane.apl.json',title='wowsims/sod Phase 4 Arcane APL (Balefire stack limit)',reviewedAt='2026-10-23',revision='0e3f6ef'},
 },
 body={
  priority=104,
  -- Known spell first, so a character with no talent points is a clean no-match.
  switch=all({type='SPELL_KNOWN',spell=400574},{type='PRIMARY_TALENT_TREE',tree=1}),
  cooldowns={block(P..'armor','sod.mage.armor',P),
   spell(P..'arcane-power',12042,all(combat,any(class('elite'),class('rareelite'),class('worldboss'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=15}))),
   spell(P..'presence-of-mind',12043,all(combat,any({type='BUFF',unit='player',spell=12042},{type='MOVING'}))),
   block(P..'upkeep','sod.mage.upkeep',P)},
  rotation={
   block(P..'boundaries','era.mage.boundaries',P),
   {id=P..'pull',type='branch',conditions=negate(combat),onFalse={},onTrue={spell(P..'pull-arcane-blast',400574),stop(P..'pull-stop')}},
   {id=P..'moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell(P..'moving-barrage',400610),spell(P..'moving-fire-blast',2136),stop(P..'moving-stop')}},
   {id=P..'aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell(P..'aoe-living-flame',401556),
    spell(P..'aoe-explosion',1449,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3})}},
   spell(P..'missile-barrage',5143,{type='BUFF',unit='player',spell=400589}),
   spell(P..'barrage',400610,{type='BUFF_STACKS',unit='player',spell=400573,operator='GREATERTHANOREQUALS',value=4}),
   block(P..'balefire','sod.mage.balefire',P),
   spell(P..'living-flame',401556),
   spell(P..'arcane-blast',400574),
   block(P..'finish','era.mage.wand-finish',P),
  },
 },
}))
