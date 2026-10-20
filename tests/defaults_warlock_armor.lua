-- Actual pack/catalog/engine/readiness and native button publishers; no trainer inference.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local file=assert(io.open(path));local text=file:read('*a');file:close();return text end
local path='Defaults/tbc/warlock-starter.lua'
-- Reuse the maintained native boundary fixture without executing its old-scope suite.
local base=read('tests/defaults_warlock.lua');local prefix=assert(base:match('^(.-)\ntest%('))
local make,first=assert(loadstring(prefix..'\nreturn fixture,first','@warlock-native-fixture'))()
local function fixture(historical)
 local original=loadfile
 if historical then
  local old=dofile('tests/fixtures/restore_tbc_warlock_armor.lua')(read(path))
  loadfile=function(file)if file==path then return assert(loadstring(old,'@archived-d5a970f-warlock'))end;return original(file)end
 end
 local ok,f,s,names=pcall(make);loadfile=original;assert(ok,f)
 local a,e=f.addon,f.env;local info,hasRange=e.C_Spell.GetSpellInfo,e.C_Spell.SpellHasRange
 names[706],names[1086]='Localized Armor family','Localized Armor family'
 e.C_Spell.GetSpellInfo=function(id)
  if id==706 or id==1086 then return {name=names[id],spellID=id,subtext=id==706 and 'Rank 1' or 'Rank 2'}end
  return info(id)
 end
 e.C_Spell.SpellHasRange=function(id)if id==706 or id==1086 then return false end;return hasRange(id)end
 a.SpellCatalog:UpdateSpell(706);a.SpellCatalog:UpdateSpell(1086)
 a.ScheduleTimer=function(_,callback,delay)assert(delay==.01);return callback end
 s.setLevel=function(level)s.level=level;a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 s.setLevel(20);return f,s,names
