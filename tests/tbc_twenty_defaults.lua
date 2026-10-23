-- The Shaman starter retired with the TBC Shaman premades (tests/defaults_tbc_shaman.lua);
-- only its Mage sibling remains here.
-- Native API fixtures exercise the real catalog, predicates, sequence and readiness.
-- Metadata/learned facts below are modeled observations, not trainer schedules.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_tbc_twenty_defaults.lua')
local function read(path)local f=assert(io.open(path));local text=f:read('*a');f:close();return text end
local families={
 [403]={403,529,548,915,943},[8042]={8042,8044,8045,8046},[324]={324,325,905},[8017]={8017,8018,8019,10399},
 [133]={133,143},[116]={116,205,837,7322,8406},[168]={168,7300,7301},[1459]={1459,1460,1461},[6603]={6603},
}
local identity={};for base,ids in pairs(families)do for rank,id in ipairs(ids)do identity[id]={name='Localized family '..base,spellID=id,subtext='Rank '..rank}end end
local function fixture(class,historical,profile)
 local f=F.new(5,1,class);local a,e=f.addon,f.env
 a.db.profile=profile or {rotations={},itemsets={}};a.db.global.effects={}
 local s={level=19,combat=false,targetCombat=false,moving=false,near=true,hostile=true,dead=false,vehicle=false,petbattle=false,
  known={},usable={},power={},cooldown={},range={},mapped={},auras={},enchanted=false}
 for _,base in ipairs(class=='SHAMAN'and{403,8042,324,8017,6603}or{133,116,1459,168})do s.known[base]=true end
 if class=='MAGE'then s.known[143],s.known[205]=true,true end
 e.UnitExists=function(unit)return unit=='player'or unit=='target'end
 e.UnitLevel=function()return s.level end;e.UnitHasVehicleUI=function()return s.vehicle end
 e.C_PetBattles={IsInBattle=function()return s.petbattle end}
 e.UnitAffectingCombat=function(unit)return unit=='player'and s.combat or unit~='player'and s.targetCombat end
 e.UnitCanAttack=function()return s.hostile end;e.UnitIsDead=function()return s.dead end
 e.GetUnitSpeed=function()return s.moving and 7 or 0 end;e.GetWeaponEnchantInfo=function()return s.enchanted end
 e.IsSpellKnown=function(id)if s.knownError then error('learned unavailable')end;return s.known[id]==true end
 e.C_UnitAuras={GetAuraDataByIndex=function(_,index)if s.auraError then error('aura unavailable')end;return s.auras[index]end}
 e.C_Spell={GetSpellInfo=function(id)
  if s.metadataError then error('metadata unavailable')end
  if type(id)=='string'then
   for base,ids in pairs(families)do if id=='Localized family '..base then
    for rank=#ids,1,-1 do if s.known[ids[rank]]then return identity[ids[rank]]end end
   end end
   return nil
  end
  return identity[id]
 end,SpellHasRange=function(id)return id~=324 and id~=325 and id~=905 and id~=8017 and id~=8018 and id~=8019 and id~=10399 and id~=168 and id~=7300 and id~=7301 and id~=1459 and id~=1460 and id~=1461 end,
 IsSpellInRange=function(id)if id==6603 then return s.near end;return s.range[id]~=false end,
 IsSpellUsable=function(id)return s.usable[id]~=false and not s.power[id],s.power[id]==true end,
 GetSpellCooldown=function(id)return s.cooldown[id]or{startTime=0,duration=0,isEnabled=true,modRate=1}end,
 IsCurrentSpell=function()return false end}
 for _,path in ipairs({'Platform/spells.lua','Platform/auras.lua','Platform/range.lua','Platform/actions.lua','Core/action_policy.lua','Core/conditions.lua','Core/aura_conditions.lua',
  'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/validation.lua','Data/catalog.lua','Data/diff.lua','Core/rotation_library.lua',
  'Conditions/common.lua','Conditions/spell.lua','Conditions/known_spell.lua','Conditions/character.lua','Conditions/buffs.lua','Conditions/combat.lua','Conditions/weapon.lua','Conditions/range.lua'})do f.load(path)end
 local path='Defaults/tbc/'..class:lower()..'-starter.lua'
 if historical then local chunk=assert(loadstring(restore(read(path),path),'@archived-e3fb19e-'..class));setfenv(chunk,e);chunk('rotationmaster',a)else f.load(path)end
 e.BOOKTYPE_SPELL,e.BOOKTYPE_PET='spell','pet';e.GetAddOnMetadata=function()return 'Rotation Master test'end;e.UnitGUID=function()return 'Player-test'end
 f.libraries['AceAddon-3.0']={NewAddon=function(_,object)return object end};f.libraries['AceEvent-3.0']={}
 f.libraries['LibDBIcon-1.0']={};f.libraries['LibSharedMedia-3.0']={};f.libraries['LibDataBroker-1.1']={NewDataObject=function(_,_,object)return object end}
 f.libraries['ThreatClassic-1.0']={Disable=function()end}
 f.load('Core/rotation_sequence.lua');f.load('main.lua')
 a.ScheduleTimer=function(_,callback,delay)assert(delay==.01);return callback end
 s.setLevel=function(level)s.level=level;a:PLAYER_LEVEL_UP('PLAYER_LEVEL_UP')end
 for id in pairs(identity)do a.SpellCatalog:UpdateSpell(id)end
 assert(a:InitializeRotationLibrary());return f,s
