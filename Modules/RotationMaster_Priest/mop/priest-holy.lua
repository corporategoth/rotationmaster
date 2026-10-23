-- Mists of Pandaria Classic Holy Priest, levels 10-90 (the recommended variant): Warcraft Tavern's and Icy Veins'
-- order with Hekili's thresholds. Selected while Holy Word: Chastise (or Holy's Meditation) is known. A friendly
-- target is healed: Holy Word: Serenity in Chakra: Serenity; Power Word: Shield only when the target is about to
-- die; Flash Heal on Surge of Light; Prayer of Mending; Flash Heal when very low; Binding Heal; with three hurt
-- allies in a group Circle of Healing, Holy Word: Sanctuary (in Chakra: Sanctuary; you place it), the tier-6
-- talent and Prayer of Healing; Renew; Greater Heal when low or at two Serendipity; Heal. An empty chakra is filled
-- by group size (Sanctuary in a raid, Serenity in a party, Chastise solo) and never swapped. An enemy target runs
-- the damage arm (mop/blocks.lua). Choosing whom to heal, Lightwell and Void Shift stay with you. The Icy Veins
-- variant puts emergency heals last.
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
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friendly={type='FRIENDLY',unit='target'}
local group={type='GROUP'}
local unshielded=negate({type='DEBUFF',unit='target',spell=6788})
local nochakra=all(negate(own(81208)),negate(own(81206)),negate(own(81209)))
local aoe=hurt(3,.85)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.priest.holy',revision=1,
 blocks={['mop.priest.upkeep']=1,['mop.priest.healer-boundaries']=1,['mop.priest.healer-cooldowns']=1,['mop.priest.holy-damage']=1},
 nameKey='Default.MoP.Priest.Holy.Name',descriptionKey='Default.MoP.Priest.Holy.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='PRIEST',minLevel=10,maxLevel=90},
 tags={'holy','healer','group','leveling','endgame','warcraft-tavern','icy-veins','hekili'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-holy-priest-rotations-cooldowns/',title='Warcraft Tavern: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-pve-rotation-cooldowns-abilities',title='Icy Veins: Holy Priest rotation (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.icy-veins.com/mists-of-pandaria-classic/holy-priest-leveling',title='Icy Veins: Holy Priest levelling (MoP Classic)',reviewedAt='2026-10-23',revision='2025-12-05'},
 {url='https://www.method.gg/mop-classic/holy-priest-class-guide-mop-classic',title='Method: Holy Priest guide (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://wowtbc.gg/mop/class-guides/holy-priest/',title='wowtbc.gg: Holy Priest (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/PriestHoly.simc',title='Hekili (MoP fork): Holy Priest priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,switch={type='OR',value={{type='SPELL_KNOWN',spell=88625},{type='SPELL_KNOWN',spell=95861}}},
 cooldowns={block('mop.priest.upkeep','priest-'),block('mop.priest.healer-cooldowns','priest-'),
  spell('priest-holy-sanctuary-chakra',81206,all(nochakra,{type='GROUP',raid=true})),
  spell('priest-holy-serenity-chakra',81208,all(nochakra,group,negate({type='GROUP',raid=true}))),
  spell('priest-holy-chastise-chakra',81209,all(nochakra,negate(group))),
  spell('priest-holy-guardian-spirit',47788,all(combat(),friendly,low(.25))),
  spell('priest-holy-divine-hymn',64843,all(combat(),hurt(5,.5))),
  spell('priest-holy-desperate-prayer',19236,health('player','LESSTHAN',.5)),
 },
 rotation={
 block('mop.priest.healer-boundaries','priest-holy-'),
 {id='priest-holy-heal',type='branch',conditions=all(friendly,negate({type='DEAD',unit='target'})),onTrue={
  spell('priest-holy-serenity',88625,all(own(81208),low(.9))),
  spell('priest-holy-shield',17,all(low(.25),unshielded)),
  spell('priest-holy-surge',2061,own(114255)),
  spell('priest-holy-mending',33076,combat()),
  spell('priest-holy-flash',2061,low(.35)),
  spell('priest-holy-binding',32546,all(health('player','LESSTHAN',.7),low(.7),negate({type='ISSAME',unit='target',otherunit='player'}))),
  {id='priest-holy-group',type='branch',conditions=group,onFalse={},onTrue={
   spell('priest-holy-circle',34861,aoe),
   spell('priest-holy-sanctuary',88625,all(own(81206),aoe)),
   spell('priest-holy-halo',120517,aoe),
   spell('priest-holy-cascade',121135,aoe),
   spell('priest-holy-divine-star',110744,aoe),
   spell('priest-holy-prayer',596,aoe),
   {id='priest-holy-nova',type='spell',action=132157,ranked=false,disabled=true,conditions=all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4})},
  }},
  spell('priest-holy-renew',139,all(low(.95),negate({type='BUFF',unit='target',spell=139,ownbuff=true}))),
  spell('priest-holy-greater',2060,any(low(.6),{type='BUFF_STACKS',unit='player',spell=63735,ownbuff=true,operator='GREATERTHANOREQUALS',value=2})),
  spell('priest-holy-heal-spell',2050,low(.9)),
  stop('priest-holy-heal-stop'),
 },onFalse={block('mop.priest.holy-damage','priest-holy-dmg-')}},
 }},
}))
