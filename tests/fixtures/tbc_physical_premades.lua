-- Shared world model for the TBC Warrior, Rogue and Hunter premade scenario tests.
-- Native WoW observations are modeled here; the real platform, conditions, catalog,
-- composition, sequence executor, readiness and initialized publisher run on top.
-- Rank families below are scenario samples, not a trainer schedule.
local F=dofile('tests/fixtures/addon.lua')
local M={F=F}
local power={WARRIOR=1,ROGUE=3,HUNTER=0}
local families={
 [78]={78,284,285,1608,11564,11565,25286,30324},[1752]={1752,1757,1758,1759,1760,8621,11293,11294,26861,26862},
 [2098]={2098,6760,6761,6762,8623,8624,11299,11300,31016,26865},[1978]={1978,13549,13550,13551,13552,13553,13554,13555,25295,27016},
 [3044]={3044,14281,14282,14283,14284,14285,14286,14287,27019},[12294]={12294,21551,25248,30330},[23881]={23881,23892,23894,30335},
}
local packs={WARRIOR={'Modules/RotationMaster_Warrior/tbc/blocks.lua','Modules/RotationMaster_Warrior/tbc/warrior-dps-wowsims.lua','Modules/RotationMaster_Warrior/tbc/warrior-dps-icyveins.lua','Modules/RotationMaster_Warrior/tbc/warrior-protection-wowhead.lua','Modules/RotationMaster_Warrior/tbc/warrior-protection-icyveins.lua'},
 ROGUE={'Modules/RotationMaster_Rogue/tbc/blocks.lua','Modules/RotationMaster_Rogue/tbc/rogue-dps-wowsims.lua','Modules/RotationMaster_Rogue/tbc/rogue-dps-wowhead.lua'},
 HUNTER={'Modules/RotationMaster_Hunter/tbc/blocks.lua','Modules/RotationMaster_Hunter/tbc/hunter-ranged-wowsims.lua','Modules/RotationMaster_Hunter/tbc/hunter-ranged-wowhead.lua'}}
M.packs=packs
-- Every action/aura ID the premades name, so the catalog and bar know them.
local ids={WARRIOR={6603,6673,469,2687,6552,72,845,78,12328,12292,1719,100,34428,20252,29801,1680,6343,5308,7384,772,23881,12294,1715,20243,7386,23922,6572,1160,99,2565,12975,871},
 ROGUE={6603,1752,2098,5171,1943,53,8676,703,1833,5938,1766,5277,14251,13877,13750,14177,1329,16511,14278,14183,2818},
 HUNTER={75,6603,2973,1495,19306,1130,19434,1978,3043,3044,2643,34120,13163,13165,5118,13159,13161,20043,34074,19506,883,982,136,34026,19574,3045,23989,34490}}
