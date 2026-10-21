-- Bounded Warrior30–39 scenarios; native observations modeled, runtime/publication real.
-- Mirrored nominal level32 rows supply scenario IDs, never player training or fixed costs.
local ID='rm.tbc.warrior.starter.30-39'
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class)
    local f=F.new(product or 5,1,class or 'WARRIOR');local a,e=f.addon,f.env
    f.translations['Default.TBC.Warrior.Thirty.Name']='TBC Warrior30–39 preview';f.translations['Default.TBC.Warrior.Thirty.Description']='Bounded Warrior30–39 preview; reactive abilities, stance and resources remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=30,combat=false,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[78]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,repeatActive=false,mapped={},power={},metadataMissing={}}
    local families={[78]={78,284,285,1608,11564},[772]={772,6546,6547},[6673]={6673,5242,6192,11549},[6603]={6603},[7384]={7384,7887},[5308]={5308,20658}}
    local names,ranks={},{}
    for base,ids in pairs(families) do for rank,id in ipairs(ids) do names[id]='Localized family '..base;ranks[id]='Rank '..rank end end
    e.UnitExists=function(unit) return unit=='player' or unit=='target' and s.exists end
    e.UnitLevel=function() return s.level end
    e.UnitAffectingCombat=function(unit) return unit=='player' and s.combat or unit~='player' and s.targetCombat end
    e.UnitCanAttack=function() return s.hostile end;e.UnitIsDead=function() return s.dead end
    e.UnitHasVehicleUI=function() return false end;e.GetUnitSpeed=function() return s.moving and 7 or 0 end
    e.UnitHealth=function(unit)if s.healthError then error('unavailable')end;return unit=='target'and s.targetHealth or s.health end;e.UnitHealthMax=function() return s.maximum end
    e.UnitCastingInfo=function()if s.castError then error('cast unavailable')end;if s.cast then return 'Manual Slam' end end
    e.UnitChannelInfo=function()if s.channelError then error('channel unavailable')end;if s.channel then return 'Channel in progress' end end
    e.IsSpellKnown=function(id)if s.knownError then error('unavailable')end;return s.known[id]==true end
    e.C_Spell={GetSpellInfo=function(id)if s.metadataMissing[id]then return end;return {name=names[id] or 'Spell '..id,spellID=id,subtext=ranks[id]} end,
        IsCurrentSpell=function(id)if s.activeError then error('unavailable')end;if s.activeNil then return nil end;return s.active==id end,SpellHasRange=function(id) return id~=6673 and id~=5242 and id~=6192 and id~=11549 end,IsSpellInRange=function(id,unit)assert(unit=='target');return s.range[id]~=false end,
        IsSpellUsable=function(id) return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua'}) do f.load(path) end
    local pack=io.open('Defaults/tbc/warrior-30-39.lua');if pack then pack:close();f.load('Defaults/tbc/warrior-30-39.lua')end
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
    for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==ID then return r.envelope.body end end;error('missing Warrior30–39 preview')
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
 local actions={78,284,285,1608,11564,772,6546,6547,6673,5242,6192,11549,6603,7384,7887,5308,20658};local buttons={}
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

local function row(a)for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==ID then return r end end;error('missing Warrior30–39 manifest')end
local function allRanks(s)for _,id in ipairs({78,284,285,1608,11564})do s.known[id]=true end end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end

test('nominal32 and39 levels grant no HS Execute or Shout ranks without native learning',function()
 local f,s=fixture();s.combat=true;for _,level in ipairs({30,31,32,39})do s.level=level;assert(first(f.addon,s)==78)end
 s.known[11564]=true;assert(first(f.addon,s)==11564);s.mapped[11564]=false;assert(first(f.addon,s)==78)
 s.targetHealth=10;s.known[20658]=true;assert(first(f.addon,s)==20658);s.mapped[20658]=false;assert(first(f.addon,s)==78)
 assert(not optional(f,s));s.known[11549]=true;assert(optional(f,s)==11549)
end)
test('learned Execute remains strictly below20 before independently ready Heroic Strike',function()
 local f,s=fixture();s.combat=true;s.known[5308],s.known[20658],s.known[11564]=true,true,true
 for _,hp in ipairs({20,100})do s.targetHealth=hp;assert(first(f.addon,s)==11564)end
 for _,hp in ipairs({19.999,10})do s.targetHealth=hp;assert(first(f.addon,s)==20658)end
 s.healthError=true;assert(first(f.addon,s)==11564)
end)
test('five exact known HS ranks stop queue advice even lower queued while higher learned and mapped',function()
 local f,s=fixture();s.combat=true;allRanks(s)
 for _,id in ipairs({78,284,285,1608,11564})do s.active=id;local selected,r=first(f.addon,s);assert(not selected and r.status=='stopped'and not r.suppressAttack,id)end
 s.active=11564;s.mapped[11564]=false;assert(not first(f.addon,s));s.active=78;assert(not first(f.addon,s))
 s.active=nil;assert(first(f.addon,s)==1608)
end)
test('unlearned queue ranks are not queried and selected unknown queue observation fails closed',function()
 local f,s=fixture();s.combat=true;local queries={};local old=f.env.C_Spell.IsCurrentSpell
 f.env.C_Spell.IsCurrentSpell=function(...)assert(select('#',...)==1);local id=(...);queries[#queries+1]=id;return old(id)end
 assert(first(f.addon,s)==78 and#queries==1 and queries[1]==78)
 s.activeError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.activeError=false;s.activeNil=true;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('unknown fifth rank queue is fatal only when that exact rank is known',function()
 local f,s=fixture();s.combat=true;local old=f.env.C_Spell.IsCurrentSpell
 f.env.C_Spell.IsCurrentSpell=function(id)if id==11564 then error('fifth queue unreadable')end;return old(id)end
 assert(first(f.addon,s)==78);s.known[11564]=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('ready Execute before a queued HS is inherited priority without canceling that queue',function()
 local f,s=fixture();s.combat=true;allRanks(s);s.active=78;s.known[20658]=true;s.targetHealth=10
 assert(first(f.addon,s)==20658 and s.active==78);s.usable[20658]=false;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and s.active==78)
end)
test('manual Slam casts and channels stop all direct advice and suppress Attack',function()
 local f,s=fixture();s.combat=true;s.known[20658]=true;s.targetHealth=10
 for _,key in ipairs({'cast','channel'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
end)
test('unknown or restricted cast channel observation stops direct advice and optional Shout',function()
 local f,s=fixture();s.combat=true;s.known[11549],s.known[20658]=true,true;s.targetHealth=10
 for _,key in ipairs({'castError','channelError'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack,key);assert(not optional(f,s));s[key]=false end
 local opaque={};f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;f.env.UnitCastingInfo=function()return opaque end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack);assert(not optional(f,s))
end)
test('optional anyrank Shout requires no cast or channel and preserves existing recognized buff',function()
 local f,s,n=fixture();s.known[6673],s.known[5242],s.known[6192],s.known[11549]=true,true,true,true;assert(optional(f,s)==11549)
 for _,key in ipairs({'cast','channel'})do s[key]=true;assert(not optional(f,s));s[key]=false end
 for _,id in ipairs({6673,5242,6192,11549})do s.buffs={{spellId=id,name=n[id],sourceUnit='party1'}};assert(not optional(f,s))end
 s.buffs={};s.auraError=true;assert(not optional(f,s));s.auraError=false;assert(optional(f,s)==11549)
end)
test('native resources stance refusal cooldown range and mapping control Execute rank fallback',function()
 local f,s=fixture();s.combat=true;s.targetHealth=10;s.known[5308],s.known[20658],s.known[11564]=true,true,true
 s.usable[20658]=false;assert(first(f.addon,s)==5308);s.usable[5308]=false;assert(first(f.addon,s)==11564)
 s.usable={};s.power[20658],s.power[5308]=true,true;assert(first(f.addon,s)==11564);s.power={}
 s.range[20658],s.range[5308]=false,false;assert(first(f.addon,s)==11564);s.range={}
 s.cooldown[20658],s.cooldown[5308]={startTime=90,duration=30,isEnabled=true,modRate=1},{startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(f.addon,s)==11564)
 s.cooldown={};s.mapped[20658],s.mapped[5308]=false,false;assert(first(f.addon,s)==11564)
end)
test('combat live hostile target gates direct advice and omitted mechanics remain manual',function()
 local f,s=fixture();assert(not first(f.addon,s));s.combat=true
 for _,key in ipairs({'hostile','exists'})do s[key]=false;assert(not first(f.addon,s));s[key]=true end
 s.dead=true;assert(not first(f.addon,s));s.dead=false;s.known[772],s.known[7384]=true,true;assert(first(f.addon,s)==78)
 local actions={};for _,r in ipairs(assert(f.addon.RotationData.IndexRotationSteps(body(f.addon))).rows)do if r.step.action then actions[r.step.action]=true end end
 for _,id in ipairs({772,7384,100,2687,355,72,1715,845,20230,2458,12294})do assert(not actions[id])end
end)
test('modern exact current arity and selected failures never call legacy fallback',function()
 local f,s=fixture();s.combat=true;s.known[11564]=true;local old=f.env.C_Spell.IsCurrentSpell;local calls,legacy=0,0
 f.env.IsCurrentSpell=function()legacy=legacy+1;return 1 end;f.env.C_Spell.IsCurrentSpell=function(...)assert(select('#',...)==1);calls=calls+1;return old(...)end
 assert(first(f.addon,s)==11564 and calls==2 and legacy==0);f.env.C_Spell.IsCurrentSpell=function()error('selected unavailable')end;assert(not first(f.addon,s)and legacy==0)
end)
test('legacy exact numeric zero one transport preserves all five queue ranks',function()
 local f,s=fixture();s.combat=true;allRanks(s);f.env.C_Spell.IsCurrentSpell=nil;f.env.IsCurrentSpell=function(...)assert(select('#',...)==1);return s.active==(...)and 1 or 0 end
 for _,id in ipairs({78,284,285,1608,11564})do s.active=id;assert(not first(f.addon,s))end
 s.active=nil;assert(first(f.addon,s)==11564)
end)
test('real initialized bar publisher finds new ranks and optional Shout without inferring learning',function()
 local f,s=fixture();s.combat=true;s.level=32;local tick,_,messages=nativePublish(f,s);tick();assert(f.addon.currentSpell==78)
 s.known[11564]=true;tick();assert(f.addon.currentSpell==11564)
 s.known[20658]=true;s.targetHealth=10;tick();assert(f.addon.currentSpell==20658)
 s.known[11549]=true;tick();assert(f.addon.avail_announced['warrior-thirty-battle-shout']==11549)
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]then seen[m[6]]=true end end;assert(seen[78]and seen[11564]and seen[20658])
end)
test('real publisher clears stale advice and Shout under casts channels and unavailable observations',function()
 local f,s=fixture();s.combat=true;s.known[11564],s.known[11549]=true,true;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==11564 and f.addon.avail_announced['warrior-thirty-battle-shout']==11549)
 for _,key in ipairs({'cast','channel','castError','channelError'})do
  s[key]=true;tick();assert(f.addon.currentSpell==nil and not f.addon.avail_announced['warrior-thirty-battle-shout'],key);s[key]=false;tick();assert(f.addon.currentSpell==11564)
 end
end)
test('real queue suppression permits known ordinary Attack and unavailable queue permits none',function()
 local f,s=fixture();s.combat=true;allRanks(s);s.active=11564;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==6603)
 s.active=78;tick();assert(f.addon.currentSpell==6603);s.activeError=true;tick();assert(f.addon.currentSpell==nil)
 s.activeError=false;s.active=nil;tick();assert(f.addon.currentSpell==11564)
 for _,id in ipairs({78,284,285,1608,11564})do s.power[id]=true end;tick();assert(f.addon.currentSpell==6603);s.beyond=true;tick();assert(f.addon.currentSpell==nil)
end)
test('actual bar refresh honors new rank mapping changes and recovering usability',function()
 local f,s=fixture();s.combat=true;s.targetHealth=10;s.known[20658]=true;s.mapped[20658]=false;local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==78)
 s.mapped[20658]=true;local key=f.addon.currentRotation;f.addon.currentRotation=nil;f.addon:Fetch();f.addon.currentRotation=key;tick();assert(f.addon.currentSpell==20658)
 s.usable[20658]=false;tick();assert(f.addon.currentSpell==78)
end)
test('three default brackets and learned anchor remain exact without talent or stance selection',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/warrior-starter.lua');f.load('Defaults/tbc/warrior-20-29.lua');assert(a:InitializeRotationLibrary())
 f.env.GetTalentTabInfo=function()error('no talent gate')end
 for _,level in ipairs({19,20,29,30,39,40})do s.level=level;a.longtermCache.conditionPlayerLevel=nil
  local rows={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then rows[#rows+1]=r.id end end
  local expected=level==19 and'rm.tbc.warrior.starter'or level<30 and'rm.tbc.warrior.starter.20-29'or level<40 and ID or nil
  assert(#rows==(expected and 1 or 0));if expected then assert(rows[1]==expected)end
  assert((not not a:evaluateCondition(body(a).switch))==(level>=30 and level<40))
 end
 s.level=30;s.known[78]=false;a.longtermCache.conditionPlayerLevel=nil;assert(not a:evaluateCondition(body(a).switch))
end)
test('class edition vehicle petbattle enable and profile boundaries remain authoritative',function()
 for _,case in ipairs({{5,'MAGE'},{2,'WARRIOR'},{1,'WARRIOR'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f,s=fixture();local a=f.addon;assert(row(a).readOnly and row(a).validation.valid and row(a).validation.resolved)
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible and not a:GetRuntimeRotation(0,row(a).runtimeKey))
 local old=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled);a.db.profile=old;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
end)
test('earlier source edits and clone bounds survive independent new source adoption',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/warrior-20-29.lua');assert(a:InitializeRotationLibrary());s.level=29
 local oldID=assert(a:CloneDefaultRotation(0,'rm.tbc.warrior.starter.20-29','Earlier Warrior'));local old=a:GetEditableRotation(0,oldID);old.rotation[1].onTrue[1].action=999;local saved=a:CopySettingsData(old)
 s.level=30;assert(a:InitializeRotationLibrary());local freshID=assert(a:CloneDefaultRotation(0,ID,'Thirty Warrior'));assert(same(saved,a:GetEditableRotation(0,oldID))and not a:GetRuntimeRotation(0,oldID))
 local fresh=a:GetEditableRotation(0,freshID);assert(fresh.rotation[1].conditions.type=='CASTING'and fresh.rotation[2].conditions.type=='CHANNELING');assert(body(a).rotation[3].onTrue[1].action==5308)
 local comparison=assert(a:BuildRotationComparison(0,freshID,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 s.level=40;assert(not row(a).eligible and not a:GetRuntimeRotation(0,freshID))
end)
finish()
