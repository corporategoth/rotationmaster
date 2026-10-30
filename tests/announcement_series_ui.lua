-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local prefix=assert(read('tests/settings_pages.lua'):match('^(.-)\ntest%('))
 prefix=prefix:gsub("    local codecData,codecDeps=[^\n]+\n",[[    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/diff.lua','Data/import_session.lua'})do f.load(path)end
    a.NewRotationCodec=function()local data,deps=dofile('tests/fixtures/codec.lua')();return data.NewCodec(deps)end
]])
 local f,parent=assert(loadstring(prefix..'\nreturn fixture()','@series-settings-fixture'))();local a=f.addon
 -- Author-only dependency overlay. Integrated runs use their local schema.
 if not a.IsValidAnnouncementOutput then f.load('/home/prez/Documents/Codex/2026-10-17/i-x20/outputs/announcement-series-schema-ui/Core/announcement_data.lua') end
 local serial=1000;a.uuid=function()serial=serial+1;return string.format('%08x-1111-1111-1111-111111111111',serial)end
 return f,a,parent
end
local function id(n)return string.format('%08x-1111-1111-1111-111111111111',n)end
local function card(n,text,mode)return{id=id(n),announce=mode or 'local',value=text or ''}end
local function entry(outputs)return{id=id(1),type='spell',spell=403,event='SUCCEEDED',outputs=outputs}end
local function open(a,parent,value)a.db.profile.announces={value};return a:OpenNativeSettings(parent,'Announces')end
local function data(p)return p:SettingsData().profile.announces[1]end
local function view(p)return assert(p.ordered and p.ordered.announce_outputs_entry1,'missing ordered output cards')end
local function choose(p,key,value)
 assert(p.fields[key],key):Click();assert(p.menu and p.menu.frame:IsShown(),'selector not opened')
 for _,row in ipairs(p.menu.rows)do if row.menuEntry and row.menuEntry.value==value then row:Click();return end end
 error('missing choice '..value)
