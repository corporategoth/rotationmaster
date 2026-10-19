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
    if self.BuildFunctionBindingFields then self:BuildFunctionBindingFields(form,owner) end
    local graph,why=self:NewFieldSchemaDraft(owner.model.value.fields,owner.model.value.fieldOrder,owner.model.value.requiredFields)
    local fieldsGraph=graph or self:NewFieldSchemaDraft(owner.model.value.fields,nil,owner.model.value.requiredFields)
    local nodes=fieldsGraph and fieldsGraph.root.children or {};local short=form.frame:GetHeight()<480
    local height=owner.advancedSchema and (short and 56 or 80) or math.max(24,math.min(short and 1 or 3,#nodes)*20)
    local y=form:Row(L['Field schema'],height+8);local title=form.pool.labels[form.counts.labels];title:SetSize(168,24);form.fields.schemaLabel=title
    local width=math.max(80,form.width-278)
    local scroll=form:Acquire('sourceSchemaScroll',function() return addon:CreateWorkbenchScrollFrame(form.child) end);scroll:ClearAllPoints();scroll:SetPoint('TOPLEFT',174,-y);scroll:SetSize(width,height);owner.schemaViewport=scroll;form.fields.schemaViewport=scroll
    scroll.decoration=scroll.decoration or addon:CreateRoundedCardDecoration(scroll);scroll.decoration:SetColors(.38,.43,.48,.8,.95)
    local requirementError=graph and graph.requiredFieldsInvalid
    addon:SetWorkbenchInvalid(scroll,not graph or requirementError,string.format(L['Invalid field schema: %s'],why or requirementError and 'invalid-required-fields' or ''))
    local raw=addon:FormatCustomFieldSchema(owner.model.value.fields) or recoveryText(owner.model.value.fields)
    local schema=form:Edit('schema',nil,raw,function(text) return addon:ParseCustomFieldSchema(text) end,function(fields) owner.model:Change(function(model) model.value.fields=fields;model.value.fieldOrder=nil;model.value.requiredFields=addon:FilterCustomRequiredFields(model.value.requiredFields,fields) end) end)
    scroll.schemaContent=scroll.schemaContent or CreateFrame('Frame',nil,scroll);local content=scroll.schemaContent
    scroll.schemaMeasure=scroll.schemaMeasure or scroll:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');local measure=scroll.schemaMeasure;measure:SetWordWrap(true);measure:Hide()
    schema:SetMaxLetters(32768);schema:SetMultiLine(true);schema:ClearAllPoints();schema:SetParent(content);schema:SetTextInsets(6,6,4,4);schema:SetJustifyV('TOP');schema:SetAltArrowKeyMode(false);schema:SetAllPoints(content);schema:SetText(raw)
    local function layoutRaw()
        local innerWidth=math.max(1,width-18);measure:SetWidth(math.max(1,innerWidth-12));measure:SetText(schema:GetText())
        local contentHeight=math.max(height,measure:GetStringHeight()+12)
        if math.abs(content:GetWidth()-innerWidth)>.1 or math.abs(content:GetHeight()-contentHeight)>.1 then content:SetSize(innerWidth,contentHeight) end
        scroll:UpdateWorkbenchScroll()
    end
    layoutRaw();addon:SetUIScript(schema,'OnEnterPressed',function() end)
    schema:EnableMouseWheel(true);addon:SetUIScript(schema,'OnMouseWheel',function(_,delta) local bar=scroll.workbenchBar;bar:SetValue(bar:GetValue()-delta*40) end)
    addon:SetUIScript(schema,'OnCursorChanged',function(_,_,cursorY,_,lineHeight)
        if not owner.advancedSchema then return end;local bar=scroll.workbenchBar;local top=-cursorY
        if top<bar:GetValue() then bar:SetValue(top) elseif top+lineHeight>bar:GetValue()+scroll:GetHeight() then bar:SetValue(top+lineHeight-scroll:GetHeight()) end
    end)
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
    if owner.advancedSchema then preview:Hide();content:Show();schema:Show();scroll:SetScrollChild(content) else content:Hide();schema:Hide();preview:Show();scroll:SetScrollChild(preview) end
    local changed=schema:GetScript('OnTextChanged');addon:SetUIScript(schema,'OnTextChanged',function(...) if changed then changed(...) end;layoutRaw() end)
    local savedY=form.y;form.y=y
    local advanced=form:Check('advancedSchema',L['Advanced'],owner.advancedSchema==true,function(value) owner.advancedSchema=value;form:Draw();owner:UpdateActions() end)
    advanced:ClearAllPoints();advanced:SetPoint('TOPLEFT',form.width-96,-y);advanced:SetWidth(96);advanced:GetFontString():SetWidth(74);form.y=savedY-30
    scroll:UpdateWorkbenchScroll()
end
