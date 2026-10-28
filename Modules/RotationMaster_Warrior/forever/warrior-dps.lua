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
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function sunders(n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return all(known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
-- Mortal Strike or Bloodthirst known: keep rage for it.
local function strike()return any(known(12294),known(23881))end
-- Rage is secret on Forever: spend on anything else only while the main strike is recovering.
local function spare(n)return any(negate(strike()),cooling(12294,n),cooling(23881,n))end
local function giant()return any({type='CREATURE',unit='target',value='GIANT'},{type='CREATURE',unit='target',value='DRAGONKIN'})end
local unqueued=all(negate(queued(78)),negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.dps',revision=6,
 blocks={['forever.warrior.boundaries']=3,['forever.warrior.upkeep']=2},
 nameKey='Default.Forever.Warrior.DPS.Name',descriptionKey='Default.Forever.Warrior.DPS.Description',
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
  spell('warrior-dps-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),spare(2))),
  spell('warrior-dps-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2))),
  spell('warrior-dps-sweeping-strikes',12292,all(combat(),enemies('GREATERTHANOREQUALS',2))),
  spell('warrior-dps-death-wish',12328,all(combat(),any(big(),enemies('GREATERTHANOREQUALS',2)))),
  spell('warrior-dps-berserker-rage',18499,all(combat(),{type='THREAT',unit='target',threat=3})),
  {id='warrior-dps-recklessness',type='spell',action=1719,ranked=false,disabled=true,conditions=all(combat(),{type='CLASSIFICATION',unit='target',value='worldboss'},
   any(negate(known(12328)),{type='BUFF',unit='player',spell=12328}))},
  {id='warrior-dps-retaliation',type='spell',action=20230,ranked=false,disabled=true,conditions=all(combat(),enemies('GREATERTHANOREQUALS',3))}},
 rotation={
 block('forever.warrior.boundaries','warrior-dps-'),
 spell('warrior-dps-victory-rush',402927),
 spell('warrior-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 -- Execute can be cast only in its execute range, so its readiness is the health test.
 spell('warrior-dps-execute',5308,any(big(),{type='GROUP'})),
 {id='warrior-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-dps-aoe-whirlwind',1680),
  spell('warrior-dps-aoe-thunder-clap',6343,all(negate(known(1680)),negate(debuff(6343)))),
  spell('warrior-dps-aoe-demoralizing-shout',1160,all(negate({type='GROUP'}),negate(debuff(1160)))),
  spell('warrior-dps-aoe-slam',1240193,all(negate({type='MOVING'}),{type='BUFF',unit='player',spell=12292})),
 }},
 spell('warrior-dps-spearing-giant',1310222,giant()),
 spell('warrior-dps-demoralizing-shout',1160,all(negate({type='GROUP'}),negate(debuff(1160)))),
 spell('warrior-dps-rend',772,all(negate(known(23881)),negate(debuff(772,true)))),
 spell('warrior-dps-overpower',7384),
 spell('warrior-dps-mortal-strike',12294),
 spell('warrior-dps-bloodthirst',23881),
 spell('warrior-dps-whirlwind',1680,spare(1.5)),
 spell('warrior-dps-slam',1240193,all(negate({type='MOVING'}),spare(1.5))),
 spell('warrior-dps-sunder',7386,all(spare(1.5),any(all(big(),negate(sunders(5))),negate(sunders(2))))),
 }},
}))