end
test('legacy entry renders one full virtual card without normalizing or dirtying draw',function()
 local _,a,parent=fixture();local old={id=id(1),type='spell',spell=403,event='SUCCEEDED',announce='local',value='Legacy'}
 local before=a:CopySettingsData(old);local p=open(a,parent,old)
 assert(#view(p).rows==1 and view(p).rows[1].body:IsShown())
 assert(p.fields.entry1channel and p.fields.entry1conditions and p.fields.entry1text)
 assert(not data(p).outputs and not p:IsSettingsDraftDirty()and a:SettingsDataEqual(old,before))
 p:Draw();assert(not p:IsSettingsDraftDirty()and not data(p).outputs)
end)
test('series has global trigger and always expanded independent destination fields',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'One'),card(3,'Two','partyraid')}));local v=view(p)
 assert(#v.rows==2 and v.rows[1].body:IsShown()and v.rows[2].body:IsShown())
 assert(p.fields.entry1type:GetParent()==p.child and p.fields.entry1event:GetParent()==p.child)
 assert(p.fields.entry1text:GetParent()==v.rows[1].body and p.fields.entry1output2text:GetParent()==v.rows[2].body)
 assert(p.fields.entry1output1help and p.fields.entry1output1duplicate and p.fields.entry1output2remove)
 assert(not p:IsSettingsDraftDirty())
end)
test('legacy add normalizes only its detached draft and duplicates use independent UUIDs',function()
 local _,a,parent=fixture();local saved={id=id(1),type='macro',identifier='REZ',announce='say',value='Ready'};local p=open(a,parent,saved)
 p.fields.entry1add_output:Click();local current=data(p)
 assert(#current.outputs==2 and current.announce==nil and current.value==nil and current.outputs[1].value=='Ready')
 assert(saved.outputs==nil and saved.value=='Ready'and current.outputs[1].id~=current.outputs[2].id)
 p.fields.entry1output1duplicate:Click();current=data(p)
 assert(#current.outputs==3 and current.outputs[1].id~=current.outputs[2].id and current.outputs[2].value=='Ready')
 p.fields.cancel:Click();assert(a.db.profile.announces[1].outputs==nil and not p:IsSettingsDraftDirty())
end)
test('ordered arrows and drag reorder whole cards then permit deleting to an empty series',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A'),card(3,'B'),card(4,'C')}))
 p.fields.entry1output3up:Click();assert(data(p).outputs[2].value=='C')
 view(p):BeginDrag(1);assert(view(p):Drop(4));assert(data(p).outputs[3].value=='A')
 while #data(p).outputs>0 do p.fields.entry1output1remove:Click()end
 assert(a:IsValidAnnouncement(data(p))and #a.db.profile.announces[1].outputs==3)
 p.fields.apply:Click();assert(#a.db.profile.announces[1].outputs==0)
end)
test('macro-only destinations remain visible invalid after trigger change without deleting cards',function()
 local _,a,parent=fixture();local value={id=id(1),type='macro',identifier='REZ',outputs={card(2,'Message','say')}};local p=open(a,parent,value)
 choose(p,'entry1channel','whisper');assert(data(p).outputs[1].announce=='whisper')
 choose(p,'entry1type','spell');assert(data(p).outputs[1].announce=='whisper'and view(p).rows[1].rmInvalid)
 p.fields.entry1channel:Click();for _,row in ipairs(p.menu.entries)do assert(row.value~='say'and row.value~='yell'and row.value~='channel')end
end)
test('joined channel choices query only on open and retain unjoined stored names',function()
 local _,a,parent=fixture();local n=0;a.Platform.GetJoinedAnnouncementChannels=function(_,current)n=n+1;assert(current());return{{value='Trade - City',text='Trade - City'}}end
 local output=card(2,'Message','channel');output.channel_name='Old Channel'
 local p=open(a,parent,{id=id(1),type='macro',identifier='REZ',outputs={output}})
 assert(n==0 and p.fields.entry1channel_name:GetText():find('Old Channel',1,true))
 choose(p,'entry1channel_name','Trade - City');assert(n==1 and data(p).outputs[1].channel_name=='Trade - City')
 assert(a.db.profile.announces[1].outputs[1].channel_name=='Old Channel')
end)
test('conditions edit only their own card and retire on replacement or trigger kind change',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A'),card(3,'B')}));local pending
 a.ShowConditionEditor=function(_,_,_,draft,callback,current,options)pending={draft=draft,callback=callback,current=current,options=options}end
 p.fields.entry1conditions:Click();assert(pending.current()and pending.options.announcementTarget)
 pending.draft.type='AND';pending.draft.value={};pending.callback(true)
 assert(data(p).outputs[1].conditions.type=='AND'and not data(p).outputs[2].conditions)
 p.fields.entry1conditions:Click();local stale=pending;data(p).outputs[1]=card(9,'Replacement');assert(not stale.current());stale.callback(true)
 assert(not data(p).outputs[1].conditions)
 p:Draw();p.fields.entry1output2conditions:Click();stale=pending;data(p).type='macro';assert(not stale.current());stale.callback(true)
 assert(not data(p).outputs[2].conditions)
end)
test('new output callbacks cannot edit a replaced parent and card Help does not flush or dirty',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));local help=p.fields.entry1output1help
 local flush=p.FlushEdits;p.FlushEdits=function()error('Help flushed draft')end;help:Click();assert(a.helpWindow and a.helpWindow.frame:IsShown()and not p:IsSettingsDraftDirty());p.FlushEdits=flush
 local old=p.fields.entry1output1remove:GetScript('OnClick');local replacement=entry({card(8,'New')});p:SettingsData().profile.announces[1]=replacement;old();assert(#replacement.outputs==1)
 p:Draw();local query;a.Platform.GetJoinedAnnouncementChannels=function()query=true;p:Release();return{{value='Trade',text='Trade'}}end
 replacement.type='macro';replacement.identifier='REZ';replacement.spell=nil;replacement.event=nil;replacement.outputs[1].announce='channel';replacement.outputs[1].channel_name='Trade';p:Draw()
 p.fields.entry1channel_name:Click();assert(query and not p.active and(not p.menu or not p.menu.frame:IsShown()))
end)
test('comparison describes ordered card changes without leaking identities or table addresses',function()
 local _,a=fixture();local left=entry({card(2,'A'),card(3,'B')});local right=a:CopySettingsData(left);right.outputs[2].value='Changed';right.outputs[2].channel_name='Guild Events'
 local rows,count=a:CollectionComparisonRows('announcement',left,right,false)
 local text='';for _,row in ipairs(rows)do text=text..row.label..' '..row.left..' '..row.right..'\n'end
 assert(count==2 and text:find('Output 2',1,true)and text:find('Changed',1,true)and text:find('Guild Events',1,true)and not text:find('table:',1,true)and not text:find(id(3),1,true))
 right.outputs={right.outputs[2],right.outputs[1]};rows,count=a:CollectionComparisonRows('announcement',left,right,false);assert(count>=2)
end)
test('whole announcement duplicate regenerates all card identities and macro identifier',function()
 local _,a,parent=fixture();local value={id=id(1),type='macro',identifier='REZ',outputs={card(2,'A'),card(3,'B')}};local p=open(a,parent,value)
 p.fields.duplicate:Click();local copy=p:SettingsData().profile.announces[2]
 assert(copy.id~=value.id and copy.identifier~='REZ'and copy.outputs[1].id~=value.outputs[1].id and copy.outputs[2].id~=value.outputs[2].id and copy.outputs[1].id~=copy.outputs[2].id and copy.outputs[2].value=='B')
 assert(#a.db.profile.announces==1)
end)
test('64 output limit blocks add and duplicate while preserving delete and edits',function()
 local _,a,parent=fixture();local outputs={};for i=1,64 do outputs[i]=card(i+10,tostring(i))end;local p=open(a,parent,entry(outputs))
 assert(not p.fields.entry1add_output:IsEnabled()and not p.fields.entry1output1duplicate:IsEnabled())
 p.fields.entry1add_output:Click();p.fields.entry1output1duplicate:Click();assert(#data(p).outputs==64)
 p.fields.entry1output1remove:Click();assert(#data(p).outputs==63 and p.fields.entry1add_output:IsEnabled())
end)
test('source channel replacement during query cannot publish a stale menu',function()
 local _,a,parent=fixture();local output=card(2,'A','channel');output.channel_name='Trade';local p=open(a,parent,{id=id(1),type='macro',identifier='REZ',outputs={output}})
 a.Platform.GetJoinedAnnouncementChannels=function()data(p).outputs[1]=card(3,'Replacement');return{{value='Trade',text='Trade'}}end
 p.fields.entry1channel_name:Click();assert(not p.menu or not p.menu.frame:IsShown());assert(data(p).outputs[1].value=='Replacement')
end)
test('retirement during new output identity creation cannot append to an obsolete draft',function()
 for _,key in ipairs({'entry1add_output','entry1output1duplicate'})do
  local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));local old=data(p);a.uuid=function()p:Release();return id(99)end
  p.fields[key]:Click();assert(not p.active and #old.outputs==1,'retired output operation wrote after UUID callback')
 end
end)

test('shared transfer old success or failure cannot hide or overwrite a newer request',function()
 for _,success in ipairs({true,false})do
  local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));local newer
  local d=a:ShowSettingsTextTransfer(p,'Old','old',function()newer=a:ShowSettingsTextTransfer(p,'New','new bytes',function()return true end);return success,'OLD failure'end)
  d.apply:Click();assert(newer==d and d.frame:IsShown()and d.input:GetText()=='new bytes'and not d.status:GetText():find('OLD failure',1,true),'retired shared transfer changed newest request')
 end
end)
test('same-table parent and output UUID changes retire condition editor ownership',function()
 for _,changeParent in ipairs({false,true})do
  local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));local child
  a.ShowConditionEditor=function(_,_,_,draft,callback,current)child={draft=draft,callback=callback,current=current}end
  p.fields.entry1conditions:Click();if changeParent then data(p).id=id(44)else data(p).outputs[1].id=id(44)end
  assert(not child.current());child.draft.type='AND';child.draft.value={};child.callback(true);assert(not data(p).outputs[1].conditions)
 end
end)
test('whole series duplicate stops before further identities after callback retirement',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A'),card(3,'B')}));local values=p:SettingsData().profile.announces;local count=0
 a.uuid=function()count=count+1;p:Release();return id(99)end;p.fields.duplicate:Click();assert(#values==1 and count==1)
end)
test('emote catalog retirement stops obsolete card control construction',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));data(p).outputs[1].announce='gesture';data(p).outputs[1].emote='CHEER'
 a.Platform.GetAnnouncementEmotes=function()p:Release();return{{value='CHEER',text='Cheer'}}end
 p:Draw();assert(not p.active and not p.fields.entry1emote_target and not p.fields.entry1output1duplicate,'obsolete card continued after provider retirement')
end)

