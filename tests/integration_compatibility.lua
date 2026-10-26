local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(scopes)
 local f=F.new()
 if scopes then
  local h=assert(io.open('Integrations/catalog.lua'));local source=h:read('*a');h:close()
  local count;source,count=source:gsub('local scopes=%b{}',function()return 'local scopes='..scopes end,1);assert(count==1)
  local fn=assert(loadstring(source,'@actual-catalog-fixture'));setfenv(fn,f.env);fn('rotationmaster',f.addon)
 else f.load('Integrations/catalog.lua')end
 return f,f.addon
end
test('declared matching addon edition scope filters external editors without using load state',function()
 local f,a=fixture();assert(a.GetIntegrationClientSupport,'client support lookup missing')
 f.env.IsAddOnLoaded=function()error('support lookup must be metadata only')end
 assert(a:GetIntegrationClientSupport('!!!LuaWorkbench',{family='tbc',interface=20506})=='supported')
 assert(a:GetIntegrationClientSupport('!!!LuaWorkbench',{family='era',interface=11509})=='unsupported')
end)
test('a differently named successor cannot authorize old integration visibility',function()
 local _,a=fixture();assert(a:GetIntegrationClientSupport('AzeriteUI',{family='retail',interface=120105})=='unsupported')
 assert(a:GetIntegrationClientSupport('AzeriteUI',{family='era',interface=11509})=='supported')
 assert(a:GetIntegrationClientSupport('AzeriteUI',{family='tbc',interface=20507})=='supported','older patch evidence invented an expiry')
end)
test('progression branches retain distinct declared scopes',function()
 local _,a=fixture()
 assert(a:GetIntegrationClientSupport('ExtendedCharacterStats',{family='progression',interface=30403})=='supported')
 assert(a:GetIntegrationClientSupport('ExtendedCharacterStats',{family='progression',interface=50504})=='unsupported')
 assert(a:GetIntegrationClientSupport('ExtendedCharacterStats',{family='progression'})=='unknown')
 assert(a:GetIntegrationClientSupport('Questie',{family='progression',interface=40402})=='supported')
 assert(a:GetIntegrationClientSupport('MobInfo2',{family='progression',interface=40401})=='supported')
 assert(a:GetIntegrationClientSupport('WeakAuras',{family='progression',interface=40402})=='supported','official Cataclysm release was omitted')
 assert(a:GetIntegrationClientSupport('LUI',{family='progression',interface=30402})=='supported','published matching-folder Wrath release was omitted')
 assert(a:GetIntegrationClientSupport('LUI',{family='progression',interface=50504})=='supported')
 assert(a:GetIntegrationClientSupport('LUI',{family='progression',interface=40402})=='unsupported','Wrath evidence must not imply Cataclysm support')
end)
test('unknown client identity and unverified addon scope remain unknown',function()
 local _,a=fixture()
 for _,id in ipairs({'New custom editor','WowLua','G15Buttons'})do assert(a:GetIntegrationClientSupport(id,{family='tbc',interface=20506})=='unknown')end
 assert(a:GetIntegrationClientSupport('!!!LuaWorkbench',{})=='unknown')
 assert(a:GetIntegrationClientSupport('!!!LuaWorkbench',nil)=='unknown')
end)
test('explicit publisher interface constraints work without age-based guesses',function()
 local _,a=fixture('{Fixture={families={"tbc"},interfaceRanges={tbc={min=20506,max=20507}}}}')
 assert(a:GetIntegrationClientSupport('Fixture',{family='tbc',interface=20505})=='unsupported')
 assert(a:GetIntegrationClientSupport('Fixture',{family='tbc',interface=20506})=='supported')
 assert(a:GetIntegrationClientSupport('Fixture',{family='tbc',interface=20508})=='unsupported')
 assert(a:GetIntegrationClientSupport('Fixture',{family='tbc'})=='unknown')
end)
test('unscoped progression metadata cannot imply every progression branch',function()
 local _,a=fixture('{Fixture={families={"progression"},interfaceRanges={}}}')
 assert(a:GetIntegrationClientSupport('Fixture',{family='progression',interface=50504})=='unknown')
end)
test('an addon that does nothing for RM on a client is out of that client scope',function()
 local _,a=fixture()
 local retail,forever={family='retail',interface=120105},{family='forever',interface=16001}
 local era,tbc,mists={family='era',interface=11509},{family='tbc',interface=20506},{family='progression',interface=50504}
 -- WeakAuras: only RM's outgoing ScanEvents call matters. Retail has no current build;
 -- Forever has the Musca Auras fork (folder WeakAuras) and ForeverAuras, both defining ScanEvents.
 assert(a:GetIntegrationClientSupport('WeakAuras',retail)=='unsupported')
 assert(a:GetIntegrationClientSupport('WeakAuras',forever)=='supported')
 assert(a:GetIntegrationClientSupport('WeakAuras',era)=='supported' and a:GetIntegrationClientSupport('WeakAuras',mists)=='supported')
 assert(a:GetIntegrationClientSupport('ForeverAuras',forever)=='supported')
 for _,client in ipairs({retail,era,tbc,mists})do assert(a:GetIntegrationClientSupport('ForeverAuras',client)=='unsupported')end
 -- MobInfo2 history is keyed by NPC name, which is secret on the restricted clients.
 assert(a:GetIntegrationClientSupport('MobInfo2',retail)=='unsupported' and a:GetIntegrationClientSupport('MobInfo2',forever)=='unsupported')
 assert(a:GetIntegrationClientSupport('MobInfo2',tbc)=='supported' and a:GetIntegrationClientSupport('MobInfo2',era)=='supported')
 -- The boss-mod adapter binds on Era, TBC and Classic progression only.
 for _,id in ipairs({'DBM-Core','BigWigs'})do
  assert(a:GetIntegrationClientSupport(id,retail)=='unsupported' and a:GetIntegrationClientSupport(id,forever)=='unsupported')
  assert(a:GetIntegrationClientSupport(id,tbc)=='supported' and a:GetIntegrationClientSupport(id,era)=='supported' and a:GetIntegrationClientSupport(id,mists)=='supported')
 end
 -- TotemTimers' Retail file is historical; the project ships Forever and Classic builds.
 assert(a:GetIntegrationClientSupport('TotemTimers',retail)=='unsupported' and a:GetIntegrationClientSupport('TotemTimers',forever)=='supported')
 -- Action bars new to the catalog.
 assert(a:GetIntegrationClientSupport('EllesmereUIActionBars',retail)=='supported' and a:GetIntegrationClientSupport('EllesmereUIActionBars',forever)=='supported')
 assert(a:GetIntegrationClientSupport('EllesmereUIActionBars',tbc)=='unsupported' and a:GetIntegrationClientSupport('EllesmereUIActionBars',era)=='unsupported')
 for _,client in ipairs({retail,forever,era,tbc,mists})do assert(a:GetIntegrationClientSupport('AzeriteUI6',client)=='supported')end
 assert(a:GetIntegrationClientSupport('AzeriteUI',retail)=='unsupported','the v5 identity stays Era and TBC only')
end)
test('dropped addons have no catalog scope or links',function()
 local f,a=fixture()
 for _,id in ipairs({'G15Buttons','SyncUI','Neuron','DiabolicUI','SamyTotemTimers','WowLua'})do
  assert(a:GetIntegrationClientSupport(id,{family='tbc',interface=20506})=='unknown',id)
  assert(#a:GetIntegrationProjectLinks(id)==0,id)
 end
end)
test('boss-mod companions are listed with the addon they extend',function()
 local _,a=fixture()
 local function has(id,fragment)for _,link in ipairs(a:GetIntegrationProjectLinks(id))do if link.url:find(fragment,1,true)then return link end end end
 assert(has('BigWigs','/wow/addons/littlewigs'),'LittleWigs companion link missing')
 assert(has('DBM-Core','/wow/addons/deadly-boss-mods-dbm-dungeons'),'DBM dungeon pack companion link missing')
 assert(has('WeakAuras','/dldvlpr-addons-wow/Musca-Auras') and has('WeakAuras','/wow/addons/musca-auras'))
 assert(not has('BigWigs','/littlewigs').primary and not has('DBM-Core','dbm-dungeons').primary)
end)
finish()
