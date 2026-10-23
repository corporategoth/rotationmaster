-- Classic Era and Season of Discovery Rogue premades. Real predicates, build context (season
-- rulesets, talents), catalog, composition, sequence and publisher; WoW observations are modeled
-- in tests/fixtures/era_rogue_shaman_warlock_warrior.lua.
local M=dofile('tests/fixtures/era_rogue_shaman_warlock_warrior.lua');local test,finish=M.F.suite()
local DPS,TAV,SIM='rm.era.rogue.dps','rm.era.rogue.dps.warcrafttavern','rm.era.rogue.dps.wowsims'
local SOD,SIV,SZK,TANK='rm.sod.rogue.dps','rm.sod.rogue.dps.icyveins','rm.sod.rogue.dps.zockify','rm.sod.rogue.tank'
local VANILLA,SEASON={DPS,TAV,SIM},{SOD,SIV,SZK,TANK}
local function rogue(level,...)
 local f,s=M.fixture('ROGUE',{level=level});M.know(s,6603,1752,2098)
 for _,set in ipairs({...})do M.know(s,unpack(set))end
 s.range[6603]=true;s.usable[14251]=false
 return f,s
end
local mid={5171,53,703,8676,1833,1943,1766,5277,8647}
local function first(f,s,id)return(M.first(f,s,id))end
local function stopped(f,s,id)local x,r=M.first(f,s,id);return x==nil and r.status=='stopped',r end
local function slice(expires)return{id=5171,expires=expires or 130}end

test('every premade registers valid 1–60; vanilla runs on every realm, SoD only on Season of Discovery',function()
 local f,s=rogue(1);local a=f.addon
 for _,id in ipairs({DPS,TAV,SIM,SOD,SIV,SZK,TANK})do local row=assert(M.row(f,id),id)
  assert(row.readOnly and row.validation.valid and row.validation.resolved and row.applicability.minLevel==1 and row.applicability.maxLevel==60,id)
  assert(a:GetDefaultRotationComposition(id),id..' is not composed')
 end
 for _,season in ipairs({false,3,11})do s.season=season or nil
  for _,id in ipairs(VANILLA)do assert(M.row(f,id).eligible,id)end
  for _,id in ipairs(SEASON)do assert(not M.row(f,id).eligible,id..' leaked onto a non-SoD realm')end
 end
 s.season=2;for _,id in ipairs({DPS,TAV,SIM,SOD,SIV,SZK})do assert(M.row(f,id).eligible,id)end
 for _,id in ipairs(SEASON)do local body=M.body(a,id);for _,v in ipairs(VANILLA)do assert(body.priority>M.body(a,v).priority,id..' must outrank '..v)end end
 for _,src in ipairs(a:GetDefaultRotation(TAV).envelope.sources)do assert(src.url:find('warcrafttavern'),src.url)end
 for _,src in ipairs(a:GetDefaultRotation(SZK).envelope.sources)do assert(src.url:find('zockify'),src.url)end
end)

test('auto-select: the recommended premade at every level and realm; variants when it is disabled',function()
 local f,s=rogue(1);local a=f.addon
 for _,level in ipairs({1,10,30,60})do s.level=level;a.longtermCache={};s.season=nil;assert(M.selected(f,s)==DPS,level)
  s.season=3;s.hardcore=true;assert(M.selected(f,s)==DPS,'Hardcore shares the vanilla premade');s.hardcore=false
  s.season=2;assert(M.selected(f,s)==SOD,'SoD at '..level)end
 M.know(s,410412);assert(M.selected(f,s)==SOD,'Tease known without the rune: still DPS');s.known[410412]=false
 M.engrave(s,400014);assert(M.selected(f,s)==TANK,'Just a Flesh Wound (a passive rune) engraved: tank');M.unengrave(s,400014)
assert(a:SetDefaultRotationEnabled(SOD,false));assert(M.selected(f,s)==SIV)
 assert(a:SetDefaultRotationEnabled(SIV,false));assert(M.selected(f,s)==SZK)
 s.season=nil;assert(a:SetDefaultRotationEnabled(DPS,false));assert(M.selected(f,s)==TAV)
 assert(a:SetDefaultRotationEnabled(TAV,false));assert(M.selected(f,s)==SIM)
end)

