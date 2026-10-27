local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

function addon:RegisterBuiltinSourceModule(path, getter)
    self.builtinSourceModules = self.builtinSourceModules or {}
    self.builtinSourceModules[path] = getter
    local module = self.BuiltinSourceCatalog and self.BuiltinSourceCatalog.modules[path]
    if not module then return end

    for alias, entry in pairs(module.bindings) do
        local args = {}

        for index, name in ipairs(entry.parameters or {}) do
            local doc = entry.args and entry.args[index]

            args[#args + 1] = {
                name = name,
                type = doc and doc.type or 'any',
                description = doc and L[doc.description] or '',
            }
        end

        local returns = {}

        for _, doc in ipairs(entry.returns or { { type = 'any', description = '' } }) do
            returns[#returns + 1] = {
                type = doc.type,
                description = doc.description ~= '' and L[doc.description] or '',
            }
        end

        local source = {
            name = entry.callName and entry.callName:match('([%w_]+)$') or alias,
            namespace = entry.namespace or path:gsub('%.lua$', ''):gsub('[/\\]', '.'),
            description = entry.description and L[entry.description] or string.format(
                L['Packaged helper from %s.'],
                path
            ),
            args = args,
            returns = returns,
            code = entry.code or '',
            bindings = entry.bindings or {},
        }

        local id = entry.bindingID or 'builtin:' .. path .. ':' .. alias

        if self:RegisterBuiltinFunction(id, source, function() return getter(alias) end, entry.kind ~= 'function') then
            local record = self.builtinFunctions[id]
            record.callName = entry.callName
            record.public = entry.callName ~= nil
            record.compatibilityNamespaces = entry.compatibilityNamespaces
        end
    end
end

-- utils/native field factories load before this module. Their generated suffixes
-- queue live getters; registering them here preserves the normal TOC order.
for path, getter in pairs(addon.builtinSourceModules or {}) do
    addon:RegisterBuiltinSourceModule(path, getter)
end

function addon:GetBuiltinConditionSource(id)
    local record = self.BuiltinSourceCatalog and self.BuiltinSourceCatalog.conditions[id]
    local definition = (self.conditionDefinitions or self.definitions or {})[id]
    if not record or not definition then return nil, 'builtin-source-unavailable' end

    if record.variants then
        record = record.variants[definition.builtinSourceVariant]
        if not record then return nil, 'builtin-source-variant-unavailable' end
    elseif definition.builtinSourceVariant ~= nil then
        return nil, 'builtin-source-variant-unavailable'
    end

    local source = {
        description = definition.description or id,
        icon = definition.icon,
        fields = self:CopySettingsData(definition.fields or {}),
        bindings = {},
        parameters = {},
    }

    if definition.requiredFields then source.requiredFields = self:CopySettingsData(definition.requiredFields) end

    for name in pairs(self.CustomConditionCallbacks) do
        local callback = record.callbacks[name]
        source[name] = callback and callback.code or name == 'valid' and 'return true' or ''

        if callback then
            source.parameters[name] = self:CopySettingsData(callback.parameters)

            for alias, binding in pairs(callback.bindings) do
                if source.bindings[alias] and source.bindings[alias] ~= binding then
                    return nil, 'ambiguous-builtin-binding'
                end

                source.bindings[alias] = binding
            end
        end
    end

    return source
end

-- Display only: never canonicalize Lua string contents or change a clone's
-- executable source merely to remove the containing Lua table's indentation.
function addon:FormatLuaSourceDisplay(source)
    local lines = {}

    for line in ((source or '') .. '\n'):gmatch('(.-)\n') do
        lines[#lines + 1] = line
    end

    while #lines > 0 and not lines[1]:find('%S') do
        table.remove(lines, 1)
    end

    while #lines > 0 and not lines[#lines]:find('%S') do
        table.remove(lines)
    end

    local prefix

    for _, line in ipairs(lines) do
        if line:find('%S') then
            local whitespace = line:match('^[ \t]*')

            if prefix == nil then
                prefix = whitespace
            else
                local n = 0

                while n < #prefix and n < #whitespace and prefix:sub(n + 1, n + 1) == whitespace:sub(n + 1, n + 1) do
                    n = n + 1
                end

                prefix = prefix:sub(1, n)
            end
        end
    end

    if prefix and #prefix > 0 then
        for i, line in ipairs(lines) do
            if line:sub(1, #prefix) == prefix then lines[i] = line:sub(#prefix + 1) end
        end
    end

    return table.concat(lines, '\n')
end
