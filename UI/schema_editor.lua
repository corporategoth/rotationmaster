local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='string',text=L['Text']},{value='number',text=L['Number']},{value='boolean',text=L['Boolean']},{value='condition',text=L['Condition']},{value='condition[]',text=L['Condition list']},{value='record',text=L['Record / map']},{value='union',text=L['Allowed types / list alternatives']}}
function addon:ShowFieldSchemaEditor(owner,fields,fieldOrder,changed,ownerValid,resume)
    local d=owner.schemaEditor
    if d and d.active then d.frame:Show();return d end
    d=d or {frame=CreateFrame('Frame',nil,UIParent),path={}};owner.schemaEditor=d;d.active=true;d.path={};d.serial=(d.serial or 0)+1;local serial=d.serial
    local frame=d.frame;frame:SetSize(760,540);frame:ClearAllPoints();frame:SetPoint('CENTER');frame:EnableMouse(true);frame:SetToplevel(true);frame:SetClampedToScreen(true);addon:MakeWindowOpaque(frame)
    d.title=d.title or frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=d.chrome or addon:CreateWorkbenchDialogChrome(frame,d.title);d.chrome:SetContext(L['Field schema'],L['Fields'],owner.model.key)
    d.close=d.close or addon:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
    d.host=d.host or CreateFrame('Frame',nil,frame);d.host:SetPoint('TOPLEFT',8,-38);d.host:SetSize(744,438)
    d.form=d.form or addon:CreateSettingsForm(d.host);local p=d.form
    local model,why=addon:NewFieldSchemaDraft(fields,fieldOrder)
    if not model then d.active=false;frame:Hide();owner.form:Message(string.format(L['Invalid field schema: %s'],why));return nil end
    d.model=resume and resume.model or model;d.path=resume and resume.path or {};local baseline=resume and resume.baseline or addon:CopySettingsData(d.model.root)
    function d:CaptureDraft()
        local raw={};for _,record in ipairs(p.edits) do if record.dirty then for key,control in pairs(p.fields) do if control==record.control then raw[key]=control:GetText();break end end end end
        return {model=self.model,path=addon:CopySettingsData(self.path),baseline=addon:CopySettingsData(baseline),raw=raw}
    end
    local function valid() return d.active and d.serial==serial and ownerValid() end
    function d:Close()
        if not self.active then return end;self.active=false;p:Release();frame:Hide();self.model=nil
        if ownerValid() then owner:Show() end
    end
    function d:IsDirty()
        local dirty=not addon:SettingsDataEqual(d.model.root,baseline);for _,record in ipairs(p.edits) do dirty=dirty or record.dirty end
        return dirty
    end
    function d:Hide()
        local dirty=self:IsDirty()
        if not valid() or not dirty then self:Close();return end
        p:ConfirmPending(function() self:Apply() end,function() self:Close() end)
    end
    function d:UpdateActions()
        local dirty=self:IsDirty()
        if dirty then d.apply:Enable() else d.apply:Disable() end
        if #d.model.undo>0 then d.undo:Enable() else d.undo:Disable() end
        if #d.model.redo>0 then d.redo:Enable() else d.redo:Disable() end
    end
    function d:Apply()
        if not valid() or not p:FlushEdits() then return false end
        local value,order=d.model:Snapshot();if not value then p:Message(string.format(L['Invalid field schema: %s'],order));return false end
        changed(value,order);d:Close();return true
    end
    for i,entry in ipairs({{'undo','undo',L['Undo']},{'redo','redo',L['Redo']},{'apply',nil,L['Apply']},{'cancel',nil,L['Cancel']}}) do
        d[entry[1]]=d[entry[1]] or (entry[2] and addon:CreateWorkbenchHistoryButton(frame,entry[2],entry[3]) or addon:CreateWorkbenchButton(frame,entry[3],90))
        local b=d[entry[1]];b:ClearAllPoints();if i<3 then b:SetPoint('BOTTOMLEFT',12+(i-1)*74,28) else b:SetPoint('BOTTOMRIGHT',-12-(4-i)*98,28) end
        addon:SetUIScript(b,'OnClick',function()
            if not valid() then return end
            if i==4 then d:Close() elseif i==3 then d:Apply() elseif p:FlushEdits() and d.model:Travel(i==2) then p:Draw() end
        end)
    end
    addon:SetUIScript(d.close,'OnClick',function() if valid() then d:Hide() end end)
    p:SetWidth(d.host:GetWidth());p:SetHeight(d.host:GetHeight())
    p:Open(function(form)
        local node=d.model:Node(d.path)
        while #d.path>0 and (not node or not node.children) do table.remove(d.path);node=d.model:Node(d.path) end
        if not node or not node.children then d.path={};node=d.model.root end
        if #d.path>0 then form:Button('back',L['Back'],function() table.remove(d.path);form:Draw() end) end
        local parts={L['Fields']};local parent=d.model.root
        for _,index in ipairs(d.path) do parent=parent.children[index];parts[#parts+1]=tostring(parent.name or index) end
        form:Heading(table.concat(parts,' / '))
        form:Text(node.kind=='record' and L['Named fields. Choose a type, then edit its children for nested data.'] or L['Allowed types. A nested record or type list describes each item in a list.'])
        for index,child in ipairs(node.children or {}) do
            if index>200 then form:Text(L['Showing the first 200 fields. Use Advanced schema for larger definitions.']);break end
            local y=form:Row(nil,48)
            local up=form:Acquire('fieldMoves',function() return addon:CreateWorkbenchIconButton(form.child,'up',L['Move Up']) end);up:ClearAllPoints();up:SetPoint('TOPLEFT',0,-y);up.icon:SetTexture(addon:ControlTexture('up'));up.tooltip=L['Move Up'];if index>1 then up:Enable() else up:Disable() end
            local down=form:Acquire('fieldMoves',function() return addon:CreateWorkbenchIconButton(form.child,'down',L['Move Down']) end);down:ClearAllPoints();down:SetPoint('TOPLEFT',0,-y-20);down.icon:SetTexture(addon:ControlTexture('down'));down.tooltip=L['Move Down'];if index<#node.children then down:Enable() else down:Disable() end
            local function move(delta) d.model:Change(function() local value=table.remove(node.children,index);table.insert(node.children,index+delta,value) end);form:Draw() end
            addon:SetUIScript(up,'OnClick',form:Guard(function() if form:FlushEdits() then move(-1) end end));addon:SetUIScript(down,'OnClick',form:Guard(function() if form:FlushEdits() then move(1) end end))
            local name=form:Edit('field_'..index,nil,node.kind=='record' and child.name or tostring(index),function(text) if node.kind~='record' or text:match('^[%a_][%w_]*$') then return text end end,function(text) d.model:Change(function() child.name=text end);d:UpdateActions() end)
            name:ClearAllPoints();name:SetPoint('TOPLEFT',28,-y-8);name:SetWidth(196);form.y=form.y-28;if node.kind~='record' then name:EnableMouse(false) end
            local kind=form:Choice('type_'..index,nil,child.kind,types,function(value)
                d.model:Change(function() child.kind=value;if value=='record' or value=='union' then child.children=child.children or {{name='field',kind='string'}};if value=='record' then
                    local used={};for i,field in ipairs(child.children) do local name=type(field.name)=='string' and field.name:match('^[%a_][%w_]*$') and field.name or 'field'..i;while used[name] do name=name..'_' end;field.name=name;used[name]=true end
                end else child.children=nil end end);form:Draw()
            end);kind:ClearAllPoints();kind:SetPoint('TOPLEFT',232,-y-8);kind:SetWidth(260);form.y=form.y-28
            if child.children then local edit=form:Button('children_'..index,L['Edit fields'],function() d.path[#d.path+1]=index;form:Draw() end);edit:ClearAllPoints();edit:SetPoint('TOPLEFT',500,-y-8);edit:SetWidth(112);form.y=form.y-28 end
            local trash=form:Acquire('fieldDelete',function() return addon:CreateWorkbenchIconButton(form.child,'trash',L['Delete']) end);trash:ClearAllPoints();trash:SetPoint('TOPRIGHT',0,-y-8)
            addon:SetUIScript(trash,'OnClick',form:Guard(function() if form:FlushEdits() then d.model:Change(function() table.remove(node.children,index) end);form:Draw() end end))
        end
        form:Button('add',L['Add field'],function()
            local used={};for _,child in ipairs(node.children) do used[child.name]=true end;local name='field';local n=1;while used[name] do n=n+1;name='field'..n end
            d.model:Change(function() node.children[#node.children+1]={name=name,kind='string'} end);form:Draw()
        end)
        if resume then
            for _,record in ipairs(form.edits) do for key,text in pairs(resume.raw) do if form.fields[key]==record.control then record.control:SetText(text);record.dirty=true end end end
            resume=nil
        end
        d:UpdateActions()
    end)
    addon:SetUIScript(frame,'OnUpdate',function() if not valid() then d:Close() else d:UpdateActions() end end)
    owner:HideForChild();frame:Show();addon:RegisterWindowForEscape(d);return d
end
