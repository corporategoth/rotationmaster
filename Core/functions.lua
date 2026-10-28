-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Custom function registry: validates the user's custom functions (db.global.custom_functions), compiles them into a
-- registry keyed by function id, resolves a binding id to a callable (custom or Built In), and compiles callback bodies
-- (custom conditions and functions) with their bindings. Install and remove are all-or-nothing: the new registry is
-- built and checked before the saved table, the registry or any consumer is touched. Owns the registry and its
-- version; the editors and transfer windows are in UI/. A function body is compiled and bound to `addon` and `L` when
-- the registry is built, and runs only when something calls it. Loaded from the Core group of RotationMaster.toc,
-- after Core/condition_catalog.lua and before Data/builtin_sources.lua. Every writer notifies
-- addon.InvalidateRotationDependencies so the lean engine's plan goes stale.
local addon_name, addon = ...
local invalidateDependencies = addon.InvalidateRotationDependencies

if type(invalidateDependencies) ~= 'function' then
    invalidateDependencies = nil
end

local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Identifier and namespace rules
-- ============================================================================

-- Lua keywords, which are never valid function or alias names.
local reserved = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

-- True for a Lua identifier of at most 128 bytes that is not a keyword.
local function identifier(name)
    return type(name) == 'string'
        and #name <= 128
        and name:match('^[A-Za-z_][A-Za-z_0-9]*$') ~= nil
        and not reserved[name]
end

-- True for a string of at most `limit` bytes; with `required` it must also contain a non-space character.
local function text(value, limit, required)
    return type(value) == 'string' and #value <= limit and (not required or value:find('%S') ~= nil)
end

-- True for a plain dense list (no metatable, no holes, no extra keys) of at most `limit` entries.
local function array(value, limit)
    if type(value) ~= 'table' or getmetatable(value) or #value > limit then
        return false
    end

    local count = 0

    for index in pairs(value) do
        count = count + 1

        if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > #value then
            return false
        end
    end

    return count == #value
end

-- True when `id` may name a custom function: a valid identifier that does not shadow the `addon` or `L` parameters
-- every function body receives.
function addon:IsCustomFunctionIdentifier(id)
    return identifier(id) and id ~= 'addon' and id ~= 'L'
end

-- Names a user namespace may not start with: the addon handles and the Lua standard library roots.
local namespaceRoots = {
    addon = true,
    L = true,
    _G = true,
    _ENV = true,
    math = true,
    string = true,
    table = true,
    coroutine = true,
    debug = true,
    io = true,
    os = true,
    package = true,
    bit = true,
    bit32 = true,
    utf8 = true,
}

