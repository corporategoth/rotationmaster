-- Actual Paladin30–39 scenarios; native observations and timer scheduling are modeled, execution/publication real.
-- Inherited example rank families only; level never grants these spells.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'PALADIN');local a,e=f.addon,f.env
    f.translations['Default.TBC.Paladin.Thirty.Name']='TBC Paladin30–39 manual seal/aura preview';f.translations['Default.TBC.Paladin.Thirty.Description']='Levels30–39: preserve manual aura and Crusader/Command/Justice seals; only Righteousness Judgement is advised. Targeted support and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[465]=true,[21084]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[465]={465,10290,643},[7294]={7294,10298},[21084]={21084,20287,20288,20289},[21082]={21082,20162,20305},[6603]={6603},[20271]={20271},[19740]={19740,19834},[20154]={20154},[20375]={20375},[20164]={20164},[19746]={19746},[19876]={19876},[20165]={20165},[20166]={20166},[20218]={20218}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    names[20154]=names[21084];ranks[20154]='Rank 1'
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitCastingInfo=function()if s.casting then return 'Cast in progress'end end
    e.UnitChannelInfo=function() if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;return s.active==id end,SpellHasRange=function(id) return id==19740 or id==19834 or id==20271 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open('Defaults/tbc/paladin-30-39.lua');if pack then pack:close();f.load('Defaults/tbc/paladin-30-39.lua')end
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
local ID='rm.tbc.paladin.starter.30-39'
local function sourceRow(a)
 for _,row in ipairs(a:ListDefaultRotations(0))do if row.id==ID then return row end end
 error('missing Paladin30–39 preview')
end
local function body(a)return sourceRow(a).envelope.body end
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
 local actions={465,10290,7294,21084,20154,20287,20288,21082,20162,20271,6603,643,10298,20289,20305,20375,20164,19746,19876};local buttons={}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  buttons[slot]=button;if slot<=12 then e['ActionButton'..slot]=button else e['MultiBarBottomLeftButton'..(slot-12)]=button end
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

local function own(s,n,id,source)s.buffs={{spellId=id,name=n[id],sourceUnit=source or 'player'}}end
local function ready()
 local f,s,n=fixture();s.combat=true;s.known[20271]=true;own(s,n,20288);return f,s,n
end

