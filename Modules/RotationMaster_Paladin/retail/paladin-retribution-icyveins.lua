-- Retail (Midnight) Retribution Paladin, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because its buffs, charges and enemy count are hidden in
-- Midnight combat. Hammer of Light; a free (Divine Purpose) spender; at 5 Holy Power with Wake of
-- Ashes cooling, the spender (SimulationCraft's finishers at holy_power=5 before Wake); Wake of
-- Ashes and Divine Toll; Blade of Justice on Art of War; Hammer of Wrath before it caps; then the
-- spender at 3+ Holy Power (Divine Storm on two or more enemies or with Empyrean Power), Hammer of
-- Wrath, Blade of Justice, Judgment and the builders. Avenging Wrath and Execution Sentence (with
-- Wake of Ashes ready) are reminders. Holy Power is never secret for the player in Midnight.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function negate(c)return{type='NOT',value=c}end
local function holyPower(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local spread=any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},own(326733))
-- Holy Power is read first so a hidden Empyrean Power cannot mask a readable answer.
local storm=any(all({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},holyPower('GREATERTHANOREQUALS',3)),own(326733))
local capped=all(holyPower('GREATERTHANOREQUALS',5),negate({type='SPELL_AVAIL',spell=255937}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.paladin.retribution.icyveins',revision=4,
 blocks={['retail.paladin.boundaries']=1,['retail.paladin.upkeep']=2},
 nameKey='Default.Retail.Paladin.Retribution.IcyVeins.Name',descriptionKey='Default.Retail.Paladin.Retribution.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='PALADIN'},
 tags={'retribution','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/retribution-paladin-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Retribution Paladin rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/paladin_retribution.simc',title='SimulationCraft: Retribution Paladin default list',reviewedAt='2026-10-23',revision='c5fea93fb77d',notes='Finishers at holy_power=5 while Wake of Ashes is cooling, before Wake.'},
  {url='https://www.wowhead.com/guide/classes/paladin/retribution/rotation-cooldowns-pve-dps',title='Wowhead: Retribution Paladin rotation',reviewedAt='2026-10-23',revision='2026-04-21',notes='Matches the Icy Veins order; Hammer of Wrath above Blade of Justice for Herald of the Sun.'},
 },
 body={priority=5,disabled=true,switch={type='SPECIALIZATION',spec=70},
  cooldowns={
   block('retail.paladin.upkeep','retiv-'),
   spell('retiv-avenging-wrath',31884,fight),
   spell('retiv-execution-sentence',343527,all(fight,{type='SPELL_COOLDOWN',spell=255937,operator='LESSTHAN',value=1.5})),
   spell('retiv-divine-protection',403876,combat()),
  },
  rotation={
   block('retail.paladin.boundaries','retiv-'),
   spell('retiv-hammer-of-light',427453),
   spell('retiv-free-storm',53385,all(own(223819),spread)),
   spell('retiv-free-verdict',383328,own(223819)),
   spell('retiv-capped-storm',53385,all(capped,spread)),
   spell('retiv-capped-verdict',383328,capped),
   spell('retiv-capped-templars-verdict',85256,capped),
   spell('retiv-wake-of-ashes',255937),
   spell('retiv-divine-toll',375576),
   spell('retiv-art-of-war',184575,own(406086)),
   spell('retiv-hammer-of-wrath-capped',24275,{type='SPELL_CHARGES',spell=24275,operator='GREATERTHANOREQUALS',value=2}),
   spell('retiv-divine-storm',53385,storm),
   spell('retiv-final-verdict',383328,holyPower('GREATERTHANOREQUALS',3)),
   spell('retiv-templars-verdict',85256,holyPower('GREATERTHANOREQUALS',3)),
   spell('retiv-hammer-of-wrath',24275),
   spell('retiv-blade-of-justice',184575),
   spell('retiv-judgment',20271),
   spell('retiv-templar-strike',407480),
   spell('retiv-templar-slash',406647),
   spell('retiv-crusader-strike',35395),
  },
 },
}))
