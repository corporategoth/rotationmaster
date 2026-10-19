local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local services={'Libs/AceGUI-3.0-Spell-EditBox/SpellLoader.lua','Libs/AceGUI-3.0-Item-EditBox/ItemLoader.lua'}
local compatibility={'Libs/AceGUI-3.0-Spell-EditBox/EditBox-Core.lua','Libs/AceGUI-3.0-Spell-EditBox/Spells-Editbox.lua','Libs/AceGUI-3.0-Spell-EditBox/Casts-EditBox.lua','Libs/AceGUI-3.0-Spell-EditBox/Auras-EditBox.lua','Libs/AceGUI-3.0-Spell-EditBox/Player-EditBox.lua','Libs/AceGUI-3.0-Item-EditBox/EditBox-Core.lua','Libs/AceGUI-3.0-Item-EditBox/Items-Editbox.lua','Libs/AceGUI-3.0-Item-EditBox/Inventory-EditBox.lua','LibsAugment/Spec-EditBox.lua','LibsAugment/Totem-EditBox.lua','LibsAugment/Glyph-EditBox.lua'}
local expected={'Predictor_Base:1','Spell_EditBox:3','Cast_EditBox:1','Aura_EditBox:1','Player_EditBox:1','ItemPredictor_Base:1','Item_EditBox:3','Inventory_EditBox:1','Spec_EditBox:1','Totem_EditBox:1','Glyph_EditBox:1'}
local function fixture()
    local f=F.new();local e=f.env;local create=e.CreateFrame;local frames={};e.LibStub=nil;f.load('Libs/LibStub/LibStub.lua')
    local lib=e.LibStub
    for name,value in pairs(f.libraries) do lib.libs[name]=value;lib.minors[name]=0 end
    local call=getmetatable(lib).__call
    getmetatable(lib).__call=function(self,name,...) assert(f.allowAce or name~='AceGUI-3.0','data services requested AceGUI');return call(self,name,...) end
    e.CreateFrame=function(...) local frame=create(...);frames[#frames+1]=frame;return frame end
    local state={loaded={},calls=0,names={[10]='Potion',[11]='Water'}}
    e.GetItemInfoInstant=function(value) local id=tonumber(value);if not id then for key,name in pairs(state.names) do if value==name then id=key end end end;return id,nil,nil,nil,id and id+100 end
    e.GetItemInfo=function(id) state.calls=state.calls+1;if state.failure then error('metadata failed') end;if state.loaded[id] then return state.names[id],'item:'..id,nil,nil,nil,nil,nil,nil,nil,id+100 end end
    return f,state,frames
end
local function loadServices(f) for _,path in ipairs(services) do f.load(path) end;return f.env.LibStub('AceGUI-3.0-ItemLoader'),f.env.LibStub('AceGUI-3.0-SpellLoader') end

test('actual data services load without Ace construction scans or loss of seeded identities',function()
    local f,_,frames=fixture();local items={};local reverse={};local predictors={};local seeded=f.libraries['AceGUI-3.0-ItemLoader'];seeded.itemList=items;seeded.itemListReverse=reverse;seeded.predictors=predictors
    local item,spell=loadServices(f);assert(item==seeded and item.itemList==items and item.itemListReverse==reverse and item.predictors==predictors)
    assert(#frames==0 and not item.loader and not spell.loader and type(spell.spellList)=='table')
    local update=item.UpdateItem;f.load(services[2]);assert(item.UpdateItem==update and item.itemList==items,'same minor registration rebuilt the service')
    f.env.LibStub.minors['AceGUI-3.0-ItemLoader']=99;f.load(services[2]);assert(item.UpdateItem==update,'older bundled version replaced an existing newer service')
end)
test('real ItemLoader metadata events populate links and reverse names without a scan',function()
    local f,state,frames=fixture();local item=loadServices(f);item:UpdateItem(10);assert(not item.itemList[10] and #frames==0)
    state.loaded[10]=true;item:UpdateItem(10);local record=item.itemList[10];assert(record.name=='Potion' and record.icon==110 and record.link=='item:10' and item.itemListReverse.potion==10)
    local calls=state.calls;item:UpdateItem(10);assert(state.calls==calls and record==item.itemList[10] and #frames==0)
end)
test('explicit limited scanning owns one native frame and preserves predictor ownership',function()
    local f,state,frames=fixture();local item=loadServices(f);state.loaded[10]=true;state.loaded[11]=true
    local queries=0;local predictor={IsVisible=function() return true end,Query=function() queries=queries+1 end};item:RegisterPredictor(predictor)
    -- A trailing sentinel characterizes the existing vendor end-index contract.
    item:StartLoading({10,11,0});assert(#frames==1);local scanner=item.loader;scanner.scripts.OnUpdate(scanner,.11)
    assert(item.itemList[10] and item.itemList[11] and not scanner:IsShown() and queries==1)
    item:UnregisterPredictor(predictor);item:StartLoading({10,0});scanner.scripts.OnUpdate(scanner,.11)
    assert(item.loader==scanner and #frames==1 and queries==1)
end)
test('native reference providers consume real loader data but preserve current observation authority',function()
    local f,state,frames=fixture();local a=f.addon;local item,spell=loadServices(f);state.loaded[10]=true;item:UpdateItem(10);state.loaded[10]=nil;a.bagContents={}
    f.load('Core/reference_catalog.lua');local provider=a:GetReferenceProvider('Item_EditBox');local rows=provider.search('',{limit=20})
    assert(#rows==1 and rows[1].id==10 and rows[1].name=='Potion');rows[1].name='Detached';assert(item.itemList[10].name=='Potion')
    state.names[10]='Current potion';state.loaded[10]=true;assert(provider.info(10).name=='Current potion')
    state.failure=true;assert(not provider.info(10));assert(#provider.search('',{limit=20})==0,'failed native observation revived stale loader metadata')
    state.failure=nil;local secret={};f.env.issecretvalue=function(value) return value==secret end;state.names[10]=secret
    assert(not provider.info(10) and #provider.search('',{limit=20})==0,'restricted native name revived the loader record')
    f.env.issecretvalue=nil;state.names[10]='Potion';state.loaded[10]=nil;f.load('Core/reference_catalog.lua');a.bagContents={[11]={count=2}}
    local inventory=a:GetReferenceProvider('Inventory_EditBox');assert(#inventory.search('',{inventory=true})==0,'index row became item ownership')
    a:GetReferenceProvider('Spell_EditBox').search('',{limit=20});assert(not spell.loader and #frames==0,'native spell search started a legacy scanner')
end)
test('explicit compatibility scripts retain every registration identity and remain construction-free',function()
    local f,_,frames=fixture();loadServices(f);f.allowAce=true;local ace=f.libraries['AceGUI-3.0'];local trace={}
    ace.Create=function() error('registration constructed a widget') end
    ace.RegisterWidgetType=function(_,name,constructor,version) assert(type(constructor)=='function');trace[#trace+1]=name..':'..version end
    for _,path in ipairs(compatibility) do f.load(path) end
    assert(#trace==#expected and #frames==0);for index,name in ipairs(expected) do assert(trace[index]==name,'compatibility registration order changed') end
end)
test('actual legacy predictor acquisition and release retain the same data service owners',function()
    local f,_,frames=fixture();local item,spell=loadServices(f);f.allowAce=true
    local constructors={};f.libraries['AceGUI-3.0'].RegisterWidgetType=function(_,name,build) constructors[name]=build end
    for _,path in ipairs(compatibility) do f.load(path) end
    local function callback(constructor,wanted)
        for index=1,100 do local name,value=debug.getupvalue(constructor,index);if not name then break end;if name==wanted then return value end end
        error('missing actual vendor lifecycle: '..wanted)
    end
    for _,entry in ipairs({{'ItemPredictor_Base',item},{'Predictor_Base',spell}}) do
        local widget=f.widget(entry[1]);widget.frame=f.env.CreateFrame('Frame');widget.predictFrame=f.env.CreateFrame('Frame');widget.itemFilter=true;widget.spellFilter=true
        callback(constructors[entry[1]],'OnAcquire')(widget);assert(entry[2].predictors[widget.predictFrame] and not widget.disabled)
        callback(constructors[entry[1]],'OnRelease')(widget);assert(not entry[2].predictors[widget.predictFrame] and not widget.frame:IsShown() and not widget.predictFrame:IsShown())
    end
    assert(not item.loader and spell.loader and #frames==5,'legacy acquisition started the wrong metadata scanner')
end)
finish()
