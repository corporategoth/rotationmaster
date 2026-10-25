-- Mists of Pandaria Classic Guardian Druid, levels 10–90, in the Guardian specialization (104). wowsims'
-- default list as Wowhead writes it, with the guides' Tooth and Claw Maul: Savage Defense whenever
-- it is down (Enrage to fund it), Frenzied Regeneration when low or rage-capped, Thrash for Weakened
-- Blows and Faerie Fire for Weakened Armor, Mangle on cooldown, Thrash and Swipe at three enemies,
-- Lacerate, Thrash and Faerie Fire as fillers. A short Cat arm serves Heart of the Wild damage.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function rage(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or{}}end
local function swing(id,conditions)return{id=id,type='stop',conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local BEAR,DEFENSE=5487,132402
local tanked={type='ISSAME',unit='targettarget',otherunit='player'}
local elite=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'})
local cleave=any({type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},{type='CLASSIFICATION',unit='target',value='worldboss'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.guardian',revision=6,
 blocks={['mop.druid.melee-boundaries']=2,['mop.druid.mark']=1},
 nameKey='Default.MoP.Druid.Guardian.Name',descriptionKey='Default.MoP.Druid.Guardian.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID'},
 tags={'guardian','tank','leveling','single-target','aoe','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/druid/guardian/apls/default.apl.json',title='wowsims/mop Guardian default APL',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/guardian/tank-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Guardian Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/guardian-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Guardian Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22',notes='Maul on Tooth and Claw procs; Swipe at three enemies.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-guardian-druid-tank-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Guardian Druid',reviewedAt='2026-10-23',notes='Faerie Fire as a filler for Mangle resets.'},
 },
 body={priority=30,specs={104},switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},
  cooldowns={
   block('guardian-mark','mop.druid.mark','guardian-'),
   spell('guardian-savage-defense',62606,all(combat(),{type='FORM',form=BEAR},negate(own(DEFENSE)))),
   spell('guardian-enrage',5229,all(combat(),{type='FORM',form=BEAR},negate(own(DEFENSE)),rage('LESSTHAN',60))),
   spell('guardian-frenzied',22842,all(combat(),any(all(health('LESSTHAN',.4),{type='SPELL_CHARGES',spell=62606,operator='EQUALS',value=0}),
    all(health('LESSTHAN',.7),rage('GREATERTHANOREQUALS',90))))),
   spell('guardian-maul',6807,all({type='FORM',form=BEAR},any(rage('GREATERTHANOREQUALS',90),all(own(135286),own(DEFENSE),rage('GREATERTHANOREQUALS',30))))),
   spell('guardian-barkskin',22812,all(combat(),tanked)),
   spell('guardian-survival-instincts',61336,all(combat(),health('LESSTHAN',.35))),
   off('guardian-might-of-ursoc',106922,all(combat(),health('LESSTHAN',.3))),
   spell('guardian-berserk',106952,all(combat(),cleave,negate(own(102558)))),
   spell('guardian-incarnation',102558,all(combat(),cleave,negate(own(50334)))),
   spell('guardian-force-of-nature',102706,all(combat(),any({type='SPELL_CHARGES',spell=102706,operator='EQUALS',value=3},own(50334)))),
   spell('guardian-natures-vigil',124974,all(combat(),elite)),
   spell('guardian-cenarion-ward',102351,health('LESSTHAN',.9)),
   spell('guardian-rejuvenation',774,all(own(108293),negate({type='BUFF',unit='player',spell=774,ownbuff=true}))),
   spell('guardian-skull-bash',106839,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   off('guardian-growl',6795,all({type='GROUP'},combat(),negate(tanked))),
  },
  rotation={
   block('guardian-boundaries','mop.druid.melee-boundaries','guardian-'),
   {id='guardian-cat',type='branch',conditions={type='FORM',form=768},onFalse={},onTrue={
    spell('guardian-cat-rake',1822,negate(bleed(1822))),
    spell('guardian-cat-rip',1079,all(cp('GREATERTHANOREQUALS',5),any(negate(bleed(1079)),{type='DEBUFF_REMAIN',unit='target',spell=1079,owndebuff=true,operator='LESSTHAN',value=4}))),
    spell('guardian-cat-bite',22568,cp('GREATERTHANOREQUALS',5)),
    spell('guardian-cat-mangle',33917),
    swing('guardian-cat-stop')}},
   {id='guardian-shift',type='branch',conditions={type='FORM',form=BEAR},onTrue={},onFalse={
    spell('guardian-bear-form',BEAR),stop('guardian-shift-stop')}},
   {id='guardian-pull',type='branch',conditions=combat(),onTrue={},onFalse={
    spell('guardian-pull-faerie-fire',770,{type='BEYOND_MELEE',unit='target'}),
    spell('guardian-pull-mangle',33917),
    swing('guardian-pull-stop')}},
   spell('guardian-weakened-blows',106832,negate({type='DEBUFF',unit='target',spell=115798})),
   spell('guardian-weakened-armor',770,all(elite,negate({type='DEBUFF',unit='target',spell=113746}))),
   spell('guardian-dream',5185,all(own(145162),health('LESSTHAN',.7))),
   spell('guardian-mangle',33917),
   {id='guardian-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
    spell('guardian-aoe-thrash',106832),spell('guardian-aoe-swipe',106785),swing('guardian-aoe-stop')}},
   spell('guardian-thrash-bleed',106832,negate(bleed(77758))),
   spell('guardian-lacerate',33745),
   spell('guardian-thrash',106832),
   spell('guardian-faerie-fire',770),
  },
 },
}))
