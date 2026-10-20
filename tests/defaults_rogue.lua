-- Bounded Rogue starter: actual engine and modeled native APIs.
-- Argument1 optionally selects a different source for behavioral RED verification.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'ROGUE');local a,e=f.addon,f.env
    f.translations['Default.TBC.Rogue.Starter.Name']='TBC Rogue early leveling preview';f.translations['Default.TBC.Rogue.Starter.Description']='Bounded solo preview; openers, utility and resource planning remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=1,combat=true,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[1752]=true,[2098]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,cast=false,stealth=false,repeatActive=false,mapped={},power={},metadataMissing={},points=0,targetPoints=0,energy=100,pointCalls=0,comboCalls=0}
    local families={[1752]={1752,1757,1758},[2098]={2098,6760,6761},[5171]={5171},[6603]={6603}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.Enum.PowerType.ComboPoints=4
    e.UnitPower=function(unit,kind)assert(unit=='player'and kind==4);s.pointCalls=s.pointCalls+1;if s.pointError then error('point unavailable')end;if s.pointNil then return nil end;return s.points end
    e.UnitPowerMax=function(unit,kind)assert(unit=='player'and kind==4);return 5 end
    e.GetComboPoints=function(unit,target)assert(unit=='player'and target=='target');s.comboCalls=s.comboCalls+1;if s.pointError then error('point unavailable')end;if s.pointNil then return nil end;return s.points end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.IsStealthed=function()if s.stealthError then error('unavailable')end;if s.stealthNil then return nil end;return s.stealth end
    e.UnitCastingInfo=function()if s.castError then error('unavailable')end;if s.cast then return 'Cast in progress' end end
    e.UnitChannelInfo=function()if s.channelError then error('unavailable')end;if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;if s.activeNil then return nil end;return s.active==id end,SpellHasRange=function(id)return id~=5171 end,IsSpellInRange=function(id,unit)assert(unit=='target');if s.rangeError then error('range unavailable')end;return s.range[id]~=false end,
        IsSpellUsable=function(id)local costs={[1752]=45,[1757]=45,[1758]=45,[2098]=35,[6760]=35,[6761]=35,[5171]=25};local lack=s.power[id]==true or s.energy<(s.costOverride or costs[id]or 0);return s.usable[id]~=false and not lack,lack end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/range.lua'}) do f.load(path) end
    f.load(arg[1] or 'Defaults/tbc/rogue-starter.lua')
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
 local actions={1752,1757,1758,2098,6760,6761,5171,6603};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;e['ActionButton'..slot]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitGUID=function(unit)return unit=='player'and'Player-rogue'or'Creature-rogue'end
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

local function slice(s,names)s.buffs={{spellId=5171,name=names[5171],sourceUnit='player'}}end
test('combo thresholds learned ranks and own Slice upkeep use actual predicates and catalog',function()
 local f,s,n=fixture();local a=f.addon
 for _,cp in ipairs({0,1,2,3,4})do s.points=cp;assert(first(a,s)==1752)end
 s.known[1757],s.known[1758]=true,true;assert(first(a,s)==1758);s.points=5;assert(first(a,s)==2098)
 s.known[6760],s.known[6761]=true,true;assert(first(a,s)==6761);s.points=2;s.known[5171]=true;assert(first(a,s)==5171)
 slice(s,n);assert(first(a,s)==1758);s.points=5;assert(first(a,s)==6761);s.buffs={};assert(first(a,s)==5171)
end)
test('native energy usability and cost changes add no reserve or hard resource threshold',function()
 local f,s=fixture();local a=f.addon;s.energy=44;assert(not first(a,s));s.energy=45;assert(first(a,s)==1752)
 s.costOverride=40;s.energy=40;assert(first(a,s)==1752);s.costOverride=nil;s.points=5;s.energy=34;assert(not first(a,s));s.energy=35;assert(first(a,s)==2098)
 s.points=2;s.known[5171]=true;s.energy=25;assert(first(a,s)==5171);s.energy=24;assert(not first(a,s))
end)
test('range cooldown mapping and rank fallback retain action-specific authority',function()
 local f,s=fixture();local a=f.addon;s.known[1757],s.known[1758]=true,true;s.mapped[1758]=false;assert(first(a,s)==1757)
 s.cooldown[1757]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(a,s)==1752)
 s.range[1752]=false;assert(not first(a,s));s.range[1752]=true;s.points=5;s.mapped[2098]=false;assert(not first(a,s),'unavailable finisher authorized builder overflow')
end)
test('combat hostile live target and native melee gate self upkeep and permit moving instant actions',function()
 local f,s=fixture();local a=f.addon;s.points=2;s.known[5171]=true
 for _,key in ipairs({'combat','hostile','exists'})do s[key]=false;assert(not first(a,s));s[key]=true end
 s.dead=true;assert(not first(a,s));s.dead=false;s.range[6603]=false;assert(not first(a,s));s.range[6603]=true;s.moving=true;assert(first(a,s)==5171)
 s.rangeError=true;local id,result=first(a,s);assert(not id and result.status=='unavailable')
end)
test('unknown point facts never match builders or finishers and aura unknown is not missing',function()
 local f,s=fixture();local a=f.addon;s.pointNil=true;assert(not first(a,s));s.pointNil=false;s.pointError=true;assert(not first(a,s));s.pointError=false
 local opaque={};s.points=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;assert(not first(a,s))
 s.points=2;s.known[5171]=true;s.auraError=true;local id,result=first(a,s);assert(not id and result.status=='unavailable' and result.suppressAttack,'unknown aura fell through');s.points=5;id,result=first(a,s);assert(not id and result.status=='unavailable' and result.suppressAttack)
end)
test('missing combo API refuses without legacy fallback and target transitions are fresh',function()
 local f,s=fixture();f.env.GetComboPoints=nil;f.env.UnitPower=function()error('fallback not allowed')end
 local id,result=first(f.addon,s);assert(not id and result.status=='unavailable'and result.suppressAttack)
 local g,t=fixture();t.points=5;assert(first(g.addon,t)==2098);t.points=0;assert(first(g.addon,t)==1752);t.points=3;assert(first(g.addon,t)==1752)
end)
test('instant actions do not inherit Heroic Strike queued or auto-repeat suppression',function()
 local f,s=fixture();f.env.C_Spell.IsCurrentSpell=function()error('invented current policy')end;f.env.C_Spell.IsAutoRepeatSpell=function()error('invented repeat policy')end
 assert(first(f.addon,s)==1752);s.points=5;assert(first(f.addon,s)==2098)
end)
test('real action bars and main publish mapped builder finisher and fresh point transitions',function()
 local f,s=fixture();s.known[1758],s.known[1757],s.known[6761]=true,true,true;s.mapped[1758]=false
 local tick,glow,messages=nativePublish(f,s);assert(f.addon:FindSpell({1758,1757,1752})==1757);tick();assert(f.addon.currentSpell==1757)
 s.points=5;tick();assert(f.addon.currentSpell==6761);s.points=2;s.known[5171]=true;tick();assert(f.addon.currentSpell==5171)
 local seen={};for _,row in ipairs(messages)do if row[1]=='ROTATIONMASTER_SPELL_UPDATE'and row[6]then seen[row[6]]=true end end;assert(seen[1757]and seen[6761]and seen[5171])
end)
test('bounded source scope preferences and clones remain independent',function()
 local f,s=fixture();local a=f.addon;local row=a:ListDefaultRotations(0)[1];assert(row.eligible and row.validation.valid and row.validation.resolved)
 local id=assert(a:CloneDefaultRotation(0,row.id,'Rogue copy'));local clone=a:GetEditableRotation(0,id);local original=body(a).rotation[1].id;clone.rotation[1].id='custom-first-step';assert(body(a).rotation[1].id==original)
 assert(a:SetDefaultRotationEnabled(row.id,false));assert(not a:ListDefaultRotations(0)[1].eligible);assert(a:SetDefaultRotationEnabled(row.id,true))
 s.level=19;assert(a:ListDefaultRotations(0)[1].eligible);s.level=20;assert(not a:ListDefaultRotations(0)[1].eligible and not a:GetRuntimeRotation(0,id))
 local other=fixture(5,'MAGE');assert(#other.addon:ListDefaultRotations(0)==0);local edition=fixture(2,'ROGUE');assert(not edition.addon:ListDefaultRotations(0)[1].eligible)
end)
test('POINT13 exact current-target transport and explicit legacy override discriminate',function()
 local f,s=fixture();s.points=5;f.env.UnitPower=function()error('fallback must not run')end
 assert(first(f.addon,s)==2098 and s.comboCalls>0 and s.pointCalls==0)
 f.addon.points.ROGUE=4;f.env.UnitPower=function(unit,kind)assert(unit=='player'and kind==4);return 0 end
 assert(first(f.addon,s)==1752,'explicit power selector incorrectly routed to target combo')
end)
test('manual stealth casts and channels stop spells and suppress implicit Attack',function()
 local f,s=fixture();local a=f.addon
 for _,key in ipairs({'stealth','cast','channel'})do
  s[key]=true;local id,result=first(a,s);assert(not id and result.status=='stopped'and result.suppressAttack,key..' not preserved');s[key]=false
 end
 for _,key in ipairs({'stealthError','stealthNil','castError','channelError'})do
  s[key]=true;local id,result=first(a,s);assert(not id and result.status=='unavailable'and result.suppressAttack,key..' unknown fell through');s[key]=false
 end
end)
test('own aura identity excludes foreign caster and unrelated spell collisions',function()
 local f,s,n=fixture();s.points=2;s.known[5171]=true
 s.buffs={{spellId=5171,name=n[5171],sourceUnit='party1'}};assert(first(f.addon,s)==5171)
 slice(s,n);assert(first(f.addon,s)==1752)
 s.buffs={{spellId=999,name='Unrelated',sourceUnit='player'}};assert(first(f.addon,s)==5171)
end)
test('actual publisher clears stale spell and refuses Attack under explicit and unknown stops',function()
 local f,s=fixture();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==1752)
 for _,key in ipairs({'stealth','cast','channel','stealthError','castError','channelError','pointNil','pointError'})do
  s[key]=true;tick();assert(not f.addon.currentSpell,key..' left spell or Attack');s[key]=false;tick();assert(f.addon.currentSpell==1752)
 end
 s.points=2;s.known[5171]=true;s.auraError=true;tick();assert(not f.addon.currentSpell,'unknown aura published Attack')
end)
test('actual publisher permits ordinary Attack only after known nonselection',function()
 local f,s=fixture();local tick=nativePublish(f,s);s.energy=0;tick();assert(f.addon.currentSpell==6603)
 s.points=5;s.mapped[2098]=false;tick();assert(f.addon.currentSpell==6603,'known unmapped finisher should retain ordinary melee Attack')
 s.combat=false;tick();assert(not f.addon.currentSpell);s.combat=true;s.range[6603]=false;tick();assert(not f.addon.currentSpell)
end)
finish()
