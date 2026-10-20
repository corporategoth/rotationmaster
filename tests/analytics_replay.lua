-- Pure normalized evidence only: no addon fixture, live API, capture or evaluator.
local passed,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function engine()
 local addon={};local env=setmetatable({type=type,pairs=pairs,rawget=rawget,getmetatable=getmetatable,math={huge=math.huge,max=math.max,min=math.min}},{__index=function(_,key)error('unexpected global/native access '..key)end})
 local chunk=assert(loadfile('Analytics/replay.lua'),'pure analytics replay module missing');setfenv(chunk,env);chunk('rotationmaster',addon)
 return assert(addon.Analytics and addon.Analytics.Replay,'pure replay API missing')
end
local function row(kind,time,fields)fields=fields or{};fields.type=kind;fields.time=time;return fields end
local function advice(time,spell,epoch,untilTime)return row('advice',time,{epoch=epoch or 1,action='spell',spell=spell or 10,validUntil=untilTime or 10})end
local function ack(time,seq,state)return row('presentation',time,{adviceSeq=seq or 1,state=state or'visible'})end
local function attempt(time,id,spell,kind,actor,epoch,phase)return row('attempt',time,{cast=id or 1,spell=spell or 10,castKind=kind or'ordinary',actor=actor or'player',epoch=epoch or 1,phase=phase or'sent'})end
local function result(time,id,spell,status,kind,actor)return row('result',time,{cast=id or 1,spell=spell or 10,status=status or'success',castKind=kind or'ordinary',actor=actor or'player'})end
local function damage(time,amount,overkill,actor,subtype)return row('damage',time,{actor=actor or'player',subtype=subtype or'spell',known=true,amount=amount,overkill=overkill})end
local function coverage(time,state)return row('damageCoverage',time,{state=state or'available'})end
local function trace(rows,duration)for i,r in ipairs(rows or{})do if r.seq==nil then r.seq=i end end;return{format=1,model=1,family='tbc',actor='player',duration=duration or 10,records=rows or{}}end
local function replay(rows,duration)return engine()(trace(rows,duration))end
local function scores(r,m,d,u)
 assert(r.status=='complete',r.reason);local a=r.agreement;assert(a.matched==m and a.different==d and a.unobservable==u,'wrong agreement counts')
 assert(a.scorable==m+d);if m+d>0 then assert(a.status=='available'and a.percentage==100*m/(m+d))else assert(a.status=='unavailable'and a.percentage==nil)end
 assert(r.nativeCertified==false and a.metric=='exact-selected-spell-agreement')
end
local function bad(t,why)local r=engine()(t);assert(r.status=='unavailable'and r.reason==why,'wrong refusal '..tostring(r.reason));assert(r.agreement.percentage==nil and r.outcome.raw.value==nil and r.outcome.net.value==nil);return r end
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end

