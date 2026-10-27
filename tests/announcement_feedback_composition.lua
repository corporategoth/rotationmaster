local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
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
