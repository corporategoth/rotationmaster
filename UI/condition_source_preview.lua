local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function plainCopy(value)
    local active,nodes,bytes={},0,0
    local function copy(v,depth)
        nodes=nodes+1;if nodes>512 or depth>12 then error('sample-limit',0) end
        local kind=type(v)
        if kind=='string' then bytes=bytes+#v;if #v>4096 or bytes>65536 then error('sample-limit',0) end;return v
        elseif kind=='number' then if v~=v or v==math.huge or v==-math.huge then error('sample-number',0) end;return v
        elseif kind=='boolean' or kind=='nil' then return v
        elseif kind~='table' or getmetatable(v) or active[v] then error('sample-data',0) end
        active[v]=true;local result={};for key,child in pairs(v) do if type(key)~='string' and type(key)~='number' then error('sample-key',0) end;result[copy(key,depth+1)]=copy(child,depth+1) end;active[v]=nil;return result
    end
    local ok,result=pcall(copy,value,0);if ok then return result end
end
local function safeText(value) local ok,text=pcall(tostring,value);return ok and text:sub(1,512) or L['Unavailable'] end
local function commitFields(widget)
    if widget.CommitPending and not widget:CommitPending() then return false end
    for _,child in ipairs(widget.children or {}) do if not commitFields(child) then return false end end;return true
end
local function sample(schema,depth)
    if (depth or 0)>12 then return nil end
    if schema=='number' then return 0 elseif schema=='boolean' then return false elseif schema=='string' then return '' elseif schema=='condition' then return {type='AND',value={}} elseif schema=='condition[]' then return {} end
    if type(schema)~='table' then return nil end
    if #schema>0 then return sample(schema[1],(depth or 0)+1) end
    local result={};for key,child in pairs(schema) do result[key]=sample(child,(depth or 0)+1) end;return result
end
function addon:ConditionTestValues(owner)
    local why=L['Set values in Test before running or debugging this condition.'];local state=owner and owner.conditionTestState
    if not owner or not owner.OwnerValid or not owner.OwnerValid() or not state or not state.configured or state.profile~=self.db.profile or state.global~=self.db.global or state.key~=owner.model.key then return nil,why end
    local source=owner:PendingSource()
    if not state.source or not self:SettingsDataEqual(source.fields,state.source.fields) or not self:SettingsDataEqual(source.bindings,state.source.bindings) or not self:SettingsDataEqual(source.requiredFields,state.source.requiredFields) then return nil,why end
    local values=plainCopy(state.values);if type(values)~='table' then return nil,why end;return values
