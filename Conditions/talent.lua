local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local platform=addon.Platform
-- Select the pure implementations privately; saved custom source retains its
-- original addon APIs and the collector verifies these stable helper leaves.
local Functions={
    cache={getCached=addon.Functions.cache.getCached},
    values={isin=addon.Functions.values.isin,compare=addon.Functions.values.compare},
    presentation={compareString=addon.Functions.presentation.compareString,nullable=addon.Functions.presentation.nullable},
}
addon.builtinCallbackBindings=addon.builtinCallbackBindings or {}
addon.builtinCallbackBindings["Conditions/talent.lua"]={
    ["Functions.cache.getCached"]="builtin:utils.lua:getCached",
    ["Functions.values.isin"]="builtin:utils.lua:isin",
    ["Functions.values.compare"]="builtin:utils.lua:compare",
    ["Functions.presentation.compareString"]="builtin:utils.lua:compareString",
    ["Functions.presentation.nullable"]="builtin:utils.lua:nullable",
}
local function integer(value,minimum,maximum)
    return type(value)=="number" and value>=minimum and value<=maximum and value%1==0
end
local function treeShape(value)
    return (value.layout==nil or value.layout=="tree") and value.tree~=nil and value.talent~=nil
end
local function legacySlot(value)
    return value.layout==nil and value.tree==nil and value.talent==nil and integer(value.value,1,21)
end
-- Trait talents (Retail, Forever) name a node and, for a choice node, the
-- chosen entry; the rank comes from Core/build_context.lua, which reads each
-- node once per talent change.
local function traitShape(value) return value.layout=="traits" end
local function traitFamily()
    local family=platform:GetClientFamily()
    return family=="retail" or family=="forever"
end
local function group(spec)
    if platform:GetClientInfo().family=="progression" and integer(spec,1,4) then return spec end
end
-- Whether the trees being edited are the player's class's (so the game can
-- name their talents), as opposed to another class's rotation.
local function ownTrees()
    local context=addon.TalentTrees.ContextClass()
    return context==nil or addon.TalentTrees.IsPlayerClass(context)
end
local function info(value,spec)
    if traitShape(value) then return integer(value.node,1,2147483647) and platform:GetTraitTalentIdentity(value.node,value.entry,value.spell) or nil end
    if value.layout=="grid" then return platform:GetGridTalentInfo(value.value,group(spec)) end
    if treeShape(value) then
        -- The game answers for the player's own class only; another class's
        -- talent index would name one of the player's talents instead.
        if not ownTrees() then return nil end
        return platform:GetTreeTalentInfo(value.tree,value.talent,group(spec))
    end
end
local function text(parent,message)
    local label=addon:CreateConditionLabel();label:SetFullWidth(true);label:SetText(message);parent:AddChild(label)
end
local function dropdown(parent,title,changed)
    local widget=addon:CreateConditionDropdown();widget:SetFullWidth(true);widget:SetLabel(title)
    widget:SetCallback("OnValueChanged",function(_,_,value) changed(value) end);parent:AddChild(widget)
    return widget
end
-- Every talent picker is one block: the talent's icon on the left, spanning two
-- rows, and a list on each row to its right (what the talent belongs to, then
-- the talent). The icon shows the chosen talent, a question mark before one is
-- chosen. UI/condition_layout.lua lays the block out.
local PLACEHOLDER="Interface\\Icons\\INV_Misc_QuestionMark"
local function block(parent)
    local widget=addon:CreateConditionGroup();widget:SetFullWidth(true);widget:SetLayout("RM-IconRows");parent:AddChild(widget)
    return widget
