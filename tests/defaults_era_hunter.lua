-- Classic Era and Season of Discovery Hunter premades: switches, priorities, boundaries and
-- reminders through the real catalog, predicates, composition, build context and sequence executor
-- on a modeled 1.15 client (tests/fixtures/era_premade_model_a.lua).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/era_premade_model_a.lua')
local RANGED,CLIPPED,STING='rm.era.hunter.ranged','rm.era.hunter.ranged.icyveins','rm.era.hunter.ranged.wowsims'
local SODR,SODM='rm.sod.hunter.ranged','rm.sod.hunter.melee'
local VANILLA={RANGED,CLIPPED,STING}
local ALL={RANGED,CLIPPED,STING,SODR,SODM}
local function hunter(level,season)
 local f,s=M.new('hunter');local a=f.addon
 if season then s.setSeason(season)end
 s.setLevel(level or 60);s.targetRange={28,30};s.pet=true;s.targetTarget='pet'
 s.learn(75,2973);s.ranged(75,1978,3044,1130,5116,2643,19434,1510,409433,409593,409552,437123,13813,13795,13809)
 return a,s,f
end
local function full(a,s)s.learn(1978,3044,1130,5116,2643,19434,1510,1495,13165,13163,883,982,136,3045,19506,5384)end
local function stopped(r)return r.status=='stopped'and r.suppressAttack end
-- Enable a disabled-by-default variant for behaviour checks.
local function enable(a,id)assert(a:SetDefaultRotationEnabled(id,true))end

test('the Hunter premades register valid, localized, sourced and composed for Era',function()
 local a,_,f=hunter()
 M.registered(a,f,ALL,'HUNTER')
 for _,id in ipairs(ALL)do assert(a:GetDefaultRotationComposition(id),id..' is not composed from the shared Hunter blocks')end
 assert(M.row(a,CLIPPED).envelope.body.disabled and M.row(a,STING).envelope.body.disabled,'the clipped and raid-sting variants are opt-in')
 assert(not M.row(a,RANGED).envelope.body.disabled and not M.row(a,SODR).envelope.body.disabled and not M.row(a,SODM).envelope.body.disabled)
 for _,source in ipairs(M.row(a,STING).envelope.sources)do assert(source.url:find('wowsims'),'the wowsims variant cites only wowsims')end
 for _,source in ipairs(M.row(a,CLIPPED).envelope.sources)do assert(source.url:find('icy%-veins'),'the Icy Veins variant cites only Icy Veins')end
end)

test('switch: one vanilla premade at every level; SoD realms take the SoD packs, melee by rune',function()
 local a,s=hunter(1);assert(M.selected(a)==RANGED,'level 1')
 s.setLevel(30);assert(M.selected(a)==RANGED);s.setLevel(60);s.setTalents({0,31,20});assert(M.selected(a)==RANGED)
 assert(not M.row(a,SODR).eligible and M.row(a,SODR).eligibilityReason=='ruleset-mismatch','SoD premade eligible on a standard realm')
 s.learn(415320);assert(M.selected(a)==RANGED,'a melee rune on a standard realm changes nothing')
 enable(a,CLIPPED);enable(a,STING);assert(M.selected(a)==RANGED,'the recommended premade outranks the opt-in variants')
 assert(a:SetDefaultRotationEnabled(RANGED,false));assert(M.selected(a)==CLIPPED,'Icy Veins next')
 assert(a:SetDefaultRotationEnabled(CLIPPED,false));assert(M.selected(a)==STING,'wowsims last')
 s.setSeason(3,true);assert(a:SetDefaultRotationEnabled(RANGED,true));assert(M.selected(a)==RANGED,'Hardcore uses the vanilla premade')
 a,s=hunter(1,2);assert(M.selected(a)==SODR,'SoD level 1: ranged')
 s.learn(415320);assert(M.selected(a)==SODM,'Flanking Strike engraved: melee')
 s.unlearn(415320);s.learn(425711);assert(M.selected(a)==SODM,'Carve engraved: melee')
 s.learn(409433);assert(M.selected(a)==SODR,'Chimera Shot in the hands slot: ranged')
 s.unlearn(409433,425711);s.learn(458482,409552);assert(M.selected(a)==SODR,'Explosive Shot with Wyvern Strike: ranged')
 s.unlearn(409552);assert(M.selected(a)==SODM,'Wyvern Strike alone: melee')
 s.unlearn(458482);s.learn(415320,409433);assert(M.selected(a)==SODR,'the weave build (Chimera + Flanking) stays ranged')
 s.known={};assert(M.selected(a)==SODR,'a SoD Hunter with nothing learned still gets a premade')
 for _,id in ipairs(VANILLA)do if not M.row(a,id).envelope.body.disabled then assert(M.row(a,id).eligible,id..' must stay eligible on SoD (no rulesets)')end end
end)

