-- Retail Druid premades: per-spec storage, auto-select, the Blizzard Assisted step, the reference
-- priorities, Restoration's friendly/hostile split, Stops and reminders through the real catalog,
-- predicates, composition and sequence executor on a modeled Retail client (probe policy; the last
-- test keeps the real restricted policy). C_AssistedCombat is a model of Blizzard's documented API.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_a.lua')
local BALANCE,FERAL,GUARDIAN,RESTO=102,103,104,105
local P='rm.retail.druid.'
local ids={[BALANCE]={P..'balance',P..'balance.guide'},[FERAL]={P..'feral',P..'feral.guide'},
 [GUARDIAN]={P..'guardian',P..'guardian.guide',P..'guardian.simc'},[RESTO]={P..'restoration'}}
local power={[BALANCE]=8,[FERAL]=3,[GUARDIAN]=1,[RESTO]=0}
local function druid(spec,level)
 local f,s=M.new('druid','DRUID',spec);local a=f.addon
 s.setLevel(level or 90);s.powerType=power[spec];s.energy=50;s.points=0
 s.ranged(78675,106839,8921,93402,5176,194153,78674,155625,33763,774,8936,18562,48438)
 -- Party members party1..n at the given health percentages (group implied).
 s.members=s.members or function(...)s.party={};s.group=true;for i,hp in ipairs({...})do s.party['party'..i]={health=hp}end end
 return a,s,f
