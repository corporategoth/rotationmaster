-- Scenario harness for the TBC Shaman, Druid and Paladin premades: the shipped blocks and
-- packs on the real catalog, condition predicates, readiness and sequence executor, with
-- native WoW APIs modeled from one state table. Health forecasts (TT_HEALTH), nameplate
-- counts (DISTANCE_COUNT) and group proximity are modeled at their documented seams.
local F=dofile('tests/fixtures/addon.lua')
local H={}
local packs={
 SHAMAN={'Modules/RotationMaster_Shaman/tbc/blocks.lua','Modules/RotationMaster_Shaman/tbc/shaman-enhancement-icyveins.lua','Modules/RotationMaster_Shaman/tbc/shaman-enhancement-wowsims.lua','Modules/RotationMaster_Shaman/tbc/shaman-elemental-icyveins.lua',
  'Modules/RotationMaster_Shaman/tbc/shaman-elemental-wowhead.lua','Modules/RotationMaster_Shaman/tbc/shaman-elemental-nextaction.lua','Modules/RotationMaster_Shaman/tbc/shaman-restoration.lua'},
 DRUID={'Modules/RotationMaster_Druid/tbc/blocks.lua','Modules/RotationMaster_Druid/tbc/druid-balance.lua','Modules/RotationMaster_Druid/tbc/druid-feral-icyveins.lua','Modules/RotationMaster_Druid/tbc/druid-feral-wowhead.lua','Modules/RotationMaster_Druid/tbc/druid-restoration.lua'},
 PALADIN={'Modules/RotationMaster_Paladin/tbc/blocks.lua','Modules/RotationMaster_Paladin/tbc/paladin-retribution-wowhead.lua','Modules/RotationMaster_Paladin/tbc/paladin-retribution-icyveins.lua','Modules/RotationMaster_Paladin/tbc/paladin-retribution-twist.lua',
  'Modules/RotationMaster_Paladin/tbc/paladin-protection-wowhead.lua','Modules/RotationMaster_Paladin/tbc/paladin-protection-icyveins.lua','Modules/RotationMaster_Paladin/tbc/paladin-holy.lua','Modules/RotationMaster_Paladin/tbc/paladin-holy-wowhead.lua'},
}
H.packs=packs
-- Rank families (base id first) for spells whose higher ranks the scenarios exercise.
local families={[403]={403,529,548,915,943,6041,10391,10392,15207,15208,25448,25449},[8042]={8042,8044,8045,8046,10412,10413,10414,25454},
 [5176]={5176,5177,5178,5179,5180,6780,8905,9912,26984,26985},[635]={635,639,647,1026,1042,3472,10328,10329,25292,27135,27136},[21084]={21084,20287,20288,20289},
 [465]={465,10290,643,10291,1032,10292,10293,27149}}
H.families=families
-- Equipment records {itemID, item class, subclass, equip location} for WEAPON_TYPE (s.gear[slot]).
H.GEAR={DAGGER={7001,2,15,'INVTYPE_WEAPON'},SWORD={7002,2,7,'INVTYPE_WEAPON'},AXE2H={7003,2,1,'INVTYPE_2HWEAPON'},SHIELD={7004,4,6,'INVTYPE_SHIELD'},
 STAFF={7005,2,10,'INVTYPE_2HWEAPON'},OFFHAND={7006,4,0,'INVTYPE_HOLDABLE'}}
