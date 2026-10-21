local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();local a=f.addon
 for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/condition_draft.lua','Core/conditions.lua','Core/condition_editor.lua','Core/announcements.lua'})do f.load(path)end
 a:RegisterCondition('UNIT',{description='Unit test',fields={unit='string',payload='object'},valid=function(_,v)return a.units[v.unit]~=nil end,evaluate=function(v,cache)assert(v.payload==nil or v.payload.unit=='announcementtarget','opaque payload changed');return v.unit=='mouseover' end})
 a.GetImportValidationOptions=function()return {conditions=a.conditionDefinitions}end
 return f,a
end
test('macro target alias follows supplied unit without mutating source or ordinary polling context',function()
 local _,a=fixture();local tree={type='UNIT',unit='announcementtarget',payload={unit='announcementtarget'}}
 assert(a:AnnouncementConditionMatches({conditions=tree},'Name-Realm',nil,'mouseover'))
 assert(not a:AnnouncementConditionMatches({conditions=tree},'Name-Realm',nil,'target'))
 assert(tree.unit=='announcementtarget' and tree.payload.unit=='announcementtarget' and a.units.announcementtarget==nil)
 assert(a:evaluateConditionResult(tree).status=='unavailable','alias must not enter normal rotation context')
 assert(a:DescribeCondition(tree,0):find('Announcement target',1,true),'context label missing from readonly summary')
end)
test('missing or restricted target stays unavailable under NOT while fixed units need no target',function()
 local f,a=fixture();local node={type='NOT',value={type='UNIT',unit='announcementtarget'}}
 assert(not a:AnnouncementConditionMatches({conditions=node},nil,nil,nil))
 local opaque={};f.env.issecretvalue=function(v)return rawequal(v,opaque)end
 assert(not a:AnnouncementConditionMatches({conditions=node},nil,nil,opaque))
 assert(a:AnnouncementConditionMatches({conditions={type='UNIT',unit='mouseover'}},nil,nil,nil))
 assert(a:AnnouncementConditionMatches({conditions={type='UNIT',unit='announcementtarget',disabled=true}},nil,nil,nil))
end)
test('unavailable target is evaluated only when reached after ordinary Boolean prefixes',function()
 local _,a=fixture();local alias={type='UNIT',unit='announcementtarget'}
 local falseLeaf={type='UNIT',unit='target'}
 assert(a:AnnouncementConditionMatches({conditions={type='NOT',value={type='AND',value={falseLeaf,alias}}}},nil,nil,nil))
 assert(a:AnnouncementConditionMatches({conditions={type='OR',value={{type='UNIT',unit='mouseover'},alias}}},nil,nil,nil))
 assert(not a:AnnouncementConditionMatches({conditions={type='NOT',value={type='AND',value={{type='UNIT',unit='mouseover'},alias}}}},nil,nil,nil))
end)
test('only macro editor validation accepts contextual alias and never evaluates it',function()
 local _,a=fixture();local root={type='UNIT',unit='announcementtarget'}
 a.conditionDefinitions.UNIT.evaluate=function()error('validation evaluated live condition')end
 assert(a:validateAnnouncementCondition(root,0))
 assert(not a:validateCondition(root,0))
 local draft={};local session=assert(a:NewConditionEditSession(0,draft,nil,{announcementTarget=true}))
 assert(session:Command('Replace',{},root));assert(session:Apply());assert(draft.unit=='announcementtarget')
end)
test('contextual unit dropdown is local to its owner and ordinary editors keep old choices',function()
 local f,a=fixture();local units={player='You',target='Target',mouseover='Mouseover'}
 for _,enabled in ipairs({false,true})do
  local top={GetUserData=function(_,key)return key=='announcementTarget' and enabled end}
  local parent=a:CreateConditionGroup();parent:SetUserData('top',top)
  local value={unit='target'};local control=a:Widget_UnitWidget(value,units,function()end);parent:AddChild(control);control.configure()
  assert((control.list.announcementtarget~=nil)==enabled and units.announcementtarget==nil and value.unit=='target');parent:Release()
 end
end)
finish()
