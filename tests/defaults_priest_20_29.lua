-- Actual-engine/publisher scenarios; native APIs and timer scheduling are modeled.
-- Optional first argument is an explicit policy-sensitivity source override; normal runs load the packaged continuation.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'PRIEST');local a,e=f.addon,f.env
    f.translations['Default.TBC.Priest.Continuation.Name']='TBC Priest 20–29 wand / learned Mind Flay preview';f.translations['Default.TBC.Priest.Continuation.Description']='Levels 20–29: optional learned Mind Flay above half health; choose wanding manually. Active channels and wand filler are preserved; healing and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=20,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[585]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[585]={585,591,598,984},[589]={589,594,970,992},[8092]={8092,8102,8103,8104},[588]={588,7128},[5019]={5019},[15407]={15407,17311}}
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
        SpellHasRange=function(id) return id~=588 and id~=7128 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    f.load(arg[1]or'Defaults/tbc/priest-20-29.lua')
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
local function pain(s,names,caster)s.debuffs={{spellId=970,name=names[970],sourceUnit=caster or 'player'}}end
local function optional(f,s)
 local a=f.addon;local step=body(a).cooldowns[1];local ready=a:NewActionReadiness(100)
 if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready('spell',id)then return id end end end
end
test('level and trainer state do not invent learned actions or later-rank families',function()
 local f,s,names=fixture();local a=f.addon;assert(first(a,s)==585);s.level=29;assert(first(a,s)==585)
 s.known[591],s.known[598]=true,true;assert(first(a,s)==598);s.mapped[598]=false;assert(first(a,s)==591);s.power[591]=true;assert(first(a,s)==585)
 s.known[589]=true;assert(first(a,s)==589);s.known[8092]=true;assert(first(a,s)==8092)
 s.combat=true;assert(first(a,s)==589);pain(s,names);s.known[5019]=true;assert(first(a,s)==5019)
end)
test('Mind Blast is only an out-of-combat stationary above-half-health opener',function()
 local f,s=fixture();s.known[8092]=true;assert(first(f.addon,s)==8092)
 s.targetHealth=50;assert(first(f.addon,s)==585);s.targetHealth=51;assert(first(f.addon,s)==8092)
 s.combat=true;assert(first(f.addon,s)==585);s.combat=false;s.moving=true;local id,result=first(f.addon,s);assert(not id and result.suppressAttack)
end)
test('native resource range cooldown and mapped actions retain final authority',function()
 local f,s,names=fixture();local a=f.addon;s.known[8092],s.known[589],s.known[5019]=true,true,true
 s.mapped[8092]=false;assert(first(a,s)==589);s.range[589]=false;assert(first(a,s)==5019);s.power[5019]=true;assert(first(a,s)==585)
 s.cooldown[585]={startTime=90,duration=30,isEnabled=true,modRate=1};local id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack)
end)
test('own localized higher-rank Pain respects other casters and the explicit half-health heuristic',function()
 local f,s,names=fixture();local a=f.addon;s.combat=true;s.known[589],s.known[970],s.known[5019]=true,true,true
 pain(s,names,'party1');assert(first(a,s)==970);pain(s,names);assert(first(a,s)==5019)
 s.debuffs={};s.targetHealth=50;assert(first(a,s)==5019);s.targetHealth=51;assert(first(a,s)==970)
end)
test('hostile combat motion and channel boundaries preserve manual party and defensive decisions',function()
 local f,s,names=fixture();local a=f.addon;s.known[589],s.known[8092]=true,true;s.targetCombat=true;assert(not first(a,s));s.combat=true;assert(first(a,s)==589)
 s.hostile=false;assert(not first(a,s));s.hostile=true;s.dead=true;assert(not first(a,s));s.dead=false;s.exists=false;assert(not first(a,s));s.exists=true
 s.moving=true;assert(first(a,s)==589);pain(s,names);local id,result=first(a,s);assert(not id and result.suppressAttack)
 s.moving=false;s.channel=true;id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack)
