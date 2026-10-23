-- Mists of Pandaria Classic Warlock premades: Affliction (recommended; Warcraft Tavern Haunt pooling off by
-- default), Demonology (recommended; guide Molten Core pooling off by default), Destruction and the
-- Unspecialized catch-all. Real predicates, catalog, composition, sequence and publisher on a modeled MoP
-- Classic client (tests/fixtures/mop_premade_model_b.lua). POINT reads Soul Shards, Demonic Fury and
-- Burning Embers by specialization index (s.spec 1/2/3).
local M=dofile('tests/fixtures/mop_premade_model_b.lua');local test,finish=M.F.suite()
local AFF,TAV,DEMO,GUIDE,DESTRO,UN='rm.mop.warlock.affliction','rm.mop.warlock.affliction.warcrafttavern','rm.mop.warlock.demonology',
 'rm.mop.warlock.demonology.guide','rm.mop.warlock.destruction','rm.mop.warlock.unspecialized'
local ALL={AFF,TAV,DEMO,GUIDE,DESTRO,UN}
local AFFKIT={30108,172,980,1120,74434,103103,48181,86121,27243,86664,1454,77799}
local DEMOKIT={103958,6353,105174,1949,103964,603,104027,104025,115422,1454,77799}
local DESTROKIT={17962,29722,348,5740,80240,116858,17877,108683,114635,77799}
-- A Warlock at level with the given specialization index and kit; charges as {current,max,seconds to the next}.
local function lock(level,spec,kit)
 local f,s=M.fixture('WARLOCK',{level=level});s.spec=spec;M.know(s,686,172)
 -- Platform/points.lua captures the Burning Embers type at load, before the fixture installs the full
 -- Enum.PowerType; reload it so embers are read in fragments as on a real 5.5.4 client.
 f.load('Platform/points.lua')
 if kit then M.know(s,unpack(kit))end
 f.env.C_Spell.GetSpellCharges=function(id)local c=s.charges[id];if not c then return end
  local active=c[1]<c[2];return {currentCharges=c[1],maxCharges=c[2],cooldownStartTime=active and 100-(10-(c[3] or 9))or 0,cooldownDuration=active and 10 or 0,chargeModRate=1}end
 return f,s
end
local function first(f,s,id)return(M.first(f,s,id))end
local function dots(s,...)s.debuffs={};for _,id in ipairs({...})do s.debuffs[#s.debuffs+1]={id=id,expires=130}end end
local function stopped(f,s,id,label)local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and r.suppressAttack,label..' '..id..': '..tostring(x)..' '..tostring(r.status))end

test('switch: the catch-all below 10 and without a spec; each specialization picks its premade; variants off; dual spec',function()
 local f,s=lock(5);assert(M.scoped(f,'WARLOCK')==6);assert(M.selected(f,s)==UN and M.ordered(f,s)==UN)
 s.specID(265);assert(M.ordered(f,s)==UN,'levels 1-9 stay in the catch-all');s.spec=nil
 s.level=40;M.know(s,30108,17962,103958);assert(M.selected(f,s)==UN and M.ordered(f,s)==UN,'level 40 with no specialization chosen')
 s.specID(265);assert(M.selected(f,s)==AFF and M.ordered(f,s)==AFF)
 assert(M.switches(f,TAV)and not f.addon:GetDefaultRotation(TAV).enabled,'the Haunt pooling variant shares the switch, off by default')
 local a=f.addon;assert(a:SetDefaultRotationEnabled(TAV,true));assert(M.ordered(f,s)==AFF,'the recommended premade has the higher priority')
 assert(a:SetDefaultRotationEnabled(AFF,false));assert(M.ordered(f,s)==TAV);assert(a:SetDefaultRotationEnabled(AFF,true))
 s.talentGroup=2;s.specID(267);assert(M.selected(f,s)==DESTRO and M.ordered(f,s)==DESTRO,'second talent group')
 s.specID(266);assert(M.ordered(f,s)==DEMO and not f.addon:GetDefaultRotation(GUIDE).enabled)
 assert(f.addon:GetDefaultRotation(GUIDE).envelope.body.priority<f.addon:GetDefaultRotation(DEMO).envelope.body.priority)
 for _,id in ipairs({AFF,DEMO,DESTRO})do assert(f.addon:GetDefaultRotation(id).envelope.body.priority>f.addon:GetDefaultRotation(UN).envelope.body.priority)end
 for _,src in ipairs(f.addon:GetDefaultRotation(TAV).envelope.sources)do assert(src.url:find('warcrafttavern')or src.url:find('method'),src.url)end
end)

