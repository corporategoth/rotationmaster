-- TBC Priest premades: damage (Icy Veins, recommended; Wowhead variant) and healer (Wowhead,
-- recommended; Icy Veins variant). Real catalog, composition, predicates, sequence executor,
-- readiness and auto-select order; native observations are modeled (tests/fixtures/tbc_premades.lua).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local M=dofile('tests/fixtures/tbc_premades.lua')
local DIV,DWH,HWH,HIV='rm.tbc.priest.dps.icyveins','rm.tbc.priest.dps.wowhead','rm.tbc.priest.healer.wowhead','rm.tbc.priest.healer.icyveins'
local ALL={DIV,DWH,HWH,HIV}
local function fixture(level,talents,...)
 local f,s=M.new('priest');s.learn(585,...);s.talents=talents or {0,0,0};s.setLevel(level or 70);return f.addon,s,f
end
local function shadow(...)return fixture(70,{5,0,56},589,8092,15407,34914,15286,15473,32379,34433,14751,588,1243,5019,8122,...)end
local function healer(...)
 local a,s,f=fixture(70,{0,41,20},589,14914,2050,2054,2060,2061,139,33076,32546,34861,596,527,528,552,17,33206,14752,14751,588,1243,...)
 s.group=true;s.friendly=true;s.hostile=false;return a,s,f
end
local function stopped(r)return r.status=='stopped'and r.suppressAttack end
local function cd(s,id,left)s.cooldown[id]={startTime=100,duration=left,isEnabled=true,modRate=1}end

test('all four premades register valid, localized, sourced and composed',function()
 local a,_,f=fixture(70)
 for _,id in ipairs(ALL)do local row=M.row(a,id)
  assert(row.readOnly and row.validation.valid and row.validation.resolved,id)
  assert(f.translations[row.nameKey]and f.translations[row.descriptionKey]and a:GetDefaultRotationComposition(id),id)
  assert(row.applicability.class=='PRIEST'and row.applicability.maxLevel==70)
 end
 assert(M.row(a,DIV).applicability.minLevel==1 and M.row(a,HWH).applicability.minLevel==10)
 for _,source in ipairs(M.row(a,DWH).envelope.sources)do assert(source.url:find('wowhead'),'Wowhead damage cites another source')end
 for _,source in ipairs(M.row(a,HIV).envelope.sources)do assert(source.url:find('icy%-veins'),'Icy Veins healer cites another source')end
 for _,source in ipairs(M.row(a,HWH).envelope.sources)do assert(source.url:find('wowhead'),'Wowhead healer cites another source')end
end)

test('auto-select: damage solo and for Shadow, healer in a group as Holy or Discipline',function()
 local a,s=fixture(5);assert(M.selected(a)==DIV)
 s.group=true;assert(M.selected(a)==DIV and not M.row(a,HWH).eligible,'no healer premade before talents')
 s.setLevel(30);assert(M.selected(a)==DIV,'a grouped priest with no points still gets damage advice')
 s.talents={0,21,0};assert(M.selected(a)==HWH);assert(M.switch(a,HIV)=='match','Icy Veins healer matches like its sibling')
 s.talents={21,0,0};assert(M.selected(a)==HWH,'Discipline heals too')
 s.talents={0,0,21};assert(M.selected(a)==DIV)
 s.talents={10,10,0};assert(M.selected(a)==DIV,'tied trees fall back to damage')
 s.talents={0,21,0};s.group=false;assert(M.selected(a)==DIV,'a Holy priest questing solo deals damage')
 s.group=true;assert(a:SetDefaultRotationEnabled(HWH,false));assert(M.selected(a)==HIV)
 s.group=false;assert(a:SetDefaultRotationEnabled(DIV,false));assert(M.selected(a)==DWH)
 assert(M.switch(a,DWH)=='match')
end)

