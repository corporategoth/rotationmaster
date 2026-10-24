-- TBC Warlock premades: all trees after Icy Veins (recommended) and the Wowhead drain-tank
-- variant. Real catalog, composition, predicates, sequence executor, readiness and auto-select
-- order; native observations are modeled (tests/fixtures/tbc_premades.lua). The armor cases
-- carry the deliberate Demon Armor over Demon Skin policy (formerly defaults_warlock_armor.lua).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/tbc_premades.lua')
local IV,WH='rm.tbc.warlock.dps.icyveins','rm.tbc.warlock.dps.wowhead'
local function fixture(level,...)
 local f,s=M.new('warlock');s.learn(686,348,687,688,...);s.setLevel(level or 70);return f.addon,s,f
end
-- A level-60ish Affliction kit.
local function kit(...)return fixture(60,172,980,1454,689,1120,5019,706,697,603,1490,18265,...)end
local function dots(s,...)for _,id in ipairs({...})do s.debuff('target',id)end end
local function stopped(r)return r.status=='stopped'and r.suppressAttack end
local function lit(a,s,id)return M.upkeep(a,s,id or IV)end
local function armorOnly(a,s,want)
 local l=lit(a,s);local got={}
 for _,id in ipairs({28176,706,687})do if l[id]then got[#got+1]=id end end
 assert(#got==(want and 1 or 0)and(not want or got[1]==want),'armor reminders: '..table.concat(got,','))
end

test('both premades register valid, localized and composed with the same switch',function()
 local a,_,f=fixture(1)
 for _,id in ipairs({IV,WH})do local row=M.row(a,id)
  assert(row.readOnly and row.validation.valid and row.validation.resolved and row.eligible,id)
  assert(f.translations[row.nameKey]and f.translations[row.descriptionKey]and a:GetDefaultRotationComposition(id),id)
  assert(row.applicability.minLevel==nil and row.applicability.maxLevel==nil)
  assert(M.switch(a,id)=='match',id)
 end
 for _,source in ipairs(M.row(a,WH).envelope.sources)do assert(not source.url:find('icy%-veins'),'Wowhead variant cites Icy Veins')end
end)

test('auto-select picks the Icy Veins premade at every level; the Wowhead one when chosen',function()
 local a,s=fixture(1)
 for _,level in ipairs({1,9,10,35,70})do s.setLevel(level)
  for _,talents in ipairs({{0,0,0},{21,0,0},{0,41,0},{10,10,10}})do s.talents=talents;assert(M.selected(a)==IV,level)end
 end
 assert(a:SetDefaultRotationEnabled(IV,false));assert(M.selected(a)==WH)
end)

test('cast, channel and target boundaries stop without melee',function()
 local a,s=kit()
 for _,id in ipairs({IV,WH})do
  s.cast=true;assert(stopped(select(2,M.first(a,s,id))));s.cast=false
  s.channel=true;assert(stopped(select(2,M.first(a,s,id))),'Drain Life channel must be kept');s.channel=false
  s.exists=false;assert(stopped(select(2,M.first(a,s,id))));s.exists=true
  s.combat=false;assert(stopped(select(2,M.first(a,s,id))),'pulled a mob someone else is fighting');s.combat=true
  s.targetCombat=false;s.combat=false;assert(M.first(a,s,id),id..' cannot pull a fresh mob')
  s.targetCombat=true;s.combat=true
 end
end)

test('training stages: level 1 Immolate and Shadow Bolt; curse and DoTs as learned',function()
 local a,s=fixture(1)
 assert(M.first(a,s,IV)==348);dots(s,348);assert(M.first(a,s,IV)==686)
 s.mana.player=30;s.clearAuras();assert(M.first(a,s,IV)==686,'solo Immolate needs 40% mana')
 a,s=kit();assert(M.first(a,s,IV)==980,'curse first')
 dots(s,980);assert(M.first(a,s,IV)==348);dots(s,348);assert(M.first(a,s,IV)==172);dots(s,172);assert(M.first(a,s,IV)==18265)
 dots(s,18265);assert(M.first(a,s,IV)==5019,'healthy solo Warlock wands')
 s.learn(30108);s.clearAuras();dots(s,980);assert(M.first(a,s,IV)==30108,'Unstable Affliction before Immolate')
end)

test('cast-time DoTs are refreshed one cast before they expire; instants only when gone',function()
 local a,s=kit();dots(s,980)
 s.debuff('target',348,{expirationTime=110,duration=15});dots(s,172,18265);assert(M.first(a,s,IV)==5019)
 s.auras.target.HARMFUL[2].expirationTime=101;assert(M.first(a,s,IV)==348)
 s.auras.target.HARMFUL[2].expirationTime=110;s.auras.target.HARMFUL[3].sourceUnit='party1';assert(M.first(a,s,IV)==172,'another Warlock\'s Corruption is not ours')
end)

test('solo sustain: Drain Life when hurt, Life Tap when healthy, wand, Destruction skips the wand',function()
 local a,s=kit();dots(s,980,348,172,18265)
 s.health.player=50;assert(M.first(a,s,IV)==689)
 s.health.player=90;s.mana.player=20;assert(M.first(a,s,IV)==1454)
 s.mana.player=80;assert(M.first(a,s,IV)==5019)
 s.repeatActive=true;local id,r=M.first(a,s,IV);assert(id==nil and stopped(r),'active wand toggled off')
 s.repeatActive=false;s.talents={0,0,21};assert(M.first(a,s,IV)==686,'deep Destruction fills with Shadow Bolt')
 s.group=true;s.talents={0,0,0};assert(M.first(a,s,IV)==686,'groups never wand')
end)

test('a dying solo target gets Drain Soul or a finisher, not new DoTs',function()
 local a,s=kit();s.health.target=15
 assert(M.first(a,s,IV)==1120,'Drain Soul for a shard')
 s.items[6265]=5;assert(M.first(a,s,IV)==5019,'shards full: no Drain Soul and no DoTs')
 s.learn(17877);assert(M.first(a,s,IV)==17877)
 s.talent['1:4']=2;assert(M.first(a,s,IV)==1120,'Improved Drain Soul keeps draining for mana')
 s.group=true;assert(M.first(a,s,IV)==1490,'in a group the dying rule does not apply')
end)

test('group curse: Elements unless someone has it, then Agony; one curse at a time',function()
 local a,s=kit();s.group=true
 assert(M.first(a,s,IV)==1490)
 s.debuff('target',1490,{sourceUnit='party1'});assert(M.first(a,s,IV)==980)
 s.clearAuras();dots(s,1490);assert(M.first(a,s,IV)~=980,'a second curse would replace ours')
end)

test('group DoT policy differs: Icy Veins gates Immolate, Wowhead always casts it after Siphon',function()
 local a,s=kit();s.group=true;dots(s,1490,172,18265)
 assert(M.first(a,s,IV)==686,'Icy Veins: no Immolate without Improved Scorch or Destruction')
 assert(M.first(a,s,WH)==348,'Wowhead: Immolate always in a group')
 s.debuff('target',22959,{sourceUnit='party2'});assert(M.first(a,s,IV)==348,'Improved Scorch enables Immolate')
 s.clearAuras();dots(s,1490);assert(M.first(a,s,IV)==172)
 s.debuff('target',22959,{sourceUnit='party2'});assert(M.first(a,s,IV)==348,'Icy Veins: Immolate before Corruption')
 assert(M.first(a,s,WH)==172,'Wowhead: Corruption before Immolate')
 s.raid=true;s.clearAuras();dots(s,1490,172);assert(M.first(a,s,IV)==686,'raid Siphon Life waits for Improved Shadow Bolt')
 s.debuff('target',17800,{sourceUnit='raid3'});assert(M.first(a,s,IV)==18265)
end)

test('solo filler differs: Icy Veins wands, Wowhead drain-tanks and saves Immolate for elites',function()
 local a,s=kit();dots(s,980,348,172,18265)
 assert(M.first(a,s,IV)==5019 and M.first(a,s,WH)==689)
 s.clearAuras();dots(s,980,172)
 assert(M.first(a,s,WH)==689,'Wowhead: no Immolate or Siphon on a normal mob')
 s.classification='elite';assert(M.first(a,s,WH)==18265);dots(s,18265);assert(M.first(a,s,WH)==348)
end)

test('procs come first: Shadow Trance and Backlash',function()
 local a,s=kit(29722);s.buff('player',17941);assert(M.first(a,s,IV)==686)
 s.clearAuras();s.buff('player',34936);assert(M.first(a,s,IV)==686)
 s.buff('player',18789);assert(M.first(a,s,IV)==29722,'Backlash with Burning Wish: Incinerate')
end)

test('moving: instants only, Corruption only with five points of Improved Corruption',function()
 local a,s=kit();s.moving=true;s.mana.player=50;dots(s,980,18265)
 assert(M.first(a,s,IV)==1454,'Life Tap while moving with mana to gain')
 s.mana.player=100;local id,r=M.first(a,s,IV);assert(id==nil and stopped(r),'cast-time spell offered while moving')
 s.talent['1:2']=5;assert(M.first(a,s,IV)==172)
end)

test('three engaged enemies: Seed, Hellfire on you, then single target',function()
 local a,s=kit(27243,1949);s.engage(3,0);assert(M.first(a,s,IV)==27243)
 dots(s,27243);assert(M.first(a,s,IV)==980,'single-target DoTs continue after the AoE arm')
 s.engage(3,3);assert(M.first(a,s,IV)==1949);s.health.player=40;assert(M.first(a,s,IV)==980)
end)

test('pet upkeep: Imp early, Voidwalker solo, Imp in groups, Felguard, nothing after a sacrifice',function()
 local a,s=fixture(5);s.combat=false
 assert(lit(a,s)[688]);s.combat=true;assert(not lit(a,s)[688],'summons wait for the end of combat')
 a,s=kit();s.combat=false;local l=lit(a,s);assert(l[697]and not l[688])
 s.group=true;l=lit(a,s);assert(l[688]and not l[697])
 s.learn(30146);l=lit(a,s);assert(l[30146]and not l[688])
 s.known[30146]=nil;s.buff('player',18790);l=lit(a,s);assert(not l[688]and not l[697],'sacrificed demon resummoned')
 s.clearAuras();s.pet=true;s.learn(18788);assert(lit(a,s)[18788]);s.learn(19028);l=lit(a,s);assert(l[19028]and not l[18788])
end)

-- Armor policy (carried from tests/defaults_warlock_armor.lua): Demon Armor over Demon Skin,
-- now with Fel Armor above both.
test('active Demon Armor never recommends a downgrade to Demon Skin',function()
 local a,s=fixture(20);s.learn(706);s.buff('player',706);armorOnly(a,s,nil);assert(M.first(a,s,IV)==348)
end)
test('untrained Armor keeps Skin; known Armor upgrades an active Skin',function()
 local a,s=fixture(20);armorOnly(a,s,687)
 s.buff('player',687);armorOnly(a,s,nil)
 s.learn(706);armorOnly(a,s,706);s.clearAuras();armorOnly(a,s,706)
 s.known[687]=nil;armorOnly(a,s,706);s.known[706]=nil;armorOnly(a,s,nil)
end)
test('an active Armor suppresses Skin even when learned state says untrained',function()
 local a,s=fixture(20);s.buff('player',706);armorOnly(a,s,nil)
 s.clearAuras();s.buff('player',28176);armorOnly(a,s,nil)
end)
test('Fel Armor is preferred once learned but never replaces a chosen Demon Armor',function()
 local a,s=fixture(62);s.learn(706,28176);armorOnly(a,s,28176)
 s.buff('player',687);armorOnly(a,s,28176);s.clearAuras();s.buff('player',706);armorOnly(a,s,nil)
end)
test('a preferred armor never falls back for mapping, usability, cooldown, range or mana',function()
 for _,mode in ipairs({'unmapped','unusable','cooldown','range','power'})do
  for _,preferred in ipairs({706,28176})do
   local a,s=fixture(62);s.learn(706);if preferred==28176 then s.learn(28176)end
   if mode=='unmapped'then s.mapped[preferred]=false elseif mode=='unusable'then s.usable[preferred]=false
   elseif mode=='cooldown'then s.cooldown[preferred]={startTime=90,duration=30,isEnabled=true,modRate=1}
   elseif mode=='range'then s.range[preferred]=false else s.power[preferred]=true end
   local l=M.upkeep(a,s,IV);assert(not l[706]and not l[687]and not l[28176],mode..' '..preferred)
   assert(M.first(a,s,IV)==348,'armor readiness changed damage advice')
  end
 end
end)
test('unreadable learned data stays unavailable through NOT',function()
 for _,mode in ipairs({'nil','error','nonboolean'})do
  local a,s,f=fixture(20);local known=f.env.IsSpellKnown
  f.env.IsSpellKnown=function(id,...)if id~=706 then return known(id,...)end
   if mode=='nil'then return nil elseif mode=='error'then error('native unavailable')else return 'yes'end end
  assert(M.status(a,IV,'warlock-iv-skin')=='unavailable'and M.status(a,IV,'warlock-iv-armor')=='unavailable',mode)
  armorOnly(a,s,nil);assert(M.first(a,s,IV)==348)
 end
end)
test('unknown auras never authorize either armor reminder',function()
 for _,trained in ipairs({false,true})do
  local a,s=fixture(20);if trained then s.learn(706)end;s.auraError=true
  -- A learned Demon Armor already settles Skin; the armor it would need to check stays unknown.
  assert(M.status(a,IV,'warlock-iv-skin')==(trained and'no-match'or'unavailable'))
  assert(M.status(a,IV,'warlock-iv-armor')==(trained and'unavailable'or'no-match'))
  armorOnly(a,s,nil)
  s.auraError=false;armorOnly(a,s,trained and 706 or 687)
  s.buff('player',706);armorOnly(a,s,nil)
 end
end)
finish()
