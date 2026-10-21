local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse=dofile('tests/fixtures/restore_swing_countdown.lua')
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
test('complete catalog differs only in swing operand and owner hash',function()
 local f=F.new();f.load('Core/function_data.lua');f.load('Data/builtin_sources.lua');local a=f.addon
 local catalog=a:CopySettingsData(a.BuiltinSourceCatalog);dofile('tests/fixtures/restore_literal_summary_catalog.lua')(catalog);dofile('tests/fixtures/restore_swing_catalog.lua')(catalog)
 assert(a:FunctionSourceHash(catalog)=='ae50b67f','unrelated generated catalog delta after swing countdown repair')
end)
test('whole weapon inverse rejects duplicate operand and unrelated source changes',function()
 local text=read('Conditions/weapon.lua');local old=inverse(text);assert(old~=text and #old==16034)
 assert(not pcall(inverse,text..'\n-- unrelated'));assert(not pcall(inverse,old));assert(not pcall(inverse,text..text))
end)
finish()