test('cast and channel stop every Priest premade; damage needs a hostile target',function()
 local a,s=shadow()
 for _,id in ipairs(ALL)do
  s.cast=true;assert(stopped(select(2,M.first(a,s,id))),id);s.cast=false
  s.channel=true;assert(stopped(select(2,M.first(a,s,id))),id..' would clip a channel');s.channel=false
 end
 s.hostile=false;assert(stopped(select(2,M.first(a,s,DIV))))
 s.hostile=true;s.combat=false;assert(stopped(select(2,M.first(a,s,DIV))),'pulled a mob someone else is fighting')
end)

test('damage training stages: Smite, Pain, Mind Blast, Mind Flay or Holy Fire',function()
 local a,s=fixture(1);assert(M.first(a,s,DIV)==585)
 s.learn(589);assert(M.first(a,s,DIV)==589);s.debuff('target',589);assert(M.first(a,s,DIV)==585)
 s.learn(8092);assert(M.first(a,s,DIV)==8092);cd(s,8092,8)
 s.learn(14914);assert(M.first(a,s,DIV)==14914,'no Mind Flay: Holy Fire');s.debuff('target',14914);assert(M.first(a,s,DIV)==585)
 s.learn(15407);assert(M.first(a,s,DIV)==15407,'Mind Flay replaces the Smite branch')
 s.combat=false;s.targetCombat=false;s.clearAuras();s.cooldown={};assert(M.first(a,s,DIV)==8092,'Mind Blast opener')
end)

test('Shadowform first, then DoTs before Mind Blast (Icy Veins) or after it (Wowhead)',function()
 local a,s=shadow()
 assert(M.first(a,s,DIV)==15473 and M.first(a,s,DWH)==15473);s.buff('player',15473)
 assert(M.first(a,s,DIV)==34914,'Icy Veins: Vampiric Touch before Mind Blast')
 assert(M.first(a,s,DWH)==8092,'Wowhead: Mind Blast before the DoTs')
 cd(s,8092,6);assert(M.first(a,s,DWH)==34914)
 s.debuff('target',34914,{expirationTime=110,duration=15});assert(M.first(a,s,DIV)==589)
 s.debuff('target',589);assert(M.first(a,s,DIV)==32379)
 s.debuff('target',15286);s.health.player=40;assert(M.first(a,s,DIV)==15407,'no Shadow Word: Death while low');s.health.player=100
 s.auras.target.HARMFUL[1].expirationTime=101;assert(M.first(a,s,DIV)==34914,'Vampiric Touch refreshed before it ends')
end)

test('Vampiric Embrace: long fights (Icy Veins) or low health (both)',function()
 local a,s=shadow();s.buff('player',15473)
 assert(M.first(a,s,DIV)~=15286 and M.first(a,s,DWH)~=15286)
 s.health.player=60;assert(M.first(a,s,DIV)==15286 and M.first(a,s,DWH)==15286)
 s.group=true;assert(M.first(a,s,DIV)~=15286,'Icy Veins: group Embrace needs a long fight')
 assert(M.first(a,s,DWH)==15286)
end)

test('a dying solo target: Icy Veins wands, Wowhead uses spells; groups keep the rotation',function()
 local a,s=shadow();s.buff('player',15473);s.health.target=15
 assert(M.first(a,s,DIV)==5019);assert(M.first(a,s,DWH)==8092)
 s.repeatActive=true;assert(stopped(select(2,M.first(a,s,DIV))),'active wand toggled off')
 s.repeatActive=false;s.group=true;assert(M.first(a,s,DIV)==34914)
end)

test('pull and movement',function()
 local a,s=shadow();s.buff('player',15473);s.combat=false;s.targetCombat=false
 assert(M.first(a,s,DIV)==34914 and M.first(a,s,DWH)==8092,'openers differ by source')
 s.usable[34914]=false;s.usable[8092]=false;s.usable[585]=false;assert(stopped(select(2,M.first(a,s,DIV))),'pull fell through')
 a,s=shadow();s.buff('player',15473);s.moving=true
 assert(M.first(a,s,DIV)==589);s.debuff('target',589);assert(M.first(a,s,DIV)==32379)
 cd(s,32379,10);assert(stopped(select(2,M.first(a,s,DIV))),'cast-time spell offered while moving')
end)

