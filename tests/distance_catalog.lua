-- Complete generated-catalog and authored-module preservation.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local inverse=dofile('tests/fixtures/restore_distance_presence.lua')
test('DISTANCE changes only its presence prefix module owner hash and thirteen declaration lines',function()
 local f=F.new();f.load('Core/function_data.lua');f.load('Data/builtin_sources.lua');local a=f.addon
 local catalog=a:CopySettingsData(a.BuiltinSourceCatalog);local scalars=0
 local function count(value)if type(value)=='table'then for _,child in pairs(value)do count(child)end else scalars=scalars+1 end end
 count(catalog);assert(scalars==7120,'catalog scalar inventory changed')
 dofile('tests/fixtures/restore_swing_catalog.lua')(catalog)
 dofile('tests/fixtures/restore_distance_catalog.lua')(catalog)
 assert(a:FunctionSourceHash(catalog)=='1885abe7','catalog differs from complete7f4dd7c beyond the reviewed DISTANCE repair')
end)
test('strict complete spatial inverse rejects unrelated edits and duplicate prefixes',function()
 local f=F.new();f.load('Core/function_data.lua');local text=read('Conditions/spatial.lua');local old=inverse(text)
 assert(#old==24993 and old~=text)
 assert(not pcall(inverse,text..'\n-- unrelated'))
 assert(not pcall(inverse,old))
 assert(not pcall(inverse,text..text))
end)
finish()
