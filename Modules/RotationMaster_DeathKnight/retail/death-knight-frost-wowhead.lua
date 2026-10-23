-- Retail (Midnight 12.x) Frost Death Knight after Wowhead (reference): Empower Rune Weapon at two
-- charges first, then Reaper's Mark, Pillar of Frost, Breath of Sindragosa and Frostwyrm's Fury in the
-- rotation; Obliterate on two Killing Machines (or one with Exterminate), Howling Blast on Rime,
-- Frost Strike before runic power caps, Obliterate on Killing Machine, Empower Rune Weapon for a new
-- Killing Machine, Frost Strike, Obliterate, Howling Blast. Disabled: secret in Midnight combat.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function buff(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local km=buff(51124)
local strong=any({type='BUFF_STACKS',unit='player',spell=51124,ownbuff=true,operator='GREATERTHANOREQUALS',value=2},all(km,any(buff(441416),buff(447954))))
local function priority(p,builder,spender)return{
 spell(p..'strong',builder,strong),spell(p..'rime',49184,buff(59052)),spell(p..'capping',spender,{type='POWER',unit='player',operator='LESSTHAN',value=-20}),
 spell(p..'killing-machine',builder,km),spell(p..'empower',47568,negate(km)),spell(p..'spend',spender),spell(p..'build',builder),spell(p..'howling-blast',49184)}end
local aoe=priority('fwh-aoe-',207230,194913)
aoe[#aoe+1]=spell('fwh-aoe-obliterate',49020);aoe[#aoe+1]=spell('fwh-aoe-frost-strike',49143)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.retail.deathknight.frost.wowhead',revision=1,
 blocks={['retail.deathknight.boundaries']=1,['retail.deathknight.utility']=1},
 nameKey='Default.Retail.DeathKnight.FrostWowhead.Name',descriptionKey='Default.Retail.DeathKnight.FrostWowhead.Description',
 applicability={families={'retail'},actionContext='player',class='DEATHKNIGHT',specs={251},minLevel=8,maxLevel=90},
 tags={'frost','melee','reference','wowhead'},
 sources={
  {url='https://www.wowhead.com/guide/classes/death-knight/frost/rotation-cooldowns-pve-dps',title='Wowhead: Frost Death Knight rotation (Midnight Season 2)',reviewedAt='2026-10-23',revision='2026-08-12',notes='Read from a Wayback snapshot.'},
 },
 body={priority=5,disabled=true,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=8},
  cooldowns={
   block('fwh-utility','retail.deathknight.utility','fwh-'),
   spell('fwh-remorseless-winter',196770,combat()),
   spell('fwh-raise-dead',46585,combat()),
  },
  rotation={
   block('fwh-boundaries','retail.deathknight.boundaries','fwh-'),
   spell('fwh-empower-charges',47568,{type='SPELL_CHARGES',spell=47568,operator='GREATERTHANOREQUALS',value=2}),
   spell('fwh-reapers-mark',439843),
   spell('fwh-pillar-of-frost',51271),
   spell('fwh-breath-of-sindragosa',152279),
   spell('fwh-frostwyrms-fury',279302),
   {id='fwh-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},
    onTrue=aoe,onFalse=priority('fwh-st-',49020,49143)},
  },
 },
}))
