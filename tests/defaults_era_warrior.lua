-- Classic Era and Season of Discovery Warrior premades. Real predicates, build context (season
-- rulesets, talents), catalog, composition, sequence and publisher; WoW observations are modeled
-- in tests/fixtures/era_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/era_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local DPS,PROT,PROTIV='rm.era.warrior.dps','rm.era.warrior.protection','rm.era.warrior.protection.icyveins'
local SDPS,SFC,SIV,STANK='rm.sod.warrior.dps','rm.sod.warrior.dps.wowhead','rm.sod.warrior.dps.icyveins','rm.sod.warrior.tank'
local VANILLA,SEASON={DPS,PROT,PROTIV},{SDPS,SFC,SIV,STANK}
local function warrior(level,...)
 local f,s=M.fixture('WARRIOR',{level=level});M.know(s,6603,78,100,6673)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.range[6603]=true;s.usable[7384]=false;s.usable[6572]=false;s.power=50;s.buffs={{id=6673,expires=200}}
 return f,s
end
local leveling={772,6343,1715,2687,7386,7384,72,1160,6572,2565,845,5308,1680,20252}
local function first(f,s,id)return(M.first(f,s,id))end
local function stopped(f,s,id)local x,r=M.first(f,s,id);return x==nil and r.status=='stopped',r end

test('every premade registers valid; vanilla on every realm, SoD only on Season of Discovery, above every vanilla premade',function()
 local f,s=warrior(60);local a=f.addon
 for _,id in ipairs(VANILLA)do local row=assert(M.row(f,id),id);assert(row.validation.valid and row.validation.resolved and row.eligible and a:GetDefaultRotationComposition(id),id)end
 for _,id in ipairs(SEASON)do local row=M.row(f,id);assert(row.validation.valid and row.validation.resolved and not row.eligible,id)end
 s.season=2;for _,id in ipairs(SEASON)do assert(M.row(f,id).eligible,id)end
 for _,id in ipairs(SEASON)do for _,v in ipairs(VANILLA)do assert(M.body(a,id).priority>M.body(a,v).priority,id..' must outrank '..v)end end
end)

test('auto-select: Defensive Stance picks the tank from level 10, anything else the DPS premade; variants when disabled',function()
 local f,s=warrior(5);local a=f.addon
 for _,season in ipairs({false,2})do s.season=season or nil;local dps,tank=season and SDPS or DPS,season and STANK or PROT
  s.level=5;s.form=2;assert(M.selected(f,s)==dps,'below 10 there is no tank premade')
  for _,level in ipairs({10,40,60})do s.level=level;s.form=2;assert(M.selected(f,s)==tank,level);s.form=1;assert(M.selected(f,s)==dps);s.form=3;assert(M.selected(f,s)==dps)end
 end
 s.season=2;s.form=1;assert(a:SetDefaultRotationEnabled(SDPS,false));assert(M.selected(f,s)==SFC);assert(a:SetDefaultRotationEnabled(SFC,false));assert(M.selected(f,s)==SIV)
 s.season=nil;s.form=2;assert(a:SetDefaultRotationEnabled(PROT,false));assert(M.selected(f,s)==PROTIV)
end)

test('boundaries: a Slam cast keeps Attack, no target stops it, out of combat only Charge',function()
 for _,id in ipairs({DPS,PROT,SDPS,STANK})do local f,s=warrior(60,leveling);if id==SDPS or id==STANK then s.season=2 end
  s.cast=true;local ok,r=stopped(f,s,id);assert(ok and not r.suppressAttack,id);s.cast=false
  s.exists=false;ok,r=stopped(f,s,id);assert(ok and r.suppressAttack,id);s.exists=true
  s.combat=false;assert(first(f,s,id)==100,id..' Charge');s.nopower[100]=true;ok,r=stopped(f,s,id);assert(ok and not r.suppressAttack,id)
 end
end)

test('DPS leveling: Rend until the main strike, Sunder on healthy targets, Overpower, Thunder Clap on packs before Whirlwind',function()
 local f,s=warrior(20,{772,7386,7384,6343,1715})
 assert(first(f,s,DPS)==772);s.debuffs={{id=772}};assert(first(f,s,DPS)==7386)
 s.debuffs={};s.creature=6;assert(first(f,s,DPS)==7386,'no Rend on Undead');s.creature=7
 s.usable[7384]=true;assert(first(f,s,DPS)==7384,'Overpower before Rend');s.usable[7384]=false
 s.targetHealth=50;s.debuffs={{id=772}};assert(first(f,s,DPS)==nil,'no Sunder below 60%')
 s.enemies={0,0,0};assert(first(f,s,DPS)==6343);M.know(s,1680);assert(first(f,s,DPS)==1680,'Whirlwind replaces Thunder Clap')
 local u=M.upkeep(f,s,DPS);assert(not u['warrior-dps-heroic-strike']);s.enemies={};s.power=25;assert(not M.upkeep(f,s,DPS)['warrior-dps-heroic-strike'],'Whirlwind known: no low-rage dump')
 s.known[1680]=false;assert(M.upkeep(f,s,DPS)['warrior-dps-heroic-strike']==78,'leveling dump from 20 rage')
end)

