-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Retail (Midnight 12.x) Restoration Druid (recommended): on an enemy, Blizzard's Assisted Combat
-- suggestion (Blizzard's Restoration list is a damage list, cat or caster by form); otherwise Icy
-- Veins' maintenance casts on your friendly target (or yourself): Lifebloom, Efflorescence,
-- Swiftmend on a Rejuvenation, Wild Growth in a group, Regrowth on Clearcasting or high Abundance,
-- Rejuvenation when missing. Health is secret on Retail, so these follow your target choice, not how
-- hurt anyone is; HoTs are secret in Midnight combat, so the steps that read them wait there. Choosing
-- whom to heal is yours.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function hot(id)return{type='BUFF',unit='target',spell=id,ownbuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.druid.restoration',revision=6,
 blocks={['retail.druid.boundaries']=3,['retail.druid.utility']=2},
 nameKey='Default.Retail.Druid.Restoration.Name',descriptionKey='Default.Retail.Druid.Restoration.Description',
 applicability={families={'retail'},actionContext='player',class='DRUID'},
 tags={'restoration','healer','assisted-combat','icy-veins'},
 sources={
  {url='https://www.icy-veins.com/wow/restoration-druid-pve-healing-rotation-cooldowns-abilities',title='Icy Veins: Restoration Druid healing rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12',notes='Maintenance casts and the Abundance cycle.'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/assisted_combat/druid_restoration.simc',title='SimulationCraft model of Blizzard Assisted Combat: Restoration (damage)',reviewedAt='2026-10-23',revision='c5fea93f'},
  {url='https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua',title='Blizzard API documentation: C_AssistedCombat (12.1.5.70529)',reviewedAt='2026-10-23',revision='e7aa82019d'},
  {url='https://github.com/kaminaris/MaxDps-Druid',title='MaxDps Druid (Midnight)',reviewedAt='2026-10-23',revision='01642676',notes='Assisted Combat spell plus defensive and cooldown glows.'},
 },
 body={priority=20,specs={105},
  cooldowns={
   block('resto-utility','retail.druid.utility','resto-'),
   spell('resto-innervate',29166,combat()),
  },
  rotation={
   block('resto-boundaries','retail.druid.boundaries','resto-'),
   {id='resto-target',type='branch',conditions={type='ATTACKABLE',unit='target'},
    onTrue={{id='resto-assisted',type='assisted',conditions={}}},
    onFalse={
     spell('resto-lifebloom',33763,negate(hot(33763))),
     spell('resto-efflorescence',145205,all(combat(),negate({type='BUFF',unit='player',spell=145205,ownbuff=true}))),
     spell('resto-swiftmend',18562,hot(774)),
     spell('resto-wild-growth',48438,all(combat(),{type='GROUP'})),
     spell('resto-regrowth',8936,any({type='BUFF',unit='player',spell=16870,ownbuff=true},{type='BUFF_STACKS',unit='player',spell=207640,ownbuff=true,operator='GREATERTHANOREQUALS',value=5})),
     spell('resto-rejuvenation',774,negate(hot(774))),
    }},
  },
 },
}))
