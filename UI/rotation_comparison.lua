local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local AceGUI=LibStub("AceGUI-3.0")

-- Consumes trusted results from RotationData, never live observations or Lua.
function addon:FormatRotationComparison(result)
    local lines,bytes,truncated={},0,false
    local function safe(value,limit)
        local text=tostring(value)
        if #text>limit then text=text:sub(1,limit).."...";truncated=true end
        return (text:gsub("|","||"))
    end
    local function append(text)
        if bytes+#text+1>65000 then truncated=true;return false end
        lines[#lines+1]=text;bytes=bytes+#text+1;return true
    end
    local function value(v)
        local count=0
        local function render(current,depth)
            count=count+1
            if count>100 or depth>8 then truncated=true;return "..." end
            if type(current)=="string" then return safe(string.format("%q",current),160) end
            if current==nil then return L["absent"] end
            if type(current)~="table" then return safe(current,160) end
            local keys={}
            for key in pairs(current) do keys[#keys+1]=key end
            table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)=="number" end)
            local parts={"{"}
            for _,key in ipairs(keys) do
                if count>=100 then parts[#parts+1]="...";truncated=true;break end
                local name=type(key)=="string" and safe(string.format("%q",key),160) or tostring(key)
                parts[#parts+1]="["..name.."] = "..render(current[key],depth+1)..", "
            end
            parts[#parts+1]="}"
            return table.concat(parts)
        end
        local text=render(v,0)
        if #text>8192 then truncated=true;return text:sub(1,8192).."..." end
        return text
    end
    local function section(title,part)
        append(title)
        if not part.valid then append(L["This comparison could not be completed."])
        elseif not part.complete then append(L["This comparison is incomplete; some changes are omitted."]) end
        if part.valid and part.complete and #part.changes==0 then append(L["No differences."]) end
        for _,change in ipairs(part.changes) do
            local path=safe(change.path,512)
            local text
            if change.kind=="added" then text=string.format(L["Added %s: %s"],path,value(change.after))
            elseif change.kind=="removed" then text=string.format(L["Removed %s: %s"],path,value(change.before))
            elseif change.kind=="moved" then text=string.format(L["Moved %s: priority %s → %s"],path,change.fromIndex,change.toIndex)
            else text=string.format(L["Changed %s: %s → %s"],path,value(change.before),value(change.after)) end
            if not append(text) then break end
        end
        for _,diagnostic in ipairs(part.diagnostics or {}) do
            if not append(safe(diagnostic.code,100)..": "..safe(diagnostic.path,512)) then break end
        end
        append("")
    end
    append(L["Read-only comparison. Priority moves are listed; rotations are not merged."])
    if result.sourceChanges then
        section(L["Changes in the default since cloning"],result.sourceChanges)
        section(L["Your changes since cloning"],result.customChanges)
        section(L["Differences from the current default"],result.currentDifferences)
        append(L["Overlapping field edits"])
        if #result.conflicts==0 then append(L["No overlapping field edits detected. Priority order still needs review."]) end
        for _,conflict in ipairs(result.conflicts) do if not append(safe(conflict.path,512)) then break end end
        if not result.complete then append(L["This comparison is incomplete; some changes are omitted."]) end
        for _,diagnostic in ipairs(result.diagnostics or {}) do append(safe(diagnostic.code,100)) end
    else section(L["Selected rotation → your rotation"],result) end
    if truncated then lines[#lines+1]=L["Some display text was truncated. Rotation data has not been changed."] end
    return table.concat(lines,"\n")
end

local function label(parent,text,kind)
    local widget=AceGUI:Create(kind or "Label");widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)
    return widget
end
local directionNames={current=L["Selected rotation → your rotation"],source=L["Default updates since cloning"],custom=L["Your edits since cloning"]}
function addon:RenderRotationComparison(parent,view,spec,showUnchanged)
    parent:ReleaseChildren()
    local model=self.RotationData.BuildVisualComparison(view)
    if not model then label(parent,L["This comparison could not be completed."]);return end
    label(parent,L["Read-only comparison. Rotations are not merged."])
    if not model.complete then label(parent,L["This comparison is incomplete; some changes are omitted."]) end
    if model.additionalChanges>0 then label(parent,L["Additional settings changed. Copy diagnostic details to inspect all fields."]) end
    local unchanged=0
    for _,rows in pairs(model.groups) do for _,row in ipairs(rows) do
        if not (row.added or row.removed or row.changed or row.moved) then unchanged=unchanged+1 end
    end end
    if model.complete and model.displayChangeCount==0 then label(parent,L["No differences."]) end
    if unchanged>0 then
        local toggle=AceGUI:Create("CheckBox");toggle:SetFullWidth(true)
        toggle:SetLabel(L["Show unchanged steps"]);toggle:SetValue(showUnchanged==true)
        toggle:SetCallback("OnValueChanged",function(_,_,value) addon:RenderRotationComparison(parent,view,spec,value==true) end)
        parent:AddChild(toggle)
        if not showUnchanged then label(parent,string.format(L["%s unchanged steps hidden."],unchanged)) end
    end
    local leftTitle=view.key=="source" and L["At cloning"] or view.key=="custom" and L["At cloning"] or L["Selected rotation"]
    local rightTitle=view.key=="source" and L["Current default"] or view.key=="import" and L["Incoming rotation"] or L["Your rotation"]
    if view.key=="import" then leftTitle=L["Your rotation"] end
    local function pair(left,right,render)
        local row=AceGUI:Create("SimpleGroup");row:SetFullWidth(true);row:SetLayout("Flow")
        for _,side in ipairs({"left","right"}) do
            local column=AceGUI:Create("SimpleGroup");column:SetRelativeWidth(0.5);column:SetLayout("List");column.alignoffset=0
            label(column,side=="left" and leftTitle or rightTitle,"Heading")
            local entry
            if side=="left" then entry=left else entry=right end
            if entry then render(column,entry) else label(column,L["No corresponding step"])
            end
            row:AddChild(column)
        end
        parent:AddChild(row)
    end
    if model.namesChanged then
        label(parent,L["Rotation names"],"Heading")
        pair({name=model.leftName,nameKey=model.leftNameKey},{name=model.rightName,nameKey=model.rightNameKey},function(column,entry)
            label(column,entry.name or entry.nameKey and L[entry.nameKey] or DEFAULT)
        end)
    end
    if model.tagsChanged then
        label(parent,L['Tags'],"Heading")
        pair({tags=model.leftTags},{tags=model.rightTags},function(column,entry) label(column,addon.RotationData.FormatRotationTags(entry.tags) or '') end)
    end
    if model.priorityChanged then
        label(parent,L['Switch priority'],'Heading')
        pair({priority=model.leftPriority},{priority=model.rightPriority},function(column,entry) label(column,entry.priority and tostring(entry.priority) or L['Invalid priority']) end)
    end
    if model.switchChanged then
        label(parent,L["Switch conditions"],"Heading")
        pair({condition=model.leftSwitch},{condition=model.rightSwitch},function(column,entry)
            addon:CreateConditionReference(column,entry.condition,spec)
        end)
    end
    for _,kind in ipairs({"cooldowns","rotation"}) do
        label(parent,kind=="cooldowns" and L["Optional highlights"] or L["Sequential priority"],"Heading")
        if #model.groups[kind]==0 then label(parent,L["No steps in this section."]) end
        for _,row in ipairs(model.groups[kind]) do
            local status={}
            if row.added then status[#status+1]="|cff6fce91"..L["Added"].."|r" end
            if row.removed then status[#status+1]="|cffe58c82"..L["Removed"].."|r" end
            if row.changed then status[#status+1]="|cffcfa04a"..L["Changed"].."|r" end
            if row.moved then status[#status+1]="|cff5bc0eb"..L["Moved"].."|r" end
            if #status>0 or showUnchanged then pair(row.left,row.right,function(column,entry)
                addon:CreateRotationBranchBreadcrumb(column,entry.branchPath)
                addon:CreateRotationStepCard(column,entry.step,spec,entry.index,kind,#status>0 and table.concat(status,", ") or L["Unchanged"])
            end) end
        end
    end
end
function addon:ShowComparisonReport(report)
    local frame=AceGUI:Create("Window")
    frame:SetTitle(L["Comparison diagnostic details"]);frame:SetWidth(820);frame:SetHeight(500);frame:SetLayout("Flow")
    frame:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end);self.HideOnEscape(frame)
    local text=AceGUI:Create("MultiLineEditBox")
    text:SetLabel(L["Press Ctrl+C to copy the selected diagnostic details."])
    text:SetFullWidth(true);text:SetFullHeight(true);text:SetNumLines(24);text:DisableButton(true)
    local setting=false
    text:SetText(report)
    text:SetCallback("OnTextChanged",function(_,_,current)
        if not setting and current~=report then setting=true;text:SetText(report);setting=false end
    end)
    frame:AddChild(text);text:SetFocus();text:SetCursorPosition(0);text:HighlightText(0,-1)
    return frame
end
function addon:ShowRotationComparison(spec,id)
    local frame=AceGUI:Create("Window")
    frame:SetTitle(L["Compare rotations"]);frame:SetWidth(1080);frame:SetHeight(700);frame:SetLayout("Flow")
    frame:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end);self.HideOnEscape(frame)
    local own=self:GetEditableRotation(spec,id)
    label(frame,string.format(L["Your rotation: %s"],own and own.name or DEFAULT))
    local targets,labels={},{}
    local selected
    local sourced=self:GetSourcedRotationView(spec,id)
    for _,row in ipairs(self:ListDefaultRotations(spec)) do
        targets[#targets+1]={kind="builtin",id=row.id}
        labels[#targets]="|cff5bc0eb"..row.name.."|r ("..L["Default · read-only"]..")"
        if sourced and sourced.lineage.sourceId==row.id and sourced.lineage.sourceKind=="builtin" then selected=#targets end
    end
    local custom={}
    for key,body in pairs(self.db.profile.rotations[spec] or {}) do
        if key~=id then custom[#custom+1]={id=key,name=body.name or DEFAULT} end
    end
    table.sort(custom,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
    for _,entry in ipairs(custom) do targets[#targets+1]={kind="custom",id=entry.id};labels[#targets]=entry.name end
    local chooser=AceGUI:Create("Dropdown")
    chooser:SetFullWidth(true);chooser:SetLabel(L["Compare against"]);chooser:SetList(labels)
    selected=selected or 1;chooser:SetValue(selected);frame:AddChild(chooser)
    local direction=AceGUI:Create("Dropdown");direction:SetFullWidth(true);direction:SetLabel(L["Comparison view"]);frame:AddChild(direction)
    local copy=AceGUI:Create("Button");copy:SetText(L["Copy diagnostic details"]);frame:AddChild(copy)
    local graph=AceGUI:Create("ScrollFrame");graph:SetLayout("List");graph:SetFullWidth(true);graph:SetFullHeight(true);frame:AddChild(graph)
    local result,report
    local function show(index)
        local view=result and result.views and result.views[index]
        if view then addon:RenderRotationComparison(graph,view,spec)
        else graph:ReleaseChildren();label(graph,L["This comparison could not be completed."]) end
    end
    local function refresh(index)
        local why
        result,why=addon:BuildRotationComparison(spec,id,targets[index])
        report=result and addon:FormatRotationComparison(result) or string.format(L["Comparison unavailable: %s"],why)
        local names={}
        for i,view in ipairs(result and result.views or {}) do names[i]=directionNames[view.key] or L["Comparison"] end
        direction:SetList(names);direction:SetValue(1);show(1)
    end
    copy:SetCallback("OnClick",function() return addon:ShowComparisonReport(report) end)
    direction:SetCallback("OnValueChanged",function(_,_,index) show(index) end)
    chooser:SetCallback("OnValueChanged",function(_,_,index) refresh(index) end)
    if #targets>0 then refresh(selected)
    else chooser:SetDisabled(true);direction:SetDisabled(true);copy:SetDisabled(true);label(graph,L["No other rotations to compare."]) end
    return frame
end
