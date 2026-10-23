-- Season of Discovery Retribution seal stacking (Wowhead Phase 8, wowsims): keep both Seal of Command
-- and Seal of Martyrdom up (each recast below 1 s), Divine Storm at three Holy Power (or freely
-- without the set), Crusader Strike, Exorcism, Holy Wrath on Undead and Demons (anything with the
-- Purifying Power rune), Consecration, and
-- Judgement while both seals are up. Disabled by default (opt-in): it needs the Soul of the Sealbearer
-- rune or the six-piece set that makes seals linger, which RM cannot read.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function expiring(id)return any(negate(own(id)),{type='BUFF_REMAIN',unit='player',spell=id,anyrank=true,ownbuff=true,operator='LESSTHANOREQUALS',value=1})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local undead=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution.stacking',revision=2,
 blocks={['sod.paladin.ret-upkeep']=1,['era.paladin.safety']=1,['era.paladin.melee-opening']=1,['era.paladin.boundaries']=1},
 nameKey='Default.SoD.Paladin.Retribution.Stacking.Name',descriptionKey='Default.SoD.Paladin.Retribution.Stacking.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',minLevel=20,maxLevel=60,rulesets={'season:2'}},
 tags={'endgame','raid','retribution','melee','single-target','season-of-discovery','wowhead','wowsims'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin DPS rotation, seal stacking (Phase 8)',reviewedAt='2026-10-23',revision='2025-06-06'},
  {url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/retribution_paladin',title='wowsims/sod Phase 8 seal stacking APL',reviewedAt='2026-10-23',revision='0e3f6ef'}},
 body={priority=103,disabled=true,switch=all(known(20375),rune(407778),{type='PRIMARY_TALENT_TREE',tree=3}),
  cooldowns={block('sstack-upkeep','sod.paladin.ret-upkeep','sstack-'),block('sstack-safety','era.paladin.safety','sstack-')},
  rotation={
   block('sstack-opening','era.paladin.melee-opening','sstack-'),
   spell('sstack-command',20375,expiring(20375)),
   spell('sstack-martyrdom',407798,expiring(407798)),
   {id='sstack-pull',type='branch',conditions=negate({type='COMBAT',unit='player'}),onFalse={},onTrue={
    spell('sstack-pull-exorcism',415068),
    {id='sstack-pull-stop',type='none',conditions={}},
   }},
   spell('sstack-divine-storm',407778,any(negate({type='BUFF',unit='player',spell=1226461}),{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3})),
   spell('sstack-crusader-strike',407676),
   spell('sstack-exorcism',415068),
   spell('sstack-holy-wrath',2812,any(rune(429144),undead)),
   spell('sstack-consecration',26573),
   spell('sstack-judgement',20271,all(own(407798),own(20375))),
  },
 },
}))
