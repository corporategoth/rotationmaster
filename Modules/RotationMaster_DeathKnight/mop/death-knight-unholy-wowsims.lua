-- Mists of Pandaria Classic Unholy Death Knight, rune-cap and Shadow Infusion pooling (wowsims
-- default APL as far as RM can read it; wowtbc.gg, Method and MaxDps agree). Off by default, same
-- switch as rm.mop.deathknight.unholy: Death Coil rebuilds Shadow Infusion while Dark Transformation
-- is down, Scourge Strike first when both Unholy or both Death runes are up, Festering Strike first
-- when both Blood and both Frost runes are up. Snapshot and trinket timing are left out.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,n)return{type='RUNE',rune=kind,operator='EQUALS',value=n}end
local function remain(id)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=3}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local infusion={type='BUFF_STACKS',unit='pet',spell=91342,operator='GREATERTHANOREQUALS',value=5}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.unholy.wowsims',revision=1,
 blocks={['mop.deathknight.boundaries']=1,['mop.deathknight.upkeep']=1,['mop.deathknight.unholy-upkeep']=1,['mop.deathknight.unholy-open']=1,
  ['mop.deathknight.survival']=1,['mop.deathknight.spread']=1},
 nameKey='Default.MoP.DeathKnight.Unholy.Wowsims.Name',descriptionKey='Default.MoP.DeathKnight.Unholy.Wowsims.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT',minLevel=55,maxLevel=90},
 tags={'unholy','single-target','aoe','wowsims'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/death_knight/unholy/apls/default.apl.json',title='wowsims/mop Unholy default APL',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://wowtbc.gg/mop/class-guides/unholy-death-knight/',title='wowtbc.gg: MoP Unholy Death Knight',reviewedAt='2026-10-23',notes='Death Coil to five stacks while Dark Transformation is down; rune-pair order.'},
  {url='https://www.method.gg/mop-classic/unholy-death-knight-class-guide-mop-classic',title='Method: MoP Classic Unholy Death Knight',reviewedAt='2026-10-23',revision='2025-07-22'},
  {url='https://github.com/kaminaris/MaxDps-DeathKnight/blob/95faf1baa6e91b0d5e32480227e35f54409dcfc2/Specialization/Mop/Unholy.lua',title='MaxDps-DeathKnight MoP Unholy',reviewedAt='2026-10-23',revision='95faf1baa6',notes='Same rune-pair rule; IDs not used.'},
 },
 body={priority=5,disabled=true,switch=known(47541),
  cooldowns={
   block('ucap-upkeep','mop.deathknight.unholy-upkeep','ucap-'),
   block('ucap-class','mop.deathknight.upkeep','ucap-'),
  },
  rotation={
   block('ucap-boundaries','mop.deathknight.boundaries','ucap-'),
   block('ucap-open','mop.deathknight.unholy-open','ucap-'),
   spell('ucap-plague-leech',123693,all(any(remain(55095),remain(55078)),{type='SPELL_AVAIL',spell=77575})),
   spell('ucap-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=10}),
   spell('ucap-soul-reaper',130736,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   spell('ucap-dark-transformation',63560,infusion),
   spell('ucap-death-coil-infusion',47541,all(known(63560),negate({type='BUFF',unit='pet',spell=63560}),negate(infusion))),
   spell('ucap-death-coil-cap',47541,rp('GREATERTHANOREQUALS',90)),
   spell('ucap-scourge-capped',55090,any(rune(3,2),rune(4,2))),
   spell('ucap-festering-capped',85948,all(rune(1,2),rune(2,2))),
   spell('ucap-sudden-doom',47541,buff(81340)),
   spell('ucap-scourge-strike',55090),
   spell('ucap-festering-strike',85948),
   spell('ucap-blood-strike',45902,negate(known(85948))),
   spell('ucap-death-coil',47541,rp('GREATERTHANOREQUALS',40)),
   spell('ucap-horn-filler',57330),
  },
 },
}))
