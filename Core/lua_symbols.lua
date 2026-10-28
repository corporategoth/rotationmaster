-- Symbol documentation and completion for the Lua editors: builds the table of names (the addon helpers, the bound and
-- bindable custom and Built In functions, the callback's parameters and `value.*` fields) that the optional
-- LuaWorkbench engine shows for a custom function or condition, and patches that engine's API help, name list,
-- autocomplete and navigation to include them. Owns only the overlay on the engine (marked `rm*` fields so it is
-- applied once and stripped before reapplying); it never edits saved functions and must not break the engine when it is
-- absent or limited. Loaded from RotationMaster.toc after Core/custom_condition_services.lua; callers are
-- Integrations/lua_workbench.lua and UI/lua_completion.lua.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- ============================================================================
-- Building the symbol table
-- ============================================================================

-- Builds the table of names the Lua editor documents and completes for an editing context.
-- @param context table|nil  The editing context: `kind` ('function' or a condition), `callback`, `id`, and `source`
--   with
--   its args, fields, bindings and parameters (and optionally a bindFunction callback used on accept).
-- @return table  `{ [name] = symbol }`. A symbol carries LuaWorkbench-style `info` documentation, its `origin`
--   ('builtin', 'custom' or 'context') and, for a function not yet bound, `requiresBinding`.
--
-- Aliases kept for saved callbacks are `documentationOnly`: documented and navigable but never offered in completion.
function addon:LuaContextSymbols(context)
    context = context or {}
    local source = context.source or {}
    local symbols = {}

    -- Registers one symbol with its documentation (description, type line, arguments and returns) under a name.
    -- @param name string  The symbol name, for example 'addon:Print' or 'value.unit'.
    -- @param kind string  'functionName', 'identifier' or 'parameter'.
    -- @param description string|nil  The documentation text.
    -- @param typeName string|nil  The type shown for a value (not used for a function).
    -- @param args table[]|nil  The function's arguments, each { name, type, description }.
    -- @param returns table[]|nil  The function's results, each { type, description }.
    -- @param id string|nil  The function id behind the symbol; it sets the symbol's origin.
    local function add(name, kind, description, typeName, args, returns, id)
        local info = {
            Name = name,
            Type = kind == 'functionName' and 'Function' or 'Parameter',
            Documentation = { description or '' },
            Arguments = {},
            Returns = {},
        }

        if kind ~= 'functionName' and typeName then
            table.insert(info.Documentation, 1, string.format(L['Type: %s'], typeName))
        end

        for _, arg in ipairs(args or {}) do
            info.Arguments[#info.Arguments + 1] = {
                Name = arg.name,
                Type = arg.type,
                Documentation = { arg.description or '' },
            }
        end

        for i, result in ipairs(returns or {}) do
            info.Returns[#info.Returns + 1] = {
                Name = 'result' .. i,
                Type = result.type,
                Documentation = { result.description or '' },
            }
        end

        symbols[name] = {
            name = name,
            kind = kind,
            description = description or '',
            type = typeName,
            info = info,
            id = id,
            origin = id and (id:match('^builtin:') and 'builtin' or 'custom') or 'context',
        }
    end

    add(
        'addon',
        'identifier',
        L['Rotation Master addon instance. Public helper functions are documented in Functions.'],
        'RMAddon'
    )

    add('L', 'identifier', L['Localized Rotation Master text, indexed by its English key.'], 'table')

    add(
        'addon.units',
        'identifier',
        L['Supported unit-token to localized unit-name lookup. Use value.unit as a key; for example addon.units[value.unit]. Available tokens vary by client.'],
        'table<string, string>'
    )

    add(
        'addon.unitsPossessive',
        'identifier',
        L['Supported unit-token to localized possessive unit-name lookup, such as your target.'],
        'table<string, string>'
    )

    add(
        'addon.Platform',
        'identifier',
        L['Rotation Master client compatibility adapter. Its methods return ordinary readable results or nil with a reason when an observation is unavailable. Use a colon call, or pass addon.Platform explicitly as self with a dot reference.'],
        'RMPlatform'
    )

    add(
        'addon.SpellCatalog',
        'identifier',
        L['Rotation Master spell catalog for resolving client-specific spell IDs, ranks, names, icons and links.'],
        'RMSpellCatalog'
    )

    for id, entry in pairs(self.builtinFunctions or {}) do
        if entry.public and entry.callName and entry.source then
            local args = {}

            for index, arg in ipairs(entry.source.args or {}) do
                if not (index == 1 and arg.name == 'self' and entry.callName:find(':', 1, true)) then
                    args[#args + 1] = arg
                end
            end

            add(entry.callName, 'functionName', entry.source.description, 'function', args, entry.source.returns, id)

            if entry.callName:find(':', 1, true) then
                add(
                    entry.callName:gsub(':', '.'),
                    'functionName',
                    entry.source.description,
                    'function',
                    entry.source.args,
                    entry.source.returns,
                    id
                )
            end

            -- Saved callbacks may still invoke a direct addon alias after the
            -- implementation moves. Keep its docs/navigation while completion
            -- offers the canonical namespace rather than another API entry.
            local name = entry.source.name
            local fn = self:ResolveFunctionBinding(id)

            if
                type(name) == 'string'
                and name:match('^[A-Za-z_][A-Za-z_0-9]*$')
                and type(fn) == 'function'
                and rawequal(self[name], fn)
            then
                local receiver = entry.source.args and entry.source.args[1] and entry.source.args[1].name == 'self'
                local alias = 'addon' .. (receiver and ':' or '.') .. name

                if alias ~= entry.callName then
                    local aliasArgs = {}

                    for index, arg in ipairs(entry.source.args or {}) do
                        if not (receiver and index == 1) then
                            aliasArgs[#aliasArgs + 1] = arg
                        end
                    end

                    add(
                        alias,
                        'functionName',
                        entry.source.description,
                        'function',
                        aliasArgs,
                        entry.source.returns,
                        id
                    )

                    symbols[alias].documentationOnly = true
                end
            end
        end
    end

    local arguments = {}

    if context.kind == 'function' then
        arguments = source.args or {}
    else
        local docs = self.CustomConditionCallbackDocs
            and self.CustomConditionCallbackDocs[context.callback or 'evaluate']

        if docs then
            for _, arg in ipairs(docs.args) do
                arguments[#arguments + 1] = { name = arg[1], type = arg[2], description = arg[3] }
            end
        end

        for alias, canonical in pairs(self:CustomConditionParameterAliases(source, context.callback or 'evaluate')) do
            for _, arg in ipairs(docs and docs.args or {}) do
                if arg[1] == canonical then
                    add(alias, 'parameter', arg[3], arg[2])
                end
            end
        end
    end

    for _, arg in ipairs(arguments) do
        if arg.name ~= '...' then
            add(arg.name, 'parameter', arg.description, arg.type)
        end
    end

    if symbols.value then
        for name, typeName in pairs(source.fields or {}) do
            if type(name) == 'string' then
                add('value.' .. name, 'identifier', name, type(typeName) == 'string' and typeName or 'table')
            end
        end
    end

    local namespace = true
    local bindingArguments = {}

    for _, arg in ipairs(arguments) do
        bindingArguments[#bindingArguments + 1] = arg

        if arg.name == 'functions' then
            namespace = false
        end
    end

    for _, parameters in pairs(source.parameters or {}) do
        for _, name in ipairs(parameters) do
            bindingArguments[#bindingArguments + 1] = { name = name }

            if name == 'functions' then
                namespace = false
            end
        end
    end

    if source.bindings and source.bindings.functions then
        namespace = false
    end

    if namespace then
        add(
            'functions',
            'identifier',
            L['Utility functions explicitly bound to this condition or function. Choose a completion to bind an available custom function before inserting its reference.'],
            'table<string, function>'
        )
    end

    -- Registers a placeholder for each parent namespace of a dotted binding path ('a.b.c' adds 'a' and 'a.b').
    -- @param path string  The dotted binding path.
    local function addNamespace(path)
        local parent = path:match('^(.*)%.')
        local prefix = ''

        for part in (parent or ''):gmatch('[^.]+') do
            prefix = prefix == '' and part or prefix .. '.' .. part

            if not symbols[prefix] then
                add(
                    prefix,
                    'identifier',
                    L['Private utility-function namespace. It contains only explicit bindings for this callback.'],
                    'table<string, function | table>'
                )
            end
        end
    end

    local bound = {}

    for alias, id in pairs(source.bindings or {}) do
        local builtin = self.builtinFunctions and self.builtinFunctions[id]
        local custom = (self.db.global.custom_functions or {})[id]
        local entry = custom or builtin and builtin.source

        if entry then
            add(
                alias,
                builtin and builtin.valueBinding and 'identifier' or 'functionName',
                entry.description,
                builtin and builtin.valueBinding and 'any' or 'function',
                entry.args,
                entry.returns,
                id
            )

            bound[alias] = true
            addNamespace(alias)

            if namespace and not alias:find('.', 1, true) and not (builtin and builtin.valueBinding) then
                add('functions.' .. alias, 'functionName', entry.description, 'function', entry.args, entry.returns, id)
                bound['functions.' .. alias] = true
            end
        end
    end

    local candidates = {}

    -- Considers one function as a completion that would need binding.
    -- @param id string  The function id.
    -- @param entry table  The function record.
    --
    -- Skipped when disabled, in an invalid namespace, the function being edited, or when binding it would clash or fail
    -- validation. A name offered by two functions is dropped as ambiguous.
    local function candidate(id, entry)
        if
            type(entry) ~= 'table'
            or entry.disabled
            or entry.namespace ~= nil and not self:IsFunctionNamespace(entry.namespace)
            or context.kind == 'function' and context.id == id
        then
            return
        end

        local name = self:FunctionQualifiedName(id, entry)
        local bindings = {}

        for alias, target in pairs(source.bindings or {}) do
            bindings[alias] = target
        end

        if bindings[name] and bindings[name] ~= id then
            return
        end

        bindings[name] = id

        if not self:NormalizeFunctionBindings(bindings, bindingArguments) then
            return
        end

        if candidates[name] then
            candidates[name] = false
        elseif candidates[name] ~= false then
            candidates[name] = { id = id, entry = entry }
        end
    end

    for id, entry in pairs(self.db.global.custom_functions or {}) do
        candidate(id, entry)
    end

    for id, entry in pairs(self.builtinFunctions or {}) do
        if not entry.valueBinding and entry.source then
            candidate(id, entry.source)
        end
    end

    for name, item in pairs(candidates) do
        if item and not bound[name] then
            addNamespace(name)
            add(name, 'functionName', item.entry.description, 'function', item.entry.args, item.entry.returns, item.id)
            symbols[name].requiresBinding = true
            symbols[name].bindingName = name
        end
    end

    return symbols
end

-- ============================================================================
-- Overlaying the Lua editor engine
-- ============================================================================

-- Overlays an editing context's symbols onto a LuaWorkbench engine.
-- @param engine table  The LuaWorkbench engine to patch.
-- @param context table|nil  The editing context passed to LuaContextSymbols.
-- @param limited boolean|nil  True for the small embedded editor, which gets no deferred loading.
--
-- Patches API help text, the symbol index and catalog, the checks for documented globals, autocomplete names and the
-- accept step that binds a function before inserting its name. Patches are installed once per engine and re-read
-- `engine.rmSymbols` afterwards, so calling it again for a new context only refreshes the symbols.
function addon:ApplyLuaContextSymbols(engine, context, limited)
    local api = engine.APIHelp

    -- Copies the first level of a table, so an overlay can be stripped without touching the engine's own tables.
    -- @param value table|nil  The table to copy; nil gives an empty table.
    -- @return table  The copy.
    local function shallow(value)
        local result = {}

        for key, entry in pairs(value or {}) do
            result[key] = entry
        end

        return result
    end

    if not api.rmSyncSymbols then
        local describe = api.FullDescription

        -- Wraps the engine's hover text.
        -- @param name string  The symbol name.
        -- @param rich boolean|nil  True for colored (rich) text.
        -- @param links boolean|nil  Passed through to the engine's own implementation.
        -- @return string|nil  The hover text; nil when the engine has none.
        -- @return number|nil  The substitution count, returned only alongside the retitled text of a Rotation Master
        --   symbol.
        --
        -- A Rotation Master symbol gets its own heading (custom function, built-in function or value), and a native
        -- global the
        -- client has no signature documentation for says so rather than inventing arguments.
        function api:FullDescription(name, rich, links)
            local symbol = engine.rmSymbols and engine.rmSymbols[name]
            local text = describe(self, name, rich, links)

            if symbol and text then
                local heading = symbol.kind == 'functionName'
                    and (symbol.origin == 'custom' and L['Rotation Master custom function']
                        or L['Rotation Master built-in function'])
                    or L['Rotation Master value']

                if rich then
                    heading = '|cffe6c07b' .. heading:gsub('|', '||') .. '|r'
                end

                return text:gsub('^[^\n]*', function() return heading end, 1)
            end

            if not text and not self.rmLimited and self.rmUndocumented and self.rmUndocumented[name] then
                return L['Global function (documentation unavailable on this client)']
                    .. '\n'
                    .. name
                    .. '\n\n'
                    .. L['This client does not provide signature documentation for this function. No arguments or return types have been inferred.']
            end

            return text
        end

        -- Rebuilds the engine's index and catalog from the current symbols.
        --
        -- Strips only this overlay's previous entries, keeps any documentation the engine loaded since (combat can
        -- defer its
        -- loading), then adds the current symbols and bumps the revision.
        function api:rmSyncSymbols()
            -- Documentation can arrive after the editor opens (combat defers
            -- upstream loading). Strip only our previous overlay, retain newly
            -- loaded metadata, then apply the current callback's symbols.
            local index, catalog = shallow(self.index), shallow(self.catalog)

            for name, symbol in pairs(self.rmOverlaySymbols or {}) do
                if index[name] == symbol.info then
                    index[name] = self.rmBaseIndex and self.rmBaseIndex[name]
                end
                if catalog[name] and catalog[name].info == symbol.info then
                    catalog[name] = self.rmBaseCatalog and self.rmBaseCatalog[name]
                end
            end

            self.rmBaseIndex = shallow(index)
            self.rmBaseCatalog = shallow(catalog)

            for name, symbol in pairs(engine.rmSymbols or {}) do
                index[name] = symbol.info

                if not symbol.documentationOnly then
                    catalog[name] = {
                        name = name,
                        kind = symbol.kind == 'functionName' and 'apiFunctions' or 'apiOther',
                        info = symbol.info,
                    }
                end
            end

            self.index, self.catalog = index, catalog
            self.rmOverlaySymbols = engine.rmSymbols
            self.source, self.paths, self.text = nil, nil, {}
            self.revision = self.revision + 1

            if engine.KnowledgeBase then
                engine.KnowledgeBase.entries = nil
            end
        end

        local load = api.Load

        -- Runs the engine's loader and resyncs the overlay when the loader changed the documentation revision.
        -- @param ... any  Passed through to the engine's loader.
        function api:Load(...)
            local revision = self.revision
            load(self, ...)

            if self.revision ~= revision then
                self:rmSyncSymbols()
            end
        end

        local paths = api.Paths

        -- Wraps the engine's semantic path analysis.
        -- @param source string  The editor text.
        -- @param force boolean|nil  Passed through to the engine; true analyses even when the engine is not enabled.
        -- @return table  The engine's path map, with tokens that resolve to a Rotation Master symbol, or to an
        --   undocumented
        --   readable global function, added (token start position to dotted name) for hover and navigation.
        --
        -- Secret values are never indexed.
        function api:Paths(source, force)
            local result = paths(self, source, force)

            if not force and not self:Enabled() then
                return result
            end

            local analysis = engine.Analysis:Get(source)
            local chain, previous, declaration
            self.rmUndocumented = self.rmUndocumented or {}

            -- Reports whether a dotted name resolves to a readable global function.
            -- @param name string  The dotted name, for example 'string.format'.
            -- @return boolean  True for a readable global function; secret values and addon-private names never count.
            local function globalFunction(name)
                if self.rmLimited or name:match('^addon[.:]') or name:match('^functions[.:]') then
                    return false
                end

                local value = _G

                for part in name:gmatch('[%w_]+') do
                    if type(value) ~= 'table' or issecretvalue and issecretvalue(value) then
                        return false
                    end

                    value = rawget(value, part)
                end

                return not (issecretvalue and issecretvalue(value)) and type(value) == 'function'
            end

            for _, token in ipairs(analysis.tokens) do
                if token.kind ~= 'space' and token.kind ~= 'newline' and token.kind ~= 'comment' then
                    if token.kind == 'identifier' or token.kind == 'call' then
                        if chain and previous and (previous.text == '.' or previous.text == ':') then
                            chain = chain .. previous.text .. token.text
                        else
                            chain = token.semanticKind == 'globalVariable'
                                and not token.definition
                                and not analysis.globals[token.text]
                                and token.text
                                or nil

                            declaration = previous and previous.text == 'function'
                        end

                        if chain and not declaration and not token.definition then
                            if engine.rmSymbols[chain] then
                                result[token.start] = chain
                            elseif not result[token.start] and globalFunction(chain) then
                                result[token.start] = chain
                                self.rmUndocumented[chain] = true
                            end
                        end
                    elseif token.text ~= '.' and token.text ~= ':' then
                        chain = nil
                    end

                    previous = token
                end
            end

            return result
        end
    end

    engine.rmContext = context
    api.rmLimited = limited == true
    engine.rmSymbols = self:LuaContextSymbols(context)
    api:rmSyncSymbols()

    if limited then
        api.ready = true
        -- No-op loader for the limited editor, which never loads the engine's own documentation.
        function api:Load() end
    end

    if not engine.Autocomplete.rmNames then
        engine.Autocomplete.rmNames = engine.Autocomplete.Names

        -- Returns the completion name list with documentation-only aliases removed.
        -- @return string[]  The visible names; recomputed only when the engine's list or the symbols change.
        function engine.Autocomplete:Names()
            local names = self:rmNames()

            if self.rmNameSource ~= names or self.rmNameSymbols ~= engine.rmSymbols then
                local visible = {}

                for _, name in ipairs(names) do
                    local symbol = engine.rmSymbols and engine.rmSymbols[name]

                    if not symbol or not symbol.documentationOnly then
                        visible[#visible + 1] = name
                    end
                end

                for name, symbol in pairs(engine.rmSymbols or {}) do
                    self.nameKinds[name] = not symbol.documentationOnly and symbol.kind or nil
                end

                self.rmNameSource, self.rmNameSymbols, self.rmVisibleNames = names, engine.rmSymbols, visible
            end

            return self.rmVisibleNames
        end
    end

    if engine.Autocomplete.Accept and not engine.Autocomplete.rmAccept then
        engine.Autocomplete.rmAccept = engine.Autocomplete.Accept

        -- Accepts the selected completion, binding a function first when the suggestion requires it.
        -- @param input table  The editor input the suggestion list belongs to.
        -- @return boolean  True when the suggestion was accepted; false when the suggestion list is stale, the editor
        --   is
        --   read-only or the binding failed.
        --
        -- Asks the owning editor to bind the function in a transaction, commits it when the engine accepted the text
        -- and rolls
        -- it back otherwise. Nothing is bound when the suggestion list is stale or the editor is read-only.
        function engine.Autocomplete:Accept(input)
            -- Mirror upstream's source/cursor/read-only guard before creating a
            -- dependency. Merely displaying or cancelling suggestions is inert.
            if self.context and input:GetText() ~= self.context.source then
                self:Refine(input, input:GetText(), input.editBox:GetCursorPosition())
            end

            local current = self.context
            local item = self.items and self.items[self.selected]

            if
                self.input ~= input
                or not self.panel
                or not self.panel:IsShown()
                or not current
                or not item
                or input:GetText() ~= current.source
                or input.editBox:GetCursorPosition() ~= current.cursor
                or not self:Enabled(input)
                or engine.Query.Editor:IsReadOnly(input)
            then
                return false
            end

            local symbol = engine.rmSymbols and engine.rmSymbols[item.name]
            local transaction

            if symbol and symbol.requiresBinding then
                local ownerContext = engine.rmContext

                if not ownerContext or type(ownerContext.bindFunction) ~= 'function' then
                    return false
                end

                transaction = ownerContext.bindFunction(symbol.id, symbol.bindingName)

                if not transaction then
                    return false
                end
            end

            local called, accepted = pcall(self.rmAccept, self, input)

            if type(transaction) == 'table' then
                if called and accepted then
                    accepted = transaction:commit()
                else
                    transaction:rollback()
                end
            end

            if not called then
                error(accepted, 0)
            end

            return accepted
        end
    end

    engine.Autocomplete:Hide()
end

-- ============================================================================
-- Navigation
-- ============================================================================

-- Ctrl-click navigation: finds the name under the cursor and navigates to it.
-- @param engine table  The LuaWorkbench engine.
-- @param input table  The editor input.
-- @param source string  The editor text.
-- @param cursor number  The cursor position in `source`.
-- @return any  Truthy when navigation happened; false when it did not.
--
-- A Rotation Master function opens its source; anything else is handed to the engine's own navigation (not in the
-- limited editor).
function addon:NavigateLuaSymbol(engine, input, source, cursor)
    local first = cursor

    while first > 0 and source:sub(first, first):match('[%w_%.:]') do
        first = first - 1
    end

    local last = cursor + 1

    while last <= #source and source:sub(last, last):match('[%w_%.:]') do
        last = last + 1
    end

    local name = source:sub(first + 1, last - 1)
    local symbol = engine.rmSymbols and engine.rmSymbols[name]

    if symbol and symbol.id and self.ShowFunctionSource then
        return self:ShowFunctionSource(symbol.id)
    end
    if engine.Navigation and not engine.embeddingOptions.limited then
        return engine.Navigation:Go({ scriptId = engine.Workspace.current, source = source, cursor = cursor })
    end

    return false
end
