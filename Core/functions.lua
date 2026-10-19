local addon_name,addon=...
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
function addon:NormalizeFunctionBindings(bindings,arguments)
    if bindings==nil then return {} end
    if type(bindings)~='table' or getmetatable(bindings) then return nil,'invalid-function-bindings' end
    local result,count={},0;local names={addon=true,L=true};for _,argument in ipairs(arguments or {}) do names[argument.name]=true end
    for alias,id in pairs(bindings) do
        count=count+1
        if count>128 or not identifier(alias) or names[alias] or not text(id,512,true) then return nil,'invalid-function-bindings' end
        result[alias]=id
    end
    return result
end
function addon:FunctionBindingPrelude(bindings)
    local keys={};for alias in pairs(bindings or {}) do keys[#keys+1]=alias end;table.sort(keys)
    local lines={};for _,alias in ipairs(keys) do lines[#lines+1]='local '..alias..'=addon:RequireFunctionBinding('..string.format('%q',bindings[alias])..')' end
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
    return loadstring('return function(addon,L) return function('..parameters..')\n'..self:FunctionBindingPrelude(bindings)..'\n'..code..'\nend end',chunkName)
end
function addon:ValidateCustomFunctionSource(id,source)
    if not self:IsCustomFunctionIdentifier(id) then return nil,'invalid-function-identifier' end
    if type(source)~='table' or getmetatable(source) or not text(source.description,4096,true) or not text(source.code,65536) or source.name~=nil and not text(source.name,256) or source.disabled~=nil and type(source.disabled)~='boolean' then return nil,'invalid-function-source' end
    local allowed={name=true,description=true,args=true,returns=true,code=true,bindings=true,disabled=true}
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
                for _,entry in ipairs(cleaned) do entry[2].functionSuspended=nil;if entry[2].on_register then pcall(entry[2].on_register,entry[1]) end end
                return nil,'function-consumer-cleanup-failed'
            end
            definition.functionSuspended=true;cleaned[#cleaned+1]={id,definition}
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
            definition.functionUnavailable=not ok and why or nil
            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted+1]={id=id,definition=definition}
                local registered=true;if definition.on_register then registered=pcall(definition.on_register,id) end
                if registered then definition.functionSuspended=nil else successful=false;definition.functionUnavailable='function-consumer-registration-failed' end
            end
            if self.ResetConditionQuarantine then self:ResetConditionQuarantine(definition) end
        end
    end
    self.conditionRegistryVersion=(self.conditionRegistryVersion or 0)+1
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
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
function addon:RemoveCustomFunction(id,expected)
    local current=(self.db.global.custom_functions or {})[id];if not current or not self:SettingsDataEqual(current,expected) then return nil,'function-changed' end
    local sources=self:CopySettingsData(self.db.global.custom_functions);sources[id]=nil;local registry,why=self:BuildFunctionRegistry(sources);if not registry then return nil,why end
    local prepared,prepareError=self:PrepareFunctionConsumerTransition(registry);if not prepared then return nil,prepareError end
    self.db.global.custom_functions=sources;self.functionRegistry=registry;self.functionRegistryVersion=(self.functionRegistryVersion or 0)+1;self:RefreshFunctionConsumers();return true
end
