-- Season of Discovery Hunter ranged DPS, levels 1–60 (Phase 8 runes), and the SoD Hunter default.
-- Runes join as they are engraved. With the Kill Shot legs rune: Trick Shots
-- Multi-Shot, Kill Shot in Rapid Fire and in execute, Chimera Shot, traps and Arcane Shot as
-- Multi-Shot allows (wowsims P8, Wowhead Trick Shooter). Without it (Lock and Load / Sniper
-- Training / leveling): Chimera Shot, Aimed Shot at two Sniper Training stacks (without that rune,
-- after an Auto Shot), traps as Chimera comes back (Frost Trap only to feed Lock and Load), Explosive
-- and Steady Shot, Multi-Shot, Arcane Shot. Serpent Sting always up, refreshed by Chimera Shot. With
-- Lock and Load engraved a Frost Trap before the pull; with Lone Wolf no pet reminders. Left manual:
-- melee weaving, positioning, Feed Pet and Tranquilizing Shot.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function stacks(id,op,n)return{type='BUFF_STACKS',unit='player',spell=id,operator=op,value=n}end
local function recharge(id,op,n)return{type='SPELL_COOLDOWN',spell=id,ranked=false,operator=op,value=n}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,attack)return{id=id,type='none',suppress_attack=not attack,conditions={}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local standing=negate({type='MOVING'})
local unmarked=negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
local afterAuto={type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=.5}
local killShot=any(rune(409593),rune(1218240))
local lockAndLoad,sniperTraining=rune(415413),rune(415399)
local rapid=buff(3045)
local worth=all(combat(),any(classified('worldboss'),classified('elite'),classified('rareelite'),{type='INSTANCE',value='party'},{type='INSTANCE',value='raid'},
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))
local viperLow=all(mana('LESSTHAN',.5),any(buff(415423),all({type='SPELL_KNOWN',spell=415423},mana('LESSTHAN',.1))))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.hunter.ranged',revision=4,
 blocks={['era.hunter.boundaries']=2,['sod.hunter.upkeep']=1},
 nameKey='Default.SoD.Hunter.Ranged.Name',descriptionKey='Default.SoD.Hunter.Ranged.Description',
 applicability={families={'era'},actionContext='player',class='HUNTER',rulesets={'season:2'}},
 tags={'dps','ranged','leveling','endgame','season-of-discovery','wowsims','wowhead'},
 sources={
  {url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/hunter/builds/p8_ranged.build.json',title='wowsims/sod: Hunter P8 ranged build',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/hunter/apls',title='wowsims/sod: Hunter P7 APLs (Lock and Load, Kill Shot)',reviewedAt='2026-10-23',revision='0e3f6ef'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/hunter/ranged/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Ranged Hunter rotation, Season of Discovery',reviewedAt='2026-10-23',revision='2025-04-28'},
  {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/hunter/dps-leveling-tips',title='Wowhead: Ranged Hunter leveling tips, Season of Discovery',reviewedAt='2026-10-23',revision='2025-02-07'},
 },
 body={priority=100,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('sod.hunter.upkeep','hunter-'),
  spell('hunter-viper',415423,all(combat(),mana('LESSTHAN',.1),negate(buff(415423)))),
  spell('hunter-hawk',13165,all(negate(buff(13165)),negate(viperLow),any(combat(),all(negate(buff(415423)),negate(buff(13163)),negate(buff(5118)),negate(buff(13159)),negate(buff(13161)),negate(buff(20043)))))),
  spell('hunter-heart-of-the-lion',409580,negate(buff(409580))),
  spell('hunter-focus-fire',428726,all({type='PET'},{type='BUFF_STACKS',unit='pet',spell=428728,operator='GREATERTHANOREQUALS',value=5},negate(buff(428726)))),
  spell('hunter-rapid-fire',3045,all(worth,negate(rapid),any(negate(killShot),{type='SPELL_COOLDOWN',spell=409593,ranked=false,operator='LESSTHANOREQUALS',value=0}))),
  spell('hunter-berserking',20554,all(worth,rapid)),
  spell('hunter-blood-fury',20572,all(worth,rapid)),
  spell('hunter-bestial-wrath',19574,all(worth,{type='PET'}))},
 rotation={
  block('era.hunter.boundaries','hunter-'),
  -- Inside melee range (dead zone, or a weaver stepping in): Kill Shot has no minimum range.
  {id='hunter-melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
   spell('hunter-melee-kill-shot',409593),
   spell('hunter-melee-wyvern-strike',458436),
   spell('hunter-melee-flanking-strike',415320),
   spell('hunter-melee-raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
   spell('hunter-melee-mongoose-bite',1495),
   spell('hunter-melee-carve',425711,{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2}),
   stop('hunter-melee-stop',true),
  }},
  {id='hunter-pull',type='branch',conditions=combat(),onTrue={},onFalse={
   spell('hunter-pull-mark',1130,unmarked),
   -- Lock and Load (passive): a Frost Trap placed before the pull makes the next Shot free.
   spell('hunter-pull-lnl-frost-trap',13809,all(lockAndLoad,negate(buff(415414)))),
   spell('hunter-pull-aimed-shot',19434,all(standing,any(negate(sniperTraining),stacks(415401,'GREATERTHANOREQUALS',2)))),
   spell('hunter-pull-serpent-sting',1978,stingless),
   {id='hunter-pull-auto-shot',type='spell',action=75,ranked=true,conditions=negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})},
   stop('hunter-pull-stop'),
  }},
  {id='hunter-auto-shot',type='spell',action=75,ranked=true,conditions=all(negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
  spell('hunter-mark',1130,all(unmarked,any(classified('worldboss'),classified('elite'),classified('rareelite'),
   {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=8}))),
  {id='hunter-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
   spell('hunter-moving-serpent-sting',1978,stingless),
   spell('hunter-moving-chimera-shot',409433),
   spell('hunter-moving-kill-shot',409593),
   spell('hunter-moving-explosive-shot',409552),
   spell('hunter-moving-arcane-shot',3044),
   stop('hunter-moving-stop'),
  }},
  {id='hunter-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
   spell('hunter-aoe-explosive-trap',13813),
   spell('hunter-aoe-multi-shot',2643),
   spell('hunter-aoe-volley',1510,all(standing,{type='DISTANCE_COUNT',enemy=true,distance=20,operator='GREATERTHANOREQUALS',value=4})),
  }},
  spell('hunter-serpent-sting',1978,stingless),
  spell('hunter-chimera-refresh',409433,any(rapid,{type='DEBUFF_REMAIN',unit='target',spell=1978,owndebuff=true,operator='LESSTHAN',value=6})),
  {id='hunter-kill-shot-build',type='branch',conditions=killShot,onTrue={
   spell('hunter-ks-trick-multi-shot',2643,stacks(1233451,'GREATERTHANOREQUALS',4)),
   spell('hunter-ks-rapid-kill-shot',409593,rapid),
   spell('hunter-ks-execute-chimera',409433,{type='HEALTHPCT',unit='target',operator='LESSTHANOREQUALS',value=.2}),
   spell('hunter-ks-kill-shot',409593,any(negate(stacks(1233451,'GREATERTHANOREQUALS',4)),recharge(2643,'GREATERTHAN',.5))),
   spell('hunter-ks-chimera-shot',409433,any(negate(stacks(1233451,'GREATERTHANOREQUALS',3)),recharge(2643,'GREATERTHAN',.5))),
   spell('hunter-ks-explosive-trap',13813,recharge(2643,'GREATERTHAN',1.5)),
   spell('hunter-ks-arcane-shot',3044,recharge(2643,'GREATERTHAN',1)),
   spell('hunter-ks-multi-shot',2643),
   stop('hunter-ks-wait'),
  },onFalse={
   spell('hunter-lnl-chimera-shot',409433),
   spell('hunter-lnl-aimed-shot',19434,any(all(stacks(415401,'GREATERTHANOREQUALS',2),negate(buff(415414))),all(negate(sniperTraining),afterAuto))),
   spell('hunter-lnl-explosive-trap',13813,all(negate(buff(415414)),recharge(409433,'LESSTHANOREQUALS',1.6))),
   spell('hunter-lnl-immolation-trap',13795,all(negate(buff(415414)),recharge(409433,'LESSTHANOREQUALS',1.6))),
   spell('hunter-lnl-frost-trap',13809,all(lockAndLoad,negate(buff(415414)),recharge(409433,'LESSTHANOREQUALS',1.6))),
   spell('hunter-lnl-explosive-shot',409552),
   spell('hunter-lnl-steady-shot',437123,standing),
   spell('hunter-lnl-multi-shot',2643),
   spell('hunter-lnl-arcane-shot',3044),
   stop('hunter-lnl-wait'),
  }},
 }},
}))