test('manual aura and seal upkeep never acquires an action even with learned mapped native ready spells',function()
 local f,s,n=fixture();s.level=39
 for id in pairs(n)do s.known[id]=true end
 assert(#body(f.addon).cooldowns==0 and #available(f,s)==0)
 local tick=nativePublish(f,s);tick();assert(not next(f.addon.avail_announced))
 for _,id in ipairs({465,7294,19746,19876,20218,21084,21082,20375,20164,20165,20166})do
  own(s,n,id);tick();assert(not next(f.addon.avail_announced))
 end
end)
test('level39 grants no spells; affirmative own Righteousness and actual learned Judgement decide direct advice',function()
 local f,s,n=fixture();s.level=39;s.combat=true;s.known={};own(s,n,20288)
 assert(not first(f.addon,s));local tick=nativePublish(f,s);tick();assert(not f.addon.currentSpell)
 s.known[20271]=true;tick();assert(f.addon.currentSpell==20271)
 s.buffs={};tick();assert(not f.addon.currentSpell)
end)
test('Judgement requires attributable own Righteousness; nil foreign restricted ownership never consumes it',function()
 local f,s,n=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 for _,who in ipairs({'party1','target'})do s.buffs[1].sourceUnit=who;tick();assert(f.addon.currentSpell==6603)end
 s.buffs[1].sourceUnit=nil;tick();assert(f.addon.currentSpell==6603)
 local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;s.buffs[1].sourceUnit=opaque;tick();assert(f.addon.currentSpell==6603)
 s.buffs[1].sourceUnit='player';tick();assert(f.addon.currentSpell==20271)
end)
test('manual Crusader Command Justice Light and Wisdom are never judged or replaced including overlapping observations',function()
 local f,s,n=ready();local tick=nativePublish(f,s)
 for _,id in ipairs({21082,20162,20305,20375,20164,20165,20166})do
  s.known[id]=false;own(s,n,id);tick();assert(f.addon.currentSpell==6603 and not next(f.addon.avail_announced),id)
  buff(s,n,20288);tick();assert(f.addon.currentSpell==6603 and not next(f.addon.avail_announced),'overlap '..id)
 end
 s.buffs={};own(s,n,20288);tick();assert(f.addon.currentSpell==20271)
end)
test('Righteousness family matches readable localized learned aura ranks without guessed new ranks',function()
 local f,s,n=ready();for id,name in pairs(n)do n[id]='Éclat '..name end
 for id in pairs(n)do f.addon.SpellCatalog:UpdateSpell(id)end
 local tick=nativePublish(f,s)
 for _,id in ipairs({21084,20154,20287,20288,20289})do own(s,n,id);tick();assert(f.addon.currentSpell==20271,id)end
end)
test('readiness cost cooldown range and refreshed bar mapping remain authoritative and recover independently',function()
 local f,s=ready();s.mapped[20271]=false;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 s.mapped[20271]=true;f.addon:Fetch();tick();assert(f.addon.currentSpell==20271)
 s.power[20271]=true;tick();assert(f.addon.currentSpell==6603);s.power[20271]=false
 s.cooldown[20271]={startTime=99,duration=10,isEnabled=true,modRate=1};tick();assert(f.addon.currentSpell==6603);s.cooldown={}
 s.range[20271]=false;tick();assert(f.addon.currentSpell==6603);s.range[20271]=true
 s.known[20271]=false;tick();assert(f.addon.currentSpell==6603);s.known[20271]=true
 tick();assert(f.addon.currentSpell==20271)
end)
test('required unknown observations skip Judgement without fabricating ownership or readiness',function()
 for _,mode in ipairs({'aura','known','usable','range','cooldown','conflict-metadata'})do
  local f,s,n=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
  if mode=='aura'then s.auraError=true
  elseif mode=='known'then s.knownError=true
  elseif mode=='usable'then f.env.C_Spell.IsSpellUsable=function()return nil,nil end
  elseif mode=='range'then f.env.C_Spell.IsSpellInRange=function()return nil end
  elseif mode=='cooldown'then f.env.C_Spell.GetSpellCooldown=function()error('unavailable')end
  else s.metadataMissing[20165]=true end
  tick();assert(f.addon.currentSpell~=20271,mode)
 end
end)
test('private initialized publisher stops Judgement and melee during any readable manual cast or channel',function()
 for _,api in ipairs({'UnitCastingInfo','UnitChannelInfo'})do
  local f,s=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
  local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
  f.env[api]=function(unit)assert(unit=='player');return 'Localized manual action',nil,nil,opaque,nil,nil,opaque end
  tick();assert(not f.addon.currentSpell)
  f.env[api]=function()end;tick();assert(f.addon.currentSpell==20271)
 end
end)
test('unknown cast or channel observation clears old direct and implicit attack advice without fallback guessing',function()
 for _,api in ipairs({'UnitCastingInfo','UnitChannelInfo'})do
  local f,s=ready();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
  f.env[api]=function()error('unavailable')end;tick();assert(not f.addon.currentSpell)
  f.env[api]=function()end;tick();assert(f.addon.currentSpell==20271)
 end
end)
test('implicit attack is offered only with affirmative native known idle ready melee observations',function()
 local f,s=fixture();s.combat=true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 s.active=6603;tick();assert(not f.addon.currentSpell);s.active=nil
 s.beyond=true;tick();assert(not f.addon.currentSpell);s.beyond=false
 s.usable[6603]=false;tick();assert(not f.addon.currentSpell);s.usable[6603]=true
 s.activeError=true;tick();assert(not f.addon.currentSpell);s.activeError=false
 s.known[6603]=false;tick();assert(not f.addon.currentSpell)
end)
test('friendly dead missing and noncombat observations never become a melee pull or Judgement',function()
 for _,mode in ipairs({'hostile','exists','combat','dead'})do
  local f,s=ready();if mode=='dead'then s.dead=true else s[mode]=false end
  local tick=nativePublish(f,s);tick();assert(not f.addon.currentSpell,mode)
 end
end)
test('legacy localized native tuples preserve own seal choice and exact selected APIs without slot alias invention',function()
 local f,s,n=ready();local e=f.env;local modern=e.C_Spell;local aura=e.C_UnitAuras.GetAuraDataByIndex
 e.C_Spell=nil;e.C_UnitAuras=nil
 e.GetSpellInfo=function(id)local v=modern.GetSpellInfo(id);if v then return v.name,v.subtext,123,0,0,0,id,123 end end
 e.IsUsableSpell=modern.IsSpellUsable;e.IsCurrentSpell=function(id)return modern.IsCurrentSpell(id)and 1 or 0 end
 e.GetSpellCooldown=function(id)local v=modern.GetSpellCooldown(id);return v.startTime,v.duration,v.isEnabled and 1 or 0,v.modRate end
 e.FindSpellBookSlotBySpellID=function(id,pet)assert(pet==false);return s.known[id]and id+1000 end
 e.SpellHasRange=function(slot,book)assert(book=='spell');return modern.SpellHasRange(slot-1000)end
 e.IsSpellInRange=function(slot,book,unit)assert(book=='spell'and unit=='target');return modern.IsSpellInRange(slot-1000,unit)and 1 or 0 end
 e.UnitAura=function(unit,index,filter)local v=aura(unit,index,filter);if v then return v.name,nil,0,nil,nil,nil,v.sourceUnit,nil,nil,v.spellId end end
 local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==20271)
 own(s,n,20166);tick();assert(f.addon.currentSpell==6603 and not next(f.addon.avail_announced))
 local legacy=0;e.Enum={SpellBookSpellBank={Player=0,Pet=1}};e.C_Spell={IsSpellKnown=function()error('selected failure')end};e.C_SpellBook={IsSpellKnown=function()error('selected failure')end}
 e.IsSpellKnown=function()legacy=legacy+1;return true end;tick();assert(not f.addon.currentSpell and legacy==0)
end)
test('three current source brackets remain disjoint at19 20 29 30 39 40 without talent query',function()
 local f,s=fixture();f.load('Defaults/tbc/paladin-starter.lua');f.load('Defaults/tbc/paladin-20-29.lua')
 f.env.GetTalentTabInfo=function()error('no talent inference')end
 for _,level in ipairs({19,20,29,30,39,40})do
  s.level=level;f.addon.longtermCache.conditionPlayerLevel=nil
  local eligible={};for _,r in ipairs(f.addon:ListDefaultRotations(0))do if r.eligible then eligible[#eligible+1]=r.id end end
  assert(#eligible==(level==40 and 0 or 1));assert(f.addon:evaluateCondition(body(f.addon).switch)==(level>=30 and level<40))
  if level<40 then assert(eligible[1]==(level==19 and 'rm.tbc.paladin.starter' or level<30 and 'rm.tbc.paladin.starter.20-29' or ID))end
 end
end)
test('source edition class vehicle petbattle enable and profile boundaries remain explicit',function()
 for _,case in ipairs({{5,'MAGE'},{2,'PALADIN'},{1,'PALADIN'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f,s=fixture();local a=f.addon;assert(sourceRow(a).eligible and sourceRow(a).validation.valid and sourceRow(a).validation.resolved)
 f.env.UnitHasVehicleUI=function()return true end;assert(not sourceRow(a).eligible);f.env.UnitHasVehicleUI=function()return false end
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not sourceRow(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not sourceRow(a).eligible)
 local old=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(sourceRow(a).enabled)
 a.db.profile=old;assert(a:InitializeRotationLibrary());assert(not sourceRow(a).enabled)
end)
test('old edited saved clone survives new registration and comparison with no automatic policy adoption',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/paladin-20-29.lua');assert(a:InitializeRotationLibrary())
 local id=assert(a:CloneDefaultRotation(0,'rm.tbc.paladin.starter.20-29','Old Paladin copy'));local clone=a:GetEditableRotation(0,id)
 clone.cooldowns[1].action=7294;local before=a:CopySettingsData(clone)
 local fresh=assert(a:CloneDefaultRotation(0,ID,'New Paladin copy'));assert(#a:GetEditableRotation(0,fresh).cooldowns==0)
 local diff=assert(a:BuildRotationComparison(0,id,{kind='builtin',id=ID}));assert(diff.valid and diff.complete)
 local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
 assert(same(clone,before))
end)
test('bounded graph recommends only Judgement with manual upkeep and no guessed new rank actions',function()
 local f=fixture();local b=body(f.addon);assert(#b.cooldowns==0)
 local rows=assert(f.addon.RotationData.IndexRotationSteps(b)).rows;local actions=0
 for _,r in ipairs(rows)do if r.step.action then actions=actions+1;assert(r.step.action==20271 and r.step.ranked==false)end end
 assert(actions==1)
end)
finish()
