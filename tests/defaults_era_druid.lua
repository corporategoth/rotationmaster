-- Classic Era and Season of Discovery Druid premades: the shipped packs on the real catalog,
-- predicates, composition, build context (season rulesets), readiness and sequence executor on a
-- modeled 1.15 client (tests/fixtures/era_premade_model_a.lua). Forms are stances read by spell (FORM form):
-- a form ID put on the player with s.buff goes on the modeled stance bar instead (s.shift), and clearing
-- the auras leaves the form, so a scenario reads as the druid's state.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/era_premade_model_a.lua')
local BAL,BALIV,FER,FERWT,FERWTC,FERWH,RES,RESWT='rm.era.druid.balance','rm.era.druid.balance.icyveins','rm.era.druid.feral','rm.era.druid.feral.warcrafttavern',
 'rm.era.druid.feral.warcrafttavern.casual','rm.era.druid.feral.wowhead','rm.era.druid.restoration','rm.era.druid.restoration.warcrafttavern'
local SBAL,SBALIV,SBALWH,SFER,STANK,STANKWS,SRES='rm.sod.druid.balance','rm.sod.druid.balance.icyveins','rm.sod.druid.balance.wowhead','rm.sod.druid.feral',
 'rm.sod.druid.tank','rm.sod.druid.tank.wowsims','rm.sod.druid.restoration'
