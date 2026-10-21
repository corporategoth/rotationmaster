local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();f.load('Platform/announcement_recipient.lua');local rows={[1]='General - City',[4]='Guild Talk'};local calls={}
 f.env.GetChannelName=function(i)calls[#calls+1]=i;return rows[i] and i or 0,rows[i]end
 return f,f.addon.Platform,rows,calls
end
test('joined channels are detached exact names from bounded native slots',function()
 local _,p,rows,calls=fixture();local out=p:GetJoinedAnnouncementChannels();assert(#out==2 and out[2].value=='Guild Talk');out[1].value='changed';assert(rows[1]=='General - City');assert(#calls==20 and calls[20]==20)
end)
test('resolution witnesses exact names and fresh local numbering',function()
 local _,p,rows=fixture();local id,current=p:ResolveAnnouncementChannel('Guild Talk',function()return true end);assert(id==4 and current());rows[4]=nil;rows[7]='Guild Talk';assert(not current());local fresh=p:ResolveAnnouncementChannel('Guild Talk',function()return true end);assert(fresh==7)
end)
test('missing ambiguous numeric-looking names and errors fail closed',function()
 local f,p,rows=fixture();assert(not p:ResolveAnnouncementChannel('Guild',function()return true end));assert(not p:ResolveAnnouncementChannel('4',function()return true end));rows[8]='Guild Talk';assert(not p:ResolveAnnouncementChannel('Guild Talk',function()return true end));f.env.GetChannelName=function()error('unavailable')end;assert(not p:GetJoinedAnnouncementChannels())
end)
test('API and owner retirement during native scans cannot publish a witness',function()
 local f,p=fixture();local old=f.env.GetChannelName;f.env.GetChannelName=function(i)f.env.GetChannelName=old;return old(i)end;assert(not p:ResolveAnnouncementChannel('Guild Talk',function()return true end));local live=true;f.env.GetChannelName=function(i)live=false;return old(i)end;assert(not p:ResolveAnnouncementChannel('Guild Talk',function()return live end))
end)
test('later scan slots cannot silently renumber an already observed channel',function()
 local f,p,rows=fixture();local id,current=p:ResolveAnnouncementChannel('Guild Talk',function()return true end);assert(id==4);local original=f.env.GetChannelName
 f.env.GetChannelName=function(i)local id,name=original(i);if i==20 then rows[4]=nil;rows[7]='Guild Talk'end;return id,name end
 -- Resolve under a stable API whose later slots mutate the selected earlier one.
 rows[4]='Guild Talk';rows[7]=nil;assert(not p:ResolveAnnouncementChannel('Guild Talk',function()return true end))
end)

finish()
