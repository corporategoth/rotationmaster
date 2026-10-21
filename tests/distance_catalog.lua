-- Complete generated-catalog and authored-module preservation.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local inverse=dofile('tests/fixtures/restore_distance_presence.lua')
local function proveCatalog(a,catalog)
 dofile('tests/fixtures/restore_literal_summary_catalog.lua')(catalog)
 local scalars=0
 local function count(value)if type(value)=='table'then for _,child in pairs(value)do count(child)end else scalars=scalars+1 end end
 count(catalog);assert(scalars==7120,'catalog scalar inventory changed')
 dofile('tests/fixtures/restore_swing_catalog.lua')(catalog)
 dofile('tests/fixtures/restore_distance_catalog.lua')(catalog)
 assert(a:FunctionSourceHash(catalog)=='1885abe7','catalog differs from complete7f4dd7c beyond the reviewed DISTANCE repair')
end
local function catalogFixture()
 local f=F.new();f.load('Core/function_data.lua');f.load('Data/builtin_sources.lua');return f.addon
end
test('DISTANCE changes only its presence prefix module owner hash and thirteen declaration lines',function()
 local a=catalogFixture();proveCatalog(a,a:CopySettingsData(a.BuiltinSourceCatalog))
end)
test('complete catalog proof rejects unrelated evaluation after accepted summary normalization',function()
 local a=catalogFixture();local catalog=a:CopySettingsData(a.BuiltinSourceCatalog)
 catalog.conditions.HEALTH.callbacks.evaluate.code=catalog.conditions.HEALTH.callbacks.evaluate.code..'\n-- unrelated evaluation delta'
 local ok,why=pcall(proveCatalog,a,catalog)
 assert(not ok and tostring(why):find('catalog differs from complete7f4dd7c',1,true),'normalization accepted unrelated condition evaluation')
end)
test('literal-summary catalog normalization rejects altered reviewed code owner and selected leaf',function()
 local a=catalogFixture();local normalize=dofile('tests/fixtures/restore_literal_summary_catalog.lua')
 for _,kind in ipairs({'code','owner','binding'})do
  local catalog=a:CopySettingsData(a.BuiltinSourceCatalog);local row=catalog.conditions.PET_NAME.callbacks.print
  if kind=='code'then row.code=row.code..' 'elseif kind=='owner'then catalog.modules['Conditions/combat.lua'].hash='unexpected'else row.bindings['PetSummary.phrase']='unexpected'end
  assert(not pcall(normalize,catalog),'normalization accepted altered '..kind)
 end
end)
test('strict complete spatial inverse rejects unrelated edits and duplicate prefixes',function()
 local f=F.new();f.load('Core/function_data.lua');local text=read('Conditions/spatial.lua');local old=inverse(text)
 assert(#old==24993 and old~=text)
 assert(not pcall(inverse,text..'\n-- unrelated'))
 assert(not pcall(inverse,old))
 assert(not pcall(inverse,text..text))
end)
finish()
