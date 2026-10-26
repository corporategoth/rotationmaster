local addon_name,addon=...
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local beginActive=addon.BeginActiveRotationTransition
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData
local function text(parent,font)
    local label=parent:CreateFontString(nil,'OVERLAY',font or 'GameFontHighlightSmall');label:SetJustifyH('LEFT');label:SetWordWrap(false);return label
end
-- A Built In's on/off switch, live from the library when it is loaded,
-- else the workspace's copy of the source (its enabled flag).
local function builtinSwitch(workspace)
    -- An import preview shows the switch the incoming rotation carries; it is nobody's setting.
    if workspace.preview then return workspace:Snapshot().disabled~=true end
    if type(addon.GetBuiltinSwitch)=='function' then return (addon:GetBuiltinSwitch(workspace.builtin)) end
    local source=workspace.source;return type(source)=='table' and (source.switchedOn==nil and source.enabled or source.switchedOn) or nil
end
-- The editor header: the specialization picker's fixed width (it holds "All
-- specializations" and the longest Retail names), the gap between controls and
-- the slot at the start of row 2 (the Read-Only pill, or Undo and Redo).
local SPEC_WIDTH,HEADER_GAP,KIND_WIDTH=172,8,78
local function builtinOverrides(workspace)
    return workspace.readOnly and not workspace.preview and type(addon.GetBuiltinOverrides)=='function' and addon:GetBuiltinOverrides(workspace.builtin) or nil
