-- Compose older feature proofs without weakening the strict three-module inverse.
local restore=dofile('tests/fixtures/restore_parser_string_operations.lua')
local restorePreview=dofile('tests/fixtures/restore_cpu_preview_context.lua')
local restoreScopes=dofile('tests/fixtures/restore_cpu_validation_scopes.lua')
local restoreSpellOrder=dofile('tests/fixtures/restore_spell_order_cache.lua')
return function(text,path)
 if path=='Core/rotation_sequence.lua'then
  local undo=dofile('tests/fixtures/restore_active_runtime_plan.lua')
  if text~=undo(nil,path,'before')then text=undo(text,path)end
 end
 if path=='main.lua'then text=dofile('tests/fixtures/restore_active_runtime_main.lua')(text,path)end
 if path=='main.lua'then text=dofile('tests/fixtures/restore_runtime_event_context.lua')(text,path)end
 if path=='Core/spell_catalog.lua' then return restoreSpellOrder(text,path) end
 if path=='Diagnostics/cpu.lua' then text=restorePreview(restoreScopes(text,path)) end
 if path=='Data/plain.lua' or path=='Data/rotation_tree.lua' or path=='Diagnostics/cpu.lua' then return restore(text,path) end
 return text
end
