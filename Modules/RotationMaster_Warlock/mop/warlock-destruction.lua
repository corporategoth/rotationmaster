-- Mists of Pandaria Classic Destruction Warlock, levels 10-90: the guide consensus order (Warcraft Tavern,
-- Method, wowtbc.gg, Wowhead; Hekili's single-target list matches) with wowsims' Backdraft and Immolate
-- refinements. Selected in the Destruction specialization (267)
-- from level 10 (RM stores MoP rotations per talent group). Pre-cast Incinerate. Moving without Kil'jaeden's
-- Cunning: Shadowburn, Conflagrate, Fel Flame. Shadowburn a target about to die. Three or more engaged
-- enemies: Rain of Fire on four, Fire and Brimstone on four with an ember (toggled off again with none),
-- Immolate, Conflagrate, Incinerate. Otherwise Immolate kept up (refreshed early in Dark Soul), Shadowburn
-- below 20% in Dark Soul or at 3.5 embers, Conflagrate at two charges, Chaos Bolt in Dark Soul or at 3.5
-- embers (not on a three-stack Backdraft), Conflagrate without Backdraft, Incinerate with it, Conflagrate,
-- Incinerate. Havoc is a reminder: it needs a second target. Shared parts: mop/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=n}end
local function embers(op,n)return{type='POINT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id)return{id=id,type='none',suppress_attack=true,conditions={}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local soul=own(113858)
local backdraft=own(117828)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.warlock.destruction',revision=4,
 blocks={['mop.warlock.boundaries']=3,['mop.warlock.upkeep']=1,['mop.warlock.pet-felhunter']=1},
 nameKey='Default.MoP.Warlock.Destruction.Name',descriptionKey='Default.MoP.Warlock.Destruction.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='WARLOCK'},
 tags={'destruction','dps','caster','ranged','leveling','endgame','warcraft-tavern','method','wowtbc','wowsims'},
 sources={{url='https://www.warcrafttavern.com/mop/guides/pve-destruction-warlock-rotations-cooldowns/',title='Warcraft Tavern: Destruction Warlock rotation (MoP)',reviewedAt='2026-10-23'},
 {url='https://www.method.gg/mop-classic/destruction-warlock-class-guide-mop-classic',title='Method: Destruction Warlock guide (MoP Classic)',reviewedAt='2026-10-23',revision='2025-07-23'},
 {url='https://wowtbc.gg/mop/class-guides/destruction-warlock/',title='wowtbc.gg: Destruction Warlock (MoP Classic)',reviewedAt='2026-10-23'},
 {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/warlock/destruction/apls/default.apl.json',title='wowsims/mop: Destruction Warlock APL',reviewedAt='2026-10-23',revision='ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9'},
 {url='https://github.com/Smufrik/Hekili/blob/0750b5dd98005481baf828cce26149b9abca875b/MistsOfPandaria/Priorities/WarlockDestruction.simc',title='Hekili (MoP fork): Destruction Warlock priority',reviewedAt='2026-10-23',revision='0750b5dd98005481baf828cce26149b9abca875b'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=267}}},
 cooldowns={block('mop.warlock.upkeep','warlock-'),block('mop.warlock.pet-felhunter','warlock-'),
  spell('warlock-destro-dark-soul',113858,all(combat(),any(negate(soul),{type='SPELL_CHARGES',spell=113858,operator='GREATERTHANOREQUALS',value=2}))),
  spell('warlock-destro-grimoire-felhunter',111897,combat()),
  spell('warlock-destro-havoc',80240,all(combat(),enemies('GREATERTHANOREQUALS',2))),
  spell('warlock-destro-flames-of-xoroth',120451,all(combat(),talent(15),negate({type='BUFF',unit='player',spell=108503}),negate({type='PET'}))),
  spell('warlock-destro-ember-tap',114635,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 },
 rotation={
 block('mop.warlock.boundaries','warlock-'),
 {id='warlock-destro-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('warlock-destro-pull-incinerate',29722),
  stop('warlock-destro-pull-stop'),
 }},
 {id='warlock-destro-moving',type='branch',conditions=all({type='MOVING'},negate(talent(17))),onFalse={},onTrue={
  spell('warlock-destro-moving-shadowburn',17877),
  spell('warlock-destro-moving-conflagrate',17962),
  spell('warlock-destro-moving-fel-flame',77799),
  stop('warlock-destro-moving-stop'),
 }},
 spell('warlock-destro-snipe',17877,{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3}),
 {id='warlock-destro-aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',3),onFalse={},onTrue={
  spell('warlock-destro-rain-of-fire',5740,all(enemies('GREATERTHANOREQUALS',4),negate({type='SPELL_HISTORY_TIME',spell=5740,operator='LESSTHAN',value=7}))),
  spell('warlock-destro-brimstone-off',108683,all(own(108683),embers('LESSTHAN',1))),
  spell('warlock-destro-brimstone',108683,all(negate(own(108683)),enemies('GREATERTHANOREQUALS',4),embers('GREATERTHANOREQUALS',1))),
  spell('warlock-destro-aoe-immolate',348,negate(dot(348))),
  spell('warlock-destro-aoe-conflagrate',17962),
  spell('warlock-destro-aoe-incinerate',29722),
  stop('warlock-destro-aoe-stop'),
 }},
 spell('warlock-destro-immolate',348,any(negate(dot(348)),remain(348,'LESSTHAN',3),all(soul,remain(348,'LESSTHAN',7.5)))),
 spell('warlock-destro-shadowburn',17877,all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2},any(soul,embers('GREATERTHANOREQUALS',3.5)))),
 spell('warlock-destro-conflagrate-capped',17962,{type='SPELL_CHARGES',spell=17962,operator='GREATERTHANOREQUALS',value=2}),
 spell('warlock-destro-chaos-bolt',116858,all(any(negate(backdraft),{type='BUFF_STACKS',unit='player',spell=117828,ownbuff=true,operator='LESSTHAN',value=3}),
  any(soul,embers('GREATERTHANOREQUALS',3.5)))),
 spell('warlock-destro-conflagrate-fresh',17962,negate(backdraft)),
 spell('warlock-destro-incinerate-backdraft',29722,backdraft),
 spell('warlock-destro-conflagrate',17962),
 spell('warlock-destro-incinerate',29722),
 }},
}))