end)
test('known active wand is never advised as off-toggle and unknown repeat suppresses lower priorities',function()
 local f,s,names=fixture();local a=f.addon;s.combat=true;s.known[5019]=true;s.repeatActive=true
 local id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack)
 s.repeatActive=false;s.repeatError=true;id,result=first(a,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
 s.known[5019]=false;assert(first(a,s)==585)
end)
test('unavailable aura health metadata and learned observations do not manufacture positive Pain matches',function()
 local f,s,names=fixture();local a=f.addon;s.combat=true;s.known[589],s.known[5019]=true,true
 s.auraError=true;assert(first(a,s)==5019);s.auraError=false;s.healthError=true;assert(first(a,s)==5019)
 s.healthError=false;s.metadataMissing[589]=true;s.debuffs={{spellId=17,name='foreign aura',sourceUnit='player'}};assert(first(a,s)==5019)
 s.metadataMissing={};s.knownError=true;assert(not first(a,s))
end)
test('only self-only InnerFire optional reminder is authored and remains independent of damage',function()
 local f,s,names=fixture();local a=f.addon;assert(not optional(f,s));s.known[588]=true;assert(optional(f,s)==588 and first(a,s)==585)
 s.buffs={{spellId=588,name=names[588],sourceUnit='player'}};assert(not optional(f,s));s.buffs={};s.auraError=true;assert(not optional(f,s))
 local actions={};local index=assert(a.RotationData.IndexRotationSteps(body(a)));for _,entry in ipairs(index.rows)do if entry.step.action then actions[entry.step.action]=true end end
 for _,manual in ipairs({1243,17,139,2050,586,605})do assert(not actions[manual])end
end)
test('source scope enable state profiles and clones remain explicit and independent',function()
 local f,s=fixture();local a=f.addon;local r=a:ListDefaultRotations(0)[1];assert(r.id=='rm.tbc.priest.starter.20-29'and r.readOnly and r.validation.valid and r.validation.resolved)
 assert(a:SetDefaultRotationEnabled(r.id,false));assert(not a:ListDefaultRotations(0)[1].enabled);assert(a:SetDefaultRotationEnabled(r.id,true))
 local id=assert(a:CloneDefaultRotation(0,r.id,'Priest copy'));local clone=a:GetEditableRotation(0,id);clone.rotation[1].onTrue[1].suppress_attack=false;assert(body(a).rotation[1].onTrue[1].suppress_attack)
 local old=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());local current=a:ListDefaultRotations(0)[1];assert(current.enabled);a.db.profile=old;assert(a:InitializeRotationLibrary());assert(a:GetEditableRotation(0,id)==clone)
 s.level=30;assert(not a:ListDefaultRotations(0)[1].eligible);assert(not a:evaluateCondition(a:ListDefaultRotations(0)[1].envelope.body.switch))
end)
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
 local actions={585,591,598,589,594,970,8092,8102,588,5019,15407,17311};local buttons={}
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

test('actual native action bars select mapped learned ranks and publish the Priest priority',function()
 local f,s=fixture();s.known[591],s.known[598]=true,true;s.mapped[598]=false
 local tick,glow,messages=nativePublish(f,s);assert(f.addon:FindSpell({598,591,585})==591)
 tick();assert(f.addon.currentSpell==591,'unmapped higher rank escaped native action discovery')
 local announced=false;for _,call in ipairs(messages)do if call[1]=='ROTATIONMASTER_SPELL_UPDATE'and call[6]==591 then announced=true end end
 assert(announced,'main publication omitted the mapped learned rank')
 s.known[8092]=true;tick();assert(f.addon.currentSpell==8092,'opening priority did not reach native publication')
 s.combat=true;s.known[589]=true;tick();assert(f.addon.currentSpell==589,'combat entered opener-only Mind Blast')
end)
test('no native mapped ranged action yields suppress-Attack rather than invented melee advice',function()
 local f,s=fixture();s.known[5019]=true;s.mapped[585],s.mapped[5019]=false,false
 local tick,glow,messages=nativePublish(f,s);assert(f.addon:FindSpell({585,5019})==nil);tick();assert(f.addon.currentSpell==nil)
 for _,call in ipairs(messages)do assert(call[1]~='ROTATIONMASTER_SPELL_UPDATE'or call[6]==nil,'unmapped spell was published')end
 s.known[588]=true;tick();assert(f.addon.avail_announced['priest-starter-inner-fire']==588,'independent optional reminder missing')
end)
test('legacy spell APIs preserve localized learned metadata and native action authority',function()
 local f,s,names=fixture();local e=f.env;local api=e.C_Spell;e.C_Spell=nil
 e.GetSpellInfo=function(id)local v=api.GetSpellInfo(id);if v then return v.name,v.subtext,nil,0,0,30,id end end
 e.SpellHasRange=function(slot,bank)assert(bank=='spell');return api.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,bank,unit)assert(bank=='spell');return api.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.IsUsableSpell=api.IsSpellUsable;e.GetSpellCooldown=function(id)local v=api.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 or nil end
 e.IsAutoRepeatSpell=function(slot,bank)assert(slot==6019 and bank=='spell');return api.IsAutoRepeatSpell(5019)end;s.combat=true;s.known[594],s.known[589]=true,true;assert(first(f.addon,s)==594)
 pain(s,names);s.known[5019]=true;assert(first(f.addon,s)==5019);s.repeatActive=true;local id,result=first(f.addon,s);assert(not id and result.suppressAttack)
 s.repeatActive=false;s.known[15407],s.known[17311]=true,true;assert(first(f.addon,s)==17311);s.power[17311]=true;s.power[15407]=true;assert(first(f.addon,s)==5019)
