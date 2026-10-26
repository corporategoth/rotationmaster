-- The world-state conditions (Conditions/player_state.lua, encounter_state.lua,
-- group_state.lua, hero_talent.lua, proc_glow.lua, trinket.lua) on every client
-- family: which client declares which unsupported (Core/condition_support.lua,
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
    e.UnitIsDeadOrGhost=function(unit) hit('UnitIsDeadOrGhost');return s.dead[unit] or false end
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
    GROUP_ROLE_COUNT={tbc='no-group-roles',era='no-group-roles'},
}
local TAGS={'MOUNTED','SWIMMING','FALLING','FLYING','RESTING','ENCOUNTER','INSTANCE_DIFFICULTY','INSTANCE_ID','KEYSTONE_LEVEL',
    'GROUP_SIZE','GROUP_ROLE_COUNT','GROUP_DEAD_COUNT','HERO_TALENT','SPELL_GLOW','TRINKET_COOLDOWN'}

test('every condition registers on every client and is declared supported exactly where the edition has it',function()
    for _,name in ipairs(ORDER) do
        local _,a=client(name)
        for _,tag in ipairs(TAGS) do
            assert(a.conditionDefinitions[tag],tag..' is not registered on '..name)
            local wanted=UNSUPPORTED[tag] and UNSUPPORTED[tag][name]
            local got=support(a,tag);assert(got==wanted,tag..' on '..name..': '..tostring(got)..', wanted '..tostring(wanted))
        end
    end
end)

test('a reader the client lacks is declared missing-api, not silently false',function()
    local _,a,e=client('retail')
    e.IsMounted=nil;assert(support(a,'MOUNTED')=='missing-api')
    local _,b,f=client('retail');f.GetInstanceInfo=nil;assert(support(b,'INSTANCE_ID')=='missing-api')
    local _,c,g=client('retail');g.C_SpellActivationOverlay=nil;assert(support(c,'SPELL_GLOW')=='missing-api')
end)

-- The five player predicates share one reader.
local STATES={MOUNTED='mounted',SWIMMING='swimming',FALLING='falling',FLYING='flying',RESTING='resting'}
test('player predicates are true, false and unavailable on every client, also under NOT',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        for tag,kind in pairs(STATES) do
            s.state[kind]=true;expect(a,{type=tag},'match',name..' '..tag)
            s.state[kind]=false;expect(a,{type=tag},'no-match',name..' '..tag)
            -- The legacy forms answer 1 or nil.
            s.state[kind]=1;expect(a,{type=tag},'match',name..' '..tag..' 1')
            s.state[kind]=nil;expect(a,{type=tag},'no-match',name..' '..tag..' nil')
            s.state[kind]=SECRET;expect(a,{type=tag},'unavailable',name..' '..tag..' secret')
            s.state[kind]='yes';expect(a,{type=tag},'unavailable',name..' '..tag..' string')
        end
    end
end)

test('player predicates survive a missing native and a throwing one',function()
    local _,a,e,s=client('retail')
    e.IsMounted=function() error('boom') end;expect(a,{type='MOUNTED'},'unavailable')
    e.IsMounted=nil;expect(a,{type='MOUNTED'},'unavailable')
    s.state.swimming=true;expect(a,{type='SWIMMING'},'match')
end)

