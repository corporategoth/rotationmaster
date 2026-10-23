-- Build context: equipment, enchants, gems, set pieces, temporary weapon
-- enchants, talents/loadouts and season rules are normalized once per
-- notification, read from cache by conditions and pack applicability, and
-- feature-detected per client family.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(project,expansion)
 local f=F.new(project or 5,expansion or 1,'SHAMAN');local a,e=f.addon,f.env
 local s={calls={},frames={},pending={},enchant={true,1000,1,283,false,nil,nil,nil}}
 local function hit(name)s.calls[name]=(s.calls[name] or 0)+1 end
 e.CreateFrame=function()
  local frame={events={}};s.frames[#s.frames+1]=frame
  function frame:SetScript(_,fn)self.onEvent=fn end
  function frame:RegisterEvent(event)self.events[event]=true end
  function frame:RegisterUnitEvent(event,unit)assert(unit=='player');self.events[event]=true end
  return frame
 end
 s.items={[1]={id=1001,set=500,link='item:1001:2543:3101:0:0:0:0'},[5]={id=1002,set=500,link='item:1002:0:0:0:0:0:0'},
  [7]={id=1003,set=501,link='item:1003:0:0:0:0:0:0'},[16]={id=2000,link='item:2000:1900:0:0:0:0:0'}}
 e.GetInventoryItemID=function(unit,slot)hit('id');assert(unit=='player');return s.items[slot] and s.items[slot].id end
 e.GetInventoryItemLink=function(_,slot)hit('link');local item=s.items[slot];return item and ('|cff|H'..item.link..'|h[Item]|h|r') end
 e.GetItemInfo=function(id)hit('info');if s.pending[id] then return nil end
  for _,item in pairs(s.items) do if item.id==id then return 'Item',nil,4,100,60,'Armor','Mail',1,'INVTYPE_HEAD',1,1,4,3,1,1,item.set or 0 end end end
 e.GetItemStats=function(link)hit('stats');if link:find('item:1001:') then return {EMPTY_SOCKET_RED=1,EMPTY_SOCKET_META=1} end;return {} end
 e.GetWeaponEnchantInfo=function()hit('enchant');return unpack(s.enchant,1,8) end
 e.GetItemSetInfo=function(id)if id==500 then return 'Cyclone Regalia' end end
 f.load('Platform/talents.lua');f.load('Core/build_context.lua')
 local function fire(event,...)for _,frame in ipairs(s.frames) do if frame.events[event] and frame.onEvent then frame.onEvent(frame,event,...) end end end
 return f,a,e,s,fire
end

test('equipment enchants gems sockets and set pieces normalize once and refresh only on a notification',function()
 local _,a,_,s,fire=fixture()
 local context=a:GetBuildContext();local head=context.equipment[1]
 assert(head.itemID==1001 and head.enchantID==2543 and head.gems[1]==3101 and #head.gems==1 and head.sockets==2 and head.setID==500)
 assert(context.equipment[16].enchantID==1900 and context.equipment[16].setID==nil and context.equipment[2]==nil)
 assert(a:GetEquippedSetPieces(500)==2 and a:GetEquippedSetPieces(501)==1 and a:GetEquippedSetPieces(999)==0)
 local reads=s.calls.id;for _=1,50 do a:GetEquippedSetPieces(500);a:GetBuildContext() end
 assert(s.calls.id==reads and reads==19,'build context rescanned without a notification')
 s.items[7]=nil;fire('UNIT_INVENTORY_CHANGED','party1');assert(a:GetEquippedSetPieces(501)==1,'another unit invalidated the player')
 fire('PLAYER_EQUIPMENT_CHANGED',7,true);assert(a:GetEquippedSetPieces(501)==0 and s.calls.id==reads+19)
end)

test('set counts stay unknown while item metadata loads and resolve on its arrival',function()
 local _,a,_,s,fire=fixture();s.pending[1003]=true
 local count,why=a:GetEquippedSetPieces(500);assert(count==nil and why=='item-data-pending','understated count while loading')
 local before=s.calls.id;fire('GET_ITEM_INFO_RECEIVED',4242,true);s.pending[1003]=nil;fire('GET_ITEM_INFO_RECEIVED',1003,true)
 assert(a:GetEquippedSetPieces(501)==1 and a:GetEquippedSetPieces(500)==2 and s.calls.id==before+19)
 fire('GET_ITEM_INFO_RECEIVED',1,true);a:GetBuildContext();assert(s.calls.id==before+19,'resolved metadata kept rescanning')
end)

test('temporary weapon enchants and missing APIs are explicit',function()
 local _,a,e,s,fire=fixture();local weapons=a:GetBuildContext().weapons
 assert(weapons.main.enchanted and weapons.main.enchantID==283 and not weapons.off.enchanted)
 s.enchant={false,nil,nil,nil,true,1000,1,7};fire('UNIT_INVENTORY_CHANGED','player')
 weapons=a:GetBuildContext().weapons;assert(not weapons.main.enchanted and weapons.off.enchantID==7)
 e.GetWeaponEnchantInfo=nil;e.GetInventoryItemID=nil;a:InvalidateBuildContext()
 assert(a:GetBuildContext().weapons.reason=='missing-api');local value,why=a:GetEquippedSetPieces(500);assert(value==nil and why=='missing-api')
end)

test('talent trees summarize per client family and refresh on talent notifications',function()
 local _,a,e,_,fire=fixture(5,1);local points={5,31,0}
 e.GetNumTalentTabs=function()return 3 end;e.GetTalentTabInfo=function(tree)return ({'Elemental','Enhancement','Restoration'})[tree],'icon',points[tree] end
 e.GetActiveTalentGroup=function()return 1 end
 local talents=a:GetTalentBuild();assert(talents.layout=='tree' and talents.primary==2 and talents.summary=='5/31/0' and talents.group==1)
 points[3]=40;assert(a:GetTalentBuild().primary==2,'talents rescanned without a notification')
 fire('CHARACTER_POINTS_CHANGED');assert(a:GetTalentBuild().primary==3)
end)

test('modern trait loadouts report the active and saved configuration',function()
 local _,a,e=fixture(1,10)
 e.GetSpecialization=function()return 2 end;e.GetSpecializationInfo=function(index)assert(index==2);return 263 end
 e.C_ClassTalents={GetActiveConfigID=function()return 11 end,GetLastSelectedSavedConfigID=function(spec)assert(spec==263);return 42 end}
 e.C_Traits={GetConfigInfo=function(id)return {name=id==42 and 'Raid' or 'Active'} end}
 local talents=a:GetTalentBuild();assert(talents.layout=='traits' and talents.loadout.specID==263 and talents.loadout.configID==11 and talents.loadout.savedConfigID==42 and talents.loadout.name=='Raid')
 local _,b,f=fixture(1,10);f.GetSpecialization=function()return nil end
 assert(b:GetTalentBuild().loadout.reason=='missing-api','missing trait API not reported')
end)

test('season and game rules become pack rulesets',function()
 local _,a,e=fixture(2,0);e.C_Seasons={GetActiveSeason=function()return 2 end};e.Enum.SeasonID={NoSeason=0,SeasonOfDiscovery=2}
 local rules=a:GetBuildRulesets();assert(rules['season:2'] and rules['season:seasonofdiscovery'] and not rules.standard and not rules.hardcore)
 local _,b,f=fixture(2,0);f.C_GameRules={IsHardcoreActive=function()return true end,IsSelfFoundActive=function()return true end,GetCurrentGameModeRecordID=function()return 3 end}
 rules=b:GetBuildRulesets();assert(rules.hardcore and rules['self-found'] and rules['mode:3'] and not rules.standard)
 local _,c=fixture(5,1);assert(c:GetBuildRulesets().standard,'a plain realm is not standard')
end)

test('packaged applicability rulesets select by the active season',function()
 local _,a,e=fixture(2,0);local data,envelope,validation=dofile('tests/fixtures/rotation_data.lua')();a.RotationData=data;a.conditionDefinitions=validation.conditions
 e.UnitLevel=function()return 11 end;e.GetBuildInfo=function()return '1.15','20202','Date',11507 end
 local reader
 local fx={load=function(path)local chunk=assert(loadfile(path));setfenv(chunk,e);return chunk('rotationmaster',a)end}
 for _,path in ipairs({'Data/catalog.lua','Data/diff.lua','Data/rotation_store.lua','Core/rotation_library.lua'}) do fx.load(path) end
 assert(a:BindRotationLibraryReader(function(value)reader=value end))
 local pack=envelope();pack.applicability.families={'era'};pack.applicability.rulesets={'hardcore','season:seasonofdiscovery'}
 local view={enabled=true,validation={valid=true,supported=true,resolved=true},applicability=pack.applicability}
 local ok,why=reader:Eligible(view,0,false);assert(not ok and why=='ruleset-mismatch','standard realm admitted a seasonal pack: '..tostring(why))
 e.C_Seasons={GetActiveSeason=function()return 2 end};e.Enum.SeasonID={SeasonOfDiscovery=2};a:InvalidateBuildContext('client')
 ok,why=reader:Eligible(view,0,false);assert(ok,'season pack not eligible on its season: '..tostring(why))
 a.GetBuildRulesets=nil;ok,why=reader:Eligible(view,0,false);assert(not ok and why=='unsupported-context-selector','missing provider assumed a match')
end)

test('set piece weapon imbue and action context conditions read the caches',function()
 local f,a,e,s=fixture();f.load('Core/conditions.lua');f.load('Conditions/build.lua')
 local defs=a.conditionDefinitions or a.definitions;local set,imbue,context=defs.SET_PIECES,defs.WEAPON_IMBUE,defs.ACTION_CONTEXT
 assert(set.valid(nil,{set=500,operator='GREATERTHANOREQUALS',value=2}) and not set.valid(nil,{set=0,operator='GREATERTHANOREQUALS',value=2}))
 assert(set.evaluate({set=500,operator='GREATERTHANOREQUALS',value=2})==true and set.evaluate({set=500,operator='GREATERTHANOREQUALS',value=3})==false)
 local reads=s.calls.id;for _=1,25 do set.evaluate({set=501,operator='EQUALS',value=1}) end;assert(s.calls.id==reads,'condition scanned equipment per evaluation')
 assert(set.print(nil,{set=500,operator='GREATERTHANOREQUALS',value=2}):find('Cyclone Regalia',1,true))
 assert(imbue.evaluate({enchant=283},{})==true and imbue.evaluate({enchant=7},{})==false and imbue.evaluate({enchant=283,offhand=true},{})==false)
 e.GetWeaponEnchantInfo=function()return true,1000,1,{} end;local value,why=imbue.evaluate({enchant=283},{});assert(value==nil and why=='invalid-weapon-observation')
 local unavailable,reason=context.evaluate({context='vehicle'});assert(unavailable==nil and reason=='action-context-unavailable')
 a.GetActionContext=function()return 'vehicle' end;assert(context.evaluate({context='vehicle'})==true and context.evaluate({context='player'})==false)
 assert(context.valid(nil,{context='possession'}) and not context.valid(nil,{context='raid'}))
 a.GetEquippedSetPieces=nil;value,why=set.evaluate({set=500,operator='GREATERTHANOREQUALS',value=2});assert(value==nil and why=='build-context-unavailable')
end)

test('mainline registers the temporary weapon enchant condition',function()
 local f,a=fixture(1,10);f.load('Conditions/build.lua')
 assert(a.definitions.SET_PIECES and a.definitions.ACTION_CONTEXT and a.definitions.WEAPON_IMBUE)
end)

finish()
