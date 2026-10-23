local addon_name,addon=...
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData
local function text(parent,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');label:SetJustifyH('LEFT');label:SetWordWrap(false);return label
end
function addon:CreateRotationEditor(parent,spec,id,onSelect)
    if parent.rmRotationEditor then return parent.rmRotationEditor:Open(spec,id,onSelect) end
    local workspace,why=self:GetRotationEditWorkspace(spec,id);if not workspace then return nil,why end
    local pane={frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,parent)),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}
    pane.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',0,0)
    pane.name=self:CreateWorkbenchEditBox(pane.frame);pane.name:SetPoint('TOPLEFT',8,-4);pane.name:SetSize(320,24);pane.name:SetMaxLetters(256)
    pane.origin=text(pane.frame);pane.origin:SetText('');pane.origin:Hide()
    pane.nameLabel=text(pane.frame);pane.nameLabel:SetText(L['Name']);pane.nameLabel:SetPoint('TOPLEFT',8,-10)
    pane.descriptionLabel=text(pane.frame);pane.descriptionLabel:SetText(L['Description']);pane.descriptionLabel:SetPoint('TOPLEFT',8,-38)
    pane.description=CreateFrame('EditBox',nil,pane.frame);pane.description:SetFontObject('GameFontHighlightSmall');pane.description:SetAutoFocus(false);pane.description:SetMultiLine(true);pane.description:SetMaxLetters(4096);pane.description:SetPoint('TOPLEFT',86,-30);pane.description:SetSize(300,36)
    pane.info=addon:CreateWorkbenchLabeledIconButton(pane.frame,'info',L['Metadata'],92)
    pane.validationButton=addon:CreateWorkbenchLabeledIconButton(pane.frame,'warning',L['This rotation cannot run until its incomplete or unavailable data is resolved.'],400)
    pane.validationButton:GetFontString():SetTextColor(1,.35,.3);pane.validationButton:Hide()
    pane.status=text(pane.frame);pane.status:SetPoint('BOTTOMLEFT',8,12)
    function pane:Message(message) self.status:SetText(message or '') end
    function pane:UpdateHistory()
        local state=self.workspace.session:HistoryState()
        local pending=not self.workspace.readOnly and (self.nameDirty or self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty or self.scopeDirty or self:HasPendingFields())
        if state.canUndo or pending then self.undo:Enable() else self.undo:Disable() end
        if state.canRedo and not pending then self.redo:Enable() else self.redo:Disable() end
        if not self.workspace.readOnly and (self.workspace.pending or self:HasUnsavedChanges()) then self.apply:Enable() else self.apply:Disable() end
    end
    function pane:BuildScene()
        local snapshot=self.workspace:Snapshot()
        for stepId,state in pairs(self.view.cardStates or {}) do self.view.expanded[stepId]=state=='expanded' end
        for stepId,expanded in pairs(self.view.expanded) do if not expanded then self.view.detailsHeights[stepId]=nil else self.view.detailsHeights[stepId]=self.view.detailsHeights[stepId] or 180 end end
        self.view.viewportWidth=self.canvas and self.canvas.frame:GetWidth() or 720
        local scene,problem=addon:BuildRotationCanvas(snapshot,self.view)
        if not scene then self:Message(problem.code);return end
        addon:FitRotationSceneWidth(scene,self.view.viewportWidth)
        local validation=data.ValidateBody(snapshot,addon:GetImportValidationOptions());self.validation=validation
        self:CollectSectionProblems(snapshot,validation)
        for _,model in ipairs(scene.cards) do
            local path='$.body'
            for _,part in ipairs(model.path) do path=path..(type(part)=='number' and '['..part..']' or '.'..part) end
            for _,diagnostic in ipairs(validation.diagnostics) do
                if diagnostic.path==path or diagnostic.path:sub(1,#path+1)==path..'.' or diagnostic.path:sub(1,#path+1)==path..'[' then
                    model.invalid=true;model.problem=diagnostic.code;break
                end
            end
            model.pendingProblem=self:PendingFieldProblem(model.id)
            if model.pendingProblem then model.invalid=true end
            model.displayName=self:FieldText(model.id,'name',model.step.name or '')
            model.expanded=not model.compact and self.view.expanded[model.id]==true
        end
        return scene
    end
    -- The first issue under each section header, from the validation this
    -- scene already ran (and any invalid staged input): the Rotation and
    -- Cooldowns tabs are marked even when the other section is in view.
    function pane:CollectSectionProblems(snapshot,validation)
        local problems={}
        for _,diagnostic in ipairs(validation.diagnostics) do
            local section=type(diagnostic.path)=='string' and diagnostic.path:match('^%$%.body%.(%a+)%[')
            if section~='rotation' and section~='cooldowns' then section='record' end
            if not problems[section] then problems[section]=addon.DescribeRotationIssue and addon:DescribeRotationIssue(diagnostic,snapshot) or tostring(diagnostic.code) end
        end
        if next(self.view.pendingFields or {}) then
            local tree=data.IndexRotationSteps(snapshot)
            for stepId in pairs(self.view.pendingFields) do
                local row=tree and tree.byId[stepId];local label=row and self:PendingFieldProblem(stepId)
                if label and not problems[row.section] then problems[row.section]=string.format(L['Incomplete input: %s'],label) end
            end
        end
        self.sectionProblems=problems
    end
    function pane:RefreshSectionMarkers()
        local problems=self.sectionProblems or {}
        for section,button in pairs(self.contentTabs or {}) do
            addon:SetWorkbenchProblem(button,problems[section] and string.format(L['This rotation cannot be selected. %s.'],problems[section]) or nil)
        end
        local first=problems.record or problems.rotation or problems.cooldowns
        self.validationButton:SetText(first and string.format(L['This rotation cannot be selected. %s.'],first) or L['This rotation cannot run until its incomplete or unavailable data is resolved.'])
    end
    function pane:RefreshValidation()
        if not self.active then return end
        local scene=self:BuildScene();if not scene then return end
        local byId={};for _,model in ipairs(scene.cards) do byId[model.id]=model end
        for _,card in ipairs(self.canvas.cards) do
            local model=card.model and byId[card.model.id]
            if model and card.frame:IsShown() then card:SetValidation(model.invalid);card.model.pendingProblem=model.pendingProblem;if card.RefreshHighlightPreview then card.RefreshHighlightPreview() end end
        end
        self:LayoutGeometry();self.canvas.frame:UpdateWorkbenchScroll()
    end
    function pane:Command(name,...)
        if not self.active then return nil,'rotation-pane-released' end
        local ok,result=self.workspace:Command(name,...)
        if not ok then self:Message(result);return nil,result end
        self:Message('');self:Render();return ok,result
    end
    function pane:Render()
        if not self.active then return end
        self.viewMode:SetText(self.view.layout=='list' and L['List view'] or L['Diagram view'])
        local snapshot=self.workspace:Snapshot()
        if self.metadataWindow and self.metadataWindow.frame:IsShown() and not self.metadataDirty then self.metadataWindow:Sync() end
        if not self.descriptionDirty then self.description:SetText(type(snapshot.description)=='string' and snapshot.description or (self.workspace.readOnly and type(self.workspace.description)=='string' and self.workspace.description or '')) end
        if not self.nameDirty and self.name:GetText()~=(snapshot.name or (workspace.fallback and DEFAULT or '')) then self.name:SetText(addon:PlainWorkbenchName(type(snapshot.name)=='string' and snapshot.name or (workspace.fallback and DEFAULT or ''))) end
        self.origin:SetText('')
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(snapshot.switch or {},spec)))
        if workspace.fallback then self.switch:Disable() else self.switch:Enable() end
        self:BuildScene();self:LayoutGeometry();self.canvas:Render()
        for _,control in ipairs({self.compare,self.clone}) do if self.workspace.pending then control:Disable() else control:Enable() end end
        self.clone:SetText(self.workspace.readOnly and L['Clone to edit'] or L['Duplicate'])
        if self.workspace.readOnly or workspace.fallback or self.workspace.pending then self.delete:Disable() else self.delete:Enable() end
        self.enable:SetSelected(self.workspace.readOnly and self.workspace.source.enabled or not self.workspace.readOnly and not snapshot.disabled)
        self.enable:SetText(self.workspace.readOnly and (self.workspace.source.enabled and L['Enabled'] or L['Disabled']) or snapshot.disabled and L['Disabled'] or L['Enabled'])
    end
    function pane:RotationDisplayName() return addon:PlainWorkbenchName(self.nameDirty and self.name:GetText() or self.workspace:Snapshot().name or self.workspace.title) end
    function pane:EditCondition(target)
        if not self.active then return end
        local editorTarget,reason=self.workspace:ConditionEditorTarget(target);if not editorTarget then self:Message(reason);return end
        local title,contextLabel
        if type(target)=='table' and target.kind=='switch' then title=L['Switch condition'];contextLabel=L['Switch condition'] else
            local row=data.IndexRotationSteps(self.workspace:Snapshot()).byId[target]
            if row then
                contextLabel=row.section=='cooldowns' and L['Cooldown'] or L['Rotation']
                local step=row.step;local name=self:FieldText(target,'name',step.name or '')
                if name:find('%S') then title=name
                elseif step.type=='spell' or step.type=='pet' or step.type=='any' then title=addon:SpellLabel(step.action)
                elseif step.type=='none' then title=L['Stop']
                elseif step.type=='assisted' then title=L["Blizzard's suggestion"]
                elseif step.type=='item' then title=L['Item']
                else title=L['Edit Condition'] end
                title=addon:PlainWorkbenchName(title)
            end
        end
        local saved=self.workspace.session:Baseline();local savedCondition
        if type(target)=='table' and target.kind=='switch' then savedCondition=saved.switch or {} else local tree=data.IndexRotationSteps(saved,{allowMissingIds=true});savedCondition=tree and tree.byId[target] and tree.byId[target].step.conditions or {} end
        addon:ShowConditionEditor(1,spec,editorTarget.condition,function(applied)
            if not applied then return end
            local ok,problem=editorTarget.commit(editorTarget.condition)
            if self.active then if ok then self:Render() else self:Message(problem) end end
        end,editorTarget.valid,{readOnly=editorTarget.readOnly,persistentOwner=true,savedValue=savedCondition,title=title,contextLabel=contextLabel,rotationName=self:RotationDisplayName()})
    end
    function pane:ShowCardHelp(model)
        local kind=model.step.type=='branch' and 'branch' or model.section=='cooldowns' and 'cooldown' or 'rotation'
        local heading=model.displayName and model.displayName~='' and model.displayName or model.step.type=='branch' and L['Branch'] or model.section=='cooldowns' and L['Cooldown'] or L['Rotation']
        if addon.ShowWorkbenchHelp then addon:ShowWorkbenchHelp(heading,addon:WorkbenchInteractionHelp(kind),self:RotationDisplayName()) end
    end
    function pane:BuildFields(card,model,alive)
        if addon.BuildRotationCardFields then addon:BuildRotationCardFields(self,card,model,alive) end
    end
    addon:InstallRotationFieldDrafts(pane)
    local function tool(label,width,callback,icon)
        local control=icon and addon:CreateWorkbenchLabeledIconButton(pane.frame,icon,label,width==24 and 68 or width) or addon:CreateWorkbenchButton(pane.frame,label,width)
        control.action=callback;pane.tools[#pane.tools+1]=control;return control
    end
    pane.undo=tool(L['Undo'],24,function() if not pane:FlushName() then return end;local flushed,reason=pane:FlushFieldEdits();if not flushed then pane:Message(reason);return end;local ok,problem=workspace.session:Undo();if ok then pane:Render() else pane:Message(problem) end end,'undo')
    pane.redo=tool(L['Redo'],24,function() local ok,problem=workspace.session:Redo();if ok then pane:Render() else pane:Message(problem) end end,'redo')
    pane.switchButton=addon:CreateWorkbenchButton(pane.frame,'',300);pane.switch=pane.switchButton
    pane.switchText=pane.switchButton:GetFontString();pane.switchText:ClearAllPoints();pane.switchText:SetPoint('TOPLEFT',6,-4);pane.switchText:SetWordWrap(true);pane.switchText:SetJustifyH('LEFT')
    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);addon:StyleWorkbenchHeader(pane.switchLabel:GetFontString());pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)
    pane.switch.tooltip=L['Click condition text on any card to view or edit its conditions.']
    pane.compare=tool(L['Compare rotations'],126,function()
        pane:RequestLeave(function() if addon.ShowRotationComparison then addon:ShowRotationComparison(spec,id) end end)
    end,'compare')
    table.remove(pane.tools);pane.compare:Hide()
    pane.clone=tool(workspace.readOnly and L['Clone to edit'] or L['Duplicate'],110,function()
        local function duplicate()
            local generated,problem,reference
            local name=string.format(L['Copy of %s'],workspace:Snapshot().name or workspace.title)
            if workspace.readOnly then generated,problem,reference=addon:CloneDefaultRotation(spec,workspace.builtin,name)
            else generated,problem,reference=addon:DuplicateCustomRotation(spec,id,name) end
            if generated and onSelect then onSelect(spec,reference or generated) else pane:Message(problem) end
        end
        if pane.RequestLeave then pane:RequestLeave(duplicate) else duplicate() end
    end,'copy')
    table.remove(pane.tools);pane.clone:Hide()
    pane.enable=tool(workspace.readOnly and L['Enable Built In'] or L['Enabled'],116,function()
        if workspace.readOnly then
            local current=workspace.source.enabled;local ok,problem=addon:SetDefaultRotationEnabled(workspace.builtin,not current)
            if ok then workspace.source.enabled=not current;pane:RefreshAdvice();if pane.active and pane.workspace==workspace then pane:Render() end else pane:Message(problem) end
        else pane:Command('SetBodyField','disabled',not workspace:Snapshot().disabled) end
    end)
    local oldEnable=pane.enable;oldEnable:Hide();table.remove(pane.tools)
    pane.enable=addon:CreateWorkbenchPill(pane.frame,L['Enabled'],70);pane.enable.action=oldEnable.action
    pane.delete=tool(L['Delete'],24,function() if pane.ConfirmDelete then pane:ConfirmDelete() end end)
    pane.delete:SetText('');pane.delete.art:Hide();pane.delete.icon=pane.delete:CreateTexture(nil,'ARTWORK');pane.delete.icon:SetAllPoints(pane.delete);pane.delete.icon:SetTexture(addon:ControlTexture('trash'));pane.delete.icon:SetVertexColor(1,.3,.3,1);pane.delete.tooltip=L['Delete rotation']
    table.remove(pane.tools)
    pane.canvas=self:CreateRotationCanvas(pane.frame,pane)
    addon:InstallRotationView(pane)
    pane.hint=text(pane.frame);pane.hint:SetPoint('BOTTOMLEFT',8,12);pane.hint:SetText(L['Click condition text on any card to view or edit its conditions.'])
    pane.apply=self:CreateWorkbenchButton(pane.frame,L['Apply'],86);pane.apply:SetPoint('BOTTOMRIGHT',-100,8)
    pane.discard=self:CreateWorkbenchButton(pane.frame,L['Discard'],86);pane.discard:SetPoint('BOTTOMRIGHT',-8,8)
    -- Bulk actions on the selected cards, left of Apply. Each is one command,
    -- so one Undo reverses it.
    local bar=CreateFrame('Frame',nil,pane.frame);pane.selectionBar=bar;bar:SetSize(196,22);bar:SetPoint('BOTTOMRIGHT',-194,8);bar:Hide()
    bar.label=text(bar);bar.label:SetPoint('LEFT',0,0);bar.label:SetWidth(84);bar.label:SetJustifyH('RIGHT')
    bar.buttons={}
    for i,entry in ipairs({{'duplicate','copy',L['Duplicate selected cards']},{'enable','check',L['Enable selected cards']},{'disable','minus',L['Disable selected cards']},{'remove','trash',L['Delete selected cards']},{'clear','close',L['Clear selection']}}) do
        local button=self:CreateWorkbenchIconButton(bar,entry[2],entry[3]);button:SetSize(20,20);button:SetPoint('LEFT',88+(i-1)*22,0);bar.buttons[entry[1]]=button
        if entry[1]=='remove' then button.icon:SetVertexColor(1,.3,.3,1) end
        addon:SetUIScript(button,'OnClick',function() if pane.active then pane:BulkCommand(entry[1]) end end)
    end
    function pane:SelectionChanged()
        local count=#self.canvas:SelectedIds(false);local width=self.frame:GetWidth()
        if count==0 or not self.active then bar:Hide() else
            bar.label:SetText(string.format(L['%d selected'],count));bar:Show()
            local editable=not self.workspace.readOnly
            for key,button in pairs(bar.buttons) do if key=='clear' or editable then button:Enable() else button:Disable() end end
        end
        local reserve=bar:IsShown() and 200 or 0
        self.status:SetWidth(math.max(1,width-330-reserve));self.hint:SetWidth(math.max(1,width-330-reserve))
    end
    function pane:BulkCommand(kind)
        if not self.active then return end
        if kind=='clear' then self.canvas:ClearSelection();return end
        if self.workspace.readOnly then return end
        local index=addon.RotationData.IndexRotationSteps(self.workspace:Snapshot());if not index then return end
        local operations={}
        if kind=='duplicate' or kind=='remove' then
            for _,id in ipairs(self.canvas:SelectedIds(true)) do operations[#operations+1]={kind=='duplicate' and 'Duplicate' or 'Remove',id} end
        else
            -- Branches keep their Evaluate / Always mode; only steps toggle.
            local disabled=kind=='disable'
            for _,id in ipairs(self.canvas:SelectedIds(false)) do
                local row=index.byId[id];if row and row.step.type~='branch' and (row.step.disabled==true)~=disabled then operations[#operations+1]={'UpdateStep',id,{disabled=disabled}} end
            end
        end
        if #operations==0 then return end
        local ok=self:Command('Batch',operations)
        if ok and kind=='remove' then self.canvas:ClearSelection() end
        return ok
    end
    function pane:RefreshAdvice(previous,previousId)
        local change=beginActive(addon)
        local function current() return activeCurrent(addon,change) end
        local function optional(name,...)
            local available=addon[name]
            if not current() then return false end
            if available then
                local method=addon[name]
                if not current() then return false end
                method(addon,...)
            end
            return current()
        end
        if previous and addon.currentSpec==spec and (addon.currentRotation==(previousId or id) or addon.currentRotation==id or workspace.effectiveFallback and addon.currentRotation==DEFAULT) then
            -- Removed/changed actions must be cleared using their old identities.
            for _,step in ipairs(previous.cooldowns or {}) do
                if not current() then return false end
                local available=addon.GetSpellIds and addon.GlowCooldown
                if not current() then return false end
                if available then
                    local get=addon.GetSpellIds
                    if not current() then return false end
                    local ids=get(addon,step)
                    if not current() then return false end
                    for _,spell in ipairs(ids) do
                        if not current() then return false end
                        local glow=addon.GlowCooldown
                        if not current() then return false end
                        glow(addon,spell,false)
                        if not current() then return false end
                    end
                end
            end
            if not optional('GlowClear') then return false end
            addon.currentSpell=nil;addon.avail_announced={};addon.announced={};addon.skipAnnounce=true
        end
        if not current() or not optional('UpdateAutoSwitch') then return false end
        local available=addon.SwitchRotation
        if not current() then return false end
        if available then
            local switch=addon.SwitchRotation
            if not current() then return false end
            local _,nextChange=switch(addon);change=nextChange or change
        end
        if not current() or not optional('EvaluateNextAction') then return false end
        local saved=self.onSaved
        if not current() then return false end
        if saved then
            saved=self.onSaved
            if not current() then return false end
            saved()
        end
        return current()
    end
    function pane:AfterDelete() self.deleted=true;if onSelect then onSelect(spec,DEFAULT) else self:Release() end end
    function pane:Apply()
        if not self.active then return nil,'rotation-pane-released' end
        local fieldsOk,fieldsError=self:FlushFieldEdits();if not fieldsOk then self:Message(fieldsError);return nil,fieldsError end
        local flushed,flushError=self:FlushName();if not flushed then return nil,flushError end
        local previous=workspace.original and data.CopyData(workspace.original)
        local previousId=id;local profile=addon.db.profile;local ok,problem=workspace:Apply()
        if ok then
            if not self.active or self.workspace~=workspace or addon.db.profile~=profile then return ok,problem end
            if workspace.id~=id then
                self:Open(spec,workspace.id,onSelect)
            end
            self:Message('')
            -- Refreshing advice can be superseded by a rotation transition it
            -- starts (an automatic switch, a restored manual choice). The save
            -- itself succeeded, so the roster and this pane still show the
            -- applied state: Apply and View Changes grey out, marks clear.
            local advised=self:RefreshAdvice(previous,previousId)
            if not advised and self.active and self.workspace==workspace and self.onSaved then self.onSaved() end
            if self.active and self.workspace==workspace then self:Render() end
        else self:Message(problem) end
        return ok,problem
    end
    function pane:EffectiveTags(snapshot)
        snapshot=snapshot or self.workspace:Snapshot();local manifest=self.workspace.source and self.workspace.source.envelope
        if not manifest then for _,kind in ipairs({'origins','imports'}) do local record=self.workspace.reserved and self.workspace.reserved[kind];if type(record)=='table' and type(record.manifest)=='table' then manifest=record.manifest;break end end end
        return data.GetRotationTags({body=snapshot,tags=manifest and manifest.tags}) or {}
    end
    function pane:EffectiveScope() return self.scopeDirty and self.scopeDraft or self.workspace.scope end
    function pane:BaselineScope() return self.workspace.session.BaselineOwnership and self.workspace.session:BaselineOwnership() end
    function pane:FlushName()
        if self.deleted or workspace.readOnly then return true end
        if self.nameDirty and not workspace.fallback then local ok,problem=workspace:Command('SetBodyField','name',self.name:GetText());if not ok then self:Message(problem);return nil,problem end;self.nameDirty=false end
        if self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty then
            local snapshot=workspace:Snapshot();local tags=snapshot.tags;local priority=snapshot.priority
            if self.priorityDirty then
                local text=self.priority:GetText();local parsed=data.GetRotationPriority(text:match('^%s*$') and nil or tonumber(text))
                if parsed==nil or not text:match('^%s*$') and tonumber(text)==nil then self.priority:SetTextColor(1,.35,.35);self:Message(L['Switch priority must be a whole number between -100000 and 100000.']);return nil,'invalid-priority' end
                if snapshot.priority~=nil or parsed~=0 then priority=parsed end
            end
            if self.tagsDirty then
                local parsed=data.ParseRotationTags(self.tags:GetText());if not parsed then self.tags:SetTextColor(1,.35,.35);self:Message(L['Invalid tags. Use up to 64 tags of 64 characters, separated by commas.']);return nil,'invalid-tags' end
                if snapshot.tags~=nil and not data.NormalizeRotationTags(snapshot.tags) or data.FormatRotationTags(parsed)~=data.FormatRotationTags(self:EffectiveTags(snapshot)) then tags=parsed end
            end
            local metadata=self.metadataDirty and self.metadataDraft or snapshot.metadata;if snapshot.metadata==nil and type(metadata)=='table' and next(metadata)==nil then metadata=nil end
            local details={description=self.descriptionDirty and self.description:GetText() or snapshot.description,metadata=metadata,tags=tags,priority=priority}
            local ok,problem=workspace:Command('SetDetails',details);if not ok then self:Message(problem);return nil,problem end
            self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self:Message('')
        end
        if self.scopeDirty then local ok,problem=workspace:Command('SetOwnership',self.scopeDraft);if not ok then self:Message(problem);return nil,problem end;self.scopeDirty=false end
        return true
    end
    function pane:HasUnsavedChanges() return not self.deleted and not self.workspace.readOnly and (self.workspace:IsDirty() or self.nameDirty==true or self.descriptionDirty==true or self.metadataDirty==true or self.tagsDirty==true or self.priorityDirty==true or self.scopeDirty==true or self:HasPendingFields()) end
    function pane:LayoutGeometry()
        if not self.ready then return end
        local width,height=self.frame:GetWidth(),self.frame:GetHeight();local x,y=8,34
        local reserve=addon:GetWorkbenchHelpReserve(self.frame)
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',86,-4);self.name:SetWidth(math.max(100,width-94-self.info:GetWidth()-8-reserve))
        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8-reserve,-4)
        for _,control in ipairs(self.tools) do
                if x+control:GetWidth()>width-112 then x=8;y=y+24 end
            control:ClearAllPoints();control:SetPoint('TOPLEFT',self.frame,'TOPLEFT',x,-y);x=x+control:GetWidth()+4
        end
        self.delete:ClearAllPoints();self.delete:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-8,-34)
        self.enable:ClearAllPoints();self.enable:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',-36,-35)
        local available=self.validation and self.validation.valid and self.validation.supported and self.validation.resolved and not self:HasInvalidPendingFields()
        self.validationButton:ClearAllPoints();self.validationButton:SetPoint('TOPLEFT',8,-y-26);self.validationButton:SetWidth(math.max(100,width-16))
        self:RefreshSectionMarkers()
        if available then self.validationButton:Hide() else self.validationButton:Show() end
        local switchTop=y+30+(available and 0 or 24)
        self.switchLabel:ClearAllPoints();self.switchLabel:SetPoint('TOPLEFT',8,-switchTop)
        self.switch:ClearAllPoints();self.switch:SetPoint('TOPLEFT',8,-switchTop-22)
        self.switchText:SetWidth(math.max(100,width-28))
        self.switchText:SetText(addon:PlainWorkbenchName(workspace.fallback and L['No other rotations match.'] or addon:DescribeCardCondition(self.workspace:Snapshot().switch or {},spec)))
        local switchHeight=math.max(20,self.switchText:GetStringHeight());self.switchText:SetHeight(math.min(72,switchHeight))
        self.switch:SetSize(math.max(100,width-16),math.min(72,switchHeight)+8)
        self.switch:Show()
        local top=self:LayoutViewControls(switchTop+22+math.min(72,switchHeight)+18,width)
        self.canvas.frame:ClearAllPoints();self.canvas.frame:SetPoint('TOPLEFT',8,-top)
        self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48));self.canvas:LayoutScrollBar();local barReserve=self.selectionBar and self.selectionBar:IsShown() and 200 or 0;self.status:SetWidth(math.max(1,width-330-barReserve));self.hint:SetWidth(math.max(1,width-330-barReserve));if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end
    end
    function pane:Layout() self:LayoutGeometry();self:Render() end
    function pane:SetWidth(value) self.frame:SetWidth(value) end
    function pane:SetHeight(value) self.frame:SetHeight(value) end
    function pane:Release()
        if self.active then self:FlushName() end
        if self.leavePrompt then self.leavePrompt.frame:Hide() end
        if self.deletePrompt then self.deletePrompt.frame:Hide() end
        if self.metadataWindow then self.metadataWindow:Close(true) end
        if addon.CancelWorkbenchReflow then addon:CancelWorkbenchReflow(self) end
        self.active=false;self.generation=(self.generation or 0)+1;self.canvas:Release();self.name:ClearFocus();self.description:ClearFocus();self.frame:Hide()
    end
    function pane:Open(nextSpec,nextId,nextSelect)
        local selected,problem=addon:GetRotationEditWorkspace(nextSpec,nextId);if not selected then return nil,problem end
        if self.active then self:Release() end
        workspace=selected;spec=nextSpec;id=selected.id;onSelect=nextSelect;self.workspace=workspace
        workspace.uiView=workspace.uiView or {collapsed={},expanded={},detailsHeights={}};self.view=workspace.uiView
        local preferred=addon.db.profile.rotation_view=='list' and 'list' or 'diagram'
        if self.view.defaultLayout~=preferred then self.view.layout=preferred;self.view.defaultLayout=preferred end
        self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self.metadataDraft=nil;self.deleted=false;self.active=true;self.generation=(self.generation or 0)+1
        local token=self.generation
        local function alive() return self.active and self.generation==token end
        for _,control in ipairs(self.tools) do
            addon:SetUIScript(control,'OnClick',function() if alive() then control.action() end end)
        end
        addon:SetUIScript(self.compare,'OnClick',function() if alive() then self.compare.action() end end)
        addon:SetUIScript(self.clone,'OnClick',function() if alive() then self.clone.action() end end)
        addon:SetUIScript(self.info,'OnClick',function() if alive() then self.metadataWindow:Open() end end)
        addon:SetUIScript(self.enable,'OnClick',function() if alive() then self.enable.action() end end)
        addon:SetUIScript(self.delete,'OnClick',function() if alive() then self.delete.action() end end)
        addon:SetUIScript(self.validationButton,'OnClick',function()
            if not alive() or not addon.ShowConditionText then return end
            local lines={L['This rotation cannot run until its incomplete or unavailable data is resolved.']}
            local snapshot=self.workspace:Snapshot()
            for _,problem in ipairs(self.validation and self.validation.diagnostics or {}) do lines[#lines+1]=addon.DescribeRotationIssue and addon:DescribeRotationIssue(problem,snapshot) or problem.path..': '..problem.code end
            for stepId in pairs(self.view.pendingFields or {}) do local reason=self:PendingFieldProblem(stepId);if reason then lines[#lines+1]=stepId..': '..reason end end
            addon:ShowConditionText(table.concat(lines,'\n'),L['Rotation validation'])
        end)
        addon:SetUIScript(self.description,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly then self.descriptionDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.description,'OnEditFocusGained',workspace.readOnly and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.switchLabel,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        addon:SetUIScript(self.switch,'OnClick',function() if alive() then self:EditCondition({kind='switch'}) end end)
        self.view.section=self.view.section=='cooldowns' and 'cooldowns' or 'rotation'
        self.view.cardStates=self.view.cardStates or {};self.view.sectionsCollapsed={};self.view.hiddenChildren=self.view.hiddenChildren or {};self.view.switchCollapsed=nil
        self:BindViewControls(alive)
        addon:SetUIScript(self.name,'OnTextChanged',function(_,userInput) if alive() and userInput and not workspace.readOnly and not workspace.fallback then self.nameDirty=true;self:UpdateHistory() end end)
        addon:SetUIScript(self.name,'OnEnterPressed',function(control) if alive() then control:ClearFocus();if self:FlushName() then self:Render() end end end)
        addon:SetUIScript(self.name,'OnEditFocusGained',(workspace.readOnly or workspace.fallback) and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.apply,'OnClick',function() if alive() then self:Apply() end end)
        addon:SetUIScript(self.discard,'OnClick',function()
            if not alive() then return end
            local ok,reason=workspace:Discard();if ok then self.metadataWindow:Close(true); self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.scopeDirty=false;self.scopeDraft=nil;self:ClearPendingFields();self:Render() else self:Message(reason) end
        end)
        if workspace.readOnly then self.apply:Disable();self.discard:Disable() else self.apply:Enable();self.discard:Enable() end
        for _,control in ipairs({self.compare,self.clone}) do if workspace.pending then control:Disable() else control:Enable() end end
        self.name:EnableMouse(not workspace.readOnly and not workspace.fallback);self.canvas.frame:Show();self.frame:Show();self:Message('')
        self.frame:SetSize(parent:GetWidth(),parent:GetHeight());self:Layout();return self
    end
    -- A resize lays out the header and viewport at once. Cards follow through
    -- the shared reflow driver, once per rendered frame at most, by geometry
    -- alone: bound cards are re-placed, never released and bound again. The
    -- diagram keeps its card widths, so that is all it needs. List and
    -- cooldown cards take the viewport width, which rewraps their text, so
    -- once the size has settled they are bound again (measured) in one render.
    function pane:Resized()
        if not self.active then return end
        self:LayoutGeometry()
        local canvas=self.canvas
        local function stale() return canvas.frame:GetWidth()~=canvas.reflowedWidth or canvas.frame:GetHeight()~=canvas.reflowedHeight end
        if not stale() then return end
        if not addon.RequestWorkbenchReflow then return self:Render() end
        local token=self.generation
        local function current() return self.active and self.generation==token end
        addon:RequestWorkbenchReflow(self,self.frame,function()
            if not current() or not stale() then return end
            if not canvas:IsDiagram() and canvas.frame:GetWidth()~=canvas.reflowedWidth then canvas:ReleaseExpandedCards() end
            canvas:Reflow()
        end)
        if not canvas:IsDiagram() then
            addon:RequestWorkbenchSettle(self,self.frame,function() if current() and not canvas:IsDiagram() and canvas.frame:GetWidth()~=canvas.renderedWidth then self:Render() end end)
        end
    end
    addon:SetUIScript(pane.frame,'OnSizeChanged',function() pane:Resized() end)
    addon:InstallRotationMetadata(pane)
    addon:InstallRotationUnsaved(pane);addon:InstallRotationChangeReview(pane)
    pane.ready=true;parent.rmRotationEditor=pane
    if addon.InstallRotationNavigation then addon:InstallRotationNavigation(pane) end
    return pane:Open(spec,id,onSelect)
end
