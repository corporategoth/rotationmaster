-- Season of Discovery Druid Feral cat: chosen when Savage Roar is engraved, or Feral is the primary
-- tree with no other legs rune. After Wowhead's SoD decision tree with wowsims P5 and Icy Veins:
-- Faerie Fire (Feral), Savage Roar, Swipe (Cat) on four or more, the Mangle debuff, Clearcasting on
-- Shred, Rip at five combo points while Savage Roar lasts, Rake, Shred from behind, powershift.
-- Tiger's Fury and Berserk are reminders. In Bear Form it plays the SoD tank section.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function combat()return{type='COMBAT',unit='player'}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.feral',revision=2,
 blocks={['era.druid.boundaries']=1,['era.druid.upkeep']=1,['sod.druid.maul']=1,['sod.druid.cat']=2,['era.druid.stealth-opener']=1,
  ['era.druid.cat-builders']=1,['era.druid.powershift']=1,['sod.druid.bear']=1,['era.druid.feral-humanoid']=1},
 nameKey='Default.SoD.Druid.Feral.Name',descriptionKey='Default.SoD.Druid.Feral.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','feral','melee','single-target','aoe','wowhead','wowsims','icy-veins'},
 sources={
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2025-04-07'},
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/feral_druid/apls/phase_5.apl.json',title='wowsims/sod Feral Phase 5 APL',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.icy-veins.com/wow-classic/feral-druid-dps-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Feral Druid DPS rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 },
 body={priority=130,switch=any(rune(407988),all(negate(rune(409824)),negate(rune(417157)),{type='PRIMARY_TALENT_TREE',tree=2})),
  cooldowns={
   ref('sod-feral-upkeep','era.druid.upkeep','sod-feral-'),
   spell('sod-feral-tigers-fury',417045,all(combat(),own(768),{type='POWER',unit='player',operator='LESSTHANOREQUALS',value=60}),true),
   spell('sod-feral-berserk',417141,all(combat(),own(417045))),
   ref('sod-feral-maul','sod.druid.maul','sod-feral-'),
   spell('sod-feral-innervate',29166,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.3})),
  },
  rotation={
   ref('sod-feral-boundaries','era.druid.boundaries','sod-feral-'),
   {id='sod-feral-cat',type='branch',conditions=own(768),onFalse={},onTrue={ref('sod-feral-cat-section','sod.druid.cat','sod-feral-cat-')}},
   {id='sod-feral-bear',type='branch',conditions=any(own(5487),own(9634)),onFalse={},onTrue={ref('sod-feral-bear-section','sod.druid.bear','sod-feral-bear-')}},
   ref('sod-feral-humanoid','era.druid.feral-humanoid','sod-feral-'),
  },
 },
}))