test('boundaries: cast, channel, no target and the pull stop every Hunter premade',function()
 local a,s=hunter();full(a,s);enable(a,CLIPPED);enable(a,STING);s.learn(409433,415320)
 for _,id in ipairs(ALL)do
  if id==SODR or id==SODM then s.setSeason(2)else s.setSeason(nil)end
  s.cast=true;assert(stopped(select(2,M.first(a,s,id))),id..' cast');s.cast=false
  s.channel=true;assert(stopped(select(2,M.first(a,s,id))),id..' channel');s.channel=false
  s.hostile=false;assert(stopped(select(2,M.first(a,s,id))),id..' no target');s.hostile=true
  s.combat=false;s.debuff('target',1130);s.debuff('target',1978);s.repeatActive=true;s.cooling(19434,5)
  local _,r=M.first(a,s,id);assert(r.status=='stopped',id..' pull fell through');s.clearAuras();s.repeatActive=false;s.combat=true;s.cooldown={}
 end
end)

test('vanilla pull: Hunter\'s Mark, Aimed Shot, Auto Shot',function()
 local a,s=hunter(6);s.learn(1130);s.combat=false;s.targetCombat=false
 M.expect(a,s,RANGED,1130,nil,'pull: Mark')
 s.debuff('target',1130,{sourceUnit='party1'});M.expect(a,s,RANGED,75,nil,'someone else\'s Mark is kept: Auto Shot')
 s.learn(19434);M.expect(a,s,RANGED,19434,nil,'Aimed Shot opener once learned')
 s.moving=true;M.expect(a,s,RANGED,75,nil,'no Aimed Shot while moving')
 s.repeatActive=true;M.expect(a,s,RANGED,nil,'stopped','Auto Shot already on')
end)

test('vanilla dead zone: Raptor Strike, Mongoose Bite, then melee without suppression',function()
 local a,s=hunter(20);full(a,s);s.targetRange={0,5}
 M.expect(a,s,RANGED,2973,nil,'Raptor Strike in melee')
 s.current[2973]=true;M.expect(a,s,RANGED,1495,nil,'queued Raptor: Mongoose Bite');s.current={}
 s.cooling(2973,4);s.cooling(1495,4);local r=M.expect(a,s,RANGED,nil,'stopped','melee: keep swinging');assert(not r.suppressAttack)
end)

test('vanilla solo leveling: Concussive before a pet, own sting, mana-gated shots, then wait',function()
 local a,s=hunter(8);s.learn(1978,3044,5116,1130);s.pet=false;s.targetTarget='player';s.debuff('target',1130)
 s.repeatActive=true
 M.expect(a,s,RANGED,5116,nil,'no pet and the mob is on you: Concussive Shot')
 s.pet=true;s.targetTarget='pet';M.expect(a,s,RANGED,1978,nil,'Serpent Sting')
 s.debuff('target',1978);M.expect(a,s,RANGED,3044,nil,'Arcane Shot with spare mana')
 s.mana.player=40;local r=M.expect(a,s,RANGED,nil,'stopped','low mana: let Auto Shot and the pet work');assert(r.suppressAttack)
 s.mana.player=100;s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{sourceUnit='party1'})
 M.expect(a,s,RANGED,1978,nil,'someone else\'s sting does not count')
 s.clearAuras();s.debuff('target',1130);s.debuff('target',3043);M.expect(a,s,RANGED,3044,nil,'own Scorpid Sting blocks Serpent')
 s.clearAuras();s.debuff('target',1130);s.health.target=20;M.expect(a,s,RANGED,3044,nil,'no sting on a dying mob')
 s.health.target=100;s.learn(19434,2643);s.debuff('target',1978)
 M.expect(a,s,RANGED,3044,nil,'Aimed Shot waits for an Auto Shot')
 s.history(75,.2);M.expect(a,s,RANGED,19434,nil,'right after an Auto: Aimed Shot')
end)

