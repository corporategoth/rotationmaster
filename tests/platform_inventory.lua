local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture(native)
    -- The native shape is Retail's (C_Container and a reagent bag past NUM_BAG_SLOTS); no
    -- current client still has the legacy container globals, so that route runs unguarded.
    local f=native and F.new(1,12) or F.new(nil,nil,nil,{clientApi=false});local e=f.env;e.NUM_BAG_SLOTS=4;e.NUM_TOTAL_EQUIPPED_BAG_SLOTS=5
    local function size(bag) return (bag==0 or bag==5) and 2 or 0 end
    local function info(bag,slot)
        if bag==5 and slot==2 then return end
        local id=slot==1 and 10 or 11;local count=bag==5 and 7 or slot
        if native then return {itemID=id,stackCount=count} end
        return 123,count,false,1,false,false,'item:'..id,false,false,id
    end
    if native then e.C_Container={GetContainerNumSlots=size,GetContainerItemInfo=info}
    else e.GetContainerNumSlots=size;e.GetContainerItemInfo=info end
    f.load('Platform/items.lua');f.load('Platform/inventory.lua');return f
end
test('count and full bag snapshots share native or legacy validation with detached location records',function()
    for _,native in ipairs({true,false}) do
        local f=fixture(native);local p=f.addon.Platform
        assert(p.GetBagSnapshot,'full normalized bag snapshot is missing')
        local snapshot=assert(p:GetBagSnapshot());local counts=assert(p:GetBagItemCounts())
        assert(counts[10]==8 and counts[11]==2 and snapshot[10].count==8 and snapshot[11].count==2)
        assert(#snapshot[10].slots==2 and snapshot[10].slots[1].bag==0 and snapshot[10].slots[2].bag==5 and snapshot[10].slots[2].slot==1)
        snapshot[10].count=99;snapshot[10].slots[1].bag=-1;counts[10]=99
        assert(p:GetBagSnapshot()[10].slots[1].bag==0 and p:GetBagItemCounts()[10]==8)
    end
end)
test('full snapshot rejects unknown partial slots and never falls back from native slot failures',function()
    local f=fixture(true);local p=f.addon.Platform;assert(p.GetBagSnapshot)
    local called=0;f.env.GetContainerItemInfo=function() called=called+1;return 123,5,false,1,false,false,'item:10',false,false,10 end
    for _,record in ipairs({{}, {itemID=10}, {stackCount=2},false}) do
        f.env.C_Container.GetContainerItemInfo=function() return record end
        local snapshot,reason=p:GetBagSnapshot();assert(not snapshot and reason and called==0)
        assert(not p:GetBagItemCounts() and called==0)
    end
    f.env.C_Container.GetContainerItemInfo=function() error('unavailable') end
    local snapshot,reason=p:GetBagSnapshot();assert(not snapshot and reason=='api-error' and called==0)
end)
test('legacy snapshots can resolve links without returning protected or malformed coordinates',function()
    local f=fixture(false);local p=f.addon.Platform;assert(p.GetBagSnapshot)
    f.env.GetItemInfoInstant=function(value) assert(value=='item:10');return 10 end
    f.env.GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end
    f.env.GetContainerItemInfo=function() return 123,3,false,1,false,false,'item:10' end
    assert(p:GetBagSnapshot()[10].count==3 and p:GetBagItemCounts()[10]==3)
    local secret={};f.env.canaccessvalue=function(value) return not rawequal(value,secret) end
    f.env.GetContainerNumSlots=function() return secret end
    local snapshot,reason=p:GetBagSnapshot();assert(not snapshot and reason=='restricted-value')
end)
test('runtime inventory uses its receiver canonical cache and publishes detached complete snapshots',function()
    local f=fixture(true);f.load('Core/inventory.lua');local a=f.addon;local cache={};local calls,dispatches=0,0
    local snapshot={[10]={count=2,slots={{bag=0,slot=3}}}};local observation=snapshot;local why
    local platform={};function platform:GetBagSnapshot() assert(self==platform);calls=calls+1;return observation,why end
    function platform:GetItemUseSpell(id) assert(self==platform and id==10);return {name='Potion'} end
    local receiver={Platform=platform,Functions={cache={}},bagContents={[99]={count=8}}};local canonical=a.Functions.cache.getCached
    receiver.Functions.cache.getCached=function(got,method,...)
        assert(got==cache and method==platform.GetBagSnapshot and select('#',...)==1 and select(1,...)==platform)
        dispatches=dispatches+1;return canonical(got,method,...)
    end
    receiver.getCached=function() error('legacy receiver.getCached used by inventory') end;a.getCached=function() error('inventory used captured addon instead of receiver') end
    local function pack(...) return {n=select('#',...),...} end
    local ready=pack(a.UpdateBagContents(receiver,cache));assert(ready.n==1 and ready[1]==true);local first=receiver.bagContents
    assert(first[10].count==2 and first[10].spell=='Potion' and first[10].slots[1]==3 and first[10].locations[1].bag==0)
    first[10].locations[1].bag=7;first[10].slots[1]=9
    assert(a.UpdateBagContents(receiver,cache)==true and calls==1 and dispatches==2 and receiver.bagContents~=first)
    assert(receiver.bagContents[10].locations[1].bag==0 and receiver.bagContents[10].slots[1]==3 and snapshot[10].slots[1].bag==0)
    cache={};observation=false;why='inventory-blocked';ready=pack(a.UpdateBagContents(receiver,cache))
    assert(ready.n==2 and ready[1]==false and ready[2]=='inventory-blocked' and next(receiver.bagContents)==nil and receiver.bagContentsUnavailable==ready[2])
    cache={};observation=nil;why=nil;ready=pack(a.UpdateBagContents(receiver,cache));assert(ready.n==2 and ready[1]==false and ready[2]=='inventory-unavailable')
    cache={};observation={};assert(a.UpdateBagContents(receiver,cache)==true and next(receiver.bagContents)==nil and receiver.bagContentsUnavailable==nil)
end)
finish()
