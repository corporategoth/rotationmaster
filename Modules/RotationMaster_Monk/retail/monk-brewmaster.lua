-- Retail (Midnight 12.x) Brewmaster Monk, Blizzard Assisted with brews (recommended): the rotation
-- is Blizzard's Assisted Combat suggestion, which Icy Veins endorses for Brewmaster only with the
-- brews handled by hand, so the cooldowns are Icy Veins' brew list: Black Ox Brew, Invoke Niuzao,
-- Purifying Brew, Celestial Brew or Infusion and Touch of Death, plus the shared utility reminders.
-- RM has no Stagger condition, so the brews light whenever they are ready in combat.
local _,addon=...
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.monk.brewmaster',revision=1,
 blocks={['retail.monk.boundaries']=1,['retail.monk.utility']=1},
 nameKey='Default.Retail.Monk.Brewmaster.Name',descriptionKey='Default.Retail.Monk.Brewmaster.Description',
 applicability={families={'retail'},actionContext='player',class='MONK',specs={268},minLevel=10,maxLevel=90},
 tags={'brewmaster','tank','assisted-combat','icy-veins'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/monk_brewmaster.simc',title='SimulationCraft model of Blizzard Assisted Combat: Brewmaster',reviewedAt='2026-10-23',revision='c5fea93f',notes='Its cooldowns list (Invoke Niuzao, racials) is what Assisted Combat leaves out.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://www.icy-veins.com/wow/brewmaster-monk-pve-tank-rotation-cooldowns-abilities',title='Icy Veins: Brewmaster Monk rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='The brews list, and the advice to use the rotation assistant only with brews pressed by hand.'},
  {url='https://github.com/kaminaris/MaxDps-Monk',title='MaxDps Monk (Midnight)',reviewedAt='2026-10-23',revision='d286e7b1',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('brew-utility','retail.monk.utility','brew-'),
   spell('brew-black-ox-brew',115399,combat()),
   spell('brew-invoke-niuzao',132578,combat()),
   spell('brew-purifying-brew',119582,combat()),
   spell('brew-celestial-brew',322507,combat()),
   spell('brew-celestial-infusion',1241059,combat()),
   spell('brew-touch-of-death',322109,combat()),
  },
  rotation={
   block('brew-boundaries','retail.monk.boundaries','brew-'),
   {id='brew-assisted',type='assisted',conditions={}},
  },
 },
}))
