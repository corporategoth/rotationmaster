-- WoW Forever Warrior melee DPS, levels 1–60, Arms and Fury, Icy Veins order (the recommended
-- DPS premade and the catch-all for any warrior outside Defensive Stance).
-- Forever rage is scarce, so this pools: Charge to pull; Victory Rush when hurt or about to
-- lapse; Intercept a distant target; Execute only on elites, bosses or in a group
-- (solo on a normal mob it stops and lets white hits finish); Whirlwind/Thunder Clap,
-- Demoralizing Shout and Sweeping Strikes Slam on packs; Spearing Strike on Giants and
-- Dragonkin; solo Demoralizing Shout; Rend until Bloodthirst is known (Arms keeps it); Overpower;
-- Mortal Strike; Bloodthirst; Whirlwind with rage to spare; Slam (an 18-second cooldown in
-- Forever) while standing; Sunder Armor (two, or five on elites); Spearing Strike as a rage dump.
-- Heroic Strike only from 80 rage (60 while the main strike recovers), Cleave from 60.
-- Shared parts: Defaults/blocks/forever-warrior.lua. Left manual: stance dancing, Hamstring,
-- Recklessness and Retaliation (listed, off by default), taunts and consumables.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rage(op,n)return{type='POWER',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function target(op,v)return{type='HEALTHPCT',unit='target',operator=op,value=v}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function sunders(n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function cooling(id,n)return all(known(id),{type='SPELL_COOLDOWN',spell=id,operator='GREATERTHAN',value=n})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
-- Mortal Strike or Bloodthirst known: keep rage for it.
local function strike()return any(known(12294),known(23881))end
local function giant()return any({type='CREATURE',unit='target',value='GIANT'},{type='CREATURE',unit='target',value='DRAGONKIN'})end
local caster={type='MANA',unit='target',operator='GREATERTHAN',value=0}
local unqueued=all(negate(queued(78)),negate(queued(845)))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.dps',revision=2,
 blocks={['forever.warrior.boundaries']=2,['forever.warrior.upkeep']=1},
 nameKey='Default.Forever.Warrior.DPS.Name',descriptionKey='Default.Forever.Warrior.DPS.Description',
 applicability={families={'forever'},actionContext='player',class='WARRIOR',minLevel=1,maxLevel=60},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins','method'},
 sources={{url='https://www.icy-veins.com/wow-forever/arms-warrior-leveling',title='Icy Veins: Forever Arms Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/fury-warrior-leveling',title='Icy Veins: Forever Fury Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/arms-warrior-melee-dps-pve-guide',title='Icy Veins: Forever Arms Warrior PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/fury-warrior-melee-dps-pve-guide',title='Icy Veins: Forever Fury Warrior PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.method.gg/wow-forever/wow-forever-warrior-leveling-guide-and-talents',title='Method: Forever Warrior leveling guide and talents',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Slam, Bloodthrill)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('forever.warrior.upkeep','warrior-dps-'),
  spell('warrior-dps-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),any(rage('GREATERTHANOREQUALS',80),
   all(rage('GREATERTHANOREQUALS',60),any(cooling(12294,2),cooling(23881,2)))))),
  spell('warrior-dps-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2),rage('GREATERTHANOREQUALS',60))),
  spell('warrior-dps-sweeping-strikes',12292,all(combat(),enemies('GREATERTHANOREQUALS',2))),
  spell('warrior-dps-death-wish',12328,all(combat(),any(big(),enemies('GREATERTHANOREQUALS',2)))),
  spell('warrior-dps-berserker-rage',18499,all(combat(),rage('LESSTHAN',50),{type='ISSAME',unit='targettarget',otherunit='player'})),
  {id='warrior-dps-recklessness',type='spell',action=1719,ranked=false,disabled=true,conditions=all(combat(),{type='CLASSIFICATION',unit='target',value='worldboss'},
   any(negate(known(12328)),{type='BUFF',unit='player',spell=12328}))},
  {id='warrior-dps-retaliation',type='spell',action=20230,ranked=false,disabled=true,conditions=all(combat(),any(enemies('GREATERTHANOREQUALS',3),
   all(enemies('GREATERTHANOREQUALS',2),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4})))}},
 rotation={
 block('forever.warrior.boundaries','warrior-dps-'),
 spell('warrior-dps-victory-rush',402927,any({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.9},
  {type='BUFF_REMAIN',unit='player',spell=402975,operator='LESSTHAN',value=5})),
 spell('warrior-dps-intercept',20252,{type='BEYOND_MELEE',unit='target'}),
 {id='warrior-dps-execute-phase',type='branch',conditions=target('LESSTHANOREQUALS',.2),onFalse={},onTrue={
  spell('warrior-dps-execute',5308,any(big(),{type='GROUP'})),
  {id='warrior-dps-let-it-die',type='none',suppress_attack=false,conditions=all(negate({type='GROUP'}),negate(big()))},
 }},
 {id='warrior-dps-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-dps-aoe-whirlwind',1680),
  spell('warrior-dps-aoe-thunder-clap',6343,all(negate(known(1680)),negate(debuff(6343)))),
  spell('warrior-dps-aoe-demoralizing-shout',1160,all(negate({type='GROUP'}),negate(debuff(1160)))),
  spell('warrior-dps-aoe-slam',1240193,all(negate({type='MOVING'}),{type='BUFF',unit='player',spell=12292})),
 }},
 spell('warrior-dps-spearing-giant',1310222,giant()),
 spell('warrior-dps-demoralizing-shout',1160,all(negate({type='GROUP'}),negate(debuff(1160)),negate(caster),target('GREATERTHAN',.5))),
 spell('warrior-dps-rend',772,all(negate(known(23881)),negate(debuff(772,true)),target('GREATERTHAN',.3))),
 spell('warrior-dps-overpower',7384),
 spell('warrior-dps-mortal-strike',12294),
 spell('warrior-dps-bloodthirst',23881),
 spell('warrior-dps-whirlwind',1680,any(rage('GREATERTHANOREQUALS',55),cooling(12294,1.5),cooling(23881,1.5))),
 spell('warrior-dps-slam',1240193,all(negate({type='MOVING'}),any(negate(strike()),rage('GREATERTHANOREQUALS',45)))),
 spell('warrior-dps-sunder',7386,all(any(negate(strike()),rage('GREATERTHANOREQUALS',40)),
  any(all(big(),negate(sunders(5))),all(target('GREATERTHAN',.5),negate(sunders(2)))))),
 spell('warrior-dps-spearing-dump',1310222,rage('GREATERTHANOREQUALS',80)),
 }},
}))
