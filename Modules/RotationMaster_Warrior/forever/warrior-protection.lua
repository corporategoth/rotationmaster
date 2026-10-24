-- WoW Forever Protection Warrior tank, levels 10–60, Icy Veins order (the recommended tank).
-- Chosen whenever you are in Defensive Stance: Forever's Protection levels in it (Vanguard),
-- and RM cannot read Forever talents. Charge to pull (usable in Defensive Stance once Vanguard
-- is taken); Victory Rush; on packs Thunder Clap on cooldown, Demoralizing Shout, Shield Slam,
-- Revenge and Rend; Shield Slam; Revenge; Demoralizing Shout; Rend; Sunder Armor (five on
-- elites); Thunder Clap on dangerous single targets. Shield Block while you hold the target,
-- Heroic Strike when both strikes are recovering, Cleave on packs. Rage, health and the target's
-- mana are secret on Forever, so the rage thresholds, the caster checks and Last Stand are left
-- out. Shared parts: Defaults/blocks/forever-warrior.lua.
-- Left manual: swapping to Battle Stance to Charge before Vanguard, taunting other enemies,
-- tab-targeting untouched enemies; Taunt, Shield Wall, Concussion Blow and Disarm are listed off.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function debuff(id,own)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=own or nil}end
local function sunders(n)return{type='DEBUFF_STACKS',unit='target',spell=7386,anyrank=true,operator='GREATERTHANOREQUALS',value=n}end
local function queued(id)return{type='SPELL_ACTIVE',spell=id,ranked=false}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local tanked={type='THREAT',unit='target',threat=3}
local unqueued=all(negate(queued(78)),negate(queued(845)))
local function rend()return spell('warrior-prot-rend',772,negate(debuff(772,true)))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warrior.protection',revision=4,
 blocks={['forever.warrior.boundaries']=2,['forever.warrior.upkeep']=2},
 nameKey='Default.Forever.Warrior.Protection.Name',descriptionKey='Default.Forever.Warrior.Protection.Description',
 applicability={families={'forever'},actionContext='player',class='WARRIOR'},
 tags={'tank','melee','leveling','endgame','aoe','icy-veins','method'},
 sources={{url='https://www.icy-veins.com/wow-forever/protection-warrior-tank-pve-guide',title='Icy Veins: Forever Protection Warrior tank PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/protection-warrior-leveling',title='Icy Veins: Forever Protection Warrior leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.method.gg/wow-forever/wow-forever-warrior-leveling-guide-and-talents',title='Method: Forever Warrior leveling guide and talents',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://worldofwarcraft.blizzard.com/en-us/news/24301514',title='Blizzard: Forever class deep dives, Priest and Warrior',reviewedAt='2026-10-23',revision='2026-09-30'}},
 body={priority=25,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='FORM',value=2}}},
 cooldowns={block('forever.warrior.upkeep','warrior-prot-'),
  spell('warrior-prot-shield-block',2565,all(combat(),tanked,negate({type='BUFF',unit='player',spell=2565}))),
  spell('warrior-prot-heroic-strike',78,all(combat(),unqueued,enemies('LESSTHAN',2),negate({type='SPELL_AVAIL',spell=23922}),negate({type='SPELL_AVAIL',spell=6572}))),
  spell('warrior-prot-cleave',845,all(combat(),unqueued,enemies('GREATERTHANOREQUALS',2))),
  {id='warrior-prot-taunt',type='spell',action=355,ranked=false,disabled=true,conditions=all(combat(),{type='GROUP'},negate(tanked))},
  {id='warrior-prot-shield-wall',type='spell',action=871,ranked=false,disabled=true,conditions=all(combat(),any(big(),enemies('GREATERTHANOREQUALS',3)))}},
 rotation={
 block('forever.warrior.boundaries','warrior-prot-'),
 spell('warrior-prot-victory-rush',402927),
 {id='warrior-prot-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',2),onFalse={},onTrue={
  spell('warrior-prot-aoe-thunder-clap',6343),
  spell('warrior-prot-aoe-demoralizing-shout',1160,negate(debuff(1160))),
  spell('warrior-prot-aoe-shield-slam',23922),
  spell('warrior-prot-aoe-revenge',6572),
  spell('warrior-prot-aoe-rend',772,negate(debuff(772,true))),
 }},
 spell('warrior-prot-shield-slam',23922),
 spell('warrior-prot-revenge',6572),
 spell('warrior-prot-demoralizing-shout',1160,negate(debuff(1160))),
 rend(),
 spell('warrior-prot-sunder',7386,any(all(big(),negate(sunders(5))),negate(sunders(2)))),
 spell('warrior-prot-thunder-clap',6343,all(big(),negate(debuff(6343)))),
 {id='warrior-prot-concussion-blow',type='spell',action=12809,ranked=false,disabled=true,conditions={}},
 {id='warrior-prot-disarm',type='spell',action=676,ranked=false,disabled=true,conditions=big()},
 }},
}))
