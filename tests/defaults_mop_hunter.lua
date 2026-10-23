-- Mists of Pandaria Classic Hunter premades: switches, priorities, boundaries and reminders through
-- the real catalog, predicates, composition and sequence executor on a modeled 5.5.4 client.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/mop_premade_model_a.lua')
local BM,MM,MMIV,SV,BASE='rm.mop.hunter.beastmastery','rm.mop.hunter.marksmanship','rm.mop.hunter.marksmanship.icyveins','rm.mop.hunter.survival','rm.mop.hunter.unspecialized'
-- Spells.
local AUTO,ARCANE,STEADY,STING,MARK,MULTI,KILLSHOT,TRAP,COBRA=75,3044,56641,1978,1130,2643,53351,13813,77767
local KC,FOCUSFIRE,WRATH,AIMED,CHIMERA,EXPLOSIVE,ARROW=34026,82692,19574,19434,53209,53301,3674
local CALLPET,REVIVE,MEND,HAWK,IRONHAWK,COUNTER,SILENCING,FERVOR,RAPID,STAMPEDE=883,982,136,13165,109260,147362,34490,82726,3045,121818
local CROWS,DIREBEAST,GLAIVE=131894,120679,117050
-- Auras.
local STINGDEBUFF,CLEAVE,FRENZY,THRILL,FIRE,STEADYFOCUS,LNL=118253,118455,19615,34720,82926,53220,56453
-- A level-90 Hunter with a pet, focus as the primary bar; the target forecast to live s.ttd seconds.
local function hunter(level)
 local f,s=M.new('hunter');local a=f.addon
 s.powerType=2;s.energy=100;s.pet=true;s.setLevel(level or 90);s.targetRange={30,35};s.ttd=60
 a.GetConditionHealthForecast=function()if s.ttd==nil then return nil,'no-forecast'end;return s.ttd end
 return a,s,f
