-- Season of Discovery Retribution, levels 1-60, and the default for any SoD Paladin no other premade
-- fits. Wowhead Phase 8 with wowsims: Seal of Martyrdom, Divine Storm at three Holy Power, then by
-- weapon speed: a slow two-hander (3.3 s or more) plays Crusader Strike, Exorcism, Divine Storm and
-- Judgement as a filler; a fast one judges only as the seal runs out, then Exorcism, Crusader
-- Strike and Divine Storm. Consecration last; Holy Wrath on Undead and Demons (on anything with the
-- Purifying Power rune); Hammer of Wrath with mana to spare, or always with Improved Hammer of Wrath.
-- Shared blocks: era/blocks.lua. Original priority data, no guide prose.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local function block(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local undead=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
local holyPower={type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.paladin.retribution',revision=3,
 blocks={['sod.paladin.ret-upkeep']=2,['era.paladin.safety']=1,['era.paladin.melee-opening']=1,['era.paladin.boundaries']=1,['sod.paladin.seal']=2},
 nameKey='Default.SoD.Paladin.Retribution.Name',descriptionKey='Default.SoD.Paladin.Retribution.Description',
 applicability={families={'era'},actionContext='player',class='PALADIN',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'leveling','endgame','retribution','melee','single-target','season-of-discovery','wowhead','wowsims','icy-veins'},
 sources={{url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/paladin/dps-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Paladin DPS rotation (Phase 8)',reviewedAt='2026-10-23',revision='2025-06-06'},
  {url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/retribution_paladin',title='wowsims/sod Phase 8 Exodin and Wrath-like APLs',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.icy-veins.com/wow-classic/retribution-paladin-dps-season-of-discovery-leveling',title='Icy Veins: SoD Retribution Paladin leveling (Phase 4)',reviewedAt='2026-10-23',revision='2024-07-02',notes='Leveling order and the mana-gated Hammer of Wrath.'}},
 body={priority=102,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
  cooldowns={block('sret-upkeep','sod.paladin.ret-upkeep','sret-'),block('sret-safety','era.paladin.safety','sret-')},
  rotation={
   block('sret-opening','era.paladin.melee-opening','sret-'),
   block('sret-seal','sod.paladin.seal','sret-'),
   {id='sret-pull',type='branch',conditions={type='COMBAT',unit='player'},onTrue={},onFalse={
    spell('sret-pull-exorcism',415068),
    spell('sret-pull-judgement',20271,negate(known(415068))),
    {id='sret-pull-stop',type='none',conditions={}},
   }},
   spell('sret-divine-storm-power',407778,holyPower),
   {id='sret-slow',type='branch',conditions={type='SWING_TIME',offhand=false,operator='GREATERTHANOREQUALS',value=3.3},onTrue={
    spell('sret-slow-crusader-strike',407676),
    spell('sret-slow-exorcism',415068),
    spell('sret-slow-divine-storm',407778),
    spell('sret-slow-judgement',20271),
   },onFalse={
    spell('sret-fast-judgement',20271,{type='BUFF_REMAIN',unit='player',spell=407798,ownbuff=true,operator='LESSTHAN',value=2}),
    spell('sret-fast-exorcism',415068),
    spell('sret-fast-crusader-strike',407676),
    spell('sret-fast-divine-storm',407778,negate({type='BUFF',unit='player',spell=1226461})),
   }},
   spell('sret-consecration',26573,any(mana('GREATERTHANOREQUALS',0.4),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})),
   spell('sret-holy-wrath',2812,all(any(rune(429144),undead),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2})),
   spell('sret-hammer-of-wrath',24275,any(rune(429152),mana('GREATERTHANOREQUALS',0.3))),
  },
 },
}))
