local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon
 for _,p in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Core/conditions.lua','Core/condition_catalog.lua','Core/profile_data.lua','init.lua'})do f.load(p)end
 return f,a
end
test('Announcement choices use independent configured list and retain existing unmarked trees',function()
 local f,a=fixture();for _,tag in ipairs({'A','B'})do a:RegisterCondition(tag,{description=tag,fields={},valid=function()return true end,evaluate=function()return true end})end
 a.db.profile={announcement_conditions={'B','UNKNOWN','B'},switch_conditions={'A'},disabled_conditions={'B'},condition_groups={},other_conditions_order={}};a.db.global.custom_conditions={}
 local tags=a:listConditions('ANNOUNCEMENT');assert(tags[1]=='B' and tags[2]=='B' and #tags==6,'Announcement catalog ignored independent list')
 local saved=a.db.profile.announcement_conditions;a.db.profile.announcement_conditions=nil;for _,tag in ipairs(a:listConditions('ANNOUNCEMENT'))do assert(tag~='A','absent Announcement list borrowed Switch')end;a.db.profile.announcement_conditions=saved;assert(a:listConditions('SWITCH')[1]=='A');assert(a:validateCondition({type='A'}));assert(a:evaluateCondition({type='A'}))
 local draft={profile={announcement_conditions={'A'}},global={}};assert(a:listConditions('ANNOUNCEMENT',false,draft)[1]=='A' and a.db.profile.announcement_conditions[1]=='B')
end)
test('closed profile transport accepts detached Announcement string lists and rejects malformed fields',function()
 local _,a=fixture();local p={version=3,announcement_conditions={'COMBAT','CUSTOM'}};assert(a:ValidateProfileTransfer(p),'new profile field rejected')
 local wire=assert(a:ProfileToPortable(p));local round=assert(a:ProfileFromPortable(wire));assert(round.announcement_conditions[2]=='CUSTOM' and round.announcement_conditions~=p.announcement_conditions);round.announcement_conditions[1]='A';assert(p.announcement_conditions[1]=='COMBAT')
 for _,bad in ipairs({false,{true},{[2]='COMBAT'},{named='COMBAT'}})do assert(not a:ValidateProfileTransfer({announcement_conditions=bad}))end
 assert(a:ValidateProfileTransfer({version=3}) and a:ValidateProfileTransfer({announcement_conditions={}}))
end)
test('cold seed is bounded absent-only and callback owner is independent',function()
 local f,a=fixture();local registrations={};local old={announcement_conditions={}};local custom={announcement_conditions={'CUSTOM'}};local missing={};local malformed={announcement_conditions=false}
 local db={profile=missing,sv={profiles={old=old,custom=custom,missing=missing,malformed=malformed}}};db.RegisterCallback=function(owner,event,fn)assert(owner~=a,'callback overwrites addon lifecycle owner');registrations[event]={owner,fn}end;a.db=db
 assert(type(a.InstallAnnouncementConditionPreferences)=='function','missing cold installer');a:InstallAnnouncementConditionPreferences()
 local seeded=missing.announcement_conditions;assert(#seeded<40);for _,tag in ipairs({'AND','OR','NOT','COMBAT','GROUP','ENEMY','DEAD','FRIENDLY'})do assert(a.index(seeded,tag),tag)end
 assert(#old.announcement_conditions==0 and custom.announcement_conditions[1]=='CUSTOM' and malformed.announcement_conditions==false)
 for _,event in ipairs({'OnNewProfile','OnProfileChanged','OnProfileCopied','OnProfileReset'})do local r=assert(registrations[event],event);local fresh={};db.profile=fresh;r[2](event,db);assert(fresh.announcement_conditions and fresh.announcement_conditions~=seeded);fresh.announcement_conditions={};r[2](event,db);assert(#fresh.announcement_conditions==0)end
 local fresh={};db.profile=fresh;a.db={profile={}};local r=registrations.OnProfileChanged;r[2]('OnProfileChanged',db);assert(fresh.announcement_conditions==nil,'old DB callback seeded foreign lifecycle')
end)
test('actual AceDB profile copy reset logout and reload preserve intentional empty lists',function()
 local f,a=fixture();local e=f.env;e.securecallfunction=function(fn,...)return fn(...)end;e.LibStub=nil;e.CreateFrame=function()return{scripts={},RegisterEvent=function()end,SetScript=function(self,key,fn)self.scripts[key]=fn end}end
 e.UnitFactionGroup=function()return'Horde'end;e.GetLocale=function()return'enUS'end;e.UnitClass=function()return'Shaman','SHAMAN'end;e.UnitRace=function()return'Orc','Orc'end;e.GetRealmName=function()return'Realm'end;e.UnitNameUnmodified=function()return'Player'end;e.GetCurrentRegionName=function()return'US'end;e.GetCurrentRegion=function()return 1 end;e.strlenutf8=string.len
 f.load('Libs/LibStub/LibStub.lua');f.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');f.load('Libs/AceDB-3.0/AceDB-3.0.lua')
 local ace=e.LibStub('AceDB-3.0');local defaults={profile={version=3},global={},char={}};local augmented={profile={},global={},char={}};a:augmentDefaults(augmented);assert(augmented.profile.announcement_conditions==nil,'AceDB default would erase intentional empty list')
 local db=ace:New('AnnouncementFlagDB',defaults,true);a.db=db;local oldCallbacks=0;db.RegisterCallback(a,'OnProfileChanged',function()oldCallbacks=oldCallbacks+1 end);a:InstallAnnouncementConditionPreferences();assert(#db.profile.announcement_conditions>8)
 db.profile.announcement_conditions={};db:SetProfile('Other');assert(#db.profile.announcement_conditions>8 and oldCallbacks==1);db:CopyProfile('Default');assert(#db.profile.announcement_conditions==0);db:ResetProfile();assert(#db.profile.announcement_conditions>8);db:SetProfile('Default');assert(#db.profile.announcement_conditions==0)
 ace.frame.scripts.OnEvent(ace.frame,'PLAYER_LOGOUT');assert(type(e.AnnouncementFlagDB.profiles.Default.announcement_conditions)=='table' and #e.AnnouncementFlagDB.profiles.Default.announcement_conditions==0,'logout erased empty list')
 local reloaded=ace:New('AnnouncementFlagDB',defaults,true);a.db=reloaded;a:InstallAnnouncementConditionPreferences();assert(#reloaded.profile.announcement_conditions==0,'reload reseeded intentional empty list')
end)
test('maintenance preserves optional list without inventing a default or stripping unknown tags',function()
 local f,a=fixture();f.load('validate.lua');a.warn=function()end;local list={'CUSTOM','FUTURE'};local p={version=3,announcement_conditions=list};f.env.AnnouncementFlagMaintenance={global={},char={},profiles={Default=p}};a.savedVariableName='AnnouncementFlagMaintenance';a:validate({global={},char={bindings={}},profile={version=3}},true);assert(p.announcement_conditions==list and list[2]=='FUTURE')
end)
if pcall(require,'bit')then test('actual RM Profile codec preserves Announcement eligibility and intentional empty lists',function()
 local _,a=fixture();local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;local codec=assert(data.NewCodec(deps))
 for _,list in ipairs({{'COMBAT','CUSTOM'},{}})do local original={version=3,announcement_conditions=list};local wire=assert(a:ProfileToPortable(original));local text=assert(codec:Encode({format='RM-Profile',version=1,profile=wire}));local decoded=assert(codec:Decode(text)).value;local p=assert(a:ProfileFromPortable(decoded.profile));assert(a:ValidateProfileTransfer(p) and #p.announcement_conditions==#list and p.announcement_conditions~=list);assert((p.announcement_conditions[1]or'')==(list[1]or''))end
end)else print('SKIP compressed profile wire: host native bit dependency unavailable; converters and AceDB covered')end
finish()