end
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end
test('every Druid premade loads for its own specialization only and declares Retail',function()
 for spec,list in pairs(ids)do
  local a=druid(spec);local rows=M.rows(a)
  for index,id in ipairs(list)do
   local row=assert(rows[id],id);local scope=row.applicability
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.class=='DRUID',id)
   assert(#scope.specs==1 and scope.specs[1]==spec and scope.minLevel==10 and scope.maxLevel==90,id..' scope')
   assert(row.eligible==(index==1),id..' eligibility: only the recommended premade is on by default')
  end
  for other,list2 in pairs(ids)do if other~=spec then for _,id in ipairs(list2)do assert(rows[id]==nil or not rows[id].eligible,id..' eligible in spec '..spec)end end end
 end
end)
test('auto-select: the recommended premade in each spec slot; an enabled reference runs but never outranks it',function()
 for spec,list in pairs(ids)do
  local a=druid(spec);assert(M.selected(a)==list[1],'spec '..spec..': '..tostring(M.selected(a)))
  for _,id in ipairs(list)do assert(M.switch(a,id)=='match',id..' switch')end
  if list[2]then enable(a,list[2]);assert(M.rows(a)[list[2]].eligible,'an enabled reference is not runnable');assert(M.selected(a)==list[1],'the reference outranked the recommended premade')end
  local low=druid(spec,9);assert(M.selected(low)==nil,'level 9 has no specialization premade')
 end
end)
test('Assisted: follows the suggestion, falls through when there is none, waits on casts and channels',function()
 for _,spec in ipairs({BALANCE,FERAL,GUARDIAN})do
  local id=ids[spec][1];local a,s=druid(spec);s.learn(5176,5221,33917)
  s.suggest=5176;M.expect(a,s,id,5176,nil,'suggested Wrath')
  assert(s.assistedCheck==false,'suggestion not read with checkForVisibleButton=false')
  s.suggest=5221;M.expect(a,s,id,5221,nil,'a new suggestion is followed')
  s.suggest=nil;M.expect(a,s,id,nil,nil,'nothing suggested')
  s.suggest=12345;M.expect(a,s,id,nil,nil,'an unknown suggestion is skipped')
  s.suggest=5176;s.cast=true;M.expect(a,s,id,nil,'stopped','casting');s.cast=false
  s.channel=true;M.expect(a,s,id,nil,'stopped','channelling (Convoke)');s.channel=false
  s.cooling(5176,5);M.expect(a,s,id,nil,nil,'a cooling suggestion is not recommended');s.cooldown={}
  s.assisted=false;M.expect(a,s,id,nil,nil,'Assisted Combat unavailable')
 end
end)
test('Assisted reminders: forms between pulls, Mark of the Wild, interrupts, Ironfur and defensives',function()
 local a,s=druid(GUARDIAN);s.learn(5487,1126,192081,22842,61336,106839,22812,26297)
 local G=P..'guardian'
 s.combat=false;local lit=M.upkeep(a,s,G);assert(lit[5487]and lit[1126]and not lit[192081],'out of combat: Bear Form and Mark of the Wild')
 s.buff('player',5487);s.buff('player',1126,{sourceUnit='party1'});lit=M.upkeep(a,s,G);assert(not lit[5487]and not lit[1126],'form and Mark already up')
 s.combat=true;lit=M.upkeep(a,s,G);assert(lit[192081]and lit[26297]and not lit[22842]and not lit[22812],'in combat: Ironfur and racial, no defensives at full health')
 s.health.player=30;s.targetCast=true;lit=M.upkeep(a,s,G);assert(lit[22842]and lit[61336]and lit[22812]and lit[106839],'low health and an enemy cast')
 local b,t=druid(BALANCE);t.learn(24858,78675);t.combat=false;lit=M.upkeep(b,t,P..'balance');assert(lit[24858],'Moonkin Form between pulls')
 t.buff('player',102560);lit=M.upkeep(b,t,P..'balance');assert(not lit[24858],'Incarnation is a Moonkin Form')
 local c,u=druid(FERAL);u.learn(768,61336);u.combat=false;lit=M.upkeep(c,u,P..'feral');assert(lit[768],'Cat Form between pulls')
 u.combat=true;u.learn(106951);u.secrets();assert(M.upkeep(c,u,P..'feral')[106951],'Berserk, outside Assisted Combat, in combat')
 t.combat=true;t.learn(194223);t.secrets();assert(M.upkeep(b,t,P..'balance')[194223],'Celestial Alignment, outside Assisted Combat, in combat')
 s.learn(50334,391528);lit=M.upkeep(a,s,G);assert(lit[50334]and lit[391528],'Guardian Berserk and Convoke, outside Assisted Combat')
end)
test('Assisted in Midnight combat: secret data still gives advice; hidden-data reminders stay dark',function()
 local a,s=druid(GUARDIAN);s.learn(33917,192081,22842,106839,26297)
 s.secrets();s.suggest=33917
 M.expect(a,s,P..'guardian',33917,nil,'suggestion with secret data')
 s.cooling(33917,4);M.expect(a,s,P..'guardian',nil,nil,'cooling by the never-secret flag');s.cooldown={}
 s.health.player=20;s.targetCast=true
 local lit=M.upkeep(a,s,P..'guardian')
 assert(lit[192081]and lit[26297],'in-combat reminders did not light on the readable cooldown flags')
 assert(not lit[22842]and not lit[106839],'a reminder gated on hidden health or enemy casts lit')
 s.secrets(false);lit=M.upkeep(a,s,P..'guardian');assert(lit[22842]and lit[106839],'readable again')
end)
test('Balance reference: pull, DoTs, Eclipse, spenders on procs and cap, Moons, filler by Eclipse',function()
 local a,s=druid(BALANCE);local G=P..'balance.guide';enable(a,G)
 s.learn(24858,5176,194153,93402,8921,78674,191034,1233346,1233272,274281)
 s.combat=false;M.expect(a,s,G,24858,nil,'pull: Moonkin Form');s.buff('player',24858);M.expect(a,s,G,5176,nil,'pull: Wrath');s.combat=true
 M.expect(a,s,G,93402,nil,'Sunfire missing');s.debuff('target',164815,{expirationTime=103})
 M.expect(a,s,G,93402,nil,'Sunfire in its pandemic window');s.clearAuras();s.buff('player',24858)
 s.debuff('target',164815,{expirationTime=200});M.expect(a,s,G,8921,nil,'Moonfire missing');s.debuff('target',164812,{expirationTime=200})
 M.expect(a,s,G,1233346,nil,'single target: Solar Eclipse')
 s.near(3);M.expect(a,s,G,1233272,nil,'three enemies: Lunar Eclipse')
 s.buff('player',48518);M.expect(a,s,G,191034,nil,'packs: Starfall');s.near(0)
 M.expect(a,s,G,274281,nil,'New Moon');s.cooling(274281,10)
 M.expect(a,s,G,194153,nil,'Lunar Eclipse: Starfire');s.auras.player.HELPFUL[2]={spellId=48517,name='x',sourceUnit='player'}
 s.buff('player',393944);M.expect(a,s,G,78674,nil,'Starsurge on Starweaver\'s Weft')
 s.clearAuras();s.buff('player',24858);s.buff('player',48517);s.debuff('target',164815,{expirationTime=200});s.debuff('target',164812,{expirationTime=200})
 s.energy=90;M.expect(a,s,G,78674,nil,'Starsurge before Astral Power caps');s.energy=20
 M.expect(a,s,G,5176,nil,'Solar Eclipse: Wrath')
 s.buff('player',393942);M.expect(a,s,G,191034,nil,'Starfall on Starweaver\'s Warp')
end)
test('Feral reference: opener, Apex, five-point finishers and pooling, bleeds and builders',function()
 local a,s=druid(FERAL);local G=P..'feral.guide';enable(a,G)
 s.learn(768,5215,1822,1079,22568,5221,213764,285381)
 s.combat=false;M.expect(a,s,G,768,nil,'pull: Cat Form');s.buff('player',768)
 M.expect(a,s,G,5215,nil,'pull: Prowl');s.stealthed=true;M.expect(a,s,G,1822,nil,'pull: Rake from stealth');s.stealthed=false;s.combat=true
 M.expect(a,s,G,1822,nil,'Rake missing');s.debuff('target',155722,{expirationTime=200})
 M.expect(a,s,G,5221,nil,'Shred filler')
 s.buff('player',391882);M.expect(a,s,G,22568,nil,'Bite on Apex Predator\'s Craving');s.clearAuras();s.buff('player',768);s.debuff('target',155722,{expirationTime=200})
 s.points=5;M.expect(a,s,G,1079,nil,'five points: Rip missing')
 s.debuff('target',1079,{expirationTime=200});M.expect(a,s,G,22568,nil,'five points: Ferocious Bite')
 s.usable[22568]=false;M.expect(a,s,G,nil,'stopped','five points: pool for the finisher');s.usable[22568]=nil
 s.near(2);M.expect(a,s,G,285381,nil,'two enemies: Primal Wrath');s.near(0)
 s.points=2;s.near(3);M.expect(a,s,G,213764,nil,'three enemies: Swipe');s.near(0)
 s.learn(5217);s.energy=40;local lit=M.upkeep(a,s,G);assert(lit[5217],'Tiger\'s Fury 50 below the energy cap')
 s.energy=80;lit=M.upkeep(a,s,G);assert(not lit[5217],'Tiger\'s Fury waits at high energy and few points')
 s.learn(106951,274837);s.buff('player',5217);lit=M.upkeep(a,s,G);assert(lit[106951]and lit[274837],'Berserk and Feral Frenzy in Tiger\'s Fury')
end)
test('Guardian references: Thrash, Mangle, Red Moon, Galactic Guardian, rage spenders; SimC Ironfur first',function()
 local a,s=druid(GUARDIAN);local G=P..'guardian.guide';enable(a,G)
 s.learn(77758,33917,1252871,8921,6807,213771)
 M.expect(a,s,G,77758,nil,'Thrash');s.cooling(77758,4)
 M.expect(a,s,G,33917,nil,'Mangle');s.cooling(33917,4)
 M.expect(a,s,G,1252871,nil,'Red Moon on one target');s.cooling(1252871,20)
 M.expect(a,s,G,8921,nil,'Moonfire missing');s.debuff('target',164812)
 s.buff('player',213708);M.expect(a,s,G,8921,nil,'Moonfire on Galactic Guardian');s.clearAuras();s.debuff('target',164812)
 s.energy=85;M.expect(a,s,G,6807,nil,'Maul above 80 rage');s.energy=30
 M.expect(a,s,G,213771,nil,'Swipe filler')
 s.learn(192081);local lit=M.upkeep(a,s,G);assert(not lit[192081],'Ironfur under 40 rage');s.energy=45;lit=M.upkeep(a,s,G);assert(lit[192081],'Ironfur at 40 rage')
 local b,t=druid(GUARDIAN);local S=P..'guardian.simc';enable(b,S)
 t.learn(192081,77758,33917,1252871,6807,213771,8921);t.energy=45
 M.expect(b,t,S,192081,nil,'SimC: Ironfur at 40 rage');t.energy=20
 M.expect(b,t,S,77758,nil,'SimC: Thrash missing');t.debuff('target',192090,{applications=3,expirationTime=200})
 t.buff('player',1307881);M.expect(b,t,S,6807,nil,'SimC: Maul on Gory Fur');t.clearAuras();t.debuff('target',192090,{applications=3,expirationTime=200})
 M.expect(b,t,S,1252871,nil,'SimC: Red Moon');t.debuff('target',1252871)
 M.expect(b,t,S,33917,nil,'SimC: Mangle while Red Moon ticks')
end)
test('Restoration: Assisted damage on an enemy, maintenance heals on a friend, hidden health in combat',function()
 local a,s=druid(RESTO);local R=P..'restoration'
 s.learn(5176,33763,145205,18562,48438,8936,774)
 s.suggest=5176;M.expect(a,s,R,5176,nil,'hostile target: Blizzard\'s suggestion')
 s.hostile=false;s.friendly=true;s.health.target=60
 M.expect(a,s,R,33763,nil,'friendly target: Lifebloom');s.auras.target.HELPFUL[1]={spellId=33763,name='x',sourceUnit='player'}
 M.expect(a,s,R,145205,nil,'Efflorescence in combat');s.buff('player',145205)
 M.expect(a,s,R,774,nil,'Rejuvenation on a hurt ally');s.auras.target.HELPFUL[2]={spellId=774,name='x',sourceUnit='player'}
 M.expect(a,s,R,18562,nil,'Swiftmend on a Rejuvenation')
 s.cooling(18562,10);s.buff('player',16870);M.expect(a,s,R,8936,nil,'Regrowth on Clearcasting');s.cooldown={}
 s.members(50,60,70);s.cooling(18562,10);M.expect(a,s,R,48438,nil,'Wild Growth on three hurt allies');s.cooldown={}
 s.secrets();s.party={};M.expect(a,s,R,nil,nil,'hidden HoTs and health: the healing steps stay dark')
 s.secrets(false);s.hostile=true;s.friendly=false;s.secrets();M.expect(a,s,R,5176,nil,'hostile target in Midnight combat: suggestion')
 s.learn(29166);s.secrets(false);s.mana.player=50;local lit=M.upkeep(a,s,R);assert(lit[29166],'Innervate below 75% mana')
end)
test('on the real restricted Retail client the Druid premades are listed but never auto-selected',function()
 M.restricted('druid','DRUID',ids)
end)
finish()
