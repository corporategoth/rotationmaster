-- Mists of Pandaria Classic Feral Druid after Icy Veins (and Wowhead's Ferocious Bite rule): the same
-- upkeep and opener as rm.mop.druid.feral, but combo points above 25% target health go only to Rip
-- and Savage Roar: Ferocious Bite only refreshes Rip in execute (or spends before Rip is learned),
-- Rake and Thrash refresh at two and three seconds, Berserk at 90 energy when Tiger's Fury is at
-- least 15 seconds away. Shares the Feral switch at a lower priority and ships disabled.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function bleed(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function power(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local clearcasting,berserk=own(135700),own(106951)
local worth=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.feral.icyveins',revision=1,
 blocks={['mop.druid.boundaries']=1,['mop.druid.target']=1,['mop.druid.mark']=1,['mop.druid.feral-upkeep']=1,['mop.druid.feral-open']=1,['mop.druid.feral-aoe']=1},
 nameKey='Default.MoP.Druid.Feral.IcyVeins.Name',descriptionKey='Default.MoP.Druid.Feral.IcyVeins.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID',minLevel=10,maxLevel=90},
 tags={'feral','leveling','single-target','aoe','icy-veins','wowhead'},
 sources={
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/feral-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/feral-druid-leveling',title='Icy Veins: MoP Classic Feral Druid leveling',reviewedAt='2026-10-23',revision='2025-06-22'},
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Feral Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20',notes='Ferocious Bite only below 25% with Rip up.'},
 },
 body={priority=20,disabled=true,switch=known(5217),
  cooldowns={
   block('fivy-mark','mop.druid.mark','fivy-'),
   block('fivy-upkeep','mop.druid.feral-upkeep','fivy-'),
   spell('fivy-berserk',106952,all(combat(),own(768),power('GREATERTHANOREQUALS',90),{type='SPELL_COOLDOWN',spell=5217,operator='GREATERTHANOREQUALS',value=15},worth)),
  },
  rotation={
   block('fivy-boundaries','mop.druid.boundaries','fivy-'),
   block('fivy-target','mop.druid.target','fivy-'),
   block('fivy-open','mop.druid.feral-open','fivy-'),
   block('fivy-aoe','mop.druid.feral-aoe','fivy-'),
   {id='fivy-execute',type='branch',conditions=all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.25},bleed(1079)),onTrue={
    spell('fivy-execute-bite',22568,cp('GREATERTHANOREQUALS',5))},
   onFalse={
    spell('fivy-rip',1079,all(cp('GREATERTHANOREQUALS',5),any(negate(bleed(1079)),remain(1079,'LESSTHANOREQUALS',2))))}},
   spell('fivy-early-bite',22568,all(cp('GREATERTHANOREQUALS',5),negate(known(1079)))),
   spell('fivy-rake',1822,any(negate(bleed(1822)),remain(1822,'LESSTHANOREQUALS',2))),
   spell('fivy-thrash',106832,all(clearcasting,any(negate(bleed(106830)),remain(106830,'LESSTHANOREQUALS',3)))),
   spell('fivy-ravage',102545,own(102543)),
   spell('fivy-shred',5221,all(any(clearcasting,berserk),negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
   spell('fivy-mangle',33917,any(cp('LESSTHAN',5),power('GREATERTHANOREQUALS',90))),
  },
 },
}))