test('DPS at 60: Execute first, Bloodthirst, Whirlwind with rage for the strike, Slam after a swing, Hamstring at the cap',function()
 local f,s=warrior(60,leveling,{23881,1464});local a=f.addon
 assert(first(f,s,DPS)==23881);s.cooldown[23881]={startTime=99,duration=6,isEnabled=true,modRate=1};assert(first(f,s,DPS)==1680,'Whirlwind while Bloodthirst recovers')
 s.cooldown[23881]={startTime=99.5,duration=1.6,isEnabled=true,modRate=1};s.power=40;assert(first(f,s,DPS)~=1680,'keep rage for Bloodthirst');s.power=60;assert(first(f,s,DPS)==1680)
 s.targetHealth=15;assert(first(f,s,DPS)==5308,'Execute first');s.targetHealth=100
 s.talent['2:12']=3;a.lastMainSwing=100;s.cooldown[23881]=nil;s.nopower[23881]=true;assert(first(f,s,DPS)==1464,'Slam right after a swing')
 a.lastMainSwing=98.5;assert(first(f,s,DPS)~=1464);s.nopower[23881]=nil
 s.cooldown[23881]={startTime=99,duration=6,isEnabled=true,modRate=1};s.cooldown[1680]={startTime=99,duration=10,isEnabled=true,modRate=1};s.power=85;s.targetHealth=50
 assert(first(f,s,DPS)==1715,'Hamstring at the rage cap')
 s.classification='worldboss';s.targetHealth=100;s.power=50;s.cooldown={};assert(first(f,s,DPS)==7386,'boss Sunder to five')
 s.debuffs={{id=7386,stacks=5,source='party1'}};assert(first(f,s,DPS)==23881);s.debuffs={{id=8647,source='party2'}};assert(first(f,s,DPS)==23881,'Expose Armor: no Sunder')
end)

test('DPS reminders: Battle Shout, Heroic Strike at 40 once queued not again, Cleave, Bloodrage, Death Wish and Recklessness timing',function()
 local f,s=warrior(60,leveling,{23881,12328,1719,12292});s.buffs={}
 local u=M.upkeep(f,s,DPS);assert(u['warrior-dps-battle-shout']==6673 and u['warrior-dps-heroic-strike']==78 and u['warrior-dps-bloodrage']==2687)
 s.active[78]=true;assert(not M.upkeep(f,s,DPS)['warrior-dps-heroic-strike'],'already queued');s.active[78]=nil
 s.enemies={0,0};u=M.upkeep(f,s,DPS);assert(u['warrior-dps-cleave']==845 and u['warrior-dps-sweeping-strikes']==12292 and not u['warrior-dps-heroic-strike'])
 s.enemies={};assert(M.upkeep(f,s,DPS)['warrior-dps-death-wish']==12328,'trash: on cooldown')
 s.classification='worldboss';u=M.upkeep(f,s,DPS);assert(not u['warrior-dps-death-wish']and not u['warrior-dps-recklessness'])
 s.ttd=25;u=M.upkeep(f,s,DPS);assert(u['warrior-dps-death-wish']and not u['warrior-dps-recklessness']);s.buffs={{id=12328}};assert(M.upkeep(f,s,DPS)['warrior-dps-recklessness']==1719)
 s.health=20;assert(not M.upkeep(f,s,DPS)['warrior-dps-intimidating-shout'],'Hardcore buttons are listed off')
end)

test('tank: Revenge, Shield Slam, Sunder to five, Demoralizing Shout on elites, Sunder filler; shouts on big packs',function()
 local f,s=warrior(60,leveling,{23922});s.form=2
 s.usable[6572]=true;assert(first(f,s,PROT)==6572);s.usable[6572]=false;assert(first(f,s,PROT)==23922);s.nopower[23922]=true
 assert(first(f,s,PROT)==7386);s.debuffs={{id=7386,stacks=5}};s.classification='elite';assert(first(f,s,PROT)==1160)
 s.debuffs[2]={id=99,source='party1'};assert(first(f,s,PROT)==7386,'a druid\'s Demoralizing Roar counts')
 s.enemies={0,0,0,0};s.debuffs={};assert(first(f,s,PROT)==1160);s.debuffs={{id=1160}};assert(first(f,s,PROT)==6673,'Battle Shout for pack threat')
 s.enemies={};s.known[23922]=false;s.debuffs={};s.classification='normal';s.usable[7386]=false;assert(first(f,s,PROT)==772,'leveling Rend')
 s.power=40;local u=M.upkeep(f,s,PROT);assert(u['warrior-prot-shield-block']==2565 and not u['warrior-prot-heroic-strike']);s.power=55;assert(M.upkeep(f,s,PROT)['warrior-prot-heroic-strike'])
 s.targettarget='party1';assert(not M.upkeep(f,s,PROT)['warrior-prot-shield-block'],'not tanking: no Shield Block')
 s.usable[7386]=nil;s.debuffs={{id=7386,stacks=5}};s.nopower[23922]=nil;M.know(s,23922);assert(first(f,s,PROTIV)==1160,'Icy Veins keeps Demoralizing Shout up')
 s.debuffs[2]={id=1160};assert(first(f,s,PROTIV)==23922);s.nopower[23922]=true
 assert(first(f,s,PROTIV)==6673 and first(f,s,PROT)==7386,'Icy Veins: Battle Shout instead of Sunder')
end)