function M.fixture(class,options)
 options=options or {}
 local f=F.new(5,1,class);local a,e=f.addon,f.env
 a.db.profile=options.profile or {rotations={},itemsets={}};a.db.global.effects={}
 local s={class=class,level=options.level or 70,combat=true,targetCombat=true,exists=true,hostile=true,dead=false,moving=false,
  known={},usable={},nopower={},range={},cooldown={},mapped={},buffs={},debuffs={},petBuffs={},
  health=100,targetHealth=100,power=class=='ROGUE'and 100 or 0,maxPower=100,mana=100,points=0,stealth=false,cast=false,channel=false,
  targetCast=nil,targetInterruptible=true,form=1,forms=3,group=false,classification='normal',targetLevel=nil,targettarget='player',
  enemies={},autorepeat=false,active={},sinceAuto=nil,mainEnchant=false,offEnchant=false,offSpeed=nil,
  pet=false,petDead=false,petHealth=100,ttd=nil}
 for _,id in ipairs(ids[class])do s.known[id]=false end
 local names,ranks={},{}
 for _,id in ipairs(ids[class])do names[id]='Spell '..id;ranks[id]='Rank 1' end
 for base,list in pairs(families)do for rank,id in ipairs(list)do names[id]='Spell '..base;ranks[id]='Rank '..rank end end
 local function highest(name)
  for base,list in pairs(families)do if name=='Spell '..base then for i=#list,1,-1 do if s.known[list[i]] then return list[i] end end;return nil end end
  local id=tonumber(name:match('^Spell (%d+)$'));return id and s.known[id] and id or nil
 end
 local function aura(list,index,unit)local x=list[index];if not x then return end
  return {spellId=x.id,name=names[x.id] or ('Spell '..x.id),sourceUnit=x.source==nil and 'player' or x.source or nil,expirationTime=x.expires or 0,duration=x.duration or 0,applications=x.stacks or 0}end
 e.Enum.PowerType.ComboPoints=4
 e.UnitExists=function(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet
  elseif unit=='targettarget'then return s.exists and s.targettarget~=nil elseif unit:match('^nameplate%d+$')then return s.enemies[tonumber(unit:match('%d+'))]~=nil end
  return false end
 e.UnitIsUnit=function(x,y)if x=='targettarget'and y=='player'then return s.targettarget=='player'end;return x==y end
 e.UnitGUID=function(unit)local n=unit:match('^nameplate(%d+)$');if n then return 'Creature-'..n end;return unit=='player'and'Player-test'or'Creature-target'end
 e.UnitIsEnemy=function(_,unit)return unit~='player'and unit~='pet'end
 e.UnitLevel=function(unit)if unit=='target'then return s.targetLevel or s.level end;return s.level end
 e.UnitClassification=function()return s.classification end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;return s.targetCombat end
 e.UnitCanAttack=function()return s.hostile end;e.UnitIsDead=function()return s.dead end
 e.UnitIsDeadOrGhost=function(unit)if unit=='pet'then return s.petDead end;return unit=='target'and s.dead or false end
 e.UnitHasVehicleUI=function()return false end;e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.UnitHealth=function(unit)if unit=='target'then return s.targetHealth elseif unit=='pet'then return s.petHealth end;return s.health end
 e.UnitHealthMax=function()return 100 end
 e.UnitPowerType=function()return power[class]end
 e.UnitPower=function(unit,kind)if kind==0 then return s.mana end;return s.power end
 e.UnitPowerMax=function(unit,kind)if kind==4 then return 5 end;return 100 end
 e.GetComboPoints=function(unit,target)assert(unit=='player'and target=='target');return s.points end
 e.IsStealthed=function()return s.stealth end
 e.GetShapeshiftForm=function()return s.form end;e.GetNumShapeshiftForms=function()return s.forms end
 e.IsInGroup=function()return s.group end;e.IsInRaid=function()return false end
 e.GetUnitName=function()return 'Pet'end
 e.UnitCastingInfo=function(unit)
  if unit=='player'then if s.cast then return 'Cast in progress',nil,nil,99000,101000 end;return end
  if unit=='target'and s.targetCast then return s.targetCast,nil,nil,99000,101000,false,'cast',not s.targetInterruptible end
 end
 e.UnitChannelInfo=function(unit)if unit=='player'and s.channel then return 'Channel in progress',nil,nil,99000,101000,false,false end end
 e.GetWeaponEnchantInfo=function()return s.mainEnchant,1000,0,1,s.offEnchant,1000,0,1 end
 e.UnitAttackSpeed=function()return 2.6,s.offSpeed end
 -- Enemies with nameplates: each entry is that enemy's native threat status for you (false = not on its table).
 e.UnitThreatSituation=function(_,unit)local n=tonumber(unit:match('^nameplate(%d+)$') or '');local v=n and s.enemies[n];if v==false then return nil end;return v end
 e.IsSpellKnown=function(id)return s.known[id]==true end
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local hit=highest(id);return hit and {name=names[hit],spellID=hit,subtext=ranks[hit]}or nil end
   return {name=names[id] or ('Spell '..id),spellID=id,subtext=ranks[id] or ''}end,
  IsCurrentSpell=function(id)return s.active[id]==true end,
  SpellHasRange=function(id)return id~=6673 and id~=2687 and id~=12328 and id~=12292 and id~=1719 and id~=6343 and id~=1680 and id~=2565 and id~=12975 and id~=871 and id~=1160 and id~=5171 and id~=13877 and id~=13750 and id~=14177 and id~=5277 and id~=14183 and not(id>=13159 and id<=13165)and id~=5118 and id~=20043 and id~=34074 and id~=19506 and id~=883 and id~=982 and id~=3045 and id~=23989 and id~=19574 end,
  IsSpellInRange=function(id)if id==6603 then return s.range[6603]~=false end;return s.range[id]~=false end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.nopower[id],s.nopower[id]==true end,
  IsAutoRepeatSpell=function(id)return s.autorepeat and id==75 end,
  GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  if unit=='pet'then return aura(s.petBuffs,index,unit)end
  if filter=='HELPFUL'then return aura(s.buffs,index,unit)end;return aura(s.debuffs,index,unit)end}
 -- The shipped error boundary wraps condition callbacks (as in game).
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
  'Core/unit_state_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
  'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/range.lua','Conditions/spatial.lua',
  'Conditions/weapon.lua','Conditions/unit_states.lua'}) do f.load(path) end
 for _,path in ipairs(options.packs or packs[class])do f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function() return 'Rotation Master test' end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
 f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function() end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.spellHistory={}
 a.GetConditionHealthForecast=function(_,unit,health)assert(unit=='target'and health==0);if s.ttd==nil then return false end;return s.ttd end
 for id in pairs(names)do a.SpellCatalog:UpdateSpell(id)end
 assert(a:InitializeRotationLibrary())
 -- Spell history is rebuilt from the modeled time since the last Auto Shot.
 -- The nameplate snapshot is rebuilt from the modeled enemies.
 local function sync()
  a.spellHistory=s.sinceAuto and {{spell=75,time=100-s.sinceAuto}} or {};a.longtermCache={}
  a.unitsInRange={};for n in pairs(s.enemies)do a.unitsInRange['Creature-'..n]={unit='nameplate'..n}end
 end
 f.sync=sync
 return f,s,names
