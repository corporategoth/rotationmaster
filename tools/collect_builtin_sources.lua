-- Offline development tool only. Never loaded by the addon.
local F=dofile('tests/fixtures/addon.lua')
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local modules={}
local publicHelpers=dofile('tools/public_helpers.lua')
local cacheOwnership=dofile('tools/cache_ownership.lua')
local conditionOwnership=dofile('tools/condition_ownership.lua')
for alias in pairs(conditionOwnership) do assert(alias=='protectedRead','condition ownership manifest invalid') end
local conditionOwner=conditionOwnership.protectedRead
assert(type(conditionOwner)=='table' and next(conditionOwnership,'protectedRead')==nil
    and conditionOwner.module=='Functions/cache.lua' and conditionOwner.member=='Functions.cache.protectedRead'
    and conditionOwner.legacyModule=='Conditions/spatial.lua' and conditionOwner.legacyAlias=='protectedRead'
    and conditionOwner.bindingID=='builtin:Conditions/spatial.lua:protectedRead' and conditionOwner.namespace=='Conditions.spatial'
    and conditionOwner.description=='Packaged helper from Conditions/spatial.lua.'
    and type(conditionOwner.captureBindings)=='table' and next(conditionOwner.captureBindings)==nil,'condition ownership manifest invalid')
assert(cacheOwnership.module=='Functions/cache.lua' and type(cacheOwnership.bindings)=='table','cache ownership manifest invalid')
local cacheKinds={getCachedInternal='function',packResults='function',cacheHits='number',cacheMisses='number',nilArgument='table',cachedResult='table'}
for alias,entry in pairs(cacheOwnership.bindings) do
    assert(cacheKinds[alias]==entry.kind and entry.bindingID=='builtin:utils.lua:'..alias,'cache ownership identity invalid: '..alias)
end
for alias in pairs(cacheKinds) do assert(cacheOwnership.bindings[alias],'cache ownership declaration missing: '..alias) end
-- Old saved factory bodies explicitly capture these library bindings. Retain
-- their original identities even after current factories stop calling Ace.
local retainedAceBindings={'UI/checkbox.lua','UI/selector.lua','UI/condition_inputs.lua','Conditions/common.lua','Conditions/combat.lua','Conditions/talent.lua','UI/condition_layout.lua'}
local lazyAceGetters={};for _,path in ipairs(retainedAceBindings) do lazyAceGetters[path]='addon:GetConditionWidgetCompatibilityLibrary()' end
lazyAceGetters['UI/condition_layout.lua']='addon:BindConditionGroupCompatibilityLibrary()'
local standard={};for name,value in pairs(_G) do if type(value)=='function' then standard[name]=value end end
local function descriptor(fn)
    local info=debug.getinfo(fn,'S');return {file=info.source:sub(1,1)=='@' and info.source:sub(2) or info.source,first=info.linedefined,last=info.lastlinedefined,what=info.what}
end
local publicIdentities,callbackBindings,currentAddon,ownedCacheSeen,ownedConditionValues={},{},nil,{},{}
local function sameCallbacks(left,right)
    for name,callback in pairs(left) do
        local other=right[name]
        if not other or callback.file~=other.file or callback.first~=other.first or callback.last~=other.last or callback.what~=other.what then return false end
        for alias,id in pairs(callback.bindings) do if other.bindings[alias]~=id then return false end end
        for alias,id in pairs(other.bindings) do if callback.bindings[alias]~=id then return false end end
    end
    for name in pairs(right) do if not left[name] then return false end end
    return true
