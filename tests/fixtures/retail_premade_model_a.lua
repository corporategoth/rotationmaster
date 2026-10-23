-- Shared native model for the Retail premade scenario suites of Death Knight, Demon Hunter, Druid,
-- Evoker, Hunter, Mage and Monk (defaults_retail_<class>.lua). Real catalog, predicates,
-- composition, sequence executor, readiness, Assisted Combat reader and auto-select order on a
-- modeled Retail (Midnight 12.x, WOW_PROJECT_MAINLINE) client. Retail stores rotations per
-- specialization ID, so every helper reads the fixture's current spec (a.currentSpec).
-- RM classes Retail as combatDataPolicy=restricted and never auto-selects a Built In there;
-- scenarios run on a synthetic Retail context whose policy is 'probe' (as tests/default_corpus.lua
-- does for its synthetic families). M.new(class,spec,{policy='restricted'}) keeps the real policy.
-- C_AssistedCombat is modeled from Blizzard's generated API documentation (Gethe/wow-ui-source live
-- e7aa82019d): s.suggest is GetNextCastSpell's answer (nil = nothing suggested), s.assisted=false
-- makes IsAvailable false. s.secrets() models Midnight combat: health, primary power, aura fields,
-- enemy casts and cooldown times become one secret sentinel; the never-secret cooldown flags,
-- secondary resources, own casts and the suggestion stay readable.
local F=dofile('tests/fixtures/addon.lua')
local M={}
local SECRET=setmetatable({},{__tostring=function()return 'secret'end})
M.SECRET=SECRET
local function packPaths(class)
 local result={};local stem=class:gsub('%-','%%-')
 for line in io.lines('RotationMaster.toc')do
  local path=line:gsub('\r',''):match('^%s*(Defaults/.-%.lua)%s*$')
  if path and(path=='Defaults/blocks/retail-'..class..'.lua'or path:match('^Defaults/retail/'..stem..'%-'))then result[#result+1]=path end
 end
 return result
end
M.packPaths=packPaths
-- class is the file stem ('death-knight'), token the class token ('DEATHKNIGHT').
function M.new(class,token,spec,options)
 options=options or{}
 local f=F.new(1,12,token);local a,e=f.addon,f.env
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
 e.Enum.PowerType.Essence=19;e.Enum.PowerType.Fury=17;e.Enum.PowerType.RunicPower=6;e.Enum.PowerType.Focus=2;e.Enum.PowerType.LunarPower=8
 local s={level=90,combat=true,targetCombat=true,hostile=true,friendly=false,dead=false,exists=true,moving=false,group=false,raid=false,
  vehicle=false,known={},usable={},range={},cooldown={},mapped={},power={},pet=false,petDead=false,
  cast=false,channel=false,repeatActive=false,current={},stealthed=false,classification='normal',creature='HUMANOID',enemies={},party={},
  health={player=100,target=100,pet=100},mana={player=100},energy=100,powerType=0,points=0,targetTarget='player',focus=nil,
  targetRange={0,5},targetLevel=90,swing=2.6,instance=nil,suggest=nil,assisted=true,secret=false,charges={},
  auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}}}
 local function hidden(value)if s.secret then return SECRET end;return value end
 local function enemy(unit)for _,entry in ipairs(s.enemies)do if entry.unit==unit then return entry end end end
 local function member(unit)return s.party[unit]end
 local function exists(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet
  elseif unit=='targettarget'then return s.exists and s.targetTarget~=nil elseif unit=='focus'then return s.focus~=nil end
  return enemy(unit)~=nil or member(unit)~=nil
 end
 e.UnitExists=exists;e.UnitLevel=function(unit)if unit=='target'then return s.targetLevel end;return s.level end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;return s.targetCombat end
 e.UnitCanAttack=function(_,unit)return unit=='target'and s.hostile end
 e.UnitIsFriend=function(_,unit)return unit=='player'or unit=='pet'or unit=='target'and s.friendly end
 e.UnitIsEnemy=function(_,unit)if unit=='target'then return s.hostile end;return enemy(unit)~=nil end
 e.UnitIsDead=function(unit)if unit=='pet'then return s.petDead end;return unit=='target'and s.dead end;e.UnitIsDeadOrGhost=e.UnitIsDead
 e.UnitIsUnit=function(x,y)
  if x==y then return true end
  if x=='targettarget'then return s.targetTarget==y end
  if x=='target'and y=='player'or x=='player'and y=='target'then return s.targetIsMe==true end
  return false
 end
 e.UnitClassification=function()return s.classification end
 local creatures={BEAST=1,DRAGONKIN=2,DEMON=3,ELEMENTAL=4,GIANT=5,UNDEAD=6,HUMANOID=7}
 e.UnitCreatureType=function()return s.creature,creatures[s.creature]end
 e.UnitHasVehicleUI=function()return s.vehicle end;e.C_PetBattles={IsInBattle=function()return false end}
 e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.IsStealthed=function()return s.stealthed end
 e.IsInInstance=function()return s.instance~=nil,s.instance or'none'end
 e.UnitAttackSpeed=function()return s.swing,nil end
 e.IsInGroup=function()return s.group or s.raid end;e.IsInRaid=function()return s.raid end
 e.UnitPlayerOrPetInParty=function(unit)return s.group and(unit=='player'or member(unit)~=nil or unit=='target'and s.friendly)end
 e.UnitPlayerOrPetInRaid=function()return false end
 e.UnitPosition=function(unit)if unit=='player'or member(unit)then return 0,0,0,1 end end
 e.UnitHealth=function(unit)if member(unit)then return hidden(member(unit).health)end;return hidden(s.health[unit]or 100)end
 e.UnitHealthMax=function()return 100 end
 e.UnitThreatSituation=function(_,unit)local entry=enemy(unit);return entry and entry.threat end
 -- Power: the primary bar (s.powerType, value s.energy; mana for type 0) is secret in Midnight
 -- combat; every other type is a secondary resource (runes, chi, arcane charges, combo points,
 -- essence) read from s.points and stays readable.
 e.UnitPowerType=function()return s.powerType end
 e.UnitPower=function(unit,kind)
  if kind==nil then kind=s.powerType end
  if kind==s.powerType then if kind==0 then return hidden(s.mana[unit]or 100)end;return hidden(s.energy)end
  if kind==0 then return hidden(s.mana[unit]or 100)end
  return s.points
 end
 e.UnitPowerMax=function(_,kind)if kind==nil then kind=s.powerType end;if kind==4 or kind==12 or kind==19 then return 5 elseif kind==5 then return 6 elseif kind==16 then return 4 end;return 100 end
 e.UnitGUID=function(unit)if unit=='player'then return 'Player-test'end;local entry=enemy(unit);if entry then return entry.guid end;return 'Creature-'..unit end
 e.UnitCastingInfo=function(unit)
  if unit=='player'and s.cast then return 'Manual cast','Manual cast',1,99000,102000,false,'cast-guid',false,1 end
  if unit=='target'and s.targetCast then return 'Enemy cast','Enemy cast',1,99000,102000,false,'enemy-guid',hidden(false),2 end
 end
 e.UnitChannelInfo=function(unit)if unit=='player'and s.channel then return 'Manual channel','Manual channel',1,99000,102000,false,false,1 end end
 e.Enum.SpellBookSpellBank={Player=0,Pet=1}
 e.C_SpellBook={IsSpellKnown=function(id,bank)return bank~=1 and s.known[id]==true end}
 e.C_CVar={GetCVar=function(name)assert(name=='nameplateMaxDistance');return '40'end}
 f.libraries['LibRangeCheck-3.0'].GetRange=function(_,unit)
  if unit=='target'then return s.targetRange[1],s.targetRange[2]end
  local entry=enemy(unit);if entry then return entry.range[1],entry.range[2]end
  if member(unit)then return 0,5 end
 end
 -- Cooldowns: s.cooldown[id] holds the remaining seconds (nil = ready). In secret mode the times
 -- are the sentinel and only the never-secret flags tell ready from cooling.
 local function cooldown(id)
  local remain=s.cooldown[id]
  if s.secret then return{startTime=SECRET,duration=SECRET,modRate=SECRET,isEnabled=true,isActive=remain~=nil,isOnGCD=false}end
  if remain==nil then return{startTime=0,duration=0,isEnabled=true,modRate=1,isActive=false}end
  return{startTime=100-(60-remain),duration=60,isEnabled=true,modRate=1,isActive=true,isOnGCD=false}
 end
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local n=tonumber(id:match('^Spell (%d+)$'));if n then return{name=id,spellID=n}end;return end
   return{name='Spell '..id,spellID=id}end,
  SpellHasRange=function(id)return s.range[id]~=nil end,
  IsSpellInRange=function(id,unit)if id==6603 then return s.targetRange[2]<=5 end;return s.range[id]end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
  GetSpellCooldown=cooldown,
  GetSpellCharges=function(id)local c=s.charges[id];if not c then return nil end
   if s.secret then return{currentCharges=SECRET,maxCharges=c.max,cooldownStartTime=SECRET,cooldownDuration=SECRET,chargeModRate=SECRET,isActive=c.current<c.max}end
   return{currentCharges=c.current,maxCharges=c.max,cooldownStartTime=c.current<c.max and 90 or 0,cooldownDuration=c.current<c.max and 20 or 0,chargeModRate=1,isActive=c.current<c.max}end,
  GetBaseSpell=function(id)return(s.base or{})[id]or id end,
  GetOverrideSpell=function(id)return(s.override or{})[id]or id end,
  IsAutoRepeatSpell=function()return s.repeatActive end,
  IsCurrentSpell=function(id)return s.current[id]==true end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  local list=s.auras[unit]and s.auras[unit][(filter or'HELPFUL'):match('^(%u+)')];local aura=list and list[index]
  if aura and s.secret and not aura.whitelisted then return{spellId=SECRET,name=SECRET,sourceUnit=SECRET,applications=SECRET,expirationTime=SECRET,duration=SECRET}end
  return aura end}
 e.C_AssistedCombat={
  IsAvailable=function()return s.assisted~=false,s.assisted==false and'Not available'or''end,
  GetNextCastSpell=function(check)s.assistedCheck=check;return s.suggest end,
  GetRotationSpells=function()return s.rotationSpells or{}end,
  GetActionSpell=function()return nil end}
 for _,path in ipairs({'Platform/inventory.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/talents.lua','Platform/assisted_combat.lua','Core/action_policy.lua',
  'Core/conditions.lua','Core/aura_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua',
  'Core/rotation_library.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua',
  'Conditions/debuffs.lua','Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/talent.lua',
  'Conditions/item.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua','Conditions/unit_states.lua','Conditions/range.lua','Conditions/misc.lua','Conditions/weapon.lua','Conditions/assisted.lua'})do f.load(path)end
 for _,path in ipairs(packPaths(class))do f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function()return 'Rotation Master test'end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.ScheduleTimer=function(_,callback)return callback end
 if(options.policy or'probe')~='restricted'then
  local real=a.Platform.GetClientInfo
  a.Platform.GetClientInfo=function(self)local info=real(self);assert(info.family=='retail');info.combatDataPolicy=options.policy or'probe';return info end
 end
 for _,definition in pairs(a.conditionDefinitions)do
  local evaluate=definition.evaluate
  if type(evaluate)=='function'then definition.evaluate=function(...)local matched,reason=evaluate(...);return matched,reason end end
 end
 assert(a:InitializeRotationLibrary())
 a.spellHistory={};a.currentSpec=spec
 s.learn=function(...)for _,id in ipairs({...})do s.known[id]=true;a.SpellCatalog:UpdateSpell(id)end end
 s.ranged=function(...)for _,id in ipairs({...})do s.range[id]=true end end
 s.setLevel=function(level)s.level=level;a.longtermCache={};a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 s.near=function(count,range,threat)
  s.enemies={};a.unitsInRange={}
  for i=1,count do local unit,guid='nameplate'..i,'Creature-np'..i;s.enemies[i]={unit=unit,guid=guid,range=range or{0,5},threat=threat or 0};a.unitsInRange[guid]={unit=unit}end
 end
 s.cooling=function(id,remain)s.cooldown[id]=remain end
 s.history=function(id,ago)table.insert(a.spellHistory,1,{spell=id,time=100-(ago or 1)})end
 s.buff=function(unit,id,extra)local list=s.auras[unit].HELPFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.debuff=function(unit,id,extra)local list=s.auras[unit].HARMFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.clearAuras=function()s.auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}}end
 s.secrets=function(on)s.secret=on~=false;e.issecretvalue=s.secret and function(v)return rawequal(v,SECRET)end or nil;a.longtermCache={}end
 return f,s
