-- Mists of Pandaria Classic Priest premades: Shadow (recommended) and Shadow Warcraft Tavern (off), Discipline,
-- Holy (recommended) and Holy Icy Veins (off), and the unspecialized catch-all. Real predicates, catalog,
-- composition, sequence executor and publisher on a modeled MoP Classic client
-- (tests/fixtures/mop_premade_model_b.lua).
local M=dofile('tests/fixtures/mop_premade_model_b.lua');local test,finish=M.F.suite()
local SH,SHT,DI,HO,HOI,UN='rm.mop.priest.shadow','rm.mop.priest.shadow.warcrafttavern','rm.mop.priest.discipline','rm.mop.priest.holy','rm.mop.priest.holy.icyveins','rm.mop.priest.unspecialized'
local function first(f,s,id)return(M.first(f,s,id))end
local function priest(level,spec,...)
 local f,s=M.fixture('PRIEST',{level=level,spec=spec});M.know(s,585,589)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 return f,s
end
local shadowEarly={15407}
local shadowFull={15407,8092,2944,15473,34914,73510,32379,48045,47585,34433,15487,15286}
local discFull={47540,17,2061,139,2050,2060,14914,109964,89485,596,32546,81700,33206,33076}
local holyFull={88625,17,2061,139,2050,2060,14914,596,32546,34861,81208,81206,81209,33076,47788,64843}
local function cooling(s,id,left)s.cooldown[id]={startTime=100-(60-left),duration=60,isEnabled=true,modRate=1}end
local function friend(s,hp)s.friend,s.hostile,s.targetHealth=true,false,hp end
local function stopped(f,s,id,suppress,label)
 local x,r=M.first(f,s,id);assert(not x and r.status=='stopped',label..': got '..tostring(x)..' '..tostring(r.status))
 if suppress~=nil then assert(r.suppressAttack==suppress,label..': attack')end
end

