local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(native)
    local f=F.new();local a,e=f.addon,f.env
    a.db.profile.itemsets={pots={name='Potions',items={10,11}}};a.db.global.itemsets={};a.bagContents={};a.combatCache={}
    local s={count={[10]=2,[11]=5},equipped={},start=0,duration=0,enabled=true,range=true,hasRange=true,level=11,minimum=1,gcdStart=0,gcdDuration=0,calls={}}
    local function call(name) s.calls[name]=(s.calls[name] or 0)+1 end
    local api={GetItemInfoInstant=function(item) return item=='Potion' and 10 or nil end,
        GetItemInfo=function(id) call('metadata');return 'Potion '..id,'|Hitem:'..id..'|h[Potion '..id..']|h',1,1,s.minimum,'Consumable','Potion',20,'',123 end,
        GetItemCount=function(id,bank,uses) call('count'..id);assert(bank==false and uses==false);return (s.count[id] or 0)+(s.equipped[id] and 1 or 0) end,
        IsEquippedItem=function(id) call('equipped'..id);return s.equipped[id]==true end,
        GetItemCooldown=function() call('cooldown');if native then return s.start,s.duration,s.enabled end;return s.start,s.duration,s.enabled and 1 or 0 end,
        ItemHasRange=function() return s.hasRange end,IsItemInRange=function() if native or s.range==nil then return s.range end;return s.range and 1 or 0 end}
    if native then e.C_Item=api else for name,fn in pairs(api) do e[name]=fn end end
    e.NUM_BAG_SLOTS=4
    local function slots(bag) return bag==0 and 2 or 0 end
    local function entry(_,slot)
        call('bag');local id=slot==1 and 10 or 11;local count=s.count[id] or 0
        if count==0 then return end
        if native then return {itemID=id,stackCount=count} end
        return 123,count,false,1,false,false,'item:'..id,false,false,id
    end
    if native then e.C_Container={GetContainerNumSlots=slots,GetContainerItemInfo=entry} else e.GetContainerNumSlots=slots;e.GetContainerItemInfo=entry end
    e.UnitLevel=function(unit) assert(unit=='player');return s.level end
    e.C_Spell={GetSpellCooldown=function(id) assert(id==29515);return {startTime=s.gcdStart,duration=s.gcdDuration,isEnabled=true,modRate=1} end}
    local c=f.libraries.LibCompress;c.fcs16init=function() return '' end;c.fcs16update=function(_,hash,value) return hash..':'..value end;c.fcs16final=function(_,hash) return hash end
    for _,path in ipairs({'Platform/spells.lua','Platform/items.lua','Platform/inventory.lua','Core/conditions.lua'}) do f.load(path) end
    local file=io.open('Core/item_conditions.lua');if file then file:close();f.load('Core/item_conditions.lua') end
    f.load('Core/itemset_services.lua');f.load('Conditions/item.lua');return f,s,api
end
local function value(tag,extra)
    local v={type=tag,item='pots',operator='EQUALS',value=2};for k,x in pairs(extra or {}) do v[k]=x end;return v