end
function addon:ShowConditionSourceTest(owner,options)
    options=options or {};local debugSurface=options.debugSurface==true
    if not owner.OwnerValid or not owner.OwnerValid() or not owner:Flush() then return end
    local checking=not debugSurface
    local source=owner:PendingSource();local key=owner.model.key;local rootOwner=owner.rmConditionOwner
    local cacheKey=debugSurface and 'sourceDebugSurface' or 'sourcePreview';local d=owner[cacheKey]
    if d and d.active then d:Close() end
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent)};owner[cacheKey]=d;d.frame:SetSize(debugSurface and 620 or 760,debugSurface and 430 or 550);d.frame:SetPoint('CENTER');d.frame:SetFrameStrata('FULLSCREEN_DIALOG');d.frame:SetToplevel(true);d.frame:SetClampedToScreen(true);d.frame:EnableMouse(true);self:MakeWindowOpaque(d.frame)
        d.title=d.frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(d.frame,d.title)
        d.info=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.info:SetPoint('TOPLEFT',12,-36);d.info:SetSize(736,40);d.info:SetJustifyH('LEFT');d.info:SetWordWrap(true)
        d.status=d.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.status:SetPoint('TOPLEFT',12,-80);d.status:SetSize(736,36);d.status:SetJustifyH('LEFT');d.status:SetWordWrap(true)
        d.scroll=self:CreateWorkbenchScrollFrame(d.frame);d.scroll:SetPoint('TOPLEFT',12,-122);d.scroll:SetSize(724,356)
        d.close=self:CreateWorkbenchButton(d.frame,L['Close'],100);d.close:SetPoint('BOTTOMRIGHT',-12,28)
        d.xClose=self:CreateWorkbenchIconButton(d.frame,'close',L['Close']);d.xClose:SetPoint('TOPRIGHT',-5,-5)
        d.check=self:CreateWorkbenchButton(d.frame,L['Run test'],110);d.check:SetPoint('TOPLEFT',12,-80);d.run=d.check
        d.live=self:CreateWorkbenchCheckBox(d.frame,L['Live'],140);d.live:SetPoint('TOPLEFT',132,-80)
    end
    d.active=true;d.failed=false;d.serial=(d.serial or 0)+1;local serial=d.serial;d.owned={};d.checking=checking;d.liveEnabled=false;d.elapsed=0;d.lastResult=nil;d.compilationInput=nil;d.definition=nil;d.widgetInput=nil
    local configuredValues=self:ConditionTestValues(owner)
    d.sample=sample(source.fields or {}) or {};local stored=configuredValues or plainCopy((self.db.global.condition_test_values or {})[key]);if type(stored)=='table' then for field,value in pairs(stored) do d.sample[field]=value end end;d.sample.type=key;d.status:SetText('');d.live:SetChecked(false);d.values=d.sample
    if not debugSurface then owner.conditionTestState={values=plainCopy(d.sample),configured=configuredValues~=nil,source=addon:CopySettingsData(source),profile=addon.db.profile,global=addon.db.global,key=key} end
    local function valid() return d.active and d.serial==serial and owner.OwnerValid and owner.OwnerValid() end
    d.valid=valid
    local function alive() return valid() and not d.failed end
    local function report(operation,callback,...)
        if addon.Diagnostics then return addon.Diagnostics:Call({module='condition-source-preview',operation=operation,conditionTag=key,customCode=true},callback,...) end
        return pcall(callback,...)
    end
    function d:ReleaseWidgets()
        local widgets=self.owned or {};self.owned={};self.widgetGeneration=(self.widgetGeneration or 0)+1;local children={}
        for widget,record in pairs(widgets) do
            if record.setCallback then widget.SetCallback=record.setCallback end;if record.addChild then widget.AddChild=record.addChild end
            widget.LayoutFinished=record.layoutFinished
            for _,child in ipairs(widget.children or {}) do children[child]=true end
        end
        for widget in pairs(widgets) do if not children[widget] then report('release-preview',addon.ReleaseConditionWidget,addon,widget) end end
        self.pane=nil;self.helpPane=nil;self.contentPane=nil;self.parent=nil
    end
    function d:Fail()
        self.failed=true;self.liveEnabled=false;self.live:SetChecked(false);self.lastResult=nil;self:ReleaseWidgets();self.status:SetText(L['The preview failed. Use /rm errors for details.']);self.status:SetTextColor(1,.4,.3)
    end
    function d:Persist()
        if debugSurface or not addon:IsCustomConditionIdentifier(key,true) then return end
        local value=plainCopy(self.sample)
        if type(value)~='table' then self.sampleProblem=L['Test values were not saved because they are not bounded plain data.'];return end
        value.type=nil;addon.db.global.condition_test_values=addon.db.global.condition_test_values or {};addon.db.global.condition_test_values[key]=value;self.sampleProblem=nil
    end
    function d:Configure()
        if debugSurface then return false end
        local values=plainCopy(self.sample);local sourceNow=owner:PendingSource()
        owner.conditionTestState={values=values,configured=type(values)=='table',source=addon:CopySettingsData(sourceNow),profile=addon.db.profile,global=addon.db.global,key=owner.model.key}
        if type(values)~='table' then self.sampleProblem=L['Test values were not saved because they are not bounded plain data.'];return false end
        self:Persist();return true
    end
    function d:Guard(widget)
        if self.owned[widget] then return end
        local record={setCallback=widget.SetCallback,addChild=widget.AddChild,layoutFinished=widget.LayoutFinished,generation=self.widgetGeneration};self.owned[widget]=record
        local function attached() return alive() and d.widgetGeneration==record.generation and d.owned[widget]==record end
        local function guarded(callback)
            return function(...) if attached() then return d:Invoke('preview-input',callback,...) end end
        end
        if record.setCallback then
            local callbacks={};for name,callback in pairs(widget.events or widget.callbacks or {}) do callbacks[name]=callback end
            widget.SetCallback=function(control,event,callback) if type(callback)=='function' then return record.setCallback(control,event,guarded(callback)) end end
            for name,callback in pairs(callbacks) do if type(callback)=='function' then widget:SetCallback(name,callback) end end
        end
        if record.addChild then widget.AddChild=function(control,child,...) if not attached() then return end;d:Guard(child);return record.addChild(control,child,...) end end
        for _,child in ipairs(widget.children or {}) do self:Guard(child) end
    end
    function d:Invoke(operation,callback,...)
        if not alive() then return end
        local before=operation=='preview-input' and plainCopy(self.sample)
        -- Track synchronous allocations as well as attached children so an
        -- exception between Create and AddChild cannot leak a native control.
        local ok,result,reason=addon:WithConditionWidgetObservation(function(widget) d:Guard(widget) end,
            function(fn,...) return report(operation,fn,...) end,callback,...)
        if not ok then self:Fail();return nil end
        local after=operation=='preview-input' and plainCopy(self.sample)
        if operation=='preview-input' and self.checking and (not after or not addon:SettingsDataEqual(before,after)) then self:Configure();self.lastResult=nil;self.pendingTest=true;self.status:SetText(L['Test values changed. Updating results.']..(self.sampleProblem and '\n'..self.sampleProblem or ''));self.status:SetTextColor(1,.8,.4) end
        return result,reason
    end
    function d:Close()
        if not self.active then return end
        if self.checking and valid() and self.pane and not self.failed then
            local ok,committed=report('commit-test-fields',commitFields,self.pane)
            if not ok or not committed then owner.conditionTestState=nil end
        end
        self.active=false;self.liveEnabled=false;self.pendingTest=nil;self.live:SetChecked(false);self.elapsed=0;self.suspended=nil;self:ReleaseWidgets();self.frame:Hide();addon:SetUIScript(self.frame,'OnUpdate',nil)
        local onClose=self.onClose;self.onClose=nil
        self.definition=nil;self.compilationInput=nil;self.widgetInput=nil;self.lastResult=nil;self.sample=nil;self.values=nil
        if rootOwner then rootOwner.widgets[self]=nil end
        if owner.OwnerValid and owner.OwnerValid() then owner:Show() end
        if onClose then report('close-test-surface',onClose,self) end
    end
    function d:Hide() self:Close() end
    d.chrome:SetContext(debugSurface and (options.callback=='help' and L['Help preview'] or L['Fields UI preview']) or L['Test condition'],L['Test'],source.description)
    d.info:SetText(debugSurface and L['Rendered output appears here when the callback runs or steps through widget creation.'] or L['Choose test values in Fields UI, then Run test to validate and evaluate. Help is shown below the fields. Opening Test does not evaluate defaults. Live is opt-in.'])
    d.info:SetWidth(d.frame:GetWidth()-24);d.status:SetWidth(d.frame:GetWidth()-24);d.scroll:SetWidth(d.frame:GetWidth()-36)
    d.status:ClearAllPoints();d.scroll:ClearAllPoints()
    if checking then d.check:Show();d.live:Show();d.status:SetPoint('TOPLEFT',12,-112);d.status:SetHeight(52);d.scroll:SetPoint('TOPLEFT',12,-172);d.scroll:SetHeight(306)
    else d.check:Hide();d.live:Hide();d.status:SetPoint('TOPLEFT',12,-80);d.status:SetHeight(20);d.scroll:SetPoint('TOPLEFT',12,-104);d.scroll:SetHeight(d.frame:GetHeight()-176) end
    local top={userdata={funcs={print=function() return '' end}}}
    function top:GetUserData(name) if name=='root' then return d.sample elseif name=='spec' then return addon.currentSpec or 0 elseif name=='index' then return 0 end;return self.userdata[name] end
    function top:SetUserData(name,value) if alive() then self.userdata[name]=value end end
    function top:SetStatusText(text) if alive() then d.status:SetText(type(text)=='string' and text or '') end end
    function top:SetCallback(event,callback) if alive() then self.userdata[event]=callback end end
    function top:Hide() if alive() then d.suspended=true;d.frame:Hide() end end
    function top:Show() if alive() then d.suspended=nil;d.frame:Show() end end
    top.rmCompactRefresh=function() if alive() and d.pane and d.pane.DoLayout then d.pane:DoLayout();d.scroll:UpdateWorkbenchScroll() end end
    function d:Render(current,definition)
        self:ReleaseWidgets();self.failed=false
        return self:Invoke('render-test',function()
        local width=d.frame:GetWidth()-60
        local content=addon:CreateConditionGroup();d.contentPane=content;content:SetLayout('List');content:SetFullWidth(true);content:SetWidth(width);content.frame:SetParent(d.scroll);content.frame:ClearAllPoints();content.frame:SetPoint('TOPLEFT');content.frame:SetWidth(width);content:SetUserData('top',top)
        -- This scroll root bypasses AddChild, which normally shows native children.
        -- A reused group remains hidden after Release until shown explicitly.
        content.frame:Show()
        content.LayoutFinished=function(_,_,height) if alive() and type(height)=='number' then content.frame:SetHeight(math.max(1,math.min(20000,height)));d.scroll:UpdateWorkbenchScroll() end end
        d.scroll:SetScrollChild(content.frame)
        if debugSurface then d.parent=content;d.pane=content;return end
        for _,callback in ipairs({'widget','help'}) do
            content:AddChild(addon.help_funcs.CreateText(callback=='widget' and L['Fields UI'] or L['Help']))
            local pane=addon:CreateConditionGroup();if callback=='widget' then d.pane=pane else d.helpPane=pane end;pane:SetLayout('List');pane:SetFullWidth(true);pane:SetWidth(width);pane.frame:SetWidth(width);pane:SetUserData('top',top);content:AddChild(pane)
            local fn=definition and definition[callback]
            if not fn then local chunk,why=addon:CompileCustomConditionCallback(key,callback,current[callback],current.bindings,current.parameters);if not chunk then error(why,0) end;fn=chunk()(addon,L) end
            if callback=='widget' then fn(pane,addon.currentSpec or 0,d.sample) else fn(pane) end
            addon:configure_frame(pane);if pane.DoLayout then pane:DoLayout() end
        end
        if content.DoLayout then content:DoLayout() end;d.scroll:UpdateWorkbenchScroll()
        end)
    end
    function d:ShowResult(accepted,status,matched,reason)
        self.lastResult={valid=not not accepted,status=status,result=matched,reason=reason};self:Configure()
        local evaluation=status=='match' and L['True'] or status=='no-match' and L['False'] or status=='invalid' and L['Skipped: invalid test values'] or L['Unavailable']..': '..safeText(reason)
        local validation=accepted and L['Passed'] or status=='unavailable' and L['Unavailable'] or L['Failed']
        self.status:SetText(string.format(L['Validation: %s'],validation)..'\n'..string.format(L['Evaluation: %s'],evaluation)..(self.sampleProblem and '\n'..self.sampleProblem or ''));local available=status=='match' or status=='no-match';self.status:SetTextColor(available and .4 or 1,available and .9 or .6,.4)
    end
    function d:Check(automatic)
        if not valid() or not self.frame:IsShown() or not self.checking then return end
        self.failed=false;self.lastResult=nil
        if not owner:Flush() then self.status:SetText(L['Complete the source fields before checking.']);return end
        if self.pane and not commitFields(self.pane) then self.status:SetText(L['Complete the highlighted test inputs before testing.']);return end
        self.pendingTest=nil
        if self.failed then return end
        local current=owner:PendingSource();local input={source=current,key=key,revision=addon.functionRegistryVersion or 0}
        if not addon:SettingsDataEqual(input,self.compilationInput) then
            self.compilationInput=addon:CopySettingsData(input);self.definition=nil
            local candidate=addon:CopySettingsData(current);candidate.disabled=false
            self.definition=self:Invoke('compile-check',addon.CompileCustomCondition,addon,addon:IsCustomConditionIdentifier(key,true) and key or 'PREVIEW',candidate,false)
        end
        local definition=self.definition
        if not definition then self:ReleaseWidgets();self.status:SetText(L['The current source could not be compiled. Fix it before testing again.']);self.status:SetTextColor(1,.4,.3);return end
        -- Every callback resolves its declared bindings. An unavailable graph
        -- therefore cannot safely render its widget before this check either.
        if definition.functionUnavailable then self:ReleaseWidgets();self.widgetInput=nil;self:ShowResult(false,'unavailable',nil,definition.functionUnavailable);return end
        local widgetInput={code=current.widget,help=current.help,fields=current.fields,bindings=current.bindings,parameters=current.parameters,revision=input.revision}
        if not addon:SettingsDataEqual(widgetInput,self.widgetInput) or not self.pane then
            self.widgetInput=addon:CopySettingsData(widgetInput)
            local defaults=sample(current.fields or {}) or {};for field,value in pairs(defaults) do if self.sample[field]==nil then self.sample[field]=value end end
            self:Render(current,definition);if self.failed then return end
        end
        if automatic then if not addon:ConditionTestValues(owner) then self.status:SetText(L['Set values in Test before running or debugging this condition.']);return end
        elseif not self:Configure() then self.status:SetText(self.sampleProblem);return end
        local accepted,validationReason
        if definition.functionUnavailable then validationReason=definition.functionUnavailable else accepted,validationReason=self:Invoke('check-valid',definition.valid,addon.currentSpec or 0,self.sample) end
        if self.failed then return end
        local matched,reason,status
        if not accepted then status=definition.functionUnavailable and 'unavailable' or 'invalid';reason=validationReason or 'invalid-condition-fields'
        else
            matched,reason=self:Invoke('check-evaluate',definition.evaluate,self.sample,{},GetTime and GetTime() or 0)
            if self.failed then return end
            status=matched==nil and reason~=nil and 'unavailable' or matched and 'match' or 'no-match'
        end
        self:ShowResult(accepted,status,matched,reason)
    end
    d.frame:ClearAllPoints();if debugSurface then d.frame:SetPoint('TOPLEFT',owner.frame,'TOPRIGHT',8,0) else d.frame:SetPoint('CENTER') end
    d.frame:SetFrameLevel(owner.frame:GetFrameLevel()+20);d.frame:Show();if not debugSurface then owner:HideForChild() end;if rootOwner then rootOwner.widgets[d]=true end
    local available,unavailable=addon:AreFunctionBindingsAvailable(source.bindings)
    if debugSurface or available then
        d:Render(source)
        if not debugSurface and d.pane and not d.failed then d.widgetInput=addon:CopySettingsData({code=source.widget,help=source.help,fields=source.fields,bindings=source.bindings,parameters=source.parameters,revision=addon.functionRegistryVersion or 0}) end
    else d.status:SetText(L['Unavailable']..': '..safeText(unavailable)) end
    addon:SetUIScript(d.check,'OnClick',function() d:Check() end)
    addon:SetUIScript(d.live,'OnClick',function() if valid() and d.checking then d.liveEnabled=not d.liveEnabled;d.elapsed=0;d.live:SetChecked(d.liveEnabled) end end)
    addon:SetUIScript(d.close,'OnClick',function() d:Close() end);addon:SetUIScript(d.xClose,'OnClick',function() d:Close() end)
    addon:SetUIScript(d.frame,'OnHide',function() d.liveEnabled=false;d.live:SetChecked(false);if d.active and not d.suspended then d:Close() end end)
    addon:SetUIScript(d.frame,'OnUpdate',function(_,elapsed)
        if not valid() then d:Close();return end
        if d.pendingTest and d.frame:IsShown() then d.pendingTest=nil;d.elapsed=0;d:Check() end
        if d.liveEnabled and d.frame:IsShown() then d.elapsed=d.elapsed+(tonumber(elapsed) or 0);if d.elapsed>=.5 then d.elapsed=d.elapsed%.5;d:Check(true) end end
    end)
    addon:RegisterWindowForEscape(d);return d
end
function addon:ShowConditionSourcePreview(owner) return self:ShowConditionSourceTest(owner) end
function addon:CreateConditionDebugSurface(owner,callback) return self:ShowConditionSourceTest(owner,{debugSurface=true,callback=callback}) end
