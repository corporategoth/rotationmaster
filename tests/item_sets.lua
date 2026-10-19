local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(native)
    local f=F.new();local a,e=f.addon,f.env
    a.db.profile.itemsets={s={items={10,11}}};a.db.global.itemsets={g={items={11}}};a.combatCache={};a.bagContents={[99]={count=100,slots={1}}}
    local state={bags={[10]=2,[11]=1},equipped={},names=true,calls=0}
    local api={GetItemInfoInstant=function(value) state.calls=state.calls+1;if state.names then return value=='Potion' and 10 or value=='item:11' and 11 or tonumber(value) end end,
        IsEquippedItem=function(id) return state.equipped[id]==true end}
    local function slots(bag) return bag==0 and 2 or 0 end
    local function info(_,slot)
        local id=slot==1 and 10 or 11;local count=state.bags[id] or 0;if count==0 then return end
        if native then return {itemID=id,stackCount=count} end
        return 123,count,false,1,false,false,'item:'..id,false,false,id
    end
    if native then e.C_Item=api;e.C_Container={GetContainerNumSlots=slots,GetContainerItemInfo=info}
    else for key,fn in pairs(api) do e[key]=fn end;e.GetContainerNumSlots=slots;e.GetContainerItemInfo=info end
    e.NUM_BAG_SLOTS=4
    f.load('Platform/items.lua');f.load('Platform/inventory.lua');f.load('Core/itemset_services.lua');f.load('Options/itemset.lua')
    local h=io.open('Core/item_sets.lua');if h then h:close();f.load('Core/item_sets.lua') end
    return f,state,api
end
test('item-set identity and membership use native-only or legacy public IDs names and links',function()
    for _,native in ipairs({true,false}) do
        local f=fixture(native);local a=f.addon
        assert(a:FindFirstItemInItems({'Potion',11})==10)
        assert(a:FindFirstItemInItemSet('s')==10 and a:FindFirstItemInItemSet('g')==11)
        assert(a:FindItemInItems({10,'item:11'},'Potion')==10)
        assert(a:FindItemInItemSet('s','item:11')==11 and a:FindItemInItemSet('s',10)==10)
        assert(a:FindItemInItems({11},'Potion')==nil)
    end
end)
test('ordered available selection uses current bags and equipped opt-in without stale addon caches',function()
    for _,native in ipairs({true,false}) do
        local f,s=fixture(native);local a=f.addon
        assert(a:FindFirstItemOfItemSet({},'s',false)==10)
        s.bags[10]=0;assert(a:FindFirstItemOfItemSet({},'s',false)==11)
        s.equipped[10]=true;assert(a:FindFirstItemOfItemSet({},'s',true)==10)
        assert(a:FindFirstItemOfItemSet({},'s',false)==11,'worn item leaked into bag-only selection')
        s.equipped[10]=false;s.bags[11]=0;assert(a:FindFirstItemOfItemSet({},'s',true)==nil)
        assert(a:FindFirstItemOfItems({}, {99},false)==nil,'stale addon snapshot became ownership')
    end
end)
test('unknown metadata is retried on later calls and unavailable earlier priority cannot silently advance',function()
    local f,s,api=fixture(true);local a=f.addon;s.names=false
    assert(a:FindFirstItemInItems({'Potion',11})==nil,'unknown earlier identity was skipped')
    s.names=true;assert(a:FindFirstItemInItems({'Potion',11})==10,'metadata did not recover')
    api.IsEquippedItem=function() error('native equipped query failed') end
    assert(a:FindFirstItemOfItems({}, {10,11},true)==nil)
    api.IsEquippedItem=function(id) return id==11 end
    f.env.C_Container.GetContainerItemInfo=function() error('native bags failed') end
    assert(a:FindFirstItemOfItems({}, {10,11},true)==nil,'earlier unknown ownership was skipped')
    assert(a:FindFirstItemOfItems({}, {11},true)==11,'positive first equipped candidate should not need bag data')
end)
test('missing malformed and explicitly shadowed item sets never fall through to global data',function()
    local f=fixture(true);local a=f.addon
    a.db.global.itemsets.s={items={11}}
    for _,bad in ipairs({false,{}, {items=false},{items={[2]=10}},{items={0}},{items={math.huge}}}) do
        a.db.profile.itemsets.s=bad
        assert(a:FindFirstItemInItemSet('s')==nil and a:FindItemInItemSet('s',11)==nil and a:FindFirstItemOfItemSet({},'s',true)==nil)
    end
    a.db.profile.itemsets.s={items={}};assert(a:FindFirstItemInItemSet('s')==nil)
    a.db.profile.itemsets.s=nil;assert(a:FindFirstItemInItemSet('s')==11)
    assert(a:FindFirstItemInItems({-1})==nil and a:FindFirstItemInItems({[2]=10})==nil)
end)
test('restricted identity ownership or bag observations never reach comparison or secure bar consumers',function()
    local f,s,api=fixture(true);local a=f.addon;local secret={}
    f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
    api.GetItemInfoInstant=function() return secret end
    assert(a:FindFirstItemInItems({'Potion'})==nil and a:FindItemInItems({10},'Potion')==nil)
    api.IsEquippedItem=function() return secret end
    assert(a:FindFirstItemOfItems({}, {10},true)==nil)
    f.env.C_Container.GetContainerItemInfo=function() return secret end
    assert(a:FindFirstItemOfItems({}, {10},false)==nil)
end)
finish()
