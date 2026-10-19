-- Strict inverse of the30 validation-only selections at7111658.
local lines={
 {old=[=[    addon.cleanArray(toremove)
]=],count=1},
 {old=[=[            if addon.tablelength(template[k]) > 0 and #template[k] == 0 then
]=],count=1},
 {old=[=[            addon.cleanArray(itemset)
]=],count=1},
 {old=[=[            addon.cleanArray(effect)
]=],count=2},
 {old=[=[            addon.cleanArray(announce)
]=],count=3},
 {old=[=[    if addon.tablelength(condition) == 0 then
]=],count=1},
 {old=[=[            addon.cleanArray(condition)
]=],count=1},
 {old=[=[    local fields = addon.deepcopy(select(4, addon:describeCondition(condition["type"])))
]=],count=1},
 {old=[=[                if addon.tablelength(data) ~= #data then
]=],count=1},
 {old=[=[            addon.cleanArray(rotation)
]=],count=2},
 {old=[=[    local cooldown_template = addon.deepcopy(rotation_template)
]=],count=1},
 {old=[=[            local template = addon.deepcopy(cooldown_template)
]=],count=1},
 {old=[=[            if addon.tablelength(rot) == 0 then
]=],count=2},
 {old=[=[            local template = addon.deepcopy(rotation_template)
]=],count=1},
 {old=[=[    local glob_template = addon.deepcopy(template.global)
]=],count=1},
 {old=[=[            if addon.tablelength(itemset) == 0 then
]=],count=1},
 {old=[=[            if addon.tablelength(effect) == 0 then
]=],count=1},
 {old=[=[            if addon.tablelength(custom_condition) == 0 then
]=],count=1},
 {old=[=[    local char_template=addon.deepcopy(template.char)
]=],count=1},
 {old=[=[    local profile_template=addon.deepcopy(template.profile)
]=],count=1},
 {old=[=[        profile_template.minimap=addon.deepcopy(profile_template.minimap)
]=],count=1},
 {old=[=[                if addon.tablelength(itemset) == 0 then
]=],count=1},
 {old=[=[                if addon.tablelength(announce) == 0 then
]=],count=1},
 {old=[=[                    if addon.tablelength(rotation) == 0 then
]=],count=1},
 {old=[=[                if addon.tablelength(group) == 0 then
]=],count=1},
}
local function literal(text) return (text:gsub('(%W)','%%%1')) end
return function(text,hash)
 assert(type(text)=='string' and type(hash)=='function','validation inverse needs source and hash')
 local edits=0
 for _,entry in ipairs(lines) do
  local repaired=entry.old:gsub('addon%.(cleanArray)%(', 'addon.Functions.collections.%1(')
  repaired=repaired:gsub('addon%.(tablelength)%(', 'addon.Functions.collections.%1(')
  repaired=repaired:gsub('addon%.(deepcopy)%(', 'addon.Functions.collections.%1(')
  local count;text,count=text:gsub(literal('\n'..repaired),function() return '\n'..entry.old end)
  assert(count==entry.count,'unexpected validation expression count/body')
  edits=edits+count
 end
 assert(edits==30 and not text:find('addon.Functions.collections.',1,true),'unexpected validation qualification')
 assert(hash(text)=='25c084e8','validation inverse differs from7111658')
 return text
end
