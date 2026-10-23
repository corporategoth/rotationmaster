-- WoW Forever Rogue premades: melee DPS (recommended), Subtlety Ambush (Warcraft Tavern) and
-- Subtlety Garrote (Wowhead). Real predicates, catalog, composition, sequence and publisher under a
-- synthetic probe-policy Forever context; WoW observations are modeled in
-- tests/fixtures/forever_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/forever_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local DPS,TAV,WH='rm.forever.rogue.dps','rm.forever.rogue.subtlety.warcrafttavern','rm.forever.rogue.subtlety.wowhead'
local function rogue(level,...)
 local f,s=M.fixture('ROGUE',{level=level});M.know(s,6603,1752,2098)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.range[6603]=true;s.usable[14251]=false;s.usable[8676]=false
 return f,s
end
local early={53,5171,1766,703,8647,8676,1943}
local subtlety={16511,14183,14278}
local function first(f,s,id)return(M.first(f,s,id))end
local function sliced(s)s.buffs={{id=5171,expires=130}}end

test('the recommended premade auto-selects at every level; Subtlety variants need the Subtlety tree, their build talent, and rank below it',function()
 local f,s=rogue(1)
 for _,level in ipairs({1,30,60})do s.level=level;assert(M.selected(f,s)==DPS,'level '..level)end
 assert(not M.switches(f,TAV)and not M.switches(f,WH),'no Subtlety tree, no Subtlety variant')
 M.know(s,16511,14183);s.level=30;M.trees(f,s,{0,0,21});assert(not M.switches(f,TAV)and not M.switches(f,WH),'Subtlety tree without the build talents')
 M.node(f,s,105750,1);assert(M.switches(f,TAV)and not M.switches(f,WH),'Cutthroat (trait node) talented: the Ambush build')
 M.node(f,s,105745,2);assert(M.switches(f,WH)and M.selected(f,s)==DPS,'Dirty Deeds (trait node) with Premeditation: the Garrote build; the default still wins')
 s.known[14183]=false;assert(not M.switches(f,WH),'the Garrote build also needs Premeditation');s.known[14183]=true
 M.trees(f,s,{31,0,20});assert(not M.switches(f,TAV),'20 Subtlety points under another main tree');M.trees(f,s,{0,0,21})
 local a=f.addon;assert(a:SetDefaultRotationEnabled(DPS,false));assert(M.selected(f,s)==TAV);assert(a:SetDefaultRotationEnabled(TAV,false));assert(M.selected(f,s)==WH)
 s.level=24;assert(M.selected(f,s)==nil,'below 25 only the recommended premade applies')
 for _,src in ipairs(a:GetDefaultRotation(TAV).envelope.sources)do assert(not src.url:find('wowhead'),src.url)end
 -- The variant's priority sources are Wowhead's; SimulationCraft only supplies the talent node IDs.
 for _,src in ipairs(a:GetDefaultRotation(WH).envelope.sources)do assert(src.url:find('wowhead')or src.url:find('simulationcraft/simc/blob/[%x]+/engine/dbc/generated/trait_data'),src.url)end
end)

