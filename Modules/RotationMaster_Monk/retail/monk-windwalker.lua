-- Retail (Midnight 12.x) Windwalker Monk, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, which already respects Combo Strikes. Around it,
-- highlights for what Assisted Combat leaves to you: Zenith, Celestial Conduit, Invoke Xuen and Touch
-- of Karma in combat, plus Spear Hand Strike, Fortifying Brew and racial cooldowns.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.windwalker',revision=6,
 blocks={['retail.monk.boundaries']=3,['retail.monk.utility']=2},
 nameKey='Default.Retail.Monk.Windwalker.Name',descriptionKey='Default.Retail.Monk.Windwalker.Description',
 applicability={families={'retail'},actionContext='player',class='MONK'},
 tags={'windwalker','melee','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/monk_windwalker.simc',title='SimulationCraft model of Blizzard Assisted Combat: Windwalker',reviewedAt='2026-10-23',revision='c5fea93f',notes='Celestial Conduit and Zenith are marked as outside the in-game Assisted Combat; its cooldowns list adds Invoke Xuen, Touch of Karma and racials.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Monk',title='MaxDps Monk (Midnight)',reviewedAt='2026-10-23',revision='d286e7b1',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,specs={269},
  cooldowns={
   block('ww-utility','retail.monk.utility','ww-'),
   spell('ww-invoke-xuen',123904,combat()),
   spell('ww-touch-of-karma',122470,combat()),
   spell('ww-zenith',1249625,combat()),
   spell('ww-celestial-conduit',443028,combat()),
  },
  rotation={
   block('ww-boundaries','retail.monk.boundaries','ww-'),
   {id='ww-assisted',type='assisted',conditions={}},
  },
 },
}))
