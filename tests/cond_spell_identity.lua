-- Locale-safe identity for casts, channels and forms: CASTING_SPELL and
-- CHANNELING_SPELL accept a spell ID (any rank unless `ranked`), FORM accepts
-- a form spell ID (`form`). Saved name and slot conditions keep their meaning.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local english={[15407]='Mind Flay',[17311]='Mind Flay',[10]='Blizzard',[71]='Defensive Stance',[2457]='Battle Stance',[2458]='Berserker Stance',
 [465]='Devotion Aura',[10293]='Devotion Aura',[7294]='Retribution Aura',[2645]='Ghost Wolf',[31801]='Seal of Truth',[20154]='Seal of Righteousness',[768]='Cat Form',[5487]='Bear Form',
 [105361]='Seal of Command',[115069]='Stance of the Sturdy Ox',[33891]='Tree of Life'}
local german={[15407]='Gedankenschinden',[17311]='Gedankenschinden',[10]='Blizzard',[71]='Verteidigungshaltung',[2457]='Kampfhaltung'}
local ranks={[15407]='Rank 1',[17311]='Rank 2',[465]='Rank 1',[10293]='Rank 7'}

local function fixture(project,class)
 local f=F.new(project or 2,nil,class or 'PRIEST');local a,e=f.addon,f.env
 local s={names=english,exists=true,cast=nil,castID=nil,channel=nil,channelID=nil,start=99000,ending=103000,now=100,flag=false,form=0,bar={},formID=nil,calls={}}
 local function call(key) s.calls[key]=(s.calls[key] or 0)+1;if s.throw==key then error('native '..key..' failed') end end
 e.UnitExists=function() call('exists');return s.exists end;e.GetTime=function() return s.now end
 e.UnitCastingInfo=function() call('cast');if s.cast==nil then return nil end;return s.cast,'display',1,s.start,s.ending,false,'cast-guid',s.flag,s.castID end
 e.UnitChannelInfo=function() call('channel');if s.channel==nil then return nil end;return s.channel,'display',1,s.start,s.ending,false,s.flag,s.channelID,false,0 end
 e.GetShapeshiftForm=function() call('form');return s.form end
 e.GetNumShapeshiftForms=function() return #s.bar end
 e.GetShapeshiftFormInfo=function(i) call('info');local id=s.bar[i];return 900+i,i==s.form,true,id end
 e.GetShapeshiftFormID=function() call('formID');return s.formID end
 e.C_Spell={GetSpellInfo=function(id) call('spell');local name=s.names[id];if s.restrictSpell then return s.opaque end;if not name then return nil end;return {name=name,iconID=1000+(tonumber(id) or 0),spellID=id,subtext=ranks[id]} end}
 e.GetSpellInfo=nil
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/spells.lua','Core/presentation.lua','Core/conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.opaque={};e.canaccessvalue=function(v) return not rawequal(v,s.opaque) end
 return f,a,s
end
local function status(a,v) return a:evaluateConditionResult(v).status end
local function expect(a,v,want,label)
 local got=status(a,v);assert(got==want,(label or v.type)..': expected '..want..' got '..got)
 local negated=status(a,{type='NOT',value=v})
 local flipped=want=='match' and 'no-match' or want=='no-match' and 'match' or 'unavailable'
 assert(negated==flipped,(label or v.type)..': NOT expected '..flipped..' got '..negated)
end
local function branch(a,v)
 local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 local chosen;local result=a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) chosen=n.id;return true end);return chosen,result
end

