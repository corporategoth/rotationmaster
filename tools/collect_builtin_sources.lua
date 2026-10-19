-- Offline development tool only. Never loaded by the addon.
local F=dofile('tests/fixtures/addon.lua')
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local modules={}
local publicHelpers=dofile('tools/public_helpers.lua')
-- Old saved factory bodies explicitly capture these library bindings. Retain
-- their original identities even after current factories stop calling Ace.
local retainedAceBindings={'UI/checkbox.lua','UI/selector.lua','UI/condition_inputs.lua','Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua'}
local standard={};for name,value in pairs(_G) do if type(value)=='function' then standard[name]=value end end
local function descriptor(fn)
    local info=debug.getinfo(fn,'S');return {file=info.source:sub(1,1)=='@' and info.source:sub(2) or info.source,first=info.linedefined,last=info.lastlinedefined,what=info.what}
end
local publicIdentities,callbackBindings,currentAddon={},{},nil
local function qualifiedBindings(module,root,value)
    local declared={}
    for alias,id in pairs(callbackBindings[module.file] or {}) do
        if alias:match('^([^.]+)%.')==root then declared[alias]=id end
    end
    if not next(declared) then return nil end
    local result,seen={},{}
    local function visit(current,path,depth)
        assert(depth<=8,'qualified callback binding depth: '..path)
        if type(current)=='function' then
            local id=declared[path]
            assert(id and publicIdentities[id]==current,'qualified callback binding identity mismatch: '..path)
            result[path]=id;return
        end
        assert(type(current)=='table' and not getmetatable(current) and not seen[current],'invalid qualified callback namespace: '..path)
        seen[current]=true
        for name,child in pairs(current) do
            assert(type(name)=='string' and name:match('^[A-Za-z_][A-Za-z_0-9]*$'),'invalid qualified callback name: '..path)
            visit(child,path..'.'..name,depth+1)
        end
    end
    visit(value,root,1)
    for alias in pairs(declared) do assert(result[alias],'qualified callback binding missing: '..alias) end
    return result
end
local function capture(module,fn,captureBindings)
    local info=descriptor(fn);info.bindings={};local captured={}
    for index=1,200 do
        local name,value=debug.getupvalue(fn,index);if not name then break end
        if name~='addon' and name~='L' and not (type(value)=='function' and standard[name]==value) then
            local reference=captureBindings and captureBindings[name]
            if reference then
                local path,alias=reference:match('^builtin:(.-):([A-Za-z_][A-Za-z_0-9]*)$')
                local getter=path and currentAddon.builtinSourceModules and currentAddon.builtinSourceModules[path]
                assert(type(value)~='function' and type(getter)=='function' and rawequal(getter(alias),value),'captured binding getter mismatch: '..name)
                local target=modules[path] or {file=path,conditions={},bindings={}};modules[path]=target
                assert(not target.bindings[alias] or target.bindings[alias].kind==type(value) and not target.bindings[alias].fn,'captured binding identity collision: '..reference)
                target.bindings[alias]=target.bindings[alias] or {kind=type(value)}
                info.bindings[name]=reference;captured[name]=true
            else
                local qualified=qualifiedBindings(module,name,value)
                if qualified then
                    for alias,id in pairs(qualified) do info.bindings[alias]=id end
                else
                    info.bindings[name]='builtin:'..module.file..':'..name
                    if not module.bindings[name] then
                        local record={kind=type(value)};module.bindings[name]=record
                        if type(value)=='function' then
                            local source=descriptor(value)
                            if source.file==module.file then record.fn=capture(module,value) else record.kind='value' end
                        end
                    end
                end
            end
        end
    end
    for name in pairs(captureBindings or {}) do assert(captured[name],'declared captured binding missing: '..name) end
    return info
end
for _,case in ipairs(inventory.branches) do
    local f=F.new(unpack(case[1]));f.addon.delayed_condition={};publicIdentities={};currentAddon=f.addon
    f.load('Platform/spells.lua');f.load('Platform/actions.lua');f.load('Platform/range.lua')
    if case[3] then f.env.MI2_GetMobData=function() end end
    for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then
        f.load(path)
    end end
    for name,documentation in pairs(publicHelpers) do
        local member=documentation.member or name
        assert(member:match('^[%a_][%w_%.]*$') and not member:find('..',1,true),'invalid public helper path: '..name)
        local fn=f.addon;for part in member:gmatch('[%w_]+') do fn=type(fn)=='table' and rawget(fn,part) or nil end
        assert(type(fn)=='function','public helper missing: '..name)
        local info=descriptor(fn);assert(info.file==documentation.module,'public helper module changed: '..name)
        local module=modules[info.file] or {file=info.file,conditions={},bindings={}};modules[info.file]=module
        local captured=capture(module,fn,documentation.captureBindings)
        local record=module.bindings[name]
        assert(not record or record.public,'public helper collides with captured local: '..name)
        local id=documentation.bindingID or 'builtin:'..info.file..':'..name
        assert(not publicIdentities[id],'duplicate public helper identity: '..id)
        publicIdentities[id]=fn
        module.bindings[name]={kind='function',fn=captured,public=documentation,addonMember=member}
    end
    for _,path in ipairs(retainedAceBindings) do
        local module=modules[path] or {file=path,conditions={},bindings={}};modules[path]=module
        local getter=f.addon.builtinSourceModules and f.addon.builtinSourceModules[path]
        local existing=getter and getter('AceGUI')
        assert(existing==nil or existing==f.libraries['AceGUI-3.0'],'retained widget library identity mismatch: '..path)
        module.bindings.AceGUI={kind='table'}
    end
    callbackBindings=f.addon.builtinCallbackBindings or {}
    for _,bindings in pairs(callbackBindings) do assert(f.addon:NormalizeFunctionBindings(bindings),'invalid declared callback bindings') end
    local definitions={};for tag,definition in pairs(f.addon.definitions) do definitions[tag]=definition end
    for _,group in pairs(f.addon.delayed_condition) do for tag,definition in pairs(group) do definitions[tag]=definition end end
    for tag,definition in pairs(definitions) do
        for name,fn in pairs(definition) do if type(fn)=='function' then
            local info=descriptor(fn)
            if info.file:match('^Conditions/') then
                local module=modules[info.file] or {file=info.file,conditions={},bindings={}};modules[info.file]=module
                module.conditions[tag]=module.conditions[tag] or {};module.conditions[tag][name]=capture(module,fn)
            end
        end end
    end
end
local function json(value)
    if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c) if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end;return string.format('\\u%04x',c:byte()) end)..'"'
    elseif type(value)=='number' then return tostring(value)
    elseif type(value)=='table' then
        if #value>0 then local items={};for _,item in ipairs(value) do items[#items+1]=json(item) end;return '['..table.concat(items,',')..']' end
        local keys={};for name in pairs(value) do keys[#keys+1]=name end;table.sort(keys);local fields={}
        for _,name in ipairs(keys) do fields[#fields+1]=json(name)..':'..json(value[name]) end;return '{'..table.concat(fields,',')..'}'
    end
    error('unsupported source metadata')
end
print(json(modules))
