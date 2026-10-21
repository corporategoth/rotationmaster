-- Run from repository root. Actual main/coordinator with native calls doubled.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local fixture=read('tests/fixtures/rotation_execution.lua')
local old="local startup=read('tests/startup.lua')"
local new="local startup=read('tests/startup.lua');local n;startup,n=startup:gsub(\"load%('Core/itemset_services.lua'%)%;load%('Core/conditions.lua'%)\",\"load('Core/itemset_services.lua');load('Platform/unit_presence.lua');load('Core/conditions.lua')\",1);assert(n==1)"
local a,b=assert(fixture:find(old,1,true));fixture=fixture:sub(1,a-1)..new..fixture:sub(b+1)
-- Historical precompute only; actual module execution remains loadfile(candidate).
local seam="local text=dofile('tests/fixtures/parser_string_history.lua')(read(path),path)"
local replace="local text=read(path);if path=='main.lua'and text:find('-- BEGIN SWITCH UNIT HANDOFF',1,true)then text=dofile('tests/fixtures/restore_switch_required_units.lua')(text,path)end;text=dofile('tests/fixtures/parser_string_history.lua')(text,path)"
a,b=assert(fixture:find(seam,1,true));fixture=fixture:sub(1,a-1)..replace..fixture:sub(b+1)
local make=assert(loadstring(fixture,'@switch-actual-fixture'))()
local function setup()
 local c=make({target=false,buttons=true});local a,e=c.a,c.e
 e.GetBuildInfo=function()return '2.5.6','12345','date',20506 end
 c.load('Platform/unit_level.lua');c.load('Core/level_conditions.lua');c.load('Platform/groups.lua');c.load('Platform/pet.lua');c.load('Core/rotation_selection.lua')
 e.UnitInParty=function()return false end;e.UnitInRaid=function()return nil end
 local id=a.currentRotation;local coordinator=a:GetScopedRotationCoordinator();local key=assert(coordinator:Key(assert(coordinator:Resolve(0,id))));local body=assert(a:GetEditableRotation(0,id))
 c.run=function(tree)
  body.switch=tree;a.manualRotation=false;a.db.profile.disable_autoswitch=false
  a:UpdateAutoSwitch();a.autoswitchRotation={key};a.currentRotation=nil;if c.beforeSwitch then c.beforeSwitch()end;a:SwitchRotation();assert(not a.adviceErrorReport)
  return a.currentRotation==key
 end
 return c
end
local function neg(v)return{type='NOT',value=v}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function known()return{type='SPELL_KNOWN',spell=403}end
local function countPresence(c,fn)
 local native=c.a.Platform.GetUnitPresenceObservation;local n=0
 debug.sethook(function(event)if event=='call'and debug.getinfo(2,'f').func==native then n=n+1 end end,'c')
 local ok,result=pcall(fn);debug.sethook();assert(ok,result);return n,result
end
for _,unit in ipairs({'target','focus','pet'})do
 test('actual Switch rejects reached missing '..unit..' through AND/NOT/GROUP',function()
  local c=setup();assert(c.e.UnitExists(unit)==false)
  for _,tree in ipairs({all(known(),neg({type='ENEMY',unit=unit})),neg({type='ENEMY',unit=unit}),neg({type='GROUP',unit=unit}),all(known(),{type='ENEMY',unit=unit})})do assert(not c.run(tree),'missing unit selected whole candidate')end
  assert(c.a:evaluateCondition(neg({type='ENEMY',unit=unit}))==true,'ordinary condition semantics changed')
 end)
