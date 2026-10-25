-- Mists of Pandaria Classic Protection Paladin after the wowsims tank lists (Sha, Horridon, Iron
-- Juggernaut) and wowtbc.gg, levels 10–90: an alternative to rm.mop.paladin.protection, off by
-- default (same switch, lower priority). Shield of the Righteous pools to full Holy Power unless
-- you drop below 40% health; Eternal Flame just before it fades with more than two Bastion of Glory
-- stacks at 3 Holy Power (or free with the tier-16 proc); Sacred Shield kept up; Holy Avenger and
-- Avenging Wrath on cooldown. Generators: Crusader Strike, Judgment, then Avenger's Shield, with
-- Hammer of Wrath low. Boss-timed defensives stay manual.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function hp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.paladin.protection.wowsims',revision=7,
 blocks={['mop.paladin.damage-boundaries']=2,['mop.paladin.upkeep']=1,['mop.paladin.seal-insight']=2,['mop.paladin.prot-upkeep']=1,['mop.paladin.prot-open']=4,['mop.paladin.prot-aoe']=2},
 nameKey='Default.MoP.Paladin.Protection.Wowsims.Name',descriptionKey='Default.MoP.Paladin.Protection.Wowsims.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PALADIN'},
 tags={'protection','tank','single-target','aoe','wowsims'},
 sources={
  {url='https://github.com/wowsims/mop/blob/master/ui/specs/paladin/protection/apls/sha.apl.json',title='wowsims MoP: Protection APLs (Sha, Horridon, Iron Juggernaut)',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://wowtbc.gg/mop/class-guides/protection-paladin/',title='wowtbc.gg: MoP Protection Paladin guide',reviewedAt='2026-10-23',notes='Same generator order; Sacred Shield maintained.'},
 },
 body={priority=20,disabled=true,specs={66},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('protsim-upkeep','mop.paladin.prot-upkeep','protsim-'),
   block('protsim-class','mop.paladin.upkeep','protsim-'),
   spell('protsim-eternal-flame',114163,all(any(negate(own(114163)),{type='BUFF_REMAIN',unit='player',spell=114163,ownbuff=true,operator='LESSTHAN',value=2}),
    {type='BUFF_STACKS',unit='player',spell=114637,operator='GREATERTHAN',value=2},any(hp('GREATERTHANOREQUALS',3),buff(144569)))),
   spell('protsim-shield-righteous',53600,all(combat(),any(hp('LESSTHAN',-1),buff(90174),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4}))),
   spell('protsim-sacred-shield',20925,any(negate(own(65148)),{type='BUFF_REMAIN',unit='player',spell=65148,ownbuff=true,operator='LESSTHAN',value=5})),
   spell('protsim-holy-avenger',105809,combat()),
   spell('protsim-avenging-wrath',31884,combat()),
  },
  rotation={
   block('protsim-boundaries','mop.paladin.damage-boundaries','protsim-'),
   block('protsim-open','mop.paladin.prot-open','protsim-'),
   block('protsim-aoe','mop.paladin.prot-aoe','protsim-'),
   spell('protsim-crusader-strike',35395),
   spell('protsim-judgment',20271),
   spell('protsim-avengers-shield',31935),
   spell('protsim-holy-wrath',119072),
   spell('protsim-execution-sentence',114157),
   spell('protsim-lights-hammer',114158),
   spell('protsim-hammer-wrath',24275),
   spell('protsim-consecration',26573),
   spell('protsim-holy-prism',114165),
   spell('protsim-sacred-shield-filler',20925),
  },
 },
}))
