-- Compose older feature proofs without weakening the strict three-module inverse.
local restore=dofile('tests/fixtures/restore_parser_string_operations.lua')
local restorePreview=dofile('tests/fixtures/restore_cpu_preview_context.lua')
local restoreScopes=dofile('tests/fixtures/restore_cpu_validation_scopes.lua')
local restoreSpellOrder=dofile('tests/fixtures/restore_spell_order_cache.lua')
return function(text,path)
 if path=='Core/spell_catalog.lua' then return restoreSpellOrder(text,path) end
 if path=='Diagnostics/cpu.lua' then text=restorePreview(restoreScopes(text,path)) end
 if path=='Data/plain.lua' or path=='Data/rotation_tree.lua' or path=='Diagnostics/cpu.lua' then return restore(text,path) end
 return text
end
