-- Shared Classic Era Druid blocks (Built In composition; authoring-time only), vanilla and
-- Season of Discovery. Consumers: rm.era.druid.balance[.icyveins], rm.era.druid.feral[.wowhead,
-- .warcrafttavern,.warcrafttavern.casual], rm.era.druid.restoration[.warcrafttavern],
-- rm.sod.druid.balance[.icyveins,.wowhead], rm.sod.druid.feral, rm.sod.druid.tank[.wowsims] and
-- rm.sod.druid.restoration. A content change needs a revision bump, every consumer's `blocks` pin
-- and revision bumped, and ledger rows in tests/fixtures/builtin_composition_ledger.lua.
-- Forms are read by spell (FORM form, any rank): the shapeshift-bar index moves as forms are learned, the spell does not.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function form(id)return{type='FORM',form=id}end
local function anyBuff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function mine(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
-- Season of Discovery runes: engraved, by the first spell the rune teaches.
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function moving()return{type='MOVING'}end
local function energy(op,v)return{type='POWER',unit='player',operator=op,value=v}end
local function cp(op,v)return{type='POINT',unit='player',operator=op,value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function ttd(v)return{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=v}end
local function engaged(v)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=v}end
local function raid()return{type='GROUP',raid=true}end
local function front()return{type='ISSAME',unit='targettarget',otherunit='player'}end
local function noFaerieFire()return all(negate({type='DEBUFF',unit='target',spell=770,anyrank=true}),negate({type='DEBUFF',unit='target',spell=16857,anyrank=true}))end
local function cat()return form(768)end
local function bear()return any(form(5487),form(9634))end
local function feral()return any(form(768),form(5487),form(9634))end
local function travelling()return any(form(783),form(1066))end
local function spell(id,action,conditions,ranked)return{id=id,type='spell',action=action,ranked=ranked or false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function wait(id)return{id=id,type='stop',conditions={}}end
local function ref(id,name,prefix)return{id=id..'-block',type='block',block=name,prefix=prefix}end
local function druid(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='DRUID',steps=steps}))end

