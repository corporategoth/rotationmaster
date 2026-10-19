local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local prefix='Interface\\AddOns\\rotationmaster\\Assets\\Conditions\\'
local function packaged(icon)
    assert(type(icon)=='string' and icon:sub(1,#prefix)==prefix,'condition still uses an unrelated texture: '..tostring(icon))
    local name=icon:sub(#prefix+1);assert(name:match('^[a-z_]+$'),'invalid packaged icon name')
    local file=assert(io.open('Assets/Conditions/'..name..'.tga','rb'),'packaged TGA missing: '..name);local header=file:read(18);file:close()
    local width=header:byte(13)+256*header:byte(14);local height=header:byte(15)+256*header:byte(16)
    assert(header:byte(3)==2 and header:byte(17)==32 and header:byte(18)%16==8,'icon is not uncompressed RGBA TGA')
    assert(width==128 and height==128,'icon dimensions are not the expected power of two')
end
test('all reviewed Built In declarations use bundled original semantic icons',function()
    local seen={}
    for _,case in ipairs(dofile('tests/fixtures/catalog_inventory.lua').branches) do
        local f=F.new(unpack(case[1]));f.addon.delayed_condition={};if case[3] then f.env.MI2_GetMobData=function() end end
        for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then f.load(path) end end
        for tag,definition in pairs(f.addon.definitions) do packaged(definition.icon);seen[tag]=true end
        for _,group in pairs(f.addon.delayed_condition) do for tag,definition in pairs(group) do packaged(definition.icon);seen[tag]=true end end
    end
    local count=0;for _ in pairs(seen) do count=count+1 end;assert(count==115,'reviewed icon inventory changed: '..count)
end)
test('category defaults follow stable identity while saved custom choices remain exact',function()
    local f=F.new();local a=f.addon
    local category={id='b3d7df2c-f257-4a2d-961e-66e49336d109',name='Renamed category',conditions={}}
    assert(a:GetConditionCategoryIcon(category)==prefix..'combat' and category.icon==nil,'default icon required mutating saved category')
    category.icon=123;assert(a:GetConditionCategoryIcon(category)==123,'explicit saved icon was replaced')
    category.icon='My\\CustomIcon';assert(a:GetConditionCategoryIcon(category)==category.icon)
    a.conditionDefinitions={TEST={icon='Custom\\ConditionIcon'}}
    assert(a:GetConditionCategoryIcon({id='custom',conditions={'TEST'}})=='Custom\\ConditionIcon','custom category fallback changed')
    packaged(a:GetConditionCategoryIcon(nil))
end)
test('structural groups use the original logic family',function()
    local f=F.new();f.load('Core/conditions.lua')
    for _,tag in ipairs({'AND','OR','NOT'}) do packaged(f.addon.conditionSpecials[tag].icon) end
end)
test('shared icon chooser exposes all original families and preserves its owner guard',function()
    local f=F.new();dofile('tests/fixtures/native_ui.lua')(f.env);f.load('UI/icon_picker.lua');local a=f.addon;local chosen;local alive=true
    local picker=a:ShowWorkbenchIconPicker(nil,function(texture) chosen=texture end,function() return alive end)
    local index
    for i,category in ipairs(picker.categories) do if category.name=='Rotation Master' then index=i;assert(#category.icons==16);for _,entry in ipairs(category.icons) do packaged(entry.texture) end end end
    assert(index,'original family category missing');picker.categoryButtons[index]:Click()
    picker.buttons[1]:Click();assert(chosen and chosen:sub(1,#prefix)==prefix,'original choice did not commit its packaged path')
    chosen=nil;picker=a:ShowWorkbenchIconPicker(nil,function(texture) chosen=texture end,function() return alive end);picker.categoryButtons[index]:Click();alive=false;picker.buttons[1]:Click();assert(chosen==nil,'stale owner committed an original icon')
end)
finish()