test('shared transfer rechecks request after optional validity callback',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'A')}));local reenter=false;local applied=0
 local d=a:ShowSettingsTextTransfer(p,'Old','old',function()applied=applied+1;return true end,{originalName=function()return'Old'end,valid=function()
  if reenter then reenter=false;a:ShowSettingsTextTransfer(p,'New','new bytes',function()return true end)end;return true
 end})
 reenter=true;d.apply:Click();assert(applied==0 and d.frame:IsShown()and d.input:GetText()=='new bytes')
end)

test('explicit legacy Channel choice converts only draft while retaining text and conditions',function()
 local _,a,parent=fixture();local value={id=id(1),type='macro',identifier='REZ',announce='local',value='Keep',conditions={type='AND',value={}}};local p=open(a,parent,value)
 a.Platform.GetJoinedAnnouncementChannels=function()return{{value='Guild Events',text='Guild Events'}}end
 choose(p,'entry1channel','channel');local current=data(p)
 assert(current.outputs and #current.outputs==1 and current.outputs[1].announce=='channel'and current.outputs[1].value=='Keep'and current.outputs[1].conditions.type=='AND'and current.value==nil and current.conditions==nil)
 assert(not value.outputs and value.announce=='local');choose(p,'entry1channel_name','Guild Events');p.fields.apply:Click()
 assert(a.db.profile.announces[1].outputs[1].channel_name=='Guild Events')
end)
test('legacy macro-only destination cannot save after explicit automatic kind change',function()
 local _,a,parent=fixture();local value={id=id(1),type='macro',identifier='REZ',announce='say',value='Keep'};local p=open(a,parent,value)
 choose(p,'entry1type','spell');local current=data(p);current.spell=403;p:Draw();assert(view(p).rows[1].rmInvalid)
 p.fields.apply:Click();assert(value.type=='macro'and current.outputs and current.outputs[1].announce=='say'and not a:IsValidAnnouncement(current))
end)

test('ordinary text and name edits remain usable by whole-announcement Duplicate',function()
 for _,enter in ipairs({true,false})do
  local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'Before')}))
  for key,value in pairs({entry1text='Edited',entry1name='Renamed'})do local input=p.fields[key];input:SetText(value);input:GetScript('OnTextChanged')(input,true);if enter then input:GetScript('OnEnterPressed')(input)end end
  p.fields.duplicate:Click();local values=p:SettingsData().profile.announces
  assert(#values==2 and values[2].outputs[1].value=='Edited'and values[2].name=='Renamed'and values[2].outputs[1].id~=values[1].outputs[1].id)
  assert(#a.db.profile.announces==1 and a.db.profile.announces[1].outputs[1].value=='Before')
 end
end)
test('ordinary text and rename edits export latest values and retain Replace import ownership',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'Before')}));local exported
 for key,value in pairs({entry1text='Edited',entry1name='Renamed'})do local input=p.fields[key];input:SetText(value);input:GetScript('OnTextChanged')(input,true);input:GetScript('OnEnterPressed')(input)end
 a.NewRotationCodec=function()return{Encode=function(_,wrapper)exported=a:CopySettingsData(wrapper);return'encoded latest'end,Decode=function()local incoming=entry({card(3,'Imported')});incoming.name='Source name';return{value={format='RM-Announcement',version=2,announcement=incoming}}end}end
 p.fields.transfer:Click();local d=assert(p.textDialog,'edited source could not open export')
 assert(d.frame:IsShown()and exported.announcement.outputs[1].value=='Edited'and exported.announcement.name=='Renamed'and d.name:GetText()=='Renamed')
 d.apply:Click();assert(data(p).name=='Renamed'and data(p).outputs[1].value=='Imported'and not d.frame:IsShown())
 assert(a.db.profile.announces[1].outputs[1].value=='Before')
