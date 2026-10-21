local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function clearNew(p) p.creatingCondition=nil;p.newConditionKey=nil;p.newConditionSource=nil end
function addon:InstallInlineConditionNavigation(p)
    if p.inlineNavigation then return end;p.inlineNavigation=true
    local leave,release,draw,layout=p.RequestLeave,p.Release,p.Draw,p.Layout
    function p:Layout()
        layout(self);local editor=self.inlineCondition
        if editor and not editor.closed and editor.OwnerValid() then editor:ResizeHeight(math.max(160,self.frame:GetHeight()-34)) end
    end
    function p:Draw()
        local editor=self.inlineCondition
        self.inlineResume=nil
        if editor and not editor.closed and editor.OwnerValid() and self.mode~='categories' and editor.inlineSelection==self.condition and editor.inlineNewSource==self.newConditionSource then
            self.inlineResume=editor:CaptureDraft()
        end
        return draw(self)
    end
    function p:RequestLeave(callback)
        local editor=self.inlineCondition
        if editor and not editor.closed and editor:IsDirty() then
            local profile,global=self.profile,self.global
            self:ConfirmPending(function()
                if self.active and self.profile==profile and self.global==global and editor:Apply() then callback() end
            end,function()
                if not self.active or self.profile~=profile or self.global~=global then return end
                editor:Close();self.inlineCondition=nil;self:DiscardSettingsDraft();clearNew(self);callback()
            end)
            return false
        end
        return leave(self,callback)
    end
    function p:Release() clearNew(self);self.inlineResume=nil;release(self);self.inlineCondition=nil end
end
function addon:OpenInlineCustomCondition(p,key,source)
    self:InstallInlineConditionNavigation(p)
    p:RequestLeave(function()
        if not p.active then return end
        p.creatingCondition=true;p.newConditionKey=key;p.newConditionSource=self:CopySettingsData(source or self.empty_condition);p.condition=nil;p.conditionSource='custom';p.category='ALL';p:Draw()
    end)
end
function addon:DuplicateInlineCustomCondition(p)
    self:InstallInlineConditionNavigation(p)
    p:RequestLeave(function()
        if not p.active then return end
        local key=p.condition;local source=self.db.global.custom_conditions[key] or self.GetBuiltinConditionSource and self:GetBuiltinConditionSource(key);if not source then return end
        p.creatingCondition=true;p.newConditionKey=key:sub(1,216)..'_'..self:uuid():gsub('-','_');p.newConditionSource=self:CopySettingsData(source);p.newConditionSource.description=string.format(L['Copy of %s'],source.description);p.condition=nil;p.conditionSource='custom';p.category='ALL';p:Draw()
    end)
