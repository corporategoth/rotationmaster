-- Actual conditions/catalog/sequence/readiness and initialized main publisher.
-- Native observations are modeled, not current-client or optimality acceptance.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local SOURCE=arg[1]or'Defaults/tbc/priest-30-39.lua'
local ID='rm.tbc.priest.shadow.30-39'
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'PRIEST');local a,e=f.addon,f.env
    f.translations['Default.TBC.Priest.Shadow30.Name']='Priest: Shadow leveling (30–39)';f.translations['Default.TBC.Priest.Shadow30.Description']='Bounded Shadow-oriented solo preview; learned spells and native readiness remain authoritative. Choose channels and wand manually; healing and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={talents={0,0,21},level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[585]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[585]={585,591,598,984,1004,6060},[589]={589,594,970,992,2767},[8092]={8092,8102,8103,8104,8105},[588]={588,7128,602},[5019]={5019},[15407]={15407,17311,17312}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function(...)assert(select('#',...)==1 and(...)=='player');if s.channelError then error('channel unavailable')end;if s.channelOpaque then return s.channelOpaque end;if s.channel then return names[15407],names[15407],1,99000,102000,false,false,15407 end end
    e.IsSpellKnown=function(id)if s.knownError or id==15407 and s.flayKnownError then error('unavailable')end;if id==15407 and s.flayKnownNil then return nil end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        SpellHasRange=function(id) return id~=588 and id~=7128 and id~=602 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    e.GetNumTalentTabs=function(inspect,pet)assert(inspect==false and pet==false);if s.talentCountError then error('missing talent count')end;return 3 end
    e.C_SpecializationInfo={GetSpecializationInfo=function(index,inspect,pet,target,sex,group)
        assert(index>=1 and index<=3 and inspect==false and pet==false and target==nil and sex==nil and group==nil)
        if s.talentError then error('talents unavailable')end
        return 200+index,({'Localized Discipline','Localized Holy','Localized Shadow'})[index],'Description',136048,nil,nil,s.talents[index],'Background',99,true
    end}
    for _,path in ipairs({'Platform/talents.lua','Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/talent.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local file=io.open(SOURCE);if file then file:close();f.load(SOURCE)end
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
local function row(a)
 for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==ID then return r end end
 error('missing Priest Shadow30–39 manifest')
end
local function body(a)return row(a).envelope.body end
local function switch(a)return a:evaluateConditionResult(body(a).switch)end
local function first(a,s)
 local ready=a:NewActionReadiness(100);local selected
 local result=a:EvaluateRotationSequence(body(a),function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
   if s.mapped[id]~=false and ready(step.type,id)then selected=id;return false end
  end end
 end)
 return selected,result
end
local function pain(s,n,caster)s.debuffs={{spellId=2767,name=n[2767],sourceUnit=caster or'player'}}end
local function entered(s,n)s.combat=true;s.known[589]=true;pain(s,n)end
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
 local actions={585,591,598,984,1004,6060,589,594,970,992,2767,8092,8102,8103,8104,8105,588,7128,602,5019,15407,17311,17312};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;if slot<=12 then e['ActionButton'..slot]=button else e['MultiBarBottomLeftButton'..(slot-12)]=button end
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-priest'or'Creature-priest'end
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
 a.db.profile.disable_autoswitch=false;a.manualRotation=false;a:UpdateAutoSwitch()
 local function tick()a:SwitchRotation();a:EvaluateNextActionInternal()end
 return tick,glow,messages
end

test('new pack and actual switch agree on exact30 through39 bracket and learned anchor',function()
 local f,s=fixture();local a=f.addon;assert(row(a).validation.valid and row(a).validation.resolved and row(a).readOnly)
 for _,level in ipairs({29,30,31,38,39,40})do s.level=level;a.longtermCache={};local want=level>=30 and level<40
  assert(row(a).eligible==want);assert((switch(a).status=='match')==want)
 end
 s.level=30;s.known[585]=false;a.longtermCache={};assert(switch(a).status=='no-match')
end)
test('primary Shadow tree is unique positive and never inferred from class level or localized name',function()
 local f,s=fixture();local a=f.addon
 for _,points in ipairs({{0,0,21},{5,0,16},{21,0,0},{0,21,0},{5,0,5},{0,0,0}})do
  s.talents=points;local r=switch(a);local expected=points[3]>points[1]and points[3]>points[2]and points[3]>0
  assert((r.status=='match')==expected)
  if points[1]==points[3]and points[2]<=points[3]then assert(r.status=='unavailable')end
 end
end)
test('unknown restricted and missing talent points cannot select the Shadow preview',function()
 local f,s=fixture();local a=f.addon
 for _,key in ipairs({'talentError','talentCountError'})do s[key]=true;assert(switch(a).status=='unavailable');s[key]=false end
 s.talents={0,0,nil};assert(switch(a).status=='unavailable')
 local opaque={};s.talents={0,0,opaque};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(switch(a).status=='unavailable')
end)
test('family class and player context eligibility stay separate from talent selection',function()
 for _,case in ipairs({{5,'MAGE'},{2,'PRIEST'},{1,'PRIEST'}})do local f=fixture(case[1],case[2]);for _,r in ipairs(f.addon:ListDefaultRotations(0))do assert(not r.eligible)end end
 for _,mode in ipairs({'vehicle','petbattle'})do local f=fixture();if mode=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end;assert(not row(f.addon).eligible)end
end)
test('level39 does not train Flay or later ranks and actual learned family controls expansion',function()
 local f,s,n=fixture();s.level=39;assert(first(f.addon,s)==585)
 s.known[1004],s.known[6060]=true,true;assert(first(f.addon,s)==6060);s.mapped[6060]=false;assert(first(f.addon,s)==1004)
 s.combat=true;s.known[589],s.known[2767]=true,true;assert(first(f.addon,s)==2767);pain(s,n);assert(first(f.addon,s)==1004)
 s.known[15407],s.known[17312]=true,true;assert(first(f.addon,s)==17312);s.mapped[17312]=false;assert(first(f.addon,s)==15407)
end)
test('opener-only Blast and missing own Pain retain explicit half-health policy',function()
 local f,s,n=fixture();s.known[8092],s.known[8105],s.known[589],s.known[2767],s.known[5019]=true,true,true,true,true
 assert(first(f.addon,s)==8105);s.targetHealth=50;assert(first(f.addon,s)==5019);s.targetHealth=51;s.combat=true;assert(first(f.addon,s)==2767)
 pain(s,n,'party1');assert(first(f.addon,s)==2767);pain(s,n);assert(first(f.addon,s)==5019)
end)
test('inherited learned Flay filler does not interrupt active wand and Pain still precedes wand boundary',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true;assert(first(f.addon,s)==15407)
 s.repeatActive=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)
 s.debuffs={};assert(first(f.addon,s)==589);pain(s,n);s.repeatActive=false;s.targetHealth=50;assert(first(f.addon,s)==5019)
end)
test('readiness mapping power cooldown usability and range retain final authority for Flay',function()
 for _,mode in ipairs({'mapping','power','cooldown','usability','range'})do local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true
  if mode=='mapping'then s.mapped[15407]=false elseif mode=='power'then s.power[15407]=true elseif mode=='cooldown'then s.cooldown[15407]={startTime=99,duration=30,isEnabled=true,modRate=1}elseif mode=='usability'then s.usable[15407]=false else s.range[15407]=false end
  assert(first(f.addon,s)==5019,mode)
 end
end)
test('motion targets and engaged pulls cannot invent ranged attack or implicit melee',function()
 local f,s,n=fixture();local a=f.addon;s.known[589]=true;s.targetCombat=true;assert(not first(a,s));s.combat=true;assert(first(a,s)==589)
 for _,key in ipairs({'hostile','exists'})do s[key]=false;assert(not first(a,s));s[key]=true end;s.dead=true;assert(not first(a,s));s.dead=false
 pain(s,n);s.known[15407],s.known[5019]=true,true;s.moving=true;local id,r=first(a,s);assert(not id and r.status=='stopped'and r.suppressAttack)
 s.moving=false;s.mapped[15407],s.mapped[5019],s.mapped[585]=false,false,false;id,r=first(a,s);assert(not id and r.suppressAttack)
end)
test('any active manual channel and unknown channel or wand facts stop replacement',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true
 f.env.UnitChannelInfo=function()return 'Localized other channel'end;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)
 f.env.UnitChannelInfo=function()error('channel unavailable')end;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 f.env.UnitChannelInfo=function()end;s.repeatError=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.repeatError=false;s.flayKnownNil=true;s.targetHealth=50;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('unknown aura or health never manufactures a positive Pain or Flay match',function()
 local f,s=fixture();s.combat=true;s.known[589],s.known[15407],s.known[5019]=true,true,true;s.auraError=true;assert(first(f.addon,s)==15407)
 s.auraError=false;s.healthError=true;assert(first(f.addon,s)==5019)
end)
test('only self-only Inner Fire upkeep uses learned family and preserves existing manual responsibilities',function()
 local f,s,n=fixture();assert(not optional(f,s));s.known[588],s.known[602]=true,true;assert(optional(f,s)==602)
 s.buffs={{spellId=602,name=n[602],sourceUnit='player'}};assert(not optional(f,s));s.buffs={};s.auraError=true;assert(not optional(f,s))
 local allowed={[585]=true,[589]=true,[8092]=true,[588]=true,[5019]=true,[15407]=true}
 for _,entry in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do if entry.step.action then assert(allowed[entry.step.action])end end
end)
test('old Priest brackets and saved clones preserve their scopes and independent source bodies',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/priest-starter.lua');f.load('Defaults/tbc/priest-20-29.lua');s.level=29;a.longtermCache={}
 local id=assert(a:CloneDefaultRotation(0,'rm.tbc.priest.starter.20-29','Old Priest clone'));local old=a:CopySettingsData(a:GetEditableRotation(0,id))
 s.level=30;a.longtermCache={};assert(not a:GetRuntimeRotation(0,id));assert(a:SettingsDataEqual(old,a:GetEditableRotation(0,id)))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Shadow30 clone'));assert(a:GetRuntimeRotation(0,fresh));a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].suppress_attack=false;assert(body(a).rotation[1].onTrue[1].suppress_attack)
 for _,level in ipairs({19,20,29,30,39,40})do s.level=level;a.longtermCache={};local eligible={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then eligible[#eligible+1]=r.id end end
  assert(#eligible==(level==40 and 0 or 1));if level>=30 and level<40 then assert(eligible[1]==ID)end
 end
end)
test('initialized real action bars publish mapped learned Flay rank and clear during channel or wand',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[17312],s.known[5019]=true,true,true;local tick,glow,messages=nativePublish(f,s);local a=f.addon
 tick();assert(a.currentSpell==17312);local highlighted=false;for _,v in ipairs(glow)do if v[1]==17312 then highlighted=true end end;assert(highlighted)
 s.channel=true;tick();assert(not a.currentSpell);s.channel=false;s.targetHealth=50;tick();assert(a.currentSpell==5019);s.repeatActive=true;tick();assert(not a.currentSpell)
 s.repeatActive=false;s.targetHealth=100;s.mapped[17312]=false;a:Fetch();tick();assert(a.currentSpell==15407)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==17312 then found=true end end;assert(found)
end)
test('real auto-switch retires and rebuilds selection after respec unknown points and return',function()
 local f,s,n=fixture();entered(s,n);s.known[15407]=true;local tick=nativePublish(f,s);local a=f.addon;tick();assert(a.currentSpell==15407)
 s.talents={21,0,0};tick();assert(not a.currentRotation and not a.currentSpell)
 s.talents={0,0,21};tick();assert(a.currentSpell==15407);s.talents={0,0,0};tick();assert(not a.currentRotation and not a.currentSpell)
 s.talents={0,0,21};tick();assert(a.currentSpell==15407);s.talentError=true;tick();assert(not a.currentRotation and not a.currentSpell)
end)
test('manual cast retains prior next-action behavior rather than silently adding a cast Stop',function()
 local f,s,n=fixture();entered(s,n);s.known[15407]=true;f.env.UnitCastingInfo=function()return 'Manual cast'end
 local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==15407)
end)
finish()
