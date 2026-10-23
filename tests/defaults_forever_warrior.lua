-- WoW Forever Warrior premades: Protection (Icy Veins, recommended tank), Protection debuff upkeep
-- (Warcraft Tavern), melee DPS (Icy Veins, recommended default) and spend-rage DPS (Warcraft
-- Tavern). Real predicates, catalog, composition, sequence and publisher under a synthetic
-- probe-policy Forever context; WoW observations are modeled in
-- tests/fixtures/forever_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/forever_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local PROT,PTAV,DPS,DTAV='rm.forever.warrior.protection','rm.forever.warrior.protection.warcrafttavern','rm.forever.warrior.dps','rm.forever.warrior.dps.warcrafttavern'
local function warrior(level,...)
 local f,s=M.fixture('WARRIOR',{level=level});M.know(s,6603,78,6673)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.range[6603]=true;s.usable[7384]=false;s.usable[6572]=false;s.usable[402927]=false;s.power=50
 return f,s
end
local leveling={100,772,6343,1715,2687,7386,7384,72,6572,1160,2565,845,1240193,402927,5308}
local function first(f,s,id)return(M.first(f,s,id))end
local function cd(s,id,n)s.cooldown[id]={startTime=99,duration=n or 6,isEnabled=true,modRate=1}end

test('Defensive Stance picks the tank premade; anything else the DPS premade; the Warcraft Tavern variants rank below',function()
 local f,s=warrior(1);s.forms=1
 for _,level in ipairs({1,30,60})do s.level=level;assert(M.selected(f,s)==DPS,'level '..level)end
 s.forms,s.form=3,2;assert(M.selected(f,s)==PROT);s.form=3;assert(M.selected(f,s)==DPS);s.form=2
 local a=f.addon;assert(a:SetDefaultRotationEnabled(PROT,false));assert(M.selected(f,s)==PTAV);s.form=1;assert(a:SetDefaultRotationEnabled(DPS,false));assert(M.selected(f,s)==DTAV)
 s.level=9;s.form=2;assert(M.selected(f,s)==DTAV,'no tank premade before Defensive Stance (10)')
 for _,id in ipairs({PTAV,DTAV})do for _,src in ipairs(a:GetDefaultRotation(id).envelope.sources)do assert(src.url:find('warcrafttavern'),src.url)end end
end)

test('on the real restricted Forever client the premades are listed but never auto-selected',function()
 local f,s=M.fixture('WARRIOR',{restricted=true});M.know(s,6603,78)
 local rows=f.addon:ListDefaultRotations(0);assert(#rows==4)
 for _,row in ipairs(rows)do assert(row.readOnly and row.builtin and not row.eligible,row.id)end
 local poll,selected=M.publisher(f,s);poll();assert(selected()==nil)
end)

test('a Slam cast keeps Attack going; no target suppresses it; out of combat only Charge',function()
 for _,id in ipairs({PROT,PTAV,DPS,DTAV})do local f,s=warrior(30,leveling)
  s.cast=true;local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and not r.suppressAttack,'casting');s.cast=false
  s.hostile=false;x,r=M.first(f,s,id);assert(not x and r.suppressAttack);s.hostile=true
  s.combat=false;assert(first(f,s,id)==100,'Charge');s.usable[100]=false;x,r=M.first(f,s,id);assert(not x and r.status=='stopped')
 end
end)

test('DPS while leveling: Rend, Overpower, Slam, Sunder with health floors',function()
 local f,s=warrior(20,leveling);assert(first(f,s,DPS)==1160,'solo Demoralizing Shout first');s.debuffs={{id=1160,source='party1'}};assert(first(f,s,DPS)==772)
 s.debuffs[2]={id=772,expires=110};assert(first(f,s,DPS)==1240193,'Slam while standing')
 s.moving=true;assert(first(f,s,DPS)==7386,'moving: Sunder');s.moving=false;cd(s,1240193,18);assert(first(f,s,DPS)==7386)
 s.debuffs[3]={id=7386,stacks=2};local x,r=M.first(f,s,DPS);assert(not x and r.status=='complete','two Sunders on a normal mob: white hits')
 s.classification='elite';assert(first(f,s,DPS)==7386,'five on an elite');s.classification='normal'
 s.usable[7384]=true;assert(first(f,s,DPS)==7384,'Overpower when it lights up');s.usable[7384]=false
 s.cooldown={};s.debuffs={{id=1160}};s.targetHealth=25;assert(first(f,s,DPS)==1240193,'no Rend below 30%');s.targetHealth=45;assert(first(f,s,DPS)==772)
 cd(s,1240193,18);s.debuffs[2]={id=772,expires=110};assert(first(f,s,DPS)==nil,'no Sunder below half health')
end)

