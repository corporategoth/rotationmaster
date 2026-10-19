local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local AceGUI=LibStub("AceGUI-3.0")
local platform=addon.Platform
local function integer(value,minimum,maximum)
    return type(value)=="number" and value>=minimum and value<=maximum and value%1==0
end
local function treeShape(value)
    return (value.layout==nil or value.layout=="tree") and value.tree~=nil and value.talent~=nil
end
local function legacySlot(value)
    return value.layout==nil and value.tree==nil and value.talent==nil and integer(value.value,1,21)
end
local function group(spec)
    if platform:GetClientInfo().family=="progression" and integer(spec,1,4) then return spec end
end
local function info(value,spec)
    if value.layout=="grid" then return platform:GetGridTalentInfo(value.value,group(spec)) end
    if treeShape(value) then return platform:GetTreeTalentInfo(value.tree,value.talent,group(spec)) end
end
local function text(parent,message)
    local label=AceGUI:Create("Label");label:SetFullWidth(true);label:SetText(message);parent:AddChild(label)
end
local function dropdown(parent,title,changed)
    local widget=addon:CreateConditionDropdown();widget:SetFullWidth(true);widget:SetLabel(title)
    widget:SetCallback("OnValueChanged",function(_,_,value) changed(value) end);parent:AddChild(widget)
    return widget
end
local function icon(parent,value,spec)
    local widget=AceGUI:Create("Icon");widget:SetWidth(44);widget:SetHeight(44);widget:SetImageSize(36,36)
    local current=info(value,spec);widget:SetImage(current and current.icon)
    widget:SetCallback("OnEnter",function()
        local observed=info(value,spec)
        if observed then
            GameTooltip:SetOwner(widget.frame,"ANCHOR_BOTTOMRIGHT",3)
            if observed.spellID then GameTooltip:SetHyperlink("spell:"..observed.spellID)
            else GameTooltip:SetText(observed.name) end
        end
    end)
    widget:SetCallback("OnLeave",function() if GameTooltip:IsOwned(widget.frame) then GameTooltip:Hide() end end)
    parent:AddChild(widget)
    return widget
