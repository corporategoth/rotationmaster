local _,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local MAX_ENTRIES,MAX_BYTES,MAX_DEPTH=128,1048576,64
-- Bound and reject hostile data before any recursive copy or source compilation.
local function portable(value)
    local active,nodes,bytes={},0,0
    local function visit(v,depth)
        nodes=nodes+1;if nodes>50000 or depth>MAX_DEPTH then return false end
        local kind=type(v)
        if kind=='string' then bytes=bytes+#v;return bytes<=MAX_BYTES
        elseif kind=='nil' or kind=='boolean' then return true
        elseif kind=='number' then return v==v and v~=math.huge and v~=-math.huge
        elseif kind~='table' or getmetatable(v) or active[v] then return false end
        active[v]=true
        for k,c in pairs(v) do if type(k)~='string' and type(k)~='number' or not visit(k,depth+1) or not visit(c,depth+1) then return false end end
        active[v]=nil;return true
    end
    return visit(value,0)
end
local function dense(value)
    if type(value)~='table' or #value>MAX_ENTRIES then return false end
    local n=0;for k in pairs(value) do n=n+1;if type(k)~='number' or k%1~=0 or k<1 or k>#value then return false end end
    return n==#value
end
local function fields(value,allowed)
    if type(value)~='table' then return false end
    for k in pairs(value) do if not allowed[k] then return false end end;return true
