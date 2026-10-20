-- Actual Hunter continuation controls; native APIs modeled, runtime/publication real.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'HUNTER');local a,e=f.addon,f.env
    f.translations['Default.TBC.Hunter.Continuation.Name']='TBC Hunter continuation preview';f.translations['Default.TBC.Hunter.Continuation.Description']='Bounded ranged preview; pets, melee and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=20,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
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
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open('Defaults/tbc/hunter-20-29.lua');if pack then pack:close();f.load('Defaults/tbc/hunter-20-29.lua')end
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
    local row=a:ListDefaultRotations(0)[1];assert(row,'missing Hunter20–29 preview');assert(row.eligible,row.eligibilityReason);return row.envelope.body
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

test('actual known rank catalog starts Auto Shot and only adopts trained mapped instant ranks',function()
 local f,s=fixture();assert(first(f.addon,s)==75);s.repeatActive=true;assert(not first(f.addon,s));s.known[1978]=true;assert(first(f.addon,s)==1978);s.known[13549],s.known[13550]=true,true;assert(first(f.addon,s)==13550);s.mapped[13550]=false;assert(first(f.addon,s)==13549)
end)
test('known active and unknown Auto Shot never advise the off toggle',function()
 local f,s,n=fixture();s.repeatActive=true;assert(not first(f.addon,s));s.known[3044]=true;assert(first(f.addon,s)==3044);s.repeatError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('own Sting priority ignores other hunters and Arcane respects native cooldown and resources',function()
 local f,s,n=fixture();s.repeatActive=true;s.known[1978],s.known[13550],s.known[3044],s.known[14281]=true,true,true,true
 own(s,n,nil,'party1');assert(first(f.addon,s)==13550);own(s,n);assert(first(f.addon,s)==14281);s.cooldown[14281]={startTime=90,duration=30,isEnabled=true,modRate=1};s.power[3044]=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
end)
test('movement permits instants but no new stationary auto start and existing casts channels are preserved',function()
 local f,s=fixture();s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.known[3044]=true;assert(first(f.addon,s)==3044);s.casting=true;assert(not first(f.addon,s));s.casting=false;s.channel=true;assert(not first(f.addon,s))
end)
test('unknown aura learned repeat and range data cannot invent a ready shot',function()
 local f,s=fixture();s.repeatActive=true;s.known[1978]=true;s.auraError=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.auraError=false;s.repeatError=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable');s.repeatError=false;s.knownError=true;assert(not first(f.addon,s))
 local g,t=fixture();g.env.C_Spell.IsSpellInRange=function()return nil end;id,r=first(g.addon,t);assert(not id and r.suppressAttack)
end)
test('native unusable ammo model and deadzone range do not create manual melee fallback',function()
 local f,s=fixture();s.known[1978],s.known[3044]=true,true;f.env.C_Spell.IsSpellUsable=function()return false,false end;local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 local g,t=fixture();t.known[1978],t.known[3044]=true,true;for _,id in ipairs({75,1978,3044})do t.range[id]=false end;id,r=first(g.addon,t);assert(not id and r.suppressAttack)
end)
test('optional self-only Hawk respects an existing deliberate Monkey aspect',function()
 local f,s,n=fixture();assert(not optional(f,s));s.known[13165],s.known[14318]=true,true;assert(optional(f,s)==14318);s.buffs={{spellId=13163,name=n[13163],sourceUnit='player'}};assert(not optional(f,s));s.buffs={{spellId=14318,name=n[14318],sourceUnit='player'}};assert(not optional(f,s));s.buffs={};s.auraError=true;assert(not optional(f,s))
end)
test('hostile group combat and source level clone bounds retain manual pet and melee roles',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==75);s.hostile=false;assert(not first(f.addon,s));s.hostile=true;s.dead=true;assert(not first(f.addon,s));s.dead=false;s.exists=false;assert(not first(f.addon,s))
 local a=f.addon;local id=assert(a:CloneDefaultRotation(0,'rm.tbc.hunter.starter.20-29','Hunter copy'));local clone=a:GetEditableRotation(0,id);clone.rotation[1].onTrue[3].action=3044;assert(body(a).rotation[1].onTrue[3].action==1978);s.level=30;assert(not a:ListDefaultRotations(0)[1].eligible)
end)
test('actual initialized buttons FindSpell and main publication preserve start repeat instants and no melee',function()
 local f,s,n=fixture();s.mapped[13550]=false;local tick,_,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==75,"initial native auto="..tostring(f.addon.currentSpell));s.repeatActive=true;tick();assert(f.addon.currentSpell==nil);s.known[1978],s.known[13549],s.known[13550]=true,true,true;tick();assert(f.addon.currentSpell==13549,"native rank="..tostring(f.addon.currentSpell));own(s,n);s.known[3044]=true;tick();assert(f.addon.currentSpell==3044,"native arcane="..tostring(f.addon.currentSpell))
 s.range[3044]=false;tick();assert(f.addon.currentSpell==nil);for _,row in ipairs(messages)do assert(row[6]~=6603,'invented implicit melee')end
