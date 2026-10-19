-- Offline development tool only. Never loaded by the addon.
local F=dofile('tests/fixtures/addon.lua')
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local modules={}
local publicHelpers=dofile('tools/public_helpers.lua')
local standard={};for name,value in pairs(_G) do if type(value)=='function' then standard[name]=value end end
local function descriptor(fn)
    local info=debug.getinfo(fn,'S');return {file=info.source:sub(1,1)=='@' and info.source:sub(2) or info.source,first=info.linedefined,last=info.lastlinedefined,what=info.what}
end
local function capture(module,fn)
    local info=descriptor(fn);info.bindings={}
    for index=1,200 do
        local name,value=debug.getupvalue(fn,index);if not name then break end
        if name~='addon' and name~='L' and not (type(value)=='function' and standard[name]==value) then
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
    return info
end
for _,case in ipairs(inventory.branches) do
    local f=F.new(unpack(case[1]));f.addon.delayed_condition={}
    if case[3] then f.env.MI2_GetMobData=function() end end
    for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then
        f.load(path)
    end end
    for name,documentation in pairs(publicHelpers) do
        local fn=f.addon[name];assert(type(fn)=='function','public helper missing: '..name)
        local info=descriptor(fn);assert(info.file==documentation.module,'public helper module changed: '..name)
        local module=modules[info.file] or {file=info.file,conditions={},bindings={}};modules[info.file]=module
        local captured=capture(module,fn)
        local record=module.bindings[name]
        assert(not record or record.public,'public helper collides with captured local: '..name)
        module.bindings[name]={kind='function',fn=captured,public=documentation,addonMember=name}
    end
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
        local keys={};for name in pairs(value) do keys[#keys+1]=name end;table.sort(keys);local fields={}
        for _,name in ipairs(keys) do fields[#fields+1]=json(name)..':'..json(value[name]) end;return '{'..table.concat(fields,',')..'}'
    end
    error('unsupported source metadata')
end
print(json(modules))