end
test('native-only item predicates use ordered public ownership instead of stale bag or combat caches',function()
    local f,s=fixture(true);local a=f.addon
    assert(a:evaluateCondition(value('CARRYING')));assert(a:evaluateCondition(value('ITEM')));assert(a:evaluateCondition(value('ITEM_RANGE')))
    assert(a:evaluateCondition(value('ITEM_COOLDOWN',{value=0})));assert(not a:evaluateCondition(value('EQUIPPED')))
    s.count[10]=0;assert(a:evaluateCondition(value('CARRYING',{value=5})))
    s.equipped[10]=true;assert(a:evaluateCondition(value('EQUIPPED')) and a:evaluateCondition(value('ITEM')))
    s.count[11]=0;assert(a:evaluateCondition(value('CARRYING',{value=0})),'equipped item counted as carried')
end)
test('legacy item tuples keep numeric range and enabled semantics',function()
    local f,s=fixture(false);local a=f.addon
    assert(a:evaluateCondition(value('ITEM_RANGE')) and a:evaluateCondition(value('ITEM')))
    s.range=false;assert(not a:evaluateCondition(value('ITEM_RANGE')))
    s.enabled=false;assert(not a:evaluateCondition(value('ITEM')))
end)
test('item availability checks required level and readable GCD while cooldown reports stable remaining seconds',function()
    local f,s=fixture(true);local a=f.addon
    s.minimum=20;assert(not a:evaluateCondition(value('ITEM')));s.minimum=nil
    assert(a:evaluateConditionResult({type='NOT',value=value('ITEM')}).status=='unavailable','missing required level became available under NOT')
    s.minimum=1;s.start=99;s.duration=30
    assert(not a:evaluateCondition(value('ITEM')) and a:evaluateCondition(value('ITEM_COOLDOWN',{value=29})))
    s.start=99;s.duration=1.5;s.gcdStart=99;s.gcdDuration=1.5;assert(a:evaluateCondition(value('ITEM')))
    s.gcdDuration=0;assert(not a:evaluateCondition(value('ITEM')))
    s.gcdStart=1e308;s.gcdDuration=1e308
    assert(a:evaluateConditionResult({type='NOT',value=value('ITEM')}).status=='unavailable','overflowed GCD became a usable timer')
    s.enabled=false;assert(a:evaluateConditionResult({type='NOT',value=value('ITEM_COOLDOWN',{value=0})}).status=='unavailable')
end)
test('empty lists and absent inventory are known absence while missing item sets stay unavailable under NOT',function()
    local f,s=fixture(true);local a=f.addon;s.count={}
    assert(not a:evaluateCondition(value('ITEM')) and a:evaluateCondition(value('ITEM',{notcarrying=true})))
    assert(not a:evaluateCondition(value('ITEM',{item={}})) and a:evaluateCondition(value('CARRYING',{item={},value=0})))
    for _,tag in ipairs({'EQUIPPED','CARRYING','ITEM','ITEM_RANGE','ITEM_COOLDOWN'}) do
        assert(a:evaluateConditionResult({type='NOT',value=value(tag,{item='missing'})}).status=='unavailable',tag..' missing set became absence')
    end
    a.db.profile.itemsets=17
    assert(a:evaluateConditionResult({type='NOT',value=value('ITEM')}).status=='unavailable','malformed item-set store became absence')
end)
test('unknown native item observations never become a positive NOT or skip to a lower-priority candidate',function()
    local f,s,api=fixture(true);local a=f.addon;local secret={};f.env.canaccessvalue=function(v) return v~=secret end
    api.GetItemCount=function() return secret end
    for _,tag in ipairs({'ITEM','ITEM_RANGE','ITEM_COOLDOWN'}) do assert(a:evaluateConditionResult({type='NOT',value=value(tag)}).status=='unavailable',tag) end
    local old=f.env.C_Container.GetContainerItemInfo;f.env.C_Container.GetContainerItemInfo=function() return {itemID=10,stackCount=secret} end
    assert(a:evaluateConditionResult({type='NOT',value=value('CARRYING')}).status=='unavailable')
    f.env.C_Container.GetContainerItemInfo=old
    api.GetItemCount=function(id) return s.count[id] end;api.IsEquippedItem=function() return secret end
    assert(a:evaluateConditionResult({type='NOT',value=value('EQUIPPED')}).status=='unavailable')
    api.IsItemInRange=function() return secret end;assert(a:evaluateConditionResult({type='NOT',value=value('ITEM_RANGE')}).status=='unavailable')
    api.GetItemCooldown=function() error('unavailable native cooldown') end
    assert(a:evaluateConditionResult({type='NOT',value=value('ITEM_COOLDOWN')}).status=='unavailable')
end)
test('real item predicates cache a shared observation only for one evaluation and refresh on the next',function()
    local f,s=fixture(true);local a=f.addon
    assert(a:evaluateCondition({type='AND',value={value('CARRYING'),value('ITEM'),value('ITEM_COOLDOWN',{value=0})}}))
    assert(s.calls.count10==1 and s.calls.cooldown==1,'one evaluation sampled shared item data repeatedly')
    s.count[10]=0;assert(not a:evaluateCondition(value('CARRYING')),'stale bag cache hid a change')
end)
test('item declarations reject malformed references and describe native metadata without deprecated globals',function()
    local f=fixture(true);local a=f.addon
    for _,item in ipairs({true,17,{0},{-1},{1.5},{false},{[2]=10}}) do assert(not a:validateCondition(value('ITEM',{item=item}),0)) end
    local text=a.conditionDefinitions.ITEM.print(0,value('ITEM',{item={10}}));assert(text:find('Potion 10',1,true),'description lost public item name')
    local data=dofile('tests/fixtures/rotation_data.lua')();local result=data.ValidateBody({switch={type='ITEM'},rotation={},cooldowns={}},{conditions=a.conditionDefinitions})
    assert(not result.valid,'missing item reference was not flagged')
end)
test('bag snapshots reject incomplete slot metadata instead of turning it into known absence',function()
    local f=fixture(true);local a=f.addon
    for _,record in ipairs({{},{itemID=10},{stackCount=2}}) do
        f.env.C_Container.GetContainerItemInfo=function() return record end
        assert(a:evaluateConditionResult({type='NOT',value=value('CARRYING')}).status=='unavailable','incomplete native slot became absence')
    end
    local legacy=fixture(false);legacy.env.GetContainerItemInfo=function() return 123 end
    assert(legacy.addon:evaluateConditionResult({type='NOT',value=value('CARRYING')}).status=='unavailable','incomplete legacy slot became absence')
end)
test('malformed personal item sets never fall through to a global set with the same ID',function()
    local f,s=fixture(true);local a=f.addon;s.count={};a.db.global.itemsets.pots={name='Global potions',items={10}}
    for _,entry in ipairs({false,17,'bad'}) do
        a.db.profile.itemsets.pots=entry
        for _,tag in ipairs({'EQUIPPED','CARRYING','ITEM','ITEM_RANGE','ITEM_COOLDOWN'}) do
            assert(a:evaluateConditionResult({type='NOT',value=value(tag)}).status=='unavailable',tag..' fell through a malformed personal set')
        end
    end
end)
test('describing malformed personal sets preserves their precedence without throwing',function()
    local f=fixture(true);local a=f.addon;a.db.profile.itemsets.pots=false;a.db.global.itemsets.pots={name='Global potions',items={10}}
    local ok,text=pcall(a.conditionDefinitions.ITEM.print,0,value('ITEM'))
    assert(ok and not text:find('Global potions',1,true),'invalid personal data was described as the global set or threw')
end)
test('bag snapshots sum stacks of one candidate and include a declared reagent bag without bank slots',function()
    local f=fixture(true);local a=f.addon;f.env.WOW_PROJECT_ID=1;f.env.LE_EXPANSION_LEVEL_CURRENT=12;f.env.Enum.BagIndex={ReagentBag=5};local bags={}
    f.env.C_Container.GetContainerNumSlots=function(bag) bags[bag]=true;return bag==0 and 2 or bag==5 and 1 or 0 end
    f.env.C_Container.GetContainerItemInfo=function(bag,slot) return {itemID=10,stackCount=bag==5 and 7 or slot} end
    assert(a:evaluateCondition(value('CARRYING',{value=10})) and bags[5] and not bags[-1] and not bags[6])
    f.env.WOW_PROJECT_ID=5;f.env.LE_EXPANSION_LEVEL_CURRENT=1;bags={}
    assert(a:evaluateCondition(value('CARRYING',{value=3})) and not bags[5],'a shared reagent enum made a Classic bank bag look carried')
end)
finish()
