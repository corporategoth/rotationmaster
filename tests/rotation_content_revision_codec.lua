local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local h=assert(io.open('tests/rotation_scope_transport.lua'));local source=h:read('*a');h:close()
local prefix=assert(source:match('^(.-)\ntest%('));local fixture,profile=assert(loadstring(prefix..'\nreturn fixture,profile','@revision-real-profile-codec'))()
test('actual profile wire codec preserves local edit revisions across all ownership maps',function()
 local a,codec=fixture();local p=profile();p.rotationStore.classes.SHAMAN[0].same.body.revision=9007199254740991
 assert(a:ValidateProfileTransfer(p));local wire=assert(a:ProfileToPortable(p));local text=assert(codec:Encode({format='RM-Profile',version=1,profile=wire}))
 local restored=assert(a:ProfileFromPortable(assert(codec:Decode(text)).value.profile,{preserveLegacyBodies=true}));assert(restored.rotationStore.classes.SHAMAN[0].same.body.revision==9007199254740991)
 assert(p.rotationStore.classes.SHAMAN[0].same.body.revision==9007199254740991)
end)
test('raw body and envelope round trips keep separate body and source revisions',function()
 local a,codec=fixture();local d=a.RotationData
 local body={name='Saved',revision=17,rotation={},cooldowns={}};local decoded=assert(codec:Decode(assert(codec:Encode(body))));assert(decoded.value.revision==17 and decoded.kind=='legacy')
 local _,envelope=dofile('tests/fixtures/rotation_data.lua')();local value=envelope();value.revision=4;value.body.revision=17
 local full=assert(codec:Decode(assert(codec:Encode(value))));assert(full.value.body.revision==17 and full.value.revision==4 and full.kind=='envelope')
 assert(d.GetRotationContentRevision(full.value.body)==17)
end)
finish()
