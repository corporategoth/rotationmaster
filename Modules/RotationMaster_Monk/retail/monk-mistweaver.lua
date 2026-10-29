-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Mistweaver Monk, Icy Veins reference: Blizzard ships no Assisted Combat
-- list for healers, and ally health, Renewing Mist charges, Mana Tea stacks and procs are secret in
-- Midnight combat, so healing advice is impossible. On a hostile target it suggests the
-- fistweaving filler (Rising Sun Kick, Blackout Kick, Tiger Palm); otherwise nothing. Disabled.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.mistweaver',revision=6,
 blocks={['retail.monk.heal-boundaries']=2,['retail.monk.utility']=2},
 nameKey="Reference (Icy Veins)",descriptionKey="Reference only, off by default. Blizzard offers no Assisted Combat list for healers, and in Midnight combat your allies' health, Renewing Mist charges, Mana Tea stacks and procs are hidden from addons, so healing advice is not possible; choose your heals yourself. On a hostile target it suggests the fistweaving filler, Rising Sun Kick, Blackout Kick and Tiger Palm; on a friendly target or none it suggests nothing. Reminders: Spear Hand Strike, and Fortifying Brew and your racial cooldown whenever they are ready in combat.",
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'mistweaver','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Mistweaver Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Damage filler between heals; the healing priorities need ally health, which is secret.'},
 },
 body={priority=10,disabled=true,specs={270},
  cooldowns={block('mw-utility','retail.monk.utility','mw-')},
  rotation={
   block('mw-boundaries','retail.monk.heal-boundaries','mw-'),
   spell('mw-rising-sun-kick',107428),
   spell('mw-blackout-kick',100784),
   spell('mw-tiger-palm',100780),
  },
 },
}))
