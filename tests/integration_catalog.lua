local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local expected={'ExtendedCharacterStats','MobInfo2','!!!LuaWorkbench','WowLua','WeakAuras','Masque','Questie','DBM-Core','BigWigs','Titan','ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'}
local function fixture(legacy)
 local f=F.new();local present,versions,calls={},{},{}
 local function loaded(id)calls[#calls+1]={'loaded',id};return present[id]==true end
 local function metadata(id,key)assert(key=='Version');calls[#calls+1]={'version',id};return versions[id]end
 -- No current client has the legacy addon globals (C_AddOns everywhere): they model an older
 -- build, placed past the fixture's client guard.
 if legacy then f.env.C_AddOns=nil;rawset(f.env,'IsAddOnLoaded',loaded);rawset(f.env,'GetAddOnMetadata',metadata)
 else f.env.C_AddOns={IsAddOnLoaded=loaded,GetAddOnMetadata=metadata} end
 local fn=loadfile('Integrations/catalog.lua');assert(fn,'integration inventory module missing');setfenv(fn,f.env);fn('RotationMaster',f.addon)
 assert(type(f.addon.ListIntegrationStatus)=='function','integration inventory API missing')
 return f,present,versions,calls
end
local function byID(rows,id)for _,row in ipairs(rows)do if row.id==id then return row end end;error('missing '..id)end
test('module load is idle and every supported addon remains visible when missing',function()
 local f,_,_,calls=fixture();assert(#calls==0)
 local rows=f.addon:ListIntegrationStatus();assert(#rows==#expected)
 for i,row in ipairs(rows)do assert(row.id==expected[i]and row.state=='missing'and type(row.name)=='string'and type(row.detail)=='string'and row.version==nil);assert(getmetatable(row)==nil)end
 assert(#calls==2*#expected and getmetatable(rows)==nil)
end)
test('modern and legacy metadata are exact dot calls and fresh versions',function()
 for _,legacy in ipairs({false,true})do
  local f,p,v,calls=fixture(legacy);p.MobInfo2=true;v.MobInfo2='1.2.3'
  assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version=='1.2.3')
  v.MobInfo2='2.0';assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version=='2.0')
  assert(#calls==4*#expected)
 end
end)
test('not-loaded addons retain safely detected version without implying installed absence',function()
 local f,_,versions=fixture();versions.MobInfo2='installed-not-loaded'
 local row=byID(f.addon:ListIntegrationStatus(),'MobInfo2')
 assert(row.state=='missing'and row.version=='installed-not-loaded','metadata for not-loaded addon was omitted')
end)
test('no addon provider discovery or gameplay callback is executed for inventory',function()
 local f,p=fixture();for _,id in ipairs(expected)do p[id]=true end
 f.addon.ListLuaEditorProviders=function()error('provider discovery')end;f.addon.DiscoverLuaEditorIntegrations=function()error('editor registration')end
 f.env.MI2_GetMobData=function()error('history query')end;f.env.WeakAuras={ScanEvents=function()error('events')end}
 f.env.UnitName=function()error('gameplay')end;f.env.GetTime=function()error('clock')end;f.env.CreateFrame=function()error('frame')end
 f.addon:ListIntegrationStatus()
end)
test('connection requires current owned capability rather than loaded flag alone',function()
 local f,p=fixture();p.ExtendedCharacterStats=true;p['!!!LuaWorkbench']=true;p.WeakAuras=true;p.MobInfo2=true
 local a=f.addon;local rows=a:ListIntegrationStatus();assert(byID(rows,'ExtendedCharacterStats').state=='loaded'and byID(rows,'!!!LuaWorkbench').state=='loaded')
 a.conditionDefinitions={ECS_STAT={},ECS_STAT_PCT={}};a.CreateLuaWorkbenchControl=function()error('constructor')end;f.env.LuaWorkbench={}
 rows=a:ListIntegrationStatus();assert(byID(rows,'ExtendedCharacterStats').state=='connected'and byID(rows,'!!!LuaWorkbench').state=='connected')
 assert(byID(rows,'WeakAuras').state=='loaded'and byID(rows,'MobInfo2').state=='loaded')
 p['!!!LuaWorkbench']=false;assert(byID(a:ListIntegrationStatus(),'!!!LuaWorkbench').state=='missing')
end)
test('unreadable capability objects cannot certify a connection',function()
 local f,p=fixture();p['!!!LuaWorkbench']=true;p.ExtendedCharacterStats=true
 local secret={ECS_STAT={},ECS_STAT_PCT={}};f.env.LuaWorkbench=secret;f.addon.conditionDefinitions=secret
 f.addon.CreateLuaWorkbenchControl=function()error('constructor')end
 f.addon.Platform.CanReadValue=function(_,value)return value~=secret end
 local rows=f.addon:ListIntegrationStatus();assert(byID(rows,'!!!LuaWorkbench').state=='loaded'and byID(rows,'ExtendedCharacterStats').state=='loaded')
end)
test('cached Questie statuses map without refresh or enabling and cannot create loaded evidence',function()
 local f,p=fixture();local status,calls='available',0
 f.addon.GetQuestieIntegrationStatus=function(self)assert(self==f.addon);calls=calls+1;return{state=status}end
 f.addon.SyncQuestieIntegration=function()error('sync')end
 assert(byID(f.addon:ListIntegrationStatus(),'Questie').state=='missing'and calls==0)
 p.Questie=true
 for source,wanted in pairs({available='connected',disabled='disabled',waiting='loaded',missing='missing',incompatible='incompatible',['client-restricted']='incompatible',error='unknown',unavailable='unknown'})do status=source;assert(byID(f.addon:ListIntegrationStatus(),'Questie').state==wanted,source)end
end)
test('provider metadata and cached status failures are bounded and never echo errors',function()
 local f,p=fixture();p.Questie=true
 f.addon.GetQuestieIntegrationStatus=function()error('PRIVATE')end
 assert(byID(f.addon:ListIntegrationStatus(),'Questie').state=='unknown')
 f.env.C_AddOns.IsAddOnLoaded=function()error({private='PRIVATE'})end
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.state=='unknown'and not row.detail:find('PRIVATE'))end
end)
test('native malformed and restricted values cannot imply loaded or expose version',function()
 local f,p,v=fixture();f.env.C_AddOns.IsAddOnLoaded=function()return'yes'end
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.state=='unknown')end
 local secret={};f.env.C_AddOns.IsAddOnLoaded=function()return secret end;f.addon.Platform.CanReadValue=function(_,value)return value~=secret end
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.state=='unknown')end
 f.env.C_AddOns.IsAddOnLoaded=function()return true end;f.env.C_AddOns.GetAddOnMetadata=function()return secret end
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.version==nil)end
end)
test('native and localized display text is bounded control-sanitized and pipe-escaped',function()
 local f,p,v=fixture();p.MobInfo2=true;v.MobInfo2='|Tprivate-path|t\n'..string.rep('x',500)
 local row=byID(f.addon:ListIntegrationStatus(),'MobInfo2');assert(row.version=='||Tprivate-path||t?'..string.rep('x',500),'version was clipped or not sanitized')
end)
test('localized names and descriptions use the locale table and remain inert',function()
 local f=fixture();local L=f.env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster')
 L['MobInfo2']='Localized |Hunsafe|h label\n'
 L['Recorded creature history conditions; no current history is queried.']='Localized detail |Tpath|t'..string.rep('x',600)
 local row=byID(f.addon:ListIntegrationStatus(),'MobInfo2')
 assert(row.name=='Localized ||Hunsafe||h label?' and #row.detail<=320 and row.detail:find('Localized detail ||Tpath||t',1,true)==1)
end)
test('cached status is read as plain fields without invoking provider-like getters',function()
 local f,p=fixture();p.Questie=true
 f.addon.GetQuestieIntegrationStatus=function()return setmetatable({},{__index=function()error('PRIVATE GETTER')end})end
 assert(byID(f.addon:ListIntegrationStatus(),'Questie').state=='unknown')
 f.addon.Platform.CanReadValue=function()error('PRIVATE RESTRICTED')end
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.state=='unknown'and row.version==nil)end
end)
test('every result is detached and no source table or unexpected row field escapes',function()
 local f,p=fixture();p.WeakAuras=true;local rows=f.addon:ListIntegrationStatus();rows[1].id='corrupt';rows[2]=false;rows.extra={}
 local nextRows=f.addon:ListIntegrationStatus();assert(nextRows[1].id==expected[1]and type(nextRows[2])=='table'and nextRows.extra==nil)
 local fields={id=true,name=true,version=true,state=true,detail=true,projectURL=true,loaded=true};for _,row in ipairs(nextRows)do for key in pairs(row)do assert(fields[key],key)end end
 assert(#f.addon.ListIntegrationStatus({})==0)
end)
test('missing metadata APIs return unknown and module never invents provider connectivity',function()
 local f=fixture();f.env.C_AddOns={};f.env.IsAddOnLoaded=nil;f.env.GetAddOnMetadata=nil
 for _,row in ipairs(f.addon:ListIntegrationStatus())do assert(row.state=='unknown'and row.version==nil)end
end)
test('display limits preserve complete UTF8 codepoints and define malformed byte replacement',function()
 local f,_,versions=fixture();local L=f.env.LibStub('AceLocale-3.0'):GetLocale('RotationMaster')
 L.MobInfo2=string.rep('é',47)..'€';versions.MobInfo2=string.rep('é',46)..'|'..'😀'
 L['Recorded creature history conditions; no current history is queried.']=string.rep('€',106)..'😀'
 local row=byID(f.addon:ListIntegrationStatus(),'MobInfo2')
 assert(row.name==string.rep('é',47),'name split a valid Unicode character')
 assert(row.version==string.rep('é',46)..'||😀','version was clipped after expanded pipe')
 assert(row.detail==string.rep('€',106),'detail split a valid Unicode character')
 versions.MobInfo2=string.char(255,192,128,237,160,128,244,144,128,128)..'é'..string.char(240,159)
 assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version==string.rep('?',10)..'é??','malformed byte policy changed')
 versions.MobInfo2='é€😀|\n';assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version=='é€😀||?')
