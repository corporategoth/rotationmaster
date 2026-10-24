-- Retail (Midnight) Protection Paladin, Wowhead: a reference, disabled by default. Judgment on
-- cooldown, Shield of the Righteous, Avenger's Shield, Divine Toll, Blessed Hammer or Hammer of the
-- Righteous, and Consecration only as the filler. Health is secret on Retail, so Word of Glory below
-- half health is left to you. Divine Toll only at 0 Holy Power, as Wowhead says (Holy Power
-- is never secret for the player in Midnight).
local _,addon=...
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.protection.wowhead',revision=5,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2,['retail.paladin.prot-defensives']=2,['retail.paladin.prot-cooldowns']=1},
 nameKey='Default.Retail.Paladin.Protection.Wowhead.Name',descriptionKey='Default.Retail.Paladin.Protection.Wowhead.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'protection','tank','reference','single-target','aoe','wowhead'},
 sources={
  {url='https://www.wowhead.com/guide/classes/paladin/protection/rotation-cooldowns-pve-tank',title='Wowhead: Protection Paladin rotation (Season 2)',reviewedAt='2026-10-23',revision='2026-08-12',notes='Divine Toll at 0 Holy Power.'},
 },
 body={priority=4,disabled=true,switch={type='SPECIALIZATION',spec=66},
  cooldowns={
   block('retail.paladin.upkeep','protwh-'),
   block('retail.paladin.prot-cooldowns','protwh-'),
   block('retail.paladin.prot-defensives','protwh-'),
  },
  rotation={
   block('retail.paladin.boundaries','protwh-'),
   spell('protwh-judgment',275779),
   spell('protwh-shield-of-the-righteous',53600),
   spell('protwh-avengers-shield',31935),
   spell('protwh-divine-toll',375576,{type='POINT',unit='player',operator='EQUALS',value=0}),
   spell('protwh-blessed-hammer',204019),
   spell('protwh-hammer-of-the-righteous',53595),
   spell('protwh-consecration',26573),
  },
 },
}))
