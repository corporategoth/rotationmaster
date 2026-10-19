local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:NewFunctionSource()
    return {name=L['New function'],description=L['Describe what this function does.'],args={},returns={},code='return nil',bindings={}}
end
function addon:FunctionSource(id)
    local custom=(self.db.global.custom_functions or {})[id];if custom then return custom,false end
    local builtin=(self.builtinFunctions or {})[id];if builtin and not builtin.valueBinding then return builtin.source,true end
end
function addon:OpenNewFunction(p,source)
    p:RequestLeave(function()
        if not p.active then return end
        p.functionID=nil;p.newFunctionID='FUNCTION_'..self:uuid():gsub('-','_');p.newFunctionSource=self:CopySettingsData(source or self:NewFunctionSource());p.functionSource='custom';p:Draw()
    end)
end
function addon:ShowFunctionSource(id)
    local source=self:FunctionSource(id);if not source then return end
    local shell=self.configWindow;local pane=shell and shell.pane
    if pane and pane.RequestLeave then
        -- Queue the selection only after navigation is approved. A cancelled
        -- symbol jump must not silently take effect during a later resize.
        pane:RequestLeave(function() self.configFunctionSelection=id;self:ShowConfig('Functions') end);return shell
    end
    self.configFunctionSelection=id;return self:ShowConfig('Functions')
end
function addon:BuildFunctionSettings(p)
    self:InstallInlineFunctionNavigation(p)
    if self.configFunctionSelection then p.functionID=self.configFunctionSelection;p.functionSource='all';p.newFunctionID=nil;p.newFunctionSource=nil;self.configFunctionSelection=nil end
    local custom=self.db.global.custom_functions or {};local entries={};local selected
    local function add(id,source,builtin)
        if p.functionSource=='builtin' and not builtin or p.functionSource=='custom' and builtin then return end
        local available,why=self:FunctionAvailable(id)
        entries[#entries+1]={value=id,text=source.name or id,search=id..' '..(source.description or ''),custom=not builtin,invalid=not available,disabled=source.disabled==true,validationMessage=not available and string.format(L['Function unavailable: %s'],why) or nil}
        if p.functionID==id then selected=true end
    end
    p.functionSource=p.functionSource or 'all'
    for id,record in pairs(self.builtinFunctions or {}) do if not record.valueBinding then add(id,record.source,true) end end
    for id,source in pairs(custom) do add(id,source,false) end
    table.sort(entries,function(a,b) if a.text==b.text then return a.value<b.value end;return a.text<b.text end)
    if not selected and not p.newFunctionSource then p.functionID=entries[1] and entries[1].value end
    p:UseRoster(entries,p.functionID,function(id) p:RequestLeave(function() p.functionID=id;p.newFunctionSource=nil;p.newFunctionID=nil;p:Draw() end) end,{
        newText=L['New'],new=function() self:OpenNewFunction(p) end,
        sources={{value='all',text=L['All']},{value='builtin',text=L['Built In']},{value='custom',text=L['Custom']}},source=p.functionSource,
        chooseSource=function(value) p:RequestLeave(function() p.functionSource=value;p.functionID=nil;p.newFunctionSource=nil;p.newFunctionID=nil;p:Draw() end) end})
    local source,readOnly=self:FunctionSource(p.functionID)
    local comparisons={}
    for id,record in pairs(self.builtinFunctions or {}) do if id~=p.functionID and not record.valueBinding then comparisons[#comparisons+1]={value=id,text=record.source.name or id} end end
    for id,value in pairs(custom) do if id~=p.functionID then comparisons[#comparisons+1]={value=id,text=value.name or id} end end
    table.sort(comparisons,function(a,b) if a.text==b.text then return a.value<b.value end;return a.text<b.text end)
    p:SetRosterActions({{key='new_function',text=L['New'],icon='plus',action=p.roster.options.new},
        {key='duplicate_function',text=L['Duplicate'],icon='copy',enabled=source~=nil,action=function() local copy=self:CopySettingsData(source);copy.name=string.format(L['Copy of %s'],copy.name or p.functionID);self:OpenNewFunction(p,copy) end},
        {key='transfer',text=L['Import/Export'],icon='transfer',action=function() if self.ShowFunctionBundleTransfer then self:ShowFunctionBundleTransfer(p,p.functionID,p.inlineFunction and p.inlineFunction:PendingSource() or source) end end},
        {key='compare',text=L['Compare'],icon='compare',enabled=source~=nil and #comparisons>0,action=function()
            local selected=p.functionID
            p:ShowChoices(p.fields.compare,comparisons,function(id)
                local other=self:FunctionSource(id);if id~=selected and source and other then self:ShowCollectionComparison(p,'profile',{name=source.name or selected,profile=source},{name=other.name or id,profile=other}) end
            end)
        end}})
    if p.newFunctionSource or source then return self:BuildInlineFunction(p,p.newFunctionID or p.functionID,p.newFunctionSource or source,readOnly and not p.newFunctionSource) end
    p:Heading(L['Functions']);p:Text(L['Add a function or duplicate a packaged helper to edit its source.'])
end
