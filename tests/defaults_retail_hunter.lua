-- Retail Hunter premades: per-spec storage, auto-select, the Blizzard Assisted step, the reference
-- priorities, Stops and reminders through the real catalog, predicates, composition and sequence
-- executor on a modeled Retail client (probe policy; the last test keeps the real restricted
-- policy). C_AssistedCombat is a model of Blizzard's documented API.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_a.lua')
local BM,MM,SV=253,254,255
local P='rm.retail.hunter.'
local ids={[BM]={P..'beastmastery',P..'beastmastery.guide'},[MM]={P..'marksmanship',P..'marksmanship.guide'},[SV]={P..'survival',P..'survival.guide'}}
local function hunter(spec,level)
 local f,s=M.new('hunter','HUNTER',spec);local a=f.addon
 s.setLevel(level or 90);s.powerType=2;s.energy=50;s.targetRange={30,35}
 s.ranged(217200,19574,34026,193455,466930,392060,19434,257044,212431,260243,53351,257620,185358,56641,1264949,257284,147362,259495,1261193)
 return a,s,f
end
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end
test('every Hunter premade loads for its own specialization only and declares Retail',function()
 for spec,list in pairs(ids)do
  local a=hunter(spec);local rows=M.rows(a)
  for index,id in ipairs(list)do
   local row=assert(rows[id],id);local scope=row.applicability
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.class=='HUNTER',id)
   assert(scope.specs==nil and scope.minLevel==nil and scope.maxLevel==nil,id..' scope: load-time facts only')
   assert(row.envelope.body.switch==nil and #row.envelope.body.specs==1 and row.envelope.body.specs[1]==spec,id..' specs')
   assert(row.eligible==(index==1),id..' eligibility: only the Assisted premade is on by default')
  end
  for other,list2 in pairs(ids)do if other~=spec then for _,id in ipairs(list2)do assert(rows[id]==nil or not rows[id].eligible,id..' eligible in spec '..spec)end end end
 end
end)
test('auto-select: the Blizzard Assisted premade in each spec slot; an enabled reference runs but never outranks it',function()
 for spec,list in pairs(ids)do
  local a=hunter(spec);assert(M.selected(a)==list[1],'spec '..spec..': '..tostring(M.selected(a)))
  for _,id in ipairs(list)do assert(M.switch(a,id)=='match',id..' switch')end
  enable(a,list[2]);assert(M.rows(a)[list[2]].eligible,'an enabled reference is not runnable')
  assert(M.selected(a)==list[1],'the reference outranked the recommended premade')
  do local low,ls=hunter(spec,9);ls.respec(1448);assert(M.selected(low)==P..'initial','below 10 the game reports the initial spec: '..tostring(M.selected(low)))end
 end
end)
test('Assisted: follows the suggestion every poll, falls through when there is none, waits on casts',function()
 for spec,list in pairs(ids)do
  local a,s=hunter(spec);s.learn(34026,217200,19434,259489,883)
  s.suggest=34026;M.expect(a,s,list[1],34026,nil,'suggested Kill Command')
  assert(s.assistedCheck==false,'suggestion not read with checkForVisibleButton=false')
  s.suggest=883;M.expect(a,s,list[1],883,nil,'Call Pet is followed too')
  s.suggest=nil;M.expect(a,s,list[1],nil,nil,'nothing suggested')
  s.suggest=12345;M.expect(a,s,list[1],nil,nil,'an unknown suggestion is skipped')
  s.suggest=19434;s.cast=true;M.expect(a,s,list[1],nil,'stopped','casting Aimed Shot');s.cast=false
  s.channel=true;M.expect(a,s,list[1],nil,'stopped','channelling Rapid Fire');s.channel=false
  s.cooling(19434,5);M.expect(a,s,list[1],nil,nil,'a cooling suggestion is not recommended');s.cooldown={}
  s.assisted=false;M.expect(a,s,list[1],nil,nil,'Assisted Combat unavailable for this spec')
 end
end)
test('Assisted in Midnight combat: secret data still gives advice; hidden-data reminders stay dark',function()
 local a,s=hunter(MM);s.learn(19434,288613,147362,109304,264735,26297)
 s.secrets();s.suggest=19434
 M.expect(a,s,P..'marksmanship',19434,nil,'suggestion with secret data')
 s.cooling(19434,8);M.expect(a,s,P..'marksmanship',nil,nil,'cooling by the never-secret flag');s.cooldown={}
 s.health.player=10;s.targetCast=true
 local lit=M.upkeep(a,s,P..'marksmanship')
 assert(lit[288613]and lit[26297],'Trueshot and the racial did not light on the readable cooldown flags')
 assert(lit[264735],'Survival of the Fittest did not light on the readable cooldown flag')
 assert(not lit[109304]and not lit[147362],'Exhilaration (yours: health is secret) or an interrupt on a hidden cast lit')
 s.secrets(false);lit=M.upkeep(a,s,P..'marksmanship')
 assert(lit[264735]and lit[147362]and not lit[109304],'Survival of the Fittest and Counter Shot where readable; never Exhilaration')
 s.combat=false;lit=M.upkeep(a,s,P..'marksmanship');assert(not lit[288613]and not lit[26297],'combat reminders lit out of combat')
 local b,t=hunter(SV);t.learn(1250646,187707);t.targetCast=true;lit=M.upkeep(b,t,P..'survival')
 assert(lit[1250646]and lit[187707]and not lit[147362],'Survival: Takedown and Muzzle, no Counter Shot')
 local c,u=hunter(BM);u.learn(321530);lit=M.upkeep(c,u,P..'beastmastery');assert(lit[321530],'Beast Mastery: Bloodshed')
end)
test('Beast Mastery reference: pet, mark, Barbed Shot pooling, Bestial Wrath, Kill Command banking, Cobra Shot',function()
 local a,s=hunter(BM);local G=P..'beastmastery.guide';enable(a,G)
 s.learn(883,257284,217200,19574,34026,193455,1264359)
 s.charges[217200]={current=1,max=2}
 M.expect(a,s,G,883,nil,'Call Pet without a pet');s.pet=true
 s.combat=false;M.expect(a,s,G,257284,nil,'pull: Hunter\'s Mark');s.debuff('target',257284)
 M.expect(a,s,G,nil,'stopped','pull: nothing more out of combat');s.combat=true
 M.expect(a,s,G,217200,nil,'Barbed Shot just before Bestial Wrath')
 s.usable[217200]=false;M.expect(a,s,G,19574,nil,'Bestial Wrath');s.usable[217200]=nil;s.cooling(19574,30)
 M.expect(a,s,G,34026,nil,'Kill Command while Bestial Wrath is far off')
 s.cooling(19574,4);M.expect(a,s,G,193455,nil,'banking: Cobra Shot while affordable (Focus is secret)')
 s.power[193455]=true;M.expect(a,s,G,217200,nil,'banking: Barbed Shot when Cobra Shot is unaffordable');s.power[193455]=nil
 s.buff('player',471878);M.expect(a,s,G,34026,nil,'Kill Command on Howl of the Pack Leader');s.clearAuras();s.debuff('target',257284)
 s.cooling(19574,30);s.cooling(34026,5);s.buff('player',1299389);M.expect(a,s,G,193455,nil,'Cobra Shot on Cobra Fang');s.clearAuras();s.debuff('target',257284)
 s.charges[217200]={current=2,max=2};s.energy=90;M.expect(a,s,G,217200,nil,'Barbed Shot before it caps')
end)
test('Beast Mastery reference: Beast Cleave on packs and the Dark Ranger order',function()
 local a,s=hunter(BM);local G=P..'beastmastery.guide';enable(a,G)
 s.learn(217200,19574,34026,193455,1264359);s.pet=true;s.charges[217200]={current=0,max=2};s.cooling(19574,30)
 s.near(3);M.expect(a,s,G,1264359,nil,'three enemies: Wild Thrash for Beast Cleave')
 s.buff('player',268877);M.expect(a,s,G,34026,nil,'Kill Command while Beast Cleave lasts')
 s.near(2);s.clearAuras();M.expect(a,s,G,1264359,nil,'two enemies (Pack Leader): Wild Thrash');s.near(0)
 local b,t=hunter(BM);enable(b,G);t.pet=true;t.learn(217200,19574,34026,193455,466930,392060);t.charges[217200]={current=1,max=2}
 t.cooling(19574,30);t.buff('player',466991,{expirationTime=110})
 M.expect(b,t,G,466930,nil,'Dark Ranger: Black Arrow in Withering Fire');t.cooling(466930,8)
 M.expect(b,t,G,34026,nil,'Dark Ranger: Kill Command');t.cooling(34026,5)
 t.clearAuras();t.buff('player',466991,{expirationTime=101});M.expect(b,t,G,392060,nil,'Dark Ranger: Wailing Arrow as Withering Fire ends')
end)
test('Marksmanship reference: pull, Sentinel and Dark Ranger orders, Trick Shots on packs',function()
 local a,s=hunter(MM);local G=P..'marksmanship.guide';enable(a,G)
 s.learn(257284,19434,257044,288613,212431,260243,53351,257620,185358,56641,1264949)
 s.charges[19434]={current=1,max=2}
 s.combat=false;s.debuff('target',257284);M.expect(a,s,G,19434,nil,'pull: Aimed Shot');s.combat=true
 M.expect(a,s,G,212431,nil,'Sentinel: Explosive Shot');s.cooling(212431,20)
 M.expect(a,s,G,260243,nil,'Volley');s.cooling(260243,30)
 M.expect(a,s,G,288613,nil,'Trueshot');s.cooling(288613,90)
 M.expect(a,s,G,257044,nil,'Rapid Fire without Precise Shots')
 s.buff('player',260242);M.expect(a,s,G,53351,nil,'Kill Shot spends Precise Shots')
 s.usable[53351]=false;M.expect(a,s,G,185358,nil,'Arcane Shot spends Precise Shots');s.usable[53351]=nil
 s.buff('player',288613);M.expect(a,s,G,257044,nil,'Rapid Fire in Trueshot');s.cooling(257044,10)
 s.clearAuras();s.debuff('target',257284);s.buff('player',288613);M.expect(a,s,G,19434,nil,'Aimed Shot in Trueshot without Precise Shots')
 s.clearAuras();s.debuff('target',257284);s.cooling(19434,5);M.expect(a,s,G,1264949,nil,'Moonlight Chakram');s.cooling(1264949,10)
 M.expect(a,s,G,56641,nil,'Steady Shot filler');s.cooldown={}
 local b,t=hunter(MM);enable(b,G);t.learn(19434,257044,288613,212431,260243,466930,185358,56641,257620,257621)
 t.charges[19434]={current=1,max=2};t.buff('player',260242);M.expect(b,t,G,466930,nil,'Dark Ranger: Black Arrow on Precise Shots')
 t.clearAuras();t.buff('player',194594);M.expect(b,t,G,260243,nil,'Dark Ranger: no Explosive Shot with Lock and Load')
 t.clearAuras();t.cooling(260243,30);t.cooling(212431,20);t.charges[19434]={current=2,max=2};M.expect(b,t,G,19434,nil,'Dark Ranger: Aimed Shot before it caps')
 t.near(3);t.cooldown={};M.expect(b,t,G,212431,nil,'packs: Explosive Shot');t.cooling(212431,20);t.cooling(260243,30)
 M.expect(b,t,G,257620,nil,'packs: Multi-Shot applies Trick Shots')
 t.buff('player',257622);t.cooling(288613,90);M.expect(b,t,G,257044,nil,'packs: Rapid Fire with Trick Shots')
end)
test('Survival reference: Tip of the Spear builder and spenders, Pack Leader and Sentinel, cleave',function()
 local a,s=hunter(SV);local G=P..'survival.guide';enable(a,G);s.pet=true;s.targetRange={0,5}
 s.learn(257284,259489,259495,1250646,1261193,186270,1264949,186289)
 s.combat=false;s.debuff('target',257284);M.expect(a,s,G,259495,nil,'pull: Wildfire Bomb');s.combat=true
 M.expect(a,s,G,259489,nil,'Sentinel: Kill Command without Tip of the Spear')
 s.buff('player',260286);M.expect(a,s,G,1261193,nil,'Sentinel: Boomstick');s.cooling(1261193,30)
 s.charges[259495]={current=1,max=1};M.expect(a,s,G,1250646,nil,'Sentinel: Takedown');s.cooling(1250646,60)
 s.buff('player',1253601);M.expect(a,s,G,259495,nil,'Sentinel: Wildfire Bomb on Sentinel\'s Mark');s.cooling(259495,10)
 M.expect(a,s,G,1264949,nil,'Sentinel: Moonlight Chakram');s.cooling(1264949,10)
 M.expect(a,s,G,186270,nil,'Sentinel: Raptor Strike')
 s.targetRange={20,25};local lit=M.upkeep(a,s,G);assert(lit[186289],'Aspect of the Eagle out of melee');s.targetRange={0,5}
 local b,t=hunter(SV);enable(b,G);t.pet=true;t.targetRange={0,5};t.learn(259489,259495,1250646,1261193,186270,471876)
 t.charges[259495]={current=1,max=1}
 M.expect(b,t,G,259489,nil,'Pack Leader: Kill Command before a ready Takedown')
 t.buff('player',260286,{applications=1});M.expect(b,t,G,1250646,nil,'Pack Leader: Takedown with Tip of the Spear');t.cooling(1250646,60)
 M.expect(b,t,G,259495,nil,'Pack Leader: Wildfire Bomb with Tip of the Spear');t.cooling(259495,10)
 M.expect(b,t,G,1261193,nil,'Pack Leader: Boomstick with Tip of the Spear');t.cooling(1261193,30)
 M.expect(b,t,G,186270,nil,'Pack Leader: Raptor Strike with Tip of the Spear')
 t.buff('player',472324);M.expect(b,t,G,259489,nil,'Pack Leader: Kill Command on Howl below two stacks')
 t.clearAuras();t.cooldown={};t.near(3);t.buff('player',260286);M.expect(b,t,G,1261193,nil,'cleave: Boomstick first')
end)
test('Hunter boundaries: no pet, casts and channels in every reference',function()
 for spec,list in pairs(ids)do
  local a,s=hunter(spec);enable(a,list[2]);s.learn(883,193455,56641,186270);s.pet=true;s.targetRange={0,5}
  s.cast=true;M.expect(a,s,list[2],nil,'stopped','casting');s.cast=false
  s.channel=true;M.expect(a,s,list[2],nil,'stopped','channelling');s.channel=false
 end
end)
test('on the real restricted Retail client every Hunter premade is complete and the Assisted premade auto-selects',function()
 M.restricted('hunter','HUNTER',ids)
end)
test('before a specialization (initial spec 1448) a level-4 Hunter gets the Blizzard Assisted premade, complete',function()
 M.initial('hunter','HUNTER',1448,P..'initial',{185358})
end)
finish()
