-- The TALENT picker on every client that has one: the talent's icon is the left
-- column of a block and spans its two rows, the upper list (specialization,
-- talent tree or Mists tier) and the talent list sit to the icon's right, and
-- the "Show talent tree" button sits beside the talent list when the row has
-- room for it, else under the rows. Geometry is resolved from the real anchors
-- (tests/fixtures/layout_audit.lua) at the narrowest condition pane, a middling
-- one and a wide one, in English, German and Russian.
local F=dofile('tests/fixtures/addon.lua')
local audit=dofile('tests/fixtures/layout_audit.lua')
local Tree=dofile('tests/fixtures/retail_traits.lua')
local test,finish=F.suite()

-- The narrowest condition card is 340 wide; its fields sit 58 inside it.
local NARROW,MIDDLE,WIDE=340-58,420,720

local function language(f,name)
    f.language(name)
end
local function editor(f,value,spec,width)
    local top=f.widget('top');top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'Updated condition' end})
    local parent=f.addon:CreateConditionGroup();parent:SetWidth(width);parent:SetUserData('top',top)
    f.addon.conditionDefinitions.TALENT.widget(parent,spec or 0,value)
    parent:SetWidth(width)
    f.addon:configure_frame(parent)
    return parent
end
local function find(parent,label)
    for _,w in ipairs(parent.children) do
        if (w.caption and w.caption:GetText() or w.label)==label then return w end
        if w.children then local inner=find(w,label);if inner then return inner end end
    end
end
local function block(parent)
    for _,w in ipairs(parent.children) do if w.layout=='RM-IconRows' then return w end end
end
local function load(f,paths) for _,path in ipairs(paths) do f.load(path) end;f.addon.conditionDefinitions=f.addon.conditionDefinitions or f.addon.definitions end
local COMMON={'Platform/spells.lua','Platform/talents.lua','Core/build_context.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'}

local clients={
    retail=function(name)
        local f=F.new(1,12,'MAGE');Tree.install(f.env,{spec=Tree.SPECS.Fire,scale=100});language(f,name);load(f,COMMON)
        f.addon.OpenTalentTree=function() end;f.addon.Platform.HasTalentTreeProvider=function() return true end
        return f,{},Tree.SPECS.Fire,'Specialization','Talent'
    end,
    forever=function(name)
        local f=F.new(18,12,'MAGE');Tree.install(f.env,{spec=Tree.SPECS.Fire});language(f,name);load(f,COMMON)
        f.addon.OpenTalentTree=function() end;f.addon.Platform.HasTalentTreeProvider=function() return true end
        -- Three trees as node groups, the way Forever's talent window shows them.
        f.env.C_Traits.GetGroupDisplayInfoByTreeID=function() return {{groupID=1,orderIndex=1,displayName='Arcane',icon=1,treeID=Tree.TREE},{groupID=2,orderIndex=2,displayName='Fire',icon=2,treeID=Tree.TREE}} end
        return f,{},0,'Talent Tree','Talent'
    end,
    era=function(name)
        local f=F.new(5,1)
        f.env.GetNumTalentTabs=function() return 3 end;f.env.GetNumTalents=function() return 5 end
        f.env.C_SpecializationInfo={GetSpecializationInfo=function(tree) return tree,'Tree '..tree,'',1,nil,nil,2 end,
            GetTalentInfo=function() return {name='Convection',icon=1,rank=1,maxRank=5,talentID=101,spellID=108269} end}
        language(f,name);load(f,{'Platform/talents.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'})
        return f,{type='TALENT',tree=1,talent=1,operator='EQUALS',value=2},0,'Talent Tree','Talent'
    end,
    mists=function(name)
        local f=F.new(19,4)
        f.env.C_SpecializationInfo={GetTalentInfo=function(query) return {name='Tier '..query.tier..' talent '..query.column,icon=1,rank=1,maxRank=1,talentID=100+query.column,spellID=1000+query.column,selected=false} end}
        language(f,name);load(f,{'Platform/talents.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'})
        return f,{},2,'Tier','Talent'
    end,
}