test('boundaries: casts, channels and no target stop; Malefic Grasp and Drain Soul channels keep advising',function()
 for _,id in ipairs(ALL)do local f,s=lock(90,1,AFFKIT);M.know(s,unpack(DEMOKIT));M.know(s,unpack(DESTROKIT))
  s.cast=true;stopped(f,s,id,'cast');s.cast=false;s.channel=true;stopped(f,s,id,'channel')
  if id==AFF or id==TAV then
   s.debuffs={{id=103103,expires=102}};stopped(f,s,id,'a Malefic Grasp debuff is not the channel')
   s.debuffs={};s.channelSpell=103103;assert(first(f,s,id),'Malefic Grasp channel: next action shown')
   s.channelSpell=1120;assert(first(f,s,id),'Drain Soul channel: next action shown');s.channelSpell=689;stopped(f,s,id,'Drain Life runs to the end')
   s.channelSpell=nil
  end
  s.channel=false;s.debuffs={};s.hostile=false;stopped(f,s,id,'no target');s.hostile=true;assert(first(f,s,id),id)
 end
end)

test('affliction: pull, early kit, DoT order, Malefic Grasp, Drain Soul execute',function()
 local f,s=lock(10,1,{30108});s.combat=false;assert(first(f,s,AFF)==30108,'pre-cast Unstable Affliction')
 dots(s,30108);stopped(f,s,AFF,'out of combat')
 M.know(s,48181);s.shards=1;assert(first(f,s,AFF)==48181,'pre-cast Haunt');s.nopower[48181]=true;stopped(f,s,AFF,'no shard, UA up')
 s.combat=true;s.debuffs={};s.nopower={};s.known[48181]=false
 assert(first(f,s,AFF)==172,'Corruption before UA');dots(s,172);assert(first(f,s,AFF)==30108);dots(s,172,30108);assert(first(f,s,AFF)==686,'Shadow Bolt filler')
 M.know(s,980,103103,1120);assert(first(f,s,AFF)==980,'Agony first');dots(s,980,172,30108);assert(first(f,s,AFF)==103103,'Malefic Grasp filler')
 s.debuffs[1].expires=101.5;assert(first(f,s,AFF)==980,'Agony under 2 s');s.debuffs[1].expires=130;s.debuffs[3].expires=101;assert(first(f,s,AFF)==30108,'UA under 1.5 s')
 s.debuffs[3].expires=130;s.targetHealth=20;assert(first(f,s,AFF)==1120,'Drain Soul at 20%')
 s.nopower[103103]=true;s.nopower[1120]=true;s.nopower[686]=true;M.know(s,1454);assert(first(f,s,AFF)==1454,'Life Tap last')
end)

test('affliction: Soul Swap opener, Haunt shard reserve, Drain Soul for a shard, Dark Soul refresh',function()
 local f,s=lock(90,1,AFFKIT);s.shards=2;s.classification='elite'
 assert(first(f,s,AFF)==74434,'fresh elite: Soulburn');s.buffs={{id=74434,expires=120}};assert(first(f,s,AFF)==86121,'then Soul Swap')
 s.buffs={};s.classification='normal';assert(first(f,s,AFF)==980,'normal mob without a forecast: DoTs one by one');s.ttd=30;assert(first(f,s,AFF)==74434)
 dots(s,980,172,30108);assert(first(f,s,AFF)==48181,'Haunt at two shards');s.shards=1;assert(first(f,s,AFF)==103103,'keep one shard')
 s.buffs={{id=113860,expires=120}};assert(first(f,s,AFF)==48181,'Dark Soul, DoTs fresh: Haunt on one shard');s.debuffs[1].expires=110;assert(first(f,s,AFF)==980,'Dark Soul: Agony refreshed inside Pandemic');s.debuffs[1].expires=125;s.debuffs[2].expires=105
 assert(first(f,s,AFF)==172);s.debuffs[2].expires=125;s.debuffs[3].expires=105;assert(first(f,s,AFF)==30108);s.debuffs[3].expires=125
 assert(first(f,s,AFF)==48181,'Haunt in Dark Soul on one shard');s.buffs={}
 s.debuffs[4]={id=48181,expires=110};s.shards=2;assert(first(f,s,AFF)==103103,'Haunt still up');s.debuffs[4].expires=103;assert(first(f,s,AFF)==48181)
 s.shards=0;s.debuffs[4].expires=100.5;assert(first(f,s,AFF)==1120,'Drain Soul for a shard when Haunt is ending with none')
 s.spec=nil;s.shards=4;s.debuffs[4]=nil;assert(first(f,s,AFF)==103103,'no specialization: shards unreadable, Haunt not guessed')
end)