test('SoD DPS: Slammin\' stacks, Rend, Blood Surge Slam, Bloodthirst; two-hander Quick Strike or dual-wield fillers; Sudden Death Execute',function()
 local f,s=warrior(60,leveling,{23881,402911,403196,1464});s.season=2
 s.buffs[2]={id=1234005,stacks=3};assert(first(f,s,SDPS)==1464);s.buffs[2]=nil
 assert(first(f,s,SDPS)==772);s.debuffs={{id=772}};s.buffs[2]={id=413399};assert(first(f,s,SDPS)==1464,'Blood Surge');s.buffs[2]=nil
 assert(first(f,s,SDPS)==23881);s.nopower[23881]=true;assert(first(f,s,SDPS)==1680,'dual wield: Whirlwind');s.nopower[1680]=true
 assert(first(f,s,SDPS)==402911);s.nopower[402911]=true;assert(first(f,s,SDPS)==403196,'Devastate replaces Sunder')
 M.know(s,429765);assert(first(f,s,SDPS)==429765,'Quick Strike engraved: two-hander');s.power=20;assert(first(f,s,SDPS)==nil)
 s.buffs[2]={id=440114};assert(first(f,s,SDPS)==5308,'Sudden Death')
 local u=M.upkeep(f,s,SDPS);assert(not u['sod-dps-heroic-strike']);s.buffs[3]={id=425415};assert(M.upkeep(f,s,SDPS)['sod-dps-heroic-strike']==78,'always with Consumed by Rage')
end)

test('SoD variants: Battle Forecaster stance swaps and no Rend; Icy Veins Execute first and no Rend',function()
 local f,s=warrior(60,leveling,{23881,2458,2457,402911});s.season=2;s.combat=true
 assert(first(f,s,SFC)==23881 and first(f,s,SDPS)==772)
 s.form=1;local u=M.upkeep(f,s,SFC);assert(u['sod-fc-berserker-stance']==2458 and not u['sod-fc-battle-stance'])
 s.buffs[2]={id=457816,expires=130};assert(not M.upkeep(f,s,SFC)['sod-fc-berserker-stance'])
 s.form=3;assert(M.upkeep(f,s,SFC)['sod-fc-battle-stance']==2457);s.buffs[3]={id=457817,expires=130};assert(not M.upkeep(f,s,SFC)['sod-fc-battle-stance'])
 s.targetHealth=15;assert(first(f,s,SIV)==5308);s.targetHealth=100;assert(first(f,s,SIV)==23881)
end)

test('SoD tank: Shield Slam for Defender\'s Resolve, Revenge, Devastate; Thunder Clap first on packs',function()
 local f,s=warrior(60,leveling,{23922,403196,440488});s.season=2;s.form=2
 assert(first(f,s,STANK)==23922);s.buffs[2]={id=460171,expires=130};s.usable[6572]=true;assert(first(f,s,STANK)==6572)
 s.usable[6572]=false;assert(first(f,s,STANK)==23922);s.nopower[23922]=true;assert(first(f,s,STANK)==440488);s.nopower[440488]=true
 assert(first(f,s,STANK)==5308,'Execute whenever the game allows it');s.usable[5308]=false;assert(first(f,s,STANK)==403196)
 s.buffs[2]={id=462230,expires=101};s.nopower[23922]=nil;assert(first(f,s,STANK)==23922,'either Defender\'s Resolve ID, ending')
 s.enemies={0,0};assert(first(f,s,STANK)==6343)
 local u=M.upkeep(f,s,STANK);assert(u['sod-tank-shield-block']==2565 and not u['sod-tank-taunt'])
end)

test('real publisher follows the stance and the realm',function()
 local f,s=warrior(40,leveling,{12294});local poll,selected=M.publisher(f,s)
 poll();assert(selected()==DPS and f.addon.currentSpell==12294)
 s.form=2;poll();assert(selected()==PROT);s.season=2;f.addon:InvalidateBuildContext('client');poll();assert(selected()==STANK)
 s.form=1;poll();assert(selected()==SDPS)
end)
finish()
