-- Bounded Hunter30–39 policy controls: native APIs modeled; engine, catalog and publication real.
-- This fixture enumerates inherited example ranks only, not a training schedule or full30–39 spellbook.
local SOURCE=arg[1]or'Defaults/tbc/hunter-30-39.lua'
local ID='rm.tbc.hunter.starter.30-39'
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'HUNTER');local a,e=f.addon,f.env
    f.translations['Default.TBC.Hunter.Thirty.Name']='TBC Hunter30–39 preview';f.translations['Default.TBC.Hunter.Thirty.Description']='Bounded ranged preview; pets, melee and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[75]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[75]={75},[1978]={1978,13549,13550,13551},[3044]={3044,14281,14282,14283},[13165]={13165,14318,14319},[13163]={13163},[5118]={5118},[3043]={3043}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.UnitCastingInfo=function()if s.casting then return 'Cast in progress'end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        SpellHasRange=function(id) return id~=13165 and id~=14318 and id~=14319 and id~=13163 and id~=5118 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==75);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open(SOURCE);if pack then pack:close();f.load(SOURCE)end
    e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function() return 'Rotation Master test' end
    e.UnitGUID=function() return 'Player-test' end
    f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
    f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
    f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
    f.libraries['ThreatClassic-1.0']={Disable=function() end};f.libraries['LibClassicDurations'].Register=function()end
    f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
    for id in pairs(names) do a.SpellCatalog:UpdateSpell(id) end
    assert(a:InitializeRotationLibrary());return f,s,names
end
local function body(a)
    for _,row in ipairs(a:ListDefaultRotations(0))do if row.id==ID then return row.envelope.body end end;error('missing Hunter30–39 preview')
end
local function first(a,s)
    local ready=a:NewActionReadiness(100);local selected
    local result=a:EvaluateRotationSequence(body(a),function(c) return a:evaluateConditionResult(c) end,function(step)
        if a:evaluateCondition(step.conditions) then
            for _,id in ipairs(a:GetSpellIds(step)) do
                if s.mapped[id]~=false and ready(step.type,id) then selected=id;return false end
            end
        end
    end)
    return selected,result
end
local function optional(f,s)
 local a=f.addon;local step=body(a).cooldowns[1];local ready=a:NewActionReadiness(100)
 if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready('spell',id)then return id end end end
