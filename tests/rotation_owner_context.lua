local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(before,withoutProof)
 local f=F.new();local a,e=f.addon,f.env;local s={class='SHAMAN',level=11,vehicle=false,classCalls=0,levelCalls=0,vehicleCalls=0}
 e.UnitClass=function(...) assert(select('#',...)==1 and (...)=='player');s.classCalls=s.classCalls+1;return 'Ignored',s.class end
 e.UnitLevel=function() s.levelCalls=s.levelCalls+1;return s.level end;e.UnitHasVehicleUI=function() s.vehicleCalls=s.vehicleCalls+1;return s.vehicle end
 a.RotationData=dofile('tests/fixtures/rotation_data.lua')();a.db.keys={char='Owner - Realm'};a.currentSpec=7
 for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Core/rotation_library.lua'}) do f.load(path) end
 local original=a.GetRotationContext
 local h=io.open('Platform/rotation_owner.lua');if h then h:close();f.load('Platform/rotation_owner.lua') end
 if before then before(a,e,s,original) end
 if withoutProof then local bind=a.BindRotationLibraryReader;a.BindRotationLibraryReader=function(self,callback) return bind(self,function(reader) reader.OwnsContext=nil;callback(reader) end) end end
 f.load('Core/rotation_scope.lua');return f,a,s,original
end
test('default ownership omits unconsumed eligibility queries and observes player class afresh',function()
 local _,a,s=fixture();local c=assert(a:GetRotationOwnerContext());assert(c.class=='SHAMAN' and c.character=='Owner - Realm')
 assert(s.classCalls==1 and s.levelCalls==0 and s.vehicleCalls==0,'owner fetched unused eligibility facts')
 s.class='MAGE';c=assert(a:GetRotationOwnerContext());assert(c.class=='MAGE' and s.classCalls==2)
end)
test('context override installed before scope load is not mistaken for original owned method',function()
 local calls=0;local _,a,s=fixture(function(a) a.GetRotationContext=function(self,spec) assert(self==a and spec==7);calls=calls+1;return {class='DRUID'} end end)
 local c=assert(a:GetRotationOwnerContext());assert(c.class=='DRUID' and calls==1 and s.classCalls==0)
end)
test('postload override remains live and restoring exact original reenables narrow ownership',function()
 local _,a,s,original=fixture();local calls=0;a.GetRotationContext=function(self,spec) assert(self==a and spec==7);calls=calls+1;return {class='MAGE'} end
 assert(a:GetRotationOwnerContext().class=='MAGE' and calls==1 and s.classCalls==0)
 a.GetRotationContext=original;assert(a:GetRotationOwnerContext().class=='SHAMAN' and s.classCalls==1 and s.levelCalls==0)
end)
test('missing private ownership proof or platform method retains exact full context fallback',function()
 for _,withoutProof in ipairs({false,true}) do local _,a,s=fixture(nil,withoutProof);if not withoutProof then a.Platform.GetPlayerOwnerClassObservation=nil end
  assert(a:GetRotationOwnerContext().class=='SHAMAN');assert(s.classCalls==1 and s.levelCalls==1 and s.vehicleCalls==1,'fallback skipped public context')
 end
end)
test('callable unavailable adapter does not borrow a second class query',function()
 local _,a,s=fixture();a.Platform.GetPlayerOwnerClassObservation=function() return nil,'class-data-unavailable' end
 local c,why=a:GetRotationOwnerContext();assert(c==nil and why=='missing-owner-context' and s.classCalls==0)
end)
test('owner class whitelist and optional character validation remain unchanged',function()
 local _,a,s=fixture();s.class='FUTURECLASS';local c,why=a:GetRotationOwnerContext();assert(c==nil and why=='missing-owner-context')
 s.class='SHAMAN';for _,bad in ipairs({'',' ','x\0y',string.rep('a',513),false,1,{}}) do a.db.keys.char=bad;c=assert(a:GetRotationOwnerContext());assert(c.class=='SHAMAN' and c.character==nil) end
 a.db.keys=nil;c=assert(a:GetRotationOwnerContext());assert(c.class=='SHAMAN' and c.character==nil)
end)
local function runtime()
 local h=assert(io.open('tests/rotation_scope_runtime.lua'));local source=h:read('*a');h:close();local prefix=assert(source:match('^(.-)\nlocal function gate'))
 local e,a,events,body,reference,save,load=assert(loadstring(prefix..'\nreturn fixture','@owner-real-runtime'))()()
 local h2=io.open('Platform/rotation_owner.lua');if h2 then h2:close();load('Platform/rotation_owner.lua') end
 e.UnitLevel=function() return 11 end;e.UnitHasVehicleUI=function() return false end
 load('Core/rotation_library.lua');load('Core/rotation_scope.lua');assert(a:InitializeRotationLibrary());assert(a:BindRotationProfile())
 a.currentRotation=assert(a:GetScopedRotationCoordinator():Key(reference))
 return e,a,events,body,reference,save
