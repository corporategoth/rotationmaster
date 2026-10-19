local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local docs={
    evaluate={description=L['Decide whether this condition currently matches.'],args={{'value','table',L['The stored values for this condition.']},{'cache','table',L['Shared data for this evaluation cycle.']},{'evalStart','number',L['Evaluation start time, in seconds from GetTime().']}},returns={'boolean | nil',L['True matches; false or nil does not match.']}},
    valid={description=L['Check whether the stored condition values are complete and valid.'],args={{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'boolean',L['True when the condition can be evaluated.']}},
    print={description=L['Describe the condition in readable words.'],args={{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'string',L['The human-readable condition summary.']}},
    widget={description=L['Build the controls used to edit this condition.'],args={{'parent','RMConditionGroup',L['The condition field container supplied by the UI adapter.']},{'spec','number',L['Rotation specialization scope.']},{'value','table',L['The stored values for this condition.']}},returns={'nil',L['Add controls to the supplied container.']}},
    help={description=L['Build the help content for this condition.'],args={{'frame','RMConditionGroup',L['The help container supplied by the UI adapter.']}},returns={'nil',L['Add help content to the supplied container.']}},
    on_register={description=L['Initialize resources when the condition is registered.'],args={{'tag','string',L['The condition identifier.']}},returns={'nil',L['No return value is used.']}},
    on_unregister={description=L['Release resources when the condition is removed or replaced.'],args={{'tag','string',L['The condition identifier.']}},returns={'nil',L['No return value is used.']}},
}
local callbacks={}
for name,entry in pairs(docs) do local args={};for _,arg in ipairs(entry.args) do args[#args+1]=arg[1] end;callbacks[name]=table.concat(args,', ') end
addon.CustomConditionCallbacks=callbacks;addon.CustomConditionCallbackDocs=docs
function addon:CustomConditionDocumentation(name)
    local doc=docs[name];if not doc then return '' end
    local lines={doc.description,'|cffffcc55'..L['Arguments']..'|r'}
    for _,arg in ipairs(doc.args) do lines[#lines+1]='|cffffcc55'..arg[1]..'|r (|cff66ccff'..arg[2]..'|r): '..arg[3] end
    lines[#lines+1]='|cffffcc55'..L['Returns']..'|r |cff66ccff'..doc.returns[1]..'|r: '..doc.returns[2]
    return table.concat(lines,'\n')
end
local kinds={string=true,number=true,boolean=true,condition=true,['condition[]']=true}
function addon:FormatCustomFieldSchema(fields)
    local normalized,why=self:NormalizeCustomFieldSchema(fields,true);if not normalized then return nil,why end
    local function format(value)
        if type(value)=='string' then return value end
        local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
        local parts={};for _,key in ipairs(keys) do parts[#parts+1]=(type(key)=='string' and (key:match('^[%a_][%w_]*$') and key or '['..string.format('%q',key)..']')..' = ' or '')..format(value[key]) end
        return '{ '..table.concat(parts,', ')..' }'
    end
    return format(normalized)
end
function addon:ParseCustomFieldSchema(text)
    if type(text)~='string' or #text>32768 then return nil,'schema-limit' end
    local cursor,nodes=1,0
    local function skip() local _,last=text:find('^%s*',cursor);cursor=(last or cursor-1)+1 end
    local function token(pattern) skip();local first,last=text:find('^'..pattern,cursor);if first then local v=text:sub(first,last);cursor=last+1;return v end end
    local parse
    parse=function(depth)
        nodes=nodes+1;if depth>16 or nodes>512 then error('schema-limit',0) end
        if token('{') then
            local result,index={},1
            if token('}') then return result end
            repeat
                local start=cursor;local name=token('[%a_][%w_]*');local key
                if not name and token('%[') then
                    local quote=token('"') or token("'");if not quote then error('invalid-field-name',0) end
                    local pieces={};local closed=false
                    while cursor<=#text do
                        local ch=text:sub(cursor,cursor);cursor=cursor+1
                        if ch==quote then closed=true;break end
                        if ch=='\\' then ch=text:sub(cursor,cursor);cursor=cursor+1;if ch~=quote and ch~='\\' then error('invalid-field-name',0) end end
                        pieces[#pieces+1]=ch
                    end
                    if not closed or not token('%]') then error('invalid-field-name',0) end;name=table.concat(pieces)
                end
                if name and token('=') then key=name else cursor=start;key=index;index=index+1 end
                if result[key]~=nil then error('duplicate-field',0) end
                result[key]=parse(depth+1)
                if token('}') then return result end
                if not token(',') then error('expected-comma',0) end
            until false
        end
        local kind=token('[%a_][%w_]*%[%]') or token('[%a_][%w_]*')
        if not kinds[kind] then error('unknown-field-type',0) end;return kind
    end
    local ok,value=pcall(parse,0);if not ok then return nil,value end;skip();if cursor<=#text then return nil,'unexpected-schema-text' end
    return self:NormalizeCustomFieldSchema(value,true)
end
function addon:NormalizeCustomConditionParameters(parameters)
    if parameters==nil then return {} end
    if type(parameters)~='table' or getmetatable(parameters) then return nil,'invalid-callback-parameters' end
    local result={}
    for name,args in pairs(parameters) do
        if not callbacks[name] or type(args)~='table' or getmetatable(args) or #args>32 then return nil,'invalid-callback-parameters' end
        local count=0;for index in pairs(args) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#args then return nil,'invalid-callback-parameters' end end
        if count~=#args then return nil,'invalid-callback-parameters' end
        for index,arg in ipairs(args) do if type(arg)~='string' or not arg:match('^[A-Za-z_][A-Za-z_0-9]*$') and not (arg=='...' and index==#args) then return nil,'invalid-callback-parameters' end end
        result[name]=self:CopySettingsData(args)
    end
    return result
end
function addon:NormalizeCustomConditionRequiredFields(required,fields)
    if type(required)~='table' or getmetatable(required) or #required>128 then return nil end
    local result,seen={},{};local count=0
    for index in pairs(required) do count=count+1;if type(index)~='number' or index%1~=0 or index<1 or index>#required then return nil end end
    if count~=#required then return nil end
    for _,name in ipairs(required) do if type(name)~='string' or fields[name]==nil or seen[name] then return nil end;seen[name]=true;result[#result+1]=name end
    return result
end
function addon:CustomConditionSignature(source,name)
    return 'function('..callbacks[name]..')'
end
function addon:CustomConditionParameterAliases(source,name)
    local aliases={};local doc=docs[name]
    for index,original in ipairs(source.parameters and source.parameters[name] or {}) do
        local canonical=doc and doc.args[index] and doc.args[index][1]
        if canonical and original~='...' and original~=canonical then aliases[original]=canonical end
    end
    return aliases
end
function addon:CompileCustomConditionCallback(key,name,code,bindings,parameters)
    local params=callbacks[name]
    if not params or type(code)~='string' then return nil,'invalid-callback' end
    local names,values={},{};for alias,canonical in pairs(self:CustomConditionParameterAliases({parameters=parameters},name)) do names[#names+1]=alias;values[#values+1]=canonical end
    -- Original packaged names stay compatible while the editor and new code
    -- always receive the complete public callback contract.
    local aliases=#names>0 and 'local '..table.concat(names,',')..'='..table.concat(values,',')..'\n' or ''
    return self:CompileLuaCallbackBody(aliases..code,params,bindings,'@RotationMaster:custom:'..tostring(key):sub(1,128)..':'..name)
end
function addon:ValidateCustomConditionSource(key,source,compatibility,allowUnavailable)
    if type(loadstring)~='function' then return nil,{field='compiler',reason='compiler-unavailable'} end
    if not self:IsCustomConditionIdentifier(key,compatibility) then return nil,{field='identifier',reason='invalid-identifier'} end
    if type(source)~='table' or type(source.description)~='string' or not source.description:find('%S') or not compatibility and #source.description>4096 or not self:IsCategoryIcon(source.icon) then return nil,{field='description',reason='incomplete-definition'} end
    if source.disabled~=nil and type(source.disabled)~='boolean' then return nil,{field='disabled',reason='invalid-disabled-flag'} end
    if not compatibility then for field in pairs(source) do if field~='description' and field~='icon' and field~='fields' and field~='disabled' and field~='fieldOrder' and field~='bindings' and field~='parameters' and field~='requiredFields' and not callbacks[field] then return nil,{field=field,reason='unknown-field'} end end end
    local fields,why=self:NormalizeCustomFieldSchema(source.fields,true);if not fields then return nil,{field='fields',reason=why} end
    if source.fieldOrder~=nil and not self:NormalizeCustomFieldOrder(source.fieldOrder,fields) then return nil,{field='fields',reason='invalid-field-order'} end
    local parameters,parameterError=self:NormalizeCustomConditionParameters(source.parameters);if not parameters then return nil,{field='parameters',reason=parameterError} end
    local bindings,unavailable
    if source.bindings~=nil then
        local arguments={{name='value'},{name='cache'},{name='evalStart'},{name='spec'},{name='parent'},{name='frame'},{name='tag'}}
        for _,aliases in pairs(parameters) do for _,name in ipairs(aliases) do arguments[#arguments+1]={name=name} end end
        local why;bindings,why=self:NormalizeFunctionBindings(source.bindings,arguments)
        if not bindings then return nil,{field='bindings',reason=why} end
        local available,problem=self:AreFunctionBindingsAvailable(bindings);if not available then if not allowUnavailable then return nil,{field='bindings',reason=problem} end;unavailable=problem end
    end
    local required;if source.requiredFields then required=self:NormalizeCustomConditionRequiredFields(source.requiredFields,fields);if not required then return nil,{field='requiredFields',reason='invalid-required-fields'} end end
    local compiled,total={},0
    for name in pairs(callbacks) do
        local code=source[name];if type(code)~='string' or not compatibility and #code>65536 then return nil,{callback=name,reason='code-limit'} end;total=total+#code;if not compatibility and total>262144 then return nil,{callback=name,reason='code-limit'} end
        local fn,errorText=self:CompileCustomConditionCallback(key,name,code,bindings,parameters)
        if not fn then return nil,{callback=name,reason='syntax-error',detail=errorText} end
        compiled[name]=fn
    end
    return {valid=true,compiled=compiled,fields=fields,bindings=bindings,parameters=parameters,requiredFields=required,unavailable=unavailable}
end
function addon:CompileCustomCondition(key,source,compatibility)
    if type(source)=='table' and source.disabled==true then
        if not self:IsCustomConditionIdentifier(key,true) then return nil,{field='identifier',reason='invalid-identifier'} end
        return {description=source.description or key,icon=source.icon,fields=self:NormalizeCustomFieldSchema(source.fields,true) or {},customCode=true,disabled=true}
    end
    local checked,why=self:ValidateCustomConditionSource(key,source,compatibility,true);if not checked then return nil,why end
    local definition={description=source.description,icon=source.icon,fields=checked.fields,customCode=true,functionBindings=checked.bindings,requiredFields=checked.requiredFields,functionUnavailable=checked.unavailable,functionSuspended=checked.unavailable~=nil}
    for name,chunk in pairs(checked.compiled) do
        local ok,binder=pcall(chunk);if not ok or type(binder)~='function' then return nil,{callback=name,reason='compile-failed'} end
        local bound,fn=pcall(binder,self,L);if not bound or type(fn)~='function' then return nil,{callback=name,reason='compile-failed'} end;definition[name]=fn
    end
    return definition
end
function addon:InstallCustomCondition(key,source,expected,expectedSource)
    local registry=self.conditionDefinitions or self.definitions;local previous=registry and registry[key]
    if previous~=expected or previous and not (self.db.global.custom_conditions or {})[key] then return false,{field='identifier',reason='definition-changed'} end
    local saved=(self.db.global.custom_conditions or {})[key]
    if saved~=nil and previous==nil and expectedSource==nil or expectedSource~=nil and not self:SettingsDataEqual(saved,expectedSource) then return false,{field='identifier',reason='definition-changed'} end
    local definition,why=self:CompileCustomCondition(key,source,expectedSource~=nil);if not definition then return false,why end
    local ok
    if self.Diagnostics then ok=self.Diagnostics:Call({module='custom_conditions',operation='register',conditionTag=key,customCode=true},self.RegisterCondition,self,key,definition)
    else ok=pcall(self.RegisterCondition,self,key,definition) end
    if not ok then
        if registry then registry[key]=previous end
        -- Trusted hooks can have arbitrary external effects. Restore registry
        -- and saved source; restoring the prior hook's setup is best effort.
        if previous and not previous.disabled and previous.on_register then pcall(previous.on_register,key) end
        return false,{field='registration',reason='registration-failed'}
    end
    self.db.global.custom_conditions=self.db.global.custom_conditions or {};self.db.global.custom_conditions[key]=self:CopySettingsData(source);return true
end
function addon:NewCustomConditionDraft(key,source)
    local d={key=key or '',value=self:CopySettingsData(source),undo={},redo={},bytes=0}
    d.baseline={key=d.key,value=self:CopySettingsData(d.value)}
    local function weight(v) if type(v)=='string' then return #v+24 elseif type(v)~='table' then return 16 end;local n=64;for k,c in pairs(v) do n=n+weight(k)+weight(c) end;return n end
    function d:Snapshot() return addon:CopySettingsData({key=self.key,value=self.value,context=self.context}) end
    function d:IsDirty() return not addon:SettingsDataEqual(self:Snapshot(),self.baseline) end
    function d:Change(change)
        local before=self:Snapshot();change(self)
        if addon:SettingsDataEqual(before,self:Snapshot()) then return false end
        self.undo[#self.undo+1]=before;self.redo={};self.bytes=0;for _,v in ipairs(self.undo) do self.bytes=self.bytes+weight(v) end
        while #self.undo>100 or self.bytes>4194304 do self.bytes=self.bytes-weight(table.remove(self.undo,1)) end;return true
    end
    function d:SetFunction(name,code) if not callbacks[name] then return false end;return self:Change(function(state) state.value[name]=code end) end
    function d:Travel(redo)
        local from=redo and self.redo or self.undo;local to=redo and self.undo or self.redo;if #from==0 then return false end
        to[#to+1]=self:Snapshot();local state=table.remove(from);self.key=state.key;self.value=state.value;self.context=state.context;return true
    end
    function d:Undo() return self:Travel(false) end
    function d:Redo() return self:Travel(true) end
    function d:MarkSaved() self.baseline=self:Snapshot();self.undo={};self.redo={};self.bytes=0 end
    return d
end
