-- Classic Era and Season of Discovery Mage premades: switches (standard, SoD and Hardcore realms),
-- priorities, boundaries, AoE and reminders through the real catalog, predicates, composition,
-- build context and sequence executor on a modeled 1.15 client (tests/fixtures/era_premade_model_a.lua).
-- Includes the Balefire Bolt safety gate: no premade may advise it at four stacks or more.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/era_premade_model_a.lua')
local FROST,GRIND,FIRE,FIREWCT='rm.era.mage.frost','rm.era.mage.frost.icyveins','rm.era.mage.fire','rm.era.mage.fire.warcrafttavern'
local SFIRE,SFROST,SFROSTWCT,SARCANE,SHEAL='rm.sod.mage.fire','rm.sod.mage.frost','rm.sod.mage.frost.warcrafttavern','rm.sod.mage.arcane','rm.sod.mage.healer'
local VANILLA={FROST,GRIND,FIRE,FIREWCT}
local SOD={SFIRE,SFROST,SFROSTWCT,SARCANE,SHEAL}
local BALEFIRE=428878
local function mage(level,talents,...)
 local f,s=M.new('mage');local a=f.addon
 -- Health forecast seam: s.ttd seconds until the target dies (nil = no forecast).
 a.GetConditionHealthForecast=function()if s.ttd==nil then return false end;return s.ttd end
 s.setLevel(level or 60);s.setTalents(talents or {0,0,0});s.targetRange={28,30}
 s.learn(133,...)
 s.ranged(133,116,2136,2948,11366,10,120,1449,2120,5019,2139,5143,400613,401502,401556,412532,400640,428739,BALEFIRE,400574,400610,401417,412510)
 return a,s,f
end
local function stopped(r)return r.status=='stopped'and r.suppressAttack end

