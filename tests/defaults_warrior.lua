-- Actual Warrior pack scenarios; native APIs are modeled, runtime/publication are real.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'WARRIOR');local a,e=f.addon,f.env
    f.translations['Default.TBC.Warrior.Starter.Name']='TBC Warrior early leveling preview';f.translations['Default.TBC.Warrior.Starter.Description']='Bounded solo preview; heals, party support and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=1,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[78]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[78]={78,284,285},[772]={772,6546},[6673]={6673,5242},[6603]={6603},[7384]={7384}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;if s.activeNil then return nil end;return s.active==id end,SpellHasRange=function(id) return id~=6673 and id~=5242 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    f.load('Defaults/tbc/warrior-starter.lua')
    a.Platform.IsBeyondMeleeRange=function()return s.beyond==true end
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
    local row=a:ListDefaultRotations(0)[1];assert(row.eligible,row.eligibilityReason);return row.envelope.body
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
 local actions={78,284,285,772,6546,6673,5242,6603};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
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

local function rend(s,names,source)s.debuffs={{spellId=6546,name=names[6546],sourceUnit=source or 'player'}}end

test('combat-only trained rank priority preserves no-pull policy',function()
 local f,s,n=fixture();assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==78)
 s.known[772]=true;assert(first(f.addon,s)==772);s.known[6546]=true;assert(first(f.addon,s)==6546)
 rend(s,n);assert(first(f.addon,s)==78);s.known[284],s.known[285]=true,true;assert(first(f.addon,s)==285)
end)
test('localized own Rend and optional higher-rank Battle Shout are independent',function()
 local f,s,n=fixture();s.combat=true;s.known[772],s.known[6546]=true,true
 rend(s,n,'party1');assert(first(f.addon,s)==6546);rend(s,n);assert(first(f.addon,s)==78)
 s.known[6673],s.known[5242]=true,true;assert(optional(f,s)==5242);s.buffs={{spellId=5242,name=n[5242],sourceUnit='party1'}};assert(not optional(f,s))
end)
test('all three exact pending ranks suppress repeated HS including lower mapped rank',function()
 local f,s,n=fixture();s.combat=true;s.known[284],s.known[285]=true,true
 for _,id in ipairs({78,284,285})do s.active=id;local selected,result=first(f.addon,s);assert(not selected and result.status=='stopped' and not result.suppressAttack)end
 s.active=78;s.mapped[284],s.mapped[285]=false,false;assert(not first(f.addon,s))
 s.active=nil;assert(first(f.addon,s)==78)
end)
test('naive highest-rank active predicate misses exact lower queued rank in allowed API model',function()
 local f,s=fixture();s.combat=true;s.known[284],s.known[285]=true,true;s.active=78
 assert(not f.addon:evaluateCondition({type='SPELL_ACTIVE',spell=78,ranked=false}))
 assert(f.addon:evaluateCondition({type='SPELL_ACTIVE',spell=78,ranked=true}));assert(not first(f.addon,s))
end)
test('pending state unknown halts lower advice and unlearned ranks are not queried',function()
 local f,s=fixture();s.combat=true;local queries={};local native=f.env.C_Spell.IsCurrentSpell
 f.env.C_Spell.IsCurrentSpell=function(id)queries[#queries+1]=id;return native(id)end
 s.activeError=true;local id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
 s.activeError=false;s.activeNil=true;id,result=first(f.addon,s);assert(not id and result.status=='unavailable')
 s.activeNil=false;queries={};assert(first(f.addon,s)==78);assert(#queries==1 and queries[1]==78)
end)
test('native learned mapped resource cooldown range and stance observations remain authoritative',function()
 local f,s=fixture();s.combat=true;s.known[284],s.known[285]=true,true;s.mapped[285]=false;assert(first(f.addon,s)==284)
 s.power[284]=true;assert(first(f.addon,s)==78);s.range[78]=false;assert(not first(f.addon,s));s.range[78]=nil
 s.cooldown[78]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(not first(f.addon,s))
 s.cooldown={};s.usable[78]=false;assert(not first(f.addon,s));s.usable={};s.knownError=true;assert(not first(f.addon,s))
end)
test('missing aura metadata does not fabricate missing Rend or Shout',function()
 local f,s=fixture();s.combat=true;s.known[772],s.known[6673]=true,true;s.auraError=true
 assert(first(f.addon,s)==78);assert(not optional(f,s));s.auraError=false;s.metadataMissing[772]=true
 s.debuffs={{spellId=17,name='foreign',sourceUnit='player'}};assert(first(f.addon,s)==78)
end)
test('hostile living combat boundary and explicit manual omissions',function()
 local f,s=fixture();s.combat=true;s.hostile=false;assert(not first(f.addon,s));s.hostile=true;s.dead=true;assert(not first(f.addon,s));s.dead=false;s.exists=false;assert(not first(f.addon,s))
 local actions={};for _,r in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do if r.step.action then actions[r.step.action]=true end end
 for _,id in ipairs({7384,100,2687,34428,355,72,1715,5308,12294})do assert(not actions[id])end
end)
test('scope explicit enable independent clones and profiles retain library authority',function()
 local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1];assert(row.validation.valid and row.validation.resolved and row.eligible)
 assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:ListDefaultRotations(0)[1].eligible);assert(a:SetDefaultRotationEnabled(row.id,true))
 local cloneID=assert(a:CloneDefaultRotation(0,row.id,'Warrior copy'));local clone=a:GetEditableRotation(0,cloneID);clone.rotation[1].onTrue[1].action=78;assert(body(a).rotation[1].onTrue[1].action==772)
 local p=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=p;assert(a:InitializeRotationLibrary());assert(a:GetEditableRotation(0,cloneID)==clone)
 s.level=20;assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotation(0,cloneID))
 for _,case in ipairs({{5,'MAGE'},{2,'WARRIOR'},{1,'WARRIOR'}})do local other=fixture(case[1],case[2]);local rows=other.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
