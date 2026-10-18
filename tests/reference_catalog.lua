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
finish()
