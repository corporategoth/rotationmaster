-- Actual Rogue30–39 continuation; native observations modeled, runtime/publication real.
-- Inherited example ranks are not an exhaustive30–39 spellbook or training schedule.
-- Source override is local to the literal old-policy parity control below.
local ID='rm.tbc.rogue.starter.30-39'
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(product,class,source,level)
    local f=F.new(product or 5,1,class or 'ROGUE');local a,e=f.addon,f.env
    f.translations['Default.TBC.Rogue.Thirty.Name']='TBC Rogue30–39 melee preview';f.translations['Default.TBC.Rogue.Thirty.Description']='Bounded solo preview; openers, utility and resource planning remain manual.'
    a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
    local s={level=level or 30,combat=true,targetCombat=false,hostile=true,dead=false,exists=true,moving=false,
        known={[1752]=true,[2098]=true,[6603]=true},usable={},range={},cooldown={},buffs={},debuffs={},
        health=100,maximum=100,targetHealth=100,channel=false,cast=false,stealth=false,repeatActive=false,mapped={},power={},metadataMissing={},points=0,targetPoints=0,energy=100,pointCalls=0,comboCalls=0}
    local families={[1752]={1752,1757,1758,1759},[2098]={2098,6760,6761,6762},[5171]={5171},[6603]={6603}}
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
        IsSpellUsable=function(id)local costs={[1752]=45,[1757]=45,[1758]=45,[1759]=45,[2098]=35,[6760]=35,[6761]=35,[6762]=35,[5171]=25};local lack=s.power[id]==true or s.energy<(s.costOverride or costs[id]or 0);return s.usable[id]~=false and not lack,lack end,
        IsAutoRepeatSpell=function(id) assert(id==5019);if s.repeatError then error('unavailable') end;return s.repeatActive end,
        GetSpellCooldown=function(id) return s.cooldown[id] or {startTime=0,duration=0,isEnabled=true,modRate=1} end}
    e.C_UnitAuras={GetAuraDataByIndex=function(_,index,filter) if s.auraError then error('unavailable') end;return (filter=='HELPFUL' and s.buffs or s.debuffs)[index] end}
    for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
        'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
        'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
        'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/range.lua'}) do f.load(path) end
    -- Built In composition: shared blocks register before the packs that expand them.
    f.load('Defaults/blocks/rogue.lua')
    local selected=source or 'Defaults/tbc/rogue-30-39.lua';local pack=io.open(selected);if pack then pack:close();f.load(selected)end
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
    local rows=a:ListDefaultRotations(0);for _,r in ipairs(rows)do if r.id==ID then return r.envelope.body end end;assert(rows[1],'missing Rogue30–39 preview');return rows[1].envelope.body
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
 local actions={1752,1757,1758,1759,2098,6760,6761,6762,5171,6603};local buttons={}
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
local function row(a)for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==ID then return r end end;error('missing Rogue30–39 manifest')end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end

