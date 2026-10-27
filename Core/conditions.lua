local addon_name, addon = ...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end

local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- Registry and tree services are independent of options rendering.
local printArray, printSingle, validateArray, validateSingle, usefulArray, usefulSingle

local conditions = {}
addon.conditionDefinitions = conditions
if invalidateDependencies then invalidateDependencies(addon,'condition',nil) end
-- Scope installs one scalar-only reader before normal runtime initialization.
---@type fun(owner:table): boolean?
local consumerAvailability
local consumerAvailabilityBound
function addon:ConsumeConditionConsumerAvailability()
    if self~=addon or consumerAvailabilityBound then return end
    consumerAvailabilityBound=true
    return function(reader)
        if consumerAvailability==nil and type(reader)=='function'then consumerAvailability=reader end
    end
end
local special = {}
addon.conditionSpecials = special
local quarantined = setmetatable({}, {__mode="k"})
local conditionQuarantineVersion=0
special["DELETE"] = { desc = DELETE, icon = "Interface\\AddOns\\" .. addon_name .. "\\Assets\\Controls\\trash.tga", fields = { } }
special["AND"] = { desc = L["AND"], icon = addon.Artwork.logic["AND"], fields = { value = "condition[]" } }
special["OR"] = { desc = L["OR"], icon = addon.Artwork.logic["OR"], fields = { value = "condition[]" } }
special["NOT"] = { desc = L["NOT"], icon = addon.Artwork.logic["NOT"], fields = { value = "condition" } }

-- Inputs here are normalized, readable data. Client adapters own secret-value access.
local matchedOutcome,unmatchedOutcome={status="match"},{status="no-match"}
local function outcome(status, reason, path)
    if status=="match" then return matchedOutcome end
    if status=="no-match" then return unmatchedOutcome end
    return {status=status, reason=reason, path=path}
end

-- Damage and UNIT_COMBAT histories are recorded only while something reads
-- them (main.lua WantHistory). Custom code may read either.
local historyReaders={COMBAT_HISTORY='combat',COMBAT_HISTORY_TIME='combat',TT_HEALTH='damage',TT_HEALTHPCT='damage'}

local function callCondition(definition, stage, value, cache, start, path, context, guard, guardNode, guardSession, stats)
    if quarantined[definition] then return false end
    if stage~='valid' and addon.WantHistory then
        local history=historyReaders[value.type]
        if history then addon:WantHistory(history)
        elseif definition.customCode then addon:WantHistory('combat');addon:WantHistory('damage') end
    end
    if guard and not guard(guardNode,guardSession)then return true,nil,nil,true,false end
    local skipped,invoked
    local function run()
        -- ObserveReportedErrors runs before this callback. Recheck the finite
        -- private producer after that callout, before handing it a private node.
        if guard and not guard(guardNode,guardSession)then skipped=true;return end
        invoked=true
        if guard and stats then
            if stage=='valid'then stats.validatorCalls=stats.validatorCalls+1
            else stats.leafEvaluations=stats.leafEvaluations+1 end
        end
        if stage == "valid" then return definition.valid(addon.currentSpec, value) end
        -- A group unit type (the main tank, the group leader, ...) is replaced by
        -- the token of whoever holds it now; nobody holding it is unavailable.
        local kinds=addon.groupUnitKinds
        if kinds and (kinds[value.unit] or kinds[value.otherunit]) then
            local resolved,why=addon:ResolveConditionUnits(value,cache)
            if not resolved then return nil,why end
            return definition.evaluate(resolved, cache, start)
        end
        return definition.evaluate(value, cache, start)
    end
    if not addon.Diagnostics then
        -- A callback may return more than (matched, reason); the extra values are not the guard's skipped/invoked flags.
        if not guard then local result,reason=run();return true,result,reason end
        local result,reason=run();return true,result,reason,skipped,invoked
    end
    local ok, result, reason = addon.Diagnostics:Call({module="conditions", operation=stage,
        conditionPath=path, conditionTag=value.type, stepId=context and context.stepId,
        rotationId=addon.currentRotation, customCode=definition.customCode == true}, run)
    if not ok then quarantined[definition] = true;conditionQuarantineVersion=conditionQuarantineVersion+1 end
    if guard then return ok,result,reason,skipped,invoked end
    return ok, result, reason
end