-- Splits a dotted path into its identifier parts. Returns the parts, or nil when the path is longer than 512 bytes,
-- has an empty segment, a non-identifier segment or more than `maxSegments` (default 8) segments.
local function identifierPath(path, maxSegments)
    if type(path) ~= 'string' or #path > 512 or path == '' or path:sub(1, 1) == '.' or path:sub(-1) == '.' or path:find(
        '..',
        1,
        true
    ) then
        return nil
    end

    local parts = {}

    for part in path:gmatch('[^.]+') do
        if not identifier(part) then
            return nil
        end

        parts[#parts + 1] = part
    end

    if #parts > (maxSegments or 8) then
        return nil
    end

    return parts
end

-- True for the empty namespace or a dotted identifier path of at most 7 segments that does not start with a reserved
-- root.
function addon:IsFunctionNamespace(namespace)
    if namespace == '' then
        return true
    end

    -- Leave room for the separator and a maximum-length callable name inside
    -- the same bounded 512-byte binding path.
    if type(namespace) ~= 'string' or #namespace > 383 then
        return false
    end

    local parts = identifierPath(namespace, 7)
    return parts ~= nil and not namespaceRoots[parts[1]]
end

-- ============================================================================
-- Names and bindings
-- ============================================================================

-- Returns the namespace a function is exposed under: its own valid `source.namespace`; for a Built In id
-- ('builtin:<module>:<name>') the module path with dots; 'builtin' for other Built In ids; otherwise 'functions'.
function addon:FunctionNamespace(id, source)
    if
        type(source) == 'table'
        and type(source.namespace) == 'string'
        and source.namespace ~= ''
        and self:IsFunctionNamespace(source.namespace)
    then
        return source.namespace
    end

    local module = type(id) == 'string' and id:match('^builtin:(.-):[^:]+$')

    if module then
        return module:gsub('%.lua$', ''):gsub('[/\\]', '.')
    end
    if type(id) == 'string' and id:match('^builtin:') then
        return 'builtin'
    end

    return 'functions'
end

-- Returns 'namespace.name' for a function, as shown in the editors.
function addon:FunctionQualifiedName(id, source)
    return self:FunctionNamespace(id, source) .. '.' .. self:FunctionEditorName(id, source)
end

-- Registry IDs remain stable across name edits; a binding exposes this suggested
-- local name in a caller. Existing exports with descriptive names still load.
function addon:FunctionEditorName(id, source)
    local name = source and source.name

    if self:IsCustomFunctionIdentifier(name) then
        return name
    end

    name = type(name) == 'string' and name:gsub('[^A-Za-z_0-9]', '_'):gsub('^%d+', '') or ''

    if name == '' then
        name = tostring(id or 'helper'):gsub('[^A-Za-z_0-9]', '_'):gsub('^%d+', '')
    end

    name = name:sub(1, 128)

    if not self:IsCustomFunctionIdentifier(name) then
        name = 'helper_' .. name:sub(1, 121)
    end

    return name
end

-- Validates a binding table of alias to function id (at most 128 aliases, aliases are identifier paths). `arguments`
-- are the callback's parameters, which an alias may not shadow. Rejects an alias that is a prefix of another and two
-- different ids on one `functions.<alias>` path. Returns a copy, or nil and 'invalid-function-bindings'.
function addon:NormalizeFunctionBindings(bindings, arguments)
    if bindings == nil then
        return {}
    end
    if type(bindings) ~= 'table' or getmetatable(bindings) then
        return nil, 'invalid-function-bindings'
    end

    local result, count = {}, 0
    local names = { addon = true, L = true }

    for _, argument in ipairs(arguments or {}) do
        names[argument.name] = true
    end

    for alias, id in pairs(bindings) do
        count = count + 1
        local parts = identifierPath(alias)

        if
            count > 128
            or not parts
            or names[parts[1]]
            or #parts > 1 and namespaceRoots[parts[1]]
            or not text(id, 512, true)
        then
            return nil, 'invalid-function-bindings'
        end

        result[alias] = id
    end

    local occupied = {}

    for alias, id in pairs(result) do
        occupied[alias] = id
    end

    if not names.functions and not result.functions then
        for alias, id in pairs(result) do
            if not alias:find('.', 1, true) then
                local path = 'functions.' .. alias

                if occupied[path] and occupied[path] ~= id then
                    return nil, 'invalid-function-bindings'
                end

                occupied[path] = id
            end
        end
    end

    for alias in pairs(occupied) do
        local prefix = ''

        for part in alias:gmatch('[^.]+') do
            if prefix ~= '' and occupied[prefix] then
                return nil, 'invalid-function-bindings'
            end

            prefix = prefix == '' and part or prefix .. '.' .. part
        end
    end

    return result
end

-- Builds the Lua text prepended to a callback body: one `local alias=addon:RequireFunctionBinding("id")` per binding,
-- the namespace tables dotted aliases need, and a `functions` table with the plain aliases unless the callback
-- already uses that name. `parameters` is the comma-separated parameter list. Returns the text, or nil and a reason.
function addon:FunctionBindingPrelude(bindings, parameters)
    local arguments = {}

    for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do
        arguments[#arguments + 1] = { name = name }
    end

    local normalized, why = self:NormalizeFunctionBindings(bindings, arguments)

    if not normalized then
        return nil, why
    end

    bindings = normalized
    local keys = {}

    for alias in pairs(bindings) do
        keys[#keys + 1] = alias
    end

    table.sort(keys)
    local lines, created = {}, {}

    local function namespace(path)
        local prefix = ''

        for part in path:gmatch('[^.]+') do
            local parent = prefix
            prefix = prefix == '' and part or prefix .. '.' .. part

            if not created[prefix] then
                lines[#lines + 1] = (parent == '' and 'local ' or '') .. prefix .. '={}'
                created[prefix] = true
            end
        end
    end

    for _, alias in ipairs(keys) do
        local parent = alias:match('^(.*)%.')

        if parent then
            namespace(parent)
        end
    end

    for _, alias in ipairs(keys) do
        lines[#lines + 1] = (alias:find('.', 1, true) and '' or 'local ')
            .. alias
            .. '=addon:RequireFunctionBinding('
            .. string.format('%q', bindings[alias])
            .. ')'
    end

    local shadowed = bindings and bindings.functions

    for name in (parameters or ''):gmatch('[A-Za-z_][A-Za-z_0-9]*') do
        if name == 'functions' then
            shadowed = true
        end
    end

    if not shadowed then
        namespace('functions')

        for _, alias in ipairs(keys) do
            if not alias:find('.', 1, true) then
                lines[#lines + 1] = 'functions.' .. alias .. '=' .. alias
            end
        end
    end

    return table.concat(lines, '\n')
end

-- ============================================================================
-- Compilation and validation
-- ============================================================================

-- Strips leading blank lines and re-indents with the Lua tokenizer when it is loaded. Returns the text for the editor.
function addon:NormalizeLuaSourceForEditor(code)
    code = (code or ''):gsub('^[ \t\r]*\n', '')

    while code:match('^[ \t\r]*\n') do
        code = code:gsub('^[ \t\r]*\n', '')
    end

    local syntax = self.LuaSyntax

    -- Use the existing Lua tokenizer/formatter so multiline literals retain
    -- their contents; stripping whitespace from every line would change them.
    if syntax and syntax.indentCode then
        code = syntax.decode(syntax.indentCode(syntax.encode(code), 4))
    end

    return code
end

-- Compiles a callback body wrapped in `function(addon,L) return function(<parameters>) <prelude> <code> end end`.
-- Returns the loadstring chunk (nothing is executed), or nil and the compile error or a reason code.
function addon:CompileLuaCallbackBody(code, parameters, bindings, chunkName)
    if type(loadstring) ~= 'function' then
        return nil, 'compiler-unavailable'
    end

    -- A valid generated wrapper alone is insufficient: an unmatched `end` in
    -- the supplied body can escape into its return list and run at bind time.
    -- Check the body as an independent chunk first. Neither chunk is executed.
    local body, why = loadstring(code, chunkName)

    if not body then
        return nil, why
    end

    local prelude, problem = self:FunctionBindingPrelude(bindings, parameters)

    if not prelude then
        return nil, problem
    end

    return loadstring(
        'return function(addon,L) return function(' .. parameters .. ')\n' .. prelude .. '\n' .. code .. '\nend end',
        chunkName
    )
end

-- Validates one saved custom function: identifier, text and size limits, only known fields, at most 32 arguments and 16
-- returns, and its bindings; then compiles it unless it is disabled. Returns { bindings, chunk } (no chunk when
-- disabled), or nil and a reason code or compile error.
function addon:ValidateCustomFunctionSource(id, source)
    if not self:IsCustomFunctionIdentifier(id) then
        return nil, 'invalid-function-identifier'
    end
    if
        type(source) ~= 'table'
        or getmetatable(source)
        or not text(source.description, 4096, true)
        or not text(source.code, 65536)
        or source.name ~= nil and not text(source.name, 256)
        or source.disabled ~= nil and type(source.disabled) ~= 'boolean'
    then
        return nil, 'invalid-function-source'
    end
    if source.namespace ~= nil and not self:IsFunctionNamespace(source.namespace) then
        return nil, 'invalid-function-namespace'
    end

    local allowed = {
        name = true,
        namespace = true,
        description = true,
        args = true,
        returns = true,
        code = true,
        bindings = true,
        disabled = true,
    }

    for field in pairs(source) do
        if not allowed[field] then
            return nil, 'unknown-function-field'
        end
    end

    if not array(source.args, 32) or not array(source.returns, 16) then
        return nil, 'invalid-function-arguments'
    end

    local names = { addon = true, L = true }

    for index, argument in ipairs(source.args) do
        if
            type(argument) ~= 'table'
            or getmetatable(argument)
            or not identifier(argument.name) and not (argument.name == '...' and index == #source.args)
            or names[argument.name]
            or not text(argument.type, 128, true)
            or not text(argument.description or '', 2048)
        then
            return nil, 'invalid-function-arguments'
        end

        names[argument.name] = true

        for field in pairs(argument) do
            if field ~= 'name' and field ~= 'type' and field ~= 'description' then
                return nil, 'invalid-function-arguments'
            end
        end
    end

    for _, result in ipairs(source.returns) do
        if
            type(result) ~= 'table'
            or getmetatable(result)
            or not text(result.type, 128, true)
            or not text(result.description or '', 2048)
        then
            return nil, 'invalid-function-returns'
        end

        for field in pairs(result) do
            if field ~= 'type' and field ~= 'description' then
                return nil, 'invalid-function-returns'
            end
        end
    end

    local bindings, why = self:NormalizeFunctionBindings(source.bindings, source.args)

    if not bindings then
        return nil, why
    end
    if source.disabled then
        return { bindings = bindings }
    end

    local params = {}

    for _, argument in ipairs(source.args) do
        params[#params + 1] = argument.name
    end

    local chunk, errorText = self:CompileLuaCallbackBody(
        source.code,
        table.concat(params, ','),
        bindings,
        '@RotationMaster:function:' .. id
    )

    if not chunk then
        return nil, errorText
    end

    return { bindings = bindings, chunk = chunk }
end

-- ============================================================================
-- Registry
-- ============================================================================

-- Registers a Built In function under an id starting 'builtin:'. `getter` returns the callable (or, with
-- `valueBinding`, any value). Returns false for a bad argument or a duplicate id.
function addon:RegisterBuiltinFunction(id, source, getter, valueBinding)
    if
        type(id) ~= 'string'
        or not id:match('^builtin:')
        or #id > 512
        or type(source) ~= 'table'
        or type(getter) ~= 'function'
    then
        return false
    end

    self.builtinFunctions = self.builtinFunctions or {}

    if self.builtinFunctions[id] then
        return false
    end

    self.builtinFunctions[id] = { source = source, get = getter, valueBinding = valueBinding == true }
    return true
end

-- Builds a registry from a table of function sources without touching the live one. Each record carries the source,
-- a problem code if it failed, its bindings and the compiled function. A function whose source is unchanged keeps its
-- previously bound function so editing one function does not rebind every other. Returns the registry, or nil and
-- 'invalid-function-registry' / 'function-limit' (more than 4096 functions).
function addon:BuildFunctionRegistry(sources)
    if type(sources) ~= 'table' or getmetatable(sources) then
        return nil, 'invalid-function-registry'
    end

    local result = {}
    local count = 0

    for id, source in pairs(sources or {}) do
        count = count + 1

        if count > 4096 then
            return nil, 'function-limit'
        end

        local checked, why = self:ValidateCustomFunctionSource(id, source)
        local previous = self.functionRegistry and self.functionRegistry[id]
        local record = { source = source, problem = why, bindings = checked and checked.bindings or {} }
        result[id] = record

        if checked and checked.chunk then
            if previous and previous.fn and self:SettingsDataEqual(previous.source, source) then
                record.fn = previous.fn
            else
                local ok, binder = pcall(checked.chunk)

                if ok and type(binder) == 'function' then
                    local bound, fn = pcall(binder, self, L)

                    if bound and type(fn) == 'function' then
                        record.fn = fn
                    else
                        record.problem = 'function-compile-failed'
                    end
                else
                    record.problem = 'function-compile-failed'
                end
            end
        end
    end

    return result
end

-- Builds the live registry from the saved functions and notifies dependents. Called at startup and lazily by
-- FunctionAvailable when no registry exists yet.
function addon:InitializeFunctionRegistry()
    self.functionRegistry = self:BuildFunctionRegistry(self.db.global.custom_functions or {}) or {}
    self.functionRegistryVersion = (self.functionRegistryVersion or 0) + 1

    if invalidateDependencies then
        invalidateDependencies(addon, 'function', nil)
    end
end

-- Returns true when function `id` and every function it binds to can run, otherwise nil and a reason
-- ('missing-function', 'disabled-function', 'function-cycle', 'function-depth' beyond 64 levels, or the record's own
-- problem). A Built In id is available. `registry` defaults to the live one; `active`, `depth` and `memo` are the
-- recursion state.
function addon:FunctionAvailable(id, registry, active, depth, memo)
    registry = registry or self.functionRegistry

    if not registry then
        self:InitializeFunctionRegistry()
        registry = self.functionRegistry
    end

    if self.builtinFunctions and self.builtinFunctions[id] then
        return true
    end

    memo = memo or {}

    if memo[id] then
        return memo[id][1], memo[id][2]
    end

    depth = (depth or 0) + 1

    if depth > 64 then
        return nil, 'function-depth'
    end

    active = active or {}

    if active[id] then
        return nil, 'function-cycle'
    end

    local record = registry[id]

    if not record then
        return nil, 'missing-function'
    end
    if record.problem then
        return nil, record.problem
    end
    if record.source.disabled then
        return nil, 'disabled-function'
    end
    if not record.fn then
        return nil, 'function-compile-failed'
    end

    active[id] = true

    for _, dependency in pairs(record.bindings) do
        local ok, why = self:FunctionAvailable(dependency, registry, active, depth, memo)

        if not ok then
            active[id] = nil
            memo[id] = { false, why }
            return nil, why
        end
    end

    active[id] = nil
    memo[id] = { true }
    return true
end

-- Returns true when every function id in `bindings` is available, otherwise nil and the first reason.
function addon:AreFunctionBindingsAvailable(bindings, registry)
    for _, id in pairs(bindings or {}) do
        local ok, why = self:FunctionAvailable(id, registry)

        if not ok then
            return nil, why
        end
    end

    return true
end

-- Returns the callable for function `id` (a custom function, or the Built In getter's value), or nil and a reason.
function addon:ResolveFunctionBinding(id)
    local ok, why = self:FunctionAvailable(id)

    if not ok then
        return nil, why
    end

    local builtin = self.builtinFunctions and self.builtinFunctions[id]

    if builtin then
        local read, value = pcall(builtin.get)

        if not read then
            return nil, 'builtin-binding-unavailable'
        end
        if not builtin.valueBinding and type(value) ~= 'function' then
            return nil, 'builtin-function-unavailable'
        end

        return value
    end

    return self.functionRegistry[id].fn
end

-- Like ResolveFunctionBinding but raises an error naming the function. The generated prelude of a callback calls it at
-- the start of every call, so a callback whose binding disappeared fails loudly instead of running without it.
function addon:RequireFunctionBinding(id)
    local value, why = self:ResolveFunctionBinding(id)

    if why then
        error('Rotation Master function unavailable: ' .. tostring(id) .. ' (' .. why .. ')', 2)
    end

    return value
end

-- ============================================================================
-- Consumer transitions and writers
-- ============================================================================

-- Release resources while the old helper graph is still usable. A later
-- refresh resumes suspended consumers only after the new graph is installed.
-- Suspends every enabled condition whose bindings will not be available in `registry`, running its on_unregister. If
-- one cleanup fails, the ones already suspended are resumed and the call returns nil and
-- 'function-consumer-cleanup-failed'.
function addon:PrepareFunctionConsumerTransition(registry)
    local cleaned = {}

    for id, definition in pairs(self.conditionDefinitions or {}) do
        if
            definition.functionBindings
            and not definition.disabled
            and not definition.functionUnavailable
            and not definition.functionSuspended
            and not self:AreFunctionBindingsAvailable(definition.functionBindings, registry)
        then
            local ok = true

            if definition.on_unregister then
                ok = pcall(definition.on_unregister, id)
            end

            if not ok then
                for _, entry in ipairs(cleaned) do
                    entry[2].functionSuspended = nil

                    if invalidateDependencies then
                        invalidateDependencies(addon, 'condition', entry[1])
                    end
                    if entry[2].on_register then
                        pcall(entry[2].on_register, entry[1])
                    end
                end

                return nil, 'function-consumer-cleanup-failed'
            end

            definition.functionSuspended = true

            if invalidateDependencies then
                invalidateDependencies(addon, 'condition', id)
            end

            cleaned[#cleaned + 1] = { id, definition }
        end
    end

    return true
end

-- Staged imports defer runtime selection refresh until commit and retain every
-- resume attempt so rollback can release partially initialized hook resources.
-- Re-evaluates every condition that binds functions: records why it is unavailable, resumes the suspended ones whose
-- bindings are back (running on_register) and bumps the condition registry version. Returns success, a reason on
-- failure, and the list of resume attempts.
function addon:RefreshFunctionConsumers(deferRefresh)
    local successful, attempted = true, {}

    for id, definition in pairs(self.conditionDefinitions or {}) do
        if definition.functionBindings then
            local ok, why = self:AreFunctionBindingsAvailable(definition.functionBindings)
            local previousUnavailable = definition.functionUnavailable
            definition.functionUnavailable = not ok and why or nil

            if previousUnavailable ~= definition.functionUnavailable then
                if invalidateDependencies then
                    invalidateDependencies(addon, 'condition', id)
                end
            end

            if ok and definition.functionSuspended and not definition.disabled then
                attempted[#attempted + 1] = { id = id, definition = definition }

                if invalidateDependencies then
                    invalidateDependencies(addon, 'condition', id)
                end

                local registered = true

                if definition.on_register then
                    registered = pcall(definition.on_register, id)
                end

                if registered then
                    definition.functionSuspended = nil
                else
                    successful = false
                    definition.functionUnavailable = 'function-consumer-registration-failed'
                end

                if invalidateDependencies then
                    invalidateDependencies(addon, 'condition', id)
                end
            end

            if self.ResetConditionQuarantine then
                self:ResetConditionQuarantine(definition)
            end
        end
    end

    self.conditionRegistryVersion = (self.conditionRegistryVersion or 0) + 1

    if invalidateDependencies then
        invalidateDependencies(addon, 'condition', nil)
    end
    if not deferRefresh and self.RefreshConditionConsumers then
        self:RefreshConditionConsumers()
    end

    return successful, not successful and 'function-consumer-registration-failed' or nil, attempted
end

-- Saves a custom function if the stored copy still equals `expected` (compare-and-set against a stale editor). The new
-- registry is built, checked and the consumers prepared before anything is written; on any failure nothing changes and
-- the call returns nil and a reason. Returns true.
function addon:InstallCustomFunction(id, source, expected)
    if not self:IsCustomFunctionIdentifier(id) then
        return nil, 'invalid-function-identifier'
    end

    local current = (self.db.global.custom_functions or {})[id]

    if not self:SettingsDataEqual(current, expected) then
        return nil, 'function-changed'
    end

    local checked, why = self:ValidateCustomFunctionSource(id, source)

    if not checked then
        return nil, why
    end

    local sources = self:CopySettingsData(self.db.global.custom_functions or {})
    sources[id] = self:CopySettingsData(source)
    local registry, problem = self:BuildFunctionRegistry(sources)

    if not registry then
        return nil, problem
    end

    if not source.disabled then
        local available, reason = self:FunctionAvailable(id, registry)

        if not available then
            return nil, reason
        end
    end

    local prepared, prepareError = self:PrepareFunctionConsumerTransition(registry)

    if not prepared then
        return nil, prepareError
    end

    self.db.global.custom_functions = sources
    self.functionRegistry = registry
    self.functionRegistryVersion = (self.functionRegistryVersion or 0) + 1

    if invalidateDependencies then
        invalidateDependencies(addon, 'function', id)
    end

    self:RefreshFunctionConsumers()
    return true
end

-- Deletes a custom function if the stored copy still equals `expected`, with the same all-or-nothing order as
-- InstallCustomFunction. Functions that bound to it become unavailable and their consumers are suspended.
function addon:RemoveCustomFunction(id, expected)
    local current = (self.db.global.custom_functions or {})[id]

    if not current or not self:SettingsDataEqual(current, expected) then
        return nil, 'function-changed'
    end

    local sources = self:CopySettingsData(self.db.global.custom_functions)
    sources[id] = nil
    local registry, why = self:BuildFunctionRegistry(sources)

    if not registry then
        return nil, why
    end

    local prepared, prepareError = self:PrepareFunctionConsumerTransition(registry)

    if not prepared then
        return nil, prepareError
    end

    self.db.global.custom_functions = sources
    self.functionRegistry = registry
    self.functionRegistryVersion = (self.functionRegistryVersion or 0) + 1

    if invalidateDependencies then
        invalidateDependencies(addon, 'function', id)
    end

    self:RefreshFunctionConsumers()
    return true
end
