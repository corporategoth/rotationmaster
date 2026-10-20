-- Actual Warrior pack scenarios; native APIs are modeled, runtime/publication are real.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'WARRIOR');local a,e=f.addon,f.env
    f.translations['Default.TBC.Warrior.Continuation.Name']='TBC Warrior continuation preview';f.translations['Default.TBC.Warrior.Continuation.Description']='Bounded Warrior20–29 preview; reactive abilities, stance and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=20,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[78]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[78]={78,284,285,1608},[772]={772,6546,6547},[6673]={6673,5242,6192},[6603]={6603},[7384]={7384,7887},[5308]={5308}}
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
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;if s.activeNil then return nil end;return s.active==id end,SpellHasRange=function(id) return id~=6673 and id~=5242 and id~=6192 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open('Defaults/tbc/warrior-20-29.lua');if pack then pack:close();f.load('Defaults/tbc/warrior-20-29.lua')end
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
    local row=a:ListDefaultRotations(0)[1];assert(row,'missing Warrior20–29 preview');assert(row.eligible,row.eligibilityReason);return row.envelope.body
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
 local actions={78,284,285,1608,772,6546,6547,6673,5242,6192,6603,7384,7887,5308};local buttons={}
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

test('combat gate and no Rend maintenance beyond nineteen',function()
 local f,s=fixture();assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==78)
 s.known[284],s.known[285],s.known[1608]=true,true,true;assert(first(f.addon,s)==1608)
 s.known[772],s.known[6546],s.known[6547]=true,true,true;assert(first(f.addon,s)==1608)
end)
test('learned usable Overpower remains manual and levels do not grant spells',function()
 local f,s=fixture();s.combat=true;assert(first(f.addon,s)==78)
 s.known[7384]=true;assert(first(f.addon,s)==78);s.known[7887]=true;assert(first(f.addon,s)==78)
 s.usable[7887],s.usable[7384]=false,false;assert(first(f.addon,s)==78)
 s.level=29;s.known[7384],s.known[7887]=false,false;assert(first(f.addon,s)==78)
end)
test('learned Execute strict below-twenty threshold and unknown health',function()
 local f,s=fixture();s.combat=true;s.targetHealth=19;assert(first(f.addon,s)==78)
 s.known[5308]=true;assert(first(f.addon,s)==5308);s.targetHealth=20;assert(first(f.addon,s)==78)
 s.targetHealth=19.999;assert(first(f.addon,s)==5308);s.healthError=true;assert(first(f.addon,s)==78)
end)
test('native power cooldown range and modeled stance refusal allow independent fallback',function()
 local f,s=fixture();s.combat=true;s.targetHealth=10;s.known[7384],s.known[5308]=true,true
 s.usable[7384]=false;assert(first(f.addon,s)==5308);s.power[5308]=true;assert(first(f.addon,s)==78)
 s.power[5308]=false;s.range[5308]=false;assert(first(f.addon,s)==78);s.range[5308]=true
 s.cooldown[5308]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(f.addon,s)==78)
 s.cooldown={};s.mapped[5308]=false;assert(first(f.addon,s)==78)
end)
test('four exact queued HS ranks stop repeated queue advice',function()
 local f,s=fixture();s.combat=true;s.known[284],s.known[285],s.known[1608]=true,true,true
 for _,id in ipairs({78,284,285,1608})do s.active=id;local selected,r=first(f.addon,s);assert(not selected and r.status=='stopped'and not r.suppressAttack)end
 s.active=1608;s.mapped[1608]=false;assert(not first(f.addon,s));s.active=nil;assert(first(f.addon,s)==285)
end)
test('unknown queue state suppresses fallback and unlearned ranks are not queried',function()
 local f,s=fixture();s.combat=true;local ids={};local old=f.env.C_Spell.IsCurrentSpell
 f.env.C_Spell.IsCurrentSpell=function(id)ids[#ids+1]=id;return old(id)end
 assert(first(f.addon,s)==78 and #ids==1 and ids[1]==78)
 s.activeError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.activeError=false;s.activeNil=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable')
end)
test('queue guards do not cancel higher-priority ready direct attacks',function()
 local f,s=fixture();s.combat=true;s.active=78;s.known[5308]=true;s.targetHealth=10;assert(first(f.addon,s)==5308)
 s.known[7384]=true;assert(first(f.addon,s)==5308);s.usable[7384],s.usable[5308]=false,false;assert(not first(f.addon,s))
end)
test('localized Shout rank three is independent optional upkeep',function()
 local f,s,n=fixture();s.combat=true;s.known[6673],s.known[5242],s.known[6192]=true,true,true;assert(optional(f,s)==6192)
 s.buffs={{spellId=6192,name=n[6192],sourceUnit='party1'}};assert(not optional(f,s));s.buffs={};s.auraError=true;assert(not optional(f,s));assert(first(f.addon,s)==78)
end)
test('hostile living target gate and manual omissions remain explicit',function()
 local f,s=fixture();s.combat=true;s.hostile=false;assert(not first(f.addon,s));s.hostile=true;s.dead=true;assert(not first(f.addon,s));s.dead=false;s.exists=false;assert(not first(f.addon,s))
 local ids={};for _,r in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do if r.step.action then ids[r.step.action]=true end end
 for _,id in ipairs({772,100,2687,34428,355,72,1715,845,20230,2458,12294})do assert(not ids[id])end
end)
test('scope explicit enable profile and independent clone authority',function()
 local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1];assert(row.validation.valid and row.validation.resolved and row.eligible)
 assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:ListDefaultRotations(0)[1].eligible);assert(a:SetDefaultRotationEnabled(row.id,true))
 local id=assert(a:CloneDefaultRotation(0,row.id,'Copy'));local copy=a:GetEditableRotation(0,id);local original=body(a).rotation[1].onTrue[1].action;copy.rotation[1].onTrue[1].action=999;assert(body(a).rotation[1].onTrue[1].action==original)
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary());assert(a:GetEditableRotation(0,id)==copy)
 for _,case in ipairs({{19,false},{20,true},{29,true},{30,false}})do s.level=case[1];assert(a:ListDefaultRotations(0)[1].eligible==case[2])end
 for _,case in ipairs({{5,'MAGE'},{2,'WARRIOR'},{1,'WARRIOR'}})do local other=fixture(case[1],case[2]);local rows=other.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
