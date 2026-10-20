local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:SettingsDataEqual(a,b) return equal(a,b) end
function addon:CopySettingsData(value,seen)
    if type(value)~='table' then return value end;seen=seen or {};if seen[value] then return seen[value] end
    local copy={};seen[value]=copy;for key,child in pairs(value) do copy[key]=self:CopySettingsData(child,seen) end;return copy
end
function addon:InstallSettingsDraft(p)
    function p:CanAutoCreateCollection(scope,key)
        return not self.emptyDismissed and not (self.draftBaseline and self.draftBaseline[scope] and next(self.draftBaseline[scope][key] or {}))
    end
    function p:CreationState()
        return {effect=self.newEffect,announcement=self.newAnnounce,profileName=self.newProfileName,profileSource=self.profileSource,importProfile=self.importProfile,stockTarget=self.newStockTarget,itemSetName=self.newItemSetName,categoryName=self.newGroupName}
    end
    function p:IsCreationDirty()
        if not self.creationUsedForNew then return false end
        for _,record in ipairs(self.edits) do if record.dirty then return true end end
        return not equal(self:CreationState(),self.creationBaseline or {})
    end
    function p:DiscardSettingsDraft()
        if self.ClearSettingsHistory then self:ClearSettingsHistory() end
        self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil;self.newEffect=nil;self.newAnnounce=nil;self.newProfileName=nil;self.importProfile=nil;self.profileSource=nil;self.newStockTarget=nil;self.newItemSetName=nil;self.newGroupName=nil;self.creating=false;self.creatingCategory=false;self.creationBaseline=nil;self.creationApply=nil;self.emptyDismissed=true
    end
    function p:ApplyCreation()
        if not self:FlushEdits() or not self.creationApply then return false end
        local apply=self.creationApply;apply()
        if self.creationUsedForNew then return false end
        if self.transactionKeys and not self:SaveSettingsDraft() then return false end
        self.creationBaseline=nil;self:Draw();return true
    end
    function p:SettingsData()
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
        return self.draft
    end
    function p:RunSettingsEffect(key,callback)
        if self.transactionKeys then self.draftEffects[key]=callback else callback() end
    end
    function p:IsSettingsDraftDirty()
        if not self.draft then return false end
        for _,record in ipairs(self.edits) do if record.dirty then return true end end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do if not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then return true end end end;return false
    end
    function p:SaveSettingsDraft()
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
            local names={};for id,effect in pairs(self.draft.global.effects) do
                if not equal(effect,self.draftBaseline.global.effects and self.draftBaseline.global.effects[id]) and addon.IsValidEffectDefinition and not addon:IsValidEffectDefinition(effect) then self:Message(L['Complete the effect settings before applying.']);return false end
                if effect.name and names[effect.name] then self:Message(L['This name is already in use.']);return false end;if effect.name then names[effect.name]=true end
            end
        end
        if self.transactionKeys.profile then for _,key in ipairs(self.transactionKeys.profile) do if key=='announces' then
            for index,entry in ipairs(self.draft.profile.announces or {}) do if not equal(entry,(self.draftBaseline.profile.announces or {})[index]) and not addon:IsValidAnnouncement(entry) then self:Message(L['Choose an action and complete the announcement before applying.']);return false end end
        end end end
        if InCombatLockdown and InCombatLockdown() then self:Message(L['Leave combat before applying these settings.']);return false end
        for scope,keys in pairs(self.transactionKeys) do for _,key in ipairs(keys) do
            if not (scope=='profile' and key=='stockTargets' and stockUnchanged) and not equal(self.draft[scope][key],self.draftBaseline[scope][key]) then addon.db[scope][key]=addon:CopySettingsData(self.draft[scope][key]) end
        end end
        local effects=self.draftEffects;if self.ClearSettingsHistory then self:ClearSettingsHistory() end;self.draft=nil;self.draftBaseline=nil;self.draftEffects=nil
        for _,callback in pairs(effects) do callback() end
        if addon.RemoveAllCurrentGlows then addon:RemoveAllCurrentGlows() end
        if addon.ButtonFetch then addon:ButtonFetch() end
        return true
    end
    function p:DraftActions()
        if not self.transactionKeys or self.creationUsed then return end
        self:CreationActions(function() if self:SaveSettingsDraft() then self:Draw() end end,function() self:DiscardSettingsDraft();self:Draw() end,true)
        if self:IsSettingsDraftDirty() then self.fields.apply:Enable() else self.fields.apply:Disable() end;self.creationUsedForNew=false
    end
end
