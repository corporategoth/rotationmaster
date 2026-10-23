local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function uiFixture()
 local prefix=assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('));local f,parent=assert(loadstring(prefix..'\nreturn fixture()','@actual-settings-fixture'))();f.load('Platform/communication.lua');f.env.MAXEMOTEINDEX=1;f.env.EMOTE1_TOKEN='CHEER';f.env.EMOTE1_CMD1='/cheer';return f,parent
end
test('announcement details cannot collapse and Emote is selectable without blocked chat modes',function()
 local f,parent=uiFixture();local a=f.addon;a.db.profile.announces={{id='a',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Keep'}};local p=a:CreateSettingsForm(parent);p:Open(function(form)a:BuildAnnounceSettings(form)end)
 assert(not p.fields.section_announce1 and p.fields.entry1text,'details must be unconditionally present')
 p.fields.entry1channel:Click();local seen={};for _,row in ipairs(p.menu.rows)do seen[row:GetText()]=row end;assert(not seen.Say and not seen.Yell and seen.Emote);seen.Emote:Click()
 assert(p.fields.entry1emote and p.fields.entry1emote_target and not p.fields.entry1text and a.db.profile.announces[1].value=='Keep')
 p.fields.entry1emote:Click();p.menu.rows[1]:Click();p.fields.entry1emote_target:Click();assert(a.db.profile.announces[1].emote=='CHEER' and a.db.profile.announces[1].emote_target==true)
 local stale=p.fields.entry1emote_target.scripts.OnClick;p:Release();stale();assert(a.db.profile.announces[1].emote_target==true)
end)
test('named-emote transfer retains token recipient option and dormant text through codec',function()
 local f=uiFixture();local a=f.addon;local entry={id='12345678-1234-1234-1234-123456789abc',type='spell',spell=403,event='SUCCEEDED',announce='gesture',emote='CHEER',emote_target=true,value='Dormant'}
 local codec=a:NewRotationCodec();local wire=assert(codec:Encode({format='RM-Announcement',version=1,announcement=entry}));local decoded=assert(codec:Decode(wire)).value.announcement
 assert(a:IsValidAnnouncement(decoded,true) and decoded.emote=='CHEER' and decoded.emote_target and decoded.value=='Dormant')
end)
test('emote draft Apply and Discard retain transaction boundaries',function()
 local f,parent=uiFixture();local a=f.addon;a.db.profile.announces={{id='a',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Keep'}}
 local p=a:OpenNativeSettings(parent,'Announces');p.fields.entry1channel:Click();for _,row in ipairs(p.menu.rows)do if row:GetText()=='Emote'then row:Click();break end end;p.fields.entry1emote:Click();p.menu.rows[1]:Click();p.fields.entry1emote_target:Click()
 assert(a.db.profile.announces[1].announce=='local' and p:IsSettingsDraftDirty());p.fields.cancel:Click();assert(a.db.profile.announces[1].announce=='local' and not p:IsSettingsDraftDirty())
 p.fields.entry1channel:Click();for _,row in ipairs(p.menu.rows)do if row:GetText()=='Emote'then row:Click();break end end;p.fields.entry1emote:Click();p.menu.rows[1]:Click();p.fields.entry1emote_target:Click();p.fields.apply:Click()
 assert(a.db.profile.announces[1].announce=='gesture' and a.db.profile.announces[1].emote=='CHEER' and a.db.profile.announces[1].emote_target)
end)
test('announcement comparison shows named emote and cast-recipient changes',function()
 local f=uiFixture();local a=f.addon;local rows=a:CollectionComparisonRows('announcement',{announce='gesture',emote='CHEER',emote_target=false},{announce='gesture',emote='WAVE',emote_target=true},false)
 assert(#rows==2 and rows[1].label=='Emote' and rows[1].left=='CHEER' and rows[1].right=='WAVE' and rows[2].label=='Use spell recipient ({{target}})')
end)
test('Announces has local Help with substitutions and no pending-edit flush',function()
 local f,parent=uiFixture();local a=f.addon;a.db.profile.announces={{id='a',type='spell',spell=403,event='SUCCEEDED',announce='local',value='Cast'}};local p=a:OpenNativeSettings(parent,'Announces')
 assert(p.fields.announce_help,'missing page-level Help');local input=p.fields.entry1text;input:SetText('Pending {{target}}');input.scripts.OnTextChanged(input,true)
 p.fields.announce_help:Click();assert(a.helpWindow and a.helpWindow.heading=='Announces' and a.db.profile.announces[1].value=='Cast' and input:GetText()=='Pending {{target}}')
 local content='';for _,row in ipairs(a.helpWindow.sections)do content=content..row.text end;for _,token in ipairs({'{{target}}','{{spell}}','{{item}}','{{event}}'})do assert(content:find(token,1,true),'missing '..token)end
 local opens=0;local old=a.ShowWorkbenchHelp;a.ShowWorkbenchHelp=function(...)opens=opens+1;return old(...)end;local stale=p.fields.announce_help.scripts.OnClick;p:Release();stale();assert(opens==0)
end)
test('the Announces page has no emote test or report buttons',function()
 local f,parent=uiFixture();f.load('Core/announcements.lua');local a,e=f.addon,f.env
 local calls=0;e.C_ChatInfo={PerformEmote=function()calls=calls+1;return false end}
 a.db.profile.announces={{id='a',type='spell',spell=547,event='START',announce='local',value='Saved'}}
 local p=a:OpenNativeSettings(parent,'Announces')
 assert(not p.fields.emote_test and not p.fields.emote_report and calls==0,'debug emote controls are still drawn')
 for _,row in ipairs(a:WorkbenchPageHelp('Announces'))do assert(row.id~='diagnostics','emote diagnostics still has page Help')end
 assert(type(a.TestAnnouncementEmote)=='function' and type(a.GetAnnouncementEmoteReport)=='function','emote diagnostic API removed')
end)
test('saved unsupported chat remains editable without offering Say or Yell',function()
 local f,parent=uiFixture();local a=f.addon;a.db.profile.announces={{id='a',type='spell',spell=547,event='START',announce='say',value='Keep'}}
 local p=a:OpenNativeSettings(parent,'Announces');p.fields.entry1channel:Click()
 for _,row in ipairs(p.menu.rows) do assert(row:GetText()~='Say' and row:GetText()~='Yell');if row:GetText()=='Local Only' then row:Click();break end end
 assert(a.db.profile.announces[1].announce=='say','must remain staged');p.fields.apply:Click()
 assert(a.db.profile.announces[1].announce=='local' and a.db.profile.announces[1].value=='Keep')
end)
finish()
