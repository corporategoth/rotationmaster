-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Havoc Demon Hunter after Icy Veins, SimulationCraft and Wowhead (optimal
-- reference): Aldrachi Reaver's Glaive and Rending Strike, Fel-Scarred Metamorphosis spending,
-- Essence Break windows, Eye Beam, Blade Dance, Immolation Aura, Chaos Strike, Felblade, Throw
-- Glaive (Fury is secret on Retail, so Felblade does not wait for room). Disabled: procs,
-- Metamorphosis and Essence Break are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local aldrachi=known(442294)
local glaive=any(buff(444686),buff(444764))
local scarredMeta=all(negate(aldrachi),buff(162264))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.havoc.guide',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 nameKey="Reference (Icy Veins, SimulationCraft and Wowhead)",descriptionKey="Reference only, off by default: the guides' Havoc priority. Your procs, Metamorphosis and Essence Break are hidden from addons in Midnight combat, so this list cannot run there; read it, or clone it to experiment. Fury is hidden on Retail, so Felblade does not wait for room. Aldrachi Reaver: Reaver's Glaive when neither Rending Strike nor Glaive Flurry is up, Chaos Strike on Rending Strike. Fel-Scarred: Essence Break, Blade Dance and Chaos Strike in Metamorphosis. Then Blade Dance and Chaos Strike inside Essence Break, Immolation Aura at two charges, Eye Beam, Felblade for Inertia, Essence Break when Eye Beam is over 4 seconds away, Blade Dance, Immolation Aura on two enemies, Chaos Strike, Felblade, Immolation Aura, Throw Glaive, Fel Rush. Reminders: Metamorphosis once Eye Beam and Blade Dance are spent, The Hunt, Vengeful Retreat, plus Disrupt and Blur.",
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'havoc','melee','reference','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/havoc-demon-hunter-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Havoc Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/demonhunter_havoc.simc',title='SimulationCraft default action list: Havoc',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://www.wowhead.com/guide/classes/demon-hunter/havoc/rotation-cooldowns-pve-dps',title='Wowhead: Havoc Demon Hunter rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-17',notes='Read from a Wayback snapshot.'},
 },
 body={priority=10,disabled=true,specs={577},
  cooldowns={
   block('hguide-utility','retail.demonhunter.utility','hguide-'),
   spell('hguide-metamorphosis',191427,all(combat(),negate({type='SPELL_AVAIL',spell=198013}),negate({type='SPELL_AVAIL',spell=188499}))),
   spell('hguide-the-hunt',370965,all(combat(),any(all(aldrachi,negate(glaive)),all(negate(aldrachi),{type='SPELL_COOLDOWN',spell=198013,operator='LESSTHAN',value=10})))),
   spell('hguide-vengeful-retreat',198793,all(combat(),any(known(388108),known(206476)))),
  },
  rotation={
   block('hguide-boundaries','retail.demonhunter.boundaries','hguide-'),
   spell('hguide-reavers-glaive',185123,all(aldrachi,glaive,negate(buff(442442)),negate(buff(442435)))),
   spell('hguide-rending-strike',162794,all(aldrachi,buff(442442))),
   spell('hguide-surge-essence-break',258860,scarredMeta),
   {id='hguide-window',type='branch',conditions=any({type='DEBUFF',unit='target',spell=320338,owndebuff=true},scarredMeta),onFalse={},onTrue={
    spell('hguide-window-blade-dance',188499),
    spell('hguide-window-chaos-strike',162794)}},
   spell('hguide-immolation-charges',258920,{type='SPELL_CHARGES',spell=258920,operator='GREATERTHANOREQUALS',value=2}),
   spell('hguide-eye-beam',198013),
   spell('hguide-inertia-felblade',232893,all(known(427640),negate(buff(427641)))),
   spell('hguide-essence-break',258860,{type='SPELL_COOLDOWN',spell=198013,operator='GREATERTHAN',value=4}),
   spell('hguide-blade-dance',188499),
   spell('hguide-immolation-cleave',258920,engaged(2)),
   spell('hguide-chaos-strike',162794),
   spell('hguide-felblade',232893),
   spell('hguide-immolation-aura',258920),
   spell('hguide-throw-glaive',185123),
   spell('hguide-fel-rush',195072),
  },
 },
}))
