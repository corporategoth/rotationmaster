local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f=F.new();for _,p in ipairs({'Data/plain.lua','Data/tags.lua','Core/conditions.lua','Conditions/unit_states.lua','Conditions/combat.lua','Conditions/character.lua','Conditions/misc.lua','Core/condition_description.lua'})do f.load(p)end
 return f,f.addon
end
local function noRaw(text)
 for _,key in ipairs({'unit:','disabled:','raid:','type:','value:','customCode:','secretField:'})do assert(not text:find(key,1,true),text)end
end
local function printTrap(a)
 a.printCondition=function()error('data-only tree invoked a printer')end
 for _,d in pairs(a.conditionDefinitions)do d.print=function()error('data-only leaf invoked a printer')end;d.valid=function()error('description validated')end;d.evaluate=function()error('description evaluated')end end
end
test('announcement Friendly is a unit-first sentence with no internal fields or unit-map mutation',function()
 local _,a=fixture();printTrap(a);local tree={type='FRIENDLY',unit='announcementtarget'}
 local text=a:DescribeCondition(tree,0);assert(text=='Announcement target is friendly',text);noRaw(text)
 assert(tree.unit=='announcementtarget'and a.units.announcementtarget==nil)
end)
test('safe Friendly and Dead negations read as negative predicates while compound NOT stays explicit',function()
 local _,a=fixture();printTrap(a)
 for _,pair in ipairs({{'FRIENDLY','Announcement target is not friendly'},{'DEAD','Announcement target is alive'}})do
  local node={type=pair[1],unit='announcementtarget'};assert(a:DescribeCondition({type='NOT',value=node},0)==pair[2]);assert(a:DescribeCondition({type='NOT',value={type='NOT',value=node}},0)==a:DescribeCondition(node,0))
 end
 local text=a:DescribeCondition({type='NOT',value={type='AND',value={{type='DEAD',unit='announcementtarget'},{type='FRIENDLY',unit='announcementtarget'}}}},0)
 assert(text=='NOT (Announcement target is dead or a ghost AND Announcement target is friendly)',text);noRaw(text)
end)
test('data-only Boolean groups use infix words and preserve mixed group scope',function()
 local f,a=fixture();printTrap(a)
 local friendly={type='FRIENDLY',unit='announcementtarget'}
 local dead={type='DEAD',unit='announcementtarget'}
 local combat={type='COMBAT',unit='announcementtarget'}
 assert(a:DescribeCondition({type='AND',value={friendly,dead,combat}},0)=='Announcement target is friendly AND Announcement target is dead or a ghost AND Announcement target is in combat')
 assert(a:DescribeCondition({type='OR',value={friendly,dead}},0)=='Announcement target is friendly OR Announcement target is dead or a ghost')
 assert(a:DescribeCondition({type='AND',value={friendly,{type='OR',value={dead,combat}}}},0)=='Announcement target is friendly AND (Announcement target is dead or a ghost OR Announcement target is in combat)')
 assert(a:DescribeCondition({type='OR',value={{type='AND',value={friendly,dead}},combat}},0)=='(Announcement target is friendly AND Announcement target is dead or a ghost) OR Announcement target is in combat')
 assert(a:DescribeCondition({type='AND',value={friendly,{type='NOT',value={type='NOT',value={type='OR',value={dead,combat}}}}}},0)=='Announcement target is friendly AND (Announcement target is dead or a ghost OR Announcement target is in combat)')
 f.translations.AND='ET';assert(a:DescribeCondition({type='AND',value={friendly,dead}},0)=='Announcement target is friendly ET Announcement target is dead or a ghost')
end)
test('actual announcement unit flags and Group raid mode use readable declared semantics',function()
 local _,a=fixture();printTrap(a)
 for _,sample in ipairs({{'COMBAT','is in combat','is not in combat'},{'ENEMY','is an enemy','is not an enemy'},{'PVP','is PVP flagged','is not PVP flagged'},{'ATTACKABLE','is attackable','is not attackable'}})do
  local node={type=sample[1],unit='announcementtarget'};assert(a:DescribeCondition(node,0)=='Announcement target '..sample[2]);assert(a:DescribeCondition({type='NOT',value=node},0)=='Announcement target '..sample[3])
 end
 for _,raid in ipairs({false,true})do local n={type='GROUP',unit='announcementtarget',raid=raid};local label=raid and'a raid'or'a party or raid';assert(a:DescribeCondition(n,0)=='Announcement target is in '..label);assert(a:DescribeCondition({type='NOT',value=n},0)=='Announcement target is not in '..label)end
 assert(a:DescribeCondition({type='GROUP',unit='announcementtarget'},0)=='Announcement target is in a party or raid')
 local text=a:DescribeCondition({type='GROUP',unit='announcementtarget',raid=3},0);assert(text:find('invalid',1,true)and not text:find('; 3',1,true),text)
end)
test('disabled states are human indicators and card-only summaries keep their existing convention',function()
 local _,a=fixture();printTrap(a);local node={type='FRIENDLY',unit='announcementtarget',disabled=true}
 local text=a:DescribeCondition(node,0);assert(text=='Disabled: Announcement target is friendly',text);noRaw(text)
 assert(a:DescribeCardCondition(node,0)=='Announcement target is friendly');assert(node.disabled==true)
 a.conditionDefinitions.FRIENDLY.disabled=true;text=a:DescribeCondition(node,0);assert(text:find('Disabled',1,true)and text:find('Unavailable condition',1,true),text);noRaw(text)
end)
test('custom-containing data-only trees run zero printers and preserve opaque literal phrase markers',function()
 local _,a=fixture();a:RegisterCondition('CUSTOM',{customCode=true,description='Custom rule',fields={code='string'},print=function()error('custom printer')end});printTrap(a)
 local marker='{{!literal|still literal}} |cffff0000';local tree={type='AND',value={{type='FRIENDLY',unit='announcementtarget'},{type='CUSTOM',disabled=true,code=marker,payload={type='DEAD',unit='announcementtarget',secretField=42}}}}
 local text=a:DescribeCondition(tree,0);assert(text:find('Announcement target is friendly',1,true)and text:find('Custom rule',1,true)and text:find('Disabled',1,true)and text:find('{{!literal||still literal}} ||cffff0000',1,true),text);noRaw(text)
 assert(tree.value[2].payload.type=='DEAD'and tree.value[2].code==marker and a.units.announcementtarget==nil)
 a:RegisterCondition('FRIENDLY',{customCode=true,description='User Friendly rule',print=function()error('custom same tag')end});text=a:DescribeCondition({type='FRIENDLY',unit='announcementtarget',code='custom body'},0);assert(text:find('User Friendly rule',1,true)and text:find('custom body',1,true)and not text:find('is friendly',1,true),text)
 a:RegisterCondition('FRIENDLY',{description='Extension rule',fields={unit='string'},print=function()error('extension printer')end});text=a:DescribeCondition({type='FRIENDLY',unit='announcementtarget'},0);assert(text:find('Extension rule',1,true)and not text:find('is friendly',1,true),text)
end)
test('unknown incomplete and malformed groups use bounded readable guidance without key dumps',function()
 local _,a=fixture();printTrap(a)
 for _,node in ipairs({{type='FUTURE',secretField=42,disabled=true},{type='FRIENDLY',unit='announcementtarget',payload='saved'},{type='NOT'},{type='AND',value={[1]={type='FRIENDLY',unit='announcementtarget'},[3]={type='DEAD',unit='announcementtarget'}}},{type='OR',value={bad={}}}})do local text=a:DescribeCondition(node,0);noRaw(text);assert(type(text)=='string'and#text<10000,text)end
 local text=a:DescribeCondition({type='FUTURE',secretField=42,disabled=true},0);assert(text:find('Unknown condition',1,true)and text:find('FUTURE',1,true)and text:find('42',1,true)and text:find('Saved settings',1,true),text)
 assert(a:DescribeCondition({type='NOT'},0):find('Incomplete',1,true))
 local missing=a:DescribeCondition({type='NOT',value={type='FRIENDLY',unit='unknown',disabled=true}},0);assert(missing:find('NOT (',1,true)and missing:find('Choose a unit',1,true),missing)
end)
test('unit labels are literal and raw lookups never call recipient or custom unit providers',function()
 local f,a=fixture();printTrap(a);local marker='Target {{!literal|other}}';a.units.target=marker
 setmetatable(a.units,{__index=function()error('unit provider')end});f.env.UnitName=function()error('native recipient lookup')end
 local text=a:DescribeCondition({type='FRIENDLY',unit='target',disabled=true},0);assert(text:find('Target {{!literal||other}} is friendly',1,true),text)
 text=a:DescribeCondition({type='FRIENDLY',unit='unknown',disabled=true},0);assert(text:find('Choose a unit',1,true),text)
 assert(rawget(a.units,'announcementtarget')==nil)
end)
test('portable validation, dense group shape and bounded tree output remain explicit',function()
 local _,a=fixture();printTrap(a);local loop={type='FRIENDLY',unit='announcementtarget'};loop.self=loop
 for _,bad in ipairs({loop,setmetatable({type='FRIENDLY'},{}),{type='FRIENDLY',payload=function()end}})do assert(a:DescribeCondition(bad,0):find('invalid data',1,true))end
 local root={type='AND',value={}};for i=1,250 do root.value[i]={type='FRIENDLY',unit='announcementtarget'}end
 local text=a:DescribeCondition(root,0);assert(text:find('truncated',1,true)and#text<65000,text)
 assert(a:DescribeCondition({type='AND',value={}},0):find('Always',1,true));assert(a:DescribeCondition({type='OR',value={}},0):find('Never',1,true))
end)
test('translated data-only predicates resolve templates before literal unit labels',function()
 local f,a=fixture();printTrap(a);f.translations['{unit} {{!is friendly|is not friendly}}']='{unit} {{!est amical|ne reste pas amical}}'
 a.units.target='Target {{!literal|other}}'
 local tree={type='NOT',value={type='FRIENDLY',unit='target',disabled=true}}
 local text=a:DescribeCondition(tree,0);assert(text=='Disabled: Target {{!literal||other}} ne reste pas amical',text)
end)
test('malformed dense lists take the data-only route before any printer callback',function()
 local _,a=fixture();local calls=0;a.printCondition=function()calls=calls+1;error('malformed group printer')end
 for _,list in ipairs({{[1]={type='COMBAT',unit='player'},[3]={type='PVP',unit='target'}},{bad={type='COMBAT',unit='player'}}})do
  local text=a:DescribeCondition({type='AND',value=list},0);assert(text:find('Incomplete condition group',1,true),text)
 end
 assert(calls==0)
end)
finish()
