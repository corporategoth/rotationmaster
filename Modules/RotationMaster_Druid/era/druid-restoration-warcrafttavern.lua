-- Classic Era Druid Restoration after Warcraft Tavern's damage tiers: no HoT upkeep at low damage.
-- Nature's Swiftness Healing Touch, Swiftmend under 40%, rank 5 Regrowth under 50%, Rejuvenation and
-- rank 3 Regrowth under 75%, full Healing Touch on a Nature's Grace proc, rank 3 Healing Touch under
-- 90%. Same switch as rm.era.druid.restoration at a lower priority.
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
 format='RotationMaster',schemaVersion=1,id='rm.era.druid.restoration.warcrafttavern',revision=2,
 blocks={['era.druid.boundaries']=2,['era.druid.upkeep']=1,['era.druid.heal-cooldowns']=1,['era.druid.resto-damage']=1},
 nameKey='Default.Era.Druid.Restoration.WarcraftTavern.Name',descriptionKey='Default.Era.Druid.Restoration.WarcraftTavern.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',minLevel=10,maxLevel=60},
 tags={'endgame','restoration','healer','group','warcraft-tavern'},
 sources={
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-druid-restoration/',title='Warcraft Tavern: Classic Restoration Druid',reviewedAt='2026-10-23'},
 },
 body={priority=29,switch={type='PRIMARY_TALENT_TREE',tree=3},
  cooldowns={ref('era-resto-wt-upkeep','era.druid.upkeep','era-resto-wt-'),ref('era-resto-wt-cooldowns','era.druid.heal-cooldowns','era-resto-wt-')},
  rotation={
   ref('era-resto-wt-boundaries','era.druid.boundaries','era-resto-wt-'),
   {id='era-resto-wt-feral-form',type='none',conditions=any(form(768),form(5487),form(9634))},
   {id='era-resto-wt-heal',type='branch',conditions=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'})),onFalse={},onTrue={
    spell('era-resto-wt-swiftness',5185,own(17116)),
    spell('era-resto-wt-swiftmend',18562,all(hp(.4),any(hot(774),hot(8936)))),
    spell('era-resto-wt-regrowth-rank5',8941,hp(.5),true),
    spell('era-resto-wt-rejuvenation',774,all(negate(hot(774)),hp(.75))),
    spell('era-resto-wt-regrowth-rank3',8939,all(negate(hot(8936)),hp(.75)),true),
    spell('era-resto-wt-natures-grace-touch',5185,all(own(16886),hp(.9))),
    spell('era-resto-wt-touch-rank3',5187,hp(.9),true),
    spell('era-resto-wt-touch',5185,hp(.9)),
    {id='era-resto-wt-heal-stop',type='none',suppress_attack=true,conditions={}}}},
   ref('era-resto-wt-damage','era.druid.resto-damage','era-resto-wt-enemy-'),
   {id='era-resto-wt-stop',type='none',suppress_attack=true,conditions={}},
  },
 },
}))