end
local function nativePublish(f,s)
 local a,e=f.addon,f.env;local glow,messages={},{}
 -- Real initialization establishes main's captured canonical cache helper.
 -- AceDB uses the native frame/event boundary; no production helper is replaced.
 e.OFF='Off';e.securecallfunction=function(fn,...)return fn(...)end
 e.UnitFactionGroup=function()return 'Horde'end;e.GetLocale=function()return 'enUS'end
 e.UnitRace=function()return 'Orc','Orc'end;e.GetRealmName=function()return 'Hunter Realm'end
 e.UnitNameUnmodified=function()return 'Hunter Character'end;e.GetCurrentRegionName=function()return 'US'end;e.GetCurrentRegion=function()return 1 end
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
 local actions={75,1978,13549,13550,13551,3044,14281,14282,14283,13165,14318,14319};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-hunter'or'Creature-hunter'end
 e.UnitName=function(unit)return unit end;e.UnitIsEnemy=function(_,unit)return unit=='target'end;e.UnitThreatSituation=function()return 0 end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function(_,button,kind)glow[#glow+1]={button.id,'clear:'..tostring(kind)}end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='hunter-test';a.db.global.effects['hunter-test']={type='texture'}
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

local function own(s,names,id,who)s.debuffs={{spellId=id or 13550,name=names[id or 13550],sourceUnit=who or'player'}}end

local function row(a)for _,v in ipairs(a:ListDefaultRotations(0))do if v.id==ID then return v end end;error('missing Hunter30–39 manifest')end
local function ready(s)s.repeatActive=true;s.known[1978],s.known[13551],s.known[3044],s.known[14283]=true,true,true,true end

test('thirty-nine grants no spells and only trained mapped ranks enter priority',function()
 local f,s,n=fixture();s.level=39;assert(row(f.addon).eligible and first(f.addon,s)==75)
 s.repeatActive=true;assert(not first(f.addon,s));s.known[1978]=true;assert(first(f.addon,s)==1978)
 s.known[13551]=true;assert(first(f.addon,s)==13551);s.mapped[13551]=false;assert(first(f.addon,s)==1978)
 own(s,n,1978);s.known[3044]=true;assert(first(f.addon,s)==3044)
 s.known[14283]=true;assert(first(f.addon,s)==14283);s.mapped[14283]=false;assert(first(f.addon,s)==3044)
end)
test('known active Auto Shot is never offered as an off toggle and unavailable repeat halts',function()
 local f,s=fixture();s.repeatActive=true;assert(not first(f.addon,s));s.known[3044]=true;assert(first(f.addon,s)==3044)
 s.repeatError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('instants remain possible while moving but stationary Auto start and cast channel protection hold',function()
 local f,s=fixture();s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.known[3044]=true;assert(first(f.addon,s)==3044)
 s.casting=true;assert(not first(f.addon,s));s.casting=false;s.channel=true;assert(not first(f.addon,s))
end)
test('own Scorpid is preserved while foreign Scorpid allows this Hunters Serpent',function()
 local f,s,n=fixture();ready(s);own(s,n,3043);assert(first(f.addon,s)==14283)
 s.known[3043]=false;assert(first(f.addon,s)==14283);own(s,n,3043,'party1');assert(first(f.addon,s)==13551)
 own(s,n,13551);assert(first(f.addon,s)==14283)
 s.debuffs={{spellId=3043,name=n[3043]}};assert(first(f.addon,s)==13551)
end)
test('missing aura data skips Sting without manufacturing ownership and unknown repeat stops all lower advice',function()
 local f,s=fixture();ready(s);s.auraError=true;assert(first(f.addon,s)==14283)
 s.repeatError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable')
 s.repeatError=false;s.knownError=true;assert(not first(f.addon,s))
end)
test('resources cooldown mapping and range gate ready shots without implicit melee',function()
 local f,s,n=fixture();ready(s);own(s,n,13551)
 s.cooldown[14283]={startTime=90,duration=30,isEnabled=true,modRate=1};s.power[3044]=true
 local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.power[3044]=false;assert(first(f.addon,s)==3044);s.range[3044]=false;assert(not first(f.addon,s))
 s.range[3044]=true;s.mapped[3044]=false;assert(not first(f.addon,s))
end)
test('native refused or unreadable usability range never invents ammunition or deadzone readiness',function()
 for _,mode in ipairs({'usable-false','usable-nil','range-false','range-nil'})do
  local f,s=fixture();ready(s)
  if mode=='usable-false'then f.env.C_Spell.IsSpellUsable=function()return false,false end
  elseif mode=='usable-nil'then f.env.C_Spell.IsSpellUsable=function()return nil,nil end
  elseif mode=='range-false'then f.env.C_Spell.IsSpellInRange=function()return false end
  else f.env.C_Spell.IsSpellInRange=function()return nil end end
  local id,r=first(f.addon,s);assert(not id and r.suppressAttack,mode)
 end
end)
test('optional Hawk preserves chosen Monkey Cheetah or existing Hawk and requires native readiness',function()
 local f,s,n=fixture();assert(not optional(f,s));s.known[13165],s.known[14319]=true,true;assert(optional(f,s)==14319)
 for _,id in ipairs({13163,5118,14318,14319})do s.buffs={{spellId=id,name=n[id],sourceUnit='player'}};assert(not optional(f,s))end
 s.buffs={};s.auraError=true;assert(not optional(f,s));s.auraError=false
 s.usable[14319],s.usable[13165]=false,false;assert(not optional(f,s))
end)
test('target guards avoid dead friendly missing or externally engaged targets',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==75)
 for _,mode in ipairs({'friendly','dead','missing'})do s.hostile=mode~='friendly';s.dead=mode=='dead';s.exists=mode~='missing';assert(not first(f.addon,s),mode)end
end)
test('real initializer action bar lookup and main publisher retain Auto start own stings and no melee',function()
 local f,s,n=fixture();ready(s);s.repeatActive=false;local tick,_,messages=nativePublish(f,s)
 tick();assert(f.addon.currentSpell==75);s.repeatActive=true;tick();assert(f.addon.currentSpell==13551)
 own(s,n,3043);tick();assert(f.addon.currentSpell==14283)
 s.range[14283],s.range[3044]=false,false;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603,'invented implicit melee')end
end)
test('real publisher optional Hawk respects chosen aspects and native learned rank mappings',function()
 local f,s,n=fixture();ready(s);s.known[13165],s.known[14319]=true,true;s.buffs={{spellId=5118,name=n[5118],sourceUnit='player'}}
 local tick=nativePublish(f,s);tick();assert(not f.addon.avail_announced['hunter-thirty-hawk'])
 s.buffs={};tick();assert(f.addon.avail_announced['hunter-thirty-hawk']==14319)
end)
test('legacy player book slot Auto75 numeric shape and selected modern failure never cross-fallback',function()
 local f,s=fixture();local e=f.env;local modern=e.C_Spell;e.C_Spell=nil
 e.GetSpellInfo=function(id)local v=modern.GetSpellInfo(id);if v then return v.name,v.subtext,nil,0,0,35,v.spellID end end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 or nil end
 e.SpellHasRange=function(slot,bank)assert(bank=='spell');return modern.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,bank,unit)assert(bank=='spell');return modern.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.IsUsableSpell=modern.IsSpellUsable;e.GetSpellCooldown=function(id)local v=modern.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate end
 local calls=0;e.IsAutoRepeatSpell=function(slot,bank)assert(slot==1075 and bank=='spell');calls=calls+1;return s.repeatActive and 1 or 0 end
 assert(first(f.addon,s)==75);s.repeatActive=true;assert(not first(f.addon,s)and calls>0)
 e.C_Spell=modern;modern.IsAutoRepeatSpell=function()error('selected modern unavailable')end;calls=0;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and calls==0)