end
function M.body(a,id)local view=assert(a:GetDefaultRotation(id),'missing '..id);return view.envelope.body end
-- The real sequence executor with real predicates and readiness; returns the first ready mapped action.
function M.first(f,s,id)
 local a=f.addon;f.sync();local ready=a:NewActionReadiness(100);local selected
 local result=a:EvaluateRotationSequence(M.body(a,id),function(c,ctx)return a:evaluateConditionResult(c,ctx)end,function(step)
  if a:evaluateCondition(step.conditions) then
   for _,spell in ipairs(a:GetSpellIds(step))do if s.mapped[spell]~=false and ready(step.type,spell)then selected=spell;return false end end
  end
 end)
 return selected,result
end
-- Independent reminders that would highlight: step ID suffix -> action (items: condition only).
function M.upkeep(f,s,id)
 local a=f.addon;f.sync();local ready=a:NewActionReadiness(100);local out={}
 for _,step in ipairs(M.body(a,id).cooldowns)do
  if a:evaluateCondition(step.conditions)then
   if step.type=='item'then out[step.id]=true
   else for _,spell in ipairs(a:GetSpellIds(step))do if s.mapped[spell]~=false and ready(step.type,spell)then out[step.id]=spell;break end end end
  end
 end
 return out
end
function M.switches(f,id)f.sync();return f.addon:evaluateCondition(M.body(f.addon,id).switch)==true end
function M.know(s,...)for _,id in ipairs({...})do s.known[id]=true end end
-- Real initialized publisher, auto-switch and bar discovery (as the existing pack suites do).
function M.publisher(f,s)
 local a,e=f.addon,f.env
 e.OFF='Off';e.securecallfunction=function(fn,...)return fn(...)end
 e.UnitFactionGroup=function()return 'Horde'end;e.GetLocale=function()return 'enUS'end
 e.UnitRace=function()return 'Orc','Orc'end;e.GetRealmName=function()return 'Premade Realm'end
 e.UnitNameUnmodified=function()return 'Premade Character'end;e.GetCurrentRegionName=function()return 'US'end;e.GetCurrentRegion=function()return 1 end
 e.strlenutf8=function(text)return #text end;e.GetItemInfo=function()end
 local create=e.CreateFrame;e.CreateFrame=function(...)local frame=create(...);frame.RegisterEvent=function()end;return frame end
 local fallback=e.LibStub;e.LibStub=false
 f.load('Libs/LibStub/LibStub.lua');f.load('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua');f.load('Libs/AceDB-3.0/AceDB-3.0.lua')
 local real=e.LibStub;setmetatable(real,{__call=function(self,name,silent)if self.libs[name]then return self:GetLibrary(name,silent)end;return fallback(name,silent)end})
 f.libraries['AceConsole-3.0'].RegisterChatCommand=function()end;f.libraries['AceConsole-3.0'].Printf=function()end
 f.libraries['LibDBIcon-1.0'].Register=function()end
 f.load('Core/itemset_services.lua');f.load('init.lua');f.load('validate.lua');f.load('profiler.lua')
 local saved=a.db.profile
 assert(a:OnInitialize(),'real publisher initialization failed');a.currentSpec=0
 -- AceDB installs a fresh profile; carry the modeled saved rotations and library state into it.
 a.db.profile.rotations,a.db.profile.rotationLibrary=saved.rotations,saved.rotationLibrary;assert(a:InitializeRotationLibrary())
 e.tinsert,e.tremove=table.insert,table.remove
 f.libraries['LibCustomGlow-1.0']={PixelGlow_Stop=function()end,AutoCastGlow_Stop=function()end,ButtonGlow_Stop=function()end}
 -- One button per known action across the five default Blizzard bars (60 slots).
 local actions,seen={},{}
 local function add(id)if not seen[id]then seen[id]=true;actions[#actions+1]=id end end
 for _,id in ipairs(ids[s.class])do add(id);for _,rank in ipairs(families[id]or{})do add(rank)end end
 assert(#actions<=60,'more modeled actions than default bar slots')
 local bars={'Action','MultiBarBottomLeft','MultiBarBottomRight','MultiBarRight','MultiBarLeft'}
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  e[bars[math.floor((slot-1)/12)+1]..'Button'..((slot-1)%12+1)]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns={IsAddOnLoaded=function()return false end};e.GetTime=function()return 100 end
 e.UnitName=function(unit)return unit end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 local glow,messages={},{}
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function()end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='premade-test';a.db.global.effects['premade-test']={type='texture'}
 a.currentRotation=nil;a:Fetch()
 a.db.profile.spell_history,a.db.profile.combat_history,a.db.profile.damage_history=10,10,10;a.db.profile.preview_spells=0
 a.currentSpec=0;a.inCombat=false;a.combatHistory={};a.damageHistory={}
 a.avail_announced={};a.announced={};a.skipAnnounce=true;a.lastCacheReport=100;a.db.profile.disable_buttons=false
 a.db.profile.disable_autoswitch=false;a.manualRotation=false
 f.load('profiler.lua');a.evaluationProfile=a:ProfiledCode()
 f.libraries['AceEvent-3.0'].SendMessage=function(_,kind,...)messages[#messages+1]={kind,...}end
 a.DispatchAnnouncement=function()end
 a.ScheduleRepeatingTimer=function()return 'modeled-publisher-timer'end;a.CancelTimer=function()end
 local function poll()f.sync();a:UpdateAutoSwitch();a:SwitchRotation();a:EvaluateNextActionInternal()end
 local function selected()local key=a.currentRotation;return key and key:match('^RM%-BUILTIN:(.+)$') or key end
 return poll,selected,glow,messages
end
return M