end)
test('full normal version strings are retained; oversized metadata is omitted instead of clipped',function()
 local f,p,v=fixture();p.MobInfo2=true;v.MobInfo2='v'..string.rep('123456789-',24)
 assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version==v.MobInfo2)
 v.MobInfo2=string.rep('x',4096);assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version==v.MobInfo2)
 v.MobInfo2=v.MobInfo2..'x';assert(byID(f.addon:ListIntegrationStatus(),'MobInfo2').version==nil,'oversized version displayed a misleading truncated prefix')
end)
test('addon loaded evidence stays independent of failed or missing adapter state',function()
 local f,p,v=fixture();p.Questie=true;v.Questie='12.1.0'
 f.addon.GetQuestieIntegrationStatus=function()error('provider failed')end
 local row=byID(f.addon:ListIntegrationStatus(),'Questie');assert(row.loaded==true and row.state=='unknown' and row.version=='12.1.0')
 f.addon.GetQuestieIntegrationStatus=function()return{state='missing'}end
 row=byID(f.addon:ListIntegrationStatus(),'Questie');assert(row.loaded==true and row.state=='missing')
 p.Questie=false;row=byID(f.addon:ListIntegrationStatus(),'Questie');assert(row.loaded==false and row.version=='12.1.0')
end)
test('Masque inventory reports cached connected compatibility and API minor without discovery',function()
 local f,p,v=fixture();p.Masque=true;v.Masque='12.1.0';local state='disabled'
 f.addon.GetMasquePreviewStatus=function()return{state=state,apiMinor=110210}end
 f.env.LibStub=function()error('inventory discovered provider')end
 for input,expected in pairs({connected='connected',disabled='disabled',incompatible='incompatible',error='unknown',unavailable='unknown',missing='missing'})do
  state=input;local row=byID(f.addon:ListIntegrationStatus(),'Masque');assert(row.state==expected and row.version=='12.1.0'and row.detail:find('110210',1,true))
 end
end)
test('boss-mod rows report the cached selected provider; the idle one is disabled; Titan stays passive',function()
 local f,p=fixture();local status={state='available',provider='DBM-Core'};local calls=0
 f.addon.GetEncounterIntegrationStatus=function(self)assert(self==f.addon);calls=calls+1;return status end
 f.addon.SyncEncounterIntegration=function()error('sync')end
 local rows=f.addon:ListIntegrationStatus()
 assert(byID(rows,'DBM-Core').state=='missing'and byID(rows,'BigWigs').state=='missing'and calls==0)
 p['DBM-Core']=true;p.BigWigs=true;p.Titan=true
 rows=f.addon:ListIntegrationStatus()
 assert(byID(rows,'DBM-Core').state=='connected'and byID(rows,'BigWigs').state=='disabled'and byID(rows,'Titan').state=='loaded')
 for source,wanted in pairs({available='connected',missing='missing',incompatible='incompatible',error='unknown',disabled='disabled'})do
  status={state=source,provider='BigWigs'};assert(byID(f.addon:ListIntegrationStatus(),'BigWigs').state==wanted,source)
  assert(byID(f.addon:ListIntegrationStatus(),'DBM-Core').state=='disabled')
 end
 status={state='disabled'};assert(byID(f.addon:ListIntegrationStatus(),'DBM-Core').state=='disabled')
 f.addon.GetEncounterIntegrationStatus=function()error('PRIVATE')end
 assert(byID(f.addon:ListIntegrationStatus(),'DBM-Core').state=='unknown')
 assert(byID(f.addon:ListIntegrationStatus(),'BigWigs').projectURL=='https://www.curseforge.com/wow/addons/big-wigs')
end)
finish()