end
-- `detached` is a workspace made by NewRotationPreviewWorkspace: the pane then
-- shows an incoming rotation read-only and writes nothing anywhere.
function addon:CreateRotationEditor(parent,spec,id,onSelect,detached)
    if parent.rmRotationEditor then return parent.rmRotationEditor:Open(spec,id,onSelect,detached) end
    local workspace,why=detached,nil;if not workspace then workspace,why=self:GetRotationEditWorkspace(spec,id) end;if not workspace then return nil,why end
    local pane={frame=self:TrackWorkbenchSize(CreateFrame('Frame',nil,parent)),workspace=workspace,view={collapsed={},expanded={},detailsHeights={}},active=false,tools={}}
    pane.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',0,0)
    -- The field has no label of its own: it is the wide one beside the
    -- specialization picker. An empty field and its tooltip say "Name".
    pane.name=self:CreateWorkbenchEditBox(pane.frame);pane.name:SetPoint('TOPLEFT',8,-4);pane.name:SetSize(320,24);pane.name:SetMaxLetters(256)
    pane.name.tooltip=L['Name'];self:AttachWorkbenchSearchHint(pane.name,L['Name'])
    pane.origin=text(pane.frame);pane.origin:SetText('');pane.origin:Hide()
    pane.descriptionLabel=text(pane.frame);pane.descriptionLabel:SetText(L['Description']);pane.descriptionLabel:SetPoint('TOPLEFT',8,-38)
    pane.description=CreateFrame('EditBox',nil,pane.frame);pane.description:SetFontObject('GameFontHighlightSmall');pane.description:SetAutoFocus(false);pane.description:SetMultiLine(true);pane.description:SetMaxLetters(4096);pane.description:SetPoint('TOPLEFT',86,-30);pane.description:SetSize(300,36)
    pane.info=addon:CreateWorkbenchLabeledIconButton(pane.frame,'info',L['Metadata'],92)
    pane.validationButton=addon:CreateWorkbenchLabeledIconButton(pane.frame,'warning',L['This rotation cannot run until its incomplete or unavailable data is resolved.'],400)
    pane.validationButton:GetFontString():SetTextColor(1,.35,.3);pane.validationButton:Hide()
    pane.status=text(pane.frame);pane.status:SetPoint('BOTTOMLEFT',8,12)
    function pane:Message(message) self.status:SetText(message or '') end
    function pane:UpdateHistory()
        local state=self.workspace.session:HistoryState()
        local pending=not self.workspace.readOnly and (self.nameDirty or self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty or self.identifierDirty or self.scopeDirty or self:HasPendingFields())
        if state.canUndo or pending then self.undo:Enable() else self.undo:Disable() end
        if state.canRedo and not pending then self.redo:Enable() else self.redo:Disable() end
        -- Apply waits for a valid, unused identifier; the message says why.
        if not self.workspace.readOnly and not self.identifierProblem and (self.workspace.pending or self:HasUnsavedChanges()) then self.apply:Enable() else self.apply:Disable() end
    end
    function pane:BuildScene()
        local snapshot=self.workspace:Snapshot()
        for stepId,state in pairs(self.view.cardStates or {}) do self.view.expanded[stepId]=state=='expanded' end
        for stepId,expanded in pairs(self.view.expanded) do if not expanded then self.view.detailsHeights[stepId]=nil else self.view.detailsHeights[stepId]=self.view.detailsHeights[stepId] or 180 end end
        self.view.viewportWidth=self.canvas and self.canvas.frame:GetWidth() or 720
        self.view.unbound,self.bindingSignature=self:CollectBindings(snapshot)
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
            model.unbound=self.view.unbound[model.id]
            model.live=self.liveStates and self.liveStates[model.id] or nil
        end
        return scene
    end
    -- Steps and cooldowns whose action no action button holds right now, so
    -- the engine skips them (addon:GetStepBinding, from the button index):
    -- stepId -> {missing=} (the missing spells of Blizzard's suggestion).
    -- Computed when the scene is built and when the index changes, never per
    -- frame. Stop and Branch have no action and are never listed.
    function pane:CollectBindings(snapshot)
        local unbound,signature={},{}
        if addon.GetStepBinding then
            local tree=data.IndexRotationSteps(snapshot,{allowMissingIds=true})
            for _,row in ipairs(tree and tree.rows or {}) do
                local step=row.step
                if type(step)=='table' and step.id~=nil then
                    local bound,missing=addon:GetStepBinding(step)
                    if bound==false then
                        unbound[step.id]={missing=missing}
                        signature[#signature+1]=tostring(step.id)..(missing and (':'..table.concat(missing,',')) or '')
                    end
                end
            end
        end
        table.sort(signature)
        return unbound,table.concat(signature,'|')
    end
    -- The bars were rescanned (a slot changed, a page, a macro...): repaint
    -- only when a card's warning changes, and not under a focused input (the
    -- next render picks it up).
    function pane:RefreshBindings()
        if not self.active then return end
        local _,signature=self:CollectBindings(self.workspace:Snapshot())
        if signature==self.bindingSignature then return end
        local focus=type(GetCurrentKeyBoardFocus)=='function' and GetCurrentKeyBoardFocus() or nil
        if focus then return end
        self:Render()
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
        self.switchText:SetText(self:SwitchSummary(snapshot))
        if workspace.fallback then self.switch:Disable() else self.switch:Enable() end
        self:ApplySwitchNotes()
        self:BuildScene();self:LayoutGeometry();self.canvas:Render()
        if self.liveTimer then self:RefreshLiveStatus() else self.switchLiveBar:SetState(nil) end
        for _,control in ipairs({self.compare,self.clone}) do if self.workspace.pending then control:Disable() else control:Enable() end end
        self.clone:SetText(self.workspace.readOnly and L['Clone to edit'] or L['Duplicate'])
        if self.workspace.readOnly or workspace.fallback then self.delete:Disable() else self.delete:Enable() end
        self.delete.tooltip=self.workspace.pending and L['Discard this new rotation'] or L['Delete rotation']
        -- A Built In's switch is read live (never the workspace's cached copy)
        -- and apart from validity, so the pill shows exactly what a click flips.
        local builtinOn=self.workspace.readOnly and builtinSwitch(self.workspace)
        self.enable:SetSelected(self.workspace.readOnly and builtinOn==true or not self.workspace.readOnly and not snapshot.disabled)
        self.enable:SetText(self.workspace.readOnly and (builtinOn and L['Enabled'] or L['Disabled']) or snapshot.disabled and L['Disabled'] or L['Enabled'])
        self:RenderPriority(snapshot)
    end
    -- The priority box and, for a Built In, which of its settings are yours.
    function pane:RenderIdentifier(snapshot)
        local locked=self.workspace.readOnly or workspace.fallback
        if locked then
            local identifier=workspace.fallback and 'default' or workspace.preview and (type(snapshot.identifier)=='string' and snapshot.identifier or '') or addon.GetBuiltinIdentifier and addon:GetBuiltinIdentifier(self.workspace.builtin) or ''
            self.identifier:SetText(identifier);self.identifier:SetTextColor(.75,.75,.75);self.identifier:SetAlpha(.75)
            self.identifier.tooltip=workspace.fallback and L['The fallback is always /rm set default.'] or not workspace.preview and L["A Built In's identifier is fixed. Use it with /rm set."] or nil
            return
        end
        self.identifier:SetAlpha(1)
        if not self.identifierDirty then
            local text=snapshot.identifier
            if not text and addon.GetRotationIdentifier and not self.workspace.pending then text=addon:GetRotationIdentifier(spec,self.workspace.id) end
            if not text and addon.NewRotationIdentifier then text=addon:NewRotationIdentifier(spec,snapshot.name or self.name:GetText(),self.workspace.id);self.identifierDirty=self.workspace.pending==true end
            self.identifier:SetText(text or '');self.identifier:SetTextColor(1,1,1);self.identifierProblem=nil
        end
        self.identifier.tooltip=snapshot.identifier and L['Use it with /rm set. Letters, digits, _ or -, starting with a letter; not case sensitive.'] or L['Made from the name until you change it. Use it with /rm set.']
    end
    function pane:CheckIdentifier()
        if self.workspace.readOnly or workspace.fallback or not addon.CheckRotationIdentifier then self.identifierProblem=nil;return true end
        local problem=addon:CheckRotationIdentifier(spec,self.workspace.id,self.identifier:GetText())
        self.identifierProblem=problem
        if problem then self.identifier:SetTextColor(1,.35,.35);self:Message(problem) else self.identifier:SetTextColor(1,1,1) end
        return problem==nil
    end
    function pane:ShowsSpecs() return addon.GetRotationSpecKind and addon:GetRotationSpecKind()~=nil end
    -- What the fallback applies to, worded as the Rotations list's
    -- specialization dropdown words it: the specialization (or talent group,
    -- or "No specialization") whose Default it is where the client keeps one
    -- Default per specialization, else every specialization.
    function pane:FallbackSpecText() return addon:GetFallbackSpecName(spec) or L['All specializations'] end
    function pane:RenderSpecs(snapshot)
        if not self:ShowsSpecs() then self.specButton:Hide();return end
        local specs=data.NormalizeRotationSpecs(snapshot.specs) or nil
        local text=workspace.fallback and self:FallbackSpecText() or addon:DescribeRotationSpecs(specs)
        self.specButton:SetText(text);addon:AlignWorkbenchTextLeft(self.specButton,26)
        local tip=L['The specializations this rotation is for. It is listed, and can be chosen, only while you play one of them; Any means every specialization.']
        -- The picker has a fixed width, so a long choice is read in full here.
        tip=text..'\n\n'..tip
        if self.workspace.readOnly or workspace.fallback then self.specButton:Disable();self.specButton:SetAlpha(.75)
        else self.specButton:Enable();self.specButton:SetAlpha(1) end
        self.specButton.tooltip=tip
    end
    function pane:SwitchSummary(snapshot)
        if workspace.fallback then return addon:PlainWorkbenchName(L['No other rotations match.']) end
        -- Nothing to match is not nothing to say: it says what that means.
        if addon.HasSwitchCondition and not addon:HasSwitchCondition(snapshot.switch) then return addon:PlainWorkbenchName(L['No switch condition: this rotation can be selected automatically whenever its specialization and level apply.']) end
        return addon:PlainWorkbenchName(addon:DescribeCardCondition(snapshot.switch or {},spec))
    end
    function pane:RenderPriority(snapshot)
        self:RenderIdentifier(snapshot)
        self:RenderSpecs(snapshot)
        local amber={1,.72,.25};local white={1,1,1}
        if self.workspace.preview then
            -- The incoming priority, as it would be saved; nothing here is a setting of this profile.
            if not self.priority:HasFocus() then self.priority:SetText(tostring(snapshot.priority~=nil and snapshot.priority or 0)) end
            self.priority:SetTextColor(white[1],white[2],white[3]);self.priority.tooltip=nil;self.enable.tooltip=nil
            self.priorityLabel:SetText(L['Priority']);self.priorityLabel:SetTextColor(1,1,1);self.enable:GetFontString():SetTextColor(white[1],white[2],white[3])
            self.name:SetAlpha(.75);self.description:SetAlpha(.75)
            self.priorityDown:Disable();self.priorityUp:Disable();self.enable:Disable()
        elseif self.workspace.readOnly then
            local overrides=builtinOverrides(self.workspace) or {}
            if not self.priority:HasFocus() then self.priority:SetText(tostring(overrides.effectivePriority or 0)) end
            -- An override colours the value (the priority number, the pill's
            -- text); labels and borders stay as they are.
            local color=overrides.priority~=nil and amber or white
            self.priority:SetTextColor(color[1],color[2],color[3])
            self.priorityLabel:SetText(L['Priority']);self.priorityLabel:SetTextColor(1,1,1)
            color=overrides.enabled~=nil and amber or white
            self.priorityDown:Enable();self.priorityUp:Enable();self.enable:Enable()
            self.enable:GetFontString():SetTextColor(color[1],color[2],color[3])
            self.enable.tooltip=overrides.enabled~=nil and string.format(L['Your setting for this profile. The Built In ships %s.'],overrides.shippedEnabled and L['enabled'] or L['disabled']) or L['As the Built In ships. Click to change it for this profile.']
            self.priority.tooltip=overrides.priority~=nil and string.format(L['Your priority for this profile; the Built In ships with %d.'],overrides.shippedPriority or 0) or nil
            self.name:SetAlpha(.75);self.description:SetAlpha(.75)
        else
            if not self.priorityDirty then self.priority:SetText(tostring(snapshot.priority~=nil and snapshot.priority or 0));self.priority:SetTextColor(1,1,1) end
            self.priorityLabel:SetText(L['Priority']);self.priorityLabel:SetTextColor(1,1,1);self.enable:GetFontString():SetTextColor(1,1,1);self.enable.tooltip=nil;self.priority.tooltip=nil
            self.name:SetAlpha(1);self.description:SetAlpha(1)
            self.priorityDown:Enable();self.priorityUp:Enable();self.enable:Enable()
        end
    end
    -- A Built In priority or Enabled change is saved now, then selection follows.
    function pane:BuiltinOverrideChanged()
        if not self.active then return end
        self:RefreshAdvice()
        if self.active then self:LayoutGeometry();self:Render() end
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
                elseif step.type=='stop' then title=L['Stop']
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
    -- Undo and Redo share the Read-Only pill's place at the start of the
    -- second row (a Built In has nothing to undo): two icon buttons that
    -- together are as wide as the pill, so nothing moves between the two.
    for _,control in ipairs({pane.undo,pane.redo}) do
        control:SetText('');control:SetSize((KIND_WIDTH-4)/2,20)
        control.icon:ClearAllPoints();control.icon:SetPoint('CENTER',0,0)
    end
    pane.switchButton=addon:CreateWorkbenchButton(pane.frame,'',300);pane.switch=pane.switchButton
    pane.switchText=pane.switchButton:GetFontString();pane.switchText:ClearAllPoints();pane.switchText:SetPoint('TOPLEFT',6,-4);pane.switchText:SetWordWrap(true);pane.switchText:SetJustifyH('LEFT')
    pane.switchLabel=addon:CreateWorkbenchButton(pane.frame,L['Switch condition'],180);addon:StyleWorkbenchHeader(pane.switchLabel:GetFontString());pane.switchLabel.art:SetAlpha(.1);addon:AlignWorkbenchTextLeft(pane.switchLabel,0)
    pane.switch.tooltip=L['Click condition text on any card to view or edit its conditions.']
    -- The switch condition's live bar, and its state first in the tooltip.
    pane.switchLiveBar=addon:CreateLiveStatusBar(pane.switch)
    do
        local enter=pane.switch:GetScript('OnEnter')
        addon:SetUIScript(pane.switch,'OnEnter',function(control,...)
            if enter then enter(control,...) end
            if pane.switchLiveBar.state then addon:ShowConditionFieldTooltip(control,control.tooltip,pane.switchLiveBar.state) end
        end)
    end
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
        if workspace.preview then return end
        if workspace.readOnly then
            local current=builtinSwitch(workspace)==true;local ok,problem=addon:SetDefaultRotationEnabled(workspace.builtin,not current)
            if ok then if workspace.source then workspace.source.enabled=not current end;pane:BuiltinOverrideChanged() else pane:Message(problem) end
        else pane:Command('SetBodyField','disabled',not workspace:Snapshot().disabled) end
    end)
    local oldEnable=pane.enable;oldEnable:Hide();table.remove(pane.tools)
    pane.enable=addon:CreateWorkbenchPill(pane.frame,L['Enabled'],70);pane.enable.action=oldEnable.action
    -- Priority sits left of the Enabled pill: together they decide whether,
    -- and in which order, automatic switching tries this rotation. For a
    -- Built In both are your settings for this profile, saved at once and
    -- shown in amber when they differ from the pack's; the pack itself is
    -- never copied.
    -- The second line: the kind (Read-Only, or Undo and Redo), the identifier
    -- (/rm set <id>), Priority, Enabled, Delete; see LayoutGeometry.
    pane.identifierLabel=text(pane.frame);pane.identifierLabel:SetText(L['ID']);pane.identifierLabel:SetJustifyH('RIGHT')
    pane.identifier=addon:CreateWorkbenchEditBox(pane.frame);pane.identifier:SetSize(108,20);pane.identifier:SetMaxLetters(32)
    pane.priorityLabel=text(pane.frame);pane.priorityLabel:SetText(L['Priority']);pane.priorityLabel:SetJustifyH('RIGHT')
    pane.priority=addon:CreateWorkbenchEditBox(pane.frame);pane.priority:SetSize(56,20);pane.priority:SetMaxLetters(7)
    pane.priorityDown=addon:CreateWorkbenchIconButton(pane.frame,'minus',L['Decrease priority']);pane.priorityDown:SetSize(18,18)
    pane.priorityUp=addon:CreateWorkbenchIconButton(pane.frame,'plus',L['Increase priority']);pane.priorityUp:SetSize(18,18)
    -- The rotation's specializations (body.specs), first on the name line:
    -- where it is listed and can be chosen. Several, or Any; read-only on a
    -- Built In and on the Default.
    pane.specButton=addon:CreateWorkbenchLabeledIconButton(pane.frame,'chevron-down','',SPEC_WIDTH);pane.specButton:SetHeight(20)
    pane.specMenu=addon:CreateWorkbenchSelector()
    pane.overrideReset=addon:CreateWorkbenchButton(pane.frame,L['Reset to default'],116);pane.overrideReset:SetHeight(20)
    pane.overrideReset.tooltip=L['Use the Built In as it ships: its own Enabled setting and priority.']
    -- A Built In shows a blue Read-Only pill where Undo and Redo sit (it has
    -- nothing to undo). It is a label, not a button; its tooltip says where
    -- the pack loads. Duplicate makes an editable copy.
    pane.readOnlyPill=addon:CreateWorkbenchPill(pane.frame,L['Read-Only'],KIND_WIDTH);pane.readOnlyPill:SetSelected(true)
    pane.readOnlyPill:SetAccent(.357,.753,.922,.9);pane.readOnlyPill:GetFontString():SetTextColor(.357,.753,.922);pane.readOnlyPill:Hide()
    pane.switchBaseTooltip=pane.switch.tooltip
    -- What else bears on selection, kept off the page (vertical space is
    -- scarce): where it loads (the Read-Only pill's tooltip), and the
    -- specialization being played and overlapping switches (the switch's
    -- tooltip, with an amber edge on the switch for an overlap).
    function pane:SwitchNotes()
        local lines,amber={},false
        local scope
        if self.workspace.readOnly and not self.workspace.preview and addon.GetDefaultRotation then local view=addon:GetDefaultRotation(self.workspace.builtin);scope=view and view.applicability
        else for _,kind in ipairs({'origins','imports'}) do local record=self.workspace.reserved and self.workspace.reserved[kind];if type(record)=='table' and type(record.manifest)=='table' and record.manifest.applicability then scope=record.manifest.applicability;break end end end
        local where=addon.DescribeApplicability and addon:DescribeApplicability(scope)
        local specs=data.NormalizeRotationSpecs(self.workspace:Snapshot().specs) or nil
        if workspace.fallback and addon.currentSpec~=nil and spec~=addon.currentSpec and addon.DescribeRotationSpec then
            lines[#lines+1]=string.format(L['You are playing %s; this fallback is for %s, so it is not used now.'],addon:DescribeRotationSpec(addon.currentSpec),addon:DescribeRotationSpec(spec))
        elseif specs and addon.GetCurrentRotationSpecValue and not data.RotationSpecsMatch(specs,addon:GetCurrentRotationSpecValue()) then
            local current=addon:GetCurrentRotationSpecValue()
            lines[#lines+1]=string.format(L['You are playing %s; this rotation is for %s, so it is not selectable now.'],current~=nil and addon:DescribeRotationSpecValue(current) or L['no specialization yet'],addon:DescribeRotationSpecs(specs))
        end
        if not self.workspace.fallback and not self.workspace.preview and spec==addon.currentSpec and addon.GetSwitchOverlaps then
            local overlap=addon:DescribeSwitchOverlap(addon:GetSwitchOverlaps(spec)[self.workspace.id])
            if overlap then lines[#lines+1]=overlap;amber=true end
        end
        return #lines>0 and table.concat(lines,'\n') or nil,amber,where
    end
    function pane:ApplySwitchNotes()
        local note,amber,where=self:SwitchNotes()
        self.switch.tooltip=note and (self.switchBaseTooltip and self.switchBaseTooltip..'\n\n'..note or note) or self.switchBaseTooltip
        if addon.SetWorkbenchNotice then addon:SetWorkbenchNotice(self.switch,amber,false) end
        -- The live bar steps inside the amber overlap edge when that shows.
        local inset=amber and 4 or 0;local bar=self.switchLiveBar
        bar:ClearAllPoints();bar:SetPoint('TOPLEFT',self.switch,'TOPLEFT',inset,0);bar:SetPoint('BOTTOMLEFT',self.switch,'BOTTOMLEFT',inset,0)
        local pill=self.workspace.preview and L['Import preview: this is the incoming rotation, read-only. Nothing is saved until you click Import.'] or L['Built In: it cannot be edited. Duplicate makes your own copy; Enabled and Priority are your settings for this profile.']
        self.readOnlyPill.tooltip=where and pill..'\n\n'..where or pill
    end
    pane.delete=tool(L['Delete'],24,function() if pane.ConfirmDelete then pane:ConfirmDelete() end end)
    pane.delete:SetText('');pane.delete.art:Hide();pane.delete.icon=pane.delete:CreateTexture(nil,'ARTWORK');pane.delete.icon:SetAllPoints(pane.delete);pane.delete.icon:SetTexture(addon:ControlTexture('trash'));pane.delete.icon:SetVertexColor(1,.3,.3,1);pane.delete.tooltip=L['Delete rotation']
    table.remove(pane.tools)
    pane.canvas=self:CreateRotationCanvas(pane.frame,pane)
    addon:InstallRotationView(pane)
    pane.hint=text(pane.frame);pane.hint:SetPoint('BOTTOMLEFT',8,12);pane.hint:SetText(L['Click condition text on any card to view or edit its conditions.'])
    -- The footer is one row of controls, each anchored to its neighbor so
    -- none can sit on another: Discard at the right edge, Apply, View Changes
    -- (draft_change_controls.lua) and, while cards are selected, their
    -- actions; the hint or status text takes whatever is left. Buttons are as
    -- wide as their text, so a long translation pushes its neighbors over.
    pane.apply=self:CreateWorkbenchButton(pane.frame,L['Apply'],86)
    pane.discard=self:CreateWorkbenchButton(pane.frame,L['Discard'],86)
    -- Bulk actions on the selected cards, left of View Changes. Each is one
    -- command, so one Undo reverses it. A Built In cannot be edited, so it
    -- gets only the count and Clear.
    local bar=CreateFrame('Frame',nil,pane.frame);pane.selectionBar=bar;bar:SetSize(196,22);bar:Hide()
    bar.label=text(bar);bar.label:SetJustifyH('LEFT');bar.label:SetHeight(22)
    bar.buttons={};bar.order={}
    for _,entry in ipairs({{'duplicate','copy',L['Duplicate selected cards'],true},{'enable','check',L['Enable selected cards'],true},{'disable','minus',L['Disable selected cards'],true},{'remove','trash',L['Delete selected cards'],true},{'clear','close',L['Clear selection']}}) do
        local key=entry[1]
        local button=self:CreateWorkbenchIconButton(bar,entry[2],entry[3]);button:SetSize(20,20);bar.buttons[key]=button;bar.order[#bar.order+1]=key
        button.editing=entry[4]==true
        if key=='remove' then button.icon:SetVertexColor(1,.3,.3,1) end
        addon:SetUIScript(button,'OnClick',function() if pane.active then pane:BulkCommand(key) end end)
    end
    local FOOTER_GAP,FOOTER_PAD=6,16
    local function fitButton(button,minimum)
        local label=button:GetFontString();local width=math.max(minimum,math.ceil(label and label:GetStringWidth() or 0)+FOOTER_PAD)
        button:SetWidth(width);return width
    end
    -- Places every footer control for the current size and selection. The
    -- selection bar sits in the row when the hint keeps a readable width,
    -- else on a row of its own above it (footerStacked).
    function pane:LayoutFooter()
        local frame=self.frame;local width=frame:GetWidth()
        local discardWidth=fitButton(self.discard,70);local applyWidth=fitButton(self.apply,70)
        local viewChanges=self.viewChanges;local viewWidth=viewChanges and fitButton(viewChanges,90) or 0
        self.discard:ClearAllPoints();self.discard:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-8,8)
        self.apply:ClearAllPoints();self.apply:SetPoint('RIGHT',self.discard,'LEFT',-FOOTER_GAP,0)
        if viewChanges then viewChanges:ClearAllPoints();viewChanges:SetPoint('RIGHT',self.apply,'LEFT',-FOOTER_GAP,0) end
        local lead=viewChanges or self.apply
        local barWidth=0;local stacked=false
        if bar:IsShown() then
            local editable=not self.workspace.readOnly
            local labelWidth=math.max(20,math.ceil(bar.label:GetStringWidth())+4);local previous
            bar.label:ClearAllPoints();bar.label:SetPoint('LEFT',bar,'LEFT',0,0);bar.label:SetWidth(labelWidth)
            local x=labelWidth+4
            for _,key in ipairs(bar.order) do
                local button=bar.buttons[key]
                if button.editing and not editable then button:Hide()
                else
                    button:Show();button:ClearAllPoints();button:SetPoint('LEFT',bar,'LEFT',x,0);x=x+22
                    button:Enable()
                end
            end
            barWidth=x-2;bar:SetSize(barWidth,22)
            local row=8+discardWidth+applyWidth+viewWidth+FOOTER_GAP*2+12
            stacked=8+80+barWidth+row>width
            bar:ClearAllPoints()
            if stacked then bar:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-8,36) else bar:SetPoint('RIGHT',lead,'LEFT',-12,0) end
        end
        -- Hint and status share the left of the row, up to the nearest control.
        local right=bar:IsShown() and not stacked and bar or lead
        for _,label in ipairs({self.status,self.hint}) do
            label:ClearAllPoints();label:SetPoint('BOTTOMLEFT',frame,'BOTTOMLEFT',8,12);label:SetPoint('RIGHT',right,'LEFT',-10,0)
        end
        local changed=self.footerStacked~=stacked;self.footerStacked=stacked
        return changed
    end
    function pane:SelectionChanged()
        local count=#self.canvas:SelectedIds(false)
        if count==0 or not self.active then bar:Hide() else bar.label:SetText(string.format(L['%d selected'],count));bar:Show() end
        -- Only a change between the row and the stacked placement moves the canvas.
        if self.ready and self:LayoutFooter() then self:Resized() end
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
        if self.identifierDirty and not self:CheckIdentifier() then return nil,'invalid-identifier' end
        if self.descriptionDirty or self.metadataDirty or self.tagsDirty or self.priorityDirty or self.identifierDirty then
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
            if self.identifierDirty then details.identifier=addon.RotationData.NormalizeRotationIdentifier(self.identifier:GetText()) end
            local ok,problem=workspace:Command('SetDetails',details);if not ok then self:Message(problem);return nil,problem end
            self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.identifierDirty=false;self.identifierEdited=false;self:Message('')
        end
        if self.scopeDirty then local ok,problem=workspace:Command('SetOwnership',self.scopeDraft);if not ok then self:Message(problem);return nil,problem end;self.scopeDirty=false end
        return true
    end
    function pane:HasUnsavedChanges() return not self.deleted and not self.workspace.readOnly and (self.workspace:IsDirty() or self.nameDirty==true or self.descriptionDirty==true or self.metadataDirty==true or self.tagsDirty==true or self.priorityDirty==true or self.identifierDirty==true or self.scopeDirty==true or self:HasPendingFields()) end
    function pane:LayoutGeometry()
        if not self.ready then return end
        local width,height=self.frame:GetWidth(),self.frame:GetHeight()
        local reserve=addon:GetWorkbenchHelpReserve(self.frame)
        local frame=self.frame
        local overrides=builtinOverrides(self.workspace)
        local showPriority=not workspace.fallback
        local showReset=overrides~=nil and overrides.overridden
        local showSpecs=self:ShowsSpecs()
        local readOnly=self.workspace.readOnly
        -- Row 1: the specialization picker where a label used to be, the name
        -- taking whatever is left, then Metadata (and the help icon's corner).
        local x=8
        self.info:ClearAllPoints();self.info:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-8-reserve,-4)
        if showSpecs then
            self.specButton:SetWidth(SPEC_WIDTH);self.specButton:ClearAllPoints();self.specButton:SetPoint('TOPLEFT',frame,'TOPLEFT',8,-6);self.specButton:Show()
            x=8+SPEC_WIDTH+HEADER_GAP
        else self.specButton:Hide() end
        self.name:ClearAllPoints();self.name:SetPoint('TOPLEFT',frame,'TOPLEFT',x,-4)
        self.name:SetWidth(math.max(60,width-x-HEADER_GAP-self.info:GetWidth()-8-reserve))
        -- Row 2 is a slot at the left and a cluster at the right. The slot
        -- holds the Read-Only pill on a Built In and, in the same space, Undo
        -- and Redo on your own rotation. The cluster is flush right and in
        -- one order: ID, Priority, Enabled, Delete; it never moves, whether or
        -- not Reset to default shows. Reset (a Built In whose settings you
        -- changed) goes left of ID, in the free space, or on the line below
        -- when there is none. The cluster is kept whole: when it cannot share
        -- the slot's line it moves down to the next line, still flush right.
        local function place(control,left,top)
            control:ClearAllPoints();control:SetPoint('TOPLEFT',frame,'TOPLEFT',left,-(top+(20-control:GetHeight())/2))
        end
        local function placeLabel(label,left,top)
            label:ClearAllPoints();label:SetPoint('LEFT',frame,'TOPLEFT',left,-(top+10))
        end
        local function sized(label) local w=math.max(1,math.ceil(label:GetStringWidth() or 0));label:SetWidth(w);label:SetHeight(12);return w end
        local kind={}
        if readOnly then
            self.readOnlyPill:Show();kind[1]=self.readOnlyPill
        else
            self.readOnlyPill:Hide()
            for _,control in ipairs(self.tools) do control:Show();kind[#kind+1]=control end
        end
        for _,control in ipairs(self.tools) do if readOnly then control:Hide() end end
        local idLabelWidth=sized(self.identifierLabel);local priorityLabelWidth=sized(self.priorityLabel)
        local idWidth=idLabelWidth+4+self.identifier:GetWidth()
        local priorityWidth=priorityLabelWidth+4+18+2+self.priority:GetWidth()+2+18
        local idPriorityWidth=idWidth+(showPriority and HEADER_GAP+2+priorityWidth or 0)
        local enabledWidth=self.enable:GetWidth()+4+self.delete:GetWidth()
        local clusterWidth=idPriorityWidth+HEADER_GAP+enabledWidth
        local resetWidth=showReset and self.overrideReset:GetWidth() or 0
        for _,control in ipairs({self.priorityLabel,self.priority,self.priorityDown,self.priorityUp}) do if showPriority then control:Show() else control:Hide() end end
        if showReset then self.overrideReset:Show() else self.overrideReset:Hide() end
        self.enable:Show();self.delete:Show();self.identifier:Show();self.identifierLabel:Show()
        local right,first=width-8,34
        local at=8
        for _,control in ipairs(kind) do place(control,at,first);at=at+control:GetWidth()+4 end
        local slotEnd=8+KIND_WIDTH
        local clusterLeft=right-clusterWidth
        local clusterLine=first
        if slotEnd+HEADER_GAP+clusterWidth>right then clusterLine=first+24 end
        local function resetFits(line) return clusterLeft-HEADER_GAP-resetWidth>=(line==first and slotEnd+HEADER_GAP or 8) end
        -- Reset never moves the cluster (it appears when you change a setting):
        -- with no room beside ID it takes the line below, flush right.
        local resetLine=clusterLine
        if showReset and not resetFits(clusterLine) then resetLine=clusterLine+24 end
        local y=math.max(clusterLine,resetLine)
        at=clusterLeft
        placeLabel(self.identifierLabel,at,clusterLine);at=at+idLabelWidth+4
        place(self.identifier,at,clusterLine);at=at+self.identifier:GetWidth()
        if showPriority then
            at=at+HEADER_GAP+2
            placeLabel(self.priorityLabel,at,clusterLine);at=at+priorityLabelWidth+4
            place(self.priorityDown,at,clusterLine);at=at+18+2
            place(self.priority,at,clusterLine);at=at+self.priority:GetWidth()+2
            place(self.priorityUp,at,clusterLine);at=at+18
        end
        at=right-enabledWidth
        place(self.enable,at,clusterLine);at=at+self.enable:GetWidth()+4
        place(self.delete,at,clusterLine)
        if showReset then place(self.overrideReset,resetLine==clusterLine and clusterLeft-HEADER_GAP-resetWidth or right-resetWidth,resetLine) end
        local available=self.validation and self.validation.valid and self.validation.supported and self.validation.resolved and not self:HasInvalidPendingFields()
        self.validationButton:ClearAllPoints();self.validationButton:SetPoint('TOPLEFT',8,-y-26);self.validationButton:SetWidth(math.max(100,width-16))
        self:RefreshSectionMarkers()
        if available then self.validationButton:Hide() else self.validationButton:Show() end
        local switchTop=y+30+(available and 0 or 24)
        self.switchLabel:ClearAllPoints();self.switchLabel:SetPoint('TOPLEFT',8,-switchTop)
        self.switch:ClearAllPoints();self.switch:SetPoint('TOPLEFT',8,-switchTop-22)
        self.switchText:SetWidth(math.max(100,width-28))
        self.switchText:SetText(self:SwitchSummary(self.workspace:Snapshot()))
        local switchHeight=math.max(20,self.switchText:GetStringHeight());self.switchText:SetHeight(math.min(72,switchHeight))
        self.switch:SetSize(math.max(100,width-16),math.min(72,switchHeight)+8)
        self.switch:Show()
        local top=self:LayoutViewControls(switchTop+22+math.min(72,switchHeight)+18,width)
        self.canvas.frame:ClearAllPoints();self.canvas.frame:SetPoint('TOPLEFT',8,-top)
        self:LayoutFooter();self.canvas.frame:SetSize(math.max(1,width-40),math.max(1,height-top-48-(self.footerStacked and 28 or 0)));self.canvas:LayoutScrollBar();if (self.status:GetText() or '')=='' then self.hint:Show() else self.hint:Hide() end
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
        self.active=false;self.generation=(self.generation or 0)+1;self.canvas:Release();self.name:ClearFocus();self.description:ClearFocus();self.frame:Hide();self.specMenu:Hide()
        if addon.WatchButtonIndex then addon:WatchButtonIndex(self,nil) end
        if addon.activeRotationEditor==self then addon.activeRotationEditor=nil end
        self:StopLiveStatus();if addon.liveStatusLastPane==self then addon.liveStatusLastPane=nil end
    end
    function pane:Open(nextSpec,nextId,nextSelect,nextDetached)
        local selected,problem=nextDetached,nil;if not selected then selected,problem=addon:GetRotationEditWorkspace(nextSpec,nextId) end;if not selected then return nil,problem end
        if self.active then self:Release() end
        workspace=selected;spec=nextSpec;id=selected.id;onSelect=nextSelect;self.workspace=workspace
        workspace.uiView=workspace.uiView or {collapsed={},expanded={},detailsHeights={}};self.view=workspace.uiView
        -- Opening a rotation never starts with cards selected (no yellow box, no selection bar).
        self.view.selection={};self.canvas.anchor=nil;self.selectionBar:Hide()
        local preferred=addon.db.profile.rotation_view=='list' and 'list' or 'diagram'
        if self.view.defaultLayout~=preferred then self.view.layout=preferred;self.view.defaultLayout=preferred end
        self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.identifierDirty=false;self.identifierProblem=nil;self.identifierEdited=false;self.scopeDirty=false;self.scopeDraft=nil;self.metadataDraft=nil;self.deleted=false;self.active=true;self.generation=(self.generation or 0)+1
        local token=self.generation
        local function alive() return self.active and self.generation==token end
        if addon.WatchButtonIndex then addon:WatchButtonIndex(self,function() if alive() then self:RefreshBindings() end end) end
        -- The warnings read the last bar scan. An old one is rescanned now (the
        -- scan is event driven; a missed event must not leave a false warning),
        -- and until it lands nothing is judged.
        if addon.EnsureFreshButtonIndex then addon:EnsureFreshButtonIndex(10) end
        -- An import preview is nobody's active editor: refreshes of the profile's rotations never reach it.
        if not workspace.preview then addon.activeRotationEditor=self end
        for _,control in ipairs(self.tools) do
            addon:SetUIScript(control,'OnClick',function() if alive() then control.action() end end)
        end
        addon:SetUIScript(self.compare,'OnClick',function() if alive() then self.compare.action() end end)
        addon:SetUIScript(self.clone,'OnClick',function() if alive() then self.clone.action() end end)
        addon:SetUIScript(self.info,'OnClick',function() if alive() then self.metadataWindow:Open() end end)
        addon:SetUIScript(self.enable,'OnClick',function() if alive() then self.enable.action() end end)
        addon:SetUIScript(self.delete,'OnClick',function() if alive() then self.delete.action() end end)
        addon:SetUIScript(self.overrideReset,'OnClick',function()
            if not alive() or not workspace.readOnly or workspace.preview or not addon.ResetBuiltinOverrides then return end
            local ok,problem=addon:ResetBuiltinOverrides(workspace.builtin)
            if ok then self:BuiltinOverrideChanged() else self:Message(problem) end
        end)
        local function setBuiltinPriority(value)
            if not alive() or not workspace.readOnly or workspace.preview or not addon.SetBuiltinPriority then return end
            local ok,problem=addon:SetBuiltinPriority(workspace.builtin,value)
            if ok then self:Message('');self:BuiltinOverrideChanged() else self.priority:SetTextColor(1,.35,.35);self:Message(problem=='invalid-priority' and L['Switch priority must be a whole number between -100000 and 100000.'] or problem) end
        end
        local function stepPriority(delta)
            if not alive() or workspace.fallback or workspace.preview then return end
            local text=self.priority:GetText();local number=tonumber(text);if text~='' and number==nil then return end
            local value=data.GetRotationPriority(text=='' and nil or number);if value==nil then return end
            value=math.max(-100000,math.min(100000,value+delta))
            if workspace.readOnly then return setBuiltinPriority(value) end
            self.priority:SetText(tostring(value));self.priorityDirty=true;self.priority:SetTextColor(1,1,1);self:UpdateHistory()
        end
        -- Toggle specializations; the menu stays open for the next one.
        local function openSpecs()
            if not alive() or workspace.readOnly or workspace.fallback then return end
            local current=data.NormalizeRotationSpecs(workspace:Snapshot().specs) or {}
            local chosen={};for _,value in ipairs(current) do chosen[value]=true end
            local entries={{value='any',text=L['Any specialization'],selected=#current==0}}
            for _,entry in ipairs(addon:GetRotationSpecEntries()) do entries[#entries+1]={value=entry.id,text=entry.name,icon=entry.icon,selected=chosen[entry.id]==true} end
            self.specMenu:Open(self.specButton,entries,nil,function(value)
                if not alive() then return end
                local list
                if value~='any' then
                    chosen[value]=not chosen[value];list={}
                    for id,on in pairs(chosen) do if on then list[#list+1]=id end end
                    list=data.NormalizeRotationSpecs(list) or nil
                end
                if not self:FlushName() then return end
                local ok,problem=workspace:Command('SetBodyField','specs',list)
                if not ok then self:Message(problem);return end
                self:Render()
                if value~='any' then openSpecs() end
            end,function() return alive() and not workspace.readOnly end,true)
        end
        addon:SetUIScript(self.specButton,'OnClick',openSpecs)
        addon:SetUIScript(self.priorityDown,'OnClick',function() stepPriority(-1) end)
        addon:SetUIScript(self.priorityUp,'OnClick',function() stepPriority(1) end)
        local function commitBuiltinPriority()
            if not alive() or not workspace.readOnly or workspace.preview then return end
            local text=self.priority:GetText();local current=builtinOverrides(workspace)
            local value=text:match('^%s*$') and current and current.shippedPriority or tonumber(text)
            if current and value==current.effectivePriority then self:RenderPriority(workspace:Snapshot());return end
            setBuiltinPriority(value)
        end
        addon:SetUIScript(self.priority,'OnTextChanged',function(_,user)
            if not alive() or not user or workspace.preview then return end
            local text=self.priority:GetText()
            if text~='' and text~='-' and not text:match('^%-?%d+$') then self.priority:SetText(self.lastPriorityText or '0');return end
            self.lastPriorityText=text
            if not workspace.readOnly and not workspace.fallback then self.priorityDirty=true;self.priority:SetTextColor(1,1,1);self:UpdateHistory() end
        end)
        addon:SetUIScript(self.priority,'OnEnterPressed',function(control) control:ClearFocus();commitBuiltinPriority() end)
        addon:SetUIScript(self.priority,'OnEditFocusLost',function() commitBuiltinPriority() end)
        addon:SetUIScript(self.priority,'OnEditFocusGained',(workspace.fallback or workspace.preview) and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.priority,'OnEnter',function()
            if not alive() or not GameTooltip then return end
            local text=L['Higher numbers are tried first; your rotations and Built Ins compete on priority alone. The fallback is used only when no other rotation matches. Equal priorities use name, then identity. Blank means zero.']
            if self.priority.tooltip then text=self.priority.tooltip..'\n\n'..text end
            GameTooltip:SetOwner(self.priority,'ANCHOR_RIGHT');GameTooltip:SetText(text,1,1,1,1,true)
        end)
        addon:SetUIScript(self.priority,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(self.priority) then GameTooltip:Hide() end end)
        local identifierLocked=workspace.readOnly or workspace.fallback
        addon:SetUIScript(self.identifier,'OnEditFocusGained',identifierLocked and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.identifier,'OnTextChanged',function(_,user)
            if not alive() or not user or identifierLocked then return end
            self.identifierDirty=true;self.identifierEdited=true;self:CheckIdentifier();self:UpdateHistory()
        end)
        addon:SetUIScript(self.identifier,'OnEnterPressed',function(control) control:ClearFocus() end)
        addon:SetUIScript(self.identifier,'OnEnter',function() if alive() and GameTooltip and self.identifier.tooltip then GameTooltip:SetOwner(self.identifier,'ANCHOR_RIGHT');GameTooltip:SetText(self.identifierProblem or self.identifier.tooltip,1,1,1,1,true) end end)
        addon:SetUIScript(self.identifier,'OnLeave',function() if GameTooltip and GameTooltip:IsOwned(self.identifier) then GameTooltip:Hide() end end)
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
        addon:SetUIScript(self.name,'OnTextChanged',function(_,userInput)
            if not alive() or not userInput or workspace.readOnly or workspace.fallback then return end
            self.nameDirty=true
            -- A new rotation's identifier follows its name until you edit the identifier.
            if workspace.pending and not self.identifierEdited and addon.NewRotationIdentifier then
                self.identifier:SetText(addon:NewRotationIdentifier(spec,self.name:GetText(),workspace.id));self.identifierDirty=true;self:CheckIdentifier()
            end
            self:UpdateHistory()
        end)
        addon:SetUIScript(self.name,'OnEnterPressed',function(control) if alive() then control:ClearFocus();if self:FlushName() then self:Render() end end end)
        addon:SetUIScript(self.name,'OnEditFocusGained',(workspace.readOnly or workspace.fallback) and function(control) control:ClearFocus() end or nil)
        addon:SetUIScript(self.apply,'OnClick',function() if alive() then self:Apply() end end)
        addon:SetUIScript(self.discard,'OnClick',function()
            if not alive() then return end
            if self:IsNewRotation() then self:DiscardNew();return end
            local ok,reason=workspace:Discard();if ok then self.metadataWindow:Close(true); self.nameDirty=false;self.descriptionDirty=false;self.metadataDirty=false;self.tagsDirty=false;self.priorityDirty=false;self.identifierDirty=false;self.identifierProblem=nil;self.identifierEdited=false;self.scopeDirty=false;self.scopeDraft=nil;self:ClearPendingFields();self:Render() else self:Message(reason) end
        end)
        if workspace.readOnly then self.apply:Disable();self.discard:Disable() else self.apply:Enable();self.discard:Enable() end
        for _,control in ipairs({self.compare,self.clone}) do if workspace.pending then control:Disable() else control:Enable() end end
        self.opening=true;self.name:EnableMouse(not workspace.readOnly and not workspace.fallback);self.canvas.frame:Show();self.frame:Show();self.opening=nil;self:Message('')
        self.frame:SetSize(parent:GetWidth(),parent:GetHeight());self:Layout();self:StartLiveStatus();return self
    end
    -- Live condition bars. Each card's condition (and the switch condition)
    -- is evaluated with the real evaluator against the player's state now,
    -- every Live Status Update Frequency seconds (profile.live_config_update,
    -- 0 = off), only while this editor is open and on screen. Only bound
    -- (visible) cards are evaluated; Release, or a tick that finds the editor
    -- hidden, cancels the timer, so a closed editor costs nothing.
    local function onScreen(frame)
        if type(frame.IsVisible)=='function' then return frame:IsVisible() end
        while frame do
            if not frame:IsShown() then return false end
            frame=frame.GetParent and frame:GetParent() or nil
        end
        return true
    end
    function pane:LiveInterval()
        local value=tonumber(addon.db.profile.live_config_update)
        return value and value>0 and value or nil
    end
    function pane:StopLiveStatus()
        if self.liveTimer then
            local timer=self.liveTimer;self.liveTimer=nil
            if addon.CancelTimer then addon:CancelTimer(timer) end
        end
        if addon.liveStatusPane==self then addon.liveStatusPane=nil end
    end
    function pane:StartLiveStatus()
        self:StopLiveStatus()
        -- Incoming conditions are never evaluated against the live game: an import preview has no bars.
        if self.workspace.preview then self:ClearLiveStatus();return end
        addon.liveStatusLastPane=self
        local interval=self:LiveInterval()
        if not self.active or not interval or type(addon.ScheduleRepeatingTimer)~='function' then self:ClearLiveStatus();return end
        local token=self.generation
        local timer
        timer=addon:ScheduleRepeatingTimer(function()
            if self.liveTimer~=timer then if addon.CancelTimer then addon:CancelTimer(timer) end;return end
            if not self.active or self.generation~=token then self:StopLiveStatus();return end
            self:RefreshLiveStatus()
        end,interval)
        self.liveTimer=timer;addon.liveStatusPane=self
        self:RefreshLiveStatus()
    end
    function pane:ClearLiveStatus()
        self.liveStates=nil
        for _,card in ipairs(self.canvas.cards) do if card.token and card.model and card.SetLive then card:SetLive(nil) end end
        self.switchLiveBar:SetState(nil)
    end
    -- Whether this rotation is the one advising now, and which step it chose
    -- (the last recommendation /rm debug glow recorded), for the tooltips.
    function pane:LiveSelection()
        local key=addon.currentRotation
        if key==nil or addon.currentSpec~=spec then return false end
        local active=key==self.workspace.id or self.workspace.effectiveFallback and key==DEFAULT
        if not active then return false end
        local recent=addon.GetRecentRecommendations and addon:GetRecentRecommendations()
        local last=type(recent)=='table' and recent[#recent] or nil
        return true,last and last.rotation==key and last.spell~=nil and last.id or nil
    end
    local function liveResult(result,now)
        if type(result)~='table' then return {status='unavailable',reason=L['the condition could not be evaluated'],at=now} end
        if result.status=='match' then return {status='satisfied',at=now} end
        if result.status=='no-match' then return {status='unsatisfied',at=now} end
        return {status='unavailable',reason=result.reason,at=now}
    end
    function pane:EvaluateLive(model,now,active,chosen)
        local step=model.step
        if step.type=='branch' and (step.mode or 'evaluate')~='evaluate' then return nil end
        local condition=step.conditions
        if type(condition)~='table' or condition.type==nil then return nil end
        if type(addon.evaluateConditionResult)~='function' then return nil end
        local ok,result=pcall(addon.evaluateConditionResult,addon,condition,{stepId=step.id})
        local state=liveResult(ok and result or nil,now)
        if active and step.type~='branch' then
            if model.section=='cooldowns' then
                if type(addon.avail_announced)=='table' and addon.avail_announced[step.id]~=nil then state.chosen=L['This cooldown is showing now.'] end
            elseif chosen~=nil and chosen==step.id then state.chosen=L['Rotation Master is advising this step now.'] end
        end
        return state
    end
    function pane:RefreshLiveStatus()
        if not self.active or not self.liveTimer then return end
        if not onScreen(self.frame) then self:StopLiveStatus();return end
        local now=type(GetTime)=='function' and GetTime() or 0
        local active,chosen=self:LiveSelection()
        local states={}
        for _,card in ipairs(self.canvas.cards) do
            if card.token and card.model and card.frame:IsShown() then
                local state=self:EvaluateLive(card.model,now,active,chosen)
                states[card.model.id]=state;card:SetLive(state)
            end
        end
        self.liveStates=states
        local switch=not self.workspace.fallback and self.workspace:Snapshot().switch
        if type(switch)=='table' and switch.type~=nil and type(addon.SwitchConditionMatchesNow)=='function' then
            local matched=addon:SwitchConditionMatchesNow(switch)
            local state=matched==true and {status='satisfied',at=now} or matched==false and {status='unsatisfied',at=now}
                or {status='unavailable',reason=L['unreadable right now'],at=now}
            if active then state.chosen=L['This rotation is advising now.'] end
            self.switchLiveBar:SetState(state)
        else self.switchLiveBar:SetState(nil) end
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
    -- Shown again without being reopened: the live bars resume.
    addon:SetUIScript(pane.frame,'OnShow',function() if pane.active and pane.ready and not pane.opening and not pane.liveTimer then pane:StartLiveStatus() end end)
    addon:InstallRotationMetadata(pane)
    addon:InstallRotationUnsaved(pane);addon:InstallRotationChangeReview(pane)
    pane.ready=true;parent.rmRotationEditor=pane
    if addon.InstallRotationNavigation then addon:InstallRotationNavigation(pane) end
    return pane:Open(spec,id,onSelect,detached)
end
-- General > Live Status Update Frequency changed: the open editor (if any)
-- restarts its dots at the new interval, or clears them at 0.
function addon:RestartLiveStatus()
    local pane=self.liveStatusLastPane
    if pane and pane.active then pane:StartLiveStatus() end
end
