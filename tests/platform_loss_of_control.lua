local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project)
    local f=F.new(project);local e=f.env;local s={count=1,row={locType='STUN_MECHANIC',lockoutSchool=4,timeRemaining=5},calls={}}
    e.C_LossOfControl={GetActiveLossOfControlDataCount=function(...)
        assert(select('#',...)==0);s.calls[#s.calls+1]='count';if s.throw=='count' then error('count failure') end;return s.count
    end,GetActiveLossOfControlData=function(...)
        assert(select('#',...)==1);local index=...;s.calls[#s.calls+1]=index;if s.throw=='row' then error('row failure') end;return s.row
    end,GetNumEvents=function() error('legacy count used') end,GetEventInfo=function() error('legacy tuple used') end}
    local file=io.open('Platform/loss_of_control.lua');if file then file:close();f.load('Platform/loss_of_control.lua') end
    return f,f.addon.Platform,s
end
local function count(p) assert(type(p.GetLossOfControlCount)=='function','owned LOC count observer missing');return p:GetLossOfControlCount() end
local function row(p,index,kind) assert(type(p.GetLossOfControlEvent)=='function','owned LOC row observer missing');return p:GetLossOfControlEvent(index,kind) end
local function unknown(fn,reason) local value,why=fn();assert(value==nil and why==reason,tostring(why)..' expected '..reason) end
test('modern APIs retain zero-argument count and one-index row queries with only selected fields',function()
    local _,p,s=fixture();assert(count(p)==1)
    local record,why=row(p,1,'type');assert(record.locType=='STUN_MECHANIC' and record.lockoutSchool==nil and record.timeRemaining==5 and why==nil)
    record,why=row(p,2,'school');assert(record.lockoutSchool==4 and record.locType==nil and record.timeRemaining==5 and why==nil)
    assert(#s.calls==3 and s.calls[1]=='count' and s.calls[2]==1 and s.calls[3]==2)
end)
test('count requires readable finite nonnegative integers and enforces an explicit256 row budget',function()
    local f,p,s=fixture();for _,value in ipairs({0,1,256}) do s.count=value;assert(count(p)==value) end
    s.count=257;unknown(function() return count(p) end,'loss-of-control-budget-exceeded')
    for _,bad in ipairs({-1,.5,0/0,math.huge,-math.huge,false,'1',{}}) do s.count=bad;unknown(function() return count(p) end,'invalid-api-result') end
    s.count=nil;unknown(function() return count(p) end,'loss-of-control-count-unavailable')
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.count=opaque;unknown(function() return count(p) end,'restricted-value')
    s.count=1;s.throw='count';unknown(function() return count(p) end,'api-error');s.throw=nil
    f.env.C_LossOfControl.GetActiveLossOfControlDataCount=nil;unknown(function() return count(p) end,'missing-api')
end)
test('index and closed kind validation precede row calls with restricted query data rejected',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    for _,index in ipairs({0,-1,.5,0/0,math.huge,false,'1',{},opaque}) do
        unknown(function() return row(p,index,'type') end,rawequal(index,opaque) and 'restricted-value' or 'invalid-loss-of-control-query')
    end
    unknown(function() return row(p,257,'type') end,'loss-of-control-budget-exceeded')
    for _,kind in ipairs({'','TYPE','all',false,0,{},opaque}) do unknown(function() return row(p,1,kind) end,rawequal(kind,opaque) and 'restricted-value' or 'invalid-loss-of-control-query') end
    assert(row(p,nil,'type')==nil and row(p,1,nil)==nil and #s.calls==0)
end)
test('missing namespace method and advertised rows are unavailable while empty count needs no row capability',function()
    local f,p,s=fixture();s.count=0;f.env.C_LossOfControl.GetActiveLossOfControlData=nil;assert(count(p)==0 and #s.calls==1)
    unknown(function() return row(p,1,'type') end,'missing-api')
    f,p,s=fixture();s.row=nil;unknown(function() return row(p,1,'type') end,'loss-of-control-event-unavailable')
    for _,bad in ipairs({false,1,'row'}) do s.row=bad;unknown(function() return row(p,1,'type') end,'invalid-api-result') end
    s.throw='row';unknown(function() return row(p,1,'type') end,'api-error')
    f.env.C_LossOfControl=nil;unknown(function() return count(p) end,'missing-api');unknown(function() return row(p,1,'type') end,'missing-api')
    f.env.C_LossOfControl={GetNumEvents=function() return 0 end,GetEventInfo=function() return 'STUN' end}
    unknown(function() return count(p) end,'missing-api');unknown(function() return row(p,1,'type') end,'missing-api')
end)
test('only requested subject is required and empty future types and unrestricted integer masks survive',function()
    local f,p,s=fixture();local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end
    s.row={locType='Future type',lockoutSchool=opaque,timeRemaining=2};assert(row(p,1,'type').locType=='Future type')
    s.row.locType='';assert(row(p,1,'type').locType=='')
    s.row={locType=opaque,lockoutSchool=1024,timeRemaining=2};assert(row(p,1,'school').lockoutSchool==1024)
    s.row.locType=opaque;unknown(function() return row(p,1,'type') end,'restricted-value')
    for _,bad in ipairs({false,0,{}}) do s.row.locType=bad;unknown(function() return row(p,1,'type') end,'invalid-api-result') end
    for _,bad in ipairs({-1,.5,0/0,math.huge,false,'4',{}}) do s.row.lockoutSchool=bad;unknown(function() return row(p,1,'school') end,'invalid-api-result') end
    s.row=setmetatable({locType='STUN'},{__index=function() error('unrequested field read') end})
    local record=row(p,1,'type');assert(record.locType=='STUN' and record.timeRemainingReason=='api-error')
end)
test('optional timing is finite when readable and otherwise a field reason without leaked values',function()
    local f,p,s=fixture();for _,value in ipairs({0,-.25,2.75}) do s.row.timeRemaining=value;assert(row(p,1,'type').timeRemaining==value) end
    s.row.timeRemaining=nil;local record=row(p,1,'type');assert(record.locType=='STUN_MECHANIC' and record.timeRemaining==nil and record.timeRemainingReason=='loss-of-control-time-unavailable')
    for _,bad in ipairs({false,'5',{},0/0,math.huge,-math.huge}) do s.row.timeRemaining=bad;record=row(p,1,'type');assert(record.timeRemaining==nil and record.timeRemainingReason=='invalid-api-result') end
    local opaque={};f.env.canaccessvalue=function(v) return not rawequal(v,opaque) end;s.row.timeRemaining=opaque;record=row(p,1,'type');assert(record.timeRemaining==nil and record.timeRemainingReason=='restricted-value')
    f.env.canaccessvalue=nil;f.env.issecretvalue=function(v) return rawequal(v,opaque) end;record=row(p,1,'type');assert(record.timeRemainingReason=='restricted-value')
end)
test('field access failures are isolated and unused fields never become requirements',function()
    local f,p,s=fixture();s.row=setmetatable({lockoutSchool=4},{__index=function(_,key) if key=='timeRemaining' then return -1 end;error('unrequested '..key) end})
    assert(row(p,1,'school').timeRemaining==-1);unknown(function() return row(p,1,'type') end,'api-error')
    s.row=setmetatable({locType='STUN'},{__index=function(_,key) if key=='timeRemaining' then error('timing unavailable') end;error('unrequested '..key) end})
    local record=row(p,1,'type');assert(record.locType=='STUN' and record.timeRemainingReason=='api-error')
    f.env.C_LossOfControl=setmetatable({},{__index=function() error('method read failed') end})
    unknown(function() return count(p) end,'api-error');unknown(function() return row(p,1,'type') end,'api-error')
end)
test('probe families use live APIs without load-time queries and blocked policies never query',function()
    for _,project in ipairs({2,5,11,14,19}) do local f,p,s=fixture(project);assert(type(p.GetLossOfControlCount)=='function','owned LOC count observer missing')
        f.load('Platform/loss_of_control.lua');assert(#s.calls==0);assert(count(p)==1 and row(p,1,'type').timeRemaining==5)
        f.env.C_LossOfControl.GetActiveLossOfControlDataCount=function(...) assert(select('#',...)==0);return 0 end;assert(count(p)==0)
    end
    for _,project in ipairs({999}) do local _,p,s=fixture(project);unknown(function() return count(p) end,'unsupported-policy');unknown(function() return row(p,1,'type') end,'unsupported-policy');assert(#s.calls==0) end
end)
finish()