end)
test('actual initialized main and buttons discover ranks and publish sequential and optional advice',function()
 local f,s,n=fixture();s.combat=true;s.known[284],s.known[285]=true,true;s.mapped[285]=false
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==284)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==284 then found=true end end;assert(found)
 s.known[772]=true;tick();assert(f.addon.currentSpell==772);rend(s,n);tick();assert(f.addon.currentSpell==284)
 s.known[6673]=true;tick();assert(f.addon.avail_announced['warrior-preview-battle-shout']==6673)
end)
test('actual main queued state cannot off-toggle and existing mapped melee fallback stays intact',function()
 local f,s=fixture();s.combat=true;s.active=78;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 s.active=6603;tick();assert(f.addon.currentSpell==78);s.power[78]=true;tick();assert(f.addon.currentSpell==nil)
 s.active=nil;tick();assert(f.addon.currentSpell==6603);s.beyond=true;tick();assert(f.addon.currentSpell==nil)
end)
test('current spell API has exact one-argument authority and selected modern failure never falls back',function()
 local f,s=fixture();s.combat=true;local e=f.env;local old=e.C_Spell.IsCurrentSpell;local calls,legacy=0,0
 e.IsCurrentSpell=function()legacy=legacy+1;return 1 end
 e.C_Spell.IsCurrentSpell=function(...)assert(select('#',...)==1 and (...)==78);calls=calls+1;return old(...)end
 assert(first(f.addon,s)==78 and calls==1 and legacy==0)
 e.C_Spell.IsCurrentSpell=function()error('selected API unavailable')end
 local id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and legacy==0)
end)
test('legacy current-spell zero one tuples preserve queued stop and no invented reactive utility',function()
 local f,s=fixture();s.combat=true;s.known[284]=true;f.env.C_Spell.IsCurrentSpell=nil
 f.env.IsCurrentSpell=function(id)return s.active==id and 1 or 0 end
 s.active=78;assert(not first(f.addon,s));s.active=nil;assert(first(f.addon,s)==284)
 s.known[7384]=true;s.usable[7384]=true;assert(first(f.addon,s)==284)
end)
test('actual bar fallback does not fabricate an unmapped Attack or consume unknown pending state',function()
 local f,s=fixture();s.combat=true;s.mapped[78],s.mapped[6603]=false,false
 local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==nil)
 s.mapped[6603]=nil;local selected=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=selected;s.activeError=true;tick();assert(f.addon.currentSpell==nil)
 s.activeError=false;tick();assert(f.addon.currentSpell==6603)
end)
finish()
