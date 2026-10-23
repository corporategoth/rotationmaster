-- Mists of Pandaria Classic Monk premades: switches, priorities, boundaries and reminders through
-- the real catalog, predicates, composition and sequence executor on a modeled 5.5.4 client
-- (tests/fixtures/mop_premade_model_a.lua). Chi is POINT (Enum.PowerType.Chi, 12), energy POWER. Stances
-- are read by spell (FORM form; s.shift); clearing the auras also leaves the stance.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/mop_premade_model_a.lua')
local BM,BMO,WW,WWS,MW,UN='rm.mop.monk.brewmaster','rm.mop.monk.brewmaster.offensive','rm.mop.monk.windwalker','rm.mop.monk.windwalker.simc','rm.mop.monk.mistweaver','rm.mop.monk.unspecialized'
local CHI=M.POWER.Chi
-- Spells.
local JAB,PALM,KICK,EXPEL,EXPEL7,TOD,CJL=100780,100787,100784,115072,115129,115080,117952
local OX,TIGER,SERPENT,LEGACY,SPEAR,FORT=115069,103985,115070,115921,116705,115203
local KEG,BOF,HAZE,CLASH,SCK,PURIFY,ELUSIVE,GUARD,CHIBREW,XUEN,RJW,CHIWAVE,ZEN,CHIBURST=121253,115181,115180,122057,101546,119582,115308,115295,115399,123904,116847,115098,124081,123986
local FOF,RSK,TEB,ENERGIZING,SEF,KARMA,WHITE=113656,107428,1247275,115288,137639,122470,116781
local SOOTHING,SURGING,ENVELOPING,RENEWING,UPLIFT,TFT,MANATEA,COCOON,DETOX,STATUE=115175,116694,124682,115151,116670,116680,115294,116849,115450,115313
-- Auras.
local SHUFFLE,TIGERPOWER,POWERGUARD,ELUSIVESTACKS,HEAVY,MODERATE,PURIFIER=115307,125359,118636,128939,124273,124274,138237
local CBKICK,CBPALM,TEBSTACKS,RSKDEBUFF,MEMORY,ZEAL,VITAL,MANATEASTACKS=116768,118864,1247279,130320,139597,127722,118674,115867
local function monk(level,options)
 local f,s=M.new('monk');local a=f.addon
 s.setLevel(level or 90);s.powerType=M.POWER.Energy;s.energy=50;s.resource[CHI]=0
 -- Chi Brew has two charges (s.chiBrew); other spells report no charge data, as the client does.
 s.chiBrew=1;f.env.C_Spell.GetSpellCharges=function(id)if id==115399 then return{currentCharges=s.chiBrew,maxCharges=2,cooldownStartTime=s.chiBrew<2 and 90 or 0,cooldownDuration=s.chiBrew<2 and 45 or 0}end end
 local clear=s.clearAuras;s.clearAuras=function()clear();s.form=0 end
 if options and options.stance~=false then s.shift(options.stance or TIGER) end
 return a,s,f