end)
test('foreign class edition vehicle petbattle and disabled packaged preferences cannot execute',function()
 for _,case in ipairs({{'class',5,'MAGE'},{'edition',2,'PRIEST'},{'restricted',1,'PRIEST'},{'vehicle',5,'PRIEST'},{'petbattle',5,'PRIEST'}})do
  local f,s=fixture(case[2],case[3]);if case[1]=='vehicle'then f.env.UnitHasVehicleUI=function()return true end elseif case[1]=='petbattle'then f.env.C_PetBattles={IsInBattle=function()return true end}end
  local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible,case[1]..' escaped packaged scope')
 end
 local f=fixture();local a=f.addon;local id='rm.tbc.priest.starter.20-29';local key=a:ListDefaultRotations(0)[1].runtimeKey;assert(a:SetDefaultRotationEnabled(id,false));assert(not a:ListDefaultRotations(0)[1].eligible)
 assert(a:GetRuntimeRotation(0,key)==nil);assert(a:SetDefaultRotationEnabled(id,true));assert(a:ListDefaultRotations(0)[1].eligible)
end)
test('cloned Priest data remains independently editable and comparison detects only explicit local edits',function()
 local f,s=fixture();local a=f.addon;local id=assert(a:CloneDefaultRotation(0,'rm.tbc.priest.starter.20-29','Priest copy'))
 local clone=a:GetEditableRotation(0,id);local old=a:CopySettingsData(clone);clone.rotation[1].onTrue[2].action=585
 assert(body(a).rotation[1].onTrue[2].action==8092,'editing clone rewrote packaged data')
 local diff=assert(a:BuildRotationComparison(0,id,{kind='builtin',id='rm.tbc.priest.starter.20-29'}));assert(diff.valid and diff.complete)
 local profile=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());a.db.profile=profile;assert(a:InitializeRotationLibrary())
 assert(a:GetEditableRotation(0,id)==clone and not a:SettingsDataEqual(old,clone),'profile reload rewrote saved local changes')
 assert(a:GetRuntimeRotation(0,id),'eligible cloned source did not execute');s.level=30;assert(not a:GetRuntimeRotation(0,id),'clone lost source scope')
end)


local function entered(s,names)s.combat=true;s.known[589]=true;pain(s,names)end
test('20through29 learns no Flay from a level threshold while learned Flay changes filler at any valid level',function()
 local f,s,n=fixture();entered(s,n);s.known[5019]=true;s.known[17311]=true;assert(first(f.addon,s)==5019,'exact base learned guard must not infer native rank knowledge');s.known[17311]=false
 for _,level in ipairs({20,24,25,28,29})do s.level=level;assert(first(f.addon,s)==5019);s.known[15407]=true;assert(first(f.addon,s)==15407,'learned Flay missing');s.known[15407]=false end
end)
test('Flay uses native ranked readiness and inherited health movement fallback without hard mana or range threshold',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[17311],s.known[5019]=true,true,true;assert(first(f.addon,s)==17311)
 s.mapped[17311]=false;assert(first(f.addon,s)==15407);s.power[15407]=true;assert(first(f.addon,s)==5019);s.power[15407]=nil;s.range[15407]=false;assert(first(f.addon,s)==5019);s.range[15407]=true
 s.cooldown[15407]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(f.addon,s)==5019);s.cooldown={};s.targetHealth=50;assert(first(f.addon,s)==5019);s.targetHealth=51;assert(first(f.addon,s)==15407)
 s.moving=true;local id,r=first(f.addon,s);assert(not id and r.suppressAttack);s.moving=false;s.healthError=true;assert(first(f.addon,s)==5019)
end)
test('new normal ranks are recognized only from actual learned metadata and family mapping',function()
 local f,s,n=fixture();s.level=29;assert(first(f.addon,s)==585);s.known[984]=true;assert(first(f.addon,s)==984);s.known[8092],s.known[8103],s.known[8104]=true,true,true;assert(first(f.addon,s)==8104);s.mapped[8104]=false;assert(first(f.addon,s)==8103)
 s.combat=true;s.known[589],s.known[992]=true,true;assert(first(f.addon,s)==992);pain(s,n);s.known[15407]=true;assert(first(f.addon,s)==(15407))
 s.known[588],s.known[7128]=true,true;assert(optional(f,s)==7128);s.buffs={{spellId=7128,name=n[588],sourceUnit='player'}};assert(not optional(f,s))
end)
test('learned active wand precedes new Flay filler while prior Pain priority remains explicit',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true;s.repeatActive=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)
 s.repeatActive=false;s.repeatError=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack);s.repeatError=false;s.known[5019]=false;assert(first(f.addon,s)==15407)
 s.known[5019]=true;s.repeatActive=true;s.debuffs={};assert(first(f.addon,s)==589,'inherited higher Pain priority changed')
