local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local reserved={['and']=true,['break']=true,['do']=true,['else']=true,['elseif']=true,['end']=true,['false']=true,['for']=true,['function']=true,['if']=true,['in']=true,['local']=true,['nil']=true,['not']=true,['or']=true,['repeat']=true,['return']=true,['then']=true,['true']=true,['until']=true,['while']=true}
local function identifier(name)
    return type(name)=='string' and #name<=128 and name:match('^[A-Za-z_][A-Za-z_0-9]*$')~=nil and not reserved[name]
end
local function text(value,limit,required) return type(value)=='string' and #value<=limit and (not required or value:find('%S')~=nil) end
local function array(value,limit)
    if type(value)~='table' or getmetatable(value) or #value>limit then return false end
    local count=0;for index in pairs(value) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#value then return false end end
    return count==#value
end
function addon:IsCustomFunctionIdentifier(id) return identifier(id) and id~='addon' and id~='L' end
local namespaceRoots={addon=true,L=true,_G=true,_ENV=true,math=true,string=true,table=true,coroutine=true,debug=true,io=true,os=true,package=true,bit=true,bit32=true,utf8=true}
local function identifierPath(path,maxSegments)
    if type(path)~='string' or #path>512 or path=='' or path:sub(1,1)=='.' or path:sub(-1)=='.' or path:find('..',1,true) then return nil end
    local parts={};for part in path:gmatch('[^.]+') do if not identifier(part) then return nil end;parts[#parts+1]=part end
    if #parts>(maxSegments or 8) then return nil end
    return parts
end
function addon:IsFunctionNamespace(namespace)
    if namespace=='' then return true end
    -- Leave room for the separator and a maximum-length callable name inside
    -- the same bounded 512-byte binding path.
    if type(namespace)~='string' or #namespace>383 then return false end
    local parts=identifierPath(namespace,7);return parts~=nil and not namespaceRoots[parts[1]]
end
function addon:FunctionNamespace(id,source)
    if type(source)=='table' and type(source.namespace)=='string' and source.namespace~='' and self:IsFunctionNamespace(source.namespace) then return source.namespace end
    local module=type(id)=='string' and id:match('^builtin:(.-):[^:]+$')
    if module then return module:gsub('%.lua$',''):gsub('[/\\]','.') end
    if type(id)=='string' and id:match('^builtin:') then return 'builtin' end
    return 'functions'
end
function addon:FunctionQualifiedName(id,source)
    return self:FunctionNamespace(id,source)..'.'..self:FunctionEditorName(id,source)
end
-- Registry IDs remain stable across name edits; a binding exposes this suggested
-- local name in a caller. Existing exports with descriptive names still load.
function addon:FunctionEditorName(id,source)
    local name=source and source.name
    if self:IsCustomFunctionIdentifier(name) then return name end
    name=type(name)=='string' and name:gsub('[^A-Za-z_0-9]','_'):gsub('^%d+','') or ''
    if name=='' then name=tostring(id or 'helper'):gsub('[^A-Za-z_0-9]','_'):gsub('^%d+','') end
    name=name:sub(1,128)
    if not self:IsCustomFunctionIdentifier(name) then name='helper_'..name:sub(1,121) end
    return name
end
function addon:NormalizeFunctionBindings(bindings,arguments)
    if bindings==nil then return {} end
    if type(bindings)~='table' or getmetatable(bindings) then return nil,'invalid-function-bindings' end
    local result,count={},0;local names={addon=true,L=true};for _,argument in ipairs(arguments or {}) do names[argument.name]=true end
    for alias,id in pairs(bindings) do
        count=count+1
        local parts=identifierPath(alias)
        if count>128 or not parts or names[parts[1]] or #parts>1 and namespaceRoots[parts[1]] or not text(id,512,true) then return nil,'invalid-function-bindings' end
        result[alias]=id
    end
    local occupied={};for alias,id in pairs(result) do occupied[alias]=id end
    if not names.functions and not result.functions then for alias,id in pairs(result) do if not alias:find('.',1,true) then
        local path='functions.'..alias;if occupied[path] and occupied[path]~=id then return nil,'invalid-function-bindings' end;occupied[path]=id
    end end end
    for alias in pairs(occupied) do
        local prefix='';for part in alias:gmatch('[^.]+') do
            if prefix~='' and occupied[prefix] then return nil,'invalid-function-bindings' end
            prefix=prefix=='' and part or prefix..'.'..part
        end
    end
    return result
end
function addon:FunctionBindingPrelude(bindings,parameters)
    local arguments={};for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do arguments[#arguments+1]={name=name} end
    local normalized,why=self:NormalizeFunctionBindings(bindings,arguments);if not normalized then return nil,why end
    bindings=normalized;local keys={};for alias in pairs(bindings) do keys[#keys+1]=alias end;table.sort(keys)
    local lines,created={},{}
    local function namespace(path)
        local prefix='';for part in path:gmatch('[^.]+') do
            local parent=prefix;prefix=prefix=='' and part or prefix..'.'..part
            if not created[prefix] then lines[#lines+1]=(parent=='' and 'local ' or '')..prefix..'={}';created[prefix]=true end
        end
    end
    for _,alias in ipairs(keys) do local parent=alias:match('^(.*)%.');if parent then namespace(parent) end end
    for _,alias in ipairs(keys) do lines[#lines+1]=(alias:find('.',1,true) and '' or 'local ')..alias..'=addon:RequireFunctionBinding('..string.format('%q',bindings[alias])..')' end
    local shadowed=bindings and bindings.functions
    for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do if name=='functions' then shadowed=true end end
    if not shadowed then
        namespace('functions');for _,alias in ipairs(keys) do if not alias:find('.',1,true) then lines[#lines+1]='functions.'..alias..'='..alias end end
    end
    return table.concat(lines,'\n')
end
function addon:NormalizeLuaSourceForEditor(code)
    code=(code or ''):gsub('^[ \t\r]*\n','')
    while code:match('^[ \t\r]*\n') do code=code:gsub('^[ \t\r]*\n','') end
    local syntax=self.LuaSyntax
    -- Use the existing Lua tokenizer/formatter so multiline literals retain
    -- their contents; stripping whitespace from every line would change them.
    if syntax and syntax.indentCode then code=syntax.decode(syntax.indentCode(syntax.encode(code),4)) end
    return code
end
function addon:CompileLuaCallbackBody(code,parameters,bindings,chunkName)
    if type(loadstring)~='function' then return nil,'compiler-unavailable' end
    -- A valid generated wrapper alone is insufficient: an unmatched `end` in
    -- the supplied body can escape into its return list and run at bind time.
    -- Check the body as an independent chunk first. Neither chunk is executed.
    local body,why=loadstring(code,chunkName);if not body then return nil,why end
    local prelude,problem=self:FunctionBindingPrelude(bindings,parameters);if not prelude then return nil,problem end
    return loadstring('return function(addon,L) return function('..parameters..')\n'..prelude..'\n'..code..'\nend end',chunkName)
end
function addon:ValidateCustomFunctionSource(id,source)
    if not self:IsCustomFunctionIdentifier(id) then return nil,'invalid-function-identifier' end
    if type(source)~='table' or getmetatable(source) or not text(source.description,4096,true) or not text(source.code,65536) or source.name~=nil and not text(source.name,256) or source.disabled~=nil and type(source.disabled)~='boolean' then return nil,'invalid-function-source' end
    if source.namespace~=nil and not self:IsFunctionNamespace(source.namespace) then return nil,'invalid-function-namespace' end
    local allowed={name=true,namespace=true,description=true,args=true,returns=true,code=true,bindings=true,disabled=true}
    for field in pairs(source) do if not allowed[field] then return nil,'unknown-function-field' end end
    if not array(source.args,32) or not array(source.returns,16) then return nil,'invalid-function-arguments' end
    local names={addon=true,L=true}
    for index,argument in ipairs(source.args) do
        if type(argument)~='table' or getmetatable(argument) or not identifier(argument.name) and not (argument.name=='...' and index==#source.args) or names[argument.name] or not text(argument.type,128,true) or not text(argument.description or '',2048) then return nil,'invalid-function-arguments' end
        names[argument.name]=true;for field in pairs(argument) do if field~='name' and field~='type' and field~='description' then return nil,'invalid-function-arguments' end end
    end
    for _,result in ipairs(source.returns) do
        if type(result)~='table' or getmetatable(result) or not text(result.type,128,true) or not text(result.description or '',2048) then return nil,'invalid-function-returns' end
        for field in pairs(result) do if field~='type' and field~='description' then return nil,'invalid-function-returns' end end
    end
    local bindings,why=self:NormalizeFunctionBindings(source.bindings,source.args);if not bindings then return nil,why end
    if source.disabled then return {bindings=bindings} end
    local params={};for _,argument in ipairs(source.args) do params[#params+1]=argument.name end
    local chunk,errorText=self:CompileLuaCallbackBody(source.code,table.concat(params,','),bindings,'@RotationMaster:function:'..id)
    if not chunk then return nil,errorText end
    return {bindings=bindings,chunk=chunk}
end
function addon:RegisterBuiltinFunction(id,source,getter,valueBinding)
    if type(id)~='string' or not id:match('^builtin:') or #id>512 or type(source)~='table' or type(getter)~='function' then return false end
    self.builtinFunctions=self.builtinFunctions or {};if self.builtinFunctions[id] then return false end
    self.builtinFunctions[id]={source=source,get=getter,valueBinding=valueBinding==true};return true
end
function addon:BuildFunctionRegistry(sources)
    if type(sources)~='table' or getmetatable(sources) then return nil,'invalid-function-registry' end
    local result={};local count=0
    for id,source in pairs(sources or {}) do
        count=count+1;if count>4096 then return nil,'function-limit' end
        local checked,why=self:ValidateCustomFunctionSource(id,source);local previous=self.functionRegistry and self.functionRegistry[id]
        local record={source=source,problem=why,bindings=checked and checked.bindings or {}};result[id]=record
        if checked and checked.chunk then
            if previous and previous.fn and self:SettingsDataEqual(previous.source,source) then record.fn=previous.fn
            else
                local ok,binder=pcall(checked.chunk)
                if ok and type(binder)=='function' then local bound,fn=pcall(binder,self,L);if bound and type(fn)=='function' then record.fn=fn else record.problem='function-compile-failed' end
                else record.problem='function-compile-failed' end
            end
        end
    end
    return result
end
function addon:InitializeFunctionRegistry()
    self.functionRegistry=self:BuildFunctionRegistry(self.db.global.custom_functions or {}) or {};self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'function',nil) end
end
function addon:FunctionAvailable(id,registry,active,depth,memo)
    registry=registry or self.functionRegistry;if not registry then self:InitializeFunctionRegistry();registry=self.functionRegistry end
    if self.builtinFunctions and self.builtinFunctions[id] then return true end
    memo=memo or {};if memo[id] then return memo[id][1],memo[id][2] end
    depth=(depth or 0)+1;if depth>64 then return nil,'function-depth' end
    active=active or {};if active[id] then return nil,'function-cycle' end
    local record=registry[id];if not record then return nil,'missing-function' end
    if record.problem then return nil,record.problem end
    if record.source.disabled then return nil,'disabled-function' end
    if not record.fn then return nil,'function-compile-failed' end
    active[id]=true
    for _,dependency in pairs(record.bindings) do local ok,why=self:FunctionAvailable(dependency,registry,active,depth,memo);if not ok then active[id]=nil;memo[id]={false,why};return nil,why end end
    active[id]=nil;memo[id]={true};return true
end
function addon:AreFunctionBindingsAvailable(bindings,registry)
    for _,id in pairs(bindings or {}) do local ok,why=self:FunctionAvailable(id,registry);if not ok then return nil,why end end;return true
end
function addon:ResolveFunctionBinding(id)
    local ok,why=self:FunctionAvailable(id);if not ok then return nil,why end
    local builtin=self.builtinFunctions and self.builtinFunctions[id]
    if builtin then
        local read,value=pcall(builtin.get);if not read then return nil,'builtin-binding-unavailable' end
        if not builtin.valueBinding and type(value)~='function' then return nil,'builtin-function-unavailable' end
        return value
    end
    return self.functionRegistry[id].fn
end
function addon:RequireFunctionBinding(id)
    local value,why=self:ResolveFunctionBinding(id);if why then error('Rotation Master function unavailable: '..tostring(id)..' ('..why..')',2) end;return value
end
-- Release resources while the old helper graph is still usable. A later
-- refresh resumes suspended consumers only after the new graph is installed.
function addon:PrepareFunctionConsumerTransition(registry)
    local cleaned={}
    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings and not definition.disabled and not definition.functionUnavailable and not definition.functionSuspended and not self:AreFunctionBindingsAvailable(definition.functionBindings,registry) then
            local ok=true;if definition.on_unregister then ok=pcall(definition.on_unregister,id) end
            if not ok then
                for _,entry in ipairs(cleaned) do entry[2].functionSuspended=nil;if invalidateDependencies then invalidateDependencies(addon,'condition',entry[1]) end;if entry[2].on_register then pcall(entry[2].on_register,entry[1]) end end
                return nil,'function-consumer-cleanup-failed'
            end
            definition.functionSuspended=true;if invalidateDependencies then invalidateDependencies(addon,'condition',id) end;cleaned[#cleaned+1]={id,definition}
        end
    end
    return true
end
-- Staged imports defer runtime selection refresh until commit and retain every
-- resume attempt so rollback can release partially initialized hook resources.
function addon:RefreshFunctionConsumers(deferRefresh)
    local successful,attempted=true,{}
    for id,definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings then
            local ok,why=self:AreFunctionBindingsAvailable(definition.functionBindings)
            local previousUnavailable=definition.functionUnavailable
            definition.functionUnavailable=not ok and why or nil
            if previousUnavailable~=definition.functionUnavailable then if invalidateDependencies then invalidateDependencies(addon,'condition',id) end end
            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted+1]={id=id,definition=definition}
                if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
                local registered=true;if definition.on_register then registered=pcall(definition.on_register,id) end
                if registered then definition.functionSuspended=nil else successful=false;definition.functionUnavailable='function-consumer-registration-failed' end
                if invalidateDependencies then invalidateDependencies(addon,'condition',id) end
            end
            if self.ResetConditionQuarantine then self:ResetConditionQuarantine(definition) end
        end
    end
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
    if invalidateDependencies then invalidateDependencies(addon,'condition',nil) end
    if not deferRefresh and self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return successful,not successful and 'function-consumer-registration-failed' or nil,attempted
end
function addon:InstallCustomFunction(id,source,expected)
    if not self:IsCustomFunctionIdentifier(id) then return nil,'invalid-function-identifier' end
    local current=(self.db.global.custom_functions or {})[id]
    if not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local checked,why=self:ValidateCustomFunctionSource(id,source);if not checked then return nil,why end
    local sources=self:CopySettingsData(self.db.global.custom_functions or {});sources[id]=self:CopySettingsData(source)
    local registry,problem=self:BuildFunctionRegistry(sources);if not registry then return nil,problem end
    if not source.disabled then local available,reason=self:FunctionAvailable(id,registry);if not available then return nil,reason end end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;if invalidateDependencies then invalidateDependencies(addon,'function',id) end;self:RefreshFunctionConsumers();return true
end
function addon:RemoveCustomFunction(id,expected)
    local current=(self.db.global.custom_functions or {})[id];if not current or not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions);sources[id]=nil;local registry,why=self:BuildFunctionRegistry(sources);if not registry then return nil,why end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;if invalidateDependencies then invalidateDependencies(addon,'function',id) end;self:RefreshFunctionConsumers();return true
end
