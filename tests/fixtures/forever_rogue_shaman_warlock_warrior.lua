-- Shared world model for the WoW Forever Rogue, Shaman, Warlock and Warrior premade scenario tests.
-- Forever is classed restricted, so packaged rotations never auto-select there; these scenarios run
-- the packs under a synthetic Forever context whose combat-data policy is 'probe' (options.restricted
-- keeps the real policy). Native WoW observations are modeled here; the real platform, conditions,
-- catalog, composition, sequence executor, readiness and initialized publisher run on top.
-- Rank families below are scenario samples, not a trainer schedule.
local F=dofile('tests/fixtures/addon.lua')
local M={F=F}
local power={WARRIOR=1,ROGUE=3,SHAMAN=0,WARLOCK=0}
local families={
 [1752]={1752,1757,1758,1759,1760,8621,11293,11294},[403]={403,529,548,915,943,6041,10391,10392,15207,15208},
 [686]={686,695,705,1088,1106,7641,11659,11660,11661,25307},[78]={78,284,285,1608,11564,11565,11566,11567,25286},
 [1240193]={1240193,1464,8820,11604,11605},[408490]={408490,1238299,1238300,1326047},
}
local packs={
 ROGUE={'Modules/RotationMaster_Rogue/forever/blocks.lua','Modules/RotationMaster_Rogue/forever/rogue-dps.lua','Modules/RotationMaster_Rogue/forever/rogue-subtlety-warcrafttavern.lua','Modules/RotationMaster_Rogue/forever/rogue-subtlety-wowhead.lua'},
 SHAMAN={'Modules/RotationMaster_Shaman/forever/blocks.lua','Modules/RotationMaster_Shaman/forever/shaman-restoration.lua','Modules/RotationMaster_Shaman/forever/shaman-elemental.lua','Modules/RotationMaster_Shaman/forever/shaman-enhancement.lua','Modules/RotationMaster_Shaman/forever/shaman-enhancement-wowhead.lua'},
 WARLOCK={'Modules/RotationMaster_Warlock/forever/blocks.lua','Modules/RotationMaster_Warlock/forever/warlock-dps.lua','Modules/RotationMaster_Warlock/forever/warlock-dps-icyveins.lua','Modules/RotationMaster_Warlock/forever/warlock-dps-wowhead.lua'},
 WARRIOR={'Modules/RotationMaster_Warrior/forever/blocks.lua','Modules/RotationMaster_Warrior/forever/warrior-protection.lua','Modules/RotationMaster_Warrior/forever/warrior-protection-warcrafttavern.lua','Modules/RotationMaster_Warrior/forever/warrior-dps.lua','Modules/RotationMaster_Warrior/forever/warrior-dps-warcrafttavern.lua'},
}
M.packs=packs
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
 for _,row in ipairs(a:ListDefaultRotations(0))do
  if row.applicability.class==class then local body=a:GetDefaultRotation(row.id).envelope.body;condition(body.switch);steps(body.rotation);steps(body.cooldowns)end
 end
 return spells,actions
