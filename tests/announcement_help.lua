local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();f.load('Help/announce.lua');f.load('UI/help.lua');return f
end
test('announcement paragraphs and headings are whole locale values',function()
    local f=fixture()
    for key in pairs(f.translations) do f.translations[key]='translated:'..key end
    local rows=f.addon:GetDocument_layout_announce_options_help()
    assert(#rows>15)
    for _,entry in ipairs(rows) do
        assert(type(entry.id)=='string' and entry.id~='','section identity missing')
        assert(entry.title:match('^translated:') and not entry.title:find('|c',1,true),'untranslated heading')
        assert(entry.text=='translated:Help.Announces.'..entry.id,'paragraph was not translated as a whole: '..entry.id)
    end
end)
test('announcement help covers every event and preserves substitution tokens',function()
    local f=fixture();local rows=f.addon:GetDocument_layout_announce_options_help();local ids={}
    for _,entry in ipairs(rows) do assert(not ids[entry.id],'duplicate section');ids[entry.id]=entry end
    for event in pairs(f.addon.events) do assert(ids['event.'..event],'missing event help: '..event) end
    local text=assert(ids.substitutions).text
    for _,token in ipairs({'{{spell}}','{{item}}','{{event}}','{{target}}'}) do assert(text:find(token,1,true),'missing token: '..token) end
    assert(ids.sound and ids.ranked and ids.save and ids.state and ids.collections)
    rows[1].text='changed';assert(f.addon:GetDocument_layout_announce_options_help()[1].text~='changed','shared mutable document')
end)
test('legacy help renderer displays the same localized paragraphs',function()
    local f=fixture();local frame=f.widget('SimpleGroup');f.addon.layout_announce_options_help(frame)
    local displayed=F.text(frame)
    for _,entry in ipairs(f.addon:GetDocument_layout_announce_options_help()) do assert(displayed:find(entry.text,1,true),'legacy renderer lost '..entry.id) end
    assert(not displayed:find('Help.Announces.',1,true),'locale key shown instead of prose')
end)
test('shared settings help does not contradict draft Apply',function()
    local f=fixture();local editing
    for _,entry in ipairs(f.addon:WorkbenchPageHelp('Announces')) do if entry.title=='Editing settings' then editing=entry.text end end
    assert(editing and editing:find('Apply',1,true) and not editing:find('apply immediately',1,true),'help still promises immediate saves')
end)
test('Announces page help describes expanded details instead of collapsible editors',function()
 local f=fixture();local editing
 for _,entry in ipairs(f.addon:WorkbenchPageHelp('Announces')) do if entry.title=='Editing settings' then editing=entry.text end end
 assert(editing and editing:find('always expanded',1,true) and not editing:find('collapse',1,true))
end)
finish()