end
local function storeCallbacks(module,tag,variant,callbacks)
    local target
    if variant~=nil then
        assert(type(variant)=='string' and #variant<=64 and variant:match('^[A-Za-z_][A-Za-z_0-9]*$'),'invalid builtin source variant: '..tag)
        assert(not module.conditions[tag],'mixed marked/unmarked builtin source variants: '..tag)
        module.conditionVariants=module.conditionVariants or {};module.conditionVariants[tag]=module.conditionVariants[tag] or {};target=module.conditionVariants[tag]
    else
        assert(not (module.conditionVariants and module.conditionVariants[tag]),'mixed marked/unmarked builtin source variants: '..tag)
        target=module.conditions;variant=tag
    end
    local previous=target[variant]
    assert(not previous or sameCallbacks(previous,callbacks),'ambiguous builtin callback source; declare a distinct builtinSourceVariant: '..tag)
    target[variant]=callbacks
end
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
local capture
local function ownedCacheBinding(alias,value)
    local declaration=assert(cacheOwnership.bindings[alias],'cache ownership declaration missing: '..alias)
    local owner=currentAddon.builtinSourceModules and currentAddon.builtinSourceModules[cacheOwnership.module]
    local legacy=currentAddon.builtinSourceModules and currentAddon.builtinSourceModules['utils.lua']
    assert(type(owner)=='function' and type(legacy)=='function' and type(value)==declaration.kind
        and rawequal(owner(alias),value) and rawequal(legacy(alias),value),'cache ownership getter mismatch: '..alias)
    local module=modules[cacheOwnership.module] or {file=cacheOwnership.module,conditions={},bindings={}};modules[module.file]=module
    if not ownedCacheSeen[alias] then
        ownedCacheSeen[alias]=true
        local record={kind=declaration.kind,ownership={bindingID=declaration.bindingID,namespace='utils',description='Packaged helper from utils.lua.'}}
        module.bindings[alias]=record
        if declaration.kind=='function' then
            assert(descriptor(value).file==module.file,'cache ownership function owner mismatch: '..alias)
            record.fn=capture(module,value,declaration.captureBindings,true)
        end
    end
    return declaration.bindingID
end
capture=function(module,fn,captureBindings,ownedCapture)
    local info=descriptor(fn);info.bindings={};local captured={}
    for index=1,200 do
        local name,value=debug.getupvalue(fn,index);if not name then break end
        if name~='addon' and name~='L' and not (type(value)=='function' and standard[name]==value) then
            local owned=module.file==cacheOwnership.module and cacheOwnership.bindings[name]
            local reference=captureBindings and captureBindings[name]
            assert(not ownedCapture or reference,'cache ownership capture declaration missing: '..name)
            reference=reference or owned and owned.bindingID
            if reference then
                local path,alias=reference:match('^builtin:(.-):([A-Za-z_][A-Za-z_0-9]*)$')
                if module.file==cacheOwnership.module and path=='utils.lua' and cacheOwnership.bindings[alias] then
                    assert(name==alias,'cache ownership capture identity mismatch: '..name)
                    info.bindings[name]=ownedCacheBinding(alias,value)
                else
                    local getter=path and currentAddon.builtinSourceModules and currentAddon.builtinSourceModules[path]
                    assert(type(value)~='function' and type(getter)=='function' and rawequal(getter(alias),value),'captured binding getter mismatch: '..name)
                    local target=modules[path] or {file=path,conditions={},bindings={}};modules[path]=target
                    assert(not target.bindings[alias] or target.bindings[alias].kind==type(value) and not target.bindings[alias].fn,'captured binding identity collision: '..reference)
                    target.bindings[alias]=target.bindings[alias] or {kind=type(value)}
                    info.bindings[name]=reference
                end
                captured[name]=true
            else
                local ownedCondition=module.file==conditionOwner.legacyModule and name==conditionOwner.legacyAlias
                local qualified=not ownedCondition and qualifiedBindings(module,name,value)
                if ownedCondition then
                    assert(type(value)=='function' and value==ownedConditionValues[conditionOwner.bindingID],
                        'condition ownership capture mismatch: '..module.file..':'..name)
                    info.bindings[name]=conditionOwner.bindingID
                elseif qualified then
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
    local f=F.new(unpack(case[1]));f.addon.delayed_condition={};publicIdentities={};currentAddon=f.addon;ownedCacheSeen={};ownedConditionValues={}
    f.load('Platform/spells.lua');f.load('Platform/actions.lua');f.load('Platform/range.lua')
    if case[3] then f.env.MI2_GetMobData=function() end end
    for path in io.lines('RotationMaster.toc') do if path:match('^Conditions/') then
        f.load(path)
    end end
    local cacheGetter=f.addon.builtinSourceModules and f.addon.builtinSourceModules[cacheOwnership.module]
    assert(type(cacheGetter)=='function','cache ownership module missing')
    for alias in pairs(cacheOwnership.bindings) do ownedCacheBinding(alias,cacheGetter(alias)) end
    for alias,entry in pairs(conditionOwnership) do
        local fn=f.addon
        for part in entry.member:gmatch('[%w_]+') do fn=type(fn)=='table' and rawget(fn,part) or nil end
        local owner=f.addon.builtinSourceModules and f.addon.builtinSourceModules[entry.module]
        local legacy=f.addon.builtinSourceModules and f.addon.builtinSourceModules[entry.legacyModule]
        assert(type(fn)=='function' and descriptor(fn).file==entry.module and type(owner)=='function' and owner(alias)==fn
            and type(legacy)=='function' and legacy(entry.legacyAlias)==fn,'condition ownership getter mismatch: '..alias)
        local module=modules[entry.module] or {file=entry.module,conditions={},bindings={}};modules[entry.module]=module
        local captured=capture(module,fn,entry.captureBindings,true)
        local previous=module.bindings[alias]
        assert(not previous or previous.ownership and sameCallbacks({[alias]=previous.fn},{[alias]=captured}),
            'condition ownership identity collision: '..alias)
        module.bindings[alias]={kind='function',fn=captured,
            ownership={bindingID=entry.bindingID,namespace=entry.namespace,description=entry.description}}
        ownedConditionValues[entry.bindingID]=fn
        assert(not publicIdentities[entry.bindingID],'condition ownership duplicate identity: '..alias)
        publicIdentities[entry.bindingID]=fn
    end
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
        assert((not lazyAceGetters[path] and existing==nil) or existing==f.libraries['AceGUI-3.0'],'retained widget library identity mismatch: '..path)
        module.bindings.AceGUI={kind='table',getterExpression=lazyAceGetters[path]}
    end
    callbackBindings=f.addon.builtinCallbackBindings or {}
    for _,bindings in pairs(callbackBindings) do assert(f.addon:NormalizeFunctionBindings(bindings),'invalid declared callback bindings') end
    local definitions={};for tag,definition in pairs(f.addon.definitions) do definitions[tag]=definition end
    for _,group in pairs(f.addon.delayed_condition) do for tag,definition in pairs(group) do definitions[tag]=definition end end
    for tag,definition in pairs(definitions) do
        local snapshots={}
        for name,fn in pairs(definition) do if type(fn)=='function' then
            local info=descriptor(fn)
            if info.file:match('^Conditions/') then
                local module=modules[info.file] or {file=info.file,conditions={},bindings={}};modules[info.file]=module
                snapshots[info.file]=snapshots[info.file] or {};snapshots[info.file][name]=capture(module,fn)
            end
        end end
        for path,callbacks in pairs(snapshots) do storeCallbacks(modules[path],tag,definition.builtinSourceVariant,callbacks) end
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
