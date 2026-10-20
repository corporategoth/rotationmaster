-- Shared publication and transport boundaries of the two revision slices.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local normalize=dofile('tests/fixtures/restore_revision_changes.lua')
local persistent=dofile('tests/fixtures/restore_rotation_content_revision.lua')
local dependency=dofile('tests/fixtures/restore_dependency_revisions.lua')
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
test('combined validation source retains both exact reviewed stages and the same original',function()
 local path='validate.lua';local text=read(path)
 local a=normalize(text,path,'persistent');local b=normalize(text,path,'dependency')
 assert(a~=text and b~=text and a~=b)
 assert(persistent(a,path)==dependency(b,path))
 assert(normalize(text,path)==dependency(nil,path,true))
 for _,value in ipairs({text..'\n-- unrelated',a,b,dependency(nil,path,true)})do
  assert(not pcall(normalize,value,path),'integration accepted an unreviewed source stage')
 end
 assert(not pcall(normalize,text,'unknown.lua'))
 assert(not pcall(normalize,text,path,'unknown'))
end)
test('combined common fixture keeps exact lazy Data and early dependency stages',function()
 local path='tests/fixtures/addon.lua';local text=read(path)
 local a=normalize(text,path,'persistent');local b=normalize(text,path,'dependency')
 assert(a~=text and b~=text and a~=b)
 assert(dependency(b,path)==normalize(text,path))
 assert(not pcall(normalize,text..'\n-- unrelated',path))
 local f=F.new();assert(f.addon.RotationData==nil,'Data was loaded eagerly')
 f.load('Data/plain.lua');assert(type(f.addon.RotationData.PrepareRotationContentRevision)=='function')
 local before=f.addon:GetRotationValidationStamp();assert(f.addon:InvalidateRotationDependencies('all'))
 assert(f.addon:GetRotationValidationStamp()~=before)
end)
test('actual repair preserves saved rotation revision while dependency repair retires the managed stamp',function()
 local f=F.new();local a=f.addon;a.warn=function()end
 for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','validate.lua'})do f.load(path)end
 local body={name='Revision fixture',revision=7,rotation={},cooldowns={}}
 a:validate_rotation('fixture','61b36ed1-fa31-4656-ad71-f3d50f193a85',body,true)
 assert(body.revision==7 and a.RotationData.GetRotationContentRevision(body)==7)
 local before=a:GetRotationValidationStamp();local invalid={items={1}}
 a:validate_itemset('fixture','invalid-id',invalid,true)
 assert(next(invalid)==nil and a:GetRotationValidationStamp()~=before)
end)
finish()