local function within(rect,width) return rect.left>=-.5 and rect.right<=width+.5 end
local function overlap(a,b) return a.left<b.right-.5 and b.left<a.right-.5 and a.bottom<b.top-.5 and b.bottom<a.top-.5 end

for _,name in ipairs({'enUS','deDE','ruRU'}) do
    for _,kind in ipairs({'retail','forever','era','mists'}) do
        for _,width in ipairs({NARROW,MIDDLE,WIDE}) do
            test(string.format('%s %s at %d: the icon is left of the lists and spans both rows, nothing overlaps',name,kind,width),function()
                local f,value,spec,upperLabel,lowerLabel=clients[kind](name)
                local parent=editor(f,value,spec,width)
                local box=assert(block(parent),'no icon block')
                local function label(key) local text=f.translations[key];return text==nil and key or text end
                local icon,upper,lower=box.children[1],find(box,label(upperLabel)),find(box,label(lowerLabel))
                assert(icon.type=='RM-ConditionIcon' and upper and lower,'the block lacks the icon or a list')
                assert(box.children[2]==upper and box.children[3]==lower,'the lists are not the rows, top to bottom')
                local resolve=audit.resolver(parent.frame)
                local ri,ru,rl=resolve(icon.frame),resolve(upper.frame),resolve(lower.frame)
                assert(ri and ru and rl,'a control has no position')
                assert(ri.right<=ru.left-2 and ri.right<=rl.left-2,string.format('the icon is not left of both lists [%.1f..%.1f] [%.1f] [%.1f]',ri.left,ri.right,ru.left,rl.left))
                assert(ru.bottom>=rl.top-.5,'the lists are not one above the other')
                assert(math.abs(ru.left-rl.left)<1,'the lists do not line up')
                -- The icon spans the two rows: it reaches above the lower row and below the upper one,
                -- and is centered on them.
                assert(ri.top>rl.top and ri.bottom<ru.bottom,'the icon does not span both rows')
                assert(math.abs((ri.top+ri.bottom)/2-(ru.top+rl.bottom)/2)<1,'the icon is not centered on the rows')
                assert(ri.top-ri.bottom>=60,'the icon is too small to read ('..(ri.top-ri.bottom)..')')
                -- Fields stay usable and inside the pane.
                for label,rect in pairs({icon=ri,upper=ru,lower=rl}) do assert(within(rect,width),label..' leaves the pane') end
                assert(ru.right-ru.left>=140 and rl.right-rl.left>=140,'a list is too narrow to read at '..width)
                assert(not overlap(ri,ru) and not overlap(ri,rl) and not overlap(ru,rl),'controls overlap')
                local button=box.children[4]
                if button then
                    assert(button.type=='RM-ConditionButton' and button:GetUserData('side'))
                    local rb=assert(resolve(button.frame),'the tree button has no position')
                    assert(within(rb,width),'the tree button leaves the pane')
                    assert(not overlap(rb,ru) and not overlap(rb,rl) and not overlap(rb,ri),'the tree button overlaps a control')
                    -- Beside the lower list when it has room, else under the rows, never between them.
                    assert(rb.top<=ru.top and rb.bottom<=ru.bottom,'the tree button sits above the rows')
                    if width==NARROW then assert(rb.top<=rl.bottom+.5,'the tree button crowds the lists at the narrowest width')
                    elseif width==WIDE then assert(rb.left>=rl.right and math.abs(rb.bottom-rl.bottom)<=1,'the tree button is not beside the talent list') end
                    assert(parent.frame.height>=-rb.bottom-.5,'the group is too short for the tree button')
                end
                assert(parent.frame.height>=-rl.bottom-.5,'the group is too short for its rows')
            end)
        end
    end
end

test('choosing fills the icon and the lists keep their rows',function()
    local f,value,spec=clients.mists('enUS')
    local parent=editor(f,value,spec,MIDDLE);local box=block(parent);local icon=box.children[1]
    assert(icon.image:GetTexture()=='Interface\\Icons\\INV_Misc_QuestionMark','nothing chosen should show the placeholder')
    find(box,'Talent'):Fire('OnValueChanged',2)
    assert(icon.image:GetTexture()==1 and value.value==2)
end)

finish()