-- Both dispatch routes use the same callback/error boundary. Only the private
-- source-owned graph may memoize a successful configuration-only validator.
local function evaluateOrdinaryLeaf(value, definition, cache, start, path, context, validation, current, stats, guard, guardNode, guardSession, afterCurrent)
    if current and not current()then return outcome("unavailable","condition-owner-changed",path)end
    if not validation or not validation.valid then
        if stats and not guard then stats.validatorCalls=stats.validatorCalls+1 end
        local ok,valid,_,skipped,invoked=callCondition(definition,"valid",value,cache,start,path,context,guard,guardNode,guardSession,stats)
        if current and not current()or invoked and afterCurrent and not afterCurrent(guardSession)or current and not current()then return outcome("unavailable","condition-owner-changed",path)end
        if skipped then return outcome("unavailable","condition-source-changed",path)end
        if not ok then return outcome("unavailable","condition-callback-error",path) end
        if not valid then return outcome("unavailable","invalid-condition-fields",path) end
        if validation then validation.valid=true end
    end
    if stats and not guard then stats.leafEvaluations=stats.leafEvaluations+1 end
    local ok,matched,reason,skipped,invoked=callCondition(definition,"evaluate",value,cache,start,path,context,guard,guardNode,guardSession,stats)
    if current and not current()or invoked and afterCurrent and not afterCurrent(guardSession)or current and not current()then return outcome("unavailable","condition-owner-changed",path)end
    if skipped then return outcome("unavailable","condition-source-changed",path)end
    if not ok then return outcome("unavailable","condition-callback-error",path) end
    -- Legacy nil without a reason is false, never unavailable.
    if matched==nil and reason~=nil then return outcome("unavailable",reason,path) end
    return outcome(matched and "match" or "no-match")
end

-- BEGIN SWITCH UNIT PRESENCE
local function switchReadable(platform,value,current)
    if current and not current()then return false end
    local method=platform and platform.CanReadValue
    if current and not current()then return false end
    if type(method)~='function'then return false end
    local ok,readable=pcall(method,platform,value)
    return (not current or current()) and ok and readable==true
end
local function switchUnitWitness(value,definition,state)
    local fields=definition.fields
    if type(fields)~='table' or rawget(fields,'unit')~='string' then return true end
    local platform=addon.Platform
    local unit,tag=value.unit,value.type
    if not switchReadable(platform,unit,state.switchCurrent)then return nil,'switch-unit-unavailable' end
    local function current()
        return (not state.switchCurrent or state.switchCurrent()) and addon.Platform==platform and switchReadable(platform,value.unit,state.switchCurrent) and switchReadable(platform,value.type,state.switchCurrent)
            and value.unit==unit and value.type==tag and conditions[tag]==definition and definition.fields==fields
            and rawget(fields,'unit')=='string' and (not state.switchCurrent or state.switchCurrent())
    end
    -- Player and legacy omitted-unit fields need identity fences, no presence API.
    if unit==nil or unit=='player'then return current end
    if type(unit)~='string' or not addon.units or addon.units[unit]==nil then return nil,'switch-unit-unavailable' end
    -- A group unit type is present when someone holds it; ask about that member.
    local presenceUnit=unit
    if addon.groupUnitKinds and addon.groupUnitKinds[unit] then
        local token=platform and platform.ResolveGroupUnit and platform:ResolveGroupUnit(unit)
        if type(token)~='string' then return nil,'switch-unit-unavailable' end
        presenceUnit=token
    end
    local method=platform.GetUnitPresenceObservation
    if type(method)~='function'then return nil,'switch-unit-unavailable' end
    local function present()
        if not current() or platform.GetUnitPresenceObservation~=method or state.switchCurrent and not state.switchCurrent() then return false end
        local ok,exists=pcall(method,platform,presenceUnit)
        return ok and switchReadable(platform,exists,state.switchCurrent) and exists==true and current()
            and platform.GetUnitPresenceObservation==method and (not state.switchCurrent or state.switchCurrent())
    end
    if not present()then return nil,'switch-unit-unavailable' end
    -- Valid/evaluate callbacks can change native unit state synchronously. Keep
    -- these cold checks fresh instead of retaining a positive snapshot.
    return present
end
local function evaluateSwitchLeaf(value,definition,cache,start,state,path)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    local witness,reason=switchUnitWitness(value,definition,state)
    if not witness then return outcome("unavailable",reason,path)end
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    local validOk,valid=callCondition(definition,"valid",value,cache,start,path,state.context)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    if type(witness)=='function' and not witness()then return outcome("unavailable","switch-unit-changed",path)end
    if not validOk then return outcome("unavailable","condition-callback-error",path)end
    if not valid then return outcome("unavailable","invalid-condition-fields",path)end
    local evalOk,matched,evalReason=callCondition(definition,"evaluate",value,cache,start,path,state.context)
    if state.switchCurrent and not state.switchCurrent()then return outcome("unavailable","switch-owner-changed",path)end
    if type(witness)=='function' and not witness()then return outcome("unavailable","switch-unit-changed",path)end
    if not evalOk then return outcome("unavailable","condition-callback-error",path)end
    if matched==nil and evalReason~=nil then return outcome("unavailable",evalReason,path)end
    return outcome(matched and "match" or "no-match")
