local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local uuid='61b36ed1-fa31-4656-ad71-f3d50f193a85'
local function repairFixture()
 local f=F.new();local a=f.addon;f.load('validate.lua')
 local warnings={};a.warn=function(_,format,...)warnings[#warnings+1]=string.format(format,...)end
 a.events={SUCCEEDED=true,START=true}
 return a,warnings
end
local function macro()return {id=uuid,type='macro',identifier='REZ',name='Rez',announce='whisper',value='Rezzing {{target}}'} end
local function series()return {id=uuid,type='macro',identifier='REZ',outputs={{id='22222222-2222-2222-2222-222222222222',announce='say',value='Ready'},{id='33333333-3333-3333-3333-333333333333',announce='channel',channel_name='Trade',value='Ready'}}} end
local function emote()return {id=uuid,type='spell',spell=403,event='SUCCEEDED',announce='gesture',emote='CHEER',emote_target=true} end
test('repair and check leave valid macro, series and emote announcements untouched',function()
 for _,make in ipairs({macro,series,emote})do
  for _,fix in ipairs({false,true})do
   local a,warnings=repairFixture();local v=make();assert(a:IsValidAnnouncement(v),'fixture must be valid')
   local before=a:CopySettingsData(v);a:validate_announce('fixture',1,v,fix)
   assert(a:SettingsDataEqual(v,before),'repair rewrote a valid announcement');assert(#warnings==0,warnings[1])
  end
 end
end)
test('an invalid macro announcement is preserved and disabled, never deleted',function()
 for _,make in ipairs({macro,series})do
  local a,warnings=repairFixture();local v=make();v.identifier='bad identifier'
  local before=a:CopySettingsData(v);a:validate_announce('fixture',1,v,false);assert(a:SettingsDataEqual(v,before) and #warnings==1,'check must not write')
  a:validate_announce('fixture',1,v,true);before.disabled=true;assert(a:SettingsDataEqual(v,before),'repair deleted or rewrote macro announcement')
 end
end)
local function castFixture()
 local prefix=assert(read('tests/spell_history_count.lua'):match('^(.-)\nlocal function node'))
 local f,a=assert(loadstring(prefix..'\nreturn fixture()','@announcement-repair'))()
 f.load('Core/conditions.lua');f.load('Core/announcements.lua')
 local outputs={};a.announced={};a.GetSpellIds=function(_,v)return {v.spell}end
 a.announce=function(_,text)outputs[#outputs+1]=text end
 return a,outputs
end
test('an announcement without an event is skipped and later announcements still fire',function()
 local a,outputs=castFixture()
 a.db.profile.announces={{id='x',type='spell',spell=547,announce='local',value='Broken'},{id='a',type='spell',spell=547,event='START',announce='local',value='Message'}}
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',547)
 assert(#outputs==1 and a.announced.x==nil and a.announced.a,'event-less announcement broke the cast handler')
end)
finish()