end)
test('modern learned player bank observes exact arguments and selected failure never cross-fallback',function()
 local f,s=fixture();local e=f.env;local legacy=0
 e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);return s.known[id]==true end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end;assert(first(f.addon,s)==75 and legacy==0)
 e.C_SpellBook.IsSpellKnown=function()error('unavailable')end;assert(not first(f.addon,s)and legacy==0)
end)
test('three source brackets stay disjoint and the source switch is bounded without a talent observation',function()
 local f,s=fixture();f.load('Defaults/tbc/hunter-starter.lua');f.load('Defaults/tbc/hunter-20-29.lua');local a=f.addon;assert(a:InitializeRotationLibrary())
 f.env.GetTalentTabInfo=function()error('generic preview must not require talents')end
 for _,level in ipairs({19,20,29,30,39,40})do
  s.level=level;a.longtermCache.conditionPlayerLevel=nil;local expected=level==19 and'rm.tbc.hunter.starter'or level<30 and'rm.tbc.hunter.starter.20-29'or level<40 and ID or nil
  local eligible={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then eligible[#eligible+1]=r.id end end
  assert(#eligible==(expected and 1 or 0));if expected then assert(eligible[1]==expected)end
  assert((not not a:evaluateCondition(body(a).switch))==(level>=30 and level<40))
 end
end)
test('edition class vehicle petbattle enable and profile boundaries exclude the packaged source',function()
 for _,case in ipairs({{2,'HUNTER'},{1,'HUNTER'},{5,'MAGE'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f,s=fixture();local a=f.addon;assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible and not a:GetRuntimeRotation(0,row(a).runtimeKey))
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled)
 a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
end)
test('old source graph and saved local clones survive new pack registration and fresh adoption',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/hunter-starter.lua');f.load('Defaults/tbc/hunter-20-29.lua');assert(a:InitializeRotationLibrary());s.level=29
 local oldID='rm.tbc.hunter.starter.20-29';local localID=assert(a:CloneDefaultRotation(0,oldID,'Old local Hunter'));local copy=a:GetEditableRotation(0,localID)
 copy.rotation[1].onTrue[3].action=3044;local before=a:CopySettingsData(copy)
 s.level=30;assert(a:InitializeRotationLibrary());local adopted=assert(a:CloneDefaultRotation(0,ID,'New Hunter'));assert(a:GetEditableRotation(0,adopted).rotation[1].onTrue[3].action==1978)
 local comparison=assert(a:BuildRotationComparison(0,localID,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 local function equal(x,y)if type(x)~=type(y)then return false end;if type(x)~='table'then return x==y end;for k,v in pairs(x)do if not equal(v,y[k])then return false end end;for k in pairs(y)do if x[k]==nil then return false end end;return true end
 assert(equal(a:GetEditableRotation(0,localID),before))
end)
finish()
