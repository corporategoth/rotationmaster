-- Mists of Pandaria Classic Druid premades: switches, priorities, boundaries and reminders through the
-- real catalog, predicates, composition and sequence executor on a modeled 5.5.4 client. Forms are
-- read by spell (FORM form; s.shift), never by stance-bar slot; combo points through POINT (UnitPower
-- type 4 on the player). Clearing the auras also leaves any form.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/mop_premade_model_a.lua')
local NONE,BAL,FER,FIV,GUA,RES,RST='rm.mop.druid.unspecialized','rm.mop.druid.balance','rm.mop.druid.feral','rm.mop.druid.feral.icyveins',
 'rm.mop.druid.guardian','rm.mop.druid.restoration','rm.mop.druid.restoration.wowhead'
local CAT,BEAR,TRAVEL,MOONKIN=768,5487,783,24858
local SOLAR,LUNAR,CA=48517,48518,112071
local function druid(level)
 local f,s=M.new('druid');local a=f.addon
 s.setLevel(level or 90);s.targetRange={28,30}
 s.ranged(5176,8921,2912,93402,78674,16914,106996,770,5185,774,8936,50464,18562,48438,33763)
 local clear=s.clearAuras;s.clearAuras=function()clear();s.form=0 end
 return a,s,f
end
local function cat(s,energy,points)s.clearAuras();s.shift(CAT);s.powerType=3;s.energy=energy or 60;s.resource[4]=points or 0;s.targetRange={0,5}end
local function bear(s,rage)s.clearAuras();s.shift(BEAR);s.powerType=1;s.energy=rage or 30;s.targetRange={0,5}end
local function caster(s)s.powerType=0;s.energy=0 end