test('casts, channels and a missing target stop with Attack suppressed',function()
 for _,id in ipairs({DPS,TAV,SIM,SOD,TANK})do local f,s=rogue(20,mid)
  for _,key in ipairs({'cast','channel'})do s[key]=true;local ok,r=stopped(f,s,id);assert(ok and r.suppressAttack,id..' '..key);s[key]=false end
  s.dead=true;local ok,r=stopped(f,s,id);assert(ok and r.suppressAttack,id);s.dead=false;assert(first(f,s,id),id)
 end
end)

test('vanilla stealth opener adapts by spell known, group and raid, then stops without breaking Stealth',function()
 for _,id in ipairs(VANILLA)do
  local f,s=rogue(10);s.stealth=true;s.combat=false;assert(first(f,s,id)==1752,'nothing learned yet: Sinister Strike')
  M.know(s,703);assert(first(f,s,id)==703);s.instance='raid';assert(first(f,s,id)==1752,'no Garrote in raids');s.instance=nil
  M.know(s,1833);assert(first(f,s,id)==1833,'solo Cheap Shot');s.group=true;assert(first(f,s,id)==703,'group Garrote')
  M.know(s,8676);assert(first(f,s,id)==703,'Ambush needs the target not facing you');s.targettarget=nil;assert(first(f,s,id)==8676)
  s.gear[16]=M.GEAR.SWORD;assert(first(f,s,id)==703,'Ambush needs a dagger in the main hand');s.gear[16]=M.GEAR.DAGGER
  M.know(s,14183);assert(first(f,s,id)==14183,'Premeditation first');s.points=4;assert(first(f,s,id)==8676,'no Premeditation past three')
  for spell in pairs(s.known)do s.nopower[spell]=true end;local ok,r=stopped(f,s,id);assert(ok and r.suppressAttack)
 end
end)

test('Slice and Dice: recommended from one point on a target worth it, Warcraft Tavern only at five with rank 2',function()
 local f,s=rogue(30,mid);local g,t=rogue(30,mid)
 s.points,t.points=1,1;assert(first(f,s,DPS)==5171 and first(g,t,TAV)==1752)
 s.targetHealth=15;assert(first(f,s,DPS)==1752,'not on a nearly dead normal mob');s.classification='elite';assert(first(f,s,DPS)==5171)
 s.classification='normal';s.targetHealth=100;s.buffs={slice()};assert(first(f,s,DPS)==1752)
 s.points=5;assert(first(f,s,DPS)==2098);s.buffs[1].expires=102;assert(first(f,s,DPS)==5171,'renewed at five in its last three seconds')
 s.buffs[1].source='party1';s.buffs[1].expires=130;assert(first(f,s,DPS)==5171,'another rogue\'s Slice is not yours')
 t.points=5;assert(first(g,t,TAV)==2098,'Tavern: no Slice before rank 2');M.know(t,6774);assert(first(g,t,TAV)==6774)
 t.buffs={slice()};assert(first(g,t,TAV)==2098)
end)

test('five points: Eviscerate then pool without a builder; a two-point Eviscerate on a dying target is recommended only',function()
 local f,s=rogue(40,mid);local g,t=rogue(40,mid)
 for _,x in ipairs({s,t})do x.buffs={slice()};x.points=5;x.nopower[2098]=true end
 local ok,r=stopped(f,s,DPS);assert(ok and not r.suppressAttack,'pool: no builder at five, auto attack continues');ok=stopped(g,t,TAV);assert(ok)
 s.nopower[2098]=nil;t.nopower[2098]=nil;s.points,t.points=2,2;s.ttd,t.ttd=3,3;assert(first(f,s,DPS)==2098 and first(g,t,TAV)==1752)
 s.ttd=nil;assert(first(f,s,DPS)==1752,'no forecast: no early Eviscerate')
end)