end
test('actual scoped tick preserves eligibility checks while omitting owner level and vehicle reads',function()
 local e,a,events=runtime();local classes,levels,vehicles=0,0,0
 e.UnitClass=function(...) assert(select('#',...)==1 and (...)=='player');classes=classes+1;return 'Shaman','SHAMAN' end
 e.UnitLevel=function() levels=levels+1;return 11 end;e.UnitHasVehicleUI=function() vehicles=vehicles+1;return false end
 a:EvaluateNextActionInternal();assert(a.currentSpell==403 and #events>0);assert(levels>0 and levels<classes and levels==vehicles,'owner still duplicated all eligibility queries')
end)
test('retained class observation reentrancy cannot publish advice from a replaced profile',function()
 local e,a,events,body,reference=runtime();local arm,changed=false,false
 a:RegisterCondition('OWNER_MUTATION',{fields={},valid=function() return true end,evaluate=function() arm=true;return true end,print=function() return '' end,widget=function() end,help=function() end})
 local record,token=a:GetRotationRecordSnapshot(0,reference);record.body.rotation[1].conditions={type='OWNER_MUTATION'};assert(a:CommitRotationDraft(reference,token,record,'class'))
 e.UnitClass=function() if arm and not changed then changed=true;a.db.profile=a.RotationData.CopyData(a.db.profile);assert(a:BindRotationProfile()) end;return 'Shaman','SHAMAN' end
 a:EvaluateNextActionInternal();assert(changed and #events==0,'retired owner observation published advice')
end)
test('class level and vehicle changes during actual conditions still invalidate staged advice',function()
 for _,kind in ipairs({'class','level','vehicle'}) do
  local e,a,events,_,reference=runtime();local changed=false
  e.UnitClass=function() return 'Ignored',kind=='class' and changed and 'MAGE' or 'SHAMAN' end
  e.UnitLevel=function() return kind=='level' and changed and 12 or 11 end
  e.UnitHasVehicleUI=function() return kind=='vehicle' and changed end
  a:RegisterCondition('OWNER_CONTEXT_CHANGE',{fields={},valid=function() return true end,evaluate=function() changed=true;return true end,print=function() return '' end,widget=function() end,help=function() end})
  local record,token=a:GetRotationRecordSnapshot(0,reference);record.body.rotation[1].conditions={type='OWNER_CONTEXT_CHANGE'};assert(a:CommitRotationDraft(reference,token,record,'class'))
  a:EvaluateNextActionInternal();assert(changed and #events==0,kind..' change published stale advice')
 end
end)
test('public record reads enforce fresh class ownership without consuming eligibility metadata',function()
 local e,a,_,_,reference=runtime();local class='SHAMAN';local calls=0
 e.UnitClass=function(...) assert(select('#',...)==1 and (...)=='player');calls=calls+1;return 'Ignored',class end
 e.UnitLevel=function() error('record ownership consumed level') end;e.UnitHasVehicleUI=function() error('record ownership consumed vehicle') end
 assert(a:GetRotationRecordSnapshot(0,reference).body.name=='Runtime' and calls>0)
 class='MAGE';local record,why=a:GetRotationRecordSnapshot(0,reference);assert(record==nil and why=='foreign-owner')
 class='SHAMAN';assert(a:GetRotationRecordSnapshot(0,reference).body.name=='Runtime')
end)
finish()