end
test('the Hunter premades load, validate and declare Mists of Pandaria Classic only',function()
 M.scope('hunter',{BASE},1);M.scope('hunter',{BM,MM,SV},10)
 local a=hunter();local row=M.row(a,MMIV);local scope=row.applicability
 assert(row.readOnly and not row.eligible and row.eligibilityReason=='disabled','the Arcane dump variant ships disabled')
 assert(scope.minExpansion==4 and scope.maxExpansion==4 and scope.minLevel==10 and scope.maxLevel==90 and scope.families[1]=='progression')
 local priorities={};for id,r in pairs(M.rows(a))do priorities[id]=r.envelope.body.priority end
 assert(priorities[BASE]<priorities[MMIV]and priorities[MMIV]<priorities[MM]and priorities[BM]==priorities[MM]and priorities[SV]==priorities[MM])
end)
test('switch: the catch-all until a signature spell; Kill Command, Aimed Shot and Explosive Shot pick the specialization',function()
 local a,s=hunter(1);s.learn(ARCANE);assert(M.selected(a)==BASE,'level 1')
 s.setLevel(10);assert(M.selected(a)==BASE,'level 10 with no specialization')
 s.learn(KC);assert(M.selected(a)==BM,'Kill Command is Beast Mastery')
 s.forget(KC);s.learn(AIMED);assert(M.selected(a)==MM,'Aimed Shot is Marksmanship')
 assert(M.switch(a,MMIV)=='match','the Arcane dump variant shares the Marksmanship switch')
 s.forget(AIMED);s.learn(EXPLOSIVE);assert(M.selected(a)==SV,'Explosive Shot is Survival')
 s.setLevel(90);assert(M.selected(a)==SV,'level 90 Survival')
 s.known={};assert(M.selected(a)==BASE,'a Hunter with nothing learned still gets a premade')
end)
test('unspecialized: boundaries, pull, sting, Arcane, Steady, Auto Shot',function()
 local a,s=hunter(1);s.learn(ARCANE,AUTO)
 s.combat=false;M.expect(a,s,BASE,ARCANE,nil,'level 1 pull: Arcane Shot')
 s.energy=10;s.usable[ARCANE]=false;M.expect(a,s,BASE,AUTO,nil,'pull: Auto Shot when Arcane Shot is unaffordable')
 s.repeatActive=true;local r=M.expect(a,s,BASE,nil,'stopped','pull: nothing more');assert(r.suppressAttack,'never melee')
 s.combat=true;s.repeatActive=false;s.usable[ARCANE]=nil;s.energy=100
 s.cast=true;M.expect(a,s,BASE,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,BASE,nil,'stopped','channelling');s.channel=false
 s.hostile=false;r=M.expect(a,s,BASE,nil,'stopped','no attackable target');assert(r.suppressAttack);s.hostile=true
 s.setLevel(9);s.learn(STEADY,STING,MARK);s.combat=false;M.expect(a,s,BASE,MARK,nil,'pull: Hunter\'s Mark');s.combat=true
 M.expect(a,s,BASE,STING,nil,'Serpent Sting on a target that lives')
 s.ttd=5;M.expect(a,s,BASE,ARCANE,nil,'no sting on a dying target');s.ttd=60
 s.debuff('target',STINGDEBUFF);M.expect(a,s,BASE,ARCANE,nil,'Arcane Shot')
 s.learn(MULTI);s.near(3);M.expect(a,s,BASE,MULTI,nil,'three: Multi-Shot');s.near(0)
 s.usable[ARCANE]=false;M.expect(a,s,BASE,STEADY,nil,'Steady Shot when short of focus')
 s.usable[STEADY]=false;M.expect(a,s,BASE,AUTO,nil,'Auto Shot');s.repeatActive=true;r=M.expect(a,s,BASE,nil,'stopped','waiting');assert(r.suppressAttack)
end)
test('reminders: pet care, aspect, interrupt, Fervor and burst only when worth it',function()
 local a,s=hunter();s.learn(KC,CALLPET,REVIVE,MEND,HAWK,COUNTER,FERVOR,RAPID,STAMPEDE)
 s.pet=false;local lit=M.upkeep(a,s,BM);assert(lit[CALLPET]and lit[HAWK],'no pet, no aspect')
 s.pet=true;s.health.pet=40;lit=M.upkeep(a,s,BM);assert(not lit[CALLPET]and lit[MEND],'Mend Pet below half')
 s.buff('pet',MEND);lit=M.upkeep(a,s,BM);assert(not lit[MEND],'Mend Pet already on');s.clearAuras();s.health.pet=100
 s.buff('player',HAWK);lit=M.upkeep(a,s,BM);assert(not lit[HAWK],'Hawk up')
 s.clearAuras();s.learn(IRONHAWK);lit=M.upkeep(a,s,BM);assert(lit[IRONHAWK]and not lit[HAWK],'Iron Hawk replaces Hawk')
 s.combat=false;s.buff('player',5118);lit=M.upkeep(a,s,BM);assert(not lit[IRONHAWK],'a travel aspect out of combat is yours');s.combat=true
 lit=M.upkeep(a,s,BM);assert(lit[IRONHAWK],'Cheetah in combat: back to the hawk');s.clearAuras()
 s.energy=40;lit=M.upkeep(a,s,BM);assert(lit[FERVOR],'Fervor when you and the pet are low');s.energy=100
 lit=M.upkeep(a,s,BM);assert(not lit[FERVOR]and lit[RAPID],'a target that lives: Rapid Fire')
 s.ttd=5;lit=M.upkeep(a,s,BM);assert(not lit[RAPID]and not lit[STAMPEDE],'a dying normal mob: no burst')
 s.classification='elite';lit=M.upkeep(a,s,BM);assert(lit[RAPID],'elite: burst')
 s.classification='normal';s.instance='party';lit=M.upkeep(a,s,BM);assert(lit[RAPID],'dungeon: burst');s.instance=nil
 s.combat=false;s.classification='worldboss';lit=M.upkeep(a,s,BM);assert(not lit[RAPID],'no burst before combat');s.combat=true
 s.buff('player',RAPID);lit=M.upkeep(a,s,MM);assert(not lit[RAPID],'Rapid Fire running');s.clearAuras()
 lit=M.upkeep(a,s,BM);assert(not lit[COUNTER],'nothing to interrupt')
end)
test('Beast Mastery: pull, Kill Shot, Kill Command held for Bestial Wrath, Focus Fire, sting, Arcane dump, filler',function()
 local a,s=hunter(10);s.learn(KC,ARCANE,STEADY,STING,MARK)
 s.combat=false;M.expect(a,s,BM,MARK,nil,'pull: mark');s.debuff('target',MARK,{sourceUnit='party1'});M.expect(a,s,BM,KC,nil,'pull: someone else\'s mark is enough, Kill Command')
 s.combat=true;s.clearAuras()
 M.expect(a,s,BM,KC,nil,'level 10: Kill Command');s.cooling(KC,4)
 M.expect(a,s,BM,STING,nil,'Serpent Sting');s.debuff('target',STINGDEBUFF,{expirationTime=110,duration=15})
 M.expect(a,s,BM,ARCANE,nil,'80+ focus: Arcane Shot');s.energy=50;M.expect(a,s,BM,STEADY,nil,'Steady Shot before Cobra')
 s.setLevel(90);s.cooldown={};s.learn(KILLSHOT,WRATH,FOCUSFIRE,COBRA,CROWS,GLAIVE)
 M.expect(a,s,BM,KILLSHOT,nil,'Kill Shot first');s.usable[KILLSHOT]=false
 s.cooling(WRATH,2);M.expect(a,s,BM,CROWS,nil,'Kill Command held 2 s before Bestial Wrath')
 s.cooling(WRATH,10);M.expect(a,s,BM,KC,nil,'Kill Command when Bestial Wrath is far');s.cooling(KC,4)
 M.expect(a,s,BM,CROWS,nil,'A Murder of Crows on a target that lives');s.cooling(CROWS,30);M.expect(a,s,BM,GLAIVE,nil,'Glaive Toss');s.cooling(GLAIVE,10)
 s.buff('pet',FRENZY,{applications=5});M.expect(a,s,BM,FOCUSFIRE,nil,'five Frenzy: Focus Fire')
 s.buff('pet',WRATH);M.expect(a,s,BM,ARCANE,nil,'no Focus Fire inside Bestial Wrath; any focus spends on Arcane');s.clearAuras()
 s.buff('pet',FRENZY,{applications=4,expirationTime=102,duration=30});M.expect(a,s,BM,FOCUSFIRE,nil,'four expiring Frenzy');s.clearAuras()
 s.debuff('target',STINGDEBUFF,{expirationTime=103,duration=15});M.expect(a,s,BM,COBRA,nil,'Cobra refreshes the sting');s.clearAuras()
 s.debuff('target',STINGDEBUFF,{expirationTime=110,duration=15});M.expect(a,s,BM,COBRA,nil,'50 focus: Cobra filler')
 s.buff('player',THRILL);s.energy=65;M.expect(a,s,BM,ARCANE,nil,'Thrill of the Hunt at 60+')
 s.cooling(COBRA,1);s.usable[COBRA]=false;local r=M.expect(a,s,BM,ARCANE,nil,'Cobra unusable')
 s.usable[ARCANE]=false;r=M.expect(a,s,BM,nil,'stopped','nothing: wait without melee');assert(r.suppressAttack)
end)
test('Beast Mastery AoE: Beast Cleave, Kill Command gate, trap, Multi-Shot spend',function()
 local a,s=hunter();s.learn(KC,ARCANE,COBRA,STING,MULTI,TRAP,FOCUSFIRE,KILLSHOT);s.usable[KILLSHOT]=false
 s.near(2);M.expect(a,s,BM,MULTI,nil,'two: Beast Cleave')
 s.buff('pet',CLEAVE,{expirationTime=104,duration=4});M.expect(a,s,BM,KC,nil,'two: Kill Command')
 s.near(4);s.energy=60;M.expect(a,s,BM,TRAP,nil,'four, short focus: Explosive Trap, no Kill Command');s.cooling(TRAP,20)
 M.expect(a,s,BM,STING,nil,'four: Serpent Sting');s.debuff('target',STINGDEBUFF)
 M.expect(a,s,BM,COBRA,nil,'four, 60 focus: Cobra')
 s.energy=90;M.expect(a,s,BM,KC,nil,'four at 80+: Kill Command');s.cooling(KC,4);M.expect(a,s,BM,MULTI,nil,'Multi-Shot to spend')
 s.near(6);s.clearAuras();s.energy=60;M.expect(a,s,BM,MULTI,nil,'six, no Beast Cleave: Multi-Shot');s.buff('pet',CLEAVE,{expirationTime=104,duration=4})
 M.expect(a,s,BM,COBRA,nil,'six, the sting is not spread past four');s.near(0)
 M.expect(a,s,BM,STING,nil,'back to one target: sting')
end)
test('Marksmanship: pull, Steady pairs, Chimera, Fire!, Careful Aim, Arcane only on the move',function()
 local a,s=hunter(10);s.learn(AIMED,ARCANE,STEADY,STING,MARK);s.debuff('target',MARK)
 s.combat=false;M.expect(a,s,MM,AIMED,nil,'pull: Aimed Shot');s.moving=true;local r=M.expect(a,s,MM,nil,'stopped','moving pull: nothing');assert(r.suppressAttack)
 s.moving=false;s.combat=true
 M.expect(a,s,MM,STING,nil,'level 10: sting');s.debuff('target',STINGDEBUFF)
 M.expect(a,s,MM,AIMED,nil,'Careful Aim: Aimed Shot above 80%')
 s.health.target=50;M.expect(a,s,MM,AIMED,nil,'before Chimera Shot Aimed Shot spends focus')
 s.setLevel(90);s.learn(CHIMERA,KILLSHOT);s.usable[KILLSHOT]=false
 M.expect(a,s,MM,CHIMERA,nil,'Chimera Shot');s.cooling(CHIMERA,1)
 M.expect(a,s,MM,STEADY,nil,'Steady Focus missing: start a pair')
 s.buff('player',STEADYFOCUS,{expirationTime=115,duration=20})
 s.energy=50;M.expect(a,s,MM,STEADY,nil,'Chimera soon, mid health, 50 focus: Steady')
 s.cooling(CHIMERA,5);M.expect(a,s,MM,AIMED,nil,'Chimera away: Aimed Shot')
 s.cooling(CHIMERA,1);s.energy=90;M.expect(a,s,MM,AIMED,nil,'85 focus: Aimed Shot')
 s.energy=50;s.buff('player',FIRE);M.expect(a,s,MM,AIMED,nil,'Fire!: Aimed Shot');s.clearAuras()
 s.buff('player',STEADYFOCUS,{expirationTime=103,duration=20});s.debuff('target',STINGDEBUFF);s.debuff('target',MARK)
 s.history(STEADY,1);M.expect(a,s,MM,STEADY,nil,'complete the pair before Chimera');s.cooldown={}
 a.spellHistory={};s.clearAuras();s.debuff('target',STINGDEBUFF);s.buff('player',STEADYFOCUS,{expirationTime=115,duration=20});s.cooling(CHIMERA,1)
 s.moving=true;s.energy=70;M.expect(a,s,MM,ARCANE,nil,'moving: Arcane Shot');s.energy=40;M.expect(a,s,MM,STEADY,nil,'moving, low focus: Steady')
end)
test('Marksmanship AoE and the Arcane dump variant',function()
 local a,s=hunter();s.learn(AIMED,ARCANE,STEADY,STING,MULTI,CHIMERA,KILLSHOT,TRAP);s.usable[KILLSHOT]=false;s.health.target=50
 s.buff('player',STEADYFOCUS,{expirationTime=115,duration=20});s.debuff('target',STINGDEBUFF)
 s.near(3);M.expect(a,s,MM,CHIMERA,nil,'three: single target');s.near(4);M.expect(a,s,MM,CHIMERA,nil,'four: Chimera')
 s.cooling(CHIMERA,5);M.expect(a,s,MM,MULTI,nil,'four: Multi-Shot');s.near(10);s.cooldown={};M.expect(a,s,MM,MULTI,nil,'ten: no Chimera')
 s.near(0);s.cooling(CHIMERA,5)
 M.expect(a,s,MMIV,ARCANE,nil,'Arcane dump: 60 focus, mid health goes to Arcane')
 M.expect(a,s,MM,AIMED,nil,'recommended: Aimed Shot')
 s.health.target=90;M.expect(a,s,MMIV,AIMED,nil,'Arcane dump: Aimed Shot above 80%');s.health.target=50
 s.energy=40;M.expect(a,s,MMIV,STEADY,nil,'Arcane dump: Steady when short')
 s.near(4);s.energy=100;M.expect(a,s,MMIV,MULTI,nil,'Arcane dump AoE: Multi-Shot first')
end)
test('Survival: pull, Explosive Shot and Lock and Load, Black Arrow, Arcane waits for Black Arrow, AoE',function()
 local a,s=hunter(10);s.learn(EXPLOSIVE,ARCANE,STEADY,STING,MARK);s.debuff('target',MARK)
 s.combat=false;M.expect(a,s,SV,EXPLOSIVE,nil,'level 10 pull: Explosive Shot');s.combat=true
 M.expect(a,s,SV,EXPLOSIVE,nil,'Explosive Shot');s.cooling(EXPLOSIVE,5)
 M.expect(a,s,SV,STING,nil,'sting');s.debuff('target',STINGDEBUFF)
 s.energy=60;M.expect(a,s,SV,ARCANE,nil,'55+ without Black Arrow: Arcane')
 s.setLevel(90);s.learn(ARROW,KILLSHOT,COBRA,MULTI,TRAP);s.usable[KILLSHOT]=false
 s.cooldown={};s.combat=false;M.expect(a,s,SV,ARROW,nil,'pull: Black Arrow');s.combat=true
 s.buff('player',LNL);M.expect(a,s,SV,EXPLOSIVE,nil,'Lock and Load: Explosive Shot')
 s.cooldown={};s.clearAuras();s.debuff('target',STINGDEBUFF);s.cooling(EXPLOSIVE,5)
 M.expect(a,s,SV,ARROW,nil,'Black Arrow');s.ttd=4;M.expect(a,s,SV,COBRA,nil,'no Black Arrow on a dying target; Arcane still waits for it at 60');s.ttd=60
 s.cooling(ARROW,2);M.expect(a,s,SV,COBRA,nil,'Black Arrow soon: hold Arcane, Cobra')
 s.energy=80;M.expect(a,s,SV,ARCANE,nil,'75+: Arcane anyway')
 s.cooling(ARROW,20);s.debuff('target',ARROW,{expirationTime=101,duration=20});s.energy=40;M.expect(a,s,SV,COBRA,nil,'Black Arrow on cooldown: Cobra')
 s.clearAuras();s.debuff('target',STINGDEBUFF);s.cooldown={};s.cooling(ARROW,20)
 s.near(3);s.energy=100;M.expect(a,s,SV,EXPLOSIVE,nil,'three: Explosive Shot');s.buff('player',LNL);M.expect(a,s,SV,MULTI,nil,'Lock and Load at 90 focus: Multi-Shot first')
 s.clearAuras();s.debuff('target',STINGDEBUFF);s.near(6);M.expect(a,s,SV,TRAP,nil,'six: no hard Explosive Shot, trap');s.cooling(TRAP,20)
 M.expect(a,s,SV,MULTI,nil,'six: Multi-Shot');s.energy=30;M.expect(a,s,SV,COBRA,nil,'six, low focus: Cobra')
end)
finish()
