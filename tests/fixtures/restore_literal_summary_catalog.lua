-- Undo only reviewed literal-summary catalog deltas on a detached catalog.
-- The callers still prove the entire historical catalog hash and inventory.
local petInverse=dofile('tests/fixtures/restore_pet_name_summary_literals.lua')
local literalInverse,_,_,literalPaths=dofile('tests/fixtures/restore_zone_cast_summary_literals.lua')
local phrase='builtin:Functions/presentation.lua:phrase'
local owners={
 PET_NAME={'Conditions/combat.lua','9487d2b0e90f3f99ba954020b370045dcff57a16a376acf89c671b190a7ca993','3a318e8fb9969398919914af49811bff0ed49ac6230e6b70463edae9abf574aa'},
 ZONE={'Conditions/spatial.lua','3c7e0f7ea88353bb22437e88becd4d2136d62f31559721c7b74b06126581b9c4','f6943c9286fac2ff65e4ab3bcd8e7d0710aa001ffb0132a63072d5e280b5c22d'},
 CASTING_SPELL={'Conditions/casting.lua','b771a35509a14a4a7fcd37ab1e6393cfd751bf54d7913dc2c54dab03bd6f7b20','592c4e18df0cd2621674a56974c4180f608c516c5f7e942b66f527264f1b3a40'},
 CHANNELING_SPELL={'Conditions/channeling.lua','ad90658fb86a04779ba36f2e50e722cad94f99216837d7d80bacb68036984bbc','7fb37783b6de6b691fd324d66b5955d95934d08b15b6a6832220c12dc1b17c35'},
}
return function(catalog)
 dofile('tests/fixtures/restore_aura_name_summary_literals.lua')(catalog,nil,'catalog')
 dofile('tests/fixtures/restore_channeling_summary_wording.lua')(catalog,nil,'catalog')
 for _,tag in ipairs({'PET_NAME','ZONE','CASTING_SPELL','CHANNELING_SPELL'})do
  local owner=owners[tag];local path=owner[1];local record=assert(catalog.conditions[tag]);local row=record.callbacks.print
  assert(record.module==path and catalog.modules[path].hash==owner[2],'unexpected literal-summary owner')
  local selected=tag=='PET_NAME'and'PetSummary.phrase'or'LiteralSummary.phrase'
  assert(row.bindings[selected]==phrase,'unexpected literal-summary selected leaf')
  if tag=='PET_NAME'then row.code=petInverse(row.code,true)else assert(literalPaths[tag]==path);row.code=literalInverse(row.code,tag,true)end
  row.bindings[selected]=nil;catalog.modules[path].hash=owner[3]
  local threshold=row.line;local moved=0
  for _,condition in pairs(catalog.conditions)do if condition.module==path then
   for _,callback in pairs(condition.callbacks)do
    callback.line=callback.line-(callback.line>threshold and tag~='PET_NAME'and tag~='ZONE'and 4 or 2);moved=moved+1
   end
  end end
  assert(moved==(tag=='PET_NAME'and 76 or 20),'unexpected literal-summary callback inventory')
  if tag=='ZONE'then for name,line in pairs({rcf=25,finite=27,booleanRead=28})do
   local binding=catalog.modules[path].bindings[name];assert(binding.line==line+2,'unexpected spatial binding location');binding.line=line
  end end
 end
 return catalog
end
