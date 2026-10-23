-- Mists of Pandaria Classic Balance Druid, levels 10–90, in the Balance specialization (102). Wowhead's Phase 5
-- list (close to wowsims): Moonfire and Sunfire kept up and refreshed inside the matching Eclipse,
-- Starfall in Lunar, Starsurge on Shooting Stars and on cooldown, Hurricane or Astral Storm at five
-- enemies, Starfire in and after Lunar, Wrath in and after Solar. RM cannot read Eclipse energy or
-- its direction, so the filler follows the two Eclipse buffs and, between them, whether Starfire was
-- one of your last three casts. Incarnation at an Eclipse's start, Celestial Alignment as it ends.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function form(id)return{type='FORM',form=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,op,v)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator=op,value=v}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function talent(n)return{type='TALENT',layout='grid',value=n}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function off(id,action,conditions)local step=spell(id,action,conditions);step.disabled=true;return step end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local SOLAR,LUNAR,CA,INCARNATION,GRACE,DREAM=48517,48518,112071,102560,16886,145151
local solar,lunar,aligned=own(SOLAR),own(LUNAR),own(CA)
local eclipse=any(lunar,solar)
local worth=any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
 {type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=25})
local dream=all(talent(17),negate(own(DREAM)),negate(aligned))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.mop.druid.balance',revision=2,
 blocks={['mop.druid.boundaries']=2,['mop.druid.target']=1,['mop.druid.mark']=1},
 nameKey='Default.MoP.Druid.Balance.Name',descriptionKey='Default.MoP.Druid.Balance.Description',
 applicability={families={'progression'},minExpansion=4,maxExpansion=4,actionContext='player',class='DRUID',minLevel=10,maxLevel=90},
 tags={'balance','leveling','single-target','aoe','wowhead','wowsims'},
 sources={
  {url='https://www.wowhead.com/mop-classic/guide/classes/druid/balance/dps-rotation-cooldowns-abilities-pve',title='Wowhead: MoP Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2026-06-20'},
  {url='https://github.com/wowsims/mop/blob/ec2c6c2552cc7e2a9555bb5eb89144dfb3b9c8d9/ui/specs/druid/balance/apls/standard.apl.json',title='wowsims/mop Balance standard APL',reviewedAt='2026-10-23',revision='ec2c6c2552'},
  {url='https://www.icy-veins.com/mists-of-pandaria-classic/balance-druid-pve-rotation-cooldowns-abilities',title='Icy Veins: MoP Classic Balance Druid rotation',reviewedAt='2026-10-23',revision='2025-06-22',notes='Same list; Innervate at 70% mana.'},
  {url='https://www.warcrafttavern.com/mop/guides/pve-balance-druid-rotations-cooldowns/',title='Warcraft Tavern: MoP Classic Balance Druid',reviewedAt='2026-10-23',notes='Astral Storm in Lunar for AoE.'},
 },
 body={priority=30,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=10},{type='SPECIALIZATION',spec=102}}},
  cooldowns={
   block('balance-mark','mop.druid.mark','balance-'),
   spell('balance-moonkin',24858,negate(any(form(24858),form(768),form(5487),form(783),form(1066),form(33943),form(40120)))),
   spell('balance-incarnation',INCARNATION,all(combat(),eclipse,any({type='SPELL_AVAIL',spell=CA},negate(known(CA))),worth)),
   spell('balance-alignment',CA,all(combat(),negate(lunar),negate(solar),any(negate(talent(11)),own(INCARNATION),
    {type='SPELL_COOLDOWN',spell=INCARNATION,operator='GREATERTHAN',value=45}),worth)),
   spell('balance-natures-vigil',124974,any(own(INCARNATION),aligned,all(negate(talent(11)),eclipse))),
   spell('balance-force-of-nature',33831,all(combat(),any({type='BUFF_REMAIN',unit='player',spell=GRACE,ownbuff=true,operator='GREATERTHANOREQUALS',value=13},
    {type='SPELL_CHARGES',spell=33831,operator='EQUALS',value=3}))),
   spell('balance-natures-swiftness',132158,dream),
   spell('balance-innervate',29166,all(combat(),{type='MANAPCT',unit='player',operator='LESSTHAN',value=.7})),
   spell('balance-solar-beam',78675,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
   spell('balance-barkskin',22812,all(combat(),health('LESSTHAN',.5))),
   spell('balance-renewal',108238,all(combat(),health('LESSTHAN',.4))),
   off('balance-detonate',88751,any(solar,aligned)),
  },
  rotation={
   block('balance-boundaries','mop.druid.boundaries','balance-'),
   {id='balance-forms',type='none',conditions=any(form(768),form(5487))},
   block('balance-target','mop.druid.target','balance-'),
   {id='balance-pull',type='branch',conditions=negate(combat()),onFalse={},onTrue={
    spell('balance-pull-dream',5185,all(talent(17),negate(own(DREAM)))),
    spell('balance-pull-moonfire',8921,{type='MOVING'}),
    spell('balance-pull-wrath',5176),
    stop('balance-pull-stop')}},
   spell('balance-astral-communion',127663,all(talent(10),own(145138),negate(lunar),negate(solar))),
   spell('balance-dream',5185,dream),
   spell('balance-moonfire',8921,any(negate(dot(8921)),remain(8921,'LESSTHAN',2),all(lunar,own(GRACE),remain(8921,'LESSTHAN',6)),all(aligned,remain(8921,'LESSTHAN',6)))),
   spell('balance-sunfire',93402,all(negate(aligned),any(negate(dot(93402)),remain(93402,'LESSTHAN',2),all(solar,own(GRACE),remain(93402,'LESSTHAN',6))))),
   spell('balance-starfall',48505,all(negate(own(48505)),any(lunar,aligned),
    negate(all(talent(11),{type='SPELL_COOLDOWN',spell=INCARNATION,operator='LESSTHAN',value=35},negate(own(INCARNATION)))))),
   spell('balance-shooting-stars',78674,own(93400)),
   spell('balance-starsurge',78674),
   {id='balance-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=5},onFalse={},onTrue={
    spell('balance-aoe-hurricane',16914,solar),
    spell('balance-aoe-astral-storm',106996,lunar)}},
   {id='balance-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
    spell('balance-moving-moonfire',8921,any(lunar,negate(solar))),
    spell('balance-moving-sunfire',93402),
    stop('balance-moving-stop')}},
   spell('balance-lunar-starfire',2912,any(lunar,aligned)),
   spell('balance-solar-wrath',5176,solar),
   spell('balance-toward-solar',2912,{type='SPELL_HISTORY',spell=2912,operator='LESSTHANOREQUALS',value=3}),
   spell('balance-wrath',5176),
  },
 },
}))
