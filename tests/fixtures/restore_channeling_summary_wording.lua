-- Exact additive inverse of only two nonplayer channeling wording keys.
local old={
 ["CHANNELING"]="\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!are|are not}} currently channeling\"], L[\"%s {{!is|is not}} currently casting\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))\n    ",
 ["CHANNELING_SPELL"]="\n        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!are|are not}} currently channeling {spell}\"], L[\"{unit} {{!is|is not}} currently casting {spell}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            spell = Functions.presentation.nullable(value.spell, L[\"<spell>\"]),\n        })\n    ",
}
local repaired={
 ["CHANNELING"]="\n        return string.format(Functions.presentation.playerize(value.unit, L[\"%s {{!are|are not}} currently channeling\"], L[\"%s {{!is|is not}} currently channeling\"]),\n            Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]))\n    ",
 ["CHANNELING_SPELL"]="\n        return LiteralSummary.phrase(Functions.presentation.playerize(value.unit, L[\"{unit} {{!are|are not}} currently channeling {spell}\"], L[\"{unit} {{!is|is not}} currently channeling {spell}\"]), {\n            unit = Functions.presentation.nullable(addon.units[value.unit], L[\"<unit>\"]),\n            spell = Functions.presentation.nullable(value.spell, L[\"<spell>\"]),\n        })\n    ",
}
local path='Conditions/channeling.lua'
local beforeHash='ad90658fb86a04779ba36f2e50e722cad94f99216837d7d80bacb68036984bbc'
local afterHash='a9eb4fc3e754c35c81d67c3cabf9c7d0f69edae20cf3f32fe029c4a446fefdbc'
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[copy(k)]=copy(x)end;return t end
local function inverse(value,tag,mode)
 if mode=='catalog'then
  assert(type(value)=='table'and value.modules[path].hash==afterHash,'unexpected current channeling catalog owner')
  for _,name in ipairs({'CHANNELING','CHANNELING_SPELL'})do local row=value.conditions[name].callbacks.print;assert(row.code==repaired[name],'unexpected current channeling catalog print');row.code=old[name]end
  value.modules[path].hash=beforeHash;return value
 end
 if mode=='export'then
  assert(type(value)=='table'and repaired[tag]and value.print==repaired[tag],'unexpected complete channeling wording export')
  local t=copy(value);t.print=old[tag];return t
 end
 assert(type(value)=='string')
 if mode==true then assert(repaired[tag]and value==repaired[tag],'unexpected complete channeling wording print');return old[tag]end
 assert(mode==nil,'unexpected wording inverse mode')
 for _,name in ipairs({'CHANNELING','CHANNELING_SPELL'})do
  local from='print = function(_, value)'..repaired[name]..'end,';local to='print = function(_, value)'..old[name]..'end,'
  local first,last=value:find(from,1,true);assert(first and not value:find(from,last+1,true),'missing or duplicate channeling wording print')
  value=value:sub(1,first-1)..to..value:sub(last+1)
 end
 local h=0;for i=1,#value do h=(h*33+value:byte(i))%4294967296 end
 assert(#value==9057 and string.format('%08x',h)=='ba5d082a','channeling differs beyond two wording keys')
 return value
end
return inverse,old,repaired