end
test('every Monk premade is Mists only, listed and eligible',function()
 M.scope('monk',{BM,WW,MW},10);M.scope('monk',{UN},1)
 local rows=M.rows(monk())
 for _,id in ipairs({BMO,WWS})do
  local scope=rows[id].applicability
  assert(scope.minExpansion==4 and scope.maxExpansion==4 and scope.minLevel==10 and scope.maxLevel==90 and scope.families[1]=='progression',id)
  assert(not rows[id].eligible and rows[id].eligibilityReason=='disabled',id..' '..tostring(rows[id].eligibilityReason))
 end
 assert(rows[BMO].envelope.body.disabled and rows[WWS].envelope.body.disabled,'source variants ship disabled')
 assert(not rows[BM].envelope.body.disabled and not rows[WW].envelope.body.disabled and not rows[MW].envelope.body.disabled and not rows[UN].envelope.body.disabled)
end)
test('switch: the catch-all owns 1-9 and an unspecialized monk; each specialization claims its premade',function()
 local a,s=monk(1);s.learn(JAB,TIGER);assert(M.selected(a)==UN,'level 1')
 s.setLevel(9);s.learn(PALM,KICK,EXPEL7);s.specID(268);assert(M.selected(a)==UN,'level 9 stays in the catch-all');s.spec=nil
 s.setLevel(10);s.learn(OX,FOF,SOOTHING);assert(M.selected(a)==UN,'level 10 without a specialization')
 s.specID(268);assert(M.selected(a)==BM,'Brewmaster');assert(M.switch(a,BMO)=='match','the Offensive variant shares the switch')
 s.specID(269);assert(M.selected(a)==WW,'Windwalker');assert(M.switch(a,WWS)=='match','the SimC variant shares the switch')
 s.specID(270);assert(M.selected(a)==MW,'Mistweaver (index 2 in Blizzard order)')
 s.setLevel(90);assert(M.selected(a)==MW,'level 90 Mistweaver')
 for _,id in ipairs({BM,WW})do assert(M.switch(a,id)=='no-match',id..' claims a Mistweaver')end
 s.known={};s.spec=nil;assert(M.selected(a)==UN,'nothing known still gets a premade')
end)
test('enabling a source variant: it ranks below its recommended sibling',function()
 local a,s=monk(90);s.learn(OX,FOF)
 assert(a:SetDefaultRotationEnabled(BMO,true)and a:SetDefaultRotationEnabled(WWS,true))
 s.specID(268);assert(M.selected(a)==BM,'recommended Brewmaster outranks Offensive')
 assert(a:SetDefaultRotationEnabled(BM,false));assert(M.selected(a)==BMO,'Offensive once Brewmaster is disabled')
 s.specID(269);assert(M.selected(a)==WW)
 assert(a:SetDefaultRotationEnabled(WW,false));assert(M.selected(a)==WWS,'SimC once Windwalker is disabled')
end)
test('catch-all: boundaries, Tiger Power, two-Chi Blackout Kick, Expel Harm when hurt, Jab',function()
 local a,s=monk(3,{stance=false});s.learn(JAB,TIGER,PALM)
 local lit=M.upkeep(a,s,UN);assert(lit[TIGER],'Fierce Tiger stance')
 s.shift(TIGER);lit=M.upkeep(a,s,UN);assert(not lit[TIGER])
 s.usable[PALM]=false;M.expect(a,s,UN,JAB,nil,'no Chi: Jab');s.resource[CHI]=2;s.usable[PALM]=nil
 M.expect(a,s,UN,PALM,nil,'Tiger Power missing: Tiger Palm');s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 M.expect(a,s,UN,JAB,nil,'level 3: no Blackout Kick yet')
 s.setLevel(7);s.learn(KICK,EXPEL7);M.expect(a,s,UN,KICK,nil,'two Chi: Blackout Kick');s.resource[CHI]=1
 s.health.player=70;M.expect(a,s,UN,EXPEL7,nil,'hurt: early Expel Harm');s.learn(EXPEL);M.expect(a,s,UN,EXPEL,nil,'the later Expel Harm replaces it')
 s.cast=true;M.expect(a,s,UN,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,UN,nil,'stopped','channelling');s.channel=false
 s.hostile=false;M.expect(a,s,UN,nil,'stopped','no attackable target')
end)
-- A level-90 Brewmaster in Sturdy Ox with Shuffle and Tiger Power running.
local function brewmaster(level)
 local a,s,f=monk(level or 90,{stance=OX})
 s.learn(OX,JAB,PALM,KICK,EXPEL,TOD,KEG,BOF,HAZE,CLASH,SCK,PURIFY,ELUSIVE,GUARD,FORT,LEGACY,SPEAR,CJL)
 s.buff('player',SHUFFLE,{expirationTime=110,duration=6});s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 s.usable[TOD]=false -- Touch of Death needs Death Note
 return a,s,f