-- FORM by spell: s.bar lists the stance-bar spells in slot order, s.form the active slot (0 none); s.shift(id).
function H.new(class,opts)
 opts=opts or {}
 local f=F.new(5,1,class);local a,e=f.addon,f.env
 a.db.profile.rotations={};a.db.profile.itemsets={};a.db.global.effects={};a.delayed_condition={}
 local s={level=70,talents={0,0,0},known={},combat=false,moving=false,near=true,group=false,raid=false,mana=1,power=0,powerMax=100,health=1,
  buffs={},debuffs={},target={hostile=true,health=1,level=70,classification='normal',creature=7},focus=nil,totems={},enchant={},speed=3.6,swing=nil,
  enemies=0,ttd=nil,history={},party={},combo=0,usable={},mapped={},cooldown={},now=100,form=0,bar={},gear={}}
 s.shift=function(id)if id==0 then s.form=0;return end;for index,known in ipairs(s.bar)do if known==id then s.form=index;return end end;s.bar[#s.bar+1]=id;s.form=#s.bar end
 H.state=s
 local names={}
 local function name(id)for base,ids in pairs(families)do for _,x in ipairs(ids)do if x==id then return 'Spell '..base end end end;return 'Spell '..id end
 local function exists(unit)
  if unit=='player' then return true end
  if unit=='target' then return s.target~=nil end
  if unit=='focus' then return s.focus~=nil end
  if unit=='targettarget' then return s.target~=nil and s.target.targetsMe~=nil end
  if unit:match('^party%d') then return s.party[tonumber(unit:match('%d+'))]~=nil end
  if unit:match('^nameplate%d') then return tonumber(unit:match('%d+'))<=s.enemies end
  return false
 end
 local function rec(unit)if unit=='target'then return s.target elseif unit=='focus'then return s.focus end end
 e.UnitExists=function(unit)return exists(unit)end
 e.UnitGUID=function(unit)if exists(unit)then return 'GUID-'..unit end end
 e.UnitLevel=function(unit)local r=rec(unit);return r and r.level or s.level end
 e.UnitAffectingCombat=function(unit)if unit=='player'then return s.combat end;local r=rec(unit);return r and r.combat or false end
 e.UnitCanAttack=function(_,unit)local r=rec(unit);if unit:match('^nameplate')then return true end;return r and r.hostile or false end
 e.UnitIsDead=function(unit)local r=rec(unit);return r and r.dead or false end
 e.UnitIsDeadOrGhost=e.UnitIsDead
 e.UnitIsFriend=function(_,unit)local r=rec(unit);if unit=='player'or unit:match('^party')then return true end;return r and not r.hostile and not r.enemy or false end
 e.UnitIsEnemy=function(_,unit)if unit:match('^nameplate')then return true end;local r=rec(unit);return r and (r.enemy or r.hostile) or false end
 e.UnitIsUnit=function(x,y)
  if x=='targettarget'and y=='player'then return s.target and s.target.targetsMe==true or false end
  if x=='target'and y=='focus'or x=='focus'and y=='target'then return s.target and s.target.isFocus==true or false end
  return x==y
 end
 e.UnitHealth=function(unit)local p=unit:match('^party(%d)');if p then return s.party[tonumber(p)]*1000 end;local r=rec(unit);return math.floor(((unit=='player'and s.health)or(r and r.health)or 1)*1000)end
 e.UnitHealthMax=function()return 1000 end
 e.UnitPowerType=function()return s.powerType or 0 end
 e.UnitPower=function(unit,kind)if unit~='player'then return 0 end;if kind==0 or kind==nil and(s.powerType or 0)==0 then return math.floor(s.mana*1000)end;return s.power end
 e.UnitPowerMax=function(unit,kind)if kind==0 or kind==nil and(s.powerType or 0)==0 then return 1000 end;return s.powerMax end
 e.GetComboPoints=function()return s.combo end
 e.UnitClassification=function(unit)local r=rec(unit);return r and r.classification or 'normal'end
 e.UnitCreatureType=function(unit)local r=rec(unit);return 'Creature',r and r.creature or 7 end
 e.UnitCastingInfo=function(unit)
  if unit=='player'then if s.cast then return 'Manual cast','',1,90000,110000,false,1,false,1 end;return end
  local r=rec(unit);if r and r.cast then return 'Enemy cast','',1,90000,110000,false,1,r.cast=='locked',1 end
 end
 e.UnitChannelInfo=function(unit)
  if unit=='player'then if s.channel then return 'Manual channel','',1,90000,110000,false,false,1 end;return end
  local r=rec(unit);if r and r.channel then return 'Enemy channel','',1,90000,110000,false,r.channel=='locked',1 end
 end
 e.GetUnitSpeed=function()return s.moving and 7 or 0 end
 e.IsInGroup=function()return s.group end;e.IsInRaid=function()return s.raid end
 e.UnitInParty=function()return s.group end;e.UnitInRaid=function()return s.raid and 1 or nil end
 e.UnitHasVehicleUI=function()return false end;e.C_PetBattles={IsInBattle=function()return false end}
 e.GetNumTotemSlots=function()return 4 end
 e.GetTotemInfo=function(slot)local t=s.totems[slot];if not t then return false,'',0,0,0 end;return true,name(t),s.now-1,60,1 end
 e.GetWeaponEnchantInfo=function()return s.enchant.main==true,1000,1,1,s.enchant.off==true,1000,1,1 end
 e.UnitAttackSpeed=function()return s.speed,nil end
 e.IsSpellKnown=function(id)return s.known[id]==true end
 e.GetNumTalentTabs=function()return 3 end
 e.GetShapeshiftForm=function()return s.form end;e.GetNumShapeshiftForms=function()return #s.bar end
 e.GetShapeshiftFormInfo=function(index)local id=s.bar[index];if id then return 136000,index==s.form,true,id end end
 e.GetInventoryItemID=function(_,slot)local item=s.gear[slot];return item and item[1]end
 e.GetInventoryItemLink=function(_,slot)local item=s.gear[slot];return item and('|Hitem:'..item[1]..':0:0:0:0:0:0|h')end
 e.GetItemInfoInstant=function(id)for _,item in pairs(s.gear)do if item[1]==id then return id,'Type','Subtype',item[4],1,item[2],item[3]end end end
 e.GetInventorySlotInfo=function(name)assert(name=='RANGEDSLOT');return 18 end
 e.C_SpecializationInfo={GetSpecializationInfo=function(index)return 200+index,'Tree '..index,'Description',1,nil,nil,s.talents[index],'Background',99,true end}
 e.C_CVar={GetCVar=function(key)if key=='nameplateMaxDistance'then return '41'end end}
 local function auraList(unit,filter)
  if unit=='player'then return filter:match('HARMFUL')and s.playerDebuffs or s.buffs end
  local r=rec(unit);if not r then return {} end
  return filter:match('HARMFUL')and s.debuffs or (unit=='focus'and r.buffs or s.targetBuffs) or {}
 end
 e.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
  local list=auraList(unit,filter or 'HELPFUL')or {};local x=list[index];if not x then return end
  return {name=name(x.id),spellId=x.id,sourceUnit=x.mine==false and 'party1' or 'player',applications=x.stacks or 0,duration=30,expirationTime=s.now+(x.remain or 20),dispelName=x.dispel}
 end}
 e.C_Spell={GetSpellInfo=function(id)
  if type(id)=='string'then for base,ids in pairs(families)do if 'Spell '..base==id then for i=#ids,1,-1 do if s.known[ids[i]]then id=ids[i];break end end end end;if type(id)=='string'then id=tonumber(id:match('%d+'))end end
  if type(id)~='number'then return end;return {name=name(id),spellID=id,subtext=''}
 end,SpellHasRange=function()return true end,IsSpellInRange=function(id)if id==6603 then return s.near end;return true end,
 IsCurrentSpell=function(id)return s.active==id end,IsSpellUsable=function(id)return s.usable[id]~=false,false end,
 GetSpellCooldown=function(id)local c=s.cooldown[id];if c then return {startTime=s.now-1,duration=c+1,isEnabled=true,modRate=1}end;return {startTime=0,duration=0,isEnabled=true,modRate=1}end}
 e.GetTime=function()return s.now end
 f.libraries['LibRangeCheck-3.0'].GetRange=function(_,unit)if s.rangeUncertain then return 5,30 end;return 0,5 end
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Platform/talents.lua','Platform/totems.lua','Platform/unit_states.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua'})do f.load(path)end
 f.load('Core/build_context.lua')
 for line in io.lines('RotationMaster.toc')do local path=line:gsub('\r',''):match('^(Conditions/.-%.lua)$');if path then f.load(path)end end
 for _,path in ipairs(opts.packs or packs[class])do f.load(path)end
 f.load('Core/rotation_sequence.lua')
 for base,ids in pairs(families)do for _,id in ipairs(ids)do a.SpellCatalog:UpdateSpell(id)end end
 -- Modeled seams: forecast (time until death), nameplate snapshot and group proximity.
 a.GetConditionHealthForecast=function()if s.ttd==nil then return false end;return s.ttd end
 a.proximity_eval=function(_,cache,fn)for i in ipairs(s.party)do local _,why=fn(cache,'party'..i,5);if why then return nil,why end end;return true end
 a.spellHistory=s.history
 assert(a:InitializeRotationLibrary())
 return f,s
