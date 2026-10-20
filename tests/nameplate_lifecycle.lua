local factory=dofile('tests/fixtures/rotation_execution.lua')
local passed,failed=0,0
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1;io.stderr:write(name..': '..tostring(why)..'\n') end end
local function fixture()
 local c=factory({});local a,e=c.a,c.e
 local s={guid='Creature-A',aliases={},name='Observed name'}
 a.unitsInRange={};a.units={player='player',target='target'}
 e.UnitGUID=function(unit) if s.onGUID then s.onGUID(unit) end;if unit=='nameplate1' then return s.guid end;return s.aliases[unit] end
 e.UnitName=function(unit) if s.onName then s.onName(unit) end;return s.name end
 e.UnitCanAttack=function()return false end;e.UnitIsEnemy=function()return false end;e.UnitIsUnit=function()return false end
 local function add()a:NAME_PLATE_UNIT_ADDED('NAME_PLATE_UNIT_ADDED','nameplate1')end
 local function remove()a:NAME_PLATE_UNIT_REMOVED('NAME_PLATE_UNIT_REMOVED','nameplate1')end
 return a,e,s,add,remove
end
local function clean(a)assert(#a.Diagnostics:GetReports()==0,a.Diagnostics:FormatReport(nil,true))end
test('disappearing GUID retires stored token',function()
 local a,e,s,add,remove=fixture();add();assert(a.unitsInRange['Creature-A']);s.guid=nil;remove();assert(not a.unitsInRange['Creature-A'],'stale removed record retained');clean(a)
end)
test('token reuse does not accumulate identities',function()
 local a,e,s,add,remove=fixture();for i=1,40 do s.guid='Creature-'..i;add();s.guid=nil;remove() end;assert(next(a.unitsInRange)==nil);clean(a)
end)
test('still-available target preserves exact identity',function()
 local a,e,s,add,remove=fixture();add();local record=a.unitsInRange['Creature-A'];s.aliases.target='Creature-A';s.guid=nil;remove();assert(a.unitsInRange['Creature-A']==record and record.unit=='target');assert(record.name=='Observed name');clean(a)
end)
test('different target cannot preserve retired identity',function()
 local a,e,s,add,remove=fixture();add();s.aliases.target='Creature-B';s.guid=nil;remove();assert(not a.unitsInRange['Creature-A']);clean(a)
end)
test('duplicate remove and untracked token are harmless',function()
 local a,e,s,add,remove=fixture();s.guid=nil;remove();remove();assert(next(a.unitsInRange)==nil);clean(a)
end)
test('missing added GUID is ignored',function()
 local a,e,s,add=fixture();s.guid=nil;add();assert(next(a.unitsInRange)==nil);clean(a)
end)
test('unreadable added GUID is ignored',function()
 local a,e,s,add=fixture();local marker={};s.guid=marker;local original=a.Platform.CanReadValue;a.Platform.CanReadValue=function(self,v)if v==marker then return false end;return original(self,v)end;add();assert(next(a.unitsInRange)==nil);clean(a)
end)
test('GUID query failure does not stop advice',function()
 local a,e,s,add=fixture();e.UnitGUID=function()error('native unavailable')end;add();assert(next(a.unitsInRange)==nil);assert(not a.adviceErrorReport);clean(a)
end)
test('reused token without removal retires former identity',function()
 local a,e,s,add=fixture();add();s.guid='Creature-B';add();assert(not a.unitsInRange['Creature-A'] and a.unitsInRange['Creature-B']);clean(a)
end)
test('reused token preserves former identity through target',function()
 local a,e,s,add=fixture();add();local old=a.unitsInRange['Creature-A'];s.aliases.target='Creature-A';s.guid='Creature-B';add();assert(a.unitsInRange['Creature-A']==old and old.unit=='target' and a.unitsInRange['Creature-B'].unit=='nameplate1');clean(a)
end)
test('newer nested add wins publication',function()
 local a,e,s,add=fixture();s.onName=function()s.onName=nil;s.guid='Creature-B';add()end;add();assert(a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A']);clean(a)
end)
test('newer add during remove survives old callback',function()
 local a,e,s,add,remove=fixture();add();s.guid=nil;s.onGUID=function(unit)if unit=='target' then s.onGUID=nil;s.guid='Creature-B';add()end end;remove();assert(a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A']);clean(a)
end)
test('newer remove during add prevents resurrected entry',function()
 local a,e,s,add,remove=fixture();s.onName=function()s.onName=nil;s.guid=nil;remove()end;add();assert(next(a.unitsInRange)==nil);clean(a)
end)
test('snapshot replacement during native query is preserved',function()
 local a,e,s,add=fixture();local old=a.unitsInRange;local newer={};s.onName=function()a.unitsInRange=newer end;add();assert(a.unitsInRange==newer and next(newer)==nil and next(old)==nil);clean(a)
end)
test('preexisting bag handler remains installed and delegates',function()
 local a=fixture();local bound,bags=0,0;a.db.char.bindings={[7]=true,[8]=true};a.UpdateBoundButton=function(_,id)assert(id==7 or id==8);bound=bound+1 end;a.UpdateBagContents=function()bags=bags+1 end
 assert(type(a.BAG_UPDATE)=='function','BAG_UPDATE removed');a:BAG_UPDATE('BAG_UPDATE');assert(bound==2 and bags==1);clean(a)
end)
test('stored token becomes unreadable after input guard',function()
 local a,e,s,add,remove=fixture();add();s.guid=nil;local original=a.Platform.CanReadValue;local reads=0
 a.Platform.CanReadValue=function(self,v)if v=='nameplate1' then reads=reads+1;return reads==1 end;return original(self,v)end
 remove();assert(a.unitsInRange['Creature-A'],'unreadable stored unit was treated as known absence');assert(reads>=2);clean(a)
end)
test('replacement record published during canonical lookup survives remove',function()
 local a,e,s,add,remove=fixture();add();s.guid=nil;local newer={unit='nameplate1',name='Newer'};local fired=false
 s.onGUID=function(unit)if unit~='nameplate1' and not fired then fired=true;a.unitsInRange['Creature-A']=newer end end
 remove();assert(a.unitsInRange['Creature-A']==newer and newer.unit=='nameplate1');clean(a)
end)
test('record retargeted during canonical lookup is not retired',function()
 local a,e,s,add,remove=fixture();add();s.guid=nil;local row=a.unitsInRange['Creature-A'];local fired=false
 s.onGUID=function(unit)if unit~='nameplate1' and not fired then fired=true;row.unit='nameplate2' end end
 remove();assert(a.unitsInRange['Creature-A']==row and row.unit=='nameplate2');clean(a)
end)
test('late readability callout cannot erase nested newer add',function()
 local a,e,s,add,remove=fixture();add();s.guid=nil;local ready,fired=false,false;local original=a.Platform.CanReadValue
 s.onGUID=function(unit)if unit~='nameplate1' then ready=true end end
 a.Platform.CanReadValue=function(self,v)if ready and v=='nameplate1' and not fired then fired=true;s.guid='Creature-B';add()end;return original(self,v)end
 remove();assert(fired,'late stored-token guard not exercised');assert(a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A']);clean(a)
end)
test('added target replacement during cleanup readability wins',function()
 local a,e,s,add=fixture();add();local previous={unit='target',name='Before'};local newer={unit='target',name='Newer'}
 a.unitsInRange['Creature-B']=previous;s.guid='Creature-B';local reads=0;local native=a.Platform.CanReadValue
 a.Platform.CanReadValue=function(self,v)if v=='nameplate1' then reads=reads+1;if reads==3 then a.unitsInRange['Creature-B']=newer end end;return native(self,v)end
 add();assert(reads>=3,'final cleanup readability not reached');assert(a.unitsInRange['Creature-B']==newer,'older ADD overwrote target record replaced by provider');clean(a)
end)
test('new target slot appearing during cleanup wins',function()
 local a,e,s,add=fixture();add();s.guid='Creature-B';local newer={unit='target',name='Newer'};local reads=0;local original=a.Platform.CanReadValue
 a.Platform.CanReadValue=function(self,v)if v=='nameplate1' then reads=reads+1;if reads==3 then a.unitsInRange['Creature-B']=newer end end;return original(self,v)end
 add();assert(a.unitsInRange['Creature-B']==newer);clean(a)
end)
test('explicit native restriction boundary refuses changed result',function()
 local a,e,s,add=fixture();local queries=0;e.canaccessvalue=function(v)if v=='Creature-A' then queries=queries+1;return queries==1 end;return true end
 add();assert(queries==2 and next(a.unitsInRange)==nil);clean(a)
end)
test('new optional-native callback cannot publish older event',function()
 local a,e,s,add=fixture();local queries=0;e.canaccessvalue=function(v)if v=='Creature-A' then queries=queries+1;if queries==2 then s.guid='Creature-B';add()end end;return true end
 add();assert(queries==2 and a.unitsInRange['Creature-B'] and not a.unitsInRange['Creature-A']);clean(a)
end)
test('malformed truthy optional native slot is unavailable without quarantine',function()
 for _,v in ipairs({false,'not-a-function',{}})do local a,e,s,add=fixture();e.canaccessvalue=v;add();if v==false then assert(a.unitsInRange['Creature-A'])else assert(next(a.unitsInRange)==nil)end;clean(a)end
end)
print(string.format('Nameplate lifecycle: %d passed, %d failed',passed,failed));if failed>0 then os.exit(1)end