end)
test('legacy player book slot Auto75 preserves numeric repeat and selected modern failure never falls back',function()
 local f,s=fixture();local e=f.env;local modern=e.C_Spell;e.C_Spell=nil
 e.GetSpellInfo=function(id)local v=modern.GetSpellInfo(id);if v then return v.name,v.subtext,nil,0,0,35,v.spellID end end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 or nil end
 e.SpellHasRange=function(slot,bank)assert(bank=='spell');return modern.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,bank,unit)assert(bank=='spell');return modern.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.IsUsableSpell=modern.IsSpellUsable;e.GetSpellCooldown=function(id)local v=modern.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate end
 local calls=0;e.IsAutoRepeatSpell=function(slot,bank)assert(slot==1075 and bank=='spell');calls=calls+1;return s.repeatActive and 1 or 0 end
 assert(first(f.addon,s)==75);s.repeatActive=true;assert(not first(f.addon,s));assert(calls>0)
 e.C_Spell=modern;modern.IsAutoRepeatSpell=function()error('selected modern unavailable')end;calls=0;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and calls==0)
end)
test('foreign edition class and vehicle context remain excluded without changing saved clones',function()
 for _,case in ipairs({{2,'HUNTER'},{1,'HUNTER'},{5,'MAGE'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f=fixture();f.env.UnitHasVehicleUI=function()return true end;assert(not f.addon:ListDefaultRotations(0)[1].eligible)
end)

test('disabled packaged preferences profile changes petbattle and source level remain authoritative',function()
 local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1];local key=row.runtimeKey
 assert(row.readOnly and row.validation.valid and row.validation.resolved)
 assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotation(0,key))
 assert(a:SetDefaultRotationEnabled(row.id,true));assert(a:GetRuntimeRotation(0,key))
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not a:ListDefaultRotations(0)[1].eligible)
 f.env.C_PetBattles=nil;assert(a:ListDefaultRotations(0)[1].eligible)
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(a:ListDefaultRotations(0)[1].enabled)
 a.db.profile=profile;assert(a:InitializeRotationLibrary());s.level=30;assert(not a:ListDefaultRotations(0)[1].eligible)
 assert(not a:evaluateCondition(a:ListDefaultRotations(0)[1].envelope.body.switch))
end)
test('saved local edits comparison and fresh clone adoption never silently rewrite old data',function()
 local f,s=fixture();local a=f.addon;local source='rm.tbc.hunter.starter.20-29'
 local id=assert(a:CloneDefaultRotation(0,source,'Local Hunter'));local clone=a:GetEditableRotation(0,id)
 clone.rotation[1].onTrue[3].action=3044;local edited=a:CopySettingsData(clone)
 local comparison=assert(a:BuildRotationComparison(0,id,{kind='builtin',id=source}));assert(comparison.valid and comparison.complete)
 local freshID=assert(a:CloneDefaultRotation(0,source,'Adopted Hunter'));local fresh=a:GetEditableRotation(0,freshID)
 assert(fresh.rotation[1].onTrue[3].action==1978 and clone.rotation[1].onTrue[3].action==3044)
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary())
 assert(a:SettingsDataEqual(edited,a:GetEditableRotation(0,id)) and a:GetRuntimeRotation(0,id))
 s.level=30;assert(not a:GetRuntimeRotation(0,id) and not a:GetRuntimeRotation(0,freshID))
