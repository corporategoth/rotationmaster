-- Retail Death Knight premades: per-spec storage, auto-select, the Blizzard Assisted step, the
-- reference priorities, Stops and reminders through the real catalog, predicates, composition and
-- sequence executor on a modeled Retail client (probe policy; the last test keeps the real
-- restricted policy). C_AssistedCombat is a model of Blizzard's documented API.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_a.lua')
local BLOOD,FROST,UNHOLY=250,251,252
local P='rm.retail.deathknight.'
local ids={[BLOOD]={P..'blood',P..'blood.guide',P..'blood.simc'},[FROST]={P..'frost',P..'frost.guide',P..'frost.wowhead'},[UNHOLY]={P..'unholy',P..'unholy.guide',P..'unholy.simc'}}
local function dk(spec,level)
 local f,s=M.new('death-knight','DEATHKNIGHT',spec);local a=f.addon
 s.setLevel(level or 90);s.powerType=6;s.energy=50;s.points=6
 s.ranged(47528,49184,195292,47541,77575,343294,207317,46584)
 return a,s,f
end
-- Guide premades ship disabled; the scenarios read their priority as if enabled.
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end
test('every Death Knight premade loads for its own specialization only and declares Retail',function()
 for spec,list in pairs(ids)do
  local a=dk(spec);local rows=M.rows(a)
  for index,id in ipairs(list)do
   local row=assert(rows[id],id);local scope=row.applicability
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.class=='DEATHKNIGHT',id)
   assert(#scope.specs==1 and scope.specs[1]==spec and scope.minLevel==8 and scope.maxLevel==90,id..' scope')
   assert(row.eligible==(index==1),id..' eligibility: only the Assisted premade is on by default')
  end
  for other,list2 in pairs(ids)do if other~=spec then for _,id in ipairs(list2)do assert(rows[id]==nil or not rows[id].eligible,id..' eligible in spec '..spec)end end end
 end
end)
test('auto-select: the Blizzard Assisted premade in each spec slot; an enabled reference runs but never outranks it',function()
 for spec,list in pairs(ids)do
  local a=dk(spec);assert(M.selected(a)==list[1],'spec '..spec..': '..tostring(M.selected(a)))
  for _,id in ipairs(list)do assert(M.switch(a,id)=='match',id..' switch')end
  enable(a,list[2]);assert(M.rows(a)[list[2]].eligible,'an enabled reference is not runnable')
  assert(M.selected(a)==list[1],'the reference outranked the recommended premade')
  local low=dk(spec,7);assert(M.selected(low)==nil,'level 7 is below the Death Knight start')
 end
end)
test('Assisted: follows the suggestion every poll, falls through when there is none, waits on casts',function()
 for spec,list in pairs(ids)do
  local a,s=dk(spec);s.learn(49998,206930,49020,55090,47541)
  s.suggest=49998;M.expect(a,s,list[1],49998,nil,'suggested Death Strike')
  assert(s.assistedCheck==false,'suggestion not read with checkForVisibleButton=false')
  s.suggest=206930;M.expect(a,s,list[1],206930,nil,'a new suggestion is followed')
  s.suggest=nil;M.expect(a,s,list[1],nil,nil,'nothing suggested')
  s.suggest=12345;M.expect(a,s,list[1],nil,nil,'an unknown suggestion is skipped')
  s.suggest=49998;s.cast=true;M.expect(a,s,list[1],nil,'stopped','casting');s.cast=false
  s.channel=true;M.expect(a,s,list[1],nil,'stopped','channelling');s.channel=false
  s.cooling(49998,5);M.expect(a,s,list[1],nil,nil,'a cooling suggestion is not recommended');s.cooldown={}
  s.assisted=false;M.expect(a,s,list[1],nil,nil,'Assisted Combat unavailable for this spec')
 end
end)
test('Assisted in Midnight combat: secret cooldowns, health and auras still give advice; hidden-data reminders stay dark',function()
 local a,s=dk(BLOOD);s.learn(49998,55233,46585,47528,48792,26297)
 s.secrets();s.suggest=49998
 M.expect(a,s,P..'blood',49998,nil,'suggestion with secret data')
 s.cooling(49998,8);M.expect(a,s,P..'blood',nil,nil,'cooling by the never-secret flag');s.cooldown={}
 s.health.player=20;s.targetCast=true
 local lit=M.upkeep(a,s,P..'blood')
 assert(lit[55233]and lit[46585]and lit[26297],'in-combat reminders did not light on the readable cooldown flags')
 assert(not lit[48792]and not lit[47528],'a reminder gated on hidden health or enemy casts lit')
 s.secrets(false);lit=M.upkeep(a,s,P..'blood')
 assert(lit[48792]and lit[47528],'Icebound Fortitude and Mind Freeze did not light where readable')
 s.cooling(55233,30);lit=M.upkeep(a,s,P..'blood');assert(not lit[55233],'a cooling reminder lit')
 s.combat=false;lit=M.upkeep(a,s,P..'blood');assert(not lit[55233]and not lit[26297],'combat reminders lit out of combat')
end)
test('Blood reference: pull, Death Strike, Bone Shield, Gift of the San\'layn, Crimson Scourge, Blood Boil, Heart Strike',function()
 local a,s=dk(BLOOD);enable(a,P..'blood.guide');local G=P..'blood.guide'
 s.learn(195292,49998,195182,206930,50842,43265)
 s.combat=false;M.expect(a,s,G,195292,nil,'pull: Death\'s Caress');s.combat=true
 s.buff('player',195181,{applications=8,expirationTime=120})
 s.debuff('target',55078)
 M.expect(a,s,G,206930,nil,'Heart Strike filler')
 s.energy=80;M.expect(a,s,G,49998,nil,'Death Strike at 75 runic power');s.energy=50
 s.health.player=40;M.expect(a,s,G,49998,nil,'Death Strike at low health');s.health.player=100
 s.clearAuras();s.debuff('target',55078);M.expect(a,s,G,195182,nil,'Marrowrend with no Bone Shield')
 s.targetRange={10,15};s.range[195182]=false;M.expect(a,s,G,195292,nil,'Death\'s Caress out of melee');s.targetRange={0,5};s.range[195182]=nil
 s.buff('player',195181,{applications=3,expirationTime=120});M.expect(a,s,G,195182,nil,'Marrowrend under five charges')
 s.clearAuras();s.buff('player',195181,{applications=8,expirationTime=120})
 M.expect(a,s,G,50842,nil,'Blood Boil with Blood Plague missing')
 s.debuff('target',55078);s.buff('player',81141);M.expect(a,s,G,43265,nil,'Death and Decay on Crimson Scourge')
 s.clearAuras();s.buff('player',195181,{applications=8,expirationTime=120});s.debuff('target',55078)
 s.learn(433895);s.buff('player',434153);s.energy=72;M.expect(a,s,G,49998,nil,'Gift: Death Strike above 70')
 s.energy=50;M.expect(a,s,G,50842,nil,'Gift: one Blood Boil');s.history(50842,2)
 M.expect(a,s,G,206930,nil,'Gift: Heart Strike once Blood Boil was cast')
 s.cooling(206930,2);M.expect(a,s,G,nil,'stopped','Gift: nothing else outside the window')
 local lit=M.upkeep(a,s,G);assert(not lit[49028],'Dancing Rune Weapon without Reaper\'s Mark known');s.learn(49028)
 lit=M.upkeep(a,s,G);assert(lit[49028],'Dancing Rune Weapon when Reaper\'s Mark is not known')
 s.learn(439843);lit=M.upkeep(a,s,G);assert(not lit[49028]and lit[439843],'Deathbringer: Reaper\'s Mark first')
 s.debuff('target',434765);lit=M.upkeep(a,s,G);assert(lit[49028],'Dancing Rune Weapon after Reaper\'s Mark')
end)
test('Blood SimulationCraft reference: runic power dump, Death and Decay upkeep, Death\'s Caress while runes are short',function()
 local a,s=dk(BLOOD);local G=P..'blood.simc';enable(a,G)
 s.learn(49998,195182,195292,206930,50842,43265,439843)
 s.buff('player',188290);s.buff('player',195181,{applications=8,expirationTime=120});s.cooling(439843,20)
 s.energy=90;M.expect(a,s,G,49998,nil,'Death Strike near the cap');s.energy=30
 s.usable[49998]=false;M.expect(a,s,G,50842,nil,'Blood Boil when Death Strike is unaffordable');s.usable[49998]=nil
 M.expect(a,s,G,49998,nil,'Death Strike above Blood Boil and Heart Strike')
 s.clearAuras();s.buff('player',188290);s.points=2;M.expect(a,s,G,195292,nil,'Death\'s Caress for Bone Shield with two runes')
 s.points=5;M.expect(a,s,G,195182,nil,'Marrowrend with runes')
 s.clearAuras();M.expect(a,s,G,43265,nil,'Death and Decay when it is down')
end)
test('Frost reference: Killing Machine, Razorice, Rime, runic power cap, AoE swaps and the ranged filler',function()
 local a,s=dk(FROST);local G=P..'frost.guide';enable(a,G)
 s.learn(49020,49143,49184,207230,194913)
 M.expect(a,s,G,49143,nil,'Frost Strike before an Obliterate without Killing Machine')
 s.usable[49143]=false;M.expect(a,s,G,49020,nil,'Obliterate last');s.usable[49143]=nil
 s.buff('player',51124,{applications=2});M.expect(a,s,G,49020,nil,'two Killing Machines');s.clearAuras()
 s.buff('player',51124,{applications=1});s.points=2;s.buff('player',59052);M.expect(a,s,G,49184,nil,'one Killing Machine and two runes: Rime first')
 s.points=3;M.expect(a,s,G,49020,nil,'one Killing Machine and three runes: Obliterate before Rime')
 s.clearAuras();s.buff('player',51124,{applications=1});M.expect(a,s,G,49020,nil,'Obliterate on Killing Machine');s.clearAuras()
 s.energy=90;M.expect(a,s,G,49143,nil,'Frost Strike before capping');s.energy=50
 s.learn(207057);s.debuff('target',51714,{applications=5});s.buff('player',51124,{applications=2});M.expect(a,s,G,49020,nil,'Killing Machines before Shattering Blade')
 s.clearAuras();s.debuff('target',51714,{applications=5});M.expect(a,s,G,49143,nil,'Shattering Blade at five Razorice');s.clearAuras()
 s.near(3);s.buff('player',51124,{applications=2});M.expect(a,s,G,207230,nil,'three enemies: Frostscythe');s.clearAuras()
 M.expect(a,s,G,194913,nil,'three enemies: Glacial Advance');s.known[194913]=nil;s.known[207230]=nil
 M.expect(a,s,G,49020,nil,'packs without the talents still Obliterate');s.near(0)
 s.usable[49020]=false;s.usable[49143]=false;s.targetRange={20,25};M.expect(a,s,G,49184,nil,'Howling Blast out of melee')
 local lit=M.upkeep(a,s,G);s.learn(51271,152279,279302,47568);lit=M.upkeep(a,s,G)
 assert(lit[51271]and not lit[152279]and not lit[279302],'Pillar first, Breath and Frostwyrm\'s Fury inside it')
 s.charges[47568]={current=1,max=2};s.buff('player',51271);s.energy=10;lit=M.upkeep(a,s,G);assert(lit[152279]and lit[279302]and lit[47568],'Pillar window and Empower Rune Weapon at low runic power')
end)
test('Frost Wowhead reference: Empower Rune Weapon at two charges and cooldowns inside the rotation',function()
 local a,s=dk(FROST);local G=P..'frost.wowhead';enable(a,G)
 s.learn(49020,49143,49184,47568,51271,439843)
 s.charges[47568]={current=2,max=2};M.expect(a,s,G,47568,nil,'Empower Rune Weapon at two charges')
 s.charges[47568]={current=1,max=2};M.expect(a,s,G,439843,nil,'Reaper\'s Mark');s.cooling(439843,30)
 M.expect(a,s,G,51271,nil,'Pillar of Frost');s.cooling(51271,30)
 s.buff('player',59052);s.energy=95;M.expect(a,s,G,49184,nil,'Rime above the runic power cap');s.clearAuras();s.energy=50
 M.expect(a,s,G,47568,nil,'Empower Rune Weapon for a Killing Machine')
 s.buff('player',51124,{applications=1});M.expect(a,s,G,49020,nil,'Obliterate on Killing Machine')
end)
test('Unholy reference: ghoul, Soul Reaper, Putrefy, procs, Lesser Ghoul build and spend',function()
 local a,s=dk(UNHOLY);local G=P..'unholy.guide';enable(a,G)
 s.learn(46584,85948,55090,47541,343294,1247378,207317)
 M.expect(a,s,G,46584,nil,'Raise Dead without a ghoul');s.pet=true
 s.combat=false;M.expect(a,s,G,85948,nil,'no Unholy pull Stop: the priority runs');s.combat=true
 M.expect(a,s,G,85948,nil,'Festering Strike with no Lesser Ghoul charges')
 s.buff('player',1254252,{applications=2});M.expect(a,s,G,55090,nil,'Scourge Strike with charges')
 s.health.target=30;M.expect(a,s,G,343294,nil,'Soul Reaper below 35%');s.health.target=100
 s.auras.pet={HELPFUL={{spellId=1233448,name='Spell 1233448',sourceUnit='player'}},HARMFUL={}}
 M.expect(a,s,G,1247378,nil,'Putrefy in Dark Transformation');s.auras.pet=nil;s.cooling(1247378,20)
 s.buff('player',81340);M.expect(a,s,G,47541,nil,'Death Coil on Sudden Doom')
 s.near(4);M.expect(a,s,G,207317,nil,'Epidemic on four enemies');s.near(0);s.clearAuras()
 s.buff('player',458123);M.expect(a,s,G,85948,nil,'Festering Scythe when its haste is missing')
 s.debuff('target',1241077,{expirationTime=200});M.expect(a,s,G,85948,nil,'no Lesser Ghoul charges: Festering Strike')
 local lit=M.upkeep(a,s,G);s.learn(77575);lit=M.upkeep(a,s,G);assert(lit[77575],'Outbreak with no plague')
 s.debuff('target',191587);lit=M.upkeep(a,s,G);assert(not lit[77575],'Outbreak with Virulent Plague up')
end)
test('Unholy SimulationCraft reference: Death Coil spending and the AoE arm',function()
 local a,s=dk(UNHOLY);local G=P..'unholy.simc';enable(a,G)
 s.learn(85948,55090,47541,207317,1247378,42650);s.pet=true
 s.energy=95;M.expect(a,s,G,47541,nil,'Death Coil near the cap');s.energy=30
 s.cooling(42650,60);M.expect(a,s,G,47541,nil,'Death Coil while Army of the Dead is far off');s.cooldown={}
 s.buff('player',1254252,{applications=2});M.expect(a,s,G,55090,nil,'Scourge Strike with Lesser Ghoul charges when Army is ready');s.clearAuras()
 M.expect(a,s,G,85948,nil,'Festering Strike')
 s.near(3);M.expect(a,s,G,85948,nil,'AoE: Festering Strike below three charges')
 s.buff('player',1254252,{applications=3});M.expect(a,s,G,55090,nil,'AoE: Scourge Strike at three')
 s.buff('player',81340);M.expect(a,s,G,207317,nil,'AoE: Epidemic on Sudden Doom')
end)
test('on the real restricted Retail client the Death Knight premades are listed but never auto-selected',function()
 M.restricted('death-knight','DEATHKNIGHT',ids)
end)
finish()