-- Platform --------------------------------------------------------------
test('cast observation reads the spell ID from slot 9 for casts and slot 8 for channels',function()
 local _,a,s=fixture();s.cast,s.castID,s.channel,s.channelID='Mind Flay',17311,'Blizzard',10
 local cast=a.Platform:GetUnitCastObservation('target','cast');local channel=a.Platform:GetUnitCastObservation('target','channel')
 assert(cast.spellID==17311 and not cast.spellReason and channel.spellID==10 and not channel.spellReason)
 s.castID=nil;cast=a.Platform:GetUnitCastObservation('target','cast');assert(cast.active and cast.spellID==nil and cast.spellReason=='cast-spell-unavailable')
 s.castID=s.opaque;cast=a.Platform:GetUnitCastObservation('target','cast');assert(cast.active and cast.name=='Mind Flay' and cast.spellReason=='restricted-value')
 for _,bad in ipairs({0,-1,1.5,'17311',math.huge,0/0,{}}) do s.castID=bad;cast=a.Platform:GetUnitCastObservation('target','cast');assert(cast.active and cast.spellID==nil and cast.spellReason=='invalid-api-result') end
end)
test('form spell observation: humanoid zero, stance-bar spell, Ghost Wolf by form ID, unreadable stays unavailable',function()
 local _,a,s=fixture(nil,'WARRIOR');s.bar={2457,71,2458}
 assert(a.Platform:GetPlayerFormSpellObservation()==0 and not s.calls.info)
 s.form=2;assert(a.Platform:GetPlayerFormSpellObservation()==71)
 s.bar={};s.form=1;s.formID=16;assert(a.Platform:GetPlayerFormSpellObservation()==2645)
 s.formID=nil;local v,why=a.Platform:GetPlayerFormSpellObservation();assert(v==nil and why=='form-identity-unavailable')
 s.bar={s.opaque};v,why=a.Platform:GetPlayerFormSpellObservation();assert(v==nil and why=='restricted-value')
 s.bar={2457};s.throw='info';v,why=a.Platform:GetPlayerFormSpellObservation();assert(v==nil and why=='api-error')
 s.throw=nil;s.form=s.opaque;v,why=a.Platform:GetPlayerFormSpellObservation();assert(v==nil and why=='restricted-value')
 s.form=.5;v,why=a.Platform:GetPlayerFormSpellObservation();assert(v==nil and why=='invalid-api-result')
end)
test('form spell candidates are gated by client family',function()
 local function ids(project,class) local _,a=fixture(project,class);return ','..table.concat(a.Platform:GetFormSpellCandidates(class),',')..',' end
 local era,mists=ids(2,'PALADIN'),ids(19,'PALADIN')
 assert(era:find(',465,',1,true) and not era:find(',31801,',1,true),'Era paladin auras are forms, seals are not')
 assert(mists:find(',31801,',1,true) and mists:find(',105361,',1,true) and not mists:find(',465,',1,true),'Mists seals are forms')
 assert(not mists:find(',20164,',1,true),'a spell this client lacks is not offered')
 assert(ids(5,'DRUID'):find(',33891,',1,true) and not ids(2,'DRUID'):find(',33891,',1,true),'Tree of Life is TBC+')
 assert(ids(19,'MONK'):find(',115069,',1,true) and ids(2,'MONK')==',,' and ids(1,'WARRIOR')==',,','no list where the family is unknown to the table')
end)