end
-- Helpers over one fixture; spec is the fixture's current specialization.
function M.rows(a)local byId={};for _,row in ipairs(a:ListDefaultRotations(a.currentSpec))do byId[row.id]=row end;return byId end
function M.row(a,id)local row=M.rows(a)[id];assert(row,'missing premade '..id);return row end
function M.switch(a,id)return a:evaluateConditionResult(M.row(a,id).envelope.body.switch).status end
-- Auto-select exactly as main does: built-in order by priority, first matching switch wins.
function M.selected(a)
 local spec=a.currentSpec;local rows=a:GetRuntimeRotations(spec);local byKey={}
 for _,row in ipairs(a:ListDefaultRotations(spec))do byKey[row.runtimeKey]=row.id end
 for _,key in ipairs(a:GetOrderedAutoSwitchRotations(spec,rows))do
  if a:evaluateConditionResult(rows[key].switch).status=='match'then return byKey[key]end
 end
end
-- First recommended action of a premade's rotation; returns the action ID and the result.
function M.first(a,s,id)
 local ready=a:NewActionReadiness(100);local chosen
 local result=a:EvaluateRotationSequence(M.row(a,id).envelope.body,function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,spell in ipairs(a:GetSpellIds(step)or{})do
   if s.mapped[spell]~=false and ready(step.type,spell)then chosen=spell;return false end
  end end
 end)
 return chosen,result