end)

test('operation baseline still rejects source value mutation during UUID or Decode callbacks',function()
 local _,a,parent=fixture();local p=open(a,parent,entry({card(2,'Before')}));local values=p:SettingsData().profile.announces
 a.uuid=function()data(p).outputs[1].value='Changed during duplicate';return id(99)end
 p.fields.duplicate:Click();assert(#values==1 and values[1].outputs[1].value=='Changed during duplicate')
 p:Draw();local replace=false;a.NewRotationCodec=function()return{Encode=function()return'encoded'end,Decode=function()if replace then data(p).outputs[1].value='Changed during import'end;return{value={format='RM-Announcement',version=2,announcement=entry({card(3,'Imported')})}}end}end
 p.fields.transfer:Click();replace=true;p.textDialog.apply:Click();assert(values[1].outputs[1].value=='Changed during import'and p.textDialog.frame:IsShown())
end)

if pcall(require,'bit') then
test('real codec exports v2 series and imports fresh child identities while v1 remains legacy only',function()
 local _,a,parent=fixture();local value=entry({card(2,'A'),card(3,'B')});local p=open(a,parent,value);local codec=a:NewRotationCodec()
 p.fields.transfer:Click();local d=p.textDialog;local encoded=d.input:GetText();local decoded=assert(codec:Decode(encoded));assert(decoded.value.version==2 and decoded.value.announcement.outputs[2].value=='B')
 d.apply:Click();local imported=data(p);assert(imported.id==value.id and imported.outputs[1].id~=value.outputs[1].id and imported.outputs[2].id~=value.outputs[2].id)
 p.fields.transfer:Click();d=p.textDialog;local invalid=a:CopySettingsData(decoded.value);invalid.version=1;d.input:SetText(assert(codec:Encode(invalid)));d.apply:Click();assert(d.frame:IsShown()and data(p).outputs[1].id==imported.outputs[1].id)
 local legacy={format='RM-Announcement',version=2,announcement={id=id(8),type='spell',spell=403,event='SUCCEEDED',announce='local',value='Legacy'}}
 d.input:SetText(assert(codec:Encode(legacy)));d.apply:Click();assert(d.frame:IsShown()and data(p).outputs[1].id==imported.outputs[1].id)
end)
end

finish()