end
local function identity(id) return type(id)=='string' and #id>0 and #id<=512 and not id:find('%c') end
local function name(value) return value==nil or type(value)=='string' and #value<=256 end
local function builtin(id) return type(id)=='string' and id:sub(1,8)=='builtin:' end
local function keys(value) local r={};for k in pairs(value or {}) do r[#r+1]=k end;table.sort(r);return r end
local function canonical(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local ordered={};for k in pairs(value) do ordered[#ordered+1]=k end
    table.sort(ordered,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local out={'{'};for _,k in ipairs(ordered) do local v=canonical(value[k]);local key=canonical(k);out[#out+1]=#key..':'..key..#v..':'..v end;out[#out+1]='}';return table.concat(out)
end
function addon:FunctionSourceHash(source)
    if not portable(source) then return nil end
    local hash=5381;local text=canonical(source);for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
    return string.format('%08x',hash)
end
-- Explicit bindings are the only remappable helper reference. Ignore comments
-- and strings when detecting handwritten resolver calls, without executing Lua.
-- Linear in the source: nothing here copies the remainder of the code.
local function manualReference(code)
    local tokens,i={},1
    while i<=#code do
        local prefix=code:match('^%-%-%[(=*)%[',i)
        local long=code:match('^%[(=*)%[',i)
        if prefix~=nil or long~=nil then
            local equal=prefix or long;local start=i+(prefix~=nil and 4 or 2)+#equal
            local first,last=code:find(']'..equal..']',start,true)
            if prefix==nil then
                local literal=code:sub(start,(first or #code+1)-1)
                tokens[#tokens+1]=(literal=='RequireFunctionBinding' or literal=='ResolveFunctionBinding') and 'resolver-string' or 'string'
            end
            i=last and last+1 or #code+1
        elseif code:sub(i,i+1)=='--' then local last=code:find('\n',i+2,true);i=last or #code+1
        elseif code:sub(i,i)=='"' or code:sub(i,i)=="'" then
            local quote=code:sub(i,i);local start=i;i=i+1
            while i<=#code do local ch=code:sub(i,i);i=i+1;if ch=='\\' then i=i+1 elseif ch==quote then break end end
            local literal=code:sub(start+1,i-2)
            if literal=='RequireFunctionBinding' or literal=='ResolveFunctionBinding' then tokens[#tokens+1]='resolver-string' else tokens[#tokens+1]='string' end
        else
            local word=code:match('^[A-Za-z_][A-Za-z_0-9]*',i)
            if word then tokens[#tokens+1]=word;i=i+#word else local ch=code:sub(i,i);if not ch:match('%s') then tokens[#tokens+1]=ch end;i=i+1 end
        end
    end
    local receivers={addon=true}
    for index,token in ipairs(tokens) do
        if tokens[index+1]=='=' and receivers[tokens[index+2]] then receivers[token]=true end
        -- Computed access on the RM namespace cannot provide a stable helper
        -- identity. Diagnose it instead of guessing what the Lua will resolve.
        if receivers[token] and tokens[index+1]=='[' or (token=='RequireFunctionBinding' or token=='ResolveFunctionBinding') and (tokens[index-1]==':' or tokens[index-1]=='.') or token=='resolver-string' and tokens[index-1]=='[' then return true end
    end
end
local function checkSource(self,kind,id,source)
    if type(source)~='table' then return nil,'invalid-bundle-source' end
    if kind=='function' then
        if type(source.code)=='string' and #source.code<=65536 and manualReference(source.code) then return nil,'explicit-function-binding-required' end
        return self:ValidateCustomFunctionSource(builtin(id) and 'IMPORTED_BUILTIN' or id,source)
    end
    if kind~='condition' then return nil,'invalid-bundle-kind' end
    for callback in pairs(self.CustomConditionCallbacks or {}) do if type(source[callback])=='string' and manualReference(source[callback]) then return nil,'explicit-function-binding-required' end end
    return self:ValidateCustomConditionSource(id,source,false,true)
end
local function lookup(self,id)
    local built=self.builtinFunctions and self.builtinFunctions[id]
    return built and built.source or (self.db.global.custom_functions or {})[id],built~=nil
end
local function requirementHashMatches(self,requirement,current,isBuiltin)
    if self:FunctionSourceHash(current)==requirement.hash then return true end
    if not isBuiltin then return false end
    -- A declared ownership move may change only its source namespace. Keep
    -- executable bodies, arguments, bindings and documentation in the hash.
    local builtinRecord=self.builtinFunctions and self.builtinFunctions[requirement.id]
    for _,namespace in ipairs(builtinRecord and builtinRecord.compatibilityNamespaces or {}) do
        local previous=self:CopySettingsData(current);previous.namespace=namespace
        if self:FunctionSourceHash(previous)==requirement.hash then return true end
    end
    -- Older packaged catalogs used the captured local alias as the display
    -- name and had no namespace metadata. Reconstruct only that exact shape;
    -- executable code, arguments, bindings and documentation remain hashed.
    local alias=requirement.id:match('^builtin:.*:([^:]+)$') or requirement.id:match('^builtin:([^:]+)$')
    if not alias then return false end
    local legacy=self:CopySettingsData(current);legacy.namespace=nil;legacy.name=alias
    return self:FunctionSourceHash(legacy)==requirement.hash
end
function addon:BuildFunctionBundle(kind,id,source,includeDependencies)
    if kind~='function' and kind~='condition' or not identity(id) then return nil,'invalid-bundle-root' end
    source=source or (kind=='function' and lookup(self,id) or (self.db.global.custom_conditions or {})[id])
    if not portable(source) then return nil,'bundle-data-limit' end
    local checked,why=checkSource(self,kind,id,source);if not checked then return nil,why end
    local bundle={format='RM-FunctionBundle',version=1,root={kind=kind,id=id,name=source.name or id,source=self:CopySettingsData(source)},dependencies={},requirements={}}
    local origins=self.db.global.function_import_origins or {};bundle.root.provenance=self:CopySettingsData(origins[kind..':'..id])
    local active,seen,count={}, {},0;if kind=='function' then active[id]=true end
    local function visit(dependency,depth)
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[dependency] then return nil,'function-cycle' end;if seen[dependency] then return true end
        count=count+1;if count>MAX_ENTRIES then return nil,'bundle-entry-limit' end
        local dependencySource,isBuiltin=lookup(self,dependency);if not dependencySource then return nil,'missing-function:'..dependency end
        if not portable(dependencySource) then return nil,'bundle-data-limit' end
        active[dependency]=true
        if not isBuiltin then local valid,errorText=checkSource(self,'function',dependency,dependencySource);if not valid then return nil,errorText end end
        -- Built In closures own their internal dependencies; only their stable
        -- public binding and source version cross this transport boundary.
        if not isBuiltin then for _,alias in ipairs(keys(dependencySource.bindings)) do local ok,errorText=visit(dependencySource.bindings[alias],depth+1);if not ok then return nil,errorText end end end
        active[dependency]=nil;seen[dependency]=true
        bundle.requirements[#bundle.requirements+1]={id=dependency,name=dependencySource.name or dependency,hash=self:FunctionSourceHash(dependencySource),builtin=isBuiltin}
        if not isBuiltin and includeDependencies~=false then bundle.dependencies[#bundle.dependencies+1]={id=dependency,name=dependencySource.name or dependency,source=self:CopySettingsData(dependencySource),provenance=self:CopySettingsData(origins['function:'..dependency])} end
        return true
    end
    for _,alias in ipairs(keys(source.bindings)) do local ok,errorText=visit(source.bindings[alias],1);if not ok then return nil,errorText end end
    if not portable(bundle) then return nil,'bundle-data-limit' end;return bundle
end
local function normalize(self,value)
    if not portable(value) or type(value)~='table' then return nil,'bundle-data-limit' end
    if value.format=='RM-CustomCondition' and value.version==1 then
        value={format='RM-FunctionBundle',version=1,root={kind='condition',id=value.name,name=value.name,source=value.condition},dependencies={},requirements={}}
    elseif value.format=='RM-CustomFunction' and value.version==1 then
        value={format='RM-FunctionBundle',version=1,root={kind='function',id=value.id or value.name,name=value.name,source=value.source or value['function']},dependencies={},requirements={}}
    end
    if value.format~='RM-FunctionBundle' or value.version~=1 or not fields(value,{format=true,version=true,root=true,dependencies=true,requirements=true}) or not fields(value.root,{kind=true,id=true,name=true,source=true,provenance=true}) or not identity(value.root.id) or not name(value.root.name) or not dense(value.dependencies) or not dense(value.requirements) then return nil,'invalid-function-bundle' end
    local root=value.root;local checked,why=checkSource(self,root.kind,root.id,root.source);if not checked then return nil,why end
    local included,required={},{}
    if root.kind=='function' then included[root.id]=root end
    for _,record in ipairs(value.dependencies) do
        if not fields(record,{id=true,name=true,source=true,provenance=true}) or not identity(record.id) or builtin(record.id) or not name(record.name) or included[record.id] then return nil,'invalid-bundle-dependency' end
        local valid,errorText=checkSource(self,'function',record.id,record.source);if not valid then return nil,errorText end;included[record.id]=record
    end
    for _,record in ipairs(value.requirements) do
        if not fields(record,{id=true,name=true,hash=true,builtin=true}) or not identity(record.id) or not name(record.name) or type(record.hash)~='string' or not record.hash:match('^%x%x%x%x%x%x%x%x$') or type(record.builtin)~='boolean' or record.builtin~=builtin(record.id) or required[record.id] or root.kind=='function' and root.id==record.id then return nil,'invalid-bundle-requirement' end
        if included[record.id] and self:FunctionSourceHash(included[record.id].source)~=record.hash then return nil,'bundle-hash-mismatch' end;required[record.id]=record
    end
    local active,seen={},{};if root.kind=='function' then active[root.id]=true end
    local function visit(id,depth)
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[id] then return nil,'function-cycle' end;if seen[id] then return true end
        if not included[id] and not required[id] then return nil,'missing-bundle-requirement:'..tostring(id) end
        active[id]=true
        local record=included[id]
        if record then for _,dependency in pairs(record.source.bindings or {}) do local ok,errorText=visit(dependency,depth+1);if not ok then return nil,errorText end end end
        active[id]=nil;seen[id]=true;return true
    end
    for _,id in pairs(root.source.bindings or {}) do local ok,errorText=visit(id,1);if not ok then return nil,errorText end end
    for _,record in ipairs(value.dependencies) do if not seen[record.id] then return nil,'unrelated-bundle-dependency' end end
    return self:CopySettingsData(value)
end
function addon:ParseFunctionBundleImport(text,codec)
    local decoded,why=codec:Decode(text);if not decoded then return nil,why end;return normalize(self,decoded.value)
end
local pending=setmetatable({},{__mode='k'})
local function effects(self,id)
    local functions,conditions=self.db.global.custom_functions or {},self.db.global.custom_conditions or {}
    local affected={[id]=true};local changed=true
    while changed do
        changed=false
        for key,source in pairs(functions) do
            if not affected[key] then for _,dependency in pairs(type(source)=='table' and type(source.bindings)=='table' and source.bindings or {}) do if affected[dependency] then affected[key]=true;changed=true;break end end end
        end
    end
    local result={};for key in pairs(affected) do if key~=id then result[#result+1]='function:'..key end end
    for key,source in pairs(conditions) do for _,dependency in pairs(type(source)=='table' and type(source.bindings)=='table' and source.bindings or {}) do if affected[dependency] then result[#result+1]='condition:'..key;break end end end
    table.sort(result);return result
end
function addon:PlanFunctionBundleImport(value,choices)
    local bundle,why=normalize(self,value);if not bundle then return nil,why end
    choices=choices or {};if type(choices)~='table' or not portable(choices) then return nil,'invalid-import-choices' end
    for id,choice in pairs(choices) do if type(id)~='string' or not fields(choice,{action=true,id=true,name=true}) or not name(choice.name) then return nil,'invalid-import-choice' end end
    local plan={bundle=bundle,rows={},requirements={},problems={},warnings={},valid=true,remap={}}
    local targets,baselines,chosenIDs={},{},{};local registry=self.conditionDefinitions or self.definitions or {}
    local function problem(id,reason) plan.valid=false;plan.problems[#plan.problems+1]={id=id,reason=reason} end
    local function row(record,kind)
        local choiceKey=kind..':'..record.id;chosenIDs[record.id]=true;chosenIDs[choiceKey]=true
        local choice=choices[choiceKey] or choices[record.id] or {};if not fields(choice,{action=true,id=true,name=true}) or not name(choice.name) then return nil,'invalid-import-choice' end
        local needsClone=builtin(record.id) and choice.id==nil
        local target=choice.id or (needsClone and ('IMPORTED_'..record.id:gsub('[^A-Za-z_0-9]','_')):sub(1,128) or record.id)
        if kind=='function' and not self:IsCustomFunctionIdentifier(target) or kind=='condition' and not self:IsCustomConditionIdentifier(target) then return nil,'invalid-import-destination' end
        local targetKey=kind..':'..target;if targets[targetKey] then return nil,'duplicate-import-destination' end;targets[targetKey]=true
        local existing;if kind=='function' then existing=(self.db.global.custom_functions or {})[target] else existing=(self.db.global.custom_conditions or {})[target] end
        local protected=kind=='function' and self.builtinFunctions and self.builtinFunctions[target] or kind=='condition' and registry[target] and not existing
        if protected then return nil,'builtin-import-destination' end
        local action=choice.action
        if needsClone then action='conflict' end
        if action==nil then action=existing and (self:SettingsDataEqual(existing,record.source) and 'reuse' or 'conflict') or 'create' end
        if action~='reuse' and action~='replace' and action~='rename' and action~='create' and action~='conflict' then return nil,'invalid-import-action' end
        if action=='rename' and target==record.id or (action=='rename' or action=='create') and existing or (action=='reuse' or action=='replace') and not existing then return nil,'invalid-import-action' end
        if action=='conflict' then problem(record.id,'dependency-conflict') end
        local entry={kind=kind,choiceKey=choiceKey,originalID=record.id,originalName=record.name or record.id,source=self:CopySettingsData(record.source),originalSource=self:CopySettingsData(record.source),provenance=self:CopySettingsData(record.provenance),destinationID=target,action=action,existing=self:CopySettingsData(existing),effects=kind=='function' and effects(self,target) or {}}
        if choice.name and kind=='function' then entry.source.name=choice.name end
        entry.destinationName=entry.source.name or target
        plan.rows[#plan.rows+1]=entry;if kind=='function' then plan.remap[record.id]=target end
        baselines[targetKey]={kind=kind,id=target,source=self:CopySettingsData(existing),definition=kind=='condition' and registry[target] or nil}
        return true
    end
    for _,record in ipairs(bundle.dependencies) do local ok,errorText=row(record,'function');if not ok then return nil,errorText end end
    local ok,errorText=row(bundle.root,bundle.root.kind);if not ok then return nil,errorText end
    for id in pairs(choices) do if not chosenIDs[id] then return nil,'unknown-import-choice' end end
    local included={};for _,record in ipairs(bundle.dependencies) do included[record.id]=true end
    for _,requirement in ipairs(bundle.requirements) do
        local current,isBuiltin=lookup(self,requirement.id);local status='included'
        if not included[requirement.id] then
            local available=self:FunctionAvailable(requirement.id)
            if not current then status='missing-function' elseif isBuiltin~=requirement.builtin or not requirementHashMatches(self,requirement,current,isBuiltin) then status='incompatible-function' elseif not available then status='unavailable-function' else status='available' end
            if status~='available' then problem(requirement.id,status) end
            baselines['requirement:'..requirement.id]={kind='requirement',id=requirement.id,source=self:CopySettingsData(current),builtin=isBuiltin}
        end
        local reviewed=self:CopySettingsData(requirement);reviewed.status=status;plan.requirements[#plan.requirements+1]=reviewed
    end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {})
    for _,entry in ipairs(plan.rows) do
        for alias,id in pairs(entry.source.bindings or {}) do entry.source.bindings[alias]=plan.remap[id] or id end
        if entry.kind=='function' and entry.action~='reuse' and entry.action~='conflict' then sources[entry.destinationID]=self:CopySettingsData(entry.source) end
    end
    local staged,compileError=self:BuildFunctionRegistry(sources);if not staged then return nil,compileError end
    -- Availability stops at disabled records; structural validation must still
    -- follow their declarations to reject cycles created by reuse/remapping.
    local graphSeen,graphCount={},0
    local function structural(id,active,depth,seen)
        if not graphSeen[id] then
            graphSeen[id]=true;graphCount=graphCount+1
            if graphCount>MAX_ENTRIES+1 then return nil,'bundle-entry-limit' end
            local current,isBuiltin=lookup(self,id)
            baselines['graph:'..id]={kind=isBuiltin and 'requirement' or 'graph',id=id,source=self:CopySettingsData(current),builtin=isBuiltin}
        end
        if self.builtinFunctions and self.builtinFunctions[id] then return true end
        if depth>MAX_DEPTH then return nil,'function-depth' end
        if active[id] then return nil,'function-cycle' end
        if seen[id] then return true end
        local record=staged[id];if not record then return nil,'missing-function' end
        if record.problem then return nil,record.problem end
        active[id]=true
        for _,dependency in pairs(record.bindings) do local valid,reason=structural(dependency,active,depth+1,seen);if not valid then return nil,reason end end
        active[id]=nil;seen[id]=true;return true
    end
    for _,entry in ipairs(plan.rows) do
        local effective=entry.action=='reuse' and entry.existing or entry.source
        local references=entry.kind=='function' and {entry.destinationID} or effective.bindings or {}
        for _,id in pairs(references) do local valid,reason=structural(id,{},1,{});if not valid then problem(entry.originalID,reason) end end
        if entry.action~='reuse' and entry.action~='conflict' then
            local valid,sourceError=checkSource(self,entry.kind,entry.destinationID,entry.source);if not valid then return nil,sourceError end
        end
        local available,reason
        if entry.kind=='function' then available,reason=self:FunctionAvailable(entry.destinationID,staged) else available,reason=self:AreFunctionBindingsAvailable(effective.bindings,staged) end
        if not available then
            if reason=='disabled-function' or entry.source.disabled then plan.warnings[#plan.warnings+1]={id=entry.originalID,reason=reason} else problem(entry.originalID,reason) end
        end
    end
    pending[plan]={snapshot=self:CopySettingsData(plan),baselines=baselines,owner=self}
    return plan
end
function addon:ApplyFunctionBundleImport(plan)
    local saved=pending[plan];if not saved or saved.owner~=self or not self:SettingsDataEqual(plan,saved.snapshot) then return nil,'import-plan-changed' end
    if not plan.valid then return nil,'import-plan-unresolved' end
    local registry=self.conditionDefinitions or self.definitions or {}
    for _,baseline in pairs(saved.baselines) do
        local current,isBuiltin
        if baseline.kind=='condition' then current=(self.db.global.custom_conditions or {})[baseline.id];if registry[baseline.id]~=baseline.definition then return nil,'import-destination-changed' end
        elseif baseline.kind=='requirement' then current,isBuiltin=lookup(self,baseline.id);if isBuiltin~=baseline.builtin then return nil,'import-destination-changed' end
        else current=(self.db.global.custom_functions or {})[baseline.id];if self.builtinFunctions and self.builtinFunctions[baseline.id] then return nil,'import-destination-changed' end end
        if not self:SettingsDataEqual(current,baseline.source) then return nil,'import-destination-changed' end
    end
    -- Replan from immutable input against the complete current graph so unrelated
    -- edits are preserved and newly introduced cycles are checked before hooks.
    local choices={};for _,entry in ipairs(plan.rows) do choices[entry.choiceKey]={action=entry.action,id=entry.destinationID,name=entry.kind=='function' and entry.source.name or nil} end
    local fresh,why=self:PlanFunctionBundleImport(plan.bundle,choices);if not fresh or not fresh.valid then return nil,why or 'import-graph-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {})
    for _,entry in ipairs(fresh.rows) do if entry.kind=='function' and entry.action~='reuse' then sources[entry.destinationID]=self:CopySettingsData(entry.source) end end
    local staged,errorText=self:BuildFunctionRegistry(sources);if not staged then return nil,errorText end
    local conditions={}
    for _,entry in ipairs(fresh.rows) do if entry.kind=='condition' and entry.action~='reuse' then local definition,reason=self:CompileCustomCondition(entry.destinationID,entry.source,false);if not definition then return nil,reason end;conditions[#conditions+1]={entry=entry,definition=definition} end end
    local oldSources,oldRegistry,oldVersion=self.db.global.custom_functions,self.functionRegistry,self.functionRegistryVersion
    local oldConditions,oldOrigins=self.db.global.custom_conditions,self.db.global.function_import_origins
    local oldConditionVersion=self.conditionRegistryVersion
    local oldDefinitions={};for id,definition in pairs(registry) do oldDefinitions[id]={definition=definition,suspended=definition.functionSuspended,unavailable=definition.functionUnavailable} end
    local replacing={};for _,record in ipairs(conditions) do replacing[record.entry.destinationID]=true end
    local function restoreConsumers()
        for id,record in pairs(oldDefinitions) do
            local definition=record.definition;local resume=definition.functionSuspended and not record.suspended
            local changed=definition.functionSuspended~=record.suspended or definition.functionUnavailable~=record.unavailable
            definition.functionSuspended=record.suspended;definition.functionUnavailable=record.unavailable
            if changed and invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            if resume and definition.on_register and not definition.disabled and not record.unavailable then pcall(definition.on_register,id) end
        end
    end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(staged);if not prepared then return nil,prepareError end
    -- A replaced condition's cleanup belongs to the former helper graph, even
    -- when both versions of that graph are available. Suppress duplicate cleanup
    -- in RegisterCondition and resume the old hook on rollback.
    for id in pairs(replacing) do
        local previous=registry[id]
        if previous and not previous.disabled and not previous.functionUnavailable and not previous.functionSuspended then
            previous.functionSuspended=true
            if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            if previous.on_unregister and not pcall(previous.on_unregister,id) then restoreConsumers();return nil,'condition-cleanup-failed' end
        end
    end
    self.db.global.custom_functions=sources;self.functionRegistry=staged
    if invalidateDependencies then invalidateDependencies(addon,'function',nil) end
    -- Isolate saved tables too: a failing trusted hook may write to these maps.
    self.db.global.custom_conditions=self:CopySettingsData(oldConditions or {})
    self.db.global.function_import_origins=self:CopySettingsData(oldOrigins or {})
    local resumedConsumers={};local failureReason='condition-registration-failed'
    local success=pcall(function()
        for _,record in ipairs(conditions) do
            local entry=record.entry;local definition,reason=self:CompileCustomCondition(entry.destinationID,entry.source,false);if not definition then error(type(reason)=='table' and reason.reason or reason,0) end
            self:RegisterCondition(entry.destinationID,definition)
        end
        -- Resuming an existing consumer is also trusted registration. Keep the
        -- entire bundle provisional until every affected hook has succeeded.
        local refreshed,reason,attempted=self:RefreshFunctionConsumers(true);resumedConsumers=attempted
        if not refreshed then failureReason=reason;error(reason,0) end
    end)
    if not success then
        -- Release partially registered resources while their staged bindings
        -- still exist, then restore the old graph before resuming old consumers.
        for index=#resumedConsumers,1,-1 do
            local resumed=resumedConsumers[index]
            if resumed.definition.on_unregister then pcall(resumed.definition.on_unregister,resumed.id) end
        end
        for _,record in ipairs(conditions) do
            local key=record.entry.destinationID;local current=registry[key]
            if current and current~=(oldDefinitions[key] and oldDefinitions[key].definition) and current.on_unregister and not current.disabled and not current.functionUnavailable then pcall(current.on_unregister,key) end
            registry[key]=oldDefinitions[key] and oldDefinitions[key].definition
            if invalidateDependencies then invalidateDependencies(addon,'condition',key) end
        end
        self.db.global.custom_functions=oldSources;self.functionRegistry=oldRegistry;self.functionRegistryVersion=oldVersion;self.db.global.custom_conditions=oldConditions;self.db.global.function_import_origins=oldOrigins;self.conditionRegistryVersion=oldConditionVersion
        if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
        restoreConsumers();return nil,failureReason
    end
    local conditionSources=self:CopySettingsData(oldConditions or {});local origins=self:CopySettingsData(oldOrigins or {})
    for _,entry in ipairs(fresh.rows) do if entry.action~='reuse' then
        if entry.kind=='condition' then conditionSources[entry.destinationID]=self:CopySettingsData(entry.source) end
        origins[entry.kind..':'..entry.destinationID]={originalID=entry.originalID,originalName=entry.originalName,hash=self:FunctionSourceHash(entry.originalSource),importedHash=self:FunctionSourceHash(entry.source),provenance=self:CopySettingsData(entry.provenance)}
    end end
    self.db.global.custom_conditions=conditionSources;self.db.global.function_import_origins=origins;self.functionRegistryVersion=(oldVersion or 0)+1
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end;pending[plan]=nil;return true
end
