-- Classic Era and Season of Discovery Paladin premades: switches, priorities, boundaries and
-- reminders through the real catalog, predicates, composition, build context and sequence executor
-- on a modeled 1.15 client (tests/fixtures/era_premade_model_a.lua).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/era_premade_model_a.lua')
local RET,TWIST,PROT,PROTIV,HOLY='rm.era.paladin.retribution','rm.era.paladin.retribution.twist','rm.era.paladin.protection','rm.era.paladin.protection.icyveins','rm.era.paladin.holy'
local SRET,SRETIV,STWIST,SSTACK,SHOCK='rm.sod.paladin.retribution','rm.sod.paladin.retribution.icyveins','rm.sod.paladin.retribution.twist','rm.sod.paladin.retribution.stacking','rm.sod.paladin.shockadin'
local SPROT,SPROTWS,SHOLY,SHOLYWH='rm.sod.paladin.protection','rm.sod.paladin.protection.wowsims','rm.sod.paladin.holy','rm.sod.paladin.holy.wowhead'
local VANILLA={RET,TWIST,PROT,PROTIV,HOLY}
local SOD={SRET,SRETIV,STWIST,SSTACK,SHOCK,SPROT,SPROTWS,SHOLY,SHOLYWH}
local function paladin(level,season)
 local f,s=M.new('paladin');local a=f.addon
 s.setLevel(level or 60);if season then s.setSeason(season)end
 return a,s,f
end
local function stopped(r,suppress)return r.status=='stopped'and(suppress==nil or r.suppressAttack==suppress)end
local function swingIn(a,s,remain)a.lastMainSwing=100-(s.swing-remain)end