end
function M.fixture(class,options)
 options=options or {}
 local f=F.new(18,12,class);local a,e=f.addon,f.env
 a.db.profile=options.profile or {rotations={},itemsets={}};a.db.global.effects={}
 local s={class=class,level=options.level or 60,combat=true,targetCombat=true,exists=true,hostile=true,friend=false,dead=false,moving=false,
  known={},usable={},nopower={},range={},cooldown={},mapped={},buffs={},debuffs={},targetBuffs={},petBuffs={},items={},totems={},
  health=100,targetHealth=100,power=class=='ROGUE'and 100 or 0,maxPower=100,mana=100,targetMana=0,points=0,stealth=false,cast=false,channel=false,
  targetCast=nil,targetInterruptible=true,form=1,forms=3,group=false,classification='normal',creature=7,targetLevel=nil,targettarget='player',
  threat=nil,enemies={},autorepeat=false,active={},mainEnchant=false,offEnchant=false,offSpeed=nil,
  pet=false,petDead=false,petHealth=100,ttd=nil,trees={0,0,0},nodes={}}
 local names,ranks={},{}
 local function highest(name)
  for base,list in pairs(families)do if name=='Spell '..base then for i=#list,1,-1 do if s.known[list[i]] then return list[i] end end;return nil end end
  local id=tonumber(name:match('^Spell (%d+)$'));return id and s.known[id] and id or nil
 end
 local function aura(list,index)local x=list[index];if not x then return end
  return {spellId=x.id,name=names[x.id] or ('Spell '..x.id),sourceUnit=x.source==nil and 'player' or x.source or nil,expirationTime=x.expires or 0,duration=x.duration or 0,
   applications=x.stacks or 0,dispelName=x.dispel}end
 e.Enum.PowerType.ComboPoints=4
 e.UnitExists=function(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet
  elseif unit=='targettarget'then return s.exists and s.targettarget~=nil elseif unit:match('^nameplate%d+$')then return s.enemies[tonumber(unit:match('%d+'))]~=nil end
  return false end
 e.UnitIsUnit=function(x,y)if x=='targettarget'and y=='player'then return s.targettarget=='player'end;return x==y end
 e.UnitGUID=function(unit)local n=unit:match('^nameplate(%d+)$');if n then return 'Creature-'..n end;return unit=='player'and'Player-test'or'Creature-target'end
 e.UnitIsEnemy=function(_,unit)if unit=='target'then return s.hostile end;return unit~='player'and unit~='pet'end
 e.UnitIsFriend=function(_,unit)if unit=='target'then return s.friend end;return unit=='player'or unit=='pet'end
 e.UnitLevel=function(unit)if unit=='target'then return s.targetLevel or s.level end;return s.level end
 e.UnitClassification=function()return s.classification end
 e.UnitCreatureType=function()return 'Creature',s.creature end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;return s.targetCombat end
 e.UnitCanAttack=function()return s.hostile end;e.UnitIsDead=function()return s.dead end
 e.UnitIsDeadOrGhost=function(unit)if unit=='pet'then return s.petDead end;return unit=='target'and s.dead or false end
 e.UnitHasVehicleUI=function()return false end;e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.UnitHealth=function(unit)if unit=='target'then return s.targetHealth elseif unit=='pet'then return s.petHealth end;return s.health end
 e.UnitHealthMax=function()return 100 end
 e.UnitPowerType=function(unit)if unit=='target'then return 0 end;return power[class]end
 e.UnitPower=function(unit,kind)
  if unit=='target'then return kind==0 and s.targetMana or 0 end
  if kind==4 then return s.points elseif kind==0 then return s.mana end;return s.power end
 e.UnitPowerMax=function(unit,kind)if kind==4 then return 5 end;return 100 end
 e.GetComboPoints=function()return s.points end
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
 -- Totem slots 1 Fire, 2 Earth, 3 Water, 4 Air: an entry is the remaining duration.
 e.GetNumTotemSlots=function()return 4 end
 e.GetTotemInfo=function(slot)local left=s.totems[slot];if not left then return false,'',0,0,0 end;return true,'Totem',100,left,136000 end
 e.GetItemCount=function(id)return s.items[id] or 0 end
 -- One backpack whose slots hold the modeled item stacks (item ID -> count).
 local function stacks()local list={};for id,count in pairs(s.items)do if count>0 then list[#list+1]={itemID=id,stackCount=count}end end
  table.sort(list,function(x,y)return x.itemID<y.itemID end);return list end
 e.NUM_BAG_SLOTS,e.NUM_TOTAL_EQUIPPED_BAG_SLOTS=0,0
 e.C_Container={GetContainerNumSlots=function(bag)return bag==0 and 16 or 0 end,GetContainerItemInfo=function(bag,slot)if bag==0 then return stacks()[slot]end end}
 -- Enemies with nameplates: each entry is that enemy's native threat status for you (false = not on its table).
 e.UnitThreatSituation=function(_,unit)
  if unit=='target'then return s.threat end
  local n=tonumber(unit:match('^nameplate(%d+)$') or '');local v=n and s.enemies[n];if v==false then return nil end;return v end
 e.IsSpellKnown=function(id)return s.known[id]==true end
 -- Forever talents (C_ClassTalents/C_Traits, as the Camelot talent frame reads them): the three classic
 -- trees are node groups of one trait tree, in display order. s.trees = points per tree, s.nodes[node] =
 -- a node's rank (absent: not in the tree), s.config=false = no active config yet (below level 10).
 e.C_ClassTalents={GetActiveConfigID=function()if s.config==false then return nil end;return 7 end}
 e.C_Traits={GetConfigInfo=function()return{ID=7,type=1,name='Loadout',treeIDs={900}}end,
  GetGroupDisplayInfoByTreeID=function()local list={};for i=1,3 do list[i]={groupID=10+i,treeID=900,orderIndex=i-1,displayName='Tree '..i,icon=i}end;return list end,
  GetGroupCurrencyInfo=function(_,ids)local list={};for i,id in ipairs(ids)do list[i]={traitNodeGroupID=id,currencyInfos={{spent=s.trees[id-10]or 0}}}end;return list end,
  GetNodeInfo=function(_,node)local rank=s.nodes[node];if rank==nil then return{ID=0,activeRank=0,maxRanks=0,entryIDs={}}end
   return{ID=node,activeRank=rank,ranksPurchased=rank,maxRanks=5,entryIDs={node*10},isVisible=true}end}
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local hit=highest(id);return hit and {name=names[hit],spellID=hit,subtext=ranks[hit]}or nil end
   return {name=names[id] or ('Spell '..id),spellID=id,subtext=ranks[id] or ''}end,
  IsCurrentSpell=function(id)return s.active[id]==true end,
  SpellHasRange=function(id)return s.range[id]~=nil end,
  IsSpellInRange=function(id)if id==6603 then return s.range[6603]~=false end;return s.range[id]~=false end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.nopower[id],s.nopower[id]==true end,
  IsAutoRepeatSpell=function(id)return s.autorepeat and id==5019 end,
  GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  if unit=='pet'then return aura(s.petBuffs,index)end
  if unit=='target'then if filter=='HELPFUL'then return aura(s.targetBuffs,index)end;return aura(s.debuffs,index)end
  if filter=='HELPFUL'then return aura(s.buffs,index)end;return nil end}
 -- The shipped error boundary wraps condition callbacks (as in game).
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/totems.lua',
  'Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua','Core/unit_state_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua','Core/rotation_tags.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/debuffs.lua',
  'Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/range.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua',
  'Conditions/weapon.lua','Conditions/unit_states.lua','Conditions/totem.lua','Platform/inventory.lua','Conditions/item.lua',
  'Platform/talents.lua','Conditions/talent.lua','Core/build_context.lua'}) do f.load(path) end
 if not options.restricted then
  local get=a.Platform.GetClientInfo
  a.Platform.GetClientInfo=function(self)local info=get(self);assert(info.family=='forever');info.combatDataPolicy='probe';return info end
 end
 for _,path in ipairs(options.packs or packs[class])do f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function() return 'Rotation Master test' end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object) return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={}
 f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object) return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function() end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.spellHistory={}
 a.GetConditionHealthForecast=function(_,unit,health)assert(unit=='target'and health==0);if s.ttd==nil then return false end;return s.ttd end
 assert(a:InitializeRotationLibrary())
 local spells,actions=collect(a,class)
 spells[6603]=true
 for id in pairs(spells)do names[id]='Spell '..id;ranks[id]='Rank 1';s.known[id]=false end
 for base,list in pairs(families)do for rank,id in ipairs(list)do names[id]='Spell '..base;ranks[id]='Rank '..rank;if s.known[id]==nil then s.known[id]=false end end end
 for id in pairs(names)do a.SpellCatalog:UpdateSpell(id)end
 local function sync()
  a.spellHistory={};a.longtermCache={}
  a.unitsInRange={};for n in pairs(s.enemies)do a.unitsInRange['Creature-'..n]={unit='nameplate'..n}end
 end
 f.sync=sync;f.actions=actions;f.families=families
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
-- Talent points per tree ({1,2,3} in display order), read again after the talent notification.
function M.trees(f,s,points)s.trees=points;f.addon:InvalidateBuildContext('talents')end
-- A trait node's rank (nil: not in the tree).
function M.node(f,s,node,rank)s.nodes[node]=rank;f.addon:InvalidateBuildContext('talents')end
-- The pack the real auto-switch would pick: enabled, eligible, matching switch, highest priority.
function M.selected(f,s)
 local a=f.addon;f.sync()
 local best,priority
 for _,row in ipairs(a:ListDefaultRotations(0))do
  if row.eligible and row.applicability.class==s.class then
   local body=M.body(a,row.id)
   if a:evaluateCondition(body.switch)==true and (not priority or body.priority>priority) then best,priority=row.id,body.priority end
  end
 end
 return best
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
 assert(a:OnInitialize(),'real publisher initialization failed');a.currentSpec=0
 -- AceDB installs a fresh profile; carry the modeled saved rotations and library state into it.
 a.db.profile.rotations,a.db.profile.rotationLibrary=saved.rotations,saved.rotationLibrary;assert(a:InitializeRotationLibrary())
 e.tinsert,e.tremove=table.insert,table.remove
 f.libraries['LibCustomGlow-1.0']={PixelGlow_Stop=function()end,AutoCastGlow_Stop=function()end,ButtonGlow_Stop=function()end}
 -- One button per action across the five default Blizzard bars (60 slots); rank families share their base button.
 local actions={}
 for _,id in ipairs(f.actions)do actions[#actions+1]=id end
 for _,list in pairs(f.families)do for _,id in ipairs(list)do if s.known[id] and id~=list[1] then actions[#actions+1]=id end end end
 assert(#actions<=60,'more modeled actions than default bar slots: '..#actions)
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