end
local function row(a)return assert(a:ListDefaultRotations(0)[1])end
local function optional(f,s,list)
 local a=f.addon;local ready=a:NewActionReadiness(100);local chosen,statuses={},{}
 for _,step in ipairs(list or row(a).envelope.body.cooldowns)do
  local result=a:evaluateConditionResult(step.conditions);statuses[step.id]=result.status
  if result.status=='match'then for _,id in ipairs(a:GetSpellIds(step)or{})do
   if s.mapped[id]~=false and ready('spell',id)then chosen[#chosen+1]=id;break end
  end end
 end
 return chosen,statuses
end
local function only(f,s,id)
 local selected=optional(f,s);assert(#selected==(id and 1 or 0),'unexpected armor reminders: '..table.concat(selected,','))
 if id then assert(selected[1]==id,'wrong armor: '..tostring(selected[1]))end
end
local function active(s,names,id)s.buffs={{name=names[id],spellId=id,sourceUnit='player'}}end

test('level twenty active Demon Armor never recommends a downgrade to Demon Skin',function()
 local f,s,names=fixture();s.known[706]=true;active(s,names,706);only(f,s,nil)
 assert(row(f.addon).eligible,'reviewed level twenty scope missing');assert(first(f.addon,s)==348)
end)
test('levels nineteen twenty and twenty-nine use actual learned ranks and thirty stays outside scope',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({19,20,29})do
  s.setLevel(level);assert(row(a).eligible,'level '..level..' excluded');assert(a:evaluateCondition(row(a).envelope.body.switch))
  only(f,s,687);s.known[706]=true;only(f,s,706);s.known[706]=nil
 end
 s.setLevel(30);assert(not row(a).eligible and not a:evaluateCondition(row(a).envelope.body.switch))
end)
test('untrained Armor keeps trained Skin ranks and known Armor upgrades an active Skin',function()
 local f,s,names=fixture();only(f,s,687)
 s.known[696]=true;only(f,s,696);active(s,names,696);only(f,s,nil)
 s.known[706]=true;only(f,s,706);s.buffs={};only(f,s,706)
 s.known[687],s.known[696]=nil,nil;only(f,s,706);s.known[706]=nil;only(f,s,nil)
end)
test('active Armor family suppresses Skin even when current learned state says untrained',function()
 local f,s,names=fixture();active(s,names,706);only(f,s,nil)
 active(s,names,1086);only(f,s,nil)
 -- Higher-family metadata is not training; only explicit learned observations enable ranks.
 s.buffs={};s.known[706]=true;only(f,s,706)
 s.known[1086]=true;only(f,s,1086);active(s,names,1086);only(f,s,nil)
end)
test('preferred Armor never falls back to Skin for missing mapping cooldown range or resources',function()
 for _,mode in ipairs({'unmapped','unusable','cooldown','range-unknown','power'})do
  local f,s=fixture();s.known[706]=true
  if mode=='unmapped'then s.mapped[706]=false
  elseif mode=='unusable'then s.usable[706]=false
  elseif mode=='cooldown'then s.cooldown[706]={startTime=90,duration=30,isEnabled=true,modRate=1}
  elseif mode=='range-unknown'then f.env.C_Spell.SpellHasRange=function(id)if id==706 then return nil end;return true end
  else local usable=f.env.C_Spell.IsSpellUsable;f.env.C_Spell.IsSpellUsable=function(id)if id==706 then return true,true end;return usable(id)end end
  only(f,s,nil);assert(first(f.addon,s)==348,'armor readiness changed damage selection')
 end
end)
test('nil error nonboolean and restricted learned data stay unknown through NOT',function()
 for _,mode in ipairs({'nil','error','nonboolean','restricted'})do
  local f,s=fixture();local known=f.env.IsSpellKnown;local opaque={}
  f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  f.env.IsSpellKnown=function(id,...)
   if id~=706 then return known(id,...)end
   if mode=='nil'then return nil elseif mode=='error'then error('native unavailable')elseif mode=='nonboolean'then return 'yes'else return opaque end
  end
  local selected,status=optional(f,s);assert(#selected==0 and status['warlock-starter-skin']=='unavailable'and status['warlock-starter-armor']=='unavailable')
  assert(first(f.addon,s)==348)
 end
end)
test('aura unknown and required name failures never authorize either armor reminder',function()
 for _,trained in ipairs({false,true})do
  local f,s,names=fixture();s.known[706]=trained;s.auraError=true
  local selected,status=optional(f,s);assert(#selected==0 and status['warlock-starter-skin']=='unavailable'and status['warlock-starter-armor']=='unavailable')
  s.auraError=false;local info=f.env.C_Spell.GetSpellInfo
  f.env.C_Spell.GetSpellInfo=function(id)if id==706 then return nil end;return info(id)end
  only(f,s,trained and 706 or 687) -- Complete empty scan needs no name metadata.
  s.buffs={{spellId=99999,name='Unrelated aura',sourceUnit='player'}}
  selected,status=optional(f,s);assert(#selected==0 and status['warlock-starter-skin']=='unavailable'and status['warlock-starter-armor']=='unavailable')
  active(s,names,706);only(f,s,nil) -- Exact spell identity needs no family metadata.
 end
end)

local function nativePublish(f,s)
 local a,e=f.addon,f.env;local glow,messages={},{}
 -- Real initialization establishes main's captured canonical cache helper.
 -- AceDB uses the native frame/event boundary; no production helper is replaced.
 e.OFF='Off';e.securecallfunction=function(fn,...)return fn(...)end
 e.UnitFactionGroup=function()return 'Horde'end;e.GetLocale=function()return 'enUS'end
 e.UnitRace=function()return 'Orc','Orc'end;e.GetRealmName=function()return 'Armor Realm'end
 e.UnitNameUnmodified=function()return 'Armor Character'end;e.GetCurrentRegionName=function()return 'US'end;e.GetCurrentRegion=function()return 1 end
 e.strlenutf8=function(text)return #text end;e.GetItemInfo=function()end
 local create=e.CreateFrame;e.CreateFrame=function(...)local frame=create(...);frame.RegisterEvent=function()end;return frame end
 local fallback=e.LibStub;e.LibStub=false
 f.load('Libs/LibStub/LibStub.lua');f.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');f.load('Libs/AceDB-3.0/AceDB-3.0.lua')
 local real=e.LibStub;setmetatable(real,{__call=function(self,name,silent)if self.libs[name]then return self:GetLibrary(name,silent)end;return fallback(name,silent)end})
 f.libraries['AceConsole-3.0'].RegisterChatCommand=function()end;f.libraries['AceConsole-3.0'].Printf=function()end
 f.libraries['LibDBIcon-1.0'].Register=function()end
 f.load('Core/itemset_services.lua');f.load('init.lua');f.load('validate.lua');f.load('profiler.lua')
 assert(a:OnInitialize(),'real native publisher initialization failed');a.currentSpec=0
 e.tinsert,e.tremove=table.insert,table.remove

 f.libraries['LibCustomGlow-1.0']={PixelGlow_Stop=function()end,AutoCastGlow_Stop=function()end,ButtonGlow_Stop=function()end}
 local actions={348,687,696,706,1086};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-armor'or'Creature-armor'end
 e.UnitName=function(unit)return unit end;e.UnitIsEnemy=function(_,unit)return unit=='target'end;e.UnitThreatSituation=function()return 0 end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function(_,button,kind)glow[#glow+1]={button.id,'clear:'..tostring(kind)}end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='armor-test';a.db.global.effects['armor-test']={type='texture'}
 a.currentRotation=nil;a:Fetch()
 a.db.profile.rotations[0]={native=a:CopySettingsData(row(a).envelope.body)}
 a.db.profile.spell_history,a.db.profile.combat_history,a.db.profile.damage_history=10,10,10;a.db.profile.preview_spells=0
 a.currentRotation='native';a.currentSpec=0;a.inCombat=false;a.units={player='Player',target='Target'};a.unitsInRange={};a.spellHistory={};a.combatHistory={};a.damageHistory={}
 a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100;a.db.profile.disable_buttons=false
 f.load('profiler.lua');a.evaluationProfile=a:ProfiledCode()
 f.libraries['AceEvent-3.0'].SendMessage=function(_,kind,...)messages[#messages+1]={kind,...}end
 a.DispatchAnnouncement=function()end
 local function tick()a:EvaluateNextActionInternal()end
 return tick,glow,messages
end
test('actual FindSpell main publishers and GlowCooldown announce Armor and clear it when buffed',function()
 local f,s,names=fixture();s.known[706]=true;local tick,glow,messages=nativePublish(f,s)
 assert(f.addon:FindSpell({706})==706,'native button mapping not active');tick()
 local armor,skin=false,false
 for _,call in ipairs(glow)do if call[1]==706 and call[2]==706 then armor=true elseif call[1]==687 and call[2]==687 then skin=true end end
 assert(armor and not skin and f.addon.avail_announced['warlock-starter-armor']==706,'native publisher chose Skin or omitted Armor')
 local announced=false;for _,call in ipairs(messages)do if call[1]=='ROTATIONMASTER_COOLDOWN_UPDATE'and call[4]=='warlock-starter-armor'and call[6]==706 then announced=true end end
 assert(announced,'Armor cooldown message missing')
 active(s,names,706);tick();assert(f.addon.avail_announced['warlock-starter-armor']==nil and f.addon.avail_announced['warlock-starter-skin']==nil)
 local cleared=false;for _,call in ipairs(glow)do if call[1]==706 and call[2]=='clear:706'then cleared=true end end;assert(cleared,'native Armor glow was not cleared')
end)
test('actual native unmapped Armor publishes no Skin while preserving damage advice',function()
 local f,s=fixture();s.known[706]=true;s.mapped[706]=false;local tick,glow,messages=nativePublish(f,s);tick()
 assert(f.addon.currentSpell==348 and f.addon.avail_announced['warlock-starter-skin']==nil and f.addon.avail_announced['warlock-starter-armor']==nil)
 for _,call in ipairs(glow)do assert(call[2]~=687,'unmapped preferred Armor enabled Skin glow')end
 for _,call in ipairs(messages)do assert(call[4]~='warlock-starter-skin','unmapped preferred Armor announced Skin')end
end)
test('strict full-pack inverse retains damage graph stable IDs and rejects unrelated changes',function()
 local current=read(path);local restore=dofile('tests/fixtures/restore_tbc_warlock_armor.lua');local old=restore(current)
 assert(#old==3021 and old:find('revision=1,',1,true));assert(not pcall(restore,current..'\n') and not pcall(restore,old))
 local f=fixture();local archived=fixture(true);local a,b=f.addon,archived.addon
 assert(a:SettingsDataEqual(row(a).envelope.body.rotation,row(b).envelope.body.rotation),'damage graph changed')
 local list=row(a).envelope.body.cooldowns;assert(list[1].id=='warlock-starter-skin'and list[2].id=='warlock-starter-armor')
 assert(row(a).validation.valid and row(a).validation.resolved)
end)
test('old saved clone keeps old cutoff and Skin policy while fresh adoption exposes exact diff',function()
 local old,s,names=fixture(true);s.setLevel(19);local a=old.addon
 local id=assert(a:CloneDefaultRotation(0,'rm.tbc.warlock.starter','Archived Warlock'))
 local saved=a:CopySettingsData(a:GetEditableRotation(0,id));local f,nextState,nextNames=fixture();local nextAddon=f.addon
 nextAddon.db.profile=a.db.profile;assert(nextAddon:InitializeRotationLibrary());local clone=nextAddon:GetEditableRotation(0,id)
 assert(nextAddon:SettingsDataEqual(saved,clone),'source reload rewrote archived clone')
 nextState.known[706]=true;active(nextState,nextNames,706)
 local selected=optional(f,nextState,clone.cooldowns);assert(#selected==1 and selected[1]==687,'old policy was silently replaced')
 local fresh=assert(nextAddon:CloneDefaultRotation(0,'rm.tbc.warlock.starter','Fresh Warlock'))
 selected=optional(f,nextState,nextAddon:GetEditableRotation(0,fresh).cooldowns);assert(#selected==0)
 local comparison=assert(nextAddon:BuildRotationComparison(0,id,{kind='builtin',id='rm.tbc.warlock.starter'}))
 assert(comparison.valid and comparison.complete and comparison.sourceChanges and #comparison.sourceChanges.changes==12)
 local byPath={};for _,change in ipairs(comparison.sourceChanges.changes)do byPath[change.path]=change;assert(not change.path:find('$.body.rotation',1,true),'damage diff appeared')end
 local scope=assert(byPath['$.applicability.maxLevel']);assert(scope.before==19 and scope.after==29)
 local policy=assert(byPath['$.body.cooldowns[warlock-starter-skin].conditions.type']);assert(policy.before=='NOT'and policy.after=='AND')
 local armor=assert(byPath['$.body.cooldowns[warlock-starter-armor]']);assert(armor.kind=='added'and armor.toIndex==2 and armor.after.action==706)
 local switch=assert(byPath['$.body.switch.value[2].value']);assert(switch.before==20 and switch.after==30)
 local source=assert(nextAddon:GetSourcedRotationView(0,id));assert(source.envelope.applicability.maxLevel==19 and source.envelope.revision==1)
 assert(nextAddon:GetRuntimeRotation(0,id)==nil,'archived clone lost its old level cutoff')
 assert(nextAddon:GetRuntimeRotation(0,fresh),'fresh clone did not adopt reviewed level scope')
end)
finish()