test('vanilla group: full rotation after Auto Shot, sting outside raids, Arcane for the dying',function()
 local a,s=hunter();full(a,s);s.group=true;s.repeatActive=true;s.debuff('target',1130)
 local r=M.expect(a,s,RANGED,nil,'stopped','no Auto yet: wait');assert(r.suppressAttack)
 s.history(75,.3);M.expect(a,s,RANGED,19434,nil,'Aimed after the Auto')
 s.cooling(19434,5);M.expect(a,s,RANGED,2643,nil,'Multi-Shot after the Auto')
 a.spellHistory={};s.history(75,.8);M.expect(a,s,RANGED,2643,nil,'Multi-Shot window is one second')
 a.spellHistory={};s.history(75,1.5);s.cooling(2643,5)
 M.expect(a,s,RANGED,nil,'stopped','Serpent needs a long fight (no forecast)')
 a.GetConditionHealthForecast=function()return 30 end
 s.instance='raid';M.expect(a,s,RANGED,nil,'stopped','no Serpent Sting in raids')
 s.instance='party';M.expect(a,s,RANGED,1978,nil,'a long fight in a dungeon: Serpent Sting in the open spot')
 s.debuff('target',1978,{expirationTime=120})
 enable(a,CLIPPED)
 a.spellHistory={};s.cooldown={}
 M.expect(a,s,CLIPPED,19434,nil,'clipped: Aimed Shot as soon as it is ready')
 s.cooling(19434,5);M.expect(a,s,CLIPPED,2643,nil,'clipped: Multi-Shot as soon as it is ready')
 s.cooling(2643,5);M.expect(a,s,CLIPPED,nil,'stopped','clipped: never Serpent Sting')
 s.unlearn(19434);s.cooldown={};s.cooling(2643,5);M.expect(a,s,RANGED,3044,nil,'before Aimed Shot: Arcane Shot')
 a.GetConditionHealthForecast=function()return 2 end;s.learn(19434);M.expect(a,s,RANGED,3044,nil,'a target dying before Aimed lands: Arcane Shot')
end)

test('wowsims variant: Serpent Sting in raids once Aimed and Multi are cooling',function()
 local a,s=hunter();full(a,s);enable(a,STING);s.group=true;s.instance='raid';s.repeatActive=true;s.debuff('target',1130)
 s.history(75,2);s.cooling(2643,5)
 M.expect(a,s,STING,nil,'stopped','Aimed ready soon: no sting yet')
 s.cooling(19434,5);M.expect(a,s,STING,1978,nil,'both cooling: Serpent Sting in a raid')
 s.debuff('target',1978,{expirationTime=120});M.expect(a,s,STING,nil,'stopped','sting with time left')
 s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=103});M.expect(a,s,STING,1978,nil,'refresh under 5 s')
 s.unlearn(3044);s.learn(3044);s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120})
 M.expect(a,s,STING,nil,'stopped','never Arcane Shot')
end)

test('vanilla moving and AoE branches',function()
 local a,s=hunter();full(a,s);s.debuff('target',1130);s.repeatActive=true
 s.moving=true;M.expect(a,s,RANGED,1978,nil,'moving: Serpent Sting');s.debuff('target',1978)
 M.expect(a,s,RANGED,3044,nil,'moving: Arcane Shot');s.cooling(3044,4)
 M.expect(a,s,RANGED,nil,'stopped','moving: never Multi-Shot');s.moving=false;s.cooldown={}
 s.near(3,{25,30});s.history(75,.4);M.expect(a,s,RANGED,2643,nil,'three engaged: Multi-Shot after the Auto')
 s.cooling(2643,5);M.expect(a,s,RANGED,19434,nil,'three engaged at range: no Volley (fewer than four near), single target goes on')
 s.near(4,{10,15});M.expect(a,s,RANGED,1510,nil,'four near: Volley while Multi-Shot cools')
end)

test('vanilla reminders: aspects, pet care, worth-it cooldowns, safety',function()
 local a,s=hunter(5);s.learn(13163);s.combat=false
 local lit=M.upkeep(a,s,RANGED);assert(lit[13163],'Monkey before Hawk')
 s.learn(13165);lit=M.upkeep(a,s,RANGED);assert(lit[13165]and not lit[13163],'Hawk replaces Monkey')
 s.buff('player',5118);lit=M.upkeep(a,s,RANGED);assert(not lit[13165],'a chosen Cheetah out of combat is kept')
 s.combat=true;lit=M.upkeep(a,s,RANGED);assert(lit[13165],'Cheetah in combat: back to Hawk');s.clearAuras()
 s.learn(883,982,136,3045,19574,19577,5384,19506,20554);s.pet=false;lit=M.upkeep(a,s,RANGED);assert(lit[883]and lit[19506],'Call Pet, Trueshot Aura')
 s.pet=true;s.health.pet=30;lit=M.upkeep(a,s,RANGED);assert(lit[136],'Mend Pet')
 s.buff('pet',136);lit=M.upkeep(a,s,RANGED);assert(not lit[136],'Mend Pet already on');s.health.pet=100
 assert(not lit[3045]and not lit[19574],'no cooldowns on a normal mob without a forecast')
 s.classification='elite';lit=M.upkeep(a,s,RANGED);assert(lit[3045]and lit[19574]and not lit[20554],'elite: Rapid Fire, Bestial Wrath')
 s.buff('player',3045);lit=M.upkeep(a,s,RANGED);assert(lit[20554]and not lit[3045],'Berserking inside Rapid Fire')
 s.clearAuras();s.classification='normal';s.instance='party';lit=M.upkeep(a,s,RANGED);assert(lit[3045],'dungeons count')
 s.instance=nil;s.targetTarget='player';lit=M.upkeep(a,s,RANGED);assert(lit[19577],'Intimidation when solo and attacked')
 s.health.player=30;lit=M.upkeep(a,s,RANGED);assert(lit[5384],'Feign Death when low with a pet')
 s.health.player=100;s.group=true;s.targetThreat=3;lit=M.upkeep(a,s,RANGED);assert(lit[5384]and not lit[19577],'Feign Death on aggro in a group')
 enable(a,CLIPPED);s.group=false;s.targetThreat=nil;lit=M.upkeep(a,s,CLIPPED);assert(lit[3045]and lit[19574],'Icy Veins: cooldowns every pull')
end)