end
test('Brewmaster: boundaries and the pull',function()
 local a,s=brewmaster()
 s.cast=true;M.expect(a,s,BM,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,BM,nil,'stopped','channelling (Spinning Crane Kick)');s.channel=false
 s.hostile=false;M.expect(a,s,BM,nil,'stopped','no attackable target');s.hostile=true
 s.combat=false;s.targetRange={20,25};M.expect(a,s,BM,HAZE,nil,'pull at range: Dizzying Haze')
 s.cooling(HAZE,5);M.expect(a,s,BM,CLASH,nil,'then Clash');s.cooling(CLASH,5)
 M.expect(a,s,BM,KEG,nil,'then Keg Smash');s.cooling(KEG,5)
 local r=M.expect(a,s,BM,nil,'stopped','pull ends');assert(not r.suppressAttack,'the pull lets the auto attack start')
end)
test('Brewmaster: Shuffle first, Desperate Measures, Keg Smash under the cap, energy and Tiger Power',function()
 local a,s=brewmaster()
 s.resource[CHI]=1;M.expect(a,s,BM,KEG,nil,'Keg Smash fits')
 s.resource[CHI]=3;M.expect(a,s,BM,KICK,nil,'Keg Smash would overcap: Blackout Kick first')
 s.cooling(KEG,5);M.expect(a,s,BM,KICK,nil,'Keg Smash cooling, three Chi: spend on Blackout Kick')
 s.resource[CHI]=1;s.health.player=90;M.expect(a,s,BM,EXPEL,nil,'hurt and not capped: Expel Harm')
 s.health.player=100;M.expect(a,s,BM,PALM,nil,'nothing else: free Tiger Palm filler')
 s.energy=85;M.expect(a,s,BM,JAB,nil,'80 energy: Jab');s.energy=50
 s.clearAuras();s.shift(OX);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 M.expect(a,s,BM,KICK,nil,'Shuffle missing: Blackout Kick before anything')
 s.usable[KICK]=false;s.health.player=30;M.expect(a,s,BM,EXPEL,nil,'below 35%: Expel Harm');s.usable[KICK]=nil;s.health.player=100
 s.buff('player',SHUFFLE,{expirationTime=101.5,duration=6});s.resource[CHI]=0;s.cooling(EXPEL,5)
 M.expect(a,s,BM,JAB,nil,'Shuffle about to drop with no Chi: Jab to rebuild')
 s.resource[CHI]=2;M.expect(a,s,BM,KICK,nil,'Shuffle about to drop: Blackout Kick')
 s.clearAuras();s.shift(OX);s.buff('player',SHUFFLE,{expirationTime=110,duration=6});s.resource[CHI]=1
 M.expect(a,s,BM,PALM,nil,'Tiger Power missing: Tiger Palm')
 s.usable[TOD]=nil;M.expect(a,s,BM,TOD,nil,'Death Note: Touch of Death')
end)
test('Brewmaster: early ranks at level 10 and 11',function()
 local a,s=monk(10,{stance=OX});s.learn(OX,JAB,PALM,KICK,HAZE);s.usable[PALM]=false
 M.expect(a,s,BM,KICK,nil,'level 10 has no Shuffle: Blackout Kick spends Chi')
 s.usable[KICK]=false;M.expect(a,s,BM,JAB,nil,'level 10 with no Chi: Jab')
 s.setLevel(11);s.learn(KEG);M.expect(a,s,BM,KEG,nil,'level 11: Keg Smash')
end)
test('Brewmaster: packs only spend Breath of Fire and Spinning Crane Kick while Shuffle is safe',function()
 local a,s=brewmaster();s.resource[CHI]=2;s.cooling(KEG,5);s.near(3);s.health.player=100
 M.expect(a,s,BM,BOF,nil,'three enemies, Shuffle 10 s: Breath of Fire')
 s.debuff('target',123725);s.energy=75;M.expect(a,s,BM,SCK,nil,'burning, 70 energy: Spinning Crane Kick')
 s.talents[16]=true;s.learn(RJW);M.expect(a,s,BM,RJW,nil,'Rushing Jade Wind replaces Crane Kick')
 s.talents[16]=nil;s.known[RJW]=nil
 s.clearAuras();s.buff('player',SHUFFLE,{expirationTime=104,duration=6});s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 M.expect(a,s,BM,SCK,nil,'Shuffle 4 s: no Breath of Fire, still Crane Kick')
 s.near(2);M.expect(a,s,BM,PALM,nil,'two enemies: single target')
end)
test('Brewmaster reminders: stance, Legacy, purify by stagger, Elusive Brew, Guard, Chi Brew, defensives',function()
 local a,s=brewmaster();s.learn(CHIBREW,XUEN,STATUE)
 s.combat=false;s.clearAuras();local lit=M.upkeep(a,s,BM);assert(lit[OX]and lit[LEGACY],'Sturdy Ox and Legacy out of combat')
 s.shift(OX);s.buff('player',20217,{sourceUnit='party1'});lit=M.upkeep(a,s,BM);assert(not lit[OX]and not lit[LEGACY],'Kings from anyone covers Legacy')
 assert(not lit[STATUE],'the statue reminder ships off')
 s.combat=true;s.buff('player',SHUFFLE,{expirationTime=110,duration=6})
 s.debuff('player',MODERATE,{sourceUnit='target'});lit=M.upkeep(a,s,BM);assert(lit[PURIFY],'Moderate Stagger with Shuffle banked')
 s.clearAuras();s.shift(OX);s.buff('player',SHUFFLE,{expirationTime=102,duration=6});s.debuff('player',MODERATE,{sourceUnit='target'})
 lit=M.upkeep(a,s,BM);assert(not lit[PURIFY],'Moderate Stagger with Shuffle short: keep the Chi')
 s.debuff('player',HEAVY,{sourceUnit='target'});lit=M.upkeep(a,s,BM);assert(lit[PURIFY],'Heavy Stagger always')
 s.clearAuras();s.shift(OX);s.buff('player',SHUFFLE,{expirationTime=110,duration=6});s.buff('player',ELUSIVESTACKS,{applications=8})
 lit=M.upkeep(a,s,BM);assert(lit[ELUSIVE],'eight Elusive Brew stacks')
 s.buff('player',ELUSIVE);lit=M.upkeep(a,s,BM);assert(not lit[ELUSIVE],'not while it runs')
 s.resource[CHI]=3;lit=M.upkeep(a,s,BM);assert(not lit[GUARD],'no Power Guard: no Guard')
 s.buff('player',POWERGUARD);lit=M.upkeep(a,s,BM);assert(lit[GUARD],'Power Guard, Shuffle safe, three Chi: Guard')
 s.resource[CHI]=0;s.cooling(KEG,5);lit=M.upkeep(a,s,BM);assert(lit[CHIBREW],'empty with Keg Smash away: Chi Brew')
 s.clearAuras();s.shift(OX);s.buff('player',SHUFFLE,{expirationTime=110,duration=6});s.buff('player',ELUSIVESTACKS,{applications=12});lit=M.upkeep(a,s,BM);assert(not lit[CHIBREW],'would overflow Elusive Brew stacks')
 s.classification='elite';s.health.player=30;lit=M.upkeep(a,s,BM);assert(lit[XUEN]and lit[FORT],'Xuen on an elite, Fortifying Brew when low')
end)
test('Brewmaster Offensive: Rushing Jade Wind before Keg Smash, purify only on the Purifier proc',function()
 local a,s=brewmaster();s.learn(RJW,CHIBREW);assert(a:SetDefaultRotationEnabled(BMO,true))
 s.resource[CHI]=1;M.expect(a,s,BMO,RJW,nil,'Rushing Jade Wind first');s.cooling(RJW,5)
 M.expect(a,s,BMO,KEG,nil,'then Keg Smash');s.cooling(KEG,5)
 s.resource[CHI]=3;M.expect(a,s,BMO,KICK,nil,'at the cap minus one: Blackout Kick')
 s.resource[CHI]=1;M.expect(a,s,BMO,PALM,nil,'Tiger Palm filler')
 s.combat=true;s.debuff('player',HEAVY,{sourceUnit='target'});local lit=M.upkeep(a,s,BMO);assert(not lit[PURIFY]and not lit[GUARD],'no routine purify or Guard')
 s.buff('player',PURIFIER);lit=M.upkeep(a,s,BMO);assert(lit[PURIFY],'Purifier proc')
 s.cast=true;M.expect(a,s,BMO,nil,'stopped','casting')
end)
-- A level-90 Windwalker in Fierce Tiger.
local function windwalker(level)
 local a,s,f=monk(level or 90)
 s.learn(FOF,TIGER,JAB,PALM,KICK,EXPEL,TOD,SCK,RSK,TEB,ENERGIZING,SEF,KARMA,WHITE,FORT,LEGACY,SPEAR,CJL)
 s.buff('player',TIGERPOWER,{expirationTime=115,duration=20});s.debuff('target',RSKDEBUFF,{expirationTime=110,duration=15})
 s.usable[TOD]=false
 return a,s,f
