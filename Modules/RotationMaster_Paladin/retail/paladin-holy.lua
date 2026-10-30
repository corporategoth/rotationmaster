-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Holy Paladin, Icy Veins (with Wowhead's damage order on an enemy). RM picks a
-- spell, not a target, and every unit's health is hidden in Midnight combat, so this keeps the
-- Holy Power economy going on whatever you target and leaves triage to you. Holy Power is never
-- secret for the player, so the guides' spending points hold. Friendly target: Eternal Flame or
-- Word of Glory at 5 Holy Power, Flash of Light on Infusion of Light, Holy Shock, Eternal Flame or
-- Word of Glory at 3+, Holy Light, Flash of Light. Enemy: Shield of the Righteous at 5, Holy Shock,
-- Shield of the Righteous at 3+, Judgment, Crusader Strike, Consecration. Light of Dawn stays
-- manual: Icy Veins casts it when Word of Glory would overheal or with Empyrean Legacy, neither
-- readable. Reminders: Divine Toll, Holy Prism, Holy Bulwark or Sacred Weapon and Beacon of
-- Virtue on cooldown in combat, aura, Rebuke, Divine Protection, Lay on Hands. The friendly test
-- is guarded by "target level above 0", which is false (not unavailable) without a target.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function holyPower(v)return{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=v}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.holy',revision=7,
 blocks={['retail.paladin.upkeep']=2},
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'holy','healer','reference','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/holy-paladin-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Holy Paladin healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Spend Holy Power at 5 before Infusion of Light and Holy Shock; spend again after them.'},
  {url='https://www.wowhead.com/guide/classes/paladin/holy/rotation-cooldowns-pve-healer',title='Wowhead: Holy Paladin rotation',reviewedAt='2026-10-23',revision='2026-08-18',notes='Damage order on an enemy target: Shield of the Righteous at 5 Holy Power, Holy Shock, Shield of the Righteous, Crusader Strike.'},
 },
 body={priority=10,specs={65},
  cooldowns={
   block('retail.paladin.upkeep','holy-'),
   BuiltinConditions.spell('holy-divine-toll',375576,BuiltinConditions.combat()),
   BuiltinConditions.spell('holy-holy-prism',114165,BuiltinConditions.combat()),
   BuiltinConditions.spell('holy-holy-bulwark',432459,BuiltinConditions.combat()),
   BuiltinConditions.spell('holy-sacred-weapon',432472,BuiltinConditions.combat()),
   BuiltinConditions.spell('holy-beacon-of-virtue',200025,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='target'})),
   BuiltinConditions.spell('holy-divine-protection',498,BuiltinConditions.combat()),
  },
  rotation={
   {id='holy-casting',type='stop',suppress_attack=false,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='holy-friendly',type='branch',conditions=BuiltinConditions.all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    BuiltinConditions.spell('holy-eternal-flame-capped',156322,holyPower(5)),
    BuiltinConditions.spell('holy-word-of-glory-capped',85673,holyPower(5)),
    BuiltinConditions.spell('holy-infusion',19750,BuiltinConditions.ownBuff(54149)),
    BuiltinConditions.spell('holy-shock',20473),
    BuiltinConditions.spell('holy-eternal-flame',156322,holyPower(3)),
    BuiltinConditions.spell('holy-word-of-glory',85673,holyPower(3)),
    BuiltinConditions.spell('holy-light',82326),
    BuiltinConditions.spell('holy-flash-of-light',19750),
    {id='holy-friendly-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   {id='holy-no-target',type='stop',suppress_attack=true,conditions=BuiltinConditions.negate({type='ATTACKABLE',unit='target'})},
   BuiltinConditions.spell('holy-shield-of-the-righteous-capped',415091,holyPower(5)),
   BuiltinConditions.spell('holy-shock-enemy',20473),
   BuiltinConditions.spell('holy-shield-of-the-righteous',415091,holyPower(3)),
   BuiltinConditions.spell('holy-judgment',275773),
   BuiltinConditions.spell('holy-crusader-strike',35395),
   BuiltinConditions.spell('holy-consecration',26573),
  },
 },
}))
