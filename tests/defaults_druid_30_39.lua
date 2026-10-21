-- Native observations modeled; real catalog/conditions/rank/readiness and initialized publisher.
-- Example inherited ranks are not a30–39 training schedule.
local SOURCE=arg[1]or'Defaults/tbc/druid-caster-30-39.lua'
local ID='rm.tbc.druid.caster.starter.30-39'
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class,deferSource)
    local f=F.new(product or 5,1,class or 'DRUID');local a,e=f.addon,f.env
    f.translations['Default.TBC.Druid.Caster.Thirty.Name']='TBC Druid caster30–39 preview';f.translations['Default.TBC.Druid.Caster.Thirty.Description']='Caster-only preview; forms, Feral combat and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[5176]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={},form=0,forms={}}
    local families={[5176]={5176,5177,5178,5179},[8921]={8921,8924,8925,8926,8927},[2912]={2912,8949},[768]={768},[5487]={5487},[1066]={1066},[6807]={6807,6808}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.GetNumShapeshiftForms=function(...)assert(select('#',...)==0);return #s.forms end
    e.GetShapeshiftForm=function(...)assert(select('#',...)==0);if s.formError then error('form unavailable')end;return s.form end
    e.GetShapeshiftFormInfo=function(i) return 123,s.form==i,true,s.forms[i] end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.UnitCastingInfo=function()if s.casting then return 'Cast in progress'end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        SpellHasRange=function(id) return true end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==75);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open(SOURCE);if pack then pack:close();if not deferSource then f.load(SOURCE)end end
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
local function row(a)for _,v in ipairs(a:ListDefaultRotations(0))do if v.id==ID then return v end end;error('missing Druidcaster30–39 manifest')end
local function body(a)return row(a).envelope.body end
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
local function nativePublish(f,s)
 local a,e=f.addon,f.env;local glow,messages={},{}
 -- Real initialization establishes main's captured canonical cache helper.
 -- AceDB uses the native frame/event boundary; no production helper is replaced.
 e.OFF='Off';e.securecallfunction=function(fn,...)return fn(...)end
 e.UnitFactionGroup=function()return 'Horde'end;e.GetLocale=function()return 'enUS'end
 e.UnitRace=function()return 'Orc','Orc'end;e.GetRealmName=function()return 'Druid Realm'end
 e.UnitNameUnmodified=function()return 'Druid Character'end;e.GetCurrentRegionName=function()return 'US'end;e.GetCurrentRegion=function()return 1 end
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
 local actions={5176,5177,5178,5179,8921,8924,8925,8926,8927,2912,8949};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-druid'or'Creature-druid'end
 e.UnitName=function(unit)return unit end;e.UnitIsEnemy=function(_,unit)return unit=='target'end;e.UnitThreatSituation=function()return 0 end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function(_,button,kind)glow[#glow+1]={button.id,'clear:'..tostring(kind)}end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='druid-test';a.db.global.effects['druid-test']={type='texture'}
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



local function own(s,n,id,who)s.debuffs={{spellId=id or 8925,name=n[id or 8925],sourceUnit=who or 'player'}}end
test('level thirty-nine does not grant Starfire Moonfire or higher ranks',function()
 local f,s,n=fixture();s.level=39;assert(row(f.addon).eligible and first(f.addon,s)==5176)
 s.known[5179]=true;assert(first(f.addon,s)==5179);s.mapped[5179]=false;assert(first(f.addon,s)==5176)
 s.known[2912]=true;assert(first(f.addon,s)==2912);s.known[8949]=true;assert(first(f.addon,s)==8949)
 s.mapped[8949]=false;assert(first(f.addon,s)==2912)
 s.known[8921],s.known[8927]=true,true;assert(first(f.addon,s)==8927);own(s,n,8927);assert(first(f.addon,s)==2912)
end)
test('source identity schema and action families stay bounded caster-only without talent queries',function()
 local f,s=fixture();local a=f.addon;local r=row(a);assert(r.readOnly and r.validation.valid and r.validation.resolved)
 f.env.GetTalentTabInfo=function()error('generic caster preview must not infer talents')end
 assert(first(a,s)==5176 and #body(a).cooldowns==0)
 local allowed={[5176]=true,[8921]=true,[2912]=true}
 for _,v in ipairs(assert(a.RotationData.IndexRotationSteps(body(a))).rows)do if v.step.action then assert(allowed[v.step.action] and v.step.ranked==false)end end
end)
test('caster brackets and automatic switch bounds are disjoint across nineteen through forty',function()
 local f,s=fixture();f.load('Defaults/tbc/druid-caster-starter.lua');f.load('Defaults/tbc/druid-caster-20-29.lua');local a=f.addon;assert(a:InitializeRotationLibrary())
 for _,level in ipairs({19,20,29,30,39,40})do
  s.level=level;a.longtermCache.conditionPlayerLevel=nil
  local expected=level==19 and'rm.tbc.druid.caster.starter'or level<30 and'rm.tbc.druid.caster.starter.20-29'or level<40 and ID or nil
  local eligible={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then eligible[#eligible+1]=r.id end end
  assert(#eligible==(expected and 1 or 0));if expected then assert(eligible[1]==expected)end
  assert((not not a:evaluateCondition(body(a).switch))==(level>=30 and level<40))
  assert((a:GetRuntimeRotation(0,row(a).runtimeKey)~=nil)==(level>=30 and level<40))
 end
 s.level=30;a.longtermCache.conditionPlayerLevel=nil;s.known[5176]=false;assert(not a:evaluateCondition(body(a).switch))
end)
test('edition class vehicle petbattle enable and current profile gates preserve packaged scope',function()
 local f,s=fixture();local a=f.addon;assert(row(a).eligible)
 for _,case in ipairs({{2,'DRUID'},{1,'DRUID'},{5,'HUNTER'}})do local other=fixture(case[1],case[2]);local rows=other.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not a:GetRuntimeRotation(0,row(a).runtimeKey))
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled)
 a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
end)
test('all nonzero form slots remain manual regardless of learned spell ordering',function()
 for _,forms in ipairs({{768},{1066,768},{783,5487,1066},{5487,1066,768,783}})do
  local f,s=fixture();s.forms=forms;s.known[2912]=true;assert(first(f.addon,s)==2912)
  for i=1,#forms do s.form=i;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)end
 end
end)
test('unavailable form observation takes neither caster nor shifted branch',function()
 for _,mode in ipairs({'nil','error'})do
  local f,s=fixture();s.known[8921],s.known[2912]=true,true
  if mode=='nil'then s.form=nil else s.formError=true end
  local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 end
end)
test('current cast and channel are preserved even when instant Moonfire is missing',function()
 local f,s=fixture();s.known[8921],s.known[2912]=true,true
 for _,mode in ipairs({'casting','channel'})do s[mode]=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack);s[mode]=false end
end)
test('moving caster can maintain missing Moonfire but never begins Wrath or Starfire',function()
 local f,s,n=fixture();s.known[2912]=true;s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.known[8921]=true;assert(first(f.addon,s)==8921);own(s,n,8921);assert(not first(f.addon,s))
 s.moving=false;assert(first(f.addon,s)==2912)
end)
test('own localized Moonfire survives cross-rank refresh while foreign and nil caster do not imply ownership',function()
 local f,s,n=fixture();s.known[8921],s.known[8927],s.known[2912]=true,true,true
 own(s,n,8926);assert(first(f.addon,s)==2912)
 own(s,n,8926,'party1');assert(first(f.addon,s)==8927)
 s.debuffs={{spellId=8926,name=n[8926]}};assert(first(f.addon,s)==8927)
 s.debuffs[1].sourceUnit='player';assert(first(f.addon,s)==2912)
 s.targetHealth=1;assert(first(f.addon,s)==2912);s.debuffs={};assert(first(f.addon,s)==8927)
end)
test('unavailable aura does not invent Moonfire need while independent Starfire remains possible',function()
 local f,s=fixture();s.known[8921],s.known[2912]=true,true;s.auraError=true;assert(first(f.addon,s)==2912)
end)
test('unknown Starfire learning stops branch while known unlearned permits ready Wrath',function()
 local f,s=fixture();local known=f.env.IsSpellKnown
 f.env.IsSpellKnown=function(id,...)if id==2912 then error('unknown learning')end;return known(id,...)end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 f.env.IsSpellKnown=known;assert(first(f.addon,s)==5176)
end)
test('independent readiness and mapping gate every rank without inventing mana or melee',function()
 local f,s=fixture();s.known[2912],s.known[8949],s.known[5179]=true,true,true
 s.power[2912],s.power[8949]=true,true;assert(first(f.addon,s)==5179)
 s.power={};s.cooldown[2912],s.cooldown[8949]={startTime=99,duration=20,isEnabled=true,modRate=1},{startTime=99,duration=20,isEnabled=true,modRate=1};assert(first(f.addon,s)==5179)
 s.cooldown={};s.range[2912],s.range[8949]=false,false;assert(first(f.addon,s)==5179)
 s.range={};s.mapped[2912],s.mapped[8949]=false,false;assert(first(f.addon,s)==5179)
 s.mapped[5179],s.mapped[5176]=false,false;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('unreadable native readiness never manufactures a cast',function()
 for _,mode in ipairs({'usability','range','cooldown'})do
  local f,s=fixture();s.known[8921],s.known[2912]=true,true
  if mode=='usability'then f.env.C_Spell.IsSpellUsable=function()return nil,nil end
  elseif mode=='range'then f.env.C_Spell.IsSpellInRange=function()return nil end
  else f.env.C_Spell.GetSpellCooldown=function()return nil end end
  local id,r=first(f.addon,s);assert(not id and r.suppressAttack,mode)
 end
end)
test('target gates avoid friendly dead missing or externally engaged targets',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==5176)
 for _,mode in ipairs({'friendly','dead','missing'})do s.hostile=mode~='friendly';s.dead=mode=='dead';s.exists=mode~='missing';local id,r=first(f.addon,s);assert(not id and r.suppressAttack,mode)end
end)
test('selected modern learned-bank adapter preserves exact args and never falls back after failure',function()
 local f,s=fixture();local e=f.env;local calls,legacy=0,0;s.known[2912]=true
 e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);calls=calls+1;return s.known[id]==true end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end;assert(first(f.addon,s)==2912 and calls>0 and legacy==0)
 e.C_SpellBook.IsSpellKnown=function()error('selected unavailable')end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and legacy==0)
end)
test('real initialized publisher maps ranks owns DoT and retires every manual form cast and channel',function()
 local f,s,n=fixture();s.known[2912],s.known[8949],s.known[5179]=true,true,true
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==8949 and #glow>0)
 s.known[8921],s.known[8927]=true,true;tick();assert(f.addon.currentSpell==8927)
 own(s,n,8926);tick();assert(f.addon.currentSpell==8949)
 s.power[2912],s.power[8949]=true,true;tick();assert(f.addon.currentSpell==5179)
 for _,mode in ipairs({'form','casting','channel'})do
  if mode=='form'then s.forms={768};s.form=1 else s[mode]=true end
  tick();assert(f.addon.currentSpell==nil,mode)
  s.form=0;s.casting=false;s.channel=false
 end
 s.form=nil;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603 and m[6]~=768 and m[6]~=5570)end
