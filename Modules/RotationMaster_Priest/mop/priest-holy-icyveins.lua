-- Mists of Pandaria Classic Holy Priest, Icy Veins order (a player-chosen variant, off by default). The chakra
-- picks the list. Chakra: Sanctuary: Holy Word: Sanctuary on three hurt allies, Renew, Circle of Healing, Prayer of
-- Mending, Prayer of Healing, then Binding Heal and Flash Heal only in emergencies. Otherwise (Serenity, or no
-- chakra yet): Renew, Holy Word: Serenity, Prayer of Mending, Greater Heal when low or at two Serendipity, Heal,
-- Binding Heal, Flash Heal when very low or on Surge of Light, Power Word: Shield last, and Flash Heal as the
-- filler before Heal is learned. Same switch, chakra fill, reminders and damage arm as the recommended Holy
-- premade (mop/blocks.lua).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function low(n)return health('target','LESSTHAN',n)end
local function hurt(n,below)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friendly={type='FRIENDLY',unit='target'}
local group={type='GROUP'}
local unshielded=negate({type='DEBUFF',unit='target',spell=6788})
local nochakra=all(negate(own(81208)),negate(own(81206)),negate(own(81209)))
local aoe=all(group,hurt(3,.85))
local renew=all(low(.95),negate({type='BUFF',unit='target',spell=139,ownbuff=true}))
local binding=all(health('player','LESSTHAN',.7),low(.7),negate({type='ISSAME',unit='target',otherunit='player'}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.holy.icyveins',revision=6,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=2,['mop.priest.healer-cooldowns']=1,['mop.priest.holy-damage']=2},
 nameKey='Default.MoP.Priest.Holy.IcyVeins.Name',descriptionKey='Default.MoP.Priest.Holy.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST'},
 tags={'holy','healer','group','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-leveling',title='Icy Veins: Holy Priest leveling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'}},
 body={priority=20,disabled=true,specs={257},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.healer-cooldowns','priest-'),
  spell('priest-holy-iv-sanctuary-chakra',81206,all(nochakra,{type='GROUP',raid=true})),
  spell('priest-holy-iv-serenity-chakra',81208,all(nochakra,group,negate({type='GROUP',raid=true}))),
  spell('priest-holy-iv-chastise-chakra',81209,all(nochakra,negate(group))),
  spell('priest-holy-iv-guardian-spirit',47788,all(combat(),friendly,low(.25))),
  spell('priest-holy-iv-divine-hymn',64843,all(combat(),hurt(5,.5))),
  spell('priest-holy-iv-desperate-prayer',19236,health('player','LESSTHAN',.5)),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-holy-iv-'),
 {id='priest-holy-iv-heal',type='branch',conditions=all(friendly,negate({type='DEAD',unit='target'})),onTrue={
  {id='priest-holy-iv-mode',type='branch',conditions=own(81206),onTrue={
   spell('priest-holy-iv-sanctuary',88625,aoe),
   spell('priest-holy-iv-raid-renew',139,renew),
   spell('priest-holy-iv-circle',34861,aoe),
   spell('priest-holy-iv-raid-mending',33076,combat()),
   spell('priest-holy-iv-prayer',596,aoe),
   spell('priest-holy-iv-raid-binding',32546,binding),
   spell('priest-holy-iv-raid-flash',2061,any(own(114255),low(.35))),
  },onFalse={
   spell('priest-holy-iv-renew',139,renew),
   spell('priest-holy-iv-serenity',88625,all(own(81208),low(.9))),
   spell('priest-holy-iv-mending',33076,combat()),
   spell('priest-holy-iv-greater',2060,any(low(.6),{type='BUFF_STACKS',unit='player',spell=63735,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
   spell('priest-holy-iv-heal-spell',2050,low(.9)),
   spell('priest-holy-iv-binding',32546,binding),
   spell('priest-holy-iv-flash',2061,any(own(114255),low(.35))),
   spell('priest-holy-iv-shield',17,all(low(.25),unshielded)),
   spell('priest-holy-iv-flash-filler',2061,low(.9)),
  }},
  stop('priest-holy-iv-heal-stop'),
 },onFalse={block('mop.priest.holy-damage','priest-holy-iv-dmg-')}},
 }},
}))