test('damage upkeep: Inner Fire, Fortitude out of combat, Shadowfiend, Inner Focus with Mind Blast',function()
 local a,s=shadow();s.combat=false
 local lit=M.upkeep(a,s,DIV);assert(lit[588]and lit[1243])
 s.buff('player',588);s.buff('player',21562,{sourceUnit='party1'});lit=M.upkeep(a,s,DIV);assert(not lit[588]and not lit[1243])
 s.combat=true;lit=M.upkeep(a,s,DIV);assert(lit[14751]and not lit[34433])
 s.mana.player=40;assert(M.upkeep(a,s,DIV)[34433]);cd(s,8092,8);assert(not M.upkeep(a,s,DIV)[14751])
end)

test('healer: shield, Prayer of Mending and Renew order differs by source',function()
 local a,s=healer();s.health.target=30
 assert(M.first(a,s,HWH)==17 and M.first(a,s,HIV)==17,'emergency shield')
 s.debuff('target',6788,{sourceUnit='party1'})
 assert(M.first(a,s,HWH)==33076,'Wowhead: Prayer of Mending whenever ready')
 assert(M.first(a,s,HIV)==139,'Icy Veins: Renew before Flash, Mending last')
 cd(s,33076,8);assert(M.first(a,s,HWH)==2061)
 s.buff('target',139);assert(M.first(a,s,HIV)==2061)
end)

test('healer: dispels, then the efficient heal for the trained level',function()
 local a,s=healer();s.health.target=85;cd(s,33076,8);s.buff('target',139)
 s.debuff('target',99999,{sourceUnit='target',dispelName='Magic'});assert(M.first(a,s,HWH)==527 and M.first(a,s,HIV)==527)
 s.auras.target.HARMFUL[1].dispelName='Disease';assert(M.first(a,s,HWH)==552)
 s.buff('target',552);assert(M.first(a,s,HWH)==2060,'Wowhead top-up with Greater Heal rank 1')
 assert(stopped(select(2,M.first(a,s,HIV))),'Icy Veins has no fixed top-up rank')
 s.health.target=60;assert(M.first(a,s,HIV)==2060)
 s.known[2060]=nil;assert(M.first(a,s,HIV)==2054);s.known[2054]=nil;assert(M.first(a,s,HIV)==2050)
end)

test('healer: Binding Heal when both of you are hurt; unknown group counts do not halt',function()
 local a,s=healer();cd(s,33076,8);s.buff('target',139)
 s.health.target=60;s.health.player=60;assert(M.first(a,s,HWH)==32546 and M.first(a,s,HIV)==32546)
 s.health.player=100;s.health.target=40;assert(M.first(a,s,HWH)==2061,'unavailable group-heal counts must not block single-target heals')
end)

test('healer pre-pull and enemy targets',function()
 local a,s=healer();s.combat=false;s.targetCombat=false
 assert(M.first(a,s,HWH)==33076);cd(s,33076,8);assert(M.first(a,s,HWH)==139)
 s.buff('target',139);assert(stopped(select(2,M.first(a,s,HWH))))
 assert(stopped(select(2,M.first(a,s,HIV))),'Icy Veins: nothing to heal at full health')
 s.combat=true;s.friendly=false;s.hostile=true;s.clearAuras()
 assert(M.first(a,s,HWH)==589);s.debuff('target',589);assert(M.first(a,s,HWH)==14914)
 s.hostile=false;assert(stopped(select(2,M.first(a,s,HWH))))
end)

test('healer upkeep: Divine Spirit out of combat, Pain Suppression on a dying friend',function()
 local a,s=healer();s.combat=false;assert(M.upkeep(a,s,HWH)[14752])
 s.combat=true;assert(not M.upkeep(a,s,HWH)[33206]);s.health.target=20;assert(M.upkeep(a,s,HWH)[33206]and M.upkeep(a,s,HIV)[33206])
end)
finish()