test('all nine Mage premades register valid, localized, sourced and scoped to era (SoD to season:2)',function()
 local a,_,f=mage()
 local all={};for _,id in ipairs(VANILLA)do all[#all+1]=id end;for _,id in ipairs(SOD)do all[#all+1]=id end
 M.registered(a,f,all,'MAGE')
 for _,id in ipairs(all)do assert(a:GetDefaultRotationComposition(id),id..' is not composed from the shared Mage blocks')end
 local lowestSod=math.huge;for _,id in ipairs(SOD)do lowestSod=math.min(lowestSod,M.row(a,id).envelope.body.priority)end
 for _,id in ipairs(VANILLA)do assert((M.row(a,id).envelope.body.priority or 0)<lowestSod,id..' outranks a SoD premade')end
 for _,source in ipairs(M.row(a,FIREWCT).envelope.sources)do assert(source.url:find('warcrafttavern'),'Tavern variant cites another source')end
end)

test('standard realm: Frost owns levels 1-9, no points and ties; Fire by points; AoE grinding solo with Improved Blizzard',function()
 local a,s=mage(1)
 assert(M.selected(a)==FROST,'level 1')
 s.setLevel(30);assert(M.selected(a)==FROST,'no talent points still selects Frost')
 for _,id in ipairs(SOD)do assert(not M.row(a,id).eligible and M.row(a,id).eligibilityReason=='ruleset-mismatch',id..' eligible on a standard realm')end
 s.setTalents({0,5,0});assert(M.selected(a)==FIRE,'Fire points and no Frost points')
 s.setTalents({17,13,0});assert(M.selected(a)==FIRE,'Arcane/Fire without Frost plays Fireball')
 s.setTalents({0,31,3});assert(M.selected(a)==FIRE,'Fire primary with an Elemental Precision dip')
 s.setTalents({10,10,10});assert(M.selected(a)==FROST,'a three-way tie falls back to Frost')
 s.setTalents({31,0,20});assert(M.selected(a)==FROST,'Arcane/Frost plays Frostbolt')
 s.setTalents({0,0,21});s.setTalent(3,10,1);assert(M.selected(a)==GRIND,'solo with Improved Blizzard: AoE grinding')
 s.group=true;assert(M.selected(a)==FROST,'in a group: Frost');s.group=false
 s.setTalents({0,31,3});assert(M.switch(a,FIREWCT)=='match','the Tavern Fire variant shares the Fire switch')
 assert(a:SetDefaultRotationEnabled(FIRE,false));assert(M.selected(a)==FIREWCT,'disabling Fire selects the Tavern variant')
 assert(a:SetDefaultRotationEnabled(FIRE,true));assert(M.selected(a)==FIRE)
 s.setSeason(3,true);assert(M.selected(a)==FIRE,'Hardcore realms use the vanilla premades')
end)

test('Season of Discovery: the SoD premades win; Fire is the default, Frost by tree, Arcane with the Arcane Blast rune, healer by rune',function()
 local a,s=mage(1);s.setSeason(2)
 assert(M.selected(a)==SFIRE,'level 1 on SoD')
 s.setLevel(40);assert(M.selected(a)==SFIRE,'no points')
 s.setTalents({0,0,25});assert(M.selected(a)==SFROST,'Frost primary')
 assert(M.switch(a,SFROSTWCT)=='match');assert(a:SetDefaultRotationEnabled(SFROST,false));assert(M.selected(a)==SFROSTWCT)
 assert(a:SetDefaultRotationEnabled(SFROST,true))
 s.setTalents({25,0,0});assert(M.selected(a)==SFIRE,'Arcane primary without Arcane Blast plays Fire')
 s.learn(400574);assert(M.selected(a)==SFIRE,'a known Arcane Blast whose rune is not engraved is not the rune')
 s.engrave(400574);assert(M.selected(a)==SARCANE,'Arcane primary with Arcane Blast engraved')
 s.setTalents({0,0,0});assert(M.switch(a,SARCANE)=='unavailable'and M.selected(a)==SFIRE,'Arcane Blast without points stays Fire')
 s.engrave(401417);assert(M.selected(a)==SHEAL,'Regeneration engraved: healer')
 s.unengrave(401417);s.engrave(412510);assert(M.selected(a)==SHEAL,'Mass Regeneration engraved: healer')
 s.runesPending=true;s.engrave();assert(M.switch(a,SHEAL)=='unavailable'and M.selected(a)==SFIRE,'runes still loading: the default until they read')
 s.runesPending=false;assert(M.selected(a)==SHEAL,'runes loaded: healer again')
 s.unengrave(412510);s.setSeason(nil);assert(M.selected(a)==FROST,'back on a standard realm')
end)

test('cast, channel, target and out-of-combat boundaries stop every damage premade without melee',function()
 local a,s=mage(60,{0,31,20},116,2136,2948,11366,401502,412532,400574)
 s.setSeason(2)
 for _,id in ipairs({FROST,GRIND,FIRE,FIREWCT,SFIRE,SFROST,SFROSTWCT,SARCANE,SHEAL})do
  s.cast=true;assert(stopped(select(2,M.first(a,s,id))),id..' cast');s.cast=false
  s.channel=true;assert(stopped(select(2,M.first(a,s,id))),id..' channel');s.channel=false
  s.hostile=false;assert(stopped(select(2,M.first(a,s,id))),id..' no target');s.hostile=true
  s.combat=false;assert(stopped(select(2,M.first(a,s,id))),id..' pulled a mob someone else is fighting');s.combat=true
  assert(M.first(a,s,id),id..' gave no advice in plain combat')
 end
end)

test('vanilla Frost: Fireball then Frostbolt, pull, Nova, Missiles in melee, AoE, execute, wand',function()
 local a,s=mage(3);M.expect(a,s,FROST,133,nil,'level 3: Fireball')
 s.combat=false;s.targetCombat=false;M.expect(a,s,FROST,133,nil,'pull: Fireball')
 s.usable[133]=false;M.expect(a,s,FROST,nil,'stopped','pull falls into its Stop');s.usable[133]=nil;s.combat=true;s.targetCombat=true
 s.learn(116,122,5143,120,1449,10,2136,5019);s.setLevel(40);s.setTalents({11,0,29})
 M.expect(a,s,FROST,116,nil,'Frostbolt filler')
 s.usable[116]=false;M.expect(a,s,FROST,5019,nil,'out of mana: wand, never Fireball');s.usable[116]=nil
 s.repeatActive=5019;s.usable[116]=false;M.expect(a,s,FROST,nil,'stopped','an active wand is left running');s.repeatActive=false;s.usable[116]=nil
 s.near(1,{0,5});s.targetThreat=2;M.expect(a,s,FROST,122,nil,'a mob on you: Frost Nova')
 s.classification='worldboss';M.expect(a,s,FROST,116,nil,'no Nova on a raid boss');s.classification='normal'
 s.cooling(122,10);M.expect(a,s,FROST,116,nil,'Nova cooling, no Improved Arcane Missiles')
 s.setTalent(1,3,3);M.expect(a,s,FROST,5143,nil,'Improved Arcane Missiles: Missiles in melee');s.setTalent(1,3,0)
 s.targetThreat=nil;s.near(3,{20,25});M.expect(a,s,FROST,10,nil,'three engaged at range: Blizzard')
 s.near(3,{0,5});M.expect(a,s,FROST,120,nil,'three close: Cone of Cold')
 s.cooling(120,5);M.expect(a,s,FROST,1449,nil,'three close, Cone cooling: Arcane Explosion')
 s.near(0);s.cooldown={};s.moving=true;M.expect(a,s,FROST,2136,nil,'moving: Fire Blast')
 s.mana.player=30;M.expect(a,s,FROST,nil,'stopped','moving on low mana: nothing');s.mana.player=100;s.moving=false
 s.health.target=8;M.expect(a,s,FROST,2136,nil,'finish with Fire Blast');s.cooling(2136,5)
 M.expect(a,s,FROST,5019,nil,'solo finish with the wand');s.group=true;M.expect(a,s,FROST,116,nil,'no wand finish in a group')
 s.classification='elite';s.group=false;M.expect(a,s,FROST,116,nil,'no execute steps on an elite')
end)

test('Frost AoE grinding: Nova, Cone while Nova cools, Blizzard at range, Explosion close, Frostbolt alone',function()
 local a,s=mage(40,{0,0,30},116,122,120,10,1449,1463);s.setTalent(3,10,3)
 s.near(2,{0,5});M.expect(a,s,GRIND,122,nil,'two close: Frost Nova')
 s.cooling(122,10);M.expect(a,s,GRIND,120,nil,'Nova spent: Cone of Cold')
 s.cooling(120,5);M.expect(a,s,GRIND,1449,nil,'both spent, pack on you: Arcane Explosion')
 s.near(2,{15,20});M.expect(a,s,GRIND,10,nil,'pack away from you: Blizzard')
 s.near(0);M.expect(a,s,GRIND,116,nil,'single target: Frostbolt')
 s.combat=false;local lit=M.upkeep(a,s,GRIND);assert(lit[1463],'Mana Shield before the pull')
end)

test('vanilla Fire: Pyroblast pull, Presence of Mind, Improved Scorch, AoE, execute, Combustion',function()
 local a,s=mage(60,{0,31,0},11366,2948,2136,11113,2120,1449,120,10,11129,12043)
 s.combat=false;s.targetCombat=false;M.expect(a,s,FIRE,11366,nil,'pull: Pyroblast');M.expect(a,s,FIREWCT,11366)
 s.combat=true;s.targetCombat=true
 M.expect(a,s,FIRE,133,nil,'no Improved Scorch: Fireball')
 s.buff('player',12043);M.expect(a,s,FIRE,11366,nil,'Presence of Mind: Pyroblast');s.clearAuras()
 s.setTalent(2,10,3);M.expect(a,s,FIRE,133,nil,'Improved Scorch, normal mob without a forecast: no Scorch')
 s.ttd=30;M.expect(a,s,FIRE,2948,nil,'long-lived target: stack Scorch')
 s.debuff('target',22959,{applications=5,expirationTime=125});M.expect(a,s,FIRE,133,nil,'five fresh stacks: Fireball')
 local lit=M.upkeep(a,s,FIRE);assert(lit[11129],'Combustion at five stacks')
 s.clearAuras();s.debuff('target',22959,{applications=5,expirationTime=103});M.expect(a,s,FIRE,2948,nil,'stacks fading: Scorch')
 s.clearAuras();lit=M.upkeep(a,s,FIRE);assert(not lit[11129],'no Combustion before the stacks');s.ttd=nil
 s.classification='elite';M.expect(a,s,FIRE,2948,nil,'elite: Scorch without a forecast');s.classification='normal'
 lit=M.upkeep(a,s,FIREWCT);assert(not lit[11129]);s.classification='worldboss';lit=M.upkeep(a,s,FIREWCT);assert(lit[11129],'Tavern: Combustion at the pull on bosses')
 s.classification='normal';M.expect(a,s,FIREWCT,2948,nil,'Tavern: Scorch to five without a forecast')
 s.setTalent(2,10,0);s.ttd=2;M.expect(a,s,FIRE,2948,nil,'about to die: Scorch finishes');s.ttd=nil
 s.near(3,{0,5});M.expect(a,s,FIRE,11113,nil,'pack close: Blast Wave');M.expect(a,s,FIREWCT,2120,nil,'Tavern opens packs with Flamestrike')
 s.cooling(11113,10);M.expect(a,s,FIRE,2120,nil,'Flamestrike when not burning')
 s.debuff('target',2120);M.expect(a,s,FIRE,1449,nil,'burning: Arcane Explosion')
end)

test('Balefire Bolt is never advised at four stacks or more, by any premade, buff or debuff, nor right after a cast',function()
 local a,s=mage(60,{0,0,0},BALEFIRE,401417);s.setSeason(2)
 local function cases(id,prepare)
  prepare();M.expect(a,s,id,BALEFIRE,nil,id..': no stacks')
  for _,kind in ipairs({'buff','debuff'})do
   s.clearAuras();prepare();s[kind]('player',BALEFIRE,{applications=3});M.expect(a,s,id,BALEFIRE,nil,id..': three '..kind..' stacks')
   for _,n in ipairs({4,5,8})do
    s.clearAuras();prepare();s[kind]('player',BALEFIRE,{applications=n})
    local got=M.first(a,s,id);assert(got~=BALEFIRE,id..': advised Balefire Bolt at '..n..' '..kind..' stacks')
   end
  end
  s.clearAuras();prepare();s.history(BALEFIRE,1);assert(M.first(a,s,id)~=BALEFIRE,id..': advised Balefire Bolt before the last stack landed')
  a.spellHistory={};s.clearAuras()
 end
 -- Fire (in combat and on the pull), Frost (filler and Brain Freeze), Frost Tavern (Brain Freeze), Arcane, healer.
 cases(SFIRE,function()s.combat=true end)
 cases(SFIRE,function()s.combat=false;s.targetCombat=false end);s.combat=true;s.targetCombat=true
 s.setTalents({0,0,30})
 cases(SFROST,function()end)
 s.learn(412532,401502);cases(SFROST,function()s.buff('player',400730)end)
 cases(SFROSTWCT,function()s.buff('player',400730)end)
 s.unlearn(412532,401502)
 s.setTalents({30,0,0});s.learn(400574);s.cooling(400574,5)
 cases(SARCANE,function()end)
 cases(SHEAL,function()end)
end)

test('SoD Fire: Hot Streak, Living Bomb, Scorch below two, Living Flame, Balefire at five stacks, Frostfire, moving, AoE',function()
 local a,s=mage(60,{0,31,0},11366,2948,2136,401502,400613,401556,BALEFIRE,11113,2120,120,10,11129);s.setSeason(2);s.engrave(BALEFIRE)
 s.combat=false;s.targetCombat=false;M.expect(a,s,SFIRE,BALEFIRE,nil,'pull: Balefire Bolt')
 s.known[BALEFIRE]=nil;M.expect(a,s,SFIRE,11366,nil,'pull without Balefire: Pyroblast');s.known[BALEFIRE]=true;s.combat=true;s.targetCombat=true
 s.buff('player',48108);M.expect(a,s,SFIRE,11366,nil,'Hot Streak: Pyroblast')
 s.buff('player',28682);M.expect(a,s,SFIRE,401556,nil,'not under Combustion; no forecast, so no Living Bomb: Living Flame')
 s.clearAuras()
 s.ttd=30;M.expect(a,s,SFIRE,400613,nil,'Living Bomb on a target that will live')
 s.debuff('target',400613);M.expect(a,s,SFIRE,401556,nil,'no Improved Scorch talent: Living Flame')
 s.setTalent(2,10,3);M.expect(a,s,SFIRE,2948,nil,'Improved Scorch without stacks: Scorch')
 s.debuff('target',22959,{applications=2,expirationTime=110});M.expect(a,s,SFIRE,401556,nil,'two stacks: Living Flame')
 s.cooling(401556,10);M.expect(a,s,SFIRE,401502,nil,'Balefire waits for five stacks: Frostfire Bolt')
 s.clearAuras();s.debuff('target',400613);s.debuff('target',22959,{applications=5,expirationTime=110})
 M.expect(a,s,SFIRE,BALEFIRE,nil,'five stacks: Balefire Bolt')
 local lit=M.upkeep(a,s,SFIRE);assert(not lit[11129],'Combustion waits for a Balefire stack')
 s.debuff('player',BALEFIRE,{applications=1});lit=M.upkeep(a,s,SFIRE);assert(lit[11129],'Combustion at five Scorch and a Balefire stack')
 s.clearAuras();s.debuff('target',400613);s.known[401502]=nil;s.known[BALEFIRE]=nil;s.setTalent(2,10,0);M.expect(a,s,SFIRE,133,nil,'no Frostfire rune: Fireball')
 s.clearAuras();s.cooldown={};s.moving=true;M.expect(a,s,SFIRE,400613,nil,'moving: Living Bomb')
 s.debuff('target',400613);M.expect(a,s,SFIRE,401556,nil,'moving: Living Flame');s.cooling(401556,5);M.expect(a,s,SFIRE,2136,nil,'moving: Fire Blast')
 s.moving=false;s.clearAuras();s.cooldown={};s.near(3,{0,5});M.expect(a,s,SFIRE,401556,nil,'pack: Living Flame')
 s.cooling(401556,5);M.expect(a,s,SFIRE,400613,nil,'pack: Living Bomb');s.debuff('target',400613);M.expect(a,s,SFIRE,11113,nil,'pack close: Blast Wave')
 lit=M.upkeep(a,s,SFIRE);assert(not lit[2136],'no Overheat engraved: no Fire Blast reminder')
 s.engrave(400615);lit=M.upkeep(a,s,SFIRE);assert(lit[2136],'Overheat (a passive rune) engraved: Fire Blast reminder')
 s.unengrave(400615);s.learn(400618);lit=M.upkeep(a,s,SFIRE);assert(not lit[2136],'an alternate Fire Blast rank is not Overheat')
end)

test('SoD Frost: Ice Lance at three Glaciate, Deep Freeze on Fingers, Brain Freeze Balefire, filler by rune, Frozen Orb',function()
 local a,s=mage(60,{0,0,31},116,400640,428739,412532,401502,BALEFIRE,440802,10,120,2136);s.setSeason(2)
 s.combat=false;s.targetCombat=false;M.expect(a,s,SFROST,412532,nil,'pull: Spellfrost Bolt');s.combat=true;s.targetCombat=true
 s.history(BALEFIRE,1)
 M.expect(a,s,SFROST,412532,nil,'Spellfrost Bolt filler')
 s.buff('player',400670);M.expect(a,s,SFROST,428739,nil,'Fingers of Frost, low Glaciate: Deep Freeze')
 s.debuff('target',1218345,{applications=3});M.expect(a,s,SFROST,400640,nil,'Fingers of Frost at three Glaciate: Ice Lance')
 s.clearAuras();a.spellHistory={};s.buff('player',400730);M.expect(a,s,SFROST,BALEFIRE,nil,'Brain Freeze: Balefire Bolt');s.clearAuras()
 s.known[BALEFIRE]=nil;s.known[412532]=nil;M.expect(a,s,SFROST,401502,nil,'no Spellfrost: Frostfire Bolt')
 s.known[401502]=nil;M.expect(a,s,SFROST,116,nil,'no bolt runes: Frostbolt')
 local lit=M.upkeep(a,s,SFROST);assert(lit[440802],'Frozen Orb at low Fingers')
 s.buff('player',400647,{applications=2});lit=M.upkeep(a,s,SFROST);assert(not lit[440802],'Frozen Orb held at two Fingers');s.clearAuras()
 s.near(3,{20,25});M.expect(a,s,SFROST,440802,nil,'pack: Frozen Orb');s.cooling(440802,20);M.expect(a,s,SFROST,10,nil,'pack: Blizzard')
 s.near(0);s.moving=true;M.expect(a,s,SFROST,2136,nil,'moving, no procs: Fire Blast')
 s.buff('player',400669);M.expect(a,s,SFROST,400640,nil,'moving with Fingers: Ice Lance')
end)

test('SoD Frost Tavern: Pyroblast pull, Hot Streak, Scorch to five, Balefire only on Brain Freeze, Frostfire',function()
 local a,s=mage(60,{0,10,31},11366,2948,401502,400613,BALEFIRE);s.setSeason(2);s.ttd=30
 s.combat=false;s.targetCombat=false;M.expect(a,s,SFROSTWCT,11366,nil,'pull: Pyroblast');s.combat=true;s.targetCombat=true
 s.buff('player',48108);M.expect(a,s,SFROSTWCT,11366,nil,'Hot Streak');s.clearAuras()
 M.expect(a,s,SFROSTWCT,400613,nil,'Living Bomb');s.debuff('target',400613)
 s.setTalent(2,10,3);M.expect(a,s,SFROSTWCT,2948,nil,'Scorch to five')
 s.debuff('target',22959,{applications=5,expirationTime=120});M.expect(a,s,SFROSTWCT,401502,nil,'no proc: Frostfire, not Balefire')
 s.buff('player',400730);M.expect(a,s,SFROSTWCT,BALEFIRE,nil,'Brain Freeze: Balefire Bolt')
end)

test('SoD Arcane: Missile Barrage, Barrage at four stacks, Living Flame, Arcane Blast, moving and packs',function()
 local a,s=mage(60,{31,0,0},400574,400610,5143,401556,2136,1449,12042,12043);s.setSeason(2)
 s.combat=false;s.targetCombat=false;M.expect(a,s,SARCANE,400574,nil,'pull: Arcane Blast');s.combat=true;s.targetCombat=true
 M.expect(a,s,SARCANE,401556,nil,'Living Flame on cooldown');s.cooling(401556,10)
 M.expect(a,s,SARCANE,400574,nil,'Arcane Blast filler')
 s.buff('player',400573,{applications=3});M.expect(a,s,SARCANE,400574,nil,'three stacks: keep blasting')
 s.clearAuras();s.buff('player',400573,{applications=4});M.expect(a,s,SARCANE,400610,nil,'four stacks: Arcane Barrage')
 s.buff('player',400589);M.expect(a,s,SARCANE,5143,nil,'Missile Barrage first');s.clearAuras()
 s.moving=true;M.expect(a,s,SARCANE,400610,nil,'moving: Arcane Barrage');s.moving=false
 s.near(3,{0,5});s.cooldown={};M.expect(a,s,SARCANE,401556,nil,'pack: Living Flame');s.cooling(401556,5);M.expect(a,s,SARCANE,1449,nil,'pack close: Arcane Explosion')
 s.classification='elite';local lit=M.upkeep(a,s,SARCANE);assert(lit[12042]and not lit[12043],'Arcane Power on elites; Presence of Mind waits for it')
 s.buff('player',12042);lit=M.upkeep(a,s,SARCANE);assert(lit[12043],'Presence of Mind with Arcane Power')
end)

test('SoD healer: beacon management on a friend, damage that heals on an enemy, Frost healer arm',function()
 local a,s=mage(60,{31,0,0},401417,412510,401462,436516,400574,400610,5143,412532);s.setSeason(2);s.engrave(412532)
 s.hostile=false;s.friendly=true;s.ranged(401462,436516,428885)
 M.expect(a,s,SHEAL,401417,nil,'friend without your beacon: Regeneration')
 s.buff('target',400735,{sourceUnit='party1'});M.expect(a,s,SHEAL,401417,nil,'someone else\'s beacon does not count')
 s.clearAuras();s.buff('target',400735);s.health.target=80;M.expect(a,s,SHEAL,412510,nil,'beaconed but hurt: Mass Regeneration')
 s.health.target=40;M.expect(a,s,SHEAL,401462,nil,'beaconed below half: Rewind Time')
 s.cooling(401462,10);M.expect(a,s,SHEAL,436516,nil,'Rewind cooling: Chronostatic Preservation')
 s.cooling(436516,10);s.cooling(412510,10);s.health.target=95;M.expect(a,s,SHEAL,nil,'stopped','healthy and beaconed: nothing to do')
 s.cooldown={};s.health.target=100;s.clearAuras();s.friendly=false;s.hostile=true
 M.expect(a,s,SHEAL,412532,nil,'enemy with Spellfrost engraved: Spellfrost Bolt')
 s.unengrave(412532);M.expect(a,s,SHEAL,400574,nil,'Arcane: Arcane Blast')
 s.buff('player',400573,{applications=2});M.expect(a,s,SHEAL,400610,nil,'two stacks: Arcane Barrage')
 s.buff('player',400589);M.expect(a,s,SHEAL,5143,nil,'Missile Barrage: Missiles')
end)

test('reminders: armor choice, intellect, gems, Ice Barrier, Mana Shield, Evocation, Cold Snap, Icy Veins, decurse',function()
 local a,s=mage(60,{0,0,31},168,7302,6117,1459,10054,10053,11426,1463,12051,12472,122,11958,475,2139)
 s.combat=false;local lit=M.upkeep(a,s,FROST)
 assert(lit[7302]and not lit[6117]and not lit[168]and lit[1459]and lit[11426],'solo: Ice Armor, intellect, Ice Barrier')
 assert(lit[10054]and not lit[10053],'conjure the best gem only')
 s.items[8008]=1;lit=M.upkeep(a,s,FROST);assert(not lit[10054],'gem already in the bags')
 s.group=true;lit=M.upkeep(a,s,FROST);assert(lit[6117]and not lit[7302],'group: Mage Armor')
 s.buff('player',7302);lit=M.upkeep(a,s,FROST);assert(not lit[6117],'an armor you chose is kept')
 s.group=false;s.clearAuras();s.known[7302]=nil;lit=M.upkeep(a,s,FROST);assert(lit[168],'Frost Armor before Ice Armor')
 s.combat=true;s.buff('player',11426);lit=M.upkeep(a,s,FROST);assert(not lit[1459]and not lit[11426]and not lit[1463],'in combat, shielded')
 s.clearAuras();s.targetThreat=2;lit=M.upkeep(a,s,FROST);assert(lit[1463],'Mana Shield while a mob is on you')
 s.mana.player=15;lit=M.upkeep(a,s,FROST);assert(lit[12051]and not lit[1463],'drained: Evocation, no Mana Shield')
 s.mana.player=100;s.health.player=15;lit=M.upkeep(a,s,FROST);assert(lit[11958],'Ice Block when nearly dead')
 s.cooling(122,20);s.near(1,{0,5});lit=M.upkeep(a,s,FROST);assert(lit[12472],'Cold Snap for a second Nova')
 s.health.player=100;s.near(0);s.debuff('player',1,{dispelName='Curse'});lit=M.upkeep(a,s,FROST);assert(lit[475],'Remove Lesser Curse on yourself')
 s.clearAuras();s.targetCast='Heal';lit=M.upkeep(a,s,FROST);assert(lit[2139],'Counterspell an interruptible cast')
 -- SoD: Molten Armor when engraved, Icy Veins, Cold Snap once Icy Veins is spent.
 s.targetCast=nil;s.setSeason(2);s.learn(428741,425121);s.combat=false;s.group=false
 lit=M.upkeep(a,s,SFROST);assert(lit[168]and not lit[428741],'Molten Armor known but not engraved: Frost Armor')
 s.engrave(428741,425121)
 lit=M.upkeep(a,s,SFROST);assert(lit[428741]and not lit[168],'Molten Armor engraved')
 s.combat=true;s.classification='elite';lit=M.upkeep(a,s,SFROST);assert(lit[425121]and not lit[12472],'Icy Veins on elites')
 s.cooldown={};s.cooling(425121,100);lit=M.upkeep(a,s,SFROST);assert(lit[12472],'Cold Snap refreshes Icy Veins')
end)
finish()
