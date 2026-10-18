local _,addon=...
local function copy(path)
    local result={};for i,part in ipairs(path) do result[i]=part end;return result
end
function addon.ConditionPathKey(path)
    local result={}
    for _,part in ipairs(path) do
        local encoded=tostring(part):gsub("%%","%%25"):gsub("/","%%2F")
        result[#result+1]=type(part)..":"..encoded
    end
    return table.concat(result,"/")
end
local function at(root,path)
    for _,part in ipairs(path) do root=root[part] end;return root
end
local function dimension(value,fallback,maximum)
    return type(value)=="number" and value==value and value>0 and math.min(value,maximum) or fallback
end

-- The input rows come from the bounded draft model. This scene holds plain,
-- detached presentation values; it never calls condition printers or widgets.
function addon:BuildConditionCanvas(root,rows,view)
    view=view or {}
    -- NOT is stored as a node, but shown as a property of its operand. Keep
    -- both paths: structural commands act on the outer wrapper; fields act
    -- on the underlying operand. This is a projection, never a data rewrite.
    local tree,ancestors
    ancestors={}
    for _,row in ipairs(rows) do
        while #ancestors>0 and ancestors[#ancestors].row.depth>=row.depth do table.remove(ancestors) end
        local branch={row=row,node=at(root,row.path),children={}}
        local parent=ancestors[#ancestors]
        if parent then parent.children[#parent.children+1]=branch else tree=branch end
        ancestors[#ancestors+1]=branch
    end
    local projected={}
    local function project(branch,depth,inactive)
        local outer=branch;local count=0;local disabled,invalidDisabled=false,false;local disabledPath,name,namePath
        local function flags(current)
            if current.row.disabled and not disabledPath then disabledPath=copy(current.row.path) end
            disabled=disabled or current.row.disabled;invalidDisabled=invalidDisabled or current.row.invalidDisabled
            if not name and (current.node.type=="AND" or current.node.type=="OR" or current.node.type=="NOT") and type(current.node.name)=="string" then name=current.node.name;namePath=copy(current.row.path) end
        end
        flags(branch)
        while branch.node.type=="NOT" and #branch.children==1 do count=count+1;branch=branch.children[1];flags(branch) end
        local siblingPath=copy(outer.row.path);local siblingIndex=table.remove(siblingPath)
        local siblings=type(siblingIndex)=='number' and at(root,siblingPath) or nil
        local canMoveUp=type(siblings)=='table' and siblingIndex>1 or false
        local canMoveDown=type(siblings)=='table' and siblingIndex<#siblings or false
        local missing=branch.node.type=="NOT" and #branch.children==0
        if missing then count=count+1 end
        projected[#projected+1]={path=copy(outer.row.path),fieldPath=copy(branch.row.path),namePath=namePath or copy(branch.row.path),
            disabledPath=disabledPath or copy(outer.row.path),node=missing and {} or branch.node,type=not missing and branch.node.type or nil,
            negated=count%2==1,missingOperand=missing,disabled=disabled,invalidDisabled=invalidDisabled,
            canMoveUp=canMoveUp,canMoveDown=canMoveDown,name=name,depth=depth,childCount=#branch.children,unreachable=inactive==true}
        for _,child in ipairs(branch.children) do project(child,depth+1,inactive or disabled) end
    end
    if tree then project(tree,0) end
    rows=projected
    local width=math.max(340,dimension(view.width,1000,4000))
    local scene={cards={},connectors={},dropTargets={},width=width,complete=true}
    local stack,y,hiddenDepth={},8,nil
    local function finish(depth)
        while #stack>0 and stack[#stack].depth>=depth do
            local group=table.remove(stack);group.height=math.max(group.height,y-group.y);y=y+8
            group.width=math.max(group.width,(group.contentRight or group.x+group.width)-group.x+14)
            local parent=stack[#stack]
            if parent then parent.contentRight=math.max(parent.contentRight or 0,group.x+group.width) end
        end
    end
    local function drop(card,kind,destination,top,height)
        scene.dropTargets[#scene.dropTargets+1]={cardKey=card.key,kind=kind,destination=destination,
            x=card.x,y=top,width=card.width,height=height}
    end
    for _,row in ipairs(rows) do
        if hiddenDepth and row.depth<=hiddenDepth then hiddenDepth=nil end
        if not hiddenDepth then
            if #scene.cards>=200 then scene.complete=false;break end
            finish(row.depth)
            local node=row.node;local key=addon.ConditionPathKey(row.path)
            local group=row.type=="AND" or row.type=="OR" or row.type=="NOT"
            local state=(view.cardStates or {})[key] or (group and view.collapsed and view.collapsed[key] and 'compact') or (not group and view.expanded and view.expanded[key] and 'expanded') or 'normal'
            local compact=state=='compact'
            local collapsed=group and (((view.hiddenChildren or {})[key] or (view.collapsed or {})[key])==true)
            local expanded=not compact and ((view.help and view.help[key]==true) or state=='expanded') or false
            local headerHeight=26+((not compact and not group and row.name and row.name~="") and 18 or 0)
            local ownHeight=compact and 28 or math.max(group and 88 or 72,headerHeight+4+(expanded and dimension((view.detailsHeights or {})[key],group and 40 or 120,5000) or math.max(28,dimension((view.summaryHeights or {})[key],28,3000))))
            local x=12+math.min(row.depth,12)*26
            local card={key=key,path=copy(row.path),type=row.type,depth=row.depth,group=group,collapsed=collapsed,compact=compact,state=state,expanded=expanded,
                childCount=row.childCount,disabled=row.disabled,invalidDisabled=row.invalidDisabled,
                unreachable=row.unreachable,canMoveUp=row.canMoveUp,canMoveDown=row.canMoveDown,
                name=row.name,negated=row.negated,fieldPath=copy(row.fieldPath),namePath=copy(row.namePath),disabledPath=copy(row.disabledPath),missingOperand=row.missingOperand,
                selected=view.selection and view.selection[key]==true or false,
                x=x,y=y,width=math.max(340,dimension((view.labelWidths or {})[key],0,1200)+192),height=ownHeight,ownHeight=ownHeight,headerHeight=headerHeight}
            local parent=stack[#stack]
            if parent then
                parent.contentRight=math.max(parent.contentRight or 0,x+card.width)
                local stemTop=parent.y+(parent.compact and 26 or 66)
                scene.connectors[#scene.connectors+1]={x=parent.x+10,y=stemTop,width=2,height=math.max(2,y+22-stemTop)}
                scene.connectors[#scene.connectors+1]={x=parent.x+10,y=y+22,width=math.max(2,x-parent.x-10),height=2}
            end
            scene.cards[#scene.cards+1]=card;y=y+ownHeight+8
            if type(row.path[#row.path])=="number" then
                local parentPath=copy(row.path);local index=table.remove(parentPath);local field=table.remove(parentPath)
                drop(card,"before",{path=parentPath,field=field,index=index},card.y,8)
                drop(card,"after",{path=copy(parentPath),field=field,index=index+1},card.y+ownHeight,8)
            else
                drop(card,"before",{path=copy(row.path),relation="before"},card.y,8)
                drop(card,"after",{path=copy(row.path),relation="after"},card.y+ownHeight,8)
            end
            if group then
                if collapsed or row.childCount==0 then
                    drop(card,"inside",{path=copy(row.fieldPath)},card.y+(compact and 8 or 36),12)
                end
                if collapsed then hiddenDepth=row.depth end
            else
                if next(node)==nil then drop(card,"inside",{path=copy(row.fieldPath)},card.y+(compact and 8 or 54),12) end
                local slots={}
                local definition=(view.definitions or {})[row.type]
                for field,kind in pairs(definition and definition.fields or {}) do
                    if (kind=="condition[]" or kind=="condition") and (not node[field] or next(node[field])==nil) then slots[#slots+1]=field end
                end
                table.sort(slots)
                for index,field in ipairs(slots) do
                    drop(card,"inside",{path=copy(row.fieldPath),field=field},card.y+(compact and 8 or 54),12)
                    local target=scene.dropTargets[#scene.dropTargets]
                    target.width=card.width/#slots;target.x=card.x+(index-1)*target.width
                end
            end
            if not collapsed and row.childCount>0 then stack[#stack+1]=card end
        end
    end
    finish(-1);scene.height=math.max(1,y+8)
    for _,card in ipairs(scene.cards) do scene.width=math.max(scene.width,card.x+card.width+16) end
    local destinations,unique={},{}
    for _,target in ipairs(scene.dropTargets) do
        for _,card in ipairs(scene.cards) do if card.key==target.cardKey then
            if target.kind~="inside" then target.width=card.width end
            if target.kind=="after" then target.y=card.y+card.height end
            if target.kind=="inside" and target.destination.field==nil then target.x=card.x+32;target.width=card.width-64 end
            break
        end end
        if target.kind=="inside" then unique[#unique+1]=target
        else
            local destination=target.destination
            local key=addon.ConditionPathKey(destination.path).."/field:"..addon.ConditionPathKey({destination.field or "value"}).."/index:"..tostring(destination.index).."/relation:"..tostring(destination.relation)
            local gap=destinations[key]
            if not gap then gap=target;destinations[key]=gap;unique[#unique+1]=gap end
            if target.kind=="before" then gap.nextY=target.y else gap.previousY=target.y end
            gap.width=math.max(gap.width,target.width)
        end
    end
    for _,target in ipairs(unique) do if target.kind~="inside" then
        local center=target.previousY and target.nextY and (target.previousY+target.nextY)/2
            or target.previousY and target.previousY+4 or target.nextY-4
        target.y=center-4;target.height=8
    end end
    scene.dropTargets=unique
    return scene
end