end)
test('channel and learned Flay unknown observations refuse filler and suppress implicit Attack',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[5019]=true,true
 for _,key in ipairs({'channelError','flayKnownError','flayKnownNil'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack,key);s[key]=false end
 s.channel=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack);s.channel=false
 local opaque={};s.channelOpaque=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('real action bars and main publish mapped Flay ranks then clear for channel wand and unknown facts',function()
 local f,s,n=fixture();entered(s,n);s.known[15407],s.known[17311],s.known[5019]=true,true,true;s.mapped[17311]=false
 local tick,glow,messages=nativePublish(f,s);assert(f.addon:FindSpell({17311,15407})==15407);tick();assert(f.addon.currentSpell==15407)
 s.channel=true;tick();assert(not f.addon.currentSpell);s.channel=false;tick();assert(f.addon.currentSpell==15407,'repeated Flay preview policy changed');s.targetHealth=50;tick();assert(f.addon.currentSpell==5019);s.repeatActive=true;tick();assert(not f.addon.currentSpell)
 s.repeatActive=false;s.targetHealth=100;s.mapped[17311]=true;f.addon:Fetch();tick();assert(f.addon.currentSpell==17311)
 s.range[15407],s.range[17311]=false,false;tick();assert(f.addon.currentSpell==5019);s.range[15407],s.range[17311]=true,true;tick();assert(f.addon.currentSpell==17311)
 for _,key in ipairs({'channelError','repeatError','flayKnownError'})do s[key]=true;tick();assert(not f.addon.currentSpell,key);s[key]=false;tick();assert(f.addon.currentSpell==17311)end
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]then seen[m[6]]=true end end;assert(seen[15407]and seen[17311]and seen[5019])
end)
test('continuation bounds20through29 exclude19 and30 without changing existing manual responsibilities',function()
 for _,level in ipairs({20,29,19,30})do
  local f,s=fixture();s.level=level;local row=f.addon:ListDefaultRotations(0)[1];local expected=level>=20 and level<30
  assert(row.eligible==expected);assert(f.addon:evaluateCondition(row.envelope.body.switch)==expected)
 end
 local f,s=fixture();local allowed={[585]=true,[589]=true,[8092]=true,[588]=true,[5019]=true,[15407]=true};local index=assert(f.addon.RotationData.IndexRotationSteps(body(f.addon)));for _,r in ipairs(index.rows)do if r.step.action then assert(allowed[r.step.action])end end
end)
local function enteredReady()
 local f,s,n=fixture();entered(s,n);s.known[5019],s.known[15407]=true,true;return f,s,n
end
test('separate Priest packs select exactly one eligible scope at19 20 29 and30',function()
 for _,level in ipairs({19,20,29,30})do
  local f,s=fixture();s.level=level;f.load('Defaults/tbc/priest-starter.lua');local eligible={}
  for _,row in ipairs(f.addon:ListDefaultRotations(0))do if row.eligible then eligible[#eligible+1]=row.id end end
  assert(#eligible==(level==30 and 0 or 1))
  if level==19 then assert(eligible[1]=='rm.tbc.priest.starter')elseif level<30 then assert(eligible[1]=='rm.tbc.priest.starter.20-29')end
 end
end)
test('any localized manual channel suppresses damage without requiring Flay identity',function()
 local f,s=enteredReady();f.env.UnitChannelInfo=function(...)assert(select('#',...)==1 and(...)=='player');return 'Other localized channel'end
 local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)
end)
test('generic channel preserves active observation without reading unused restricted timing fields',function()
 local f,s=enteredReady();local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
 f.env.UnitChannelInfo=function()return 'Other channel',nil,nil,nil,opaque,nil,opaque end
 local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack)
end)
test('modern exact learned player bank governs Flay and selected errors refuse legacy rescue',function()
 local f,s=enteredReady();f.env.Enum={SpellBookSpellBank={Player=73,Pet=74}};local legacy=0
 f.env.IsSpellKnown=function()legacy=legacy+1;return true end
 f.env.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local spell,bank=...;assert(bank==73);return s.known[spell]==true end}
 assert(first(f.addon,s)==15407 and legacy==0)
 f.env.C_SpellBook.IsSpellKnown=function(spell,bank)assert(bank==73);if spell==15407 then error('modern unknown')end;return s.known[spell]==true end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack and legacy==0)
end)
test('unknown exact Flay knowledge vetoes filler even below the half-health preference',function()
 local f,s=enteredReady();s.targetHealth=50;s.flayKnownNil=true
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
finish()
