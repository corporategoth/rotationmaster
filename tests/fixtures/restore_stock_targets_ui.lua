-- Strict complete-module inverse of Unit2b desired-stock editing at baseline92c8fe8.
local changes={
 ['UI/settings_items.lua']={bytes=11031,hash='e49911e2',edits={
  {from=[====[    return value
end
function addon:BuildItemSettings(p)
    self:ItemSettingsSourceOptions(p,{})
    if p.itemSettingsSource=='stock' then return self:BuildStockSettings(p) end
    local store=p:SettingsData()
    local profileSets=store.profile.itemsets or {};local globalSets=store.global.itemsets or {};local merged={}
    for id,set in pairs(globalSets) do merged[id]=set end;for id,set in pairs(profileSets) do merged[id]=set end
    local entries=self:SettingsEntries(merged);for _,entry in ipairs(entries) do local value=(merged[entry.value].items or {})[1];local info=value and self:GetReferenceProvider('item').info(tonumber(value) or self:GetReferenceProvider('item').resolve(value));entry.icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08' end;if not merged[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,self:ItemSettingsSourceOptions(p,{newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end}));p:Heading(L['Item Sets']);if p.historyEnabled then p:HistoryActions() end
    local set=merged[p.selection]
    if set then
        local id=p.selection;local items=set.items or {}
]====],to=[====[    return value
end
function addon:BuildItemSettings(p)
    local store=p:SettingsData()
    local profileSets=store.profile.itemsets or {};local globalSets=store.global.itemsets or {};local merged={}
    for id,set in pairs(globalSets) do merged[id]=set end;for id,set in pairs(profileSets) do merged[id]=set end
    local entries=self:SettingsEntries(merged);for _,entry in ipairs(entries) do local value=(merged[entry.value].items or {})[1];local info=value and self:GetReferenceProvider('item').info(tonumber(value) or self:GetReferenceProvider('item').resolve(value));entry.icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08' end;if not merged[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end});p:Heading(L['Item Sets']);if p.historyEnabled then p:HistoryActions() end
    local set=merged[p.selection]
    if set then
        local id=p.selection;local items=set.items or {}
]====]},
 }},
 ['UI/settings_layout.lua']={bytes=15144,hash='d4613b45',edits={
  {from=[====[        for i,entry in ipairs(options.sources or {}) do
            local control=r.sourceButtons[i];if not control then control=addon:CreateWorkbenchButton(r.frame,'',74);r.sourceButtons[i]=control end
            control:SetText(entry.text);control:SetSelected(entry.value==options.source);control:Show()
            addon:SetUIScript(control,'OnClick',self:Guard(function() if options.requestSource then options.requestSource(entry.value) elseif self:FlushEdits() then options.chooseSource(entry.value) end end))
        end
        for i=#(options.sources or {})+1,#r.sourceButtons do r.sourceButtons[i]:Hide() end
        if options.categories then
]====],to=[====[        for i,entry in ipairs(options.sources or {}) do
            local control=r.sourceButtons[i];if not control then control=addon:CreateWorkbenchButton(r.frame,'',74);r.sourceButtons[i]=control end
            control:SetText(entry.text);control:SetSelected(entry.value==options.source);control:Show()
            addon:SetUIScript(control,'OnClick',self:Guard(function() if self:FlushEdits() then options.chooseSource(entry.value) end end))
        end
        for i=#(options.sources or {})+1,#r.sourceButtons do r.sourceButtons[i]:Hide() end
        if options.categories then
]====]},
 }},
 ['UI/settings_draft.lua']={bytes=6320,hash='a890ad3b',edits={
  {from=[====[        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key]) end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
]====],to=[====[        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key]) end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
]====]},
  {from=[====[    function p:SaveSettingsDraft()
        if not self.draft then return true end
        if not self:Valid(self.generation) then return false end
        local stockUnchanged=false
        for _,key in ipairs(self.transactionKeys.profile or {}) do if key=='stockTargets' then
            if not addon.StockTargets.Validate(self.draft.profile.stockTargets) then self:Message(L['Complete the stock target settings before applying.']);return false end
            stockUnchanged=equal(self.draft.profile.stockTargets,self.draftBaseline.profile.stockTargets)
            if not stockUnchanged and not addon.StockSettings.CheckProfile(addon.db.profile) then self:Message(L['Invalid stock targets; data preserved.']);return false end
        end end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(addon.db[scope] and addon.db[scope][key],self.draftBaseline[scope][key]) then self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return false end
        end end
        local ownsEffects=false;for _,key in ipairs(self.transactionKeys.global or {}) do if key=='effects' then ownsEffects=true end end
        if ownsEffects and self.draft.global.effects then
]====],to=[====[    function p:SaveSettingsDraft()
        if not self.draft then return true end
        if not self:Valid(self.generation) then return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not equal(addon.db[scope] and addon.db[scope][key],self.draftBaseline[scope][key]) then self:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return false end
        end end
        local ownsEffects=false;for _,key in ipairs(self.transactionKeys.global or {}) do if key=='effects' then ownsEffects=true end end
        if ownsEffects and self.draft.global.effects then
]====]},
  {from=[====[    function p:SettingsData()
        if not self.transactionKeys then return addon.db end
        if not self.draft then
            if self.settingsKey=='ItemSets' then
                local keys={};for _,key in ipairs(self.transactionKeys.profile or {}) do if key~='stockTargets' then keys[#keys+1]=key end end
                self.stockEditable=addon.StockSettings.CheckProfile(addon.db.profile)==true
                if self.stockEditable then keys[#keys+1]='stockTargets' end;self.transactionKeys.profile=keys
            end
            self.draft={profile=addon:CopySettingsData(addon.StockSettings.DraftProfile(addon.db.profile)),global=addon:CopySettingsData(addon.db.global),char=addon:CopySettingsData(addon.db.char or {})};self.draftBaseline={};self.draftEffects={}
            for scope,keys in pairs(self.transactionKeys) do self.draftBaseline[scope]={};for _,key in ipairs(keys) do self.draftBaseline[scope][key]=addon:CopySettingsData(addon.db[scope] and addon.db[scope][key]) end end
        end
]====],to=[====[    function p:SettingsData()
        if not self.transactionKeys then return addon.db end
        if not self.draft then
            self.draft={profile=addon:CopySettingsData(addon.StockSettings.DraftProfile(addon.db.profile)),global=addon:CopySettingsData(addon.db.global),char=addon:CopySettingsData(addon.db.char or {})};self.draftBaseline={};self.draftEffects={}
            for scope,keys in pairs(self.transactionKeys) do self.draftBaseline[scope]={};for _,key in ipairs(keys) do self.draftBaseline[scope][key]=addon:CopySettingsData(addon.db[scope] and addon.db[scope][key]) end end
        end
]====]},
  {from=[====[    end
    function p:DiscardSettingsDraft()
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newStockTarget=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true
    end
    function p:ApplyCreation()
        if not self:FlushEdits() or not self.creationApply then return false end
]====],to=[====[    end
    function p:DiscardSettingsDraft()
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true
    end
    function p:ApplyCreation()
        if not self:FlushEdits() or not self.creationApply then return false end
]====]},
  {from=[====[        return not self.emptyDismissed and not (self.draftBaseline and self.draftBaseline[scope] and next(self.draftBaseline[scope][key] or {}))
    end
    function p:CreationState()
        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,stockTarget=self.newStockTarget,itemSetName=self.newItemSetName,categoryName=self.newGroupName}
    end
    function p:IsCreationDirty()
        if not self.creationUsedForNew then return false end
]====],to=[====[        return not self.emptyDismissed and not (self.draftBaseline and self.draftBaseline[scope] and next(self.draftBaseline[scope][key] or {}))
    end
    function p:CreationState()
        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,itemSetName=self.newItemSetName,categoryName=self.newGroupName}
    end
    function p:IsCreationDirty()
        if not self.creationUsedForNew then return false end
]====]},
 }},
 ['UI/settings_history.lua']={bytes=3524,hash='56831bff',edits={
  {from=[====[        if not self:FlushEdits() then return end
        local from=redo and self.historyRedo or self.historyUndo;local to=redo and self.historyUndo or self.historyRedo
        if not from or #from==0 then return end
        to[#to+1]=self:HistorySnapshot();local value=table.remove(from);self.draft.profile.itemsets=addon:CopySettingsData(value.profile);self.draft.global.itemsets=addon:CopySettingsData(value.global);self.draftEffects=addon:CopySettingsData(value.effects);self.selection=value.selection;self.stockSelection=value.stockSelection;self.draft.profile.stockTargets=addon:CopySettingsData(value.stock);self.historyEpoch=(self.historyEpoch or 0)+1;self:Draw()
    end
    function p:HistoryActions()
        local y=self:Row(nil,28)
]====],to=[====[        if not self:FlushEdits() then return end
        local from=redo and self.historyRedo or self.historyUndo;local to=redo and self.historyUndo or self.historyRedo
        if not from or #from==0 then return end
        to[#to+1]=self:HistorySnapshot();local value=table.remove(from);self.draft.profile.itemsets=addon:CopySettingsData(value.profile);self.draft.global.itemsets=addon:CopySettingsData(value.global);self.draftEffects=addon:CopySettingsData(value.effects);self.selection=value.selection;self.historyEpoch=(self.historyEpoch or 0)+1;self:Draw()
    end
    function p:HistoryActions()
        local y=self:Row(nil,28)
]====]},
  {from=[====[    function p:ClearSettingsHistory() self.historyEpoch=(self.historyEpoch or 0)+1;self.historyUndo={};self.historyRedo={};self.historyBytes=0 end
    function p:HistorySnapshot()
        if not self.historyEnabled or not self.draft then return end
        local stock=self.stockEditable and self.draft.profile.stockTargets or nil;if not addon.StockTargets.Validate(stock) then stock=nil end
        return addon:CopySettingsData({profile=self.draft.profile.itemsets,global=self.draft.global.itemsets,effects=self.draftEffects,selection=self.selection,stock=stock,stockSelection=self.stockSelection})
    end
    function p:UpdateHistoryActions()
        if self.fields.undo then if #(self.historyUndo or {})>0 then self.fields.undo:Enable() else self.fields.undo:Disable() end end
]====],to=[====[    function p:ClearSettingsHistory() self.historyEpoch=(self.historyEpoch or 0)+1;self.historyUndo={};self.historyRedo={};self.historyBytes=0 end
    function p:HistorySnapshot()
        if not self.historyEnabled or not self.draft then return end
        return addon:CopySettingsData({profile=self.draft.profile.itemsets,global=self.draft.global.itemsets,effects=self.draftEffects,selection=self.selection})
    end
    function p:UpdateHistoryActions()
        if self.fields.undo then if #(self.historyUndo or {})>0 then self.fields.undo:Enable() else self.fields.undo:Disable() end end
]====]},
 }},
 ['UI/settings_unsaved.lua']={bytes=12278,hash='424b31f6',edits={
  {from=[====[            self.roster.unsavedByValue={};self.roster.unsavedState=nil
            if self.draftBaseline then
                self.roster.unsavedState={before=rosterLookup(self,self.draftBaseline),current=rosterLookup(self,self.draft),pending=pending,
                    selected=self.settingsKey=='ItemSets' and self.itemSettingsSource=='stock' and self.stockSelection or self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection,
                    announces=self.draft and self.draft.profile.announces or addon.db.profile.announces or {}}
            end
            self:RefreshRosterMarkers()
]====],to=[====[            self.roster.unsavedByValue={};self.roster.unsavedState=nil
            if self.draftBaseline then
                self.roster.unsavedState={before=rosterLookup(self,self.draftBaseline),current=rosterLookup(self,self.draft),pending=pending,
                    selected=self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection,
                    announces=self.draft and self.draft.profile.announces or addon.db.profile.announces or {}}
            end
            self:RefreshRosterMarkers()
]====]},
  {from=[====[-- opened after an import. Pending text is compared before it is committed.
function addon:InstallSettingsUnsaved(p)
    p.unsavedDefaults={};p.unsavedBindings={}
    function p:UnsavedIdentity() return table.concat({self.settingsKey or '',self.mode or '',self.settingsKey=='ItemSets' and self.itemSettingsSource or '',self.settingsKey=='ItemSets' and self.itemSettingsSource=='stock' and tostring(self.stockSelection) or '',tostring(self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection or 'general'),self.creating and 'new' or ''},':') end
    function p:BindUnsaved(key,control,value,kind)
        local identity=self:UnsavedIdentity();local defaults=self.unsavedDefaults[identity] or {};self.unsavedDefaults[identity]=defaults
        local before=context(self,self.draftBaseline,self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or nil)
]====],to=[====[-- opened after an import. Pending text is compared before it is committed.
function addon:InstallSettingsUnsaved(p)
    p.unsavedDefaults={};p.unsavedBindings={}
    function p:UnsavedIdentity() return table.concat({self.settingsKey or '',self.mode or '',tostring(self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or self.selection or 'general'),self.creating and 'new' or ''},':') end
    function p:BindUnsaved(key,control,value,kind)
        local identity=self:UnsavedIdentity();local defaults=self.unsavedDefaults[identity] or {};self.unsavedDefaults[identity]=defaults
        local before=context(self,self.draftBaseline,self.mode=='categories' and self.categorySelection or self.settingsKey=='Conditions' and self.condition or nil)
]====]},
  {from=[====[local function find(list,id) for _,value in ipairs(list or {}) do if value.id==id then return value end end end
local function contains(list,value) for _,entry in ipairs(list or {}) do if entry==value then return true end end;return false end
local function context(p,store,id)
    local stockID=id or p.stockSelection
    store=store or {};local profile,global=store.profile or {},store.global or {};id=id or (p.mode=='categories' and p.categorySelection or p.settingsKey=='Conditions' and p.condition or p.selection)
    if p.settingsKey=='ItemSets' and p.itemSettingsSource=='stock' then return (profile.stockTargets or {})[stockID] end
    if p.settingsKey=='General' then local result=addon:CopySettingsData(profile);result.minimap=not (profile.minimap or {}).hide;for i,v in ipairs((store.char or {}).specs or {}) do result['spec'..i]=v end;return result end
    if p.settingsKey=='Integrations' then return profile end
    if p.settingsKey=='Effects' then return (global.effects or {})[id] end
]====],to=[====[local function find(list,id) for _,value in ipairs(list or {}) do if value.id==id then return value end end end
local function contains(list,value) for _,entry in ipairs(list or {}) do if entry==value then return true end end;return false end
local function context(p,store,id)
    store=store or {};local profile,global=store.profile or {},store.global or {};id=id or (p.mode=='categories' and p.categorySelection or p.settingsKey=='Conditions' and p.condition or p.selection)
    if p.settingsKey=='General' then local result=addon:CopySettingsData(profile);result.minimap=not (profile.minimap or {}).hide;for i,v in ipairs((store.char or {}).specs or {}) do result['spec'..i]=v end;return result end
    if p.settingsKey=='Integrations' then return profile end
    if p.settingsKey=='Effects' then return (global.effects or {})[id] end
]====]},
 }},
 ['UI/settings_collections.lua']={bytes=7083,hash='460760cb',edits={
  {from=[====[    p:RequestLeave(function()
        if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
        p:DiscardSettingsDraft();p:Draw()
        local stockUnrelated=p.settingsKey=='ItemSets'
        local function ownsKey(scope,key)return not (stockUnrelated and scope=='profile' and key=='stockTargets')end
        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do if ownsKey(scope,key) then expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end end
        local conditionRevision,functionRevision=self.conditionRegistryVersion,self.functionRegistryVersion
        p:Confirm(warning..' '..L['This cannot be undone.'],function()
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before applying these settings.']);return end
            for scope,keys in pairs(p.transactionKeys or {}) do for _,key in ipairs(keys) do
                if ownsKey(scope,key) and not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            end end
            if self.conditionRegistryVersion~=conditionRevision or self.functionRegistryVersion~=functionRevision then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            local called,ok,why=pcall(remove)
]====],to=[====[    p:RequestLeave(function()
        if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
        p:DiscardSettingsDraft();p:Draw()
        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end
        local conditionRevision,functionRevision=self.conditionRegistryVersion,self.functionRegistryVersion
        p:Confirm(warning..' '..L['This cannot be undone.'],function()
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before applying these settings.']);return end
            for scope,keys in pairs(p.transactionKeys or {}) do for _,key in ipairs(keys) do
                if not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            end end
            if self.conditionRegistryVersion~=conditionRevision or self.functionRegistryVersion~=functionRevision then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            local called,ok,why=pcall(remove)
]====]},
 }},
}
return function(text,path)
 local spec=assert(changes[path],'unknown stock editor source path')
 for _,edit in ipairs(spec.edits)do local a,b=text:find(edit.from,1,true);assert(a and not text:find(edit.from,b+1,true),'stock editor inverse source differs');text=text:sub(1,a-1)..edit.to..text:sub(b+1)end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==spec.bytes and string.format('%08x',hash)==spec.hash,'unrelated stock editor source delta')
 return text
end
