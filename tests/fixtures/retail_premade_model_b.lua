-- Shared native model for the Retail premade scenario suites of Paladin, Priest, Rogue, Shaman,
-- Warlock and Warrior (defaults_retail_<class>.lua). Real catalog, predicates, composition,
-- sequence executor, readiness, Assisted Combat reader and auto-select order on a modeled Retail
-- (WOW_PROJECT_MAINLINE, Midnight) client. RM classes Retail as combatDataPolicy=restricted and
-- never auto-selects a Built In there; scenarios therefore run on a synthetic Retail context whose
-- policy is 'probe' (as tests/default_corpus.lua does for its synthetic families), so the packs are
-- exercised as they would run if that policy is relaxed. M.new(class,{policy='restricted'}) keeps
-- the real policy. Storage is per specialization: every helper takes the specialization ID.
-- C_AssistedCombat is modeled from Blizzard's generated documentation as tests/assisted_combat.lua
-- does: s.suggest is GetNextCastSpell's answer, s.assisted=false makes IsAvailable() false.
-- s.secretCooldowns hides cooldown times behind a sentinel and keeps the never-secret flags
-- (tests/retail_combat_readiness.lua), as Retail does in combat.
local F=dofile('tests/fixtures/addon.lua')
local M={}
-- Each fixture's model state, so the slot helpers can put the player in the slot's specialization.
local states=setmetatable({},{__mode='k'})
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function()return 'secret'end})
-- The class's Built In module files (tools/builtin_modules.lua reads its TOC).
local function packPaths(class)
 return dofile('tools/builtin_modules.lua').paths({family='retail',class=(class:gsub('%-','')):upper()})