end
-- END SWITCH UNIT PRESENCE

local function evaluate(value, cache, start, state, depth, path)
    state.count = state.count + 1
    if depth > 64 or state.count > 4096 then
        return outcome("unavailable", "condition-limit", path)
    end
    if value == nil then return outcome("match") end
    if type(value) ~= "table" then return outcome("unavailable", "invalid-condition", path) end
    if state.active[value] then return outcome("unavailable", "condition-cycle", path) end
    if value.disabled ~= nil and type(value.disabled) ~= "boolean" then
        return outcome("unavailable", "invalid-disabled-flag", path)
    end
    if value.disabled then return outcome("match") end
    if value.type == nil then
        if next(value) == nil then return outcome("match") end
        return outcome("unavailable", "missing-condition-type", path)
    end
    if type(value.type) ~= "string" then return outcome("unavailable", "invalid-condition-type", path) end
    state.active[value] = true
    local result
    if value.type == "AND" or value.type == "OR" then
        local children = value.value
        if children == nil then children = {} end
        if type(children) ~= "table" then
            result = outcome("unavailable", "invalid-condition-list", path)
        else
            local count, largest = 0, 0
            for key in pairs(children) do
                if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                    result = outcome("unavailable", "invalid-condition-list", path)
                    break
                end
                count = count + 1
                if count > 4096 - state.count then
                    result = outcome("unavailable", "condition-limit", path)
                    break
                end
                if key > largest then largest = key end
            end
            if not result and count ~= largest then result = outcome("unavailable", "sparse-condition-list", path) end
            if not result then
                local matched = value.type == "AND"
                for index = 1, count do
                    local child = evaluate(children[index], cache, start, state, depth+1, path..".value["..index.."]")
                    if child.status == "unavailable" then result = child; break end
                    if value.type == "AND" and child.status == "no-match" then matched = false; break end
                    if value.type == "OR" and child.status == "match" then matched = true; break end
                end
                result = result or outcome(matched and "match" or "no-match")
            end
        end
    elseif value.type == "NOT" then
        if type(value.value) ~= "table" then
            result = outcome("unavailable", "invalid-not-condition", path)
        else
            result = evaluate(value.value, cache, start, state, depth+1, path..".value")
            if result.status ~= "unavailable" then
                result = outcome(result.status == "match" and "no-match" or "match")
            end
        end
    else
        local definition = conditions[value.type]
        if not definition then
            result = outcome("unavailable", "unknown-condition", path)
        elseif definition.functionUnavailable then
            result = outcome("unavailable", "unavailable-function", path)
        elseif definition.disabled then
            result = outcome("unavailable", "disabled-condition", path)
        elseif type(definition.valid) ~= "function" or type(definition.evaluate) ~= "function" then
            result = outcome("unavailable", "incomplete-condition-definition", path)
        elseif state.switchUnits then
            result=evaluateSwitchLeaf(value,definition,cache,start,state,path)
        elseif state.announcementTarget and value.unit=='announcementtarget' then
            local unit,current=state.announcementTarget(value.type)
            if not unit or type(current)~='function' or not current() or type(definition.fields)~='table' or definition.fields.unit~='string' then
                result=outcome('unavailable','cast-recipient-unavailable',path)
            else
                -- Contextual units validate fields with the same representative
                -- player token used by the editor, then evaluate the exact name.
                local validation=addon.RotationData.CopyData(value);validation.unit='player'
                local validOk,valid
                if current() then validOk,valid=callCondition(definition,'valid',validation,cache,start,path,state.context) end
                if not current() then result=outcome('unavailable','cast-recipient-changed',path)
                elseif not validOk or not valid then result=outcome('unavailable','invalid-condition-fields',path)
                else
                    local input=addon.RotationData.CopyData(value);input.unit=unit
                    local evalOk,matched,reason=callCondition(definition,'evaluate',input,cache,start,path,state.context)
                    if not current() then result=outcome('unavailable','cast-recipient-changed',path)
                    elseif not evalOk then result=outcome('unavailable','condition-callback-error',path)
                    elseif matched==nil and reason~=nil then result=outcome('unavailable',reason,path)
                    else result=outcome(matched and 'match' or 'no-match') end
                end
            end
        else
            result=evaluateOrdinaryLeaf(value,definition,cache,start,path,state.context)
        end
    end
    state.active[value] = nil
    return result
