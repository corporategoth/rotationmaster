-- Retail (Midnight 12.x) Fire Mage after SimulationCraft, Icy Veins and Wowhead (optimal reference):
-- Combustion as a Fire hard cast finishes; Fire Blast while hard-casting to turn Heating Up into Hot Streak;
-- Pyroblast (Flamestrike on four or more) on Hyperthermia, Meteor, then Hot Streak, Fire Blast on
-- Heating Up inside Combustion, Pyroclasm, Scorch on Heat Shimmer or on the move, Fire Blast on
-- Heating Up, Frostfire Bolt or Fireball. Disabled: Hot Streak, Heating Up, Pyroclasm and Fire Blast
-- charges are secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local heating,combustion=buff(48107),buff(190319)
-- A Fire hard cast in progress (Fireball, Frostfire Bolt, Pyroblast, Flamestrike), read by spell, so a
-- mount, Hearthstone or Polymorph cast is not one.
local hardcast={type='OR',value={{type='CASTING_SPELL',unit='player',spell=133},{type='CASTING_SPELL',unit='player',spell=431044},
 {type='CASTING_SPELL',unit='player',spell=11366},{type='CASTING_SPELL',unit='player',spell=2120}}}
-- One priority, written for a spender: Pyroblast on one to three enemies, Flamestrike on four or more.
local function priority(p,spender)return{
 spell(p..'hyperthermia',spender,buff(383874)),
 spell(p..'meteor',153561),
 spell(p..'hot-streak',spender,buff(48108)),
 spell(p..'combustion-fire-blast',108853,all(heating,combustion)),
 spell(p..'pyroclasm',spender,buff(269651)),
 spell(p..'heat-shimmer',2948,buff(458964)),
 spell(p..'moving-scorch',2948,{type='MOVING'}),
 spell(p..'fire-blast',108853,heating)}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.mage.fire.guide',revision=7,
 blocks={['retail.mage.boundaries']=3,['retail.mage.utility']=2},
 nameKey='Default.Retail.Mage.FireGuide.Name',descriptionKey='Default.Retail.Mage.FireGuide.Description',
 applicability={families={'retail'},actionContext='player',class='MAGE'},
 tags={'fire','caster','reference','icy-veins','wowhead','simulationcraft'},
 sources={
  {url='https://www.icy-veins.com/wow/fire-mage-pve-dps-rotation-cooldowns-abilities',title='Icy Veins: Fire Mage rotation (12.1.5)',reviewedAt='2026-10-23',revision='2026-10-12'},
  {url='https://www.wowhead.com/guide/classes/mage/fire/rotation-cooldowns-pve-dps',title='Wowhead: Fire Mage rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-16',notes='Read from a Wayback snapshot of 2026-09-17.'},
  {url='https://github.com/simulationcraft/simc/blob/c5fea93fb77da1fae1cb1bfb1de13d2c60923ccf/ActionPriorityLists/default/mage_fire.simc',title='SimulationCraft default action list: Fire',reviewedAt='2026-10-23',revision='c5fea93f'},
 },
 body={priority=10,disabled=true,specs={63},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={
   block('fguide-utility','retail.mage.utility','fguide-'),
   spell('fguide-barrier',235313,combat()),
   spell('fguide-combustion',190319,all(combat(),hardcast,{type='CASTING_REMAIN',unit='player',operator='LESSTHAN',value=1})),
  },
  rotation={
   spell('fguide-casting-fire-blast',108853,all(hardcast,heating)),
   block('fguide-boundaries','retail.mage.boundaries','fguide-'),
   {id='fguide-pull',type='branch',conditions=combat(),onTrue={},onFalse={spell('fguide-pull-pyroblast',11366),stop('fguide-pull-stop')}},
   {id='fguide-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},
    onTrue=priority('fguide-aoe-',2120),onFalse=priority('fguide-st-',11366)},
   spell('fguide-frostfire-bolt',431044),
   spell('fguide-fireball',133),
  },
 },
}))
