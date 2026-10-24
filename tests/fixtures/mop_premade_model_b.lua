-- Shared world model for the Mists of Pandaria Classic Priest, Rogue, Shaman, Warlock and Warrior
-- premade scenario tests (defaults_mop_<class>.lua). A modeled MoP Classic client (WOW_PROJECT_MISTS_CLASSIC,
-- LE_EXPANSION_LEVEL_CURRENT 4, family progression, combatDataPolicy probe, so Built Ins auto-select);
-- the real platform, conditions, catalog, composition, sequence executor, readiness and initialized
-- publisher run on top. Rotations are stored per talent group (dual spec 1/2): s.talentGroup, default 1.
-- MoP has no spell ranks, so every spell is its own family. Natives modeled per class:
--  POINT: s.points (Combo Points 4), s.orbs (Shadow Orbs 28), s.shards (Soul Shards 7),
--   s.fury (Demonic Fury 15), s.embers (Burning Embers 14, whole embers with a fraction); s.spec is the
--   specialization index C_SpecializationInfo.GetSpecialization returns (nil below 10).
--  TALENT grid: s.talents[index]=true (index = (tier-1)*3+column).
--  WEAPON_IMBUE / WEAPON: s.mainEnchant / s.offEnchant = enchant ID (or false); s.offSpeed for an off hand.
--  Totems: s.totems[slot]={left,name} or a number (remaining seconds); slots 1 Fire 2 Earth 3 Water 4 Air.
--  Party: s.members(...) party1..n at the given health percentages, all in range (PROXIMITY_*).
--  SPECIALIZATION: s.spec indexes the class's specialization IDs (M.SPECS); s.specID(id) sets it by ID.
--  FORM by spell: s.bar lists the stance-bar spells in slot order, s.form the active slot (0 none);
--   s.shift(id) activates a form by spell, adding it to the bar if missing.
--  WEAPON_TYPE: s.gear[16]/s.gear[17]={itemID,classID,subClassID,equipLoc} (M.DAGGER, M.SHIELD, ...).
--  Cast/channel identity and progress: s.castSpell / s.channelSpell (spell IDs), the channel running from
--   s.channelStart to s.channelEnd (seconds; GetTime is 100, default 99..101, so half done).
local F=dofile('tests/fixtures/addon.lua')
local M={F=F}
local MISTS=19
-- PowerTypeConstantsDocumentation.lua at 5.5.4.70531.
local POWER={Mana=0,Rage=1,Focus=2,Energy=3,ComboPoints=4,Runes=5,RunicPower=6,SoulShards=7,LunarPower=8,HolyPower=9,
 Alternate=10,Maelstrom=11,Chi=12,Insanity=13,BurningEmbers=14,DemonicFury=15,ArcaneCharges=16,Fury=17,Pain=18,Essence=19,
 Balance=26,ShadowOrbs=28}
local primary={WARRIOR=1,ROGUE=3,SHAMAN=0,WARLOCK=0,PRIEST=0}
-- Specialization IDs by index (C_SpecializationInfo.GetSpecializationInfo), Blizzard's order.
local SPECS={WARRIOR={71,72,73},PALADIN={65,66,70},HUNTER={253,254,255},ROGUE={259,260,261},PRIEST={256,257,258},
 DEATHKNIGHT={250,251,252},SHAMAN={262,263,264},MAGE={62,63,64},WARLOCK={265,266,267},MONK={268,270,269},DRUID={102,103,104,105}}
