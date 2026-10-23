-- Shared native model for the TBC premade scenario suites (defaults_tbc_<class>.lua).
-- Real catalog, predicates, composition, sequence executor, readiness and auto-select order;
-- the WoW client is modeled. Every spell is its own family ('Spell <id>'), so learned state is
-- per ID. Observations are modeled facts, not trainer schedules or native acceptance.
local F=dofile('tests/fixtures/addon.lua')
local M={}
-- The class's Built In module files (tools/builtin_modules.lua reads its TOC).
local function packPaths(class)
 return dofile('tools/builtin_modules.lua').paths({family='tbc',class=(class:gsub('%-','')):upper()})
end
M.packPaths=packPaths
function M.new(class,product)
 local f=F.new(product or 5,1,class:upper());local a,e=f.addon,f.env
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
 local s={level=70,combat=true,targetCombat=true,hostile=true,friendly=false,dead=false,exists=true,moving=false,group=false,raid=false,
  vehicle=false,known={},usable={},range={},cooldown={},mapped={},power={},talents={0,0,0},talent={},pet=false,
  cast=false,channel=false,repeatActive=false,classification='normal',enemies={},items={},
  health={player=100,target=100,pet=100},mana={player=100},
  auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}},channelSpell=nil,channelStart=99,channelEnd=102}
 local units={player=true,target=true}
 local function exists(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet end
  for _,enemy in ipairs(s.enemies)do if enemy.unit==unit then return true end end
  return false
 end
 e.UnitExists=exists;e.UnitLevel=function()return s.level end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;return s.targetCombat end
 e.UnitCanAttack=function(_,unit)return unit=='target'and s.hostile end
 e.UnitIsFriend=function(_,unit)return unit=='player'or unit=='pet'or unit=='target'and s.friendly end
 e.UnitIsEnemy=function(_,unit)if unit=='target'then return s.hostile end;for _,enemy in ipairs(s.enemies)do if enemy.unit==unit then return true end end;return false end
 e.UnitIsDead=function(unit)return unit=='target'and s.dead end;e.UnitIsDeadOrGhost=e.UnitIsDead
 e.UnitIsUnit=function(x,y)return x==y end
 e.UnitClassification=function()return s.classification end
 e.UnitHasVehicleUI=function()return s.vehicle end;e.C_PetBattles={IsInBattle=function()return false end}
 e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.IsInGroup=function()return s.group or s.raid end;e.IsInRaid=function()return s.raid end
 e.UnitHealth=function(unit)return s.health[unit]or 100 end;e.UnitHealthMax=function()return 100 end
 e.UnitPower=function(unit)return s.mana[unit]or 100 end;e.UnitPowerMax=function()return 100 end
 e.UnitPowerType=function()return 0 end
 e.UnitGUID=function(unit)if unit=='player'then return 'Player-test'end;for _,enemy in ipairs(s.enemies)do if enemy.unit==unit then return enemy.guid end end;return 'Creature-'..unit end
 e.UnitThreatSituation=function(_,unit)for _,enemy in ipairs(s.enemies)do if enemy.unit==unit then return enemy.threat end end end
 e.UnitCastingInfo=function(unit)if unit=='player'and s.cast then return 'Manual cast','Manual cast',1,99000,102000,false,'cast-guid',false,1 end end
 -- Channel identity and progress: s.channelSpell (a rank of it), running s.channelStart..s.channelEnd (GetTime is 100).
 e.UnitChannelInfo=function(unit)if unit=='player'and s.channel then local name=s.channelSpell and('Spell '..s.channelSpell)or'Manual channel';return name,name,1,s.channelStart*1000,s.channelEnd*1000,false,false,s.channelSpell or 1 end end
 e.IsSpellKnown=function(id)if s.knownError then error('learning unavailable')end;return s.known[id]==true end
 e.GetNumTalentTabs=function()return 3 end
 e.C_SpecializationInfo={GetSpecializationInfo=function(index)return 100+index,'Tree '..index,'Description',136048,nil,nil,s.talents[index],'Background',99,true end}
 e.GetTalentInfo=function(tree,index)local rank=s.talent[tree..':'..index]or 0;return 'Talent '..tree..':'..index,136048,1,1,rank,5,nil,nil,nil,nil,nil,tree*100+index end
 -- Backpack only: one slot per carried item ID (s.items[id]=count).
 e.NUM_BAG_SLOTS=0
 local function slots()local list={};for id,count in pairs(s.items)do if count>0 then list[#list+1]={itemID=id,stackCount=count}end end;table.sort(list,function(x,y)return x.itemID<y.itemID end);return list end
 e.C_Container={GetContainerNumSlots=function(bag)assert(bag==0);return #slots()end,GetContainerItemInfo=function(_,slot)return slots()[slot]end}
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local n=tonumber(id:match('^Spell (%d+)$'));if n then return{name=id,spellID=n}end;return end
   return{name='Spell '..id,spellID=id}end,
  SpellHasRange=function(id)return s.range[id]~=nil end,
  IsSpellInRange=function(id)return s.range[id]end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
  GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end,
  IsAutoRepeatSpell=function()return s.repeatActive end,
  IsCurrentSpell=function()return false end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  if s.auraError then error('auras unavailable')end
  local list=s.auras[unit]and s.auras[unit][filter or'HELPFUL'];return list and list[index]end}
 for _,path in ipairs({'Platform/inventory.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/talents.lua','Core/action_policy.lua',
  'Core/conditions.lua','Core/aura_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua',
  'Core/rotation_library.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua',
  'Conditions/debuffs.lua','Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/talent.lua',
  'Conditions/item.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua','Conditions/unit_states.lua','Conditions/range.lua'})do f.load(path)end
 for _,path in ipairs(packPaths(class))do f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function()return 'Rotation Master test'end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.ScheduleTimer=function(_,callback)return callback end
 assert(a:InitializeRotationLibrary())
 -- Learning a spell also teaches the catalog its identity; ranged spells default in range.
 s.learn=function(...)for _,id in ipairs({...})do s.known[id]=true;a.SpellCatalog:UpdateSpell(id)end end
 s.ranged=function(...)for _,id in ipairs({...})do s.range[id]=true end end
 s.setLevel=function(level)s.level=level;a.longtermCache={};a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 -- Engaged enemies for THREAT_COUNT: threat 0 = on the table, 2/3 = attacking you.
 s.engage=function(count,threat)
  s.enemies={};a.unitsInRange={}
  for i=1,count do local unit,guid='nameplate'..i,'Creature-np'..i;s.enemies[i]={unit=unit,guid=guid,threat=threat or 0};a.unitsInRange[guid]={unit=unit}end
 end
 s.buff=function(unit,id,extra)local list=s.auras[unit].HELPFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.debuff=function(unit,id,extra)local list=s.auras[unit].HARMFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.clearAuras=function()s.auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}}end
 return f,s
