-- Actual Druid continuation controls; form/native values modeled, source/publication real.
-- Original Druid caster controls; real registry, conditions, rank selection and native publisher.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'DRUID');local a,e=f.addon,f.env
    f.translations['Default.TBC.Druid.Caster.Continuation.Name']='TBC Druid caster leveling preview';f.translations['Default.TBC.Druid.Caster.Continuation.Description']='Caster-only preview; forms, Feral combat and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=20,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
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
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open('Defaults/tbc/druid-caster-20-29.lua');if pack then pack:close();f.load('Defaults/tbc/druid-caster-20-29.lua')end
    e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function() return 'Rotation Master test' end
    e.UnitGUID=function() return 'Player-test' end
    f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
    f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
    f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
    f.libraries['ThreatClassic-1.0']={Disable=function() end};f.libraries['LibClassicDurations'].Register=function()end
    f.load('Core/rotation_sequence.lua');f.load('main.lua')
    for id in pairs(names) do a.SpellCatalog:UpdateSpell(id) end
    assert(a:InitializeRotationLibrary());return f,s,names
end
local function body(a)
    local row=a:ListDefaultRotations(0)[1];assert(row,'missing Druidcaster20–29 preview');assert(row.eligible,row.eligibilityReason);return row.envelope.body
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
test('untrained caster learns only mapped Wrath and own missing Moonfire ranks',function()
 local f,s,n=fixture();assert(first(f.addon,s)==5176);s.known[5177],s.known[5178]=true,true;assert(first(f.addon,s)==5178);s.mapped[5178]=false;assert(first(f.addon,s)==5177)
 s.known[8921],s.known[8925]=true,true;assert(first(f.addon,s)==8925);own(s,n,nil,'party1');assert(first(f.addon,s)==8925);own(s,n);assert(first(f.addon,s)==5177)
end)
test('humanoid zero works with no learned forms or only Aquatic or Bear and both orders',function()
 for _,forms in ipairs({{},{1066},{5487},{5487,1066},{1066,5487}})do
  local f,s=fixture();s.forms=forms;s.form=0;assert(first(f.addon,s)==5176)
  for i=1,#forms do s.form=i;local id,r=first(f.addon,s);assert(not id and r.suppressAttack and r.status=='stopped')end
 end
end)
-- Modeled alternate topology documents the index/identity gap, not a native ordering claim.
test('modeled Aquatic-only slot1 cannot identify Bear and no form action is manufactured',function()
 local f,s=fixture();s.forms={1066};s.form=1;s.known[1066]=true;s.known[5487]=false
 assert(f.env.GetShapeshiftFormInfo(1)==123 and select(4,f.env.GetShapeshiftFormInfo(1))==1066)
 assert(f.addon:evaluateCondition({type='FORM',value=1}),'existing index equality cannot identify Bear')
 local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('unreadable missing failed form is unavailable and never chooses caster or a shifted action',function()
 for _,mode in ipairs({'nil','throw','missing','restricted'})do local f,s=fixture()
  if mode=='nil'then s.form=nil elseif mode=='throw'then s.formError=true elseif mode=='missing'then f.env.GetShapeshiftForm=nil else s.form={};local opaque=s.form;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end end
  local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack,mode)
 end
end)
test('movement allows Moonfire but protects Wrath casts channels and existing own effects',function()
 local f,s,n=fixture();s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.known[8921]=true;assert(first(f.addon,s)==8921)
 own(s,n,8921);assert(not first(f.addon,s));s.moving=false;assert(first(f.addon,s)==5176)
 s.casting=true;assert(not first(f.addon,s));s.casting=false;s.channel=true;assert(not first(f.addon,s))
end)
test('native mana usability cooldown range and mappings remain sole action authority',function()
 local f,s=fixture();s.known[8921]=true;s.power[8921]=true;assert(first(f.addon,s)==5176);s.power[5176]=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 s.power={};s.cooldown[8921]={startTime=99,duration=10,isEnabled=true,modRate=1};assert(first(f.addon,s)==5176)
 s.range[5176]=false;assert(not first(f.addon,s));s.cooldown={};s.mapped[8921]=false;assert(not first(f.addon,s))
end)
test('unknown aura does not invent Moonfire but independent known Wrath remains permitted',function()
 local f,s=fixture();s.known[8921]=true;s.auraError=true;assert(first(f.addon,s)==5176)
 s.power[5176]=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('actual main buttons publish caster priorities but never forms Bear rage actions or melee fallback',function()
 local f,s,n=fixture();local tick,_,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==5176)
 s.known[8921],s.known[8925]=true,true;tick();assert(f.addon.currentSpell==8925);own(s,n);tick();assert(f.addon.currentSpell==5176)
 s.forms={1066};s.form=1;s.known[5487],s.known[6807]=true,true;tick();assert(f.addon.currentSpell==nil)
 s.form=0;s.power[5176]=true;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603 and m[6]~=5487 and m[6]~=1066 and m[6]~=6807)end
