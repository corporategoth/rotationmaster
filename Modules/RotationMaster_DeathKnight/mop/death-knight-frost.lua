-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Mists of Pandaria Classic Frost Death Knight with a two-handed weapon, levels 55–90 (simulator'
-- obliterate APL, the same as Hekili's obliterate_build; Warcraft Tavern's leveling advice). The
-- default Frost premade: Killing Machine goes to Obliterate, Obliterate spends any capped rune pair,
-- Frost Strike only above 76 runic power and as a 40 filler, Howling Blast on Rime and with spare
-- Frost or Death runes. With two one-handers rm.mop.deathknight.frost.dualwield takes over.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,n)return{type='RUNE',rune=kind,operator='EQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.frost',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.frost-upkeep']=2,['mop.deathknight.frost-open']=2,
  ['mop.deathknight.frost-tail']=1,['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 nameKey='Default.MoP.DeathKnight.Frost.Name',descriptionKey='Default.MoP.DeathKnight.Frost.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','leveling','single-target','aoe','hekili'},
 sources={

  {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/DeathKnightFrost.simc',title='Hekili MoP fork: Frost Death Knight (obliterate_build)',reviewedAt='2026-10-23',revision='0750b5dd98'},
  {url='https://www.warcrafttavern.com/mop/guides/death-knight-leveling-guide/',title='Warcraft Tavern: MoP Death Knight leveling',reviewedAt='2026-10-23',notes='Two-handers while leveling; Obliterate on Killing Machine.'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-death-knight-leveling',title='Icy Veins: MoP Classic Frost Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23',notes='Shared opening: Pillar, diseases, Death Strike at low health.'},
 },
 body={priority=20,specs={251},
  cooldowns={
   block('frost-upkeep','mop.deathknight.frost-upkeep','frost-'),
   block('frost-class','mop.deathknight.upkeep','frost-'),
  },
  rotation={
   block('frost-boundaries','mop.deathknight.boundaries','frost-'),
   block('frost-open','mop.deathknight.frost-open','frost-'),
   spell('frost-obliterate-km',49020,buff(51124)),
   spell('frost-strike-cap',49143,rp('GREATERTHANOREQUALS',76)),
   spell('frost-rime',49184,buff(59052)),
   spell('frost-obliterate-capped',49020,any(rune(2,2),rune(3,2),rune(4,2))),
   spell('frost-obliterate',49020),
   spell('frost-howling-blast',49184),
   block('frost-tail','mop.deathknight.frost-tail','frost-'),
  },
 },
}))
