local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite();local fixture=dofile('tests/fixtures/threat_count.lua')
local function observe(a,minimum,cache) assert(type(a.GetConditionThreatCount)=='function','observed threat count service missing');return a:GetConditionThreatCount(minimum or 1,cache) end
local function unknown(a,minimum,cache) local result,why=observe(a,minimum,cache);assert(result==nil and type(why)=='string' and why~='','unavailable snapshot became known');return why end
local function order(s) local names={};for _,row in ipairs(s.calls) do names[#names+1]=row[1] end;return table.concat(names,',') end
test('current observed identity gates exact existing threat queries and preserves every status domain',function()
 for _,case in ipairs({{3,1,1},{0,0,1},{0,1,0},{-1,-2,1},{1.5,1.5,1},{9,3,1}}) do
  local _,a,s=fixture();s.facts.nameplate1.threat=case[1];assert(observe(a,case[2],{})==case[3]);assert(order(s)=='exists,guid,exists,enemy,threat')
 end
end)
test('absence recycled tokens nonenemy and optional nil status have lazy known exclusions',function()
 for _,case in ipairs({{'exists',false,'exists'},{'guid','Creature-new','exists,guid'},{'enemy',false,'exists,guid,exists,enemy'},{'threat','nil','exists,guid,exists,enemy,threat'}}) do
  local f,a,s=fixture();s.facts.nameplate1[case[1]]=case[2];if case[2]=='nil' then s.facts.nameplate1.threat=nil end
  if case[1]=='exists' or case[1]=='guid' then a.Platform.GetUnitThreatObservation=nil;f.env.UnitThreatSituation=nil end
  assert(observe(a,1,{})==0);assert(order(s)==case[3])
 end
end)
test('required native failures remain unavailable without falling back to stored scalar facts',function()
 for _,key in ipairs({'exists','guid','enemy','threat'}) do
  for _,mode in ipairs({'nil','missing','throw','opaque','table','nan','infinite','string'}) do
   if key~='threat' or mode~='nil' then local f,a,s,o=fixture();local row=s.facts.nameplate1
    if mode=='nil' then row[key]=nil elseif mode=='missing' then f.env[({exists='UnitExists',guid='UnitGUID',enemy='UnitIsEnemy',threat='UnitThreatSituation'})[key]]=nil elseif mode=='throw' then row.throw=key elseif mode=='opaque' then row[key]=o elseif mode=='table' then row[key]={} elseif mode=='nan' then row[key]=0/0 elseif mode=='infinite' then row[key]=math.huge else row[key]='invalid' end
    if key=='guid' and mode=='string' then row.guid='' end
    if key~='guid' or mode~='string' or row.guid=='' then unknown(a,1,{}) end
   end
  end
 end
end)
test('empty membership is known zero but malformed consumed snapshot data is unavailable',function()
 local _,a=fixture();a.unitsInRange={};a.Platform.GetHealthForecastIdentityObservation=nil;a.Platform.GetUnitThreatObservation=nil;assert(observe(a,1,{})==0)
 for _,bad in ipairs({false,1,'units'}) do local _,a=fixture();a.unitsInRange=bad;unknown(a) end
 local _,a=fixture();a.unitsInRange=nil;unknown(a)
 for _,mode in ipairs({'key','record','unit','empty-unit','opaque-key','opaque-record','opaque-unit','throwing-unit'}) do local _,a,_,o=fixture()
  if mode=='key' then a.unitsInRange={[1]={unit='nameplate1'}} elseif mode=='record' then a.unitsInRange={['Creature-old']=false} elseif mode=='unit' then a.unitsInRange['Creature-old'].unit=nil elseif mode=='empty-unit' then a.unitsInRange['Creature-old'].unit='' elseif mode=='opaque-key' then a.unitsInRange={[o]={unit='nameplate1'}} elseif mode=='opaque-record' then a.unitsInRange={['Creature-old']=o} elseif mode=='opaque-unit' then a.unitsInRange['Creature-old'].unit=o else a.unitsInRange['Creature-old']=setmetatable({},{__index=function() error('unit read failed') end}) end
  unknown(a)
 end
end)
test('unavailable applicable rows prevent partial counts and no replacement membership is inserted',function()
 local _,a,s=fixture();s.facts.nameplate2={exists=true,guid='Creature-second',enemy=nil,threat=3};a.unitsInRange['Creature-second']={unit='nameplate2',enemy=true,threat=3};unknown(a,1,{})
 s.facts.nameplate2.guid='Creature-replacement';assert(observe(a,1,{})==1 and a.unitsInRange['Creature-replacement']==nil)
end)
test('caller cache retains full nil reason false and numeric tuples with fresh membership traversal',function()
 local _,a,s=fixture();local cache={};s.facts.nameplate1.enemy=nil;local why=unknown(a,1,cache);local count=#s.calls;s.facts.nameplate1.enemy=true;assert(unknown(a,1,cache)==why and #s.calls==count);assert(observe(a,1,{})==1)
 s.calls={};cache={};assert(observe(a,1,cache)==1 and #s.calls==5);assert(observe(a,2,cache)==1 and #s.calls==5);a.unitsInRange={};assert(observe(a,1,cache)==0 and #s.calls==5)
 a.unitsInRange={['Creature-new']={unit='nameplate1'}};assert(observe(a,1,cache)==0 and #s.calls==5)
 s.facts.nameplate1.guid='Creature-new';assert(observe(a,1,{})==1);s.calls={};assert(observe(a,1)==1 and observe(a,1)==1 and #s.calls==10);assert(next(a.longtermCache)==nil)
end)
test('policy is fresh even for empty maps and unsupported policy performs no unit query',function()
 for _,project in ipairs({1,18,999}) do local _,a,s=fixture(false,project);a.unitsInRange={};unknown(a);assert(#s.calls==0) end
 local _,a,s=fixture();a.unitsInRange={};assert(observe(a,1,{})==0);a.Platform.GetClientInfo=function() return {combatDataPolicy='restricted'} end;unknown(a,1,{});assert(#s.calls==0)
end)
test('public helper overrides retain typed availability and exact canonical cache identity',function()
 for _,kind in ipairs({'identity','threat'}) do for _,bad in ipairs({{},true,0/0,math.huge}) do local _,a,_,o=fixture();local value=bad;if type(bad)=='table' then value=o end
  if kind=='identity' then a.Platform.GetHealthForecastIdentityObservation=function() return value end else a.Platform.GetUnitThreatObservation=function() return value end end
  unknown(a,1,{})
 end end
 local _,a,s=fixture();local cache={};assert(observe(a,1,cache)==1);a.Platform.GetUnitThreatObservation=function() return false end;assert(observe(a,1,cache)==0 and #s.calls==5)
 local f,a,s=fixture();local other=setmetatable({unitsInRange=a.unitsInRange,Platform=setmetatable({},{__index=a.Platform})},{__index=a});assert(observe(a,1,cache)==1);local before=#s.calls;assert(observe(other,1,cache)==1 and #s.calls==before+5)
end)
test('query and cache validation never coerce missing or opaque arguments',function()
 for _,bad in ipairs({false,'1',{},0/0,math.huge}) do local _,a,s=fixture();assert(a.GetConditionThreatCount,'count service missing');local count,why=a:GetConditionThreatCount(bad,{});assert(count==nil and type(why)=='string' and #s.calls==0) end
 local _,a,s=fixture();assert(a.GetConditionThreatCount,'count service missing');local result,why=a:GetConditionThreatCount(nil,{});assert(result==nil and type(why)=='string' and #s.calls==0)
 for _,bad in ipairs({false,1,'cache'}) do local _,a,s=fixture();assert(a.GetConditionThreatCount,'count service missing');local count,why=a:GetConditionThreatCount(1,bad);assert(count==nil and type(why)=='string' and #s.calls==0) end
end)
-- The session-fixed client policy is read once (one full metadata snapshot,
-- seven reads), not rebuilt for every observation; unit observations memoize.
test('client policy metadata is read once while unit observations memoize',function()
 local f,a,s=fixture();local e=f.env;local metadata=0
 local function meta(value) return function(...) assert(select('#',...)==0);metadata=metadata+1;return value end end
 e.GetClassicExpansionLevel=meta(2);e.GetLocale=meta('enUS');e.GetBuildInfo=function(...) assert(select('#',...)==0);metadata=metadata+1;return '11.0','12345','date',110000 end
 e.C_Seasons={GetActiveSeason=meta(0)};e.C_GameRules={GetCurrentGameModeRecordID=meta(0),IsHardcoreActive=meta(false),IsSelfFoundAllowed=meta(false)}
 local cache={};assert(observe(a,1,cache)==1 and metadata==7 and #s.calls==5);local before=metadata;assert(observe(a,2,cache)==1 and metadata-before==0 and #s.calls==5)
 a.unitsInRange={};before=metadata;assert(observe(a,1,cache)==0 and metadata-before==0 and #s.calls==5)
end)
test('a later unknown cannot be hidden by an earlier already sufficient match',function()
 local _,a,s=fixture();a.unitsInRange={['Creature-A']={unit='nameplate1'},['Creature-B']={unit='nameplate2'}}
 local first,entity=next(a.unitsInRange);local second,other=next(a.unitsInRange,first)
 s.facts[entity.unit]={exists=true,guid=first,enemy=true,threat=3};s.facts[other.unit]={exists=true,guid=second,enemy=nil,threat=3}
 unknown(a,1,{});assert(s.calls[1][2]==entity.unit and s.calls[5][1]=='threat' and s.calls[6][2]==other.unit,'test must consume known match before unknown')
end)
finish()