test('every Paladin premade registers valid, localized, sourced, composed and scoped to era',function()
 local a,_,f=paladin()
 local all={};for _,id in ipairs(VANILLA)do all[#all+1]=id end;for _,id in ipairs(SOD)do all[#all+1]=id end
 M.registered(a,f,all,'PALADIN')
 for _,id in ipairs(all)do assert(a:GetDefaultRotationComposition(id),id..' is not composed from the shared blocks')end
 for _,id in ipairs({TWIST,STWIST,SSTACK,SHOCK})do assert(M.row(a,id).envelope.body.disabled==true,id..' must ship disabled')end
 for _,id in ipairs({RET,PROT,PROTIV,HOLY,SRET,SRETIV,SPROT,SPROTWS,SHOLY,SHOLYWH})do assert(not M.row(a,id).envelope.body.disabled,id..' must ship enabled')end
 local top=0;for _,id in ipairs(VANILLA)do top=math.max(top,M.row(a,id).envelope.body.priority or 0)end
 for _,id in ipairs(SOD)do assert((M.row(a,id).envelope.body.priority or 0)>top,id..' must outrank every vanilla premade')end
 for _,source in ipairs(M.row(a,PROTIV).envelope.sources)do assert(not source.url:find('wowsims'),'Icy Veins variant cites wowsims')end
end)

test('standard realm: Retribution by default, Righteous Fury or the Protection tree tanks, Holy in a group',function()
 local a,s=paladin(1);assert(M.selected(a)==RET,'level 1')
 s.setLevel(16);s.buff('player',25780);assert(M.selected(a)==PROT,'Righteous Fury at any spec tanks')
 s.clearAuras();s.setLevel(30);assert(M.selected(a)==RET,'no points spent')
 s.setTalents({0,21,0});assert(M.selected(a)==PROT,'Protection tree')
 assert(M.switch(a,PROTIV)=='match','the Icy Veins variant shares the Protection switch')
 s.setTalents({21,0,0});assert(M.selected(a)==RET,'solo Holy melees');s.group=true;assert(M.selected(a)==HOLY,'Holy in a group')
 s.setTalents({10,0,10});assert(M.selected(a)==RET,'a tie falls back to Retribution')
 s.group=false;s.setLevel(60);s.setTalents({11,5,35});s.learn(20375);assert(M.selected(a)==RET,'twisting is opt-in')
 assert(M.switch(a,TWIST)=='match')
 assert(a:SetDefaultRotationEnabled(TWIST,true));assert(M.selected(a)==TWIST);assert(a:SetDefaultRotationEnabled(TWIST,false))
 assert(a:SetDefaultRotationEnabled(PROT,false));s.setTalents({0,31,20});assert(M.selected(a)==PROTIV,'disabling Protection selects the Icy Veins variant')
 for _,id in ipairs(SOD)do assert(not M.row(a,id).eligible and M.row(a,id).eligibilityReason=='ruleset-mismatch'or M.row(a,id).envelope.body.disabled,id..' eligible off SoD')end
end)

test('Season of Discovery realm: SoD premades win; runes and the Holy tree pick the role',function()
 local a,s=paladin(1,2);assert(M.selected(a)==SRET,'level 1 on SoD')
 for _,id in ipairs({SRET,SRETIV,SPROT,SPROTWS,SHOLY,SHOLYWH})do assert(M.row(a,id).eligible,id)end
 s.learn(407632);assert(M.selected(a)==SRET,'a known Hammer of the Righteous whose rune is not engraved');s.unlearn(407632)
 s.engrave(407632);assert(M.selected(a)==SPROT,'Hammer of the Righteous engraved');s.unengrave(407632)
 s.buff('player',407627);assert(M.selected(a)==SPROT,'SoD Righteous Fury');s.clearAuras()
 s.engrave(407613);assert(M.selected(a)==SRET,'Beacon solo still deals damage');s.group=true;assert(M.selected(a)==SHOLY,'Beacon in a group heals')
 assert(M.switch(a,SHOLYWH)=='match');s.unengrave(407613)
 s.setLevel(40);s.setTalents({30,0,0});assert(M.selected(a)==SHOLY,'Holy tree without Crusader Strike heals')
 assert(M.switch(a,SHOCK)=='no-match','Shockadin needs the Shock and Awe rune');s.engrave(462834);assert(M.switch(a,SHOCK)=='match','Holy tree with Shock and Awe (a passive rune): Shockadin')
 s.unengrave(462834)
 s.engrave(407676);assert(M.selected(a)==SRET,'Holy tree with Crusader Strike is a damage build')
 s.group=false;s.setTalents({0,0,0});assert(M.selected(a)==SRET,'no points on SoD')
 assert(a:SetDefaultRotationEnabled(SRET,false));assert(M.selected(a)==SRETIV,'the Icy Veins Phase 4 variant is next')
 assert(a:SetDefaultRotationEnabled(SRET,true))
 s.setLevel(60);s.setTalents({5,11,35});s.learn(20375);s.engrave(407778);assert(M.switch(a,STWIST)=='match'and M.switch(a,SSTACK)=='match')
 assert(M.selected(a)==SRET,'twisting and stacking are opt-in')
 s.setSeason(nil);assert(M.selected(a)==RET,'back on a standard realm')
end)

test('every premade stops while casting or channelling; melee premades stop without a target',function()
 local a,s=paladin(60);s.learn(20154,20271,879,24275,26573,20925,407798,407676,407778,415068,407632,440658,407669,635,19750)
 for _,id in ipairs({RET,TWIST,PROT,PROTIV,HOLY,SRET,SRETIV,STWIST,SSTACK,SHOCK,SPROT,SPROTWS,SHOLY,SHOLYWH})do
  s.cast=true;assert(stopped(select(2,M.first(a,s,id)),true),id..' casting');s.cast=false
  s.channel=true;assert(stopped(select(2,M.first(a,s,id)),true),id..' channelling');s.channel=false
 end
 s.hostile=false
 for _,id in ipairs({RET,TWIST,PROT,PROTIV,SRET,SRETIV,STWIST,SSTACK,SHOCK,SPROT,SPROTWS})do assert(stopped(select(2,M.first(a,s,id)),true),id..' no target')end
end)

test('vanilla Retribution: seal by weapon speed, pull, Undead, Hammer of Wrath, Judgement, Consecration',function()
 local a,s=paladin(4);s.learn(20154,20271)
 M.expect(a,s,RET,20154,nil,'level 4: Seal of Righteousness')
 s.buff('player',20154);s.combat=false;local r=M.expect(a,s,RET,20271,nil,'pull: Judgement');s.cooling(20271,5)
 r=M.expect(a,s,RET,nil,'stopped','pull ends in a stop');assert(not r.suppressAttack)
 s.combat=true;s.cooldown={};M.expect(a,s,RET,20271,nil,'Judgement on cooldown')
 s.mana.player=10;M.expect(a,s,RET,nil,nil,'low mana: melee');s.mana.player=100
 a,s=paladin(60);s.learn(20154,20375,20271,879,2812,24275,26573,21082);s.swing=3.8;s.usable[24275]=false
 M.expect(a,s,RET,20375,nil,'slow weapon: Seal of Command');s.swing=2.6;M.expect(a,s,RET,20154,nil,'fast weapon: Righteousness')
 s.buff('player',20375)
 s.classification='elite';M.expect(a,s,RET,21082,nil,'elite: Seal of the Crusader first')
 s.buff('player',21082);M.expect(a,s,RET,20271,nil,'judge the Crusader');s.clearAuras()
 s.debuff('target',21183,{sourceUnit='party1'});s.buff('player',20375);M.expect(a,s,RET,20271,nil,'someone else\'s Crusader: plain Judgement')
 s.raid=true;s.clearAuras();s.buff('player',20375);M.expect(a,s,RET,20271,nil,'no Crusader in a raid');s.raid=false;s.classification='normal'
 s.creature='UNDEAD';M.expect(a,s,RET,879,nil,'Undead: Exorcism');s.cooling(879,5);s.near(3,{0,5});M.expect(a,s,RET,2812,nil,'Undead pack: Holy Wrath')
 s.near(0);s.creature='HUMANOID';s.cooldown={}
 s.health.target=15;s.usable[24275]=nil;M.expect(a,s,RET,24275,nil,'execute: Hammer of Wrath');s.health.target=100;s.usable[24275]=false
 s.cooling(20271,5);M.expect(a,s,RET,nil,nil,'Judgement cooling, no Vengeance: melee')
 s.buff('player',20050);M.expect(a,s,RET,26573,nil,'Vengeance: Consecration');s.clearAuras();s.buff('player',20375)
 s.near(2,{0,5});M.expect(a,s,RET,26573,nil,'two close enemies: Consecration')
end)

test('vanilla Retribution reminders: aura, blessing, heal, emergency bubble',function()
 local a,s=paladin(60);s.learn(465,7294,20218,19740,19742,19750,635,642,498,633)
 s.combat=false;s.health.player=50
 local lit=M.upkeep(a,s,RET);assert(lit[20218]and not lit[7294]and lit[19742]and not lit[19740]and lit[19750]and not lit[635],'solo')
 s.group=true;lit=M.upkeep(a,s,RET);assert(lit[19740]and not lit[19742],'group: Might')
 s.buff('player',465);s.buff('player',25782,{sourceUnit='party1'});lit=M.upkeep(a,s,RET);assert(not lit[20218]and not lit[19740],'chosen aura and a Greater Blessing are kept')
 s.combat=true;s.health.player=15;lit=M.upkeep(a,s,RET);assert(lit[642]and not lit[498]and not lit[19750],'bubble')
 s.debuff('player',25771);lit=M.upkeep(a,s,RET);assert(not lit[642],'Forbearance blocks the bubble')
 s.health.player=5;lit=M.upkeep(a,s,RET);assert(lit[633],'Lay on Hands')
end)

test('vanilla seal twisting: swap seals before the swing, then Judgement',function()
 local a,s=paladin(60);s.learn(20154,20375,20271,26573);s.swing=3.6;s.setTalents({0,11,40})
 M.expect(a,s,TWIST,20154,nil,'no seal: Righteousness')
 s.buff('player',20154);swingIn(a,s,0.3);M.expect(a,s,TWIST,20375,nil,'Righteousness before the swing: rank-1 Command')
 assert(M.step(a,TWIST,'twist-to-command').ranked==true)
 s.clearAuras();s.buff('player',20375);M.expect(a,s,TWIST,20154,nil,'Command before the swing: back to Righteousness')
 swingIn(a,s,2);M.expect(a,s,TWIST,20271,nil,'mid swing: Judgement')
end)

test('vanilla Protection: pull, Holy Shield, packs vs one target, Seal of Wisdom on low mana',function()
 local a,s=paladin(60);s.learn(25780,20154,20166,20271,20925,26573,2812,879,21082);s.buff('player',25780)
 s.mana.player=30;M.expect(a,s,PROT,20166,nil,'low mana: Seal of Wisdom');s.mana.player=100
 M.expect(a,s,PROT,20154,nil,'Seal of Righteousness');s.buff('player',20154)
 s.combat=false;M.expect(a,s,PROT,20925,nil,'pull: Holy Shield');s.buff('player',20925);M.expect(a,s,PROT,20271,nil,'pull: Judgement')
 s.cooling(20271,5);M.expect(a,s,PROT,nil,'stopped','pull stops');s.cooldown={};s.combat=true
 M.expect(a,s,PROT,21082,nil,'one target: Seal of the Crusader');s.debuff('target',21183);M.expect(a,s,PROT,20271,nil,'then Judgement')
 s.cooling(20271,5);M.expect(a,s,PROT,26573,nil,'Consecration with mana');s.mana.player=40;M.expect(a,s,PROT,nil,nil,'no Consecration below half mana')
 s.near(2);M.expect(a,s,PROT,26573,nil,'two engaged: Consecration down to 20% mana')
 s.cooling(26573,5);s.creature='UNDEAD';M.expect(a,s,PROT,2812,nil,'Undead pack: Holy Wrath')
 s.near(0);s.cooldown={};s.cooling(20271,5);s.cooling(26573,5);M.expect(a,s,PROT,879,nil,'Undead: Exorcism')
 s.clearAuras();s.buff('player',25780);s.buff('player',20154);M.expect(a,s,PROT,20925,nil,'Holy Shield dropped: recast')
 local lit=M.upkeep(a,s,PROT);assert(not lit[25780],'Righteous Fury up')
 s.clearAuras();s.learn(465,20911,20217,633);lit=M.upkeep(a,s,PROT);assert(lit[25780]and lit[465]and lit[20911]and not lit[20217],'tank upkeep')
 s.health.player=5;lit=M.upkeep(a,s,PROT);assert(lit[633],'Lay on Hands')
end)

test('Protection, Seal of Wisdom variant: keeps Judgement of Wisdom, Consecration, Kings in raids',function()
 local a,s=paladin(60);s.learn(20154,20166,20271,20925,26573,25898);s.buff('player',25780)
 M.expect(a,s,PROTIV,20166,nil,'Seal of Wisdom')
 s.buff('player',20166);s.buff('player',20925);M.expect(a,s,PROTIV,20271,nil,'judge Wisdom onto the target')
 s.debuff('target',20186);M.expect(a,s,PROTIV,26573,nil,'Judgement of Wisdom up: Consecration')
 s.cooling(26573,5);M.expect(a,s,PROTIV,nil,nil,'nothing else solo');s.raid=true;M.expect(a,s,PROTIV,25898,nil,'raid: Greater Blessing of Kings')
end)

test('vanilla Holy: friendly target bands, exact ranks, cleanse, moving, enemy in melee',function()
 local a,s=paladin(60);s.learn(635,3472,19750,19941,20473,4987,1152,20166,20271);s.group=true;s.setTalents({31,0,0})
 s.hostile=false;s.friendly=true
 s.health.target=30;M.expect(a,s,HOLY,635,nil,'below 40%: Holy Light')
 s.health.target=60;M.expect(a,s,HOLY,3472,nil,'below 65%: Holy Light rank 6')
 s.health.target=80;M.expect(a,s,HOLY,19750,nil,'below 85%: Flash of Light')
 s.health.target=90;M.expect(a,s,HOLY,19941,nil,'below 95%: Flash of Light rank 4')
 s.health.target=100;local r=M.expect(a,s,HOLY,nil,'stopped','healthy friend: nothing');assert(r.suppressAttack)
 s.health.target=70;s.moving=true;M.expect(a,s,HOLY,20473,nil,'moving: Holy Shock');s.moving=false
 s.debuff('target',1,{dispelName='Disease'});M.expect(a,s,HOLY,4987,nil,'Cleanse');s.clearAuras()
 a,s=paladin(30);s.learn(635,19750);s.group=true;s.hostile=false;s.friendly=true
 s.health.target=60;M.expect(a,s,HOLY,19750,nil,'rank 6 not learned yet: Flash of Light');s.health.target=30;M.expect(a,s,HOLY,635,nil,'low: Holy Light')
 a,s=paladin(60);s.learn(20166,20271);s.group=true
 M.expect(a,s,HOLY,20166,nil,'enemy in melee: Seal of Wisdom');s.buff('player',20166);M.expect(a,s,HOLY,20271,nil,'Judgement outside raids')
 s.raid=true;M.expect(a,s,HOLY,nil,'stopped','no Judgement in a raid');s.targetRange={20,30};r=M.expect(a,s,HOLY,nil,'stopped','enemy at range');assert(r.suppressAttack)
 s.learn(19746,19742,20216,633);s.hostile=false;s.friendly=true;s.health.target=10;s.raid=false
 local lit=M.upkeep(a,s,HOLY);assert(lit[19746]and lit[19742]and lit[20216]and lit[633],'healer upkeep')
end)

test('SoD Retribution: Martyrdom, Holy Power Divine Storm, slow and fast weapon orders, Consecration',function()
 local a,s=paladin(1,2);s.learn(20154,407798,20271)
 M.expect(a,s,SRET,407798,nil,'level 1: Seal of Martyrdom');s.buff('player',407798)
 s.combat=false;M.expect(a,s,SRET,20271,nil,'pull before Exorcism: Judgement');s.combat=true
 a,s=paladin(60,2);s.learn(407798,20271,415068,407676,407778,26573,2812,24275);s.buff('player',407798,{expirationTime=120,duration=30})
 s.combat=false;M.expect(a,s,SRET,415068,nil,'pull: Exorcism');s.cooling(415068,5);M.expect(a,s,SRET,nil,'stopped','pull stops');s.combat=true;s.cooldown={}
 s.buff('player',1226461,{applications=3});M.expect(a,s,SRET,407778,nil,'three Holy Power: Divine Storm')
 s.clearAuras();s.buff('player',407798,{expirationTime=120,duration=30});s.buff('player',1226461,{applications=1})
 s.swing=3.6;M.expect(a,s,SRET,407676,nil,'slow: Crusader Strike first');s.cooling(407676,4);M.expect(a,s,SRET,415068,nil,'slow: Exorcism')
 s.cooling(415068,4);M.expect(a,s,SRET,407778,nil,'slow: Divine Storm');s.cooling(407778,4);M.expect(a,s,SRET,20271,nil,'slow: Judgement filler')
 s.cooldown={};s.swing=2.4;M.expect(a,s,SRET,415068,nil,'fast: Exorcism first, no Judgement with a fresh seal')
 s.cooling(415068,4);M.expect(a,s,SRET,407676,nil,'fast: Crusader Strike');s.cooling(407676,4)
 M.expect(a,s,SRET,26573,nil,'fast: no Divine Storm while Holy Power builds')
 s.clearAuras();s.buff('player',407798,{expirationTime=101,duration=30});M.expect(a,s,SRET,20271,nil,'fast: judge as the seal runs out')
 s.cooling(20271,5);M.expect(a,s,SRET,407778,nil,'fast without the set: Divine Storm')
 s.cooling(407778,5);s.mana.player=20;M.expect(a,s,SRET,nil,nil,'low mana, one target: melee')
 s.near(3,{0,5});M.expect(a,s,SRET,26573,nil,'three close: Consecration')
 s.cooling(26573,5);M.expect(a,s,SRET,nil,nil,'a humanoid pack without Purifying Power: no Holy Wrath')
 s.engrave(429144);M.expect(a,s,SRET,2812,nil,'Purifying Power (a passive rune): Holy Wrath on any pack')
 s.cooling(2812,5);s.near(0);M.expect(a,s,SRET,nil,nil,'low mana without Improved Hammer of Wrath: no Hammer of Wrath')
 s.engrave(429152);M.expect(a,s,SRET,24275,nil,'Improved Hammer of Wrath (a passive rune): Hammer of Wrath whatever the mana')
end)

test('SoD Retribution reminders: Avenging Wrath at three Holy Power with Aura Mastery',function()
 local a,s=paladin(60,2);s.learn(407788,407624,20218,19740);s.classification='worldboss'
 local lit=M.upkeep(a,s,SRET);assert(lit[407788]and lit[20218],'Avenging Wrath on a boss without the set')
 s.buff('player',1226461,{applications=2});lit=M.upkeep(a,s,SRET);assert(not lit[407788],'wait for three Holy Power')
 s.clearAuras();s.buff('player',1226461,{applications=3});lit=M.upkeep(a,s,SRET);assert(lit[407788])
 s.buff('player',407788);lit=M.upkeep(a,s,SRET);assert(lit[407624],'Aura Mastery with Avenging Wrath')
 s.clearAuras();s.debuff('player',25771);lit=M.upkeep(a,s,SRET);assert(not lit[407788],'Forbearance')
end)

test('SoD Retribution Icy Veins variant: Crusader once, Exorcism, Crusader Strike, Divine Storm, Judgement',function()
 local a,s=paladin(60,2);s.learn(407798,20271,415068,407676,407778,26573,24275,21082);s.buff('player',407798)
 M.expect(a,s,SRETIV,415068,nil,'Exorcism first');s.cooling(415068,5);M.expect(a,s,SRETIV,407676,nil,'Crusader Strike')
 s.cooling(407676,5);M.expect(a,s,SRETIV,407778,nil,'Divine Storm');s.cooling(407778,5);M.expect(a,s,SRETIV,20271,nil,'Judgement on cooldown')
 s.classification='elite';s.cooldown={};M.expect(a,s,SRETIV,21082,nil,'elite: Seal of the Crusader')
end)

test('SoD seal twisting and stacking',function()
 local a,s=paladin(60,2);s.learn(407798,20375,20271,415068,407676,407778);s.swing=3.6
 s.buff('player',407798);swingIn(a,s,0.3);M.expect(a,s,STWIST,20375,nil,'Martyrdom before the swing: Command')
 s.clearAuras();s.buff('player',20375);M.expect(a,s,STWIST,407798,nil,'Command before the swing: Martyrdom')
 swingIn(a,s,1.2);local r=M.expect(a,s,STWIST,nil,'stopped','danger zone holds the global cooldown');assert(not r.suppressAttack)
 s.buff('player',407798);swingIn(a,s,3);M.expect(a,s,STWIST,20271,nil,'both seals: Judgement')
 s.clearAuras();s.buff('player',407798);M.expect(a,s,STWIST,407676,nil,'filler: Crusader Strike')
 s.clearAuras();M.expect(a,s,SSTACK,20375,nil,'stacking: Command');s.buff('player',20375,{expirationTime=120})
 M.expect(a,s,SSTACK,407798,nil,'stacking: Martyrdom');s.buff('player',407798,{expirationTime=120})
 M.expect(a,s,SSTACK,407778,nil,'both up: Divine Storm');s.clearAuras();s.buff('player',20375,{expirationTime=100.5});s.buff('player',407798,{expirationTime=120})
 M.expect(a,s,SSTACK,20375,nil,'Command expiring: recast')
end)

test('Shockadin: Holy Shock keeps Sunlight, then Exorcism',function()
 local a,s=paladin(60,2);s.learn(407798,20473,415068,407676,20271);s.buff('player',407798,{expirationTime=120})
 M.expect(a,s,SHOCK,20473,nil,'Sunlight missing: Holy Shock');s.buff('player',1239543,{expirationTime=120})
 M.expect(a,s,SHOCK,415068,nil,'Sunlight up: Exorcism')
end)

test('SoD Protection: pull, Holy Shield, single target and pack orders, reminders',function()
 local a,s=paladin(60,2);s.learn(407627,407798,20925,407669,415068,407632,440658,20271,407778,26573);s.buff('player',407627);s.buff('player',407798)
 s.combat=false;M.expect(a,s,SPROT,20925,nil,'pull: Holy Shield');s.buff('player',20925);M.expect(a,s,SPROT,407669,nil,'pull: Avenger\'s Shield');s.combat=true
 M.expect(a,s,SPROT,407632,nil,'one target: Hammer of the Righteous');s.cooling(407632,5)
 M.expect(a,s,SPROT,440658,nil,'Shield of Righteousness');s.cooling(440658,5);M.expect(a,s,SPROT,415068,nil,'Exorcism')
 s.near(3);M.expect(a,s,SPROT,407669,nil,'pack: Avenger\'s Shield before Exorcism');s.cooling(407669,5);M.expect(a,s,SPROT,26573,nil,'pack: Consecration')
 s.near(0);s.cooldown={};s.clearAuras();s.buff('player',407798);M.expect(a,s,SPROT,20925,nil,'Holy Shield dropped')
 s.learn(465,20911,407788,458371,633,407631);s.combat=false;local lit=M.upkeep(a,s,SPROT);assert(lit[407627]and lit[20925]and lit[465]and lit[20911],'pre-pull upkeep')
 s.combat=true;s.health.player=30;lit=M.upkeep(a,s,SPROT);assert(lit[407788]and lit[458371]and not lit[633],'defensives')
 s.group=true;s.targetThreat=1;lit=M.upkeep(a,s,SPROT);assert(lit[407631],'taunt when the target attacks someone else')
 s.targetThreat=3;lit=M.upkeep(a,s,SPROT);assert(not lit[407631],'no taunt when tanking')
end)

test('SoD Protection wowsims variant: Judgement first, renew the seal, Shield of Righteousness last',function()
 local a,s=paladin(60,2);s.learn(407798,20925,407669,415068,407632,440658,20271);s.buff('player',407798,{expirationTime=120});s.buff('player',20925)
 M.expect(a,s,SPROTWS,20271,nil,'Judgement whenever a seal is up');s.cooling(20271,5)
 M.expect(a,s,SPROTWS,407669,nil,'Avenger\'s Shield');s.cooling(407669,5);M.expect(a,s,SPROTWS,407632,nil,'Hammer of the Righteous')
 s.clearAuras();s.buff('player',20925);s.buff('player',407798,{expirationTime=101});M.expect(a,s,SPROTWS,407798,nil,'renew an expiring seal')
end)

test('SoD Holy: Divine Light vs Holy Light by mana, Holy Shock, Flash; Holy Light first variant',function()
 local a,s=paladin(60,2);s.learn(407613,458856,635,19750,20473,4987,407798,412019);s.group=true;s.hostile=false;s.friendly=true
 s.health.target=50;M.expect(a,s,SHOLY,458856,nil,'below 60%: Divine Light');s.mana.player=40;M.expect(a,s,SHOLY,635,nil,'low mana: Holy Light');s.mana.player=100
 s.health.target=80;M.expect(a,s,SHOLY,19750,nil,'below 90%: Flash of Light');M.expect(a,s,SHOLYWH,20473,nil,'Wowhead: Holy Shock for light damage')
 s.health.target=70;M.expect(a,s,SHOLYWH,458856,nil,'Wowhead: Divine Light below 75%')
 s.health.target=20;M.expect(a,s,SHOLY,20473,nil,'emergency: Holy Shock')
 s.health.target=100;local lit=M.upkeep(a,s,SHOLY);assert(lit[407613]and lit[412019],'Beacon and Sacred Shield on the friend')
 s.buff('target',407613);s.buff('target',412019);lit=M.upkeep(a,s,SHOLY);assert(not lit[407613]and not lit[412019])
 s.hostile=true;s.friendly=false;M.expect(a,s,SHOLY,407798,nil,'enemy in melee: Seal of Martyrdom')
 s.buff('player',407798);local r=M.expect(a,s,SHOLY,nil,'stopped','then melee');assert(not r.suppressAttack)
end)

finish()
