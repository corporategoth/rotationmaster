-- Strict additive inverse of the PET_NAME print repair only, baseline 5a54d42.
local old='\n        return string.format(L["you {{!have|do not have}} a pet named %s"], Functions.presentation.nullable(value.value, L["<name>"]))\n    '
local repaired='\n        return PetSummary.phrase(L["you {{!have|do not have}} a pet named {name}"], {name = Functions.presentation.nullable(value.value, L["<name>"])})\n    '
local declaration='local PetSummary={phrase=addon.Functions.presentation.phrase}\n'
local selection='    ["PetSummary.phrase"]="builtin:Functions/presentation.lua:phrase",\n'
local binding='builtin:Functions/presentation.lua:phrase'
local function once(text,from,to,label)
 local first,last=text:find(from,1,true);assert(first and not text:find(from,last+1,true),'missing or duplicate '..label)
 return text:sub(1,first-1)..to..text:sub(last+1)
end
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for k,v in pairs(value)do result[copy(k)]=copy(v)end;return result
end
local function inverse(value,mode)
 if mode=='export'then
  assert(type(value)=='table'and value.print==repaired and type(value.bindings)=='table'and value.bindings['PetSummary.phrase']==binding,'unexpected complete PET_NAME export')
  local result=copy(value);result.print=old;result.bindings['PetSummary.phrase']=nil;return result
 end
 assert(type(value)=='string','expected complete source')
 if mode==true then assert(value==repaired,'unexpected complete PET_NAME print');return old end
 assert(mode==nil,'unexpected inverse mode')
 value=once(value,'print = function(_, value)'..repaired..'end,','print = function(_, value)'..old..'end,','PET_NAME print')
 value=once(value,declaration,'','PetSummary declaration');value=once(value,selection,'','PetSummary selected leaf')
 local hash=0;for i=1,#value do hash=(hash*33+value:byte(i))%4294967296 end
 assert(#value==38994 and string.format('%08x',hash)=='b59db7c1','unrelated complete combat delta')
 return value
end
return inverse,old,repaired
