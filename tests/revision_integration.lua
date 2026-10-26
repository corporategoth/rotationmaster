-- Shared publication and transport boundaries of the two revision slices.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local normalize=dofile('tests/fixtures/restore_revision_changes.lua')
local persistent=dofile('tests/fixtures/restore_rotation_content_revision.lua')
local dependency=dofile('tests/fixtures/restore_dependency_revisions.lua')
local function read(path)local h=assert(io.open(path));local text=h:read('*a');h:close();return text end
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