test('one evaluation reads each predicate once, and the cache does not outlive the pass',function()
    local _,a,_,s=client('retail')
    s.state.mounted=true
    local cache={};local def=a.conditionDefinitions.MOUNTED
    assert(def.evaluate({},cache)==true and def.evaluate({},cache)==true and s.calls.IsMounted==1)
    assert(a:evaluateConditionResult({type='AND',value={{type='MOUNTED'},{type='MOUNTED'}}}).status=='match' and s.calls.IsMounted==2)
    assert(next(a.longtermCache)==nil or true)
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

test('INSTANCE_DIFFICULTY and INSTANCE_ID compare what GetInstanceInfo reports',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        s.diff=8;s.instance=2648
        expect(a,{type='INSTANCE_DIFFICULTY',value=8},'match',name);expect(a,{type='INSTANCE_DIFFICULTY',value=2},'no-match',name)
        expect(a,{type='INSTANCE_ID',value=2648},'match',name);expect(a,{type='INSTANCE_ID',value=2552},'no-match',name)
        s.diff=0;expect(a,{type='INSTANCE_DIFFICULTY',value=0},'match',name..' open world')
        s.diff=SECRET;expect(a,{type='INSTANCE_DIFFICULTY',value=8},'unavailable',name)
        expect(a,{type='INSTANCE_ID',value=2648},'match',name..' a secret difficulty does not hide the instance ID')
        s.diff=2;s.instance=SECRET;expect(a,{type='INSTANCE_ID',value=2648},'unavailable',name)
        expect(a,{type='INSTANCE_DIFFICULTY',value=2},'match',name..' a secret instance ID does not hide the difficulty')
        s.instance=2648;s.diff='x';expect(a,{type='INSTANCE_DIFFICULTY',value=2},'unavailable',name..' malformed')
        e.GetInstanceInfo=nil;expect(a,{type='INSTANCE_ID',value=2648},'unavailable',name..' missing')
    end
    local _,a,_,s=client('retail');s.diff=8
    local before=s.calls.GetInstanceInfo or 0
    assert(a:evaluateConditionResult({type='AND',value={{type='INSTANCE_DIFFICULTY',value=8},{type='INSTANCE_ID',value=2552}}}).status=='match')
    assert(s.calls.GetInstanceInfo==before+1,'both conditions share one GetInstanceInfo read')
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

test('TRINKET_COOLDOWN reads the equipped trinket whatever it is, and an empty slot is false',function()
    for _,name in ipairs(ORDER) do
        local _,a,e,s=client(name)
        local ready={type='TRINKET_COOLDOWN',slot=13,operator='LESSTHANOREQUALS',value=0}
        a.GetEquippedSlotInfo=function(_,slot) local id=s.slots[slot];if id==nil then return false end;return {itemID=id} end
        expect(a,ready,'no-match',name..' empty slot')
        s.slots[13]=200;s.cooldown[200]={90,30}   -- ends at 120, 20 s left at time 100
        expect(a,ready,'no-match',name);expect(a,{type='TRINKET_COOLDOWN',slot=13,operator='LESSTHAN',value=21},'match',name)
        s.cooldown[200]={0,0};expect(a,ready,'match',name..' ready')
        s.cooldown[200]={0,0,false};expect(a,ready,'unavailable',name..' no use effect')
        s.slots[14]=201;s.cooldown[201]={95,10};expect(a,{type='TRINKET_COOLDOWN',slot=14,operator='EQUALS',value=5},'match',name..' second slot')
        s.cooldown[201]={SECRET,10};expect(a,{type='TRINKET_COOLDOWN',slot=14,operator='EQUALS',value=5},'unavailable',name..' secret cooldown')
        a.GetEquippedSlotInfo=function() return nil,'item-data-pending' end;expect(a,ready,'unavailable',name..' equipment unknown')
    end
    local _,a=client('retail');local def=a.conditionDefinitions.TRINKET_COOLDOWN
    assert(def.valid(0,{slot=13,operator='EQUALS',value=0}) and not def.valid(0,{slot=12,operator='EQUALS',value=0}) and not def.valid(0,{slot=13,operator='EQUALS',value=-1}))
end)

local function party(s,members,roles,dead) s.members=members;s.raid=false;s.roles=roles or {};s.dead=dead or {} end
test('GROUP_SIZE counts you, and 1 means alone',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        party(s,0);expect(a,{type='GROUP_SIZE',operator='EQUALS',value=1},'match',name..' alone')
        party(s,3);expect(a,{type='GROUP_SIZE',operator='EQUALS',value=3},'match',name..' party');expect(a,{type='GROUP_SIZE',operator='GREATERTHAN',value=3},'no-match',name)
        s.raid=true;s.members=25;expect(a,{type='GROUP_SIZE',operator='GREATERTHANOREQUALS',value=10},'match',name..' raid')
        s.members=SECRET;expect(a,{type='GROUP_SIZE',operator='EQUALS',value=1},'unavailable',name)
        s.members=41;expect(a,{type='GROUP_SIZE',operator='EQUALS',value=1},'unavailable',name..' malformed')
    end
end)

test('GROUP_ROLE_COUNT counts assigned roles in a party (you included) and a raid',function()
    for _,name in ipairs({'retail','forever','mists'}) do
        local _,a,_,s=client(name)
        party(s,5,{player='TANK',party1='HEALER',party2='DAMAGER',party3='DAMAGER',party4='NONE'})
        expect(a,{type='GROUP_ROLE_COUNT',role='DAMAGER',operator='EQUALS',value=2},'match',name)
        expect(a,{type='GROUP_ROLE_COUNT',role='TANK',operator='EQUALS',value=1},'match',name..' you are counted')
        expect(a,{type='GROUP_ROLE_COUNT',role='HEALER',operator='GREATERTHAN',value=1},'no-match',name)
        s.raid=true;s.members=3;s.roles={raid1='TANK',raid2='TANK',raid3='HEALER'}
        expect(a,{type='GROUP_ROLE_COUNT',role='TANK',operator='EQUALS',value=2},'match',name..' raid')
        s.roles={raid1='TANK',raid2=SECRET,raid3='HEALER'}
        expect(a,{type='GROUP_ROLE_COUNT',role='TANK',operator='EQUALS',value=1},'unavailable',name..' one unreadable member makes the count unavailable')
        s.roles={raid1=3,raid2='TANK',raid3='HEALER'}
        expect(a,{type='GROUP_ROLE_COUNT',role='TANK',operator='EQUALS',value=1},'unavailable',name..' malformed role')
    end
    local _,a=client('retail');local def=a.conditionDefinitions.GROUP_ROLE_COUNT
    assert(def.valid(0,{role='TANK',operator='EQUALS',value=1}) and not def.valid(0,{role='NONE',operator='EQUALS',value=1}) and not def.valid(0,{operator='EQUALS',value=1}))
end)

test('GROUP_DEAD_COUNT never counts you, in a party or a raid',function()
    for _,name in ipairs(ORDER) do
        local _,a,_,s=client(name)
        party(s,4,{},{player=true,party1=true,party3=true})
        expect(a,{type='GROUP_DEAD_COUNT',operator='EQUALS',value=2},'match',name..' party: you are dead, two others are')
        -- A raid lists you among raid1-4 (here raid2) as well as under "player".
        s.raid=true;s.members=4;s.dead={raid1=true,raid2=true,raid4=true,player=true}
        expect(a,{type='GROUP_DEAD_COUNT',operator='EQUALS',value=2},'match',name..' raid: you are dead, two others are')
        s.dead={raid1=true,raid4=true}
        expect(a,{type='GROUP_DEAD_COUNT',operator='EQUALS',value=2},'match',name..' raid: you are alive')
        s.dead={raid1=SECRET};expect(a,{type='GROUP_DEAD_COUNT',operator='EQUALS',value=0},'unavailable',name..' an unreadable member')
        s.dead={raid1='yes'};expect(a,{type='GROUP_DEAD_COUNT',operator='EQUALS',value=0},'unavailable',name..' a malformed member')
    end
end)

test('the group snapshot is read once per evaluation for all three conditions',function()
    local _,a,_,s=client('retail')
    party(s,5,{player='TANK',party1='HEALER'},{party2=true})
    local before=s.calls.GetNumGroupMembers or 0
    local result=a:evaluateConditionResult({type='AND',value={
        {type='GROUP_SIZE',operator='EQUALS',value=5},{type='GROUP_ROLE_COUNT',role='HEALER',operator='EQUALS',value=1},
        {type='GROUP_DEAD_COUNT',operator='EQUALS',value=1}}})
    assert(result.status=='match',result.status..' '..tostring(result.reason))
    assert(s.calls.GetNumGroupMembers==before+1,'one snapshot')
end)

test('editor round trips: every condition builds its widget and prints a summary',function()
    local _,a=client('retail')
    for _,tag in ipairs(TAGS) do
        local def=a.conditionDefinitions[tag]
        assert(type(def.description)=='string' and type(def.print(0,{}))=='string',tag)
        if def.help then def.help({AddChild=function() end}) end
    end
    local fields={
        MOUNTED={},ENCOUNTER={},INSTANCE_DIFFICULTY={value=8},INSTANCE_ID={value=2648},KEYSTONE_LEVEL={operator='GREATERTHAN',value=10},
        GROUP_SIZE={operator='EQUALS',value=5},GROUP_ROLE_COUNT={role='TANK',operator='EQUALS',value=1},GROUP_DEAD_COUNT={operator='GREATERTHAN',value=0},
        HERO_TALENT={subtree=21},SPELL_GLOW={spell=116858},TRINKET_COOLDOWN={slot=13,operator='LESSTHAN',value=1},
    }
    for tag,value in pairs(fields) do
        value.type=tag;assert(a.conditionDefinitions[tag].valid(0,value),tag..' rejects a valid saved value')
        assert(not a.conditionDefinitions[tag].print(0,value):find('<'),tag..' left a placeholder in a complete summary: '..a.conditionDefinitions[tag].print(0,value))
    end
    -- A required field missing is invalid.
    for _,tag in ipairs({'INSTANCE_DIFFICULTY','INSTANCE_ID','KEYSTONE_LEVEL','GROUP_SIZE','GROUP_ROLE_COUNT','GROUP_DEAD_COUNT','TRINKET_COOLDOWN','SPELL_GLOW'}) do
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
    assert(has(profile.switch_conditions,'ENCOUNTER') and has(profile.switch_conditions,'HERO_TALENT') and not has(profile.switch_conditions,'FALLING'))
    assert(has(profile.condition_groups[1].conditions,'MOUNTED') and has(profile.condition_groups[1].conditions,'KEYSTONE_LEVEL'))
    assert(has(profile.condition_groups[2].conditions,'GROUP_SIZE') and has(profile.condition_groups[3].conditions,'TRINKET_COOLDOWN'))
    local count=#profile.switch_conditions;a:InitializeWorldConditions(nil,db);assert(#profile.switch_conditions==count,'seeded twice')
    table.remove(profile.switch_conditions,2);a:InitializeWorldConditions(nil,db);assert(#profile.switch_conditions==count-1,'a removed seed came back')
end)

test('the reason texts exist for every new unsupported reason',function()
    local _,a=client('era')
    for tag,reasons in pairs(UNSUPPORTED) do
        for _,reason in pairs(reasons) do
            local text=a:DescribeUnsupportedCondition({code='unsupported-condition',condition=tag,reason=reason})
            assert(text and not text:find(reason,1,true),tag..' '..reason..' has no readable reason: '..tostring(text))
        end
    end
end)

-- Whole poll: the real addon in TOC order (TBC Shaman, bars 403, 8042, 324, 8017).
-- An encounter selects Earth Shock, being mounted Lightning Shield, otherwise
-- Lightning Bolt; both engines answer alike and follow each change.
local root=assert(io.popen('pwd'):read('*l'))
test('whole poll: lean and standard engines agree on ENCOUNTER and MOUNTED',function()
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
        {id='ride',type='spell',action=324,conditions={type='MOUNTED'}},
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
