-- Real condition/catalog/sequence/readiness and main publication; native APIs modeled.
-- Talent indices are TBC slots (Enhancement2), not TalentTab record ID263.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local pack='Defaults/tbc/shaman-enhancement-30-39.lua'
local function fixture(project,class,missingMetadata)
 local f=F.new(project or 5,1,class or 'SHAMAN');local a,e=f.addon,f.env
 f.translations['Default.TBC.Shaman.Enhancement30.Name']='Shaman: Enhancement leveling (30–39)'
 f.translations['Default.TBC.Shaman.Enhancement30.Description']='Bounded Enhancement-oriented solo preview; equipment and utility remain manual.'
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
 local s={level=30,combat=true,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,near=true,vehicle=false,petbattle=false,
  known={[403]=true,[8042]=true,[8017]=true,[324]=true,[6603]=true},usable={},range={},cooldown={},buffs={},mapped={},power={},metadataMissing=missingMetadata or {},talents={0,21,0},enchanted=false}
 local families={[403]={403,529,548,915,943,6041,10391},[8042]={8042,8044,8045,8046,10412},[8017]={8017,8018,8019,10399,16314},[8232]={8232},[324]={324,325,905,945},[6603]={6603}}
 local names,ranks,ranged={}, {},{}
 for base,ids in pairs(families)do for rank,id in ipairs(ids)do names[id]='Localized family '..base;ranks[id]='Rank '..rank;ranged[id]=base==403 or base==8042 or base==6603 end end
 e.UnitExists=function(unit)return unit=='player'or unit=='target'and s.exists end
 e.UnitLevel=function()return s.level end;e.UnitAffectingCombat=function(unit)return unit=='player'and s.combat or unit~='player'and s.targetCombat end
 e.UnitCanAttack=function()return s.hostile end;e.UnitIsDead=function()return s.dead end
 e.UnitHasVehicleUI=function()return s.vehicle end;e.C_PetBattles={IsInBattle=function()return s.petbattle end}
 e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.UnitCastingInfo=function()if s.cast then return 'Manual cast' end end;e.UnitChannelInfo=function()if s.channel then return 'Manual channel' end end
 e.GetWeaponEnchantInfo=function()if s.enchantError then error('unavailable')end;return s.enchanted,1000,1,nil,false end
 e.IsSpellKnown=function(id)if s.knownError or s.knownErrorID==id then error('unavailable')end;return s.known[id]==true end
 e.GetNumTalentTabs=function(inspect,pet)assert(inspect==false and pet==false);if s.talentCountError then error('unavailable')end;return 3 end
 local ids={261,263,262};local treeNames={'Localized Elemental','Localized Enhancement','Localized Restoration'}
 e.C_SpecializationInfo={GetSpecializationInfo=function(index,inspect,pet,target,sex,group)
  assert(index>=1 and index<=3 and inspect==false and pet==false and target==nil and sex==nil and group==nil,'inactive/preview group queried')
  if s.talentError then error('unavailable')end
  return ids[index],treeNames[index],'Description',136048,nil,nil,s.talents[index],'Background',99,true
 end}
 e.C_Spell={GetSpellInfo=function(id)
  if s.metadataMissing[id]then return end
  if type(id)=='string'then for _,group in pairs(families)do if names[group[1]]==id then for i=#group,1,-1 do if s.known[group[i]]then id=group[i];break end end end end end
  if not names[id]then return end;return{name=names[id],spellID=id,subtext=ranks[id]}
 end,SpellHasRange=function(id)return ranged[id]end,IsSpellInRange=function(id)if id==6603 then return s.near end;return s.range[id]~=false end,
 IsCurrentSpell=function()return false end,IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
 GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.C_UnitAuras={GetAuraDataByIndex=function(_,index)if s.auraError then error('unavailable')end;return s.buffs[index]end}
 for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/talents.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/combat.lua','Conditions/weapon.lua','Conditions/range.lua','Conditions/talent.lua'})do f.load(path)end
 local file=io.open(pack);if file then file:close();f.load(pack)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function()return 'Rotation Master test'end;e.UnitGUID=function()return 'Player-test'end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 for id in pairs(names)do a.SpellCatalog:UpdateSpell(id)end
 a.ScheduleTimer=function(_,callback)return callback end
 s.setLevel=function(level)s.level=level;a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 assert(a:InitializeRotationLibrary());return f,s,names
end
local function row(a)local r=a:ListDefaultRotations(0)[1];assert(r,'missing Shaman Enhancement30–39 preview');return r end
local function body(a)return row(a).envelope.body end
local function switch(a)return a:evaluateConditionResult(body(a).switch)end
local function first(a,s)
 local ready=a:NewActionReadiness(100);local chosen
 local result=a:EvaluateRotationSequence(body(a),function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready(step.type,id)then chosen=id;return false end end end
 end)
 return chosen,result
end
local function upkeep(a,s)
 local ready=a:NewActionReadiness(100);local actions={}
 for _,step in ipairs(body(a).cooldowns)do if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
  if s.mapped[id]~=false and ready(step.type,id)then actions[#actions+1]=id;break end
 end end end
 return table.concat(actions,',')
end
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
 local actions={403,529,548,915,943,6041,10391,8042,8044,8045,8046,10412,8017,8018,8019,10399,16314,8232,324,325,905,945,6603};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;if slot<=12 then e['ActionButton'..slot]=button else e['MultiBarBottomLeftButton'..(slot-12)]=button end
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-shaman'or'Creature-shaman'end
 e.UnitName=function(unit)return unit end;e.UnitIsEnemy=function(_,unit)return unit=='target'end;e.UnitThreatSituation=function()return 0 end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function(_,button,kind)glow[#glow+1]={button.id,'clear:'..tostring(kind)}end
 a.verbose=function()end;a.debug=function()end;a.info=function()end;a.warn=function()end
 a.db.profile.effect='armor-test';a.db.global.effects['armor-test']={type='texture'}
 a.currentRotation=nil;a:Fetch()
 a.db.profile.rotations[0]={native=a:CopySettingsData(body(a))}
 a.db.profile.spell_history,a.db.profile.combat_history,a.db.profile.damage_history=10,10,10;a.db.profile.preview_spells=0
 a.currentRotation='native';a.currentSpec=0;a.inCombat=false;a.units={player='Player',target='Target'};a.unitsInRange={};a.spellHistory={};a.combatHistory={};a.damageHistory={}
 a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100;a.db.profile.disable_buttons=false
 f.load('profiler.lua');a.evaluationProfile=a:ProfiledCode()
 f.libraries['AceEvent-3.0'].SendMessage=function(_,kind,...)messages[#messages+1]={kind,...}end
 a.DispatchAnnouncement=function()end
 a.ScheduleRepeatingTimer=function()return 'modeled-timer'end;a.CancelTimer=function()end
 a.db.profile.disable_autoswitch=false;a.manualRotation=false;a:UpdateAutoSwitch()
 local function tick()a:SwitchRotation();a:EvaluateNextActionInternal()end
 return tick,glow,messages
end

-- Removing the source or widening its scope must break these consumer-visible checks.
test('new preview resolves only matching class edition level and player context',function()
 local f,s=fixture();local a=f.addon;assert(row(a).eligible and row(a).validation.valid and row(a).validation.resolved)
 for _,level in ipairs({30,31,34,39})do s.setLevel(level);assert(row(a).eligible);assert(switch(a).status=='match')end
 for _,level in ipairs({29,40})do s.setLevel(level);assert(not row(a).eligible);assert(switch(a).status=='no-match')end
 s.level=30;s.vehicle=true;assert(not row(a).eligible);s.vehicle=false;s.petbattle=true;assert(not row(a).eligible)
 local other=fixture(5,'MAGE');assert(#other.addon:ListDefaultRotations(0)==0)
 local edition=fixture(2,'SHAMAN');assert(not row(edition.addon).eligible)
end)
test('switch uses only a unique positive Enhancement maximum and requires learned Bolt',function()
 local f,s=fixture();local a=f.addon
 for _,case in ipairs({{{0,21,0},'match'},{{5,16,0},'match'},{{0,1,0},'match'},{{16,5,0},'no-match'},{{0,5,16},'no-match'},{{10,10,1},'unavailable'},{{0,10,10},'unavailable'},{{7,7,7},'unavailable'},{{0,0,0},'unavailable'}})do
  s.talents=case[1];assert(switch(a).status==case[2],table.concat(case[1],','))
 end
 s.talents={0,21,0};s.known[403]=false;assert(switch(a).status=='no-match');s.known[403]=true;s.knownErrorID=403;assert(switch(a).status=='unavailable')
end)
test('missing restricted malformed and failed talent facts never activate the switch',function()
 local f,s=fixture();local a=f.addon
 for _,points in ipairs({{0,21},{0,-1,0},{0,1.5,0}})do s.talents=points;assert(switch(a).status=='unavailable')end
 local secret={};s.talents={0,21,secret};f.env.canaccessvalue=function(v)return not rawequal(v,secret)end;assert(switch(a).status=='unavailable')
 s.talents={0,21,0};s.talentError=true;assert(switch(a).status=='unavailable');s.talentError=false;s.talentCountError=true;assert(switch(a).status=='unavailable')
end)
test('fresh polls follow respecs without using preview points as allocation',function()
 local f,s=fixture();local a=f.addon;assert(switch(a).status=='match')
 s.talents={21,0,0};assert(switch(a).status=='no-match');s.talents={0,0,0};assert(switch(a).status=='unavailable')
 s.talents={0,21,0};assert(switch(a).status=='match')
end)
test('learned Windfury supersedes only missing mainhand enchant and unlearned falls back once',function()
 local f,s=fixture();local a=f.addon;assert(upkeep(a,s)=='8017,324')
 s.known[8232]=true;assert(upkeep(a,s)=='8232,324');assert(first(a,s)==8042)
 s.enchanted=true;assert(upkeep(a,s)=='324');s.enchanted=1;assert(upkeep(a,s)=='324')
 s.enchanted=false;s.buffs={{spellId=324,sourceUnit='player'}};assert(upkeep(a,s)=='8232')
end)
test('unready learned Windfury never authorizes an inferior Rockbiter reminder',function()
 local f,s=fixture();local a=f.addon;s.known[8232]=true
 for _,key in ipairs({'usable','mapped'})do s[key][8232]=false;assert(upkeep(a,s)=='324');s[key][8232]=nil end
 s.power[8232]=true;assert(upkeep(a,s)=='324');s.power={};s.cooldown[8232]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(upkeep(a,s)=='324')
 local g,t=fixture(nil,nil,{[8232]=true});t.known[8232]=true;t.usable[8232]=false;assert(upkeep(g.addon,t)=='324')
end)
test('unknown enchant or learned Windfury does not become missing or unlearned',function()
 local f,s=fixture();local a=f.addon;s.knownErrorID=8232;assert(upkeep(a,s)=='324');s.knownErrorID=nil;s.enchantError=true;assert(upkeep(a,s)=='324')
 s.enchantError=false;local secret={};s.enchanted=secret;f.env.canaccessvalue=function(v)return not rawequal(v,secret)end;assert(upkeep(a,s)=='324')
end)
test('rank expansion keeps actual learned mappings resources and readiness authoritative',function()
 local f,s=fixture();local a=f.addon;s.known[10412]=true;assert(first(a,s)==10412)
 s.mapped[10412]=false;assert(first(a,s)==8042);s.usable[8042]=false;assert(not first(a,s))
 s.combat=false;s.mapped={};s.usable={};s.known[6041],s.known[10391]=true,true;assert(first(a,s)==10391)
 s.power[10391]=true;assert(first(a,s)==6041);s.mapped[6041]=false;assert(first(a,s)==403)
end)
test('Shield higher ranks own attribution and independent upkeep preserve existing semantics',function()
 local f,s,n=fixture();local a=f.addon;s.known[945],s.known[16314]=true,true;assert(upkeep(a,s)=='16314,945')
 s.buffs={{spellId=945,name=n[945],sourceUnit='player'}};assert(upkeep(a,s)=='16314')
 s.buffs[1].sourceUnit='party1';assert(upkeep(a,s)=='16314,945');s.auraError=true;assert(upkeep(a,s)=='16314')
end)
test('ranged filler remains stationary and no peaceful engaged hostile pull is introduced',function()
 local f,s=fixture();local a=f.addon;s.usable[8042]=false;assert(not first(a,s));s.near=false;assert(first(a,s)==403)
 s.moving=true;assert(not first(a,s));s.moving=false;s.combat=false;s.targetCombat=true;assert(not first(a,s))
 s.targetCombat=false;assert(first(a,s)==403);s.hostile=false;assert(not first(a,s))
end)
test('normal main publisher changes advice for ranks and clears it after a respec or unknown switch',function()
 local f,s=fixture();local tick,glow,messages=nativePublish(f,s);local a=f.addon
 tick();assert(a.currentSpell==8042,'initial advice '..tostring(a.currentSpell)..' rotation '..tostring(a.currentRotation));s.known[10412]=true;tick();assert(a.currentSpell==10412)
 s.talents={21,0,0};tick();assert(not a.currentRotation and not a.currentSpell,'respec retained published advice')
 s.talents={0,21,0};tick();assert(a.currentSpell==10412);s.talents={0,0,0};tick();assert(not a.currentRotation and not a.currentSpell)
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]then seen[m[6]]=true end end;assert(seen[8042]and seen[10412]);assert(#glow>0)
end)
test('normal publisher keeps optional enchant and shield independent of chosen damage',function()
 local f,s=fixture();s.known[8232]=true;local tick,_,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==8042,'optional publish '..tostring(f.addon.currentSpell)..' rotation '..tostring(f.addon.currentRotation))
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_COOLDOWN_UPDATE'then seen[m[6]]=true end end
 assert(seen[8232]and seen[324]);s.enchanted=true;tick();assert(f.addon.currentSpell==8042)
end)
test('new clones are independent and old1–29 pack keeps its original cutoff',function()
 local f,s=fixture();local a=f.addon;local id=assert(a:CloneDefaultRotation(0,row(a).id,'New clone'));local clone=a:GetEditableRotation(0,id)
 clone.rotation[1].action=974;assert(body(a).rotation[1].action==403)
 f.load('Defaults/tbc/shaman-starter.lua');local old
 for _,v in ipairs(a:ListDefaultRotations(0))do if v.id=='rm.tbc.shaman.starter'then old=v end end
 assert(old and old.envelope.applicability.maxLevel==29);s.setLevel(29);assert(a:evaluateCondition(old.envelope.body.switch));s.setLevel(30);assert(not a:evaluateCondition(old.envelope.body.switch))
end)
finish()
