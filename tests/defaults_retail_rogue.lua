-- Retail (Midnight) Rogue premades: specialization slots, the Blizzard Assisted rotations, the
-- disabled guide references and the reminders, through the real catalog, predicates,
-- composition, readiness and sequence executor on a modeled Retail client (probe policy; the last
-- test keeps the real restricted policy). Combo points are read on the player (POINT; a negative
-- value is the deficit from the maximum, here 5).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_b.lua')
local ASSA,ASSAIV='rm.retail.rogue.assassination','rm.retail.rogue.assassination.icyveins'
local OUTLAW,OUTLAWIV='rm.retail.rogue.outlaw','rm.retail.rogue.outlaw.icyveins'
local SUB,SUBIV='rm.retail.rogue.subtlety','rm.retail.rogue.subtlety.icyveins'
local SPECS={[259]={ASSA,ASSAIV},[260]={OUTLAW,OUTLAWIV},[261]={SUB,SUBIV}}
local unpack=unpack or table.unpack
local function rogue()
 local f,s=M.new('rogue');s.powerType=3
 return f.addon,s,f
end
test('every Rogue premade is listed in each slot, Retail only, eligible only in its own specialization',function()
 local a=rogue();M.checkSlots(a,SPECS)
 for _,id in ipairs({ASSAIV,OUTLAWIV,SUBIV})do assert(M.row(a,259,id).envelope.body.disabled==true,id..' reference is not off by default')end
end)
test('Assisted: each specialization follows Blizzard\'s suggestion after the Stops',function()
 local a,s=rogue();s.learn(1329,703,193315,53)
 M.checkAssisted(a,s,259,ASSA,1329);M.checkAssisted(a,s,260,OUTLAW,193315);M.checkAssisted(a,s,261,SUB,53)
 s.suggest=1329;s.hostile=false;local r=M.expect(a,s,259,ASSA,nil,'stopped','no enemy target');assert(r.suppressAttack)
end)
test('reminders: poisons and Stealth between pulls, Vanish out of stealth, Kick, Crimson Vial',function()
 local a,s=rogue();s.learn(2823,315584,3408,1784,1766,185311,1856)
 s.combat=false;local lit=M.upkeep(a,s,259,ASSA);assert(lit[2823]and not lit[315584]and lit[3408]and lit[1784],'Deadly, Crippling, Stealth')
 s.known[2823]=nil;lit=M.upkeep(a,s,260,OUTLAW);assert(lit[315584],'Instant Poison without Deadly')
 s.buff('player',8679);s.buff('player',381637);s.stealthed=true;lit=M.upkeep(a,s,260,OUTLAW);assert(not lit[315584]and not lit[3408]and not lit[1784],'Wound and Atrophic count; already stealthed')
 s.hostile=false;s.stealthed=false;lit=M.upkeep(a,s,260,OUTLAW);assert(not lit[1784],'no Stealth reminder without an enemy target');s.hostile=true
 s.combat=true;lit=M.upkeep(a,s,259,ASSA);assert(lit[1856],'Assassination: Vanish out of stealth');assert(not M.upkeep(a,s,261,SUB)[1856],'Subtlety has no Vanish reminder')
 s.health.player=40;lit=M.upkeep(a,s,261,SUB);assert(not lit[185311],'health is secret: Crimson Vial is yours')
end)
test('Assassination reference: stealth opener, bleeds by timer, spend at 5, AoE builders',function()
 local a,s=rogue();s.learn(703,1943,32645,1329,8676,51723,1247227,441776)
 s.stealthed=true;M.expect(a,s,259,ASSAIV,703,nil,'stealth: Garrote');s.cooling(703,5)
 local r=M.expect(a,s,259,ASSAIV,8676,nil,'then Ambush');s.stealthed=false;s.cooldown={}
 M.expect(a,s,259,ASSAIV,703,nil,'no Garrote: Garrote')
 s.debuff('target',703,{expirationTime=115,duration=18});s.usable[8676]=false;M.expect(a,s,259,ASSAIV,1329,nil,'below 5: Mutilate')
 s.usable[8676]=nil;M.expect(a,s,259,ASSAIV,8676,nil,'Ambush (Blindside) before Mutilate')
 s.points=5;M.expect(a,s,259,ASSAIV,1943,nil,'5 points, no Rupture: Rupture')
 s.debuff('target',1943,{expirationTime=120,duration=24});M.expect(a,s,259,ASSAIV,441776,nil,'Coup de Grace when usable');s.usable[441776]=false
 M.expect(a,s,259,ASSAIV,32645,nil,'Envenom')
 s.clearAuras();s.debuff('target',703,{expirationTime=102,duration=18});s.debuff('target',1943,{expirationTime=120,duration=24})
 M.expect(a,s,259,ASSAIV,32645,nil,'full combo points: no Garrote refresh')
 s.points=2;M.expect(a,s,259,ASSAIV,703,nil,'Garrote in its last 30%')
 s.clearAuras();s.debuff('target',1943,{expirationTime=120,duration=24});s.debuff('target',703,{expirationTime=115,duration=18});s.near(3);M.expect(a,s,259,ASSAIV,1247227,nil,'three engaged: Crimson Tempest')
 s.debuff('target',1247227);M.expect(a,s,259,ASSAIV,51723,nil,'then Fan of Knives')
 s.learn(360194,385627,1856,5938,381623);s.near(0);s.clearAuras();local lit=M.upkeep(a,s,259,ASSAIV);assert(not lit[360194]and lit[1856],'Deathmark waits for bleeds; Vanish with Deathmark ready')
 s.debuff('target',703);s.debuff('target',1943);lit=M.upkeep(a,s,259,ASSAIV);assert(lit[360194]and not lit[385627],'Deathmark with both bleeds; Kingsbane after it')
 s.debuff('target',360194);lit=M.upkeep(a,s,259,ASSAIV);assert(lit[385627],'Kingsbane during Deathmark')
 s.energy=20;s.debuff('target',457129);lit=M.upkeep(a,s,259,ASSAIV);assert(lit[381623]and lit[5938],'Thistle Tea low on energy; Shiv on the Mark')
end)
test('Outlaw reference: stealth Ambush, finish one short of full, Opportunity stacks, cooldown reminders',function()
 local a,s=rogue();s.learn(8676,315341,51690,441776,2098,185763,193315)
 s.stealthed=true;M.expect(a,s,260,OUTLAWIV,8676,nil,'stealth: Ambush');s.stealthed=false
 s.usable[8676]=false;M.expect(a,s,260,OUTLAWIV,193315,nil,'Sinister Strike')
 s.buff('player',195627,{applications=3});M.expect(a,s,260,OUTLAWIV,185763,nil,'three Opportunity at low combo points: Pistol Shot')
 s.points=4;M.expect(a,s,260,OUTLAWIV,315341,nil,'4 of 5: Between the Eyes');s.cooling(315341,20)
 M.expect(a,s,260,OUTLAWIV,51690,nil,'Killing Spree');s.cooling(51690,60);M.expect(a,s,260,OUTLAWIV,441776,nil,'Coup de Grace')
 s.known[441776]=nil;M.expect(a,s,260,OUTLAWIV,2098,nil,'Dispatch');s.points=3;s.clearAuras()
 s.buff('player',195627,{applications=2});M.expect(a,s,260,OUTLAWIV,193315,nil,'two Opportunity: build')
 s.buff('player',386270);s.usable[8676]=nil;M.expect(a,s,260,OUTLAWIV,8676,nil,'Audacity: Ambush')
 s.learn(1214909,13750,13877,271877,1277933);s.cooldown={};s.clearAuras();local lit=M.upkeep(a,s,260,OUTLAWIV)
 assert(lit[1214909]and not lit[13750]and not lit[13877]and lit[271877]and not lit[1277933],'Roll the Bones; Adrenaline Rush waits for low points; one enemy')
 s.points=1;s.buff('player',193356);s.near(2);lit=M.upkeep(a,s,260,OUTLAWIV);assert(not lit[1214909]and lit[13750]and lit[13877],'rolled; low points; two enemies')
 s.cooling(13750,60);s.cooling(315341,20);s.cooling(271877,30);lit=M.upkeep(a,s,260,OUTLAWIV);assert(lit[1277933],'Preparation when all three cool')
end)
test('Subtlety reference: stealth opener, finishers one short of full, builders, Dance reminders',function()
 local a,s=rogue();s.learn(185438,196819,280719,441776,319175,197835,200758,53)
 s.combat=false;s.stealthed=true;local r=M.expect(a,s,261,SUBIV,185438,nil,'opener: Shadowstrike');s.combat=true;s.stealthed=false
 s.usable[185438]=false;M.expect(a,s,261,SUBIV,200758,nil,'Gloomblade');s.known[200758]=nil;M.expect(a,s,261,SUBIV,53,nil,'Backstab')
 s.near(2);M.expect(a,s,261,SUBIV,197835,nil,'two engaged: Shuriken Storm');s.near(0)
 s.points=4;s.usable[441776]=false;M.expect(a,s,261,SUBIV,196819,nil,'4 of 5: Eviscerate')
 s.buff('player',185422);M.expect(a,s,261,SUBIV,280719,nil,'Secret Technique in Shadow Dance');s.clearAuras()
 s.near(3);M.expect(a,s,261,SUBIV,319175,nil,'Black Powder on three');s.near(0)
 s.learn(426591,121471,185313,1856);local lit=M.upkeep(a,s,261,SUBIV);assert(not lit[426591]and lit[121471]and not lit[185313]and not lit[1856],'Shadow Blades with Dance ready; Dance waits at 4 points')
 s.points=1;lit=M.upkeep(a,s,261,SUBIV);assert(lit[185313]and lit[1856],'Dance and Vanish at low points with Secret Technique ready')
 s.buff('player',185422);lit=M.upkeep(a,s,261,SUBIV);assert(lit[426591]and not lit[185313],'Goremaw\'s Bite in Dance')
end)
test('on the real restricted Retail client every Rogue premade is complete and the recommended premade auto-selects',function()
 M.checkRestricted('rogue',SPECS,{1329,193315,53})
end)
test('before a specialization (initial spec 1453) a level-4 Rogue gets the Blizzard Assisted premade, complete',function()
 M.initial('rogue',1453,'rm.retail.rogue.initial',{1752})
end)
finish()
