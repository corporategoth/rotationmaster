local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local f=F.new();f.load('Platform/communication.lua');f.load('Core/announcements.lua')
 f.env.MAXEMOTEINDEX=3;f.env.EMOTE1_TOKEN='CHEER';f.env.EMOTE1_CMD1='/cheer';f.env.EMOTE2_TOKEN='WAVE';f.env.EMOTE2_CMD1='/wave';f.env.EMOTE3_TOKEN='CHEER';f.env.EMOTE3_CMD1='/cheer'
 return f,f.addon,f.env
end
test('named emote list uses current client commands and detached unique choices',function()
 local _,a=fixture();local rows=a.Platform:GetAnnouncementEmotes();assert(#rows==2 and rows[1].value=='CHEER' and rows[1].text=='/cheer');rows[1].value='BAD';assert(a.Platform:GetAnnouncementEmotes()[1].value=='CHEER')
end)
test('named emotes send exact cast recipient and explicit empty target without chat',function()
 local _,a,e=fixture();local calls={};e.C_ChatInfo={PerformEmote=function(...)calls[#calls+1]={...} end,SendChatMessage=function()error('text chat not requested')end};e.UnitName=function()error('must not query selected target')end
 local result=a:DispatchAnnouncement({announce='gesture',emote='CHEER',emote_target=true},nil,'Clickcast-Realm');assert(result.chat and #calls==1 and calls[1][1]=='CHEER' and calls[1][2]=='Clickcast-Realm')
 result=a:DispatchAnnouncement({announce='gesture',emote='WAVE'},nil,'Ignored');assert(result.chat and calls[2][2]=='','targetless must not use client default target')
 result=a:DispatchAnnouncement({announce='gesture',emote='CHEER',emote_target=true},nil,nil);assert(not result.chat and #calls==2,'missing cast recipient must not guess')
end)
test('named emote rejection never falls back and sound remains independent',function()
 local _,a,e=fixture();local fallback=0;e.DoEmote=function()fallback=fallback+1 end;e.C_ChatInfo={PerformEmote=function()error('restricted')end}
 assert(not a:DispatchAnnouncement({announce='gesture',emote='CHEER'},nil).chat and fallback==0)
 e.C_ChatInfo=nil;assert(a:DispatchAnnouncement({announce='gesture',emote='CHEER'},nil).chat and fallback==1)
 assert(not a:DispatchAnnouncement({announce='gesture',emote='NOT_IN_CLIENT'},nil).chat and fallback==1)
 local secret={};e.issecretvalue=function(v)return v==secret end;assert(not a:DispatchAnnouncement({announce='gesture',emote='CHEER',emote_target=true},nil,secret).chat and fallback==1)
end)
test('named-emote failure still permits independently configured sound',function()
 local f,a,e=fixture();local sounds=0;e.C_ChatInfo={PerformEmote=function()error('not allowed')end};e.PlaySoundFile=function()sounds=sounds+1;return true end
 f.libraries['LibSharedMedia-3.0']={Fetch=function()return 'sound.ogg'end}
 local result=a:DispatchAnnouncement({announce='gesture',emote='CHEER',announce_sound='Chime'},nil);assert(not result.chat and result.sound and sounds==1)
end)
test('restricted emote mode is rejected through the existing destination readability gate',function()
 local _,a,e=fixture();local mode={};e.issecretvalue=function(v)return v==mode end;e.C_ChatInfo={PerformEmote=function()error('must not send')end}
 local result=a:DispatchAnnouncement({announce=mode,emote='CHEER'},nil);assert(not result.chat and result.chatReason=='invalid-destination')
end)
test('named emote schema accepts entries without text and rejects malformed controls',function()
 local _,a=fixture();local v={type='spell',spell=403,event='SUCCEEDED',announce='gesture',emote='CHEER',emote_target=true};assert(a:IsValidAnnouncement(v));v.emote='';assert(not a:IsValidAnnouncement(v));v.emote='CHEER';v.emote_target='target';assert(not a:IsValidAnnouncement(v));v.emote_target=false;assert(a:IsValidAnnouncement(v));v.announce='emote';v.value='legacy custom text';assert(a:IsValidAnnouncement(v),'legacy text must remain accepted')
end)
test('actual cast event routes clickcast recipient across success and stop without stale spell fallback',function()
 local prefix=assert(read('tests/spell_history_count.lua'):match('^(.-)\nlocal function node'));local make=assert(loadstring(prefix..'\nreturn fixture','@actual-cast-events'))();local f,a=make();f.load('Platform/communication.lua');f.load('Core/announcements.lua');local e=f.env;e.MAXEMOTEINDEX=1;e.EMOTE1_TOKEN='CHEER';e.EMOTE1_CMD1='/cheer';a.announced={};a.GetSpellIds=function(_,v)return {v.spell}end
 local calls={};e.C_ChatInfo={PerformEmote=function(token,target)calls[#calls+1]={token,target}end};e.UnitName=function()error('must not query target')end
 a.db.profile.announces={{id='success',type='spell',spell=547,event='SUCCEEDED',announce='gesture',emote='CHEER',emote_target=true},{id='stop',type='spell',spell=547,event='STOP',announce='gesture',emote='CHEER',emote_target=true}}
 a:UNIT_SPELLCAST_SENT('UNIT_SPELLCAST_SENT','player','Healed-Realm','Cast-1',547);a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','Cast-1',547);a:UNIT_SPELLCAST_STOP('UNIT_SPELLCAST_STOP','player','Cast-1',547)
 assert(#calls==2 and calls[1][2]=='Healed-Realm' and calls[2][2]=='Healed-Realm')
 a:UNIT_SPELLCAST_SUCCEEDED('UNIT_SPELLCAST_SUCCEEDED','player','Cast-2',547);assert(#calls==2,'prior cast recipient is not proof of this recipient')
end)
test('strict main inverse accepts only exact event additions and preserves the predecessor',function()
 local source=read('main.lua');local inverse=dofile('tests/fixtures/restore_announcement_emotes.lua');local restored=inverse(source,'main.lua');assert(#restored==87884 and not restored:find('self:DispatchAnnouncement(ent,nil,currentSpells[castguid])',1,true))
 assert(not pcall(inverse,source..' ','main.lua'));local changed=source:gsub('currentSpells%[castguid%]%)','lastCastTarget[spellid])',1);assert(changed~=source and not pcall(inverse,changed,'main.lua'))
end)
finish()