-- Casts and channels --------------------------------------------------------
test('saved name conditions keep matching by name, unchanged',function()
 local _,a,s=fixture();s.channel,s.channelID='Mind Flay',17311
 expect(a,{type='CHANNELING_SPELL',unit='target',spell='Mind Flay'},'match')
 expect(a,{type='CHANNELING_SPELL',unit='target',spell='Blizzard'},'no-match')
 s.channelID=s.opaque;expect(a,{type='CHANNELING_SPELL',unit='target',spell='Mind Flay'},'match','name match needs no spell ID')
 s.channel=nil;expect(a,{type='CHANNELING_SPELL',unit='target',spell='Mind Flay'},'no-match')
end)
test('a spell ID matches any rank by default and only that rank when ranked',function()
 for _,kind in ipairs({'cast','channel'}) do
  local tag=kind=='cast' and 'CASTING_SPELL' or 'CHANNELING_SPELL'
  local _,a,s=fixture();s[kind],s[kind..'ID']='Mind Flay',17311
  expect(a,{type=tag,unit='target',spell=17311},'match',tag..' exact')
  expect(a,{type=tag,unit='target',spell=15407},'match',tag..' other rank')
  expect(a,{type=tag,unit='target',spell=15407,ranked=true},'no-match',tag..' ranked other rank')
  expect(a,{type=tag,unit='target',spell=17311,ranked=true},'match',tag..' ranked same rank')
  expect(a,{type=tag,unit='target',spell=10},'no-match',tag..' other spell')
  s[kind]=nil;expect(a,{type=tag,unit='target',spell=17311},'no-match',tag..' idle')
  s.exists=false;expect(a,{type=tag,unit='target',spell=17311},'no-match',tag..' no unit')
 end
end)
test('spell IDs are locale-safe where saved English names are not',function()
 local _,a,s=fixture();s.names=german;s.channel,s.channelID='Gedankenschinden',15407
 expect(a,{type='CHANNELING_SPELL',unit='player',spell=15407},'match')
 expect(a,{type='CHANNELING_SPELL',unit='player',spell=17311},'match','other rank on a German client')
 expect(a,{type='CHANNELING_SPELL',unit='player',spell='Mind Flay'},'no-match','an English name cannot match a German client')
end)
test('unreadable identity is unavailable, never guessed, including under NOT and in branches',function()
 local _,a,s=fixture();s.channel,s.channelID='Mind Flay',s.opaque
 local v={type='CHANNELING_SPELL',unit='target',spell=15407,ranked=true}
 expect(a,v,'unavailable','restricted ID with exact rank');local chosen,result=branch(a,v);assert(chosen==nil and result.status=='unavailable')
 expect(a,{type='CHANNELING_SPELL',unit='target',spell=15407},'match','any rank still decides by the readable name')
 s.restrictSpell=true;expect(a,{type='CHANNELING_SPELL',unit='target',spell=10},'unavailable','configured spell name unreadable')
 local _,b,t=fixture();t.channel,t.channelID,t.names='Mind Flay',17311,{};expect(b,{type='CHANNELING_SPELL',unit='target',spell=15407},'unavailable','unknown configured spell')
 for _,project in ipairs({999}) do local _,b,t=fixture(project);t.cast,t.castID='Mind Flay',15407;expect(b,{type='CASTING_SPELL',unit='target',spell=15407},'unavailable','restricted client '..project);assert(not t.calls.cast) end
end)
test('one native read serves the spell, remaining-time and interrupt conditions in one evaluation',function()
 local _,a,s=fixture();s.channel,s.channelID='Mind Flay',17311;s.ending=100500
 local clip={type='AND',value={{type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_REMAIN',unit='player',operator='LESSTHAN',value=1}}}
 assert(status(a,clip)=='match' and s.calls.channel==1,'clip test read the channel more than once')
 s.ending=102000;assert(status(a,clip)=='no-match')
end)
test('validation accepts names and positive integer IDs only',function()
 local _,a=fixture();local d=a.conditionDefinitions.CASTING_SPELL
 assert(d.valid(0,{unit='target',spell='Mind Flay'}) and d.valid(0,{unit='target',spell=15407}) and d.valid(0,{unit='target',spell=15407,ranked=true}))
 for _,bad in ipairs({0,-1,1.5,math.huge,0/0}) do assert(not d.valid(0,{unit='target',spell=bad})) end
 assert(not d.valid(0,{unit='target'}) and not d.valid(0,{unit='nowhere',spell=1}))
end)
test('summaries name the spell, with the rank only when ranked',function()
 local _,a=fixture();a.Platform.GetSpellLink=function() return nil end
 a.SpellCatalog={SpellRank=function(_,id) return ranks[id] end}
 local any=a:printCondition({type='CHANNELING_SPELL',unit='player',spell=15407},7)
 local exact=a:printCondition({type='CHANNELING_SPELL',unit='player',spell=15407,ranked=true},7)
 assert(any:find('Mind Flay',1,true) and not any:find('Rank',1,true),any)
 assert(exact:find('Mind Flay',1,true) and exact:find('Rank 1',1,true),exact)
 assert(a:printCondition({type='CHANNELING_SPELL',unit='player',spell='Mind Flay'},7):find('Mind Flay',1,true))
end)
test('rank checkbox round trip, absent on Retail',function()
 local f,a=fixture();f.load('Conditions/common.lua');local v={spell=15407};local updates=0
 local box=assert(a:Widget_SpellRankWidget(v,function() updates=updates+1 end))
 box:Fire('OnValueChanged',true);assert(v.ranked==true and updates==1)
 box:Fire('OnValueChanged',false);assert(v.ranked==nil and updates==2)
 local g,b=fixture(1);g.load('Conditions/common.lua');assert(b:Widget_SpellRankWidget({},function() end)==nil)
end)
test('compiled copies of the built-in sources evaluate the same',function()
 local _,a,s=fixture(nil,'WARRIOR');s.channel,s.channelID='Mind Flay',17311;s.bar={2457,71};s.form=2
 for _,tag in ipairs({'CHANNELING_SPELL','CASTING_SPELL','FORM'}) do a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag))))) end
 for _,v in ipairs({{type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_SPELL',unit='player',spell=15407,ranked=true},{type='CASTING_SPELL',unit='player',spell=15407},{type='FORM',form=71},{type='FORM',form=2457},{type='FORM',value=2}}) do
  local copy={};for k,x in pairs(v) do copy[k]=x end;copy.type='COPY_'..v.type
  assert(status(a,v)==status(a,copy),v.type..' copy diverged');assert(a.conditionDefinitions[v.type].valid(0,v)==a.conditionDefinitions[copy.type].valid(0,copy))
 end
end)

-- Forms --------------------------------------------------------------------
test('FORM by spell matches the active form wherever it sits on the stance bar',function()
 local _,a,s=fixture(nil,'WARRIOR');s.bar={2457,71,2458};s.form=2
 expect(a,{type='FORM',form=71},'match');expect(a,{type='FORM',form=2457},'no-match')
 s.bar={71,2458};s.form=1;expect(a,{type='FORM',form=71},'match','same form after the bar shifted')
 expect(a,{type='FORM',value=2},'no-match','a saved slot keeps its slot meaning');expect(a,{type='FORM',value=1},'match')
 s.form=0;expect(a,{type='FORM',form=71},'no-match','humanoid is in no form');expect(a,{type='FORM',value=0},'match')
end)
test('FORM by spell matches any rank of the form and Ghost Wolf without a stance bar',function()
 local _,a,s=fixture(nil,'PALADIN');s.bar={10293,7294};s.form=1
 expect(a,{type='FORM',form=465},'match','Devotion Aura rank 7 is Devotion Aura');expect(a,{type='FORM',form=7294},'no-match')
 local _,b,t=fixture(nil,'SHAMAN');t.form=1;t.formID=16;expect(b,{type='FORM',form=2645},'match')
end)
test('FORM by spell is locale-safe and unavailable where the form cannot be read',function()
 local _,a,s=fixture(nil,'WARRIOR');s.names=german;s.bar={2457,71};s.form=2;expect(a,{type='FORM',form=71},'match')
 s.bar={s.opaque,s.opaque};expect(a,{type='FORM',form=71},'unavailable','restricted form spell')
 s.bar={2457,71};s.form=s.opaque;expect(a,{type='FORM',form=71},'unavailable','restricted form index')
 s.form=2;s.throw='info';expect(a,{type='FORM',form=71},'unavailable','native failure')
 s.throw=nil;s.form=1;s.bar={};s.formID=nil;expect(a,{type='FORM',form=71},'unavailable','no identity')
 for _,project in ipairs({999}) do local _,b,t=fixture(project,'WARRIOR');t.bar={71};t.form=1;expect(b,{type='FORM',form=71},'unavailable','restricted client '..project);assert(not t.calls.form) end
 local _,c,u=fixture(nil,'WARRIOR');u.bar={2457};u.form=1;local cache={}
 local eval=c.conditionDefinitions.FORM.evaluate;assert(eval({form=2457},cache)==true and eval({form=71},cache)==false and u.calls.form==1 and u.calls.info==1,'form spell read once per evaluation')
end)
test('FORM validation: a form spell needs no class or stance count, a slot keeps its old bound',function()
 local f,a=fixture(nil,'DRUID');f.env.GetNumShapeshiftForms=function() error('form spell validation counted forms') end
 local d=a.conditionDefinitions.FORM;assert(d.valid(0,{form=768}) and d.valid(0,{form=768,value=9}))
 for _,bad in ipairs({0,-5,1.5,math.huge,0/0,'768'}) do assert(not d.valid(0,{form=bad})) end
 f.env.GetNumShapeshiftForms=function() return 2 end;assert(d.valid(0,{value=2}) and not d.valid(0,{value=3}))
end)

-- FORM editor ----------------------------------------------------------------
local function mount(a,value)
 local definition=a.conditionDefinitions.FORM;local parent=a:CreateConditionGroup();parent:SetWidth(640);local state={prints=0};local top={};local funcs={}
 function top:GetUserData(key) if key=='root' then return value elseif key=='funcs' then return funcs end end
 function funcs:print(root,spec) state.prints=state.prints+1;return definition.print(spec,value) end
 function top:SetStatusText(text) state.status=text end
 parent:SetUserData('top',top);definition.widget(parent,7,value);a:configure_frame(parent);parent:DoLayout()
 return parent.children[1],parent.children[2],parent,state
end
local function choose(dropdown,key)
 dropdown.button:Click();for _,row in ipairs(dropdown.selector.rows) do if row.menuEntry and row.menuEntry.value==key then row:Click();return end end;error('form choice missing '..key)
end
test('editor lists humanoid, stance-bar forms, then class forms, and stores the picked spell',function()
 local _,a,s=fixture(2,'PALADIN');s.bar={10293};local v={type='FORM'};local icon,dropdown,parent,state=mount(a,v)
 local order=table.concat(dropdown.order,',');assert(order:sub(1,15)=='0,spell:10293,s','stance bar first: '..order)
 assert(dropdown.list['spell:10293']=='Devotion Aura' and dropdown.list['spell:465']==nil,'rank 1 of a listed form is not repeated')
 assert(dropdown.list['spell:7294']=='Retribution Aura' and dropdown.list['spell:31801']==nil,'Era lists auras, not Mists seals')
 choose(dropdown,'spell:7294');assert(v.form==7294 and v.value==nil and state.status:find('Retribution Aura',1,true) and icon.image:GetTexture()==8294)
 choose(dropdown,'0');assert(v.form==nil and v.value==0 and state.status:find('humanoid',1,true));parent:Release()
end)
test('editor keeps a saved slot selectable and shows a saved spell it does not list',function()
 local _,a,s=fixture(2,'WARRIOR');s.bar={2457,71};local v={type='FORM',value=2};local _,dropdown,parent=mount(a,v)
 assert(dropdown:GetValue()=='2' and dropdown.list['2']=='Stance bar slot 2 (Defensive Stance)');choose(dropdown,'spell:71');assert(v.form==71 and v.value==nil);parent:Release()
 local w={type='FORM',form=99999};local _,d,p=mount(a,w);assert(d:GetValue()=='spell:99999' and d.list['spell:99999']:find('99999',1,true));p:Release()
end)
-- Cast and channel progress -------------------------------------------------
test('cast observation carries the full duration from start and end, with independent reasons',function()
 local _,a,s=fixture();s.channel='Mind Flay';s.start,s.ending=99000,102000
 local r=a.Platform:GetUnitCastObservation('player','channel');assert(r.durationSeconds==3 and r.remainingSeconds==2 and not r.durationReason)
 s.start=s.opaque;r=a.Platform:GetUnitCastObservation('player','channel');assert(r.active and r.durationSeconds==nil and r.durationReason=='restricted-value' and r.remainingSeconds==2)
 s.start=nil;r=a.Platform:GetUnitCastObservation('player','channel');assert(r.durationReason=='cast-time-unavailable')
 for _,bad in ipairs({102000,103000,-1,'99000',0/0,math.huge}) do s.start=bad;r=a.Platform:GetUnitCastObservation('player','channel');assert(r.durationReason=='invalid-api-result',tostring(bad)) end
end)
test('channel progress is the share done, so a tick threshold N/K holds at any haste',function()
 local _,a,s=fixture();s.channel,s.channelID='Mind Flay',15407
 local function at(start,ending,now) s.start,s.ending,s.now=start,ending,now end
 local secondTick={type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=0.66}
 at(99000,102000,100);expect(a,secondTick,'no-match','after one tick of three')
 at(99000,102000,101.05);expect(a,secondTick,'match','after two ticks of three')
 at(99000,101400,100.2);expect(a,secondTick,'no-match','hasted, after one tick')
 at(99000,101400,100.65);expect(a,secondTick,'match','hasted, after two ticks')
 at(99000,102000,103);expect(a,{type='CHANNELING_PROGRESS',unit='player',operator='EQUALS',value=1},'match','ended channel is all done')
 at(99500,102000,99);expect(a,{type='CHANNELING_PROGRESS',unit='player',operator='EQUALS',value=0},'match','clock before start clamps to none done')
 s.channel=nil;expect(a,secondTick,'no-match','not channeling')
end)
test('cast progress is the casting counterpart on the same observation',function()
 local _,a,s=fixture();s.cast,s.castID='Frostbolt',116;s.start,s.ending,s.now=99000,101500,100.5
 expect(a,{type='CASTING_PROGRESS',unit='target',operator='GREATERTHAN',value=0.5},'match')
 expect(a,{type='CASTING_PROGRESS',unit='target',operator='GREATERTHAN',value=0.7},'no-match')
 expect(a,{type='CHANNELING_PROGRESS',unit='target',operator='GREATERTHAN',value=0},'no-match','a cast is not a channel')
end)
test('progress is unavailable when the times cannot be read, including under NOT and in branches',function()
 for _,field in ipairs({'start','ending'}) do local _,a,s=fixture();s.channel='Mind Flay';s[field]=s.opaque
  local v={type='CHANNELING_PROGRESS',unit='player',operator='LESSTHAN',value=0.5};expect(a,v,'unavailable',field)
  local chosen,result=branch(a,v);assert(chosen==nil and result.status=='unavailable')
 end
 for _,project in ipairs({999}) do local _,b,t=fixture(project);t.channel='Mind Flay';expect(b,{type='CHANNELING_PROGRESS',unit='player',operator='LESSTHAN',value=0.5},'unavailable','restricted client '..project);assert(not t.calls.channel) end
end)
test('clip after the second tick reads the channel once',function()
 local _,a,s=fixture();s.channel,s.channelID='Mind Flay',17311;s.start,s.ending,s.now=99000,102000,101.1
 local clip={type='AND',value={{type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=0.66}}}
 assert(status(a,clip)=='match' and s.calls.channel==1)
end)
test('progress validation, summaries and compiled copies',function()
 local _,a,s=fixture();s.channel='Mind Flay';s.start,s.ending,s.now=99000,102000,101.1
 for _,tag in ipairs({'CASTING_PROGRESS','CHANNELING_PROGRESS'}) do local d=a.conditionDefinitions[tag]
  assert(d.valid(0,{unit='player',operator='LESSTHAN',value=0}) and d.valid(0,{unit='target',operator='GREATERTHAN',value=1}))
  assert(not d.valid(0,{unit='player',operator='LESSTHAN',value=1.5}) and not d.valid(0,{unit='player',operator='LESSTHAN',value=-0.1}) and not d.valid(0,{unit='player',operator='NOPE',value=.5}) and not d.valid(0,{unit='player',operator='LESSTHAN'}))
  a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,assert(a:GetBuiltinConditionSource(tag)))))
  local v={type=tag,unit='player',operator='GREATERTHANOREQUALS',value=.66};assert(status(a,v)==status(a,{type='COPY_'..tag,unit='player',operator='GREATERTHANOREQUALS',value=.66}))
 end
 local text=a:printCondition({type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=.66},7);assert(text:find('channel progress',1,true) and text:find('66%',1,true),text)