test('affliction: moving and Kil\'jaeden\'s Cunning; Seed of Corruption on packs',function()
 local f,s=lock(90,1,AFFKIT);dots(s,980,172,30108);s.moving=true;assert(first(f,s,AFF)==77799,'Fel Flame while moving');s.mana=50
 assert(first(f,s,AFF)==1454,'Life Tap while moving below 80%');s.mana=100;s.debuffs[1].expires=101;assert(first(f,s,AFF)==980)
 s.debuffs[1].expires=130;s.shards=3;assert(first(f,s,AFF)==48181,'Haunt on the move at two shards');s.known[48181]=false;s.known[77799]=false;stopped(f,s,AFF,'moving, nothing instant')
 s.talents[17]=true;assert(first(f,s,AFF)==103103,'Kil\'jaeden\'s Cunning: cast while moving');s.moving=false;s.talents[17]=false
 s.enemies={0,0,0};assert(first(f,s,AFF)==103103,'Soulburn: Seed known, three enemies: no plain Seed')
 s.enemies={0,0,0,0,0,0};assert(first(f,s,AFF)==74434,'six enemies: Soulburn');s.buffs={{id=74434,expires=120}};assert(first(f,s,AFF)==27243,'then Seed')
 s.debuffs[4]={id=27243,expires=115};assert(first(f,s,AFF)==103103,'your Seed is on the target')
 local g,t=lock(60,1,{30108,980,103103,27243});dots(t,980,172,30108);t.enemies={0,false,0,0};assert(first(g,t,AFF)==27243,'plain Seed before 62 on three engaged enemies')
 t.enemies={0,false,0};assert(first(g,t,AFF)==103103,'an enemy not fighting you is not counted')
end)

test('affliction variant: Haunt at four shards or Dark Soul; execute Soul Swap re-snapshot',function()
 local f,s=lock(90,1,AFFKIT);dots(s,980,172,30108);s.shards=3;assert(first(f,s,TAV)==103103 and first(f,s,AFF)==48181,'pool Haunt')
 s.shards=4;assert(first(f,s,TAV)==48181);s.shards=1;s.buffs={{id=113860,expires=101}};assert(first(f,s,TAV)==48181,'Haunt in Dark Soul')
 s.buffs={};s.targetHealth=15;assert(first(f,s,TAV)==74434,'execute: Soulburn');s.buffs={{id=74434,expires=120}};assert(first(f,s,TAV)==86121)
 s.buffs={};s.history={{spell=86121,time=97}};assert(first(f,s,TAV)==1120,'not again within 8 s')
end)

test('demonology: caster form, the Shadowflame weave, Metamorphosis entry, Molten Core',function()
 local f,s=lock(90,2,DEMOKIT);s.combat=false;assert(first(f,s,DEMO)==6353,'pre-cast Soul Fire');s.combat=true
 assert(first(f,s,DEMO)==172,'Corruption');dots(s,172);s.charges[105174]={2,2};assert(first(f,s,DEMO)==105174,'two charges')
 s.charges[105174]={1,2,6};assert(first(f,s,DEMO)==686,'one charge, the next 6 s away: Shadow Bolt');s.charges[105174]={1,2,2};assert(first(f,s,DEMO)==105174,'next charge within 2.5 s')
 s.charges[105174]={1,2,6};s.debuffs[2]={id=47960,stacks=1,expires=102};assert(first(f,s,DEMO)==105174,'one-stack Shadowflame ending: second Hand')
 s.history={{spell=105174,time=99.5}};assert(first(f,s,DEMO)==103958,'then Metamorphosis at once');s.history=nil;s.debuffs[2]=nil
 s.buffs={{id=113861,expires=115}};assert(first(f,s,DEMO)==103958,'Dark Soul with more than 10 s');s.buffs[1].expires=105;assert(first(f,s,DEMO)==686)
 s.buffs={};s.fury=960;assert(first(f,s,DEMO)==103958,'never cap fury');s.fury=600
 s.buffs={{id=122355,stacks=2,expires=120}};assert(first(f,s,DEMO)==6353,'two Molten Core stacks');s.buffs[1].stacks=1;assert(first(f,s,DEMO)==686)
 s.buffs[1].expires=103;assert(first(f,s,DEMO)==6353,'Molten Core ending');s.buffs={};s.targetHealth=25;assert(first(f,s,DEMO)==6353,'below 25%')
 s.targetHealth=100;s.enemies={0,0,0};assert(first(f,s,DEMO)==686);s.enemies={0,0,0,0};assert(first(f,s,DEMO)==1949,'Hellfire on four')
 s.enemies={0,0};s.buffs={{id=108508,expires=120}};assert(first(f,s,DEMO)==1949,'two with Mannoroth\'s Fury');s.buffs={};s.enemies={}
 s.moving=true;assert(first(f,s,DEMO)==77799,'Fel Flame on the move');s.debuffs={};assert(first(f,s,DEMO)==172)
end)

