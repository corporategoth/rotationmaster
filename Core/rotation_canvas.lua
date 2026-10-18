local _,addon=...
local data=addon.RotationData
local cardWidth,headerHeight,gap,armGap,armLead,armJoin=340,84,24,40,40,24
local function copy(path) local result={};for i,key in ipairs(path) do result[i]=key end;return result end
local function extend(path,key) local result=copy(path);result[#result+1]=key;return result end
local function height(value)
    return type(value)=="number" and value==value and value>0 and math.min(value,800) or 0
end

-- Plain geometry only. No live combat observation, callback, native frame or
-- custom printer is involved. Both evaluated arms stay visible while editing.
function addon:BuildRotationCanvas(body,view)
    local index,why=data.IndexRotationSteps(body)
    if not index then return nil,why end
    view=view or {}
    local section=view.section=='rotation' and 'rotation' or view.section=='cooldowns' and 'cooldowns' or nil
    local listView=view.layout=="list" and section~='cooldowns'
    local collapsed=type(view.collapsed)=="table" and view.collapsed or {}
    local details=type(view.detailsHeights)=="table" and view.detailsHeights or {}
    local scene={cards={},connectors={},dropTargets={},groups={},complete=true,width=cardWidth,height=0,section=section,layout=section=='cooldowns' and 'grid' or listView and "list" or "diagram",armLabels={}}
    local rows={};for _,row in ipairs(index.rows) do rows[row.step]=row end
    local function state(step)
        return (view.cardStates or {})[step.id] or (collapsed[step.id] and 'compact') or (height(details[step.id])>0 and 'expanded') or (listView and rows[step].section=='rotation' and 'compact') or 'normal'
    end
    local function armList(step,arm)
        local folded=(view.hiddenArms or {})[step.id] and view.hiddenArms[step.id][arm]
        local source=step[arm=='true' and 'onTrue' or 'onFalse']
        return source,folded==true
    end
    local count=0
    local measureList
    local function measureNode(step)
        if count>=200 then scene.complete=false;return nil end
        count=count+1
        local row=rows[step]
        local mode=state(step)
        local ownHeader=mode=='compact' and 28 or mode=='expanded' and 28 or (step.type=='branch' and 68 or 78)+math.max(0,height((view.summaryHeights or {})[step.id])-28)
        local conditionHeight=mode=='expanded' and step.type~='branch' and math.max(24,height((view.summaryHeights or {})[step.id])) or 0
        local node={step=step,row=row,ownHeader=ownHeader,conditionHeight=conditionHeight,header=mode=='expanded' and math.max(72,ownHeader+height(details[step.id])+(conditionHeight>0 and conditionHeight+4 or 0)) or ownHeader,width=cardWidth}
        node.height=node.header;node.left=cardWidth/2;node.right=cardWidth/2
        if step.type=="branch" and not ((view.hiddenChildren or {})[step.id] or collapsed[step.id]) then
            local yes,hideYes=armList(step,'true');local no,hideNo=armList(step,'false')
            node.yes=measureList(hideYes and {} or yes,extend(row.path,"onTrue"),step.id)
            node.no=measureList(hideNo and {} or no,extend(row.path,"onFalse"),step.id)
            node.yes.folded=hideYes;node.no.folded=hideNo
            node.yes.count=#yes;node.no.count=#no
            if listView then
                node.width=math.max(node.no.width,node.yes.width)+32
                node.height=node.header+22+node.no.height+22+node.yes.height+4
            else
                local hasYes,hasNo=#node.yes.nodes>0,#node.no.nodes>0
                node.single=hasYes~=hasNo
                if node.single then
                    local active=hasYes and node.yes or node.no
                    node.left=math.max(cardWidth/2,active.left+(hasNo and 0 or 100))
                    node.right=math.max(cardWidth/2,active.right+(hasYes and 0 or 100))
                else
                    node.armDistance=node.no.right+armGap+node.yes.left
                    node.left=math.max(cardWidth/2,node.armDistance/2+node.no.left)
                    node.right=math.max(cardWidth/2,node.armDistance/2+node.yes.right)
                end
                node.width=node.left+node.right
                node.height=node.header+armLead+math.max(node.yes.height,node.no.height)+armJoin
            end
        end
        return node
    end
    measureList=function(list,path,parentId)
        local result={nodes={},path=path,parentId=parentId,width=cardWidth,left=cardWidth/2,right=cardWidth/2,height=0,gap=listView and path[1]=='rotation' and 0 or gap}
        for position,step in ipairs(list) do
            local node=measureNode(step)
            if not node then result.truncated=true;break end
            node.canMoveUp=position>1;node.canMoveDown=position<#list
            if #result.nodes>0 then result.height=result.height+result.gap end
            result.nodes[#result.nodes+1]=node;result.width=math.max(result.width,node.width)
            if not listView then result.left=math.max(result.left,node.left);result.right=math.max(result.right,node.right);result.width=result.left+result.right end
            result.height=result.height+node.height
        end
        if #result.nodes==0 then result.height=36 end
        return result
    end
    local sectionStates=view.sectionsCollapsed or {}
    local ordered=measureList(section~='cooldowns' and not sectionStates.rotation and body.rotation or {},{"rotation"})
    local optional=measureList(section~='rotation' and not sectionStates.cooldowns and body.cooldowns or {},{"cooldowns"})
    local function target(list,indexValue,x,y,width)
        scene.dropTargets[#scene.dropTargets+1]={x=x,y=y,width=width,height=24,
            destination={path=copy(list.path),index=indexValue,parentId=list.parentId},truncated=list.truncated==true}
    end
    local function line(from,to,points,arm,inactive,label,owner)
        scene.connectors[#scene.connectors+1]={from=from,to=to,points=points,arm=arm,
            tone=arm=="true" and "green" or arm=="false" and "red" or inactive and "gray" or "neutral",
            label=label,owner=owner,inactive=inactive==true}
    end
    local placeList
    local function placeNode(node,x,y)
        local step,row=node.step,node.row
        local branch=step.type=="branch"
        local inactive=row.unreachable or step.disabled==true
        local mode=branch and (step.mode or "evaluate") or nil
        local tone=branch and (mode=="true" and "green" or mode=="false" and "red" or "white") or "green"
        local shallow={}
        for key,value in pairs(step) do if not (branch and (key=="onTrue" or key=="onFalse")) then shallow[key]=value end end
        local card={id=step.id,path=copy(row.path),section=row.section,depth=row.depth,ordinal=row.ordinal,
            parentId=row.parentId,arm=row.arm,canMoveUp=node.canMoveUp,canMoveDown=node.canMoveDown,step=data.CopyData(shallow),mode=mode,inactive=inactive,
            border=inactive and "gray" or tone,collapsed=branch and ((view.hiddenChildren or {})[step.id] or collapsed[step.id])==true,compact=state(step)=="compact",
            expanded=state(step)=="expanded",x=x+(listView and 0 or node.left-cardWidth/2),y=y,width=cardWidth,height=node.header,headerHeight=node.ownHeader,conditionHeight=node.conditionHeight}
        scene.cards[#scene.cards+1]=card
        local center=card.x+cardWidth/2
        local entry={x=center,y=y,id=step.id}
        local exit={x=center,y=y+node.header,id=step.id}
        if node.yes and listView then
            scene.groups[#scene.groups+1]={id=step.id,kind='branch',x=x,y=y,width=node.width,height=node.height,tone=inactive and 'gray' or tone,inactive=inactive}
            local armsY=y+node.header
            for _,choice in ipairs({{arm='false',list=node.no,blocked=inactive or mode=='true'},
                {arm='true',list=node.yes,blocked=inactive or mode=='false'}}) do
                scene.groups[#scene.groups+1]={id=step.id,kind='arm',arm=choice.arm,x=x+20,y=armsY,width=node.width-24,height=choice.list.height+22,tone=choice.arm=='false' and 'red' or 'green',inactive=choice.blocked}
                scene.armLabels[#scene.armLabels+1]={x=x+26,y=armsY+2,arm=choice.arm,inactive=choice.blocked,parentId=step.id,folded=choice.list.folded,count=choice.list.count}
                placeList(choice.list,x+24,armsY+18,'list')
                armsY=armsY+choice.list.height+22
            end
            exit={x=center,y=y+node.height,id=step.id}
        elseif node.yes then
            local armsY=y+node.header+armLead
            local hasYes,hasNo=#node.yes.nodes>0,#node.no.nodes>0
            local centers={}
            if node.single then
                centers['true']=hasYes and center or x+node.width-40
                centers['false']=hasNo and center or x+40
            else
                centers['false']=center-node.armDistance/2;centers['true']=center+node.armDistance/2
            end
            local joinY=y+node.height
            for _,choice in ipairs({{arm="false",list=node.no,blocked=inactive or mode=="true"},
                {arm="true",list=node.yes,blocked=inactive or mode=="false"}}) do
                local laneCenter=centers[choice.arm];local enter,leave
                if #choice.list.nodes>0 then enter,leave=placeList(choice.list,laneCenter-choice.list.left,armsY,"rotation")
                else
                    enter={x=laneCenter,y=armsY};leave={x=laneCenter,y=armsY+choice.list.height}
                    scene.dropTargets[#scene.dropTargets+1]={x=laneCenter-36,y=armsY,width=72,height=24,destination={path=copy(choice.list.path),index=1,parentId=step.id}}
                end
                local populated=#choice.list.nodes>0
                local stemX=node.single and populated and center or center+(choice.arm=='false' and -2 or 2)
                local points={{x=stemX,y=y+node.header},{x=stemX,y=armsY-20},{x=enter.x,y=armsY-20},{x=enter.x,y=armsY}}
                line(step.id,enter.id,points,choice.arm,choice.blocked,choice.arm,step.id)
                if not enter.id then line(step.id,nil,{{x=enter.x,y=enter.y},{x=leave.x,y=leave.y}},choice.arm,choice.blocked,nil,step.id) end
                line(leave.id,nil,{{x=leave.x,y=leave.y},{x=leave.x,y=joinY-8},{x=center,y=joinY-8}},choice.arm,choice.blocked,nil,step.id)
                local labelX=math.max(x,math.min(x+node.width-100,laneCenter-50));local labelY=armsY-40;local placement='above'
                if node.single and populated then labelX=center+(choice.arm=='true' and 8 or -108);labelY=y+node.header+(armLead-20)/2-9;placement=choice.arm=='true' and 'right' or 'left' end
                scene.armLabels[#scene.armLabels+1]={x=labelX,y=labelY,placement=placement,arm=choice.arm,parentId=step.id,folded=choice.list.folded,count=choice.list.count,inactive=choice.blocked}
            end
            line(nil,nil,{{x=center,y=joinY-8},{x=center,y=joinY}},nil,inactive,nil,step.id)
            exit={x=center,y=joinY,id=step.id}
        end
        return entry,exit
    end
    placeList=function(list,x,y,section)
        local cursor=y
        local first,last
        for i,node in ipairs(list.nodes) do
            local nx=x+(section=='rotation' and list.left-node.left or 0)
            if section=='list' then
                scene.dropTargets[#scene.dropTargets+1]={x=nx,y=cursor-6,width=node.width,height=12,destination={path=copy(list.path),index=i,parentId=list.parentId},truncated=list.truncated==true}
            else target(list,i,nx,cursor-(i==1 and 24 or list.gap/2+12),node.width) end
            local entry,exit=placeNode(node,nx,cursor)
            if not first then first=entry end
            if last and section=="rotation" then
                line(last.id,entry.id,{{x=last.x,y=last.y},{x=last.x,y=cursor-gap/2},
                    {x=entry.x,y=cursor-gap/2},{x=entry.x,y=cursor}},nil,node.row.unreachable or node.step.disabled==true)
            end
            last=exit;cursor=cursor+node.height+list.gap
        end
        if section=='list' then
            scene.dropTargets[#scene.dropTargets+1]={x=x,y=(#list.nodes==0 and y+list.height/2 or y+list.height)-6,width=list.width,height=12,destination={path=copy(list.path),index=#list.nodes+1,parentId=list.parentId},truncated=list.truncated==true}
        else target(list,#list.nodes+1,x,#list.nodes==0 and y+list.height/2-12 or y+list.height+list.gap/2-12,list.width) end
        local empty={x=x+list.width/2,y=y+list.height}
        return first or {x=empty.x,y=y},last or empty
    end
    local columns=math.max(1,math.min(4,math.floor(((view.viewportWidth or 720)+gap)/(cardWidth+gap))))
    columns=math.min(columns,math.max(1,#optional.nodes))
    local gridWidth=columns*cardWidth+(columns-1)*gap
    scene.sections={cooldowns={y=8,collapsed=sectionStates.cooldowns==true},rotation={collapsed=sectionStates.rotation==true}}
    local cursor=section and 24 or 44
    if section~='rotation' and #optional.nodes==0 and not sectionStates.cooldowns then target(optional,1,0,cursor,gridWidth);cursor=cursor+36 end
    for first=1,#optional.nodes,columns do
        local rowHeight=0
        for i=first,math.min(first+columns-1,#optional.nodes) do
            local node=optional.nodes[i];local x=(i-first)*(cardWidth+gap)
            target(optional,i,x,cursor-16,cardWidth)
            placeNode(node,x,cursor);rowHeight=math.max(rowHeight,node.height)
        end
        cursor=cursor+rowHeight+gap
    end
    if #optional.nodes>0 then target(optional,#optional.nodes+1,0,cursor-12,gridWidth) end
    scene.separatorY=cursor+8
    scene.sections.rotation.y=section=='rotation' and -12 or sectionStates.cooldowns and scene.sections.cooldowns.y+32 or cursor+16
    if section~='cooldowns' and not sectionStates.rotation then placeList(ordered,0,scene.sections.rotation.y+36,listView and "list" or "rotation") end
    scene.width=math.max(560,ordered.width,gridWidth,math.min(1600,view.viewportWidth or 0))
    scene.height=section=='cooldowns' and cursor+16 or scene.sections.rotation.y+(sectionStates.rotation and 32 or 36+ordered.height+24)
    return scene
end