test('Execute only on elites, bosses or in a group; solo normal mobs are left to white hits',function()
 local f,s=warrior(30,leveling);s.targetHealth=15;local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped'and not r.suppressAttack,'solo trash: pool rage')
 s.group=true;assert(first(f,s,DPS)==5308);s.group=false;s.classification='worldboss';assert(first(f,s,DPS)==5308)
 s.nopower[5308]=true;assert(first(f,s,DPS)==1240193,'no rage for Execute on a boss: carry on');s.classification='normal'
 assert(first(f,s,DTAV)==7386,'Warcraft Tavern: Sunders first');s.debuffs={{id=7386,stacks=5}};s.nopower[5308]=nil;assert(first(f,s,DTAV)==5308)
end)

test('DPS with the full kit: Mortal Strike or Bloodthirst, Whirlwind with spare rage, Rend only before Bloodthirst',function()
 local f,s=warrior(50,leveling,{12294,1680,20252});s.debuffs={{id=772,expires=110},{id=1160}};assert(first(f,s,DPS)==12294);cd(s,12294,4)
 assert(first(f,s,DPS)==1680,'Whirlwind while Mortal Strike recovers');cd(s,1680,10);assert(first(f,s,DPS)==1240193);s.power=40;assert(first(f,s,DPS)~=1240193,'keep 30 rage for Mortal Strike')
 s.power=50;s.range[6603]=false;assert(first(f,s,DPS)==20252,'Intercept a distant target');s.range[6603]=true
 local g,t=warrior(50,leveling,{23881,1680});t.debuffs={{id=1160}};assert(first(g,t,DPS)==23881,'Fury drops Rend');cd(t,23881,4);assert(first(g,t,DPS)==1680)
 t.cooldown={};t.cooldown[23881]={startTime=99,duration=1.2,isEnabled=true,modRate=1};t.power=50;assert(first(g,t,DPS)==1240193,'Bloodthirst nearly back: no Whirlwind at 50 rage')
 t.usable[402927]=true;t.health=80;assert(first(g,t,DPS)==402927,'Victory Rush when hurt')
 M.know(t,1310222);t.usable[402927]=false;t.creature=5;assert(first(g,t,DPS)==1310222,'Spearing Strike on a Giant')
end)

test('single target vs packs: the DPS arm and the tank arm on two engaged enemies',function()
 local f,s=warrior(40,leveling,{12292});s.enemies={0,0};s.debuffs={{id=772,expires=110}};assert(first(f,s,DPS)==6343,'Thunder Clap before Whirlwind is known')
 s.debuffs[2]={id=6343};assert(first(f,s,DPS)==1160,'solo Demoralizing Shout');s.debuffs[3]={id=1160,source='party1'};s.buffs={{id=12292}};assert(first(f,s,DPS)==1240193,'Sweeping Strikes Slam')
 M.know(s,1680);assert(first(f,s,DPS)==1680)
 local g,t=warrior(40,leveling,{23922});t.form=2;t.enemies={0,0};assert(first(g,t,PROT)==6343);cd(t,6343);assert(first(g,t,PROT)==1160)
 t.debuffs={{id=1160}};assert(first(g,t,PROT)==23922);cd(t,23922);t.usable[6572]=true;assert(first(g,t,PROT)==6572)
end)

