-- Real pack/predicates/catalog/sequence/readiness/publication; modeled native
-- observations do not establish current-client acceptance or optimal priorities.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local SOURCE=arg[1]or'Defaults/tbc/warlock-30-39.lua'
local ID='rm.tbc.warlock.starter.30-39'
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function once(s,old,new)local a,b=assert(s:find(old,1,true));assert(not s:find(old,b+1,true));return s:sub(1,a-1)..new..s:sub(b+1)end
local nativePrefix=assert(read('tests/defaults_warlock.lua'):match('^(.-)\ntest%('))
nativePrefix=once(nativePrefix,"F.new(5,1,'WARLOCK')","F.new(PROJECT or 5,1,CLASS or 'WARLOCK')")
nativePrefix=once(nativePrefix,"'Defaults/tbc/warlock-starter.lua'",'SOURCE')
nativePrefix=once(nativePrefix,"f.load('Core/rotation_sequence.lua');f.load('main.lua')","f.libraries['LibClassicDurations'].Register=function()end;f.load('Core/rotation_sequence.lua');f.load('main.lua')")
local function fixture(project,class)
 local make=assert(loadstring('local SOURCE,PROJECT,CLASS=...\n'..nativePrefix..'\nreturn fixture','@warlock-thirties-native-fixture'))(SOURCE,project,class)
 local f,s,names=make();local a,e=f.addon,f.env;s.level=30;s.power={};s.metadataMissing={};s.casting=false
 f.translations['Default.TBC.Warlock.Thirties.Name']='TBC Warlock 30–39 single-target preview'
 f.translations['Default.TBC.Warlock.Thirties.Description']='Bounded Affliction-oriented preview with learned Siphon Life; proc priorities, talents, pets and resources remain manual.'
 local rankInfo={
  [706]={706,1},[1086]={706,2},[11733]={706,3},
  [1094]={348,3},[2941]={348,4},[11665]={348,5},
  [6223]={172,3},[7648]={172,4},[11671]={172,5},[6217]={980,3},[11711]={980,4},
  [699]={689,2},[709]={689,3},[7651]={689,4},[1106]={686,4},[7641]={686,5},[11659]={686,6},
  [18265]={18265,1},[18879]={18265,2}}
 local info=e.C_Spell.GetSpellInfo
 e.C_Spell.GetSpellInfo=function(id)
  if s.metadataMissing[id]then return end
  local rank=rankInfo[id];if rank then return{name=names[id],spellID=id,subtext='Rank '..rank[2]}end
  return info(id)
 end
 for id,rank in pairs(rankInfo)do names[id]=names[rank[1]]or('Localized family '..rank[1])end
 for id in pairs(rankInfo)do a.SpellCatalog:UpdateSpell(id)end
 local usable=e.C_Spell.IsSpellUsable;e.C_Spell.IsSpellUsable=function(id)if s.power[id]then return false,true end;return usable(id)end
 local hasRange=e.C_Spell.SpellHasRange;e.C_Spell.SpellHasRange=function(id)if id==706 or id==1086 or id==11733 then return false end;return hasRange(id)end
 e.UnitCastingInfo=function()if s.casting then return 'Manual cast','Manual cast',1,99000,102000,false,1,false,686 end end
 f.load('Conditions/casting.lua')
 return f,s,names
end
local function row(a)for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==ID then return r end end;error('missing Warlock30–39 manifest')end
local function body(a)return row(a).envelope.body end
local function first(a,s)
 local selected;local ready=a:NewActionReadiness(100)
 local result=a:EvaluateRotationSequence(body(a),function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
   if s.mapped[id]~=false and ready(step.type,id)then selected=id;return false end
  end end
 end)
 return selected,result