end
local function treeWidget(parent,spec,value,update)
    local trees,treeOrder={},{}
    for index=1,platform:GetTalentTreeCount() or 0 do
        local tree=platform:GetTalentTreeInfo(index,group(spec))
        if tree then trees[index]=tree.name;treeOrder[#treeOrder+1]=index end
    end
    local talents,talentOrder={},{}
    local talentIcon,talentPicker,treePicker
    local function choices()
        talents,talentOrder={},{}
        if value.tree then
            for index=1,platform:GetTreeTalentCount(value.tree) or 0 do
                local talent=platform:GetTreeTalentInfo(value.tree,index,group(spec))
                if talent then talents[index]=talent.name;talentOrder[#talentOrder+1]=index end
            end
        end
    end
    choices()
    treePicker=dropdown(parent,L["Talent Tree"],function(selected)
        if selected==value.tree then return end
        local wasTree=value.layout=="tree" or value.layout==nil and value.tree~=nil
        value.tree,value.talent,value.layout=selected,nil,"tree"
        if not wasTree then value.value,value.operator=nil,nil end
        choices();talentPicker:SetList(talents,talentOrder);talentPicker:SetValue(nil)
        talentPicker:SetDisabled(#talentOrder==0);talentIcon:SetImage("Interface\\Icons\\INV_Misc_QuestionMark");update()
    end)
    treePicker.configure=function() treePicker:SetList(trees,treeOrder);treePicker:SetValue(value.tree) end
    talentIcon=icon(parent,value,spec)
    talentPicker=dropdown(parent,L["Talent"],function(selected)
        value.talent,value.layout=selected,"tree"
        local talent=info(value,spec);talentIcon:SetImage(talent and talent.icon);update()
    end)
    talentPicker:SetDisabled(#talentOrder==0)
    talentPicker.configure=function() talentPicker:SetList(talents,talentOrder);talentPicker:SetValue(value.talent) end
    parent:AddChild(addon:Widget_OperatorWidget(value,L["Points"],update))
end
local function gridWidget(parent,spec,value,update)
    local choices,order={},{}
    for index=1,18 do
        local talent=platform:GetGridTalentInfo(index,group(spec))
        if talent then choices[index]=talent.name;order[#order+1]=index end
    end
    if value.layout~="grid" and (value.tree~=nil or value.value~=nil) then
        text(parent,L["This reference belongs to another talent layout. Selecting a talent explicitly replaces it; viewing does not convert it."])
    end
    local talentIcon=icon(parent,value,spec)
    local picker
    picker=dropdown(parent,L["Talent"],function(selected)
        value.layout,value.value="grid",selected
        value.tree,value.talent,value.operator=nil,nil,nil
        local talent=info(value,spec);talentIcon:SetImage(talent and talent.icon);update()
    end)
    picker:SetDisabled(#order==0)
    picker.configure=function() picker:SetList(choices,order);picker:SetValue(value.layout=="grid" and value.value or nil) end
end
addon:RegisterCondition("TALENT",{
    description=L["Talent"],icon="Interface\\Icons\\Inv_misc_book_11",
    fields={layout="string",tree="number",talent="number",operator="string",value="number"},
    valid=function(_,value)
        if value.layout=="grid" then
            return integer(value.value,1,18) and value.tree==nil and value.talent==nil and value.operator==nil
        end
        if legacySlot(value) then return true end
        return treeShape(value) and integer(value.tree,1,16) and integer(value.talent,1,256)
            and addon.isin(addon.operators,value.operator) and integer(value.value,0,64)
    end,
    evaluate=function(value,cache)
        if legacySlot(value) then return nil,"historical-talent-layout" end
        local talent,reason
        if value.layout=="grid" then
            talent,reason=addon.getCached(cache,platform.GetGridTalentInfo,platform,value.value)
            if not talent then return nil,reason end
            return talent.selected
        end
        talent,reason=addon.getCached(cache,platform.GetTreeTalentInfo,platform,value.tree,value.talent)
        if not talent then return nil,reason end
        return addon.compare(value.operator,talent.rank,value.value)
    end,
    print=function(spec,value)
        local talent=info(value,spec)
        if legacySlot(value) then return string.format(L["Historical talent slot %s (unavailable)"],value.value) end
        if value.layout=="grid" then return string.format(L["you {{!are|are not}} talented in %s"],talent and talent.name or L["<talent>"]) end
        local tree=value.tree and platform:GetTalentTreeInfo(value.tree,group(spec))
        return addon.compareString(value.operator,string.format(L["talent points in %s (%s)"],
            talent and talent.name or L["<talent>"],tree and tree.name or L["<talent tree>"]),addon.nullable(value.value))
    end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"),spec)) end
        local current=platform:GetTalentLayout()
        if current=="tree" then treeWidget(parent,spec,value,update)
        elseif current=="grid" then gridWidget(parent,spec,value,update)
        else text(parent,L["This client uses a different talent system. This reference is preserved but cannot be evaluated."]) end
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Classic conditions compare points spent in a tree talent. Mists selections use six tiers with three choices. Historical references from another talent system remain unavailable and are never automatically converted."]))
    end,
})

local function treeName(value,spec)
    local tree=integer(value.tree,1,16) and platform:GetTalentTreeInfo(value.tree,group(spec))
    return tree and tree.name or value.tree and string.format(L['Talent tree %s'],tostring(value.tree)) or L['<talent tree>']
end
local function treePicker(parent,spec,value,update)
    local choices,order={},{}
    local count=platform:GetTalentTreeCount()
    for index=1,count or 0 do local tree=platform:GetTalentTreeInfo(index,group(spec));if tree then choices[index]=tree.name;order[#order+1]=index end end
    if not count then text(parent,L['This client does not expose a Classic talent-tree layout. The saved tree reference is preserved.']) end
    local picker=dropdown(parent,L['Talent tree'],function(selected) value.tree=selected;update() end)
    picker:SetDisabled(#order==0 or value.disabled==true)
    picker.configure=function() picker:SetList(choices,order);picker:SetValue(value.tree) end
end
local function treeExists(value,cache)
    local count,reason=addon.getCached(cache,platform.GetTalentTreeCount,platform)
    if count==nil then return nil,reason end
    if value.tree>count then return nil,'talent-tree-unavailable' end
    return true
end
addon:RegisterCondition('TALENT_TREE_POINTS',{
    description=L['Talent Tree Points'],icon='Interface\\Icons\\Inv_misc_book_11',requiredFields={'tree','operator','value'},
    fields={tree='number',operator='string',value='number'},
    valid=function(_,value) return integer(value.tree,1,16) and addon.isin(addon.operators,value.operator) and integer(value.value,0,512) end,
    evaluate=function(value,cache)
        local exists,why=treeExists(value,cache);if not exists then return nil,why end
        local tree,reason=addon.getCached(cache,platform.GetTalentTreeInfo,platform,value.tree)
        if not tree then return nil,reason end
        if not integer(tree.pointsSpent,0,512) then return nil,'talent-points-unavailable' end
        return addon.compare(value.operator,tree.pointsSpent,value.value)
    end,
    print=function(spec,value) return addon.compareString(value.operator,string.format(L['points spent in %s'],treeName(value,spec)),addon.nullable(value.value)) end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData('top');local function update() top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec)) end
        treePicker(parent,spec,value,update);parent:AddChild(addon:Widget_OperatorWidget(value,L['Points'],update))
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Talent tree selects the Classic tree whose spent points are compared. Public points are read again on the next evaluation; missing or restricted points are unavailable, including under NOT. Grids and trait trees are unsupported.']))
        frame:AddChild(addon.help_funcs.Gap());addon.layout_condition_operatorwidget_help(frame,L['Talent Tree Points'],L['Points'],L['Compare whole points spent from zero to 512. An explicit comparison with zero can describe an unspent tree.'])
    end,
})
addon:RegisterCondition('PRIMARY_TALENT_TREE',{
    description=L['Primary Talent Tree'],icon='Interface\\Icons\\Inv_misc_book_11',requiredFields={'tree'},fields={tree='number'},
    valid=function(_,value) return integer(value.tree,1,16) end,
    evaluate=function(value,cache)
        local exists,why=treeExists(value,cache);if not exists then return nil,why end
        local primary,reason=addon.getCached(cache,platform.GetPrimaryTalentTree,platform)
        if not primary then return nil,reason end
        return primary.index==value.tree
    end,
    print=function(spec,value) return string.format(L['your primary talent tree {{!is|is not}} %s'],treeName(value,spec)) end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData('top');treePicker(parent,spec,value,function() top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec)) end)
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Talent tree selects the unique Classic tree with the most positive spent points. Equal maxima, no spent points, missing records and restricted points are unavailable, including under NOT.']))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L['The primary tree is derived from readable points, not the saved rotation slot. Hybrid builds may need tree-point or individual-talent conditions instead; the primary tree does not assign a tank or healer role. Grids and trait trees are unsupported.']))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="AceGUI" then return AceGUI end
        if name=="dropdown" then return dropdown end
        if name=="gridWidget" then return gridWidget end
        if name=="group" then return group end
        if name=="icon" then return icon end
        if name=="info" then return info end
        if name=="integer" then return integer end
        if name=="legacySlot" then return legacySlot end
        if name=="platform" then return platform end
        if name=="text" then return text end
        if name=="treeExists" then return treeExists end
        if name=="treeName" then return treeName end
        if name=="treePicker" then return treePicker end
        if name=="treeShape" then return treeShape end
        if name=="treeWidget" then return treeWidget end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Conditions/talent.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Conditions/talent.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
