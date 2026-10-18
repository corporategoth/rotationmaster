local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local callbacks={on_register='tag',on_unregister='tag',valid='spec, value',evaluate='value, cache, evalStart',print='spec, value',widget='parent, spec, value',help='frame'}
addon.CustomConditionCallbacks=callbacks
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
function addon:ValidateCustomConditionSource(key,source,compatibility)
    if type(loadstring)~='function' then return nil,{field='compiler',reason='compiler-unavailable'} end
    if type(key)~='string' or (not compatibility and #key>256) or not key:match('^[%w_]+$') or ({AND=true,OR=true,NOT=true,DELETE=true})[key] then return nil,{field='identifier',reason='invalid-identifier'} end
    if type(source)~='table' or type(source.description)~='string' or not source.description:find('%S') or not compatibility and #source.description>4096 or not self:IsCategoryIcon(source.icon) then return nil,{field='description',reason='incomplete-definition'} end
    if source.disabled~=nil and type(source.disabled)~='boolean' then return nil,{field='disabled',reason='invalid-disabled-flag'} end
    if not compatibility then for field in pairs(source) do if field~='description' and field~='icon' and field~='fields' and field~='disabled' and not callbacks[field] then return nil,{field=field,reason='unknown-field'} end end end
    local fields,why=self:NormalizeCustomFieldSchema(source.fields,true);if not fields then return nil,{field='fields',reason=why} end
    local compiled,total={},0
    for name,params in pairs(callbacks) do
        local code=source[name];if type(code)~='string' or not compatibility and #code>65536 then return nil,{callback=name,reason='code-limit'} end;total=total+#code;if not compatibility and total>262144 then return nil,{callback=name,reason='code-limit'} end
        local fn,errorText=loadstring('return function(addon, L)\nreturn function('..params..')\n'..code..'\nend\nend','@RotationMaster:custom:'..key:sub(1,128)..':'..name)
        if not fn then return nil,{callback=name,reason='syntax-error',detail=errorText} end
        compiled[name]=fn
    end
    return {valid=true,compiled=compiled,fields=fields}
end
function addon:CompileCustomCondition(key,source,compatibility)
    if type(source)=='table' and source.disabled==true then
        if type(key)~='string' or not key:match('^[%w_]+$') or ({AND=true,OR=true,NOT=true,DELETE=true})[key] then return nil,{field='identifier',reason='invalid-identifier'} end
        return {description=source.description or key,icon=source.icon,fields=self:NormalizeCustomFieldSchema(source.fields,true) or {},customCode=true,disabled=true}
    end
    local checked,why=self:ValidateCustomConditionSource(key,source,compatibility);if not checked then return nil,why end
    local definition={description=source.description,icon=source.icon,fields=checked.fields,customCode=true}
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
    function d:Snapshot() return addon:CopySettingsData({key=self.key,value=self.value}) end
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
        to[#to+1]=self:Snapshot();local state=table.remove(from);self.key=state.key;self.value=state.value;return true
    end
    function d:Undo() return self:Travel(false) end
    function d:Redo() return self:Travel(true) end
    function d:MarkSaved() self.baseline=self:Snapshot();self.undo={};self.redo={};self.bytes=0 end
    return d
end