test('thirty-nine grants no ranks and learned mapped ranks retain exact builder finisher priority',function()
 local f,s,n=fixture();local a=f.addon;s.level=39;assert(row(a).eligible and first(a,s)==1752)
 s.known[1759]=true;assert(first(a,s)==1759);s.mapped[1759]=false;assert(first(a,s)==1752)
 s.points=5;assert(first(a,s)==2098);s.known[6762]=true;assert(first(a,s)==6762);s.mapped[6762]=false;assert(first(a,s)==2098)
 s.points=2;s.known[5171]=true;assert(first(a,s)==5171);slice(s,n);assert(first(a,s)==1752)
end)
test('two point Slice upkeep and five point Eviscerate retain fixed preview policy without lifetime claims',function()
 local f,s,n=fixture();local a=f.addon;s.known[5171]=true
 for _,cp in ipairs({0,1})do s.points=cp;assert(first(a,s)==1752)end
 for _,cp in ipairs({2,3,4,5})do s.points=cp;assert(first(a,s)==5171)end
 slice(s,n);for _,cp in ipairs({0,1,2,3,4})do s.points=cp;assert(first(a,s)==1752)end
 s.points=5;for _,hp in ipairs({1,100})do s.targetHealth=hp;assert(first(a,s)==2098)end
 s.mapped[2098]=false;assert(not first(a,s),'unmapped finisher cannot authorize builder overflow')
end)
test('native reduced costs and low resources add no authored energy reserve',function()
 local f,s=fixture();local a=f.addon;s.energy=44;assert(not first(a,s));s.energy=45;assert(first(a,s)==1752)
 s.costOverride=1;s.energy=1;assert(first(a,s)==1752);s.points=5;assert(first(a,s)==2098)
 s.points=2;s.known[5171]=true;assert(first(a,s)==5171);s.energy=0;assert(not first(a,s))
end)
test('manual stealth casts channels and their unavailable observations halt and suppress Attack',function()
 local f,s=fixture();local a=f.addon
 for _,key in ipairs({'stealth','cast','channel'})do s[key]=true;local id,r=first(a,s);assert(not id and r.status=='stopped'and r.suppressAttack,key);s[key]=false end
 for _,key in ipairs({'stealthError','stealthNil','castError','channelError'})do s[key]=true;local id,r=first(a,s);assert(not id and r.status=='unavailable'and r.suppressAttack,key);s[key]=false end
end)
test('combat living hostile target and actual melee gate every action including self upkeep',function()
 local f,s=fixture();s.points=2;s.known[5171]=true
 for _,key in ipairs({'combat','hostile','exists'})do s[key]=false;assert(not first(f.addon,s));s[key]=true end
 s.dead=true;assert(not first(f.addon,s));s.dead=false;s.range[6603]=false;assert(not first(f.addon,s));s.range[6603]=true
 s.moving=true;assert(first(f.addon,s)==5171);s.rangeError=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('unavailable combo points stop builders finishers and any implicit Attack',function()
 local f,s=fixture();for _,key in ipairs({'pointNil','pointError'})do s[key]=true;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack);s[key]=false end
 local opaque={};s.points=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end;local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
end)
test('missing current-target combo API does not fall back and target transitions are read fresh',function()
 local f,s=fixture();f.env.GetComboPoints=nil;f.env.UnitPower=function()error('no legacy fallback')end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 local g,t=fixture();for _,case in ipairs({{5,2098},{0,1752},{3,1752},{5,2098}})do t.points=case[1];assert(first(g.addon,t)==case[2])end
 assert(t.comboCalls>0 and t.pointCalls==0)
end)
test('own Slice respects caster identity while nil stays not-own and restricted stays unavailable',function()
 local f,s,n=fixture();s.points=2;s.known[5171]=true
 s.buffs={{spellId=5171,name=n[5171],sourceUnit='party1'}};assert(first(f.addon,s)==5171)
 slice(s,n);assert(first(f.addon,s)==1752);s.buffs[1].sourceUnit=nil;assert(first(f.addon,s)==5171)
 local opaque={};s.buffs[1].sourceUnit=opaque;f.env.canaccessvalue=function(v)return not rawequal(v,opaque)end
 local id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)
 s.buffs={};s.auraError=true;for _,points in ipairs({2,5})do s.points=points;id,r=first(f.addon,s);assert(not id and r.status=='unavailable'and r.suppressAttack)end