end
-- Helpers over one fixture.
function M.rows(a)local byId={};for _,row in ipairs(a:ListDefaultRotations(0))do byId[row.id]=row end;return byId end
function M.row(a,id)local row=M.rows(a)[id];assert(row,'missing premade '..id);return row end
function M.switch(a,id)return a:evaluateConditionResult(M.row(a,id).envelope.body.switch).status end
-- Auto-select exactly as main does: built-in order by priority, first matching switch wins.
function M.selected(a)
 local rows=a:GetRuntimeRotations(0);local byKey={}
 for _,row in ipairs(a:ListDefaultRotations(0))do byKey[row.runtimeKey]=row.id end
 for _,key in ipairs(a:GetOrderedAutoSwitchRotations(0,rows))do
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
-- Independent reminders that would light: a set of action IDs (items by their step ID).
function M.upkeep(a,s,id)
 local lit={};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(M.row(a,id).envelope.body.cooldowns)do
  if a:evaluateConditionResult(step.conditions).status=='match'then
   if step.type=='item'then lit[step.id]=true
   else for _,spell in ipairs(a:GetSpellIds(step)or{})do if s.mapped[spell]~=false and ready(step.type,spell)then lit[spell]=true;break end end end
  end
 end
 return lit
end
function M.status(a,id,stepId)
 local function find(list)for _,step in ipairs(list or{})do
  if step.id==stepId then return step end
  local found=find(step.onTrue)or find(step.onFalse);if found then return found end
 end end
 local body=M.row(a,id).envelope.body;local step=assert(find(body.cooldowns)or find(body.rotation),'missing step '..stepId)
 return a:evaluateConditionResult(step.conditions).status
end
return M
