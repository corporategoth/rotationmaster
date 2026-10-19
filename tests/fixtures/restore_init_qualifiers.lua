-- Exact four selections only; full source must restore checkpoint7111658.
local selections={
 {'local multiinsert, deepcopy = addon.Functions.collections.multiinsert, addon.Functions.collections.deepcopy','local multiinsert, deepcopy = addon.multiinsert, addon.deepcopy'},
 {'addon.Functions.values.isin(list,tag)','addon.isin(list,tag)'},
 {"addon.Functions.values.isin(category.conditions,'SPELL_AUTOREPEAT')","addon.isin(category.conditions,'SPELL_AUTOREPEAT')"},
}
return function(text,hash)
 assert(type(text)=='string' and type(hash)=='function','init inverse requires source and hash')
 for _,selection in ipairs(selections) do
  local first,last=text:find(selection[1],1,true)
  assert(first and not text:find(selection[1],last+1,true),'unexpected init selection count/body')
  text=text:sub(1,first-1)..selection[2]..text:sub(last+1)
 end
 assert(hash(text)=='ea3d0468','init inverse differs from7111658')
 return text
end