test('Improved Expose Armor duty in a group on elites nobody Sunders; pooling while it lasts',function()
 local f,s=rogue(60,mid);s.group=true;s.classification='elite';s.points=5;s.buffs={slice()}
 assert(first(f,s,DPS)==2098,'no talent: no duty');s.talent['1:8']=1;assert(first(f,s,DPS)==2098,'needs 2/2');s.talent['1:8']=2
 assert(first(f,s,DPS)==8647);s.debuffs={{id=8647,expires=110}};assert(stopped(f,s,DPS),'pool for the next Expose Armor')
 s.debuffs[1].expires=101;assert(first(f,s,DPS)==8647);s.debuffs[1].expires=130;assert(first(f,s,DPS)==2098)
 s.debuffs={{id=7386,source='party1',stacks=5}};assert(first(f,s,DPS)==2098,'a warrior Sunders: no Expose Armor')
 s.debuffs={};s.group=false;assert(first(f,s,DPS)==2098,'solo: no duty')
 s.group=true;assert(first(f,s,TAV)==2098,'Warcraft Tavern never uses Expose Armor')
end)

test('builders follow what is known, the raid and whether the target faces you',function()
 for _,id in ipairs(VANILLA)do
  local f,s=rogue(50,mid);s.lastMainSwing=nil;f.addon.lastMainSwing=99.5
  assert(first(f,s,id)==1752,'targeted: Sinister Strike');s.targettarget='party1';assert(first(f,s,id)==53,'Backstab when not tanked')
  M.know(s,16511);assert(first(f,s,id)==16511);M.know(s,14278);assert(first(f,s,id)==14278)
  s.instance='raid';assert(first(f,s,id)==53,'no Ghostly Strike or Hemorrhage in raids')
  s.gear[16]=M.GEAR.SWORD;assert(first(f,s,id)==1752,'no dagger: Sinister Strike instead of Backstab');s.gear[16]=M.GEAR.DAGGER
  s.usable[14251]=true;M.know(s,14251);assert(first(f,s,id)==14251,'Riposte first')
 end
end)

test('wowsims swing sync: Sinister Strike right after a main-hand swing, near the energy cap or on a dying target',function()
 local f,s=rogue(60,mid);local a=f.addon;s.buffs={slice()};s.power=50
 a.lastMainSwing=99.8;assert(first(f,s,SIM)==1752);a.lastMainSwing=99;assert(first(f,s,SIM)==nil,'mid-swing: wait')
 assert(first(f,s,DPS)==1752,'the recommended premade does not wait')
 s.power=80;assert(first(f,s,SIM)==1752,'near the cap');s.power=50;s.ttd=4;assert(first(f,s,SIM)==1752,'dying target')
 s.ttd=nil;s.points=5;s.buffs={};s.targetHealth=10;assert(first(f,s,SIM)==nil,'Eviscerate waits for Slice, energy or a dying target')
 s.power=90;assert(first(f,s,SIM)==2098)
end)