end

-- Alternatives belong to translated predicate templates, never inferred from
-- rendered names. Only the first marker is the leaf's predicate; subsequent
-- markers are qualifiers and retain their positive wording under negation.
local printerSources=setmetatable({}, {__mode='k'})
function addon:RenderConditionPhrase(text,negated)
    if type(text)~='string' then return text end
    local first=true;local hasPrimary=text:find('{{!',1,true)~=nil
    local rendered,count=text:gsub('{{(.-)|(.-)}}',function(positive,negative)
        local primary=positive:sub(1,1)=='!';if primary then positive=positive:sub(2) end
        local predicate=not hasPrimary or primary
        local result=negated and first and predicate and negative or positive;if predicate then first=false end;return result
    end)
    if negated and count==0 then return string.format(L['not (%s)'],text) end
    return rendered
end
-- Transient summary authority is shared by native and compiled helper calls.
-- Values are detached before rendering and are never parsed as template syntax.
local summaryRecords=setmetatable({}, {__mode='k'})
local SUMMARY_LIMIT,SUMMARY_PARTS=64000,4096
local function summaryObject(record)
    local object={};summaryRecords[object]=record;return object
end
local function invalidSummary() return summaryObject({kind='invalid'}) end
local function summaryFallback()
    local key='Condition summary unavailable: invalid template or values.'
    local text=L[key];return type(text)=='string' and #text<=SUMMARY_LIMIT and text or key
end
local function summaryScalar(value)
    local kind=type(value)
    if kind=='string' then return #value<=SUMMARY_LIMIT and value or nil end
    if kind=='boolean' or kind=='number' and value==value and value~=math.huge and value~=-math.huge then return tostring(value) end
end
function addon:CreateConditionSummaryPredicate(positive,negative,primary)
    if type(positive)~='string' or #positive>SUMMARY_LIMIT or negative~=nil and (type(negative)~='string' or #negative>SUMMARY_LIMIT) or primary~=nil and type(primary)~='boolean' then return invalidSummary() end
    return summaryObject({kind='predicate',positive=positive,negative=negative,primary=primary==true})
