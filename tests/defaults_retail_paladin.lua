-- Retail (Midnight) Paladin premades: specialization slots, the Blizzard Assisted rotations, the
-- disabled guide references and the reminders, through the real catalog, predicates, composition,
-- readiness and sequence executor on a modeled Retail client (probe policy; the last test keeps the
-- real restricted policy). Holy Power (s.points) is readable in combat, as Blizzard keeps the
-- player's secondary resources never secret in Midnight; the guide references gate on it.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_b.lua')
local RET,RETIV='rm.retail.paladin.retribution','rm.retail.paladin.retribution.icyveins'
local PROT,PROTIV,PROTWH='rm.retail.paladin.protection','rm.retail.paladin.protection.icyveins','rm.retail.paladin.protection.wowhead'
local HOLY='rm.retail.paladin.holy'
local SPECS={[70]={RET,RETIV},[66]={PROT,PROTIV,PROTWH},[65]={HOLY}}
local unpack=unpack or table.unpack
local function paladin()
 local f,s=M.new('paladin');s.ranged(20271,275779,275773,24275,31935,20473,19750,82326,85673,156322,375576)
 return f.addon,s,f
end
local retKit={427453,53385,383328,85256,255937,375576,184575,24275,20271,407480,35395}
local protKit={375576,427453,26573,31935,53600,24275,275779,204019,53595,85673}
test('every Paladin premade is listed in each slot, Retail only, eligible only in its own specialization',function()
 local a,s=paladin();s.learn(255937)
 M.checkSlots(a,SPECS)
 for _,id in ipairs({RETIV,PROTIV,PROTWH})do assert(M.row(a,70,id).envelope.body.disabled==true,id..' reference is not off by default')end
 -- Below 10 the game reports the initial specialization (1451): its premade, never a specialization's.
 s.setLevel(9);assert(M.selected(a,1451)=='rm.retail.paladin.initial','below 10: '..tostring((M.selected(a,1451))))
end)
test('Retribution Assisted: Blizzard\'s suggestion after the cast and no-target Stops',function()
 local a,s=paladin();s.learn(unpack(retKit))
 M.checkAssisted(a,s,70,RET,255937)
 s.suggest=427453;M.expect(a,s,70,RET,427453,nil,'an override suggestion')
 s.hostile=false;local r=M.expect(a,s,70,RET,nil,'stopped','no enemy target');assert(r.suppressAttack);s.hostile=true
 s.suggest=99999;M.expect(a,s,70,RET,nil,'complete','a suggestion you do not know is skipped')
end)
test('Retribution reminders: aura out of combat, Rebuke, defensives',function()
 local a,s=paladin();s.learn(465,96231,633,403876)
 s.combat=false;local lit=M.upkeep(a,s,70,RET);assert(lit[465]and not lit[96231],'aura between pulls')
 s.buff('player',317920);lit=M.upkeep(a,s,70,RET);assert(not lit[465],'any aura of yours counts')
 s.combat=true;lit=M.upkeep(a,s,70,RET);assert(lit[403876]and not lit[633],'Divine Protection whenever it is ready in combat; Lay on Hands is yours')
 s.health.player=10;lit=M.upkeep(a,s,70,RET);assert(not lit[633],'health is secret: no Lay on Hands reminder')
end)
test('Retribution Icy Veins reference: Hammer of Light, free spenders, 5 Holy Power before Wake, Art of War, Hammer of Wrath cap, spenders at 3+, fillers',function()
 local a,s=paladin();s.learn(unpack(retKit));s.points=3
 M.expect(a,s,70,RETIV,427453,nil,'Hammer of Light first');s.usable[427453]=false
 s.buff('player',223819);M.expect(a,s,70,RETIV,383328,nil,'Divine Purpose: free Final Verdict')
 s.near(2);M.expect(a,s,70,RETIV,53385,nil,'Divine Purpose on two enemies: free Divine Storm');s.near(0);s.clearAuras()
 s.points=5;M.expect(a,s,70,RETIV,255937,nil,'5 Holy Power with Wake of Ashes ready: Wake first, as SimulationCraft waits for it')
 s.cooling(255937,20);M.expect(a,s,70,RETIV,383328,nil,'5 Holy Power with Wake cooling: spend before Divine Toll')
 s.secretCooldowns=true;M.expect(a,s,70,RETIV,383328,nil,'cooldown times secret: the Wake test reads the never-secret flags');s.secretCooldowns=false
 s.near(2);M.expect(a,s,70,RETIV,53385,nil,'5 Holy Power on two enemies: Divine Storm');s.near(0)
 s.known[383328]=nil;M.expect(a,s,70,RETIV,85256,nil,'5 Holy Power without Final Verdict: Templar\'s Verdict');s.learn(383328)
 s.points=4;M.expect(a,s,70,RETIV,375576,nil,'4 Holy Power: no spend yet, Divine Toll');s.cooling(375576,40)
 s.buff('player',406086);M.expect(a,s,70,RETIV,184575,nil,'Blade of Justice on Art of War');s.clearAuras()
 s.charges={[24275]=2};M.expect(a,s,70,RETIV,24275,nil,'Hammer of Wrath at two charges');s.charges=nil
 M.expect(a,s,70,RETIV,383328,nil,'then the spender at 3+')
 s.near(2);M.expect(a,s,70,RETIV,53385,nil,'two enemies at 3+: Divine Storm');s.near(0)
 s.known[383328]=nil;M.expect(a,s,70,RETIV,85256,nil,'Templar\'s Verdict without Final Verdict');s.learn(383328)
 s.points=2;M.expect(a,s,70,RETIV,24275,nil,'below 3 Holy Power: no spender, Hammer of Wrath')
 s.near(2);M.expect(a,s,70,RETIV,24275,nil,'two enemies below 3 Holy Power: still no Divine Storm');s.near(0)
 s.buff('player',326733);M.expect(a,s,70,RETIV,53385,nil,'Empyrean Power: a free Divine Storm below 3');s.clearAuras()
 s.cooling(24275,5);M.expect(a,s,70,RETIV,184575,nil,'Blade of Justice');s.cooling(184575,5)
 M.expect(a,s,70,RETIV,20271,nil,'Judgment');s.cooling(20271,5);M.expect(a,s,70,RETIV,407480,nil,'Templar Strike')
 s.known[407480]=nil;M.expect(a,s,70,RETIV,35395,nil,'Crusader Strike')
 s.learn(31884,343527);s.cooldown={};s.cooling(255937,20);local lit=M.upkeep(a,s,70,RETIV);assert(lit[31884]and not lit[343527],'Avenging Wrath; Execution Sentence waits for Wake of Ashes')
 s.cooling(255937,1);lit=M.upkeep(a,s,70,RETIV);assert(lit[343527],'Execution Sentence with Wake of Ashes about ready')
end)
test('Protection Assisted: suggestion, defensives on readiness',function()
 local a,s=paladin();s.learn(unpack(protKit));s.learn(31850,86659)
 M.checkAssisted(a,s,66,PROT,53600)
 local lit=M.upkeep(a,s,66,PROT);assert(lit[31850]and lit[86659],'Ardent Defender and Guardian of Ancient Kings whenever ready in combat (health is secret)')
 s.cooling(31850,60);lit=M.upkeep(a,s,66,PROT);assert(not lit[31850]and lit[86659],'a cooling defensive stays dark')
 s.combat=false;lit=M.upkeep(a,s,66,PROT);assert(not lit[86659],'defensives out of combat')
end)
test('Protection Icy Veins reference: pre-pull Consecration, Consecration upkeep, Vanguard, filler',function()
 local a,s=paladin();s.learn(unpack(protKit))
 s.combat=false;local r=M.expect(a,s,66,PROTIV,26573,nil,'pre-pull Consecration')
 s.cooling(26573,5);r=M.expect(a,s,66,PROTIV,nil,'stopped','nothing else before the pull');assert(not r.suppressAttack);s.cooldown={};s.combat=true
 M.expect(a,s,66,PROTIV,375576,nil,'Divine Toll');s.cooling(375576,30);s.usable[427453]=false
 M.expect(a,s,66,PROTIV,26573,nil,'not standing in Consecration');s.buff('player',188370)
 s.points=3;M.expect(a,s,66,PROTIV,53600,nil,'standing in it, 3 Holy Power: Shield of the Righteous')
 s.buff('player',1268810);M.expect(a,s,66,PROTIV,31935,nil,'Vanguard: Avenger\'s Shield first');s.clearAuras();s.buff('player',188370)
 s.points=2;M.expect(a,s,66,PROTIV,24275,nil,'below 3 Holy Power: no Shield of the Righteous, Hammer of Wrath');s.cooling(24275,5)
 M.expect(a,s,66,PROTIV,275779,nil,'Judgment');s.cooling(275779,5);M.expect(a,s,66,PROTIV,204019,nil,'Blessed Hammer')
 s.cooling(204019,3);s.cooling(53595,3);M.expect(a,s,66,PROTIV,31935,nil,'Avenger\'s Shield');s.cooling(31935,5)
 s.buff('player',327510);M.expect(a,s,66,PROTIV,85673,nil,'Shining Light: Word of Glory');s.clearAuras();s.buff('player',188370)
 M.expect(a,s,66,PROTIV,26573,nil,'Consecration filler')
 s.learn(31884,389539,432472,432459);s.cooldown={};local lit=M.upkeep(a,s,66,PROTIV);assert(lit[31884]and lit[432472]and lit[432459],'cooldowns')
 s.buff('player',31884);lit=M.upkeep(a,s,66,PROTIV);assert(not lit[432472],'Sacred Weapon waits for Avenging Wrath to end')
end)
test('Protection Wowhead reference: Judgment first, Divine Toll only at 0 Holy Power, Consecration last',function()
 local a,s=paladin();s.learn(unpack(protKit));s.points=3
 M.expect(a,s,66,PROTWH,275779,nil,'Judgment');s.cooling(275779,5)
 M.expect(a,s,66,PROTWH,53600,nil,'Shield of the Righteous');s.usable[53600]=false
 M.expect(a,s,66,PROTWH,31935,nil,'Avenger\'s Shield');s.cooling(31935,5)
 M.expect(a,s,66,PROTWH,204019,nil,'Holy Power left: no Divine Toll, Blessed Hammer')
 s.points=1;M.expect(a,s,66,PROTWH,204019,nil,'one Holy Power: still no Divine Toll')
 s.points=0;M.expect(a,s,66,PROTWH,375576,nil,'Divine Toll at 0 Holy Power')
 s.secretCooldowns=true;M.expect(a,s,66,PROTWH,375576,nil,'with cooldown times secret too');s.secretCooldowns=false
 s.cooling(375576,30);s.cooling(204019,3);s.cooling(53595,3)
 M.expect(a,s,66,PROTWH,26573,nil,'Consecration only as the filler')
 s.health.player=40;M.expect(a,s,66,PROTWH,26573,nil,'health is secret: no Word of Glory, Consecration filler')
end)
test('Holy: Holy Power spent at 5 first and at 3+ after the heals, Infusion and Holy Shock, enemy damage list, no target stops',function()
 local a,s=paladin();s.learn(19750,20473,156322,85673,82326,415091,275773,35395,26573)
 s.hostile=false;s.friendly=true;s.points=5
 M.expect(a,s,65,HOLY,156322,nil,'5 Holy Power: Eternal Flame first')
 s.buff('player',54149);M.expect(a,s,65,HOLY,156322,nil,'5 Holy Power: spend before Infusion of Light')
 s.points=2;M.expect(a,s,65,HOLY,19750,nil,'Infusion of Light: Flash of Light');s.clearAuras()
 M.expect(a,s,65,HOLY,20473,nil,'Holy Shock');s.cooling(20473,5)
 M.expect(a,s,65,HOLY,82326,nil,'below 3 Holy Power: no spender, Holy Light')
 s.points=3;M.expect(a,s,65,HOLY,156322,nil,'Eternal Flame at 3');s.known[156322]=nil;M.expect(a,s,65,HOLY,85673,nil,'Word of Glory at 3')
 s.points=5;s.cooldown={};M.expect(a,s,65,HOLY,85673,nil,'Word of Glory at 5 without Eternal Flame');s.cooling(20473,5)
 s.points=3;s.usable[85673]=false;M.expect(a,s,65,HOLY,82326,nil,'Holy Light');s.usable[85673]=nil;s.cooldown={}
 s.cast=true;M.expect(a,s,65,HOLY,nil,'stopped','casting');s.cast=false
 s.friendly=false;s.exists=false;local r=M.expect(a,s,65,HOLY,nil,'stopped','no target');assert(r.suppressAttack);s.exists=true
 s.hostile=true;s.points=5;M.expect(a,s,65,HOLY,415091,nil,'enemy, 5 Holy Power: Shield of the Righteous')
 s.points=3;M.expect(a,s,65,HOLY,20473,nil,'enemy, 3 Holy Power: Holy Shock first');s.cooling(20473,5)
 M.expect(a,s,65,HOLY,415091,nil,'then Shield of the Righteous at 3')
 s.points=2;M.expect(a,s,65,HOLY,275773,nil,'below 3: Judgment');s.cooling(275773,5);M.expect(a,s,65,HOLY,35395,nil,'Crusader Strike')
 s.learn(375576,114165,200025,432459);local lit=M.upkeep(a,s,65,HOLY);assert(lit[375576]and lit[114165]and lit[432459]and not lit[200025],'cooldowns; Beacon of Virtue only on a friend')
 s.combat=false;lit=M.upkeep(a,s,65,HOLY);assert(not lit[375576],'cooldowns wait for combat')
end)
test('on the real restricted Retail client every Paladin premade is complete and the recommended premade auto-selects',function()
 M.checkRestricted('paladin',SPECS,{255937,53600,20473})
end)
test('before a specialization (initial spec 1451) a level-4 Paladin gets the Blizzard Assisted premade, complete',function()
 M.initial('paladin',1451,'rm.retail.paladin.initial',{35395})
end)
test('on the real restricted Retail client Holy Power still reads in combat, so the gates are live',function()
 local f,s=M.new('paladin',{policy='restricted'});local a=f.addon;s.combat=true;s.points=5
 local function point(op,v)return a:evaluateConditionResult({type='POINT',unit='player',operator=op,value=v}).status end
 assert(point('GREATERTHANOREQUALS',5)=='match','5 Holy Power reads as 5')
 s.points=0;assert(point('EQUALS',0)=='match'and point('GREATERTHANOREQUALS',3)=='no-match','0 Holy Power reads as 0')
end)
finish()
