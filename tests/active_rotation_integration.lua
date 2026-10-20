-- Actual predecessor and load-order integration contracts for the transition service.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse=dofile('tests/fixtures/restore_active_rotation_transition.lua')
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
local predecessors={
 ['main.lua']={bytes=66470,hash='ab5eb4e0'},
 ['Core/rotation_lifecycle.lua']={bytes=2762,hash='2e07dece'},
 ['Core/rotation_library.lua']={bytes=39299,hash='46d2527f'},
 ['Core/rotation_scope.lua']={bytes=55193,hash='063dfab9'},
 ['Core/rotation_editor.lua']={bytes=8444,hash='408aea58'},
 ['Core/imports.lua']={bytes=12117,hash='7dd8b555'},
 ['Core/rotation_migration.lua']={bytes=13116,hash='86f3ba98'},
 ['UI/rotation_editor.lua']={bytes=27620,hash='4f6f9218'},
 ['tests/fixtures/addon.lua']={bytes=7208,hash='679f5da9'},
}
test('all eight predecessor modules and the shared fixture retain complete c0 source identities',function()
 local count=0
 for path,pin in pairs(predecessors)do
  local current=read(path);local previous=inverse(current,path);local hash=5381
  for i=1,#previous do hash=(hash*33+previous:byte(i))%4294967296 end
  assert(#previous==pin.bytes and string.format('%08x',hash)==pin.hash,'wrong complete predecessor '..path)
  assert(not pcall(inverse,current..'\n-- unrelated',path),'unrelated bytes accepted '..path)
  assert(not pcall(inverse,previous,path),'old source accepted as current '..path)
  count=count+1
 end
 assert(count==9);assert(not pcall(inverse,read('Core/rotation_active.lua'),'Core/rotation_active.lua'))
end)
test('the single active service loads before every consumer in the real TOC',function()
 local text=read('RotationMaster.toc');local at=assert(text:find('\nCore/rotation_active.lua\n',1,true))
 assert(not text:find('\nCore/rotation_active.lua\n',at+1,true))
 for path in pairs(predecessors)do if path~='tests/fixtures/addon.lua'then
  assert(assert(text:find('\n'..path..'\n',1,true))>at,'consumer loaded before active service '..path)
 end end
end)
finish()