test('SoD ranged: Kill Shot build priorities',function()
 local a,s=hunter(60,2);full(a,s);s.learn(409433,409593,13813);s.debuff('target',1130);s.repeatActive=true
 M.expect(a,s,SODR,1978,nil,'Serpent Sting first');s.debuff('target',1978,{expirationTime=110})
 M.expect(a,s,SODR,409593,nil,'Kill Shot while Trick Shots is below four and nothing else is pending')
 s.buff('player',1233451,{applications=4});M.expect(a,s,SODR,2643,nil,'four Trick Shots: Multi-Shot');s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=110})
 s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=104});M.expect(a,s,SODR,409433,nil,'sting under 6 s: Chimera Shot refreshes it')
 s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120})
 s.buff('player',3045);s.buff('player',1233451,{applications=4});s.cooling(409433,4);M.expect(a,s,SODR,2643,nil,'Trick Shots beats Rapid Fire');s.clearAuras();s.cooldown={}
 s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.buff('player',3045)
 M.expect(a,s,SODR,409433,nil,'Rapid Fire: Chimera refresh first (it keeps the sting)')
 s.cooling(409433,4);M.expect(a,s,SODR,409593,nil,'Rapid Fire: Kill Shot');s.clearAuras();s.cooldown={}
 s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.cooling(409593,8)
 s.buff('player',1233451,{applications=3});s.health.target=15;M.expect(a,s,SODR,409433,nil,'execute: Chimera Shot')
 s.health.target=100;s.cooling(409433,4);M.expect(a,s,SODR,2643,nil,'Multi-Shot ready: Multi-Shot')
 s.cooling(2643,3);M.expect(a,s,SODR,13813,nil,'Multi-Shot away: Explosive Trap')
 s.cooling(13813,10);M.expect(a,s,SODR,3044,nil,'then Arcane Shot')
 s.cooling(2643,.8);M.expect(a,s,SODR,nil,'stopped','Multi-Shot nearly back: wait for it')
end)

test('SoD ranged: Lock and Load / Sniper Training and leveling arm',function()
 local a,s=hunter(60,2);full(a,s);s.learn(409433,13813,13795,13809);s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.repeatActive=true
 M.expect(a,s,SODR,409433,nil,'Chimera Shot on cooldown')
 s.cooling(409433,5);M.expect(a,s,SODR,2643,nil,'no Sniper Training, no Auto yet: Multi-Shot')
 s.history(75,.2);M.expect(a,s,SODR,19434,nil,'right after an Auto: Aimed Shot')
 a.spellHistory={};s.buff('player',415401,{applications=2});M.expect(a,s,SODR,19434,nil,'two Sniper Training stacks: Aimed Shot')
 s.buff('player',415414);M.expect(a,s,SODR,2643,nil,'Lock and Load up: Chimera first, no Aimed')
 s.clearAuras();s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.cooling(19434,5);s.cooling(409433,1)
 M.expect(a,s,SODR,13813,nil,'Chimera nearly back: a trap feeds Lock and Load')
 s.cooling(13813,10);M.expect(a,s,SODR,13795,nil,'then Immolation Trap')
 a,s=hunter(20,2);s.learn(1978,3044,2643,437123,409552);s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.repeatActive=true
 M.expect(a,s,SODR,409552,nil,'leveling: Explosive Shot');s.cooling(409552,4)
 M.expect(a,s,SODR,437123,nil,'leveling: Steady Shot')
 s.moving=true;M.expect(a,s,SODR,3044,nil,'moving: instants only')
end)