test('demonology: in Metamorphosis, leave cue, Doom, Touch of Chaos, Soul Fire, packs',function()
 local f,s=lock(90,2,DEMOKIT);dots(s,172);s.buffs={{id=103958,expires=200}};s.fury=200
 assert(first(f,s,DEMO)~=103958,'the Metamorphosis aura alone is not the form');s.shift(103958)
 assert(first(f,s,DEMO)==103958,'no Dark Soul, 300 fury or less: leave');s.buffs[2]={id=113861,expires=120};assert(first(f,s,DEMO)==603,'in Dark Soul stay: Doom')
 s.buffs[2]=nil;s.fury=500;s.debuffs[2]={id=603,expires=160};assert(first(f,s,DEMO)==103964,'Touch of Chaos')
 s.debuffs[2].expires=120;assert(first(f,s,DEMO)==103964,'Doom ending, no forecast: not refreshed');s.ttd=60;assert(first(f,s,DEMO)==603);s.ttd=nil;s.debuffs[2].expires=160
 s.debuffs[1].expires=103;s.buffs[2]={id=122355,stacks=1,expires=120};assert(first(f,s,DEMO)==103964,'extend an ending Corruption');s.debuffs[1].expires=130
 assert(first(f,s,DEMO)==104027,'Soul Fire on any Molten Core');s.buffs[2]=nil
 s.enemies={0,0,0};assert(first(f,s,DEMO)==104025,'Immolation Aura on three');s.buffs[2]={id=104025,expires=110};assert(first(f,s,DEMO)==103964)
 s.enemies={0,0,0,0,0,0,0};assert(first(f,s,DEMO)==115422,'Void Ray on seven');s.enemies={}
 local g,t=lock(20,2,{103958,6353,105174});dots(t,172);t.shift(103958);t.fury=500;stopped(g,t,DEMO,'no demon spells yet: the caster list does not apply')
end)

test('demonology variant: Molten Core pooled to eight, Metamorphosis at 900 fury or with Dark Soul',function()
 local f,s=lock(90,2,DEMOKIT);dots(s,172);s.charges[105174]={0,2,6};s.fury=600
 s.buffs={{id=122355,stacks=2,expires=120}};assert(first(f,s,GUIDE)==686 and first(f,s,DEMO)==6353,'pool Molten Core')
 s.buffs[1].stacks=8;assert(first(f,s,GUIDE)==6353);s.buffs={};s.fury=900;assert(first(f,s,GUIDE)==103958 and first(f,s,DEMO)==686,'900 fury')
 s.fury=100;s.buffs={{id=113861,expires=102}};assert(first(f,s,GUIDE)==103958,'any Dark Soul')
end)