end
function addon:BuildInlineCustomCondition(p,key,source,readOnly)
    self:InstallInlineConditionNavigation(p)
    local token=p.generation;local store=p:SettingsData();local profile=store.profile
    local isNew=p.creatingCondition==true
    if isNew then key=nil;source=p.newConditionSource or self.empty_condition end
    local preferences={hidden=self:SettingsContains(profile.disabled_conditions,key),switch=self:SettingsContains(profile.switch_conditions,key),announcement=self:SettingsContains(profile.announcement_conditions,key),category='DEFAULT'}
    for _,group in ipairs(profile.condition_groups or {}) do if self:SettingsContains(group.conditions,key) then preferences.category=group.id;break end end
    local function valid() return p:Valid(token) end
    local geometry=self:GetWorkbenchRosterGeometry(p.frame:GetWidth(),p.frame:GetHeight())
    local options={readOnly=readOnly,parent=p.frame,x=geometry.detailX,footer=p.frame,width=geometry.detailWidth,height=math.max(160,p.frame:GetHeight()-34),editor=p.inlineEditorCache,resume=p.inlineResume};p.inlineResume=nil
    options.initialize=function(model)
        if isNew and p.newConditionKey then model.key=p.newConditionKey;model.baseline.key=model.key;model.creationPending=true end
        model.context=self:CopySettingsData(preferences);model.baseline.context=self:CopySettingsData(preferences)
    end
    options.closeOwner=function(mouse)
        local shell=addon.configWindow
        if shell and shell.pane==p then if mouse then shell.rightDown=true end;shell:Hide() else p:RequestLeave(function() p:Release() end) end
    end
    options.dirty=function() return p:IsSettingsDraftDirty() end
    options.discard=function() if valid() then p:DiscardSettingsDraft();clearNew(p);p:Draw() end end
    options.fields=function(form,d)
        local context=d.model.context;local y=form.y
        local checkWidth=(form.width-148)/2
        local hidden=form:Check('hidden',L['Hidden'],context.hidden,function(value) d.model:Change(function(model) model.context.hidden=value end);d:UpdateActions() end);hidden:SetWidth(checkWidth);hidden:GetFontString():SetWidth(checkWidth-22)
        local switch=form:Check('switch',L['Switch Condition'],context.switch,function(value) d.model:Change(function(model) model.context.switch=value end);d:UpdateActions() end);switch:ClearAllPoints();switch:SetPoint('TOPLEFT',checkWidth+8,-y);switch:SetWidth(checkWidth);switch:GetFontString():SetWidth(checkWidth-22);form.y=form.y-28
        local announcement=form:Check('announcement',L['Announcement Condition'],context.announcement,function(value) d.model:Change(function(model) model.context.announcement=value end);d:UpdateActions() end);announcement.tooltip=L['Show this condition in the announcement condition editor.'];form.cleanups[#form.cleanups+1]=function() announcement.tooltip=nil end
        if key and not readOnly then self:SettingsTopDelete(form,function()
            self:ConfirmSettingsDeletion(p,L['Delete this custom condition? Existing rotations using it will become unavailable.'],function()
                local ok,why=self:DeleteSavedCustomCondition(key);if ok then clearNew(p);p.condition=nil end;return ok,why
            end)
        end) end
    end
    options.category=function(form,d)
        local context=d.model.context;local savedCategory=d.model.baseline.context.category
        local groups=store.profile.condition_groups or {};local destinations={{value='DEFAULT',text=L['Other'],icon=self:GetConditionCategoryIcon(nil)}};local current=L['Other'];local icon=self:GetConditionCategoryIcon(nil)
        for _,group in ipairs(groups) do destinations[#destinations+1]={value=group.id,text=group.name or group.id,icon=self:GetConditionCategoryIcon(group)};if group.id==savedCategory then current=group.name or group.id;icon=self:GetConditionCategoryIcon(group) end end
        local function visitCategory()
            p:RequestLeave(function() if p.active then p.mode='categories';p.categorySelection=savedCategory;p:Draw() end end)
        end
        local categoryY=form:Row(L['Category'],28);form.pool.labels[form.counts.labels]:SetWidth(168)
        local fieldWidth=(form.width-182)/2
        local category=form:Acquire('sourceCategory',function() return self:CreateWorkbenchButton(form.child,'',fieldWidth) end);form.fields.current_category=category;category:ClearAllPoints();category:SetPoint('TOPLEFT',174,-categoryY);category:SetText(current)
        -- Navigation must offer Discard even while a raw source field is invalid.
        self:SetUIScript(category,'OnClick',function() if valid() then visitCategory() end end)
        category.categoryIcon=category.categoryIcon or category:CreateTexture(nil,'ARTWORK');category.categoryIcon:SetPoint('LEFT',3,0);category.categoryIcon:SetSize(20,20);category.categoryIcon:SetTexture(icon);category:SetWidth(fieldWidth);self:AlignWorkbenchTextLeft(category,28)
        local moveLabel=form:Acquire('labels',function() return form.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall') end)
        form.fields.moveLabel=moveLabel;moveLabel:ClearAllPoints();moveLabel:SetPoint('TOPLEFT',174+fieldWidth+8,-categoryY);moveLabel:SetSize(38,24);moveLabel:SetText(L['Move']);moveLabel:SetJustifyH('LEFT');moveLabel:SetJustifyV('MIDDLE')
        local move=form:Choice('move_to',nil,context.category,destinations,function(value)
            if valid() then d.model:Change(function(model) model.context.category=value end);form:Draw();d:UpdateActions() end
        end)
        move:ClearAllPoints();move:SetPoint('TOPLEFT',174+fieldWidth+50,-categoryY);move:SetWidth(fieldWidth-42);form.y=form.y-30
    end
    options.updateActions=function(d)
        for _,field in ipairs({'hidden','switch','announcement'}) do self:SetWorkbenchUnsaved(d.form.fields[field],d.model.context[field]~=d.model.baseline.context[field]) end
        self:SetWorkbenchUnsaved(d.form.fields.move_to,d.model.context.category~=d.model.baseline.context.category)
    end
    options.save=function(identifier,value,expected,expectedSource)
        if not valid() then return false,{reason='definition-changed'} end
        if InCombatLockdown and InCombatLockdown() then return false,{reason=L['Leave combat before applying these settings.']} end
        -- Validate every owned settings baseline before registration. A trusted
        -- registration hook can fail; preferences are applied only after it succeeds.
        for scope,keys in pairs(p.transactionKeys) do for _,field in ipairs(keys) do
            if not self:SettingsDataEqual(self.db[scope] and self.db[scope][field],p.draftBaseline[scope][field]) then return false,{reason=L['Settings changed elsewhere. Cancel to reload them before applying.']} end
        end end
        local previous=self:CopySettingsData(self.db.global.custom_conditions[identifier]);local oldDefinition=self.conditionDefinitions[identifier]
        if oldDefinition~=expected or expectedSource and not self:SettingsDataEqual(previous,expectedSource) then return false,{reason='definition-changed'} end
        if readOnly and not self:SettingsDataEqual(source,value) then return false,{reason='readonly-builtin'} end
        local changed=not readOnly and not self:SettingsDataEqual(previous,value)
        if changed then local ok,why=self:InstallCustomCondition(identifier,value,expected,expectedSource);if not ok then return false,why end end
        local saved=self:CopySettingsData(self.db.global.custom_conditions[identifier])
        p.draft.global.custom_conditions[identifier]=saved;p.draftBaseline.global.custom_conditions=p.draftBaseline.global.custom_conditions or {};p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(saved)
        local context=p.inlineCondition.model.context;local draft=p.draft.profile
        local function membership(list,enabled)
            if self:SettingsContains(list,identifier)~=enabled then self:SettingsFlag(list,identifier,enabled) end
        end
        draft.disabled_conditions=draft.disabled_conditions or {};membership(draft.disabled_conditions,context.hidden)
        draft.switch_conditions=draft.switch_conditions or {};membership(draft.switch_conditions,context.switch)
        draft.announcement_conditions=draft.announcement_conditions or {};membership(draft.announcement_conditions,context.announcement)
        for _,group in ipairs(draft.condition_groups or {}) do group.conditions=group.conditions or {};membership(group.conditions,group.id==context.category) end
        if not p:SaveSettingsDraft() then
            -- This can occur if trusted registration code changes another owned
            -- namespace. Restore our source/registry rather than accepting half a save.
            if changed then
                local current=self.conditionDefinitions[identifier];if current and not current.disabled and current.on_unregister then pcall(current.on_unregister,identifier) end
                self.db.global.custom_conditions[identifier]=previous;self.conditionDefinitions[identifier]=oldDefinition;self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
                if invalidateDependencies then invalidateDependencies(addon,'condition',identifier) end
                if oldDefinition and not oldDefinition.disabled and oldDefinition.on_register then pcall(oldDefinition.on_register,identifier) end
                if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
                p.draft.global.custom_conditions[identifier]=self:CopySettingsData(previous);p.draftBaseline.global.custom_conditions[identifier]=self:CopySettingsData(previous)
            end
            return false,{reason=L['Settings changed elsewhere. Cancel to reload them before applying.']}
        end
        return true
    end
    local d,owner=self:condition_edit_box(function(identifier)
        if not valid() then return end
        clearNew(p);p.condition=identifier;p.conditionSource=readOnly and 'builtin' or 'custom';p.category='ALL';p:Draw()
    end,key,source,valid,options)
    p.inlineCondition=d;p.inlineEditorCache=d
    d.inlineSelection=p.condition;d.inlineNewSource=p.newConditionSource
    p.cleanups[#p.cleanups+1]=function() self:CloseCustomConditionEditor(d,owner);if p.inlineCondition==d then p.inlineCondition=nil end end
    p.creationUsed=true;p.creationUsedForNew=false;p.y=1;p.scroll:Hide()
    -- The right pane owns its source actions; no duplicate page Apply row.
    return d
end