end
local function dots(s,names,includeSiphon,caster)
 s.debuffs={};for _,id in ipairs(includeSiphon and{2941,7648,11711,18879}or{2941,7648,11711})do s.debuffs[#s.debuffs+1]={spellId=id,name=names[id],sourceUnit=caster or'player'}end
end
local function optional(f,s)
 local a=f.addon;local ids,statuses={},{};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(body(a).cooldowns)do local result=a:evaluateConditionResult(step.conditions);statuses[step.id]=result.status
  if result.status=='match'then for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready('spell',id)then ids[#ids+1]=id;break end end end
 end
 return ids,statuses
end
local function nativePublish(f,s)
 local source=read('tests/defaults_warlock_armor.lua');local start=assert(source:find('local function nativePublish(f,s)',1,true));local stop=assert(source:find("\ntest('actual FindSpell",start,true))
 local code=source:sub(start,stop-1)
 code=once(code,'local actions={348,687,696,706,1086}','local actions={348,2941,172,7648,980,11711,18265,18879,689,709,7651,5019,686,7641,687,696,706,1086}')
 code=once(code,"e['ActionButton'..slot]=button","if slot<=12 then e['ActionButton'..slot]=button else e['MultiBarBottomLeftButton'..(slot-12)]=button end")
 code=once(code,"a.currentRotation=nil;a:Fetch()","a.ScheduleRepeatingTimer=function()return 'modeled-publisher-timer'end;a.CancelTimer=function()end;a.currentRotation=nil;a:Fetch()")
 return assert(loadstring('local row=...\n'..code..'\nreturn nativePublish','@warlock-thirties-publisher'))(row)(f,s)
end

test('new scope and learned Bolt executable switch agree at exact bracket boundaries',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({29,30,31,38,39,40})do s.level=level;a.longtermCache={};local want=level>=30 and level<40;assert(row(a).eligible==want);assert(a:evaluateCondition(body(a).switch)==want)end
 s.level=30;s.known[686]=false;a.longtermCache={};assert(not a:evaluateCondition(body(a).switch))
end)
test('other classes families vehicle and petbattle cannot run this player preview',function()
 for _,case in ipairs({{5,'MAGE'},{2,'WARLOCK'},{1,'WARLOCK'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);for _,r in ipairs(rows)do assert(not r.eligible)end end
 for _,mode in ipairs({'vehicle','petbattle'})do local f=fixture();if mode=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end;assert(not row(f.addon).eligible)end
end)
test('untrained Siphon never appears merely from level and existing missing DoT order remains',function()
 local f,s,n=fixture();local a=f.addon;s.level=39;s.known[172],s.known[980]=true,true
 assert(first(a,s)==348);s.debuffs={{spellId=2941,name=n[2941],sourceUnit='player'}};assert(first(a,s)==172)
 s.debuffs[#s.debuffs+1]={spellId=7648,name=n[7648],sourceUnit='player'};assert(first(a,s)==980);dots(s,n);assert(first(a,s)==686)
end)
test('learned Siphon follows Agony and remains available while moving without talent-level guesses',function()
 local f,s,n=fixture();s.known[172],s.known[980],s.known[18265]=true,true,true;assert(first(f.addon,s)==348)
 dots(s,n);assert(first(f.addon,s)==18265);s.moving=true;assert(first(f.addon,s)==18265)
 s.known[18265]=false;assert(not first(f.addon,s));s.known[18879]=true;assert(first(f.addon,s)==18879)
end)
test('own localized higher Siphon is maintained and another caster does not satisfy it',function()
 local f,s,n=fixture();s.known[18265]=true;dots(s,n,true);assert(first(f.addon,s)==686)
 s.debuffs[4].sourceUnit='party1';assert(first(f.addon,s)==18265)
 s.debuffs[4].sourceUnit='player';s.debuffs[4].name='Other name';assert(first(f.addon,s)==18265)
end)
test('native learned rank expansion selects reviewed thirty-level identities only when learned',function()
 local f,s,n=fixture();local a=f.addon;assert(first(a,s)==348);s.known[2941]=true;assert(first(a,s)==2941)
 dots(s,n);s.known[7641]=true;assert(first(a,s)==7641);s.mapped[7641]=false;assert(first(a,s)==686)
 s.mapped={};s.known[18265],s.known[18879]=true,true;assert(first(a,s)==18879);s.mapped[18879]=false;assert(first(a,s)==18265)
end)
test('Siphon refusal for mapping resources cooldown usability or range never invents a cast',function()
 for _,mode in ipairs({'mapping','power','cooldown','usability','range'})do local f,s,n=fixture();s.known[18265]=true;dots(s,n)
  if mode=='mapping'then s.mapped[18265]=false elseif mode=='power'then s.power[18265]=true elseif mode=='cooldown'then s.cooldown[18265]={startTime=99,duration=30,isEnabled=true,modRate=1}elseif mode=='usability'then s.usable[18265]=false else s.range[18265]=false end
  assert(first(f.addon,s)==686,mode)
 end
end)
test('unknown Siphon learning aura or family metadata never turns into absent and castable',function()
 local f,s,n=fixture();s.known[18265]=true;dots(s,n);s.auraError=true;assert(first(f.addon,s)==686)
 s.auraError=false;s.metadataMissing[18265]=true;assert(first(f.addon,s)==686)
 f,s,n=fixture();dots(s,n);local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==18265 or id==18879 then return nil end;return known(id)end;assert(first(f.addon,s)==686)
end)
test('channel Stop protects ongoing drains and unknown channel cannot authorize a replacement',function()
 local f,s,n=fixture();s.known[18265]=true;s.channel=true;local id,result=first(f.addon,s);assert(not id and result.status=='stopped'and result.suppressAttack)
 f.env.UnitChannelInfo=function()error('channel unavailable')end;id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
end)
test('health recovery and wand off-toggle retain original ordering after Siphon maintenance',function()
 local f,s,n=fixture();local a=f.addon;dots(s,n,true);s.known[18265],s.known[689],s.known[5019]=true,true,true;s.combat=true;s.health=69;s.repeatActive=true
 assert(first(a,s)==689);s.channel=true;assert(not first(a,s));s.channel=false;s.health=70;local id,r=first(a,s);assert(not id and r.status=='stopped'and r.suppressAttack)
 s.debuffs={};assert(first(a,s)==348)
end)
test('unknown wand blocks lower fillers but untrained wand permits ready Bolt',function()
 local f,s,n=fixture();dots(s,n,true);s.known[5019]=true;s.repeatError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.known[5019]=false;assert(first(f.addon,s)==686)
end)
test('target guards and exhausted ranged choices do not become a new melee or engaged pull',function()
 local f,s,n=fixture();local a=f.addon;s.targetCombat=true;assert(not first(a,s));s.combat=true;assert(first(a,s)==348)
 for _,key in ipairs({'hostile','exists'})do s[key]=false;assert(not first(a,s));s[key]=true end;s.dead=true;assert(not first(a,s));s.dead=false
 s.mapped[348],s.mapped[686]=false,false;local id,r=first(a,s);assert(not id and r.status=='stopped'and r.suppressAttack)
end)
test('Demon Armor higher rank supersedes Skin and unknown learning never permits downgrade',function()
 local f,s,n=fixture();local ids=optional(f,s);assert(#ids==1 and ids[1]==687)
 s.known[706],s.known[1086]=true,true;ids=optional(f,s);assert(#ids==1 and ids[1]==1086)
 s.buffs={{spellId=1086,name=n[1086],sourceUnit='player'}};assert(#optional(f,s)==0)
 s.buffs={};local known=f.env.IsSpellKnown;f.env.IsSpellKnown=function(id)if id==706 then return nil end;return known(id)end;local selected,status=optional(f,s);assert(#selected==0);for _,v in pairs(status)do assert(v=='unavailable')end
end)
test('learned preferred Armor unready or unmapped does not license Skin fallback',function()
 for _,mode in ipairs({'mapping','power','cooldown','usability'})do local f,s=fixture();s.known[706]=true
  if mode=='mapping'then s.mapped[706]=false elseif mode=='power'then s.power[706]=true elseif mode=='cooldown'then s.cooldown[706]={startTime=99,duration=30,isEnabled=true,modRate=1}else s.usable[706]=false end
  assert(#optional(f,s)==0,mode);assert(first(f.addon,s)==348)
 end
end)
test('initialized main publisher exposes learned Siphon rank and removes it when maintained',function()
 local f,s,n=fixture();s.known[18265],s.known[18879]=true,true;dots(s,n);local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==18879)
 local found=false;for _,v in ipairs(glow)do if v[1]==18879 then found=true end end;assert(found,'native Siphon highlight missing')
 dots(s,n,true);tick();assert(f.addon.currentSpell==686,'actual '..tostring(f.addon.currentSpell))
 s.channel=true;tick();assert(f.addon.currentSpell==nil)
end)
test('initialized publisher retains existing cast-time next-action policy and known Armor denial',function()
 local f,s,n=fixture();s.known[706]=true;s.mapped[706]=false;s.casting=true;local tick,glow= nativePublish(f,s);tick();assert(f.addon.currentSpell==348)
 assert(f.addon.avail_announced['warlock-thirties-skin']==nil and f.addon.avail_announced['warlock-thirties-armor']==nil)
 for _,v in ipairs(glow)do assert(v[2]~=687,'Skin licensed by unreadyArmor')end
 s.mapped[348],s.mapped[686]=false,false;f.addon:Fetch();tick();assert(f.addon.currentSpell==nil,'actual '..tostring(f.addon.currentSpell))
end)
test('old source and clones retain old cutoff and independent priorities',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/warlock-starter.lua');s.level=29;a.longtermCache={}
 local id=assert(a:CloneDefaultRotation(0,'rm.tbc.warlock.starter','Old source clone'));local clone=a:CopySettingsData(a:GetEditableRotation(0,id))
 s.level=30;a.longtermCache={};assert(not a:GetRuntimeRotation(0,id));assert(a:SettingsDataEqual(clone,a:GetEditableRotation(0,id)))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Thirties clone'));assert(a:GetRuntimeRotation(0,fresh));a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].suppress_attack=false;assert(body(a).rotation[1].onTrue[1].suppress_attack)
 assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
end)
finish()
