-- Retail (Midnight) Warlock premades: specialization slots, the Blizzard Assisted rotations, the
-- disabled guide references and the reminders, through the real catalog, predicates,
-- composition, readiness and sequence executor on a modeled Retail client (probe policy; the last
-- test keeps the real restricted policy). Soul shards are read on the player (POINT).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_b.lua')
local AFF,AFFIV='rm.retail.warlock.affliction','rm.retail.warlock.affliction.icyveins'
local DEMO,DEMOIV='rm.retail.warlock.demonology','rm.retail.warlock.demonology.icyveins'
local DESTRO,DESTROSC,DESTROIV='rm.retail.warlock.destruction','rm.retail.warlock.destruction.simc','rm.retail.warlock.destruction.icyveins'
local SPECS={[265]={AFF,AFFIV},[266]={DEMO,DEMOIV},[267]={DESTRO,DESTROSC,DESTROIV}}
local unpack=unpack or table.unpack
local function warlock()
 local f,s=M.new('warlock');s.ranged(980,172,445468,1259790,48181,686,1261153,198590,27243,105174,264178,434506,348,29722,116858,17962,6353,17877)
 return f.addon,s,f
end
test('every Warlock premade is listed in each slot, Retail only, eligible only in its own specialization',function()
 local a=warlock();M.checkSlots(a,SPECS)
 for _,id in ipairs({AFFIV,DEMOIV,DESTROSC,DESTROIV})do assert(M.row(a,265,id).envelope.body.disabled==true,id..' reference is not off by default')end
end)
test('Assisted: each specialization follows Blizzard\'s suggestion after the Stops',function()
 local a,s=warlock();s.learn(1259790,105174,116858)
 M.checkAssisted(a,s,265,AFF,1259790);M.checkAssisted(a,s,266,DEMO,105174);M.checkAssisted(a,s,267,DESTRO,116858)
 s.suggest=116858;s.hostile=false;M.expect(a,s,267,DESTRO,nil,'stopped','no enemy target')
end)
test('reminders: demon between pulls, cooldowns, Tyrant after Dreadstalkers, interrupt and defensives',function()
 local a,s=warlock();s.learn(691,30146,688,205180,265187,1276452,1276467,1276672,1122,119898,108416,104773)
 s.combat=false;local lit=M.upkeep(a,s,265,AFF);assert(lit[691],'Felhunter when no demon is out')
 s.buff('player',196099);lit=M.upkeep(a,s,267,DESTRO);assert(not lit[688],'no Imp after Grimoire of Sacrifice');s.clearAuras()
 s.pet=true;lit=M.upkeep(a,s,266,DEMO);assert(not lit[30146],'a demon is out');s.pet=false;lit=M.upkeep(a,s,266,DEMO);assert(lit[30146],'Felguard')
 s.combat=true;lit=M.upkeep(a,s,265,AFF);assert(lit[205180],'Darkglare');lit=M.upkeep(a,s,267,DESTRO);assert(lit[1122],'Summon Infernal')
 lit=M.upkeep(a,s,266,DEMO);assert(lit[1276452]and lit[1276467]and lit[1276672]and not lit[265187],'Grimoires and Doomguard; Tyrant waits for Dreadstalkers')
 s.history(104316,4);lit=M.upkeep(a,s,266,DEMO);assert(lit[265187],'Tyrant with Dreadstalkers out')
 s.health.player=30;lit=M.upkeep(a,s,265,AFF);assert(lit[108416]and lit[104773],'Dark Pact and Unending Resolve when low')
end)
test('Affliction reference: Haunt pull, DoTs under 3 s, shard spending, Nightfall, filler',function()
 local a,s=warlock();s.learn(48181,980,172,1257052,1259790,1261153,686,198590,27243)
 s.combat=false;M.expect(a,s,265,AFFIV,48181,nil,'Haunt before the pull');s.combat=true
 s.cooling(48181,10);M.expect(a,s,265,AFFIV,980,nil,'Agony');s.debuff('target',980,{expirationTime=110,duration=18})
 M.expect(a,s,265,AFFIV,172,nil,'Corruption');s.debuff('target',146739,{expirationTime=110,duration=14})
 M.expect(a,s,265,AFFIV,1257052,nil,'Dark Harvest at no shards');s.cooling(1257052,40)
 M.expect(a,s,265,AFFIV,198590,nil,'Drain Soul filler')
 s.points=5;M.expect(a,s,265,AFFIV,1259790,nil,'5 shards: Unstable Affliction');s.points=4;M.expect(a,s,265,AFFIV,1259790,nil,'4 shards: avoid capping')
 s.points=1;s.buff('player',264571,{applications=2});M.expect(a,s,265,AFFIV,1261153,nil,'two Nightfall: Malefic Grasp')
 s.clearAuras();s.debuff('target',980,{expirationTime=102,duration=18});s.debuff('target',146739,{expirationTime=110,duration=14});M.expect(a,s,265,AFFIV,980,nil,'Agony under 3 s')
 s.learn(445468);s.clearAuras();s.debuff('target',980,{expirationTime=110,duration=18});M.expect(a,s,265,AFFIV,445468,nil,'Wither replaces Corruption')
 s.near(3);M.expect(a,s,265,AFFIV,27243,nil,'three engaged without your Corruption: Seed')
end)
test('Demonology reference: pull, Power Siphon, Grimoires, Tyrant at 5, shard spending, filler',function()
 local a,s=warlock();s.learn(264130,264178,686,1276452,1276467,1276672,104316,265187,196277,434635,105174,434506)
 s.combat=false;M.expect(a,s,266,DEMOIV,264130,nil,'Power Siphon before the pull');s.combat=true
 M.expect(a,s,266,DEMOIV,264130,nil,'Power Siphon with no Demonic Core');s.cooling(264130,20)
 M.expect(a,s,266,DEMOIV,1276452,nil,'Grimoire: Imp Lord');s.cooling(1276452,60);s.cooling(1276467,60);s.cooling(1276672,60)
 M.expect(a,s,266,DEMOIV,104316,nil,'Call Dreadstalkers');s.cooling(104316,10)
 s.points=5;M.expect(a,s,266,DEMOIV,265187,nil,'Tyrant at 5 shards');s.cooling(265187,40)
 M.expect(a,s,266,DEMOIV,434635,nil,'Ruination');s.usable[434635]=false;M.expect(a,s,266,DEMOIV,105174,nil,'Hand of Gul\'dan at 3+')
 s.points=1;M.expect(a,s,266,DEMOIV,434506,nil,'Infernal Bolt below 3');s.usable[434506]=false
 s.buff('player',264173,{applications=3});M.expect(a,s,266,DEMOIV,264178,nil,'Demonbolt on Demonic Core');s.clearAuras()
 M.expect(a,s,266,DEMOIV,686,nil,'Shadow Bolt');s.near(3);M.expect(a,s,266,DEMOIV,196277,nil,'three engaged: Implosion')
end)
test('Destruction SimulationCraft reference: Soul Fire, Chaos Bolt only capped, Conflagrate, Immolate, AoE',function()
 local a,s=warlock();s.learn(6353,29722,116858,17962,1122,442726,348,434635,152108,434506,5740)
 s.combat=false;M.expect(a,s,267,DESTROSC,6353,nil,'Soul Fire before the pull');s.combat=true
 s.points=4;M.expect(a,s,267,DESTROSC,6353,nil,'Soul Fire at 4');s.cooling(6353,30)
 s.points=5;M.expect(a,s,267,DESTROSC,116858,nil,'Chaos Bolt at 5');s.points=3
 M.expect(a,s,267,DESTROSC,17962,nil,'Conflagrate below 4 without Backdraft');s.buff('player',117828)
 M.expect(a,s,267,DESTROSC,1122,nil,'Backdraft up: Summon Infernal');s.cooling(1122,100);s.cooling(442726,40)
 M.expect(a,s,267,DESTROSC,348,nil,'Immolate missing');s.debuff('target',157736,{expirationTime=115,duration=18})
 s.usable[434635]=false;s.cooling(152108,20);M.expect(a,s,267,DESTROSC,434506,nil,'Infernal Bolt at 3 or fewer');s.usable[434506]=false
 M.expect(a,s,267,DESTROSC,29722,nil,'Incinerate');s.near(3);M.expect(a,s,267,DESTROSC,5740,nil,'three engaged at 3 shards: Rain of Fire')
end)
test('Destruction Icy Veins reference: Shadowburn, Chaos Bolt at 4, Channel Demonfire',function()
 local a,s=warlock();s.learn(445468,1122,442726,17877,6353,116858,152108,434506,196447,17962,29722,348)
 M.expect(a,s,267,DESTROIV,445468,nil,'Wither missing');s.debuff('target',445474,{expirationTime=115,duration=18})
 s.cooling(1122,100);s.cooling(442726,40);M.expect(a,s,267,DESTROIV,17877,nil,'Shadowburn');s.cooling(17877,10)
 s.points=4;s.cooling(6353,30);M.expect(a,s,267,DESTROIV,116858,nil,'Chaos Bolt at 4');s.points=2
 s.cooling(152108,20);s.usable[434506]=false;M.expect(a,s,267,DESTROIV,196447,nil,'Channel Demonfire')
end)
test('on the real restricted Retail client every Warlock premade is complete and the recommended premade auto-selects',function()
 M.checkRestricted('warlock',SPECS,{1259790,105174,116858})
end)
test('before a specialization (initial spec 1454) a level-4 Warlock gets the Blizzard Assisted premade, complete',function()
 M.initial('warlock',1454,'rm.retail.warlock.initial',{686})
end)
finish()