test('on the real restricted Forever client the premades are listed but never auto-selected',function()
 local f,s=M.fixture('ROGUE',{restricted=true});M.know(s,6603,1752,2098,16511,14183)
 local rows=f.addon:ListDefaultRotations(0);assert(#rows==3)
 for _,row in ipairs(rows)do assert(row.readOnly and row.builtin and not row.eligible,row.id)end
 local poll,selected=M.publisher(f,s);poll();assert(selected()==nil,'a restricted client never runs a packaged rotation')
end)

test('casts, channels and a missing target stop with Attack suppressed',function()
 for _,id in ipairs({DPS,TAV,WH})do local f,s=rogue(30,early,subtlety)
  for _,key in ipairs({'cast','channel'})do s[key]=true;local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
  s.hostile=false;local x,r=M.first(f,s,id);assert(not x and r.suppressAttack);s.hostile=true;assert(first(f,s,id)==16511 or first(f,s,id)==14278)
 end
end)

test('stealth openers: default adapts by spell known and group; variants open Ambush or Garrote; all stop in Stealth',function()
 local f,s=rogue(10);s.stealth=true;s.combat=false;assert(first(f,s,DPS)==1752,'nothing learned yet: Sinister Strike')
 M.know(s,703);assert(first(f,s,DPS)==703);M.know(s,8676);s.usable[8676]=nil;assert(first(f,s,DPS)==703,'Ambush needs the target not facing you')
 s.targettarget=nil;assert(first(f,s,DPS)==8676);M.know(s,1833);assert(first(f,s,DPS)==1833,'solo Cheap Shot');s.group=true;assert(first(f,s,DPS)==8676)
 M.know(s,16511);s.classification='elite';assert(first(f,s,DPS)==703,'Subtlety Garrote on a group elite')
 M.know(s,14183);assert(first(f,s,DPS)==14183,'Premeditation first');s.points=4;assert(first(f,s,DPS)==703,'not past three points')
 s.points=0;assert(first(f,s,TAV)==14183);s.points=4;assert(first(f,s,TAV)==8676,'Tavern opens Ambush');assert(first(f,s,WH)==703,'Wowhead opens Garrote')
 for spell in pairs(s.known)do s.nopower[spell]=true end
 for _,id in ipairs({DPS,TAV,WH})do local x,r=M.first(f,s,id);assert(not x and r.status=='stopped'and r.suppressAttack,id)end
end)

test('finishers: Slice and Dice from three, Venom, refresh in the last second, five-point spend and pool',function()
 local f,s=rogue(40,early);s.points=2;assert(first(f,s,DPS)==1752);s.points=3;assert(first(f,s,DPS)==5171)
 sliced(s);assert(first(f,s,DPS)==1752);s.buffs[1].source='party1';assert(first(f,s,DPS)==5171,'another rogue\'s Slice is not yours');sliced(s)
 M.know(s,1310703);s.points=4;assert(first(f,s,DPS)==1310703,'Venom missing at four');s.buffs[2]={id=1310703,expires=120}
 s.buffs[1].expires=100.5;assert(first(f,s,DPS)==5171,'refresh with under a second left');s.buffs[1].expires=130
 s.points=5;assert(first(f,s,DPS)==2098);s.nopower[2098]=true;local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped'and not r.suppressAttack,'pool at five, Attack continues')
end)

test('Subtlety five points: Rupture on long fights (default), always (Wowhead), never (Warcraft Tavern)',function()
 local f,s=rogue(40,early,subtlety);sliced(s);s.points=5
 assert(first(f,s,DPS)==2098,'solo normal mob: Eviscerate');s.classification='elite';assert(first(f,s,DPS)==1943)
 s.debuffs={{id=1943}};assert(first(f,s,DPS)==2098);s.debuffs={}
 assert(first(f,s,WH)==1943);s.classification='normal';assert(first(f,s,WH)==1943,'Wowhead: Rupture is the standing finisher');assert(first(f,s,TAV)==2098)
 M.know(s,1310707);s.classification='elite';assert(first(f,s,DPS)==2098,'Mutilate known: Assassination does not Rupture')
end)

test('group Expose Armor on elites unless five Sunders are up',function()
 local f,s=rogue(40,early);sliced(s);s.points=5;assert(first(f,s,DPS)==2098)
 s.group=true;assert(first(f,s,DPS)==2098,'trash: no Expose Armor');s.classification='worldboss';assert(first(f,s,DPS)==8647)
 s.debuffs={{id=7386,stacks=5,source='party1'}};assert(first(f,s,DPS)==2098,'a warrior holds five Sunders')
 s.debuffs={{id=8647,expires=120}};assert(first(f,s,DPS)==2098);s.debuffs[1].expires=102;assert(first(f,s,DPS)==8647,'refresh under three seconds')
end)

test('builders follow what is known: Mutilate below four points, Hemorrhage debuff, Ghostly Strike, Backstab when not tanked',function()
 local f,s=rogue(40,early);assert(first(f,s,DPS)==1752);s.targettarget='party1';assert(first(f,s,DPS)==53,'Backstab when the target is not on you')
 M.know(s,1310707);s.targettarget='player';assert(first(f,s,DPS)==1310707);sliced(s);s.points=3;assert(first(f,s,DPS)==1310707)
 s.points=4;s.buffs[2]={id=1310703,expires=130};assert(first(f,s,DPS)==1752,'Sinister Strike for the fifth point')
 s.points=2;s.nopower[1310707]=true;local x,r=M.first(f,s,DPS);assert(not x and r.status=='stopped','pool for Mutilate rather than a Sinister Strike')
 local g,t=rogue(40,early,subtlety);assert(first(g,t,DPS)==16511,'keep your Hemorrhage debuff up first');t.debuffs={{id=16511,expires=110}}
 assert(first(g,t,DPS)==14278,'then Ghostly Strike');t.cooldown[14278]={startTime=99,duration=20,isEnabled=true,modRate=1}
 assert(first(g,t,DPS)==16511,'Hemorrhage is still the builder');t.debuffs={}
 assert(first(g,t,TAV)==16511,'Tavern: Hemorrhage when tanked');t.targettarget='party1';assert(first(g,t,TAV)==53,'Tavern: Backstab from behind')
 M.know(t,1757,1759);t.known[16511],t.known[14278],t.known[53]=false,false,false;assert(first(g,t,DPS)==1759,'highest learned Sinister rank')
 t.mapped[1759]=false;assert(first(g,t,DPS)==1757)
end)

test('reactive Riposte and Cutthroat Ambush below five points',function()
 local f,s=rogue(40,early,{14251});sliced(s);s.usable[14251]=true;assert(first(f,s,DPS)==14251)
 s.usable[14251]=false;s.usable[8676]=true;assert(first(f,s,DPS)==8676,'Cutthroat proc');s.points=5;assert(first(f,s,DPS)==2098)
 s.points=4;assert(first(f,s,TAV)==8676)
end)

test('single target vs packs: Blade Flurry and Adrenaline Rush on two engaged enemies or an elite',function()
 local f,s=rogue(40,early,{13877,13750});local u=M.upkeep(f,s,DPS);assert(not u['rogue-blade-flurry'])
 s.enemies={0,1};u=M.upkeep(f,s,DPS);assert(u['rogue-blade-flurry']==13877 and u['rogue-adrenaline-rush']==13750)
 s.enemies={3,false};assert(not M.upkeep(f,s,DPS)['rogue-blade-flurry'],'an enemy not fighting you is not counted')
 s.classification='elite';assert(M.upkeep(f,s,DPS)['rogue-blade-flurry']);s.combat=false;assert(not M.upkeep(f,s,DPS)['rogue-blade-flurry'])
end)

test('reminders: poisons per weapon, Kick, Cold Blood by spec, Evasion solo, Feint in groups, Thistle Tea, Preparation',function()
 local f,s=rogue(40,early,{14177,1966,14185,1856,5277});local u=M.upkeep(f,s,DPS)
 assert(u['rogue-mainhand-poison']and not u['rogue-offhand-poison'],'no off-hand weapon, no off-hand poison')
 s.offSpeed=1.8;assert(M.upkeep(f,s,DPS)['rogue-offhand-poison']);s.offEnchant,s.mainEnchant=true,true;u=M.upkeep(f,s,DPS)
 assert(not u['rogue-mainhand-poison']and not u['rogue-offhand-poison'])
 for _,step in ipairs(M.body(f.addon,DPS).cooldowns)do if step.id=='rogue-offhand-poison'then assert(step.action[1]==20844 and step.action[#step.action]==6947)end end
 assert(not u['rogue-kick']);s.targetCast='Fireball';assert(M.upkeep(f,s,DPS)['rogue-kick']==1766);s.targetInterruptible=false;assert(not M.upkeep(f,s,DPS)['rogue-kick'])
 s.points=4;assert(not M.upkeep(f,s,DPS)['rogue-cold-blood']);s.points=5;assert(M.upkeep(f,s,DPS)['rogue-cold-blood']==14177,'Eviscerate at five')
 M.know(s,1310703);assert(not M.upkeep(f,s,DPS)['rogue-cold-blood']);s.points=2;assert(M.upkeep(f,s,DPS)['rogue-cold-blood'],'Venom known: empower a Mutilate')
 s.health=40;assert(M.upkeep(f,s,DPS)['rogue-evasion']==5277);s.group=true;assert(not M.upkeep(f,s,DPS)['rogue-evasion'])
 assert(not M.upkeep(f,s,DPS)['rogue-feint']);s.threat=1;assert(M.upkeep(f,s,DPS)['rogue-feint']==1966)
 s.power=20;assert(M.upkeep(f,s,DPS)['rogue-thistle-tea']);s.buffs={{id=13750}};assert(not M.upkeep(f,s,DPS)['rogue-thistle-tea'])
 assert(not M.upkeep(f,s,DPS)['rogue-preparation']);s.cooldown[1856]={startTime=90,duration=300,isEnabled=true,modRate=1}
 assert(not M.upkeep(f,s,DPS)['rogue-preparation'],'Evasion is still ready');s.cooldown[5277]={startTime=90,duration=300,isEnabled=true,modRate=1}
 assert(M.upkeep(f,s,DPS)['rogue-preparation']==14185)
end)

test('variant cooldowns: Wowhead Vanishes to re-Garrote, Warcraft Tavern Vanishes for Ambush on a tanked boss',function()
 local f,s=rogue(40,early,subtlety,{1856,14185});assert(M.upkeep(f,s,WH)['rogue-wowhead-vanish']==1856);s.debuffs={{id=703,expires=110}}
 assert(not M.upkeep(f,s,WH)['rogue-wowhead-vanish']);s.debuffs={}
 assert(not M.upkeep(f,s,TAV)['rogue-tavern-vanish']);s.group,s.classification,s.targettarget=true,'worldboss','party1';assert(M.upkeep(f,s,TAV)['rogue-tavern-vanish']==1856)
 s.cooldown[1856]={startTime=90,duration=300,isEnabled=true,modRate=1};assert(M.upkeep(f,s,WH)['rogue-wowhead-preparation']and M.upkeep(f,s,TAV)['rogue-tavern-preparation'])
end)

test('unavailable combo points halt with Attack suppressed rather than guessing a builder',function()
 local f,s=rogue(20,early);f.env.UnitPower=function()error('unavailable')end
 local x,r=M.first(f,s,DPS);assert(not x and r.status=='unavailable'and r.suppressAttack)
end)

test('real publisher auto-selects the recommended premade and highlights across combo points',function()
 local f,s=rogue(40,early);local poll,selected,glow=M.publisher(f,s);sliced(s)
 poll();assert(selected()==DPS and f.addon.currentSpell==1752);s.points=5;poll();assert(f.addon.currentSpell==2098);assert(#glow>0)
end)
finish()
