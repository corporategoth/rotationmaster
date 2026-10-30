-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local file=assert(io.open('tests/announcement_macros.lua'));local source=file:read('*a');file:close();local make=assert(loadstring(assert(source:match('^(.-)\ntest%('))..'\nreturn fixture'))()
local function card(i,mode,value)return{id=string.format('%08d-1111-1111-1111-111111111111',i),announce=mode or'local',value=value or tostring(i)}end
local function fixture(cards)
 local f,a,e,o,u=make();f.load('Core/announcement_data.lua');f.load('Platform/announcement_recipient.lua');a.db.profile.announces[1]={id='11111111-1111-1111-1111-111111111111',type='macro',identifier='pull',outputs=cards};return f,a,e,o,u,e.RM_Annouce
end
test('ordered series skips disabled and false or unavailable cards',function()
 local cards={card(1),card(2),card(3),card(4)};cards[2].disabled=true;cards[3].conditions={type='SERIES_UNAVAILABLE'}
 local _,a,_,o,_,run=fixture(cards);a:RegisterCondition('SERIES_UNAVAILABLE',{fields={},valid=function()return true end,evaluate=function()return nil end});assert(a:IsValidAnnouncement(a.db.profile.announces[1]));assert(run('pull').chat);assert(#o==2 and o[1].text=='1' and o[2].text=='4')
end)
test('missing per-card placeholders and supplied absent units retain independent outputs',function()
 local _,_,_,o,_,run=fixture({card(1,'local','{{target}}'),card(2,'local','{{spell}}'),card(3,'local','{{item}}'),card(4)});assert(run('pull','missing').chat and #o==1 and o[1].text=='4')
end)
test('Whisper skips nonplayer or missing unit without suppressing siblings',function()
 local _,_,e,o,_,run=fixture({card(1,'whisper'),card(2)});assert(run('pull').chat and #o==1);e.UnitIsPlayer=function()return false end;assert(run('pull','target').chat and #o==2);assert(o[2].destination=='LOCAL')
end)
test('source sibling mutation aborts stale series after first delivery',function()
 local cards={card(1),card(2)};local _,a,_,o,_,run=fixture(cards);local old=a.announce;a.announce=function(self,v)old(self,v);cards[2].value='mutated'end;run('pull');assert(#o==1)
end)
test('detached card mutation during condition callback cannot deliver',function()
 local _,a,_,o,_,run=fixture({card(1),card(2)});a.AnnouncementConditionMatches=function(_,view)view.value='injected';return true end;run('pull');assert(#o==0)
end)
test('native send error has no retry and independent next output runs',function()
 local _,_,e,o,_,run=fixture({card(1,'say'),card(2)});local n=0;e.C_ChatInfo.SendChatMessage=function()n=n+1;error('refused')end;assert(run('pull').chat and n==1 and #o==1 and o[1].text=='2')
end)
test('channel is macro-only and resolves fresh named membership',function()
 local c=card(1,'channel');c.channel_name='Exact';local _,a,e,o,_,run=fixture({c,card(2)});local slot=4;e.GetChannelName=function(i)return i==slot and i or 0,i==slot and'Exact'or nil end
 assert(run('pull').chat and #o==2 and o[1].destination=='CHANNEL' and o[1].target==4);slot=8;assert(run('pull').chat and o[3].target==8);slot=0;run('pull');assert(#o==5 and o[5].text=='2');assert(not a:DispatchAnnouncement(c,'blocked').chat)
end)
test('absent supplied unit appearance during callback retires remaining series',function()
 local _,a,_,o,u,run=fixture({card(1),card(2)});a.announce=function(_,v)o[#o+1]={text=v};u.missing={name='New',guid='New'}end;run('pull','missing');assert(#o==1)
end)
test('missing target context remains unavailable under NOT while siblings continue',function()
 local c=card(1);c.conditions={type='NOT',value={type='TARGET_CHECK',unit='announcementtarget'}}
 local _,a,_,o,_,run=fixture({c,card(2)});a:RegisterCondition('TARGET_CHECK',{fields={unit='string'},valid=function()return true end,evaluate=function()return false end})
 run('pull','missing');assert(#o==1 and o[1].text=='2')
end)
test('Whisper player eligibility is fresh after native backend getter callbacks',function()
 local _,_,e,o,_,run=fixture({card(1,'whisper'),card(2)});local allowed=true;e.UnitIsPlayer=function()return allowed end
 e.C_ChatInfo=setmetatable({},{__index=function()allowed=false;return function()error('stale player sent')end end})
 run('pull','target');assert(#o==1 and o[1].text=='2')
end)
test('new reentrant macro invocation retires old remaining siblings',function()
 local _,a,_,o,_,run=fixture({card(1),card(2)});a.db.profile.announces[2]={id='99999999-1111-1111-1111-111111111111',type='macro',identifier='newer',outputs={card(3)}}
 local old=a.announce;local once=false;a.announce=function(self,v)old(self,v);if not once then once=true;run('newer')end end
 run('pull');assert(#o==2 and o[1].text=='1' and o[2].text=='3')
end)

test('channel is revalidated after message readability callbacks renumber membership',function()
 local c=card(1,'channel','Unique message');c.channel_name='Exact';local _,a,e,o,_,run=fixture({c,card(2)});local slot=4;e.GetChannelName=function(i)return i==slot and i or 0,i==slot and'Exact'or nil end
 local readable=a.Platform.CanReadValue;local n=0;a.Platform.CanReadValue=function(self,v)if v=='Unique message'then n=n+1;if n==1 then slot=7 end end;return readable(self,v)end
 run('pull');assert(#o==1 and o[1].text=='2','stale channel address sent')
end)

test('channel native observations cannot retire the parent and still send',function()
 local c=card(1,'channel');c.channel_name='Exact';local _,a,e,o,_,run=fixture({c,card(2)});local n=0;e.GetChannelName=function(i)n=n+1;if n==44 then a.db.profile={announces={}}end;return i==4 and 4 or 0,i==4 and'Exact'or nil end
 run('pull');assert(#o==0,'channel observation sent from retired profile')
end)

test('zero and sixty-four cards preserve order while malformed arrays fail closed',function()
 local _,_,_,o,_,run=fixture({});assert(not run('pull').chat and #o==0)
 local cards={};for i=1,64 do cards[i]=card(i)end;local _,a,_,out,_,invoke=fixture(cards);assert(invoke('pull').chat and #out==64 and out[64].text=='64');cards[65]=card(65);assert(not invoke('pull').chat and #out==64);cards[65]=nil;cards.extra=card(66);assert(not invoke('pull').chat)
end)
test('profile registry and sibling condition callbacks retire the parent before output',function()
 for _,kind in ipairs({'profile','registry','sibling'})do
  local cards={card(1),card(2)};local _,a,_,o,_,run=fixture(cards)
  a:RegisterCondition('SERIES_MUTATE',{fields={},valid=function()return true end,evaluate=function()if kind=='profile'then a.db.profile={}elseif kind=='registry'then a.conditionRegistryVersion=a.conditionRegistryVersion+1 else cards[2].value='mutated'end;return true end});cards[1].conditions={type='SERIES_MUTATE'}
  run('pull');assert(#o==0,kind)
 end
end)
test('false reached condition skips only that card and still evaluates later siblings',function()
 local cards={card(1),card(2),card(3)};local _,a,_,o,_,run=fixture(cards);local seen={}
 a:RegisterCondition('SERIES_MATCH',{fields={match='boolean'},valid=function()return true end,evaluate=function(v)seen[#seen+1]=v.match;return v.match end});cards[1].conditions={type='SERIES_MATCH',match=false};cards[2].conditions={type='SERIES_MATCH',match=true};assert(run('pull').chat and #seen==2 and not seen[1] and seen[2] and #o==2 and o[1].text=='2')
end)
test('targeted gestures with no supplied recipient skip the whole card',function()
 local c=card(1,'gesture');c.emote='CHEER';c.emote_target=true;c.announce_sound='Chime';local f,_,e,o,_,run=fixture({c,card(2)});local calls=0;e.DoEmote=function()calls=calls+1 end;e.PlaySoundFile=function()calls=calls+1 end;f.libraries['LibSharedMedia-3.0']={Fetch=function()return'sound.ogg'end};assert(run('pull').chat and #o==1 and calls==0)
end)

local function automatic(cards)
 local h=assert(io.open('tests/spell_history_count.lua'));local src=h:read('*a');h:close();local make=assert(loadstring(assert(src:match('^(.-)\nlocal function node'))..'\nreturn fixture'))();local f,a=make()
 for _,path in ipairs({'Data/validation.lua','Core/announcement_data.lua','Core/announcements.lua','Platform/communication.lua'})do f.load(path)end
 local out={};a.announce=function(_,v)out[#out+1]=v end;a.announced={};a.GetSpellIds=function(_,v)return{v.spell}end
 a.db.profile.announces={{id='11111111-1111-1111-1111-111111111111',type='spell',spell=686,event='START',outputs=cards}}
 return f,a,out
end
test('actual automatic adapter matches once and reserves parent before card callbacks',function()
 local _,a,out=automatic({card(1),card(2)});local old=a.announce;local once=false;a.announce=function(self,v)old(self,v);if not once then once=true;self:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast',686)end end
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast',999);assert(#out==0)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast',686);assert(#out==2 and out[1]=='1' and out[2]=='2');a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast',686);assert(#out==2)
end)
test('automatic series disable during condition callback retires its owner',function()
 local c=card(1);c.conditions={type='DISABLE_SERIES'};local _,a,out=automatic({c,card(2)});local reached=0;a.enabledState=true;a.IsEnabled=function(self)return self.enabledState end
 a:RegisterCondition('DISABLE_SERIES',{fields={},valid=function()return true end,evaluate=function()reached=reached+1;a.enabledState=false;return true end})
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','cast',686);assert(reached==1 and #out==0)
end)
test('automatic series never reuses prior cast target for a missing receipt',function()
 local _,a,out=automatic({card(1,'local','{{target}}'),card(2)})
 a:UNIT_SPELLCAST_SENT('UNIT_SPELLCAST_SENT','player','Exact-Realm','old',686);a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','old',686)
 a:UNIT_SPELLCAST_START('UNIT_SPELLCAST_START','player','new',686);assert(#out==3 and out[1]=='Exact-Realm' and out[3]=='2')
end)

finish()