test('reminders: poisons per weapon, Kick, Blade Flurry and Adrenaline Rush on elites or packs, Cold Blood, Evasion; optional ones off',function()
 local f,s=rogue(40,mid,{13877,13750,14177,1856,1776});local u=M.upkeep(f,s,DPS)
 assert(u['rogue-mainhand-poison']and not u['rogue-offhand-poison'],'no off-hand weapon, no off-hand poison')
 s.offSpeed=1.8;assert(not M.upkeep(f,s,DPS)['rogue-offhand-poison'],'an off-hand swing alone is not a weapon')
 s.gear[17]=M.GEAR.OFFHAND;assert(not M.upkeep(f,s,DPS)['rogue-offhand-poison'],'a held item takes no poison')
 s.gear[17]=M.GEAR.SWORD;assert(M.upkeep(f,s,DPS)['rogue-offhand-poison']);s.offEnchant=true;s.mainEnchant=563;u=M.upkeep(f,s,DPS)
 assert(not u['rogue-mainhand-poison']and not u['rogue-offhand-poison'],'a Windfury Totem enchant counts as an enchant')
 for _,step in ipairs(M.body(f.addon,DPS).cooldowns)do if step.id=='rogue-offhand-poison'then assert(step.action[1]==20844 and step.action[6]==8928)end end
 assert(not u['rogue-kick']);s.targetCast='Fireball';assert(M.upkeep(f,s,DPS)['rogue-kick']==1766);s.targetCast=nil
 assert(not u['rogue-blade-flurry']);s.buffs={slice()};assert(not M.upkeep(f,s,DPS)['rogue-blade-flurry'],'one normal enemy')
 s.enemies={0,1};u=M.upkeep(f,s,DPS);assert(u['rogue-blade-flurry']==13877 and u['rogue-adrenaline-rush']==13750)
 s.enemies={};s.classification='elite';assert(M.upkeep(f,s,DPS)['rogue-blade-flurry'])
 s.points=4;assert(not M.upkeep(f,s,DPS)['rogue-cold-blood']);s.points=5;assert(M.upkeep(f,s,DPS)['rogue-cold-blood']==14177)
 s.health=40;u=M.upkeep(f,s,DPS);assert(u['rogue-evasion']==5277 and not u['rogue-gouge'],'Gouge is listed off')
 s.group=true;s.targettarget='party1';s.threat=2;assert(not M.upkeep(f,s,DPS)['rogue-vanish'],'Vanish is listed off')
 s.items[7676]=1;s.power=20;s.points=3;assert(M.upkeep(f,s,DPS)['rogue-thistle-tea'])
end)

test('SoD: AoE first on three enemies, then the single-target list',function()
 local f,s=rogue(60,{5171,1766,399956,399963,436564,412096,409240,425012});s.season=2;s.buffs={slice()};s.targettarget='party1'
 s.enemies={0,0,0};assert(first(f,s,SOD)==436564,'Blunderbuss');s.nopower[436564]=true
 assert(first(f,s,SOD)==409240,'Crimson Tempest needs three points');s.points=3;assert(first(f,s,SOD)==412096)
 s.debuffs={{id=436611}};assert(first(f,s,SOD)==409240);s.enemies={0,0};s.points=1;assert(first(f,s,SOD)==399956,'two enemies: single target')
end)

test('SoD: Envenom at five once engraved, Eviscerate before; bleed choice follows the runes',function()
 local f,s=rogue(30,{5171,1943});s.season=2;s.buffs={slice()};s.points=5
 assert(first(f,s,SOD)==2098,'no Carnage engraved: no bleed, Eviscerate')
 M.engrave(s,432276);assert(first(f,s,SOD)==1943,'Carnage (a passive rune), no cloak rune, no Saber Slash: Rupture');s.debuffs={{id=1943}};assert(first(f,s,SOD)==2098,'Eviscerate until Envenom')
 M.know(s,399963);assert(first(f,s,SOD)==399963,'a known Envenom is cast');s.known[399963]=false
 M.engrave(s,399963);assert(first(f,s,SOD)==399963);s.debuffs={}
 M.engrave(s,412096);assert(first(f,s,SOD)==412096,'Crimson Tempest replaces Rupture');s.debuffs={{id=436611}};assert(first(f,s,SOD)==399963)
 M.unengrave(s,412096);M.engrave(s,424785);s.debuffs={{id=424785,stacks=3,expires=110}};assert(first(f,s,SOD)==399963,'Saber Slash bleed covers Carnage')
 s.nopower[399963]=true;assert(stopped(f,s,SOD),'pool at five')
end)