test('destruction: pull, Immolate, Conflagrate charges, Backdraft, embers for Chaos Bolt and Shadowburn',function()
 local f,s=lock(90,3,DESTROKIT);s.usable[17877]=false;s.combat=false;assert(first(f,s,DESTRO)==29722,'pre-cast Incinerate');s.combat=true
 assert(first(f,s,DESTRO)==348,'Immolate');dots(s,348);s.charges[17962]={2,2};assert(first(f,s,DESTRO)==17962,'never cap Conflagrate')
 s.charges[17962]={1,2};s.embers=1;assert(first(f,s,DESTRO)==17962,'no Backdraft: Conflagrate');s.buffs={{id=117828,stacks=3,expires=110}}
 assert(first(f,s,DESTRO)==29722,'Backdraft: Incinerate');s.embers=3.5;assert(first(f,s,DESTRO)==29722,'no Chaos Bolt on three Backdraft stacks')
 s.buffs[1].stacks=2;assert(first(f,s,DESTRO)==116858,'Chaos Bolt at 3.5 embers');s.embers=3;assert(first(f,s,DESTRO)==29722)
 s.buffs[2]={id=113858,expires=115};assert(first(f,s,DESTRO)==116858,'Chaos Bolt in Dark Soul');s.debuffs[1].expires=106;assert(first(f,s,DESTRO)==348,'Immolate early in Dark Soul')
 s.debuffs[1].expires=130;s.buffs={};s.usable[17877]=nil;s.targetHealth=15;s.embers=3.5;assert(first(f,s,DESTRO)==17877,'Shadowburn below 20%')
 s.embers=2;assert(first(f,s,DESTRO)==17962);s.usable[17877]=false;s.targetHealth=100
 s.ttd=2;s.usable[17877]=nil;assert(first(f,s,DESTRO)==17877,'snipe a dying target');s.ttd=nil;s.usable[17877]=false
 s.spec=nil;s.charges[17962]={1,2};s.buffs={{id=117828,stacks=1,expires=110}};assert(first(f,s,DESTRO)==29722,'embers unreadable: no Chaos Bolt guess')
end)

test('destruction: packs, Fire and Brimstone on and off, moving',function()
 local f,s=lock(90,3,DESTROKIT);s.usable[17877]=false;dots(s,348);s.charges[17962]={1,2};s.embers=2
 s.enemies={0,0,0};assert(first(f,s,DESTRO)==17962,'three: Conflagrate');s.enemies={0,0,0,0};assert(first(f,s,DESTRO)==5740,'Rain of Fire on four')
 s.history={{spell=5740,time=97}};assert(first(f,s,DESTRO)==108683,'Fire and Brimstone');s.buffs={{id=108683}};assert(first(f,s,DESTRO)==17962)
 s.embers=0;assert(first(f,s,DESTRO)==108683,'out of embers: switch it off');s.buffs={};assert(first(f,s,DESTRO)==17962,'not back on without an ember')
 s.debuffs={};assert(first(f,s,DESTRO)==348);s.nopower[348]=true;s.nopower[17962]=true;s.nopower[29722]=true;stopped(f,s,DESTRO,'nothing castable on a pack')
 local g,t=lock(90,3,DESTROKIT);t.usable[17877]=false;dots(t,348);t.moving=true;assert(first(g,t,DESTRO)==17962,'moving: Conflagrate')
 t.nopower[17962]=true;assert(first(g,t,DESTRO)==77799);t.talents[17]=true;assert(first(g,t,DESTRO)==29722,'Kil\'jaeden\'s Cunning')
end)

test('unspecialized: pull, Drain Life, Corruption, Shadow Bolt',function()
 local f,s=lock(5,nil,{689});s.combat=false;assert(first(f,s,UN)==172);dots(s,172);assert(first(f,s,UN)==686);s.combat=true
 assert(first(f,s,UN)==686);s.health=40;assert(first(f,s,UN)==689,'Drain Life when low');s.health=100;s.debuffs={};assert(first(f,s,UN)==172)
 s.cast=true;stopped(f,s,UN,'cast')
end)