end
test('Windwalker: boundaries, pull, Touch of Death',function()
 local a,s=windwalker();s.learn(CHIWAVE)
 s.channel=true;M.expect(a,s,WW,nil,'stopped','channelling Fists of Fury');s.channel=false
 s.cast=true;M.expect(a,s,WW,nil,'stopped','casting');s.cast=false
 s.hostile=false;M.expect(a,s,WW,nil,'stopped','no attackable target');s.hostile=true
 s.combat=false;M.expect(a,s,WW,CHIWAVE,nil,'pull: Chi Wave');s.cooling(CHIWAVE,10)
 local r=M.expect(a,s,WW,nil,'stopped','pull ends');assert(not r.suppressAttack);s.combat=true
 s.usable[TOD]=nil;M.expect(a,s,WW,TOD,nil,'Death Note: Touch of Death first')
end)
test('Windwalker: Tiger Power, Rising Sun Kick, Combo Breaker, Fists of Fury, Jab, Blackout Kick',function()
 local a,s=windwalker();s.resource[CHI]=2
 M.expect(a,s,WW,RSK,nil,'Rising Sun Kick on cooldown');s.cooling(RSK,6)
 s.buff('player',CBKICK);M.expect(a,s,WW,KICK,nil,'Combo Breaker: Blackout Kick')
 s.clearAuras();s.shift(TIGER);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 s.resource[CHI]=3;M.expect(a,s,WW,FOF,nil,'Rising Sun Kick 6 s away, energy low: Fists of Fury')
 s.energy=60;M.expect(a,s,WW,KICK,nil,'energy would cap during the channel: Blackout Kick')
 s.energy=40;s.moving=true;M.expect(a,s,WW,KICK,nil,'moving: no Fists of Fury');s.moving=false
 s.buff('player',ENERGIZING);M.expect(a,s,WW,KICK,nil,'inside Energizing Brew: no Fists of Fury')
 s.clearAuras();s.shift(TIGER);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20});s.resource[CHI]=1;s.cooldown[FOF]=nil;s.cooling(FOF,10)
 M.expect(a,s,WW,JAB,nil,'two Chi missing: Jab');s.health.player=70;M.expect(a,s,WW,EXPEL,nil,'hurt: Expel Harm instead of Jab');s.health.player=100
 s.resource[CHI]=4;M.expect(a,s,WW,KICK,nil,'Chi to spare: Blackout Kick')
 s.cooling(RSK,1);s.resource[CHI]=3;M.expect(a,s,WW,nil,nil,'Rising Sun Kick nearly back: hold the Chi')
 s.clearAuras();s.shift(TIGER);M.expect(a,s,WW,PALM,nil,'Tiger Power missing: Tiger Palm')
 s.buff('player',TIGERPOWER,{expirationTime=115,duration=20});s.buff('player',CBPALM);s.resource[CHI]=4;M.expect(a,s,WW,PALM,nil,'Combo Breaker: free Tiger Palm')