test('SoD: Poisoned Knife at four poison stacks, Saber Slash stacks, Slice from two points, builder by glove rune',function()
 local f,s=rogue(60,{5171,425012,399963});s.season=2;s.points=1;s.power=60
 assert(first(f,s,SOD)==1752,'one point and no rune: Sinister Strike');s.points=2;assert(first(f,s,SOD)==5171)
 s.buffs={slice(101)};s.points=4;assert(first(f,s,SOD)==5171,'renewed from four in its last two seconds')
 M.engrave(s,432271);assert(first(f,s,SOD)==1752,'Cut to the Chase (a passive rune): its finishers refresh Slice, no renewal');M.unengrave(s,432271);s.buffs={slice()}
 s.points=2;s.debuffs={{id=458820,stacks=4}};assert(first(f,s,SOD)==425012);s.debuffs[1].stacks=3;assert(first(f,s,SOD)==1752)
 s.debuffs={{id=2818,stacks=4,source='party1'}};assert(first(f,s,SOD)==1752,'another rogue\'s poison')
 s.debuffs={};M.know(s,399956);assert(first(f,s,SOD)==399956,'Mutilate');s.points=4;s.targettarget='party1';M.know(s,53);assert(first(f,s,SOD)==53,'Backstab for the fifth point')
 s.known[399956]=false;s.targettarget='player';assert(first(f,s,SOD)==1752,'faced without Cutthroat: Sinister Strike')
 M.engrave(s,462708);assert(first(f,s,SOD)==53,'Cutthroat (a passive rune) engraved: Backstab even when faced')
 s.gear[16]=M.GEAR.SWORD;assert(first(f,s,SOD)==1752,'Backstab needs a dagger');s.gear[16]=M.GEAR.DAGGER;M.know(s,424785);s.points=2;assert(first(f,s,SOD)==424785)
 s.debuffs={{id=424785,stacks=3,expires=130}};assert(first(f,s,SOD)==424785,'Saber Slash is also the builder')
 s.known[424785]=false;s.known[399963]=true;s.buffs[2]={id=462707};M.know(s,8676);assert(first(f,s,SOD)==8676,'Cutthroat Ambush')
 s.gear[16]=M.GEAR.SWORD;assert(first(f,s,SOD)~=8676,'Cutthroat Ambush needs a dagger');s.gear[16]=M.GEAR.DAGGER
end)

test('SoD variants: Icy Veins five-point Rupture and five poison stacks, Zockify without bleeds',function()
 local f,s=rogue(60,{5171,1943,399963,425012,412096});s.season=2;s.points=5;s.buffs={slice()}
 assert(first(f,s,SIV)==399963 and first(f,s,SOD)==399963,'no Carnage engraved: no bleed in either')
 M.engrave(s,432276);assert(first(f,s,SIV)==1943 and first(f,s,SZK)==399963 and first(f,s,SOD)==412096)
 s.points=3;s.debuffs={{id=458820,stacks=4}};assert(first(f,s,SIV)==1752 and first(f,s,SZK)==425012)
 s.debuffs[1].stacks=5;assert(first(f,s,SIV)==425012);s.buffs={};s.debuffs={};s.points=2;assert(first(f,s,SZK)==5171 and first(f,s,SIV)==1752)
 M.engrave(s,424785);assert(first(f,s,SZK)==424785,'Zockify Saber Slash builds Slice at four');s.points=4;assert(first(f,s,SZK)==5171)
end)

test('SoD stealth: Shadowstrike, group Garrote, Ambush only without a glove builder',function()
 local f,s=rogue(60,{703,8676,1833});s.season=2;s.stealth=true;s.combat=false;s.targettarget=nil
 assert(first(f,s,SOD)==8676);s.gear[16]=M.GEAR.SWORD;assert(first(f,s,SOD)==1833,'no dagger: no Ambush');s.gear[16]=M.GEAR.DAGGER;s.group=true;assert(first(f,s,SOD)==703);s.group=false;M.engrave(s,399956);assert(first(f,s,SOD)==1833,'Mutilate build: no Ambush')
 M.know(s,399985);assert(first(f,s,SOD)==399985);local ok,r=stopped(f,s,SIV);assert(not ok and r)
end)

