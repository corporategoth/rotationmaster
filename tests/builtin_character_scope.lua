-- Only this character's Built In packs are kept: other editions and other
-- classes never register, so a client holds its own premades, not every one.
local corpus=dofile('tests/fixtures/default_corpus.lua')
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local modules=dofile('tools/builtin_modules.lua')
-- Pack files (blocks register no pack) in the module TOCs; filter as tools/builtin_modules.lua.
local function files(filter)local n=0;for _,path in ipairs(modules.paths(filter))do if not modules.isBlock(path)then n=n+1 end end;return n end
local clients={{'tbc',5,1,'SHAMAN'},{'forever',18,12,'MAGE'},{'retail',1,12,'WARRIOR'}}
for _,c in ipairs(clients)do
 test(c[1]..' '..c[4]..' registers only its own edition and class',function()
  local f,packs=corpus.load(c[2],c[3],c[4],{characterScope=true});local a=f.addon
  assert(#packs==files({family=c[1],class=c[4]}),('%d packs registered, %d expected'):format(#packs,files({family=c[1],class=c[4]})))
  for _,pack in ipairs(packs)do
   assert(pack.applicability.families[1]==c[1] and pack.applicability.class==c[4],pack.id..' does not belong to this character')
  end
  for _,id in ipairs({'rm.tbc.mage.frost','rm.forever.rogue.dps','rm.retail.priest.shadow'})do
   if not id:find('.'..c[1]..'.'..c[4]:lower(),1,true)then assert(a:GetDefaultRotation(id)==nil,id..' was kept on a '..c[1]..' '..c[4])end
  end
 end)
end
test('offline tools and cross-edition checks still see every pack',function()
 local _,packs=corpus.load(5,1,'SHAMAN');assert(#packs==files(),'full load lost packs: '..#packs)
end)
print(('%d passed, %d failed'):format(pass,fail));if fail>0 then os.exit(1)end
