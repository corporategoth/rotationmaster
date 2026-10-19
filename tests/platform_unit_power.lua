local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local a,e=f.addon,f.env
    local s={exists=true,powerType=3,current={[0]=50,[1]=10,[3]=20},maximum={[0]=100,[1]=100,[3]=100},calls={},trace={}}
    e.Enum.PowerType.Mana=0;e.Enum.PowerType.Rage=1;e.Enum.PowerType.Energy=3;e.Enum.PowerType.Balance=26
    local function call(key,...)
        s.calls[key]=(s.calls[key] or 0)+1;s.trace[#s.trace+1]={key=key,n=select('#',...),...};if s.throw==key then error('native failure') end
    end
    e.UnitExists=function(unit) call('exists',unit);return s.exists end
    e.UnitPowerType=function(...) assert(select('#',...)==1);call('type',...);return s.powerType,s.token or 'UNUSED_TOKEN',s.color end
    e.UnitPower=function(...) assert(select('#',...)==2);local unit,id=...;call('current',unit,id);return s.current[id] end
    e.UnitPowerMax=function(...) assert(select('#',...)==2);local unit,id=...;call('maximum',unit,id);return s.maximum[id] end
    local file=io.open('Platform/unit_power.lua');if file then file:close();f.load('Platform/unit_power.lua') end
    assert(type(a.Platform.GetUnitPowerObservation)=='function','owned unit power adapter missing');return f,a.Platform,s
end
test('explicit mana and current power retain distinct identities including Mana0 and exact native argument tuples',function()
    local _,p,s=fixture();assert(next(s.calls)==nil,'module observed resources during load')
    local r=assert(p:GetUnitPowerObservation('player','mana',true));assert(r.exists and r.powerType==0 and r.current==50 and r.maximum==100 and not s.calls.type)
    r=assert(p:GetUnitPowerObservation('target','current',true));assert(r.powerType==3 and r.current==20 and r.maximum==100 and s.calls.type==1)
    s.powerType=0;r=assert(p:GetUnitPowerObservation('pet','current',false));assert(r.powerType==0 and r.current==50 and r.maximum==nil)
    s.powerType=1;r=assert(p:GetUnitPowerObservation('vehicle','current',true));assert(r.powerType==1 and r.current==10)
    for _,entry in ipairs(s.trace) do if entry.key=='current' or entry.key=='maximum' then assert(entry.n==2 and (entry[2]==0 or entry[2]==1 or entry[2]==3)) else assert(entry.n==1) end end
    assert(s.trace[#s.trace][1]=='vehicle','adapter redirected the provided actor')
end)
test('known absence skips all resource queries and invalid or restricted requests fail before natives',function()
    local _,p,s=fixture();s.exists=false;local r=p:GetUnitPowerObservation('target','current',true);assert(r.exists==false and not s.calls.type and not s.calls.current and not s.calls.maximum)
    for _,project in ipairs({1,18,999}) do local _,q,state=fixture(project);local value,why=q:GetUnitPowerObservation('target','mana');assert(value==nil and why=='unsupported-policy' and next(state.calls)==nil) end
    local f;f,p,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
    for _,unit in ipairs({'',0,false,{},secret}) do assert(p:GetUnitPowerObservation(unit,'mana')==nil) end
    for _,mode in ipairs({'',0,false,{},secret,'energy'}) do assert(p:GetUnitPowerObservation('target',mode)==nil) end
    for _,flag in ipairs({0,'true',{},secret}) do assert(p:GetUnitPowerObservation('target','mana',flag)==nil) end
    assert(p:GetUnitPowerObservation(nil,'mana')==nil and p:GetUnitPowerObservation('target',nil)==nil and next(s.calls)==nil)
end)
test('nil failed restricted and malformed existence never becomes known absence',function()
    for _,mode in ipairs({'nil','missing','throw','restricted','number','string'}) do local f,p,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='nil' then s.exists=nil elseif mode=='missing' then f.env.UnitExists=nil elseif mode=='throw' then s.throw='exists' elseif mode=='restricted' then s.exists=secret elseif mode=='number' then s.exists=1 else s.exists='false' end
        local value,why=p:GetUnitPowerObservation('target','mana',true);assert(value==nil and type(why)=='string' and not s.calls.current and not s.calls.type)
    end
end)
test('enum containers and selected constants are readable before indexing while unrelated opaque members are ignored',function()
    for _,where in ipairs({'root','types','mana'}) do local f,p,s=fixture();local secret=setmetatable({}, {__index=function() error('restricted enum indexed') end});f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if where=='root' then f.env.Enum=secret elseif where=='types' then f.env.Enum.PowerType=secret else f.env.Enum.PowerType.Mana=secret end
        local value,why=p:GetUnitPowerObservation('target','mana');assert(value==nil and why=='restricted-value' and not s.calls.current)
    end
    for _,where in ipairs({'root','types','mana'}) do local f,p,s=fixture();if where=='root' then f.env.Enum=nil elseif where=='types' then f.env.Enum.PowerType=nil else f.env.Enum.PowerType.Mana=nil end
        local value,why=p:GetUnitPowerObservation('target','mana');assert(value==nil and type(why)=='string' and not s.calls.current,'missing Mana selected current resource')
    end
    local f,p,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end;f.env.Enum.PowerType.Unrelated=secret;s.token=secret;s.color=secret
    assert(p:GetUnitPowerObservation('target','current').powerType==3,'unrelated enum or presentation tuple hid readable type')
end)
test('current type requires a readable known live enum identity but explicit mana needs no current type API',function()
    for _,mode in ipairs({'nil','missing','throw','restricted','string','fraction','negative','unknown','nan'}) do local f,p,s=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='nil' then s.powerType=nil elseif mode=='missing' then f.env.UnitPowerType=nil elseif mode=='throw' then s.throw='type' elseif mode=='restricted' then s.powerType=secret elseif mode=='string' then s.powerType='ENERGY' elseif mode=='fraction' then s.powerType=1.5 elseif mode=='negative' then s.powerType=-1 elseif mode=='unknown' then s.powerType=100000 else s.powerType=0/0 end
        local value,why=p:GetUnitPowerObservation('target','current');assert(value==nil and type(why)=='string' and not s.calls.current)
        assert(p:GetUnitPowerObservation('target','mana').current==50,'explicit mana depended on current power type')
    end
end)
test('current signed Balance quantities preserve sign while explicit mana rejects negative current',function()
    local _,p,s=fixture();s.powerType=26;s.current[26]=-25.5;s.maximum[26]=100
    local r=assert(p:GetUnitPowerObservation('player','current',true));assert(r.powerType==26 and r.current==-25.5 and r.maximum==100)
    s.current[0]=-1;local value,why=p:GetUnitPowerObservation('player','mana',false);assert(value==nil and type(why)=='string')
end)
test('readable fractional quantities and zero remain valid while unavailable required fields reject before arithmetic',function()
    local _,p,s=fixture();s.current[0]=.5;s.maximum[0]=1.5;local r=p:GetUnitPowerObservation('target','mana',true);assert(r.current==.5 and r.maximum==1.5)
    s.current[0]=0;s.maximum[0]=0;r=p:GetUnitPowerObservation('target','mana',true);assert(r.current==0 and r.maximum==0)
    for _,key in ipairs({'current','maximum'}) do for _,mode in ipairs({'nil','missing','throw','restricted','negative','nan','infinite','string','boolean'}) do local f,q,state=fixture();local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
        if mode=='nil' then state[key][0]=nil elseif mode=='missing' then f.env[key=='current' and 'UnitPower' or 'UnitPowerMax']=nil elseif mode=='throw' then state.throw=key elseif mode=='restricted' then state[key][0]=secret elseif mode=='negative' then state[key][0]=-1 elseif mode=='nan' then state[key][0]=0/0 elseif mode=='infinite' then state[key][0]=math.huge elseif mode=='string' then state[key][0]='50' else state[key][0]=false end
        local value,why=q:GetUnitPowerObservation('target','mana',true);assert(value==nil and type(why)=='string')
        if key=='maximum' then assert(q:GetUnitPowerObservation('target','mana',false).current==50) end
    end end
end)
finish()
