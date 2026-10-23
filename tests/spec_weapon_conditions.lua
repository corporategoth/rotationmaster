-- SPECIALIZATION and WEAPON_TYPE, and the temporary weapon enchant conditions
-- on Retail: true/false/unavailable per client family (Era, TBC, Wrath, Mists,
-- Retail, Forever), restricted values, event-driven caching (no native read
-- per evaluation), editor and validation round trips, the one-time profile
-- seed, and the same answer from the lean and standard engines.
-- Specialization APIs follow Platform/specializations.lua; C_PaperDollInfo
-- .GetTemporaryEnchantmentInfo follows Blizzard's generated API documentation
-- (Gethe/wow-ui-source live, PaperDollInfoDocumentation.lua: one
-- TemporaryItemEnchantInfo {enchantID, remainingTimeMs, chargesRemaining,
-- hasExpirationTime} per slot, or nothing).
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local root=assert(io.popen('pwd'):read('*l'))

-- product, expansion, class token. s.native counts native reads.
local function fixture(product,expansion,class)
    local f=F.new(product,expansion,class or 'WARRIOR');local a,e=f.addon,f.env
    local s={native={},frames={},items={},points={0,0,0},spec=nil,specs={}}
    local function hit(name) s.native[name]=(s.native[name] or 0)+1 end
    -- Native UI frames (for editors) that also record event registrations.
    local nativeCreate=e.CreateFrame
    e.CreateFrame=function(...)
        local frame=nativeCreate(...);frame.events={};s.frames[#s.frames+1]=frame
        local setScript=frame.SetScript
        function frame:SetScript(name,fn) if name=='OnEvent' then self.onEvent=fn end;if setScript then return setScript(self,name,fn) end end
        function frame:RegisterEvent(event) self.events[event]=true end
        function frame:RegisterUnitEvent(event) self.events[event]=true end
        return frame
    end
    -- Talent-tree clients have no specialization API.
    if product==2 or product==5 or product==11 then s.treeClient=true end
    -- Equipment: s.items[slot]={id,class,subclass,equipLoc}
    e.GetInventoryItemID=function(_,slot) hit('GetInventoryItemID');return s.items[slot] and s.items[slot][1] end
    e.GetInventoryItemLink=function(_,slot) local item=s.items[slot];return item and ('|Hitem:'..item[1]..':0:0:0:0:0:0|h') end
    e.GetItemInfo=function() return 'Item' end
    e.GetItemInfoInstant=function(id)
        hit('GetItemInfoInstant')
        for _,item in pairs(s.items) do
            if item[1]==id then if item.pending then return nil end;return id,'Type','Subtype',item[4] or '',1,item[2],item[3] end
        end
    end
    e.GetInventorySlotInfo=function(name) assert(name=='RANGEDSLOT');if s.noRangedSlot then error('Invalid inventory slot') end;return 18 end
    -- Talent trees (Era/TBC/Wrath).
    e.GetNumTalentTabs=function() return 3 end
    e.GetTalentTabInfo=function(tree) hit('GetTalentTabInfo');return 'Tree '..tree,'icon',s.points[tree] end
    -- Specialization API (Retail/Mists/Forever).
    e.C_SpecializationInfo={
        GetSpecialization=function() hit('GetSpecialization');if s.specError then error('not ready') end;return s.spec end,
        GetSpecializationInfo=function(index) hit('GetSpecializationInfo');return s.specs[index] end,
        GetNumSpecializationsForClassID=function(classID) return classID==1 and 3 or 0 end,
    }
    e.GetSpecializationInfoForClassID=function(classID,index)
        if classID==1 then return ({71,72,73})[index],({'Arms','Fury','Protection'})[index],'',100+index end
    end
    e.GetSpecializationInfoByID=function(id)
        local known={[71]='Arms',[72]='Fury',[73]='Protection',[64]='Frost',[1480]='Devourer'}
        if known[id] then return id,known[id],'',200,'DAMAGER',id==1480 and 'DEMONHUNTER' or (id==64 and 'MAGE' or 'WARRIOR') end
    end
    if s.treeClient then e.C_SpecializationInfo=nil end
    f.load('Platform/talents.lua');f.load('Core/build_context.lua');f.load('Core/conditions.lua')
    f.load('Conditions/common.lua');f.load('Conditions/specialization.lua');f.load('Conditions/equipment.lua')
    f.load('Conditions/weapon.lua');f.load('Conditions/build.lua')
    local function fire(event,...) for _,frame in ipairs(s.frames) do if frame.events[event] and frame.onEvent then frame.onEvent(frame,event,...) end end end
    return f,a,e,s,fire
end
local function result(a,node) return a:evaluateConditionResult(node) end
local function spec(id) return {type='SPECIALIZATION',spec=id} end
local function weapon(slot,kind,subclass) return {type='WEAPON_TYPE',slot=slot,kind=kind,subclass=subclass} end
local function status(a,node) local r=result(a,node);return r.status,r.reason end
local function unavailableUnderNot(a,node,reason)
    local r=result(a,node);assert(r.status=='unavailable',node.type..' was '..tostring(r.status))
    if reason then assert(r.reason==reason or tostring(r.reason):find(reason,1,true),'reason '..tostring(r.reason)..' expected '..reason) end
    assert(result(a,{type='NOT',value=node}).status=='unavailable','NOT of unavailable was known')
end

test('specialization: Mists of Pandaria Classic compares the active specialization ID',function()
    local _,a,_,s=fixture(19,4,'WARRIOR');s.spec=2;s.specs={71,72,73}
    assert(a:evaluateCondition(spec(72))==true and a:evaluateCondition(spec(71))==false,'Fury')
    assert(a:evaluateCondition({type='NOT',value=spec(73)})==true)
    assert(a:evaluateCondition(spec(64))==false,'another class must be false')
end)

test('specialization: no specialization yet is unavailable for your class, false for others',function()
    local _,a,_,s=fixture(19,4,'WARRIOR');s.spec=nil
    unavailableUnderNot(a,spec(72),'specialization-unavailable')
    assert(a:evaluateCondition(spec(64))==false)
    local _,b,_,t=fixture(19,4,'WARRIOR');t.specError=true;unavailableUnderNot(b,spec(72),'api-error')
end)

test('specialization: Retail reads the specialization, initial specs are false and secrets unavailable',function()
    local _,a,e,s=fixture(1,12,'WARRIOR');s.spec=1;s.specs={71}
    assert(a:evaluateCondition(spec(71))==true and a:evaluateCondition(spec(72))==false)
    s.specs={1446};a:InvalidateBuildContext('talents');assert(a:evaluateCondition(spec(71))==false,'an initial spec is not Arms')
    local opaque={};s.specs={opaque};e.issecretvalue=function(v) return v==opaque end;a:InvalidateBuildContext('talents')
    unavailableUnderNot(a,spec(71),'restricted-value')
    e.issecretvalue=function() return false end
    s.specs={1480};a:InvalidateBuildContext('talents')
    assert(a:evaluateCondition(spec(1480))==false,'a Devourer ID of another class (from the client) is false for a Warrior')
end)

test('specialization: Forever cannot name its specializations, other classes stay false',function()
    local _,a,_,s=fixture(18,12,'WARRIOR');s.spec=1;s.specs={1491}
    unavailableUnderNot(a,spec(72),'specialization-unsupported')
    assert(a:evaluateCondition(spec(64))==false)
end)

test('specialization: talent-tree clients compare the primary tree (Era, TBC, Wrath)',function()
    for _,client in ipairs({{2,0},{5,1},{11,2}}) do
        local _,a,_,s,fire=fixture(client[1],client[2],'WARRIOR');s.points={31,20,0}
        assert(a:evaluateCondition(spec(71))==true and a:evaluateCondition(spec(72))==false,'Arms on '..client[1])
        s.points={0,41,10};fire('CHARACTER_POINTS_CHANGED')
        assert(a:evaluateCondition(spec(72))==true,'Fury after the talent change on '..client[1])
        s.points={20,20,0};fire('PLAYER_TALENT_UPDATE');unavailableUnderNot(a,spec(72),'ambiguous-primary-talent-tree')
        s.points={0,0,0};fire('ACTIVE_TALENT_GROUP_CHANGED');unavailableUnderNot(a,spec(71),'no-talents-spent')
        assert(a:evaluateCondition(spec(64))==false,'another class is false even without talents')
    end
    local _,d,_,s=fixture(2,0,'DRUID');s.points={5,31,15}
    assert(d:evaluateCondition(spec(103))==true and d:evaluateCondition(spec(104))==true,'Feral and Guardian both mean Feral Combat')
    assert(d:evaluateCondition(spec(105))==false and d:evaluateCondition(spec(102))==false)
    local _,m,_,t=fixture(2,0,'WARRIOR');t.points={31,0,0}
    unavailableUnderNot(m,spec(999999),'unknown-specialization')
end)

test('specialization: the observation is cached until a talent or specialization notification',function()
    local _,a,_,s,fire=fixture(19,4,'WARRIOR');s.spec=1;s.specs={71,72,73}
    assert(a:evaluateCondition(spec(71)))
    local before=s.native.GetSpecialization
    for _=1,50 do a:evaluateCondition(spec(71));a:evaluateCondition(spec(72)) end
    assert(s.native.GetSpecialization==before,'specialization read per evaluation')
    s.spec=2;assert(a:evaluateCondition(spec(71))==true,'refreshed without a notification')
    fire('PLAYER_SPECIALIZATION_CHANGED','player');assert(a:evaluateCondition(spec(72))==true and s.native.GetSpecialization==before+1)
    local _,b,_,t,fireTree=fixture(2,0,'WARRIOR');t.points={31,0,0};b:evaluateCondition(spec(71))
    local reads=t.native.GetTalentTabInfo;for _=1,50 do b:evaluateCondition(spec(71)) end
    assert(t.native.GetTalentTabInfo==reads,'talent trees read per evaluation');fireTree('CHARACTER_POINTS_CHANGED');b:evaluateCondition(spec(71))
    assert(t.native.GetTalentTabInfo>reads)
end)

test('specialization: validation, summary and editor round trip',function()
    local f,a,_,s=fixture(19,4,'WARRIOR');s.spec=2;s.specs={71,72,73}
    local d=a.conditionDefinitions.SPECIALIZATION
    assert(d.valid(0,{spec=72}) and not d.valid(0,{}) and not d.valid(0,{spec=0}) and not d.valid(0,{spec='72'}) and not d.valid(0,{spec=1.5}))
    assert(d.print(0,{spec=72})=='your specialization is Fury',d.print(0,{spec=72}))
    assert(d.print(0,{}):find('<specialization>',1,true))
    local value={type='SPECIALIZATION'}
    local parent=a:CreateConditionGroup();local owner={values={root=value,funcs={print=function() return d.print(0,value) end}}}
    function owner:GetUserData(key) return self.values[key] end
    function owner:SetStatusText(text) self.status=text end
    parent:SetUserData('top',owner);d.widget(parent,1,value)
    local class,picker=parent.children[1],parent.children[2]
    class.configure();picker.configure()
    assert(class.value=='WARRIOR','your own class is offered first')
    assert(#picker.order==3 and picker.order[2]==72 and type(picker.list[72])=='table' and picker.list[72].text=='Fury' and picker.list[72].icon==102,'client names and icons')
    picker:SetValue(72);picker:Fire('OnValueChanged',72);assert(value.spec==72 and owner.status=='your specialization is Fury')
    class:SetValue('MAGE');class:Fire('OnValueChanged','MAGE')
    assert(value.spec==nil,'changing class kept a spec of the old class')
    -- Era names its trees itself only for your class; others use the table.
    local _,b=fixture(2,0,'WARRIOR');local db=b.conditionDefinitions.SPECIALIZATION
    local v2={type='SPECIALIZATION',spec=64};local p2=b:CreateConditionGroup();local o2={values={root=v2,funcs={print=function() return '' end}}}
    function o2:GetUserData(key) return self.values[key] end
    function o2:SetStatusText() end
    p2:SetUserData('top',o2);db.widget(p2,0,v2);p2.children[1].configure();p2.children[2].configure()
    assert(p2.children[1].value=='MAGE' and p2.children[2].list[64]=='Frost' and #p2.children[2].order==3)
    assert(db.print(0,{spec=104})=='your specialization is Guardian')
    local text=F.text(p2);assert(text~=nil)
    local help=b:CreateConditionGroup();db.help(help);assert(F.text(help):find('primary talent tree',1,true))
    assert(f)
end)

-- Equipment fixtures: a dagger, a shield, a bow; class 2 weapon, 4 armor.
local DAGGER={1001,2,15,'INVTYPE_WEAPON'}
local SWORD2H={1002,2,8,'INVTYPE_2HWEAPON'}
local SHIELD={1003,4,6,'INVTYPE_SHIELD'}
local BOW={1004,2,2,'INVTYPE_RANGED'}
local ORB={1005,4,0,'INVTYPE_HOLDABLE'}

test('weapon type: slots, categories and subclasses on Era',function()
    local _,a,_,s,fire=fixture(2,0,'ROGUE');s.items={[16]=DAGGER,[17]=SHIELD,[18]=BOW}
    assert(a:evaluateCondition(weapon('mainhand',nil,15))==true,'dagger')
    assert(a:evaluateCondition(weapon('mainhand',nil,13))==false,'not a fist weapon')
    assert(a:evaluateCondition(weapon('mainhand','onehand'))==true and a:evaluateCondition(weapon('mainhand','twohand'))==false)
    assert(a:evaluateCondition(weapon('mainhand','weapon'))==true and a:evaluateCondition(weapon('mainhand','empty'))==false)
    assert(a:evaluateCondition(weapon('offhand','shield'))==true and a:evaluateCondition(weapon('offhand','weapon'))==false)
    assert(a:evaluateCondition(weapon('offhand',nil,15))==false,'a shield is no dagger')
    assert(a:evaluateCondition(weapon('ranged','ranged'))==true and a:evaluateCondition(weapon('ranged',nil,2))==true)
    s.items={[16]=SWORD2H,[17]=SWORD2H};fire('PLAYER_EQUIPMENT_CHANGED',16,true)
    assert(a:evaluateCondition(weapon('offhand','twohand'))==true,"Titan's Grip")
    s.items={[16]=SWORD2H};fire('UNIT_INVENTORY_CHANGED','player')
    assert(a:evaluateCondition(weapon('offhand','empty'))==true and a:evaluateCondition(weapon('offhand','weapon'))==false)
    assert(a:evaluateCondition({type='NOT',value=weapon('offhand','weapon')})==true,'not dual wielding')
    s.items={[16]=DAGGER,[17]=ORB};fire('PLAYER_EQUIPMENT_CHANGED',17,true)
    assert(a:evaluateCondition(weapon('offhand','holdable'))==true and a:evaluateCondition(weapon('offhand','shield'))==false)
end)

test('weapon type: the ranged slot is unavailable from Mists of Pandaria on, and where the client lacks it',function()
    for _,client in ipairs({{19,4},{1,12}}) do
        local _,a,_,s=fixture(client[1],client[2],'HUNTER');s.items={[16]=BOW}
        unavailableUnderNot(a,weapon('ranged','ranged'),'no-ranged-slot')
        assert(a:evaluateCondition(weapon('mainhand','ranged'))==true,'bow in the main hand on '..client[1])
    end
    local _,b,_,t=fixture(18,12,'HUNTER');t.noRangedSlot=true;unavailableUnderNot(b,weapon('ranged','empty'),'no-ranged-slot')
end)

test('weapon type: unclassifiable and restricted items are unavailable, never empty',function()
    local _,a,e,s,fire=fixture(5,1,'WARRIOR');s.items={[16]={1009,2,1,'INVTYPE_2HWEAPON',pending=true}}
    unavailableUnderNot(a,weapon('mainhand','twohand'))
    assert(a:evaluateCondition(weapon('mainhand','empty'))==false,'an equipped but unclassified item is still not an empty slot')
    s.items={[16]={1010,2,1,''}};fire('PLAYER_EQUIPMENT_CHANGED',16,true)
    assert(a:evaluateCondition(weapon('mainhand',nil,1))==true,'subclass needs no equip location')
    unavailableUnderNot(a,weapon('mainhand','twohand'),'item-data-unavailable')
    local opaque=setmetatable({},{__eq=function() return false end})
    s.items={[16]={1011,opaque,1,'INVTYPE_2HWEAPON'}};e.canaccessvalue=function(v) return v~=opaque end;fire('PLAYER_EQUIPMENT_CHANGED',16,true)
    unavailableUnderNot(a,weapon('mainhand','weapon'),'restricted-value')
end)

test('weapon type: equipment is read once per change, not per evaluation',function()
    local _,a,_,s,fire=fixture(2,0,'WARRIOR');s.items={[16]=SWORD2H,[17]=SHIELD}
    a:evaluateCondition(weapon('mainhand','twohand'))
    local ids,instant=s.native.GetInventoryItemID,s.native.GetItemInfoInstant
    for _=1,50 do a:evaluateCondition(weapon('mainhand','twohand'));a:evaluateCondition(weapon('offhand','shield')) end
    assert(s.native.GetInventoryItemID==ids and s.native.GetItemInfoInstant==instant,'equipment read per evaluation')
    fire('UNIT_INVENTORY_CHANGED','party1');a:evaluateCondition(weapon('mainhand','twohand'))
    assert(s.native.GetInventoryItemID==ids,'another unit invalidated the player')
    fire('PLAYER_EQUIPMENT_CHANGED',16,true);a:evaluateCondition(weapon('mainhand','twohand'))
    assert(s.native.GetInventoryItemID==ids+19 and s.native.GetItemInfoInstant==instant+2,'weapon slots classified once per change')
end)

test('weapon type: validation, summary and editor round trip',function()
    local _,a=fixture(2,0,'ROGUE');local d=a.conditionDefinitions.WEAPON_TYPE
    assert(d.valid(0,{slot='mainhand',kind='twohand'}) and d.valid(0,{slot='offhand',subclass=15}))
    assert(not d.valid(0,{slot='mainhand'}) and not d.valid(0,{slot='neck',kind='weapon'}) and not d.valid(0,{slot='mainhand',kind='polearm'}))
    assert(not d.valid(0,{slot='mainhand',kind='weapon',subclass=15}) and not d.valid(0,{slot='mainhand',subclass=1.5}) and not d.valid(0,{slot='mainhand',subclass=99}))
    assert(d.print(0,{slot='offhand',kind='shield'})=='your Off Hand slot holds Shield',d.print(0,{slot='offhand',kind='shield'}))
    assert(d.print(0,{slot='mainhand',subclass=15})=='your Main Hand slot holds Daggers')
    local value={type='WEAPON_TYPE'};local parent=a:CreateConditionGroup();local owner={values={root=value,funcs={print=function() return d.print(0,value) end}}}
    function owner:GetUserData(key) return self.values[key] end
    function owner:SetStatusText(text) self.status=text end
    parent:SetUserData('top',owner);d.widget(parent,0,value)
    local slot,kind=parent.children[1],parent.children[2];slot.configure();kind.configure()
    slot:SetValue('mainhand');slot:Fire('OnValueChanged','mainhand')
    kind:SetValue('subclass:15');kind:Fire('OnValueChanged','subclass:15')
    assert(value.slot=='mainhand' and value.subclass==15 and value.kind==nil and d.valid(0,value),'subclass choice')
    kind:Fire('OnValueChanged','twohand');assert(value.kind=='twohand' and value.subclass==nil and d.valid(0,value),'category choice')
    assert(owner.status=='your Main Hand slot holds Two-handed weapon')
    a.env=nil;_G.GetItemSubClassInfo=nil
    local help=a:CreateConditionGroup();d.help(help);assert(F.text(help):find('Titan',1,true))
end)

test('weapon enchants on Retail read C_PaperDollInfo once per evaluation, and stay unavailable when unreadable',function()
    local _,a,e=fixture(1,12,'SHAMAN');local calls=0
    local info={[16]={enchantID=5400,remainingTimeMs=3600000,chargesRemaining=0,hasExpirationTime=true}}
    e.GetWeaponEnchantInfo=function() error('the deprecated API must not be used where the modern one exists') end
    e.C_PaperDollInfo={GetTemporaryEnchantmentInfo=function(slot) calls=calls+1;return info[slot] end}
    for _,tag in ipairs({'WEAPON','WEAPON_REMAIN','WEAPON_STACKS','WEAPON_IMBUE'}) do assert(a.conditionDefinitions[tag],tag..' not registered on Retail') end
    assert(a:evaluateCondition({type='WEAPON'})==true and a:evaluateCondition({type='WEAPON',offhand=true})==false)
    assert(a:evaluateCondition({type='WEAPON_IMBUE',enchant=5400})==true and a:evaluateCondition({type='WEAPON_IMBUE',enchant=5401})==false)
    assert(a:evaluateCondition({type='WEAPON_REMAIN',operator='GREATERTHAN',value=3000})==true)
    calls=0;assert(a:evaluateCondition({type='AND',value={{type='WEAPON'},{type='WEAPON_IMBUE',enchant=5400},{type='WEAPON',offhand=true}}})==false)
    assert(calls==2,'one evaluation read each slot more than once: '..calls)
    info[16].hasExpirationTime=false;unavailableUnderNot(a,{type='WEAPON_REMAIN',operator='GREATERTHAN',value=1})
    local opaque={};e.issecretvalue=function(v) return v==opaque end
    info[16]=opaque;unavailableUnderNot(a,{type='WEAPON'},'restricted-value')
    info[16]={enchantID=opaque,remainingTimeMs=1,chargesRemaining=0,hasExpirationTime=true};unavailableUnderNot(a,{type='WEAPON_IMBUE',enchant=5400},'restricted-value')
    e.issecretvalue=function() return false end
    e.C_PaperDollInfo.GetTemporaryEnchantmentInfo=function() error('blocked') end;unavailableUnderNot(a,{type='WEAPON'},'api-error')
    e.C_PaperDollInfo=nil;e.GetWeaponEnchantInfo=function() return true,1000,0,283,false,nil,nil,nil end
    assert(a:evaluateCondition({type='WEAPON_IMBUE',enchant=283})==true,'the classic API is used where the modern one is absent')
    e.GetWeaponEnchantInfo=nil;unavailableUnderNot(a,{type='WEAPON'},'missing-api')
end)

test('the conditions join Character, Items and the Switch picker once per profile',function()
    local _,a=fixture(2,0,'WARRIOR')
    local profile={switch_conditions={'AND'},condition_groups={{id='b8136123-2bda-4230-a77a-89ea2aed3a1a',conditions={'CLASS'}},{id='fca4ff75-4085-458a-b5bf-27a6b52f2092',conditions={'EQUIPPED'}}}}
    local db={profile=profile};a:InitializeLoadoutConditions(nil,db)
    assert(profile.loadoutConditionsSeeded and profile.switch_conditions[2]=='SPECIALIZATION' and profile.switch_conditions[3]=='WEAPON_TYPE')
    assert(profile.condition_groups[1].conditions[2]=='SPECIALIZATION' and profile.condition_groups[2].conditions[2]=='WEAPON_TYPE')
    a:InitializeLoadoutConditions(nil,db);assert(#profile.switch_conditions==3,'seeded twice')
    table.remove(profile.switch_conditions,2);a:InitializeLoadoutConditions(nil,db);assert(#profile.switch_conditions==2,'a removed seed came back')
end)

-- Whole poll: the real addon in TOC order (TBC Shaman, bars 403, 8042, 324,
-- 8017). A shield in the off hand selects Earth Shock, otherwise Lightning
-- Bolt; both engines answer alike and follow an equipment change.
test('whole poll: lean and standard engines agree on WEAPON_TYPE and SPECIALIZATION',function()
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=true,buttons=true,poll=.15})
    local a,e=c.a,c.e
    local items={[16]={1001,2,4,'INVTYPE_WEAPON'},[17]={1003,4,6,'INVTYPE_SHIELD'}}
    e.GetInventoryItemID=function(_,slot) return items[slot] and items[slot][1] end
    e.GetInventoryItemLink=function() return nil end
    e.GetItemInfoInstant=function(id) for _,item in pairs(items) do if item[1]==id then return id,'T','S',item[4],1,item[2],item[3] end end end
    e.GetInventorySlotInfo=function() return 18 end
    local points={0,31,5};e.GetNumTalentTabs=function() return 3 end;e.GetTalentTabInfo=function(tree) return 'Tree '..tree,'icon',points[tree] end
    -- The fixture's TOC model loads conditions, not every Platform reader.
    if not a.Platform.GetTalentLayout then c.load('Platform/talents.lua') end
    if not a.GetEquippedWeaponSlot then c.load('Core/build_context.lua') end
    a:InvalidateBuildContext()
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id='loadout'}}
    assert(a:CommitRotationDraft(reference,nil,{body={name='Loadout',priority=0,cooldowns={},rotation={
        {id='shock',type='spell',action=8042,conditions={type='AND',value={{type='WEAPON_TYPE',slot='offhand',kind='shield'},{type='SPECIALIZATION',spec=263}}}},
        {id='bolt',type='spell',action=403,conditions={}}}}},'class'))
    a:HandleCommand('set Loadout');for _=1,3 do c.tick() end
    for _,engine in ipairs({'lean','standard'}) do
        assert(a:SetEvaluationEngine(engine));items[17]={1003,4,6,'INVTYPE_SHIELD'};points={0,31,5};a:InvalidateBuildContext();c.tick();c.tick()
        assert(a.currentSpell==8042,engine..' with a shield: '..tostring(a.currentSpell))
        items[17]=nil;c.fire('PLAYER_EQUIPMENT_CHANGED');a:InvalidateBuildContext('equipment');c.tick();c.tick()
        assert(a.currentSpell==403,engine..' without a shield: '..tostring(a.currentSpell))
        items[17]={1003,4,6,'INVTYPE_SHIELD'};points={31,0,5};a:InvalidateBuildContext();c.tick();c.tick()
        assert(a.currentSpell==403,engine..' as Elemental: '..tostring(a.currentSpell))
    end
    assert(a:SetEvaluationEngine('lean'))
    assert(not a.adviceErrorReport,'evaluation raised an error')
    -- The seed flag is a valid profile scalar.
    c.load('UI/settings_draft.lua');c.load('Core/profile_data.lua')
    assert(a:ValidateProfileTransfer({loadoutConditionsSeeded=true}) and not a:ValidateProfileTransfer({loadoutConditionsSeeded='yes'}))
    assert(a.db.profile.loadoutConditionsSeeded,'the real profile was not seeded')
end)

finish()
