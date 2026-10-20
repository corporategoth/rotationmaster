-- Normalize only the reviewed final countdown operand on a detached catalog.
local inverse=dofile('tests/fixtures/restore_swing_countdown.lua')
return function(catalog)
 local row=assert(catalog.conditions.SWING_TIME_REMAIN)
 row.callbacks.evaluate.code=inverse(row.callbacks.evaluate.code,true)
 catalog.modules['Conditions/weapon.lua'].hash='5f87a0286e3b360fecaf2e34a7ec014dca86a86748b53a40d403f8fb3da6cffc'
 return catalog
end