end
-- Independent reminders that would light: a set of action IDs.
function M.upkeep(a,s,id)
 local lit={};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(M.row(a,id).envelope.body.cooldowns)do
  if not step.disabled and a:evaluateConditionResult(step.conditions).status=='match'then
   for _,spell in ipairs(a:GetSpellIds(step)or{})do if s.mapped[spell]~=false and ready(step.type,spell)then lit[spell]=true;break end end
  end
 end
 return lit
end
-- Asserts the first action (nil for none) and, optionally, the sequence status.
function M.expect(a,s,id,want,status,label)
 local got,result=M.first(a,s,id)
 assert(got==want,(label or id)..': expected '..tostring(want)..', got '..tostring(got)..' ('..tostring(result.status)..')')
 if status then assert(result.status==status,(label or id)..': expected status '..status..', got '..tostring(result.status))end
 return result
end
-- Common checks for one class: every premade loads for its spec only, declares Retail, and is
-- listed but never auto-selected on the real restricted client.
function M.restricted(class,token,specs)
 for spec,ids in pairs(specs)do
  local f=M.new(class,token,spec,{policy='restricted'});local a=f.addon
  local rows=M.rows(a)
  for _,id in ipairs(ids)do
   local row=assert(rows[id],id..' not listed on the restricted client')
   assert(row.readOnly and row.builtin and not row.eligible,id..' eligible on the restricted client')
  end
  assert(M.selected(a)==nil,'a Built In auto-selected on the restricted Retail client')
  assert(a:GetRuntimeRotations(spec)and next(a:GetRuntimeRotations(spec))==nil,'restricted runtime is not empty')
 end
end
return M
