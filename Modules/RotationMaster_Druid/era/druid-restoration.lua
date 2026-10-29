-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Classic Era Druid Restoration, from level 10 when Restoration is the primary talent tree. After
-- Icy Veins and Wowhead: acts on the current friendly target (choosing whom to heal and downranking
-- beyond rank 4 Healing Touch stay with you). Nature's Swiftness Healing Touch, Swiftmend in an
-- emergency, Rejuvenation and Regrowth kept rolling, Regrowth spam with Improved Regrowth, Healing
-- Touch at full rank for heavy damage or Nature's Grace, rank 4 otherwise. On an enemy: Moonfire,
-- Insect Swarm, Wrath.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function form(id)return{type='FORM',form=id}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function hp(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.restoration',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['era.druid.heal-cooldowns']=1,['era.druid.resto-damage']=2},
 nameKey="Restoration",descriptionKey="Restoration from level 10 when Restoration is your main talent tree. Heals your current friendly target: Healing Touch after Nature's Swiftness, Swiftmend below 40% on your own HoT, Rejuvenation and Regrowth kept rolling, Regrowth as the main heal with Improved Regrowth, full Healing Touch below 45% or on a Nature's Grace proc, rank 4 Healing Touch otherwise. On an enemy: Moonfire, Insect Swarm and Wrath. Silent in Cat or Bear Form. Reminders: Mark of the Wild, Omen of Clarity, Nature's Swiftness, Tranquility, Innervate, Rebirth, poison and curse removal. Choosing whom to heal stays with you.",
 applicability={families={'era'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','restoration','healer','group','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/restoration-druid-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/restoration-druid-leveling-talent-build-from-1-to-60',title='Icy Veins: Restoration Druid leveling',reviewedAt='2026-10-23',revision='2026-07-18'},
  {url='https://www.wowhead.com/classic/guide/classes/druid/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Restoration Druid rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={ref('era-resto-upkeep','era.druid.upkeep','era-resto-'),ref('era-resto-cooldowns','era.druid.heal-cooldowns','era-resto-')},
  rotation={
   ref('era-resto-boundaries','era.druid.boundaries','era-resto-'),
   {id='era-resto-feral-form',type='stop',conditions=any(form(768),form(5487),form(9634))},
   {id='era-resto-heal',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('era-resto-swiftness',5185,own(17116)),
    spell('era-resto-swiftmend',18562,all(hp(.4),any(hot(774),hot(8936)))),
    spell('era-resto-rejuvenation',774,all(negate(hot(774)),any({type='COMBAT',unit='player'},hp(.95)))),
    spell('era-resto-regrowth',8936,all(negate(hot(8936)),hp(.8))),
    {id='era-resto-regrowth-build',type='branch',conditions={type='TALENT',layout='tree',tree=3,talent=14,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
     spell('era-resto-regrowth-spam',8936,hp(.75))}},
    spell('era-resto-big-touch',5185,any(hp(.45),own(16886))),
    spell('era-resto-touch-rank4',5188,hp(.85),true),
    spell('era-resto-touch',5185,hp(.85)),
    {id='era-resto-heal-stop',type='stop',suppress_attack=true,conditions={}}}},
   ref('era-resto-damage','era.druid.resto-damage','era-resto-enemy-'),
   {id='era-resto-stop',type='stop',suppress_attack=true,conditions={}},
  },
 },
}))
