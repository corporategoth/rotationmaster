-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Offline only (tools and tests); never loaded by the addon. The packaged Built
-- In modules: one load-on-demand addon per class (Modules/RotationMaster_<Class>)
-- with one client-flavour TOC per edition, each listing only that edition's
-- folder. Module and edition names come from Core/builtin_modules.lua, the
-- in-game loader. Load order: edition order, then class name; within an edition,
-- the order its TOC lists (blocks.lua before the packs that expand it).
local M = {}

-- Tells whether a file can be opened for reading.
-- @param path string  The file path.
-- @return boolean  True when it can.
local function readable(path)
    local file = io.open(path, 'r')

    if file then
        file:close()
        return true
    end

    return false
end

-- Loads Core/builtin_modules.lua, the in-game loader's module and edition catalog, outside the game.
-- @param root string  The repository root, with a trailing slash or empty for the current directory.
-- @return table  The BuiltInModules catalog (classes and editions).
-- @return table  The namespace the loader file populated (it carries GetBuiltInModuleName).
local function catalog(root)
    local scope = { ipairs = ipairs, type = type }
    scope._G = scope
    local chunk = assert(loadfile(root .. 'Core/builtin_modules.lua'))
    local namespace = {}
    setfenv(chunk, setmetatable(scope, { __index = function() return nil end }))
    chunk('RotationMaster', namespace)
    return namespace.BuiltInModules, namespace
end

-- Lists the file entries of a TOC, repository-relative, in order.
-- @param toc string  The TOC path, relative to root.
-- @param root string|nil  The repository root; nil or empty means the current directory.
-- @return string[]  The paths of the files the TOC lists (blank lines and # comments skipped).
function M.entries(toc, root)
    root = (root and root ~= '') and (root:gsub('/?$', '/')) or ''
    local dir = toc:match('^(.*)/[^/]+$')
    local result = {}

    for line in io.lines(root .. toc) do
        line = line:gsub('\r', ''):match('^%s*(.-)%s*$')

        if line ~= '' and not line:match('^#') then
            result[#result + 1] = dir .. '/' .. line:gsub('\\', '/')
        end
    end

    return result
end

-- Lists every class module on disk.
-- @param root string|nil  The repository root; nil or empty means the current directory.
-- @return table[]  The modules, each {name, class, dir, toc (the unsuffixed fallback), tocs (every TOC), bind,
--   editions={[family]={family, folder, flavors, tocs, files}}}.
-- @return table[]  The editions of the catalog.
--
-- An edition's files are its primary flavour TOC's block and pack paths (bind.lua excluded); its other flavour TOCs are
-- identical (tests/verify.py).
function M.list(root)
    root = (root and root ~= '') and (root:gsub('/?$', '/')) or ''
    local modules, namespace = catalog(root)
    local classes = {}

    for token in pairs(modules.classes) do
        classes[#classes + 1] = token
    end

    table.sort(classes, function(x, y) return modules.classes[x] < modules.classes[y] end)
    local result = {}

    for _, token in ipairs(classes) do
        local name = namespace.GetBuiltInModuleName(namespace, token)
        local dir = 'Modules/' .. name

        local module = {
            name = name,
            class = token,
            dir = dir,
            toc = dir .. '/' .. name .. '.toc',
            bind = dir .. '/bind.lua',
            tocs = {},
            editions = {},
        }

        if readable(root .. module.toc) then
            module.tocs[1] = module.toc

            for _, edition in ipairs(modules.editions) do
                local row = { family = edition.family, folder = edition.folder, flavors = edition.flavors, tocs = {} }

                for _, flavor in ipairs(edition.flavors) do
                    local toc = dir .. '/' .. name .. '_' .. flavor .. '.toc'

                    if readable(root .. toc) then
                        row.tocs[#row.tocs + 1] = toc
                        module.tocs[#module.tocs + 1] = toc
                    end
                end

                if #row.tocs > 0 then
                    row.files = {}

                    for _, path in ipairs(M.entries(row.tocs[1], root)) do
                        if path ~= module.bind and path ~= dir .. '/locales.xml' then
                            row.files[#row.files + 1] = path
                        end
                    end

                    module.editions[edition.family] = row
                end
            end

            result[#result + 1] = module
        end
    end

    assert(#result > 0, 'no Built In modules under ' .. root .. 'Modules')
    return result, modules.editions
end

-- Lists the block and pack paths of the Built In modules, in load order.
-- @param filter table|nil  {family=, class=}; either may be omitted, and nil selects everything.
-- @param root string|nil  The repository root; nil or empty means the current directory.
-- @return string[]  The flat path list.
function M.paths(filter, root)
    local result = {}
    local list, editions = M.list(root)

    for _, edition in ipairs(editions) do
        for _, module in ipairs(list) do
            local row = module.editions[edition.family]

            if
                row
                and (not filter
                    or (filter.family == nil or filter.family == edition.family)
                        and (filter.class == nil or filter.class == module.class))
            then
                for _, path in ipairs(row.files) do
                    result[#result + 1] = path
                end
            end
        end
    end

    return result
end

-- Tells whether a path is a module's blocks.lua.
-- @param path string  The file path.
-- @return boolean  True for a path ending in /blocks.lua.
function M.isBlock(path)
    return path:match('/blocks%.lua$') ~= nil
end

-- Lists every module TOC (fallback and flavours): inputs whose bytes decide what loads.
-- @param root string|nil  The repository root; nil or empty means the current directory.
-- @return string[]  The TOC paths.
function M.tocs(root)
    local result = {}

    for _, module in ipairs(M.list(root)) do
        for _, toc in ipairs(module.tocs) do
            result[#result + 1] = toc
        end
    end

    return result
end

return M
