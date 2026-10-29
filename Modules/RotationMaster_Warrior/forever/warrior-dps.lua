-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Warrior melee DPS, levels 1–60, Arms and Fury, Icy Veins order (the recommended
-- DPS premade and the catch-all for any warrior outside Defensive Stance).
-- Forever rage is scarce, so this pools; rage and health are secret on Forever, so pooling keeps
-- rage for the main strike by spending elsewhere only while Mortal Strike or Bloodthirst is
-- recovering. Charge to pull; Victory Rush; Intercept a distant target; Execute (castable only in
-- its range) on elites, bosses or in a group; Whirlwind/Thunder Clap, Demoralizing Shout and
-- Sweeping Strikes Slam on packs; Spearing Strike on Giants and Dragonkin; solo Demoralizing
-- Shout; Rend until Bloodthirst is known (Arms keeps it); Overpower; Mortal Strike; Bloodthirst;
-- Whirlwind, Slam (an 18-second cooldown in Forever) while standing and Sunder Armor (two, or
-- five on elites) while the main strike recovers. Heroic Strike while the main strike recovers,
-- Cleave on packs.
-- Shared parts: Defaults/blocks/forever-warrior.lua. Left manual: stance dancing, Hamstring,
-- Recklessness and Retaliation (listed, off by default), taunts and consumables.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function sunders(n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return BuiltinConditions.all(BuiltinConditions.known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
-- Mortal Strike or Bloodthirst known: keep rage for it.
local function strike()return BuiltinConditions.any(BuiltinConditions.known(12294),BuiltinConditions.known(23881))end
-- Rage is secret on Forever: spend on anything else only while the main strike is recovering.
local function spare(n)return BuiltinConditions.any(BuiltinConditions.negate(strike()),cooling(12294,n),cooling(23881,n))end
local function giant()return BuiltinConditions.any({type='CREATURE',unit='target',value='GIANT'},{type='CREATURE',unit='target',value='DRAGONKIN'})end
local unqueued=BuiltinConditions.all(BuiltinConditions.negate(queued(78)),BuiltinConditions.negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.dps',revision=6,
 blocks={['forever.warrior.boundaries']=3,['forever.warrior.upkeep']=2},
 applicability={families={'forever'},actionContext='player',class='WARRIOR'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins','method'},
 sources={{url='https://www.icy-veins.com/wow-forever/arms-warrior-leveling',title='Icy Veins: Forever Arms Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/fury-warrior-leveling',title='Icy Veins: Forever Fury Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/arms-warrior-melee-dps-pve-guide',title='Icy Veins: Forever Arms Warrior PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/fury-warrior-melee-dps-pve-guide',title='Icy Veins: Forever Fury Warrior PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.method.gg/wow-forever/wow-forever-warrior-leveling-guide-and-talents',title='Method: Forever Warrior leveling guide and talents',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Slam, Bloodthrill)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=10,
 cooldowns={block('forever.warrior.upkeep','warrior-dps-'),
  BuiltinConditions.spell('warrior-dps-heroic-strike',78,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('LESSTHAN',2),spare(2))),
  BuiltinConditions.spell('warrior-dps-cleave',845,BuiltinConditions.all(BuiltinConditions.combat(),unqueued,enemies('GREATERTHANOREQUALS',2))),
  BuiltinConditions.spell('warrior-dps-sweeping-strikes',12292,BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',2))),
  BuiltinConditions.spell('warrior-dps-death-wish',12328,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(big(),enemies('GREATERTHANOREQUALS',2)))),
  BuiltinConditions.spell('warrior-dps-berserker-rage',18499,BuiltinConditions.all(BuiltinConditions.combat(),{type='THREAT',unit='target',threat=3})),
  {id='warrior-dps-recklessness',type='spell',action=1719,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),{type='CLASSIFICATION',unit='target',value='worldboss'},
   BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(12328)),{type='BUFF',unit='player',spell=12328}))},
  {id='warrior-dps-retaliation',type='spell',action=20230,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),enemies('GREATERTHANOREQUALS',3))}},
 rotation={
 block('forever.warrior.boundaries','warrior-dps-'),
 BuiltinConditions.spell('warrior-dps-victory-rush',402927),
 BuiltinConditions.spell('warrior-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 -- Execute can be cast only in its execute range, so its readiness is the health test.
 BuiltinConditions.spell('warrior-dps-execute',5308,BuiltinConditions.any(big(),{type='GROUP'})),
 {id='warrior-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  BuiltinConditions.spell('warrior-dps-aoe-whirlwind',1680),
  BuiltinConditions.spell('warrior-dps-aoe-thunder-clap',6343,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(1680)),BuiltinConditions.negate(debuff(6343)))),
  BuiltinConditions.spell('warrior-dps-aoe-demoralizing-shout',1160,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(debuff(1160)))),
  BuiltinConditions.spell('warrior-dps-aoe-slam',1240193,BuiltinConditions.all(BuiltinConditions.negate({type='MOVING'}),{type='BUFF',unit='player',spell=12292})),
 }},
 BuiltinConditions.spell('warrior-dps-spearing-giant',1310222,giant()),
 BuiltinConditions.spell('warrior-dps-demoralizing-shout',1160,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(debuff(1160)))),
 BuiltinConditions.spell('warrior-dps-rend',772,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(23881)),BuiltinConditions.negate(debuff(772,true)))),
 BuiltinConditions.spell('warrior-dps-overpower',7384),
 BuiltinConditions.spell('warrior-dps-mortal-strike',12294),
 BuiltinConditions.spell('warrior-dps-bloodthirst',23881),
 BuiltinConditions.spell('warrior-dps-whirlwind',1680,spare(1.5)),
 BuiltinConditions.spell('warrior-dps-slam',1240193,BuiltinConditions.all(BuiltinConditions.negate({type='MOVING'}),spare(1.5))),
 BuiltinConditions.spell('warrior-dps-sunder',7386,BuiltinConditions.all(spare(1.5),BuiltinConditions.any(BuiltinConditions.all(big(),BuiltinConditions.negate(sunders(5))),BuiltinConditions.negate(sunders(2))))),
 }},
}))
