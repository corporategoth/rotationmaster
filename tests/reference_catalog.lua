local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon;local names={[1]='Water',[2]='Bread'}
    f.env.GetItemInfo=function(id) id=tonumber(id) or id=='Water' and 1 or id=='Bread' and 2;local name=names[id];return name,name and '|Hitem:'..id..'|h['..name..']|h',nil,nil,nil,nil,nil,nil,nil,id and id+10 end
    f.env.GetItemInfoInstant=function(value) return tonumber(value) or value=='Water' and 1 or value=='Bread' and 2 end
    a.bagContents={[1]=2};f.libraries['AceGUI-3.0-ItemLoader'].itemList={[1]={name='Water',icon=11},[2]={name='Bread',icon=12}}
    local h=io.open('Core/reference_catalog.lua');if h then h:close();f.load('Core/reference_catalog.lua') end
    return f
end
test('item and spell references share presentation while inventory is a scope filter',function()
    local f=fixture();local a=f.addon;assert(a.GetReferenceProvider,'reference providers missing')
    local all=a:GetReferenceProvider('Item_EditBox');local inventory=a:GetReferenceProvider('Inventory_EditBox')
    assert(all.name(1)=='Water' and all.info(1).icon==11 and all.resolve('|Hitem:2|h[Bread]|h')==2)
    local rows=all.search('',{limit=20});assert(#rows==2 and rows[1].name=='Bread')
    rows=inventory.search('',{limit=20,inventory=true});assert(#rows==1 and rows[1].id==1)
    assert(not inventory.resolve(2,{inventory=true}))
end)
test('inventory scope accepts production bag records plus equipped IDs but never catalog-only ownership',function()
    local f=fixture();local a=f.addon;local p=a:GetReferenceProvider('Inventory_EditBox')
    a.bagContents={[1]={count=2,slots={{bag=0,slot=1}}},[2]={count=0,slots={}}}
    local rows=p.search('',{inventory=true});assert(#rows==1 and rows[1].id==1,'real bag record disappeared from inventory search')
    assert(p.resolve('Water',{inventory=true})==1 and p.resolve('item:1',{inventory=true})==1)
    assert(not p.resolve(2,{inventory=true}),'catalog metadata was treated as ownership')
    f.env.GetInventoryItemID=function(_,slot) if slot==16 then return 2 end end
    rows=p.search('',{inventory=true});assert(#rows==2 and p.resolve(2,{inventory=true})==2)
    a.bagContents={[1]=2};assert(p.resolve(1,{inventory=true})==1,'legacy numeric snapshot stopped working')
end)
test('invalid or unreadable bag entries are not inspected or treated as ownership',function()
    local f=fixture();local a=f.addon;local p=a:GetReferenceProvider('Inventory_EditBox');local secret={}
    f.env.canaccessvalue=function(v) return not rawequal(v,secret) end
    for _,entry in ipairs({secret,{count=secret},{count=-1},{count=1.5},{count=math.huge},{count='2'},{},false}) do
        a.bagContents={[1]=entry};assert(not p.resolve(1,{inventory=true}),'invalid snapshot entry became owned')
    end
end)
test('native display metadata validates optional fields and returns detached records without a level requirement',function()
    local f=fixture();local p=f.addon:GetReferenceProvider('item');local secret={}
    f.env.canaccessvalue=function(v) return not rawequal(v,secret) end
    local value={'Water','item:1',nil,nil,nil,nil,nil,nil,nil,11}
    f.env.C_Item={GetItemInfo=function() return unpack(value,1,10) end}
    local info=assert(p.info(1));assert(info.name=='Water' and info.icon==11)
    info.name='Changed';assert(p.info(1).name=='Water','caller mutated the catalog cache')
    f.env.GetItemInfo=function() error('native failure must not fall through') end
    for _,field in ipairs({'name','link','icon'}) do
        local slot=field=='name' and 1 or field=='link' and 2 or 10
        local old=value[slot];value[slot]=secret;assert(not p.info(1),'restricted '..field..' leaked into the picker');value[slot]=old
    end
    for _,bad in ipairs({{slot=1,value=''},{slot=2,value={}},{slot=10,value=math.huge},{slot=10,value=false}}) do
        local old=value[bad.slot];value[bad.slot]=bad.value;assert(not p.info(1),'malformed display field was accepted');value[bad.slot]=old
    end
    f.env.C_Item.GetItemInfo=function() error('native failed') end;assert(not p.info(1),'old metadata revived after a failed read')
    local rows=p.search('Water');assert(#rows==0,'failed native metadata was revived from the loader')
end)
test('malformed loader metadata and unreadable inputs cannot reach sorting string or texture operations',function()
    local f=fixture();local p=f.addon:GetReferenceProvider('item');local secret={}
    f.env.canaccessvalue=function(v) return not rawequal(v,secret) end
    f.libraries['AceGUI-3.0-ItemLoader'].itemList={[3]={name=secret},[4]={name='Bad icon',icon=secret},[5]={name='Bad link',link=secret},[6]={name=''},[7]={name='Good',icon=17}}
    f.addon.bagContents={};local rows=p.search('',{limit=20});assert(#rows==1 and rows[1].id==7)
    for _,value in ipairs({secret,{},false,math.huge}) do assert(not p.resolve(value) and not p.search(value),'non-public text input was accepted') end
    assert(not p.search('',{limit=0/0}),'NaN search limit was accepted')
end)
test('equipped-only items are indexed and unloaded metadata does not turn the loader into an ownership source',function()
    local f=fixture();local a=f.addon;local p=a:GetReferenceProvider('Inventory_EditBox')
    a.bagContents={};f.libraries['AceGUI-3.0-ItemLoader'].itemList={}
    f.env.GetInventoryItemID=function(_,slot) if slot==16 then return 2 end end
    local rows=p.search('',{inventory=true});assert(#rows==1 and rows[1].id==2 and rows[1].name=='Bread')
    f.env.GetInventoryItemID=nil;f.env.GetItemInfo=function() return nil end
    f.libraries['AceGUI-3.0-ItemLoader'].itemList={[3]={name='Indexed',icon=13}}
    rows=p.search('Indexed',{inventory=true});assert(#rows==0)
    rows=p.search('Indexed');assert(#rows==1 and rows[1].id==3)
end)
test('unloaded names never excuse malformed optional native display fields',function()
    local f=fixture();local a=f.addon;local p=a:GetReferenceProvider('item');a.bagContents={}
    f.libraries['AceGUI-3.0-ItemLoader'].itemList={[3]={name='Indexed',icon=13}}
    for _,bad in ipairs({{icon={}},{link={}},{icon=false},{link=false}}) do
        f.env.C_Item={GetItemInfo=function() return nil,bad.link,nil,nil,nil,nil,nil,nil,nil,bad.icon end}
        local rows=p.search('3');assert(#rows==0,'malformed native field revived a loader row')
    end
    f.env.C_Item.GetItemInfo=function() return nil end
    assert(#p.search('3')==1,'genuinely unloaded metadata should permit the readable loader row')
end)
test('failed unowned indexed items recover on subsequent name and blank searches',function()
    for _,query in ipairs({'Indexed',''}) do
        local f=fixture();local a=f.addon;local p=a:GetReferenceProvider('item');a.bagContents={}
        f.libraries['AceGUI-3.0-ItemLoader'].itemList={[3]={name='Indexed',icon=13}}
        local ready=false;f.env.C_Item={GetItemInfo=function() if ready then return 'Indexed',nil,nil,nil,nil,nil,nil,nil,nil,13 end;error('temporary') end}
        assert(#p.search('3')==0);ready=true
        local rows=p.search(query);assert(#rows==1 and rows[1].id==3,'recovered item remained hidden until its ID was retried')
    end
end)
finish()
