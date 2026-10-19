local addon_name, addon = ...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)

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
        section(L["Changes in the Built In rotation since cloning"],result.sourceChanges)
        section(L["Your changes since cloning"],result.customChanges)
        section(L["Differences from the current Built In rotation"],result.currentDifferences)
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
    local widget=addon:CreateConditionLabel();if kind=='Heading' then widget:SetFontObject('GameFontNormal');widget:SetColor(1,.82,.25) end;widget:SetFullWidth(true);widget:SetText(text);parent:AddChild(widget)
    return widget
end
local directionNames={current=L["Selected rotation → your rotation"],source=L["Built In updates since cloning"],custom=L["Your edits since cloning"]}
local function renderComparison(self,parent,view,spec,showUnchanged)
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
        local toggle=addon:CreateConditionCheckBox();toggle:SetFullWidth(true)
        toggle:SetLabel(L["Show unchanged steps"]);toggle:SetValue(showUnchanged==true)
        toggle:SetCallback("OnValueChanged",function(_,_,value) addon:RenderRotationComparison(parent,view,spec,value==true) end)
        parent:AddChild(toggle)
        if not showUnchanged then label(parent,string.format(L["%s unchanged steps hidden."],unchanged)) end
    end
    local leftTitle=view.key=="source" and L["At cloning"] or view.key=="custom" and L["At cloning"] or L["Selected rotation"]
    local rightTitle=view.key=="source" and L["Current Built In rotation"] or view.key=="import" and L["Incoming rotation"] or L["Your rotation"]
    if view.key=="import" then leftTitle=L["Your rotation"] end
    local function pair(left,right,render)
        local row=addon:CreateConditionGroup();row:SetFullWidth(true);row:SetLayout('Table');row:SetUserData('table',{columns={1,1}});parent:AddChild(row)
        for _,side in ipairs({"left","right"}) do
            local column=addon:CreateConditionGroup();column:SetFullWidth(true);column:SetLayout('List');row:AddChild(column)
            label(column,side=="left" and leftTitle or rightTitle,"Heading")
            local entry
            if side=="left" then entry=left else entry=right end
            if entry then render(column,entry) else label(column,L["No corresponding step"])
            end
        end
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
function addon:RenderRotationComparison(parent,view,spec,showUnchanged)
    local paused=type(parent.PauseLayout)=='function' and type(parent.ResumeLayout)=='function'
    if paused then parent:PauseLayout() end
    local ok,why=pcall(renderComparison,self,parent,view,spec,showUnchanged)
    if paused then parent:ResumeLayout() end
    if not ok then error(why,0) end
end

function addon:ShowComparisonReport(report)
    local d=self.rotationComparisonReport
    if not d then d=self:CreateWorkbenchTextReport(820,500);self.rotationComparisonReport=d end
    d:SetReport(L['Comparison diagnostic details'],report);return d
