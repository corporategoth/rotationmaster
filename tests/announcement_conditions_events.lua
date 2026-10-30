-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local prefix=assert(read('tests/spell_history_count.lua'):match('^(.-)\nlocal function node'))
 local f,a=assert(loadstring(prefix..'\nreturn fixture()','@announcement-condition-events'))()
 f.load('Core/conditions.lua');f.load('Core/announcements.lua')
 local outputs,checks={},{}
 a.announced={};a.GetSpellIds=function(_,v)return {v.spell}end
 a.announce=function(_,text)outputs[#outputs+1]=text end
 a:RegisterCondition('RECIPIENT',{fields={},valid=function()return true end,evaluate=function(_,cache)checks[#checks+1]=cache.announcementRecipient or 'missing';return cache.announcementRecipient=='Clickcast-Realm' end})
 a.db.profile.announces={{id='a',type='spell',spell=547,event='START',announce='local',value='Message',conditions={type='RECIPIENT'}}}
 return f,a,outputs,checks
end
test('actual cast adapter checks matching event only, exact recipient, and dedup before conditions',function()
 local _,a,outputs,checks=fixture()
 a:UNIT_SPELLCAST_SENT('UNIT_SPELLCAST_SENT','player','Clickcast-Realm','cast-1',547)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',999);assert(#checks==0)
 a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','cast-1',547);assert(#checks==0)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',547);assert(#checks==1 and checks[1]=='Clickcast-Realm' and #outputs==1)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',547);assert(#checks==1 and #outputs==1)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-2',547);assert(checks[2]=='missing' and #outputs==1 and #a.announced.a==1,'prior spell recipient must not leak')
end)
test('false or unavailable condition suppresses sound and message, with legacy no-condition output intact',function()
 local _,a,outputs=fixture();local entry=a.db.profile.announces[1]
 entry.conditions={type='NOT',value={type='MISSING'}};entry.announce_sound='Never';local dispatch=a.DispatchAnnouncement;local sent=0
 a.DispatchAnnouncement=function(...)sent=sent+1;return dispatch(...)end
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',547);assert(sent==0 and #outputs==0 and a.announced.a==nil)
 entry.conditions=nil;entry.announce_sound=nil;a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-2',547);assert(sent==1 and #outputs==1)
end)
test('profile replacement and registry changes during condition callback retire the old event',function()
 local _,a,outputs=fixture();local entry=a.db.profile.announces[1]
 a:RegisterCondition('REPLACE',{fields={},valid=function()return true end,evaluate=function()a.db.profile={announces={}};return true end})
 entry.conditions={type='REPLACE'};a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-1',547);assert(#outputs==0 and a.announced.a==nil)
 a.db.profile.announces={entry};a:RegisterCondition('REGISTER',{fields={},valid=function()return true end,evaluate=function()a:RegisterCondition('NEW',{fields={},valid=function()return true end,evaluate=function()return true end});return true end})
 entry.conditions={type='REGISTER'};a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast-2',547);assert(#outputs==0)
end)
finish()
