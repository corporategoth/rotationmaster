-- Strict test-only inverse of CARRYING named-summary ownership and print body.
-- Frozen item module frozen from 4d5f0bb (FunctionSourceHash 2154174d).
local old="\n        return Functions.presentation.compareString(value.operator,\n                string.format(L[\"the number of %s you are carrying\"], Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"])),\n                Functions.presentation.nullable(value.value, L[\"<quantity>\"]))\n    "
local repaired="\n        return Summary.phrase(L[\"the number of {item} you are carrying {comparison} {quantity}\"], {\n            item = Functions.presentation.nullable(get_item_desc(value.item), L[\"<item>\"]),\n            comparison = Summary.predicate(value.operator, true),\n            quantity = Functions.presentation.nullable(value.value, L[\"<quantity>\"]),\n        })\n    "
local declaration="local Summary={\n    phrase=addon.Functions.presentation.phrase,\n    predicate=addon.Functions.presentation.predicate,\n}\n"
local bindings="    [\"Summary.phrase\"]=\"builtin:Functions/presentation.lua:phrase\",\n    [\"Summary.predicate\"]=\"builtin:Functions/presentation.lua:predicate\",\n"

local added={['Summary.phrase']='builtin:Functions/presentation.lua:phrase',['Summary.predicate']='builtin:Functions/presentation.lua:predicate'}
local function replaceOnce(text,from,to,label)
 local first,last=text:find(from,1,true);assert(first and not text:find(from,last+1,true),'missing or duplicate '..label)
 return text:sub(1,first-1)..to..text:sub(last+1)
end
local function copy(value)
 if type(value)~='table' then return value end
 local result={};for key,entry in pairs(value) do result[copy(key)]=copy(entry) end;return result
end
local function inverse(value,mode)
 if mode=='export' then
  assert(type(value)=='table' and value.print==repaired and type(value.bindings)=='table','unexpected complete CARRYING export')
  for key,id in pairs(added) do assert(value.bindings[key]==id,'unexpected selected summary binding') end
  local result=copy(value);result.print=old
  for key in pairs(added) do result.bindings[key]=nil end
  return result
 end
 assert(type(value)=='string')
 if mode==true then assert(value==repaired,'unexpected CARRYING print body');return old end
 value=replaceOnce(value,'print = function(_, value)'..repaired..'end,','print = function(_, value)'..old..'end,','CARRYING print')
 value=replaceOnce(value,declaration,'','Summary declaration')
 return replaceOnce(value,bindings,'','Summary selected bindings')
end
return inverse,old,repaired,added
