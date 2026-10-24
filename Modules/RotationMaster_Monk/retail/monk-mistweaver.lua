-- Retail (Midnight 12.x) Mistweaver Monk, Icy Veins reference: Blizzard ships no Assisted Combat
-- list for healers, and ally health, Renewing Mist charges, Mana Tea stacks and procs are secret in
-- Midnight combat, so healing advice is impossible. On a hostile target it suggests the
-- fistweaving filler (Rising Sun Kick, Blackout Kick, Tiger Palm); otherwise nothing. Disabled.
local _,addon=...
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.mistweaver',revision=2,
 blocks={['retail.monk.boundaries']=1,['retail.monk.utility']=2},
 nameKey='Default.Retail.Monk.Mistweaver.Name',descriptionKey='Default.Retail.Monk.Mistweaver.Description',
 applicability={families={'retail'},actionContext='player',class='MONK',specs={270},minLevel=10,maxLevel=90},
 tags={'mistweaver','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/mistweaver-monk-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Mistweaver Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Damage filler between heals; the healing priorities need ally health, which is secret.'},
 },
 body={priority=10,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={block('mw-utility','retail.monk.utility','mw-')},
  rotation={
   block('mw-boundaries','retail.monk.boundaries','mw-'),
   stop('mw-not-hostile',negate({type='ATTACKABLE',unit='target'})),
   spell('mw-rising-sun-kick',107428),
   spell('mw-blackout-kick',100784),
   spell('mw-tiger-palm',100780),
  },
 },
}))
