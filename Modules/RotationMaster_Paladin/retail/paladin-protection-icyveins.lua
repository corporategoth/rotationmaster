-- Retail (Midnight) Protection Paladin, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because the Consecration, Vanguard and Shining Light buffs it
-- reads are hidden in Midnight combat. Consecration before the pull; Divine Toll, Hammer of Light,
-- Consecration when you are not standing in it, Avenger's Shield with Vanguard, Shield of the
-- Righteous at 3+ Holy Power (never secret for the player in Midnight), Hammer of Wrath, Judgment,
-- Blessed Hammer or Hammer of the Righteous, Avenger's Shield, Word of Glory with Shining Light,
-- Consecration as the filler.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.protection.icyveins',revision=7,
 blocks={['retail.paladin.boundaries']=2,['retail.paladin.upkeep']=2,['retail.paladin.prot-defensives']=2,['retail.paladin.prot-cooldowns']=1},
 nameKey='Default.Retail.Paladin.Protection.IcyVeins.Name',descriptionKey='Default.Retail.Paladin.Protection.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'protection','tank','reference','single-target','aoe','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/protection-paladin-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Protection Paladin rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Shield of the Righteous at 3 to 5 Holy Power.'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/paladin_protection.simc',title='SimulationCraft: Protection Paladin default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={66},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('retail.paladin.upkeep','protiv-'),
   block('retail.paladin.prot-cooldowns','protiv-'),
   block('retail.paladin.prot-defensives','protiv-'),
  },
  rotation={
   block('retail.paladin.boundaries','protiv-'),
   {id='protiv-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('protiv-pull-consecration',26573),
    {id='protiv-pull-stop',type='stop',suppress_attack=false,conditions={}},
   }},
   spell('protiv-divine-toll',375576),
   spell('protiv-hammer-of-light',427453),
   spell('protiv-consecration-missing',26573,negate(own(188370))),
   spell('protiv-vanguard',31935,own(1268810)),
   spell('protiv-shield-of-the-righteous',53600,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3}),
   spell('protiv-hammer-of-wrath',24275),
   spell('protiv-judgment',275779),
   spell('protiv-blessed-hammer',204019),
   spell('protiv-hammer-of-the-righteous',53595),
   spell('protiv-avengers-shield',31935),
   spell('protiv-shining-light',85673,own(327510)),
   spell('protiv-consecration',26573),
  },
 },
}))
