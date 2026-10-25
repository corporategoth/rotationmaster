-- Mists of Pandaria Classic Paladin premades: switches, priorities, boundaries and reminders through
-- the real catalog, predicates, composition and sequence executor on a modeled 5.5.4 client
-- (tests/fixtures/mop_premade_model_a.lua). Holy Power is POINT (s.resource[9]); seals are stances read
-- by spell (FORM form), on a stance bar in the order they were learned (Command, Truth, Righteousness,
-- Insight here), with none active by default.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/mop_premade_model_a.lua')
local RET,RETTAV,PROT,PROTSIM,HOLY,START='rm.mop.paladin.retribution','rm.mop.paladin.retribution.warcrafttavern','rm.mop.paladin.protection',
 'rm.mop.paladin.protection.wowsims','rm.mop.paladin.holy','rm.mop.paladin.unspecialized'
local HP=M.POWER.HolyPower
local COMMAND,TRUTH,RIGHTEOUSNESS,INSIGHT=105361,31801,20154,20165
local function paladin(level)
 local f,s=M.new('paladin');local a=f.addon
 s.setLevel(level or 90);s.resource[HP]=0;s.bar={COMMAND,TRUTH,RIGHTEOUSNESS,INSIGHT};s.form=0
 return a,s,f
end
test('the Paladin premades load, validate and declare Mists of Pandaria only',function()
 M.scope('paladin',{RET,PROT,HOLY},10)
 local a,s=M.scope('paladin',{START},1);local rows=M.rows(a)
 -- Disabled variants: same scope, eligible once enabled.
 for _,id in ipairs({RETTAV,PROTSIM})do
  local scope=rows[id].applicability
  assert(scope.minExpansion==4 and scope.maxExpansion==4 and scope.minLevel==nil and scope.maxLevel==nil and scope.families[1]=='progression',id)
  assert(not rows[id].eligible and rows[id].eligibilityReason=='disabled',id)
  -- Eligible in its own specialization (body.specs).
  s.specID(rows[id].envelope.body.specs[1]);a:InvalidateBuildContext()
  assert(a:SetDefaultRotationEnabled(id,true));assert(M.rows(a)[id].eligible,id..' not eligible once enabled')
 end
 assert(rows[RETTAV].envelope.body.disabled and rows[PROTSIM].envelope.body.disabled,'source variants ship disabled')
 assert(not rows[RET].envelope.body.disabled and not rows[PROT].envelope.body.disabled and not rows[HOLY].envelope.body.disabled and not rows[START].envelope.body.disabled)
end)
test('switch: the catch-all owns levels 1-9 and an unspecialized paladin; each specialization picks its premade',function()
 local a,s=paladin(1);s.learn(35395);assert(M.selected(a)==START,'level 1')
 s.setLevel(9);s.learn(20271,85673);s.specID(70);assert(M.selected(a)==START,'level 9 stays in the catch-all');s.spec=nil
 s.setLevel(10);s.learn(85256,31935,20473);assert(M.selected(a)==START,'level 10 without a specialization')
 s.specID(70);assert(M.selected(a)==RET,'Retribution')
 assert(M.switch(a,RETTAV)=='match','the Warcraft Tavern variant shares the switch')
 s.specID(66);assert(M.selected(a)==PROT,'Protection')
 assert(M.switch(a,PROTSIM)=='match','the wowsims variant shares the switch')
 s.specID(65);assert(M.selected(a)==HOLY,'Holy')
 s.setLevel(90);s.known={};s.spec=nil;assert(M.selected(a)==START,'a level-90 paladin without a specialization still gets a premade')
 a:SetDefaultRotationEnabled(RETTAV,true);a:SetDefaultRotationEnabled(RET,false);s.specID(70)
 assert(M.selected(a)==RETTAV,'enabling the variant and disabling the recommended pack switches to it')
end)
test('unspecialized: boundaries, pull, danger and generators',function()
 local a,s=paladin(9);s.learn(35395,20271,85673,853)
 s.cast=true;M.expect(a,s,START,nil,'stopped','casting');s.cast=false
 s.hostile=false;M.expect(a,s,START,nil,'stopped','no hostile target');s.hostile=true
 s.combat=false;s.targetRange={20,25};M.expect(a,s,START,20271,nil,'pull with Judgment')
 s.cooling(20271,4);M.expect(a,s,START,nil,'stopped','pull, Judgment cooling');s.cooldown={};s.combat=true;s.targetRange={0,5}
 M.expect(a,s,START,35395,nil,'Crusader Strike');s.cooling(35395,3);M.expect(a,s,START,20271,nil,'Judgment');s.cooldown={}
 s.health.player=45;M.expect(a,s,START,853,nil,'solo and hurt: Hammer of Justice')
 s.health.player=30;M.expect(a,s,START,85673,nil,'in danger: Word of Glory')
 s.learn(105361,19750);s.combat=false;local lit=M.upkeep(a,s,START);assert(lit[105361]and lit[19750],'Seal of Command and an out-of-combat Flash of Light')
 s.shift(COMMAND);assert(not M.upkeep(a,s,START)[105361],'in Seal of Command')
end)
test('Retribution: boundaries, pull, early training',function()
 local a,s=paladin(10);s.maximum={[HP]=3};s.learn(35395,20271,85673,85256)
 s.cast=true;M.expect(a,s,RET,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,RET,nil,'stopped','channelling');s.channel=false
 s.hostile=false;M.expect(a,s,RET,nil,'stopped','not attackable');s.hostile=true
 s.combat=false;s.targetRange={20,25};M.expect(a,s,RET,20271,nil,'pull: Judgment')
 s.cooling(20271,4);M.expect(a,s,RET,nil,'stopped','pull ends in a stop');s.cooldown={};s.combat=true;s.targetRange={0,5}
 M.expect(a,s,RET,35395,nil,'level 10: Crusader Strike')
 s.resource[HP]=3;M.expect(a,s,RET,85256,nil,'3 of 3 Holy Power before 85: Templar\'s Verdict')
 s.resource[HP]=2;s.cooling(35395,3);M.expect(a,s,RET,20271,nil,'Judgment');s.cooldown={}
 s.health.player=30;M.expect(a,s,RET,85673,nil,'solo, in danger: Word of Glory');s.group=true;M.expect(a,s,RET,35395,nil,'no Word of Glory in a group')
end)
test('Retribution: Inquisition, pooling, generators and wings at 90',function()
 local a,s=paladin();s.learn(35395,20271,85673,85256,53385,24275,879,84963,53595,31884)
 s.resource[HP]=2;M.expect(a,s,RET,24275,nil,'no Inquisition at 2 Holy Power: Hammer of Wrath')
 s.resource[HP]=3;M.expect(a,s,RET,84963,nil,'Inquisition at 3')
 s.buff('player',84963,{expirationTime=102,duration=30});M.expect(a,s,RET,84963,nil,'refresh at 3 s or less');s.clearAuras()
 s.buff('player',84963,{expirationTime=130,duration=30});M.expect(a,s,RET,24275,nil,'3 Holy Power with Inquisition: generate first')
 s.resource[HP]=5;M.expect(a,s,RET,85256,nil,'at 5: Templar\'s Verdict before generators');s.resource[HP]=3
 s.cooling(24275,5);M.expect(a,s,RET,35395,nil,'Crusader Strike');s.cooling(35395,3)
 M.expect(a,s,RET,20271,nil,'Judgment');s.cooling(20271,4);M.expect(a,s,RET,879,nil,'Exorcism');s.cooling(879,8)
 M.expect(a,s,RET,85256,nil,'nothing else: Templar\'s Verdict at 3 with Inquisition over 4 s')
 s.clearAuras();s.buff('player',84963,{expirationTime=103.5,duration=30});s.resource[HP]=2;M.expect(a,s,RET,nil,nil,'no Verdict that would starve the refresh');s.cooldown={}
 s.clearAuras();s.buff('player',84963,{expirationTime=130,duration=30});s.buff('player',31884);s.resource[HP]=3;s.cooling(24275,5)
 M.expect(a,s,RET,85256,nil,'Avenging Wrath: no pooling');s.resource[HP]=1;s.usable[85256]=false;M.expect(a,s,RET,20271,nil,'Avenging Wrath: Judgment above Crusader Strike');s.usable[85256]=nil
 s.clearAuras();s.buff('player',84963,{expirationTime=130,duration=30});s.buff('player',90174);M.expect(a,s,RET,85256,nil,'Divine Purpose: free Verdict')
end)
test('Retribution: two or more enemies',function()
 local a,s=paladin();s.learn(35395,20271,85256,53385,24275,879,53595)
 s.buff('player',84963,{expirationTime=130,duration=30});s.learn(84963)
 s.near(2);s.resource[HP]=5;M.expect(a,s,RET,53385,nil,'capped: Divine Storm')
 s.resource[HP]=3;M.expect(a,s,RET,24275,nil,'Hammer of Wrath');s.cooling(24275,5)
 M.expect(a,s,RET,35395,nil,'two enemies: Crusader Strike')
 s.near(4);M.expect(a,s,RET,53595,nil,'four within 8 yards: Hammer of the Righteous')
 s.cooling(53595,3);s.cooling(35395,3);s.cooling(20271,4);s.cooling(879,8);M.expect(a,s,RET,53385,nil,'nothing else: Divine Storm at 3')
 s.usable[53385]=false;M.expect(a,s,RET,nil,'stopped','the AoE arm ends in a stop')
 local b,t=paladin(30);t.maximum={[HP]=3};t.learn(35395,20271,85256);t.near(2);t.resource[HP]=3
 M.expect(b,t,RET,85256,nil,'before Divine Storm (34): Templar\'s Verdict')
end)
test('Retribution reminders: seal, blessing, Rebuke, wings, Guardian, Holy Avenger, defensives',function()
 local a,s=paladin();s.learn(31801,105361,20217,19740,96231,31884,86698,105809,114157,498,633,84963)
 s.combat=false;local lit=M.upkeep(a,s,RET);assert(lit[31801]and not lit[105361]and lit[20217]and not lit[19740],'Seal of Truth and Kings')
 s.shift(COMMAND);assert(M.upkeep(a,s,RET)[31801],'Seal of Command left over from levelling: Seal of Truth')
 s.shift(INSIGHT);assert(M.upkeep(a,s,RET)[31801],'the wrong seal: Seal of Truth')
 s.shift(TRUTH);assert(not M.upkeep(a,s,RET)[31801],'in Seal of Truth')
 s.bar={TRUTH,COMMAND,INSIGHT,RIGHTEOUSNESS};s.form=1;assert(not M.upkeep(a,s,RET)[31801],'Seal of Truth wherever it sits on the bar')
 s.form=4;s.buff('player',20217,{sourceUnit='party1'});lit=M.upkeep(a,s,RET);assert(not lit[31801]and not lit[20217]and lit[19740],'Seal of Righteousness you chose is kept; Might over another paladin\'s Kings')
 s.bar[4]={};lit=M.upkeep(a,s,RET);assert(not lit[31801],'an unreadable seal skips the reminder')
 s.clearAuras();s.combat=true;lit=M.upkeep(a,s,RET);assert(not lit[31884]and not lit[114157],'no wings or Execution Sentence without Inquisition')
 s.buff('player',84963);s.classification='elite';lit=M.upkeep(a,s,RET);assert(lit[31884]and lit[86698]and lit[114157],'Inquisition and an elite: wings, Guardian, Execution Sentence')
 s.buff('player',31884);s.resource[HP]=2;lit=M.upkeep(a,s,RET);assert(lit[105809],'Holy Avenger in wings at 2 or less');s.resource[HP]=3;assert(not M.upkeep(a,s,RET)[105809],'not at 3')
 s.health.player=50;lit=M.upkeep(a,s,RET);assert(lit[498]and not lit[633],'Divine Protection solo')
 s.health.player=15;s.debuff('player',25771);lit=M.upkeep(a,s,RET);assert(not lit[633],'Forbearance blocks Lay on Hands')
 s.auras.player.HARMFUL={};lit=M.upkeep(a,s,RET);assert(lit[633],'Lay on Hands')
end)
test('Retribution, Warcraft Tavern: Exorcism first, Inquisition at any Holy Power when missing',function()
 local a,s=paladin();s.learn(35395,20271,85256,53385,24275,879,84963)
 M.expect(a,s,RETTAV,879,nil,'Exorcism first');s.cooling(879,8)
 s.resource[HP]=1;M.expect(a,s,RETTAV,84963,nil,'Inquisition missing: cast it at 1')
 s.buff('player',84963,{expirationTime=115,duration=30});M.expect(a,s,RETTAV,35395,nil,'15 s left at 1 Holy Power: Crusader Strike')
 s.resource[HP]=3;M.expect(a,s,RETTAV,84963,nil,'refresh at 3 in the last 20 s')
 s.clearAuras();s.buff('player',84963,{expirationTime=130,duration=30});s.cooling(35395,3);s.cooling(20271,4);M.expect(a,s,RETTAV,85256,nil,'Templar\'s Verdict before Hammer of Wrath')
 s.cooldown={};s.combat=false;s.targetRange={20,25};M.expect(a,s,RETTAV,879,nil,'pull: Exorcism')
end)
test('Protection: pull, Grand Crusader, single target, training stages',function()
 local a,s=paladin(10);s.learn(35395,20271,31935)
 s.combat=false;M.expect(a,s,PROT,31935,nil,'pull: Avenger\'s Shield');s.cooling(31935,10);s.targetRange={20,25}
 M.expect(a,s,PROT,20271,nil,'pull from range: Judgment');s.cooling(20271,4);M.expect(a,s,PROT,nil,'stopped','pull stop');s.cooldown={};s.targetRange={0,5};s.combat=true
 s.cast=true;M.expect(a,s,PROT,nil,'stopped','casting');s.cast=false
 s.hostile=false;M.expect(a,s,PROT,nil,'stopped','not attackable');s.hostile=true
 M.expect(a,s,PROT,31935,nil,'level 10: Avenger\'s Shield');s.cooling(31935,10);M.expect(a,s,PROT,35395,nil,'Crusader Strike')
 s.setLevel(90);s.learn(24275,26573,119072,53595,114157,20925);s.cooldown={}
 s.buff('player',85416);M.expect(a,s,PROT,31935,nil,'Grand Crusader: Avenger\'s Shield');s.clearAuras();s.cooling(31935,10)
 M.expect(a,s,PROT,24275,nil,'Hammer of Wrath');s.cooling(24275,5);M.expect(a,s,PROT,35395,nil,'Crusader Strike');s.cooling(35395,3)
 M.expect(a,s,PROT,20271,nil,'Judgment');s.cooling(20271,4);M.expect(a,s,PROT,114157,nil,'Execution Sentence');s.cooling(114157,30)
 M.expect(a,s,PROT,26573,nil,'Consecration');s.cooling(26573,5);M.expect(a,s,PROT,119072,nil,'Holy Wrath');s.cooling(119072,5)
 M.expect(a,s,PROT,20925,nil,'Sacred Shield filler')
 s.cooldown={};s.learn(31884);s.buff('player',31884);s.talents[14]=true;M.expect(a,s,PROT,20271,nil,'Sanctified Wrath in wings: Judgment first')
end)
test('Protection: three enemies use Icy Veins\' AoE order',function()
 local a,s=paladin();s.learn(35395,20271,31935,24275,26573,119072,53595)
 s.near(3);M.expect(a,s,PROT,31935,nil,'Avenger\'s Shield');s.cooling(31935,10)
 M.expect(a,s,PROT,26573,nil,'Consecration');s.cooling(26573,5);M.expect(a,s,PROT,53595,nil,'Hammer of the Righteous')
 s.near(2);M.expect(a,s,PROT,24275,nil,'two enemies: single target')
end)
test('Protection reminders: Righteous Fury, Insight, Shield of the Righteous, Eternal Flame, wings, defensives',function()
 local a,s,f=paladin();s.learn(25780,20165,31801,53600,114163,85673,20925,31884,105809,86659,31850,498,633)
 s.combat=false;local lit=M.upkeep(a,s,PROT);assert(lit[25780]and lit[20165]and not lit[31801]and lit[20925]and not lit[53600],'out of combat: Fury, Insight, Sacred Shield')
 s.shift(TRUTH);assert(M.upkeep(a,s,PROT)[20165],'Seal of Truth from before 32: Insight');s.shift(RIGHTEOUSNESS);assert(not M.upkeep(a,s,PROT)[20165],'Righteousness for a pack is kept')
 s.shift(INSIGHT);s.buff('player',25780);s.buff('player',65148,{expirationTime=130,duration=30});s.combat=true
 lit=M.upkeep(a,s,PROT);assert(lit[53600]and not lit[25780]and not lit[20925],'Shield of the Righteous whenever usable')
 assert(not lit[114163],'no Eternal Flame without Holy Power');s.resource[HP]=3;assert(not M.upkeep(a,s,PROT)[114163],'nor without Bastion of Glory')
 s.buff('player',114637,{applications=3});lit=M.upkeep(a,s,PROT);assert(lit[114163],'3 Holy Power and 3 Bastion: Eternal Flame')
 s.buff('player',114163,{expirationTime=125,duration=30});assert(not M.upkeep(a,s,PROT)[114163],'not while it is running')
 s.health.player=45;lit=M.upkeep(a,s,PROT);assert(not lit[85673],'no Word of Glory with Eternal Flame talented')
 assert(lit[86659]and lit[498]and not lit[31850],'Guardian and Divine Protection when hurt')
 s.health.player=30;s.buff('player',86659);lit=M.upkeep(a,s,PROT);assert(not lit[31850],'no Ardent Defender inside Guardian')
 s.health.player=100;s.clearAuras();assert(not M.upkeep(a,s,PROT)[31884],'wings only while tanking')
 f.env.UnitThreatSituation=function(_,unit)if unit=='target'then return 3 end end;lit=M.upkeep(a,s,PROT);assert(lit[31884]and lit[105809],'tanking: wings and Holy Avenger')
 s.forget(114163);s.health.player=45;assert(M.upkeep(a,s,PROT)[85673],'Word of Glory without Eternal Flame')
end)
test('Protection, wowsims: Shield of the Righteous pools to full, melee generators first',function()
 local a,s=paladin();s.learn(35395,20271,31935,53600,119072,20925)
 s.resource[HP]=3;local lit=M.upkeep(a,s,PROTSIM);assert(not lit[53600],'3 of 5: pool')
 s.resource[HP]=5;assert(M.upkeep(a,s,PROTSIM)[53600],'5: spend');s.resource[HP]=3
 s.health.player=35;assert(M.upkeep(a,s,PROTSIM)[53600],'below 40%: spend at 3');s.health.player=100
 s.buff('player',90174);assert(M.upkeep(a,s,PROTSIM)[53600],'Divine Purpose');s.clearAuras()
 M.expect(a,s,PROTSIM,35395,nil,'Crusader Strike before Avenger\'s Shield');s.cooling(35395,3)
 M.expect(a,s,PROTSIM,20271,nil,'Judgment');s.cooling(20271,4);M.expect(a,s,PROTSIM,31935,nil,'then Avenger\'s Shield')
 s.combat=false;s.cooldown={};M.expect(a,s,PROTSIM,31935,nil,'pull: Avenger\'s Shield');s.combat=true
 s.near(3);M.expect(a,s,PROTSIM,31935,nil,'shared AoE arm')
end)
local function healer(level)
 local a,s,f=paladin(level);s.friendly=true;s.hostile=false;s.health.target=100
 return a,s,f
