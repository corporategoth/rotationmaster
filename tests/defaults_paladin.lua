-- Actual Paladin pack scenarios; native observations modeled, execution/publication real.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'PALADIN');local a,e=f.addon,f.env
    f.translations['Default.TBC.Paladin.Starter.Name']='TBC Paladin upkeep/melee preview';f.translations['Default.TBC.Paladin.Starter.Description']='Bounded solo preview; heals, party support and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=1,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[465]=true,[21084]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[465]={465,10290},[7294]={7294},[21084]={21084,20287,20288},[21082]={21082,20162},[6603]={6603},[20271]={20271},[19740]={19740,19834},[20154]={20154}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    names[20154]=names[21084];ranks[20154]='Rank 1'
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;return s.active==id end,SpellHasRange=function(id) return id==19740 or id==19834 or id==20271 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    f.load('Defaults/tbc/paladin-starter.lua')
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
local function available(f,s)
 local a=f.addon;local ready=a:NewActionReadiness(100);local rows={}
 for _,step in ipairs(body(a).cooldowns)do if a:evaluateCondition(step.conditions)then
  for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready('spell',id)then rows[#rows+1]=id;break end end
 end end
 return rows
end
local function contains(t,id)for _,x in ipairs(t)do if x==id then return true end end;return false end
local function buff(s,n,id,source)s.buffs[#s.buffs+1]={spellId=id,name=n[id],sourceUnit=source or 'player'}end
local function nativePublish(f,s)
 local a,e=f.addon,f.env;local glow,messages={},{}
 -- Real initialization establishes main's captured canonical cache helper.
 -- AceDB uses the native frame/event boundary; no production helper is replaced.
 e.OFF='Off';e.securecallfunction=function(fn,...)return fn(...)end
 e.UnitFactionGroup=function()return 'Horde'end;e.GetLocale=function()return 'enUS'end
 e.UnitRace=function()return 'Blood Elf','BloodElf'end;e.GetRealmName=function()return 'Paladin Realm'end
 e.UnitNameUnmodified=function()return 'Paladin Character'end;e.GetCurrentRegionName=function()return 'US'end;e.GetCurrentRegion=function()return 1 end
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
 local actions={465,10290,7294,21084,20154,20287,20288,21082,20162,20271,6603};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-paladin'or'Creature-paladin'end
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

test('upkeep ranks require actual learning and mapped native readiness',function()
 local f,s=fixture();local r=available(f,s);assert(contains(r,465)and contains(r,21084))
 s.known[10290],s.known[20288]=true,true;r=available(f,s);assert(contains(r,10290)and contains(r,20288))
 s.mapped[20288]=false;assert(contains(available(f,s),21084));s.power[21084]=true;assert(not contains(available(f,s),21084))
 s.known={};assert(#available(f,s)==0)
end)
test('preserve own active Devotion or Retribution rather than toggling an aura or declaring an upgrade',function()
 local f,s,n=fixture();s.known[7294]=true;buff(s,n,7294);assert(not contains(available(f,s),465))
 s.known[7294]=false;assert(not contains(available(f,s),465))
 s.buffs={};buff(s,n,10290);assert(not contains(available(f,s),465))
 s.buffs={};buff(s,n,7294,'party1');assert(contains(available(f,s),465))
end)
test('active localized higher Righteousness or manually selected Crusader prevents replacement',function()
 local f,s,n=fixture();buff(s,n,20288);assert(not contains(available(f,s),21084))
 s.buffs={};buff(s,n,20162);assert(not contains(available(f,s),21084))
 s.known[21082],s.known[20162]=false,false;assert(not contains(available(f,s),21084))
 s.buffs={};buff(s,n,20154);assert(not contains(available(f,s),21084))
end)
test('unknown aura or required family metadata never manufactures missing upkeep',function()
 local f,s,n=fixture();s.auraError=true;assert(#available(f,s)==0);s.auraError=false
 buff(s,n,7294);s.metadataMissing[21082]=true;assert(not contains(available(f,s),21084))
 s.metadataMissing={};assert(contains(available(f,s),21084))
end)
test('normal family lookup handles alternate learned Righteousness identity without a new alias map',function()
 local f,s=fixture();s.known[21084]=false;s.known[20154]=true;assert(contains(available(f,s),20154))
 s.mapped[20154]=false;assert(not contains(available(f,s),20154))
end)
test('actual publisher retains independent optional reminders and normal melee fallback',function()
 local f,s=fixture();s.combat=true;local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 assert(f.addon.avail_announced['paladin-preview-devotion']==465 and f.addon.avail_announced['paladin-preview-righteousness']==21084)
 s.active=6603;tick();assert(f.addon.currentSpell==nil)
 s.active=nil;s.beyond=true;tick();assert(f.addon.currentSpell==nil)
end)
test('friendly dead absent or noncombat target never becomes a melee pull',function()
 for _,key in ipairs({'hostile','exists','combat'})do local f,s=fixture();s.combat=true;s[key]=false;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==nil,key)end
 local f,s=fixture();s.combat=true;s.dead=true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==nil)
end)
test('manual blessings retain actual target range limitations rather than fabricated self cast',function()
 local f,s=fixture();s.known[19740]=true;local e=f.env;local calls=0
 e.C_Spell.IsSpellInRange=function(id,unit)assert(id==19740 and unit=='target');calls=calls+1;return nil end
 assert(not f.addon:NewActionReadiness(100)('spell',19740)and calls==1)
 e.C_Spell.IsSpellInRange=function()return true end;assert(f.addon:NewActionReadiness(100)('spell',19740))
 for _,row in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do assert(row.step.action~=19740)end
end)
test('profile preferences clones edition class and level scope remain explicit',function()
 local f,s=fixture();local a=f.addon;local r=a:ListDefaultRotations(0)[1];assert(r.eligible and r.validation.valid and r.validation.resolved)
 assert(a:SetDefaultRotationEnabled(r.id,false));assert(not a:ListDefaultRotations(0)[1].eligible);assert(a:SetDefaultRotationEnabled(r.id,true))
 local id=assert(a:CloneDefaultRotation(0,r.id,'Paladin copy'));local clone=a:GetEditableRotation(0,id);clone.cooldowns[1].action=7294;assert(body(a).cooldowns[1].action==465)
 local old=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=old;assert(a:InitializeRotationLibrary());assert(a:GetEditableRotation(0,id)==clone)
 s.level=20;assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotation(0,id))
 for _,case in ipairs({{5,'PRIEST'},{2,'PALADIN'},{1,'PALADIN'}})do local other=fixture(case[1],case[2]);local rows=other.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
end)
test('only an active readable Righteousness seal enables ordinary Judgement publication',function()
 local f,s,n=fixture();s.combat=true;s.known[20271]=true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 buff(s,n,20288);tick();assert(f.addon.currentSpell==20271)
 buff(s,n,20162);tick();assert(f.addon.currentSpell==6603,'overlapping manual Crusader preparation was judged')
 s.buffs={};buff(s,n,20162);tick();assert(f.addon.currentSpell==6603,'manual Crusader preparation was judged')
 s.buffs={};buff(s,n,20288);s.auraError=true;tick();assert(f.addon.currentSpell==6603)
end)
test('Judgement still requires native learned range cost cooldown and actual mapped bar authority',function()
 local f,s,n=fixture();s.combat=true;buff(s,n,20288);s.known[20271]=true;s.mapped[20271]=false
 local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 local rot=f.addon.currentRotation;f.addon.currentRotation=nil;s.mapped[20271]=nil;f.addon:Fetch();f.addon.currentRotation=rot;tick();assert(f.addon.currentSpell==20271)
 s.power[20271]=true;tick();assert(f.addon.currentSpell==6603);s.power[20271]=nil;s.range[20271]=false;tick();assert(f.addon.currentSpell==6603)
 s.range[20271]=nil;s.cooldown[20271]={startTime=99,duration=10,isEnabled=true,modRate=1};tick();assert(f.addon.currentSpell==6603)
 s.cooldown={};s.known[20271]=false;tick();assert(f.addon.currentSpell==6603)
end)
test('consumed seal observation remains fresh and lower ordinary melee survives Judgement unknowns',function()
 local f,s,n=fixture();s.combat=true;s.known[20271]=true;buff(s,n,20288);local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 s.buffs={};tick();assert(f.addon.currentSpell==6603 and f.addon.avail_announced['paladin-preview-righteousness']==21084)
 buff(s,n,20288);f.env.C_Spell.IsSpellInRange=function(id,unit)assert(unit=='target');if id==20271 then return nil end;return true end
 tick();assert(f.addon.currentSpell==6603)
end)
test('missing or unavailable self-effect range shape never fabricates self-cast and recovers next observation',function()
 local f,s=fixture();local api=f.env.C_Spell;local shape,range=api.SpellHasRange,api.IsSpellInRange
 api.SpellHasRange=nil;api.IsSpellInRange=nil;assert(#available(f,s)==0)
 api.IsSpellInRange=range;local legacy,rangeCalls=0,0;f.env.SpellHasRange=function()legacy=legacy+1;return false end
 api.IsSpellInRange=function(...)rangeCalls=rangeCalls+1;return range(...)end
 api.SpellHasRange=function()return nil end;assert(#available(f,s)==0 and legacy==0 and rangeCalls==0)
 api.SpellHasRange=function()error('shape unavailable')end;assert(#available(f,s)==0 and legacy==0)
 api.SpellHasRange=shape;local ready=available(f,s);assert(contains(ready,465)and contains(ready,21084)and rangeCalls==0)
end)
test('applicable self-effect range stays bound to actual target rather than an invented self recipient',function()
 local f,s=fixture();local e=f.env;local calls=0
 e.C_Spell.SpellHasRange=function()return true end
 e.C_Spell.IsSpellInRange=function(id,unit)assert((id==465 or id==21084)and unit=='target');calls=calls+1;return nil end
 assert(#available(f,s)==0 and calls==2)
 e.C_Spell.IsSpellInRange=function(_,unit)assert(unit=='target');return false end;assert(#available(f,s)==0)
 e.C_Spell.IsSpellInRange=function(_,unit)assert(unit=='target');return true end;assert(#available(f,s)==2)
end)
test('legacy localized metadata and aura tuples preserve learned families seal choice and Judgement',function()
 local f,s,n=fixture();local e=f.env;local modern=e.C_Spell;local aura=e.C_UnitAuras.GetAuraDataByIndex;local unused={}
 for id,name in pairs(n)do n[id]='Éclat '..name end
 e.C_Spell=nil;e.C_UnitAuras=nil
 e.GetSpellInfo=function(id)local v=modern.GetSpellInfo(id);if v then return v.name,v.subtext,123,0,0,0,id,123,unused end end
 e.IsUsableSpell=modern.IsSpellUsable;e.IsCurrentSpell=function(id)return modern.IsCurrentSpell(id)and 1 or 0 end
 e.GetSpellCooldown=function(id)local v=modern.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate,unused end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 end
 e.SpellHasRange=function(slot,book)assert(book=='spell');return modern.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,book,unit)assert(book=='spell'and unit=='target');return modern.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.UnitAura=function(unit,index,filter)local v=aura(unit,index,filter);if v then return v.name,unused,0,nil,nil,nil,v.sourceUnit,nil,unused,v.spellId,unused end end
 for id in pairs(n)do assert(f.addon.SpellCatalog:UpdateSpell(id))end
 s.known[10290],s.known[20288]=true,true;local ready=available(f,s);assert(contains(ready,10290)and contains(ready,20288))
 s.combat=true;s.known[20271]=true;buff(s,n,20154);assert(first(f.addon,s)==20271)
 local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 buff(s,n,20162);assert(not first(f.addon,s)and not contains(available(f,s),21084));tick();assert(f.addon.currentSpell==6603)
end)
finish()
