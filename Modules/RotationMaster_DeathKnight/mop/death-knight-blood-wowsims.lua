-- Mists of Pandaria Classic Blood Death Knight, health-reactive (wowsims Iron Juggernaut and Sha
-- APLs, readable parts only). Off by default, same switch as rm.mop.deathknight.blood: Death Strike
-- below 70% health, to restore or refresh Blood Shield, or before the Frost and Unholy runes cap,
-- rather than on every rune; Heart Strike also spends a lone Blood rune when the Frost and Unholy
-- runes are more than a second away. No AoE branch: the simulator tanks single bosses.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function disease(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rp(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function rune(kind,op,n)return{type='RUNE',rune=kind,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local FEVER,PLAGUE=55095,55078
local shield={type='BUFF',unit='player',spell=77535,ownbuff=true}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.deathknight.blood.wowsims',revision=5,
 blocks={['mop.deathknight.boundaries']=3,['mop.deathknight.upkeep']=1,['mop.deathknight.blood-upkeep']=2,['mop.deathknight.blood-pull']=2},
 nameKey='Default.MoP.DeathKnight.Blood.Wowsims.Name',descriptionKey='Default.MoP.DeathKnight.Blood.Wowsims.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DEATHKNIGHT'},
 tags={'blood','tank','single-target','wowsims'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/death_knight/blood/apls/iron_juggernaut.apl.json',title='wowsims/mop Blood Iron Juggernaut APL',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/death_knight/blood/apls/sha.apl.json',title='wowsims/mop Blood Sha APL',reviewedAt='2026-10-23',revision='ec2c6c2552'},
 },
 body={priority=25,disabled=true,specs={250},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('bsim-upkeep','mop.deathknight.blood-upkeep','bsim-'),
   block('bsim-class','mop.deathknight.upkeep','bsim-'),
  },
  rotation={
   block('bsim-boundaries','mop.deathknight.boundaries','bsim-'),
   block('bsim-pull','mop.deathknight.blood-pull','bsim-'),
   spell('bsim-death-strike-reactive',49998,any({type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7},
    all({type='SELF_LEVEL',operator='GREATERTHANOREQUALS',value=80},any(negate(shield),{type='BUFF_REMAIN',unit='player',spell=77535,ownbuff=true,operator='LESSTHAN',value=3})))),
   spell('bsim-death-strike-runes',49998,all(rune(2,'EQUALS',2),rune(3,'EQUALS',2))),
   spell('bsim-rune-strike-cap',56815,rp('GREATERTHANOREQUALS',90)),
   spell('bsim-death-coil-cap',47541,all(negate(known(56815)),rp('GREATERTHANOREQUALS',80))),
   spell('bsim-soul-reaper',114866,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35}),
   spell('bsim-heart-strike-capped',55050,rune(1,'EQUALS',2)),
   spell('bsim-blood-strike-capped',45902,all(negate(known(55050)),rune(1,'EQUALS',2))),
   spell('bsim-outbreak',77575,any(negate(disease(FEVER)),negate(disease(PLAGUE)))),
   spell('bsim-icy-touch',45477,negate(disease(FEVER))),
   spell('bsim-plague-strike',45462,negate(disease(PLAGUE))),
   spell('bsim-blood-tap',45529,{type='BUFF_STACKS',unit='player',spell=114851,operator='GREATERTHANOREQUALS',value=11}),
   spell('bsim-scourge-boil',48721,buff(81141)),
   spell('bsim-scourge-decay',43265,buff(81141)),
   spell('bsim-heart-strike',55050,all({type='RUNE_COOLDOWN',rune=2,operator='GREATERTHAN',value=1},{type='RUNE_COOLDOWN',rune=3,operator='GREATERTHAN',value=1})),
   spell('bsim-blood-strike',45902,all(negate(known(55050)),{type='RUNE_COOLDOWN',rune=2,operator='GREATERTHAN',value=1},{type='RUNE_COOLDOWN',rune=3,operator='GREATERTHAN',value=1})),
   spell('bsim-rune-strike',56815),
   spell('bsim-horn-filler',57330),
  },
 },
}))
