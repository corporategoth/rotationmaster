local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function digest(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return n end
local expected={["UI/settings_announces.lua"]={26410,3047187761},["Core/condition_description.lua"]={5605,1865595316},["Locales/enUS.lua"]={254288,2916484446},["Web/schema/catalog.json"]={32746,217191212},["tools/check"]={41009,992207271}}

local inverse=dofile('tests/fixtures/restore_announcement_feedback.lua')
test('exact feedback and prior pack successors reconstruct closed GitBC predecessors',function()
 for path,row in pairs(expected)do
  local current=read(path);local old=inverse(current,path)
  assert(#old==row[1]and digest(old)==row[2],path..' predecessor differs')
  assert(inverse(old,path)==old,path..' inverse is not idempotent')
 end
end)
test('unrelated same-length changes are not silently normalized into accepted history',function()
 for path,row in pairs(expected)do
  local current=read(path);local changed=(current:sub(1,1)=='x'and'y'or'x')..current:sub(2)
  local result=inverse(changed,path)
  assert(result==changed and not(#result==row[1]and digest(result)==row[2]),path..' unrelated text normalized')
 end
end)
test('a same-length checksum collision cannot impersonate a reviewed successor',function()
 for _,path in ipairs({'UI/settings_announces.lua','Core/condition_description.lua'})do
  local current=read(path);local changed,n=current:gsub('GetLocale','GfSLocale',1)
  assert(n==1 and #changed==#current and digest(changed)==digest(current),'positive checksum-collision control missing')
  assert(inverse(changed,path)==changed,path..' checksum collision was normalized')
 end
end)
test('actual announcement condition button renders readable clauses and edits only its detached output',function()
 local s=read('tests/announcement_series_ui.lua')
 local fixture,card,entry,open,data=assert(loadstring(assert(s:match('^(.-)\ntest%('))..'\nreturn fixture,card,entry,open,data','@feedback-composition-fixture'))()
 local f,a,parent=fixture()
 for _,path in ipairs({'Core/conditions.lua','Conditions/unit_states.lua','Core/condition_description.lua'})do f.load(path)end
 for _,tag in ipairs({'FRIENDLY','DEAD'})do local d=a.conditionDefinitions[tag]
  d.print=function()error('presentation ran a condition printer')end
  d.valid=function()error('presentation validated a live condition')end
  d.evaluate=function()error('presentation evaluated a live condition')end
 end
 local first=card(2,'A');first.conditions={type='AND',value={{type='FRIENDLY',unit='announcementtarget'},{type='NOT',value={type='DEAD',unit='announcementtarget'}}}}
 local saved=entry({first,card(3,'B')});local p=open(a,parent,saved)
 local button=p.fields.entry1conditions;local text=button:GetText()
 assert(text:find('Announcement target is friendly',1,true)and text:find('Announcement target is alive',1,true),text)
 for _,token in ipairs({'unit:','disabled:','Condition reference'})do assert(not text:find(token,1,true),text)end
 assert(a.units.announcementtarget==nil and not p:IsSettingsDraftDirty())
 local pending;a.ShowConditionEditor=function(_,_,_,draft,callback,current,options)pending={draft=draft,callback=callback,current=current,options=options}end
 button:Click();assert(pending and pending.current()and pending.options.announcementTarget)
 pending.draft.value[1].unit='player';pending.callback(true)
 assert(data(p).outputs[1].conditions.value[1].unit=='player'and saved.outputs[1].conditions.value[1].unit=='announcementtarget')
 assert(data(p).outputs[2].conditions==nil and a.units.announcementtarget==nil)
end)
finish()
