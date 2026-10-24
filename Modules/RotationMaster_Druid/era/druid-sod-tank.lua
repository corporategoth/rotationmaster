-- Season of Discovery Druid bear tank: chosen when Lacerate is engraved. After Icy Veins, wowsims P6
-- and Warcraft Tavern: Faerie Fire (Feral) or Sunfire (Bear) from range, Lacerate before it drops,
-- Mangle (Bear) on cooldown, Lacerate, Swipe; on three or more, Mangle under Berserk and Swipe.
-- Maul with 30 rage, Berserk, Survival Instincts, Frenzied Regeneration, Barkskin, Enrage and
-- Demoralizing Roar are reminders. In Cat Form (off-tanking) it plays the SoD cat section.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function form(id)return{type='FORM',form=id}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.tank',revision=5,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['sod.druid.maul']=2,['sod.druid.tank-cooldowns']=2,['sod.druid.bear']=2,['sod.druid.cat']=2,
  ['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.tank-humanoid']=2},
 nameKey='Default.SoD.Druid.Tank.Name',descriptionKey='Default.SoD.Druid.Tank.Description',
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','feral','tank','melee','single-target','aoe','icy-veins','wowsims','warcraft-tavern'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/feral-druid-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Feral Druid tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/feral_tank_druid/apls/phase_6.apl.json',title='wowsims/sod Feral tank Phase 6 APL',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.warcrafttavern.com/wow-classic-sod/guides/druid-tank/',title='Warcraft Tavern: SoD Druid tank (Phase 4)',reviewedAt='2026-10-23'},
 },
 body={priority=140,switch={type='RUNE_ENGRAVED',spell=414644},
  cooldowns={ref('sod-tank-upkeep','era.druid.upkeep','sod-tank-'),ref('sod-tank-maul','sod.druid.maul','sod-tank-'),ref('sod-tank-cooldowns','sod.druid.tank-cooldowns','sod-tank-')},
  rotation={
   ref('sod-tank-boundaries','era.druid.boundaries','sod-tank-'),
   {id='sod-tank-bear',type='branch',conditions=any(form(5487),form(9634)),onFalse={},onTrue={ref('sod-tank-bear-section','sod.druid.bear','sod-tank-bear-')}},
   {id='sod-tank-cat',type='branch',conditions=form(768),onFalse={},onTrue={ref('sod-tank-cat-section','sod.druid.cat','sod-tank-cat-')}},
   ref('sod-tank-humanoid','sod.druid.tank-humanoid','sod-tank-'),
  },
 },
}))
