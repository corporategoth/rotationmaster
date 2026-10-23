-- WoW Forever Druid premades: switches, priorities, boundaries and reminders through the real
-- catalog, predicates, composition and sequence executor on a modeled Forever client (probe policy;
-- the last test keeps the real restricted policy).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/forever_premade_model.lua')
local BAL,DOT,FERAL,RESTO,REJUV='rm.forever.druid.balance','rm.forever.druid.balance.tavern','rm.forever.druid.feral','rm.forever.druid.restoration','rm.forever.druid.restoration.icyveins'
local function druid(level)
 local f,s=M.new('druid');local a=f.addon
 s.setLevel(level or 60);s.ranged(5176,8921,2912,5570,770,339,8936,774,5185,18562,408120,1079,1822,5221,1082,6785,22568,16979)
 return a,s,f
end
test('the Druid premades load, validate and declare Forever only',function()
 local a=druid();local rows=M.rows(a)
 for _,id in ipairs({BAL,DOT,FERAL,RESTO,REJUV})do
  local row=assert(rows[id],id);local scope=row.applicability
  assert(row.readOnly and row.builtin and scope.families[1]=='forever'and #scope.families==1 and scope.class=='DRUID'and scope.maxLevel==60,id)
  assert(row.eligible,id..' not eligible on the probe Forever context')
 end
end)
test('switch by talent tree (1 Balance, 2 Feral, 3 Restoration): levels 1-9 and untalented casters get Balance; Feral by tree or form; Restoration in a group',function()
 local a,s=druid(5);s.learn(5176)
 assert(M.selected(a)==BAL,'level 5')
 s.setLevel(14);s.learn(5487);assert(M.selected(a)==BAL,'untalented caster form')
 s.buff('player',5487);assert(M.selected(a)==FERAL,'an untalented Druid in Bear Form gets Feral (the empty tree is a clean no-match)');s.clearAuras()
 s.setTrees({0,3,0});assert(M.selected(a)==FERAL,'Feral main tree in caster form, before any talent spell')
 s.setTrees({3,3,0});assert(M.selected(a)==BAL,'a tie stays Balance');s.buff('player',768);assert(M.selected(a)==FERAL,'a tie in Cat Form: the form decides');s.clearAuras()
 s.setLevel(30);s.setTrees({0,21,0});s.learn(1322605);assert(M.selected(a)==FERAL,'Feral main tree')
 s.setTrees({31,20,0});assert(M.selected(a)==FERAL,'20 Feral points under a Balance main tree: the readable points test (as Feral Charge was)')
 s.config=false;s.setTrees(s.trees);s.buff('player',5487);assert(M.switch(a,FERAL)=='unavailable'and M.selected(a)==BAL,'the points are read first: with no talent config even Bear Form waits (in-game check)');s.clearAuras();s.config=nil;s.setTrees(s.trees)
 s.known[1322605]=nil;s.learn(18562);s.setTrees({0,0,16});assert(M.selected(a)==BAL,'solo Restoration levels as Balance')
 s.group=true;assert(M.selected(a)==RESTO,'grouped Restoration druid heals')
 assert(M.switch(a,REJUV)=='match','Icy Veins Restoration shares the switch')
 s.setTrees({0,0,10});assert(M.selected(a)==BAL,'ten Restoration points: not yet');s.setTrees({0,0,11});assert(M.selected(a)==RESTO,'from 11 points (Gift of the Earthmother)')
 s.setTrees({31,0,20});assert(M.selected(a)==BAL,'a Balance/Restoration hybrid with Swiftmend stays Balance even grouped')
 s.group=false;s.known={};s.setTrees({0,0,0});s.learn(5176);assert(M.selected(a)==BAL,'a character with nothing talented still gets a premade')
 assert(M.switch(a,DOT)=='match','Multi-DoT shares the catch-all switch')
end)
test('Balance: boundaries, pull and moving branches',function()
 local a,s=druid();s.learn(5176,8921,2912,5570,770)
 s.cast=true;M.expect(a,s,BAL,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,BAL,nil,'stopped','channelling');s.channel=false
 s.buff('player',783);M.expect(a,s,BAL,nil,'stopped','travel form');s.clearAuras()
 s.hostile=false;local r=M.expect(a,s,BAL,nil,'stopped','no hostile target');assert(not r.suppressAttack);s.hostile=true
 s.combat=false;M.expect(a,s,BAL,5176,nil,'pull with Wrath');s.combat=true
 s.moving=true;M.expect(a,s,BAL,8921,nil,'moving Moonfire')
 s.debuff('target',8921);M.expect(a,s,BAL,5570,nil,'moving Insect Swarm')
 s.debuff('target',5570);M.expect(a,s,BAL,nil,'stopped','solo: no Faerie Fire while moving')
 s.group=true;M.expect(a,s,BAL,770,nil,'grouped Faerie Fire while moving')
end)
test('Balance: DoTs, Eclipse and Clearcasting Starfire, Wrath, and the early-rank list',function()
 local a,s=druid(3);s.learn(5176)
 M.expect(a,s,BAL,5176,nil,'levels 1-3: Wrath only')
 s.setLevel(60);s.learn(8921,2912,5570,16914)
 M.expect(a,s,BAL,8921,nil,'Moonfire first')
 s.debuff('target',8921,{sourceUnit='party1'});M.expect(a,s,BAL,8921,nil,'another druid\'s Moonfire is not yours')
 s.clearAuras();s.debuff('target',8921);M.expect(a,s,BAL,5570,nil,'Insect Swarm second')
 s.health.target=15;M.expect(a,s,BAL,5176,nil,'no Insect Swarm on a dying target');s.health.target=100
 s.debuff('target',5570);M.expect(a,s,BAL,5176,nil,'Wrath fills without Eclipse')
 s.buff('player',408255);M.expect(a,s,BAL,2912,nil,'Starfire on Eclipse charges')
 s.clearAuras();s.debuff('target',8921);s.debuff('target',5570);s.buff('player',16870);M.expect(a,s,BAL,2912,nil,'Starfire on Clearcasting')
 s.clearAuras();s.debuff('target',8921);s.debuff('target',5570)
 s.mana.player=5;s.usable[5176]=false;local r=M.expect(a,s,BAL,nil,'complete','out of mana: melee allowed');assert(not r.suppressAttack)
 s.mana.player=50;r=M.expect(a,s,BAL,nil,'stopped','spells unusable with mana left');assert(r.suppressAttack)
end)
test('Balance: Hurricane on three enemies near you, single target otherwise',function()
 local a,s=druid();s.learn(5176,8921,16914)
 s.near(3);M.expect(a,s,BAL,16914,nil,'Hurricane at 3')
 s.near(2);M.expect(a,s,BAL,8921,nil,'two enemies stay single target')
 s.near(3);s.known[16914]=nil;M.expect(a,s,BAL,8921,nil,'before Hurricane AoE falls through to DoTs')
 s.learn(16914);for _,entry in ipairs(s.enemies)do entry.threat=nil end;M.expect(a,s,BAL,8921,nil,'enemies not engaged with you are not counted')
end)
test('Balance reminders: Mark, solo Thorns, Moonkin, Nature\'s Grasp, Innervate',function()
 local a,s=druid();s.learn(1126,467,24858,16689,29166,774)
 s.combat=false;local lit=M.upkeep(a,s,BAL)
 assert(lit[1126]and lit[467]and lit[24858]and lit[774],'out of combat upkeep')
 s.buff('player',21849);s.group=true;lit=M.upkeep(a,s,BAL);assert(not lit[1126]and not lit[467]and not lit[774],'Gift covers Mark; Thorns and pre-pull Rejuvenation are solo only')
 s.clearAuras();s.group=false;s.combat=true;s.mana.player=20;lit=M.upkeep(a,s,BAL)
 assert(lit[16689]and lit[29166]and not lit[1126],'Nature\'s Grasp when the mob is on you, Innervate low on mana')
 s.buff('player',24858);s.targetTarget='party1';lit=M.upkeep(a,s,BAL);assert(not lit[24858]and not lit[16689],'Moonkin up; mob not on you')
end)
test('Multi-DoT variant: DoTs, Entangling Roots with another enemy near, Wrath',function()
 local a,s=druid();s.learn(5176,8921,5570,339)
 M.expect(a,s,DOT,8921);s.debuff('target',8921);M.expect(a,s,DOT,5570);s.debuff('target',5570)
 M.expect(a,s,DOT,5176,nil,'alone: Wrath');s.near(2);M.expect(a,s,DOT,339,nil,'root with a second enemy')
 s.debuff('target',339,{sourceUnit='party1'});M.expect(a,s,DOT,5176,nil,'already rooted')
end)
test('Feral: caster form shifts, Cat opener, finishers, builders and pooling',function()
 local a,s=druid();s.learn(768,5487,1082,5221,1079,1822,22568,6785,1322605,770,8936)
 M.expect(a,s,FERAL,768,nil,'humanoid: Cat Form');s.known[768]=nil;M.expect(a,s,FERAL,5487,nil,'Bear before Cat is known');s.known[768]=true
 s.combat=false;s.health.player=40;M.expect(a,s,FERAL,8936,nil,'heal out of combat before shifting');s.combat=true;s.health.player=100
 s.buff('player',768);s.powerType=3;s.energy=80
 s.stealthed=true;local r=M.expect(a,s,FERAL,6785,'selected','Ravage from Prowl')
 s.known[6785]=nil;M.expect(a,s,FERAL,5221,nil,'Shred before Ravage');s.known[6785]=true;s.stealthed=false
 M.expect(a,s,FERAL,1822,nil,'Rake when missing (target on me, so no Faerie Fire solo)')
 s.group=true;M.expect(a,s,FERAL,770,nil,'Faerie Fire in a group');s.debuff('target',770,{sourceUnit='party1'});s.group=false
 s.energy=50;M.expect(a,s,FERAL,1322605,nil,'Shifting Power at 60 energy or less');s.mana.player=10;M.expect(a,s,FERAL,1822,nil,'mana floor');s.mana.player=100;s.energy=80
 s.debuff('target',1822);M.expect(a,s,FERAL,1082,nil,'Claw when the target faces you')
 s.targetTarget='party1';M.expect(a,s,FERAL,5221,nil,'Shred from behind');s.targetTarget='player'
 s.points=4;M.expect(a,s,FERAL,1079,nil,'Rip at four points');s.health.target=20;M.expect(a,s,FERAL,22568,nil,'Bite on a dying target');s.health.target=100
 s.debuff('target',1079);M.expect(a,s,FERAL,22568,nil,'Bite once Rip runs')
 s.buff('player',16870);M.expect(a,s,FERAL,1082,nil,'Clearcasting is kept for a builder')
 s.points=0;s.usable[1082]=false;r=M.expect(a,s,FERAL,nil,'stopped','pooling keeps auto attack');assert(not r.suppressAttack)
end)
test('Feral: Bear range pull, Demoralizing Roar, Primal Bite, AoE Swipe, Lacerate filler',function()
 local a,s=druid();s.learn(5487,9634,770,16979,99,407995,779,414644,6807,5229)
 s.buff('player',9634);s.powerType=1;s.energy=40
 s.targetRange={8,25};M.expect(a,s,FERAL,770,nil,'Faerie Fire at range')
 s.debuff('target',770,{sourceUnit='party1'});local r=M.expect(a,s,FERAL,16979,nil,'Feral Charge at range')
 s.targetRange={0,5};M.expect(a,s,FERAL,407995,nil,'solo single target: Primal Bite, no Roar')
 s.near(2);M.expect(a,s,FERAL,99,nil,'Demoralizing Roar on two enemies')
 s.debuff('target',1160,{sourceUnit='party1'});M.expect(a,s,FERAL,407995,nil,'Demoralizing Shout already up')
 s.cooling(407995,4);s.near(3);M.expect(a,s,FERAL,779,nil,'Swipe on three')
 s.near(0);M.expect(a,s,FERAL,414644,nil,'Lacerate filler');s.known[414644]=nil;M.expect(a,s,FERAL,779,nil,'Swipe before Lacerate')
 s.energy=60;local lit=M.upkeep(a,s,FERAL);assert(lit[6807]and not lit[5229],'Maul with spare rage')
 s.current[6807]=true;lit=M.upkeep(a,s,FERAL);assert(not lit[6807],'Maul already queued');s.current[6807]=nil
 s.energy=10;lit=M.upkeep(a,s,FERAL);assert(lit[5229]and not lit[6807],'Enrage when low on rage')
end)
test('Restoration: heals the friendly target in order; damage on a hostile target',function()
 local a,s=druid();s.learn(18562,408120,8936,774,5185,5176,8921)
 s.members(100,100,100);s.hostile=false;s.friendly=true;s.health.target=90
 M.expect(a,s,RESTO,774,nil,'Rejuvenation on a lightly hurt target')
 s.health.target=50;M.expect(a,s,RESTO,8936,nil,'Regrowth below 60%')
 s.buff('target',774);M.expect(a,s,RESTO,18562,nil,'Swiftmend on a HoT target below 70%')
 s.cooling(18562,10);s.buff('target',8936);s.health.target=40;M.expect(a,s,RESTO,5185,nil,'Healing Touch below 50%')
 s.health.target=96;local r=M.expect(a,s,RESTO,nil,'stopped','nothing to heal')
 s.members(50,60,70);M.expect(a,s,RESTO,408120,nil,'Wild Growth with three allies hurt')
 s.friendly=false;s.hostile=true;M.expect(a,s,RESTO,8921,nil,'hostile target: Moonfire')
 s.friendly=false;s.hostile=false;r=M.expect(a,s,RESTO,nil,'stopped','no usable target');assert(r.suppressAttack)
end)
test('Icy Veins Restoration: HoTs first, Healing Touch only with both HoTs, Innervate on cooldown',function()
 local a,s=druid();s.learn(18562,8936,774,5185,29166)
 s.members(100,100,100);s.hostile=false;s.friendly=true;s.health.target=40
 M.expect(a,s,REJUV,774,nil,'Rejuvenation first even when low');s.buff('target',774)
 M.expect(a,s,REJUV,8936,nil,'then Regrowth');s.buff('target',8936)
 M.expect(a,s,REJUV,5185,nil,'Healing Touch with both HoTs')
 s.mana.player=90;assert(M.upkeep(a,s,REJUV)[29166],'Innervate on cooldown');assert(not M.upkeep(a,s,RESTO)[29166],'Tavern saves Innervate')
end)
test('on the real restricted Forever client the Druid premades are listed but never auto-selected',function()
 local f,s=M.new('druid',{policy='restricted'});local a=f.addon;s.learn(5176);s.buff('player',768)
 local rows=M.rows(a)
 for _,id in ipairs({BAL,DOT,FERAL,RESTO,REJUV})do
  assert(rows[id]and rows[id].readOnly,id..' not listed');assert(not rows[id].eligible,id..' became eligible')
  assert(rows[id].eligibilityReason=='restricted-or-unsupported-client',id..' '..tostring(rows[id].eligibilityReason))
 end
 assert(a.Platform:GetClientInfo().combatDataPolicy=='restricted'and next(a:GetRuntimeRotations(0))==nil and M.selected(a)==nil,'a restricted client auto-selected a packaged rotation')
end)
finish()
