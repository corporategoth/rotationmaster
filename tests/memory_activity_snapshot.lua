local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function setup()
 local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);local a,e=f.addon,f.env;local calls=0
 local create=e.CreateFrame;e.CreateFrame=function(...)calls=calls+1;return create(...)end
 f.load('Diagnostics/cpu.lua')
 return f,a,function()return calls end
end
test('retained diagnostic is passive at load and exposes only detached scalar counts',function()
 local f,a,frames=setup();assert(type(a.GetRetainedMemoryDiagnostic)=='function','scalar retained seam missing');assert(frames()==0)
 local callback=function()end;local source={spellIDs={n=7,capped=false},spellNames={n=8,capped=true}}
 a:BindCPUActivityDiagnostic('spell',function()return source end)
 a:BindCPUActivityDiagnostic('item',function()return {itemRecords={n=9,capped=false},itemIndex={n=10,capped=false}}end)
 a:BindCPUActivityDiagnostic('visual',function()return {buttons=2,slots=3,sequence=1,capped=true,callbacks={overlay=callback}}end)
 local value=a:GetRetainedMemoryDiagnostic();assert(frames()==1 and value.spellIDs==7 and value.spellNames==8 and value.spellNamesCapped and value.sequence==1 and value.sequenceCapped)
 for _,v in pairs(value)do assert(type(v)=='number'or type(v)=='boolean','object/callback escaped')end
 value.spellIDs=99;assert(source.spellIDs.n==7 and a:GetRetainedMemoryDiagnostic().spellIDs==7 and frames()==1)
end)
test('missing malformed throwing and restricted readers withhold counts',function()
 local f,a=setup();assert(type(a.GetRetainedMemoryDiagnostic)=='function','scalar retained seam missing')
 a:BindCPUActivityDiagnostic('spell',function()error('SECRET_INTERNAL')end)
 a:BindCPUActivityDiagnostic('item',function()return {itemRecords={n=9000,capped=false},itemIndex={n=11,capped=false}}end)
 f.env.issecretvalue=function(value)return value==11 end
 local value=a:GetRetainedMemoryDiagnostic();assert(next(value)==nil,'fabricated or restricted scalar exposed')
end)
test('foreign owner cannot invoke retained providers',function()
 local _,a=setup();assert(type(a.GetRetainedMemoryDiagnostic)=='function','scalar retained seam missing');local calls=0
 a:BindCPUActivityDiagnostic('spell',function()calls=calls+1;return{}end)
 assert(a.GetRetainedMemoryDiagnostic({})==nil and calls==0)
end)
finish()
