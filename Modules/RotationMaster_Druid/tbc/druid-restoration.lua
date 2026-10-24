-- Restoration (Icy Veins, Wowhead, Warcraft Tavern agree): Tree of Life, Nature's
-- Swiftness and Healing Touch in emergencies, Swiftmend a dying target that carries a
-- HoT, three rolling Lifeblooms in combat, Rejuvenation and Regrowth HoTs, then Regrowth
-- (in Tree) or Healing Touch as the direct heal. Heals act on your friendly target (or
-- none); a hostile target gets Moonfire and Wrath while soloing. Downranking is manual.
-- Shared blocks: Defaults/blocks/druid.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function hot(id)return{type='BUFF',unit='target',spell=id,anyrank=true,ownbuff=true}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function combat()return{type='COMBAT',unit='player'}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.druid.restoration',revision=4,
 blocks={['tbc.druid.boundaries']=4,['tbc.druid.feral-form-stop']=3,['tbc.druid.upkeep']=1},
 nameKey='Default.TBC.Druid.Restoration.Name',descriptionKey='Default.TBC.Druid.Restoration.Description',
 applicability={families={'tbc'},actionContext='player',class='DRUID'},
 tags={'leveling','endgame','restoration','healer','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/tbc-classic/restoration-druid-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Restoration Druid rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/restoration-druid-leveling-guide',title='Icy Veins: Restoration Druid leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/druid/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Restoration Druid healing',reviewedAt='2026-10-23',revision='2024-05-18'},
  {url='https://www.warcrafttavern.com/tbc/guides/pve-restoration-druid-healing-rotation-cooldowns-abilities/',title='Warcraft Tavern: Restoration Druid healing',reviewedAt='2026-10-23'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={
   {id='resto-upkeep',type='block',block='tbc.druid.upkeep',prefix='resto-'},
   {id='resto-tree-of-life',type='spell',action=33891,ranked=false,conditions=negate(any({type='FORM',form=33891},{type='FORM',form=768},{type='FORM',form=5487},{type='FORM',form=9634},{type='FORM',form=783},{type='FORM',form=1066},{type='FORM',form=33943},{type='FORM',form=40120}))},
   {id='resto-swiftness',type='spell',action=17116,ranked=false,conditions=all(combat(),{type='FRIENDLY',unit='target'},hurt(0.3))},
   {id='resto-tranquility',type='spell',action=740,ranked=false,conditions=all(combat(),{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=0.6,operator='GREATERTHANOREQUALS',value=3,distance=30})},
   {id='resto-innervate',type='spell',action=29166,ranked=false,conditions=all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.25})},
   {id='resto-rebirth',type='spell',action=20484,ranked=false,conditions=all(combat(),{type='FRIENDLY',unit='target'},{type='DEAD',unit='target'})},
  },
  rotation={
   {id='resto-boundaries',type='block',block='tbc.druid.boundaries',prefix='resto-'},
   {id='resto-forms',type='block',block='tbc.druid.feral-form-stop',prefix='resto-'},
   {id='resto-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onTrue={
    {id='resto-moonfire',type='spell',action=8921,ranked=false,conditions=negate({type='DEBUFF',unit='target',spell=8921,anyrank=true,owndebuff=true})},
    {id='resto-wrath',type='spell',action=5176,ranked=false,conditions=negate({type='MOVING'})},
   },onFalse={
    {id='resto-enemy',type='stop',suppress_attack=true,conditions={type='ENEMY',unit='target'}},
    {id='resto-swift-touch',type='spell',action=5185,ranked=false,conditions=own(17116)},
    {id='resto-swiftmend',type='spell',action=18562,ranked=false,conditions=all(hurt(0.4),any(hot(774),hot(8936)))},
    {id='resto-lifebloom',type='spell',action=33763,ranked=false,conditions=all(combat(),{type='FRIENDLY',unit='target'},
     any(negate(hot(33763)),{type='BUFF_STACKS',unit='target',spell=33763,ownbuff=true,operator='LESSTHAN',value=3},{type='BUFF_REMAIN',unit='target',spell=33763,ownbuff=true,operator='LESSTHANOREQUALS',value=1.5}))},
    {id='resto-rejuvenation',type='spell',action=774,ranked=false,conditions=all(hurt(0.95),negate(hot(774)))},
    {id='resto-regrowth-hot',type='spell',action=8936,ranked=false,conditions=all(hurt(0.8),negate(hot(8936)))},
    {id='resto-tree',type='branch',conditions={type='FORM',form=33891},onTrue={
     {id='resto-tree-regrowth',type='spell',action=8936,ranked=false,conditions=hurt(0.7)},
    },onFalse={
     {id='resto-touch',type='spell',action=5185,ranked=false,conditions=hurt(0.5)},
     {id='resto-regrowth',type='spell',action=8936,ranked=false,conditions=hurt(0.7)},
    }},
    {id='resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
   }},
  },
 },
}))
