local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:RegisterBuiltinSourceModule(path,getter)
    self.builtinSourceModules=self.builtinSourceModules or {};self.builtinSourceModules[path]=getter
    local module=self.BuiltinSourceCatalog and self.BuiltinSourceCatalog.modules[path];if not module then return end
    for alias,entry in pairs(module.bindings) do
        local args={};for _,name in ipairs(entry.parameters or {}) do args[#args+1]={name=name,type='any',description=''} end
        local source={name=alias,description=string.format(L['Packaged helper from %s.'],path),args=args,returns={{type='any',description=''}},code=entry.code or '',bindings=entry.bindings or {}}
        self:RegisterBuiltinFunction('builtin:'..path..':'..alias,source,function() return getter(alias) end,entry.kind~='function')
    end
end
function addon:GetBuiltinConditionSource(id)
    local record=self.BuiltinSourceCatalog and self.BuiltinSourceCatalog.conditions[id]
    local definition=(self.conditionDefinitions or self.definitions or {})[id]
    if not record or not definition then return nil,'builtin-source-unavailable' end
    local source={description=definition.description or id,icon=definition.icon,fields=self:CopySettingsData(definition.fields or {}),bindings={},parameters={}}
    if definition.requiredFields then source.requiredFields=self:CopySettingsData(definition.requiredFields) end
    for name in pairs(self.CustomConditionCallbacks) do
        local callback=record.callbacks[name];source[name]=callback and callback.code or name=='valid' and 'return true' or ''
        if callback then
            source.parameters[name]=self:CopySettingsData(callback.parameters)
            for alias,binding in pairs(callback.bindings) do
                if source.bindings[alias] and source.bindings[alias]~=binding then return nil,'ambiguous-builtin-binding' end
                source.bindings[alias]=binding
            end
        end
    end
    return source
end
