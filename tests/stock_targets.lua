-- Pure profile-owned desired stock; observations never enter storage.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function model()
 local a={};a.db=setmetatable({},{__index=function()error('pure model read database')end});a.Platform=setmetatable({},{__index=function()error('pure model read native API')end})
 local e=setmetatable({GetTime=function()error('pure model queried clock')end,GetItemCount=function()error('pure model queried inventory')end},{__index=_G});e._G=e
 local fn=assert(loadfile('Core/stock_targets.lua'));setfenv(fn,e);fn('rotationmaster',a)
 return assert(a.StockTargets,'canonical stock owner absent')
end
local function row(item,minimum,target,enabled)return{itemID=item or 1710,minimum=minimum or 5,target=target or 12,enabled=enabled~=false}end
local function valid(m,plan)assert(m.Validate(plan)==true,'valid exact-item target plan rejected')end
local function bad(m,plan)local ok,why=m.Validate(plan);assert(ok==nil and type(why)=='string'and #why>0,'invalid target plan accepted')end
local function unchanged(plan,body)
 local snapshot={};for k,v in pairs(plan)do local copy={};if type(v)=='table'then for x,y in pairs(v)do copy[x]=y end end;snapshot[k]={v,copy}end
 body();for k,pair in pairs(snapshot)do assert(plan[k]==pair[1]);if type(pair[1])=='table'then for x,y in pairs(pair[2])do assert(plan[k][x]==y or type(y)=='number'and y~=y and plan[k][x]~=plan[k][x])end;for x in pairs(plan[k])do assert(pair[2][x]~=nil)end end end
 for k in pairs(plan)do assert(snapshot[k])end
end
test('threshold boundary refills to target only below minimum',function()
 local m=model();for _,case in ipairs({{0,12},{4,8},{5,0},{6,0}})do local plan={a=row()};local counts={[1710]=case[1]};unchanged(plan,function()
  local report=assert(m.BuildReport(plan,counts));assert(report.complete and report.rows[1].carried==case[1] and report.rows[1].shortage==case[2]);assert(counts[1710]==case[1])
 end)end
end)
test('absent empty zero and disabled targets never invent requirements',function()
 local m=model();valid(m,nil);valid(m,{});for _,plan in ipairs({{}, {a=row(1710,0,0)}, {a=row(1710,5,12,false)}})do
  local report=assert(m.BuildReport(plan,nil,'inventory-unavailable'));assert(report.complete==(next(plan)==nil or plan.a.enabled==false))
 end
 local report=assert(m.BuildReport({a=row(1710,0,0)},{}));assert(report.complete and report.rows[1].shortage==0)
end)
test('enabled unknown facts block list while disabled unknown facts do not',function()
 local m=model();local plan={a=row(),b=row(9,2,8,false)}
 local report=assert(m.BuildReport(plan,nil,'inventory-unavailable'));assert(not report.complete);local text,why=m.FormatShortages(report);assert(text==nil and type(why)=='string')
 report=assert(m.BuildReport({a=row(9,2,8,false)},nil,'inventory-unavailable'));assert(report.complete and m.FormatShortages(report))
 for _,quantity in ipairs({-1,.5,math.huge,-math.huge,0/0,false,'4',{}})do report=assert(m.BuildReport(plan,{[1710]=quantity}));assert(not report.complete and m.FormatShortages(report)==nil)end
end)
test('complete plain missing entries mean zero without consuming unrelated count data',function()
 local m=model();local report=assert(m.BuildReport({a=row()},{}));assert(report.complete and report.rows[1].carried==0 and report.rows[1].shortage==12)
 report=assert(m.BuildReport({a=row()},{[1710]=4,[999]='unconsumed bad value'}));assert(report.complete and report.rows[1].shortage==8)
 local gets=0;report=assert(m.BuildReport({a=row()},setmetatable({},{__index=function()gets=gets+1;error('inherited count')end})));assert(not report.complete and gets==0)
end)
test('closed bounded row schema rejects malformed shapes and duplicates without mutation',function()
 local m=model();local plan={};for i=1,128 do plan['row'..i]=row(i)end;valid(m,plan);plan.extra=row(999);bad(m,plan)
 for _,change in ipairs({function(r)r.itemID=0 end,function(r)r.itemID=.5 end,function(r)r.itemID=math.huge end,function(r)r.minimum=-1 end,function(r)r.minimum=.5 end,function(r)r.minimum=0/0 end,function(r)r.target=1000001 end,function(r)r.minimum=13 end,function(r)r.enabled=nil end,function(r)r.enabled=1 end,function(r)r.carried=5 end})do local p={a=row()};change(p.a);unchanged(p,function()bad(m,p)end)end
 valid(m,{a=row(123456789012,1000000,1000000)})
 for _,key in ipairs({'',string.rep('x',129),'x\0y','x\127y'})do bad(m,{[key]=row()})end
 bad(m,{[1]=row()});bad(m,{a=row(),b=row(1710,0,2,false)})
 local r=row();bad(m,{a=r,b=r});local cycle={};cycle.a=cycle;bad(m,cycle);local p={a=row()};p.a.itemID=p;bad(m,p)
 local calls=0;bad(m,setmetatable({a=row()},{__index=function()calls=calls+1;error('metadata')end}));bad(m,{a=setmetatable(row(),{})});assert(calls==0)
end)
test('detached report and deterministic exact item text cannot mutate desired or observed data',function()
 local m=model();local plan={last=row(100,5,12),first=row(9,5,12)};local counts={[100]=4,[9]=4};local report=assert(m.BuildReport(plan,counts));local text=assert(m.FormatShortages(report))
 assert(text:lower():find('carried',1,true)and assert(text:find('9 x 8',1,true))<assert(text:find('100 x 8',1,true)))
 report.rows[1].target=999;report.rows[1].carried=99;assert(plan.first.target==12 and plan.last.target==12 and counts[9]==4 and counts[100]==4)
end)
test('partial inventory and opaque reasons remain fixed unknown without touching counts or plans',function()
 local m=model();local plan={a=row()};local counts={[1710]=4};local report=assert(m.BuildReport(plan,counts,'PRIVATE_NATIVE_ERROR'))
 assert(not report.complete and report.rows[1].countKnown==false and report.rows[1].carried==nil and report.rows[1].shortage==nil)
 local text,reason=m.FormatShortages(report);assert(text==nil and reason=='inventory-unavailable' and report.reason=='inventory-unavailable' and counts[1710]==4)
 local cycle={};cycle.self=cycle;local result,why=m.BuildReport(cycle,setmetatable({},{__index=function()error('invalid plan read counts')end}));assert(result==nil and type(why)=='string'and cycle.self==cycle)
end)
test('formatting preserves large exact numeric IDs and validates reports without arbitrary error text',function()
 local m=model();local plan={a=row(123456789012,5,12)};local report=assert(m.BuildReport(plan,{}));assert(m.FormatShortages(report):find('123456789012 x 12',1,true))
 for _,badReport in ipairs({false,{}, {complete=true,rows={}}, {complete=false,reason='PRIVATE_NATIVE_ERROR',rows={}}})do
  local ok,text,why=pcall(m.FormatShortages,badReport);assert(ok);if type(badReport)=='table'and badReport.complete==true then assert(text:find('No shortages.',1,true))else assert(text==nil and (why=='invalid-stock-report'or why=='inventory-unavailable'))end
 end
 local malformed=assert(m.BuildReport(plan,{}));malformed.rows[1].carried='PRIVATE_NATIVE_ERROR';local text,why=m.FormatShortages(malformed);assert(text==nil and why=='invalid-stock-report')
end)
finish()
