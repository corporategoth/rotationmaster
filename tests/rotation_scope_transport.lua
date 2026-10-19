local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local data,deps=dofile('tests/fixtures/codec.lua')();local a=f.addon;a.RotationData=data
    f.load('Data/catalog.lua');f.load('Data/rotation_store.lua');f.load('Core/rotation_migration.lua')
    return a,assert(data.NewCodec(deps))
end
local function profile()
    return {version=3,rotationFallbackID='Exact original fallback',rotationStore={version=1,classes={SHAMAN={[0]={same={body={name='Class',rotation={},cooldowns={}},comparison={kind='custom',id='ancestor',origins={},sourceAddress={scope='character',class='SHAMAN',owner='Old - Realm',spec=0,id='ancestor'}}}}}},characters={},legacy={rotations={[0]={old={}}}}}}
end
test('native legacy profile decode archives exact empty bodies while saved one-argument callers retain normalization',function()
    local a=fixture();local wire={version=2,rotations={['0']={Old={}}}}
    local old=assert(a:ProfileFromPortable(wire));assert(old.rotations[0].Old.rotation and old.rotations[0].Old.cooldowns)
    local native=assert(a:ProfileFromPortable(wire,{preserveLegacyBodies=true}));assert(next(native.rotations[0].Old)==nil)
    assert(a:ApplyRotationProfileMigration(assert(a:PlanRotationProfileMigration(native,'Exact original fallback'))));assert(a:ValidateProfileTransfer(native))
    assert(next(native.rotationStore.legacy.rotations[0].Old)==nil and next(wire.rotations['0'].Old)==nil)
end)
test('version3 explicit fallback and historical full source address survive actual profile wire codec unchanged',function()
    local a,codec=fixture();local p=profile();assert(a:ValidateProfileTransfer(p))
    local text=assert(codec:Encode({format='RM-Profile',version=1,profile=assert(a:ProfileToPortable(p))}))
    local recovered=assert(a:ProfileFromPortable(assert(codec:Decode(text)).value.profile,{preserveLegacyBodies=true}))
    assert(a:SettingsDataEqual(p,recovered) and recovered.rotationStore.classes.SHAMAN[0].same.comparison.sourceAddress.spec==0)
    assert(recovered.rotationFallbackID=='Exact original fallback')
end)
test('source-address provenance is strict historical data rather than forged current read authority',function()
    local a=fixture()
    for _,mutate in ipairs({function(c) c.sourceAddress.id='different' end,function(c) c.sourceAddress.extra=true end,function(c) c.sourceAddress.scope='legacy' end,function(c) c.kind='builtin' end,function(c) c.sourceAddress.spec=0/0 end}) do
        local p=profile();mutate(p.rotationStore.classes.SHAMAN[0].same.comparison);assert(not a:ValidateProfileTransfer(p))
    end
    local p=profile();p.rotationFallbackID=nil;assert(a:ValidateProfileTransfer(p));local value,why=a:PlanRotationProfileMigration(p,'Do not infer');assert(not value and why=='missing-fallback-configuration')
end)
finish()