end)
test('existing profiles receive the progress conditions once, removals stay, defaults list them',function()
 local _,a=fixture();local combat={id='b3d7df2c-f257-4a2d-961e-66e49336d109',conditions={'CASTING'}};local db={profile={condition_groups={{id='other',conditions={}},combat}}}
 a:InitializeCastProgressConditions(nil,db);assert(db.profile.castProgressConditionsSeeded and table.concat(combat.conditions,',')=='CASTING,CASTING_PROGRESS,CHANNELING_PROGRESS' and #db.profile.condition_groups[1].conditions==0)
 table.remove(combat.conditions);a:InitializeCastProgressConditions(nil,db);assert(#combat.conditions==2,'a removed seed came back')
 local malformed={profile={}};a:InitializeCastProgressConditions(nil,malformed);assert(malformed.profile.castProgressConditionsSeeded)
 local f2,b=fixture();f2.load('Core/profile_data.lua');assert(b:ValidateProfileTransfer({castProgressConditionsSeeded=true}) and not b:ValidateProfileTransfer({castProgressConditionsSeeded='yes'}))
 local h=assert(io.open('init.lua'));local init=h:read('*a');h:close()
 assert(init:find('"CASTING_REMAIN", "CASTING_PROGRESS"',1,true) and init:find('"CHANNELING_REMAIN", "CHANNELING_PROGRESS"',1,true) and init:find('InstallCastProgressConditions',1,true))
end)
finish()
