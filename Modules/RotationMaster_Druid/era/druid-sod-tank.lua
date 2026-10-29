-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Season of Discovery Druid bear tank: chosen when Lacerate is engraved. After Icy Veins, simulator P6
-- and Warcraft Tavern: Faerie Fire (Feral) or Sunfire (Bear) from range, Lacerate before it drops,
-- Mangle (Bear) on cooldown, Lacerate, Swipe; on three or more, Mangle under Berserk and Swipe.
-- Maul with 30 rage, Berserk, Survival Instincts, Frenzied Regeneration, Barkskin, Enrage and
-- Demoralizing Roar are reminders. In Cat Form (off-tanking) it plays the SoD cat section.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function form(id)return{type='FORM',form=id}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.druid.tank',revision=6,
 blocks={['era.druid.boundaries']=4,['era.druid.upkeep']=1,['sod.druid.maul']=2,['sod.druid.tank-cooldowns']=2,['sod.druid.bear']=2,['sod.druid.cat']=2,
  ['era.druid.stealth-opener']=2,['era.druid.cat-builders']=1,['era.druid.powershift']=2,['sod.druid.tank-humanoid']=2},
 nameKey="Bear tank (SoD)",descriptionKey="Season of Discovery bear tank, chosen when Lacerate is engraved. Faerie Fire (Feral) or Sunfire (Bear) to pull from range, Lacerate before it drops, Mangle on cooldown, Lacerate, Swipe; on three or more enemies Mangle under Berserk and Swipe. In Cat Form it plays the cat list for off-tanking; in caster form it shifts to Bear. Reminders: Maul with 30 rage, Berserk, Survival Instincts, Frenzied Regeneration and Barkskin when low, Enrage between pulls, Demoralizing Roar on elites. Taunting and target choice stay with you.",
 applicability={families={'era'},actionContext='player',class='DRUID',rulesets={'season:2'}},
 tags={'season-of-discovery','leveling','endgame','feral','tank','melee','single-target','aoe','icy-veins','warcraft-tavern'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/feral-druid-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Feral Druid tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},

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