end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function row(a)return assert(a:ListDefaultRotations(0)[1])end
local function selected(a,s)
 local r=row(a);assert(r.eligible,r.eligibilityReason)
 local selected;local ready=a:NewActionReadiness(100)
 local result=a:EvaluateRotationSequence(r.envelope.body,function(c)return a:evaluateConditionResult(c)end,function(step)
  if a:evaluateCondition(step.conditions)then for _,id in ipairs(a:GetSpellIds(step))do
   if s.mapped[id]~=false and ready(step.type,id)then selected=id;return false end
  end end
 end)
 return selected,result
end
local function upkeep(a,s)
 local actions={};local ready=a:NewActionReadiness(100)
 for _,step in ipairs(row(a).envelope.body.cooldowns)do if a:evaluateCondition(step.conditions)then
  for _,id in ipairs(a:GetSpellIds(step))do if s.mapped[id]~=false and ready(step.type,id)then actions[#actions+1]=id;break end end
 end end
 return table.concat(actions,',')
end
test('both current previews cover twenty-through-twenty-nine with matching runtime switches',function()
 for _,class in ipairs({'MAGE'})do local f,s=fixture(class);local a=f.addon
  for level=19,29 do s.setLevel(level);assert(row(a).eligible,'level'..level..' missing for '..class);assert(a:evaluateCondition(row(a).envelope.body.switch));assert(selected(a,s))end
  s.setLevel(30);assert(not row(a).eligible);assert(not a:evaluateCondition(row(a).envelope.body.switch))
  s.level=0;assert(not row(a).eligible)
 end
end)
test('Mage twenty-six Frost ranks do not enable the other family when unusable or unmapped',function()
 local f,s=fixture('MAGE');local a=f.addon;s.level=26;s.known[7322],s.known[8406]=true,true
 assert(selected(a,s)==8406);s.mapped[8406]=false;assert(selected(a,s)==7322)
 s.mapped[8406]=nil;s.range[8406]=false;assert(selected(a,s)==7322);s.mapped[8406]=false
 s.cooldown[7322]={startTime=90,duration=30,isEnabled=true,modRate=1};assert(selected(a,s)==205)
 s.power[205]=true;assert(selected(a,s)==116);s.usable[116]=false;assert(not selected(a,s))
 s.known[8406],s.known[7322],s.known[205],s.known[116]=false,false,false,false
 assert(selected(a,s)==143,'actual early training branch behavior changed')
end)
test('Mage keeps Intellect and Frost Armor families through twenty-nine without replacing active buffs',function()
 local f,s=fixture('MAGE');local a=f.addon;s.level=29;s.known[1461],s.known[7301]=true,true
 assert(upkeep(a,s)=='1461,7301')
 s.auras={{spellId=1461,name=identity[1461].name,sourceUnit='party1'},{spellId=7301,name=identity[7301].name,sourceUnit='player'}}
 assert(upkeep(a,s)=='');assert(selected(a,s)==205)
 s.auras={};s.auraError=true;assert(upkeep(a,s)=='')
end)
test('both previews preserve motion engagement unknown learned-state and aura refusal',function()
 for _,class in ipairs({'MAGE'})do local f,s=fixture(class);local a=f.addon;s.level=20
  s.targetCombat=true;assert(not selected(a,s));s.targetCombat=false;s.hostile=false;assert(not selected(a,s));s.hostile=true
  if class=='MAGE'then s.moving=true;assert(not selected(a,s));s.moving=false end
  s.knownError=true;assert(not selected(a,s));assert(upkeep(a,s)=='');assert(a:evaluateConditionResult(row(a).envelope.body.switch).status=='unavailable')
 end
end)
test('unavailable spell metadata does not authorize higher-level upkeep under NOT',function()
 for _,class in ipairs({'MAGE'})do local f,s=fixture(class);s.level=24;s.auras={{spellId=999,name='Other readable aura',sourceUnit='player'}};s.metadataError=true;local actions=upkeep(f.addon,s);assert(actions==(class=='SHAMAN'and'8017'or''),class..':'..actions)end
end)
test('existing applicability still excludes nonplayer contexts foreign classes and other client families',function()
 for _,class in ipairs({'MAGE'})do local f,s=fixture(class);local a,e=f.addon,f.env;s.level=20;assert(row(a).eligible)
  s.vehicle=true;assert(not row(a).eligible);s.vehicle=false;s.petbattle=true;assert(not row(a).eligible);s.petbattle=false
  for _,family in ipairs({{1,12},{2,0},{19,4},{18,12}})do e.WOW_PROJECT_ID,e.LE_EXPANSION_LEVEL_CURRENT=family[1],family[2];assert(not row(a).eligible)end
  e.WOW_PROJECT_ID,e.LE_EXPANSION_LEVEL_CURRENT=5,1;e.UnitClass=function()return 'Warlock','WARLOCK'end;assert(#a:ListDefaultRotations(0)==0)
 end
end)
test('archived source clones keep their old cutoff and current clones require explicit adoption',function()
 for _,class in ipairs({'MAGE'})do
  local old,oldState=fixture(class,true);local a=old.addon;local pack=row(a);local id=assert(a:CloneDefaultRotation(0,pack.id,'Archived clone'))
  local edited=a:GetEditableRotation(0,id);local leaf=class=='SHAMAN'and edited.rotation[1]or edited.rotation[1].onTrue[1].onFalse[1];leaf.action=974
  local saved=a.RotationData.CopyData(edited);local previous=assert(a:GetSourcedRotationView(0,id))
  local f,s=fixture(class,false,a.db.profile);local current=f.addon;s.level=20
  assert(not current:GetRuntimeRotations(0)[id]);assert(row(current).eligible)
  local view=assert(current:GetSourcedRotationView(0,id));assert(view.lineage.baseline.revision==previous.lineage.baseline.revision)
  assert(same(saved,current:GetEditableRotation(0,id)))
  local fresh=assert(current:CloneDefaultRotation(0,pack.id,'Current clone'));assert(current:GetRuntimeRotations(0)[fresh])
  assert(current:GetSourcedRotationView(0,fresh).lineage.baseline.revision==row(current).envelope.revision)
  oldState.level=20;assert(not row(a).eligible)
 end
end)
test('strict complete-pack inverse accepts only the approved current body and rejects unrelated bytes',function()
 for _,class in ipairs({'mage'})do local path='Defaults/tbc/'..class..'-starter.lua';local current=read(path);local old=restore(current,path)
  assert(old~=current and not pcall(restore,old,path));assert(not pcall(restore,current..'\n',path))
  assert(not pcall(restore,current:gsub('ranked=false','ranked=true',1),path))
 end
end)
finish()
