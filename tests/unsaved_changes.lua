local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local f=F.new();local a=f.addon
for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/unsaved_changes.lua'}) do local h=io.open(path);if h then h:close();f.load(path) end end
local function leaf(id) return {id=id,type='spell',action=403,conditions={}} end
test('rotation changes identify edited and moved cards separately from metadata and switch changes',function()
    assert(a.RotationUnsavedState,'unsaved change comparison missing')
    local before={name='One',metadata={author='A'},switch={},rotation={leaf('a'),leaf('b')},cooldowns={leaf('c')}}
    local after=a.RotationData.CopyData(before);after.rotation[1].action=8042;after.metadata.author='B';after.switch={type='COMBAT',unit='player'}
    local state=a:RotationUnsavedState(before,after)
    assert(state.cards.a and not state.cards.b and not state.cards.c and state.metadata and state.switch and not state.name)
    after=a.RotationData.CopyData(before);after.rotation[1],after.rotation[2]=after.rotation[2],after.rotation[1];state=a:RotationUnsavedState(before,after)
    assert(state.cards.a and state.cards.b and not state.metadata)
end)
test('plain change comparison sees deletions and distinct numeric/string keys without running callbacks',function()
    assert(a.UnsavedDataEqual);local before={[0]={name='A'},fn=function() error('ran callback') end};local after={['0']={name='A'},fn=before.fn}
    assert(not a:UnsavedDataEqual(before,after));after={[0]={name='A'},fn=before.fn};assert(a:UnsavedDataEqual(before,after));after.fn=nil;assert(not a:UnsavedDataEqual(before,after))
end)
finish()