test('every premade is scoped to Mists; the catch-all owns 1-9 and unspecced; each specialization picks its premade',function()
 local f,s=priest(5,nil);assert(M.scoped(f,'PRIEST')==6)
 assert(M.selected(f,s)==UN and M.ordered(f,s)==UN,'level 5')
 s.specID(258);assert(M.selected(f,s)==UN and M.ordered(f,s)==UN,'levels 1-9 stay in the catch-all');s.spec=nil
 s.level=12;assert(M.selected(f,s)==UN and M.ordered(f,s)==UN,'level 12 with no specialization')
 M.know(s,15407,47540,88625);assert(M.selected(f,s)==UN,'known spells do not pick a specialization')
 s.specID(258);assert(M.selected(f,s)==SH and M.ordered(f,s)==SH)
 s.specID(256);assert(M.selected(f,s)==DI and M.ordered(f,s)==DI)
 s.specID(257);assert(M.selected(f,s)==HO and M.ordered(f,s)==HO)
 s.level=90;s.spec=nil;assert(M.selected(f,s)==UN)
 -- Dual spec: the second talent group stores its own selection and reads its own specialization.
 s.specID(256);s.talentGroup=2;assert(M.selected(f,s)==DI and M.ordered(f,s)==DI)
 local rows=f.addon:ListDefaultRotations(2);assert(#rows==6)
end)

test('source variants ship disabled and select only once enabled and the recommended premade is off',function()
 local f,s=priest(90,3,shadowFull);local a=f.addon
 assert(M.switches(f,SHT) and M.selected(f,s)==SH)
 for _,row in ipairs(a:ListDefaultRotations(1))do if row.id==SHT or row.id==HOI then assert(not row.eligible and row.eligibilityReason=='disabled',row.id)end end
 assert(a:SetDefaultRotationEnabled(SHT,true));assert(M.selected(f,s)==SH,'recommended has the higher priority')
 assert(a:SetDefaultRotationEnabled(SH,false));assert(M.selected(f,s)==SHT and M.ordered(f,s)==SHT)
 s.specID(257);assert(M.selected(f,s)==HO);assert(a:SetDefaultRotationEnabled(HOI,true));assert(a:SetDefaultRotationEnabled(HO,false))
 assert(M.selected(f,s)==HOI)
 for _,src in ipairs(a:GetDefaultRotation(SHT).envelope.sources)do assert(src.url:find('warcrafttavern'),src.url)end
 for _,src in ipairs(a:GetDefaultRotation(HOI).envelope.sources)do assert(src.url:find('icy%-veins'),src.url)end
end)

test('Shadow boundaries: casts stop; a Mind Flay is clipped for Mind Blast, Death or after its second tick; no target stops',function()
 local f,s=priest(90,3,shadowFull);s.debuffs={{id=589,expires=200},{id=34914,expires=200}}
 s.cast=true;stopped(f,s,SH,true,'cast');s.cast=false
 s.channel=true;s.channelSpell=48045;cooling(s,8092,5);s.channelStart,s.channelEnd=97,100.1;stopped(f,s,SH,true,'Mind Sear is never cut, even near its end')
 s.history={{spell=15407,time=99}};stopped(f,s,SH,true,'the last cast was Mind Flay, but the channel is Mind Sear')
 s.history=nil;s.channelSpell=15407;s.channelStart,s.channelEnd=99,102;stopped(f,s,SH,true,'Mind Flay after one tick with nothing worth clipping for')
 s.channelStart,s.channelEnd=98.05,101.05;stopped(f,s,SH,true,'just before the second tick (65%)')
 s.channelStart,s.channelEnd=97.95,100.95;assert(first(f,s,SH)==15407,'past the second tick (68%): clip and recast')
 s.channelStart,s.channelEnd=99,102;s.cooldown[8092]=nil;assert(first(f,s,SH)==8092,'clip Mind Flay for Mind Blast')
 s.channelSpell=129197;assert(first(f,s,SH)==8092,'Insanity is clipped too')
 cooling(s,8092,5);s.targetHealth=15;assert(first(f,s,SH)==32379,'clip for Shadow Word: Death in execute')
 s.channelSpell=nil;s.targetHealth=100;stopped(f,s,SH,true,'an unnamed channel is not Mind Flay')
 s.channel=false;s.targetHealth=100;s.hostile=false;stopped(f,s,SH,true,'no enemy')
 for _,id in ipairs({SH,SHT})do s.hostile=true;s.cast=true;stopped(f,s,id,true,id..' cast');s.cast=false end
end)

test('Shadow pull: Mind Spike, then Mind Blast, Vampiric Touch, Pain, Flay by what is known, then stop',function()
 local f,s=priest(10,3,shadowEarly);s.combat=false
 assert(first(f,s,SH)==589,'level 10 opens with Pain');s.known[589]=false;assert(first(f,s,SH)==15407);s.known[589]=true
 M.know(s,34914);assert(first(f,s,SH)==34914);M.know(s,8092);assert(first(f,s,SH)==8092);M.know(s,73510);assert(first(f,s,SH)==73510)
 for id in pairs(s.known)do s.nopower[id]=true end;stopped(f,s,SH,true,'out of combat nothing to cast')
end)

test('Shadow single target: early kit, orbs and the Mind Blast gate, Insanity, DoT refresh, Surge, Flay',function()
 local f,s=priest(10,3,shadowEarly);assert(first(f,s,SH)==589,'Pain missing');s.debuffs={{id=589,expires=200}}
 assert(first(f,s,SH)==15407,'Mind Flay filler');s.debuffs[1].expires=102;assert(first(f,s,SH)==589,'refresh in the last tick')
 s.debuffs[1].expires=200
 local g,t=priest(90,3,shadowFull);t.debuffs={{id=589,expires=200},{id=34914,expires=200}}
 assert(first(g,t,SH)==8092,'Mind Blast below three orbs');t.orbs=3;assert(first(g,t,SH)==2944,'Devouring Plague at three with Mind Blast ready')
 cooling(t,8092,3);assert(first(g,t,SH)==15407,'hold Devouring Plague while Mind Blast is three seconds away')
 cooling(t,8092,7);assert(first(g,t,SH)==2944,'Mind Blast six or more seconds away');t.orbs=2;assert(first(g,t,SH)==15407)
 t.targetHealth=15;assert(first(g,t,SH)==32379,'Death below 20%');t.targetHealth=100
 t.debuffs[2].expires=103;assert(first(g,t,SH)==34914,'Vampiric Touch under 4.5 s');t.debuffs[2].expires=200
 t.buffs={{id=87160,stacks=1}};assert(first(g,t,SH)==73510,'Mind Spike on Surge of Darkness');t.buffs={}
 t.debuffs[3]={id=2944,expires=104};t.debuffs[1].expires=101;assert(first(g,t,SH)==589,'no Insanity without the talent')
 t.talents[9]=true;assert(first(g,t,SH)==15407,'Mind Flay: Insanity under Devouring Plague before refreshes')
 assert(first(g,t,SHT)==589,'the Tavern variant has no Insanity priority')
 t.debuffs={{id=589,expires=200},{id=34914,expires=200}};t.targetHealth=20;t.ttd=nil;t.debuffs[1].expires=101
 assert(first(g,t,SH)==15407,'an unknown lifetime on a low target skips the refresh');t.ttd=20;assert(first(g,t,SH)==589)
end)

test('Shadow Warcraft Tavern: Plague at three without a gate, Death before Mind Blast',function()
 local f,s=priest(90,3,shadowFull);s.debuffs={{id=589,expires=200},{id=34914,expires=200}};s.orbs=3;cooling(s,8092,3)
 assert(first(f,s,SHT)==2944 and first(f,s,SH)==15407);s.orbs=0;s.cooldown[8092]=nil;s.targetHealth=15
 assert(first(f,s,SHT)==32379 and first(f,s,SH)==8092)
end)

test('Shadow orbs: Devouring Plague needs a specialization; unavailable orbs never guess a spend',function()
 local f,s=priest(90,nil,shadowFull);s.debuffs={{id=589,expires=200},{id=34914,expires=200}};s.orbs=3
 assert(first(f,s,SH)==8092,'no specialization index: orbs unreadable, Plague skipped');s.spec=3;assert(first(f,s,SH)==2944)
end)

test('Shadow moving: instants only, then stop',function()
 local f,s=priest(90,3,shadowFull);s.debuffs={{id=589,expires=200},{id=34914,expires=200}};s.moving=true
 assert(first(f,s,SH)==589,'Pain is the moving filler');s.orbs=3;assert(first(f,s,SH)==2944);s.orbs=0
 s.buffs={{id=124430}};assert(first(f,s,SH)==8092,'instant Mind Blast on Divine Insight');s.buffs={}
 s.nopower[589]=true;stopped(f,s,SH,true,'nothing instant: stop rather than cast')
end)

test('Shadow packs: five engaged enemies run the tier-6 talent, DoTs and Mind Sear; before Mind Sear the single-target list',function()
 local f,s=priest(90,3,shadowFull);s.enemies={0,0,0,0};s.debuffs={{id=589,expires=200},{id=34914,expires=200}}
 assert(first(f,s,SH)==8092,'four enemies: single target');s.enemies={0,0,0,0,0};assert(first(f,s,SH)==48045)
 s.debuffs={};assert(first(f,s,SH)==34914,'DoT the current target first');s.debuffs={{id=589,expires=200},{id=34914,expires=200}}
 M.know(s,120517);assert(first(f,s,SH)==120517,'Halo on cooldown in packs');s.known[120517]=false
 s.nopower[48045]=true;stopped(f,s,SH,true,'Mind Sear known: the pack list ends here');s.nopower[48045]=nil
 s.known[48045]=false;assert(first(f,s,SH)==8092,'before 76 the pack falls through to single target')
 s.enemies={0,false,false,false,false};M.know(s,48045);assert(first(f,s,SH)==8092,'enemies not fighting you do not count')
end)

test('Shadow reminders: Shadowform, Inner Fire, Silence, long-fight Shadowfiend, Dispersion, Vampiric Embrace',function()
 local f,s=priest(90,3,shadowFull,{588,21562,10060});local u=M.upkeep(f,s,SH)
 assert(u['priest-shadowform']==15473 and u['priest-inner-fire']==588 and not u['priest-fortitude'],'Fortitude only between pulls')
 s.combat=false;assert(M.upkeep(f,s,SH)['priest-fortitude']==21562);s.combat=true
 s.buffs={{id=15473},{id=73413},{id=21562,source='party1'}};u=M.upkeep(f,s,SH);assert(u['priest-shadowform']==15473,'the Shadowform aura is not the form')
 s.shift(15473);u=M.upkeep(f,s,SH);assert(not u['priest-shadowform'] and not u['priest-inner-fire'],'in Shadowform; Inner Will is respected')
 assert(not u['priest-silence']);s.targetCast='Frostbolt';assert(M.upkeep(f,s,SH)['priest-silence']==15487);s.targetInterruptible=false;assert(not M.upkeep(f,s,SH)['priest-silence'])
 assert(not u['priest-shadowfiend']);s.classification='elite';u=M.upkeep(f,s,SH);assert(u['priest-shadowfiend']==34433 and u['priest-power-infusion']==10060)
 s.classification='normal';s.ttd=30;assert(M.upkeep(f,s,SH)['priest-shadowfiend'],'a target that will live 15 s')
 s.mana=10;assert(M.upkeep(f,s,SH)['priest-dispersion']==47585);s.mana=100;s.health=35;assert(M.upkeep(f,s,SH)['priest-vampiric-embrace']==15286)
 assert(not M.upkeep(f,s,SH)['priest-psychic-scream'],'Psychic Scream ships off')
end)

test('Discipline heals a friendly target: shield triggers, Surge, Penance, emergencies, group heals, top-up',function()
 local f,s=priest(90,1,discFull);friend(s,40);s.cast=true;stopped(f,s,DI,true,'cast');s.cast=false
 s.channel=true;stopped(f,s,DI,true,'Penance channel');s.channel=false
 assert(first(f,s,DI)==17,'low target, no Weakened Soul: shield');s.debuffs={{id=6788,source='party1'}}
 assert(first(f,s,DI)==47540,'Weakened Soul: Penance');cooling(s,47540,5);assert(first(f,s,DI)==2060,'Greater Heal');s.targetHealth=30
 assert(first(f,s,DI)==2061,'Flash Heal when very low');s.buffs={{id=123266}};assert(first(f,s,DI)==17,'Divine Insight shields through Weakened Soul');s.buffs={}
 s.targetHealth=80;s.buffs={{id=114255}};assert(first(f,s,DI)==2061,'free Flash on Surge of Light');s.buffs={}
 s.debuffs={};s.history={{spell=17,time=95}};assert(first(f,s,DI)==2050,'shield cast 5 s ago: Heal to top up')
 s.history={{spell=17,time=80}};assert(first(f,s,DI)==17,'Rapture: shield again after 12 s');s.history=nil;s.debuffs={{id=6788}}
 s.combat=false;s.debuffs={};assert(first(f,s,DI)==17,'pre-pull shield');s.combat=true;s.debuffs={{id=6788}}
 s.targetHealth=95;stopped(f,s,DI,true,'healthy friend: nothing to do');s.group=true;assert(first(f,s,DI)==33076,'Prayer of Mending in a group fight')
 cooling(s,33076,5);s.members(50,50,50);assert(first(f,s,DI)==596,'Prayer of Healing for three hurt allies')
 s.buffs={{id=109964}};assert(first(f,s,DI)==596);s.party={};assert(first(f,s,DI)==2060,'Spirit Shell: Greater Heal')
end)

test('Discipline Atonement on an enemy, solo Pain, and the reminders',function()
 local f,s=priest(90,1,discFull,{588,129250,19236,34433});assert(first(f,s,DI)==47540,'Penance on the enemy');cooling(s,47540,5)
 assert(first(f,s,DI)==129250,'Solace when known');s.known[129250]=false;assert(first(f,s,DI)==14914,'Holy Fire');cooling(s,14914,5)
 assert(first(f,s,DI)==589,'solo Pain');s.group=true;assert(first(f,s,DI)==585,'no Pain in a group');s.talents[9]=true;s.cooldown[14914]=nil
 assert(first(f,s,DI)==585,'Solace talented: never Holy Fire');s.hostile=false;stopped(f,s,DI,true,'no target')
 local u=M.upkeep(f,s,DI);assert(not u['priest-disc-archangel'] and not u['priest-disc-spirit-shell'],'Spirit Shell ships off')
 friend(s,20);s.buffs={{id=81661,stacks=5}};u=M.upkeep(f,s,DI)
 assert(u['priest-disc-archangel']==81700 and u['priest-disc-inner-focus']==89485 and u['priest-disc-pain-suppression']==33206)
 s.health=25;assert(M.upkeep(f,s,DI)['priest-disc-desperate-prayer']==19236);s.mana=50;assert(M.upkeep(f,s,DI)['priest-shadowfiend'])
end)

test('Holy heals a friendly target by chakra, group heals and Serendipity; fills an empty chakra by group size',function()
 local f,s=priest(90,2,holyFull);friend(s,85);s.buffs={{id=81208}}
 assert(first(f,s,HO)==88625,'Holy Word: Serenity in Serenity');cooling(s,88625,5);assert(first(f,s,HO)==33076,'Prayer of Mending')
 cooling(s,33076,5);assert(first(f,s,HO)==139,'Renew');s.targetBuffs={{id=139}};assert(first(f,s,HO)==2050,'Heal to top up')
 s.buffs[2]={id=63735,stacks=2};assert(first(f,s,HO)==2060,'Greater Heal at two Serendipity');s.buffs[2]=nil
 s.targetHealth=20;assert(first(f,s,HO)==17,'shield only when about to die');s.debuffs={{id=6788}};assert(first(f,s,HO)==2061)
 s.targetHealth=80;s.group=true;s.members(50,50,50);s.buffs={{id=81206}};assert(first(f,s,HO)==34861,'Circle of Healing')
 cooling(s,34861,5);s.cooldown[88625]=nil;assert(first(f,s,HO)==88625,'Holy Word: Sanctuary in Sanctuary');cooling(s,88625,5)
 assert(first(f,s,HO)==596,'Prayer of Healing');s.party={};s.group=false
 s.buffs={};local u=M.upkeep(f,s,HO);assert(u['priest-holy-chastise-chakra']==81209 and not u['priest-holy-serenity-chakra'])
 s.group=true;u=M.upkeep(f,s,HO);assert(u['priest-holy-serenity-chakra']==81208 and not u['priest-holy-sanctuary-chakra'])
 s.raid=true;u=M.upkeep(f,s,HO);assert(u['priest-holy-sanctuary-chakra']==81206);s.buffs={{id=81209}};assert(not M.upkeep(f,s,HO)['priest-holy-sanctuary-chakra'],'never swap a chosen chakra')
 s.targetHealth=20;assert(M.upkeep(f,s,HO)['priest-holy-guardian-spirit']==47788)
end)

test('Holy damage arm and the Icy Veins variant order',function()
 local f,s=priest(90,2,holyFull);assert(first(f,s,HO)==88625,'Chastise without a chakra');s.buffs={{id=81208}};assert(first(f,s,HO)==14914,'not in Serenity')
 cooling(s,14914,5);assert(first(f,s,HO)==589);s.debuffs={{id=589,expires=200}};assert(first(f,s,HO)==585)
 assert(first(f,s,HOI)==585,'the variant shares the damage arm')
 friend(s,30);s.debuffs={};s.cooldown={};assert(first(f,s,HO)==88625,'Serenity before the shield above 25%')
 s.targetHealth=50;assert(first(f,s,HO)==88625,'recommended: Serenity first');assert(first(f,s,HOI)==139,'Icy Veins: Renew first')
 s.targetBuffs={{id=139}};cooling(s,88625,5);cooling(s,33076,5);s.targetHealth=30;assert(first(f,s,HOI)==2060 and first(f,s,HO)==2061,'Icy Veins heals before the emergency Flash')
 s.buffs={{id=81206}};s.group=true;s.members(50,50,50);s.cooldown[88625]=nil;assert(first(f,s,HOI)==88625,'Sanctuary mode')
 local g,t=priest(20,2,{88625,17,2061});friend(t,80);assert(first(g,t,HOI)==2061,'Flash Heal filler before Heal is learned')
end)

test('Unspecialized: heal a friend, Pain then Smite on an enemy, self-shield when solo',function()
 local f,s=priest(5,nil,{17,2061});s.range[585]=true
 assert(first(f,s,UN)==589);s.debuffs={{id=589,expires=110}};assert(first(f,s,UN)==585)
 s.cast=true;stopped(f,s,UN,true,'cast');s.cast=false;s.hostile=false;stopped(f,s,UN,true,'no target')
 friend(s,50);assert(first(f,s,UN)==2061);s.targetHealth=75;s.debuffs={};assert(first(f,s,UN)==17);s.debuffs={{id=6788}};stopped(f,s,UN,true,'shielded friend')
 s.health=50;s.playerDebuffs={};assert(M.upkeep(f,s,UN)['priest-starter-self-shield']==17);s.playerDebuffs={{id=6788}}
 assert(not M.upkeep(f,s,UN)['priest-starter-self-shield'],'Weakened Soul on you')
end)

test('real publisher auto-selects Shadow and follows the orbs',function()
 local f,s=priest(90,3,shadowFull);s.debuffs={{id=589,expires=200},{id=34914,expires=200}};s.buffs={{id=15473}}
 local poll,selected,glow=M.publisher(f,s);poll();assert(selected()==SH and f.addon.currentSpell==8092,tostring(f.addon.currentSpell))
 s.orbs=3;poll();assert(f.addon.currentSpell==2944);assert(#glow>0)
end)
finish()