end
test('reached missing first OR branch stops entire candidate and callback trace',function()
 local c=setup();local calls=0;c.a:RegisterCondition('AFTER',{fields={},valid=function()return true end,evaluate=function()calls=calls+1;return true end,print=function()return'after'end})
 assert(not c.run(any(neg({type='ENEMY',unit='focus'}),{type='AFTER'})));assert(calls==0,'callback ran after fatal missing unit')
end)
test('already true OR branch leaves later units unvisited',function()
 local c=setup();local n,selected=countPresence(c,function()return c.run(any(known(),{type='ENEMY',unit='focus'}))end)
 assert(selected and n==0)
end)
test('disabled unit leaf and explicit NOT HavePet remain legitimate',function()
 local c=setup();local n,selected=countPresence(c,function()return c.run(all(known(),{type='ENEMY',unit='focus',disabled=true}))end);assert(selected and n==0)
 n,selected=countPresence(c,function()return c.run(neg({type='PET'}))end);assert(selected and n==0)
end)
test('player-only trees add no presence probes',function()
 local c=setup();local n,selected=countPresence(c,function()return c.run(all(known(),neg({type='COMBAT',unit='player'})))end);assert(selected and n==0)
end)
test('presence stays fresh across reached callbacks and next switch',function()
 local c=setup();local native=c.e.UnitExists;c.e.UnitExists=function(u)return u=='focus'or native(u)end
 local tree=all(neg({type='ENEMY',unit='focus'}),neg({type='COMBAT',unit='focus'}))
 local n,selected=countPresence(c,function()return c.run(tree)end);assert(selected and n>=4,'presence not rechecked around callbacks')
 n,selected=countPresence(c,function()return c.run(tree)end);assert(selected and n>=4,'presence not fresh in next switch')
end)
test('opaque missing throwing and malformed presence never invert into switch match',function()
 for _,value in ipairs({'missing','throw','nil','number','restricted'})do
  local c=setup()
  if value=='missing'then c.a.Platform.GetUnitPresenceObservation=nil
  elseif value=='throw'then c.a.Platform.GetUnitPresenceObservation=function()error({})end
  elseif value=='nil'then c.a.Platform.GetUnitPresenceObservation=function()return nil,'unknown'end
  elseif value=='number'then c.a.Platform.GetUnitPresenceObservation=function()return 1 end
  else local opaque={};c.a.Platform.GetUnitPresenceObservation=function()return opaque end;local read=c.a.Platform.CanReadValue;c.a.Platform.CanReadValue=function(self,v)if v==opaque then return false end;return read(self,v)end end
  assert(not c.run(neg({type='ENEMY',unit='focus'})),value)
 end
end)
test('custom declared unit provider is fresh per reached leaf; undeclared fields unaffected',function()
 local c=setup();local n=0;c.a.Platform.GetUnitPresenceObservation=function(_,unit)assert(unit=='focus');n=n+1;return n<=3 end
 c.a:RegisterCondition('CUSTOM_UNIT',{fields={unit='string'},valid=function()return true end,evaluate=function()return true end,print=function()return'custom'end})
 assert(not c.run(all({type='CUSTOM_UNIT',unit='focus'},{type='CUSTOM_UNIT',unit='focus'}))and n>=4)
 c.a:RegisterCondition('CUSTOM_OTHER',{fields={unit='number'},valid=function()return true end,evaluate=function()return true end,print=function()return'other'end})
 local before=n;assert(c.run({type='CUSTOM_OTHER',unit=5})and n==before)
end)
test('native provider replacement during callback retires positive witness',function()
 local c=setup();local native=c.e.UnitExists;c.e.UnitExists=function(u)return u=='focus'or native(u)end
 c.a:RegisterCondition('REPLACE',{fields={unit='string'},valid=function()return true end,evaluate=function()c.e.UnitExists=function()return false end;return true end,print=function()return'change'end})
 assert(not c.run({type='REPLACE',unit='focus'}))
end)
test('unit mutation during valid callback cannot consume old presence',function()
 local c=setup();c.a.Platform.GetUnitPresenceObservation=function()return true end;local armed=false;c.beforeSwitch=function()armed=true end
 c.a:RegisterCondition('MUTATE',{fields={unit='string'},valid=function(_,v)if armed then v.unit='pet'end;return true end,evaluate=function()return true end,print=function()return'mutate'end})
 assert(not c.run({type='MUTATE',unit='focus'}))
end)
test('public evaluator overrides keep original receiver and one argument',function()
 local c=setup();local n=0;c.a.evaluateCondition=function(self,tree,...)assert(self==c.a and select('#',...)==0);n=n+1;return true end
 assert(c.run({type='ENEMY',unit='focus'})and n==1)
end)
test('player unit mutation after validation cannot bypass presence without a probe',function()
 local c=setup();local armed=false;c.beforeSwitch=function()armed=true end
 c.a:RegisterCondition('PLAYER_MUTATE',{fields={unit='string'},valid=function(_,v)if armed then v.unit='focus'end;return true end,evaluate=function()return true end,print=function()return'player'end})
 local n,selected=countPresence(c,function()return c.run({type='PLAYER_MUTATE',unit='player'})end);assert(not selected and n==0)
end)
test('profile replacement during presence query cannot publish old selection',function()
 local c=setup();c.a.Platform.GetUnitPresenceObservation=function()c.a.db.profile={};return true end
 assert(not c.run(neg({type='ENEMY',unit='focus'})))
end)
test('public result override retains its original nil context tuple',function()
 local c=setup();local n=0;c.a.evaluateConditionResult=function(self,tree,...)assert(self==c.a and select('#',...)==1 and (...)==nil);n=n+1;return{status='match'}end
 assert(c.run({type='ENEMY',unit='focus'})and n==1)
end)
test('same native API clearing the unit during callbacks retires selection',function()
 for _,stage in ipairs({'valid','evaluate'})do
  local c=setup();local present=true;local armed=false;c.beforeSwitch=function()armed=true end;local native=c.e.UnitExists
  c.e.UnitExists=function(u)if u=='focus'then return present end;return native(u)end
  c.a:RegisterCondition('GONE',{fields={unit='string'},valid=function()if armed and stage=='valid'then present=false end;return true end,evaluate=function()if stage=='evaluate'then present=false end;return true end,print=function()return'gone'end})
  assert(not c.run({type='GONE',unit='focus'}),stage..' retained stale positive presence')
 end
end)
test('strict complete inverse preserves both predecessor modules and rejects unrelated edits',function()
 local inverse=dofile('tests/fixtures/restore_switch_required_units.lua')
 for _,path in ipairs({'Core/conditions.lua','main.lua'})do
  local text=read(path);local previous=inverse(text,path);assert(previous~=text and inverse(previous,path)==previous)
  assert(not pcall(inverse,text..'\n-- unrelated mutation',path));if path=='Core/conditions.lua'then assert(not pcall(inverse,text:gsub('switch%-unit%-unavailable','other-unit-reason',1),path))end
 end
end)
test('presence retirement prevents all old-owner valid and evaluate callbacks',function()
 local c=setup();local calls=0;local armed=false;c.beforeSwitch=function()armed=true end
 c.a:RegisterCondition('OLDOWNER',{fields={unit='string'},valid=function()if armed then calls=calls+1 end;return true end,evaluate=function()calls=calls+1;return true end,print=function()return'old'end})
 c.a.Platform.GetUnitPresenceObservation=function()c.a.db.profile={};return true end
 assert(not c.run({type='OLDOWNER',unit='focus'}));assert(calls==0,'retired owner callbacks executed')
end)
test('retired presence owner stops before the next candidate callback',function()
 local c=setup();local retired=false;local late=0
 c.beforeSwitch=function()c.a.autoswitchRotation[2]=c.a.autoswitchRotation[1]end
 c.a.IsDefaultRuntimeRotation=function()if retired then late=late+1 end;return false end
 c.a.Platform.GetUnitPresenceObservation=function()retired=true;c.a.db.profile={};return true end
 assert(not c.run({type='ENEMY',unit='focus'}));assert(late==0,'next candidate callback ran after retirement')
end)
test('readability lookup retirement stops before invoking the returned method',function()
 local c=setup();local late=0;local retired=false;local platform=c.a.Platform;local read=platform.CanReadValue;local meta=getmetatable(platform)
 platform.GetUnitPresenceObservation=function()
  platform.CanReadValue=nil;setmetatable(platform,{__index=function(_,key)if key=='CanReadValue'then retired=true;c.a.db.profile={};return function(self,v)if retired then late=late+1 end;return read(self,v)end end;if meta and type(meta.__index)=='function'then return meta.__index(platform,key)end end});return true
 end
 assert(not c.run({type='ENEMY',unit='focus'}));assert(late==0,'readability callback after getter retirement')
end)
test('presence method identity getter retiring the owner cannot invoke returned old method',function()
 local c=setup();local a=c.a;local platform=a.Platform;local lookups,late=0,0;local retired=false
 local method=function()if retired then late=late+1 end;return true end
 c.beforeSwitch=function()
  platform.GetUnitPresenceObservation=nil;local old=getmetatable(platform)
  setmetatable(platform,{__index=function(self,key)
   if key=='GetUnitPresenceObservation'then
    lookups=lookups+1;if lookups==2 then retired=true;a.db.profile={}end
    return method
   end
   if old and type(old.__index)=='function'then return old.__index(self,key)end
   if old and type(old.__index)=='table'then return old.__index[key]end
  end})
 end
 assert(not c.run({type='ENEMY',unit='focus'}))
 assert(retired and lookups>=2,'getter control did not retire');assert(late==0,'old presence callback invoked after getter retirement')
end)

test('final presence identity getter retiring the owner cannot invoke old condition evaluate',function()
 local c=setup();local a=c.a;local platform=a.Platform;local lookups,late=0,0;local retired=false;local evaluations=0
 local method=function()if retired then late=late+1 end;return true end
 c.beforeSwitch=function()
  platform.GetUnitPresenceObservation=nil;local old=getmetatable(platform)
  setmetatable(platform,{__index=function(self,key)
   if key=='GetUnitPresenceObservation'then
    lookups=lookups+1;if lookups==5 then retired=true;a.db.profile={}end
    return method
   end
   if old and type(old.__index)=='function'then return old.__index(self,key)end
   if old and type(old.__index)=='table'then return old.__index[key]end
  end})
 end
 a:RegisterCondition('LATE_WITNESS',{fields={unit='string'},valid=function()return true end,evaluate=function()evaluations=evaluations+1;return true end,print=function()return'late'end})
 assert(not c.run({type='LATE_WITNESS',unit='focus'}))
 assert(retired and lookups>=2,'getter control did not retire');assert(evaluations==0,'old condition evaluate invoked after final presence identity getter retirement')
end)
finish()
