-- Literal continuation controls; real engine/registrar/publisher and native APIs
-- modeled at the accepted30–39 fixture boundary. No new rank/trainer claims.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local ID,OLD='rm.tbc.mage.starter.40-49','rm.tbc.mage.starter.30-39'
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function once(s,old,new)local a,b=assert(s:find(old,1,true));assert(not s:find(old,b+1,true));return s:sub(1,a-1)..new..s:sub(b+1)end
local function replace(s,old,new)local out,n={},0;local at=1;while true do local a,b=s:find(old,at,true);if not a then out[#out+1]=s:sub(at);break end;out[#out+1]=s:sub(at,a-1)..new;at=b+1;n=n+1 end;assert(n>0);return table.concat(out)end
local prefix=assert(read('tests/defaults_mage_30_39.lua'):match('^(.-)\ntest%('))
prefix=replace(prefix,'Defaults/tbc/mage-30-39.lua','Defaults/tbc/mage-40-49.lua')
prefix=replace(prefix,'rm.tbc.mage.starter.30-39',ID);prefix=replace(prefix,'Mage.Thirties','Mage.Forties')
prefix=once(prefix,'level=30,combat=false','level=40,combat=false')
local baseFixture,row,body,first,optional,nativePublish=assert(loadstring(prefix..'\nreturn fixture,row,body,first,optional,nativePublish','@mage-forty-accepted-publisher'))()
local function fixture(...)local f,s,n=baseFixture(...);f.load('Core/rotation_selection.lua');return f,s,n end
local function clear(a)a.longtermCache={}end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function noArmor(actions)assert(not actions[168]and not actions[7301]and not actions[7302]and not actions[6117])end

test('complete source is exactly the six-row30policy with independent identities and bracket',function()
 local old=read('Defaults/tbc/mage-30-39.lua');local new=read(arg[1]or'Defaults/tbc/mage-40-49.lua')
 old=replace(old,'30–39','40–49');old=replace(old,OLD,ID);old=replace(old,'Mage.Thirties','Mage.Forties');old=replace(old,'mage-thirties-','mage-forties-')
 old=once(old,'minLevel=30,maxLevel=39','minLevel=40,maxLevel=49')
 old=once(old,"operator='GREATERTHANOREQUALS',value=30","operator='GREATERTHANOREQUALS',value=40")
 old=once(old,"operator='LESSTHAN',value=40","operator='LESSTHAN',value=50")
 assert(new==old,'continuation changed inherited authored policy')
 local f=fixture();local a=f.addon;local r=row(a);assert(r.id==ID and r.envelope.revision==1 and r.validation.valid and r.readOnly)
 local index=assert(a.RotationData.IndexRotationSteps(body(a)));assert(#index.rows==6)
 local ids={};for _,entry in ipairs(index.rows)do assert(entry.step.id:find('mage-forties-',1,true)==1 and not ids[entry.step.id]);ids[entry.step.id]=true end
end)
test('class edition action context and39 40 49 50 level boundaries are exact',function()
 local f,s=fixture();for _,level in ipairs({39,40,49,50})do s.level=level;clear(f.addon);local wanted=level>=40 and level<=49
  assert(row(f.addon).eligible==wanted and f.addon:evaluateCondition(body(f.addon).switch)==wanted)
 end
 for _,case in ipairs({{5,'SHAMAN'},{2,'MAGE'},{1,'MAGE'}})do local x=fixture(case[1],case[2]);local rows=x.addon:ListDefaultRotations(0);assert(#rows==0 or not rows[1].eligible)end
 for _,kind in ipairs({'vehicle','petbattle'})do f=fixture();if kind=='vehicle'then f.env.UnitHasVehicleUI=function()return true end else f.env.C_PetBattles={IsInBattle=function()return true end}end;assert(not row(f.addon).eligible and not f.addon:GetRuntimeRotation(0,row(f.addon).runtimeKey))end
end)
test('Frost orientation adds no allocation gate or level-granted ability',function()
 local f,s=fixture();local calls=0;f.env.GetTalentTabInfo=function()calls=calls+1;error('no allocation observation required')end
 f.env.C_SpecializationInfo={GetSpecializationInfo=function()calls=calls+1;error('no allocation observation required')end}
 for _,level in ipairs({40,49})do s.level=level;clear(f.addon);assert(f.addon:evaluateCondition(body(f.addon).switch)and first(f.addon,s)==116)end
 assert(calls==0);s.known[116]=false;assert(not f.addon:evaluateCondition(body(f.addon).switch)and not first(f.addon,s))
end)
test('reviewed trained Frostbolt families still select highest ready mapped rank at49',function()
 local f,s=fixture();s.level=49;s.known[8407],s.known[8408]=true,true;assert(first(f.addon,s)==8408)
 s.mapped[8408]=false;assert(first(f.addon,s)==8407);s.power[8407]=true;assert(first(f.addon,s)==116)
end)
test('unavailable or unready Frostbolt never invents an opposite family or melee permission',function()
 for _,kind in ipairs({'mapping','power','cooldown','usable','range','unknown'})do local f,s=fixture()
  if kind=='mapping'then s.mapped[116]=false elseif kind=='power'then s.power[116]=true elseif kind=='cooldown'then s.cooldown[116]={startTime=99,duration=30,isEnabled=true,modRate=1}
  elseif kind=='usable'then s.usable[116]=false elseif kind=='range'then s.range[116]=false else f.env.C_Spell.IsSpellUsable=function()return nil end end
  assert(not first(f.addon,s),kind)
 end
end)
test('preserve any manual armor including localized ranks and other casters',function()
 for _,id in ipairs({168,7301,7302,6117})do for _,caster in ipairs({'player','party1'})do local f,s,n=fixture()
  s.known[168],s.known[7302],s.known[6117]=true,true,true;s.buffs={{spellId=id,name=n[id],sourceUnit=caster}}
  noArmor(optional(f,s));assert(first(f.addon,s)==116)
 end end
end)
test('known Mage then Ice then Frost preference never downgrades an unready preferred family',function()
 local f,s=fixture();s.known[168]=true;assert(optional(f,s)[168]);s.known[7302]=true;assert(optional(f,s)[7302]);s.known[6117]=true;assert(optional(f,s)[6117])
 for _,kind in ipairs({'mapping','power','cooldown','usable'})do f,s=fixture();s.known[168],s.known[7302],s.known[6117],s.known[1459]=true,true,true,true
  if kind=='mapping'then s.mapped[6117]=false elseif kind=='power'then s.power[6117]=true elseif kind=='cooldown'then s.cooldown[6117]={startTime=99,duration=30,isEnabled=true,modRate=1}else s.usable[6117]=false end
  local actions=optional(f,s);noArmor(actions);assert(actions[1459]and first(f.addon,s)==116,kind)
 end
end)
test('unknown learning aura and metadata never turn NOT into absent armor',function()
 for _,id in ipairs({168,7302,6117})do local f,s=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true;s.knownError=id;noArmor(optional(f,s))end
 local f,s=fixture();s.known[168],s.known[7302],s.known[6117]=true,true,true;s.auraError=true;noArmor(optional(f,s))
 s.auraError=false;s.buffs={{spellId=999,name='Foreign',sourceUnit='party1'}};s.metadataMissing[7302]=true;noArmor(optional(f,s))
end)
test('Intellect upkeep remains independent and recognizes other caster learned ranks',function()
 local f,s,n=fixture();s.known[1459],s.known[1461],s.known[6117]=true,true,true;assert(optional(f,s)[1461]and optional(f,s)[6117])
 s.buffs={{spellId=1461,name=n[1461],sourceUnit='party1'}};assert(not optional(f,s)[1461]and optional(f,s)[6117])
end)
test('pull movement and target engagement policy remains literal',function()
 local f,s=fixture();s.targetCombat=true;assert(not first(f.addon,s));s.combat=true;assert(first(f.addon,s)==116)
 s.targetCombat=false;s.combat=false;s.moving=true;assert(not first(f.addon,s));s.moving=false;s.hostile=false;assert(not first(f.addon,s))
 s.hostile=true;s.dead=true;assert(not first(f.addon,s));s.dead=false;s.exists=false;assert(not first(f.addon,s))
end)
test('actual initialized publisher selects neighboring brackets and retires unknown learning',function()
 local f,s=fixture();f.load('Defaults/tbc/mage-30-39.lua');local tick,glow,messages=nativePublish(f,s);local a=f.addon
 a.db.profile.rotations[0].native=nil;a.currentRotation=nil;a.db.profile.disable_autoswitch=false;a.manualRotation=false
 local function poll()clear(a);a:UpdateAutoSwitch();a:SwitchRotation();tick()end
 for _,level in ipairs({39,40,49,50,40})do s.level=level;poll();if level==50 then assert(not a.currentRotation and not a.currentSpell)else assert(a.currentRotation=='RM-BUILTIN:'..(level<40 and OLD or ID)and a.currentSpell==116)end end
 s.known[116]=false;poll();assert(not a.currentRotation and not a.currentSpell);s.known[116]=true;poll();assert(a.currentSpell==116)
 f.env.IsSpellKnown=function()return nil end;poll();assert(not a.currentRotation and not a.currentSpell)
 assert(#glow>0 and #messages>0)
end)
test('manual cast channel and unavailable channel keep inherited next-action hint without new Stop',function()
 for _,id in ipairs({OLD,ID})do local f,s=fixture();if id==OLD then f.load('Defaults/tbc/mage-30-39.lua');s.level=39 end
  local tick=nativePublish(f,s);local a=f.addon;a.currentRotation='RM-BUILTIN:'..id;a.manualRotation=true
  s.casting=true;tick();assert(a.currentSpell==116);s.casting=false;s.channel=true;tick();assert(a.currentSpell==116)
  f.env.UnitChannelInfo=function()error('unobserved manual channel')end;tick();assert(a.currentSpell==116)
 end
end)
test('actual initialized publication keeps ready ranks armor messages and unready6603 boundary',function()
 local f,s,n=fixture();s.known[8407],s.known[8408],s.known[168]=true,true,true;local tick,glow,messages=nativePublish(f,s);local a=f.addon
 tick();assert(a.currentSpell==8408 and a.avail_announced['mage-forties-frost-armor']==168)
 s.known[6117]=true;tick();assert(a.avail_announced['mage-forties-mage-armor']==6117 and not a.avail_announced['mage-forties-frost-armor'])
 s.buffs={{spellId=7302,name=n[7302],sourceUnit='party1'}};tick();assert(not a.avail_announced['mage-forties-mage-armor'])
 s.mapped[8408]=false;a:Fetch();tick();assert(a.currentSpell==8407)
 s.mapped[8407],s.mapped[116]=false,false;a:Fetch();tick();assert(not a.currentSpell,'untrained/unmapped6603 produced implicit advice')
 for _,m in ipairs(messages)do assert(m[6]~=6603)end;assert(#glow>0)
end)
test('saved30clones and source remain independent at40 and after local edits',function()
 local f,s=fixture();local a=f.addon;f.load('Defaults/tbc/mage-30-39.lua');assert(a:InitializeRotationLibrary());s.level=39;clear(a)
 local id=assert(a:CloneDefaultRotation(0,OLD,'Old Mage clone'));local old=a:GetEditableRotation(0,id);old.rotation[1].onTrue[1].action=133;local saved=a:CopySettingsData(old)
 s.level=40;clear(a);assert(not a:GetRuntimeRotation(0,id)and same(a:GetEditableRotation(0,id),saved))
 local fresh=assert(a:CloneDefaultRotation(0,ID,'Forty Mage clone'));a:GetEditableRotation(0,fresh).rotation[1].onTrue[1].action=133
 assert(body(a).rotation[1].onTrue[1].action==116 and same(a:GetEditableRotation(0,id),saved))
end)
finish()