end
function addon:CreateConditionSummaryPhrase(template,values)
    if type(template)~='string' or #template>SUMMARY_LIMIT or type(values)~='table' or getmetatable(values)~=nil then return invalidSummary() end
    local copied,count={},0
    for key,value in pairs(values) do
        count=count+1
        if count>SUMMARY_PARTS or type(key)~='string' or not key:match('^[A-Za-z_][A-Za-z_0-9]*$') then return invalidSummary() end
        local predicate=type(value)=='table' and summaryRecords[value]
        if predicate and predicate.kind=='predicate' then copied[key]=predicate
        else copied[key]=summaryScalar(value);if copied[key]==nil then return invalidSummary() end end
    end
    local parts,index={},1
    local function add(part) parts[#parts+1]=part;return #parts<=SUMMARY_PARTS end
    while index<=#template do
        local head=template:sub(index,index+3)
        if head=='{{{{' or head=='}}}}' then
            if not add(head:sub(1,2)) then return invalidSummary() end;index=index+4
        elseif template:sub(index,index+1)=='{{' then
            local closing=template:find('}}',index+2,true);if not closing then return invalidSummary() end
            local body=template:sub(index+2,closing-1)
            local positive,negative=body:match('^([^|{}]*)|([^|{}]*)$');if not positive then return invalidSummary() end
            local primary=positive:sub(1,1)=='!';if primary then positive=positive:sub(2) end
            if not add({kind='predicate',positive=positive,negative=negative,primary=primary}) then return invalidSummary() end
            index=closing+2
        elseif template:sub(index,index)=='{' then
            local closing=template:find('}',index+1,true);if not closing then return invalidSummary() end
            local name=template:sub(index+1,closing-1)
            if not name:match('^[A-Za-z_][A-Za-z_0-9]*$') or copied[name]==nil or not add(copied[name]) then return invalidSummary() end
            index=closing+1
        elseif template:sub(index,index)=='}' then return invalidSummary()
        else
            local nextBrace=template:find('[{}]',index) or #template+1
            if not add(template:sub(index,nextBrace-1)) then return invalidSummary() end;index=nextBrace
        end
    end
    return summaryObject({kind='phrase',parts=parts})
end
function addon:RenderConditionSummary(result,negated)
    if type(result)=='string' then return self:RenderConditionPhrase(result,negated) end
    local record=type(result)=='table' and summaryRecords[result]
    if not record or record.kind~='phrase' then return summaryFallback() end
    local primary=false
    for _,part in ipairs(record.parts) do if type(part)=='table' and part.negative~=nil and part.primary then primary=true;break end end
    local output,bytes,first,predicates={},0,true,0
    for _,part in ipairs(record.parts) do
        local text=part
        if type(part)=='table' then
            local eligible=not primary or part.primary
            text=part.positive
            if part.negative~=nil then
                predicates=predicates+1
                if negated and first and eligible then text=part.negative end
                if eligible then first=false end
            end
        end
        bytes=bytes+#text;if bytes>SUMMARY_LIMIT then return summaryFallback() end
        output[#output+1]=text
    end
    local text=table.concat(output)
    if negated and predicates==0 then
        local ok,wrapped=pcall(string.format,L['not (%s)'],text)
        if not ok then return summaryFallback() end;text=wrapped
    end
    if #text>SUMMARY_LIMIT then return summaryFallback() end
    return text
end
---@param text string
---@return string
local function trimOuter(text)
    if text:sub(1,1)~='(' or text:sub(-1)~=')' then return text end
    local depth=0
    for i=1,#text do
        local c=text:sub(i,i)
        if c=='(' then depth=depth+1 elseif c==')' then depth=depth-1 end
        if depth==0 and i<#text or depth<0 then return text end
    end
    return depth==0 and text:sub(2,-2) or text
end

printArray = function(operation, array, spec)
    if array == nil then
        return ""
    end

    local rv = "("
    local first = true

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            if first then
                first = false
            else
                rv = rv .. " " .. operation .. " "
            end

            rv = rv .. printSingle(entry, spec)
        end
    end

    rv = rv .. ")"

    return rv
end

printSingle = function(value, spec, negated)
    if value == nil or value.type == nil or value.disabled then
        return ""
    end

    if value.type == "AND" or value.type == "OR" then
        local text=printArray(value.type, value.value, spec)
        return negated and L['NOT']..' '..text or text
    elseif value.type == "NOT" then
        return printSingle(value.value, spec, not negated)
    elseif conditions[value.type] ~= nil then
        if conditions[value.type].disabled or conditions[value.type].functionUnavailable then return string.format(L['Unavailable condition: %s'],conditions[value.type].description or value.type) end
        return conditions[value.type].print(spec, value, negated)
    else
        return L["<INVALID CONDITION>"]
    end
end

validateArray = function(_, array, spec)
    if array == nil then
        return true
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = validateArray(entry.type, entry.value, spec)
            else
                rv = validateSingle(entry, spec)
            end
            if not rv then
                return false
            end
        end
    end

    return true
end

validateSingle = function(value, spec)
    if value == nil or value.type == nil or value.disabled then
        return true
    end

    if value.type == "AND" or value.type == "OR" then
        return validateArray(value.type, value.value, spec)
    elseif value.type == "NOT" then
        return validateSingle(value.value, spec)
    elseif conditions[value.type] ~= nil then
        if conditions[value.type].disabled or conditions[value.type].functionUnavailable then return false end
        -- A condition that cannot work on this client leaves the tree incomplete.
        if addon.GetConditionSupport and addon:GetConditionSupport(value.type, conditions[value.type], value) then return false end
        return conditions[value.type].valid(spec, value)
    else
        return false
    end
end

usefulArray = function(_, array)
    if array == nil then
        return false
    end

    for _, entry in pairs(array) do
        if entry ~= nil and entry.type ~= nil then
            local rv
            if entry.type == "AND" or entry.type == "OR" then
                rv = usefulArray(entry.type, entry.value)
            else
                rv = usefulSingle(entry)
            end
            if rv then
                return true
            end
        end
    end

    return false
end

usefulSingle = function(value)
    if value == nil or value.type == nil then
        return false
    end

    if value.type == "AND" or value.type == "OR" then
        return usefulArray(value.type, value.value)
    elseif value.type == "NOT" then
        return usefulSingle(value.value)
    elseif conditions[value.type] ~= nil then
        return true
    else
        return false
    end
end

function addon:RefreshConditionConsumers()
    -- Built-in and saved definitions register before runtime initialization.
    if self.currentSpec==nil or type(self.autoswitchRotation)~='table' or not self.UpdateAutoSwitch then return end
    self:UpdateAutoSwitch()
    if self.currentRotation and self.GetRuntimeRotation then
        local available=consumerAvailability and consumerAvailability(self)
        if available==nil then
            local pass=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() and self:AcquireRotationRuntimePass(self.currentSpec)
            local body;if pass then body=pass:Get(self.currentRotation) else body=self:GetRuntimeRotation(self.currentSpec,self.currentRotation) end
            available=not not body
        end
        if not available then self:DisableRotation() end
    end
    self:SwitchRotation()
end

function addon:ResetConditionQuarantine(definition)
    if quarantined[definition]then conditionQuarantineVersion=conditionQuarantineVersion+1 end
    quarantined[definition]=nil
end

function addon:RegisterCondition(tag, array)
    local availabilityChanged=(conditions[tag] and conditions[tag].disabled==true or false)~=(array.disabled==true)
    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    if type(array.print)=='function' and not printerSources[array.print] then
        local raw=array.print
        local wrapped=function(spec,value,negated) return addon:RenderConditionSummary(raw(spec,value),negated) end
        printerSources[wrapped]=raw;array.print=wrapped
    end
    conditions[tag] = array
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'condition',tag) end
    quarantined[array] = nil
    if not array.disabled and not array.functionUnavailable and array.on_register then
        array.on_register(tag)
    end
    if availabilityChanged then self:RefreshConditionConsumers() end
end

function addon:UnregisterCondition(tag)
    local wasDisabled=conditions[tag] and conditions[tag].disabled==true
    if conditions[tag] and not conditions[tag].disabled and not conditions[tag].functionUnavailable and not conditions[tag].functionSuspended and conditions[tag].on_unregister then
        conditions[tag].on_unregister(tag)
    end
    local removed=conditions[tag]~=nil
    if removed then self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1 end
    conditions[tag] = nil
    if removed then if invalidateDependencies then invalidateDependencies(addon,'condition',tag) end end
    if wasDisabled then self:RefreshConditionConsumers() end
end

function addon:evaluateConditionResult(value, context)
    local result=evaluate(value, {}, GetTime(), {active={}, count=0, context=context}, 0, "condition")
    if result==matchedOutcome or result==unmatchedOutcome then return {status=result.status} end
    return result
end

-- Cast-event conditions get their own observation cache. Recipient context
-- never enters a rotation's polling cache or survives this announcement.
local function announcementUnits(value,unit)
    local data=addon.RotationData
    if not data.CheckPortable(value) then return nil,'invalid-announcement-condition' end
    local count,found=0,false
    local readable
    local function walk(node,depth,replace)
        count=count+1
        if count>4096 or depth>64 then return false end
        if type(node)~='table' or node.disabled==true then return true end
        if node.type=='AND' or node.type=='OR' then
            if type(node.value)=='table' then for _,child in pairs(node.value) do if not walk(child,depth+1,replace) then return false end end end
        elseif node.type=='NOT' then return walk(node.value,depth+1,replace)
        elseif node.unit=='announcementtarget' then
            local definition=conditions[node.type]
            found=true
            if replace then
                if readable and definition and type(definition.fields)=='table' and definition.fields.unit=='string' then node.unit=unit
                else node.type=false end -- unavailable only if reached; Boolean prefixes still short-circuit
            end
        end
        return true
    end
    if not walk(value,0,false) then return nil,'condition-limit' end
    if not found then return value end
    readable=addon.Platform:CanReadValue(unit) and type(unit)=='string' and unit~='' and #unit<=512
    local resolved=data.CopyData(value);count=0
    walk(resolved,0,true)
    return resolved
end
function addon:evaluateAnnouncementConditionResult(value, recipient, targetUnit, resolveTarget)
    local resolved,reason
    if resolveTarget then
        if not addon.RotationData.CheckPortable(value) then return outcome('unavailable','invalid-announcement-condition','announcement') end
        resolved=value
    else resolved,reason=announcementUnits(value,targetUnit) end
    if reason then return outcome('unavailable',reason,'announcement') end
    local result=evaluate(resolved, {announcementRecipient=recipient}, GetTime(), {active={}, count=0, announcementTarget=resolveTarget}, 0, "announcement")
    if result==matchedOutcome or result==unmatchedOutcome then return {status=result.status} end
    return result
end

function addon:validateAnnouncementCondition(value,spec)
    local resolved,reason=announcementUnits(value,'target')
    return not reason and validateSingle(resolved,spec)
end

function addon:evaluateCondition(value, context)
    return self:evaluateConditionResult(value, context).status == "match"
end

-- BEGIN CONDITION PLANS
-- A condition plan is a condition tree checked once (structure, lists, cycles,
-- limits) and then evaluated every poll with the exact semantics of
-- evaluate() above: AND/OR short-circuit, NOT keeps unavailable, a nil result
-- without a reason is false. Plans belong to one rotation body; main rebuilds
-- them when the body's execution generation changes. Definitions are looked
-- up per leaf, so registration, disabling and quarantine apply immediately.
-- Leaves return status strings, so evaluation allocates nothing itself.
local planLeafContext={module="conditions", operation="evaluate"}
local planValidContext={module="conditions", operation="valid"}
local function planCall(definition, context, fn, ...)
    local history=historyReaders[context.conditionTag]
    if history and addon.WantHistory then addon:WantHistory(history)
    elseif definition.customCode and addon.WantHistory then addon:WantHistory('combat');addon:WantHistory('damage') end
    local diagnostics=addon.Diagnostics
    if not diagnostics then return true, fn(...) end
    context.rotationId=addon.currentRotation;context.customCode=definition.customCode==true
    local ok, result, reason=diagnostics:Call(context, fn, ...)
    if not ok then quarantined[definition]=true;conditionQuarantineVersion=conditionQuarantineVersion+1 end
    return ok, result, reason
end

local function compilePlan(value, state, depth, path)
    state.count=state.count+1
    if depth > 64 or state.count > 4096 then state.limit=true;return {status="unavailable"} end
    if value == nil then return {status="match"} end
    if type(value) ~= "table" then return {status="unavailable"} end
    if state.active[value] then return {status="unavailable"} end
    if value.disabled ~= nil and type(value.disabled) ~= "boolean" then return {status="unavailable"} end
    if value.disabled then return {status="match"} end
    if value.type == nil then return {status=next(value)==nil and "match" or "unavailable"} end
    if type(value.type) ~= "string" then return {status="unavailable"} end
    state.active[value]=true
    local node
    if value.type == "AND" or value.type == "OR" then
        local children=value.value
        if children == nil then children={} end
        if type(children) ~= "table" then node={status="unavailable"}
        else
            local count, largest=0, 0
            for key in pairs(children) do
                if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then node={status="unavailable"};break end
                count=count+1
                if key > largest then largest=key end
            end
            if not node and count ~= largest then node={status="unavailable"} end
            if not node then
                node={kind=value.type}
                for index=1,count do node[index]=compilePlan(children[index], state, depth+1, path..".value["..index.."]") end
            end
        end
    elseif value.type == "NOT" then
        if type(value.value) ~= "table" then node={status="unavailable"}
        else node={kind="NOT", compilePlan(value.value, state, depth+1, path..".value")} end
    else
        node={kind="leaf", value=value, tag=value.type, path=path}
    end
    state.active[value]=nil
    return node
end

local function evaluatePlan(node, cache, start, stepId)
    local status=node.status
    if status then return status end
    local kind=node.kind
    if kind == "leaf" then
        local tag=node.tag
        local definition=conditions[tag]
        if not definition or definition.functionUnavailable or definition.disabled
            or type(definition.valid) ~= "function" or type(definition.evaluate) ~= "function"
            or quarantined[definition] then return "unavailable" end
        local value=node.value
        if node.validFor ~= definition then
            planValidContext.conditionPath, planValidContext.conditionTag, planValidContext.stepId=node.path, tag, stepId
            local ok, valid=planCall(definition, planValidContext, definition.valid, addon.currentSpec, value)
            if not ok or not valid then return "unavailable" end
            -- Validators read configuration; custom ones are rechecked every poll.
            if not definition.customCode then node.validFor=definition end
        end
        planLeafContext.conditionPath, planLeafContext.conditionTag, planLeafContext.stepId=node.path, tag, stepId
        local kinds=addon.groupUnitKinds
        if kinds and (kinds[value.unit] or kinds[value.otherunit]) then
            local resolved=addon:ResolveConditionUnits(value,cache)
            if not resolved then return "unavailable" end
            value=resolved
        end
        local ok, matched, reason=planCall(definition, planLeafContext, definition.evaluate, value, cache, start)
        if not ok then return "unavailable" end
        if matched == nil and reason ~= nil then return "unavailable" end
        return matched and "match" or "no-match"
    elseif kind == "NOT" then
        status=evaluatePlan(node[1], cache, start, stepId)
        if status == "unavailable" then return status end
        return status == "match" and "no-match" or "match"
    end
    for index=1,#node do
        status=evaluatePlan(node[index], cache, start, stepId)
        if status == "unavailable" then return status end
        if kind == "AND" and status == "no-match" then return "no-match" end
        if kind == "OR" and status == "match" then return "match" end
    end
    return kind == "AND" and "match" or "no-match"
end

function addon:ConsumeConditionPlans()
    if self ~= addon then return end
    addon.ConsumeConditionPlans=nil
    return function(value)
        local state={active={}, count=0}
        local plan=compilePlan(value, state, 0, "condition")
        -- The ordinary node budget counts only reached nodes; a tree too large
        -- to compile whole keeps the ordinary evaluator.
        if state.limit then return {legacy=value} end
        return plan
    end, function(plan, cache, start, stepId)
        if plan.legacy ~= nil then return addon:evaluateConditionResult(plan.legacy, {stepId=stepId}).status end
        return evaluatePlan(plan, cache, start, stepId)
    end
end
-- END CONDITION PLANS

-- BEGIN SWITCH CONDITION EVALUATOR
local ownedConditionEvaluator=addon.evaluateCondition
local ownedConditionResult=addon.evaluateConditionResult
local switchEnvironment=getfenv(1)
---@type fun(f: number|function): table
local switchGetfenv=getfenv
local switchBound=false
local runtimeBound=false
local runtimeDiagnostics=addon.Diagnostics
local runtimeDiagnosticsCall=runtimeDiagnostics and runtimeDiagnostics.Call
local runtimeDiagnosticsObserve=runtimeDiagnostics and runtimeDiagnostics.ObserveReportedErrors
local runtimeDiagnosticsCallEnvironment=type(runtimeDiagnosticsCall)=='function' and switchGetfenv(runtimeDiagnosticsCall)or nil
local runtimeDiagnosticsObserveEnvironment=type(runtimeDiagnosticsObserve)=='function' and switchGetfenv(runtimeDiagnosticsObserve)or nil
function addon:ConsumeConditionRuntimeEngine()
    if self~=addon or runtimeBound then return end
    runtimeBound=true
    return conditions,evaluateOrdinaryLeaf,outcome,function()
        return addon.evaluateCondition==ownedConditionEvaluator and addon.evaluateConditionResult==ownedConditionResult
            and switchGetfenv(ownedConditionEvaluator)==switchEnvironment
            and switchGetfenv(ownedConditionResult)==switchEnvironment
            and addon.Diagnostics==runtimeDiagnostics
            and (not runtimeDiagnostics or runtimeDiagnostics.Call==runtimeDiagnosticsCall
                and runtimeDiagnostics.ObserveReportedErrors==runtimeDiagnosticsObserve
                and (runtimeDiagnosticsCallEnvironment==nil or switchGetfenv(runtimeDiagnosticsCall)==runtimeDiagnosticsCallEnvironment)
                and (runtimeDiagnosticsObserveEnvironment==nil or switchGetfenv(runtimeDiagnosticsObserve)==runtimeDiagnosticsObserveEnvironment))
    end,function(definition)return quarantined[definition]==true end,function()return conditionQuarantineVersion end
end
function addon:ConsumeSwitchConditionEvaluator()
    if self~=addon or switchBound then return end
    switchBound=true
    return function(owner,value,current)
        local method=owner.evaluateCondition
        if current and not current()then return false end
        if method~=ownedConditionEvaluator or owner.evaluateConditionResult~=ownedConditionResult
            or switchGetfenv(ownedConditionEvaluator)~=switchEnvironment
            or switchGetfenv(ownedConditionResult)~=switchEnvironment then return method(owner,value) end
        local result=evaluate(value,{},GetTime(),{active={},count=0,switchUnits=true,switchCurrent=current},0,"switch")
        return result.status=="match"
    end
end
-- END SWITCH CONDITION EVALUATOR

function addon:printCondition(value, spec)
    return trimOuter(printSingle(value, spec))
end

function addon:validateCondition(value, spec)
    return validateSingle(value, spec)
end

function addon:usefulCondition(value)
    return usefulSingle(value)
end

-- A rotation with no switch condition (none at all, an empty one, or a tree
-- with nothing in it) matches whenever it is otherwise eligible: its
-- specializations, level and edition gates still apply, and priority decides
-- among everything that matches. The user can always disable it. A tree that
-- is not empty but is broken (an unknown condition) is not "no switch": it
-- fails validation and the rotation cannot be selected.
function addon:HasSwitchCondition(switch)
    return type(switch)=='table' and self:usefulCondition(switch)
end
