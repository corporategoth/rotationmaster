-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight) Shadow Priest, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because its DoT, Madness and Voidform timings are hidden in
-- Midnight combat. Vampiric Touch before the pull. Tentacle Slam to apply Vampiric Touch, both DoTs
-- refreshed in the last 30%, Shadow Word: Madness when it is ending or in Voidform, Void Blast during
-- Madness, Tentacle Slam at two charges, Void Torrent, Mind Blast, Tentacle Slam, Mind Flay: Insanity
-- during Madness, Void Volley; moving: Death and Pain; Mind Flay, clipped for a ready Mind Blast (the
-- channel is read by spell, so Void Torrent and other channels run out). Insanity and health are
-- secret on Retail, so the Insanity-cap Madness, the Shadow Word: Death execute and Desperate Prayer
-- are left to you. Reminders: Halo, Voidform with both DoTs up, Power Infusion in Voidform.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function dotRemain(id,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local madness=dot(335467)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.priest.shadow.icyveins',revision=8,
 blocks={['retail.priest.upkeep']=2},
 nameKey="Reference (Icy Veins)",descriptionKey="Reference only, off by default: the Icy Veins and SimulationCraft order reads DoT timers, Madness and Voidform, which Midnight hides in combat; Insanity and health are hidden on Retail, so the Insanity-cap Madness, the Shadow Word: Death execute and Desperate Prayer are left to you. Vampiric Touch before the pull; Tentacle Slam to apply Vampiric Touch; Vampiric Touch and Shadow Word: Pain refreshed in their last 30%; Shadow Word: Madness when it is ending or in Voidform; Void Blast during Madness; Tentacle Slam at two charges; Void Torrent; Mind Blast; Tentacle Slam; Mind Flay: Insanity during Madness; Void Volley; Death and Pain while moving; Mind Flay, clipped for a ready Mind Blast. Reminders: Halo, Voidform with both DoTs up, Power Infusion in Voidform.",
 applicability={families={'retail'},actionContext='player',class='PRIEST'},
 tags={'shadow','ranged','reference','single-target','icy-veins','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/shadow-priest-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Shadow Priest rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/priest_shadow.simc',title='SimulationCraft: Shadow Priest default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
 },
 body={priority=5,disabled=true,specs={258},
  cooldowns={
   block('retail.priest.upkeep','shadowiv-'),
   spell('shadowiv-shadowform',232698,all(negate(combat()),negate(own(232698)),negate(own(194249)))),
   spell('shadowiv-halo',120644,fight),
   spell('shadowiv-voidform',228260,all(fight,dot(34914),dot(589))),
   spell('shadowiv-power-infusion',10060,all(fight,own(194249))),
  },
  rotation={
   {id='shadowiv-casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},all({type='CHANNELING',unit='player'},
    negate(all(any({type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_SPELL',unit='player',spell=391403}),{type='SPELL_AVAIL',spell=8092}))),
    negate({type='ATTACKABLE',unit='target'}))},
   {id='shadowiv-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('shadowiv-pull-vampiric-touch',34914,negate(dot(34914))),
    {id='shadowiv-pull-stop',type='stop',suppress_attack=true,conditions={}},
   }},
   spell('shadowiv-tentacle-touch',1227280,negate(dot(34914))),
   spell('shadowiv-vampiric-touch',34914,any(negate(dot(34914)),dotRemain(34914,6.3))),
   spell('shadowiv-shadow-word-pain',589,any(negate(dot(589)),dotRemain(589,4.8))),
   spell('shadowiv-madness',335467,any(negate(madness),dotRemain(335467,1.5),own(194249))),
   spell('shadowiv-void-blast',450983,madness),
   spell('shadowiv-tentacle-capped',1227280,{type='SPELL_CHARGES',spell=1227280,operator='GREATERTHANOREQUALS',value=2}),
   spell('shadowiv-void-torrent',263165),
   spell('shadowiv-mind-blast',8092),
   spell('shadowiv-tentacle-slam',1227280),
   spell('shadowiv-mind-flay-insanity',391403,madness),
   spell('shadowiv-void-volley',1242173),
   {id='shadowiv-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('shadowiv-moving-death',32379),
    spell('shadowiv-moving-pain',589),
   }},
   spell('shadowiv-mind-flay',15407),
  },
 },
}))