end)
test('Windwalker: level 10 kit before Rising Sun Kick',function()
 local a,s=monk(10);s.learn(FOF,JAB,PALM,KICK);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 s.resource[CHI]=3;M.expect(a,s,WW,FOF,nil,'level 10: Fists of Fury with three Chi')
 s.cooling(FOF,10);M.expect(a,s,WW,KICK,nil,'no Rising Sun Kick known: Blackout Kick spends')
 s.resource[CHI]=1;M.expect(a,s,WW,JAB,nil,'Jab builds')
end)
test('Windwalker: cleave at two, Spinning Crane Kick at three and four',function()
 local a,s=windwalker();s.resource[CHI]=2;s.near(2);s.cooling(FOF,10)
 M.expect(a,s,WW,RSK,nil,'two enemies: Rising Sun Kick on cooldown');s.cooling(RSK,6)
 s.near(3);M.expect(a,s,WW,SCK,nil,'three enemies: Spinning Crane Kick')
 s.near(4);M.expect(a,s,WW,SCK,nil,'four enemies with the debuff up: Crane Kick')
 s.learn(RJW);M.expect(a,s,WW,RJW,nil,'Rushing Jade Wind first');s.known[RJW]=nil
 s.near(1);M.expect(a,s,WW,JAB,nil,'one enemy, two Chi missing: Jab')
end)
test('Windwalker reminders: Tigereye Brew stacks, Energizing Brew, Chi Brew, Storm Earth and Fire, Karma',function()
 local a,s=windwalker();s.learn(CHIBREW,XUEN)
 s.combat=false;s.clearAuras();local lit=M.upkeep(a,s,WW);assert(lit[TIGER]and lit[WHITE]and lit[LEGACY],'stance, White Tiger, Legacy: '..tostring(lit[TIGER])..tostring(lit[WHITE])..tostring(lit[LEGACY]))
 s.combat=true;s.shift(TIGER);s.buff('player',TEBSTACKS,{applications=12});s.resource[CHI]=1
 lit=M.upkeep(a,s,WW);assert(not lit[TEB],'12 stacks, no burst: hold Tigereye Brew')
 s.buff('player',2825,{sourceUnit='party1'});lit=M.upkeep(a,s,WW);assert(lit[TEB],'Bloodlust: 10 stacks are enough')
 s.clearAuras();s.shift(TIGER);s.buff('player',TEBSTACKS,{applications=16});lit=M.upkeep(a,s,WW);assert(not lit[TEB],'16 stacks with one Chi')
 s.resource[CHI]=2;lit=M.upkeep(a,s,WW);assert(lit[TEB],'16 stacks with two Chi')
 s.buff('player',TEB);lit=M.upkeep(a,s,WW);assert(not lit[TEB],'already active')
 s.energy=30;lit=M.upkeep(a,s,WW);assert(lit[ENERGIZING],'low energy: Energizing Brew')
 s.resource[CHI]=1;lit=M.upkeep(a,s,WW);assert(lit[CHIBREW],'inside Tigereye Brew with room: Chi Brew')
 s.clearAuras();s.shift(TIGER);lit=M.upkeep(a,s,WW);assert(not lit[CHIBREW],'one charge, no Tigereye Brew: keep it')
 s.chiBrew=2;lit=M.upkeep(a,s,WW);assert(lit[CHIBREW],'two charges: Chi Brew')
 s.near(2);lit=M.upkeep(a,s,WW);assert(lit[SEF],'two enemies: Storm, Earth, and Fire')
 s.health.player=50;s.targetTarget='player';lit=M.upkeep(a,s,WW);assert(lit[KARMA]and not lit[FORT],'Touch of Karma at 50% while tanked')
end)
test('Windwalker SimC: Rising Sun Kick debuff first, Fists of Fury tied to Tigereye Brew, AoE pooling',function()
 local a,s=windwalker();assert(a:SetDefaultRotationEnabled(WWS,true));s.resource[CHI]=3;s.energy=40
 s.clearAuras();s.shift(TIGER);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20})
 M.expect(a,s,WWS,RSK,nil,'debuff missing: Rising Sun Kick');s.debuff('target',RSKDEBUFF,{expirationTime=110,duration=15});s.cooling(RSK,6)
 M.expect(a,s,WWS,KICK,nil,'no Tigereye Brew: no Fists of Fury')
 s.buff('player',TEB);M.expect(a,s,WWS,FOF,nil,'inside Tigereye Brew: Fists of Fury')
 s.clearAuras();s.shift(TIGER);s.buff('player',TIGERPOWER,{expirationTime=102,duration=20});M.expect(a,s,WWS,PALM,nil,'Tiger Power under 3 s')
 s.clearAuras();s.shift(TIGER);s.buff('player',TIGERPOWER,{expirationTime=115,duration=20});s.debuff('target',RSKDEBUFF,{expirationTime=110,duration=15});s.near(3)
 M.expect(a,s,WWS,SCK,nil,'three enemies: Spinning Crane Kick');s.cooling(SCK,1)
 s.energy=40;local r=M.expect(a,s,WWS,nil,'stopped','AoE below 60 energy: pool');assert(not r.suppressAttack)
