local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local function size(value)
    if type(value)=='string' then return #value+32 end;if type(value)~='table' then return 16 end
    local n=64;for key,child in pairs(value) do n=n+size(key)+size(child) end;return n
end
function addon:InstallSettingsHistory(p)
    function p:ClearSettingsHistory() self.historyEpoch=(self.historyEpoch or 0)+1;self.historyUndo={};self.historyRedo={};self.historyBytes=0 end
    function p:HistorySnapshot()
        if not self.historyEnabled or not self.draft then return end
        local stock=self.stockEditable and self.draft.profile.stockTargets or nil;if not addon.StockTargets.Validate(stock) then stock=nil end
        return addon:CopySettingsData({profile=self.draft.profile.itemsets,global=self.draft.global.itemsets,effects=self.draftEffects,selection=self.selection,stock=stock,stockSelection=self.stockSelection})
    end
    function p:UpdateHistoryActions()
        if self.fields.undo then if #(self.historyUndo or {})>0 then self.fields.undo:Enable() else self.fields.undo:Disable() end end
        if self.fields.redo then if #(self.historyRedo or {})>0 then self.fields.redo:Enable() else self.fields.redo:Disable() end end
    end
    function p:WithSettingsHistory(callback,...)
        if not self.historyEnabled or self.historyDepth then return callback(...) end
        local before=self:HistorySnapshot();local epoch=self.historyEpoch;self.historyDepth=true
        local ok,result=pcall(callback,...);self.historyDepth=nil;if not ok then error(result,0) end
        local after=self:HistorySnapshot()
        if before and after and epoch==self.historyEpoch and not equal(before,after) then
            self.historyUndo=self.historyUndo or {};self.historyRedo={};self.historyUndo[#self.historyUndo+1]=before
            local bytes=0;for _,entry in ipairs(self.historyUndo) do bytes=bytes+size(entry) end
            while #self.historyUndo>100 or bytes>8388608 do bytes=bytes-size(table.remove(self.historyUndo,1)) end;self.historyBytes=bytes
        end
        self:UpdateHistoryActions();return result
    end
    function p:TravelSettingsHistory(redo)
        if not self:FlushEdits() then return end
        local from=redo and self.historyRedo or self.historyUndo;local to=redo and self.historyUndo or self.historyRedo
        if not from or #from==0 then return end
        to[#to+1]=self:HistorySnapshot();local value=table.remove(from);self.draft.profile.itemsets=addon:CopySettingsData(value.profile);self.draft.global.itemsets=addon:CopySettingsData(value.global);self.draftEffects=addon:CopySettingsData(value.effects);self.selection=value.selection;self.stockSelection=value.stockSelection;self.draft.profile.stockTargets=addon:CopySettingsData(value.stock);self.historyEpoch=(self.historyEpoch or 0)+1;self:Draw()
    end
    function p:HistoryActions()
        local y=self:Row(nil,28)
        for i,entry in ipairs({{'undo','undo',L['Undo']},{'redo','redo',L['Redo']}}) do
            local button=self:Acquire('historyActions',function() return addon:CreateWorkbenchHistoryButton(self.child,entry[2],entry[3]) end);button:ClearAllPoints();button:SetPoint('TOPLEFT',(i-1)*74,-y);button:SetWidth(68);button:SetText(entry[3]);button.icon:SetTexture(addon:ControlTexture(entry[2]));self.fields[entry[1]]=button
            addon:SetUIScript(button,'OnClick',self:Guard(function() self:TravelSettingsHistory(entry[1]=='redo') end))
        end
        self:UpdateHistoryActions()
    end
end