M.SPECS=SPECS
-- Equipment records {itemID, item class, subclass, equip location}: weapons are class 2, shields class 4/6.
M.DAGGER={7001,2,15,'INVTYPE_WEAPON'};M.SWORD={7002,2,7,'INVTYPE_WEAPON'};M.AXE2H={7003,2,1,'INVTYPE_2HWEAPON'}
M.SHIELD={7004,4,6,'INVTYPE_SHIELD'};M.STAFF={7005,2,10,'INVTYPE_2HWEAPON'};M.OFFHAND={7006,4,0,'INVTYPE_HOLDABLE'}
-- The class's Mists module files, in TOC order (tools/builtin_modules.lua).
function M.packs(class)return dofile('tools/builtin_modules.lua').paths({family='progression',class=class})end
-- Every spell an action or a condition of the class's premades names, collected from the expanded bodies.
local function collect(a,class)
 local spells,actions,seen={},{},{}
 local function condition(c)
  if type(c)~='table' then return end
  if type(c.spell)=='number' and c.type~='TOTEM' then spells[c.spell]=true end
  if c.type=='AND' or c.type=='OR' then for _,v in ipairs(c.value)do condition(v)end elseif c.type=='NOT' then condition(c.value)end
 end
 local function steps(list)
  for _,step in ipairs(list or {})do
   condition(step.conditions)
   if step.type=='spell' and type(step.action)=='number' then spells[step.action]=true;if not seen[step.action] then seen[step.action]=true;actions[#actions+1]=step.action end end
   steps(step.onTrue);steps(step.onFalse)
  end
 end
 for _,row in ipairs(a:ListDefaultRotations(1))do
  if row.applicability.class==class then local body=a:GetDefaultRotation(row.id).envelope.body;condition(body.switch);steps(body.rotation);steps(body.cooldowns)end
 end
 return spells,actions
end
function M.fixture(class,options)
 options=options or {}
 local f=F.new(options.project or MISTS,options.expansion or 4,class);local a,e=f.addon,f.env
 a.db.profile=options.profile or {rotations={},itemsets={}};a.db.global.effects={}
 local s={class=class,level=options.level or 90,talentGroup=1,spec=options.spec,combat=true,targetCombat=true,exists=true,hostile=true,friend=false,dead=false,moving=false,
  known={},usable={},nopower={},range={},cooldown={},charges={},mapped={},buffs={},debuffs={},targetBuffs={},petBuffs={},items={},totems={},talents={},
  health=100,targetHealth=100,power=class=='ROGUE'and 100 or 0,maxPower=100,mana=100,targetMana=0,points=0,orbs=0,shards=0,fury=0,embers=0,
  stealth=false,cast=false,channel=false,castSpell=nil,channelSpell=nil,
  targetCast=nil,targetInterruptible=true,form=0,forms=3,group=false,raid=false,party={},classification='normal',creature=7,targetLevel=nil,targettarget='player',
  threat=nil,enemies={},autorepeat=false,active={},mainEnchant=false,offEnchant=false,offSpeed=nil,
  pet=false,petDead=false,petHealth=100,petFamily=nil,ttd=nil,bar={},gear={},channelStart=99,channelEnd=101}
 if class=='WARRIOR'then s.bar={2457,71,2458}end
 s.specID=function(id)s.spec=nil;for index,known in ipairs(SPECS[class]or{})do if known==id then s.spec=index end end;assert(s.spec,'not a '..class..' specialization: '..tostring(id))end
 s.shift=function(id)if id==0 then s.form=0;return end;for index,known in ipairs(s.bar)do if known==id then s.form=index;return end end;s.bar[#s.bar+1]=id;s.form=#s.bar end
 local names={}
 local function aura(list,index)local x=list[index];if not x then return end
  return {spellId=x.id,name=names[x.id] or ('Spell '..x.id),sourceUnit=x.source==nil and 'player' or x.source or nil,expirationTime=x.expires or 0,duration=x.duration or 0,
   applications=x.stacks or 0,dispelName=x.dispel,isHelpful=list~=s.debuffs}end
 local types={};for name,id in pairs(POWER)do types[name]=id end;e.Enum.PowerType=types
 -- Platform/points.lua resolves power types when it loads (F.new loaded it with the short list): reload it.
 f.load('Platform/points.lua')
 local function member(unit)return s.party[unit]end
 e.UnitExists=function(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet
  elseif unit=='targettarget'then return s.exists and s.targettarget~=nil elseif unit:match('^nameplate%d+$')then return s.enemies[tonumber(unit:match('%d+'))]~=nil end
  return member(unit)~=nil end
 e.UnitIsUnit=function(x,y)if x=='targettarget'and y=='player'then return s.targettarget=='player'end;if x=='targettarget'then return s.targettarget==y end;return x==y end
 e.UnitGUID=function(unit)local n=unit:match('^nameplate(%d+)$');if n then return 'Creature-'..n end;return unit=='player'and'Player-test'or member(unit)and('Player-'..unit)or'Creature-target'end
 e.UnitIsEnemy=function(_,unit)if unit=='target'then return s.hostile end;return unit~='player'and unit~='pet'and not member(unit)end
 e.UnitIsFriend=function(_,unit)if unit=='target'then return s.friend end;return unit=='player'or unit=='pet'or member(unit)~=nil end
 e.UnitLevel=function(unit)if unit=='target'then return s.targetLevel or s.level end;return s.level end
 e.UnitClassification=function()return s.classification end
 e.UnitCreatureType=function()return 'Creature',s.creature end
 e.UnitCreatureFamily=function(unit)if unit=='pet'then return s.petFamily end end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;return s.targetCombat end
 e.UnitCanAttack=function(_,unit)if unit=='target'or unit==nil then return s.hostile end;return unit:match('^nameplate')~=nil end
 e.UnitIsDead=function(unit)if unit=='pet'then return s.petDead end;return unit=='target'and s.dead or false end
 e.UnitIsDeadOrGhost=e.UnitIsDead
 e.UnitHasVehicleUI=function()return false end;e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.C_PetBattles={IsInBattle=function()return false end}
 e.UnitHealth=function(unit)if unit=='target'then return s.targetHealth elseif unit=='pet'then return s.petHealth elseif member(unit)then return member(unit).health end;return s.health end
 e.UnitHealthMax=function()return 100 end
 e.UnitPowerType=function(unit)if unit=='target'then return 0 end;return primary[class]end
 -- Secondary resources by type; Burning Embers in fragments (10 per ember) when asked for them.
 e.UnitPower=function(unit,kind,fragments)
  if unit~='player'then return kind==0 and s.targetMana or 0 end
  if kind==nil then kind=primary[class]end
  if kind==4 then return s.points elseif kind==0 then return s.mana elseif kind==28 then return s.orbs elseif kind==7 then return s.shards
  elseif kind==15 then return s.fury elseif kind==14 then if fragments then return math.floor(s.embers*10+.5)end;return math.floor(s.embers)end
  return s.power end
 e.UnitPowerMax=function(unit,kind,fragments)
  if kind==4 then return 5 elseif kind==28 then return 3 elseif kind==7 then return 4 elseif kind==15 then return 1000
  elseif kind==14 then return fragments and 40 or 4 end;return s.maxPower end
 e.C_SpecializationInfo={GetSpecialization=function()return s.spec end,GetActiveSpecGroup=function()return s.talentGroup end,
  GetSpecializationInfo=function(index)return SPECS[class]and SPECS[class][index]end,
  GetTalentInfo=function(query)
   local index=(query.tier-1)*3+query.column
   return {name='Talent '..index,icon=136000,talentID=1000+index,spellID=2000+index,selected=s.talents[index]==true}
  end}
 e.GetNumTalentGroups=function()return 2 end
 e.IsStealthed=function()return s.stealth end
 e.GetShapeshiftForm=function()return s.form end;e.GetNumShapeshiftForms=function()return s.forms end
 e.GetShapeshiftFormInfo=function(index)local id=s.bar[index];if id then return 136000,index==s.form,true,id end end
 -- Equipment (WEAPON_TYPE): item IDs per slot and their instant class/subclass/equip location.
 e.GetInventoryItemID=function(_,slot)local item=s.gear[slot];return item and item[1]end
 e.GetInventoryItemLink=function(_,slot)local item=s.gear[slot];return item and('|Hitem:'..item[1]..':0:0:0:0:0:0|h')end
 e.GetItemInfoInstant=function(id)for _,item in pairs(s.gear)do if item[1]==id then return id,'Type','Subtype',item[4],1,item[2],item[3]end end end
 e.IsInGroup=function()return s.group or s.raid end;e.IsInRaid=function()return s.raid end
 e.UnitPlayerOrPetInParty=function(unit)return(s.group or s.raid)and(unit=='player'or member(unit)~=nil or unit=='target'and s.friend)end
 e.UnitPlayerOrPetInRaid=function()return false end
 e.UnitPosition=function(unit)if unit=='player'or member(unit)then return 0,0,0,1 end end
 e.GetUnitName=function()return 'Pet'end
 e.UnitCastingInfo=function(unit)
  if unit=='player'then if s.cast then local name=s.castSpell and('Spell '..s.castSpell)or'Cast in progress';return name,nil,nil,99000,101000,false,'cast',false,s.castSpell end;return end
  if unit=='target'and s.targetCast then return s.targetCast,nil,nil,99000,101000,false,'cast',not s.targetInterruptible end
 end
 e.UnitChannelInfo=function(unit)
  if unit=='player'and s.channel then local name=s.channelSpell and('Spell '..s.channelSpell)or'Channel in progress';return name,nil,nil,s.channelStart*1000,s.channelEnd*1000,false,false,s.channelSpell end
  if unit=='target'and s.targetChannel then return s.targetChannel,nil,nil,99000,101000,false,not s.targetInterruptible end
 end
 e.GetWeaponEnchantInfo=function()
  local main,off=s.mainEnchant,s.offEnchant
  return main and true or false,1000,0,type(main)=='number'and main or nil,off and true or false,1000,0,type(off)=='number'and off or nil end
 e.UnitAttackSpeed=function()return 2.6,s.offSpeed end
 -- Totem slots 1 Fire, 2 Earth, 3 Water, 4 Air: an entry is the remaining duration, or {left,name}.
 e.GetNumTotemSlots=function()return 4 end
 e.GetTotemInfo=function(slot)local entry=s.totems[slot];if not entry then return false,'',0,0,0 end
  if type(entry)=='table'then return true,entry[2]or'Totem',100,entry[1],136000 end;return true,'Totem',100,entry,136000 end
 e.GetItemCount=function(id)return s.items[id] or 0 end
 local function stacks()local list={};for id,count in pairs(s.items)do if count>0 then list[#list+1]={itemID=id,stackCount=count}end end
  table.sort(list,function(x,y)return x.itemID<y.itemID end);return list end
 e.NUM_BAG_SLOTS,e.NUM_TOTAL_EQUIPPED_BAG_SLOTS=0,0
 e.C_Container={GetContainerNumSlots=function(bag)return bag==0 and 16 or 0 end,GetContainerItemInfo=function(bag,slot)if bag==0 then return stacks()[slot]end end}
 -- Enemies with nameplates: each entry is that enemy's native threat status for you (false = not on its table).
 e.UnitThreatSituation=function(_,unit)
  if unit=='target'then return s.threat end
  local n=tonumber(unit:match('^nameplate(%d+)$') or '');local v=n and s.enemies[n];if v==false then return nil end;return v end
 e.IsSpellKnown=function(id,pet)if pet then return s.petKnown and s.petKnown[id]==true or false end;return s.known[id]==true end
 f.libraries['LibRangeCheck-3.0'].GetRange=function(_,unit)
  if member(unit)then return 0,5 end
  local n=tonumber((unit or''):match('^nameplate(%d+)$')or'');if n then return 0,5 end
  return 0,5
 end
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local n=tonumber(id:match('^Spell (%d+)$'));if n and s.known[n]then return {name=id,spellID=n,subtext=''}end;return nil end
   return {name=names[id] or ('Spell '..id),spellID=id,subtext=''}end,
  IsCurrentSpell=function(id)return s.active[id]==true end,
  SpellHasRange=function(id)return s.range[id]~=nil end,
  IsSpellInRange=function(id)if id==6603 then return s.range[6603]~=false end;return s.range[id]~=false end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.nopower[id],s.nopower[id]==true end,
  IsAutoRepeatSpell=function(id)return s.autorepeat and id==5019 end,
  GetSpellCharges=function(id)local c=s.charges[id];if c then return {currentCharges=c[1],maxCharges=c[2],cooldownStartTime=99,cooldownDuration=10,chargeModRate=1}end end,
  GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  if unit=='pet'then return aura(s.petBuffs,index)end
  if unit=='target'then if filter=='HELPFUL'then return aura(s.targetBuffs,index)end;return aura(s.debuffs,index)end
  if member(unit)then local m=member(unit);if filter=='HELPFUL'then return aura(m.buffs or {},index)end;return aura(m.debuffs or {},index)end
  if filter=='HELPFUL'then return aura(s.buffs,index)end;return aura(s.playerDebuffs or {},index)end}
 -- The shipped error boundary wraps condition callbacks (as in game).
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/totems.lua','Platform/talents.lua',
  'Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua','Core/unit_state_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
  'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/range.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua',
  'Conditions/weapon.lua','Conditions/build.lua','Core/build_context.lua','Conditions/specialization.lua','Conditions/equipment.lua','Conditions/unit_states.lua','Conditions/totem.lua','Conditions/talent.lua','Conditions/petspell.lua','Conditions/misc.lua',
  'Platform/inventory.lua','Conditions/item.lua'}) do f.load(path) end
 local get=a.Platform.GetClientInfo
 a.Platform.GetClientInfo=function(self)local info=get(self);assert(info.family=='progression'and info.expansion==(options.expansion or 4));
  if options.policy then info.combatDataPolicy=options.policy end;return info end
 for _,path in ipairs(options.packs or M.packs(class))do f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';-- No client has a GetAddOnMetadata global any more; metadata comes from C_AddOns.
 e.C_AddOns={GetAddOnMetadata=function()return 'Rotation Master test'end,IsAddOnLoaded=function()return false end}
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
 f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function() end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.spellHistory={};a.currentSpec=s.talentGroup
 a.GetConditionHealthForecast=function(_,unit,health)assert(unit=='target'and health==0);if s.ttd==nil then return false end;return s.ttd end
 assert(a:InitializeRotationLibrary())
 local spells,actions=collect(a,class)
 spells[6603]=true
 for id in pairs(spells)do names[id]='Spell '..id;s.known[id]=false end
 for id in pairs(names)do a.SpellCatalog:UpdateSpell(id)end
 local function sync()
  a.spellHistory=s.history or {};a.longtermCache={};a.currentSpec=s.talentGroup
  -- Specialization and equipment are cached until their notifications; the model changes them directly.
  a:InvalidateBuildContext()
  a.unitsInRange={};for n in pairs(s.enemies)do a.unitsInRange['Creature-'..n]={unit='nameplate'..n}end
 end
 -- Party members party1..n at the given health percentages (group implied).
 s.members=function(...)s.party={};s.group=true;for i,hp in ipairs({...})do s.party['party'..i]={health=hp}end end
 f.sync=sync;f.actions=actions
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
-- Independent reminders that would highlight: step ID -> action (items: condition only). Disabled steps never highlight.
function M.upkeep(f,s,id)
 local a=f.addon;f.sync();local ready=a:NewActionReadiness(100);local out={}
 for _,step in ipairs(M.body(a,id).cooldowns)do
  if not step.disabled and a:evaluateCondition(step.conditions)then
   if step.type=='item'then out[step.id]=true
   else for _,spell in ipairs(a:GetSpellIds(step))do if s.mapped[spell]~=false and ready(step.type,spell)then out[step.id]=spell;break end end end
  end
 end
 return out
end
function M.switches(f,id)f.sync();return f.addon:evaluateCondition(M.body(f.addon,id).switch)==true end
function M.know(s,...)for _,id in ipairs({...})do s.known[id]=true end end
-- The pack the real auto-switch would pick: enabled, eligible, matching switch, highest priority.
function M.selected(f,s)
 local a=f.addon;f.sync()
 local best,priority
 for _,row in ipairs(a:ListDefaultRotations(s.talentGroup))do
  if row.eligible and row.applicability.class==s.class then
   local body=M.body(a,row.id)
   if a:evaluateCondition(body.switch)==true and (not priority or body.priority>priority) then best,priority=row.id,body.priority end
  end
 end
 return best
end
-- The real auto-switch order (custom first, priority, name, id) over runtime rotations.
function M.ordered(f,s)
 local a=f.addon;f.sync();local rows=a:GetRuntimeRotations(s.talentGroup);local byKey={}
 for _,row in ipairs(a:ListDefaultRotations(s.talentGroup))do byKey[row.runtimeKey]=row.id end
 for _,key in ipairs(a:GetOrderedAutoSwitchRotations(s.talentGroup,rows))do
  if a:evaluateConditionResult(rows[key].switch).status=='match'then return byKey[key]end
 end
end
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
 assert(a:OnInitialize(),'real publisher initialization failed');a.currentSpec=s.talentGroup
 a.db.profile.rotations,a.db.profile.rotationLibrary=saved.rotations,saved.rotationLibrary;assert(a:InitializeRotationLibrary())
 e.tinsert,e.tremove=table.insert,table.remove
 f.libraries['LibCustomGlow-1.0']={PixelGlow_Stop=function()end,AutoCastGlow_Stop=function()end,ButtonGlow_Stop=function()end}
 -- One button per action across the default Blizzard bars (up to 72 slots).
 local actions={}
 for _,id in ipairs(f.actions)do actions[#actions+1]=id end
 local bars={'Action','MultiBarBottomLeft','MultiBarBottomRight','MultiBarRight','MultiBarLeft','MultiBar5'}
 assert(#actions<=#bars*12,'more modeled actions than default bar slots: '..#actions)
 for slot,id in ipairs(actions)do
  local button={id=id};function button:GetAttribute(key)if key=='type'then return 'action'elseif key=='action'then return slot end end
  e[bars[math.floor((slot-1)/12)+1]..'Button'..((slot-1)%12+1)]=button
 end
 e.HasAction=function(slot)return actions[slot]~=nil and s.mapped[actions[slot]]~=false end
 e.GetActionInfo=function(slot)return 'spell',actions[slot]end
 e.C_AddOns.IsAddOnLoaded=function()return false end;e.GetTime=function()return 100 end
 e.UnitName=function(unit)return unit end
 f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('buttons.lua')
 local glow,messages={},{}
 a.Glow=function(_,button,kind)glow[#glow+1]={button.id,kind}end;a.HideGlow=function()end
 a.verbose=function()end;a.debug=function()end;a.info=function()end
 a.db.profile.effect='premade-test';a.db.global.effects['premade-test']={type='texture'}
 a.currentRotation=nil;a:Fetch()
 a.db.profile.spell_history,a.db.profile.combat_history,a.db.profile.damage_history=10,10,10;a.db.profile.preview_spells=0
 a.currentSpec=s.talentGroup;a.inCombat=false;a.combatHistory={};a.damageHistory={}
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
-- Asserts the first action (nil for none) and, optionally, the sequence status.
function M.expect(f,s,id,want,status,label)
 local got,result=M.first(f,s,id)
 assert(got==want,(label or id)..': expected '..tostring(want)..', got '..tostring(got)..' ('..tostring(result.status)..')')
 if status then assert(result.status==status,(label or id)..': expected status '..status..', got '..tostring(result.status))end
 return result
end
-- Every premade of the class is scoped to Mists of Pandaria Classic: families progression, expansion 4..4.
function M.scoped(f,class)
 local count=0
 for _,row in ipairs(f.addon:ListDefaultRotations(1))do
  if row.applicability.class==class then
   local scope=row.applicability;count=count+1
   assert(#scope.families==1 and scope.families[1]=='progression' and scope.minExpansion==4 and scope.maxExpansion==4,row.id..' is not scoped to Mists')
   assert(row.id:match('^rm%.mop%.'),row.id)
  end
 end
 return count
end
return M
