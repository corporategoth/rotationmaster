-- Classic Era Elemental Shaman, wowsims order (alternative premade; same switch, lower priority).
-- The only measured list: Chain Lightning on cooldown even on one target, Earth Shock while
-- Elemental Mastery is up, otherwise Lightning Bolt (wowsims also drops to rank 4 below 30% mana,
-- which Rotation Master cannot pin). Same boundaries, interrupt and reminders as the recommended
-- premade (era/blocks.lua). Mana-hungry by design.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.shaman.elemental.wowsims',revision=1,
 blocks={['era.shaman.manual']=1,['era.shaman.interrupt']=1,['era.shaman.shield']=1,['era.shaman.self-heal']=1,['era.shaman.caster-totems']=1},
 nameKey='Default.Era.Shaman.Elemental.Wowsims.Name',descriptionKey='Default.Era.Shaman.Elemental.Wowsims.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN',minLevel=10,maxLevel=60},
 tags={'dps','ranged','caster','endgame','wowsims'},
 sources={{url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/elemental_shaman/apls/default.apl.json',title='wowsims/classic: Elemental Shaman default APL',reviewedAt='2026-10-23',revision='7779ebbf79dc7f1341e6ab939b28a3402c9a730a'}},
 body={priority=21,switch={type='PRIMARY_TALENT_TREE',tree=1},
 cooldowns={
  block('era.shaman.shield','ele-ws-'),
  block('era.shaman.caster-totems','ele-ws-'),
  spell('ele-ws-elemental-mastery',16166,combat()),
  block('era.shaman.self-heal','ele-ws-'),
 },
 rotation={
 block('era.shaman.manual','ele-ws-'),
 {id='ele-ws-no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 block('era.shaman.interrupt','ele-ws-'),
 spell('ele-ws-chain-lightning',421),
 spell('ele-ws-mastery-shock',8042,{type='BUFF',unit='player',spell=16166}),
 spell('ele-ws-bolt',403),
 }},
}))