end)
test('hostile combat source known gate scope disabled preferences and clones remain existing contracts',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==5176);s.hostile=false;assert(not first(f.addon,s))
 local a=f.addon;local row=a:ListDefaultRotations(0)[1];assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:ListDefaultRotations(0)[1].eligible);assert(a:SetDefaultRotationEnabled(row.id,true))
 local id=assert(a:CloneDefaultRotation(0,row.id,'Druid caster clone'));local clone=a:GetEditableRotation(0,id);clone.rotation[1].onTrue[1].onTrue[2].action=5176;assert(body(a).rotation[1].onTrue[1].onTrue[2].action==8921)
 s.level=30;assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotation(0,id))
 for _,case in ipairs({{5,'HUNTER'},{2,'DRUID'},{1,'DRUID'}})do local other=fixture(case[1],case[2]);local rows=other.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
end)
test('authored pack has no stance spells heals targeted upkeep rage or energy policy',function()
 local f=fixture();local b=body(f.addon);assert(#b.cooldowns==0)
 for _,r in ipairs(assert(f.addon.RotationData.IndexRotationSteps(b)).rows)do local step=r.step;if step.action then assert(step.action==5176 or step.action==8921 or step.action==2912)end end
end)
test('current compiled FORM source preserves humanoid identity and unavailable branch semantics',function()
 local f,s=fixture();local a=f.addon;for _,path in ipairs({'Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'})do f.load(path)end;f.env.loadstring=function(code,name)local fn,why=loadstring(code,name);if fn then setfenv(fn,f.env)end;return fn,why end;local source=assert(a:GetBuiltinConditionSource('FORM'));a:RegisterCondition('DRUID_COPY_FORM',assert(a:CompileCustomCondition('DRUID_COPY_FORM',source)))
 local n={type='DRUID_COPY_FORM',value=0};assert(a.conditionDefinitions.DRUID_COPY_FORM.valid(0,n));assert(a:evaluateConditionResult(n).status=='match')
 s.forms={1066};s.form=1;assert(a:evaluateConditionResult(n).status=='no-match')
 s.form=nil;assert(a:evaluateConditionResult({type='NOT',value=n}).status=='unavailable')
 local branch={rotation={{id='copy-form',type='branch',conditions=n,onTrue={{id='yes',type='spell',action=5176}},onFalse={{id='no',type='spell',action=8921}}}}}
 assert(a:EvaluateRotationSequence(branch,function(v)return a:evaluateConditionResult(v)end,function()error('unknown compiled form selected branch')end).status=='unavailable')
end)

test('profile petbattle vehicle source learning and cloned data never bypass caster scope',function()
 local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1]
 assert(row.id=='rm.tbc.druid.caster.starter.20-29' and row.readOnly and row.validation.valid and row.validation.resolved)
 s.known[5176]=false;assert(not a:evaluateCondition(row.envelope.body.switch));s.known[5176]=true
 local runtimeKey=row.runtimeKey;assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:GetRuntimeRotation(0,runtimeKey));assert(a:SetDefaultRotationEnabled(row.id,true));assert(a:GetRuntimeRotation(0,runtimeKey))
 for _,kind in ipairs({'vehicle','petbattle'})do
  if kind=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end
  assert(not a:ListDefaultRotations(0)[1].eligible,kind)
  f.env.UnitHasVehicleUI=function()return false end;f.env.C_PetBattles=nil
 end
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(a:ListDefaultRotations(0)[1].enabled)
 a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(a:GetRuntimeRotation(0,runtimeKey))