end)
test('old and new packs are nonoverlapping without modifying old registration',function()
 local f,s=fixture();f.load('Defaults/tbc/warrior-starter.lua');assert(f.addon:InitializeRotationLibrary())
 for _,level in ipairs({19,20,29,30})do s.level=level;local rows=f.addon:ListDefaultRotations(0);assert(#rows==2);local eligible={};for _,r in ipairs(rows)do if r.eligible then eligible[r.id]=true end end
 assert((eligible['rm.tbc.warrior.starter']==true)==(level==19));assert((eligible['rm.tbc.warrior.starter.20-29']==true)==(level==20 or level==29))end
end)
test('actual main and buttons publish HS rank four direct attacks and optional Shout',function()
 local f,s=fixture();s.combat=true;s.known[284],s.known[285],s.known[1608]=true,true,true
 local tick,glow,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==1608)
 local found=false;for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]==1608 then found=true end end;assert(found)
 s.known[5308]=true;s.targetHealth=10;tick();assert(f.addon.currentSpell==5308,'expected Execute, got '..tostring(f.addon.currentSpell)..' condition '..tostring(f.addon:evaluateCondition({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})));s.known[7384]=true;tick();assert(f.addon.currentSpell==5308)
 s.known[6673],s.known[5242],s.known[6192]=true,true,true;tick();assert(f.addon.avail_announced['warrior-continuation-battle-shout']==6192)
end)
test('actual current HS cannot off-toggle and unknown queue suppresses implicit Attack',function()
 local f,s=fixture();s.combat=true;s.known[1608]=true;s.active=1608;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 s.activeError=true;tick();assert(f.addon.currentSpell==nil);s.activeError=false;s.active=nil;tick();assert(f.addon.currentSpell==1608)
 s.power[78],s.power[1608]=true,true;tick();assert(f.addon.currentSpell==6603);s.beyond=true;tick();assert(f.addon.currentSpell==nil)
end)
test('actual bar refresh observes mapping and recovering usability',function()
 local f,s=fixture();s.combat=true;s.known[5308]=true;s.targetHealth=10;s.mapped[5308]=false;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==78)
 s.mapped[5308]=true;local key=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=key;tick();assert(f.addon.currentSpell==5308,'expected Execute, got '..tostring(f.addon.currentSpell)..' condition '..tostring(f.addon:evaluateCondition({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.2})))
 s.usable[5308]=false;tick();assert(f.addon.currentSpell==78)
end)
test('modern exact current arity and selected failure have no legacy fallback',function()
 local f,s=fixture();s.combat=true;local old=f.env.C_Spell.IsCurrentSpell;local calls,legacy=0,0
 f.env.IsCurrentSpell=function()legacy=legacy+1;return 1 end;f.env.C_Spell.IsCurrentSpell=function(...)assert(select('#',...)==1 and (...)==78);calls=calls+1;return old(...)end
 assert(first(f.addon,s)==78 and calls==1 and legacy==0);f.env.C_Spell.IsCurrentSpell=function()error('selected unavailable')end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and legacy==0)
end)
test('legacy zero one current tuple retains rank four queue stop',function()
 local f,s=fixture();s.combat=true;s.known[1608]=true;f.env.C_Spell.IsCurrentSpell=nil
 f.env.IsCurrentSpell=function(...)assert(select('#',...)==1);return s.active==(...)and 1 or 0 end;s.active=1608;assert(not first(f.addon,s));s.active=nil;assert(first(f.addon,s)==1608)
end)
test('unknown usability does not manufacture reactive or Execute availability',function()
 local f,s=fixture();s.combat=true;s.known[7384],s.known[5308]=true,true;s.targetHealth=10
 f.env.C_Spell.IsSpellUsable=function(id)if id==7384 or id==5308 then return nil,nil end;return true,false end;assert(first(f.addon,s)==78)
end)
finish()