end
test('Holy: friendly target, spenders at 3 Holy Power, procs and triage',function()
 local a,s=healer();s.learn(20473,19750,82327,635,82326,85222,85673,114163)
 M.expect(a,s,HOLY,20473,nil,'Holy Shock on cooldown');s.cooling(20473,6)
 M.expect(a,s,HOLY,nil,'stopped','nobody hurt: stop')
 s.health.target=85;M.expect(a,s,HOLY,635,nil,'top off: Holy Light')
 s.health.target=60;M.expect(a,s,HOLY,82326,nil,'big deficit: Divine Light')
 s.health.target=30;M.expect(a,s,HOLY,19750,nil,'emergency: Flash of Light')
 s.health.target=85;s.members(80,70,60);M.expect(a,s,HOLY,82327,nil,'three hurt nearby: Holy Radiance')
 s.resource[HP]=3;M.expect(a,s,HOLY,85222,nil,'3 Holy Power, group hurt: Light of Dawn')
 s.party={};s.group=false;M.expect(a,s,HOLY,114163,nil,'3 Holy Power, one target: Eternal Flame')
 s.buff('target',114163)
 M.expect(a,s,HOLY,85673,nil,'Eternal Flame running: Word of Glory')
 s.resource[HP]=2;s.health.target=60;s.buff('player',54149);M.expect(a,s,HOLY,82326,nil,'Infusion of Light: Divine Light')
 s.clearAuras();s.buff('player',114250,{applications=3});s.health.target=75;M.expect(a,s,HOLY,19750,nil,'three Selfless Healer: Flash of Light')
 s.clearAuras();s.cast=true;M.expect(a,s,HOLY,nil,'stopped','casting')
 local b,t=healer(14);t.learn(20473,19750);t.cooling(20473,6);t.health.target=85;M.expect(b,t,HOLY,19750,nil,'before Holy Light (34): Flash of Light tops off')
end)
test('Holy: an enemy target gets the damage arm',function()
 local a,s=paladin();s.learn(20473,20271,35395,2812)
 M.expect(a,s,HOLY,20473,nil,'Holy Shock');s.cooling(20473,6);M.expect(a,s,HOLY,20271,nil,'Judgment')
 s.cooling(20271,4);s.cooling(35395,3);M.expect(a,s,HOLY,2812,nil,'Denounce')
 s.hostile=false;M.expect(a,s,HOLY,nil,'stopped','no friend, nothing attackable: stop')
end)
test('Holy reminders: Insight, Beacon and Sacred Shield on focus, Divine Plea, cooldowns, Lay on Hands',function()
 local a,s,f=healer();s.learn(20165,53563,20925,54428,31884,31842,86669,633,114158)
 s.form=0;local lit=M.upkeep(a,s,HOLY);assert(lit[20165]and not lit[53563],'Insight; no Beacon without a focus');s.shift(INSIGHT)
 s.focus='party1';f.env.UnitIsFriend=function(_,unit)return unit=='player'or unit=='focus'or unit=='target'end
 lit=M.upkeep(a,s,HOLY);assert(lit[53563]and lit[20925],'Beacon and Sacred Shield on the focus')
 s.mana.player=50;assert(M.upkeep(a,s,HOLY)[54428],'Divine Plea below 60% mana')
 s.members(60,60,60);lit=M.upkeep(a,s,HOLY);assert(lit[31884]and lit[31842]and lit[86669]and lit[114158],'three below 70%: cooldowns and Light\'s Hammer')
 s.health.target=10;assert(M.upkeep(a,s,HOLY)[633],'Lay on Hands on the target')
end)
finish()
