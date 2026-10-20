-- Actual native editor construction/profile transport; frame APIs are modeled.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
 local f,a=dofile('tests/fixtures/lua_workbench.lua')()
 a.DiscoverLuaEditorIntegrations=function()end
 a.IsLuaWorkbenchIntegrationAvailable=function()return false end
 a.LuaSyntax={enable=function()end,disable=function()end,decode=function(text)return text end}
 local ok=pcall(require,'bit')
 if ok then local data,deps=dofile('tests/fixtures/codec.lua')();a.RotationData=data;a.NewRotationCodec=function()return data.NewCodec(deps)end
 else for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua'})do f.load(path)end end
 f.load('Core/profile_data.lua')
 return f,a
end
local function create(f,a,preference,host)
 if host then return a:AcquireSourceLuaEditor(host,f.env.UIParent,function()end,function()return true end,preference)end
 return a:CreateWorkbenchLuaEditor(f.env.UIParent,function()end,function()return true end,preference)
end
test('native highlighting preference is honored by both cold editor entry points',function()
 for _,pooled in ipairs({false,true})do
  local f,a=fixture();a.db.profile.lua_native_highlighting=false
  local c=create(f,a,'native',pooled and{}or nil);assert(not c.syntax,'native preference false still highlights');c:Release()
  a.db.profile.lua_native_highlighting=true
  c=create(f,a,'native',pooled and{}or nil);assert(c.syntax==a.LuaSyntax,'native preference true lost highlighting');c:Release()
 end
end)
test('plain legacy selection and missing optional preference keep their existing rendering',function()
 local f,a=fixture();a.db.profile.lua_editor='plain'
 local c=create(f,a,'plain');assert(not c.syntax);c:Release()
 a.db.profile.lua_editor='native';c=create(f,a,'native');assert(c.syntax==a.LuaSyntax);c:Release()
end)
test('native preference changes take effect on reopen without mutating the active input',function()
 local f,a=fixture();local owner={};local c=create(f,a,'native',owner);assert(c.syntax)
 c:SetText('return 42');a.db.profile.lua_native_highlighting=false
 assert(c.syntax and c:GetText()=='return 42');c:Release()
 local nextControl=create(f,a,'native',owner);assert(not nextControl.syntax);nextControl:Release()
end)
test('disabled custom factories are never invoked by explicit or automatic selection',function()
 local f,a=fixture();local calls=0
 assert(a:RegisterLuaEditorProvider('Third editor',function()calls=calls+1;error('disabled factory ran')end))
 a.db.profile.lua_editor_disabled={['Third editor']=true};a.db.profile.lua_native_highlighting=false
 for _,preferred in ipairs({'Third editor','auto'})do for _,pooled in ipairs({false,true})do
  local c=create(f,a,preferred,pooled and{}or nil);assert(not c.syntax);c:Release()
 end end
 assert(calls==0,'disabled custom factory invoked')
end)
test('unavailable external and failed factories respect the Native fallback preference',function()
 local f,a=fixture();a.db.profile.lua_native_highlighting=false
 local c=create(f,a,'LuaWorkbench',{});assert(not c.syntax,'source unavailable fallback ignored preference');c:Release()
 assert(a:RegisterLuaEditorProvider('Failed editor',function()error('provider failure')end))
 c=create(f,a,'Failed editor');assert(not c.syntax,'constructor failure ignored preference');c:Release()
end)
test('profile transport preserves false highlighting and independent disabled custom identifiers',function()
 local _,a=fixture();local value={lua_editor='Third editor',lua_native_highlighting=false,lua_editor_disabled={native=true,['Future editor']=true}}
 assert(a:ValidateProfileTransfer(value),'new optional preferences rejected')
 local wire=assert(a:ProfileToPortable(value));local copy=assert(a:ProfileFromPortable(wire))
 assert(copy.lua_native_highlighting==false and copy.lua_editor_disabled['Future editor'])
 copy.lua_editor_disabled.native=nil;assert(value.lua_editor_disabled.native)
 assert(not a:ValidateProfileTransfer({lua_native_highlighting='false'}))
end)
test('disabled identifier map is bounded and rejects reserved or malformed entries',function()
 local _,a=fixture();local map={};for i=1,64 do map['Provider '..i]=true end
 assert(a:ValidateProfileTransfer({lua_editor_disabled=map}),'64 bounded provider identifiers refused')
 map['Provider 65']=true;assert(not a:ValidateProfileTransfer({lua_editor_disabled=map}));map['Provider 65']=nil
 for _,bad in ipairs({{plain=true},{auto=true},{['']=true},{['   ']=true},{[string.rep('x',129)]=true},{native=false},{native=1},setmetatable({native=true},{})})do
  assert(not a:ValidateProfileTransfer({lua_editor_disabled=bad}),'malformed disabled map accepted')
 end
end)
test('automatic skips unavailable Workbench and uses another enabled registered editor',function()
 for _,pooled in ipairs({false,true})do
  local f,a=fixture();local workbenchCalls,otherCalls=0,0
  a:RegisterLuaEditorProvider('LuaWorkbench',function()workbenchCalls=workbenchCalls+1;error('unavailable')end)
  a:RegisterLuaEditorProvider('Z editor',function(host,changed,valid)otherCalls=otherCalls+1;return a:CreateWorkbenchLuaEditor(host,changed,valid,'plain')end)
  local c=create(f,a,'auto',pooled and{}or nil);assert(workbenchCalls==0 and otherCalls==1);c:Release()
 end
end)
test('disabled external choice uses enabled Native with its highlighting preference',function()
 for _,pooled in ipairs({false,true})do
  local f,a=fixture();a.db.profile.lua_editor_disabled={LuaWorkbench=true};a.db.profile.lua_native_highlighting=true
  local c=create(f,a,'LuaWorkbench',pooled and{}or nil);assert(c.syntax==a.LuaSyntax);c:Release()
 end
end)
finish()
