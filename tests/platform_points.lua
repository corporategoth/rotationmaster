local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
 local f=F.new(project);local e=f.env;local s={exists=true,class='MAGE',current=3,maximum=5,calls={}}
 local function call(k,...) s.calls[#s.calls+1]={k,n=select('#',...),...};if s.throw==k then error('native points failure') end;return s[k] end
 e.UnitExists=function(...) assert(select('#',...)==1);return call('exists',...) end
 e.UnitClass=function(...) assert(select('#',...)==1);call('class',...);return s.label,s.class,s.id end
 e.UnitPower=function(...) assert(select('#',...)==2);return call('current',...) end;e.UnitPowerMax=function(...) assert(select('#',...)==2);return call('maximum',...) end
 e.UnitPowerType=function() error('no primary resource query') end
 local file=io.open('Platform/points.lua');if file then file:close();f.load('Platform/points.lua') end
 return f,f.addon.Platform,s
end
local function identity(p,unit,mode) assert(p.GetUnitPointIdentityObservation,'point identity missing');return p:GetUnitPointIdentityObservation(unit==nil and 'target' or unit,mode) end
local function power(p,unit,selector,kind) assert(p.GetUnitPointPowerObservation,'point power missing');return p:GetUnitPointPowerObservation(unit==nil and 'target' or unit,selector,kind) end
local function unavailable(fn,why) local value,reason=fn();assert(value==nil and reason==why,tostring(value)..':'..tostring(reason)..' expected '..why) end
test('identity keeps exact unit existence order and consumed class field only',function()
 local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.label=opaque;s.id=opaque
 assert(identity(p,'pet',true).class=='MAGE');assert(#s.calls==2 and s.calls[1][1]=='exists' and s.calls[2][1]=='class' and s.calls[2][2]=='pet')
 s.calls={};f.env.UnitClass=nil;assert(identity(p,'player',false).exists and #s.calls==1)
 s.exists=false;s.calls={};assert(identity(p,'target',true).exists==false and #s.calls==1)
end)
test('quantity kinds preserve every finite signed fractional value with exact two native arguments',function()
 local _,p,s=fixture();for _,kind in ipairs({'current','maximum'}) do for _,v in ipairs({0,3,-2,.5,-.25,1e308}) do s[kind]=v;assert(power(p,'pet',0,kind)==v);local c=s.calls[#s.calls];assert(c[1]==kind and c[2]=='pet' and c[3]==0 and c.n==2) end end
end)
test('strict readable modes tokens and explicit selectors reject before querying',function()
 local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
 for _,bad in ipairs({'',false,0,{},opaque}) do unavailable(function() return identity(p,bad,true) end,rawequal(bad,opaque) and 'restricted-value' or 'invalid-unit') end
 for _,bad in ipairs({false,'0',-1,.5,{},0/0,math.huge,opaque}) do unavailable(function() return power(p,'target',bad,'current') end,rawequal(bad,opaque) and 'restricted-value' or 'invalid-point-power-query') end
 unavailable(function() return power(p,'target',nil,'current') end,'invalid-point-power-query')
 for _,bad in ipairs({'current',0,{}}) do unavailable(function() return identity(p,'target',bad) end,'invalid-point-identity-query') end
 unavailable(function() return identity(p,'target',nil) end,'invalid-point-identity-query');unavailable(function() return power(p,'target',4,'both') end,'invalid-point-power-query');assert(#s.calls==0)
end)
test('required missing failed nil malformed and restricted native facts are unavailable',function()
 for _,k in ipairs({'exists','class','current','maximum'}) do
  local f,p,s=fixture();local function observe() if k=='exists' or k=='class' then return identity(p,'target',true) end;return power(p,'target',4,k) end
  s[k]=nil;unavailable(observe,k=='exists' and 'unit-data-unavailable' or k=='class' and 'point-class-unavailable' or 'point-power-unavailable')
  for _,bad in ipairs(k=='exists' and {0,'false',{}} or k=='class' and {0,'',{}} or {false,'3',{},0/0,math.huge}) do s[k]=bad;unavailable(observe,'invalid-api-result') end
  local opaque={};s[k]=opaque;f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;unavailable(observe,'restricted-value');s[k]=k=='exists' and true or k=='class' and 'MAGE' or 3;s.throw=k;unavailable(observe,'api-error');s.throw=nil
  f.env[({exists='UnitExists',class='UnitClass',current='UnitPower',maximum='UnitPowerMax'})[k]]=nil;unavailable(observe,'missing-api')
 end
end)
test('policy and load-time silence support all identified probe families and live replacement',function()
 -- An unknown client reads nothing. Retail and Forever read identity, and only the secondary resources Blizzard stopped making
 -- secret (48e9d4b0: conditions follow what the game keeps secret, not the policy); a primary power stays unsupported there.
 do local _,p,s=fixture(999);unavailable(function() return identity(p,'target',true) end,'unsupported-policy');unavailable(function() return power(p,'target',4,'current') end,'unsupported-policy');assert(#s.calls==0) end
 for _,project in ipairs({1,18}) do local _,p=fixture(project);assert(identity(p,'target',true).exists and power(p,'target',4,'current')==3);unavailable(function() return power(p,'target',0,'current') end,'unsupported-policy') end
 for _,project in ipairs({2,5,11,14,19}) do local f,p,s=fixture(project);f.load('Platform/points.lua');assert(#s.calls==0);assert(identity(p,'target',true).exists and power(p,'target',4,'current')==3);f.env.UnitPower=function(...) assert(select('#',...)==2);return -.5 end;assert(power(p,'target',4,'current')==-.5) end
end)
test('nil unit and opaque query fields cannot reach cache indexing or native APIs',function()
 local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
 unavailable(function() return p:GetUnitPointIdentityObservation(nil,true) end,'invalid-unit')
 unavailable(function() return p:GetUnitPointPowerObservation(nil,4,'current') end,'invalid-unit')
 unavailable(function() return p:GetUnitPointIdentityObservation('target',opaque) end,'restricted-value')
 unavailable(function() return p:GetUnitPointPowerObservation('target',4,opaque) end,'restricted-value');assert(#s.calls==0)
end)
finish()
