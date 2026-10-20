-- Actual predicates, rank catalog, sequence, readiness and initialized publication;
-- observations and action bars are modeled, not native-client acceptance.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local SOURCE=arg[1]or'Defaults/tbc/mage-30-39.lua'
local ID='rm.tbc.mage.starter.30-39'
local function fixture(product,class,missingMetadata)
 local f=F.new(product or 5,1,class or 'MAGE');local a,e=f.addon,f.env
 f.translations['Default.TBC.Mage.Thirties.Name']='TBC Mage 30–39 Frost single-target preview'
 f.translations['Default.TBC.Mage.Thirties.Description']='Bounded Frost preview; manual armor choices, talents and resources are preserved.'
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
 local s={level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
  known={[116]=true},usable={},range={},cooldown={},buffs={},mapped={},power={},metadataMissing={},casting=false,channel=false}
 if missingMetadata then s.metadataMissing[missingMetadata]=true end
 local families={[116]={116,205,8407,8408},[1459]={1459,1461},[168]={168,7301},[7302]={7302},[6117]={6117}}
 local names,ranks={},{}
 for base,ids in pairs(families)do for rank,id in ipairs(ids)do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
 ranks[8407],ranks[8408],ranks[1461],ranks[7301]='Rank 6','Rank 7','Rank 3','Rank 3'
 e.UnitExists=function(unit)return unit=='player'or unit=='target'and s.exists end
 e.UnitLevel=function()return s.level end
 e.UnitAffectingCombat=function(unit)return unit=='player'and s.combat or unit~='player'and s.targetCombat end
 e.UnitCanAttack=function()return s.hostile end;e.UnitIsDead=function()return s.dead end
 e.UnitHasVehicleUI=function()return false end;e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.UnitCastingInfo=function(unit)assert(unit=='player');if s.casting then return names[116],names[116],1,99000,102000,false,1,false,116 end end
 e.UnitChannelInfo=function(unit)assert(unit=='player');if s.channel then return 'Manual channel','Manual channel',1,99000,102000,false,false,10 end end
 e.IsSpellKnown=function(id)if s.knownError==id or s.knownError==true then error('learning unavailable')end;return s.known[id]==true end
 e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return{name=names[id]or'Spell '..id,spellID=id,subtext=ranks[id]}end,
  SpellHasRange=function(id)return id==116 or id==205 or id==8407 or id==8408 end,
  IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
  GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)assert(unit=='player'and filter=='HELPFUL');if s.auraError then error('auras unavailable')end;return s.buffs[index]end}
 for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/combat.lua',
  'Conditions/casting.lua','Conditions/channeling.lua'})do f.load(path)end
 f.load(SOURCE)
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function()return'Rotation Master test'end;e.UnitGUID=function()return'Player-test'end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('main.lua')
 for id in pairs(names)do a.SpellCatalog:UpdateSpell(id)end
 assert(a:InitializeRotationLibrary());return f,s,names
end
local function row(a)
 local rows=a:ListDefaultRotations(0)
 for _,v in ipairs(rows)do if v.id==ID then return v end end
 if SOURCE~='Defaults/tbc/mage-30-39.lua'then return rows[1]end
 error('missing Mage30–39 manifest')
end
local function body(a)return row(a).envelope.body end
local function first(a,s)
 local ready=a:NewActionReadiness(100);local selected
 local result=a:EvaluateRotationSequence(body(a),function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
   if s.mapped[id]~=false and ready(step.type,id)then selected=id;return false end
  end end
 end)
 return selected,result
end
local function optional(f,s)
 local a=f.addon;local actions={};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(body(a).cooldowns)do if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
  if s.mapped[id]~=false and ready('spell',id)then actions[id]=true;break end
 end end end
 return actions