test('tank single target: Revenge first on low rage, Shield Slam, Demoralizing Shout against melee, Sunder, elite Thunder Clap',function()
 local f,s=warrior(40,leveling,{23922});s.form=2;s.usable[6572]=true;assert(first(f,s,PROT)==23922);s.power=20;assert(first(f,s,PROT)==6572,'low rage: Revenge')
 s.power=50;cd(s,23922);assert(first(f,s,PROT)==6572);s.usable[6572]=false;assert(first(f,s,PROT)==1160);s.targetMana=50;assert(first(f,s,PROT)==772,'casters: no Demoralizing Shout')
 s.debuffs={{id=772,expires=110}};assert(first(f,s,PROT)==7386);s.debuffs[2]={id=7386,stacks=2};local x=first(f,s,PROT);assert(x==nil,'normal mob: two Sunders')
 s.classification='elite';assert(first(f,s,PROT)==7386);s.debuffs[2].stacks=5;assert(first(f,s,PROT)==6343,'elite Thunder Clap')
 assert(first(f,s,PTAV)==6343,'Warcraft Tavern: Thunder Clap kept up first');s.debuffs[3]={id=6343};assert(first(f,s,PTAV)==1160,'Warcraft Tavern: Demoralizing Shout on casters too')
 s.debuffs[4]={id=1160};s.usable[6572]=true;assert(first(f,s,PTAV)==6572)
 s.debuffs[2].expires=101;assert(first(f,s,PTAV)==7386,'Warcraft Tavern refreshes Sunder')
end)

test('reminders: Battle Shout, Bloodrage between pulls, interrupts, rage dumps, tank and DPS cooldowns',function()
 local f,s=warrior(40,leveling,{12292,12328,18499,12975,6552,1719,20230});s.power=20;local u=M.upkeep(f,s,DPS)
 assert(u['warrior-dps-battle-shout']==6673 and u['warrior-dps-bloodrage']==2687);s.buffs={{id=6673,source='party1',expires=150}};s.combat=false
 u=M.upkeep(f,s,DPS);assert(not u['warrior-dps-battle-shout']and u['warrior-dps-bloodrage'],'anyone\'s shout counts; Bloodrage out of combat');s.combat=true
 s.targetCast='Heal';u=M.upkeep(f,s,DPS);assert(u['warrior-dps-shield-bash']==72 and u['warrior-dps-pummel']==6552);s.targetCast=nil
 assert(not u['warrior-dps-heroic-strike']);s.power=80;assert(M.upkeep(f,s,DPS)['warrior-dps-heroic-strike']==78);s.active[78]=true;assert(not M.upkeep(f,s,DPS)['warrior-dps-heroic-strike'],'already queued')
 s.active={};M.know(s,12294);s.power=60;assert(not M.upkeep(f,s,DPS)['warrior-dps-heroic-strike']);cd(s,12294,4);assert(M.upkeep(f,s,DPS)['warrior-dps-heroic-strike'],'60 while Mortal Strike recovers')
 assert(M.upkeep(f,s,DTAV)['warrior-tavern-heroic-strike']);s.enemies={0,0};u=M.upkeep(f,s,DPS);assert(u['warrior-dps-cleave']==845 and not u['warrior-dps-heroic-strike'])
 assert(u['warrior-dps-sweeping-strikes']==12292 and u['warrior-dps-death-wish']==12328);assert(not u['warrior-dps-recklessness']and not u['warrior-dps-retaliation'],'listed off by default')
 s.enemies={};s.power=20;assert(M.upkeep(f,s,DPS)['warrior-dps-berserker-rage']==18499);s.targettarget='party1';assert(not M.upkeep(f,s,DPS)['warrior-dps-berserker-rage'])
 u=M.upkeep(f,s,DTAV);assert(u['warrior-tavern-recklessness']==1719 and not u['warrior-tavern-death-wish'],'Death Wish waits for Recklessness');s.buffs={{id=1719}};assert(M.upkeep(f,s,DTAV)['warrior-tavern-death-wish'])
 s.form,s.targettarget=2,'player';u=M.upkeep(f,s,PROT);assert(u['warrior-prot-shield-block']==2565);s.targetMana=40;assert(not M.upkeep(f,s,PROT)['warrior-prot-shield-block'],'not against casters')
 s.health=25;u=M.upkeep(f,s,PROT);assert(u['warrior-prot-last-stand']==12975 and not u['warrior-prot-taunt']and not u['warrior-prot-shield-wall'])
 assert(not M.upkeep(f,s,PTAV)['warrior-tavern-prot-shield-block'])
end)

test('real publisher picks the stance premade and highlights',function()
 local f,s=warrior(30,leveling);local poll,selected,glow=M.publisher(f,s)
 poll();assert(selected()==DPS and f.addon.currentSpell==1160);s.form=2;poll();assert(selected()==PROT);assert(#glow>0)
end)
finish()