local VANILLA={BAL,BALIV,FER,FERWT,FERWTC,FERWH,RES,RESWT}
local SOD={SBAL,SBALIV,SBALWH,SFER,STANK,STANKWS,SRES}
local ALL={};for _,list in ipairs({VANILLA,SOD})do for _,id in ipairs(list)do ALL[#ALL+1]=id end end
local CAT,BEAR,DIRE,TRAVEL=768,5487,9634,783
local FORMS={[CAT]=true,[BEAR]=true,[DIRE]=true,[TRAVEL]=true,[1066]=true,[24858]=true}
local SR,LACERATE,LIFEBLOOM,STARSURGE=407988,414644,408124,417157
-- The Lifebloom rune's first taught spell (wowsims/exporter); 408124 is the heal it grants.
local LIFEBLOOM_RUNE,GALE_WINDS,ELUNES_FIRES,IMPROVED_SWIPE=409824,417135,414719,439510
local function druid(level,talents,...)
 local f,s=M.new('druid');local a=f.addon
 -- Health forecast seam: s.ttd seconds until the target dies (nil = no forecast).
 a.GetConditionHealthForecast=function()if s.ttd==nil then return false end;return s.ttd end
 local buff,clear=s.buff,s.clearAuras;s.aura=buff -- s.aura puts a real aura on, form ID or not
 s.buff=function(unit,id,extra)if unit=='player'and FORMS[id]then s.shift(id)else buff(unit,id,extra)end end
 s.clearAuras=function()clear();s.shift(0)end
 s.setLevel(level or 60);s.setTalents(talents or {0,0,0});s.learn(5176,8921,...)
 return a,s,f
end
local function cat(s)s.clearAuras();s.buff('player',CAT);s.powerType=3;s.energy=100 end
local function bear(s,id)s.clearAuras();s.buff('player',id or BEAR);s.powerType=1;s.energy=0 end
local function behind(s)s.targetTarget='party1'end
local function stopped(a,s,id,suppress)
 local spell,r=M.first(a,s,id);return spell==nil and r.status=='stopped'and(suppress==nil or (r.suppressAttack==true)==suppress)
end
local function friendly(s,hp)s.hostile=false;s.friendly=true;s.health.target=hp or 100 end
local function fresh(remain)return{expirationTime=100+remain,duration=40}end

test('fifteen sourced, localized, composed premades: vanilla and Season of Discovery',function()
 local a,s,f=druid()
 M.registered(a,f,ALL,'DRUID')
 for _,id in ipairs(ALL)do assert(a:GetDefaultRotationComposition(id),id..' does not use the shared Druid blocks')end
 local prio={};for _,id in ipairs(ALL)do prio[id]=M.row(a,id).envelope.body.priority or 0 end
 for _,v in ipairs(VANILLA)do for _,x in ipairs(SOD)do assert(prio[x]>prio[v],x..' must outrank '..v)end end
 assert(prio[BAL]>prio[BALIV]and prio[FER]>prio[FERWT]and prio[FERWT]>prio[FERWTC]and prio[FERWTC]>prio[FERWH]and prio[RES]>prio[RESWT])
 assert(prio[SBAL]>prio[SBALWH]and prio[SBALWH]>prio[SBALIV]and prio[STANK]>prio[STANKWS]and prio[STANK]>prio[SFER])
 assert(M.row(a,STANKWS).envelope.body.disabled==true and not M.row(a,STANKWS).eligible,'the cat-weave tank is opt-in')
 assert(M.row(a,FER).applicability.minLevel==10 and M.row(a,RES).applicability.minLevel==10 and M.row(a,BAL).applicability.minLevel==1)
end)

test('standard realm: Balance owns levels 1-9, no points and ties; Feral and Restoration by tree; variants share switches',function()
 local a,s=druid(5)
 assert(M.selected(a)==BAL)
 for _,id in ipairs(SOD)do assert(not M.row(a,id).eligible,id..' eligible on a standard realm')end
 for _,case in ipairs({{30,{0,0,0},BAL},{20,{0,11,0},FER},{20,{0,0,11},RES},{40,{31,0,0},BAL},{40,{10,10,0},BAL},{60,{0,30,21},FER},{60,{11,0,40},RES},{60,{30,0,21},BAL}})do
  s.setLevel(case[1]);s.setTalents(case[2]);assert(M.selected(a)==case[3],table.concat(case[2],'/')..' chose '..tostring(M.selected(a)))
 end
 s.setTalents({0,0,0});assert(M.switch(a,FER)=='unavailable'and M.selected(a)==BAL,'no points: Balance')
 s.setTalents({0,30,21})
 for _,id in ipairs({FERWT,FERWTC,FERWH})do assert(M.switch(a,id)=='match',id..' shares the Feral switch')end
 assert(a:SetDefaultRotationEnabled(FER,false));assert(M.selected(a)==FERWT)
 assert(a:SetDefaultRotationEnabled(FERWT,false));assert(M.selected(a)==FERWTC)
 assert(a:SetDefaultRotationEnabled(FERWTC,false));assert(M.selected(a)==FERWH)
 s.setTalents({0,0,0});assert(a:SetDefaultRotationEnabled(BAL,false));assert(M.selected(a)==BALIV)
 s.setTalents({11,0,40});assert(a:SetDefaultRotationEnabled(RES,false));assert(M.selected(a)==RESWT)
end)

test('Season of Discovery: the legs rune decides the role; vanilla premades never win',function()
 local a,s=druid(1);s.setSeason(2)
 assert(M.selected(a)==SBAL,'level 1 SoD druid')
 for _,id in ipairs(SOD)do if id~=STANKWS then assert(M.row(a,id).eligible,id..' not eligible on SoD')end end
 s.setLevel(25);s.learn(SR);assert(M.selected(a)==SBAL,'Savage Roar known (from gear) without the rune: not the cat switch')
 s.unlearn(SR);s.engrave(SR);assert(M.selected(a)==SFER,'Savage Roar engraved: cat')
 s.unengrave(SR);s.engrave(LACERATE);assert(M.selected(a)==STANK,'Lacerate: tank')
 s.unengrave(LACERATE);s.engrave(LIFEBLOOM_RUNE);assert(M.selected(a)==SRES,'Lifebloom: Restoration')
 s.unengrave(LIFEBLOOM_RUNE);s.engrave(STARSURGE);assert(M.selected(a)==SBAL,'Starsurge: Balance')
 s.unengrave(STARSURGE);s.setTalents({0,21,0});assert(M.selected(a)==SFER,'Feral tree without a legs rune: cat')
 s.engrave(LIFEBLOOM_RUNE);assert(M.selected(a)==SRES,'Lifebloom outranks the Feral tree')
 s.unengrave(LIFEBLOOM_RUNE);s.engrave(STARSURGE);assert(M.selected(a)==SBAL,'Starsurge on a Feral tree stays Balance')
 s.unengrave(STARSURGE);s.setTalents({0,0,21});assert(M.selected(a)==SRES)
 s.engrave(SR);assert(M.selected(a)==SFER,'Savage Roar outranks the Restoration tree')
 s.runesPending=true;s.engrave();assert(M.selected(a)==SBAL,'runes still loading: Balance until they read')
 s.runesPending=false;s.unengrave(SR);s.setTalents({10,10,0});assert(M.selected(a)==SBAL,'a tie stays Balance')
 s.setTalents({0,0,0});s.setLevel(40);assert(M.selected(a)==SBAL,'no points stays Balance')
 s.setSeason(nil);assert(M.selected(a)==BAL,'back on a standard realm')
end)

test('boundaries: casts, channels and travel forms suppress Attack; no target stops every premade',function()
 local a,s=druid(60,{0,30,21},CAT,1082,5221,2912)
 for _,season in ipairs({nil,2})do
  s.setSeason(season)
  for _,id in ipairs(season and SOD or VANILLA)do
   s.clearAuras()
   s.cast=true;assert(stopped(a,s,id,true),id..' casting');s.cast=false
   s.channel=true;assert(stopped(a,s,id,true),id..' channelling');s.channel=false
   s.buff('player',TRAVEL);assert(stopped(a,s,id,true),id..' travel form');s.clearAuras()
   s.hostile=false;assert(stopped(a,s,id),id..' no target');s.hostile=true
  end
 end
end)

test('Balance leveling stages: Wrath pull, Moonfire, Wrath, then Starfire; moving instants; melee when dry',function()
 local a,s=druid(8);s.ranged(5176,8921)
 s.combat=false;M.expect(a,s,BAL,5176,nil,'pull: Wrath');s.moving=true;M.expect(a,s,BAL,8921,nil,'pull on the move: Moonfire');s.moving=false;s.combat=true
 s.ttd=20;M.expect(a,s,BAL,8921,nil,'Moonfire on a target that lives')
 s.debuff('target',8921);M.expect(a,s,BAL,5176,nil,'Moonfire up: Wrath');s.clearAuras()
 s.ttd=4;M.expect(a,s,BAL,5176,nil,'no Moonfire on a dying target');s.ttd=20
 s.mana.player=20;M.expect(a,s,BAL,5176,nil,'Moonfire is dropped when mana runs short');s.mana.player=100
 s.moving=true;s.debuff('target',8921);local r=M.expect(a,s,BAL,nil,'stopped','moving with Moonfire up');assert(r.suppressAttack);s.moving=false
 s.usable[5176]=false;r=M.expect(a,s,BAL,nil,'stopped','out of mana: melee');assert(not r.suppressAttack);s.usable[5176]=nil
 s.setLevel(40);s.learn(2912,16914,770,5570);s.setTalents({11,0,0})
 M.expect(a,s,BAL,5570,nil,'Insect Swarm once talented')
 s.debuff('target',5570);M.expect(a,s,BAL,2912,nil,'Starfire filler')
 s.group=true;M.expect(a,s,BAL,770,nil,'Faerie Fire in a group')
 s.debuff('target',16857,{sourceUnit='party1'});M.expect(a,s,BAL,2912,nil,'anyone\'s Faerie Fire counts');s.group=false
 s.near(3);M.expect(a,s,BAL,16914,nil,'three engaged: Hurricane');s.near(0)
 s.buff('player',16886);M.expect(a,s,BAL,2912,nil,'Nature\'s Grace: Starfire')
end)

test('Balance in Cat or Bear Form plays the Feral sections',function()
 local a,s=druid(15,{0,0,0},BEAR,6807,99,779)
 bear(s);s.energy=5;s.learn(5229);M.expect(a,s,BAL,5229,nil,'bear: Enrage when starved')
 s.energy=30;local r=M.expect(a,s,BAL,nil,'stopped','bear: no Demoralizing Roar on a normal mob, no rage to Swipe');assert(not r.suppressAttack)
 s.energy=65;M.expect(a,s,BAL,779,nil,'bear: Swipe with spare rage')
 s.setLevel(22);s.learn(CAT,1082);cat(s);M.expect(a,s,BAL,1082,nil,'cat: Claw from the front')
end)

test('Icy Veins Balance: Starfire only, Hurricane then stop on packs',function()
 local a,s=druid(60,{31,0,0},2912,16914);s.ttd=30
 M.expect(a,s,BALIV,2912,nil,'no Moonfire: Starfire')
 s.near(3);M.expect(a,s,BALIV,16914,nil,'Hurricane');s.cooling(16914,8);M.expect(a,s,BALIV,nil,'stopped','packs: nothing else');s.near(0)
 s.moving=true;M.expect(a,s,BALIV,nil,'stopped','moving')
end)

test('Feral cat: stealth opener, Faerie Fire, Clearcasting, finishers, Rake, positional builder, powershift',function()
 local a,s=druid(20,{0,11,0},CAT,1082,1079,1822)
 cat(s);s.ttd=30
 s.points=4;M.expect(a,s,FER,1079,nil,'before Ferocious Bite: Rip')
 s.debuff('target',1079);M.expect(a,s,FER,1822,nil,'Rip up: Rake')
 s.debuff('target',1822);M.expect(a,s,FER,1082,nil,'Rake up: Claw');s.points=0
 s.setLevel(40);s.learn(5221,22568,16857,5215,6785)
 cat(s);s.debuff('target',16857,fresh(30));s.debuff('target',1822)
 s.stealthed=true;M.expect(a,s,FER,6785,nil,'stealthed: Ravage');s.stealthed=false
 s.clearAuras();s.buff('player',CAT);s.debuff('target',1822);M.expect(a,s,FER,16857,nil,'no Faerie Fire: Faerie Fire (Feral)')
 s.debuff('target',16857,fresh(4));M.expect(a,s,FER,16857,nil,'refresh under 6 s')
 s.clearAuras();s.buff('player',CAT);s.debuff('target',1822);s.debuff('target',16857,fresh(30))
 M.expect(a,s,FER,1082,nil,'target on you: Claw');behind(s);M.expect(a,s,FER,5221,nil,'behind: Shred')
 s.buff('player',16870);s.targetTarget='player';M.expect(a,s,FER,1082,nil,'Clearcasting from the front is no Shred');behind(s);M.expect(a,s,FER,5221);s.clearAuras()
 s.buff('player',CAT);s.debuff('target',1822);s.debuff('target',16857,fresh(30))
 s.points=4;s.energy=50;M.expect(a,s,FER,1079,nil,'long-lived target solo: Rip')
 s.debuff('target',1079);M.expect(a,s,FER,22568,nil,'Rip up: Ferocious Bite')
 s.energy=70;M.expect(a,s,FER,5221,nil,'63 energy or more: Shred first')
 s.energy=50;s.raid=true;s.clearAuras();s.buff('player',CAT);s.debuff('target',16857,fresh(30))
 M.expect(a,s,FER,22568,nil,'raid: no Rip, Bite');s.points=0
 M.expect(a,s,FER,5221,nil,'raid: no Rake');s.raid=false
 s.usable[5221]=false;s.usable[1082]=false;s.debuff('target',1822);s.energy=20
 local r=M.expect(a,s,FER,nil,'stopped','short of energy without Furor: wait');assert(not r.suppressAttack,'auto-attack continues')
 s.setTalent(3,2,5);M.expect(a,s,FER,CAT,nil,'Furor 5/5: powershift')
 s.mana.player=10;M.expect(a,s,FER,nil,'stopped','no mana to shift back: wait')
end)

test('Feral bear: pull, Enrage, Demoralizing Roar, Swipe on packs and spare rage, Faerie Fire filler; humanoid shifts',function()
 local a,s=druid(40,{0,21,0},BEAR,DIRE,6807,779,99,5229,16857,CAT)
 bear(s,DIRE);s.combat=false;s.targetRange={10,25};M.expect(a,s,FER,16857,nil,'pull from range: Faerie Fire (Feral)')
 s.targetRange={0,5};M.expect(a,s,FER,5229,nil,'pull in melee: Enrage');s.combat=true
 s.energy=5;M.expect(a,s,FER,5229,nil,'starved solo: Enrage')
 s.energy=30;M.expect(a,s,FER,16857,nil,'normal mob: Faerie Fire filler')
 s.classification='elite';M.expect(a,s,FER,99,nil,'elite: Demoralizing Roar')
 s.debuff('target',1160,{sourceUnit='party1'});M.expect(a,s,FER,16857,nil,'a Shout already covers it');s.classification='normal'
 s.near(2);M.expect(a,s,FER,779,nil,'two engaged: Swipe');s.near(0)
 s.energy=65;M.expect(a,s,FER,779,nil,'spare rage: Swipe')
 local lit=M.upkeep(a,s,FER);assert(lit[6807],'Maul in bear combat')
 s.current[6807]=true;lit=M.upkeep(a,s,FER);s.current[6807]=nil
 s.clearAuras();s.powerType=0;M.expect(a,s,FER,CAT,nil,'caster form: Cat Form')
 s.unlearn(CAT);M.expect(a,s,FER,DIRE,nil,'before Cat Form: Dire Bear Form')
 s.unlearn(DIRE,BEAR);M.expect(a,s,FER,8921,nil,'no forms yet: Moonfire')
end)

test('Feral source variants: Tavern Rip in raids, no-powershift list, Wowhead raid bear',function()
 local a,s=druid(60,{0,30,21},CAT,1082,5221,1079,22568,1822,16857,5217,BEAR,DIRE,779,99,5229,6807)
 s.setTalent(3,2,5);cat(s);s.raid=true;behind(s);s.debuff('target',16857,fresh(30))
 s.points=5;s.energy=50
 M.expect(a,s,FER,22568,nil,'recommended: Bite in a raid')
 M.expect(a,s,FERWT,1079,nil,'Tavern: Rip in a raid')
 s.points=4;M.expect(a,s,FERWT,22568,nil,'Tavern: Bite from four')
 s.points=0;s.usable[5221]=false;s.usable[1082]=false;s.energy=20
 M.expect(a,s,FERWT,CAT,nil,'Tavern powershifts')
 M.expect(a,s,FERWTC,nil,'stopped','casual list never powershifts')
 s.usable[5221]=nil;s.usable[1082]=nil;s.points=5;s.energy=50;s.ttd=30
 M.expect(a,s,FERWTC,1079,nil,'casual: Rip at five on a long fight')
 s.debuff('target',1079);M.expect(a,s,FERWTC,5217,nil,'casual: Tiger\'s Fury before Bite')
 s.buff('player',5217);M.expect(a,s,FERWTC,22568,nil,'casual: Bite')
 s.raid=false;bear(s,DIRE);s.energy=30;s.near(3);s.debuff('target',99)
 M.expect(a,s,FER,779,nil,'recommended bear Swipes packs')
 M.expect(a,s,FERWH,16857,nil,'Wowhead bear tab-Mauls instead')
 s.energy=65;M.expect(a,s,FERWH,779,nil,'Wowhead: Swipe at 60 rage')
end)

test('Restoration: friendly-target heals by health, HoTs rolling, Swiftmend, rank 4 Healing Touch; damage solo',function()
 local a,s=druid(60,{0,0,31},5185,5188,774,8936,18562,5570,17116)
 friendly(s,100);s.combat=false;M.expect(a,s,RES,nil,'stopped','healthy friend out of combat')
 s.combat=true;M.expect(a,s,RES,774,nil,'in combat: Rejuvenation')
 s.buff('target',774);M.expect(a,s,RES,nil,'stopped','Rejuvenation up, full health')
 s.health.target=75;M.expect(a,s,RES,8936,nil,'below 80%: Regrowth')
 s.buff('target',8936);M.expect(a,s,RES,5188,nil,'HoTs up: rank 4 Healing Touch')
 s.health.target=40;M.expect(a,s,RES,5185,nil,'below 45%: Healing Touch at full rank')
 s.health.target=30;M.expect(a,s,RES,18562,nil,'below 40% with my HoT: Swiftmend')
 s.cooling(18562,10);s.buff('player',17116);M.expect(a,s,RES,5185,nil,'Nature\'s Swiftness: Healing Touch');s.clearAuras();s.cooldown={}
 s.health.target=70;s.buff('target',774);s.buff('target',8936);s.setTalent(3,14,5);M.expect(a,s,RES,8936,nil,'Improved Regrowth: Regrowth spam')
 s.clearAuras();s.buff('player',CAT);M.expect(a,s,RES,nil,'stopped','silent in Cat Form');s.clearAuras()
 s.hostile=true;s.friendly=false;s.ttd=30;M.expect(a,s,RES,8921,nil,'enemy: Moonfire')
 s.debuff('target',8921);M.expect(a,s,RES,5570,nil,'enemy: Insect Swarm');s.debuff('target',5570);M.expect(a,s,RES,5176,nil,'enemy: Wrath')
 s.hostile=false;s.friendly=true;s.dead=true;local lit=M.upkeep(a,s,RES)
 s.learn(20484);lit=M.upkeep(a,s,RES);assert(lit[20484],'Rebirth on a dead friend in combat')
end)

test('Warcraft Tavern Restoration: no HoTs at low damage, downranked tiers',function()
 local a,s=druid(60,{0,0,31},5185,5187,5188,774,8936,8939,8941,18562)
 friendly(s,95);M.expect(a,s,RES,774,nil,'recommended rolls Rejuvenation');s.clearAuras()
 M.expect(a,s,RESWT,nil,'stopped','Tavern: nothing at 95%')
 s.health.target=85;M.expect(a,s,RESWT,5187,nil,'below 90%: rank 3 Healing Touch')
 s.health.target=70;M.expect(a,s,RESWT,774,nil,'below 75%: Rejuvenation')
 s.buff('target',774);M.expect(a,s,RESWT,8939,nil,'then rank 3 Regrowth')
 s.health.target=45;M.expect(a,s,RESWT,8941,nil,'below 50%: rank 5 Regrowth')
end)

test('forms are read by spell wherever they sit on the stance bar, never from an aura',function()
 local a,s=druid(40,{0,21,0},BEAR,DIRE,CAT,1082,779,16857,5229,24858,1126)
 s.points=0;s.debuff('target',16857,fresh(30))
 s.aura('player',CAT);s.powerType=0;M.expect(a,s,FER,CAT,nil,'a Cat Form aura without the stance is caster form: shift')
 s.clearAuras();s.bar={BEAR,1066,CAT};s.form=3;s.powerType=3;s.energy=100;s.debuff('target',16857,fresh(30))
 M.expect(a,s,FER,1082,nil,'Cat Form in slot 3 behind Bear and Aquatic: the cat list')
 s.form=1;s.powerType=1;s.energy=30;M.expect(a,s,FER,16857,nil,'Bear Form in slot 1: the bear list')
 s.bar={DIRE,1066,CAT,TRAVEL};s.form=1;M.expect(a,s,FER,16857,nil,'Dire Bear Form: the bear list')
 s.form=4;assert(stopped(a,s,FER,true)and stopped(a,s,BAL,true),'Travel Form in slot 4 stops with Attack off')
 s.form=2;assert(stopped(a,s,FER,true),'Aquatic Form stops too')
 s.combat=false;s.clearAuras();s.buff('player',1126);local lit=M.upkeep(a,s,BAL);assert(lit[24858],'caster form: Moonkin reminder')
 for _,id in ipairs({TRAVEL,1066,24858,CAT,DIRE})do s.shift(id);assert(not M.upkeep(a,s,BAL)[24858],'no Moonkin reminder in form '..id)end
 s.form=nil;assert(M.status(a,FER,'era-feral-cat')=='unavailable','an unreadable form is unavailable, not caster form')
end)

test('Druid upkeep: Mark, Thorns solo, Omen, Moonkin Form, Tiger\'s Fury before a pull',function()
 local a,s=druid(60,{31,0,0},1126,467,16864,24858,29166,CAT,5217)
 s.combat=false;local lit=M.upkeep(a,s,BAL)
 assert(lit[1126]and lit[467]and lit[16864]and lit[24858],'out of combat solo')
 s.buff('player',21849);s.buff('player',16864);s.buff('player',24858);s.group=true;lit=M.upkeep(a,s,BAL)
 assert(not lit[1126]and not lit[467]and not lit[16864]and not lit[24858],'Gift, Omen and Moonkin up; Thorns only solo')
 s.group=false;s.clearAuras();cat(s);lit=M.upkeep(a,s,BAL);assert(lit[5217]and not lit[24858],'cat at full energy before a pull: Tiger\'s Fury, no Moonkin')
 s.combat=true;s.mana.player=10;lit=M.upkeep(a,s,BAL);assert(lit[29166]and not lit[5217],'Innervate when drained')
end)

test('SoD Balance: Starsurge, empowered Starfire, Sunfire and Moonfire, Hurricane at six, Insect Swarm on the move',function()
 local a,s=druid(60,{31,0,0},2912,16914,5570,STARSURGE,414684,439748,5185);s.setSeason(2);s.ttd=30
 s.combat=false;M.expect(a,s,SBAL,STARSURGE,nil,'pull: Starsurge');s.combat=true
 M.expect(a,s,SBAL,STARSURGE,nil,'Starsurge buff down: Starsurge')
 s.buff('player',STARSURGE);M.expect(a,s,SBAL,414684,nil,'Sunfire');s.debuff('target',414684)
 M.expect(a,s,SBAL,8921,nil,'Moonfire');s.debuff('target',8921)
 M.expect(a,s,SBAL,2912,nil,'Starsurge-empowered Starfire')
 s.clearAuras();s.cooling(STARSURGE,5);s.debuff('target',414684);s.debuff('target',8921)
 M.expect(a,s,SBAL,5176,nil,'unempowered: Wrath');s.buff('player',408255);M.expect(a,s,SBAL,2912,nil,'Lunar Eclipse: Starfire');s.clearAuras()
 s.debuff('target',414684);s.debuff('target',8921)
 s.near(5);M.expect(a,s,SBAL,5176,nil,'five engaged: no Hurricane');s.near(6);M.expect(a,s,SBAL,16914,nil,'six: Hurricane')
 s.near(4);s.engrave(GALE_WINDS);M.expect(a,s,SBAL,16914,nil,'Gale Winds (a passive rune) engraved: Hurricane at four')
 s.near(3);M.expect(a,s,SBAL,5176,nil,'Gale Winds, three engaged: no Hurricane');s.unengrave(GALE_WINDS);s.near(0)
 s.moving=true;M.expect(a,s,SBAL,5570,nil,'moving: Insect Swarm');s.debuff('target',5570);M.expect(a,s,SBAL,nil,'stopped','moving, DoTs up');s.moving=false
 local lit=M.upkeep(a,s,SBAL);assert(lit[439748],'Starfall in combat')
 friendly(s,40);s.buff('player',414800);lit=M.upkeep(a,s,SBAL);assert(lit[5185],'Fury of Stormrage: instant Healing Touch on a dying friend')
end)

test('SoD Balance variants: Icy Veins keeps Insect Swarm and Hurricane at four; Wowhead extends Sunfire with Wrath',function()
 local a,s=druid(60,{31,0,0},2912,16914,5570,STARSURGE,414684);s.setSeason(2);s.ttd=30
 s.cooling(STARSURGE,5);s.debuff('target',414684,fresh(10));s.debuff('target',8921)
 M.expect(a,s,SBAL,5176,nil,'recommended: no Insect Swarm')
 M.expect(a,s,SBALIV,5570,nil,'Icy Veins: Insect Swarm upkeep')
 s.near(4);M.expect(a,s,SBALIV,16914,nil,'Icy Veins: Hurricane at four');M.expect(a,s,SBAL,5176,nil,'recommended: not at four');s.near(0)
 s.buff('player',408255);M.expect(a,s,SBALWH,2912,nil,'Wowhead: Lunar Eclipse Starfire')
 s.clearAuras();s.debuff('target',414684,fresh(3));s.debuff('target',8921);s.buff('player',408255)
 M.expect(a,s,SBALWH,2912,nil,'Wowhead without Elune\'s Fires: nothing extends Sunfire, Starfire')
 s.engrave(ELUNES_FIRES,414684);M.expect(a,s,SBALWH,5176,nil,'Wowhead with Elune\'s Fires (a passive rune): Wrath extends a short Sunfire first')
 M.expect(a,s,SBAL,2912,nil,'recommended: Starfire')
 s.combat=false;s.cooldown={};M.expect(a,s,SBALWH,5176,nil,'Wowhead pull: Wrath');M.expect(a,s,SBAL,STARSURGE,nil,'recommended pull: Starsurge')
end)

test('SoD Feral cat: Savage Roar, Swipe on four, Mangle debuff, Rip with Roar lasting, Rake, powershift, reminders',function()
 local a,s=druid(60,{0,30,21},CAT,BEAR,5221,1079,1822,16857,SR,407993,411128,417045,417141,407995,779,6807);s.setSeason(2)
 cat(s);behind(s);s.ttd=30;s.debuff('target',16857,fresh(30))
 s.points=1;M.expect(a,s,SFER,SR,nil,'Savage Roar from one combo point')
 s.buff('player',SR,fresh(20));M.expect(a,s,SFER,407993,nil,'Mangle debuff')
 s.debuff('target',407993,{sourceUnit='party1'});M.expect(a,s,SFER,1822,nil,'anyone\'s Mangle counts; Rake')
 s.debuff('target',1822);M.expect(a,s,SFER,5221,nil,'Shred');s.targetTarget='player';M.expect(a,s,SFER,407993,nil,'from the front: Mangle');behind(s)
 s.points=5;M.expect(a,s,SFER,1079,nil,'five points, Roar lasting: Rip')
 s.clearAuras();s.buff('player',CAT);s.buff('player',SR,fresh(5));s.debuff('target',16857,fresh(30));s.debuff('target',407993);s.debuff('target',1822)
 M.expect(a,s,SFER,5221,nil,'Roar about to drop: no Rip')
 s.near(4);M.expect(a,s,SFER,5221,nil,'four engaged without Improved Swipe: no Swipe (Cat)')
 s.engrave(IMPROVED_SWIPE);M.expect(a,s,SFER,411128,nil,'four engaged, Improved Swipe engraved: Swipe (Cat)');s.near(0)
 s.clearAuras();s.buff('player',CAT);s.buff('player',SR,fresh(20));s.debuff('target',407993);s.debuff('target',1822);s.debuff('target',1079)
 M.expect(a,s,SFER,16857,nil,'no Faerie Fire up: Faerie Fire first')
 s.debuff('target',16857,fresh(5));s.usable[5221]=false;s.usable[407993]=false;s.energy=20
 M.expect(a,s,SFER,16857,nil,'Faerie Fire refresh under 8 s before waiting')
 s.clearAuras();s.buff('player',CAT);s.buff('player',SR,fresh(20));s.debuff('target',407993);s.debuff('target',1822);s.debuff('target',1079);s.debuff('target',16857,fresh(30))
 s.setTalent(3,2,5);M.expect(a,s,SFER,CAT,nil,'powershift')
 s.buff('player',417141);M.expect(a,s,SFER,nil,'stopped','no powershift under Berserk')
 local lit=M.upkeep(a,s,SFER);assert(lit[417045],'Tiger\'s Fury at low energy')
 s.buff('player',417045);lit=M.upkeep(a,s,SFER);assert(lit[417141],'Berserk with Tiger\'s Fury')
 bear(s);s.energy=40;M.expect(a,s,SFER,407995,nil,'in Bear Form: Mangle (Bear)')
end)

test('SoD tank: Lacerate refresh, Mangle, Lacerate, packs, pull, reminders; cat weave opt-in',function()
 local a,s=druid(60,{0,30,21},BEAR,DIRE,CAT,LACERATE,407995,779,6807,16857,417141,408024,22842,5229,1822,SR,407993);s.setSeason(2);s.engrave(LACERATE)
 bear(s,DIRE);s.energy=40
 M.expect(a,s,STANK,407995,nil,'Mangle on cooldown')
 s.cooling(407995,4);M.expect(a,s,STANK,LACERATE,nil,'Lacerate filler')
 s.debuff('target',414647,fresh(2));s.cooldown={};M.expect(a,s,STANK,LACERATE,nil,'Lacerate about to drop: refresh first')
 s.clearAuras();s.buff('player',DIRE);s.near(3);M.expect(a,s,STANK,779,nil,'packs: Swipe')
 s.buff('player',417141);M.expect(a,s,STANK,407995,nil,'packs under Berserk: Mangle');s.near(0)
 s.combat=false;s.targetRange={10,25};M.expect(a,s,STANK,16857,nil,'pull from range');s.combat=true;s.targetRange={0,5}
 s.energy=40;local lit=M.upkeep(a,s,STANK);assert(lit[6807],'Maul at 30 rage')
 s.energy=20;lit=M.upkeep(a,s,STANK);assert(not lit[6807],'no Maul below 30 rage')
 s.cooling(407995,4);s.clearAuras();s.buff('player',DIRE);lit=M.upkeep(a,s,STANK);assert(lit[417141],'Berserk once Mangle cools')
 s.health.player=25;lit=M.upkeep(a,s,STANK);assert(lit[408024]and lit[22842],'Survival Instincts and Frenzied Regeneration when low');s.health.player=100
 s.clearAuras();s.powerType=0;M.expect(a,s,STANK,DIRE,nil,'caster form: Dire Bear Form')
 cat(s);s.points=0;M.expect(a,s,STANK,16857,nil,'off-tanking in Cat: the cat list');s.debuff('target',16857,fresh(30));M.expect(a,s,STANK,407993)
 -- Cat weave (disabled by default): shift to Cat when Rake is down, Rake, back to Dire Bear.
 assert(a:SetDefaultRotationEnabled(STANKWS,true));assert(M.selected(a)==STANK)
 bear(s,DIRE);M.expect(a,s,STANKWS,CAT,nil,'cat weave: Rake down, shift to Cat')
 cat(s);s.points=0;M.expect(a,s,STANKWS,407993,nil,'cat weave: Mangle to build Savage Roar')
 s.buff('player',SR);M.expect(a,s,STANKWS,1822,nil,'cat weave: Rake')
 s.debuff('target',1822);M.expect(a,s,STANKWS,DIRE,nil,'cat weave: back to Dire Bear')
end)

test('SoD Restoration: procs, Wild Growth, Swiftmend, Lifebloom stacks, Nourish; Tree of Life reminder',function()
 local a,s=druid(60,{0,0,31},5185,5188,774,8936,18562,LIFEBLOOM,408120,408247,439733,408024,17116);s.setSeason(2)
 friendly(s,80)
 M.expect(a,s,SRES,LIFEBLOOM,nil,'no Lifebloom: Lifebloom')
 s.buff('target',LIFEBLOOM,{applications=3,expirationTime=105});M.expect(a,s,SRES,774,nil,'three fresh stacks: Rejuvenation')
 s.clearAuras();s.buff('target',LIFEBLOOM,{applications=3,expirationTime=100.5});M.expect(a,s,SRES,LIFEBLOOM,nil,'a second left: Lifebloom')
 s.clearAuras();s.buff('target',LIFEBLOOM,{applications=3,expirationTime=105});s.buff('target',774);M.expect(a,s,SRES,408247,nil,'Nourish')
 s.members(85,85,100);M.expect(a,s,SRES,408120,nil,'two hurt nearby: Wild Growth')
 s.cooling(408120,5);s.members(85,85,85);M.expect(a,s,SRES,18562,nil,'three hurt with my HoT up: Swiftmend')
 s.cooldown={};s.party={};s.group=false;s.buff('player',414800);M.expect(a,s,SRES,5185,nil,'Fury of Stormrage: instant Healing Touch')
 s.clearAuras();s.members(60,60,60);local lit=M.upkeep(a,s,SRES);assert(lit[439733]and lit[408024],'Tree of Life and Survival Instincts on a hurt group')
end)

finish()
