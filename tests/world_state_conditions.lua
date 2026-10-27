-- The world-state conditions (PLAYER_STATE, ENCOUNTER, KEYSTONE_LEVEL, GROUP_COUNT,
-- HERO_TALENT, SPELL_GLOW), the optional difficulty and ID of INSTANCE and the trinket
-- slot of ITEM_COOLDOWN, on every client family: which client declares which unsupported (Core/condition_support.lua,
-- which is also what the website's per-edition red X reads), true / false /
-- unavailable for each reader, secret values (one sentinel stands in for every
-- secret field, as in tests/restricted_client_conditions.lua), the shared
-- per-evaluation cache, editor and validation round trips, the one-time profile
-- seed, and the same answer from the lean and standard engines.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local C=dofile('tests/fixtures/condition_client.lua')
local ORDER=C.order
local SECRET,expect,status,support=C.SECRET,C.expect,C.status,C.support

-- s: the fake game. s.calls counts native reads per name.
local function client(name,class)
    local f,a,e=C.load(name,class,{'Platform/world_state.lua','Platform/edition_state.lua'})
    local s={calls={},state={},encounter=false,diff=0,instance=2552,name='Khaz Algar',keystone=0,affixes={},hero=nil,glow={},
        members=0,raid=false,roles={},dead={},slots={},cooldown={}}
    local function hit(n) s.calls[n]=(s.calls[n] or 0)+1 end
    e.IsMounted=function() hit('IsMounted');return s.state.mounted end
    e.IsSwimming=function() hit('IsSwimming');return s.state.swimming end
    e.IsFalling=function() hit('IsFalling');return s.state.falling end
    e.IsFlying=function() hit('IsFlying');return s.state.flying end
    e.IsResting=function() hit('IsResting');return s.state.resting end
    e.UnitIsDead=function(unit) assert(unit=='player');hit('UnitIsDead');return s.state.dead end
    e.IsInInstance=function() return s.inInstance~=false,s.instanceType or 'party' end
    e.C_InstanceEncounter={IsEncounterInProgress=function() hit('IsEncounterInProgress');if s.throw=='encounter' then error('boom') end;return s.encounter end}
    e.IsEncounterInProgress=nil
    e.GetInstanceInfo=function() hit('GetInstanceInfo');return s.name,'party',s.diff,'Heroic',5,0,false,s.instance,5 end
    e.GetDifficultyInfo=function(id) local names={[1]={'Normal','party'},[2]={'Heroic','party'},[8]={'Mythic Keystone','party'},[14]={'Normal','raid'},[16]={'Mythic','raid'}};local n=names[id];if n then return n[1],n[2] end end
    e.C_ChallengeMode={
        IsChallengeModeActive=function() hit('IsChallengeModeActive');return s.keystone>0 end,
        GetActiveKeystoneInfo=function() hit('GetActiveKeystoneInfo');return s.keystone,s.affixes,true end,
    }
    e.C_ClassTalents={GetActiveHeroTalentSpec=function() hit('GetActiveHeroTalentSpec');return s.hero end}
    e.C_SpellActivationOverlay={IsSpellOverlayed=function(id) hit('IsSpellOverlayed');return s.glow[id] or false end}
    e.GetNumGroupMembers=function() hit('GetNumGroupMembers');return s.members end
    e.IsInRaid=function() return s.raid end
    e.UnitGroupRolesAssigned=function(unit) hit('UnitGroupRolesAssigned');return s.roles[unit] or 'NONE' end
    e.UnitIsDeadOrGhost=function(unit)
        hit('UnitIsDeadOrGhost')
        local value=s.dead[unit]
        if value==nil and unit=='player' then
            if s.state.dead==SECRET then return SECRET end
            value=(s.state.dead==true or s.state.ghost==true)
        end
        if value==nil then return false end
        return value
    end
    e.GetInventoryItemID=function(_,slot) return s.slots[slot] end
    e.GetInventoryItemLink=function() return nil end
    e.GetItemInfoInstant=function() return nil end
    e.GetTime=function() return 100 end
    -- Retail and Forever read C_Item; the Classic clients C_Container or the global (Platform/items.lua).
    local function itemCooldown(id) hit('GetItemCooldown');local c=s.cooldown[id];if not c then return 0,0,false end;return c[1],c[2],c[3]~=false end
    e.C_Item={GetItemCooldown=itemCooldown,GetItemInfoInstant=function() return nil end,GetItemInfo=function() return nil end}
    e.C_Container={GetItemCooldown=itemCooldown}
    e.GetItemCooldown=itemCooldown
    a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1
    a.Widget_GetSpellId=function(_,id) return id end
    a.Widget_GetSpellLink=function(_,id) return id and ('[spell '..id..']') or nil end
    a.IsConditionSpellID=function(id) return type(id)=='number' and id>0 end
    a.GetSpellIdRelatives=function(_,id) if id==116858 then return {116858,11366} end;return {id} end
    return f,a,e,s
end
-- Which clients have each condition (nil = all). Reasons are Core/condition_support.lua's.
local UNSUPPORTED={
    KEYSTONE_LEVEL={forever='retail-only',mists='retail-only',tbc='retail-only',era='retail-only'},
    HERO_TALENT={forever='retail-only',mists='retail-only',tbc='retail-only',era='retail-only'},
}
-- Assigned roles exist on Retail, Forever and Mists only; the size and the dead members read everywhere.
local ROLE_MEASURES={TANK=true,HEALER=true,DAMAGER=true}
local TAGS={'PLAYER_STATE','ENCOUNTER','KEYSTONE_LEVEL','GROUP_COUNT','HERO_TALENT','SPELL_GLOW','INSTANCE'}

test('every condition registers on every client and is declared supported exactly where the edition has it',function()
    for _,name in ipairs(ORDER) do
        local _,a=client(name)
        for _,tag in ipairs(TAGS) do
            assert(a.conditionDefinitions[tag],tag..' is not registered on '..name)
            local wanted=UNSUPPORTED[tag] and UNSUPPORTED[tag][name]
            local got=support(a,tag);assert(got==wanted,tag..' on '..name..': '..tostring(got)..', wanted '..tostring(wanted))
        end
        for measure in pairs({size=true,dead=true,TANK=true,HEALER=true,DAMAGER=true}) do
            local wanted=ROLE_MEASURES[measure] and (name=='tbc' or name=='era') and 'no-group-roles' or nil
            local got=support(a,'GROUP_COUNT',{measure=measure});assert(got==wanted,'GROUP_COUNT '..measure..' on '..name..': '..tostring(got)..', wanted '..tostring(wanted))
        end
    end
end)

test('a reader the client lacks is declared missing-api, not silently false',function()
    local _,a,e=client('retail')
    e.IsMounted=nil;assert(support(a,'PLAYER_STATE',{state='mounted'})=='missing-api')
    assert(support(a,'PLAYER_STATE',{state='swimming'})==nil,'a state reads only its own API')
    e.UnitIsDead=nil;assert(support(a,'PLAYER_STATE',{state='dead'})=='missing-api' and support(a,'PLAYER_STATE',{state='ghost'})=='missing-api')
    assert(support(a,'PLAYER_STATE',{})==nil,'no state chosen yet: listed everywhere')
    local _,c,g=client('retail');g.C_SpellActivationOverlay=nil;assert(support(c,'SPELL_GLOW')=='missing-api')
    local _,d,h=client('retail');h.UnitGroupRolesAssigned=nil
    assert(support(d,'GROUP_COUNT',{measure='TANK'})=='missing-api' and support(d,'GROUP_COUNT',{measure='size'})==nil)
    local _,i,j=client('retail');j.UnitIsDeadOrGhost=nil
    assert(support(i,'GROUP_COUNT',{measure='dead'})=='missing-api' and support(i,'GROUP_COUNT',{measure='TANK'})==nil)
    local _,k,l=client('retail');l.C_Container=nil;l.C_Item=nil;l.GetItemCooldown=nil
    assert(support(k,'ITEM_COOLDOWN',{slot=13})=='missing-api','no cooldown reader')
    local _,m,n=client('retail');n.GetInventoryItemID=nil
    assert(support(m,'ITEM_COOLDOWN',{slot=13})=='missing-api' and support(m,'ITEM_COOLDOWN',{item=5512})==nil,'only a slot needs the equipped item API')
end)

-- PLAYER_STATE: one reader, a kind per state.
local STATES={mounted='mounted',swimming='swimming',falling='falling',flying='flying',resting='resting'}
test('player states are true, false and unavailable on every client, also under NOT',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        for state,kind in pairs(STATES) do
            local condition={type='PLAYER_STATE',state=state}
            s.state[kind]=true;expect(a,condition,'match',name..' '..state)
            s.state[kind]=false;expect(a,condition,'no-match',name..' '..state)
            -- The legacy forms answer 1 or nil.
            s.state[kind]=1;expect(a,condition,'match',name..' '..state..' 1')
            s.state[kind]=nil;expect(a,condition,'no-match',name..' '..state..' nil')
            s.state[kind]=SECRET;expect(a,condition,'unavailable',name..' '..state..' secret')
            s.state[kind]='yes';expect(a,condition,'unavailable',name..' '..state..' string')
            s.state[kind]=nil
        end
    end
end)

test('dead is UnitIsDead and ghost is dead-or-ghost without dead, so a ghost is not dead',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        local dead,ghost={type='PLAYER_STATE',state='dead'},{type='PLAYER_STATE',state='ghost'}
        expect(a,dead,'no-match',name..' alive');expect(a,ghost,'no-match',name..' alive')
        s.state.dead=true;expect(a,dead,'match',name..' a corpse');expect(a,ghost,'no-match',name..' a corpse is not a ghost')
        s.state.dead=false;s.state.ghost=true;expect(a,dead,'no-match',name..' a ghost is not dead');expect(a,ghost,'match',name..' a ghost')
        s.state.ghost=false
        s.state.dead=SECRET;expect(a,dead,'unavailable',name..' secret');expect(a,ghost,'unavailable',name..' either read secret')
        s.state.dead=false;s.dead.player=SECRET;expect(a,ghost,'unavailable',name..' a secret dead-or-ghost');s.dead.player=nil
        s.state.dead='x';expect(a,dead,'unavailable',name..' malformed')
    end
    -- The older Is Dead or Ghost condition keeps testing any unit.
    local _,a=client('retail');local released=a.conditionDefinitions.DEAD
    assert(released and released.fields.unit=='string' and released.valid(0,{unit='target'}),'the released DEAD condition (any unit) is unchanged')
end)

test('a player state survives a missing native and a throwing one, and rejects what it does not list',function()
    local _,a,e,s=client('retail')
    e.IsMounted=function() error('boom') end;expect(a,{type='PLAYER_STATE',state='mounted'},'unavailable')
    e.IsMounted=nil;expect(a,{type='PLAYER_STATE',state='mounted'},'unavailable')
    s.state.swimming=true;expect(a,{type='PLAYER_STATE',state='swimming'},'match')
    local def=a.conditionDefinitions.PLAYER_STATE
    for _,state in ipairs({'mounted','swimming','flying','falling','resting','dead','ghost'}) do assert(def.valid(0,{state=state}),state) end
    assert(not def.valid(0,{}) and not def.valid(0,{state='stealthed'}) and not def.valid(0,{state=7}))
    for _,state in ipairs({'mounted','swimming','flying','falling','resting','dead','ghost'}) do
        local text=def.print(0,{state=state});assert(type(text)=='string' and text:find('you ',1,true) and not text:find('<',1,true),state..': '..text)
    end
end)

test('one evaluation reads each predicate once, and the cache does not outlive the pass',function()
    local _,a,_,s=client('retail')
    s.state.mounted=true
    local cache={};local def=a.conditionDefinitions.PLAYER_STATE
    assert(def.evaluate({state='mounted'},cache)==true and def.evaluate({state='mounted'},cache)==true and s.calls.IsMounted==1)
    assert(a:evaluateConditionResult({type='AND',value={{type='PLAYER_STATE',state='mounted'},{type='PLAYER_STATE',state='mounted'}}}).status=='match' and s.calls.IsMounted==2)
end)

test('ENCOUNTER reads the game encounter state, with the deprecated global as a fallback',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        s.encounter=true;expect(a,{type='ENCOUNTER'},'match',name)
        s.encounter=false;expect(a,{type='ENCOUNTER'},'no-match',name)
        s.encounter=SECRET;expect(a,{type='ENCOUNTER'},'unavailable',name)
        s.encounter=nil;expect(a,{type='ENCOUNTER'},'unavailable',name)
        s.encounter='yes';expect(a,{type='ENCOUNTER'},'unavailable',name)
        s.encounter=false;s.throw='encounter';expect(a,{type='ENCOUNTER'},'unavailable',name)
    end
    local _,a,e=client('era');e.C_InstanceEncounter=nil;e.IsEncounterInProgress=function() return true end
    expect(a,{type='ENCOUNTER'},'match','global fallback')
    e.IsEncounterInProgress=nil;expect(a,{type='ENCOUNTER'},'unavailable','no reader')
end)

test('INSTANCE adds an optional difficulty and an optional instance ID, and every part given must match',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        s.diff=8;s.instance=2648;s.inInstance=true;s.instanceType='party'
        local function inst(extra) local c={type='INSTANCE'};for k,v in pairs(extra) do c[k]=v end;return c end
        expect(a,inst{value='party'},'match',name..' a released condition keeps its meaning');expect(a,inst{value='raid'},'no-match',name)
        expect(a,inst{difficulty=8},'match',name);expect(a,inst{difficulty=2},'no-match',name)
        expect(a,inst{instanceID=2648},'match',name);expect(a,inst{instanceID=2552},'no-match',name)
        expect(a,inst{value='party',difficulty=8,instanceID=2648},'match',name..' every part')
        expect(a,inst{value='raid',difficulty=8,instanceID=2648},'no-match',name..' the kind differs')
        expect(a,inst{value='party',difficulty=2,instanceID=2648},'no-match',name..' the difficulty differs')
        expect(a,inst{value='party',difficulty=8,instanceID=1},'no-match',name..' the ID differs')
        s.diff=0;s.inInstance=false;s.instanceType='none'
        expect(a,inst{value='none',difficulty=0},'match',name..' open world');expect(a,inst{difficulty=0},'match',name)
        s.inInstance=true;s.instanceType='party';s.diff=SECRET
        expect(a,inst{difficulty=8},'unavailable',name);expect(a,inst{instanceID=2648},'match',name..' a secret difficulty does not hide the instance ID')
        expect(a,inst{value='party'},'match',name..' nor the kind')
        expect(a,inst{value='raid',difficulty=8},'no-match',name..' a wrong kind decides before the unreadable difficulty is asked')
        s.diff=2;s.instance=SECRET;expect(a,inst{instanceID=2648},'unavailable',name)
        expect(a,inst{difficulty=2},'match',name..' a secret instance ID does not hide the difficulty')
        s.instance=2648;s.diff='x';expect(a,inst{difficulty=2},'unavailable',name..' malformed')
        s.diff=2;e.GetInstanceInfo=nil;expect(a,inst{instanceID=2648},'unavailable',name..' missing')
        expect(a,inst{value='party'},'match',name..' the kind does not need GetInstanceInfo')
    end
    local _,a,_,s=client('retail');s.diff=8
    local before=s.calls.GetInstanceInfo or 0
    assert(a:evaluateConditionResult({type='AND',value={{type='INSTANCE',difficulty=8},{type='INSTANCE',instanceID=2552}}}).status=='match')
    assert(s.calls.GetInstanceInfo==before+1,'both conditions share one GetInstanceInfo read')
    local def=a.conditionDefinitions.INSTANCE
    assert(def.valid(0,{}) and def.valid(0,{value='party'}) and def.valid(0,{difficulty=8}) and def.valid(0,{value='raid',difficulty=0,instanceID=2648}))
    assert(not def.valid(0,{difficulty=-1}) and not def.valid(0,{difficulty=1.5}) and not def.valid(0,{instanceID='x'}) and not def.valid(0,{value='moon'}))
    -- A condition saved without the new fields prints as it always did.
    assert(def.print(0,{value='party'})==string.format('your instance type {{!is|is not}} %s','Dungeon') or def.print(0,{value='party'}):find('your instance type',1,true))
    local text=def.print(0,{value='party',difficulty=8,instanceID=2648});assert(text:find('2648',1,true) and text:find('you are in an instance',1,true) and not text:find('<',1,true),text)
    def.help({AddChild=function() end})
end)

test('KEYSTONE_LEVEL is 0 outside a Mythic+ run and the keystone level inside it',function()
    local _,a,e,s=client('retail')
    s.keystone=0;expect(a,{type='KEYSTONE_LEVEL',operator='EQUALS',value=0},'match');expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHANOREQUALS',value=10},'no-match')
    s.keystone=12;s.affixes={9,10};expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHANOREQUALS',value=10},'match');expect(a,{type='KEYSTONE_LEVEL',operator='LESSTHAN',value=12},'no-match')
    assert((s.calls.GetActiveKeystoneInfo or 0)>0)
    s.keystone=SECRET;expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHAN',value=1},'unavailable','secret active flag')
    s.keystone=12;e.C_ChallengeMode.GetActiveKeystoneInfo=function() return SECRET,{},true end
    expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHAN',value=1},'unavailable','secret level')
    e.C_ChallengeMode.GetActiveKeystoneInfo=function() return -1,{},true end
    expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHAN',value=1},'unavailable','malformed level')
    e.C_ChallengeMode=nil;expect(a,{type='KEYSTONE_LEVEL',operator='GREATERTHAN',value=1},'unavailable','missing')
end)

test('HERO_TALENT compares the chosen hero tree, and a tree that is not chosen is false',function()
    local _,a,e,s=client('retail')
    s.hero=nil;expect(a,{type='HERO_TALENT'},'no-match','none chosen, any');expect(a,{type='HERO_TALENT',subtree=21},'no-match','none chosen')
    s.hero=21;expect(a,{type='HERO_TALENT'},'match','any');expect(a,{type='HERO_TALENT',subtree=21},'match');expect(a,{type='HERO_TALENT',subtree=22},'no-match')
    s.hero=SECRET;expect(a,{type='HERO_TALENT',subtree=21},'unavailable')
    s.hero='x';expect(a,{type='HERO_TALENT',subtree=21},'unavailable','malformed')
    e.C_ClassTalents=nil;expect(a,{type='HERO_TALENT'},'unavailable','missing')
    local def=a.conditionDefinitions.HERO_TALENT
    assert(def.valid(0,{}) and def.valid(0,{subtree=21}) and not def.valid(0,{subtree=0}) and not def.valid(0,{subtree=1.5}) and not def.valid(0,{subtree='a'}))
end)

test('SPELL_GLOW asks the spell and its relatives, and is false only when none glows',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        local glow={type='SPELL_GLOW',spell=116858}
        expect(a,glow,'no-match',name)
        s.glow[116858]=true;expect(a,glow,'match',name..' the spell itself')
        s.glow[116858]=false;s.glow[11366]=true;expect(a,glow,'match',name..' an override')
        s.glow[11366]=SECRET;expect(a,glow,'unavailable',name..' an unreadable relative leaves not-glowing unproven')
        s.glow[116858]=true;expect(a,glow,'match',name..' a glowing relative wins over an unreadable one')
    end
    local _,a=client('retail')
    local def=a.conditionDefinitions.SPELL_GLOW
    assert(def.valid(0,{spell=116858}) and not def.valid(0,{}) and not def.valid(0,{spell=116858,ranked='yes'}))
end)

test('ITEM_COOLDOWN with a trinket slot reads the equipped trinket whatever it is, and an empty slot is false',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        local ready={type='ITEM_COOLDOWN',slot=13,operator='LESSTHANOREQUALS',value=0}
        a.GetEquippedSlotInfo=function(_,slot) local id=s.slots[slot];if id==nil then return false end;return {itemID=id} end
        expect(a,ready,'no-match',name..' empty slot')
        s.slots[13]=200;s.cooldown[200]={90,30}   -- ends at 120, 20 s left at time 100
        expect(a,ready,'no-match',name);expect(a,{type='ITEM_COOLDOWN',slot=13,operator='LESSTHAN',value=21},'match',name)
        s.cooldown[200]={0,0};expect(a,ready,'match',name..' ready')
        s.cooldown[200]={0,0,false};expect(a,ready,'unavailable',name..' no use effect')
        s.slots[14]=201;s.cooldown[201]={95,10};expect(a,{type='ITEM_COOLDOWN',slot=14,operator='EQUALS',value=5},'match',name..' second slot')
        s.cooldown[201]={SECRET,10};expect(a,{type='ITEM_COOLDOWN',slot=14,operator='EQUALS',value=5},'unavailable',name..' secret cooldown')
        a.GetEquippedSlotInfo=function() return nil,'item-data-pending' end;expect(a,ready,'unavailable',name..' equipment unknown')
        a.GetEquippedSlotInfo=nil;expect(a,ready,'unavailable',name..' no build context')
    end
    local _,a=client('retail');local def=a.conditionDefinitions.ITEM_COOLDOWN
    assert(def.valid(0,{slot=13,operator='EQUALS',value=0}) and def.valid(0,{slot=14,operator='EQUALS',value=0}) and not def.valid(0,{slot=12,operator='EQUALS',value=0}) and not def.valid(0,{slot=13,operator='EQUALS',value=-1}))
    -- The released shape is untouched: an item (set), no slot.
    assert(def.valid(0,{item='00000000-0000-0000-0000-000000000001',operator='EQUALS',value=0}) and def.valid(0,{item={5512},operator='EQUALS',value=0}) and not def.valid(0,{operator='EQUALS',value=0}),'an item or a slot is needed')
    local text=def.print(0,{slot=13,operator='LESSTHAN',value=3});assert(text:find('Trinket 1',1,true) and not text:find('<',1,true),text)
    assert(def.requiredFields[1]=='operator' and #def.requiredFields==2,'an item is no longer required when a slot is chosen')
end)

local function party(s,members,roles,dead) s.members=members;s.raid=false;s.roles=roles or {};s.dead=dead or {} end
local function count(measure,operator,value,percent) return {type='GROUP_COUNT',measure=measure,operator=operator,value=value,percent=percent} end
test('GROUP_COUNT size counts you, and 1 means alone',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        party(s,0);expect(a,count('size','EQUALS',1),'match',name..' alone')
        party(s,3);expect(a,count('size','EQUALS',3),'match',name..' party');expect(a,count('size','GREATERTHAN',3),'no-match',name)
        s.raid=true;s.members=25;expect(a,count('size','GREATERTHANOREQUALS',10),'match',name..' raid')
        s.members=40;expect(a,count('size','EQUALS',40),'match',name..' a full raid')
        s.members=SECRET;expect(a,count('size','EQUALS',1),'unavailable',name)
        s.members=41;expect(a,count('size','EQUALS',1),'unavailable',name..' malformed')
    end
end)

test('GROUP_COUNT counts assigned roles, you included, in a party and a raid',function()
    for _,name in ipairs({'retail','forever','mists'}) do
        local _,a,_,s=client(name)
        party(s,5,{player='TANK',party1='HEALER',party2='DAMAGER',party3='DAMAGER',party4='NONE'})
        expect(a,count('DAMAGER','EQUALS',2),'match',name)
        expect(a,count('TANK','EQUALS',1),'match',name..' you are counted')
        expect(a,count('HEALER','GREATERTHAN',1),'no-match',name)
        s.raid=true;s.members=3;s.roles={raid1='TANK',raid2='TANK',raid3='HEALER'}
        expect(a,count('TANK','EQUALS',2),'match',name..' raid')
        s.roles={raid1='TANK',raid2=SECRET,raid3='HEALER'}
        expect(a,count('TANK','EQUALS',1),'unavailable',name..' one unreadable member makes the count unavailable')
        expect(a,count('size','EQUALS',3),'match',name..' the size does not read roles')
        s.roles={raid1=3,raid2='TANK',raid3='HEALER'}
        expect(a,count('TANK','EQUALS',1),'unavailable',name..' malformed role')
    end
end)

test('GROUP_COUNT dead counts you too, in a party and a raid',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        party(s,4,{},{player=true,party1=true,party3=true})
        expect(a,count('dead','EQUALS',3),'match',name..' party: you and two others are dead')
        -- A raid lists you among raid1-4 (here raid2), so you are counted once.
        s.raid=true;s.members=4;s.dead={raid1=true,raid2=true,raid4=true}
        expect(a,count('dead','EQUALS',3),'match',name..' raid: you are one of the three')
        s.dead={raid1=true,raid4=true}
        expect(a,count('dead','EQUALS',2),'match',name..' raid: you are alive')
        s.dead={raid1=SECRET};expect(a,count('dead','EQUALS',0),'unavailable',name..' an unreadable member')
        s.dead={raid1='yes'};expect(a,count('dead','EQUALS',0),'unavailable',name..' a malformed member')
        expect(a,count('size','EQUALS',4),'match',name..' the size does not read deaths')
    end
end)

test('GROUP_COUNT compares a percent of the whole group, you included',function()
    for _,name in ipairs({'retail','mists'}) do
        local _,a,_,s=client(name)
        -- "More than half the group is dead and I am not": Run for your lives.
        party(s,4,{},{party1=true,party2=true,party3=true})
        expect(a,count('dead','GREATERTHAN',50,true),'match',name..' three of four are dead');expect(a,count('dead','EQUALS',75,true),'match',name)
        expect(a,{type='AND',value={count('dead','GREATERTHAN',50,true),{type='PLAYER_STATE',state='dead'}}},'no-match',name..' and I am alive: not dead')
        s.dead.player=true;expect(a,count('dead','EQUALS',100,true),'match',name..' you are part of the whole')
        party(s,4,{player='TANK',party1='HEALER',party2='DAMAGER',party3='DAMAGER'})
        expect(a,count('DAMAGER','EQUALS',50,true),'match',name..' two of four');expect(a,count('TANK','LESSTHAN',30,true),'match',name)
        expect(a,count('TANK','EQUALS',1),'match',name..' the count of the same role')
        party(s,0,{player='DAMAGER'});expect(a,count('DAMAGER','EQUALS',100,true),'match',name..' alone you are the whole group')
        party(s,0,{},{player=true});expect(a,count('dead','EQUALS',100,true),'match',name..' alone and dead')
    end
    local _,a=client('retail');local def=a.conditionDefinitions.GROUP_COUNT
    assert(def.valid(0,count('dead','GREATERTHAN',50,true)) and def.valid(0,count('size','EQUALS',5)) and def.valid(0,count('TANK','EQUALS',1,false)))
    assert(not def.valid(0,count('size','EQUALS',50,true)),'the size is always 100 percent of itself')
    assert(not def.valid(0,count('dead','EQUALS',101,true)) and def.valid(0,count('dead','EQUALS',101)) and not def.valid(0,count('dead','EQUALS',-1)))
    assert(not def.valid(0,count('NONE','EQUALS',1)) and not def.valid(0,{type='GROUP_COUNT',operator='EQUALS',value=1}) and not def.valid(0,count('dead','EQUALS',1,'yes')))
    for _,case in ipairs({count('size','EQUALS',5),count('TANK','GREATERTHAN',1),count('dead','GREATERTHAN',50,true),count('HEALER','LESSTHAN',20,true)}) do
        local text=def.print(0,case);assert(type(text)=='string' and not text:find('<',1,true),text)
    end
    assert(def.print(0,count('dead','GREATERTHAN',50,true)):find('percent',1,true))
end)

test('the group snapshot reads only what its measure needs, once per evaluation',function()
    local _,a,_,s=client('retail')
    party(s,5,{player='TANK',party1='HEALER'},{party2=true})
    local before=s.calls.GetNumGroupMembers or 0
    local result=a:evaluateConditionResult({type='AND',value={count('size','EQUALS',5),count('HEALER','EQUALS',1),count('dead','EQUALS',1),count('TANK','EQUALS',1)}})
    assert(result.status=='match',result.status..' '..tostring(result.reason))
    assert(s.calls.GetNumGroupMembers==before+3,'one snapshot per measure kind: size, roles, dead')
    local rolesBefore=s.calls.UnitGroupRolesAssigned or 0
    a:evaluateConditionResult(count('size','EQUALS',5));a:evaluateConditionResult(count('dead','EQUALS',1))
    assert((s.calls.UnitGroupRolesAssigned or 0)==rolesBefore,'a size or death count never asks for roles')
end)

test('editor round trips: every condition builds its widget and prints a summary',function()
    local _,a=client('retail')
    for _,tag in ipairs(TAGS) do
        local def=a.conditionDefinitions[tag]
        assert(type(def.description)=='string' and type(def.print(0,{}))=='string',tag)
        if def.help then def.help({AddChild=function() end}) end
    end
    local fields={
        PLAYER_STATE={state='ghost'},ENCOUNTER={},KEYSTONE_LEVEL={operator='GREATERTHAN',value=10},
        GROUP_COUNT={measure='TANK',operator='EQUALS',value=1,percent=false},HERO_TALENT={subtree=21},SPELL_GLOW={spell=116858},
        INSTANCE={value='party',difficulty=8,instanceID=2648},ITEM_COOLDOWN={slot=13,operator='LESSTHAN',value=1},
    }
    for tag,value in pairs(fields) do
        value.type=tag;assert(a.conditionDefinitions[tag].valid(0,value),tag..' rejects a valid saved value')
        assert(not a.conditionDefinitions[tag].print(0,value):find('<'),tag..' left a placeholder in a complete summary: '..a.conditionDefinitions[tag].print(0,value))
    end
    -- A required field missing is invalid.
    for _,tag in ipairs({'PLAYER_STATE','KEYSTONE_LEVEL','GROUP_COUNT','ITEM_COOLDOWN','SPELL_GLOW'}) do
        assert(not a.conditionDefinitions[tag].valid(0,{type=tag}),tag..' accepts an empty value')
    end
end)

test('the conditions join their categories and the Switch picker once per profile',function()
    local _,a=client('retail')
    local profile={switch_conditions={'AND'},condition_groups={
        {id='fa10aaf8-bc71-480f-9062-c949fd7c74e9',conditions={'ZONE'}},{id='b8136123-2bda-4230-a77a-89ea2aed3a1a',conditions={'CLASS'}},
        {id='fca4ff75-4085-458a-b5bf-27a6b52f2092',conditions={'EQUIPPED'}}}}
    local db={profile=profile};a:InitializeWorldConditions(nil,db)
    assert(profile.worldConditionsSeeded)
    local function has(list,tag) for _,v in ipairs(list) do if v==tag then return true end end end
    assert(has(profile.switch_conditions,'ENCOUNTER') and has(profile.switch_conditions,'HERO_TALENT') and has(profile.switch_conditions,'PLAYER_STATE') and has(profile.switch_conditions,'GROUP_COUNT'))
    assert(has(profile.condition_groups[1].conditions,'PLAYER_STATE') and has(profile.condition_groups[1].conditions,'KEYSTONE_LEVEL'))
    assert(has(profile.condition_groups[2].conditions,'GROUP_COUNT') and has(profile.condition_groups[2].conditions,'ECLIPSE'))
    local count=#profile.switch_conditions;a:InitializeWorldConditions(nil,db);assert(#profile.switch_conditions==count,'seeded twice')
    table.remove(profile.switch_conditions,2);a:InitializeWorldConditions(nil,db);assert(#profile.switch_conditions==count-1,'a removed seed came back')
end)

test('a development profile seeded with the merged-away drafts loses exactly those tags',function()
    local _,a=client('retail')
    local profile={worldConditionsSeeded=true,switch_conditions={'AND','MOUNTED','ENCOUNTER','GROUP_SIZE','RESTING'},condition_groups={
        {id='fa10aaf8-bc71-480f-9062-c949fd7c74e9',conditions={'ZONE','MOUNTED','SWIMMING','PLAYER_STATE','INSTANCE_ID'}},
        {id='fca4ff75-4085-458a-b5bf-27a6b52f2092',conditions={'EQUIPPED','TRINKET_COOLDOWN'}}}}
    a:InitializeWorldConditions(nil,{profile=profile})
    assert(table.concat(profile.switch_conditions,',')=='AND,ENCOUNTER',table.concat(profile.switch_conditions,','))
    assert(table.concat(profile.condition_groups[1].conditions,',')=='ZONE,PLAYER_STATE' and table.concat(profile.condition_groups[2].conditions,',')=='EQUIPPED')
end)

test('the reason texts exist for every unsupported reason',function()
    local _,a=client('era')
    local reasons={KEYSTONE_LEVEL=UNSUPPORTED.KEYSTONE_LEVEL,HERO_TALENT=UNSUPPORTED.HERO_TALENT,GROUP_COUNT={era='no-group-roles'}}
    for tag,list in pairs(reasons) do
        for _,reason in pairs(list) do
            local text=a:DescribeUnsupportedCondition({code='unsupported-condition',condition=tag,reason=reason})
            assert(text and not text:find(reason,1,true),tag..' '..reason..' has no readable reason: '..tostring(text))
        end
    end
end)

-- Whole poll: the real addon in TOC order (TBC Shaman, bars 403, 8042, 324, 8017).
-- An encounter selects Earth Shock, being mounted Lightning Shield, otherwise
-- Lightning Bolt; both engines answer alike and follow each change.
local root=assert(io.popen('pwd'):read('*l'))
test('whole poll: lean and standard engines agree on ENCOUNTER and PLAYER_STATE',function()
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=true,buttons=true,poll=.15})
    local a,e=c.a,c.e
    c.load('Platform/world_state.lua')
    local state={mounted=false,encounter=false}
    e.IsMounted=function() return state.mounted end
    e.C_InstanceEncounter={IsEncounterInProgress=function() return state.encounter end}
    a.db.profile.idle_poll=0
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id='world'}}
    assert(a:CommitRotationDraft(reference,nil,{body={name='World',priority=0,cooldowns={},rotation={
        {id='boss',type='spell',action=8042,conditions={type='ENCOUNTER'}},
        {id='ride',type='spell',action=324,conditions={type='PLAYER_STATE',state='mounted'}},
        {id='bolt',type='spell',action=403,conditions={}}}}},'class'))
    a:HandleCommand('set World');for _=1,3 do c.tick() end
    for _,engine in ipairs({'lean','standard'}) do
        assert(a:SetEvaluationEngine(engine))
        state.mounted,state.encounter=false,false;c.fire('PLAYER_MOUNT_DISPLAY_CHANGED');c.tick();c.tick()
        assert(a.currentSpell==403,engine..' on foot: '..tostring(a.currentSpell))
        state.encounter=true;c.fire('ENCOUNTER_START');c.tick();c.tick()
        assert(a.currentSpell==8042,engine..' in an encounter: '..tostring(a.currentSpell))
        state.encounter=false;state.mounted=true;c.fire('ENCOUNTER_END');c.tick();c.tick()
        assert(a.currentSpell==324,engine..' mounted: '..tostring(a.currentSpell))
        state.mounted=false;c.tick();c.tick()
        assert(a.currentSpell==403,engine..' on foot again: '..tostring(a.currentSpell))
    end
    assert(a:SetEvaluationEngine('lean'))
    assert(not a.adviceErrorReport,'evaluation raised an error')
    -- The seed flag is a valid profile scalar.
    c.load('UI/settings_draft.lua');c.load('Core/profile_data.lua')
    assert(a:ValidateProfileTransfer({worldConditionsSeeded=true}) and not a:ValidateProfileTransfer({worldConditionsSeeded='yes'}))
end)

finish()
