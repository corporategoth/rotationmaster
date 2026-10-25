-- Retail Mage premades: per-spec storage, auto-select, the Blizzard Assisted step, the reference
-- priorities, Stops and reminders through the real catalog, predicates, composition and sequence
-- executor on a modeled Retail client (probe policy; the last test keeps the real restricted
-- policy). C_AssistedCombat is a model of Blizzard's documented API.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_a.lua')
local ARCANE,FIRE,FROST=62,63,64
local P='rm.retail.mage.'
local ids={[ARCANE]={P..'arcane',P..'arcane.guide'},[FIRE]={P..'fire',P..'fire.guide'},[FROST]={P..'frost',P..'frost.guide'}}
local function mage(spec,level)
 local f,s=M.new('mage','MAGE',spec);local a=f.addon
 s.setLevel(level or 90);s.powerType=0;s.points=0;s.targetRange={30,35}
 s.ranged(2139,30451,44425,5143,153626,1241462,1295924,133,11366,108853,2948,2120,153561,431044,116,44614,30455,84714,199786,205021,153595,190356,157997,120)
 s.buff('player',1459)
 return a,s,f
end
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end
test('every Mage premade loads for its own specialization only and declares Retail',function()
 for spec,list in pairs(ids)do
  local a=mage(spec);local rows=M.rows(a)
  for index,id in ipairs(list)do
   local row=assert(rows[id],id);local scope=row.applicability
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.class=='MAGE',id)
   assert(scope.specs==nil and scope.minLevel==nil and scope.maxLevel==nil,id..' scope: load-time facts only')
   assert(row.envelope.body.switch==nil and #row.envelope.body.specs==1 and row.envelope.body.specs[1]==spec,id..' specs')
   assert(row.eligible==(index==1),id..' eligibility: only the Assisted premade is on by default')
  end
  for other,list2 in pairs(ids)do if other~=spec then for _,id in ipairs(list2)do assert(rows[id]==nil or not rows[id].eligible,id..' eligible in spec '..spec)end end end
 end
end)
test('auto-select: the Blizzard Assisted premade in each spec slot; an enabled reference runs but never outranks it',function()
 for spec,list in pairs(ids)do
  local a=mage(spec);assert(M.selected(a)==list[1],'spec '..spec..': '..tostring(M.selected(a)))
  for _,id in ipairs(list)do assert(M.switch(a,id)=='match',id..' switch')end
  enable(a,list[2]);assert(M.rows(a)[list[2]].eligible,'an enabled reference is not runnable')
  assert(M.selected(a)==list[1],'the reference outranked the recommended premade')
  do local low,ls=mage(spec,9);ls.respec(1449);assert(M.selected(low)==P..'initial','below 10 the game reports the initial spec: '..tostring(M.selected(low)))end
 end
end)
test('Assisted: follows the suggestion every poll, falls through when there is none, waits on casts',function()
 for spec,list in pairs(ids)do
  local a,s=mage(spec);s.learn(30451,133,116,44425)
  s.suggest=30451;M.expect(a,s,list[1],30451,nil,'suggested Arcane Blast')
  assert(s.assistedCheck==false,'suggestion not read with checkForVisibleButton=false')
  s.suggest=133;M.expect(a,s,list[1],133,nil,'a new suggestion is followed')
  s.suggest=nil;M.expect(a,s,list[1],nil,nil,'nothing suggested')
  s.suggest=12345;M.expect(a,s,list[1],nil,nil,'an unknown suggestion is skipped')
  s.suggest=116;s.cast=true;M.expect(a,s,list[1],nil,'stopped','casting');s.cast=false
  s.channel=true;M.expect(a,s,list[1],nil,'stopped','channelling');s.channel=false
  s.cooling(116,5);M.expect(a,s,list[1],nil,nil,'a cooling suggestion is not recommended');s.cooldown={}
  s.assisted=false;M.expect(a,s,list[1],nil,nil,'Assisted Combat unavailable for this spec')
 end
end)
test('Assisted in Midnight combat: secret data still gives advice; Arcane Charges stay readable; hidden-data reminders stay dark',function()
 local a,s=mage(ARCANE);s.learn(30451,44425,2139,45438,235450,26297,1459)
 s.secrets();s.suggest=44425
 M.expect(a,s,P..'arcane',44425,nil,'suggestion with secret data')
 s.cooling(44425,8);M.expect(a,s,P..'arcane',nil,nil,'cooling by the never-secret flag');s.cooldown={}
 s.points=4;assert(a:evaluateConditionResult({type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=4}).status=='match','Arcane Charges are not readable under secrets')
 assert(a:evaluateConditionResult({type='MANAPCT',unit='player',operator='LESSTHAN',value=.5}).status=='unavailable','mana is readable under secrets')
 s.health.player=10;s.targetCast=true
 local lit=M.upkeep(a,s,P..'arcane')
 assert(lit[26297]and lit[235450],'the racial and the barrier did not light on the readable cooldown flags')
 assert(not lit[45438]and not lit[2139],'Ice Block (yours: health is secret) or an interrupt on a hidden cast lit')
 s.secrets(false);lit=M.upkeep(a,s,P..'arcane')
 assert(lit[2139]and lit[235450]and not lit[45438],'Counterspell and the barrier where readable; never Ice Block')
 s.combat=false;s.clearAuras();lit=M.upkeep(a,s,P..'arcane');assert(lit[1459]and not lit[26297],'Arcane Intellect out of combat, racials only in combat')
 s.buff('player',1459);lit=M.upkeep(a,s,P..'arcane');assert(not lit[1459],'Arcane Intellect while it is up')
 local b,t=mage(FROST);t.learn(31687);assert(M.upkeep(b,t,P..'frost')[31687],'Water Elemental without a pet')
 local c,u=mage(ARCANE);u.learn(365350);u.secrets();assert(M.upkeep(c,u,P..'arcane')[365350],'Arcane Surge, outside Assisted Combat, on the cooldown flag')
 local d,v=mage(FIRE);v.learn(190319);v.secrets();assert(M.upkeep(d,v,P..'fire')[190319],'Combustion, outside Assisted Combat, on the cooldown flag')
 t.pet=true;assert(not M.upkeep(b,t,P..'frost')[31687],'Water Elemental with one out')
end)
test('Arcane reference: pull, Sunfury Missiles, Barrage at four charges, Orb, Pulse, Blast, out-of-mana Barrage',function()
 local a,s=mage(ARCANE);local G=P..'arcane.guide';enable(a,G)
 s.learn(30451,44425,5143,153626,1241462)
 s.combat=false;M.expect(a,s,G,30451,nil,'pull: Arcane Blast');s.combat=true
 M.expect(a,s,G,153626,nil,'Arcane Orb below three charges');s.cooling(153626,10)
 M.expect(a,s,G,1241462,nil,'Arcane Pulse at zero charges');s.cooling(1241462,10)
 M.expect(a,s,G,30451,nil,'Arcane Blast');s.usable[30451]=false
 M.expect(a,s,G,44425,nil,'Arcane Barrage when Blast cannot be cast');s.usable[30451]=nil
 s.points=4;s.buff('player',1242974,{applications=25});M.expect(a,s,G,44425,nil,'Barrage at four charges and 25 Salvo')
 s.clearAuras();s.buff('player',1242974,{applications=12});s.buff('player',263725);M.expect(a,s,G,44425,nil,'Barrage at 12 Salvo with Clearcasting')
 s.clearAuras();s.buff('player',1242974,{applications=5});s.buff('player',263725);M.expect(a,s,G,5143,nil,'Missiles on Clearcasting below 12 Salvo')
 s.clearAuras();s.buff('player',451038);M.expect(a,s,G,44425,nil,'Barrage with Arcane Soul')
 s.points=1;M.expect(a,s,G,44425,nil,'Arcane Soul: Barrage below four charges too (SimulationCraft)')
 s.clearAuras();s.buff('player',1242974,{applications=25});M.expect(a,s,G,30451,nil,'25 Salvo below four charges: no Barrage (Orb and Pulse cooling)')
 s.clearAuras();s.points=1;s.cooldown={};s.near(3);M.expect(a,s,G,153626,nil,'Orb on packs too')
 s.cooling(153626,10);M.expect(a,s,G,1241462,nil,'Pulse on three enemies');s.near(0)
 local lit=M.upkeep(a,s,G);s.learn(321507,365350,12051,205025);lit=M.upkeep(a,s,G)
 assert(lit[365350]and not lit[321507],'Arcane Surge; Touch of the Magi waits for a Barrage')
 s.history(44425,1);s.buff('player',365362);lit=M.upkeep(a,s,G);assert(lit[321507],'Touch of the Magi after a Barrage in Arcane Surge')
 s.points=0;lit=M.upkeep(a,s,G);assert(lit[205025],'Presence of Mind at zero charges after a Barrage')
 s.clearAuras();s.learn(12051);s.mana.player=5;lit=M.upkeep(a,s,G);assert(not lit[12051],'Evocation is yours (mana is secret)')
end)
test('Arcane reference, Spellslinger: Salvo 20 Barrage (four charges on two or more enemies), Missiles below 15, Orb and Pulse below three charges',function()
 local a,s=mage(ARCANE);local G=P..'arcane.guide';enable(a,G)
 s.learn(443739,30451,44425,5143,153626,1241462)
 s.points=3;M.expect(a,s,G,30451,nil,'three charges: Arcane Blast')
 s.buff('player',1242974,{applications=20});M.expect(a,s,G,44425,nil,'Barrage at 20 Salvo')
 s.near(2);M.expect(a,s,G,30451,nil,'20 Salvo on two enemies below four charges: no Barrage')
 s.points=4;M.expect(a,s,G,44425,nil,'20 Salvo on two enemies at four charges: Barrage');s.near(0);s.points=3
 s.clearAuras();s.buff('player',1242974,{applications=14});s.buff('player',263725);M.expect(a,s,G,5143,nil,'Missiles below 15 Salvo')
 s.clearAuras();s.points=1;M.expect(a,s,G,153626,nil,'Orb below three charges')
 s.cooling(153626,10);M.expect(a,s,G,1241462,nil,'Pulse below three charges outside Surge')
 s.buff('player',365362);M.expect(a,s,G,30451,nil,'no Pulse in Arcane Surge')
end)
test('Fire reference: Fire Blast while casting, pull, procs by spender, Combustion window, Scorch, filler',function()
 local a,s,f=mage(FIRE);local G=P..'fire.guide';enable(a,G)
 s.learn(11366,2120,108853,2948,133,431044,153561)
 s.cast=true;s.castSpell=133;M.expect(a,s,G,nil,'stopped','casting without Heating Up')
 s.buff('player',48107);M.expect(a,s,G,108853,nil,'Fire Blast while casting with Heating Up')
 s.castSpell=8690;M.expect(a,s,G,nil,'stopped','a Hearthstone cast is no Fire hard cast');s.castSpell=nil
 M.expect(a,s,G,nil,'stopped','an unnamed cast either');s.cast=false;s.clearAuras()
 s.combat=false;M.expect(a,s,G,11366,nil,'pull: Pyroblast');s.combat=true
 M.expect(a,s,G,153561,nil,'Meteor');s.cooling(153561,30)
 M.expect(a,s,G,431044,nil,'Frostfire Bolt filler');s.known[431044]=nil;M.expect(a,s,G,133,nil,'Fireball without Frostfire')
 s.buff('player',48108);M.expect(a,s,G,11366,nil,'Pyroblast on Hot Streak')
 s.near(4);M.expect(a,s,G,2120,nil,'Flamestrike on Hot Streak with four enemies');s.near(0);s.clearAuras()
 s.buff('player',269651);s.buff('player',48107);M.expect(a,s,G,11366,nil,'Pyroclasm before Fire Blast outside Combustion')
 s.buff('player',190319);M.expect(a,s,G,108853,nil,'inside Combustion Fire Blast comes first');s.clearAuras()
 s.buff('player',458964);M.expect(a,s,G,2948,nil,'Scorch on Heat Shimmer');s.clearAuras()
 s.moving=true;M.expect(a,s,G,2948,nil,'Scorch on the move');s.moving=false
 s.buff('player',383874);M.expect(a,s,G,11366,nil,'Pyroblast on Hyperthermia');s.clearAuras()
 s.learn(190319);local lit=M.upkeep(a,s,G);assert(not lit[190319],'Combustion outside a hard cast')
 s.cast=true;s.castSpell=11366;lit=M.upkeep(a,s,G);assert(not lit[190319],'Combustion with two seconds of the cast left')
 -- The model's cast ends at 102 s; a cast ending in half a second is the Combustion window.
 f.env.UnitCastingInfo=function(unit)if unit=='player'then return 'Fireball','Fireball',1,99000,100500,false,'cast-guid',false,133 end end
 lit=M.upkeep(a,s,G);assert(lit[190319],'Combustion as a hard cast finishes')
end)
test('Frost reference: Frostfire and Spellslinger orders, AoE, movement, filler',function()
 local a,s=mage(FROST);local G=P..'frost.guide';enable(a,G)
 s.learn(116,44614,30455,84714,199786,205021,153595,190356,157997,120)
 s.combat=false;M.expect(a,s,G,116,nil,'pull: Frostbolt');s.combat=true
 M.expect(a,s,G,153595,nil,'Spellslinger: Comet Storm first');s.cooling(153595,20)
 s.buff('player',190446);M.expect(a,s,G,44614,nil,'Flurry on Brain Freeze');s.buff('player',1247730)
 M.expect(a,s,G,84714,nil,'no Brain Freeze Flurry under Thermal Void');s.clearAuras()
 s.buff('player',44544,{applications=2});M.expect(a,s,G,30455,nil,'Ice Lance on two Fingers of Frost');s.clearAuras()
 s.cooling(84714,30);s.cooling(205021,30);s.debuff('target',1221389,{applications=6});M.expect(a,s,G,30455,nil,'Spellslinger Ice Lance at six Freezing')
 s.clearAuras();s.cooling(44614,10);M.expect(a,s,G,199786,nil,'Glacial Spike filler when usable');s.usable[199786]=false
 M.expect(a,s,G,116,nil,'Frostbolt filler');s.moving=true;M.expect(a,s,G,30455,nil,'Ice Lance on the move');s.moving=false
 s.near(4);M.expect(a,s,G,157997,nil,'Spellslinger: Ice Nova on four');s.near(0)
 s.learn(431044);s.cooldown={};s.usable[199786]=nil
 s.buff('player',199844);M.expect(a,s,G,199786,nil,'Frostfire: Glacial Spike when ready');s.clearAuras()
 M.expect(a,s,G,153595,nil,'Frostfire: Comet Storm on one target')
 s.near(3);M.expect(a,s,G,205021,nil,'Frostfire: no Comet Storm on three, Ray of Frost');s.near(0)
 s.cooling(153595,20);s.cooling(205021,30);s.cooling(84714,30);s.debuff('target',1221389,{applications=6})
 M.expect(a,s,G,44614,nil,'Frostfire: six Freezing is not enough, Flurry')
 s.debuff('target',1221389,{applications=12});s.clearAuras();s.debuff('target',1221389,{applications=12});M.expect(a,s,G,30455,nil,'Frostfire: Ice Lance at twelve Freezing')
 s.clearAuras();s.buff('player',270232);s.near(3);M.expect(a,s,G,190356,nil,'Blizzard on Freezing Rain with three enemies');s.near(0);s.clearAuras()
 s.cooling(44614,10);s.usable[199786]=false;M.expect(a,s,G,431044,nil,'Frostfire Bolt filler')
end)
test('on the real restricted Retail client every Mage premade is complete and the recommended premade auto-selects',function()
 M.restricted('mage','MAGE',ids)
end)
test('before a specialization (initial spec 1449) a level-4 Mage gets the Blizzard Assisted premade, complete',function()
 M.initial('mage','MAGE',1449,P..'initial',{116})
end)
finish()
