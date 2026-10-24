-- Retail (Midnight) Subtlety Rogue, Icy Veins and SimulationCraft's default list: the optimal
-- reference, disabled by default because Shadow Dance, Darkest Night and energy are hidden in
-- Midnight combat. Stealthed before the pull: Shadowstrike. One combo point short of full:
-- Eviscerate with Darkest Night, Secret Technique in Shadow Dance, Coup de Grace, Black Powder on
-- three or more enemies, Eviscerate. Otherwise build: Shadowstrike, Shuriken Storm on two or
-- more, Gloomblade or Backstab. Reminders: Goremaw's Bite in Shadow Dance, Shadow Blades with
-- Shadow Dance ready, Shadow Dance at two or fewer (or six or more) combo points with Secret
-- Technique ready or Shadow Blades up, Vanish out of stealth at two or fewer combo points.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function points(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local fight=all(combat(),{type='ATTACKABLE',unit='target'})
local dance=own(185422)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.rogue.subtlety.icyveins',revision=2,
 blocks={['retail.rogue.boundaries']=1,['retail.rogue.upkeep']=2},
 nameKey='Default.Retail.Rogue.Subtlety.IcyVeins.Name',descriptionKey='Default.Retail.Rogue.Subtlety.IcyVeins.Description',
 applicability={families={'retail'},actionContext='player',class='ROGUE',specs={261},minLevel=10,maxLevel=90},
 tags={'subtlety','melee','reference','single-target','aoe','icy-veins','simulationcraft','wowhead'},
 sources={
  {url='https://www.icy-veins.com/wow/subtlety-rogue-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Subtlety Rogue rotation (Midnight)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/rogue_subtlety.simc',title='SimulationCraft: Subtlety Rogue default list',reviewedAt='2026-10-23',revision='c5fea93fb77d'},
  {url='https://www.wowhead.com/guide/classes/rogue/subtlety/rotation-cooldowns-pve-dps',title='Wowhead: Subtlety Rogue rotation (Season 2)',reviewedAt='2026-10-23',revision='2026-08-22'},
 },
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('retail.rogue.upkeep','subiv-'),
   spell('subiv-goremaws-bite',426591,all(fight,dance)),
   spell('subiv-shadow-blades',121471,all(fight,{type='SPELL_AVAIL',spell=185313})),
   spell('subiv-shadow-dance',185313,all(fight,negate(dance),any(points('LESSTHANOREQUALS',2),points('GREATERTHANOREQUALS',6)),any({type='SPELL_AVAIL',spell=280719},own(121471)))),
   spell('subiv-vanish',1856,all(fight,negate({type='STEALTHED'}),points('LESSTHANOREQUALS',2))),
  },
  rotation={
   block('retail.rogue.boundaries','subiv-'),
   {id='subiv-opener',type='branch',conditions=all(negate(combat()),{type='STEALTHED'}),onFalse={},onTrue={
    spell('subiv-opener-shadowstrike',185438),
    {id='subiv-opener-stop',type='none',suppress_attack=true,conditions={}},
   }},
   {id='subiv-finish',type='branch',conditions=points('LESSTHANOREQUALS',-1),onFalse={
    spell('subiv-shadowstrike',185438),
    spell('subiv-shuriken-storm',197835,enemies(2)),
    spell('subiv-gloomblade',200758),
    spell('subiv-backstab',53),
   },onTrue={
    spell('subiv-darkest-night',196819,own(457280)),
    spell('subiv-secret-technique',280719,dance),
    spell('subiv-coup-de-grace',441776),
    spell('subiv-black-powder',319175,enemies(3)),
    spell('subiv-eviscerate',196819),
   }},
  },
 },
}))