end
function addon:ShowRotationComparison(spec,id)
    local reference,reason=self:ResolveRotationReference(spec,id);if not reference then return nil,reason end
    local record,recordToken=self:GetRotationRecordSnapshot(spec,reference);if not record then return nil,recordToken end
    local coordinator=self:GetScopedRotationCoordinator();local context=self:GetRotationOwnerContext();local targetToken
    local d=self.rotationComparisonWindow
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent),children={}};self.rotationComparisonWindow=d
        d.frame:SetSize(1080,700);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:SetToplevel(true);d.frame:SetClampedToScreen(true);d.frame:EnableMouse(true);self:MakeWindowOpaque(d.frame)
        d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(d.frame,d.title)
        d.summary=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.summary:SetPoint('TOPLEFT',12,-38);d.summary:SetSize(1030,20);d.summary:SetJustifyH('LEFT');d.summary:SetWordWrap(false);d.summary:SetMaxLines(1)
        d.close=self:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
        d.scroll=self:CreateWorkbenchGroupViewport(d.frame);d.scroll:SetPoint('TOPLEFT',12,-154);d.scroll:SetSize(1030,518)
        function d:Hide() self.frame:Hide() end
        function d:Clear()
            self.active=false;self.scroll:ReleaseConditionContent()
            for _,widget in ipairs(self.children) do if widget~=self.graph then addon:ReleaseConditionWidget(widget) end end
            self.children={};self.graph=nil
        end
        addon:SetUIScript(d.close,'OnClick',function() d:Hide() end);addon:SetUIScript(d.frame,'OnHide',function() d:Clear() end);d.frame:Hide()
    end
    d:Clear();d.serial=(d.serial or 0)+1;local serial=d.serial;local profile=self.db.profile
    local function valid()
        if not d.active or d.serial~=serial or not d.frame:IsShown() or addon.db.profile~=profile or addon:GetScopedRotationCoordinator()~=coordinator or not coordinator or not coordinator:CheckReady() then return false end
        local now=addon:GetRotationOwnerContext()
        return now and context and now.class==context.class and now.character==context.character and (not recordToken or coordinator:TokenCurrent(recordToken)) and (not targetToken or coordinator:TokenCurrent(targetToken))
    end
    local function control(widget,x,y,width)
        widget.frame:SetParent(d.frame);widget.frame:ClearAllPoints();widget.frame:SetPoint('TOPLEFT',d.frame,'TOPLEFT',x,y);widget:SetWidth(width);widget.frame:Show();d.children[#d.children+1]=widget;return widget
    end
    d.active=true
    local own=record.body;d.chrome:SetContext(L['Compare rotations'],L['Read-only'],own and own.name or DEFAULT)
    d.summary:SetText(string.format(L['Your rotation: %s'],own and own.name or DEFAULT))
    local targets,labels={},{};local selected;local sourced=self:GetSourcedRotationView(spec,reference)
    local rows,headerReason=self:ListRotationHeaders(spec);if not rows then d:Clear();return nil,headerReason end
    table.sort(rows,function(a,b) if a.name==b.name then return a.key<b.key end;return a.name<b.name end)
    for _,row in ipairs(rows) do
        if not row.pending and not self:SettingsDataEqual(row.reference,reference) then
            targets[#targets+1]=row.reference;labels[#targets]=row.kind=='builtin' and '|cff5bc0eb'..row.name..'|r ('..L['Built In · read-only']..')' or row.name
            if row.scope then labels[#targets]=labels[#targets]..' · '..(row.scope=='character' and L['This character'] or L['Class']) end
            if row.kind=='builtin' and sourced and sourced.lineage.sourceId==row.canonicalId and sourced.lineage.sourceKind=='builtin' then selected=#targets end
        end
    end
    local chooser=control(self:CreateConditionDropdown(),12,-68,510);d.chooser=chooser;chooser:SetLabel(L['Compare against'])
    local order={};for i=1,#labels do order[i]=i end;chooser:SetList(labels,order);selected=selected or 1;chooser:SetValue(selected)
    local direction=control(self:CreateConditionDropdown(),536,-68,510);d.direction=direction;direction:SetLabel(L['Comparison view'])
    local copy=control(self:CreateConditionButton(),12,-120,200);d.copy=copy;copy:SetText(L['Copy diagnostic details'])
    local graph=self:CreateConditionGroup();graph:SetLayout('List');d.graph=graph;d.children[#d.children+1]=graph;d.scroll:SetConditionContent(graph)
    local result,report
    local function show(index)
        if not valid() then return end
        local view=result and result.views and result.views[index]
        if view then addon:RenderRotationComparison(graph,view,spec) else graph:ReleaseChildren();label(graph,L['This comparison could not be completed.']) end
        d.scroll:UpdateWorkbenchScroll()
    end
    local function refresh(index)
        if not valid() then return end
        local target=targets[index];if not target then return end
        local snapshot,token=addon:GetRotationRecordSnapshot(spec,target);if not snapshot then d:Hide();return end
        targetToken=token
        local why;result,why=addon:BuildRotationComparison(spec,reference,target)
        if not valid() then d:Hide();return end
        report=result and addon:FormatRotationComparison(result) or string.format(L['Comparison unavailable: %s'],why)
        local names,viewOrder={},{};for i,view in ipairs(result and result.views or {}) do names[i]=directionNames[view.key] or L['Comparison'];viewOrder[i]=i end
        direction:SetList(names,viewOrder);direction:SetValue(1);direction:SetDisabled(#names==0);show(1)
    end
    copy:SetCallback('OnClick',function() if valid() then return addon:ShowComparisonReport(report) end end)
    direction:SetCallback('OnValueChanged',function(_,_,index) show(index) end);chooser:SetCallback('OnValueChanged',function(_,_,index) refresh(index) end)
    d.frame:Show();self:RegisterWindowForEscape(d)
    if #targets>0 then refresh(selected) else chooser:SetDisabled(true);direction:SetDisabled(true);copy:SetDisabled(true);label(graph,L['No other rotations to compare.']) end
    addon:SetUIScript(d.frame,'OnUpdate',function() if d.active and d.serial==serial and not valid() then d:Hide() end end)
    return d
end
