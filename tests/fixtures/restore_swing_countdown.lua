-- Strict final-operand inverse; complete7f4dd7c weapon module.
local old=[====[return Functions.values.compare(value.operator,speed-math.max(evalStart-lastSwing,0),value.value)]====]
local repaired=[====[return Functions.values.compare(value.operator,math.max(speed-math.max(evalStart-lastSwing,0),0),value.value)]====]
return function(text,callback)
 assert(type(text)=='string','expected swing source')
 local first,last=text:find(repaired,1,true);assert(first and not text:find(repaired,last+1,true),'missing or duplicate swing operand')
 text=text:sub(1,first-1)..old..text:sub(last+1)
 if not callback then
  local h=5381;for i=1,#text do h=(h*33+text:byte(i))%4294967296 end
  assert(#text==16034 and string.format('%08x',h)=='82c03b8a','unrelated complete weapon source delta')
 end
 return text
end
