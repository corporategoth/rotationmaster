-- Retail (Midnight 12.x) Havoc Demon Hunter, Blizzard Assisted (recommended): the rotation is
-- Blizzard's Assisted Combat suggestion, the one rotation input an addon can still read in combat.
-- Around it, highlights for what Assisted Combat leaves to you: Metamorphosis, The Hunt and
-- Vengeful Retreat (with Inertia or Exergy), which its model marks as outside the assistant, plus
-- Disrupt and Blur.
local _,addon=...
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.demonhunter.havoc',revision=2,
 blocks={['retail.demonhunter.boundaries']=1,['retail.demonhunter.utility']=2},
 nameKey='Default.Retail.DemonHunter.Havoc.Name',descriptionKey='Default.Retail.DemonHunter.Havoc.Description',
 applicability={families={'retail'},actionContext='player',class='DEMONHUNTER',specs={577},minLevel=8,maxLevel=90},
 tags={'havoc','melee','assisted-combat'},
 sources={
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/demonhunter_havoc.simc',title='SimulationCraft model of Blizzard Assisted Combat: Havoc',reviewedAt='2026-10-23',revision='c5fea93f',notes='Metamorphosis, The Hunt, Vengeful Retreat and Fel Rush are marked as not part of the in-game Assisted Combat.'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-DemonHunter',title='MaxDps Demon Hunter (Midnight)',reviewedAt='2026-10-23',revision='238137bc',notes='Assisted Combat spell plus interrupt, defensive and cooldown glows.'},
 },
 body={priority=20,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=8},
  cooldowns={
   block('havoc-utility','retail.demonhunter.utility','havoc-'),
   spell('havoc-metamorphosis',191427,combat()),
   spell('havoc-the-hunt',370965,combat()),
   spell('havoc-vengeful-retreat',198793,any(known(427640),known(206476))),
  },
  rotation={
   block('havoc-boundaries','retail.demonhunter.boundaries','havoc-'),
   {id='havoc-assisted',type='assisted',conditions={}},
  },
 },
}))
