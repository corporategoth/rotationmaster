-- Normalize only the reviewed DISTANCE presence repair on a detached catalog.
local inverse=dofile('tests/fixtures/restore_distance_presence.lua')
return function(catalog)
 local path='Conditions/spatial.lua';local row=assert(catalog.conditions.DISTANCE)
 local callback=row.callbacks.evaluate;callback.code=inverse(callback.code,true)
 catalog.modules[path].hash='615beaf7be64b71da169d54beeb01cb8985d8b05a829703f57edf9b055f545c8'
 local moved=0
 for _,condition in pairs(catalog.conditions)do if condition.module==path then
  for _,entry in pairs(condition.callbacks)do if entry.line>callback.line then entry.line=entry.line-3;moved=moved+1 end end
 end end
 assert(moved==13,'unexpected DISTANCE callback relocation count')
 return catalog
end