end)
test('explicit fresh clone adoption and comparison preserve prior local edits and selected manual forms',function()
 local f,s=fixture();local a=f.addon;local source='rm.tbc.druid.caster.starter.20-29'
 local id=assert(a:CloneDefaultRotation(0,source,'Edited caster'));local clone=a:GetEditableRotation(0,id)
 clone.rotation[1].onTrue[1].onTrue[2].action=5176;local saved=a:CopySettingsData(clone)
 local diff=assert(a:BuildRotationComparison(0,id,{kind='builtin',id=source}));assert(diff.valid and diff.complete)
 local freshID=assert(a:CloneDefaultRotation(0,source,'Fresh caster'));local fresh=a:GetEditableRotation(0,freshID)
 assert(fresh.rotation[1].onTrue[1].onTrue[2].action==8921 and clone.rotation[1].onTrue[1].onTrue[2].action==5176)
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(a:SettingsDataEqual(saved,a:GetEditableRotation(0,id)))
 s.forms={1066};s.form=1;local result=a:EvaluateRotationSequence(fresh,function(v)return a:evaluateConditionResult(v)end,function()error('manual form yielded a caster spell')end)
 assert(result.suppressAttack and result.status=='stopped')
 s.level=30;assert(not a:GetRuntimeRotation(0,id) and not a:GetRuntimeRotation(0,freshID))
end)
test('actual trained Starfire family precedes independently ready Wrath without granting ranks',function()
 local f,s=fixture();s.level=29;s.known[5179]=true;assert(first(f.addon,s)==5179)
 s.known[2912]=true;assert(first(f.addon,s)==2912);s.known[8949]=true;assert(first(f.addon,s)==8949)
 s.mapped[8949]=false;assert(first(f.addon,s)==2912);s.mapped[2912]=false;assert(first(f.addon,s)==5179)
end)
test('new Moonfire ranks preserve own localized aura before stationary Starfire policy',function()
 local f,s,n=fixture();s.known[8921],s.known[8926],s.known[8927],s.known[2912],s.known[8949]=true,true,true,true,true
 assert(first(f.addon,s)==8927);own(s,n,8926,'party1');assert(first(f.addon,s)==8927);own(s,n,8926);assert(first(f.addon,s)==8949)
 s.targetHealth=1;assert(first(f.addon,s)==8949);s.debuffs={};assert(first(f.addon,s)==8927)
end)
test('unavailable Starfire learning is distinct from known-unlearned fallback',function()
 local f,s=fixture();local old=f.env.IsSpellKnown
 f.env.IsSpellKnown=function(id,bank)if id==2912 then error('learning unknown')end;return old(id,bank)end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 f.env.IsSpellKnown=old;assert(first(f.addon,s)==5176)
end)
test('known Starfire native power cooldown range refusal leaves Wrath fallback independently authoritative',function()
 local f,s=fixture();s.known[2912],s.known[8949],s.known[5179]=true,true,true
 s.power[8949],s.power[2912]=true,true;assert(first(f.addon,s)==5179)
 s.power={};s.cooldown[8949],s.cooldown[2912]={startTime=99,duration=20,isEnabled=true,modRate=1},{startTime=99,duration=20,isEnabled=true,modRate=1};assert(first(f.addon,s)==5179)
 s.cooldown={};s.range[8949],s.range[2912]=false,false;assert(first(f.addon,s)==5179)
 f.env.C_Spell.IsSpellUsable=function(id)if id==2912 or id==8949 then return nil,nil end;return true,false end;assert(first(f.addon,s)==5179)
 s.range[5179],s.range[5176]=false,false;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('Cat and alternate learned-form topologies remain manual with no slot inference',function()
 for _,forms in ipairs({{768},{1066,768},{768,5487,1066},{5487,1066,768}})do
  local f,s=fixture();s.forms=forms;s.known[2912],s.known[768],s.known[5487]=true,true,true
  s.form=0;assert(first(f.addon,s)==2912)
  for index=1,#forms do s.form=index;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)end
 end
end)
test('motion current casts and channels never introduce a cast or implicit Feral attack',function()
 local f,s,n=fixture();s.known[2912]=true;s.moving=true;assert(not first(f.addon,s));s.known[8921]=true;assert(first(f.addon,s)==8921)
 own(s,n,8921);assert(not first(f.addon,s));s.moving=false;assert(first(f.addon,s)==2912)
 s.casting=true;assert(not first(f.addon,s));s.casting=false;s.channel=true;assert(not first(f.addon,s))
end)
test('real initialized publisher maps new caster ranks and preserves fallback and nonzero-form retirement',function()
 local f,s,n=fixture();s.known[2912],s.known[8949],s.known[5179]=true,true,true
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==8949)
 s.power[8949],s.power[2912]=true,true;tick();assert(f.addon.currentSpell==5179)
 s.known[8921],s.known[8926],s.known[8927]=true,true,true;tick();assert(f.addon.currentSpell==8927)
 own(s,n,8926);tick();assert(f.addon.currentSpell==5179);s.forms={768};s.form=1;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603 and m[6]~=768 and m[6]~=5570)end
end)
test('modern player learned-bank observation is exact two args and selected failure has no legacy fallback',function()
 local f,s=fixture();local e=f.env;local calls,legacy=0,0;s.known[2912]=true
 e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);calls=calls+1;return s.known[id]==true end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end;assert(first(f.addon,s)==2912 and calls>0 and legacy==0)
 e.C_SpellBook.IsSpellKnown=function()error('selected unavailable')end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and legacy==0)
end)
test('separate caster IDs have exact nineteen/twenty/twenty-nine/thirty scope separation',function()
 local f,s=fixture();f.load('Defaults/tbc/druid-caster-starter.lua');assert(f.addon:InitializeRotationLibrary())
 for _,level in ipairs({19,20,29,30})do s.level=level;local rows=f.addon:ListDefaultRotations(0);assert(#rows==2);local eligible={};for _,row in ipairs(rows)do if row.eligible then eligible[row.id]=true end end
 assert((eligible['rm.tbc.druid.caster.starter']==true)==(level==19));assert((eligible['rm.tbc.druid.caster.starter.20-29']==true)==(level==20 or level==29))end
end)
test('nil caster is not invented as own while native-attributable Moonfire is preserved',function()
 local f,s,n=fixture();s.known[8921],s.known[8927],s.known[2912]=true,true,true
 s.debuffs={{spellId=8927,name=n[8927]}};assert(first(f.addon,s)==8927)
 s.debuffs[1].sourceUnit='player';assert(first(f.addon,s)==2912)
end)
finish()