end)
test('known rank mapping cooldown and native usability independently constrain priority',function()
 local f,s=fixture();s.known[1757],s.known[1759]=true,true;s.mapped[1759]=false;assert(first(f.addon,s)==1757)
 s.cooldown[1757]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(first(f.addon,s)==1752)
 s.usable[1752]=false;assert(not first(f.addon,s));s.usable[1752]=true;s.range[1752]=false;assert(not first(f.addon,s))
end)
test('instant actions never infer queued current-spell or autorepeat policy',function()
 local f,s=fixture();f.env.C_Spell.IsCurrentSpell=function()error('invented queue')end;f.env.C_Spell.IsAutoRepeatSpell=function()error('invented repeat')end
 assert(first(f.addon,s)==1752);s.points=5;assert(first(f.addon,s)==2098)
end)
test('real initialized bars and main publish mapped builders finishers and Slice on fresh points',function()
 local f,s,n=fixture();s.known[1759],s.known[1757],s.known[6762]=true,true,true;s.mapped[1759]=false
 local tick,_,messages=nativePublish(f,s);assert(f.addon:FindSpell({1759,1757,1752})==1757);tick();assert(f.addon.currentSpell==1757)
 s.points=5;tick();assert(f.addon.currentSpell==6762);s.points=0;tick();assert(f.addon.currentSpell==1757)
 s.points=2;s.known[5171]=true;tick();assert(f.addon.currentSpell==5171);slice(s,n);tick();assert(f.addon.currentSpell==1757)
 local seen={};for _,m in ipairs(messages)do if m[1]=='ROTATIONMASTER_SPELL_UPDATE'and m[6]then seen[m[6]]=true end end;assert(seen[1757]and seen[6762]and seen[5171]);assert(s.comboCalls>0 and s.pointCalls==0)
end)
test('real publisher clears stale advice under explicit and unavailable stops without Attack',function()
 local f,s=fixture();local tick=nativePublish(f,s);tick();assert(f.addon.currentSpell==1752)
 for _,key in ipairs({'stealth','cast','channel','stealthError','castError','channelError','pointNil','pointError'})do s[key]=true;tick();assert(f.addon.currentSpell==nil,key);s[key]=false;tick();assert(f.addon.currentSpell==1752)end
 s.points=2;s.known[5171]=true;s.auraError=true;tick();assert(f.addon.currentSpell==nil)
end)
test('real publisher retains ordinary Attack only after known nonselection within melee combat',function()
 local f,s=fixture();local tick=nativePublish(f,s);s.energy=0;tick();assert(f.addon.currentSpell==6603)
 s.points=5;s.mapped[2098]=false;tick();assert(f.addon.currentSpell==6603)
 s.combat=false;tick();assert(f.addon.currentSpell==nil);s.combat=true;s.range[6603]=false;tick();assert(f.addon.currentSpell==nil)
end)
test('modern learned player bank exact arity and selected failure stay separate from target-combo transport',function()
 local f,s=fixture();local e=f.env;local calls,legacy=0,0;e.Enum.SpellBookSpellBank={Player=0,Pet=1}
 e.C_SpellBook={IsSpellKnown=function(...)assert(select('#',...)==2);local id,bank=...;assert(bank==0);calls=calls+1;return s.known[id]==true end};e.IsSpellKnown=function()legacy=legacy+1;return true end
 assert(first(f.addon,s)==1752 and calls>0 and legacy==0);e.C_SpellBook.IsSpellKnown=function()error('selected unavailable')end;assert(not first(f.addon,s)and legacy==0)
end)
test('three default brackets remain disjoint and source switch has no talent observation',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/rogue-starter.lua');f.load('Defaults/tbc/rogue-20-29.lua');assert(a:InitializeRotationLibrary())
 f.env.GetTalentTabInfo=function()error('generic source must not require a tree')end
 for _,level in ipairs({19,20,29,30,39,40})do
  s.level=level;a.longtermCache.conditionPlayerLevel=nil;local eligible={};for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible then eligible[#eligible+1]=r.id end end
  local expected=level==19 and'rm.tbc.rogue.starter'or level<30 and'rm.tbc.rogue.starter.20-29'or level<40 and ID or nil
  assert(#eligible==(expected and 1 or 0));if expected then assert(eligible[1]==expected)end
  assert((not not a:evaluateCondition(body(a).switch))==(level>=30 and level<40))
 end
 s.level=30;s.known[1752]=false;a.longtermCache.conditionPlayerLevel=nil;assert(not a:evaluateCondition(body(a).switch))
end)
test('edition class vehicle petbattle enable and profile boundaries remain authoritative',function()
 for _,case in ipairs({{2,'ROGUE'},{1,'ROGUE'},{5,'MAGE'}})do local f=fixture(case[1],case[2]);local rows=f.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 local f,s=fixture();local a=f.addon;assert(row(a).readOnly and row(a).eligible and row(a).validation.valid and row(a).validation.resolved)
 f.env.UnitHasVehicleUI=function()return true end;assert(not row(a).eligible);f.env.UnitHasVehicleUI=function()return false end
 f.env.C_PetBattles={IsInBattle=function()return true end};assert(not row(a).eligible);f.env.C_PetBattles=nil
 assert(a:SetDefaultRotationEnabled(ID,false));assert(not row(a).eligible and not a:GetRuntimeRotation(0,row(a).runtimeKey))
 local old=a.db.profile;a.db.profile={rotations={},itemsets={}};assert(a:InitializeRotationLibrary());assert(row(a).enabled)
 a.db.profile=old;assert(a:InitializeRotationLibrary());assert(not row(a).enabled)
end)
test('accepted old bracket literal advice parity holds with inherited known families',function()
 local old,os,on=fixture(nil,nil,'Defaults/tbc/rogue-20-29.lua',29);local new,ns,nn=fixture()
 for _,s in ipairs({os,ns})do s.known[5171],s.known[1759],s.known[6762]=true,true,true end
 for _,case in ipairs({{0,1759},{1,1759},{2,5171},{5,5171}})do os.points,ns.points=case[1],case[1];assert(first(old.addon,os)==case[2]and first(new.addon,ns)==case[2])end
 slice(os,on);slice(ns,nn);os.points,ns.points=5,5;assert(first(old.addon,os)==6762 and first(new.addon,ns)==6762)
 os.stealth,ns.stealth=true,true;assert(not first(old.addon,os)and not first(new.addon,ns))
end)
test('earlier source clones and saved edits survive new source adoption with independent scope',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/rogue-starter.lua');f.load('Defaults/tbc/rogue-20-29.lua');assert(a:InitializeRotationLibrary());s.level=29
 local localID=assert(a:CloneDefaultRotation(0,'rm.tbc.rogue.starter.20-29','Earlier Rogue'));local clone=a:GetEditableRotation(0,localID);clone.rotation[1].id='my-stop';local saved=a:CopySettingsData(clone)
 s.level=30;assert(a:InitializeRotationLibrary());local freshID=assert(a:CloneDefaultRotation(0,ID,'Thirty Rogue'));local fresh=a:GetEditableRotation(0,freshID);assert(fresh.rotation[1].type=='none'and fresh.rotation[1].conditions.type=='STEALTHED'and fresh.rotation[1].suppress_attack and fresh.rotation[1].id~='rogue-thirty-preserve-stealth')
 assert(same(saved,a:GetEditableRotation(0,localID))and not a:GetRuntimeRotation(0,localID));assert(body(a).rotation[1].id=='rogue-thirty-preserve-stealth')
 local comparison=assert(a:BuildRotationComparison(0,freshID,{kind='builtin',id=ID}));assert(comparison.valid and comparison.complete)
 s.level=40;assert(not row(a).eligible and not a:GetRuntimeRotation(0,freshID))
end)
finish()
