local addon_name,addon=...
local data=addon.RotationData

-- Build the candidate order without evaluating switch conditions. Missing
-- priorities retain the historical alphabetical order; IDs break equal names.
function addon:GetOrderedAutoSwitchRotations(spec,rotations)
    local candidates={}
    for id,body in pairs(rotations) do
        local priority=type(body)=='table' and data.GetRotationPriority(body.priority)
        if type(id)=='string' and id~=DEFAULT and priority and not body.disabled
            and type(body.switch)=='table' and self:usefulCondition(body.switch)
            and self:validateCondition(body.switch,spec) and self:rotationValidConditions(body,spec) then
            local tie=id;local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
            if scoped then local ref=scoped:Resolve(spec,id);if ref then if ref.kind=='builtin' then tie='builtin:'..ref.id else local a=ref.address;tie=table.concat({a.scope,a.class,a.owner,tostring(a.spec),a.id},'\0') end end end
            candidates[#candidates+1]={id=id,tie=tie,priority=priority,name=type(body.name)=='string' and body.name or id,
                builtin=self:IsDefaultRuntimeRotation(spec,id)==true}
        end
    end
    table.sort(candidates,function(left,right)
        if left.builtin~=right.builtin then return not left.builtin end
        if left.priority~=right.priority then return left.priority>right.priority end
        if left.name~=right.name then return left.name<right.name end
        return left.tie<right.tie
    end)
    local ordered={};for _,entry in ipairs(candidates) do ordered[#ordered+1]=entry.id end
    return ordered
end

-- BEGIN ROTATION ELIGIBILITY EXPLANATIONS
-- Plain words for why a rotation cannot be selected. Validation already
-- records every blocking issue (each diagnostic is an error, or an
-- unsupported or unresolved warning); this names the first one by where it is
-- (switch, rotation step, cooldown, branch child) and what is wrong, and the
-- runtime refusals that are not validation (disabled, another specialization,
-- another action bar). Only called on a refusal, a command or a hover; never
-- while polling.
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local issueText={
    ['unknown-condition']=L['uses a condition this client does not have (%s)'],
    ['disabled-condition']=L['uses a condition that is disabled in Settings (%s)'],
    ['unavailable-function']=L['uses a custom condition whose function is unavailable (%s)'],
    ['missing-itemset']=L['uses an item set that no longer exists'],
    ['missing-effect']=L['uses a highlight effect that no longer exists'],
    ['unknown-field']=L['has a setting this version does not understand (%s)'],
    ['missing-field']=L['is missing a required setting (%s)'],
    ['invalid-field-type']=L['has an invalid setting (%s)'],
    ['invalid-field-value']=L['has an invalid setting (%s)'],
    ['empty-item-list']=L['has no items'],
    ['assisted-in-optional-list']=L["uses Blizzard's suggestion, which only works in the rotation list"],
    ['unknown-action-type']=L['has an action type this version does not understand'],
    ['unexpected-assisted-action']=L['has a setting this version does not understand (%s)'],
    ['unexpected-stop-option']=L['has a setting this version does not understand (%s)'],
    ['invalid-priority']=L['has an invalid switch priority'],
    ['invalid-handle']=L['has an invalid handle'],
}
local refusalText={
    ['disabled']=L['it is disabled'],
    ['disabled-dependency']=L['it uses a condition, item set or function that is disabled'],
    ['action-context-mismatch']=L['you are using another action bar'],
    ['inactive-fallback']=L['a fallback saved for this character takes precedence'],
    ['class-mismatch']=L['it is for another class'],
    ['edition-mismatch']=L['it is for another WoW edition'],
    ['specialization-mismatch']=L['it is for another specialization'],
    ['level-mismatch']=L['your level is outside its level range'],
    ['missing-level']=L['your level is unavailable'],
    ['build-mismatch']=L['it is for another game build'],
    ['missing-build']=L['the game build is unavailable'],
    ['expansion-mismatch']=L['it is for another expansion'],
    ['ruleset-mismatch']=L['it is for another season or game rules'],
    ['unsupported-context-selector']=L['it needs context Rotation Master cannot read yet'],
}
-- Walk a validation path ("$.body.rotation[2].onTrue[1].conditions.type").
local function tokens(path)
    local list={};local rest=type(path)=='string' and path:match('^%$%.body(.*)$')
    if not rest then return nil end
    for name,index in rest:gmatch('%.?([%a_][%w_]*)%[?(%d*)%]?') do
        list[#list+1]=name;if index~='' then list[#list+1]=tonumber(index) end
    end
    return list
end
local function stepName(step)
    if type(step)~='table' then return nil end
    if type(step.name)=='string' and step.name:find('%S') then return step.name end
    if step.type=='branch' then return L['Branch'] elseif step.type=='none' then return L['Stop']
    elseif step.type=='assisted' then return L["Blizzard's suggestion"] elseif step.type=='item' then return L['Item'] end
    if (step.type=='spell' or step.type=='pet' or step.type=='any') and type(step.action)=='number' then
        local info=addon.Platform and addon.Platform.GetSpellInfo and addon.Platform:GetSpellInfo(step.action)
        if type(info)=='table' and type(info.name)=='string' then return info.name end
        return string.format(L['Spell %d'],step.action)
    end
end
-- Where a diagnostic is, in words: "Cooldown 2 (Touch of Death)",
-- "Rotation step 1 › Yes 2 (Stop)", "Switch condition". body is optional.
function addon:DescribeRotationIssueLocation(path,body)
    local list=tokens(path);if not list then return L['Rotation'] end
    local section=list[1]
    if section=='switch' then return L['Switch condition'] end
    if (section~='rotation' and section~='cooldowns') or type(list[2])~='number' then return L['Rotation settings'] end
    local parts={string.format(section=='cooldowns' and L['Cooldown %d'] or L['Rotation step %d'],list[2])}
    local node=type(body)=='table' and type(body[section])=='table' and body[section][list[2]] or nil
    local i=3
    while (list[i]=='onTrue' or list[i]=='onFalse') and type(list[i+1])=='number' do
        parts[#parts+1]=string.format(list[i]=='onTrue' and L['Yes %d'] or L['No %d'],list[i+1])
        node=type(node)=='table' and type(node[list[i]])=='table' and node[list[i]][list[i+1]] or nil
        i=i+2
    end
    local text=table.concat(parts,' › ');local name=stepName(node)
    if name then text=string.format('%s (%s)',text,self.PlainWorkbenchName and self:PlainWorkbenchName(name) or name) end
    return text
end
local function valueAt(body,path)
    local list=tokens(path);if not list then return nil end
    local node=body
    for _,key in ipairs(list) do if type(node)~='table' then return nil end;node=node[key] end
    return node
end
-- One diagnostic in plain words; body (optional) names the step.
function addon:DescribeRotationIssue(problem,body)
    if type(problem)~='table' then return nil end
    local where=self:DescribeRotationIssueLocation(problem.path,body)
    local what=self.DescribeUnsupportedCondition and self:DescribeUnsupportedCondition(problem)
    if not what then
        local template=issueText[problem.code]
        local field=type(problem.path)=='string' and problem.path:match('([%w_]+)%]?$') or ''
        if problem.code=='unknown-condition' or problem.code=='disabled-condition' or problem.code=='unavailable-function' then
            local condition=body and valueAt(body,(problem.path or ''):gsub('%.type$',''))
            local definition=type(condition)=='table' and self.conditionDefinitions and self.conditionDefinitions[condition.type]
            field=type(definition)=='table' and type(definition.description)=='string' and definition.description or type(condition)=='table' and tostring(condition.type) or field
        end
        what=template and string.format(template,field) or string.format(L['has a problem (%s)'],tostring(problem.code))
    end
    return string.format('%s: %s',where,(what:gsub('%.$','')))
end
-- The first issue that stops a body being selected, and its description.
function addon:FirstRotationIssue(body,validation)
    if validation==nil and type(body)=='table' then validation=data.ValidateBody(body,self:GetRotationValidationOptions()) end
    local problem=type(validation)=='table' and type(validation.diagnostics)=='table' and validation.diagnostics[1] or nil
    if not problem then return nil end
    return problem,self:DescribeRotationIssue(problem,body)
end
-- A specialization's name as the editor shows it.
function addon:DescribeRotationSpec(spec)
    if type(self.GetRotationEditorSpecs)=='function' then
        local ok,entries=pcall(self.GetRotationEditorSpecs,self)
        if ok and type(entries)=='table' then for _,entry in ipairs(entries) do if entry.id==spec and type(entry.name)=='string' then return entry.name end end end
    end
    if self.Platform and self.Platform.IsInitialSpecialization and self.Platform:IsInitialSpecialization(spec) then return L['No specialization (levels 1-9)'] end
    local display=self.Platform and self.Platform.GetSpecializationDisplay and self.Platform:GetSpecializationDisplay(spec)
    if type(display)=='table' and type(display.name)=='string' then return display.name end
    if spec==0 then return L['Rotations'] end
    return tostring(spec)
end
-- The specialization RM runs when the Rotations editor does not offer it.
-- On Retail below level 10 no specialization is chosen: GetSpecialization()
-- answers the class's initial spec (an index past the class's count, its own
-- spec ID), RM keys rotations by that ID, and the editor lists only the
-- class's chosen specs, so nothing saved there can run at that level.
function addon:GetUnofferedRotationSpec()
    local spec=self.currentSpec
    if spec==nil or type(self.GetRotationEditorSpecs)~='function' then return nil end
    local ok,entries=pcall(self.GetRotationEditorSpecs,self)
    if not ok or type(entries)~='table' then return nil end
    for _,entry in ipairs(entries) do if entry.id==spec then return nil end end
    local names={};for _,entry in ipairs(entries) do names[#names+1]=entry.name or tostring(entry.id) end
    return spec,names
end
local function otherFallbacks(self,spec)
    local names={}
    if type(self.GetRotationEditorSpecs)~='function' or type(self.ResolveRotationReference)~='function' then return names end
    local ok,entries=pcall(self.GetRotationEditorSpecs,self);if not ok or type(entries)~='table' then return names end
    for _,entry in ipairs(entries) do
        if entry.id~=spec and self:ResolveRotationReference(entry.id,DEFAULT) then names[#names+1]=entry.name or tostring(entry.id) end
    end
    return names
end
-- nil when `value` (a rotation key, or DEFAULT) can be selected now for
-- `spec`; otherwise a sentence saying why, and the refusal code.
function addon:ExplainRotationRefusal(spec,value)
    if spec==nil then return L['your specialization is not available yet'],'specialization-unavailable' end
    local coordinator=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    local body,code
    if coordinator then
        local pass,why=self:AcquireRotationRuntimePass(spec)
        if not pass then return string.format(L['rotations cannot be read (%s)'],tostring(why)),why end
        body,code=pass:Get(value)
    elseif type(self.GetRuntimeRotation)=='function' then body=self:GetRuntimeRotation(spec,value);code=not body and 'rotation-unavailable' or nil
    else return string.format(L['rotations cannot be read (%s)'],'rotation-store-unavailable'),'rotation-store-unavailable' end
    if body then return nil end
    if code=='unknown-rotation' and value==DEFAULT then
        local text=string.format(L['no fallback rotation is saved for %s'],self:DescribeRotationSpec(spec))
        local others=otherFallbacks(self,spec)
        if #others>0 then text=text..' '..string.format(L['(there is one for %s)'],table.concat(others,', ')) end
        if spec==self.currentSpec and self:GetUnofferedRotationSpec() then
            text=text..'; '..string.format(L['you have not chosen a specialization yet, so Rotation Master uses %s, which the Rotations editor does not offer'],self:DescribeRotationSpec(spec))
        end
        return text,code
    end
    if code=='invalid-fallback' or code=='rotation-unavailable' or code=='invalid-or-unsupported' then
        local record,_,validation=nil,nil,nil
        if self.GetRotationRecordSnapshot then record,_,validation=self:GetRotationRecordSnapshot(spec,value) end
        local _,text=self:FirstRotationIssue(record and record.body,validation)
        if text then return text,code end
        return L['it has incomplete or unsupported data'],code
    end
    if code=='disabled' and self.GetDefaultIdForRuntime and self.GetBuiltinSwitch then
        local id=self:GetDefaultIdForRuntime(spec,value)
        local state;if id then local _,found=self:GetBuiltinSwitch(id);state=found end
        if state=='user-disabled' then return L['you switched it off (turn it back on in Rotations)'],code end
        if state=='shipped-disabled' then return L['it ships disabled, an alternative to the recommended one (turn it on in Rotations)'],code end
    end
    return refusalText[code] or string.format(L['it is unavailable (%s)'],tostring(code)),code
end
-- True when `key` can be selected but has no usable switch condition, so
-- automatic switching never picks it (you choose it by hand).
function addon:IsManualOnlyRotation(spec,key)
    local pass=self.AcquireRotationRuntimePass and self:AcquireRotationRuntimePass(spec)
    local body=pass and pass:Get(key)
    if type(body)~='table' then return false end
    return type(body.switch)~='table' or not self:usefulCondition(body.switch)
end
-- A rotation's priority as automatic switching ranks it (nil when unknown).
function addon:GetRotationEffectivePriority(spec,key)
    if key==DEFAULT then return nil end
    local pass=self.AcquireRotationRuntimePass and self:AcquireRotationRuntimePass(spec)
    local body=pass and pass:Get(key)
    if not body and self.GetRuntimeRotation and not pass then body=self:GetRuntimeRotation(spec,key) end
    return type(body)=='table' and data.GetRotationPriority(body.priority) or nil
end
-- Built Ins that would be selectable for `spec` now (applicability, and a
-- switch condition that is not known to fail) but are switched off: every one
-- the player switched off, and, when no Built In for `spec` is on at all, the
-- alternatives that ship off. Menus and commands only.
function addon:GetDisabledApplicableBuiltins(spec)
    if spec==nil or type(self.GetBuiltinStates)~='function' then return {} end
    local rows=self:GetBuiltinStates(spec);local user,shipped,anyOn={},{},false
    for _,row in ipairs(rows) do
        if row.applies then
            local matches=self.SwitchConditionMatchesNow and type(row.body)=='table' and type(row.body.switch)=='table'
                and self:usefulCondition(row.body.switch) and self:SwitchConditionMatchesNow(row.body.switch)
            if matches~=false then
                if row.state=='enabled' then anyOn=true
                elseif row.state=='user-disabled' then user[#user+1]=row
                elseif row.state=='shipped-disabled' then shipped[#shipped+1]=row end
            end
        end
    end
    if not anyOn then for _,row in ipairs(shipped) do user[#user+1]=row end end
    return user
end
-- /rm why: each rotation's eligibility for the current character, with the
-- first blocking issue. Returns the lines.
function addon:GetRotationEligibilityReport()
    local spec=self.currentSpec;local lines={}
    local level=type(UnitLevel)=='function' and UnitLevel('player')
    lines[1]=string.format(L['Specialization: %s (%s), level %s'],spec~=nil and self:DescribeRotationSpec(spec) or L['None'],tostring(spec),tostring(level or '?'))
    local active=self.currentRotation and (self.currentRotation==DEFAULT and DEFAULT or self:GetRotationName(self.currentRotation) or tostring(self.currentRotation))
    lines[2]=string.format(L['Active rotation: %s'],active and (active..' ('..(self.manualRotation and L['manual'] or L['automatic'])..')') or L['None'])
    if spec==nil then lines[3]=L['No rotation can run until your specialization is available.'];return lines end
    -- The active rotation's steps that no action button holds are skipped.
    if self.currentRotation~=nil and self.ListUnboundSteps and self.GetRotationForCleanup then
        local ok,body=pcall(self.GetRotationForCleanup,self,spec,self.currentRotation)
        local unbound=ok and self:ListUnboundSteps(body) or {}
        if #unbound>0 then
            local names={}
            for i,entry in ipairs(unbound) do names[i]=self:DescribeUnboundStep(entry) end
            lines[#lines+1]=string.format(L['Skipped, not on your action bars (they cannot be highlighted): %s.'],table.concat(names,'; '))
        end
    end
    local unoffered,offered=self:GetUnofferedRotationSpec()
    if unoffered then
        lines[#lines+1]=string.format(L['You have not chosen a specialization yet (Retail characters below level 10 have none), so Rotation Master uses %s (%s). The Rotations editor only offers %s, so rotations saved there cannot run until you choose a specialization.'],
            self:DescribeRotationSpec(unoffered),tostring(unoffered),table.concat(offered,', '))
    end
    local function verdict(name,value)
        local why=self:ExplainRotationRefusal(spec,value)
        if not why and value~=DEFAULT and self:IsManualOnlyRotation(spec,value) then lines[#lines+1]=string.format(L['%s: ready, manual only: no switch condition (choose it with /rm set or the minimap menu).'],name);return end
        lines[#lines+1]=why and string.format(L['%s: cannot be selected, %s.'],name,why) or string.format(L['%s: ready'],name)
    end
    verdict(string.format(L['Fallback (%s)'],DEFAULT),DEFAULT)
    local headers=self.ListRotationHeaders and self:ListRotationHeaders(spec)
    if type(headers)~='table' then return lines end
    local handles={}
    if self.ListRotationHandles then for _,entry in ipairs(self:ListRotationHandles(spec)) do handles[entry.key]=entry.handle end end
    local function tagged(text,key) return handles[key] and string.format('%s [%s]',text,handles[key]) or text end
    -- Built Ins that are off are named when they would otherwise apply here,
    -- with who switched them off; the rest are only counted.
    local states={}
    for _,row in ipairs(self.GetBuiltinStates and self:GetBuiltinStates(spec) or {}) do states[row.id]=row end
    local disabled=0
    for _,row in ipairs(headers) do
        if row.fallback then
        elseif row.kind=='builtin' then
            local state=states[row.canonicalId]
            local name=tagged(string.format(L['%s (Built In)'],row.name),row.key)
            if state and (state.state=='invalid' or state.fits and not state.applies and state.reason=='invalid-or-unsupported') then
                local problem=row.problem and self:DescribeRotationIssue(row.problem)
                lines[#lines+1]=string.format(L['%s: cannot be selected, %s.'],name,problem and (problem:gsub('%.$','')) or L['it has incomplete or unsupported data'])
            elseif state and state.state=='user-disabled' and state.applies then
                lines[#lines+1]=string.format(L['%s: disabled by you (turn it back on in Rotations, in its Built In view).'],name)
            elseif state and state.state=='shipped-disabled' and state.applies then
                lines[#lines+1]=string.format(L['%s: ships disabled, an alternative to the recommended one (turn it on in Rotations, in its Built In view).'],name)
            elseif not row.enabled then disabled=disabled+1
            else verdict(name,row.key) end
        else verdict(tagged(row.name,row.key),row.key) end
    end
    if disabled>0 then lines[#lines+1]=string.format(L['%d other Built In rotations are disabled (for another specialization, level or edition).'],disabled) end
    -- The order automatic switching tries them in, and what it would choose now.
    local order=self.autoswitchRotation
    if type(order)=='table' then
        local names={}
        for _,key in ipairs(order) do
            local name=self:GetRotationName(key)
            if name then names[#names+1]=string.format('%s (%s)',name,tostring(self:GetRotationEffectivePriority(spec,key) or '?')) end
        end
        if #names==0 then
            lines[#lines+1]=string.format(L['Automatic switching tries nothing else, then the fallback (%s): no enabled rotation here has a switch condition it can use.'],DEFAULT)
        else
            names[#names+1]=string.format(L['then the fallback (%s)'],DEFAULT)
            lines[#lines+1]=string.format(L['Automatic switching tries: %s. Higher numbers are tried first; your own rotations are always tried before Built Ins.'],table.concat(names,', '))
        end
        local choice=self.PreviewAutoSwitch and self:PreviewAutoSwitch()
        lines[#lines+1]=string.format(L['Automatic switching would choose: %s'],choice and (choice==DEFAULT and DEFAULT or self:GetRotationName(choice) or tostring(choice)) or L['None'])
    end
    return lines
end
function addon:ShowRotationEligibilityReport()
    local lines=self:GetRotationEligibilityReport()
    if #lines<=4 or not self.ShowConditionText then
        for _,line in ipairs(lines) do self:print(line) end
        return lines
    end
    self:print(L['Rotation eligibility opened in a window you can copy from.'])
    self:ShowConditionText(table.concat(lines,'\n'),L['Why rotations are or are not selected'])
    return lines
end
-- END ROTATION ELIGIBILITY EXPLANATIONS

-- BEGIN SWITCH OVERLAP
-- Rotations of one tier (your own, or Built In) whose switch conditions can
-- match at the same time, so that priority alone decides between them (a
-- tie, by name). Static: each switch becomes a region (specializations and
-- a player level range, from SPECIALIZATION and LEVEL conditions joined by
-- AND, narrowed by a Built In's applicability) plus its other conditions;
-- two overlap when their regions meet and one's other conditions are a
-- subset of the other's (identical, or one subsumes the other). Live: both
-- match right now. Computed on demand (list refresh, editor open), cached on
-- the auto-switch list identity; never while polling.
local function canonical(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys={};for key in pairs(value) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local parts={};for _,key in ipairs(keys) do parts[#parts+1]=tostring(key)..'='..canonical(value[key]) end
    return '{'..table.concat(parts,',')..'}'
end
local function newRegion() return {lo=-math.huge,hi=math.huge,atoms={},count=0} end
local function addAtom(region,condition) local key=canonical(condition);if not region.atoms[key] then region.atoms[key]=true;region.count=region.count+1 end end
local function narrowSpecs(region,list)
    local set={};for _,spec in ipairs(list) do if not region.specs or region.specs[spec] then set[spec]=true end end
    region.specs=set
end
local function addCondition(region,condition)
    if type(condition)~='table' or condition.type==nil then return end
    if condition.type=='AND' and type(condition.value)=='table' then
        for _,child in ipairs(condition.value) do addCondition(region,child) end;return
    end
    if condition.type=='LEVEL' and condition.unit=='player' and not condition.relative and type(condition.value)=='number' then
        local value,operator=condition.value,condition.operator
        if operator=='GREATERTHANOREQUALS' then region.lo=math.max(region.lo,value);return
        elseif operator=='GREATERTHAN' then region.lo=math.max(region.lo,math.floor(value)+1);return
        elseif operator=='LESSTHANOREQUALS' then region.hi=math.min(region.hi,value);return
        elseif operator=='LESSTHAN' then region.hi=math.min(region.hi,math.ceil(value)-1);return
        elseif operator=='EQUALS' then region.lo=math.max(region.lo,value);region.hi=math.min(region.hi,value);return end
    end
    if condition.type=='SPECIALIZATION' and type(condition.spec)=='number' then narrowSpecs(region,{condition.spec});return end
    addAtom(region,condition)
end
local function meets(a,b)
    if math.max(a.lo,b.lo)>math.min(a.hi,b.hi) then return false end
    if a.specs and b.specs then
        local any=false;for spec in pairs(a.specs) do if b.specs[spec] then any=true;break end end
        if not any then return false end
    end
    -- Packs for different season or realm rules never load together.
    if a.rulesets and b.rulesets then
        local any=false;for name in pairs(a.rulesets) do if b.rulesets[name] then any=true;break end end
        if not any then return false end
    end
    return true
end
local function subset(a,b) if a.count>b.count then return false end;for key in pairs(a.atoms) do if not b.atoms[key] then return false end end;return true end
local function sameSpecs(a,b)
    if (a.specs==nil)~=(b.specs==nil) then return false end
    if not a.specs then return true end
    for spec in pairs(a.specs) do if not b.specs[spec] then return false end end
    for spec in pairs(b.specs) do if not a.specs[spec] then return false end end
    return true
end
function addon:GetSwitchRegion(switch,applicability)
    local region=newRegion()
    if type(applicability)=='table' then
        if type(applicability.specs)=='table' then narrowSpecs(region,applicability.specs) end
        if type(applicability.minLevel)=='number' then region.lo=math.max(region.lo,applicability.minLevel) end
        if type(applicability.maxLevel)=='number' then region.hi=math.min(region.hi,applicability.maxLevel) end
        if type(applicability.rulesets)=='table' then region.rulesets={};for _,name in ipairs(applicability.rulesets) do region.rulesets[name]=true end end
    end
    addCondition(region,switch)
    return region
end
local function within(inner,outer)
    if inner.lo<outer.lo or inner.hi>outer.hi then return false end
    if outer.specs then
        if not inner.specs then return false end
        for spec in pairs(inner.specs) do if not outer.specs[spec] then return false end end
    end
    return true
end
-- How two switch regions relate when both can match at once: 'identical';
-- 'subsumes' (a matches whenever b does); 'subsumed' (the reverse);
-- 'overlaps' (they share some of their range); nil when no overlap is proved.
function addon:CompareSwitchRegions(a,b)
    if not meets(a,b) then return nil end
    local ab,ba=subset(a,b),subset(b,a)
    if not ab and not ba then return nil end
    if ab and ba and a.lo==b.lo and a.hi==b.hi and sameSpecs(a,b) then return 'identical' end
    if ab and within(b,a) then return 'subsumes' end
    if ba and within(a,b) then return 'subsumed' end
    return 'overlaps'
end
local overlapCache={}
function addon:GetSwitchOverlaps(spec)
    spec=spec or self.currentSpec
    local order=self.autoswitchRotation
    if spec==nil or spec~=self.currentSpec or type(order)~='table' then return {} end
    if overlapCache.order==order and overlapCache.spec==spec and overlapCache.registry==self.conditionRegistryVersion then return overlapCache.result end
    local pass=self.AcquireRotationRuntimePass and self:AcquireRotationRuntimePass(spec)
    local rows={}
    for _,key in ipairs(order) do
        local body=pass and pass:Get(key) or (not pass and self.GetRuntimeRotation and self:GetRuntimeRotation(spec,key))
        if type(body)=='table' and type(body.switch)=='table' then
            local builtin=self.GetDefaultIdForRuntime and self:GetDefaultIdForRuntime(spec,key)
            local view=builtin and self.GetDefaultRotation and self:GetDefaultRotation(builtin)
            local matches=self.SwitchConditionMatchesNow and self:SwitchConditionMatchesNow(body.switch)
            rows[#rows+1]={key=key,name=body.name or key,priority=data.GetRotationPriority(body.priority) or 0,builtin=builtin~=nil,
                region=self:GetSwitchRegion(body.switch,view and view.applicability),live=matches==true}
        end
    end
    local result={}
    local function add(row,other,kind,live)
        local list=result[row.key];if not list then list={};result[row.key]=list end
        list[#list+1]={key=other.key,name=other.name,priority=other.priority,kind=kind,live=live,tie=row.priority==other.priority}
    end
    for i=1,#rows do for j=i+1,#rows do
        local a,b=rows[i],rows[j]
        if a.builtin==b.builtin then
            local kind=self:CompareSwitchRegions(a.region,b.region)
            local live=a.live and b.live
            if kind or live then
                local reverse=kind=='subsumes' and 'subsumed' or kind=='subsumed' and 'subsumes' or kind
                add(a,b,kind or 'live',live);add(b,a,reverse or 'live',live)
            end
        end
    end end
    overlapCache={order=order,spec=spec,registry=self.conditionRegistryVersion,result=result}
    return result
end
-- One line naming what a rotation overlaps with, for a tooltip or note; nil when nothing.
function addon:DescribeSwitchOverlap(list)
    if type(list)~='table' or #list==0 then return nil end
    local ties,others={},{}
    for _,entry in ipairs(list) do
        local text=string.format('%s (%d)',self.PlainWorkbenchName and self:PlainWorkbenchName(entry.name) or entry.name,entry.priority)
        if entry.tie then ties[#ties+1]=text else others[#others+1]=text end
    end
    local lines={}
    if #ties>0 then lines[#lines+1]=string.format(L['Same priority as %s: their switch conditions can match together, and the tie is decided by name.'],table.concat(ties,', ')) end
    if #others>0 then lines[#lines+1]=string.format(L['Can match together with %s: only priority decides which is chosen.'],table.concat(others,', ')) end
    return table.concat(lines,'\n'),#ties>0
end
-- The load-time scope of a definition, as one line; nil when it has none.
-- Specializations are never listed (you can respec) and only a minimum level
-- is (you only level up); rulesets read as names.
local SEASONS={[1]='Season of Mastery',[2]='Season of Discovery',[3]='Hardcore',[11]='Anniversary',[12]='Anniversary Hardcore'}
local SEASON_NAMES={seasonofmastery=1,seasonofdiscovery=2,hardcore=3,fresh=11,freshhardcore=12}
local function rulesetName(token)
    if token=='hardcore' then return L['Hardcore'] elseif token=='self-found' then return L['Self-Found'] elseif token=='standard' then return L['Standard realms'] end
    local season=type(token)=='string' and token:match('^season:(.+)$')
    if season then
        local id=tonumber(season) or SEASON_NAMES[season]
        if id and SEASONS[id] then return L[SEASONS[id]] end
        return string.format(L['Season %s'],season)
    end
    local mode=type(token)=='string' and token:match('^mode:(%d+)$')
    if mode then return string.format(L['Game mode %s'],mode) end
    return tostring(token)
end
function addon:DescribeApplicability(scope)
    if type(scope)~='table' then return nil end
    local parts={}
    local editions={tbc=L['TBC'],era=L['Classic Era'],progression=L['Classic Progression'],retail=L['Retail'],forever=L['Forever']}
    if type(scope.families)=='table' then local names={};for _,family in ipairs(scope.families) do names[#names+1]=editions[family] or family end;parts[#parts+1]=table.concat(names,', ') end
    if type(scope.class)=='string' then parts[#parts+1]=(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[scope.class]) or scope.class:sub(1,1)..scope.class:sub(2):lower() end
    if type(scope.minLevel)=='number' and scope.minLevel>1 then parts[#parts+1]=string.format(L['level %d+'],scope.minLevel) end
    if scope.minExpansion or scope.maxExpansion then parts[#parts+1]=string.format(L['expansions %s–%s'],tostring(scope.minExpansion or '?'),tostring(scope.maxExpansion or '?')) end
    if type(scope.rulesets)=='table' then local names={};for _,token in ipairs(scope.rulesets) do names[#names+1]=rulesetName(token) end;parts[#parts+1]=table.concat(names,', ') end
    if #parts==0 then return nil end
    return string.format(L['Loads only for: %s. The switch condition decides the rest.'],table.concat(parts,' · '))
end
-- END SWITCH OVERLAP

-- BEGIN ROTATION HANDLES
-- Every rotation for a specialization has a handle (Data/validation.lua):
-- a Built In's comes from its pack (GetBuiltinHandle), yours is stored in
-- the rotation (body.handle) or, until you set one, made from its name. The
-- fallback is "default". Stored handles and Built Ins claim theirs first;
-- the rest are derived in name order, a clash taking -2, -3...
local function sortedUnstored(list) table.sort(list,function(a,b) if a.name~=b.name then return a.name<b.name end;return tostring(a.canonicalId)<tostring(b.canonicalId) end) end
function addon:ListRotationHandles(spec,headers)
    headers=headers or self.ListRotationHeaders and self:ListRotationHeaders(spec)
    local rows,used,pending={},{},{}
    for _,row in ipairs(type(headers)=='table' and headers or {}) do
        local entry={key=row.key,name=row.name,kind=row.kind,canonicalId=row.canonicalId,fallback=row.fallback,row=row}
        if row.fallback then entry.handle='default';entry.stored=true
        elseif row.kind=='builtin' then entry.handle=row.handle
        elseif row.handle then entry.handle=row.handle;entry.stored=true end
        if entry.handle then
            if used[entry.handle] and not row.fallback then entry.duplicateOf=used[entry.handle] end
            used[entry.handle]=used[entry.handle] or entry
        elseif not row.fallback then pending[#pending+1]=entry end
        rows[#rows+1]=entry
    end
    sortedUnstored(pending)
    for _,entry in ipairs(pending) do
        local base=data.SlugRotationHandle(entry.name);local handle,n=base,2
        while used[handle] do handle=data.SlugRotationHandle(base:sub(1,29)..'-'..n);n=n+1 end
        entry.handle=handle;entry.derived=true;used[handle]=entry
    end
    return rows,used
end
function addon:GetRotationHandle(spec,key)
    if key==DEFAULT then return 'default' end
    local rows=self:ListRotationHandles(spec)
    for _,entry in ipairs(rows) do if entry.key==key then return entry.handle,entry end end
end
-- A free handle made from a name, for a new rotation or a copy.
function addon:NewRotationHandle(spec,name,except)
    local _,used=self:ListRotationHandles(spec)
    local base=data.SlugRotationHandle(name);local handle,n=base,2
    while used[handle] and used[handle].key~=except do handle=data.SlugRotationHandle(base:sub(1,29)..'-'..n);n=n+1 end
    return handle
end
-- nil when `text` can be this rotation's handle; else a sentence why.
function addon:CheckRotationHandle(spec,key,text)
    local handle,why=data.NormalizeRotationHandle(text)
    if not handle then
        if why=='reserved-handle' then return string.format(L['%s is reserved for /rm set.'],tostring(text)) end
        return L['A handle starts with a letter, then letters, digits, _ or -, up to 32 characters.']
    end
    local _,used=self:ListRotationHandles(spec)
    local owner=used[handle]
    if owner and owner.key~=key then return string.format(L['%s already uses the handle %s.'],owner.name,handle) end
    return nil,handle
end
-- The rotation a handle names among those selectable now; nil, and the
-- valid handles, when none or several do.
function addon:ResolveRotationHandle(spec,text,selectable)
    local wanted=type(text)=='string' and text:lower():match('^%s*(.-)%s*$')
    if not wanted or wanted=='' then return nil end
    local rows=self:ListRotationHandles(spec);local found,valid={},{}
    for _,entry in ipairs(rows) do
        if not selectable or entry.fallback or selectable[entry.key] then
            valid[#valid+1]=entry.handle
            if entry.handle==wanted then found[#found+1]=entry end
        end
    end
    table.sort(valid)
    if #found==1 then return found[1].fallback and DEFAULT or found[1].key,found[1] end
    return nil,nil,valid,#found>1
end
-- The handles of the rotations in `selectable` (runtime rows), sorted.
function addon:ListSelectableHandles(spec,selectable)
    local list={}
    for _,entry in ipairs(self:ListRotationHandles(spec)) do if entry.fallback and selectable[DEFAULT] or selectable[entry.key] then list[#list+1]=entry.handle end end
    table.sort(list);return list
end
-- "Name [handle]" for chat and menus.
function addon:FormatRotationLabel(name,key,spec)
    if type(name)~='string' then return name end
    local handle=key~=DEFAULT and self:GetRotationHandle(spec or self.currentSpec,key) or nil
    return handle and string.format('%s [%s]',name,handle) or name
end
function addon:GetRotationLabel(key,spec)
    local name=key==DEFAULT and DEFAULT or self:GetRotationName(key)
    if not name then return nil end
    return self:FormatRotationLabel(name,key,spec)
end
-- /rm list: handle, name and status of every rotation for the live spec.
function addon:GetRotationHandleReport()
    local spec=self.currentSpec;local lines={}
    if spec==nil then return {L['No rotation can run until your specialization is available.']} end
    lines[1]=string.format(L['Rotations for %s (use /rm set <handle>):'],self:DescribeRotationSpec(spec))
    local states={}
    for _,row in ipairs(self.GetBuiltinStates and self:GetBuiltinStates(spec) or {}) do states[row.id]=row end
    for _,entry in ipairs(self:ListRotationHandles(spec)) do
        local status
        if entry.kind=='builtin' then
            local state=states[entry.canonicalId]
            if state and state.state=='user-disabled' then status=L['disabled by you']
            elseif state and state.state=='shipped-disabled' then status=L['ships disabled']
            elseif state and not state.applies then status=L['not for this character now'] end
        end
        if not status then
            local why=self:ExplainRotationRefusal(spec,entry.fallback and DEFAULT or entry.key)
            status=why and string.format(L['cannot be selected: %s'],why) or (self.currentRotation==(entry.fallback and DEFAULT or entry.key) and L['active'] or L['ready'])
            if not why and not entry.fallback and self:IsManualOnlyRotation(spec,entry.key) then status=status..', '..L['manual only (no switch condition)'] end
        end
        local kind=entry.fallback and L['fallback'] or entry.kind=='builtin' and L['Built In'] or L['yours']
        lines[#lines+1]=string.format('%s — %s (%s) — %s',entry.handle,entry.name,kind,status)
    end
    return lines
end
function addon:ShowRotationHandleReport()
    local lines=self:GetRotationHandleReport()
    if #lines<=6 or not self.ShowConditionText then for _,line in ipairs(lines) do self:print(line) end;return lines end
    self:print(L['The rotation list opened in a window you can copy from.'])
    self:ShowConditionText(table.concat(lines,'\n'),L['Rotations and their handles'])
    return lines
end
-- END ROTATION HANDLES
