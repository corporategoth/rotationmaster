-- Mists of Pandaria Classic Frost Death Knight with two one-handed weapons (Masterfrost), levels
-- 55–90, after Icy Veins' rotation with wowsims' masterfrost cap guards. Selected in the Frost
-- specialization (251) while the off hand holds a weapon (with a two-hander rm.mop.deathknight.frost
-- takes over). Killing Machine goes to Frost Strike, Howling Blast is the main rune spender,
-- Obliterate spends capped Unholy runes below 77 runic power.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.frost.dualwield',revision=6,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.frost-upkeep']=2,['mop.deathknight.frost-open']=2,
  ['mop.deathknight.frost-tail']=1,['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 nameKey='Default.MoP.DeathKnight.FrostDualWield.Name',descriptionKey='Default.MoP.DeathKnight.FrostDualWield.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'frost','single-target','aoe','icy-veins','wowsims'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-death-knight-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Frost Death Knight rotation (dual-wield)',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/frost-death-knight-leveling',title='Icy Veins: MoP Classic Frost Death Knight leveling',reviewedAt='2026-10-23',revision='2025-09-23'},
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/death_knight/frost/apls/masterfrost.apl.json',title='wowsims/mop Frost masterfrost APL',reviewedAt='2026-10-23',revision='ec2c6c2552',notes='Obliterate on two Unholy runes, Frost Strike above 76.'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/death-knight/frost/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Frost Death Knight rotation',reviewedAt='2026-10-23',revision='2025-08-02',notes='Read from a Wayback snapshot; same order.'},
 },
 body={priority=30,specs={251},switch={type='WEAPON_TYPE',slot='offhand',kind='weapon'},
  cooldowns={
   block('masterfrost-upkeep','mop.deathknight.frost-upkeep','masterfrost-'),
   block('masterfrost-class','mop.deathknight.upkeep','masterfrost-'),
  },
  rotation={
   block('masterfrost-boundaries','mop.deathknight.boundaries','masterfrost-'),
   block('masterfrost-open','mop.deathknight.frost-open','masterfrost-'),
   spell('masterfrost-strike-km',49143,any(buff(51124),rp('GREATERTHANOREQUALS',89))),
   spell('masterfrost-howling-capped',49184,any(rune(2,'EQUALS',2),rune(4,'EQUALS',2),buff(59052))),
   spell('masterfrost-obliterate-capped',49020,all(rune(3,'EQUALS',2),rp('LESSTHANOREQUALS',76))),
   spell('masterfrost-strike-cap',49143,rp('GREATERTHANOREQUALS',76)),
   spell('masterfrost-obliterate',49020,all(rune(3,'GREATERTHANOREQUALS',1),rp('LESSTHAN',77))),
   spell('masterfrost-howling-blast',49184),
   block('masterfrost-tail','mop.deathknight.frost-tail','masterfrost-'),
  },
 },
}))
