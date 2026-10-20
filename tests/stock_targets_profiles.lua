local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function row(item)return{itemID=item or 1710,minimum=5,target=12,enabled=true}end
local function fixture()
 local f=F.new();f.load('Core/stock_targets.lua');f.load('Data/plain.lua');f.load('Data/tags.lua');f.load('Data/rotation_tree.lua');f.load('Data/validation.lua')
 return f,f.addon
end
test('optional desired plan roundtrips detached through original profile converters without new defaults',function()
 local _,a=fixture();local plan={a=row()};local p={version=3,stockTargets=plan};assert(a:ValidateProfileTransfer(p))
 local wire=assert(a:ProfileToPortable(p));local copy=assert(a:ProfileFromPortable(wire));assert(a:ValidateProfileTransfer(copy))
 assert(wire.stockTargets~=plan and wire.stockTargets.a~=plan.a and copy.stockTargets~=wire.stockTargets and copy.stockTargets.a.itemID==1710)
 copy.stockTargets.a.target=99;assert(plan.a.target==12 and wire.stockTargets.a.target==12 and p.version==3 and copy.version==3)
 for _,empty in ipairs({{version=3},{version=3,stockTargets={}}})do assert(a:ValidateProfileTransfer(empty));local result=assert(a:ProfileFromPortable(assert(a:ProfileToPortable(empty))));assert((result.stockTargets==nil)==(empty.stockTargets==nil))end
end)
test('profiles without optional stock retain old conversion without consulting stock validator',function()
 local _,a=fixture();a.StockTargets.Validate=function()error('absent optional field invoked new validator')end
 local p={version=3,poll=.15};assert(a:ValidateProfileTransfer(p));assert(a:ProfileFromPortable(assert(a:ProfileToPortable(p))).stockTargets==nil)
end)
test('malformed stock is rejected before generic copy and no metadata or deep graph is traversed',function()
 local _,a=fixture();local original=a.CopySettingsData;local copies,metadata=0,0
 a.CopySettingsData=function(...)copies=copies+1;return original(...)end
 local deep={};local last=deep;for i=1,20000 do local child={};last.child=child;last=child end
 local cycle={};cycle.self=cycle
 local alias=row();local plans={false,7,'future',{a={itemID=1710,minimum=0,target=1}}, {a=row(),b=row()}, {a=alias,b=alias},deep,cycle,setmetatable({a=row()},{__index=function()metadata=metadata+1;error('stock metadata getter')end})}
 for _,plan in ipairs(plans)do local p={version=3,stockTargets=plan};local before=copies
  assert(not a:ValidateProfileTransfer(p));assert(a:ProfileToPortable(p)==nil);assert(a:ProfileFromPortable(p)==nil);assert(copies==before,'invalid stock reached recursive generic copy');assert(p.stockTargets==plan)
 end
 assert(metadata==0)
end)
test('observations generated text and unknown row fields never enter profile transport',function()
 local _,a=fixture();for _,field in ipairs({'carried','countKnown','shortage','countReason','timestamp','report','name','character'})do
  local plan={a=row()};plan.a[field]=field=='carried'and 4 or 'not saved';local p={version=3,stockTargets=plan};assert(not a:ValidateProfileTransfer(p)and a:ProfileToPortable(p)==nil and a:ProfileFromPortable(p)==nil)
 end
 local p={version=3,stockTargets={a=row()}};local report=assert(a.StockTargets.BuildReport(p.stockTargets,{[1710]=4}));local text=assert(a.StockTargets.FormatShortages(report));assert(text and p.stockTargets.a.carried==nil)
 local wire=assert(a:ProfileToPortable(p));assert(wire.stockTargets.a.shortage==nil and wire.stockTargets.a.countKnown==nil and wire.stockTargets.a.timestamp==nil)
end)
test('maintenance preserves valid and invalid optional roots by identity even when fixing other fields',function()
 local f,a=fixture();f.load('validate.lua');local warnings={};a.warn=function(_,message,...)warnings[#warnings+1]=string.format(message,...)end
 local template={global={},char={bindings={}},profile={version=3,itemsets={},announces={},rotations={},condition_groups={}}}
 local cycle={};cycle.self=cycle;local poisoned=setmetatable({a=row()},{__index=function()error('maintenance stock metadata')end})
 for _,plan in ipairs({{a=row()},false,cycle,poisoned})do
  local p={version=3,stockTargets=plan,unrelatedExtra='repair this'};local db={global={},char={},profiles={Default=p}};f.env.StockTargetsDB=db;a.savedVariableName='StockTargetsDB';warnings={}
  a:validate(template,false);assert(p.stockTargets==plan and p.unrelatedExtra=='repair this')
  a:validate(template,true);assert(p.stockTargets==plan and p.unrelatedExtra==nil,'maintenance erased or repaired stock root')
  if plan==false or plan==cycle or plan==poisoned then local found=false;for _,warning in ipairs(warnings)do if warning:find('Invalid stock targets',1,true)and warning:find('data preserved',1,true)then found=true end end;assert(found,'invalid preserved stock produced no warning')end
 end
 assert(template.profile.stockTargets==nil)
end)
test('maintenance reads only stored stock field and never synthesizes a profile metadata getter',function()
 local f,a=fixture();f.load('validate.lua');a.warn=function()end;local reads=0
 local p=setmetatable({version=3},{__index=function(_,key)if key=='stockTargets'then reads=reads+1;error('profile stock metadata getter')end end})
 local db={global={},char={},profiles={Default=p}};f.env.StockTargetsDB=db;a.savedVariableName='StockTargetsDB'
 a:validate({global={},char={bindings={}},profile={version=3}},true);assert(reads==0 and rawget(p,'stockTargets')==nil)
end)
local function aceDB(f)
 local e=f.env;e.LibStub=nil;e.CreateFrame=function()return{RegisterEvent=function()end,SetScript=function()end}end
 e.UnitFactionGroup=function()return'Horde'end;e.GetLocale=function()return'enUS'end;e.UnitClass=function()return'Shaman','SHAMAN'end;e.UnitRace=function()return'Orc','Orc'end;e.GetRealmName=function()return'Realm'end;e.UnitNameUnmodified=function()return'Player'end;e.GetCurrentRegionName=function()return'US'end;e.GetCurrentRegion=function()return 1 end;e.strlenutf8=string.len
 f.load('Libs/LibStub/LibStub.lua');f.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');f.load('Libs/AceDB-3.0/AceDB-3.0.lua')
 return e.LibStub('AceDB-3.0'):New('StockProfileDB',{profile={version=3},global={},char={}},true)
end
test('actual AceDB copies desired targets isolates profiles and Reset removes the absent default',function()
 local f,a=fixture();local db=aceDB(f);db.profile.stockTargets={a=row()};local default=db.profile
 db:SetProfile('Other');assert(db.profile.stockTargets==nil);db:CopyProfile('Default');assert(db.profile.stockTargets~=default.stockTargets and db.profile.stockTargets.a~=default.stockTargets.a and db.profile.stockTargets.a.itemID==1710)
 db.profile.stockTargets.a.target=99;assert(default.stockTargets.a.target==12);db:ResetProfile();assert(db.profile.stockTargets==nil and db.profile.version==3)
 db:SetProfile('Default');assert(db.profile.stockTargets==default.stockTargets and default.stockTargets.a.target==12)
end)
if pcall(require,'bit')then test('actual RM-Profile version1 codec transports only valid desired stock rows',function()
 local _,a=fixture();local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;local codec=assert(data.NewCodec(deps));local p={version=3,stockTargets={a=row()}}
 local wire=assert(a:ProfileToPortable(p));local text=assert(codec:Encode({format='RM-Profile',version=1,profile=wire}));local wrapper=assert(codec:Decode(text)).value
 assert(wrapper.format=='RM-Profile'and wrapper.version==1 and wrapper.profile.version==3);local restored=assert(a:ProfileFromPortable(wrapper.profile));assert(a:ValidateProfileTransfer(restored)and restored.stockTargets.a.itemID==1710 and restored.stockTargets.a.carried==nil)
end)else print('SKIP compressed profile wire: host native bit dependency unavailable; converters/AceDB still exercised')end
finish()