test('the Druid premades load, validate and declare Mists only',function()
 M.scope('druid',{NONE},1);M.scope('druid',{BAL,FER,GUA,RES},10)
 local a=druid();local rows=M.rows(a)
 for _,id in ipairs({FIV,RST})do
  local row=assert(rows[id],id);local scope=row.applicability
  assert(row.readOnly and row.envelope.body.disabled and scope.minExpansion==4 and scope.maxExpansion==4 and scope.minLevel==10 and scope.maxLevel==90,id)
  assert(a:GetDefaultRotationComposition(id),id..' uses the shared Druid blocks')
 end
end)
test('switch: unspecialized until a specialization; Balance, Feral, Guardian, Restoration by ID; variants share it',function()
 local a,s=druid(1);s.learn(5176);assert(M.selected(a)==NONE,'level 1')
 s.specID(103);assert(M.selected(a)==NONE and M.switch(a,FER)=='no-match','levels 1-9 stay in the catch-all');s.spec=nil
 s.setLevel(10);s.learn(2912,5217,62606,18562);assert(M.selected(a)==NONE,'level 10 without a specialization')
 for _,case in ipairs({{102,BAL},{103,FER},{104,GUA},{105,RES}})do
  s.specID(case[1]);assert(M.selected(a)==case[2],case[2]);s.setLevel(90);assert(M.selected(a)==case[2],case[2]..' at 90');s.setLevel(10)
 end
 s.specID(103);assert(M.switch(a,GUA)=='no-match','Feral is not Guardian on Mists (one tree on talent-tree clients)')
 assert(M.switch(a,FIV)==M.switch(a,FER),'Icy Veins Feral shares the Feral switch')
 assert(M.switch(a,FIV)=='match'and M.selected(a)==FER,'disabled variant never auto-selects')
 assert(a:SetDefaultRotationEnabled(FIV,true)and a:SetDefaultRotationEnabled(FER,false));assert(M.selected(a)==FIV,'enable the variant, disable Feral')
 s.specID(105);assert(M.switch(a,RST)=='match'and M.selected(a)==RES)
 s.known={};s.spec=nil;assert(M.selected(a)==NONE,'a druid with nothing learned still gets a premade')
end)
test('unspecialized: boundaries, caster pull and filler, Cat and Bear arms',function()
 local a,s=druid(8);s.learn(5176,8921,774,1822,33917,22568,6807);caster(s)
 s.cast=true;M.expect(a,s,NONE,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,NONE,nil,'stopped','channelling');s.channel=false
 s.shift(TRAVEL);M.expect(a,s,NONE,nil,'stopped','travel form');s.clearAuras()
 s.hostile=false;M.expect(a,s,NONE,nil,'stopped','no attackable target');s.hostile=true
 s.combat=false;M.expect(a,s,NONE,5176,nil,'pull: Wrath');s.moving=true;M.expect(a,s,NONE,8921,nil,'pull moving: Moonfire');s.moving=false;s.combat=true
 s.debuff('target',8921);M.expect(a,s,NONE,5176,nil,'Wrath filler')
 s.health.player=40;M.expect(a,s,NONE,774,nil,'solo and hurt: Rejuvenation');s.health.player=100
 cat(s,60,0);M.expect(a,s,NONE,1822,nil,'cat: Rake');s.debuff('target',1822);M.expect(a,s,NONE,33917,nil,'cat: Mangle');s.clearAuras();s.shift(CAT)
 s.health.target=20;M.expect(a,s,NONE,33917,nil,'cat: no Rake on a dying normal mob');s.health.target=100
 s.debuff('target',1822);s.resource[4]=5;M.expect(a,s,NONE,22568,nil,'cat: five points Bite')
 s.resource[4]=2;s.health.target=20;M.expect(a,s,NONE,22568,nil,'cat: two points on a dying target');s.health.target=100
 bear(s,40);M.expect(a,s,NONE,33917,nil,'bear: Mangle');s.cooling(33917,4);M.expect(a,s,NONE,6807,nil,'bear: Maul')
 s.energy=10;local r=M.expect(a,s,NONE,nil,'stopped','bear: nothing to press keeps auto attack');assert(not r.suppressAttack)
end)
test('Balance: pull, boundaries, DoTs, Starsurge, Eclipse filler and the direction proxy',function()
 local a,s=druid(10);s.learn(5176,8921,2912);caster(s)
 s.combat=false;M.expect(a,s,BAL,5176,nil,'pull: Wrath');s.combat=true
 M.expect(a,s,BAL,8921,nil,'Moonfire first');s.debuff('target',8921,{expirationTime=120})
 M.expect(a,s,BAL,5176,nil,'no Eclipse, no recent Starfire: Wrath')
 s.history(2912,2);M.expect(a,s,BAL,2912,nil,'Starfire among the last casts: keep heading to Solar');a.spellHistory={}
 s.shift(CAT);local r=M.expect(a,s,BAL,nil,'stopped','in Cat Form');assert(not r.suppressAttack);s.clearAuras()
 s.setLevel(90);s.learn(78674,93402,48505,16914,106996,127663);s.debuff('target',8921,{expirationTime=120})
 M.expect(a,s,BAL,93402,nil,'Sunfire missing');s.debuff('target',93402,{expirationTime=120})
 M.expect(a,s,BAL,78674,nil,'Starsurge on cooldown');s.cooling(78674,10)
 s.clearAuras();s.debuff('target',8921,{expirationTime=120});s.debuff('target',93402,{expirationTime=120})
 s.buff('player',LUNAR);M.expect(a,s,BAL,48505,nil,'Lunar: Starfall');s.buff('player',48505);M.expect(a,s,BAL,2912,nil,'Lunar: Starfire')
 s.clearAuras();s.debuff('target',8921,{expirationTime=120});s.debuff('target',93402,{expirationTime=120})
 s.buff('player',SOLAR);M.expect(a,s,BAL,5176,nil,'Solar: Wrath')
 s.buff('player',16886);s.clearAuras();s.buff('player',SOLAR);s.buff('player',16886);s.debuff('target',8921,{expirationTime=120});s.debuff('target',93402,{expirationTime=104})
 M.expect(a,s,BAL,93402,nil,'Solar with Nature\'s Grace: refresh Sunfire under 6 s')
 s.clearAuras();s.debuff('target',8921,{expirationTime=120});s.debuff('target',93402,{expirationTime=120});s.buff('player',CA)
 M.expect(a,s,BAL,48505,nil,'Celestial Alignment: Starfall');s.buff('player',48505);M.expect(a,s,BAL,2912,nil,'Celestial Alignment: Starfire')
end)
test('Balance: AoE by Eclipse, moving, Soul of the Forest and Dream of Cenarius talents',function()
 local a,s=druid();s.learn(5176,8921,2912,78674,93402,16914,106996,127663,5185);caster(s);s.cooling(78674,10)
 local function dots()s.debuff('target',8921,{expirationTime=120});s.debuff('target',93402,{expirationTime=120})end
 dots();s.near(5);s.buff('player',SOLAR);M.expect(a,s,BAL,16914,nil,'five, Solar: Hurricane')
 s.clearAuras();dots();s.buff('player',LUNAR);s.buff('player',48505);M.expect(a,s,BAL,106996,nil,'five, Lunar: Astral Storm')
 s.near(4);M.expect(a,s,BAL,2912,nil,'four: single target');s.near(0)
 s.clearAuras();dots();s.moving=true;M.expect(a,s,BAL,8921,nil,'moving: Moonfire outside Solar')
 s.buff('player',SOLAR);M.expect(a,s,BAL,93402,nil,'moving in Solar: Sunfire');s.moving=false
 s.clearAuras();dots();s.talents[10]=true;s.buff('player',145138);M.expect(a,s,BAL,127663,nil,'Astral Insight: Astral Communion')
 s.clearAuras();dots();s.talents={[17]=true};M.expect(a,s,BAL,5185,nil,'Dream of Cenarius missing: Healing Touch')
 s.buff('player',CA);M.expect(a,s,BAL,2912,nil,'no Dream Healing Touch in Celestial Alignment')
end)
test('Balance reminders: Mark, Moonkin Form, Eclipse cooldowns, Innervate, Solar Beam',function()
 local a,s=druid();s.learn(1126,24858,112071,102560,29166,78675,22812,124974,132158);caster(s)
 s.combat=false;local lit=M.upkeep(a,s,BAL);assert(lit[1126]and lit[24858],'Mark and Moonkin out of combat')
 s.buff('player',20217);s.shift(MOONKIN);lit=M.upkeep(a,s,BAL);assert(not lit[1126]and not lit[24858],'Kings counts, form kept')
 s.combat=true;s.classification='worldboss';lit=M.upkeep(a,s,BAL);assert(lit[CA]and not lit[102560],'no Eclipse, no talent: Celestial Alignment')
 s.buff('player',LUNAR);lit=M.upkeep(a,s,BAL);assert(lit[102560]and not lit[CA],'Eclipse: Incarnation')
 s.classification='normal';lit=M.upkeep(a,s,BAL);assert(not lit[102560],'a trash mob without a death forecast')
 s.mana.player=50;lit=M.upkeep(a,s,BAL);assert(lit[29166],'Innervate under 70%')
 lit=M.upkeep(a,s,BAL);assert(not lit[78675],'no cast to interrupt')
end)
test('Feral: forms, pull, Savage Roar, Healing Touch, execute Bite, Rip, Bite when safe, Rake, Thrash, Shred, Mangle',function()
 local a,s=druid(90);s.learn(5217,768,1822,33917,22568,5215,6785,5221,52610,1079,106832,106785,5185,770,33745,6807)
 caster(s);M.expect(a,s,FER,768,nil,'not in Cat: Cat Form')
 s.shift(TRAVEL);M.expect(a,s,FER,nil,'stopped','travel form');s.clearAuras()
 cat(s,60,0);s.combat=false
 M.expect(a,s,FER,52610,nil,'pull: Savage Roar (glyphed)');s.usable[52610]=false
 M.expect(a,s,FER,5215,nil,'pull: Prowl');s.stealthed=true;M.expect(a,s,FER,6785,nil,'stealthed: Ravage');s.stealthed=false;s.usable[52610]=nil
 s.combat=true;s.resource[4]=1;M.expect(a,s,FER,52610,nil,'Savage Roar missing')
 s.buff('player',52610,{expirationTime=102});M.expect(a,s,FER,52610,nil,'Savage Roar under 3 s')
 s.clearAuras();s.shift(CAT);s.buff('player',127538,{expirationTime=130});s.resource[4]=0
 M.expect(a,s,FER,1822,nil,'Rake once Roar is up');s.debuff('target',1822,{expirationTime=120})
 M.expect(a,s,FER,33917,nil,'Mangle builds');s.targetTarget='party1';s.buff('player',135700)
 M.expect(a,s,FER,106832,nil,'Clearcasting: Thrash');s.debuff('target',106830,{expirationTime=120});M.expect(a,s,FER,5221,nil,'Clearcasting, not tanked: Shred')
 s.targetTarget='player';M.expect(a,s,FER,33917,nil,'tanked: Mangle, never Shred')
 s.auras.player.HELPFUL[2]=nil;s.resource[4]=5;M.expect(a,s,FER,1079,nil,'five points: Rip')
 s.debuff('target',1079,{expirationTime=110});s.buff('player',127538,{expirationTime=110});M.expect(a,s,FER,22568,nil,'Rip and Roar safe: Bite')
 s.clearAuras();s.shift(CAT);s.buff('player',127538,{expirationTime=104});s.debuff('target',1822,{expirationTime=120});s.debuff('target',1079,{expirationTime=110})
 M.expect(a,s,FER,nil,'complete','Roar short: no Bite; five points and no cap pools energy')
 s.energy=95;M.expect(a,s,FER,33917,nil,'about to cap: Mangle');s.energy=60
 s.health.target=20;M.expect(a,s,FER,22568,nil,'execute with Rip: Bite')
 s.resource[4]=1;s.clearAuras();s.shift(CAT);s.buff('player',127538,{expirationTime=130});s.debuff('target',1822,{expirationTime=120});s.debuff('target',1079,{expirationTime=101})
 M.expect(a,s,FER,22568,nil,'execute, Rip about to drop: Bite refreshes it');s.health.target=100
 s.resource[4]=4;s.buff('player',69369);s.talents[17]=true;M.expect(a,s,FER,5185,nil,'Predatory Swiftness at four points: Healing Touch for Dream of Cenarius')
 s.talents={};M.expect(a,s,FER,33917,nil,'without Dream of Cenarius no Healing Touch at full health')
 s.health.player=40;M.expect(a,s,FER,5185,nil,'below half health: Healing Touch');s.health.player=100
 bear(s,70);s.debuff('target',77758);M.expect(a,s,FER,33917,nil,'Bear arm: Mangle');s.cooling(33917,4);M.expect(a,s,FER,33745,nil,'Bear arm: Lacerate')
end)
test('Feral: AoE at four, Rake before Rip is learned, early leveling Bite',function()
 local a,s=druid(14);s.learn(5217,768,1822,33917,22568,106832,106785);cat(s,60,5)
 s.debuff('target',1822,{expirationTime=120});M.expect(a,s,FER,22568,nil,'before Rip: five-point Bite')
 s.setLevel(90);s.learn(1079,52610);s.buff('player',52610,{expirationTime=130});s.resource[4]=0
 s.near(4);M.expect(a,s,FER,106832,nil,'four: Thrash');s.debuff('target',106830,{expirationTime=120});M.expect(a,s,FER,106785,nil,'four: Swipe')
 s.energy=0;s.power[106785]=true;local r=M.expect(a,s,FER,nil,'stopped','four, no energy: pool with auto attack');assert(not r.suppressAttack)
 s.near(3);s.power[106785]=nil;s.energy=60;s.clearAuras();s.shift(CAT);s.buff('player',52610,{expirationTime=130});s.debuff('target',1822,{expirationTime=120});s.debuff('target',1079,{expirationTime=120})
 M.expect(a,s,FER,106832,nil,'three: single-target list, Thrash with two or more enemies')
end)
test('Icy Veins Feral: no Bite above 25%, execute Bite, Thrash only on Clearcasting',function()
 local a,s=druid(90);s.learn(5217,768,1822,33917,22568,5221,52610,1079,106832,106785);cat(s,60,5)
 s.buff('player',52610,{expirationTime=130});s.debuff('target',1822,{expirationTime=120});s.debuff('target',1079,{expirationTime=115})
 M.expect(a,s,FIV,nil,'complete','five points, Rip safe: no Bite above 25%, pool')
 s.resource[4]=3;M.expect(a,s,FIV,33917,nil,'under five points: Mangle');s.resource[4]=5
 s.near(2);M.expect(a,s,FIV,nil,'complete','two enemies: no Thrash without Clearcasting');s.near(0)
 s.health.target=20;M.expect(a,s,FIV,22568,nil,'execute: Bite');s.health.target=100
 s.clearAuras();s.shift(CAT);s.buff('player',52610,{expirationTime=130});s.debuff('target',1079,{expirationTime=115})
 s.debuff('target',1822,{expirationTime=102});s.resource[4]=0;M.expect(a,s,FIV,1822,nil,'Rake at two seconds')
end)
test('Feral reminders: Tiger\'s Fury, Berserk with it, Incarnation, interrupts and defensives',function()
 local a,s=druid(90);s.learn(5217,106952,102543,106839,61336,22812,1126,124974);cat(s,30,0)
 local lit=M.upkeep(a,s,FER);assert(lit[5217]and not lit[106952],'Tiger\'s Fury under 35 energy')
 s.buff('player',5217);s.classification='worldboss';lit=M.upkeep(a,s,FER);assert(lit[106952]and lit[124974],'Berserk and Vigil with Tiger\'s Fury')
 s.buff('player',106951);lit=M.upkeep(a,s,FER);assert(not lit[5217]and lit[102543],'no Tiger\'s Fury in Berserk; Incarnation with it')
 lit=M.upkeep(a,s,FIV);assert(not lit[106952],'Icy Veins: Berserk at 90 energy away from Tiger\'s Fury only')
 s.health.player=30;lit=M.upkeep(a,s,FER);assert(lit[61336]and lit[22812],'defensives when low')
 s.health.player=100;s.auras.player.HELPFUL={};s.bar={BEAR,TRAVEL,CAT};s.form=3;assert(M.upkeep(a,s,FER)[5217],'Cat Form learned third is still Cat Form')
 s.form=1;assert(not M.upkeep(a,s,FER)[5217],'no Tiger\'s Fury in Bear Form');s.bar[1]=CAT;assert(M.upkeep(a,s,FER)[5217],'Cat Form in slot 1')
 s.combat=false;s.health.player=100;lit=M.upkeep(a,s,FER);assert(lit[1126],'Mark between pulls')
end)
test('Guardian: Bear Form, pull, Weakened Blows and Armor, Mangle, AoE, fillers, Heart of the Wild cat arm',function()
 local a,s=druid(90);s.learn(62606,5487,33917,6807,106832,106785,770,33745,5185,1822,1079,22568);s.ranged(770)
 caster(s);M.expect(a,s,GUA,5487,nil,'Bear Form');bear(s,20);s.targetRange={28,30};s.combat=false
 M.expect(a,s,GUA,770,nil,'ranged pull: Faerie Fire');s.targetRange={0,5};M.expect(a,s,GUA,33917,nil,'melee pull: Mangle');s.combat=true
 M.expect(a,s,GUA,106832,nil,'Weakened Blows missing: Thrash');s.debuff('target',115798,{sourceUnit='party1'})
 s.classification='elite';M.expect(a,s,GUA,770,nil,'elite without Weakened Armor: Faerie Fire');s.debuff('target',113746,{sourceUnit='party1'})
 M.expect(a,s,GUA,33917,nil,'Mangle');s.cooling(33917,4)
 M.expect(a,s,GUA,106832,nil,'own Thrash bleed missing');s.debuff('target',77758);M.expect(a,s,GUA,33745,nil,'Lacerate')
 s.near(3);M.expect(a,s,GUA,106832,nil,'three: Thrash');s.cooling(106832,4);M.expect(a,s,GUA,106785,nil,'three: Swipe');s.near(0)
 s.health.player=60;s.buff('player',145162);M.expect(a,s,GUA,5185,nil,'Dream of Cenarius proc when hurt: Healing Touch')
 cat(s,60,5);s.cooldown={};M.expect(a,s,GUA,1822,nil,'Cat arm: Rake');s.debuff('target',1822);M.expect(a,s,GUA,1079,nil,'Cat arm: Rip')
 s.hostile=false;M.expect(a,s,GUA,nil,'stopped','no attackable target')
end)
test('Guardian reminders: Savage Defense, Enrage, Frenzied Regeneration, Maul, Barkskin, Berserk',function()
 local a,s=druid(90);s.learn(62606,5229,22842,6807,22812,106952,61336,106839);bear(s,60)
 local lit=M.upkeep(a,s,GUA);assert(lit[62606]and not lit[5229]and lit[22812],'Savage Defense down, tanked: Barkskin')
 s.buff('player',132402);lit=M.upkeep(a,s,GUA);assert(not lit[62606]and not lit[6807],'covered, no Tooth and Claw')
 s.buff('player',135286);lit=M.upkeep(a,s,GUA);assert(lit[6807],'Tooth and Claw with Savage Defense up: Maul')
 s.clearAuras();s.shift(BEAR);s.energy=20;lit=M.upkeep(a,s,GUA);assert(lit[5229],'low rage, no Savage Defense: Enrage')
 s.energy=95;s.health.player=60;lit=M.upkeep(a,s,GUA);assert(lit[22842]and lit[6807],'capped and hurt: Frenzied Regeneration and Maul')
 s.near(2);lit=M.upkeep(a,s,GUA);assert(lit[106952],'cleave: Berserk')
end)
test('Restoration: soloing damage, heals on the friendly target, Swiftmend, Wild Growth, Regrowth, Rejuvenation',function()
 local a,s=druid(90);s.learn(18562,774,50464,8936,5185,33763,48438,8921,5176,88423);caster(s)
 M.expect(a,s,RES,8921,nil,'attackable target: Moonfire');s.debuff('target',8921);M.expect(a,s,RES,5176,nil,'then Wrath')
 s.shift(CAT);local r=M.expect(a,s,RES,nil,'stopped','Cat Form: no advice, attack kept');assert(not r.suppressAttack);s.clearAuras()
 s.hostile=false;s.friendly=true;s.health.target=100;M.expect(a,s,RES,nil,'stopped','healthy friend: nothing')
 s.health.target=90;M.expect(a,s,RES,774,nil,'Rejuvenation');s.buff('target',774)
 M.expect(a,s,RES,18562,nil,'HoT and no Harmony: Swiftmend');s.buff('player',100977)
 M.expect(a,s,RES,nil,'stopped','90% with a HoT: nothing more');s.health.target=80;M.expect(a,s,RES,50464,nil,'top off: Nourish');s.health.target=40;M.expect(a,s,RES,18562,nil,'below 60%: Swiftmend');s.cooling(18562,10)
 M.expect(a,s,RES,5185,nil,'below 50%: Healing Touch');s.moving=true;M.expect(a,s,RES,nil,'stopped','moving: no cast heals')
 s.moving=false;s.buff('player',16870);s.health.target=80;M.expect(a,s,RES,8936,nil,'Clearcasting: Regrowth')
 s.members(50,60,70);M.expect(a,s,RES,48438,nil,'three hurt: Wild Growth')
 s.cast=true;M.expect(a,s,RES,nil,'stopped','casting');s.cast=false
end)
test('Restoration reminders and the tank-healing variant',function()
 local a,s,f=druid(90);s.learn(18562,774,50464,8936,5185,33763,102342,29166,88423,132158);caster(s)
 local friend=f.env.UnitIsFriend;f.env.UnitIsFriend=function(x,unit)if unit=='focus'then return s.focus~=nil end;return friend(x,unit)end
 s.auras.focus={HELPFUL={},HARMFUL={}}
 s.focus='party1';s.members(100);local lit=M.upkeep(a,s,RES);assert(lit[33763],'Lifebloom on the focus tank')
 s.hostile=false;s.friendly=true;s.health.target=30;lit=M.upkeep(a,s,RES);assert(lit[132158],'Nature\'s Swiftness on a dying friend')
 s.mana.player=50;lit=M.upkeep(a,s,RES);assert(lit[29166],'Innervate under 80%')
 assert(a:SetDefaultRotationEnabled(RST,true))
 s.focus=nil;s.health.target=95;M.expect(a,s,RST,33763,nil,'tank healing: Lifebloom on the targeted tank')
 s.buff('target',33763,{applications=3,expirationTime=120});M.expect(a,s,RST,774,nil,'Rejuvenation kept up')
 s.buff('target',774);s.health.target=55;M.expect(a,s,RST,8936,nil,'heavy damage: Regrowth');s.usable[8936]=false
 M.expect(a,s,RST,50464,nil,'light: Nourish');s.health.target=40;M.expect(a,s,RST,5185,nil,'Lifebloom and Rejuvenation rolling, below 50%: Healing Touch')
end)
finish()