test('SoD tank: Main Gauche, Blade Dance, Slice, Eviscerate with both up; Tease when the target is not on you',function()
 local f,s=rogue(60,{410412,424919,400012,5171,409240,436564,425012,5277});s.season=2;s.usable[14251]=false
 assert(first(f,s,TANK)==424919);s.nopower[424919]=true
 assert(first(f,s,TANK)==1752,'no points: builder');s.points=1;assert(first(f,s,TANK)==400012)
 s.buffs={{id=400012,expires=130}};s.points=3;assert(first(f,s,TANK)==5171);s.buffs[2]=slice()
 s.points=5;assert(first(f,s,TANK)==2098);s.buffs[1].expires=101;assert(first(f,s,TANK)==400012,'Blade Dance renewed first')
 s.buffs[1].expires=130;s.enemies={0,0,0};s.points=2;assert(first(f,s,TANK)==409240)
 s.enemies={};s.power=60;assert(first(f,s,TANK)==436564,'Blunderbuss while Blade Dance is up');s.nopower[436564]=true
 s.power=20;assert(first(f,s,TANK)==425012);s.power=100;M.know(s,424785);assert(first(f,s,TANK)==424785)
 local u=M.upkeep(f,s,TANK);assert(not u['rogue-tank-tease'],'solo: no Tease')
 s.group=true;s.targettarget='party1';u=M.upkeep(f,s,TANK);assert(u['rogue-tank-tease']==410412,'Tease: '..tostring(u['rogue-tank-tease']))
 s.health=40;assert(M.upkeep(f,s,TANK)['rogue-tank-evasion']==5277)
 s.offSpeed=1.6;assert(not M.upkeep(f,s,TANK)['rogue-tank-offhand-poison'],'an off-hand swing alone is not a weapon')
 s.gear[17]=M.GEAR.SWORD;assert(M.upkeep(f,s,TANK)['rogue-tank-offhand-poison'],'an off-hand weapon without poison')
 s.offEnchant=true;assert(not M.upkeep(f,s,TANK)['rogue-tank-offhand-poison'])
end)

test('SoD Master of Subtlety (a passive rune): Vanish and Preparation only once it is engraved',function()
 local f,s=rogue(60,{5171,1856,14185});s.season=2;s.group=true;s.targettarget='party1';s.points=5
 local u=M.upkeep(f,s,SOD);assert(not u['rogue-sod-vanish'],'no Master of Subtlety: no Vanish')
 M.engrave(s,425096);u=M.upkeep(f,s,SOD);assert(u['rogue-sod-vanish']==1856,'Master of Subtlety engraved: Vanish to renew it')
 s.buffs={{id=425096,expires=105}};assert(not M.upkeep(f,s,SOD)['rogue-sod-vanish'],'its buff is up');s.buffs={}
 s.cooldown[1856]={startTime=90,duration=300,isEnabled=true,modRate=1};assert(M.upkeep(f,s,SOD)['rogue-sod-preparation']==14185,'Preparation once Vanish is spent')
 M.unengrave(s,425096);assert(not M.upkeep(f,s,SOD)['rogue-sod-preparation'],'no Preparation without the rune')
end)

test('unavailable combo points halt with Attack suppressed rather than guessing a builder',function()
 local f,s=rogue(20,mid);local power=f.env.UnitPower;f.env.UnitPower=function(unit,kind)if kind==4 then error('unavailable')end;return power(unit,kind)end
 local x,r=M.first(f,s,DPS);assert(not x and r.status=='unavailable'and r.suppressAttack)
end)

test('real publisher highlights the selected premade and follows the realm season',function()
 local f,s=rogue(40,mid);local poll,selected,glow=M.publisher(f,s);s.buffs={slice()}
 poll();assert(selected()==DPS and f.addon.currentSpell==1752);s.points=5;poll();assert(f.addon.currentSpell==2098);assert(#glow>0)
 s.season=2;f.addon:InvalidateBuildContext('client');poll();assert(selected()==SOD,'SoD realm switches to the SoD premade')
end)
finish()