test('empty trace has neither agreement nor fabricated damage zero',function()local r=replay({});scores(r,0,0,0);assert(r.outcome.raw.status=='unavailable'and r.outcome.raw.value==nil and r.outcome.rate.value==nil)end)
test('67 repeated selected advice refreshes produce one successful opportunity',function()
 local rows={};for i=1,67 do rows[#rows+1]=advice(0,10);rows[#rows+1]=ack(0,#rows)end;rows[#rows+1]=attempt(1);rows[#rows+1]=result(2)
 local r=replay(rows);scores(r,1,0,0);assert(r.coverage.adviceRows==67 and r.coverage.visibleAcknowledgements==67)
end)
test('first attempt freezes original advice rather than future successful spell',function()local r=replay({advice(0,10),ack(0),attempt(1,1,20),advice(2,20),ack(2,4),result(3,1,20)});scores(r,0,1,0)end)
test('acknowledgement after first attempt cannot rescue same-time evidence',function()scores(replay({advice(0),attempt(0),ack(0),result(0)}),0,0,1)end)
test('equal timestamps obey strict sequence and earlier ack can score',function()scores(replay({advice(0),ack(0),attempt(0),result(0)}),1,0,0)end)
test('expiration instant is stale while immediately earlier attempt is valid',function()
 for _,t in ipairs({1.999,2,2.001})do local r=replay({advice(0,10,1,2),ack(0),attempt(t),result(3)});if t<2 then scores(r,1,0,0)else scores(r,0,0,1)end end
end)
test('hidden unknown and future or old acknowledgement never qualify current advice',function()
 for _,state in ipairs({'hidden','unknown'})do scores(replay({advice(0),ack(0,1,state),attempt(1),result(2)}),0,0,1)end
 scores(replay({ack(0,2),advice(0),attempt(1),result(2)}),0,0,1)
 scores(replay({advice(0),ack(0),advice(1),ack(1,1),attempt(2),result(3)}),0,0,1)
end)
test('no selected advice and explicitly unknown or unmodeled advice remain unavailable',function()
 scores(replay({attempt(1),result(2)}),0,0,1)
 for _,action in ipairs({'none','unknown','unmodeled'})do scores(replay({row('advice',0,{epoch=1,action=action}),ack(0),attempt(1),result(2)}),0,0,1)end
end)
test('retirement and changed epoch never migrate pending attempts to new advice',function()
 scores(replay({advice(0),ack(0),attempt(1),row('retire',2,{reason='context'}),advice(2,10,2),ack(2,5),result(3)}),0,0,1)
 scores(replay({advice(0),ack(0),attempt(1),advice(2,10,2),ack(2,4),result(3)}),0,0,1)
 scores(replay({advice(0),ack(0),attempt(1,1,10,nil,nil,2),result(2)}),0,0,1)
end)
test('duplicate START and success preserve frozen anchor and one denominator',function()
 local r=replay({advice(0,10),ack(0),attempt(1,1,20),advice(2,20),ack(2,4),attempt(2,1,20,nil,nil,nil,'start'),result(3,1,20),result(4,1,20)});scores(r,0,1,0);assert(r.counts.duplicateAttempts==1 and r.counts.duplicateResults==1)
end)
test('failed interrupted stop-only and missing success create no successful denominator',function()
 for _,status in ipairs({'failed','interrupted','stop'})do local r=replay({advice(0),ack(0),attempt(1),result(2,1,10,status)});scores(r,0,0,0);assert(r.counts[status]==1)end
 scores(replay({advice(0),ack(0),attempt(1)}),0,0,0)
 local completed=replay({advice(0),ack(0),attempt(1),result(2,1,10,'stop'),result(3)});scores(completed,1,0,0);assert(completed.counts.duplicateResults==0,'distinct STOP and success were labeled duplicate results')
end)
test('channels autorepeat pets and other actors cannot enter ordinary player denominator',function()
 for _,kind in ipairs({'channel','autorepeat','unmodeled'})do local r=replay({advice(0),ack(0),attempt(1,1,10,kind),result(2,1,10,'success',kind),result(3,1,10,'success',kind)});scores(r,0,0,0);assert(r.counts.excludedCasts==1)end
 for _,actor in ipairs({'pet','other','unknown'})do local r=replay({advice(0),ack(0),attempt(1,1,10,nil,actor),result(2,1,10,nil,nil,actor)});scores(r,0,0,0);assert(r.counts.excludedCasts==1)end
end)
test('result-only instant success and unknown keys never borrow future advice',function()
 scores(replay({result(0),advice(1),ack(1,2),attempt(2),result(3)}),0,0,1)
 local r=replay({advice(0),ack(0),attempt(1,0),result(2,0)});scores(r,0,0,1);assert(r.counts.unkeyedRows==2)
end)
test('result spell actor or kind conflict is unobservable rather than hindsight match',function()
 for _,r in ipairs({result(2,1,20),result(2,1,10,nil,nil,'pet'),result(2,1,10,nil,'channel')})do scores(replay({advice(0),ack(0),attempt(1),r}),0,0,1)end
 scores(replay({advice(0),ack(0),attempt(1),result(2),result(3,1,20)}),0,0,1)
end)
test('failed or interrupted identity cannot later resurrect as a scorable success',function()for _,status in ipairs({'failed','interrupted'})do scores(replay({advice(0),ack(0),attempt(1),result(2,1,10,status),attempt(3),result(4)}),0,0,1)end end)
test('30second queue bound and expired tombstone cannot become fresh opportunity',function()
 scores(replay({advice(0,10,1,100),ack(0),attempt(1),result(31)},100),1,0,0)
 local r=replay({advice(0,10,1,100),ack(0),attempt(1),advice(32,10,1,100),ack(32,4),attempt(32),result(33)},100);scores(r,0,0,1);assert(r.counts.expired==1)
end)
test('distinct exact ranks remain different without retrospective equivalence',function()scores(replay({advice(0,1759),ack(0),attempt(1,1,1758),result(2,1,1758)}),0,1,0)end)
test('readable zero damage differs from no-event and unavailable observations',function()
 local r=replay({coverage(0),damage(1,0,0)});assert(r.outcome.raw.status=='available'and r.outcome.raw.value==0 and r.outcome.rate.value==0)
 local none=replay({coverage(0)});assert(none.outcome.raw.value==nil and none.outcome.rate.value==nil)
 local unknown=replay({coverage(0),row('damage',1,{actor='player',subtype='spell',known=false})});assert(unknown.outcome.raw.value==nil and unknown.outcome.unknownRows==1)
end)
test('four normalized subtypes and simultaneous identical hits are counted separately',function()
 local rows={coverage(0)};for _,sub in ipairs({'swing','range','spell','periodic'})do rows[#rows+1]=damage(1,100,20,'player',sub);rows[#rows+1]=damage(1,100,20,'player',sub)end
 local r=replay(rows);assert(r.outcome.raw.value==800 and r.outcome.net.value==640 and r.outcome.rate.value==80 and r.outcome.readableRows==8)
end)
test('pet other unknown actor and unsupported damage are never attributed as player complete totals',function()
 local r=replay({coverage(0),damage(1,999,0,'pet'),damage(2,999,0,'other'),damage(3,10,0)});assert(r.outcome.raw.value==10 and r.outcome.excludedRows==2)
 local u=replay({coverage(0),damage(1,10,0),damage(2,999,0,'unknown'),damage(3,4,0,'player','unmodeled')});assert(u.outcome.raw.status=='partial'and u.outcome.raw.value==10 and u.outcome.rate.value==nil)
end)
test('overkill sentinel missing overkill and impossible derived damage affect net only',function()
 local r=replay({coverage(0),damage(1,100,-1),damage(2,100,20)});assert(r.outcome.raw.value==200 and r.outcome.net.value==180)
 for _,over in ipairs({false,200})do local d=damage(1,100,over==false and nil or over);if over==false then d.overkill=nil end;local x=replay({coverage(0),d});assert(x.outcome.raw.value==100 and x.outcome.net.value==nil)end
end)
test('unknown damage and arithmetic overflow cannot fabricate total or rate',function()
 local r=replay({coverage(0),damage(1,10,0),row('damage',2,{actor='player',subtype='spell',known=false})});assert(r.outcome.raw.status=='partial'and r.outcome.raw.value==10 and r.outcome.rate.value==nil)
 local huge=replay({coverage(0),damage(1,1e308,0),damage(2,1e308,0)});assert(huge.outcome.raw.status=='unavailable'and huge.outcome.raw.value==nil and huge.outcome.rate.value==nil)
 local rate=replay({coverage(0),damage(0,1e308,0)},1e-308);assert(rate.outcome.raw.value==1e308 and rate.outcome.rate.value==nil)
end)
test('covered capture seconds and uncovered events never become encounter or rotation attribution',function()
 local r=replay({damage(0,999,0),coverage(2),damage(3,100,0),coverage(6,'unavailable'),damage(7,999,0)});assert(r.outcome.coveredSeconds==4 and r.outcome.raw.value==100 and r.outcome.raw.status=='partial'and r.outcome.rate.value==nil and r.outcome.uncoveredRows==2);assert(r.outcome.attribution=='capture-only'and r.outcome.encounter=='unavailable')
 local zero=replay({coverage(0),damage(0,0,0)},0);assert(zero.outcome.raw.value==0 and zero.outcome.rate.value==nil)
end)
test('malformed sparse or metatable inputs are refused without metamethod execution',function()
 bad({},'invalid-header');local t=trace({});t.records[2]=advice(0);bad(t,'dense-records-required')
 local trap=setmetatable({},{__index=function()error('executed')end,__pairs=function()error('executed')end});bad(trap,'unsafe-table')
 t=trace({advice(0)});setmetatable(t.records[1],{__metatable=false,__index=function()error('executed')end});bad(t,'unsafe-table')
 t=trace({});setmetatable(t.records,{__len=function()error('executed')end});bad(t,'unsafe-table')
end)
test('unknown keys executable values cycles and nested payloads fail closed',function()
 local t=trace({advice(0)});t.name='Player-1234';bad(t,'unknown-field');t=trace({advice(0)});t.records[1].code=function()error('executed')end;bad(t,'unknown-field')
 t=trace({advice(0)});t.records[1].spell={};bad(t,'invalid-record');t=trace({});t.records=t;bad(t,'dense-records-required')
 t=trace({advice(0)});t.records[1].spell=function()error('executed')end;bad(t,'invalid-record')
end)
test('NaN infinities negative duration and out-of-bound rows are refused',function()
 for _,value in ipairs({0/0,math.huge,-math.huge,-1,601})do local t=trace({});t.duration=value;bad(t,'invalid-header')end
 for _,value in ipairs({0/0,math.huge,-1,11})do local t=trace({advice(0)});t.records[1].time=value;bad(t,'invalid-record')end
 for _,value in ipairs({0/0,math.huge,-1,11})do local t=trace({advice(0)});t.records[1].validUntil=value;bad(t,'invalid-record')end
 bad(trace({advice(2,10,1,1)}),'invalid-record')
end)
test('duplicate or decreasing sequence and decreasing receive time are refused',function()
 local t=trace({advice(0),ack(1)});t.records[2].seq=1;bad(t,'duplicate-or-decreasing-sequence');t.records[2].seq=0;bad(t,'invalid-record')
 bad(trace({advice(2),ack(1)}),'decreasing-time')
end)
test('record cap refuses a tail rather than publishing prefix percentage',function()
 local rows={};for i=1,4097 do rows[i]=row('retire',0,{reason='stop'})end;bad(trace(rows),'record-limit')
 local r=replay({advice(0),ack(0),attempt(1),result(2)});scores(r,1,0,0)
end)
test('distinct aliases count result-only and expired tombstones toward cap',function()
 local rows={};for i=1,1025 do rows[i]=result(0,i,10,'failed')end;bad(trace(rows),'cast-limit')
 rows={};for i=1,1024 do rows[i]=result(0,i,10,'failed')end;local r=replay(rows);assert(r.status=='complete'and r.counts.distinctCasts==1024)
end)
test('pending cap failure is bounded and reused aliases do not consume another slot',function()
 local rows={};for i=1,129 do rows[i]=attempt(0,i)end;bad(trace(rows),'pending-limit')
 rows={};for i=1,128 do rows[i]=attempt(0,i)end;rows[129]=attempt(0,1);local r=replay(rows);assert(r.status=='complete'and r.counts.pending==128 and r.counts.duplicateAttempts==1)
end)
test('payload byte charge is independently capped and counts fixed string bytes',function()
 local rows={};for i=1,4096 do rows[i]=attempt(0,1)end;bad(trace(rows),'payload-limit')
 local r=replay({advice(0),ack(0),attempt(1),result(2)});assert(r.bytes>0 and r.bytes<=524288)
end)
test('inputs stay byte-for-byte data-equivalent and reports do not alias future runs',function()
 local t=trace({coverage(0),advice(0),ack(0,2),attempt(1),result(2),damage(3,10,0)});local baseline=copy(t);local fn=engine();local one=fn(t);assert(equal(t,baseline));local two=fn(t);assert(equal(one,two));one.agreement.matched=999;one.outcome.raw.value=999;assert(two.agreement.matched==1 and two.outcome.raw.value==10 and equal(t,baseline))
end)
test('reports expose only bounded enum reasons/counts without aliases names GUIDs or executable source',function()
 local r=replay({advice(0,1759,999),ack(0),attempt(1,123456,1758,nil,nil,999),result(2,123456,1758)});scores(r,0,1,0)
 local function scan(t)for k,v in pairs(t)do assert(k~='cast'and k~='epoch'and k~='spell'and k~='code'and k~='name'and k~='GUID');if type(v)=='table'then scan(v)elseif type(v)=='string'then for _,secret in ipairs({'Player-','Creature-','123456','1759','SECRET','function:','table:'})do assert(not v:find(secret,1,true))end end end end;scan(r)
 bad(trace({row('retire',0,{reason='SECRET_SOURCE_TEXT'})}),'invalid-record')
end)
test('exact4096record boundary accepts and payload charge has independently handcounted bytes',function()
 local rows={};for i=1,4096 do rows[i]=row('retire',0,{reason='stop'})end;local r=replay(rows);assert(r.status=='complete'and r.records==4096)
 assert(replay({}).bytes==90,'empty fixed header charge differs');assert(replay({coverage(0)}).bytes==167,'actual ASCII scalar bytes were not charged exactly')
end)
test('expired alias tombstones remain in distinct-key bound rather than being recycled',function()
 local rows={};local id=0;for batch=0,8 do for _=1,128 do id=id+1;rows[#rows+1]=attempt(batch*31,id)end end;bad(trace(rows,600),'cast-limit')
end)
test('duplicate attempt with a new epoch cannot relabel an old cast as newly observed',function()
 scores(replay({advice(0),ack(0),attempt(1),attempt(2,1,10,nil,nil,2,'start'),result(3)}),0,0,1)
end)
print(passed..' passed, '..failed..' failed');os.exit(failed>0 and 1 or 0)