end)
-- A level-90 Mistweaver in Wise Serpent, on mana.
local function mistweaver()
 local a,s,f=monk(90,{stance=SERPENT});s.powerType=0
 s.learn(SOOTHING,SERPENT,JAB,PALM,KICK,EXPEL,TOD,SURGING,ENVELOPING,RENEWING,UPLIFT,TFT,MANATEA,COCOON,DETOX,STATUE,SCK,CJL,LEGACY,SPEAR,FORT)
 s.usable[TOD]=false
 return a,s,f
end
test('Mistweaver healing: Renewing Mist, Uplift on a hurt group, Expel Harm, Soothing Mist, healthy stop',function()
 local a,s=mistweaver();s.hostile=false;s.friendly=true;s.combat=true;s.health.target=70;s.resource[CHI]=4
 M.expect(a,s,MW,RENEWING,nil,'Renewing Mist on cooldown');s.cooling(RENEWING,5)
 s.members(70,60,80,90);M.expect(a,s,MW,UPLIFT,nil,'three hurt allies and Chi: Uplift');s.party={};s.group=false
 M.expect(a,s,MW,SOOTHING,nil,'capped and alone: Soothing Mist on the target')
 s.resource[CHI]=2;M.expect(a,s,MW,EXPEL,nil,'room for Chi: Expel Harm');s.cooling(EXPEL,5)
 s.buff('player',VITAL,{applications=5});M.expect(a,s,MW,SURGING,nil,'five Vital Mists: Surging Mist');s.clearAuras();s.shift(SERPENT)
 s.health.target=95;local r=M.expect(a,s,MW,nil,'stopped','healthy friendly target');assert(r.suppressAttack)
 s.dead=true;s.health.target=10;M.expect(a,s,MW,nil,'stopped','a dead friend is not healed or attacked')
end)
test('Mistweaver: Enveloping and Surging Mist inside the Soothing Mist channel; other channels stop',function()
 local a,s=mistweaver();s.hostile=false;s.friendly=true;s.health.target=70;s.resource[CHI]=3
 s.channel=true;s.buff('target',SOOTHING);M.expect(a,s,MW,nil,'stopped','a Soothing Mist heal on the target is not your channel')
 s.channelSpell=SOOTHING;M.expect(a,s,MW,ENVELOPING,nil,'inside Soothing Mist: Enveloping Mist')
 s.buff('target',132120);M.expect(a,s,MW,nil,'stopped','Enveloping running, target at 70%: keep channelling')
 s.health.target=50;M.expect(a,s,MW,SURGING,nil,'below 60%: Surging Mist')
 s.clearAuras();s.channelSpell=MANATEA;M.expect(a,s,MW,nil,'stopped','another channel (Mana Tea) ends advice')
end)
test('Mistweaver fistweaving on an enemy: Muscle Memory spenders, capped Chi, Vital Mists, Jab',function()
 local a,s=mistweaver();s.resource[CHI]=1
 s.combat=false;s.targetRange={20,25};M.expect(a,s,MW,RENEWING,nil,'pull: Renewing Mist banks Chi');s.cooling(RENEWING,5)
 M.expect(a,s,MW,CJL,nil,'then Crackling Jade Lightning');s.targetRange={0,5};s.combat=true
 M.expect(a,s,MW,EXPEL,nil,'room for Chi: Expel Harm');s.cooling(EXPEL,5)
 M.expect(a,s,MW,JAB,nil,'Jab filler procs Muscle Memory')
 s.buff('player',MEMORY);M.expect(a,s,MW,PALM,nil,'Muscle Memory, no Tiger Power: Tiger Palm')
 s.buff('player',TIGERPOWER,{expirationTime=115,duration=20});M.expect(a,s,MW,KICK,nil,'Muscle Memory, no Serpent\'s Zeal: Blackout Kick')
 s.buff('player',ZEAL,{expirationTime=115,duration=30});M.expect(a,s,MW,PALM,nil,'both up: Tiger Palm spends Muscle Memory')
 s.clearAuras();s.shift(SERPENT);s.resource[CHI]=4;M.expect(a,s,MW,KICK,nil,'capped without Muscle Memory: Blackout Kick')
 s.resource[CHI]=2;s.buff('player',VITAL,{applications=5});M.expect(a,s,MW,SURGING,nil,'five Vital Mists: free Surging Mist')
 s.hostile=false;s.clearAuras();M.expect(a,s,MW,nil,'stopped','nothing targeted')
end)
test('Mistweaver reminders: stance, statue, Mana Tea, Thunder Focus Tea, Life Cocoon, Detox',function()
 local a,s=mistweaver();s.combat=false;s.clearAuras()
 local lit=M.upkeep(a,s,MW);assert(lit[SERPENT]and lit[LEGACY]and not lit[STATUE],'Wise Serpent and Legacy solo; statue only in a group')
 s.group=true;lit=M.upkeep(a,s,MW);assert(lit[STATUE],'group: Jade Serpent Statue');s.history(STATUE,60);lit=M.upkeep(a,s,MW);assert(not lit[STATUE],'placed a minute ago')
 s.buff('player',MANATEASTACKS,{applications=4});s.mana.player=60;lit=M.upkeep(a,s,MW);assert(lit[MANATEA],'downtime with stacks: Mana Tea')
 s.members(50,60,90);lit=M.upkeep(a,s,MW);assert(not lit[MANATEA],'two allies hurt: heal instead')
 s.combat=true;s.resource[CHI]=3;s.members(50,60,80);lit=M.upkeep(a,s,MW);assert(lit[TFT],'three hurt with Chi: Thunder Focus Tea')
 s.hostile=false;s.friendly=true;s.health.target=30;lit=M.upkeep(a,s,MW);assert(lit[COCOON],'friend under 35%: Life Cocoon')
 s.debuff('target',12345,{dispelName='Magic',sourceUnit='target'});lit=M.upkeep(a,s,MW);assert(lit[DETOX],'Magic on a friend: Detox')
 s.health.player=30;lit=M.upkeep(a,s,MW);assert(lit[FORT],'low: Fortifying Brew')
end)
finish()