end)
test('unavailable native usability and range cannot manufacture ammo readiness or melee advice',function()
 for _,mode in ipairs({'usable','range'})do
  local f,s=fixture();s.known[1978],s.known[3044]=true,true
  if mode=='usable'then f.env.C_Spell.IsSpellUsable=function()return nil,nil end else f.env.C_Spell.IsSpellInRange=function()return nil end end
  local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 end
 -- This models native unavailable facts. No bag/ammo observation or guarantee is inferred.
end)
test('optional Hawk preserves deliberate Cheetah and Monkey independently of spellbook facts',function()
 local f,s,n=fixture();s.known[13165],s.known[14318],s.known[14319]=true,true,true;assert(optional(f,s)==14319)
 s.buffs={{spellId=5118,name=n[5118],sourceUnit='player'}};assert(not optional(f,s))
 s.known[5118]=false;assert(not optional(f,s));s.buffs={{spellId=13163,name=n[13163],sourceUnit='player'}};assert(not optional(f,s))
 s.buffs={{spellId=14319,name=n[14319],sourceUnit='player'}};assert(not optional(f,s));s.buffs={{spellId=14318,name=n[14318],sourceUnit='player'}};assert(not optional(f,s));s.buffs={};assert(optional(f,s)==14319)
end)
test('own Scorpid is preserved but another Hunter does not suppress this Hunters Serpent',function()
 local f,s,n=fixture();s.repeatActive=true;s.known[1978],s.known[13551],s.known[3044],s.known[14283]=true,true,true,true
 s.debuffs={{spellId=3043,name=n[3043],sourceUnit='player'}};assert(first(f.addon,s)==14283)
 s.known[3043]=false;assert(first(f.addon,s)==14283);s.debuffs={{spellId=3043,name=n[3043],sourceUnit='party1'}};assert(first(f.addon,s)==13551)
 s.debuffs={};assert(first(f.addon,s)==13551)
end)
test('twenty-nine grants no ranks and actual learned new families remain ranked/mapped',function()
 local f,s,n=fixture();s.level=29;s.repeatActive=true;s.known[1978],s.known[13550],s.known[3044],s.known[14281]=true,true,true,true
 assert(first(f.addon,s)==13550);s.known[13551]=true;assert(first(f.addon,s)==13551);s.mapped[13551]=false;assert(first(f.addon,s)==13550)
 own(s,n,13550);assert(first(f.addon,s)==14281);s.known[14282]=true;assert(first(f.addon,s)==14282);s.known[14283]=true;assert(first(f.addon,s)==14283)
 s.mapped[14283]=false;assert(first(f.addon,s)==14282)
end)
test('native minimum-range refusal and unavailable range never invent melee or positioning',function()
 local f,s=fixture();s.known[1978],s.known[13551],s.known[3044],s.known[14282],s.known[14283]=true,true,true,true,true
 for _,id in ipairs({75,1978,13551,3044,14282,14283})do s.range[id]=false end
 local id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 f.env.C_Spell.IsSpellInRange=function()return nil end;id,r=first(f.addon,s);assert(not id and r.suppressAttack)
 local actions={};for _,row in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do if row.step.action then actions[row.step.action]=true end end
 for _,id in ipairs({6603,2973,1495,1513,1130,5116,2643,3045,1499,3043,5118,19434,56641})do assert(not actions[id])end
end)
test('real publisher uses new rank mappings while preserving Cheetah and own Scorpid',function()
 local f,s,n=fixture();s.repeatActive=true;s.known[1978],s.known[13551],s.known[3044],s.known[14282],s.known[14283]=true,true,true,true,true
 s.known[13165],s.known[14318],s.known[14319]=true,true,true;s.buffs={{spellId=5118,name=n[5118],sourceUnit='player'}}
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==13551);assert(not f.addon.avail_announced['hunter-continuation-hawk'])
 s.debuffs={{spellId=3043,name=n[3043],sourceUnit='player'}};tick();assert(f.addon.currentSpell==14283)
 s.buffs={};tick();assert(f.addon.avail_announced['hunter-continuation-hawk']==14319)
 s.range[14283],s.range[14282],s.range[3044]=false,false,false;tick();assert(f.addon.currentSpell==nil)
 for _,m in ipairs(messages)do assert(m[6]~=6603)end
end)
test('modern exact Auto75 query nil/missing/error does not call legacy state fallback',function()
 local f,s=fixture();local e=f.env;local old=e.C_Spell.IsAutoRepeatSpell;local queries,legacy=0,0
 e.IsAutoRepeatSpell=function()legacy=legacy+1;return 1 end
 e.C_Spell.IsAutoRepeatSpell=function(...)assert(select('#',...)==1 and (...)==75);queries=queries+1;return old(...)end
 assert(first(f.addon,s)==75 and queries==1 and legacy==0)
 e.C_Spell.IsAutoRepeatSpell=function()return nil end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and legacy==0)
 e.C_Spell.IsAutoRepeatSpell=function()error('unavailable')end;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and legacy==0)
end)
test('separate old/new default IDs cover nineteen/twenty/twenty-nine/thirty without overlap',function()
 local f,s=fixture();f.load('Defaults/tbc/hunter-starter.lua');assert(f.addon:InitializeRotationLibrary())
 for _,level in ipairs({19,20,29,30})do s.level=level;local rows=f.addon:ListDefaultRotations(0);assert(#rows==2);local eligible={};for _,row in ipairs(rows)do if row.eligible then eligible[row.id]=true end end
 assert((eligible['rm.tbc.hunter.starter']==true)==(level==19));assert((eligible['rm.tbc.hunter.starter.20-29']==true)==(level==20 or level==29))end
end)
test('modern learned player bank has exact two arguments and no selected failure fallback',function()
 local f,s=fixture();local e=f.env;local calls,legacy=0,0
 e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);calls=calls+1;return s.known[id]==true end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end
 assert(first(f.addon,s)==75 and calls>0 and legacy==0)
 e.C_SpellBook.IsSpellKnown=function()error('selected learned observation unavailable')end;assert(not first(f.addon,s)and legacy==0)
end)
test('nil aura caster is not invented as own under the existing attribution contract',function()
 local f,s,n=fixture();s.repeatActive=true;s.known[1978],s.known[13551],s.known[3044]=true,true,true
 s.debuffs={{spellId=3043,name=n[3043]}};assert(first(f.addon,s)==13551)
 s.debuffs[1].sourceUnit='player';assert(first(f.addon,s)==3044)
end)
finish()
