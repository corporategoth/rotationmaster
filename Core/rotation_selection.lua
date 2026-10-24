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
    return refusalText[code] or string.format(L['it is unavailable (%s)'],tostring(code)),code
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
    local unoffered,offered=self:GetUnofferedRotationSpec()
    if unoffered then
        lines[#lines+1]=string.format(L['You have not chosen a specialization yet (Retail characters below level 10 have none), so Rotation Master uses %s (%s). The Rotations editor only offers %s, so rotations saved there cannot run until you choose a specialization.'],
            self:DescribeRotationSpec(unoffered),tostring(unoffered),table.concat(offered,', '))
    end
    local function verdict(name,value)
        local why=self:ExplainRotationRefusal(spec,value)
        lines[#lines+1]=why and string.format(L['%s: cannot be selected, %s.'],name,why) or string.format(L['%s: ready'],name)
    end
    verdict(string.format(L['Fallback (%s)'],DEFAULT),DEFAULT)
    local headers=self.ListRotationHeaders and self:ListRotationHeaders(spec)
    if type(headers)~='table' then return lines end
    -- Built Ins that are off are named when they would otherwise apply here,
    -- with who switched them off; the rest are only counted.
    local states={}
    for _,row in ipairs(self.GetBuiltinStates and self:GetBuiltinStates(spec) or {}) do states[row.id]=row end
    local disabled=0
    for _,row in ipairs(headers) do
        if row.fallback then
        elseif row.kind=='builtin' then
            local state=states[row.canonicalId]
            local name=string.format(L['%s (Built In)'],row.name)
            if state and (state.state=='invalid' or state.fits and not state.applies and state.reason=='invalid-or-unsupported') then
                local problem=row.problem and self:DescribeRotationIssue(row.problem)
                lines[#lines+1]=string.format(L['%s: cannot be selected, %s.'],name,problem and (problem:gsub('%.$','')) or L['it has incomplete or unsupported data'])
            elseif state and state.state=='user-disabled' and state.applies then
                lines[#lines+1]=string.format(L['%s: disabled by you (turn it back on in Rotations, in its Built In view).'],name)
            elseif state and state.state=='shipped-disabled' and state.applies then
                lines[#lines+1]=string.format(L['%s: ships disabled, an alternative to the recommended one (turn it on in Rotations, in its Built In view).'],name)
            elseif not row.enabled then disabled=disabled+1
            else verdict(name,row.key) end
        else verdict(row.name,row.key) end
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
        names[#names+1]=string.format(L['then the fallback (%s)'],DEFAULT)
        lines[#lines+1]=string.format(L['Automatic switching tries: %s. Higher numbers are tried first; your own rotations are always tried before Built Ins.'],table.concat(names,', '))
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
