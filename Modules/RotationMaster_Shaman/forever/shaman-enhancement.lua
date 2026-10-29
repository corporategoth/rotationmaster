-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Enhancement Shaman, levels 1–60, Icy Veins order (the recommended Shaman
-- default, and every Shaman before a deep Elemental or Restoration talent).
-- Rank-1-style Lightning Bolt pull, Stormstrike on cooldown, a free Lightning Bolt at five
-- Maelstrom Weapon stacks, Fire Nova and Flame Shock on packs, Earth Shock into the Stormstrike
-- debuff, Flame Shock in groups, Earth Shock, then melee. Lightning Bolt fills the gap while the
-- target is out of melee range. Health, mana and time to die are secret or unavailable on
-- Forever, so self-heals, the low-mana casting pause (the Wowhead variant saves mana instead) and
-- the will-it-live checks are left out.
-- Left manual: totem placement presets (Call of the Elements), Frost Shock for threat, Purge,
-- Grounding/Tremor and other situational totems, Totemic Recall and Ghost Wolf.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function shocked()return{type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}end
local stationary=negate({type='MOVING'})
local ranged={type='BEYOND_MELEE',unit='target'}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.enhancement',revision=6,
 blocks={['forever.shaman.manual-target']=2,['forever.shaman.upkeep']=2,['forever.shaman.imbue']=1,['forever.shaman.group-totems']=1},
 nameKey="Enhancement (Icy Veins)",descriptionKey="Melee Enhancement from level 1 to 60, and the default for any Shaman before Lava Burst or Mana Tide Totem. Pulls with Lightning Bolt from range, then Stormstrike on cooldown, an instant Lightning Bolt at five Maelstrom Weapon stacks, Fire Nova (with a Fire totem down) and Flame Shock on three or more enemies, Earth Shock into the Stormstrike debuff, Flame Shock in groups, and Earth Shock on cooldown; Lightning Bolt fills the gap while the target is out of reach. Health and mana are hidden from addons on Forever, so healing yourself and pausing to refill mana are your call (the Wowhead premade saves mana instead). Reminders: weapon imbue (Windfury, else Flametongue, else Rockbiter), Water or Lightning Shield, the Earth Shock interrupt, Searing or Magma Totem, group totems, Rage of the Farseer, Stoneclaw Totem. Left to you: totem presets, Frost Shock, Purge and other totems.",
 applicability={families={'forever'},actionContext='player',class='SHAMAN'},
 tags={'dps','melee','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/enhancement-shaman-melee-dps-pve-guide',title='Icy Veins: Forever Enhancement Shaman PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/enhancement-shaman-leveling',title='Icy Veins: Forever Enhancement Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://mobalytics.gg/wow-forever/classes/shaman-leveling-guide',title='Mobalytics: Forever Shaman leveling 1–30 (pre-30 imbue, Fire Nova, totems)',reviewedAt='2026-10-23',revision='2026-10-21'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Fire Nova, totems, Stormstrike)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=10,
 cooldowns={block('forever.shaman.upkeep','shaman-enh-'),block('forever.shaman.imbue','shaman-enh-'),block('forever.shaman.group-totems','shaman-enh-'),
  spell('shaman-enh-magma-totem',8190,all(combat(),negate({type='TOTEM',spell=1}),enemies(3))),
  spell('shaman-enh-searing-totem',3599,all(combat(),negate({type='TOTEM',spell=1}),negate(all(known(8190),enemies(3))))),
  spell('shaman-enh-rage-of-the-farseer',425336,all(combat(),any(big(),enemies(3)))),
  spell('shaman-enh-stoneclaw-totem',5730,all(combat(),negate({type='GROUP'}),enemies(2)))},
 rotation={
 block('forever.shaman.manual-target','shaman-enh-'),
 {id='shaman-enh-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('shaman-enh-pull-bolt',403,all(ranged,stationary)),
  {id='shaman-enh-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 spell('shaman-enh-stormstrike',17364),
 spell('shaman-enh-maelstrom-bolt',403,{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=5}),
 {id='shaman-enh-aoe',type='branch',conditions=enemies(3),onFalse={},onTrue={
  spell('shaman-enh-fire-nova',408341,{type='TOTEM',spell=1}),
  spell('shaman-enh-aoe-flame-shock',8050,negate(shocked())),
 }},
 spell('shaman-enh-stormstrike-shock',8042,{type='DEBUFF',unit='target',spell=17364,owndebuff=true}),
 spell('shaman-enh-flame-shock',8050,all({type='GROUP'},negate(shocked()))),
 spell('shaman-enh-earth-shock',8042),
 spell('shaman-enh-bolt',403,all(ranged,stationary)),
 }},
}))
