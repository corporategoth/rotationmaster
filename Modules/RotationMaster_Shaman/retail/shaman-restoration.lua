-- Retail (Midnight) Restoration Shaman, Icy Veins. Blizzard's Assisted Combat does not cover
-- healers, health is hidden in Midnight combat and RM picks a spell, not a target, so this orders
-- your healing tools by readiness on whatever you target and leaves triage to you. Friendly
-- target: Healing Stream Totem, Unleash Life, Healing Rain and Chain Heal in a group, Surging
-- Totem, Riptide, Healing Wave. Enemy: Flame Shock when missing, Lava Burst, Lightning Bolt.
-- Reminders: Water Shield, Earth Shield on a friendly target and Skyfury between pulls; Nature's
-- Swiftness in combat; Healing Tide and Spirit Link in grouped combat; Wind Shear; Astral Shift.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local friend=all({type='LEVEL',unit='target',operator='GREATERTHAN',value=0},{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
local grouped=all(combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.shaman.restoration',revision=3,
 blocks={['retail.shaman.upkeep']=2},
 nameKey='Default.Retail.Shaman.Restoration.Name',descriptionKey='Default.Retail.Shaman.Restoration.Description',
 applicability={families={'retail'},actionContext='player',class='SHAMAN'},
 tags={'restoration','healer','reference','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/restoration-shaman-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Restoration Shaman healing rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
 },
 body={priority=10,switch={type='SPECIALIZATION',spec=264},
  cooldowns={
   block('retail.shaman.upkeep','resto-'),
   spell('resto-water-shield',52127,all(negate(combat()),negate({type='BUFF',unit='player',spell=52127,ownbuff=true}))),
   spell('resto-earth-shield',974,all(negate(combat()),friend,negate({type='BUFF',unit='target',spell=974,ownbuff=true}))),
   spell('resto-natures-swiftness',378081,combat()),
   spell('resto-healing-tide',108280,grouped),
   spell('resto-spirit-link',98008,grouped),
  },
  rotation={
   {id='resto-casting',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
   {id='resto-friendly',type='branch',conditions=friend,onFalse={},onTrue={
    spell('resto-healing-stream',5394),
    spell('resto-unleash-life',73685),
    spell('resto-healing-rain',73920,{type='GROUP'}),
    spell('resto-surging-totem',444995),
    spell('resto-riptide',61295),
    spell('resto-chain-heal',1064,{type='GROUP'}),
    spell('resto-healing-wave',77472),
    {id='resto-friendly-stop',type='none',suppress_attack=true,conditions={}},
   }},
   {id='resto-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
   spell('resto-flame-shock',470411,negate({type='DEBUFF',unit='target',spell=188389,owndebuff=true})),
   spell('resto-lava-burst',51505),
   spell('resto-lightning-bolt',188196),
  },
 },
}))