test('SoD ranged: dead zone, AoE, reminders',function()
 local a,s=hunter(60,2);full(a,s);s.learn(409593,415320,13813);s.targetRange={0,5}
 M.expect(a,s,SODR,409593,nil,'in melee: Kill Shot (no minimum range)');s.cooling(409593,5)
 M.expect(a,s,SODR,415320,nil,'in melee: Flanking Strike');s.targetRange={28,30}
 s.debuff('target',1130);s.debuff('target',1978,{expirationTime=120});s.repeatActive=true;s.near(3,{25,30})
 M.expect(a,s,SODR,13813,nil,'three engaged: Explosive Trap')
 s.cooling(13813,10);M.expect(a,s,SODR,2643,nil,'then Multi-Shot')
 s.near(0);s.learn(415423,409580,428726);s.mana.player=8;local lit=M.upkeep(a,s,SODR)
 assert(lit[415423]and lit[409580]and not lit[13165],'Viper below 10%, Heart of the Lion')
 s.buff('player',415423);s.mana.player=40;lit=M.upkeep(a,s,SODR);assert(not lit[13165],'Viper held until half mana')
 s.mana.player=60;lit=M.upkeep(a,s,SODR);assert(lit[13165],'back to Hawk')
 s.clearAuras();s.buff('pet',428728,{applications=5});lit=M.upkeep(a,s,SODR);assert(lit[428726],'Focus Fire at five Frenzy')
 s.classification='elite';s.cooling(409593,5);lit=M.upkeep(a,s,SODR);assert(not lit[3045],'Rapid Fire waits for Kill Shot')
 s.cooldown={};lit=M.upkeep(a,s,SODR);assert(lit[3045],'Rapid Fire with Kill Shot ready')
end)

test('SoD melee: Flanking upkeep, Raptor Fury, fillers, out-of-reach shots, AoE',function()
 local a,s=hunter(60,2);full(a,s);s.learn(415320,458436,425711,2974,13795,13813);s.targetRange={0,5}
 s.combat=false;s.targetCombat=false;local r=M.expect(a,s,SODM,1130,nil,'pull: Mark')
 s.debuff('target',1130);r=M.expect(a,s,SODM,nil,'stopped','pull in melee: stop and swing');assert(not r.suppressAttack)
 s.targetRange={28,30};M.expect(a,s,SODM,1978,nil,'pull from range: Serpent Sting');s.combat=true;s.targetCombat=true
 s.debuff('target',1978);M.expect(a,s,SODM,2643,nil,'out of reach: Multi-Shot');s.targetRange={0,5}
 M.expect(a,s,SODM,415320,nil,'no Flanking buff: Flanking Strike')
 s.buff('player',415320,{applications=3,expirationTime=110});M.expect(a,s,SODM,2973,nil,'three Flanking stacks: Raptor Strike')
 s.clearAuras();s.debuff('target',1130);s.buff('player',415320,{applications=3,expirationTime=101.5})
 M.expect(a,s,SODM,415320,nil,'Flanking about to drop: refresh')
 s.clearAuras();s.debuff('target',1130);s.buff('player',415320,{applications=3,expirationTime=110});s.buff('player',415358,{applications=4})
 M.expect(a,s,SODM,1495,nil,'four Raptor Fury: Mongoose Bite')
 s.buff('player',467331);M.expect(a,s,SODM,458436,nil,'Clever Strikes: Wyvern Strike')
 s.clearAuras();s.debuff('target',1130);s.buff('player',415320,{applications=3,expirationTime=110})
 s.cooling(2973,4);s.cooling(1495,4);s.cooling(458436,6);s.cooling(415320,20);s.cooling(425711,5)
 M.expect(a,s,SODM,13795,nil,'empty gap: Immolation Trap');s.cooling(13795,10)
 M.expect(a,s,SODM,2974,nil,'then Wing Clip');s.cooldown={}
 s.near(3);M.expect(a,s,SODM,425711,nil,'three engaged: Carve')
 s.near(0);s.learn(469145,415423,20572);local lit=M.upkeep(a,s,SODM);assert(lit[469145]and not lit[13165],'Falcon at 60')
 s.classification='elite';lit=M.upkeep(a,s,SODM);assert(lit[3045],'Rapid Fire with two Flanking stacks')
 s.clearAuras();lit=M.upkeep(a,s,SODM);assert(not lit[3045],'no Flanking stacks yet')
 s.mana.player=4;lit=M.upkeep(a,s,SODM);assert(lit[415423],'Viper below 5%')
end)
finish()
