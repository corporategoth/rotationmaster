-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Vengeance Demon Hunter after Wowhead's order and Icy Veins' hero-tree goals
-- (optimal reference): Aldrachi Reaver's Glaive cycle, Fracture at full charges, Spirit Bomb on
-- packs, Immolation Aura, Sigil of Flame, Soul Cleave, Fel Devastation, Fracture, Felblade, Throw
-- Glaive. RM cannot count Soul Fragments, so Spirit Bomb waits for three enemies and Soul Cleave
-- fills single target; Fury is secret on Retail, so spenders wait only for their cost and builders
-- do not avoid capping. Disabled: secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function engaged(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.vengeance.guide',revision=6,
 blocks={['retail.demonhunter.boundaries']=3,['retail.demonhunter.utility']=2},
 nameKey="Reference (Wowhead and Icy Veins)",descriptionKey="Reference only, off by default: Wowhead's Vengeance order with Icy Veins' hero-tree goals. Your buffs are hidden in Midnight combat, so it cannot run there; Fury is hidden on Retail, so spenders wait only for their cost and builders do not avoid capping. Aldrachi Reaver: Reaver's Glaive, Fracture on Rending Strike, Soul Cleave on Glaive Flurry. Then Fracture at full charges, Spirit Bomb on three or more enemies, Immolation Aura, Sigil of Flame, Soul Cleave against one target, Fel Devastation, Soul Cleave, Fracture, Felblade, Throw Glaive. Rotation Master cannot count Soul Fragments, so Spirit Bomb follows the enemy count. Reminders: Demon Spikes when it is down, Metamorphosis, Fiery Brand, Sigil of Spite, Soul Carver (Infernal Strike at two charges is off), plus Disrupt and Blur.",
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER'},
 tags={'vengeance','tank','reference','wowhead','icy-veins'},
 sources={
  {url='https://www.wowhead.com/guide/classes/demon-hunter/vengeance/rotation-cooldowns-pve-tank',title='Wowhead: Vengeance Demon Hunter rotation (Midnight Season 1)',reviewedAt='2026-10-23',revision='2026-02-24',notes='Read from a Wayback snapshot; Season 1 data. Spirit Bomb at 6 souls.'},
  {url='https://www.icy-veins.com/wow/vengeance-demon-hunter-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Vengeance Demon Hunter rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Hero-tree goals: Fracture before Soul Cleave (Aldrachi), Fracture on cooldown and Voidfall spending (Annihilator).'},
 },
 body={priority=10,disabled=true,specs={581},
  cooldowns={
   block('vguide-utility','retail.demonhunter.utility','vguide-'),
   spell('vguide-demon-spikes',203720,all(combat(),negate(buff(203819)))),
   spell('vguide-metamorphosis',187827,all(combat(),negate(buff(187827)))),
   spell('vguide-fiery-brand',204021,combat()),
   off('vguide-infernal-strike',189110,{type='SPELL_CHARGES',spell=189110,operator='GREATERTHANOREQUALS',value=2}),
   spell('vguide-sigil-of-spite',390163,combat()),
   spell('vguide-soul-carver',207407,combat()),
  },
  rotation={
   block('vguide-boundaries','retail.demonhunter.boundaries','vguide-'),
   {id='vguide-aldrachi',type='branch',conditions=known(442294),onFalse={},onTrue={
    spell('vguide-reavers-glaive',204157,all(any(buff(444686),buff(444764)),negate(buff(442442)),negate(buff(442435)))),
    spell('vguide-rending-fracture',263642,buff(442442)),
    spell('vguide-flurry-soul-cleave',228477,buff(442435))}},
   spell('vguide-fracture-charges',263642,{type='SPELL_CHARGES',spell=263642,operator='GREATERTHANOREQUALS',value=2}),
   spell('vguide-spirit-bomb',247454,engaged(3)),
   spell('vguide-immolation-aura',258920),
   spell('vguide-sigil-of-flame',204596),
   spell('vguide-single-soul-cleave',228477,negate(engaged(3))),
   spell('vguide-fel-devastation',212084),
   spell('vguide-soul-cleave',228477),
   spell('vguide-fracture',263642),
   spell('vguide-felblade',232893),
   spell('vguide-throw-glaive',204157),
  },
 },
}))