test('reminders: pets by spec and talent, Healthstone, shared upkeep, spec cooldowns',function()
 local f,s=lock(5,nil,{688});s.combat=false;local u=M.upkeep(f,s,UN);assert(u['warlock-start-imp']==688,'before the Voidwalker: Imp')
 M.know(s,697,6201);u=M.upkeep(f,s,UN);assert(u['warlock-start-voidwalker']==697 and not u['warlock-start-imp']and u['warlock-start-healthstone']==6201)
 s.group=true;assert(M.upkeep(f,s,UN)['warlock-start-imp']);s.pet=true;assert(not M.upkeep(f,s,UN)['warlock-start-imp']);s.items[5512]=1;assert(not M.upkeep(f,s,UN)['warlock-start-healthstone'])
 local g,t=lock(90,1,AFFKIT);M.know(t,691,112869,697,688,109773,1490,18540,112927,1122,112921,104773,113860,111897,108503);t.combat=false
 u=M.upkeep(g,t,AFF);assert(u['warlock-felhunter']==691 and not u['warlock-observer']and not u['warlock-early-voidwalker'],'Felhunter')
 t.talents[13]=true;u=M.upkeep(g,t,AFF);assert(u['warlock-observer']==112869 and not u['warlock-felhunter'],'Supremacy: Observer')
 t.buffs={{id=108503}};assert(not M.upkeep(g,t,AFF)['warlock-observer'],'sacrificed: no pet');t.buffs={};t.talents[13]=false
 assert(M.upkeep(g,t,AFF)['warlock-dark-intent']==109773);t.buffs={{id=109773,source='party1'}};assert(not M.upkeep(g,t,AFF)['warlock-dark-intent'],'any Dark Intent counts')
 t.pet=true;t.talents[15]=true;assert(M.upkeep(g,t,AFF)['warlock-grimoire-of-sacrifice']==108503)
 t.combat=true;u=M.upkeep(g,t,AFF);assert(not u['warlock-curse-of-the-elements']and u['warlock-aff-dark-soul']==113860 and u['warlock-aff-grimoire-felhunter'])
 t.group=true;assert(M.upkeep(g,t,AFF)['warlock-curse-of-the-elements']);t.debuffs={{id=1490,source='party1'}};assert(not M.upkeep(g,t,AFF)['warlock-curse-of-the-elements'],'someone else\'s curse')
 assert(not M.upkeep(g,t,AFF)['warlock-doomguard']);t.classification='elite';t.ttd=50;assert(M.upkeep(g,t,AFF)['warlock-doomguard']==18540,'elite in its last minute')
 t.ttd=nil;t.buffs={{id=2825,source='party1'}};assert(M.upkeep(g,t,AFF)['warlock-doomguard'],'under Bloodlust');t.talents[13]=true
 u=M.upkeep(g,t,AFF);assert(u['warlock-terrorguard']==112927 and not u['warlock-doomguard']);t.enemies={0,0,0,0,0,0,0};assert(M.upkeep(g,t,AFF)['warlock-abyssal']==112921)
 t.health=30;assert(M.upkeep(g,t,AFF)['warlock-unending-resolve']==104773);t.buffs={{id=113860,expires=120}};assert(not M.upkeep(g,t,AFF)['warlock-aff-dark-soul'],'Dark Soul already up')
 t.mana=10;assert(M.upkeep(g,t,AFF)['warlock-aff-life-tap']==1454);t.moving=true;assert(not M.upkeep(g,t,AFF)['warlock-aff-life-tap'])
 local d,v=lock(90,2,DEMOKIT);M.know(v,30146,112870,697,111898,104316,113861,755);v.combat=false;assert(M.upkeep(d,v,DEMO)['warlock-demo-felguard']==30146)
 v.pet=true;v.combat=true;u=M.upkeep(d,v,DEMO);assert(u['warlock-demo-dark-soul']and u['warlock-demo-grimoire-felguard']and not u['warlock-demo-imp-swarm'],'Imp Swarm waits for Dark Soul')
 v.buffs={{id=113861,expires=115}};assert(M.upkeep(d,v,DEMO)['warlock-demo-imp-swarm']==104316);v.mana=20;assert(M.upkeep(d,v,DEMO)['warlock-demo-life-tap'])
 v.shift(103958);assert(not M.upkeep(d,v,DEMO)['warlock-demo-life-tap'],'no Life Tap in demon form');v.petHealth=20;assert(M.upkeep(d,v,DEMO)['warlock-demo-health-funnel']==755)
 local x,w=lock(90,3,DESTROKIT);M.know(w,113858,120451);w.pet=false;u=M.upkeep(x,w,DESTRO);assert(u['warlock-destro-dark-soul']and not u['warlock-destro-havoc']and not u['warlock-destro-flames-of-xoroth'])
 w.enemies={0,0};assert(M.upkeep(x,w,DESTRO)['warlock-destro-havoc']==80240,'Havoc on two');w.talents[15]=true;assert(M.upkeep(x,w,DESTRO)['warlock-destro-flames-of-xoroth']==120451)
 w.health=40;assert(M.upkeep(x,w,DESTRO)['warlock-destro-ember-tap']==114635)
end)

test('real publisher auto-selects the specialization premade and highlights',function()
 local f,s=lock(90,1,AFFKIT);dots(s,980,172,30108);s.shards=1;local poll,selected,glow=M.publisher(f,s)
 poll();assert(selected()==AFF and f.addon.currentSpell==103103,tostring(selected())..' '..tostring(f.addon.currentSpell));s.shards=3;poll();assert(f.addon.currentSpell==48181);assert(#glow>0)
end)
finish()
