-- Season of Discovery Druid Restoration: chosen when Lifebloom is engraved, or Restoration is the
-- primary tree with no other legs rune. After Icy Veins (Warcraft Tavern for the procs): acts on the
-- current friendly target. Instant Healing Touch on Nature's Swiftness or Fury of Stormrage, Wild
-- Growth on a hurt group, Swiftmend for Efflorescence or an emergency, three Lifebloom stacks,
-- Rejuvenation, Regrowth, Nourish, rank 4 Healing Touch. Tree of Life and Survival Instincts are
-- reminders for heavy moments. On an enemy: Sunfire, Moonfire, Wrath.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function hp(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function hurt(health,count)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=count}end
local function combat()return{type='COMBAT',unit='player'}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.restoration',revision=1,
 blocks={['era.druid.boundaries']=1,['era.druid.upkeep']=1,['era.druid.heal-cooldowns']=1,['era.druid.resto-damage']=1},
 nameKey='Default.SoD.Druid.Restoration.Name',descriptionKey='Default.SoD.Druid.Restoration.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','restoration','healer','group','icy-veins','warcraft-tavern'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/restoration-druid-healer-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Restoration Druid rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/druid-healer/',title='Warcraft Tavern: SoD Druid healer (Phase 4)',reviewedAt='2026-10-23'},
 },
 body={priority=130,switch=any(known(408124),all(negate(known(407988)),negate(known(417157)),{type='PRIMARY_TALENT_TREE',tree=3})),
  cooldowns={
   ref('sod-resto-upkeep','era.druid.upkeep','sod-resto-'),ref('sod-resto-cooldowns','era.druid.heal-cooldowns','sod-resto-'),
   spell('sod-resto-tree-of-life',439733,all(combat(),negate(own(439733)),hurt(.7,3)),true),
   spell('sod-resto-survival-instincts',408024,all(combat(),hurt(.8,2)),true),
   spell('sod-resto-revive',437138,all(negate(combat()),{type='FRIENDLY',unit='target'},{type='DEAD',unit='target'}),true),
  },
  rotation={
   ref('sod-resto-boundaries','era.druid.boundaries','sod-resto-'),
   {id='sod-resto-feral-form',type='none',conditions=any(own(768),own(5487),own(9634))},
   {id='sod-resto-heal',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('sod-resto-instant-touch',5185,any(own(17116),{type='BUFF',unit='player',spell=414800,anyrank=true})),
    spell('sod-resto-wild-growth',408120,hurt(.9,2),true),
    spell('sod-resto-swiftmend',18562,all(any(hot(774),hot(8936)),any(hurt(.9,3),hp(.4)))),
    spell('sod-resto-lifebloom',408124,all(any(negate(hot(408124)),{type='BUFF_STACKS',unit='target',spell=408124,anyrank=true,ownbuff=true,operator='LESSTHAN',value=3},
     {type='BUFF_REMAIN',unit='target',spell=408124,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1}),any(combat(),hp(.98))),true),
    spell('sod-resto-rejuvenation',774,all(negate(hot(774)),hp(.9))),
    spell('sod-resto-regrowth',8936,all(negate(hot(8936)),hp(.6))),
    spell('sod-resto-nourish',408247,hp(.85),true),
    spell('sod-resto-touch-rank4',5188,hp(.85),true),
    spell('sod-resto-touch',5185,hp(.85)),
    {id='sod-resto-heal-stop',type='none',suppress_attack=true,conditions={}}}},
   ref('sod-resto-damage','era.druid.resto-damage','sod-resto-enemy-'),
   {id='sod-resto-stop',type='none',suppress_attack=true,conditions={}},
  },
 },
}))