end
local function icon(parent,value,spec)
    local widget=addon:CreateConditionIcon();widget:SetWidth(64);widget:SetImageSize(60,60)
    local current=info(value,spec);widget:SetImage(current and current.icon or PLACEHOLDER)
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
    -- Names, never positions: the game's for the player's class, the shipped
    -- table's for another class's rotation or before the game has the data.
    local listed=addon.TalentTrees.Choices(addon.TalentTrees.ContextClass(),group(spec))
    if listed then trees,treeOrder=listed.choices,listed.order end
    local talents,talentOrder={},{}
    local talentIcon,talentPicker,treePicker
    local function choices()
        talents,talentOrder={},{}
        if value.tree and ownTrees() then
            for index=1,platform:GetTreeTalentCount(value.tree) or 0 do
                local talent=platform:GetTreeTalentInfo(value.tree,index,group(spec))
                if talent then talents[index]={text=talent.name,icon=talent.icon};talentOrder[#talentOrder+1]=index end
            end
        end
    end
    choices()
    local box=block(parent)
    talentIcon=icon(box,value,spec)
    treePicker=dropdown(box,L["Talent Tree"],function(selected)
        if selected==value.tree then return end
        local wasTree=value.layout=="tree" or value.layout==nil and value.tree~=nil
        value.tree,value.talent,value.layout=selected,nil,"tree"
        if not wasTree then value.value,value.operator=nil,nil end
        choices();talentPicker:SetList(talents,talentOrder);talentPicker:SetValue(nil)
        talentPicker:SetDisabled(#talentOrder==0);talentIcon:SetImage(PLACEHOLDER);update()
    end)
    treePicker.configure=function() treePicker:SetList(trees,treeOrder);treePicker:SetValue(value.tree) end
    talentPicker=dropdown(box,L["Talent"],function(selected)
        value.talent,value.layout=selected,"tree"
        local talent=info(value,spec);talentIcon:SetImage(talent and talent.icon or PLACEHOLDER);update()
    end)
    talentPicker:SetDisabled(#talentOrder==0)
    talentPicker.configure=function() talentPicker:SetList(talents,talentOrder);talentPicker:SetValue(value.talent) end
    parent:AddChild(addon:Widget_OperatorWidget(value,L["Points"],update))
end
-- Mists of Pandaria: six tiers, one of three talents in each. The tier is the
-- upper list, the three talents of that tier the lower; the reference stays
-- the slot, 1-18.
local GRID_TIER_LEVELS={15,30,45,60,75,90}
local function gridWidget(parent,spec,value,update)
    local tiers,tierOrder={},{}
    for tier,level in ipairs(GRID_TIER_LEVELS) do tiers[tier]=string.format(L["Tier %d (level %d)"],tier,level);tierOrder[tier]=tier end
    local chosen=value.layout=="grid" and integer(value.value,1,18) and value.value or nil
    local shownTier=chosen and math.ceil(chosen/3) or 1
    local choices,order={},{}
    local function load()
        choices,order={},{}
        for column=1,3 do
            local talent=platform:GetGridTalentInfo((shownTier-1)*3+column,group(spec))
            if talent then choices[column]={text=talent.name,icon=talent.icon};order[#order+1]=column end
        end
    end
    load()
    if value.layout~="grid" and (value.tree~=nil or value.value~=nil) then
        text(parent,L["This reference belongs to another talent layout. Selecting a talent explicitly replaces it; viewing does not convert it."])
    end
    local box=block(parent)
    local talentIcon=icon(box,value,spec)
    local tierPicker,picker
    tierPicker=dropdown(box,L["Tier"],function(selected)
        if selected==shownTier then return end
        shownTier=selected;load();picker:SetList(choices,order)
        picker:SetValue(chosen and math.ceil(chosen/3)==shownTier and (chosen-1)%3+1 or nil);picker:SetDisabled(#order==0)
    end)
    tierPicker.configure=function() tierPicker:SetList(tiers,tierOrder);tierPicker:SetValue(shownTier) end
    picker=dropdown(box,L["Talent"],function(selected)
        chosen=(shownTier-1)*3+selected
        value.layout,value.value="grid",chosen
        value.tree,value.talent,value.operator=nil,nil,nil
        local talent=info(value,spec);talentIcon:SetImage(talent and talent.icon or PLACEHOLDER);update()
    end)
    picker:SetDisabled(#order==0)
    picker.configure=function() picker:SetList(choices,order);picker:SetValue(chosen and math.ceil(chosen/3)==shownTier and (chosen-1)%3+1 or nil) end
end
-- The specializations of the player's class (Retail), for the list of talents
-- to show; nil where the client has one talent tree per class.
local function classSpecs()
    if platform:GetClientFamily()~="retail" or not platform.GetClassSpecializationChoices then return nil end
    local ok,_,_,classID=pcall(UnitClass,"player")
    if not ok or not platform:CanReadValue(classID) then return nil end
    local choices=platform:GetClassSpecializationChoices(classID)
    return choices and #choices>1 and choices or nil
end
-- What a group of the talent list is called.
local function groupLabel(candidate)
    if candidate.kind=="class" then return L["Class talents"] end
    if candidate.kind=="spec" then return L["Specialization talents"] end
    if candidate.kind=="talents" then return L["Class and specialization talents"] end
    if candidate.kind=="hero" then return candidate.name and string.format(L["Hero talents: %s"],candidate.name) or L["Hero Talents"] end
    return candidate.name or L["Talents"]
end
local function traitsWidget(parent,spec,value,update)
    -- Retail: the talents of the rotation's specialization, which need not be
    -- the one being played (shown can be switched). Forever: the loadout.
    local specs=classSpecs()
    local shown
    if specs then
        for _,choice in ipairs(specs) do if choice.id==spec then shown=spec end end
        if not shown and platform.GetPlayerSpecializationID then shown=platform:GetPlayerSpecializationID() end
    end
    if not traitShape(value) and (value.tree~=nil or value.value~=nil) then
        text(parent,L["This reference belongs to another talent layout. Selecting a talent explicitly replaces it; viewing does not convert it."])
    end
    local box=block(parent)
    local note=addon:CreateConditionLabel();note:SetFullWidth(true);parent:AddChild(note)
    local groups,selectedGroup,selectedTalent={},nil,nil
    local groupNames,groupOrder={},{}
    -- The talent list: with a specialization list, every group under its own
    -- heading; without one (Forever's three trees), the chosen tree's talents.
    local list,order,positions={},{},{}
    local talentIcon,talentPicker,groupPicker,nodeBox,entryBox,operators,specPicker,treeButton
    local treeOwner={}
    local function rebuild()
        list,order,positions={},{},{}
        for groupIndex,candidate in ipairs(groups) do
            if specs or groupIndex==selectedGroup then
                if specs and #groups>1 then
                    list[#list+1]={text=groupLabel(candidate),header=true,disabled=true};order[#order+1]=#list
                end
                for talentIndex,talent in ipairs(candidate.talents) do
                    list[#list+1]={text=talent.entry and string.format(L["%s (choice)"],talent.name) or talent.name,icon=talent.icon}
                    order[#order+1]=#list;positions[#list]={group=groupIndex,talent=talentIndex}
                end
            end
        end
    end
    local function flatIndex(groupIndex,talentIndex)
        for index,position in pairs(positions) do
            if position.group==groupIndex and position.talent==talentIndex then return index end
        end
    end
    local function reload()
        -- The game names the talents of the class being played: another class's
        -- rotation (a Built In, a shared one) gets no list.
        local own=ownTrees()
        local listed,reason
        if own then listed,reason=platform:GetTraitTalents(shown) end
        groups=listed or {}
        if not own then note:SetText(L["Talents can be listed only for your own class. A node ID entered below is kept and evaluated."])
        elseif listed then note:SetText("")
        elseif reason=="in-combat" then note:SetText(L["Talents of another specialization cannot be loaded during combat. A node ID entered below is kept and evaluated."])
        else note:SetText(string.format(L["Your talents cannot be listed right now (%s). A node ID entered below is kept and evaluated."],tostring(reason))) end
        selectedGroup,selectedTalent=nil,nil
        local matchedGroup,matchedTalent
        if traitShape(value) then
            for groupIndex,candidate in ipairs(groups) do
                for talentIndex,talent in ipairs(candidate.talents) do
                    if talent.node==value.node and talent.entry==value.entry then matchedGroup,matchedTalent=groupIndex,talentIndex end
                end
            end
        end
        selectedGroup=matchedGroup or (#groups>0 and 1 or nil)
        groupNames,groupOrder={},{}
        for index,candidate in ipairs(groups) do groupNames[index]=groupLabel(candidate);groupOrder[#groupOrder+1]=index end
        rebuild()
        if matchedGroup then selectedTalent=flatIndex(matchedGroup,matchedTalent) end
    end
    local function show()
        if groupPicker then groupPicker:SetList(groupNames,groupOrder);groupPicker:SetValue(selectedGroup);groupPicker:SetDisabled(#groupOrder<2) end
        talentPicker:SetList(list,order);talentPicker:SetValue(selectedTalent);talentPicker:SetDisabled(#order==0)
        if treeButton then treeButton:SetDisabled(value.disabled==true or #groups==0) end
    end
    local function adopt()
        if not traitShape(value) then value.operator,value.value="GREATERTHANOREQUALS",1 end
        value.layout,value.tree,value.talent="traits",nil,nil
        if operators and operators.Refresh then operators.Refresh() end
    end
    talentIcon=icon(box,value,spec)
    if specs then
        local specNames,specOrder={},{}
        for index,choice in ipairs(specs) do
            specNames[choice.id]={text=choice.name,icon=choice.icon};specOrder[index]=choice.id
        end
        specPicker=dropdown(box,L["Specialization"],function(selected)
            if selected==shown then return end
            shown=selected;reload();show()
        end)
        specPicker.configure=function() specPicker:SetList(specNames,specOrder);specPicker:SetValue(shown) end
    end
    reload()
    if not specs then
        groupPicker=dropdown(box,L["Talent Tree"],function(selected)
            if selected==selectedGroup then return end
            selectedGroup,selectedTalent=selected,nil;rebuild()
            talentPicker:SetList(list,order);talentPicker:SetValue(nil);talentPicker:SetDisabled(#order==0)
        end)
        groupPicker.configure=show
    end
    local function currentSelection()
        if traitShape(value) and value.node then return {node=value.node,entry=value.entry,spell=value.spell} end
    end
    -- Keeps the open talent tree (if it is this editor's) on the condition's talent.
    local function refreshTree()
        if not addon.RefreshTalentTree then return end
        local current=info(value,spec)
        addon:RefreshTalentTree(treeOwner,currentSelection(),current and current.name)
    end
    local function apply(talent)
        adopt()
        value.node,value.entry,value.spell=talent.node,talent.entry,talent.spellID
        nodeBox:SetText(tostring(talent.node));entryBox:SetText(talent.entry and tostring(talent.entry) or "")
        talentIcon:SetImage(talent.icon or PLACEHOLDER);update()
    end
    talentPicker=dropdown(box,L["Talent"],function(selected)
        local position=positions[selected]
        local talent=position and groups[position.group] and groups[position.group].talents[position.talent]
        if not talent then return end
        selectedTalent=selected;apply(talent);refreshTree()
    end)
    talentPicker.configure=show
    -- A button for the drawn tree sits beside the talent list when the client
    -- can show one. It reads the same tree the lists do, so it is off while the
    -- lists could not be filled.
    if platform.HasTalentTreeProvider and addon.OpenTalentTree and platform:HasTalentTreeProvider() then
        treeButton=addon:CreateConditionButton();treeButton:SetText(L["Show talent tree"]);treeButton:SetAutoWidth(true)
        treeButton:SetUserData("side",true)
        treeButton.frame.tooltip=L["Opens the talent tree of the rotation's specialization. Click a talent to choose it for this condition."]
        treeButton:SetDisabled(value.disabled==true or #groups==0)
        treeButton:SetCallback("OnClick",function()
            local current=info(value,spec)
            addon:OpenTalentTree({owner=treeOwner,spec=shown,selection=currentSelection(),selectionName=current and current.name,
                specs=specs,
                onSelect=function(selection)
                    -- Clicking the chosen talent again clears the choice.
                    if not selection then
                        value.node,value.entry,value.spell=nil,nil,nil
                        selectedTalent=nil
                        nodeBox:SetText("");entryBox:SetText("")
                        talentIcon:SetImage(PLACEHOLDER);update();show()
                        return
                    end
                    local found,foundGroup,foundTalent
                    for groupIndex,candidate in ipairs(groups) do
                        for talentIndex,talent in ipairs(candidate.talents) do
                            if talent.node==selection.node and talent.entry==selection.entry then foundGroup,foundTalent,found=groupIndex,talentIndex,talent end
                        end
                    end
                    if found then selectedGroup=foundGroup end
                    rebuild()
                    selectedTalent=found and flatIndex(foundGroup,foundTalent) or nil
                    apply({node=selection.node,entry=selection.entry,spellID=selection.spell,icon=found and found.icon or selection.icon})
                    show()
                end,
                -- The tree and the lists show the same specialization.
                onSpec=function(chosen)
                    if chosen==shown then return end
                    shown=chosen;reload();show()
                    if specPicker then specPicker:SetValue(shown) end
                end})
        end)
        treeButton:SetCallback("OnRelease",function() addon:CloseTalentTree(treeOwner) end)
        box:AddChild(treeButton)
    end
    local function identifier(entered)
        local number=tonumber(entered)
        if number and number>0 and number<2147483648 and number%1==0 then return number end
    end
    nodeBox=addon:CreateConditionEditBox();nodeBox:SetLabel(L["Talent Node ID"])
    if traitShape(value) and value.node~=nil then nodeBox:SetText(tostring(value.node)) end
    nodeBox:SetCallback("OnEnterPressed",function(_,_,entered)
        local number=identifier(entered)
        if not number then nodeBox:SetText(traitShape(value) and value.node and tostring(value.node) or "");return end
        -- A node typed by hand no longer goes with the spell of the talent picked before.
        adopt();value.node,value.spell=number,nil;selectedTalent=nil;talentPicker:SetValue(nil)
        local current=info(value,spec);talentIcon:SetImage(current and current.icon or PLACEHOLDER);update();refreshTree()
    end)
    parent:AddChild(nodeBox)
    entryBox=addon:CreateConditionEditBox();entryBox:SetLabel(L["Choice Entry ID"])
    if traitShape(value) and value.entry~=nil then entryBox:SetText(tostring(value.entry)) end
    entryBox:SetCallback("OnEnterPressed",function(_,_,entered)
        local number=identifier(entered)
        if entered~="" and entered~=nil and not number then entryBox:SetText(value.entry and tostring(value.entry) or "");return end
        if not traitShape(value) then return end
        value.entry,value.spell=number,nil;selectedTalent=nil;talentPicker:SetValue(nil)
        local current=info(value,spec);talentIcon:SetImage(current and current.icon or PLACEHOLDER);update();refreshTree()
    end)
    parent:AddChild(entryBox)
    operators=addon:Widget_OperatorWidget(value,L["Rank"],update);parent:AddChild(operators)
    show()
end
addon:RegisterCondition("TALENT",{
    description=L["Talent"],icon = addon.Artwork.condition["TALENT"],
    fields={layout="string",tree="number",talent="number",node="number",entry="number",spell="number",operator="string",value="number"},
    valid=function(_,value)
        if traitShape(value) then
            return integer(value.node,1,2147483647) and (value.entry==nil or integer(value.entry,1,2147483647))
                and (value.spell==nil or integer(value.spell,1,2147483647)) and value.tree==nil and value.talent==nil
                and Functions.values.isin(addon.operators,value.operator) and integer(value.value,0,64)
        end
        if value.node~=nil or value.entry~=nil then return false end
        if value.layout=="grid" then
            return integer(value.value,1,18) and value.tree==nil and value.talent==nil and value.operator==nil
        end
        if legacySlot(value) then return true end
        return treeShape(value) and integer(value.tree,1,16) and integer(value.talent,1,256)
            and Functions.values.isin(addon.operators,value.operator) and integer(value.value,0,64)
    end,
    evaluate=function(value,cache)
        if legacySlot(value) then return nil,"historical-talent-layout" end
        if traitShape(value) then
            if not addon.GetTraitNodeRank then return nil,"build-context-unavailable" end
            local rank,why=addon:GetTraitNodeRank(value.node,value.entry,value.spell)
            if rank==nil then return nil,why end
            return Functions.values.compare(value.operator,rank,value.value)
        end
        local talent,reason
        if value.layout=="grid" then
            talent,reason=Functions.cache.getCached(cache,platform.GetGridTalentInfo,platform,value.value)
            if not talent then return nil,reason end
            return talent.selected
        end
        talent,reason=Functions.cache.getCached(cache,platform.GetTreeTalentInfo,platform,value.tree,value.talent)
        if not talent then return nil,reason end
        return Functions.values.compare(value.operator,talent.rank,value.value)
    end,
    print=function(spec,value)
        local talent=info(value,spec)
        if legacySlot(value) then return string.format(L["Historical talent slot %s (unavailable)"],value.value) end
        if traitShape(value) then
            local name=talent and talent.name or value.node and string.format(L["talent node %s"],tostring(value.node)) or L["<talent>"]
            return Functions.presentation.compareString(value.operator,string.format(L["the number of ranks in %s"],name),Functions.presentation.nullable(value.value))
        end
        if value.layout=="grid" then return string.format(L["you {{!are|are not}} talented in %s"],talent and talent.name or L["<talent>"]) end
        local tree=value.tree and addon.TalentTrees.Name(value.tree,addon.TalentTrees.ContextClass(),group(spec))
        return Functions.presentation.compareString(value.operator,string.format(L["the number of talent points in %s (%s)"],
            talent and talent.name or L["<talent>"],tree or L["<talent tree>"]),Functions.presentation.nullable(value.value))
    end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData("top")
        local function update() top:SetStatusText(top:GetUserData("funcs"):print(top:GetUserData("root"),spec)) end
        local current=platform:GetTalentLayout()
        if current=="tree" then treeWidget(parent,spec,value,update)
        elseif current=="grid" then gridWidget(parent,spec,value,update)
        elseif current=="traits" then traitsWidget(parent,spec,value,update)
        else text(parent,L["This client uses a different talent system. This reference is preserved but cannot be evaluated."]) end
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L["Classic conditions compare points spent in a tree talent. Mists selections use six tiers with three choices. Historical references from another talent system remain unavailable and are never automatically converted."]))
        frame:AddChild(addon.help_funcs.Gap())
        frame:AddChild(addon.help_funcs.CreateText(L["Retail and Forever compare the rank of a talent in your active loadout. Pick it from the talents of the rotation's specialization (the Specialization list shows another specialization's, outside combat), or enter the node ID (and, for a choice node, the entry ID of the choice) to share a rotation. A choice node's entry has rank zero unless it is the chosen one, a hero talent outside your chosen hero tree has rank zero, and so does a talent of a specialization you are not playing. A talent picked from the list also remembers its spell, and is found again by it if Blizzard renumbers the talent tree. Ranks are read again after any talent change; an unreadable node is unavailable, including under NOT."]))
        if platform.HasTalentTreeProvider and platform:HasTalentTreeProvider() then
            frame:AddChild(addon.help_funcs.Gap())
            frame:AddChild(addon.help_funcs.CreateText(L["Show talent tree draws the talent tree of the specialization shown, with every talent open to choose. Click a talent to choose it, or click the chosen one again to clear it; the Talent list follows. It cannot open during combat."]))
        end
    end,
})

local function treeName(value,spec)
    local name=integer(value.tree,1,16) and addon.TalentTrees.Name(value.tree,addon.TalentTrees.ContextClass(),group(spec))
    return name or value.tree and string.format(L['Talent tree %s'],tostring(value.tree)) or L['<talent tree>']
end
local function treePicker(parent,spec,value,update)
    local choices,order={},{}
    local listed=addon.TalentTrees.Choices(addon.TalentTrees.ContextClass(),group(spec))
    if listed then choices,order=listed.choices,listed.order
    else text(parent,L['This client does not expose a Classic talent-tree layout. The saved tree reference is preserved.']) end
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
    description=L['Talent Tree Points'],icon = addon.Artwork.condition["TALENT_TREE_POINTS"],requiredFields={'tree','operator','value'},
    fields={tree='number',operator='string',value='number'},
    valid=function(_,value) return integer(value.tree,1,16) and Functions.values.isin(addon.operators,value.operator) and integer(value.value,0,512) end,
    evaluate=function(value,cache)
        if traitFamily() then
            if not addon.GetTraitTreePoints then return nil,"build-context-unavailable" end
            local points,why=addon:GetTraitTreePoints(value.tree)
            if points==nil then return nil,why end
            return Functions.values.compare(value.operator,points,value.value)
        end
        local exists,why=treeExists(value,cache);if not exists then return nil,why end
        local tree,reason=Functions.cache.getCached(cache,platform.GetTalentTreeInfo,platform,value.tree)
        if not tree then return nil,reason end
        if not integer(tree.pointsSpent,0,512) then return nil,'talent-points-unavailable' end
        return Functions.values.compare(value.operator,tree.pointsSpent,value.value)
    end,
    print=function(spec,value) return Functions.presentation.compareString(value.operator,string.format(L['the number of points spent in %s'],treeName(value,spec)),Functions.presentation.nullable(value.value)) end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData('top');local function update() top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec)) end
        treePicker(parent,spec,value,update);parent:AddChild(addon:Widget_OperatorWidget(value,L['Points'],update))
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Talent tree selects the Classic tree whose spent points are compared. Public points are read again on the next evaluation; missing or restricted points are unavailable, including under NOT. Grids and trait trees are unsupported.']))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L["Talent trees are named, never numbered: the list shows each tree by name, in the order the talent window shows them, for the class the rotation is for. Your own class takes the names the game gives its trees; another class's rotation uses Rotation Master's own list of that class's trees. The rotation saves the tree's position in that order, so it keeps its meaning when you share it."]))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L['Forever is the exception: Talent tree is one of the three talent trees of your active loadout (in the order the talent window shows them); their points are read again after any talent change. Retail has no such trees.']))
        frame:AddChild(addon.help_funcs.Gap());addon.layout_condition_operatorwidget_help(frame,L['Talent Tree Points'],L['Points'],L['Compare whole points spent from zero to 512. An explicit comparison with zero can describe an unspent tree.'])
    end,
})
addon:RegisterCondition('PRIMARY_TALENT_TREE',{
    description=L['Primary Talent Tree'],icon = addon.Artwork.condition["PRIMARY_TALENT_TREE"],requiredFields={'tree'},fields={tree='number'},
    valid=function(_,value) return integer(value.tree,1,16) end,
    evaluate=function(value,cache)
        if traitFamily() then
            if not addon.GetTraitPrimaryTree then return nil,"build-context-unavailable" end
            local primary,why=addon:GetTraitPrimaryTree()
            if primary==nil then return nil,why end
            return primary==value.tree
        end
        local exists,why=treeExists(value,cache);if not exists then return nil,why end
        local primary,reason=Functions.cache.getCached(cache,platform.GetPrimaryTalentTree,platform)
        if not primary then return nil,reason end
        return primary.index==value.tree
    end,
    print=function(spec,value) return string.format(L['your primary talent tree {{!is|is not}} %s'],treeName(value,spec)) end,
    widget=function(parent,spec,value)
        local top=parent:GetUserData('top');treePicker(parent,spec,value,function() top:SetStatusText(top:GetUserData('funcs'):print(top:GetUserData('root'),spec)) end)
    end,
    help=function(frame)
        frame:AddChild(addon.help_funcs.CreateText(L['Talent tree selects the unique Classic tree with the most positive spent points. Equal maxima, no spent points, missing records and restricted points are unavailable, including under NOT.']))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L["Talent trees are named, never numbered: the list shows each tree by name, in the order the talent window shows them, for the class the rotation is for. Your own class takes the names the game gives its trees; another class's rotation uses Rotation Master's own list of that class's trees. The rotation saves the tree's position in that order, so it keeps its meaning when you share it."]))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L['The primary tree is derived from readable points, not the saved rotation slot. Hybrid builds may need tree-point or individual-talent conditions instead; the primary tree does not assign a tank or healer role. Grids and trait trees are unsupported.']))
        frame:AddChild(addon.help_funcs.Gap());frame:AddChild(addon.help_funcs.CreateText(L['Forever is the exception: Talent tree is one of the three talent trees of your active loadout (in the order the talent window shows them); their points are read again after any talent change. Retail has no such trees.']))
    end,
})

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="GRID_TIER_LEVELS" then return GRID_TIER_LEVELS end
        if name=="PLACEHOLDER" then return PLACEHOLDER end
        if name=="block" then return block end
        if name=="classSpecs" then return classSpecs end
        if name=="dropdown" then return dropdown end
        if name=="gridWidget" then return gridWidget end
        if name=="group" then return group end
        if name=="groupLabel" then return groupLabel end
        if name=="icon" then return icon end
        if name=="info" then return info end
        if name=="integer" then return integer end
        if name=="legacySlot" then return legacySlot end
        if name=="ownTrees" then return ownTrees end
        if name=="platform" then return platform end
        if name=="text" then return text end
        if name=="traitFamily" then return traitFamily end
        if name=="traitShape" then return traitShape end
        if name=="traitsWidget" then return traitsWidget end
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
