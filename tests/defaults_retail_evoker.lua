-- Retail Evoker premades: per-spec storage, auto-select, the Blizzard Assisted step, the Icy Veins
-- Ebon Might list (readable in combat), the reference priorities, Stops and reminders through the
-- real catalog, predicates, composition and sequence executor on a modeled Retail client (probe
-- policy; the last test keeps the real restricted policy). C_AssistedCombat is a model of
-- Blizzard's documented API.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/retail_premade_model_a.lua')
local DEV,AUG,PRES=1467,1473,1468
local P='rm.retail.evoker.'
local ids={[DEV]={P..'devastation',P..'devastation.guide'},[AUG]={P..'augmentation',P..'augmentation.assisted'},[PRES]={P..'preservation'}}
local enabledByDefault={[P..'devastation']=true,[P..'augmentation']=true,[P..'augmentation.assisted']=true}
local function evoker(spec,level)
 local f,s=M.new('evoker','EVOKER',spec);local a=f.addon
 s.setLevel(level or 90);s.powerType=0;s.targetRange={20,25}
 s.ranged(351338,361469,362969,356995,357211,409311,395160,1292321,360827,369459)
 return a,s,f
end
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end
test('every Evoker premade loads for its own specialization only and declares Retail',function()
 for spec,list in pairs(ids)do
  local a=evoker(spec);local rows=M.rows(a)
  for _,id in ipairs(list)do
   local row=assert(rows[id],id);local scope=row.applicability
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.class=='EVOKER',id)
   assert(#scope.specs==1 and scope.specs[1]==spec and scope.minLevel==10 and scope.maxLevel==90,id..' scope')
   assert(row.eligible==(enabledByDefault[id]==true),id..' default enablement')
  end
  for other,list2 in pairs(ids)do if other~=spec then for _,id in ipairs(list2)do assert(rows[id]==nil or not rows[id].eligible,id..' eligible in spec '..spec)end end end
 end
end)
test('auto-select: Assisted for Devastation, the Icy Veins Ebon Might list for Augmentation, nothing for Preservation',function()
 local a=evoker(DEV);assert(M.selected(a)==P..'devastation',tostring(M.selected(a)))
 enable(a,P..'devastation.guide');assert(M.selected(a)==P..'devastation','the reference outranked Assisted')
 a=evoker(AUG);assert(M.selected(a)==P..'augmentation','Augmentation: '..tostring(M.selected(a)))
 assert(M.switch(a,P..'augmentation.assisted')=='match')
 assert(a:SetDefaultRotationEnabled(P..'augmentation',false));assert(M.selected(a)==P..'augmentation.assisted','the Assisted alternative is the fallback')
 a=evoker(PRES);assert(M.selected(a)==nil,'Preservation is reference only')
 assert(M.selected(evoker(DEV,9))==nil,'below level 10')
end)
test('Assisted: follows the suggestion, falls through, waits on casts, channels and empowers',function()
 for _,id in ipairs({P..'devastation',P..'augmentation.assisted'})do
  local spec=id:find('devastation')and DEV or AUG
  local a,s=evoker(spec);s.learn(356995,361469,357208)
  s.suggest=356995;M.expect(a,s,id,356995,nil,'suggested Disintegrate')
  assert(s.assistedCheck==false)
  s.suggest=361469;M.expect(a,s,id,361469,nil,'a new suggestion is followed')
  s.suggest=nil;M.expect(a,s,id,nil,nil,'nothing suggested')
  s.suggest=357208;s.channel=true;M.expect(a,s,id,nil,'stopped','empowering Fire Breath reads as a channel');s.channel=false
  s.cast=true;M.expect(a,s,id,nil,'stopped','casting');s.cast=false
  s.cooling(357208,10);M.expect(a,s,id,nil,nil,'a cooling suggestion');s.cooldown={}
  s.assisted=false;M.expect(a,s,id,nil,nil,'Assisted Combat unavailable')
 end
end)
test('Assisted in Midnight combat: advice and cooldown highlights survive secrets; hidden-data reminders stay dark',function()
 local a,s=evoker(DEV);s.learn(356995,375087,357210,370553,351338,363916)
 s.secrets();s.suggest=356995
 M.expect(a,s,P..'devastation',356995,nil,'suggestion with secret data')
 s.health.player=20;s.targetCast=true
 local lit=M.upkeep(a,s,P..'devastation')
 assert(lit[375087]and lit[357210]and lit[370553],'cooldowns did not light on the readable flags')
 assert(lit[363916],'Obsidian Scales did not light on the readable cooldown flag')
 assert(not lit[351338],'a reminder gated on hidden enemy casts lit')
 s.secrets(false);lit=M.upkeep(a,s,P..'devastation')
 assert(lit[363916]and lit[351338],'Obsidian Scales and Quell did not light where readable')
 s.cooling(375087,60);lit=M.upkeep(a,s,P..'devastation');assert(not lit[375087],'a cooling Dragonrage lit')
end)
test('utility: Blessing of the Bronze and Source of Magic out of combat',function()
 local a,s=evoker(PRES);s.learn(364342,369459)
 s.combat=false;local lit=M.upkeep(a,s,P..'preservation');assert(lit[364342]and not lit[369459],'Bronze missing; no friendly target')
 s.buff('player',381748);s.group=true;s.friendly=true;s.hostile=false;lit=M.upkeep(a,s,P..'preservation')
 assert(not lit[364342]and lit[369459],'Bronze up; Source of Magic on a friendly group target')
 s.auras.target.HELPFUL[1]={spellId=369459,name='Spell 369459',sourceUnit='player'};lit=M.upkeep(a,s,P..'preservation');assert(not lit[369459],'Source of Magic already on the target')
 s.combat=true;s.clearAuras();lit=M.upkeep(a,s,P..'preservation');assert(not lit[364342],'Bronze in combat')
end)
test('Augmentation (Icy Veins): Ebon Might upkeep, Prescience, empowers, Eruption, filler; pull',function()
 local a,s=evoker(AUG);local G=P..'augmentation'
 s.learn(395152,409311,357208,396286,395160,362969,361469,403631,360827)
 M.expect(a,s,G,395152,nil,'Ebon Might when missing')
 s.buff('player',395296,{expirationTime=103});M.expect(a,s,G,395152,nil,'Ebon Might under 4 s')
 s.clearAuras();s.buff('player',395296,{expirationTime=108});M.expect(a,s,G,409311,nil,'Breath of Eons ready: no early Ebon Might; Prescience')
 s.cooling(403631,60);M.expect(a,s,G,395152,nil,'Ebon Might on cooldown once Breath of Eons is cooling')
 s.cooling(395152,20);s.cooling(409311,5);M.expect(a,s,G,357208,nil,'Fire Breath');s.cooling(357208,20)
 M.expect(a,s,G,396286,nil,'Upheaval');s.cooling(396286,20)
 M.expect(a,s,G,395160,nil,'Eruption in Ebon Might')
 s.clearAuras();s.buff('player',392268,{applications=2});M.expect(a,s,G,395160,nil,'Eruption on two Essence Bursts')
 s.clearAuras();s.cooldown={[395152]=20,[409311]=5,[357208]=20,[396286]=20,[403631]=60}
 M.expect(a,s,G,362969,nil,'Azure Strike without Ebon Might or Essence Burst')
 s.combat=false;s.hostile=false;s.friendly=true;s.group=true;M.expect(a,s,G,360827,nil,'pull: Blistering Scales on the friendly target')
 s.friendly=false;s.hostile=true;M.expect(a,s,G,361469,nil,'pull: Living Flame')
end)
test('Augmentation in Midnight combat: whitelisted Ebon Might stays readable, hidden auras skip their step',function()
 local a,s=evoker(AUG);local G=P..'augmentation'
 s.learn(395152,409311,357208,396286,395160,362969,403631,370553,404977)
 s.secrets();s.cooldown={[403631]=60,[409311]=5,[357208]=20,[396286]=20}
 s.buff('player',395296,{whitelisted=true,expirationTime=103})
 M.expect(a,s,G,395152,nil,'Ebon Might refresh read in combat')
 s.clearAuras();s.buff('player',395296,{whitelisted=true,expirationTime=108});s.cooling(395152,20)
 M.expect(a,s,G,395160,nil,'Eruption in Ebon Might in combat')
 s.clearAuras();s.buff('player',392268,{applications=2});M.expect(a,s,G,362969,nil,'hidden Essence Burst: the Eruption step is skipped, not the rotation')
 local lit=M.upkeep(a,s,G);assert(lit[404977]and not lit[370553],'Time Skip with both empowers cooling, no Tip the Scales')
 s.cooldown[357208]=nil;lit=M.upkeep(a,s,G);assert(lit[370553]and not lit[404977],'Tip the Scales with Fire Breath ready')
end)
test('Devastation reference: hero trees, Mass Disintegrate, Pyre, procs, moving and the pull',function()
 local a,s=evoker(DEV);local G=P..'devastation.guide';enable(a,G)
 s.learn(359073,357208,356995,357211,361469,362969,1292321,357210)
 s.combat=false;M.expect(a,s,G,361469,nil,'pull: Living Flame');s.combat=true
 M.expect(a,s,G,359073,nil,'Flameshaper: Eternity Surge');s.cooling(359073,20)
 M.expect(a,s,G,357208,nil,'Fire Breath with its burn missing')
 s.debuff('target',357209,{expirationTime=110});M.expect(a,s,G,356995,nil,'burn ticking: Disintegrate');s.clearAuras()
 s.cooling(357208,20);s.near(5);M.expect(a,s,G,357211,nil,'Pyre on five');s.near(0)
 s.usable[356995]=false;M.expect(a,s,G,1292321,nil,'Unbound Flame')
 s.cooling(1292321,10);s.buff('player',375802);s.buff('player',370901);M.expect(a,s,G,361469,nil,'Burnout with Leaping Flames');s.clearAuras()
 s.buff('player',1265871);M.expect(a,s,G,362969,nil,'Azure Sweep');s.clearAuras()
 s.moving=true;M.expect(a,s,G,362969,nil,'Azure Strike on the move');s.moving=false
 M.expect(a,s,G,361469,nil,'Living Flame filler');s.usable[356995]=nil;s.cooldown={}
 s.learn(436335);M.expect(a,s,G,359073,nil,'Scalecommander: Eternity Surge');s.cooling(359073,20)
 M.expect(a,s,G,357208,nil,'Scalecommander: Fire Breath');s.cooling(357208,20)
 s.near(2);M.expect(a,s,G,357210,nil,'Scalecommander: Deep Breath on two');s.near(0);s.cooling(357210,60)
 s.buff('player',436336);s.near(5);M.expect(a,s,G,356995,nil,'Mass Disintegrate stacks before Pyre');s.clearAuras()
 M.expect(a,s,G,357211,nil,'Pyre on five');s.near(0)
 s.buff('player',359618,{applications=2});s.usable[356995]=false;M.expect(a,s,G,361469,nil,'no Unbound Flame at two Essence Bursts');s.clearAuras()
 local lit=M.upkeep(a,s,G);s.learn(375087,370553);lit=M.upkeep(a,s,G)
 assert(lit[375087]and not lit[370553]and lit[357210]==nil,'Tip the Scales waits for Dragonrage or Fire Breath')
 s.cooldown[357208]=nil;lit=M.upkeep(a,s,G);assert(lit[370553],'Tip the Scales with Fire Breath ready')
 s.cooldown[357210]=nil;lit=M.upkeep(a,s,G);assert(lit[357210],'Scalecommander: Deep Breath highlight')
end)
test('Preservation reference: damage filler on an enemy only',function()
 local a,s=evoker(PRES);local G=P..'preservation';enable(a,G)
 s.learn(357208,356995,361469,362969)
 M.expect(a,s,G,357208,nil,'Fire Breath');s.cooling(357208,20)
 M.expect(a,s,G,356995,nil,'Disintegrate')
 s.moving=true;M.expect(a,s,G,362969,nil,'Azure Strike on the move');s.moving=false
 s.hostile=false;s.friendly=true;M.expect(a,s,G,nil,'stopped','no advice on a friendly target')
end)
test('on the real restricted Retail client every Evoker premade is complete and the recommended premade auto-selects',function()
 M.restricted('evoker','EVOKER',ids,{[PRES]=false})
end)
test('before a specialization (initial spec 1465) a level-4 Evoker gets the Blizzard Assisted premade, complete',function()
 M.initial('evoker','EVOKER',1465,P..'initial',{361469})
end)
finish()
