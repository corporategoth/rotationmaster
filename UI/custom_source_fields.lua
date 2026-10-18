local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={string=L['Text'],number=L['Number'],boolean=L['Boolean'],condition=L['Condition'],['condition[]']=L['Condition list'],record=L['Record / map'],union=L['Allowed types / list alternatives']}
local function recoveryText(value)
    local active,nodes={},0
    local function render(v,depth)
        nodes=nodes+1;if nodes>512 or depth>16 then return '"<limit>"' end
        if type(v)=='string' then return types[v] and v or string.format('%q',v) end
        if type(v)~='table' then return (type(v)=='number' or type(v)=='boolean') and tostring(v) or 'nil' end
        if active[v] then return '"<cycle>"' end;active[v]=true
        local fields={};for key,child in pairs(v) do fields[#fields+1]='['..(type(key)=='number' and tostring(key) or string.format('%q',tostring(key)))..']='..render(child,depth+1) end
        active[v]=nil;table.sort(fields);return '{'..table.concat(fields,', ')..'}'
    end
    return render(value,0):sub(1,32768)
end

-- Source metadata shows its schema directly. The same schema draft/editor
-- handles every entry; Advanced changes its presentation, never its format.
function addon:BuildCustomSourceFields(form,owner)
    local graph,why=self:NewFieldSchemaDraft(owner.model.value.fields,owner.model.value.fieldOrder)
    local fieldsGraph=graph or self:NewFieldSchemaDraft(owner.model.value.fields)
    local nodes=fieldsGraph and fieldsGraph.root.children or {};local short=form.frame:GetHeight()<480
    local height=owner.advancedSchema and (short and 40 or 64) or math.max(20,math.min(short and 1 or 3,#nodes)*20)
    local y=form:Row(L['Field schema'],height+8);form.pool.labels[form.counts.labels]:SetWidth(168)
    local width=math.max(80,form.width-278)
    local scroll=form:Acquire('sourceSchemaScroll',function() return addon:CreateWorkbenchScrollFrame(form.child) end);scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',174,-y);scroll:SetSize(width,height);owner.schemaViewport=scroll
    addon:SetWorkbenchInvalid(scroll,not graph,why and string.format(L['Invalid field schema: %s'],why))
    local raw=addon:FormatCustomFieldSchema(owner.model.value.fields) or recoveryText(owner.model.value.fields)
    local schema=form:Edit('schema',nil,raw,function(text) return addon:ParseCustomFieldSchema(text) end,function(fields) owner.model:Change(function(model) model.value.fields=fields;model.value.fieldOrder=nil end) end)
    schema:SetMaxLetters(32768);schema:SetText(raw);schema:SetMultiLine(true);schema:ClearAllPoints();schema:SetPoint('TOPLEFT',0,0);schema:SetWidth(width-18);schema:SetParent(scroll)
    owner.schemaRows=owner.schemaRows or {};scroll.preview=scroll.preview or CreateFrame('Frame',nil,scroll);local preview=scroll.preview;preview:SetWidth(width-18);preview:SetHeight(math.max(20,#nodes*20))
    for index=1,math.max(1,#nodes) do
        local node=nodes[index];local row=owner.schemaRows[index]
        if not row then row=addon:CreateWorkbenchButton(preview,'',100);row.kindLabel=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');row.kindLabel:SetJustifyH('LEFT');owner.schemaRows[index]=row end
        row:SetParent(preview);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(index-1)*20);row:SetSize(preview:GetWidth(),20);row:SetText(node and node.name or why and L['Invalid custom condition.'] or L['Edit fields']);row.art:Hide();addon:AlignWorkbenchTextLeft(row,2)
        row.kindLabel:ClearAllPoints();row.kindLabel:SetPoint('LEFT',row,'LEFT',math.floor(row:GetWidth()*.5),0);row.kindLabel:SetWidth(row:GetWidth()*.5);row.kindLabel:SetText(node and types[node.kind] or '');row.kindLabel:SetTextColor(.4,.8,1)
        row:GetFontString():SetWidth(row:GetWidth()*.5-4);row.tooltip=L['Edit fields']
        addon:SetUIScript(row,'OnClick',form:Guard(function()
            if not owner:Flush() then return end
            if fieldsGraph then
                local child=owner:OpenSchema(owner.model.value.fields,graph and owner.model.value.fieldOrder or nil)
                if child and not graph then child.requiresApply=true;child:UpdateActions() end
            else owner.advancedSchema=true;form:Draw();owner:UpdateActions() end
        end))
        if owner.advancedSchema then row:Hide() else row:Show() end
    end
    for i=math.max(1,#nodes)+1,#owner.schemaRows do owner.schemaRows[i]:Hide() end
    form.fields.schemaGraph=owner.schemaRows[1]
    if owner.advancedSchema then preview:Hide();schema:Show();scroll:SetScrollChild(schema) else schema:Hide();preview:Show();scroll:SetScrollChild(preview) end
    local changed=schema:GetScript('OnTextChanged');addon:SetUIScript(schema,'OnTextChanged',function(...) if changed then changed(...) end;scroll:UpdateWorkbenchScroll() end)
    local savedY=form.y;form.y=y
    local advanced=form:Check('advancedSchema',L['Advanced'],owner.advancedSchema==true,function(value) owner.advancedSchema=value;form:Draw();owner:UpdateActions() end)
    advanced:ClearAllPoints();advanced:SetPoint('TOPLEFT',form.width-96,-y);advanced:SetWidth(96);advanced:GetFontString():SetWidth(74);form.y=savedY-30
    scroll:UpdateWorkbenchScroll()
end