end
-- Lua 5.1 has no __pairs: give DISTANCE_COUNT a plain snapshot rebuilt from the state.
function H.sync(f,s)
 f.addon.longtermCache.conditionPlayerLevel=nil -- what PLAYER_LEVEL_UP does
 f.addon:InvalidateBuildContext() -- equipment and talents change without their notifications here
 local list={};for i=1,s.enemies do list['GUID-nameplate'..i]={unit='nameplate'..i}end;f.addon.unitsInRange=list
 f.addon.lastMainSwing=s.swing and (s.now-(s.speed-s.swing))or nil
 for _,ids in pairs(families)do for _,id in ipairs(ids)do f.addon.SpellCatalog:UpdateSpell(id)end end
 for id in pairs(s.known)do f.addon.SpellCatalog:UpdateSpell(id)end
end
function H.copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[H.copy(k)]=H.copy(x)end;return out end
function H.learn(f,s,...)for _,id in ipairs({...})do s.known[id]=true end;H.sync(f,s)end
function H.row(a,id)for _,r in ipairs(a:ListDefaultRotations(0))do if r.id==id then return r end end;error('missing pack '..id)end
function H.body(a,id)return H.row(a,id).envelope.body end
function H.switch(a,id)return a:evaluateConditionResult(H.body(a,id).switch).status end
-- Built In auto-select: enabled eligible packs by priority, then name; the first matching switch.
function H.selected(f,s)
 H.sync(f,s);local a=f.addon;local rows={}
 for _,r in ipairs(a:ListDefaultRotations(0))do if r.eligible and r.enabled then rows[#rows+1]=r end end
 table.sort(rows,function(x,y)local p,q=x.envelope.body.priority or 0,y.envelope.body.priority or 0;if p~=q then return p>q end;return x.id<y.id end)
 for _,r in ipairs(rows)do if a:evaluateConditionResult(r.envelope.body.switch).status=='match'then return r.id end end
end
-- main.lua's rank expansion for spell steps (main itself needs the full addon).
local function spellIds(a,step)if step.ranked then return {step.action}end;return a.SpellCatalog:GetAllSpellIds(step.action)or {step.action}end
H.spellIds=spellIds
-- First recommended action and the sequence result for a pack.
function H.first(f,s,id)
 H.sync(f,s);local a=f.addon;local ready=a:NewActionReadiness(s.now);local chosen
 local result=a:EvaluateRotationSequence(H.body(a,id),function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,x in ipairs(spellIds(a,step))do if s.mapped[x]~=false and s.known[x] and ready(step.type,x)then chosen=x;return false end end end
 end)
 return chosen,result
end
-- Independent upkeep reminders currently lit, as a set of base action IDs.
function H.upkeep(f,s,id)
 H.sync(f,s);local a=f.addon;local ready=a:NewActionReadiness(s.now);local lit={}
 for _,step in ipairs(H.body(a,id).cooldowns)do
  if not step.disabled and a:evaluateCondition(step.conditions)then for _,x in ipairs(spellIds(a,step))do if s.known[x] and ready(step.type,x)then lit[step.action]=true;break end end end
 end
 return lit
end
function H.step(body,id)
 local found
 local function walk(list)for _,st in ipairs(list or {})do if st.id==id then found=st end;walk(st.onTrue);walk(st.onFalse)end end
 walk(body.rotation);walk(body.cooldowns);return assert(found,'missing step '..id)
end
return H
