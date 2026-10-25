-- Restoration (Icy Veins order, Wowhead upkeep): emergency Nature's Swiftness and
-- Lesser Healing Wave, cures, Earth Shield on the focus, Chain Heal for group damage,
-- Healing Wave for single-target damage. Heals act on your friendly target (or none);
-- a hostile target gets the solo-leveling damage filler instead. Rank choice is manual.
-- Shared blocks: Defaults/blocks/shaman.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function group()return{type='GROUP'}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.shaman.restoration',revision=4,
 blocks={['tbc.shaman.shield']=1,['tbc.shaman.bloodlust']=1,['tbc.shaman.boundaries']=3,['tbc.shaman.interrupt']=1},
 nameKey='Default.TBC.Shaman.Restoration.Name',descriptionKey='Default.TBC.Shaman.Restoration.Description',
 applicability={families={'tbc'},actionContext='player',class='SHAMAN'},
 tags={'leveling','endgame','restoration','healer','icy-veins','wowhead'},
 sources={{url='https://www.icy-veins.com/tbc-classic/restoration-shaman-healer-pve-rotation-cooldowns-abilities',title='Icy Veins: Restoration Shaman rotation',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.icy-veins.com/tbc-classic/restoration-shaman-leveling-guide',title='Icy Veins: Restoration Shaman leveling',reviewedAt='2026-10-23',revision='2026-01-12'},
  {url='https://www.wowhead.com/tbc/guide/classes/shaman/healer-rotation-cooldowns-abilities-pve',title='Wowhead: Restoration Shaman healing',reviewedAt='2026-10-23',revision='2024-02-28',notes='Water Shield and Earth Shield upkeep.'}},
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='PRIMARY_TALENT_TREE',tree=3}}},
  cooldowns={
   {id='resto-shield',type='block',block='tbc.shaman.shield',prefix='resto-'},
   {id='resto-earth-shield-focus',type='spell',action=974,ranked=false,conditions=all({type='FRIENDLY',unit='focus'},negate({type='BUFF',unit='focus',spell=974,anyrank=true,ownbuff=true}))},
   {id='resto-mana-tide',type='spell',action=16190,ranked=false,conditions=all(combat(),group(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=0.6})},
   {id='resto-mana-spring',type='spell',action=5675,ranked=false,conditions=all(combat(),group(),negate({type='TOTEM',spell=3}))},
   {id='resto-strength-of-earth',type='spell',action=8075,ranked=false,conditions=all(combat(),group(),negate({type='TOTEM',spell=2}))},
   {id='resto-lust',type='block',block='tbc.shaman.bloodlust',prefix='resto-'},
  },
  rotation={
   {id='resto-boundaries',type='block',block='tbc.shaman.boundaries',prefix='resto-'},
   {id='resto-hostile',type='branch',conditions={type='ATTACKABLE',unit='target'},onTrue={
    {id='resto-kick',type='block',block='tbc.shaman.interrupt',prefix='resto-'},
    {id='resto-flame-shock',type='spell',action=8050,ranked=false,conditions=all(negate({type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}),negate({type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=12}))},
    {id='resto-bolt',type='spell',action=403,ranked=false,conditions=negate({type='MOVING'})},
   },onFalse={
    {id='resto-enemy',type='stop',suppress_attack=true,conditions={type='ENEMY',unit='target'}},
    {id='resto-swift-wave',type='spell',action=331,ranked=false,conditions={type='BUFF',unit='player',spell=16188,ownbuff=true}},
    {id='resto-swiftness',type='spell',action=16188,ranked=false,conditions=hurt(0.3)},
    {id='resto-lesser-wave',type='spell',action=8004,ranked=false,conditions=hurt(0.4)},
    {id='resto-cure-poison',type='spell',action=526,ranked=false,conditions={type='DISPELLABLE',unit='target',debufftype='Poison'}},
    {id='resto-cure-disease',type='spell',action=2870,ranked=false,conditions={type='DISPELLABLE',unit='target',debufftype='Disease'}},
    {id='resto-earth-shield',type='spell',action=974,ranked=false,conditions=all({type='ISSAME',unit='target',otherunit='focus'},negate({type='BUFF',unit='target',spell=974,anyrank=true,ownbuff=true}))},
    {id='resto-chain-heal',type='spell',action=1064,ranked=false,conditions={type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=0.85,operator='GREATERTHANOREQUALS',value=3,distance=40}},
    {id='resto-healing-wave',type='spell',action=331,ranked=false,conditions=hurt(0.9)},
    {id='resto-heal-stop',type='stop',suppress_attack=true,conditions={}},
   }},
  },
 },
}))