end
local function noArmor(actions)assert(not actions[168]and not actions[7301]and not actions[7302]and not actions[6117],'unexpected armor reminder')end
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
 local actions={116,205,8407,8408,1459,1461,168,7301,7302,6117};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-mage'or'Creature-mage'end
 e.UnitName=function(unit)return unit end;e.UnitIsEnemy=function(_,unit)return unit=='target'end;e.UnitThreatSituation=function()return 0 end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function(_,button,kind)glow[#glow+1]={button.id,'clear:'..tostring(kind)}end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='armor-test';a.db.global.effects['armor-test']={type='texture'}
 a.ScheduleRepeatingTimer=function()return 'modeled-publisher-timer'end;a.CancelTimer=function()end
 a.currentRotation=nil;a:Fetch()
 a.db.profile.rotations[0]={native=a:CopySettingsData(body(a))}
 a.db.profile.spell_history,a.db.profile.combat_history,a.db.profile.damage_history=10,10,10;a.db.profile.preview_spells=0
 a.currentRotation='native';a.currentSpec=0;a.inCombat=false;a.units={player='Player',target='Target'};a.unitsInRange={};a.spellHistory={};a.combatHistory={};a.damageHistory={}
 a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100;a.db.profile.disable_buttons=false
 f.load('profiler.lua');a.evaluationProfile=a:ProfiledCode()
 f.libraries['AceEvent-3.0'].SendMessage=function(_,kind,...)messages[#messages+1]={kind,...}end
 a.DispatchAnnouncement=function()end
 local function tick()a:EvaluateNextActionInternal()end
 return tick,glow,messages
end

test('scope boundaries are exact and the executable level switch agrees',function()
 local f,s=fixture();local a=f.addon
 for _,level in ipairs({29,30,33,34,39,40})do s.level=level;a.longtermCache={};local wanted=level>=30 and level<40
  assert(row(a).eligible==wanted);assert(a:evaluateCondition(body(a).switch)==wanted)
 end
end)
test('foreign class edition vehicle and petbattle contexts cannot activate the pack',function()
 for _,case in ipairs({{5,'SHAMAN'},{2,'MAGE'},{1,'MAGE'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 for _,kind in ipairs({'vehicle','petbattle'})do local f=fixture();local a=f.addon
  if kind=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end
  assert(not row(a).eligible);assert(not a:GetRuntimeRotation(0,row(a).runtimeKey))
 end
end)
test('reviewed32and38 Frostbolt ranks require actual learning mapping and readiness',function()
 local f,s=fixture();local a=f.addon;s.level=39;assert(first(a,s)==116)
 s.known[8407]=true;assert(first(a,s)==8407);s.known[8408]=true;assert(first(a,s)==8408)
 s.mapped[8408]=false;assert(first(a,s)==8407);s.power[8407]=true;assert(first(a,s)==116)
end)
test('Frostbolt readiness refusal never invents a Fire or talent fallback',function()
 local f,s=fixture();local a=f.addon;s.known[8407],s.known[8408]=true,true
 s.range[8407],s.range[8408],s.range[116]=false,false,false;assert(not first(a,s));s.range={}
 s.usable[8407],s.usable[8408],s.usable[116]=false,false,false;assert(not first(a,s));s.usable={}
 for _,id in ipairs({116,8407,8408})do s.cooldown[id]={startTime=99,duration=30,isEnabled=true,modRate=1}end
 assert(not first(a,s))
end)
test('level30 does not grant Ice Armor and learned Frost Armor remains optional',function()
 local f,s=fixture();s.known[168]=true;local actions=optional(f,s);assert(actions[168]and not actions[7302]and not actions[6117])
 s.known[7301]=true;assert(optional(f,s)[7301])
end)
test('learned Ice Armor wins only over definitely unlearned Mage Armor',function()
 local f,s=fixture();s.known[168],s.known[7302]=true,true;local actions=optional(f,s)
 assert(actions[7302]and not actions[168]and not actions[6117]);s.level=33;assert(optional(f,s)[7302])
end)
test('learned Mage Armor is the sole armor reminder without a level training guess',function()
 local f,s=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true
 local actions=optional(f,s);assert(actions[6117]and not actions[168]and not actions[7302])
 s.level=39;s.known[6117]=false;assert(optional(f,s)[7302],'level39 fabricated Mage Armor learning')
end)
test('each existing manual armor and localized higher rank from any caster is preserved',function()
 for _,id in ipairs({168,7301,7302,6117})do for _,caster in ipairs({'player','party1'})do
  local f,s,n=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true
  s.buffs={{spellId=id,name=n[id],sourceUnit=caster}};noArmor(optional(f,s));assert(first(f.addon,s)==116)
 end end
end)
test('learned preferred armor unmapped unready or unavailable never falls to another family',function()
 for _,kind in ipairs({'mapped','power','usable','cooldown','metadata'})do
  local f,s=fixture(nil,nil,kind=='metadata'and 6117 or nil);s.known[168],s.known[7302],s.known[6117],s.known[1459]=true,true,true,true
  if kind=='mapped'then s.mapped[6117]=false elseif kind=='power'then s.power[6117]=true
  elseif kind=='usable'then s.usable[6117]=false elseif kind=='cooldown'then s.cooldown[6117]={startTime=99,duration=30,isEnabled=true,modRate=1}
  end
  local actions=optional(f,s)
  -- Missing name metadata may still permit the exact native ID when readiness
  -- APIs answer directly. It never licenses an inferior armor family.
  if kind=='metadata'then assert(not actions[168]and not actions[7302])else noArmor(actions)end
  assert(actions[1459]and first(f.addon,s)==116,kind)
 end
end)
test('unknown learning of any armor family authorizes no armor upkeep under NOT',function()
 for _,id in ipairs({168,7302,6117})do local f,s=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true;s.knownError=id;noArmor(optional(f,s))end
 local f,s=fixture();s.known[168]=true;f.env.IsSpellKnown=function(id)if id==6117 then return nil end;return s.known[id]==true end;noArmor(optional(f,s))
end)
test('unknown aura observations cannot become absent armor and missing metadata stays unavailable',function()
 local f,s,n=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true;s.auraError=true;noArmor(optional(f,s))
 s.auraError=false;s.buffs={{spellId=999,name='Some other buff',sourceUnit='player'}};s.metadataMissing[7302]=true;noArmor(optional(f,s))
end)
test('Intellect is independent and recognizes localized learned ranks and other casters',function()
 local f,s,n=fixture();s.known[1459],s.known[1461],s.known[6117]=true,true,true
 assert(optional(f,s)[1461]and optional(f,s)[6117]);s.buffs={{spellId=1461,name=n[1461],sourceUnit='party1'}}
 local actions=optional(f,s);assert(not actions[1461]and actions[6117]);s.buffs={{spellId=6117,name=n[6117],sourceUnit='player'}}
 actions=optional(f,s);noArmor(actions);assert(actions[1461])
end)
test('target motion and engagement guards retain intentional pull and combat semantics',function()
 local f,s=fixture();local a=f.addon
 s.targetCombat=true;assert(not first(a,s));s.combat=true;assert(first(a,s)==116)
 s.combat=false;s.targetCombat=false;s.moving=true;assert(not first(a,s));s.moving=false
 s.hostile=false;assert(not first(a,s));s.hostile=true;s.dead=true;assert(not first(a,s));s.dead=false;s.exists=false;assert(not first(a,s))
 s.exists=true;assert(first(a,s)==116)
end)
test('initialized publisher preserves existing advisory behavior during casts channels and their end',function()
 local f,s=fixture();local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==116)
 s.casting=true;tick();assert(f.addon.currentSpell==116,'new blanket current-cast suppression changed Mage advice')
 s.casting=false;tick();assert(f.addon.currentSpell==116);s.channel=true;tick();assert(f.addon.currentSpell==116)
 s.channel=false;s.exists=false;tick();assert(f.addon.currentSpell==nil,'invalid target did not clear published advice')
 s.exists=true;tick();assert(f.addon.currentSpell==116)
end)
test('bounded source excludes unreviewed talent emergency AoE and Fire priorities',function()
 local f=fixture();local actions={};local index=assert(f.addon.RotationData.IndexRotationSteps(body(f.addon)))
 for _,entry in ipairs(index.rows)do if entry.step.action then actions[entry.step.action]=true end end
 for _,id in ipairs({133,122,2136,120,10,12472,11958,11426,1463,45438})do assert(not actions[id],id)end
 assert(actions[116])
end)
test('old and new manifest clones remain separate and preserve explicit local edits',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/mage-starter.lua');assert(a:InitializeRotationLibrary())
 local older=assert(a:CloneDefaultRotation(0,'rm.tbc.mage.starter','Older copy'))
 local newer=assert(a:CloneDefaultRotation(0,ID,'Thirties copy'));local new=a:GetEditableRotation(0,newer);local old=a:GetEditableRotation(0,older)
 new.rotation[1].onTrue[1].action=133;assert(body(a).rotation[1].onTrue[1].action==116);assert(old.rotation[1].onTrue[1].type=='branch','old clone rewritten')
 local saved=a:CopySettingsData(new);local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary())
 assert(a:SettingsDataEqual(saved,a:GetEditableRotation(0,newer))and a:GetEditableRotation(0,older)==old)
end)
test('metadata provenance stable identifiers and revision remain explicit',function()
 local f=fixture();local a=f.addon;local r=row(a);local m=r.envelope
 assert(r.readOnly and r.validation.valid and r.validation.supported and r.validation.resolved)
 assert(m.id==ID and m.revision==1 and f.translations[m.nameKey]and f.translations[m.descriptionKey])
 assert(m.applicability.class=='MAGE'and m.applicability.actionContext=='player'and m.applicability.minLevel==30 and m.applicability.maxLevel==39)
 assert(m.sources[1].url=='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide'and m.sources[1].reviewedAt=='2026-10-20')
 local seen={};local index=assert(a.RotationData.IndexRotationSteps(body(a)));for _,entry in ipairs(index.rows)do local id=entry.step.id;assert(type(id)=='string'and not seen[id]);seen[id]=true end
end)
test('real publisher selects mapped rank38 and retires lower armor reminders',function()
 local f,s,n=fixture();s.level=38;s.known[8407],s.known[8408],s.known[168]=true,true,true
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==8408)
 assert(f.addon.avail_announced['mage-thirties-frost-armor']==168)
 s.known[6117]=true;tick();assert(f.addon.avail_announced['mage-thirties-mage-armor']==6117)
 assert(not f.addon.avail_announced['mage-thirties-frost-armor'])
 s.buffs={{spellId=7302,name=n[7302],sourceUnit='party1'}};tick();assert(not f.addon.avail_announced['mage-thirties-mage-armor'])
 s.mapped[8408]=false;f.addon:Fetch();tick();assert(f.addon.currentSpell==8407)
 local published=false;for _,call in ipairs(messages)do if call[1]=='ROTATIONMASTER_SPELL_UPDATE'and call[6]==8408 then published=true end end;assert(published)
end)
test('legacy spell API follows learned rank and native resource authority without modern fallback',function()
 local f,s=fixture();local e=f.env;local api=e.C_Spell;e.C_Spell=nil
 e.GetSpellInfo=function(id)local v=api.GetSpellInfo(id);if v then return v.name,v.subtext,nil,0,0,30,id end end
 e.SpellHasRange=function(slot,bank)assert(bank=='spell');return api.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,bank,unit)assert(bank=='spell');return api.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.IsUsableSpell=api.IsSpellUsable;e.GetSpellCooldown=function(id)local v=api.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 or nil end
 s.known[8407],s.known[8408]=true,true;assert(first(f.addon,s)==8408);s.power[8408]=true;assert(first(f.addon,s)==8407)
end)
test('modern learned-bank uses exact player arguments and selected failure cannot become unlearned',function()
 local f,s=fixture();local e=f.env;local calls,legacy=0,0;s.known[6117],s.known[8408]=true,true
 e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);calls=calls+1;return s.known[id]==true end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end;assert(first(f.addon,s)==8408 and optional(f,s)[6117]and calls>0 and legacy==0)
 e.C_SpellBook.IsSpellKnown=function()error('selected learning unavailable')end;noArmor(optional(f,s));assert(not first(f.addon,s)and legacy==0)
end)
test('disabled source cannot execute and source-scoped copies expire at forty',function()
 local f,s=fixture();local a=f.addon;local key=row(a).runtimeKey;assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible and not a:GetRuntimeRotation(0,key))
 assert(a:SetDefaultRotationEnabled(ID,true));local clone=assert(a:CloneDefaultRotation(0,ID,'Mage copy'));assert(a:GetRuntimeRotation(0,clone))
 s.level=40;a.longtermCache={};assert(not a:GetRuntimeRotation(0,clone)and not a:GetRuntimeRotation(0,key))
end)
finish()