-- Casts and channels (Starfire, Hurricane, Tranquility, Healing Touch) and travel forms halt advice and Attack.
druid('era.druid.boundaries',{
 stop('casting',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},travelling())),
},4)
-- Out-of-combat self buffs every source keeps: Mark (unless Gift is up), Thorns while soloing,
-- Omen of Clarity (a cast self-buff in vanilla) once talented.
druid('era.druid.upkeep',{
 spell('mark-of-the-wild',1126,all(negate(combat()),negate(anyBuff(1126)),negate(anyBuff(21849)))),
 spell('thorns',467,all(negate(combat()),negate({type='GROUP'}),negate(anyBuff(467)))),
 spell('omen-of-clarity',16864,all(negate(combat()),negate(own(16864)))),
})
-- Caster reminders: Moonkin Form when out of every form (travel forms too), Innervate on yourself when drained,
-- Nature's Grasp outdoors while a mob is on you solo.
druid('era.druid.caster-cooldowns',{
 spell('moonkin-form',24858,negate(any(form(24858),feral(),travelling()))),
 spell('innervate',29166,all(combat(),mana('LESSTHAN',.25))),
 spell('natures-grasp',16689,all(combat(),negate({type='GROUP'}),front(),negate(anyBuff(16689)),{type='OUTDOORS'})),
},2)
-- Feral reminders: Maul on every swing in bear (off the GCD), Tiger's Fury only at full energy
-- before a pull, Manual Crowd Pummeler on elites, Innervate, Frenzied Regeneration outside raids.
druid('era.druid.feral-cooldowns',{
 spell('maul',6807,all(bear(),combat(),negate({type='SPELL_ACTIVE',spell=6807}))),
 spell('tigers-fury',5217,all(cat(),negate(combat()),{type='ATTACKABLE',unit='target'},energy('GREATERTHANOREQUALS',100))),
 {id='crowd-pummeler',type='item',action={9449},conditions=all(combat(),feral(),{type='EQUIPPED',item={9449}},negate(anyBuff(13494)),
  any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'}))},
 spell('innervate',29166,all(combat(),mana('LESSTHAN',.3))),
 spell('frenzied-regeneration',22842,all(bear(),combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4},negate(raid()))),
},2)
-- Cat entry for every Feral list: no target, the stealth opener (Ravage, Shred, Mangle, Claw).
druid('era.druid.stealth-opener',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 {id='stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  spell('ravage',6785),spell('shred',5221),spell('mangle',407993,{},true),spell('claw',1082),stop('stealth-stop')}},
},2)
-- Positional builder: with the target on you, Mangle (Cat) or Claw; from behind, Shred.
druid('era.druid.cat-builders',{
 {id='facing',type='branch',conditions=front(),onTrue={spell('front-mangle',407993,{},true),spell('front-claw',1082)},
  onFalse={spell('behind-shred',5221),spell('behind-mangle',407993,{},true),spell('behind-claw',1082)}},
})
-- Powershift: re-cast Cat Form with Furor 5/5 when more than 20 energy short of a Shred, keeping
-- enough mana to shift back (not under Berserk), then wait for the tick with Attack on.
druid('era.druid.powershift',{
 spell('powershift',768,all({type='TALENT',layout='tree',tree=3,talent=2,operator='GREATERTHANOREQUALS',value=5},energy('LESSTHANOREQUALS',27),
  mana('GREATERTHANOREQUALS',.15),negate(own(417141)))),
 wait('wait'),
},2)
-- Vanilla cat (Icy Veins, Wowhead, wowsims, Warcraft Tavern leveling): Faerie Fire (Feral) kept up,
-- Clearcasting on Shred, a finisher from four combo points (Rip before Ferocious Bite is learned,
-- else on long-lived targets outside raids; Bite under 63 energy), Rake outside raids, builder.
druid('era.druid.cat',{
 ref('opening','era.druid.stealth-opener','open-'),
 spell('faerie-fire',16857,any(noFaerieFire(),all({type='DEBUFF',unit='target',spell=16857,anyrank=true},{type='DEBUFF_REMAIN',unit='target',spell=16857,anyrank=true,operator='LESSTHAN',value=6}))),
 spell('clearcasting-shred',5221,all(own(16870),negate(front()))),
 {id='finisher',type='branch',conditions=cp('GREATERTHANOREQUALS',4),onFalse={},onTrue={
  spell('rip',1079,all(negate(mine(1079)),any(negate(known(22568)),all(negate(raid()),ttd(12))))),
  spell('bite',22568,energy('LESSTHAN',63))}},
 spell('rake',1822,all(negate(raid()),negate(mine(1822)),ttd(9))),
 ref('builders','era.druid.cat-builders','build-'),
 ref('powershift','era.druid.powershift','shift-'),
})
-- Bear pull: Faerie Fire (Feral) from range, Enrage for starting rage.
druid('era.druid.bear-pull',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-faerie-fire',16857,{type='BEYOND_MELEE',unit='target'}),
  spell('pull-enrage',5229,energy('LESSTHAN',20))}},
},3)
-- Vanilla bear (Icy Veins, Warcraft Tavern): Enrage when starved solo, Demoralizing Roar on packs
-- and elites unless a warrior's Shout covers it, Swipe on two or more, Swipe to dump rage,
-- Faerie Fire (Feral) as the free filler. Maul is a reminder.
druid('era.druid.bear',{
 ref('pull','era.druid.bear-pull','pull-'),
 spell('enrage',5229,all(energy('LESSTHAN',10),negate(engaged(2)),negate(raid()))),
 spell('demoralizing-roar',99,all(negate({type='DEBUFF',unit='target',spell=99,anyrank=true}),negate({type='DEBUFF',unit='target',spell=1160,anyrank=true}),
  any(engaged(2),{type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='worldboss'}))),
 {id='aoe',type='branch',conditions=engaged(2),onFalse={},onTrue={spell('aoe-swipe',779,energy('GREATERTHANOREQUALS',25))}},
 spell('swipe',779,energy('GREATERTHANOREQUALS',60)),
 spell('faerie-fire',16857),
 wait('wait'),
},2)
-- In Cat or Bear while playing a caster list: the vanilla cat and bear sections.
druid('era.druid.forms',{
 {id='cat',type='branch',conditions=cat(),onFalse={},onTrue={ref('cat-section','era.druid.cat','cat-')}},
 {id='bear',type='branch',conditions=bear(),onFalse={},onTrue={ref('bear-section','era.druid.bear','bear-')}},
},2)
-- A Feral druid in caster form: shift (Cat once learned, else Bear), else caster filler.
druid('era.druid.feral-humanoid',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 spell('cat-form',768),
 spell('dire-bear-form',9634,negate(known(768))),
 spell('bear-form',5487,negate(known(768))),
 spell('moonfire',8921,negate(mine(8921))),
 spell('wrath',5176,negate(moving())),
 stop('humanoid-stop'),
},2)
-- Caster pull: Starfire or Wrath standing, Moonfire on the move, then stop.
druid('era.druid.caster-pull',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-starfire',2912,negate(moving())),spell('pull-wrath',5176,negate(moving())),spell('pull-moonfire',8921),stop('pull-stop')}},
},3)
-- Vanilla Balance (Wowhead 2025, Warcraft Tavern, wowsims): Faerie Fire in a group, Hurricane on
-- three or more, Moonfire and Insect Swarm on targets that live (mana floor), Starfire (on a Nature's
-- Grace proc first), Wrath before Starfire is learned, melee when dry.
druid('era.druid.caster',{
 ref('pull','era.druid.caster-pull','pull-'),
 spell('faerie-fire',770,all({type='GROUP'},noFaerieFire())),
 {id='aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={spell('aoe-hurricane',16914,negate(moving()))}},
 {id='moving',type='branch',conditions=moving(),onFalse={},onTrue={
  spell('moving-moonfire',8921,negate(mine(8921))),spell('moving-insect-swarm',5570,negate(mine(5570))),stop('moving-stop')}},
 spell('moonfire',8921,all(negate(mine(8921)),ttd(8),mana('GREATERTHANOREQUALS',.3))),
 spell('insect-swarm',5570,all(negate(mine(5570)),ttd(8),mana('GREATERTHANOREQUALS',.3))),
 spell('natures-grace-starfire',2912,own(16886)),
 spell('starfire',2912),
 spell('wrath',5176),
 wait('dry'),
},2)
-- Healer reminders: Nature's Swiftness in an emergency, Tranquility on a hurt group, Innervate,
-- Rebirth on a dead friendly target, poison and curse removal on a friendly target.
local friendly=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
druid('era.druid.heal-cooldowns',{
 spell('natures-swiftness',17116,all(combat(),friendly,{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.3})),
 spell('tranquility',740,all(combat(),{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=.6,operator='GREATERTHANOREQUALS',value=3})),
 spell('innervate',29166,all(combat(),mana('LESSTHAN',.25))),
 spell('rebirth',20484,all(combat(),{type='FRIENDLY',unit='target'},{type='DEAD',unit='target'})),
 spell('abolish-poison',2893,all(friendly,{type='DISPELLABLE',unit='target',debufftype='Poison'},negate({type='BUFF',unit='target',spell=2893,anyrank=true}))),
 spell('cure-poison',8946,all(friendly,{type='DISPELLABLE',unit='target',debufftype='Poison'},negate(known(2893)))),
 spell('remove-curse',2782,all(friendly,{type='DISPELLABLE',unit='target',debufftype='Curse'})),
})
-- A healer on an enemy (solo leveling): Sunfire, Moonfire and Insect Swarm, Wrath, melee when dry.
druid('era.druid.resto-damage',{
 {id='damage',type='branch',conditions={type='ATTACKABLE',unit='target'},onFalse={},onTrue={
  spell('sunfire',414684,negate(mine(414684)),true),
  spell('moonfire',8921,negate(mine(8921))),
  spell('insect-swarm',5570,negate(mine(5570))),
  spell('wrath',5176,negate(moving())),
  wait('damage-wait')}},
},2)

-- Season of Discovery.
-- Cat (Wowhead SoD, wowsims P5, Icy Veins): Faerie Fire when none is up, Savage Roar, Swipe (Cat)
-- on four or more, Mangle debuff, Clearcasting on Shred, Rip at five combo points with Savage Roar
-- lasting, Rake, builder, powershift, Faerie Fire refresh last.
druid('sod.druid.cat',{
 ref('opening','era.druid.stealth-opener','open-'),
 spell('faerie-fire',16857,noFaerieFire()),
 spell('savage-roar',407988,all(negate(own(407988)),cp('GREATERTHANOREQUALS',1))),
 {id='aoe',type='branch',conditions=all(engaged(4),rune(439510)),onFalse={},onTrue={
  spell('aoe-swipe',411128,{},true),ref('aoe-powershift','era.druid.powershift','aoe-')}},
 spell('mangle',407993,negate({type='DEBUFF',unit='target',spell=407993,anyrank=true}),true),
 spell('clearcasting-shred',5221,all(own(16870),negate(front()))),
 spell('rip',1079,all(cp('GREATERTHANOREQUALS',5),negate(mine(1079)),{type='BUFF_REMAIN',unit='player',spell=407988,ownbuff=true,operator='GREATERTHANOREQUALS',value=8},ttd(10))),
 spell('rake',1822,negate(mine(1822))),
 ref('builders','era.druid.cat-builders','build-'),
 spell('faerie-fire-refresh',16857,{type='DEBUFF_REMAIN',unit='target',spell=16857,anyrank=true,operator='LESSTHAN',value=8}),
 ref('powershift','era.druid.powershift','shift-'),
},2)
-- Bear (Icy Veins, wowsims P6, Warcraft Tavern): Faerie Fire (Feral) or Sunfire (Bear) to pull from
-- range, Lacerate before it drops, packs (Mangle under Berserk, Swipe), Mangle, Lacerate, Swipe.
druid('sod.druid.bear',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 {id='pull',type='branch',conditions=all(negate(combat()),{type='BEYOND_MELEE',unit='target'}),onFalse={},onTrue={
  spell('pull-faerie-fire',16857),spell('pull-sunfire',414687,{},true)}},
 spell('lacerate-refresh',414644,all(mine(414647),{type='DEBUFF_REMAIN',unit='target',spell=414647,anyrank=true,owndebuff=true,operator='LESSTHAN',value=3}),true),
 {id='aoe',type='branch',conditions=engaged(3),onFalse={},onTrue={
  spell('aoe-mangle',407995,own(417141),true),spell('aoe-swipe',779),wait('aoe-wait')}},
 spell('mangle',407995,{},true),
 spell('lacerate',414644,{},true),
 spell('swipe',779),
 wait('wait'),
},2)
-- In Cat or Bear while playing a SoD caster list: the SoD cat and bear sections.
druid('sod.druid.forms',{
 {id='cat',type='branch',conditions=cat(),onFalse={},onTrue={ref('cat-section','sod.druid.cat','cat-')}},
 {id='bear',type='branch',conditions=bear(),onFalse={},onTrue={ref('bear-section','sod.druid.bear','bear-')}},
},2)
-- SoD Maul: with 30 rage or more, not already queued.
druid('sod.druid.maul',{
 spell('maul',6807,all(bear(),combat(),energy('GREATERTHANOREQUALS',30),negate({type='SPELL_ACTIVE',spell=6807}))),
},2)
-- SoD tank reminders: Berserk once Mangle is cooling or on packs, Survival Instincts, Frenzied
-- Regeneration and Barkskin when low, Enrage between pulls, Demoralizing Roar on elites when uncovered.
druid('sod.druid.tank-cooldowns',{
 spell('berserk',417141,all(combat(),bear(),any({type='SPELL_COOLDOWN',spell=407995,operator='GREATERTHAN',value=0},engaged(2)))),
 spell('survival-instincts',408024,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.3})),
 spell('frenzied-regeneration',22842,all(combat(),bear(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 spell('barkskin',22812,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5})),
 spell('enrage',5229,all(negate(combat()),bear(),{type='ATTACKABLE',unit='target'})),
 spell('demoralizing-roar',99,all(combat(),bear(),negate({type='DEBUFF',unit='target',spell=99,anyrank=true}),negate({type='DEBUFF',unit='target',spell=1160,anyrank=true}),
  any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='worldboss'}))),
},2)
-- A tank in caster form: Dire Bear or Bear Form, else caster filler.
druid('sod.druid.tank-humanoid',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 spell('dire-bear-form',9634),
 spell('bear-form',5487),
 spell('moonfire',8921,negate(mine(8921))),
 spell('wrath',5176,negate(moving())),
 stop('humanoid-stop'),
},2)
-- SoD Balance reminders: Starfall, an instant Healing Touch from Fury of Stormrage on a dying friend,
-- curse and poison removal, Wild Growth (hybrid) on a hurt group.
druid('sod.druid.balance-cooldowns',{
 spell('starfall',439748,all(combat(),{type='ATTACKABLE',unit='target'}),true),
 spell('instant-healing-touch',5185,all(anyBuff(414800),{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.5})),
 spell('remove-curse',2782,all({type='FRIENDLY',unit='target'},{type='DISPELLABLE',unit='target',debufftype='Curse'})),
 spell('cure-poison',8946,all({type='FRIENDLY',unit='target'},{type='DISPELLABLE',unit='target',debufftype='Poison'})),
 spell('wild-growth',408120,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=30,healthoperator='LESSTHAN',health=.8,operator='GREATERTHANOREQUALS',value=2},true),
})
-- SoD caster pull: Starsurge, Wrath standing, Sunfire or Moonfire on the move, then stop.
druid('sod.druid.caster-pull',{
 stop('no-target',negate({type='ATTACKABLE',unit='target'})),
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-starsurge',417157,{},true),spell('pull-wrath',5176,negate(moving())),spell('pull-sunfire',414684,{},true),spell('pull-moonfire',8921),stop('pull-stop')}},
},3)