end)
test('real publisher clears advice on unreadable readiness without a guessed fallback',function()
 local f,s=fixture();s.known[2912],s.known[8949]=true,true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==8949)
 f.env.C_Spell.IsSpellUsable=function()return nil,nil end;tick();assert(f.addon.currentSpell==nil)
end)
test('prior caster sources and saved edited clones survive new registration fresh adoption and comparison',function()
 local f,s=fixture(nil,nil,true);local a=f.addon;f.load('Defaults/tbc/druid-caster-starter.lua');f.load('Defaults/tbc/druid-caster-20-29.lua');assert(a:InitializeRotationLibrary());s.level=29
 local old='rm.tbc.druid.caster.starter.20-29';local id=assert(a:CloneDefaultRotation(0,old,'Local edited caster'));local clone=a:GetEditableRotation(0,id)
 clone.rotation[1].onTrue[1].onTrue[2].action=5176;local before=a:CopySettingsData(clone)
 s.level=30;f.load(SOURCE);assert(a:InitializeRotationLibrary());local fresh=assert(a:CloneDefaultRotation(0,ID,'Fresh thirty caster'))
 assert(a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].onTrue[2].action==8921)
 local comparison=assert(a:BuildRotationComparison(0,id,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 assert(a:SettingsDataEqual(before,a:GetEditableRotation(0,id)))
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary())
 assert(a:SettingsDataEqual(before,a:GetEditableRotation(0,id)))
end)
finish()
