-- Strict additive inverse of only the two ECS summary prints at26e0ca4.
local old={
 ["ECS_STAT"]="\n        return Functions.presentation.compareString(value.operator,\n                Functions.presentation.nullable_value(value.stat, ecs_state.stats, L[\"<stat>\"]), Functions.presentation.nullable(value.value))\n    ",
 ["ECS_STAT_PCT"]="\n        local v = value.value\n        if v ~= nil then\n            v = v * 100\n        end\n        return Functions.presentation.compareString(value.operator,\n                Functions.presentation.nullable_value(value.stat, ecs_state.percentages, L[\"<stat>\"]), Functions.presentation.nullable(v) .. \"%\")\n    ",
}
local repaired={
 ["ECS_STAT"]="\n        return ECSLabels.phrase(L[\"{stat} {comparison} {value}\"], {\n            stat = Functions.presentation.nullable_value(value.stat, ecs_state.stats, L[\"<stat>\"]),\n            comparison = ECSLabels.predicate(value.operator, true),\n            value = Functions.presentation.nullable(value.value),\n        })\n    ",
 ["ECS_STAT_PCT"]="\n        local v = value.value\n        if v ~= nil then\n            v = v * 100\n        end\n        return ECSLabels.phrase(L[\"{stat} {comparison} {value}%\"], {\n            stat = Functions.presentation.nullable_value(value.stat, ecs_state.percentages, L[\"<stat>\"]),\n            comparison = ECSLabels.predicate(value.operator, true),\n            value = Functions.presentation.nullable(v),\n        })\n    ",
}
-- Later Help copy repairs (ECS_STAT and ECS_STAT_PCT have no Unit field): composed
-- before the print inverse so every predecessor identity stays exact.
local helpCurrent={
 ["ECS_STAT"]='"Your current value of the selected stat, as Extended Character Stats reports it.")',
 ["ECS_STAT_PCT"]='"Your current value of the selected stat, as a percentage, as Extended Character Stats reports it.")',
}
local helpOld='"The current value of the selected stat for " .. color.BLIZ_YELLOW .. L["Unit"] .. color.RESET .. ".")'
local declaration="local ECSLabels={phrase=addon.Functions.presentation.phrase,predicate=addon.Functions.presentation.predicate}\n"
local selection="    [\"ECSLabels.phrase\"]=\"builtin:Functions/presentation.lua:phrase\",\n    [\"ECSLabels.predicate\"]=\"builtin:Functions/presentation.lua:predicate\",\n"
local added={['ECSLabels.phrase']='builtin:Functions/presentation.lua:phrase',['ECSLabels.predicate']='builtin:Functions/presentation.lua:predicate'}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[copy(k)]=copy(x)end;return r end
local function once(text,from,to,label)local a,b=text:find(from,1,true);assert(a and not text:find(from,b+1,true),'missing or duplicate '..label);return text:sub(1,a-1)..to..text:sub(b+1)end
local catalogLines={["ECS_STAT"]={["evaluate"]={136,133},["help"]={168,162},["on_register"]={92,89},["print"]={140,137},["valid"]={131,128},["widget"]={147,141}},["ECS_STAT_PCT"]={["evaluate"]={187,181},["help"]={224,215},["on_register"]={92,89},["print"]={192,186},["valid"]={182,176},["widget"]={203,194}},["STAT"]={["evaluate"]={39,36},["help"]={75,72},["print"]={45,42},["valid"]={33,30},["widget"]={50,47}}}
local catalogOwner={"7d637c0a16a50b8f0ce6a69607e11f71783df7cd13ce41ef93368f87d8ee8310","feabaa3c681dd312b1f30cbb7b7271cf6eeb81c193002a72b17ccf4d715eb417"}
local function inverse(value,tag,mode)
 if mode=='catalog'then
  assert(type(value)=='table'and tag==nil,'expected complete current catalog')
  local owner=assert(value.modules['Conditions/ext_stats.lua']);assert(owner.hash==catalogOwner[1],'unexpected ECS catalog owner')
  for id,callbacks in pairs(catalogLines)do
   local record=assert(value.conditions[id]);assert(record.module=='Conditions/ext_stats.lua')
   for name,lines in pairs(callbacks)do local row=assert(record.callbacks[name]);assert(row.line==lines[1],'unexpected ECS callback location');row.line=lines[2]end
  end
  for _,id in ipairs({'ECS_STAT','ECS_STAT_PCT'})do
   local row=value.conditions[id].callbacks.print;assert(row.code==repaired[id],'unexpected ECS catalog print')
   for name,binding in pairs(added)do assert(row.bindings[name]==binding,'unexpected ECS catalog leaf');row.bindings[name]=nil end
   row.code=old[id]
   local help=value.conditions[id].callbacks.help;help.code=once(help.code,helpCurrent[id],helpOld,id..' help')
  end
  owner.hash=catalogOwner[2];return value
 end
 if mode=='export'then
  assert(type(value)=='table'and repaired[tag]and value.print==repaired[tag]and type(value.bindings)=='table','unexpected complete ECS export')
  for name,id in pairs(added)do assert(value.bindings[name]==id,'unexpected ECS summary binding')end
  local result=copy(value);result.print=old[tag];result.help=once(result.help,helpCurrent[tag],helpOld,tag..' help');for name in pairs(added)do result.bindings[name]=nil end;return result
 end
 if mode==true then assert(repaired[tag]and value==repaired[tag],'unexpected complete ECS print');return old[tag]end
 assert(type(value)=='string'and tag==nil and mode==nil,'expected complete ECS module')
 for _,name in ipairs({'ECS_STAT','ECS_STAT_PCT'})do value=once(value,helpCurrent[name],helpOld,name..' help')end
 for _,name in ipairs({'ECS_STAT','ECS_STAT_PCT'})do value=once(value,'print = function(_, value)'..repaired[name]..'end,','print = function(_, value)'..old[name]..'end,',name..' print')end
 value=once(value,declaration,'','ECSLabels declaration');value=once(value,selection,'','ECSLabels selected bindings')
 local n=0;for i=1,#value do n=(n*33+value:byte(i))%4294967296 end
 assert(#value==11029 and string.format('%08x',n)=='5de593bf','unrelated complete ECS module delta')
 return value
end
return inverse,old,repaired,added