end
M.packPaths=packPaths
function M.new(class,options)
 options=options or{}
 local f=F.new(1,12,class:upper());local a,e=f.addon,f.env
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={}
 local s={level=90,combat=true,targetCombat=true,hostile=true,friendly=false,dead=false,exists=true,moving=false,group=false,raid=false,
  vehicle=false,known={},usable={},range={},cooldown={},active={},mapped={},power={},pet=false,petDead=false,
  cast=false,channel=false,repeatActive=false,current={},stealthed=false,classification='normal',creature='HUMANOID',enemies={},party={},
  health={player=100,target=100,pet=100},mana={player=100},energy=100,powerType=0,points=0,maxPoints=5,targetTarget='player',focus=nil,
  targetRange={0,5},targetLevel=90,swing=2.6,instance=nil,suggest=nil,assisted=true,secretCooldowns=false,enchants={},
  auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}}}
 local function enemy(unit)for _,entry in ipairs(s.enemies)do if entry.unit==unit then return entry end end end
 local function member(unit)return s.party[unit]end
 local function exists(unit)
  if unit=='player'then return true elseif unit=='target'then return s.exists elseif unit=='pet'then return s.pet
  elseif unit=='targettarget'then return s.exists and s.targetTarget~=nil elseif unit=='focus'then return s.focus~=nil end
  return enemy(unit)~=nil or member(unit)~=nil
 end
 e.issecretvalue=function(value)return rawequal(value,SECRET)end
 e.canaccessvalue=function(value)return not rawequal(value,SECRET)end
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
 e.UnitHealth=function(unit)if member(unit)then return member(unit).health end;return s.health[unit]or 100 end;e.UnitHealthMax=function()return 100 end
 -- Your threat status on the target follows whom it attacks (3: you hold it; s.targetThreat overrides).
 e.UnitThreatSituation=function(_,unit)
  if unit=='target'then if s.targetThreat~=nil then return s.targetThreat end;if not s.exists then return nil end;return s.targetTarget=='player'and 3 or 0 end
  local entry=enemy(unit);return entry and entry.threat end
 -- Power: the current type (mana 0, rage 1, energy 3...); combo points 4, soul shards 7 and holy
 -- power 9 read s.points (max s.maxPoints).
 e.UnitPowerType=function()return s.powerType end
 e.UnitPower=function(unit,kind)
  if kind==nil then kind=s.powerType end
  if kind==0 then return s.mana[unit]or 100 elseif kind==4 or kind==7 or kind==9 then return s.points end
  return s.energy
 end
 e.UnitPowerMax=function(_,kind)if kind==4 or kind==7 or kind==9 then return s.maxPoints end;return 100 end
 e.UnitGUID=function(unit)if unit=='player'then return 'Player-test'end;local entry=enemy(unit);if entry then return entry.guid end;return 'Creature-'..unit end
 -- s.castSpell / s.channelSpell name the spell in progress (CASTING_SPELL / CHANNELING_SPELL by ID).
 e.UnitCastingInfo=function(unit)if unit=='player'and s.cast then local name=s.castSpell and('Spell '..s.castSpell)or'Manual cast';return name,name,1,99000,102000,false,'cast-guid',false,s.castSpell or 1 end end
 e.UnitChannelInfo=function(unit)if unit=='player'and s.channel then local name=s.channelSpell and('Spell '..s.channelSpell)or'Manual channel';return name,name,1,99000,102000,false,false,s.channelSpell or 1 end end
 -- Retail keeps GetWeaponEnchantInfo only behind loadDeprecationFallbacks; C_PaperDollInfo is native.
 e.INVSLOT_MAINHAND,e.INVSLOT_OFFHAND=16,17
 e.C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot)
  if slot==16 and s.enchants.main==true then return {enchantID=1,remainingTimeMs=60000,hasExpirationTime=true,chargesRemaining=0} end
  if slot==17 and s.enchants.off==true then return {enchantID=2,remainingTimeMs=60000,hasExpirationTime=true,chargesRemaining=0} end end}
 e.Enum.SpellBookSpellBank={Player=0,Pet=1}
 e.Enum.PowerType.HolyPower,e.Enum.PowerType.Maelstrom,e.Enum.PowerType.Insanity,e.Enum.PowerType.Focus=9,11,13,2
 -- constants.lua ran before these Retail power types existed; rerun it so the class resource map
 -- (addon.points) is Retail's: Paladin reads Holy Power, as on the client.
 f.load('constants.lua');assert(a.points.PALADIN==9)
 e.C_SpellBook={IsSpellKnown=function(id,bank)return bank~=1 and s.known[id]==true end}
 e.C_CVar={GetCVar=function(name)assert(name=='nameplateMaxDistance');return '40'end}
 f.libraries['LibRangeCheck-3.0'].GetRange=function(_,unit)
  if unit=='target'then return s.targetRange[1],s.targetRange[2]end
  local entry=enemy(unit);if entry then return entry.range[1],entry.range[2]end
  if member(unit)then return 0,5 end
 end
 local function cooldown(id)
  if s.secretCooldowns then
   local cooling=s.cooldown[id]~=nil
   return{startTime=SECRET,duration=SECRET,modRate=SECRET,isEnabled=true,isActive=cooling,isOnGCD=false}
  end
  local record=s.cooldown[id]
  if record then return record end
  return{startTime=0,duration=0,isEnabled=true,modRate=1,isActive=false,isOnGCD=false}
 end
 e.C_Spell={GetSpellInfo=function(id)
   if type(id)=='string'then local n=tonumber(id:match('^Spell (%d+)$'));if n then return{name=id,spellID=n}end;return end
   return{name='Spell '..id,spellID=id}end,
  SpellHasRange=function(id)return s.range[id]~=nil end,
  IsSpellInRange=function(id,unit)if id==6603 then return s.targetRange[2]<=5 end;return s.range[id]end,
  IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
  GetSpellCooldown=cooldown,
  GetSpellCharges=function(id)local c=s.charges and s.charges[id];if c then return{currentCharges=c,maxCharges=2,cooldownStartTime=0,cooldownDuration=0,chargeModRate=1}end end,
  GetBaseSpell=function(id)return id end,GetOverrideSpell=function(id)return id end,
  IsAutoRepeatSpell=function()return s.repeatActive end,
  IsCurrentSpell=function(id)return s.current[id]==true end}
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  local list=s.auras[unit]and s.auras[unit][(filter or'HELPFUL'):match('^(%u+)')];return list and list[index]end}
 e.C_AssistedCombat={
  IsAvailable=function()return s.assisted~=false,s.assisted==false and 'Not available for this specialization'or''end,
  GetNextCastSpell=function()return s.suggest end,
  GetRotationSpells=function()return{}end,GetActionSpell=function()return nil end}
 -- The player's specialization, which the premades' SPECIALIZATION switches read (index 1 and its ID;
 -- an initial spec below 10 is reported the same way). s.respec(id) changes it mid-session.
 e.C_SpecializationInfo={GetSpecialization=function()if s.specID then return 1 end end,
  GetSpecializationInfo=function(index)if index==1 then return s.specID end end}
 for _,path in ipairs({'Platform/inventory.lua','Platform/unit_states.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/talents.lua','Platform/assisted_combat.lua','Core/action_policy.lua',
  'Core/conditions.lua','Core/aura_conditions.lua','Core/point_conditions.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua',
  'Core/rotation_library.lua','Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua',
  'Conditions/debuffs.lua','Conditions/combat.lua','Conditions/casting.lua','Conditions/channeling.lua','Conditions/stats.lua','Conditions/talent.lua',
  'Conditions/item.lua','Conditions/spatial.lua','Conditions/spatial_stats.lua','Conditions/unit_states.lua','Conditions/range.lua','Conditions/misc.lua','Conditions/weapon.lua','Conditions/assisted.lua',
  'Core/build_context.lua','Conditions/specialization.lua'})do f.load(path)end
 for _,path in ipairs(packPaths(class))do f.load(path)end
 -- The client has no BOOKTYPE_* globals (removed in 11.0) and reads addon metadata through C_AddOns.
 e.C_AddOns={GetAddOnMetadata=function()return 'Rotation Master test'end,IsAddOnLoaded=function()return false end}
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end};f.libraries['LibClassicDurations'].Register=function()end
 f.load('Core/rotation_sequence.lua');f.load('Core/rotation_selection.lua');f.load('main.lua')
 a.ScheduleTimer=function(_,callback)return callback end
 if(options.policy or'probe')~='restricted'then
  local real=a.Platform.GetClientInfo
  a.Platform.GetClientInfo=function(self)local info=real(self);assert(info.family=='retail');info.combatDataPolicy=options.policy or'probe';return info end
 end
 -- The client's Diagnostics call boundary keeps two results per leaf.
 for _,definition in pairs(a.conditionDefinitions)do
  local evaluate=definition.evaluate
  if type(evaluate)=='function'then definition.evaluate=function(...)local matched,reason=evaluate(...);return matched,reason end end
 end
 assert(a:InitializeRotationLibrary())
 a.spellHistory={}
 s.learn=function(...)for _,id in ipairs({...})do s.known[id]=true;a.SpellCatalog:UpdateSpell(id)end end
 s.ranged=function(...)for _,id in ipairs({...})do s.range[id]=true end end
 s.setLevel=function(level)s.level=level;a.longtermCache={};a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 s.respec=function(id)if s.specID~=id then s.specID=id;a:InvalidateBuildContext('talents')end end
 states[a]=s
 -- Nameplate enemies engaged with you (THREAT_COUNT; DISTANCE_COUNT at the given range, default 0-5).
 s.near=function(count,range,threat)
  s.enemies={};a.unitsInRange={}
  for i=1,count do local unit,guid='nameplate'..i,'Creature-np'..i;s.enemies[i]={unit=unit,guid=guid,range=range or{0,5},threat=threat or 0};a.unitsInRange[guid]={unit=unit}end
 end
 s.members=function(...)s.party={};s.group=true;for i,hp in ipairs({...})do s.party['party'..i]={health=hp}end end
 s.cooling=function(id,remain)s.cooldown[id]={startTime=100-(60-remain),duration=60,isEnabled=true,modRate=1,isActive=true,isOnGCD=false}end
 s.history=function(id,ago)table.insert(a.spellHistory,1,{spell=id,time=100-ago})end
 s.buff=function(unit,id,extra)local list=s.auras[unit].HELPFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.debuff=function(unit,id,extra)local list=s.auras[unit].HARMFUL;local aura={spellId=id,name='Spell '..id,sourceUnit='player'};for k,v in pairs(extra or{})do aura[k]=v end;list[#list+1]=aura end
 s.clearAuras=function()s.auras={player={HELPFUL={},HARMFUL={}},target={HELPFUL={},HARMFUL={}}}end
 return f,s
end
-- Helpers over one fixture; spec is the specialization slot (its ID).
function M.rows(a,spec)local byId={};for _,row in ipairs(a:ListDefaultRotations(spec))do byId[row.id]=row end;return byId end
function M.row(a,spec,id)local row=M.rows(a,spec)[id];assert(row,'missing premade '..id);return row end
-- Auto-select exactly as main does: built-in order by priority, first matching switch wins.
function M.selected(a,spec)
 states[a].respec(spec)
 local rows=a:GetRuntimeRotations(spec);local byKey={}
 for _,row in ipairs(a:ListDefaultRotations(spec))do byKey[row.runtimeKey]=row.id end
 for _,key in ipairs(a:GetOrderedAutoSwitchRotations(spec,rows))do
  if a:evaluateConditionResult(rows[key].switch).status=='match'then return byKey[key]end
 end
end
-- First recommended action of a premade's rotation; returns the action ID and the result.
function M.first(a,s,spec,id)
 s.respec(spec)
 local ready=a:NewActionReadiness(100);local chosen
 local result=a:EvaluateRotationSequence(M.row(a,spec,id).envelope.body,function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,spell in ipairs(a:GetSpellIds(step)or{})do
   if s.mapped[spell]~=false and ready(step.type,spell)then chosen=spell;return false end
  end end
 end)
 return chosen,result
end
-- Independent reminders that would light: a set of action IDs.
function M.upkeep(a,s,spec,id)
 s.respec(spec)
 local lit={};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(M.row(a,spec,id).envelope.body.cooldowns)do
  if not step.disabled and a:evaluateConditionResult(step.conditions).status=='match'then
   for _,spell in ipairs(a:GetSpellIds(step)or{})do if s.mapped[spell]~=false and ready(step.type,spell)then lit[spell]=true;break end end
  end
 end
 return lit
end
function M.expect(a,s,spec,id,want,status,label)
 local got,result=M.first(a,s,spec,id)
 assert(got==want,(label or id)..': expected '..tostring(want)..', got '..tostring(got)..' ('..tostring(result.status)..')')
 if status then assert(result.status==status,(label or id)..': expected status '..status..', got '..tostring(result.status))end
 return result
end
-- Checks every premade of a class: listed in every slot of the class, declared Retail and its own
-- specialization, eligible only there; the recommended one per slot auto-selects, disabled
-- references never do. specs: {[specID]={recommended id, other ids...}}.
function M.checkSlots(a,specs)
 for spec,ids in pairs(specs)do
  local rows=M.rows(a,spec)
  for other,otherIds in pairs(specs)do for _,id in ipairs(otherIds)do
   local row=assert(rows[id],id..' not listed in slot '..spec);local scope=row.applicability
   -- Applicability holds only load-time facts; the specialization is the switch (a respec takes effect live).
   assert(row.readOnly and row.builtin and #scope.families==1 and scope.families[1]=='retail'and scope.specs==nil,id..' scope')
   assert(scope.minLevel==nil and scope.maxLevel==nil,id..' level range')
   local switch=row.envelope.body.switch;assert(switch.type=='SPECIALIZATION'and switch.spec==other,id..' switch')
   if other==spec then
    assert(row.eligible or row.eligibilityReason=='disabled',id..' not eligible in its own slot: '..tostring(row.eligibilityReason))
   else
    assert(not row.eligible,id..' eligible in slot '..spec)
   end
  end end
  assert(M.selected(a,spec)==ids[1],'slot '..spec..' selected '..tostring((M.selected(a,spec)))..', expected '..ids[1])
 end
end
-- The Assisted step follows Blizzard's suggestion, falls through when there is none, and keeps
-- working with cooldown times secret (the never-secret flags decide readiness).
function M.checkAssisted(a,s,spec,id,suggestion)
 s.suggest=suggestion;M.expect(a,s,spec,id,suggestion,'selected','suggestion')
 s.secretCooldowns=true;M.expect(a,s,spec,id,suggestion,'selected','suggestion with cooldown times secret')
 s.cooling(suggestion,10);M.expect(a,s,spec,id,nil,'complete','a cooling suggestion is not shown')
 s.cooldown[suggestion]=nil;s.secretCooldowns=false
 s.suggest=nil;M.expect(a,s,spec,id,nil,'complete','nothing suggested')
 s.suggest=suggestion;s.assisted=false;M.expect(a,s,spec,id,nil,'complete','Assisted Combat unavailable');s.assisted=true
 s.cast=true;M.expect(a,s,spec,id,nil,'stopped','casting');s.cast=false
 s.channel=true;M.expect(a,s,spec,id,nil,'stopped','channelling');s.channel=false
end
-- On the real restricted client: listed and complete (every condition readable there),
-- the references disabled, and the highest-priority enabled premade of each slot auto-selected.
-- recommended maps a spec to the premade expected to auto-select there.
function M.checkRestricted(class,specs,learn,recommended)
 local f,s=M.new(class,{policy='restricted'});local a=f.addon;if learn then s.learn(unpack(learn))end
 local support=dofile('tests/fixtures/client_support.lua');support.install(f,{stubNatives=true})
 for spec,ids in pairs(specs)do
  local rows=M.rows(a,spec)
  for _,id in ipairs(ids)do assert(rows[id]and rows[id].readOnly,id..' not listed');support.complete(rows[id],id)end
  -- recommended[spec]==false: nothing auto-selects (only references ship for that slot).
  local want=recommended and recommended[spec];if want==nil then want=ids[1] end;if want==false then want=nil end
  assert(M.selected(a,spec)==want,'slot '..spec..' auto-selected '..tostring((M.selected(a,spec)))..', expected '..want)
 end
end
-- Before a specialization (below level 10) the game reports the class's initial specialization;
-- its Blizzard Assisted premade auto-selects for a level-4 character, follows the suggestion and
-- is complete on the real restricted client. learn[1] is the suggested spell.
function M.initial(class,spec,id,learn)
 local f,s=M.new(class);local a=f.addon;s.setLevel(4);s.learn(unpack(learn))
 local row=M.row(a,spec,id);local scope=row.applicability
 assert(scope.specs==nil and scope.minLevel==nil and scope.maxLevel==nil,id..' scope: load-time facts only')
 local switch=row.envelope.body.switch;assert(switch.type=='SPECIALIZATION'and switch.spec==spec,id..' switch')
 assert(M.selected(a,spec)==id,'initial spec auto-selected '..tostring((M.selected(a,spec))))
 for other,listed in pairs(M.rows(a,spec))do if other~=id then assert(not listed.eligible,other..' eligible in the initial spec')end end
 s.suggest=learn[1];M.expect(a,s,spec,id,learn[1],nil,'the Assisted suggestion')
 s.cast=true;M.expect(a,s,spec,id,nil,'stopped','casting');s.cast=false
 local g,gs=M.new(class,{policy='restricted'});local b=g.addon;gs.setLevel(4)
 local support=dofile('tests/fixtures/client_support.lua');support.install(g,{stubNatives=true})
 assert(support.complete(M.rows(b,spec)[id],id)=='eligible')
 assert(M.selected(b,spec)==id,'restricted initial spec auto-selected '..tostring((M.selected(b,spec))))
end
return M
